"""Public documents work without authentication, SQL, scripts or a cloud service."""
import os
from html.parser import HTMLParser
import unittest
from unittest.mock import patch
from xml.etree import ElementTree

from app import app
from public_site import PAGES

class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links, self.images, self.tags = [], [], []

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        self.tags.append((tag, values))
        if tag in {'a', 'link'} and values.get('href', '').startswith('/'):
            self.links.append(values['href'])
        if tag == 'img':
            self.images.append(values)


class PublicSiteTests(unittest.TestCase):
    def setUp(self):
        self.config = patch.dict(os.environ, {
            'APP_ORIGIN': 'https://mysold.ydoxide.fr', 'PUBLIC_SITE_URL': '',
            'PUBLIC_INDEXING': 'true', 'PUBLIC_OPERATOR_NAME': '',
            'PUBLIC_CONTACT_EMAIL': '', 'PUBLIC_CONTACT_URL': 'https://github.com/ABP-Display/MySold',
        })
        self.config.start()
        self.addCleanup(self.config.stop)
        sql = patch('app.connect', side_effect=AssertionError('Public pages must not access the DB'))
        self.connect = sql.start()
        self.addCleanup(sql.stop)
        self.client = app.test_client()

    def test_pages_have_real_html_metadata_and_no_cookies_or_scripts(self):
        for page, (path, _, _) in PAGES.items():
            with self.subTest(page=page):
                response = self.client.get(path)
                self.assertEqual(response.status_code, 200)
                self.assertNotIn('Set-Cookie', response.headers)
                self.assertEqual(response.headers['X-Robots-Tag'], 'index, follow')
                text = response.get_data(as_text=True)
                self.assertIn('href="https://mysold.ydoxide.fr' + path + '"', text)
                self.assertIn('property="og:image"', text)
                self.assertIn('name="description"', text)
                self.assertIn("default-src 'none'", response.headers['Content-Security-Policy'])
                parser = Links()
                parser.feed(text)
                self.assertEqual(sum(tag == 'h1' for tag, _ in parser.tags), 1)
                self.assertFalse(any(tag == 'script' for tag, _ in parser.tags))
                self.assertTrue(all('alt' in img and 'width' in img and 'height' in img for img in parser.images))
                for link in parser.links:
                    if link.startswith(('/site-assets/',)) or link.split('?')[0] in {p[0] for p in PAGES.values()}:
                        result = self.client.get(link)
                        self.assertEqual(result.status_code, 200, link)
                        self.assertNotIn('Set-Cookie', result.headers)
                        result.close()

    def test_assets_are_compressed_formats_and_not_private_documents(self):
        for view in ('expenses', 'income', 'monthly', 'year'):
            for suffix in ('', '-mobile'):
                filename = f'showcase-{view}{suffix}.webp'
                with self.subTest(filename=filename):
                    response = self.client.get('/site-assets/' + filename)
                    self.assertEqual(response.status_code, 200)
                    self.assertEqual(response.mimetype, 'image/webp')
                    self.assertLess(len(response.data), 150_000)
                    self.assertIn('max-age=3600', response.headers['Cache-Control'])
                    response.close()
        with self.client.get('/site-assets/showcase-share.jpg') as response:
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.mimetype, 'image/jpeg')
        self.assertEqual(self.client.get('/site-assets/preview.webp').status_code, 404)
        self.assertEqual(self.client.get('/site-assets/../../.env').status_code, 404)
        self.assertEqual(self.client.get('/site-assets/nonexistent.css').status_code, 404)

    def test_only_public_documents_enter_the_sitemap(self):
        response = self.client.get('/sitemap.xml')
        self.assertEqual(response.mimetype, 'application/xml')
        root = ElementTree.fromstring(response.data)
        urls = [n.text for n in root.iter('{http://www.sitemaps.org/schemas/sitemap/0.9}loc')]
        self.assertEqual(set(urls), {'https://mysold.ydoxide.fr' + p[0] for p in PAGES.values()})
        self.assertIn('https://mysold.ydoxide.fr/presentation', urls)
        self.assertNotIn('https://mysold.ydoxide.fr/', urls)
        self.assertNotIn('https://mysold.ydoxide.fr/index.html', urls)
        robots = self.client.get('/robots.txt').get_data(as_text=True)
        self.assertIn('Disallow: /api/', robots)
        self.assertIn('Sitemap: https://mysold.ydoxide.fr/sitemap.xml', robots)
        # Root must remain crawlable so its noindex directive can be read.
        self.assertNotIn('Disallow: /\n', robots)

    def test_untrusted_host_and_proxy_headers_cannot_poison_canonical_urls(self):
        response = self.client.get('/presentation', headers={
            'Host': 'attacker.example', 'X-Forwarded-Host': 'attacker.example',
            'X-Forwarded-Proto': 'http',
        })
        self.assertNotIn(b'attacker.example', response.data)
        self.assertIn(b'href="https://mysold.ydoxide.fr/presentation"', response.data)

    def test_local_private_and_invalid_configurations_do_not_advertise_indexing(self):
        for environment in (
            {'APP_ORIGIN': 'http://localhost:28086'},
            {'PUBLIC_INDEXING': 'false'},
            {'PUBLIC_SITE_URL': 'https://attacker.example'},
            {'PUBLIC_SITE_URL': 'https://mysold.ydoxide.fr?secret=value'},
            {'PUBLIC_SITE_URL': 'javascript:alert(1)'},
        ):
            with self.subTest(environment=environment), patch.dict(os.environ, environment):
                response = self.client.get('/presentation')
                self.assertIn('noindex', response.headers['X-Robots-Tag'])
                self.assertNotIn(b'javascript:', response.data)
                self.assertNotIn(b'attacker.example', response.data)
                self.assertNotIn(b'<loc>', self.client.get('/sitemap.xml').data)
                self.assertIn(b'Disallow: /\n', self.client.get('/robots.txt').data)

    def test_multiple_allowed_origins_prefer_https_and_explicit_valid_origin_wins(self):
        with patch.dict(os.environ, {'APP_ORIGIN': 'http://localhost:28085,https://mysold.ydoxide.fr'}):
            self.assertIn(b'href="https://mysold.ydoxide.fr/presentation"', self.client.get('/presentation').data)
        with patch.dict(os.environ, {'APP_ORIGIN': 'https://one.example,https://two.example',
                                    'PUBLIC_SITE_URL': 'https://two.example'}):
            self.assertIn(b'href="https://two.example/presentation"', self.client.get('/presentation').data)
            self.assertNotIn(b'<strong>ydoxide</strong>', self.client.get('/mentions-legales/').data)

    def test_operator_fields_are_escaped_and_contact_cannot_execute_script(self):
        with patch.dict(os.environ, {'PUBLIC_OPERATOR_NAME': '<script>alert(1)</script>',
                                    'PUBLIC_CONTACT_URL': 'javascript:alert(1)',
                                    'PUBLIC_CONTACT_EMAIL': 'bad@example.com\nInjected'}):
            response = self.client.get('/mentions-legales/')
            self.assertNotIn(b'<script>', response.data)
            self.assertIn(b'&lt;script&gt;', response.data)
            self.assertNotIn(b'javascript:', response.data)
            self.assertNotIn(b'mailto:', response.data)

    def test_unknown_pages_are_404_and_api_errors_stay_json(self):
        for path in ('/nothing-here', '/public-not-found'):
            response = self.client.get(path)
            self.assertEqual(response.status_code, 404)
            self.assertIn('noindex', response.headers['X-Robots-Tag'])
            self.assertIn('Page introuvable', response.get_data(as_text=True))
        response = self.client.get('/api/nothing-here')
        self.assertEqual(response.status_code, 404)
        self.assertTrue(response.is_json)
        self.assertEqual(response.headers['Cache-Control'], 'no-store')
        self.assertIn('noindex', response.headers['X-Robots-Tag'])

    def test_no_slash_does_not_redirect_https_visitors_to_internal_http(self):
        for path, _, _ in PAGES.values():
            response = self.client.get(path.rstrip('/'))
            self.assertEqual(response.status_code, 200)
            self.assertNotIn('Location', response.headers)

    def test_presentation_links_to_app_and_old_urls_redirect(self):
        response = self.client.get('/presentation')
        self.assertIn(b'href="/"', response.data)
        self.assertNotIn(b'flutter_bootstrap.js', response.data)
        for path in ('/decouvrir', '/decouvrir/', '/presentation/'):
            response = self.client.get(path)
            self.assertEqual(response.status_code, 301)
            self.assertEqual(response.headers['Location'], '/presentation')

    def test_presentation_and_legal_pages_ignore_the_session(self):
        self.client.set_cookie('mysold_session', 'a' * 43)
        self.assertEqual(self.client.get('/presentation').status_code, 200)
        self.assertEqual(self.client.get('/confidentialite/').status_code, 200)
        self.connect.assert_not_called()

    def test_session_cookie_and_technical_storage_are_described_honestly(self):
        response = self.client.get('/cookies/')
        self.assertIn(b'mysold_session', response.data)
        self.assertIn(b'HttpOnly', response.data)
        self.assertNotIn(b'analytics.js', response.data)
        self.assertIn(b'canal confidentiel', self.client.get('/mentions-legales/').data)
        self.assertIn(b'ydoxide', self.client.get('/mentions-legales/').data)


if __name__ == '__main__':
    unittest.main()
