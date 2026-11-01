"""Annual archive integration tests, always against the separate *_test DB."""
import unittest
from datetime import datetime, timezone
from unittest.mock import patch
from zoneinfo import ZoneInfo

import annual_evolution as annual
from app import app, connect, migrate
import test_api as fixture
from test_api import HEADERS


def instant(value):
    return datetime.fromisoformat(value).replace(tzinfo=timezone.utc)


def tx(value, date, kind='expense', **links):
    return {'type': kind, 'amount': value,
            'date': {'_type': 'timestamp', 'value': date}, **links}


class CalculationTests(unittest.TestCase):
    def test_flows_future_dates_transfers_investments_and_timezone_boundary(self):
        result = annual.calculate(
            {'cash': {'balance': 1000}, 'holding': {'balance': 300}},
            {'food': {'name': 'Food', 'type': 'expense'}},
            {'asset': {'holdingAccountId': 'holding'}}, iter([
                tx(40, '2025-12-31T22:59:00Z', categoryId='food', fromAccountId='cash'),
                tx(10, '2025-12-31T23:00:00Z', categoryId='food', fromAccountId='cash'),
                tx(200, '2026-01-02T12:00:00Z', 'income', fromAccountId='cash'),
                tx(100, '2026-01-03T12:00:00Z', 'investment', fromAccountId='cash', investmentId='asset'),
                tx(20, '2026-01-04T12:00:00Z', 'transfer', fromAccountId='holding', toAccountId='cash'),
                tx(30, '2026-12-01T12:00:00Z', categoryId='food', fromAccountId='cash'),
            ]), 2026, instant('2026-06-01T12:00:00'), ZoneInfo('Europe/Paris'))
        self.assertEqual(result['accounts']['cash'], {'name': '', 'beginning': 920.0, 'ending': 1030.0})
        self.assertEqual(result['accounts']['holding']['beginning'], 220)
        self.assertEqual(result['accounts']['holding']['ending'], 300)
        self.assertEqual(result['categories']['expense:food']['beginning'], 40)
        self.assertEqual(result['categories']['expense:food']['ending'], 50)

    def test_cents_negative_balance_and_references(self):
        result = annual.calculate({'a': {'balance': -1.01}}, {}, {}, iter([
            tx(.1, '2026-01-02T00:00:00Z', fromAccountId={'_type': 'reference', 'path': 'users/u/accounts/a'}),
            tx(.2, '2026-01-02T00:00:00Z', fromAccountId='a'),
        ]), 2026, instant('2026-06-01T12:00:00'), ZoneInfo('UTC'))
        self.assertEqual(result['accounts']['a']['beginning'], -.71)


class AnnualTests(unittest.TestCase):
    setUp = fixture.ApiTests.setUp
    register = fixture.ApiTests.register
    path = fixture.ApiTests.path
    operation = fixture.ApiTests.operation
    commit = fixture.ApiTests.commit
    seed = fixture.ApiTests.seed

    @classmethod
    def setUpClass(cls):
        fixture.ApiTests.setUpClass()

    def report(self, year=2026, at='2026-11-01T12:00:00', client=None):
        with patch('app.now', return_value=instant(at)):
            result = (client or self.client).post('/api/annual-evolution', headers=HEADERS,
                json={'year': year, 'timeZone': 'Europe/Paris'})
        self.assertEqual(result.status_code, 200, result.json)
        return result.json

    def test_snapshot_survives_manual_edits_and_cache_invalidates(self):
        self.seed()
        self.commit([self.operation('transactions/old', tx(40, '2025-02-01T00:00:00Z', categoryId='expense', fromAccountId='cash')),
                     self.operation('transactions/new', tx(10, '2026-02-01T00:00:00Z', categoryId='expense', fromAccountId='cash'))])
        first = self.report()
        self.assertEqual(first['accounts'][0]['beginning'], 110)
        self.assertEqual(first['categories'][0]['beginning'], 40)
        self.assertEqual(first['categories'][0]['ending'], 50)
        self.assertEqual(self.commit([self.operation('accounts/cash', {'balance': 150}, 'update')]).status_code, 200)
        changed = self.report()
        self.assertEqual(changed['accounts'][0]['beginning'], 110)
        self.assertEqual(changed['accounts'][0]['ending'], 150)

    def test_cached_report_does_not_scan_transactions_again(self):
        self.seed()
        first = self.report()
        with patch('annual_evolution.read_values', side_effect=AssertionError('Unexpected history scan')):
            self.assertEqual(self.report(), first)
        with connect() as db:
            self.assertEqual(db.execute('SELECT count(*) AS n FROM annual_snapshots WHERE user_id=%s', (self.uid,)).fetchone()['n'], 1)

    def test_rollover_happens_before_first_write_and_previous_year_stays_closed(self):
        self.seed()
        self.report()
        with patch('app.now', return_value=instant('2026-12-31T23:00:01')):
            self.assertEqual(self.commit([self.operation('accounts/cash', {'balance': 300}, 'update')]).status_code, 200)
        current = self.report(2027, '2027-01-01T12:00:00')
        cash = next(row for row in current['accounts'] if row['id'] == 'cash')
        self.assertEqual((cash['beginning'], cash['ending']), (100, 300))
        previous = self.report(2026, '2027-01-01T12:00:00')
        self.assertEqual(next(row for row in previous['accounts'] if row['id'] == 'cash')['ending'], 100)
        with patch('app.now', return_value=instant('2027-01-02T12:00:00')):
            self.commit([self.operation('accounts/cash', {'balance': 500}, 'update')])
        self.assertEqual(self.report(2026, '2027-01-02T12:00:00')['accounts'], previous['accounts'])

    def test_failed_write_rolls_back_snapshot_and_revision(self):
        self.seed()
        self.report()
        with patch('app.now', return_value=instant('2026-12-31T23:00:01')):
            self.assertEqual(self.commit([self.operation('accounts/cash', {'balance': {'_op': 'increment', 'value': -999}}, 'update')]).status_code, 409)
        with connect() as db:
            self.assertIsNone(db.execute('SELECT 1 FROM annual_snapshots WHERE user_id=%s AND year=2027', (self.uid,)).fetchone())
            self.assertEqual(db.execute('SELECT revision FROM annual_tracking WHERE user_id=%s', (self.uid,)).fetchone()['revision'], 0)

    def test_inactive_year_is_saved_before_a_later_manual_adjustment(self):
        self.seed()
        self.report()
        with patch('app.now', return_value=instant('2028-01-02T12:00:00')):
            self.commit([self.operation('accounts/cash', {'balance': 300}, 'update')])
        inactive = self.report(2027, '2028-01-02T12:00:00')
        cash = next(row for row in inactive['accounts'] if row['id'] == 'cash')
        self.assertEqual((cash['beginning'], cash['ending']), (100, 100))

    def test_isolation_authentication_and_future_year(self):
        self.seed()
        self.report()
        self.assertEqual(self.report(client=self.other)['accounts'], [])
        self.assertEqual(self.report(2027)['future'], True)
        self.assertEqual(app.test_client().post('/api/annual-evolution', headers=HEADERS, json={'year': 2026}).status_code, 401)
        self.assertEqual(self.client.post('/api/annual-evolution', headers=HEADERS, json={'year': True}).status_code, 400)
        self.assertEqual(self.client.post('/api/annual-evolution', headers=HEADERS, json={'year': 2026, 'timeZone': '../secret'}).status_code, 400)

    def test_references_persist_after_new_client_and_user_deletion_cascades(self):
        self.seed()
        first = self.report()
        from test_api import PASSWORD
        second = app.test_client()
        self.assertEqual(second.post('/api/auth/login', headers=HEADERS, json={'email': 'first@example.test', 'password': PASSWORD}).status_code, 200)
        self.assertEqual(self.report(client=second), first)
        with connect() as db:
            db.execute('DELETE FROM users WHERE id=%s', (self.uid,))
            for table in ('annual_tracking', 'annual_snapshots', 'annual_report_cache'):
                self.assertEqual(db.execute('SELECT count(*) AS n FROM '+table+' WHERE user_id=%s', (self.uid,)).fetchone()['n'], 0)

    def test_two_tabs_create_one_snapshot_and_share_the_cached_report(self):
        from concurrent.futures import ThreadPoolExecutor
        from test_api import PASSWORD
        self.seed()
        second = app.test_client()
        second.post('/api/auth/login', headers=HEADERS, json={'email': 'first@example.test', 'password': PASSWORD})
        def query(client):
            response = client.post('/api/annual-evolution', headers=HEADERS,
                                   json={'year': 2026, 'timeZone': 'Europe/Paris'})
            self.assertEqual(response.status_code, 200, response.json)
            return response.json
        with patch('app.now', return_value=instant('2026-11-01T12:00:00')), \
                patch('annual_evolution.read_values', wraps=annual.read_values) as reads:
            with ThreadPoolExecutor(max_workers=2) as pool:
                results = list(pool.map(query, [self.client, second]))
        self.assertEqual(results[0], results[1])
        self.assertEqual(reads.call_count, 1)
        with connect() as db:
            self.assertEqual(db.execute('SELECT count(*) AS n FROM annual_snapshots WHERE user_id=%s', (self.uid,)).fetchone()['n'], 1)


if __name__ == '__main__':
    unittest.main()
