"""Local administration, run using docker compose exec api python manage.py."""
import argparse
import getpass
from app import connect, migrate
from werkzeug.security import generate_password_hash

parser = argparse.ArgumentParser()
commands = parser.add_subparsers(dest='command', required=True)
commands.add_parser('migrate')
reset = commands.add_parser('reset-password')
reset.add_argument('email')
args = parser.parse_args()
if args.command == 'migrate':
    migrate()
else:
    password = getpass.getpass('Nouveau mot de passe (8 caractères minimum) : ')
    confirmation = getpass.getpass('Confirmation : ')
    if password != confirmation or not 8 <= len(password) <= 256:
        raise SystemExit('Mot de passe invalide ou confirmation différente.')
    with connect() as db:
        user = db.execute('UPDATE users SET password_hash=%s WHERE email=%s RETURNING id',
                          (generate_password_hash(password, method='scrypt'), args.email.strip().lower())).fetchone()
        if not user:
            raise SystemExit('Compte introuvable.')
        db.execute('DELETE FROM sessions WHERE user_id=%s', (user['id'],))
    print('Mot de passe modifié. Les sessions existantes ont été fermées.')
