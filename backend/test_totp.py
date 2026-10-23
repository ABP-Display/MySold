import unittest
from urllib.parse import parse_qs, urlsplit
import totp


class TotpTests(unittest.TestCase):
    SECRET = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'

    def test_rfc6238_sha1_vectors_truncated_to_six_digits(self):
        for at, code in [(59, '287082'), (1111111109, '081804'),
                         (1111111111, '050471'), (1234567890, '005924'),
                         (2000000000, '279037'), (20000000000, '353130')]:
            with self.subTest(at=at):
                self.assertEqual(totp.code_at(self.SECRET, at // 30), code)

    def test_time_window_and_replay(self):
        for counter in (9, 10, 11):
            code = totp.code_at(self.SECRET, counter)
            self.assertEqual(totp.verify(self.SECRET, code, at=300), counter)
            self.assertIsNone(totp.verify(self.SECRET, code, last_counter=counter, at=300))
        self.assertIsNone(totp.verify(self.SECRET, totp.code_at(self.SECRET, 8), at=300))

    def test_malformed_codes(self):
        for code in (None, 123456, '12345', '1234567', '１２３４５６', '123 456'):
            self.assertIsNone(totp.verify(self.SECRET, code, at=300))

    def test_secret_and_provisioning(self):
        secret = totp.new_secret()
        self.assertEqual(len(secret), 32)
        uri = totp.provisioning_uri(secret, 'user+test@example.test')
        parsed = urlsplit(uri)
        self.assertEqual(parsed.scheme, 'otpauth')
        self.assertEqual(parse_qs(parsed.query)['secret'], [secret])

    def test_recovery_codes_are_independent_high_entropy_values(self):
        codes = totp.recovery_codes()
        self.assertEqual(len(set(codes)), 10)
        for code in codes:
            self.assertEqual(len(code.replace('-', '')), 20)
            self.assertEqual(totp.recovery_hash(code), totp.recovery_hash(code.lower().replace('-', ' ')))
        self.assertIsNone(totp.recovery_hash('123456'))
