"""Create fictional chart data in the loopback-only test instance, never production."""
import hashlib
import http.cookiejar
import json
from datetime import datetime, timezone
import urllib.error
import urllib.request
import uuid

BASE = 'http://localhost:28086'
EMAIL, PASSWORD, PIN = 'demo@mysold.local', 'MySold-local-2026!', '123456'
jar = http.cookiejar.CookieJar()
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))


def request(path, data):
    req = urllib.request.Request(BASE + '/api/' + path, data=json.dumps(data).encode(),
        headers={'Origin': BASE, 'X-MySold-Request': '1', 'Content-Type': 'application/json'})
    with client.open(req, timeout=30) as response:
        return json.load(response)


def main():
    profile = dict(firstName='Démo', lastName='Locale', language='Français', languageCode='fr',
        currency='€', currencyCode='EUR', theme='Sombre', reconnectionFrequency='never',
        pin=hashlib.sha256(PIN.encode()).hexdigest())
    try:
        user = request('auth/register', dict(email=EMAIL, password=PASSWORD, profile=profile))['user']
    except urllib.error.HTTPError as error:
        if error.code != 409:
            raise
        user = request('auth/login', dict(email=EMAIL, password=PASSWORD))['user']
    uid = user['uid']
    operations = []

    def save(path, data):
        operations.append(dict(path='users/' + uid + '/' + path, action='set', data=data))

    for key, name, balance, managed in [
        ('current', 'Compte courant', 4250, False), ('savings', 'Livret A', 12800, False),
        ('reserve', 'Épargne de précaution', 3800, False), ('titles', 'Compte-titres', 4550, True),
    ]:
        save('accounts/local-' + key, dict(name=name, balance=balance, managedByInvestments=managed))
    expense = [
        ('food', 'Alimentation', 0xff81bbaa), ('home', 'Logement', 0xffb3a2d0),
        ('transport', 'Transports', 0xff88a9d3), ('leisure', 'Loisirs', 0xffcfb27c),
        ('health', 'Santé', 0xffc68d9f), ('bills', 'Énergie et abonnements', 0xff92a5ad),
        ('gifts', 'Cadeaux', 0xffb494be), ('other', 'Divers', 0xff9aaf88),
    ]
    incomes = [('salary', 'Salaire', 3200), ('freelance', 'Missions indépendantes', 450),
        ('refund', 'Remboursements', 177.5), ('dividend', 'Dividendes', 85),
        ('rental', 'Revenus locatifs', 600), ('gift', 'Cadeaux reçus', 75)]
    colors = [0xff81bbaa, 0xff88a9d3, 0xffb3a2d0, 0xffcfb27c, 0xffc68d9f, 0xff92a5ad]
    for key, name, color in expense:
        save('categories/local-' + key, dict(name=name, type='expense', color=color))
    for index, (key, name, _) in enumerate(incomes):
        save('categories/local-' + key, dict(name=name, type='income', color=colors[index]))
    for key, name, kind, balance in [('etf', 'ETF Monde', 'etf', 3200),
            ('stock', 'Actions européennes', 'stock', 850), ('crypto', 'Bitcoin', 'crypto', 500)]:
        save('investments/local-' + key, dict(name=name, investmentType=kind, balance=balance,
            holdingAccountId='local-titles'))
    now = datetime.now(timezone.utc)

    def transaction(key, kind, day, amount, description, **links):
        date = datetime(now.year, now.month, min(day, 28), 12, tzinfo=timezone.utc)
        save('transactions/local-' + key, dict(type=kind, amount=amount, description=description,
            date={'_type': 'timestamp', 'value': date.isoformat()}, **links))

    for i in range(28):
        key, name, _ = expense[i % len(expense)]
        amount = 790 if i == 1 else round(12.4 + (i * 17.31) % 110, 2)
        transaction('expense-' + str(i), 'expense', i + 1, amount, name,
            fromAccountId='local-current', categoryId='local-' + key)
    for i, (key, name, amount) in enumerate(incomes):
        transaction('income-' + str(i), 'income', 2 + i * 3, amount, name,
            fromAccountId='local-current', categoryId='local-' + key)
    for i, (day, amount) in enumerate([(1,80), (4,120), (8,50), (12,150), (15,90), (20,60), (24,100), (28,50)]):
        transaction('investment-' + str(i), 'investment', day, amount, 'Versement investissement',
            fromAccountId='local-current', toAccountId='local-titles',
            investmentId='local-' + ['etf','stock','crypto'][i % 3])
    for i, (day, target, amount) in enumerate([(2,'savings',200),(3,'reserve',75),
            (8,'savings',150),(10,'reserve',125),(15,'savings',300),(19,'reserve',100),
            (24,'savings',120),(28,'reserve',80)]):
        transaction('transfer-' + str(i), 'transfer', day, amount, 'Virement interne',
            fromAccountId='local-current', toAccountId='local-' + target)
    transaction('withdrawal', 'transfer', 14, 40, 'Retrait ETF', fromAccountId='local-titles',
        toAccountId='local-current', investmentId='local-etf')
    request('documents/commit', dict(requestId=uuid.uuid4().hex, operations=operations, restore=True))
    print('Local demo ready:', BASE)
    print('Email:', EMAIL, '| Password:', PASSWORD, '| PIN:', PIN)


if __name__ == '__main__':
    main()
