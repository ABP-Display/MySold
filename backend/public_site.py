"""Anonymous, server-rendered information. Never reads sessions or the database."""
import hashlib
import os
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit
from xml.etree.ElementTree import Element, SubElement, tostring

from flask import Blueprint, Response, abort, jsonify, redirect, render_template, request
from origin_policy import is_allowed_origin

site = Blueprint('public_site', __name__, template_folder='templates',
                 static_folder='public_assets', static_url_path='/site-assets')
REPOSITORY = 'https://github.com/ABP-Display/MySold'
PAGES = {
    'discover': ('/presentation', 'MySold : budget et patrimoine auto-hébergés',
                 'Gérez vos comptes, dépenses, revenus et investissements avec MySold. Une application web installable, auto-hébergée, sans connexion bancaire obligatoire.'),
    'privacy': ('/confidentialite/', 'Politique de confidentialité | MySold',
                'Données personnelles, sécurité, conservation, export et suppression sur cette instance MySold.'),
    'terms': ('/conditions/', 'Conditions générales d’utilisation | MySold',
              'Les conditions d’utilisation du service de gestion de finances personnelles MySold.'),
    'legal': ('/mentions-legales/', 'Mentions légales | MySold',
              'Informations sur l’exploitant de cette instance MySold et son hébergement.'),
    'cookies': ('/cookies/', 'Cookies et stockage local | MySold',
                'À quoi servent le cookie de session, les préférences locales et le cache PWA de MySold.'),
}
ASSETS = Path(__file__).with_name('public_assets')
SHOWCASE_SHARE = 'showcase-share.jpg'
LOCAL_PHONE_CAPTURES = {
    'expenses': 'mois-depenses.webp', 'income': 'mois-revenus.webp',
    'investments': 'mois-invest.webp', 'transfers': 'mois-transfert.webp',
    'monthly': 'stats-mensuelles.webp', 'year': 'stats-annuelles.webp',
}


def asset_version(filename):
    css = (ASSETS / filename).read_text(encoding='utf-8')
    return hashlib.sha256(css.encode('utf-8')).hexdigest()[:12]


CSS_VERSION = asset_version('site.css')
SHOWCASE_CSS_VERSION = asset_version('showcase.css')


def public_origin():
    allowed = os.getenv('APP_ORIGIN', '')
    explicit = os.getenv('PUBLIC_SITE_URL', '').strip().rstrip('/')
    candidates = [explicit] if explicit else [v.strip().rstrip('/') for v in allowed.split(',')]
    valid = [candidate for candidate in candidates if is_allowed_origin(candidate, allowed)]
    for candidate in valid:
        if urlsplit(candidate).scheme == 'https':
            return candidate
    if valid:
        return valid[0]
    # Never derive canonical URLs from untrusted Host or X-Forwarded-* headers.
    return None


def setting(name, default=''):
    return os.getenv(name, default).strip()[:2000]


def contact_url():
    value = setting('PUBLIC_CONTACT_URL', REPOSITORY)
    try:
        parts = urlsplit(value)
        if (parts.scheme == 'https' and parts.hostname and parts.username is None
                and parts.password is None and not parts.query):
            parts.port
            return value
    except ValueError:
        pass
    return REPOSITORY


def site_context(page, status=200):
    origin = public_origin()
    official = origin == 'https://mysold.ydoxide.fr'
    name = setting('PUBLIC_OPERATOR_NAME') or ('ydoxide' if official else '')
    email = setting('PUBLIC_CONTACT_EMAIL')
    if not re.fullmatch(r'[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+', email):
        email = ''
    path, title, description = PAGES.get(page, ('', 'Page introuvable | MySold',
                                               'Cette page MySold n’existe pas.'))
    indexable = (status == 200 and origin is not None
                 and urlsplit(origin).scheme == 'https'
                 and urlsplit(origin).hostname not in {'localhost', '127.0.0.1', '::1'}
                 and setting('PUBLIC_INDEXING', 'true').lower() == 'true')
    return dict(page=page, title=title, description=description, origin=origin,
                canonical=origin + path if origin and path else None,
                social_image=f'{origin}/site-assets/{SHOWCASE_SHARE}' if origin else None,
                indexable=indexable, repository=REPOSITORY, operator=name,
                contact_url=contact_url(), contact_email=email,
                operator_address=setting('PUBLIC_OPERATOR_ADDRESS'),
                hosting=setting('PUBLIC_HOSTING_NAME'),
                hosting_address=setting('PUBLIC_HOSTING_ADDRESS'),
                hosting_contact=setting('PUBLIC_HOSTING_CONTACT'),
                hosting_region=setting('PUBLIC_HOSTING_REGION'),
                log_retention=setting('PUBLIC_LOG_RETENTION'),
                backup_retention=setting('PUBLIC_BACKUP_RETENTION'),
                css_version=CSS_VERSION)


def public_page(page, status=200, **extra):
    context = site_context(page, status)
    response = Response(render_template('public/' + page + '.html', **context, **extra),
                        status=status, mimetype='text/html')
    response.headers['X-Robots-Tag'] = 'index, follow' if context['indexable'] else 'noindex, follow'
    return response


def local_capture_mode():
    origin = public_origin()
    return (os.getenv('MYSOLD_SHOWCASE_LOCAL_CAPTURES') == 'true' and origin
            and urlsplit(origin).hostname in {'localhost', '127.0.0.1', '::1'})


@site.before_request
def restrict_local_captures():
    if request.path.startswith('/site-assets/local-phone/') and not local_capture_mode():
        abort(404)


@site.get('/presentation')
def discover():
    local_preview = local_capture_mode() and all(
        (ASSETS / 'local-phone' / name).is_file() for name in LOCAL_PHONE_CAPTURES.values())
    return public_page('discover', home_url='/presentation', site_base='', asset_base='/site-assets',
                       stylesheet_url=f'/site-assets/showcase.css?v={SHOWCASE_CSS_VERSION}',
                       icon_url='/icons/Icon-192.png',
                       phone_captures=LOCAL_PHONE_CAPTURES if local_preview else {})


@site.get('/decouvrir/', strict_slashes=False)
@site.get('/presentation/')
def legacy_discover():
    return redirect('/presentation', code=301)


@site.get('/confidentialite/', strict_slashes=False)
def privacy():
    return public_page('privacy')


@site.get('/conditions/', strict_slashes=False)
def terms():
    return public_page('terms')


@site.get('/mentions-legales/', strict_slashes=False)
def legal():
    return public_page('legal')


@site.get('/cookies/', strict_slashes=False)
def cookies():
    return public_page('cookies')


class LegalArticle(HTMLParser):
    blocks = {'h2', 'p', 'dt', 'dd', 'li'}

    def __init__(self):
        super().__init__()
        self.article = False
        self.block = None
        self.parts = []
        self.paragraphs = []

    def handle_starttag(self, tag, attrs):
        if tag == 'article':
            self.article = True
        if self.article and tag in self.blocks:
            self.block = tag
            self.parts = []

    def handle_data(self, data):
        if self.block:
            self.parts.append(data)

    def handle_endtag(self, tag):
        if tag == self.block:
            text = ' '.join(''.join(self.parts).split())
            if text:
                self.paragraphs.append({'text': text, 'heading': tag in {'h2', 'dt'}})
            self.block = None
        if tag == 'article':
            self.article = False


@site.get('/api/legal/<page>')
def legal_document(page):
    if page not in {'terms', 'privacy', 'legal', 'cookies'}:
        abort(404)
    context = site_context(page)
    parser = LegalArticle()
    parser.feed(render_template('public/' + page + '.html', **context))
    return jsonify(paragraphs=parser.paragraphs)


@site.get('/public-not-found')
def not_found():
    return public_page('not_found', 404)


@site.get('/robots.txt')
def robots():
    origin = public_origin()
    text = ('User-agent: *\nAllow: /\nDisallow: /api/\n'
            '# Private application HTML carries noindex; robots.txt is not access control.\n')
    if site_context('discover')['indexable']:
        text += f'Sitemap: {origin}/sitemap.xml\n'
    else:
        text = 'User-agent: *\nDisallow: /\n'
    return Response(text, mimetype='text/plain')


@site.get('/sitemap.xml')
def sitemap():
    root = Element('urlset', xmlns='http://www.sitemaps.org/schemas/sitemap/0.9')
    if site_context('discover')['indexable']:
        for path, _, _ in PAGES.values():
            SubElement(SubElement(root, 'url'), 'loc').text = public_origin() + path
    return Response(tostring(root, encoding='utf-8', xml_declaration=True), mimetype='application/xml')


@site.after_request
def headers(response):
    response.headers['Content-Security-Policy'] = (
        "default-src 'none'; style-src 'self'; img-src 'self'; font-src 'self'; "
        "base-uri 'none'; form-action 'none'; frame-ancestors 'none'")
    if request.path.startswith('/site-assets/local-phone/'):
        response.headers['Cache-Control'] = 'private, no-store'
    elif request.path.startswith('/site-assets/') and response.status_code == 200:
        response.headers['Cache-Control'] = 'public, max-age=3600'
    return response
