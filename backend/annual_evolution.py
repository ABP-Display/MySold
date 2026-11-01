"""Annual references and bounded-memory reports. No timer or browser history scan."""
from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from zoneinfo import ZoneInfo

from psycopg.types.json import Jsonb


def amount(value):
    return Decimal(str(value or 0)).quantize(Decimal('.01'), rounding=ROUND_HALF_UP)


def reference(value):
    if isinstance(value, dict):
        value = value.get('path', '')
    return str(value).split('/')[-1] if value else None


def calculate(accounts, categories, investments, transactions, year, instant, zone):
    """Reconstruct first-use baselines; once saved they are never overwritten."""
    local = instant.astimezone(zone)
    start = datetime(year, 1, 1, tzinfo=zone)
    ending = min(datetime(year + 1, 1, 1, tzinfo=zone),
                 datetime(local.year, local.month, local.day, tzinfo=zone) + timedelta(days=1))
    starts = {key: amount(data.get('balance')) for key, data in accounts.items()}
    ends = dict(starts)
    category_starts, category_ends = {}, {}
    category_names = {f"{data['type']}:{key}": data.get('name', '')
                      for key, data in categories.items() if data.get('type') in {'income', 'expense'}}
    for tx in transactions:
        date = tx.get('date', {})
        date = datetime.fromisoformat(date['value'].replace('Z', '+00:00'))
        value, kind = amount(tx.get('amount')), tx.get('type')
        deltas = {}
        def add(key, delta):
            if key:
                deltas[key] = deltas.get(key, Decimal(0)) + delta
        if kind == 'income':
            add(reference(tx.get('fromAccountId')), value)
        elif kind == 'expense':
            add(reference(tx.get('fromAccountId')), -value)
        elif kind in {'transfer', 'investment'}:
            add(reference(tx.get('fromAccountId')), -value)
            destination = reference(tx.get('toAccountId'))
            if not destination and kind == 'investment':
                destination = reference(investments.get(reference(tx.get('investmentId')), {}).get('holdingAccountId'))
            add(destination, value)
        for key, delta in deltas.items():
            if key in starts:
                if date >= start:
                    starts[key] -= delta
                if date >= ending:
                    ends[key] -= delta
        if kind in {'income', 'expense'}:
            key = f"{kind}:{reference(tx.get('categoryId')) or ''}"
            category_names.setdefault(key, '')
            if date < start:
                category_starts[key] = category_starts.get(key, Decimal(0)) + value
            if date < ending:
                category_ends[key] = category_ends.get(key, Decimal(0)) + value
    return {
        'accounts': {key: {'name': data.get('name', ''), 'beginning': float(starts[key]),
                           'ending': float(ends[key])} for key, data in accounts.items()},
        'categories': {key: {'name': name, 'beginning': float(category_starts.get(key, 0)),
                              'ending': float(category_ends.get(key, 0))} for key, name in category_names.items()},
    }


def read_values(db, uid, year, instant, zone):
    refs = {}
    for collection in ('accounts', 'categories', 'investments'):
        rows = db.execute('SELECT path,data FROM documents WHERE user_id=%s AND collection=%s',
                          (uid, collection)).fetchall()
        refs[collection] = {row['path'].split('/')[-1]: row['data'] for row in rows}
    # A server-side cursor bounds memory, even for a large imported history.
    with db.cursor(name='annual_operations') as cursor:
        cursor.itersize = 500
        cursor.execute("SELECT data FROM documents WHERE user_id=%s AND collection='transactions'", (uid,))
        return calculate(refs['accounts'], refs['categories'], refs['investments'],
                         (row['data'] for row in cursor), year, instant, zone)


def snapshot(db, uid, year, instant, zone, tracking, values=None):
    existing = db.execute('SELECT data FROM annual_snapshots WHERE user_id=%s AND year=%s', (uid, year)).fetchone()
    if existing:
        return existing['data']
    values = values if values is not None else read_values(db, uid, year, instant, zone)
    boundary = datetime(year, 1, 1, tzinfo=zone)
    saved = {
        'source': 'rollover' if tracking['started_at'] < boundary else 'reconstructed',
        'timeZone': tracking['time_zone'],
        'accounts': {key: {'name': row['name'], 'value': row['beginning']} for key, row in values['accounts'].items()},
        'categories': {key: {'name': row['name'], 'value': row['beginning']} for key, row in values['categories'].items()},
    }
    db.execute('INSERT INTO annual_snapshots(user_id,year,data) VALUES (%s,%s,%s)', (uid, year, Jsonb(saved)))
    return saved


def before_financial_write(db, uid, instant):
    """Already under the user's write lock; rollover before the first mutation."""
    tracking = db.execute('SELECT * FROM annual_tracking WHERE user_id=%s', (uid,)).fetchone()
    if tracking:
        zone = ZoneInfo(tracking['time_zone'])
        fill_missing_years(db, uid, instant.astimezone(zone).year, instant, zone, tracking)


def fill_missing_years(db, uid, through_year, instant, zone, tracking):
    last = db.execute('SELECT max(year) AS year FROM annual_snapshots WHERE user_id=%s', (uid,)).fetchone()['year']
    first = max(tracking['started_at'].astimezone(zone).year, (last + 1) if last else through_year)
    # Usually empty, or one new year. Preserve inactive years before a later
    # manual adjustment can make their opening values impossible to recover.
    for year in range(first, through_year + 1):
        snapshot(db, uid, year, instant, zone, tracking)


def invalidate(db, uid):
    db.execute('UPDATE annual_tracking SET revision=revision+1 WHERE user_id=%s', (uid,))
    db.execute('DELETE FROM annual_report_cache WHERE user_id=%s', (uid,))


def report(db, uid, year, time_zone, instant):
    # Same lock as financial commits: snapshot, values and cache share one state.
    db.execute('SELECT id FROM users WHERE id=%s FOR UPDATE', (uid,))
    db.execute('INSERT INTO annual_tracking(user_id,time_zone) VALUES (%s,%s) ON CONFLICT DO NOTHING', (uid, time_zone))
    tracking = db.execute('SELECT * FROM annual_tracking WHERE user_id=%s', (uid,)).fetchone()
    zone = ZoneInfo(tracking['time_zone'])
    today = instant.astimezone(zone).date()
    if year > today.year:
        return {'year': year, 'asOf': today.isoformat(), 'future': True,
                'source': 'unavailable', 'timeZone': tracking['time_zone'], 'accounts': [], 'categories': []}
    cached = db.execute('SELECT data FROM annual_report_cache WHERE user_id=%s AND year=%s AND revision=%s AND as_of=%s',
                        (uid, year, tracking['revision'], today)).fetchone()
    if cached:
        return cached['data']
    fill_missing_years(db, uid, today.year - 1, instant, zone, tracking)
    values = read_values(db, uid, year, instant, zone)
    saved = snapshot(db, uid, year, instant, zone, tracking, values)
    closing = None
    if year < today.year:
        # The next opening reference is also the previous year's closing value.
        # Later manual adjustments must not rewrite a completed year.
        closing_values = {collection: {key: {**row, 'beginning': row['ending']}
                                      for key, row in values[collection].items()}
                          for collection in ('accounts', 'categories')}
        closing = snapshot(db, uid, year + 1, instant, zone, tracking, closing_values)
    result = {'year': year, 'asOf': min(today, datetime(year, 12, 31).date()).isoformat(),
              'future': False, 'source': saved['source'], 'timeZone': tracking['time_zone']}
    for collection in ('accounts', 'categories'):
        rows = []
        # Retain names and baselines for references deleted since January.
        ending_values = ({key: {'name': row['name'], 'ending': row['value']}
                          for key, row in closing[collection].items()} if closing else values[collection])
        for key in saved[collection].keys() | ending_values.keys():
            current = ending_values.get(key)
            initial = saved[collection].get(key, {})
            row = {'id': key, 'name': (current or {}).get('name') or initial.get('name', ''),
                   'beginning': initial.get('value', 0), 'ending': current['ending'] if current else 0}
            if collection == 'categories':
                row['type'] = key.split(':')[0]
            rows.append(row)
        result[collection] = sorted(rows, key=lambda row: (-abs(row['ending']), row['name']))
    db.execute('''INSERT INTO annual_report_cache(user_id,year,revision,as_of,data) VALUES (%s,%s,%s,%s,%s)
        ON CONFLICT(user_id,year) DO UPDATE SET revision=excluded.revision,as_of=excluded.as_of,data=excluded.data''',
               (uid, year, tracking['revision'], today, Jsonb(result)))
    return result
