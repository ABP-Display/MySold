"""Deterministic annual projections. Monetary arithmetic stays in cents."""
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP


def cents(value):
    return int((Decimal(str(value or 0)) * 100).quantize(Decimal(1), rounding=ROUND_HALF_UP))


def effects(tx):
    amount, kind = cents(tx.get('amount')), tx.get('type')
    result = {}
    def add(collection, key, value):
        if key:
            path = collection + '/' + key
            result[path] = result.get(path, 0) + value
    source, target = tx.get('fromAccountId'), tx.get('toAccountId')
    if kind == 'income':
        add('accounts', source, amount)
    elif kind == 'expense':
        add('accounts', source, -amount)
    elif kind in {'investment', 'transfer'}:
        add('accounts', source, -amount)
        add('accounts', target, amount)
        add('investments', tx.get('investmentId'), amount if kind == 'investment' else -amount)
    return result


def date_of(data):
    return datetime.fromisoformat(data['date']['value'].replace('Z', '+00:00')).astimezone(timezone.utc)


def build_analysis(documents, year, now):
    start = datetime(year, 1, 1, tzinfo=timezone.utc)
    end = datetime(year + 1, 1, 1, tzinfo=timezone.utc)
    cutoff = min(now, end)
    try:
        previous_cutoff = cutoff.replace(year=cutoff.year - 1)
    except ValueError:
        previous_cutoff = cutoff.replace(year=cutoff.year - 1, day=28)
    entities = {p: d for p, d in documents.items() if p.split('/')[0] in {'accounts', 'investments', 'categories'}}
    movement = {p: [] for p in entities}
    flows = {p: [0] * 12 for p in entities}
    counts = {p: [0] * 12 for p in entities}
    previous = {p: 0 for p in entities}
    for path, tx in documents.items():
        collection = path.split('/')[0]
        if collection == 'transactions':
            date = date_of(tx)
            for entity, delta in effects(tx).items():
                if entity in movement:
                    movement[entity].append((date, delta))
                    if start <= date < cutoff:
                        flows[entity][date.month - 1] += delta
            category = 'categories/' + str(tx.get('categoryId'))
            if category in flows and start.replace(year=year-1) <= date < previous_cutoff:
                previous[category] += cents(tx['amount'])
            if category in flows and start <= date < cutoff:
                flows[category][date.month - 1] += cents(tx['amount'])
                counts[category][date.month - 1] += 1
        elif collection == 'balanceEvents':
            if tx.get('kind') == 'initial':
                continue
            entity = tx.get('entityPath')
            if entity in movement:
                movement[entity].append((date_of(tx), cents(tx['amount'])))
    references = {(d.get('entityPath'), d.get('year')): d for p, d in documents.items() if p.startswith('annualReferences/')}
    output = []
    for path, data in entities.items():
        kind = path.split('/')[0]
        monthly = flows[path]
        if kind == 'categories':
            opening, current, closing, estimated = None, sum(monthly), [], False
        else:
            ledger = movement[path]
            opening = cents(data.get('balance')) - sum(delta for date, delta in ledger if date >= start)
            reference = references.get((path, year))
            estimated = reference is None
            if reference is not None:
                opening = cents(reference['amount'])
            closing = [opening + sum(delta for date, delta in ledger if start <= date < min(datetime(year + (m == 12), m % 12 + 1, 1, tzinfo=timezone.utc), cutoff))
                       if datetime(year, m, 1, tzinfo=timezone.utc) < cutoff else None for m in range(1, 13)]
            current = cents(data.get('balance')) - sum(delta for date, delta in ledger if date >= cutoff)
        comparison = previous[path] if kind == 'categories' else opening
        delta = current - comparison if comparison is not None else None
        unexplained = 0 if kind == 'categories' else current - opening - sum(v for date, v in movement[path] if start <= date < cutoff)
        if unexplained:
            # An explicit reference must never fabricate a balancing movement.
            known = [i for i, v in enumerate(closing) if v is not None]
            closing = [None] * 12
            if known:
                closing[known[-1]] = current
        output.append(dict(path=path, name=data['name'], kind=kind, categoryType=data.get('type'),
            opening=None if opening is None else opening / 100, current=current / 100,
            delta=None if delta is None else delta / 100,
            percent=None if comparison is None or comparison <= 0 else round(delta / comparison * 100, 2),
            previous=previous[path] / 100 if kind == 'categories' else None,
            estimated=estimated, monthly=[v / 100 for v in monthly], counts=counts[path],
            netFlows=sum(monthly) / 100,
            valuationChange=None if opening is None else (current - opening - sum(monthly)) / 100,
            unexplained=unexplained / 100,
            closing=[None if v is None else v / 100 for v in closing]))
    return dict(year=year, asOf=cutoff.isoformat(), entities=output,
                investmentNotice='La variation de valeur inclut les versements et retraits ; ce n’est pas un rendement financier.')
