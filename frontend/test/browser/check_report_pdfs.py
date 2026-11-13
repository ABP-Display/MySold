"""Check synthetic reports emitted by report_chromium.cjs (requires pypdf)."""
from pathlib import Path
from pypdf import PdfReader

output = Path(__file__).resolve().parents[3] / 'test-results'
scenarios = ['month', 'year', 'empty', 'single', 'negative', 'january', 'february', 'long']
for language in ['fr', 'ja']:
    for scenario in scenarios:
        reader = PdfReader(output / f'report-{language}-{scenario}.pdf')
        text = '\n'.join(page.extract_text() for page in reader.pages)
        compact = ''.join(text.split())
        assert 0 < len(reader.pages) < 40, scenario
        assert ('予算概要' if language == 'ja' else 'Vuebudgétaire') in compact
        if language == 'ja':
            assert '取引件数' in compact
            assert '利用可能額' in compact
            assert 'Operations' not in text
        if scenario in ['january', 'february']:
            for index in range(180):
                assert f'CONTROLE-{index:03d}' in compact, (scenario, index)
        if scenario == 'long':
            assert 'DESCRIPTION-DEBUT' in compact and 'DESCRIPTION-FIN' in compact
        if scenario != 'empty':
            # User-entered synthetic French values must survive a Japanese export.
            assert 'Comptecourant' in compact
            assert 'Viequotidienne' in compact
        print(f'{language}/{scenario}: {len(reader.pages)} pages, content verified')
