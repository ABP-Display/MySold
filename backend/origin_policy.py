"""Exact origin allowlist for browser requests that modify application data."""
from urllib.parse import urlsplit

DEFAULT_APP_ORIGIN = 'http://localhost:28085,https://mysold.ydoxide.fr'


def is_allowed_origin(origin, configured_origins):
    if not origin or origin == 'null':
        return False
    try:
        parsed = urlsplit(origin)
        if (parsed.scheme not in {'http', 'https'} or not parsed.hostname
                or parsed.username is not None or parsed.password is not None
                or parsed.path or parsed.query or parsed.fragment):
            return False
        # Accessing port also rejects malformed/out-of-range ports.
        parsed.port
    except ValueError:
        return False
    allowed = {value.strip().rstrip('/') for value in configured_origins.split(',')
               if value.strip()}
    return origin in allowed
