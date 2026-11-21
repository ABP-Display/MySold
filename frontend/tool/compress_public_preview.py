"""Development only: compress a 1200x630 fictional demo capture; requires Pillow."""
from pathlib import Path
import sys
from PIL import Image

source, destination = (Path(value) for value in sys.argv[1:])
with Image.open(source) as image:
    if image.size != (1200, 630):
        raise ValueError('Expected a 1200x630 demo capture, not a user screenshot')
    image.convert('RGB').save(destination, 'WEBP', quality=86, method=6)
    image.convert('RGB').save(destination.with_suffix('.jpg'), 'JPEG', quality=86,
                              optimize=True, progressive=True, subsampling=0)
print(f'{destination.name}: {destination.stat().st_size} bytes')
