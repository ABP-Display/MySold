"""Generate static PDF faces from the bundled OFL Noto Sans JP variable font.

Development only: requires fonttools. The existing variable UI font is preserved.
"""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

fonts = Path(__file__).resolve().parents[1] / 'assets/fonts'
for weight, name in [(400, 'Regular'), (700, 'Bold')]:
    font = TTFont(fonts / 'NotoSansJP.ttf')
    if 'fvar' not in font:
        raise ValueError('Expected the bundled variable Noto Sans JP font')
    instance = instantiateVariableFont(font, {'wght': weight}, inplace=True)
    output = fonts / f'NotoSansJP-{name}.ttf'
    instance.save(output)
    print(f'{output.name}: {output.stat().st_size} bytes')
