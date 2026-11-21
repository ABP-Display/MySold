"""Compress public showcase captures of the local fixture account; requires Pillow."""
import argparse
from pathlib import Path

from PIL import Image


def compress(directory, destination):
    for view, height in (('expenses', 750), ('income', 750), ('monthly', 840), ('year', 840)):
        for suffix, size in (('', (1200, height)), ('-mobile', (390, 740))):
            source = directory / f'gallery-{view}{suffix}.png'
            target = destination / f'showcase-{view}{suffix}.webp'
            with Image.open(source) as image:
                if image.size != size:
                    raise ValueError(f'{source.name}: expected {size}, got {image.size}')
                rgb = image.convert('RGB')
                rgb.save(target, 'WEBP', quality=88, method=6)
                if view == 'expenses' and not suffix:
                    rgb.crop((0, 0, 1200, 630)).save(
                        destination / 'showcase-share.jpg', 'JPEG', quality=87,
                        optimize=True, progressive=True, subsampling=0)
            print(f'{target.name}: {target.stat().st_size} bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture_directory', type=Path)
    args = parser.parse_args()
    compress(args.capture_directory, Path(__file__).resolve().parents[2] / 'backend/public_assets')
