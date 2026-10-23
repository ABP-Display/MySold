"""Origin policy tests; no database or third-party packages required."""
import unittest

from origin_policy import DEFAULT_APP_ORIGIN, is_allowed_origin


class OriginPolicyTests(unittest.TestCase):
    def test_default_localhost_and_public_domain(self):
        for origin in ('http://localhost:28085', 'https://mysold.ydoxide.fr'):
            with self.subTest(origin=origin):
                self.assertTrue(is_allowed_origin(origin, DEFAULT_APP_ORIGIN))

    def test_custom_configuration_replaces_defaults(self):
        configured = 'https://finances.example.test'
        self.assertTrue(is_allowed_origin(configured, configured))
        self.assertFalse(is_allowed_origin('https://mysold.ydoxide.fr', configured))
        self.assertFalse(is_allowed_origin('http://localhost:28085', configured))

    def test_multiple_origins_whitespace_and_config_trailing_slash(self):
        configured = ' https://finances.example.test/ , http://192.168.1.20:28085 , '
        self.assertTrue(is_allowed_origin('https://finances.example.test', configured))
        self.assertTrue(is_allowed_origin('http://192.168.1.20:28085', configured))

    def test_scheme_port_and_hostname_must_match(self):
        for origin in ('http://mysold.ydoxide.fr', 'https://mysold.ydoxide.fr:444',
                       'http://localhost:8080', 'https://mysold.ydoxide.fr.evil.test',
                       'https://evil.test'):
            with self.subTest(origin=origin):
                self.assertFalse(is_allowed_origin(origin, DEFAULT_APP_ORIGIN))

    def test_missing_null_or_malformed_origin_is_rejected(self):
        for origin in (None, '', 'null', 'https://mysold.ydoxide.fr/path',
                       'https://mysold.ydoxide.fr?query', 'https://mysold.ydoxide.fr#hash',
                       'https://user@mysold.ydoxide.fr', 'https://[bad',
                       'https://mysold.ydoxide.fr:99999'):
            with self.subTest(origin=origin):
                self.assertFalse(is_allowed_origin(origin, DEFAULT_APP_ORIGIN))

    def test_empty_configuration_denies_requests(self):
        self.assertFalse(is_allowed_origin('http://localhost:28085', ' , '))

    def test_wildcards_do_not_allow_arbitrary_domains(self):
        self.assertFalse(is_allowed_origin('https://evil.test', '*'))


if __name__ == '__main__':
    unittest.main()
