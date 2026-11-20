"""User-owned investment presentation settings, not financial balances."""
import re

DEFAULT_IDS = frozenset({'stock', 'etf', 'crypto', 'bond', 'other'})


def validate_categories(value):
    if not isinstance(value, list) or not 1 <= len(value) <= 40:
        raise ValueError('Prévoyez de 1 à 40 catégories d’investissement.')
    ids, names, result = set(), set(), []
    for row in value:
        if not isinstance(row, dict) or set(row) != {'id', 'name', 'color', 'icon'}:
            raise ValueError('Catégorie d’investissement invalide.')
        ident, name = row['id'], row['name']
        if not isinstance(ident, str) or (ident not in DEFAULT_IDS and not re.fullmatch('[a-f0-9]{32}', ident)):
            raise ValueError('Identifiant de catégorie invalide.')
        if not isinstance(name, str) or not name.strip() or len(name.strip()) > 60:
            raise ValueError('Le nom doit contenir de 1 à 60 caractères.')
        if ident in ids or name.strip().casefold() in names:
            raise ValueError('Cette catégorie existe déjà.')
        if type(row['color']) is not int or not 0xff000000 <= row['color'] <= 0xffffffff:
            raise ValueError('Couleur de catégorie invalide.')
        if type(row['icon']) is not int or not 0 <= row['icon'] <= 0x10ffff or 0xd800 <= row['icon'] <= 0xdfff:
            raise ValueError('Icône de catégorie invalide.')
        ids.add(ident)
        names.add(name.strip().casefold())
        result.append({**row, 'name': name.strip()})
    if 'other' not in ids:
        raise ValueError('La catégorie de secours doit être conservée.')
    return result


def category_ids(profile):
    value = (profile or {}).get('investmentCategories')
    return {row['id'] for row in value} if isinstance(value, list) else DEFAULT_IDS
