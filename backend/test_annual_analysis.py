import time
import unittest
from datetime import datetime, timezone
from annual_analysis import build_analysis, effects
from app import connect, digest
from test_api import ApiTests, HEADERS

class CalculationTests(unittest.TestCase):
    def test_transfers_and_investments_are_not_global_expenses(self):
        self.assertEqual(effects(dict(type='investment', amount=20, fromAccountId='a', toAccountId='b', investmentId='gold')),
                         {'accounts/a': -2000, 'accounts/b': 2000, 'investments/gold': 2000})
        self.assertEqual(effects(dict(type='transfer', amount=5, fromAccountId='b', toAccountId='a', investmentId='gold'))['investments/gold'], -500)

    def test_large_history_stays_bounded_and_uses_exact_cents(self):
        docs = {'accounts/a': dict(name='Courant', balance=1000)}
        for i in range(10000):
            docs['transactions/' + str(i)] = dict(type='expense', amount=.1, fromAccountId='a', date=dict(value='2026-01-01T00:00:00Z'))
        start = time.monotonic()
        result = build_analysis(docs, 2026, datetime(2026, 11, 13, tzinfo=timezone.utc))
        self.assertEqual(result['entities'][0]['opening'], 2000)
        self.assertEqual(len(result['entities'][0]['closing']), 12)
        self.assertLess(time.monotonic() - start, 3)

class AnnualApiTests(ApiTests):
    def analysis(self, year=2026, client=None):
        return (client or self.client).post('/api/analysis/annual', headers=HEADERS, json={'year': year})

    def test_adjustment_cache_encryption_and_retroactive_delete(self):
        self.assertEqual(self.commit([self.operation('accounts/a', {'name':'Courant', 'balance':1000}), self.operation('categories/c', {'name':'Achats', 'type':'expense'})]).status_code, 200)
        tx = dict(type='expense', amount=100, fromAccountId='a', categoryId='c', date=dict(_type='timestamp', value='2026-01-02T12:00:00Z'))
        self.assertEqual(self.commit([self.operation('transactions/t', tx), self.operation('accounts/a', {'balance': {'_op':'increment','value':-100}}, 'update')]).status_code, 200)
        result = self.analysis()
        self.assertEqual(result.status_code, 200, result.json)
        account = next(e for e in result.json['entities'] if e['path']=='accounts/a')
        self.assertEqual((account['opening'], account['current']), (1000, 900))
        self.assertTrue(account['estimated'])
        with connect() as db:
            row = db.execute('SELECT data,sealed_data FROM annual_analysis_cache WHERE user_id=%s', (self.uid,)).fetchone()
            self.assertNotIn('Courant', str(row['data']))
            self.assertIsNotNone(row['sealed_data'])
        self.assertEqual(self.commit([self.operation('accounts/a', {'balance':1100}, 'update')]).status_code, 200)
        account = next(e for e in self.analysis().json['entities'] if e['path']=='accounts/a')
        self.assertEqual((account['opening'], account['current'], account['valuationChange']), (1000,1100,200))
        self.assertEqual(self.commit([self.operation('transactions/t', action='delete'), self.operation('accounts/a', {'balance': {'_op':'increment','value':100}}, 'update')]).status_code, 200)
        account = next(e for e in self.analysis().json['entities'] if e['path']=='accounts/a')
        self.assertEqual((account['opening'],account['current']), (1000,1200))

    def test_security_boundaries_and_reference(self):
        self.commit([self.operation('accounts/a', {'name':'Privé', 'balance':125})])
        self.assertEqual(self.analysis(client=self.other).json['entities'], [])
        for year in [True, '2026', '../secret', 2201]:
            self.assertEqual(self.analysis(year).status_code, 400)
        self.assertEqual(self.client.post('/api/analysis/annual', json={'year':2026}).status_code,403)
        path = 'accounts/a'
        ref = self.operation('annualReferences/' + digest(path+':2026'), dict(entityPath=path,year=2026,amount=0))
        self.assertEqual(self.commit([ref]).status_code,200)
        account = self.analysis().json['entities'][0]
        self.assertFalse(account['estimated'])
        self.assertIsNone(account['percent'])
        self.assertEqual(account['current'],125)
        ref['data']['entityPath']='users/'+self.other_uid+'/accounts/a'
        self.assertEqual(self.commit([ref]).status_code,400)

    def test_restoration_across_users_does_not_duplicate_adjustments(self):
        self.commit([self.operation('accounts/a', {'name':'Courant', 'balance':1000})])
        self.commit([self.operation('accounts/a', {'balance':1200}, 'update')])
        with connect() as db:
            from encryption import vault
            docs = [(r['path'], vault(db).decode(self.uid, r)) for r in db.execute(
                'SELECT path,data,sealed_data FROM documents WHERE user_id=%s', (self.uid,)).fetchall() if r['path'] != 'user']
        import secrets
        for path, data in sorted(docs, key=lambda pair: (not pair[0].startswith('accounts/'), pair[0])):
            response = self.other.post('/api/documents/commit', headers=HEADERS, json=dict(
                restore=True, requestId=secrets.token_hex(16), operations=[dict(path=self.path(path,self.other_uid),action='set',data=data)]))
            self.assertEqual(response.status_code,200,response.json)
        original = self.analysis().json['entities'][0]
        restored = self.analysis(client=self.other).json['entities'][0]
        self.assertEqual((original['opening'], original['current']), (restored['opening'], restored['current']))
