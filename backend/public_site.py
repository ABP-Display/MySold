"""Anonymous, server-rendered information. Never reads sessions or the database."""
import hashlib
import os
import re
from pathlib import Path
from urllib.parse import urlsplit
from xml.etree.ElementTree import Element, SubElement, tostring

from flask import Blueprint, Response, render_template, request
from origin_policy import is_allowed_origin

site = Blueprint('public_site', __name__, template_folder='templates',
                 static_folder='public_assets', static_url_path='/site-assets')
REPOSITORY = 'https://github.com/ABP-Display/MySold'
PAGES = {
    'discover': ('/decouvrir/', 'MySold : budget et patrimoine auto-hébergés',
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
CSS_VERSION = hashlib.sha256((Path(__file__).with_name('public_assets') / 'site.css').read_bytes()).hexdigest()[:12]


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


def public_page(page, status=200):
    context = site_context(page, status)
    response = Response(render_template('public/' + page + '.html', **context),
                        status=status, mimetype='text/html')
    response.headers['X-Robots-Tag'] = 'index, follow' if context['indexable'] else 'noindex, follow'
    return response


@site.get('/decouvrir/', strict_slashes=False)
def discover():
    return public_page('discover')


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
        "default-src 'none'; style-src 'self'; img-src 'self'; "
        "base-uri 'none'; form-action 'none'; frame-ancestors 'none'")
    if request.path.startswith('/site-assets/') and response.status_code == 200:
        response.headers['Cache-Control'] = 'public, max-age=3600'
    return response
