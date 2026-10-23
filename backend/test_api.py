"""Integration tests against an isolated PostgreSQL database ending in _test."""
import os
import secrets
import unittest
from concurrent.futures import ThreadPoolExecutor
from app import app, connect, migrate

HEADERS = {'X-MySold-Request': '1', 'Origin': 'http://localhost:28085'}
PASSWORD = 'Test-password-123!'
DATE = {'_type': 'timestamp', 'value': '2026-10-22T12:00:00.000Z'}


class ApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not os.environ.get('POSTGRES_DB', '').endswith('_test'):
            raise RuntimeError('Tests require a separate database ending in _test.')
        os.environ['COOKIE_SECURE'] = 'false'
        os.environ['APP_ORIGIN'] = 'http://localhost:28085'
        migrate()

    def setUp(self):
        with connect() as db:
            db.execute('DELETE FROM users')
            db.execute('DELETE FROM rate_limits')
        self.client = app.test_client()
        self.uid = self.register(self.client, 'first@example.test')
        self.other = app.test_client()
        self.other_uid = self.register(self.other, 'second@example.test')

    def register(self, client, email):
        response = client.post('/api/auth/register', json={
            'email': email, 'password': PASSWORD, 'profile': {'firstName': 'Test', 'pin': 'a'*64},
        }, headers=HEADERS)
        self.assertEqual(response.status_code, 200, response.json)
        self.assertIn('HttpOnly', response.headers['Set-Cookie'])
        return response.json['user']['uid']

    def path(self, path, uid=None):
        return 'users/' + (uid or self.uid) + ('' if path == 'user' else '/' + path)

    def operation(self, path, data=None, action='set'):
        return {'path': self.path(path), 'action': action, 'data': data or {}}

    def commit(self, operations, client=None, request_id=None):
        return (client or self.client).post('/api/documents/commit', headers=HEADERS,
            json={'operations': operations, 'requestId': request_id or secrets.token_hex(16)})

    def get(self, path, client=None):
        response = (client or self.client).post('/api/documents/get', headers=HEADERS, json={'path': self.path(path)})
        self.assertEqual(response.status_code, 200, response.json)
        return response.json['data']

    def seed(self):
        result = self.commit([
            self.operation('accounts/cash', {'name': 'Cash', 'balance': 100}),
            self.operation('accounts/holding', {'name': 'Titres', 'balance': 0, 'managedByInvestments': True}),
            self.operation('categories/expense', {'name': 'Courses', 'type': 'expense'}),
            self.operation('categories/income', {'name': 'Salaire', 'type': 'income'}),
            self.operation('investments/gold', {'name': 'Or', 'balance': 0, 'holdingAccountId': 'holding'}),
        ])
        self.assertEqual(result.status_code, 200, result.json)

    def test_authentication_and_cross_user_isolation(self):
        anonymous = app.test_client()
        self.assertEqual(anonymous.post('/api/documents/get', headers=HEADERS, json={'path': self.path('user')}).status_code, 401)
        self.assertEqual(self.other.post('/api/documents/get', headers=HEADERS, json={'path': self.path('user')}).status_code, 403)
        self.assertEqual(self.other.post('/api/documents/commit', headers=HEADERS, json={
            'requestId': secrets.token_hex(16), 'operations': [self.operation('user', {'firstName': 'Stolen'})],
        }).status_code, 403)
        self.assertEqual(self.get('user')['firstName'], 'Test')

    def test_csrf_and_unknown_collections(self):
        self.assertEqual(self.client.post('/api/auth/logout', json={}).status_code, 403)
        self.assertEqual(self.client.post('/api/auth/logout', headers={'Origin': 'https://example.test'}, json={}).status_code, 403)
        self.assertEqual(self.client.post('/api/auth/logout', headers={'X-MySold-Request': '1'}, json={}).status_code, 403)
        self.assertEqual(self.client.post('/api/auth/logout', headers={**HEADERS, 'Origin': 'https://evil.test'}, json={}).status_code, 403)
        self.assertEqual(self.commit([self.operation('../secrets', {})]).status_code, 400)

    def test_batch_rollback_insufficient_funds_and_idempotency(self):
        self.seed()
        operations = [self.operation('accounts/cash', {'balance': {'_op': 'increment', 'value': -150}}, 'update')]
        self.assertEqual(self.commit(operations).status_code, 409)
        self.assertEqual(self.get('accounts/cash')['balance'], 100)
        request_id = secrets.token_hex(16)
        operations[0]['data']['balance']['value'] = -29.14
        self.assertEqual(self.commit(operations, request_id=request_id).status_code, 200)
        self.assertEqual(self.commit(operations, request_id=request_id).status_code, 200)
        self.assertEqual(self.get('accounts/cash')['balance'], 70.86)

    def test_links_and_protected_deletion(self):
        self.seed()
        transaction = {'amount': 10, 'date': DATE, 'type': 'expense', 'fromAccountId': 'cash', 'categoryId': 'expense'}
        self.assertEqual(self.commit([self.operation('transactions/t1', transaction)]).status_code, 200)
        self.assertEqual(self.commit([self.operation('accounts/cash', action='delete')]).status_code, 409)
        self.assertEqual(self.commit([self.operation('categories/expense', action='delete')]).status_code, 409)
        transaction['fromAccountId'] = 'missing'
        self.assertEqual(self.commit([self.operation('transactions/t2', transaction)]).status_code, 400)
        self.assertIsNone(self.get('transactions/t2'))

    def test_investment_purchase_withdrawal_and_managed_balances(self):
        self.seed()
        result = self.commit([
            self.operation('accounts/cash', {'balance': {'_op': 'increment', 'value': -20}}, 'update'),
            self.operation('investments/gold', {'balance': {'_op': 'increment', 'value': 20}}, 'update'),
            self.operation('accounts/holding', {'balance': {'_op': 'increment', 'value': 20}}, 'update'),
            self.operation('transactions/buy', {'amount': 20, 'date': DATE, 'type': 'investment', 'fromAccountId': 'cash', 'toAccountId': 'holding', 'investmentId': 'gold'}),
        ])
        self.assertEqual(result.status_code, 200, result.json)
        self.assertEqual(self.get('accounts/holding')['balance'], 20)
        result = self.commit([
            self.operation('accounts/cash', {'balance': {'_op': 'increment', 'value': 5}}, 'update'),
            self.operation('investments/gold', {'balance': {'_op': 'increment', 'value': -5}}, 'update'),
            self.operation('accounts/holding', {'balance': {'_op': 'increment', 'value': -5}}, 'update'),
            self.operation('transactions/sell', {'amount': 5, 'date': DATE, 'type': 'transfer', 'fromAccountId': 'holding', 'toAccountId': 'cash', 'investmentId': 'gold'}),
        ])
        self.assertEqual(result.status_code, 200, result.json)
        self.assertEqual(self.get('accounts/cash')['balance'], 85)
        self.assertEqual(self.get('accounts/holding')['balance'], 15)
        result = self.commit([self.operation('accounts/holding', {'balance': 999}, 'update')])
        self.assertEqual(result.status_code, 200)
        self.assertEqual(self.get('accounts/holding')['balance'], 15)

    def test_import_paths_are_owned_by_destination_and_transactions_not_replayed(self):
        self.seed()
        # CSV restores opening/final balances and raw transactions separately.
        self.commit([self.operation('investments/gold', {'balance': 42.35}, 'update')])
        self.assertEqual(self.get('accounts/holding')['balance'], 42.35)
        tx = {'amount': 20, 'date': DATE, 'type': 'expense', 'fromAccountId': 'cash', 'categoryId': 'expense'}
        self.assertEqual(self.commit([self.operation('transactions/imported', tx)]).status_code, 200)
        self.assertEqual(self.get('accounts/cash')['balance'], 100)

    def test_date_filter_pagination_and_sql_injection(self):
        self.seed()
        operations = [self.operation('transactions/t' + str(i), {
            'amount': 1, 'date': DATE, 'type': 'income', 'fromAccountId': 'cash', 'categoryId': 'income',
        }) for i in range(512)]
        self.assertEqual(self.commit(operations[:500]).status_code, 200)
        self.assertEqual(self.commit(operations[500:]).status_code, 200)
        query = {'path': self.path('transactions'), 'filters': [{'field': 'date', 'op': 'gte', 'value': DATE}], 'order': 'date', 'limit': 3}
        response = self.client.post('/api/documents/query', headers=HEADERS, json=query)
        self.assertEqual(response.status_code, 200, response.json)
        self.assertEqual(len(response.json['documents']), 3)
        self.assertIsNone(response.json['cursor'])
        query['limit'] = None
        first = self.client.post('/api/documents/query', headers=HEADERS, json=query).json
        self.assertEqual(len(first['documents']), 500)
        query['cursor'] = first['cursor']
        second = self.client.post('/api/documents/query', headers=HEADERS, json=query).json
        self.assertEqual(len(second['documents']), 12)
        self.assertIsNone(second['cursor'])
        self.assertFalse({d['path'] for d in first['documents']} & {d['path'] for d in second['documents']})
        query['order'] = "date'); DROP TABLE users; --"
        self.assertEqual(self.client.post('/api/documents/query', headers=HEADERS, json=query).status_code, 400)
        self.assertIsNotNone(self.get('user'))

    def test_concurrent_debits_are_serialized(self):
        self.seed()
        cookie = self.client.get_cookie('mysold_session').value
        def debit(_):
            client = app.test_client()
            client.set_cookie('mysold_session', cookie)
            return self.commit([self.operation('accounts/cash', {'balance': {'_op': 'increment', 'value': -60}}, 'update')], client=client).status_code
        with ThreadPoolExecutor(max_workers=2) as executor:
            self.assertEqual(sorted(executor.map(debit, range(2))), [200, 409])
        self.assertEqual(self.get('accounts/cash')['balance'], 40)

    def test_delete_requires_password_and_cascades_all_data(self):
        self.seed()
        self.assertEqual(self.client.post('/api/auth/delete', json={}, headers=HEADERS).status_code, 403)
        response = self.client.post('/api/auth/reauthenticate', json={'password': PASSWORD}, headers=HEADERS)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.client.post('/api/auth/delete', json={}, headers=HEADERS).status_code, 200)
        with connect() as db:
            for table in ('users', 'sessions', 'documents'):
                column = 'id' if table == 'users' else 'user_id'
                self.assertEqual(db.execute(f'SELECT count(*) AS n FROM {table} WHERE {column}=%s', (self.uid,)).fetchone()['n'], 0)


if __name__ == '__main__':
    unittest.main()
