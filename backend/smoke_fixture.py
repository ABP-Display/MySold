"""Create/remove disposable UI test data, only with explicit local opt-in."""
import argparse
import hashlib
import os
import secrets
from app import app, connect

if os.environ.get('MYSOLD_UI_TEST') != '1':
    raise SystemExit('Set MYSOLD_UI_TEST=1 for this local test fixture.')
parser = argparse.ArgumentParser()
parser.add_argument('--remove', metavar='USER_ID')
args = parser.parse_args()
if args.remove:
    with connect() as db:
        row = db.execute('SELECT email FROM users WHERE id=%s', (args.remove,)).fetchone()
        if not row or not row['email'].startswith('mysold-ui-') or not row['email'].endswith('@example.invalid'):
            raise SystemExit('Not a disposable UI test account.')
        db.execute('DELETE FROM users WHERE id=%s', (args.remove,))
    print('Disposable test account removed.')
else:
    email = 'mysold-ui-' + secrets.token_hex(4) + '@example.invalid'
    # Synthetic local test credentials, not an application default account.
    headers = {'X-MySold-Request': '1', 'Origin': os.environ['PUBLIC_ORIGIN']}
    client = app.test_client()
    result = client.post('/api/auth/register', headers=headers, json={
        'email': email, 'password': 'MySold-Test-123!', 'profile': {
            'firstName': 'Test temporaire', 'pin': hashlib.sha256(b'123456').hexdigest(),
            'currency': '€', 'currencyCode': 'EUR', 'language': 'Français',
            'languageCode': 'fr', 'theme': 'Sombre', 'reconnectionFrequency': 'never',
        },
    })
    if result.status_code != 200:
        raise SystemExit(str(result.json))
    uid = result.json['user']['uid']
    date = {'_type': 'timestamp', 'value': '2026-10-22T12:00:00.000Z'}
    docs = {
        'accounts/cash': {'name': 'Compte courant (test)', 'balance': 2000},
        'accounts/holding': {'name': 'Compte titres (test)', 'balance': 500, 'managedByInvestments': True},
        'categories/salary': {'name': 'Salaire', 'type': 'income', 'icon': 59007, 'color': 4283215696},
        'categories/shopping': {'name': 'Courses', 'type': 'expense', 'icon': 59005, 'color': 4294198070},
        'investments/gold': {'name': 'Or (test)', 'balance': 500, 'holdingAccountId': 'holding', 'type': 'other'},
        'transactions/salary': {'description': 'Salaire de test', 'type': 'income', 'amount': 3500, 'date': date, 'fromAccountId': 'cash', 'categoryId': 'salary'},
        'transactions/shopping': {'description': 'Achats de test', 'type': 'expense', 'amount': 1000, 'date': date, 'fromAccountId': 'cash', 'categoryId': 'shopping'},
        'transactions/buy': {'description': 'Investissement de test', 'type': 'investment', 'amount': 500, 'date': date, 'fromAccountId': 'cash', 'toAccountId': 'holding', 'investmentId': 'gold'},
    }
    response = client.post('/api/documents/commit', headers=headers, json={
        'requestId': secrets.token_hex(16),
        'operations': [{'action': 'set', 'path': 'users/' + uid + '/' + path, 'data': data} for path, data in docs.items()],
    })
    if response.status_code != 200:
        raise SystemExit(str(response.json))
    print('uid=' + uid)
    print('email=' + email)
