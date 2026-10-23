"""RFC 6238 TOTP (SHA-1, six digits, 30 seconds), without external services."""
import base64
import hashlib
import hmac
import re
import secrets
import struct
import time
from urllib.parse import quote, urlencode


def new_secret():
    return base64.b32encode(secrets.token_bytes(20)).decode().rstrip('=')


def code_at(secret, counter):
    key = base64.b32decode(secret + '=' * (-len(secret) % 8))
    value = hmac.new(key, struct.pack('>Q', counter), hashlib.sha1).digest()
    offset = value[-1] & 15
    number = struct.unpack('>I', value[offset:offset + 4])[0] & 0x7fffffff
    return f'{number % 1000000:06d}'


def verify(secret, code, last_counter=-1, at=None):
    if not isinstance(code, str) or not re.fullmatch(r'[0-9]{6}', code):
        return None
    counter = int(time.time() if at is None else at) // 30
    for candidate in (counter, counter - 1, counter + 1):
        if candidate >= 0 and candidate > last_counter and hmac.compare_digest(code_at(secret, candidate), code):
            return candidate
    return None


def provisioning_uri(secret, email):
    return 'otpauth://totp/' + quote('MySold:' + email, safe='') + '?' + urlencode({
        'secret': secret, 'issuer': 'MySold', 'algorithm': 'SHA1', 'digits': 6, 'period': 30,
    })


def recovery_codes():
    codes = [secrets.token_hex(10).upper() for _ in range(10)]
    return ['-'.join(code[i:i + 5] for i in range(0, 20, 5)) for code in codes]


def recovery_hash(code):
    if not isinstance(code, str) or len(code) > 64:
        return None
    normalized = code.replace('-', '').replace(' ', '').upper()
    if not re.fullmatch(r'[0-9A-F]{20}', normalized):
        return None
    return hashlib.sha256(normalized.encode()).hexdigest()
