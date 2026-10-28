#!/usr/bin/env python3
"""Export the approved generated artwork to existing platform icon slots.

Requires Pillow. Resizes/encodes only; does not regenerate or redraw the artwork.
--check checks dimensions, opacity and exact pixels against the master.
"""

import argparse
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTER = Path('app/assets/branding/kairosstep-icon.png')


def targets(root):
    slots = {}
    for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                          ('xxhdpi', 144), ('xxxhdpi', 192)]:
        slots[Path(f'app/android/app/src/main/res/mipmap-{density}/ic_launcher.png')] = size
    for folder in [Path('app/ios/Runner/Assets.xcassets/AppIcon.appiconset'),
                   Path('app/macos/Runner/Assets.xcassets/AppIcon.appiconset')]:
        manifest = json.loads((root / folder / 'Contents.json').read_text())
        for item in manifest['images']:
            points = float(item['size'].split('x')[0])
            scale = float(item['scale'].removesuffix('x'))
            slots[folder / item['filename']] = round(points * scale)
    for name, size in [('favicon.png', 32), ('icons/Icon-192.png', 192),
                       ('icons/Icon-512.png', 512), ('icons/Icon-maskable-192.png', 192),
                       ('icons/Icon-maskable-512.png', 512)]:
        slots[Path('app/web') / name] = size
    return slots


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    root = args.root.resolve()
    with Image.open(root / MASTER) as master:
        if master.width != master.height or master.width < 1024:
            raise SystemExit('Master must be square and at least 1024px')
        if master.convert('RGBA').getextrema()[3] != (255, 255):
            raise SystemExit('Launcher artwork must be fully opaque')
        source = master.convert('RGB')
    slots = targets(root)
    for relative, size in slots.items():
        path = root / relative
        expected = source.resize((size, size), Image.Resampling.LANCZOS)
        if args.check:
            with Image.open(path) as actual:
                if actual.size != (size, size) or actual.convert('RGB').tobytes() != expected.tobytes():
                    raise SystemExit(f'Stale or invalid icon: {relative}')
                if actual.convert('RGBA').getextrema()[3] != (255, 255):
                    raise SystemExit(f'Nonopaque icon: {relative}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            expected.save(path, format='PNG', optimize=True)
    ico = root / 'app/windows/runner/resources/app_icon.ico'
    sizes = [(size, size) for size in (16, 24, 32, 48, 64, 128, 256)]
    if args.check:
        with Image.open(ico) as actual:
            if actual.format != 'ICO' or actual.ico.sizes() != set(sizes):
                raise SystemExit('Invalid Windows icon size set')
            # Match Pillow's ICO export: a 256px frame, then Lanczos thumbnails.
            for size in sizes:
                expected = source.resize((256, 256), Image.Resampling.LANCZOS)
                if size != (256, 256):
                    expected = expected.resize(size, Image.Resampling.LANCZOS)
                if actual.ico.getimage(size).convert('RGB').tobytes() != expected.tobytes():
                    raise SystemExit(f'Stale Windows icon frame: {size}')
    else:
        source.resize((256, 256), Image.Resampling.LANCZOS).save(
            ico, format='ICO', sizes=sizes, bitmap_format='png')
    print(f'{"PASS" if args.check else "Exported"}: {len(slots)} PNG slots and 1 Windows ICO')


if __name__ == '__main__':
    main()
