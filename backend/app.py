"""MySold same-origin API. No cloud credentials or external runtime service."""
import copy
import hashlib
import json
import logging
import os
import re
import secrets
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from functools import wraps
from pathlib import Path

import psycopg
from flask import Flask, g, jsonify, request
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from werkzeug.exceptions import HTTPException
from werkzeug.security import check_password_hash, generate_password_hash
from origin_policy import DEFAULT_APP_ORIGIN, is_allowed_origin
import totp

UTC = timezone.utc
COLLECTIONS = {'accounts', 'categories', 'investments', 'transactions', 'budgetAlerts'}
FIELDS = {'date', 'type', 'fromAccountId', 'toAccountId', 'holdingAccountId',
          'categoryId', 'investmentId', 'name', 'balance', 'amount', 'createdAt'}
PROFILE_FIELDS = {'firstName', 'lastName', 'phone', 'pin', 'theme', 'currency',
                  'currencyCode', 'language', 'languageCode', 'reconnectionFrequency',
                  'lockDelayMinutes', 'createdAt', 'lastConnection', 'updatedAt',
                  'hideAmounts', 'email', 'authProvider'}
app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 4 * 1024 * 1024


class Problem(Exception):
    def __init__(self, message, code='invalid-data', status=400):
        self.message, self.code, self.status = message, code, status


def connect():
    password_file = os.getenv('POSTGRES_PASSWORD_FILE')
    password = (Path(password_file).read_text().rstrip('\n') if password_file
                else os.environ['POSTGRES_PASSWORD'])
    return psycopg.connect(host=os.getenv('DB_HOST', 'db'),
                          dbname=os.getenv('POSTGRES_DB', 'mysold'),
                          user=os.getenv('POSTGRES_USER', 'mysold'),
                          password=password,
                          port=os.getenv('DB_PORT', '5432'), row_factory=dict_row,
                          options='-c statement_timeout=15000')


def migrate():
    with connect() as db:
        db.execute(Path(__file__).with_name('schema.sql').read_text())


def now():
    return datetime.now(UTC)


def timestamp():
    return {'_type': 'timestamp', 'value': now().isoformat(timespec='milliseconds').replace('+00:00', 'Z')}


def body():
    data = request.get_json()
    if not isinstance(data, dict):
        raise Problem('Un objet JSON est attendu.')
    return data


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


@app.errorhandler(Problem)
def problem(error):
    return jsonify(code=error.code, message=error.message), error.status


@app.errorhandler(HTTPException)
def http_problem(error):
    return jsonify(code='http-error', message=error.description), error.code


@app.errorhandler(Exception)
def unexpected(error):
    # No request bodies, credentials, or financial data in error logs.
    logging.error('Request failed: %s', type(error).__name__)
    return jsonify(code='server-error', message='Le serveur a rencontré une erreur.'), 500


@app.before_request
def require_application_header():
    if request.method in {'POST', 'PUT', 'PATCH', 'DELETE'}:
        if request.headers.get('X-MySold-Request') != '1':
            raise Problem('Requête refusée.', 'csrf', 403)
        if not is_allowed_origin(request.headers.get('Origin'),
                                 os.getenv('APP_ORIGIN', DEFAULT_APP_ORIGIN)):
            raise Problem('Origine refusée.', 'csrf', 403)


@app.after_request
def no_cache(response):
    response.headers['Cache-Control'] = 'no-store'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['Referrer-Policy'] = 'same-origin'
    return response


def session_user(db):
    token = request.cookies.get('mysold_session', '')
    if not token or len(token) > 128:
        return None
    return db.execute('''SELECT u.id, u.email, s.verified_at FROM sessions s
        JOIN users u ON u.id = s.user_id WHERE s.token_hash = %s AND s.expires_at > now()''',
                      (digest(token),)).fetchone()


def authenticated(function):
    @wraps(function)
    def wrapped(*args, **kwargs):
        with connect() as db:
            user = session_user(db)
            if not user:
                raise Problem('Veuillez vous reconnecter.', 'unauthorized', 401)
            g.db, g.user = db, user
            return function(*args, **kwargs)
    return wrapped


def cookie_response(user, db=None):
    token = secrets.token_urlsafe(32)
    def store(connection):
        connection.execute('DELETE FROM sessions WHERE expires_at < now()')
        connection.execute('INSERT INTO sessions(token_hash,user_id,expires_at) VALUES (%s,%s,%s)',
                   (digest(token), user['id'], now() + timedelta(days=7)))
    if db is None:
        with connect() as connection:
            store(connection)
    else:
        store(db)
    response = jsonify(user={'uid': user['id'], 'email': user['email']})
    response.set_cookie('mysold_session', token, httponly=True, samesite='Strict',
                        secure=os.getenv('COOKIE_SECURE', 'true').lower() == 'true',
                        max_age=7 * 86400, path='/')
    return response


def rate_limit(key, maximum=15):
    with connect() as db:
        db.execute('DELETE FROM rate_limits WHERE expires_at < now()')
        row = db.execute('''INSERT INTO rate_limits(key,count,expires_at)
            VALUES (%s,1,now() + interval '15 minutes') ON CONFLICT (key)
            DO UPDATE SET count=rate_limits.count+1 RETURNING count''', (digest(key),)).fetchone()
    if row['count'] > maximum:
        raise Problem('Trop de tentatives. Réessayez dans 15 minutes.', 'rate-limited', 429)


def credentials(data):
    email, password = data.get('email', ''), data.get('password', '')
    if not isinstance(email, str) or not isinstance(password, str):
        raise Problem('Identifiants invalides.')
    email = email.strip().lower()
    if len(email) > 254 or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email):
        raise Problem('Adresse e-mail invalide.')
    if not 8 <= len(password) <= 256:
        raise Problem('Le mot de passe doit contenir de 8 à 256 caractères.')
    return email, password


@app.get('/api/health')
def health():
    with connect() as db:
        db.execute('SELECT 1')
    return jsonify(status='ok')


@app.get('/api/auth/session')
def session():
    with connect() as db:
        user = session_user(db)
        return jsonify(user=None if not user else {'uid': user['id'], 'email': user['email']})


@app.post('/api/auth/register')
def register():
    if os.getenv('ALLOW_REGISTRATION', 'true').lower() != 'true':
        raise Problem('Les inscriptions sont fermées.', 'registration-closed', 403)
    data = body()
    email, password = credentials(data)
    rate_limit('register:' + request.headers.get('X-Real-IP', request.remote_addr), 10)
    profile = data.get('profile', {})
    if not isinstance(profile, dict):
        raise Problem('Profil invalide.')
    profile = {k: v for k, v in profile.items() if k in PROFILE_FIELDS}
    profile.update(email=email, authProvider='password', createdAt=timestamp(), lastConnection=timestamp())
    validate_document('user', profile)
    uid = secrets.token_hex(16)
    try:
        with connect() as db:
            db.execute('INSERT INTO users(id,email,password_hash) VALUES (%s,%s,%s)',
                       (uid, email, generate_password_hash(password, method='scrypt')))
            save(db, uid, 'user', profile)
    except psycopg.errors.UniqueViolation:
        raise Problem('Impossible de créer ce compte.', 'registration-failed', 409)
    return cookie_response({'id': uid, 'email': email})


# A fixed hash ensures nonexistent users also pay the password-check cost.
DUMMY_HASH = generate_password_hash(secrets.token_hex(24), method='scrypt')


@app.post('/api/auth/login')
def login():
    email, password = credentials(body())
    rate_limit('login-email:' + email)
    rate_limit('login-ip:' + request.headers.get('X-Real-IP', request.remote_addr), 100)
    with connect() as db:
        user = db.execute('SELECT * FROM users WHERE email=%s FOR UPDATE', (email,)).fetchone()
        valid = check_password_hash(user['password_hash'] if user else DUMMY_HASH, password)
        if not user or not valid:
            raise Problem('Adresse e-mail ou mot de passe incorrect.', 'invalid-credentials', 401)
        factor = db.execute('SELECT secret FROM mfa WHERE user_id=%s', (user['id'],)).fetchone()
        if factor and factor['secret']:
            challenge = secrets.token_urlsafe(32)
            db.execute('DELETE FROM mfa_challenges WHERE expires_at < now()')
            db.execute('INSERT INTO mfa_challenges(token_hash,user_id,expires_at) VALUES (%s,%s,%s)',
                       (digest(challenge), user['id'], now() + timedelta(minutes=5)))
            return jsonify(mfa_required=True, challenge=challenge)
        db.execute('''UPDATE documents SET data=jsonb_set(data,'{lastConnection}',%s)
                      WHERE user_id=%s AND path='user' ''', (Jsonb(timestamp()), user['id']))
        return cookie_response(user, db)


def consume_mfa_code(db, uid, factor, code):
    counter = totp.verify(factor['secret'], code, factor['last_counter'])
    if counter is not None:
        db.execute('UPDATE mfa SET last_counter=%s WHERE user_id=%s', (counter, uid))
        return True
    hashed = totp.recovery_hash(code)
    if hashed:
        return db.execute('DELETE FROM mfa_recovery WHERE user_id=%s AND code_hash=%s RETURNING code_hash',
                          (uid, hashed)).fetchone() is not None
    return False


@app.post('/api/auth/mfa/verify')
def mfa_verify():
    data = body()
    challenge, code = data.get('challenge'), data.get('code')
    if not isinstance(challenge, str) or not 32 <= len(challenge) <= 128:
        raise Problem('Vérification expirée. Recommencez la connexion.', 'mfa-expired', 401)
    rate_limit('mfa-ip:' + request.headers.get('X-Real-IP', request.remote_addr), 100)
    rate_limit('mfa-challenge:' + digest(challenge), 10)
    with connect() as db:
        user = db.execute('''SELECT u.id,u.email FROM users u JOIN mfa_challenges c ON c.user_id=u.id
            WHERE c.token_hash=%s AND c.expires_at > now() FOR UPDATE OF u''', (digest(challenge),)).fetchone()
        if not user:
            raise Problem('Vérification expirée. Recommencez la connexion.', 'mfa-expired', 401)
        rate_limit('mfa-user:' + user['id'], 15)
        pending = db.execute('SELECT token_hash FROM mfa_challenges WHERE token_hash=%s AND expires_at > now() FOR UPDATE',
                             (digest(challenge),)).fetchone()
        factor = db.execute('SELECT * FROM mfa WHERE user_id=%s FOR UPDATE', (user['id'],)).fetchone()
        if not pending or not factor or not factor['secret'] or not consume_mfa_code(db, user['id'], factor, code):
            raise Problem('Code incorrect ou déjà utilisé.', 'invalid-mfa', 401)
        db.execute('DELETE FROM mfa_challenges WHERE user_id=%s', (user['id'],))
        db.execute('''UPDATE documents SET data=jsonb_set(data,'{lastConnection}',%s)
                      WHERE user_id=%s AND path='user' ''', (Jsonb(timestamp()), user['id']))
        return cookie_response(user, db)


def mfa_password(data):
    rate_limit('mfa-settings:' + g.user['id'], 15)
    password = data.get('password')
    user = g.db.execute('SELECT password_hash FROM users WHERE id=%s FOR UPDATE', (g.user['id'],)).fetchone()
    if not isinstance(password, str) or len(password) > 256 or not check_password_hash(user['password_hash'], password):
        raise Problem('Mot de passe incorrect.', 'invalid-credentials', 401)
    return g.db.execute('SELECT * FROM mfa WHERE user_id=%s FOR UPDATE', (g.user['id'],)).fetchone()


def revoke_other_sessions():
    g.db.execute('DELETE FROM sessions WHERE user_id=%s AND token_hash<>%s',
                 (g.user['id'], digest(request.cookies['mysold_session'])))
    g.db.execute('DELETE FROM mfa_challenges WHERE user_id=%s', (g.user['id'],))


def replace_recovery_codes():
    codes = totp.recovery_codes()
    g.db.execute('DELETE FROM mfa_recovery WHERE user_id=%s', (g.user['id'],))
    for code in codes:
        g.db.execute('INSERT INTO mfa_recovery(user_id,code_hash) VALUES (%s,%s)',
                     (g.user['id'], totp.recovery_hash(code)))
    return codes


@app.get('/api/auth/mfa')
@authenticated
def mfa_status():
    factor = g.db.execute('SELECT secret IS NOT NULL AS enabled FROM mfa WHERE user_id=%s', (g.user['id'],)).fetchone()
    count = g.db.execute('SELECT count(*) AS count FROM mfa_recovery WHERE user_id=%s', (g.user['id'],)).fetchone()
    return jsonify(enabled=bool(factor and factor['enabled']), recovery_remaining=count['count'])


@app.post('/api/auth/mfa/setup')
@authenticated
def mfa_setup():
    factor = mfa_password(body())
    if factor and factor['secret']:
        raise Problem('La double authentification est déjà activée.', status=409)
    secret = totp.new_secret()
    g.db.execute('''INSERT INTO mfa(user_id,pending_secret,pending_expires_at) VALUES (%s,%s,%s)
        ON CONFLICT(user_id) DO UPDATE SET pending_secret=excluded.pending_secret,pending_expires_at=excluded.pending_expires_at''',
        (g.user['id'], secret, now() + timedelta(minutes=10)))
    return jsonify(secret=secret, uri=totp.provisioning_uri(secret, g.user['email']))


@app.post('/api/auth/mfa/enable')
@authenticated
def mfa_enable():
    data = body()
    factor = mfa_password(data)
    if not factor or factor['secret'] or not factor['pending_secret'] or factor['pending_expires_at'] <= now():
        raise Problem('Configuration expirée. Recommencez l’activation.', status=409)
    counter = totp.verify(factor['pending_secret'], data.get('code'))
    if counter is None:
        raise Problem('Code incorrect. Vérifiez l’heure de votre appareil.', 'invalid-mfa', 401)
    g.db.execute('''UPDATE mfa SET secret=pending_secret,pending_secret=NULL,pending_expires_at=NULL,last_counter=%s
        WHERE user_id=%s''', (counter, g.user['id']))
    codes = replace_recovery_codes()
    revoke_other_sessions()
    return jsonify(ok=True, recovery_codes=codes)


@app.post('/api/auth/mfa/disable')
@authenticated
def mfa_disable():
    data = body()
    factor = mfa_password(data)
    if not factor or not factor['secret'] or not consume_mfa_code(g.db, g.user['id'], factor, data.get('code')):
        raise Problem('Code incorrect ou déjà utilisé.', 'invalid-mfa', 401)
    g.db.execute('DELETE FROM mfa WHERE user_id=%s', (g.user['id'],))
    revoke_other_sessions()
    return jsonify(ok=True)


@app.post('/api/auth/mfa/recovery')
@authenticated
def mfa_recovery():
    data = body()
    factor = mfa_password(data)
    if not factor or not factor['secret'] or not consume_mfa_code(g.db, g.user['id'], factor, data.get('code')):
        raise Problem('Code incorrect ou déjà utilisé.', 'invalid-mfa', 401)
    codes = replace_recovery_codes()
    revoke_other_sessions()
    return jsonify(recovery_codes=codes)


@app.post('/api/auth/logout')
def logout():
    with connect() as db:
        db.execute('DELETE FROM sessions WHERE token_hash=%s', (digest(request.cookies.get('mysold_session', '')),))
    response = jsonify(ok=True)
    response.delete_cookie('mysold_session', path='/')
    return response


@app.post('/api/auth/reauthenticate')
@authenticated
def reauthenticate():
    rate_limit('reauth:' + g.user['id'])
    password = body().get('password')
    if not isinstance(password, str) or len(password) > 256:
        raise Problem('Mot de passe invalide.', status=401)
    user = g.db.execute('SELECT password_hash FROM users WHERE id=%s', (g.user['id'],)).fetchone()
    if not check_password_hash(user['password_hash'], password):
        raise Problem('Mot de passe incorrect.', status=401)
    g.db.execute('UPDATE sessions SET verified_at=now() WHERE token_hash=%s',
                 (digest(request.cookies['mysold_session']),))
    return jsonify(ok=True)


@app.post('/api/auth/delete')
@authenticated
def delete_account():
    if not g.user['verified_at'] or now() - g.user['verified_at'] > timedelta(minutes=5):
        raise Problem('Confirmez votre mot de passe avant la suppression.', status=403)
    g.db.execute('DELETE FROM users WHERE id=%s', (g.user['id'],))
    response = jsonify(ok=True)
    response.delete_cookie('mysold_session', path='/')
    return response


def local_path(value, collection=False):
    if not isinstance(value, str) or len(value) > 512:
        raise Problem('Chemin invalide.')
    parts = value.split('/')
    if len(parts) < 2 or parts[:2] != ['users', g.user['id']]:
        raise Problem('Accès refusé.', 'forbidden', 403)
    if len(parts) == 2 and not collection:
        return 'user'
    if len(parts) != (3 if collection else 4) or parts[2] not in COLLECTIONS:
        raise Problem('Collection inconnue.')
    if any(not re.fullmatch(r'[\w-]{1,128}', p) for p in parts[2:]):
        raise Problem('Identifiant invalide.')
    return '/'.join(parts[2:])


def absolute(path):
    return 'users/' + g.user['id'] + ('' if path == 'user' else '/' + path)


def load(db, uid, path):
    row = db.execute('SELECT data FROM documents WHERE user_id=%s AND path=%s', (uid, path)).fetchone()
    return row['data'] if row else None


def save(db, uid, path, data):
    collection = path.split('/')[0] if path != 'user' else ''
    db.execute('''INSERT INTO documents(user_id,path,collection,data) VALUES (%s,%s,%s,%s)
        ON CONFLICT(user_id,path) DO UPDATE SET data=excluded.data''', (uid, path, collection, Jsonb(data)))


@app.post('/api/documents/get')
@authenticated
def get_document():
    return jsonify(data=load(g.db, g.user['id'], local_path(body().get('path'))))


@app.post('/api/documents/query')
@authenticated
def query_documents():
    data = body()
    collection = local_path(data.get('path'), collection=True)
    clauses, params = ['user_id=%s', 'collection=%s'], [g.user['id'], collection]
    filters = data.get('filters', [])
    if not isinstance(filters, list) or len(filters) > 10:
        raise Problem('Filtres invalides.')
    for item in filters:
        field, operator, value = item.get('field'), item.get('op'), item.get('value')
        if field not in FIELDS or operator not in {'eq', 'gte', 'lt'}:
            raise Problem('Filtre inconnu.')
        op = {'eq': '=', 'gte': '>=', 'lt': '<'}[operator]
        if isinstance(value, dict) and value.get('_type') == 'timestamp':
            expr = "data->%s->>'value'"
            value = parse_date(value['value']).isoformat(timespec='milliseconds').replace('+00:00', 'Z')
        else:
            expr = 'data->>%s'
            if isinstance(value, (dict, list)):
                raise Problem('Valeur de filtre invalide.')
            value = str(value).lower() if isinstance(value, bool) else str(value)
        clauses.append(f'{expr} {op} %s')
        params.extend([field, value])
    order = data.get('order')
    if order and order not in FIELDS:
        raise Problem('Tri inconnu.')
    direction = 'DESC' if data.get('descending') else 'ASC'
    ordering = 'path ASC'
    if order:
        expr = "data->%s->>'value'" if order in {'date', 'createdAt'} else 'data->>%s'
        ordering = f'{expr} {direction} NULLS LAST, path ASC'
        params.append(order)
    try:
        offset = int(data.get('cursor') or 0)
        maximum = data.get('limit')
        maximum = None if maximum is None else int(maximum)
    except (ValueError, TypeError):
        raise Problem('Pagination invalide.')
    if offset < 0 or (maximum is not None and maximum < 1):
        raise Problem('Pagination invalide.')
    count = 500 if maximum is None else min(500, max(0, maximum-offset))
    params.extend([count+1, offset])
    rows = g.db.execute('SELECT path,data FROM documents WHERE ' + ' AND '.join(clauses) +
                        ' ORDER BY ' + ordering + ' LIMIT %s OFFSET %s', params).fetchall()
    more = len(rows) > count and (maximum is None or offset+count < maximum)
    return jsonify(documents=[{'path': absolute(r['path']), 'data': r['data']} for r in rows[:count]],
                   cursor=str(offset+count) if more else None)


def parse_date(value):
    try:
        result = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if result.tzinfo is None:
            result = result.replace(tzinfo=UTC)
        return result.astimezone(UTC)
    except (ValueError, AttributeError, OverflowError):
        raise Problem('Date invalide.')


def money(value):
    try:
        if isinstance(value, bool):
            raise ValueError()
        number = Decimal(str(value))
        if not number.is_finite() or abs(number) > Decimal('1000000000000'):
            raise ValueError()
        return float(number.quantize(Decimal('.01'), rounding=ROUND_HALF_UP))
    except (ValueError, InvalidOperation):
        raise Problem('Montant invalide.')


def resolve(value, previous=None, depth=0):
    if depth > 20:
        raise Problem('Document trop imbriqué.')
    if isinstance(value, dict):
        if '_op' in value:
            if value['_op'] == 'serverTimestamp':
                return timestamp()
            if value['_op'] == 'increment':
                return money(Decimal(str(previous or 0)) + Decimal(str(money(value.get('value')))))
            raise Problem('Opération inconnue.')
        if value.get('_type') == 'timestamp':
            return {'_type': 'timestamp', 'value': parse_date(value.get('value')).isoformat(timespec='milliseconds').replace('+00:00', 'Z')}
        return {k: resolve(v, (previous or {}).get(k) if isinstance(previous, dict) else None, depth+1)
                for k, v in value.items()}
    if isinstance(value, list):
        return [resolve(v, depth=depth+1) for v in value]
    if isinstance(value, str) and len(value) > 20000:
        raise Problem('Texte trop long.')
    return value


def validate_document(path, data):
    if not isinstance(data, dict):
        raise Problem('Document invalide.')
    if len(json.dumps(data)) > 262144:
        raise Problem('Document trop volumineux.')
    collection = path.split('/')[0]
    for field in ('balance', 'amount'):
        if field in data:
            data[field] = money(data[field])
    if path == 'user':
        if not set(data).issubset(PROFILE_FIELDS):
            raise Problem('Champ de profil non autorisé.')
        if data.get('pin') is not None and not re.fullmatch(r'[a-fA-F0-9]{64}', str(data['pin'])):
            raise Problem('PIN invalide.')
    elif collection in {'accounts', 'categories', 'investments'}:
        if not isinstance(data.get('name'), str) or not data['name'].strip() or len(data['name']) > 200:
            raise Problem('Le nom doit contenir de 1 à 200 caractères.')
        if collection == 'categories' and data.get('type') not in {'expense', 'income'}:
            raise Problem('Type de catégorie invalide.')
    elif collection == 'transactions':
        if data.get('type') not in {'expense', 'income', 'investment', 'transfer'} or data.get('amount', 0) <= 0:
            raise Problem('Transaction invalide.')
        if not isinstance(data.get('date'), dict) or data['date'].get('_type') != 'timestamp':
            raise Problem('Date de transaction manquante.')
        if data.get('fromAccountId') and data.get('fromAccountId') == data.get('toAccountId'):
            raise Problem('Les comptes source et destination doivent être différents.')


def validate_links(db, uid, path, data):
    collection = path.split('/')[0]
    if collection == 'transactions':
        for field, target in (('fromAccountId', 'accounts'), ('toAccountId', 'accounts'),
                              ('categoryId', 'categories'), ('investmentId', 'investments')):
            value = data.get(field)
            if value and not load(db, uid, target + '/' + str(value)):
                raise Problem('Référence introuvable : ' + field)
        kind = data['type']
        if kind in {'expense', 'income'}:
            if not data.get('fromAccountId') or not data.get('categoryId'):
                raise Problem('Compte et catégorie requis.')
            category = load(db, uid, 'categories/' + data['categoryId'])
            account = load(db, uid, 'accounts/' + data['fromAccountId'])
            if category['type'] != kind or account.get('managedByInvestments'):
                raise Problem('Compte ou catégorie incompatible.')
        if kind == 'investment':
            inv = load(db, uid, 'investments/' + str(data.get('investmentId')))
            source = load(db, uid, 'accounts/' + str(data.get('fromAccountId')))
            if not inv or not source or source.get('managedByInvestments') or inv.get('holdingAccountId') != data.get('toAccountId'):
                raise Problem('Comptes de l’investissement invalides.')
        if kind == 'transfer':
            if not data.get('toAccountId') or not (data.get('fromAccountId') or data.get('investmentId')):
                raise Problem('Source et destination requises.')
            destination = load(db, uid, 'accounts/' + data['toAccountId'])
            source = load(db, uid, 'accounts/' + str(data.get('fromAccountId')))
            if destination.get('managedByInvestments') or (source and source.get('managedByInvestments') and not data.get('investmentId')):
                raise Problem('Utilisez un retrait d’actif pour ce compte.')
            if data.get('investmentId'):
                investment = load(db, uid, 'investments/' + data['investmentId'])
                if investment.get('holdingAccountId') != data.get('fromAccountId'):
                    raise Problem('Le compte source ne détient pas cet actif.')
    elif collection == 'investments':
        account = load(db, uid, 'accounts/' + str(data.get('holdingAccountId')))
        if not account or not account.get('managedByInvestments'):
            raise Problem('Un compte support géré par les investissements est requis.')
        if data.get('balance', 0) < 0:
            raise Problem('La valeur d’un actif ne peut pas être négative.')


@app.post('/api/documents/commit')
@authenticated
def commit():
    payload = body()
    operations, request_id = payload.get('operations'), payload.get('requestId')
    if not isinstance(operations, list) or not 1 <= len(operations) <= 500:
        raise Problem('Un lot doit contenir de 1 à 500 opérations.')
    if not isinstance(request_id, str) or not re.fullmatch('[a-f0-9]{32}', request_id):
        raise Problem('Identifiant de requête invalide.')
    db, uid = g.db, g.user['id']
    # Serialize writes for this user. All increments, links and balances are
    # checked inside the same database transaction, including concurrent tabs.
    db.execute('SELECT id FROM users WHERE id=%s FOR UPDATE', (uid,))
    if db.execute('SELECT 1 FROM requests WHERE user_id=%s AND id=%s', (uid, request_id)).fetchone():
        return jsonify(ok=True)
    touched, originals, investments_changed = {}, {}, False
    for operation in operations:
        if not isinstance(operation, dict):
            raise Problem('Opération invalide.')
        path = local_path(operation.get('path'))
        action = operation.get('action')
        old = load(db, uid, path)
        originals.setdefault(path, copy.deepcopy(old))
        if action == 'delete':
            if path == 'user':
                raise Problem('Utilisez la suppression de compte.', status=403)
            db.execute('DELETE FROM documents WHERE user_id=%s AND path=%s', (uid, path))
            touched[path] = None
        elif action in {'set', 'update'}:
            if action == 'update' and old is None:
                raise Problem('Document introuvable.', status=404)
            patch = operation.get('data')
            if not isinstance(patch, dict):
                raise Problem('Données invalides.')
            merged = copy.deepcopy(old or {}) if action == 'update' or operation.get('merge') else {}
            for key, value in patch.items():
                merged[key] = resolve(value, (old or {}).get(key))
            validate_document(path, merged)
            if path == 'user':
                merged['email'], merged['authProvider'] = g.user['email'], 'password'
            save(db, uid, path, merged)
            touched[path] = merged
        else:
            raise Problem('Action inconnue.')
        investments_changed |= path.startswith('investments/')
    for path, data in touched.items():
        if data is not None:
            validate_links(db, uid, path, data)
        elif path.split('/')[0] in {'accounts', 'categories', 'investments'}:
            fields = {'accounts': ['fromAccountId', 'toAccountId', 'holdingAccountId'],
                      'categories': ['categoryId'], 'investments': ['investmentId']}[path.split('/')[0]]
            for field in fields:
                if db.execute('SELECT 1 FROM documents WHERE user_id=%s AND data @> %s LIMIT 1',
                              (uid, Jsonb({field: path.split('/')[-1]}))).fetchone():
                    raise Problem('Cet élément est encore utilisé.', 'in-use', 409)
    # Managed account values always derive from holdings, including CSV imports.
    account_rows = db.execute("SELECT path,data FROM documents WHERE user_id=%s AND collection='accounts'", (uid,)).fetchall()
    for row in account_rows:
        path, account = row['path'], row['data']
        if account.get('managedByInvestments'):
            if investments_changed or path in touched:
                values = db.execute("SELECT data->>'balance' AS balance FROM documents WHERE user_id=%s AND collection='investments' AND data->>'holdingAccountId'=%s", (uid, path.split('/')[-1])).fetchall()
                account['balance'] = money(sum((Decimal(v['balance'] or '0') for v in values), Decimal(0)))
                save(db, uid, path, account)
        elif path in touched:
            previous = originals[path]
            # Explicit balance edits may represent an opening balance/overdraft;
            # transaction debits, represented as increments, must remain funded.
            debit = any(o.get('path') == absolute(path) and isinstance(o.get('data', {}).get('balance'), dict)
                        and o['data']['balance'].get('_op') == 'increment' for o in operations)
            if debit and account.get('balance', 0) < 0:
                raise Problem('Solde insuffisant.', 'insufficient-funds', 409)
            if previous and previous.get('managedByInvestments'):
                if db.execute("SELECT 1 FROM documents WHERE user_id=%s AND collection='investments' AND data->>'holdingAccountId'=%s LIMIT 1", (uid, path.split('/')[-1])).fetchone():
                    raise Problem('Ce compte détient encore des investissements.')
    db.execute("DELETE FROM requests WHERE user_id=%s AND created_at < now() - interval '7 days'", (uid,))
    db.execute('INSERT INTO requests(user_id,id) VALUES (%s,%s)', (uid, request_id))
    return jsonify(ok=True)


if __name__ == '__main__':
    migrate()
    app.run(host='127.0.0.1', port=8000)
