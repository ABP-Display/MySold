"""Render the reference page for GitHub Pages from the live site's template."""
import argparse
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, select_autoescape

from public_site import ASSETS, PAGES, REPOSITORY, SHOWCASE_CSS_VERSION, SHOWCASE_SHARE

BACKEND = Path(__file__).resolve().parent
DOCS = BACKEND.parent / 'docs'
OFFICIAL = 'https://mysold.ydoxide.fr'
PAGES_URL = 'https://abp-display.github.io/MySold/'
SHOWCASE_ASSETS = ('showcase.css', SHOWCASE_SHARE, *(
    f'showcase-{view}{suffix}.webp'
    for view in ('expenses', 'income', 'monthly', 'year')
    for suffix in ('', '-mobile')
))


def generate(check=False):
    jinja = Environment(loader=FileSystemLoader(BACKEND / 'templates'),
                        autoescape=select_autoescape())
    path, title, description = PAGES['discover']
    html = jinja.get_template('public/discover.html').render(
        title=title, description=description, indexable=False,
        canonical=OFFICIAL + path, icon_url='./assets/icon.png',
        stylesheet_url=f'./assets/showcase.css?v={SHOWCASE_CSS_VERSION}', asset_base='./assets',
        site_base=OFFICIAL, home_url='./index.html', repository=REPOSITORY,
        social_image=PAGES_URL + 'assets/' + SHOWCASE_SHARE,
    )
    files = {DOCS / 'index.html': (html + '\n').encode('utf-8')}
    files.update({DOCS / 'assets' / name: (ASSETS / name).read_bytes()
                  for name in SHOWCASE_ASSETS})
    for target, content in files.items():
        if check:
            current = target.read_bytes() if target.is_file() else b''
            if target.suffix in {'.html', '.css'}:
                current = current.replace(b'\r\n', b'\n')
                content = content.replace(b'\r\n', b'\n')
            if current != content:
                raise SystemExit(f'Out of date: {target.relative_to(DOCS)}')
        else:
            target.write_bytes(content)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    generate(check=parser.parse_args().check)
