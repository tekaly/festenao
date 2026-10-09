"""Contact sheets of the theme screenshots: every preset side by side.

    flutter test tool/screenshot_test.dart
    python3 -I tool/contact_sheet.py [.local/themes]

Writes `sheet_<light|dark>_<desktop|phone>_<page>.png` next to the shots and
an `index.html` that shows them, then every shot.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

PRESETS = [
    'festenao', 'basalte', 'arcade', 'obsidian', 'guinguette', 'nocturne',
    'violet', 'teal', 'coral', 'forest', 'ocean', 'graphite', 'lagon',
]
SHEETS = [
    ('desktop', 'overview', 4, 720),
    ('desktop', 'access', 4, 720),
    ('desktop', 'kit', 4, 720),
    ('phone', 'overview', 7, 280),
    ('phone', 'access', 7, 280),
]
LABEL = 44
GAP = 16


def font(size):
    for path in [
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
        '/usr/share/fonts/TTF/DejaVuSans-Bold.ttf',
    ]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def sheet(directory, mode, form, page, columns, width):
    shots = []
    for preset in PRESETS:
        path = os.path.join(directory, f'{preset}_{mode}_{form}_{page}.png')
        if os.path.exists(path):
            shots.append((preset, Image.open(path).convert('RGB')))
    if not shots:
        return None
    first = shots[0][1]
    height = round(first.height * width / first.width)
    rows = (len(shots) + columns - 1) // columns
    background = (243, 244, 246) if mode == 'light' else (17, 19, 24)
    ink = (22, 24, 29) if mode == 'light' else (238, 240, 243)
    canvas = Image.new(
        'RGB',
        (GAP + columns * (width + GAP), GAP + rows * (LABEL + height + GAP)),
        background,
    )
    draw = ImageDraw.Draw(canvas)
    label_font = font(24)
    for index, (preset, image) in enumerate(shots):
        x = GAP + (index % columns) * (width + GAP)
        y = GAP + (index // columns) * (LABEL + height + GAP)
        draw.text((x + 4, y + 8), preset, fill=ink, font=label_font)
        canvas.paste(image.resize((width, height), Image.LANCZOS), (x, y + LABEL))
    name = f'sheet_{mode}_{form}_{page}.png'
    canvas.save(os.path.join(directory, name), optimize=True)
    print('wrote', os.path.join(directory, name))
    return name


def main():
    directory = sys.argv[1] if len(sys.argv) > 1 else '.local/themes'
    names = []
    for mode in ['light', 'dark']:
        for form, page, columns, width in SHEETS:
            name = sheet(directory, mode, form, page, columns, width)
            if name:
                names.append(name)
    shots = sorted(
        f for f in os.listdir(directory)
        if f.endswith('.png') and not f.startswith('sheet_')
    )
    with open(os.path.join(directory, 'index.html'), 'w') as out:
        out.write('<!doctype html><meta charset="utf-8"><title>Festenao themes</title>')
        out.write('<style>body{font-family:sans-serif;background:#f3f4f6;margin:24px}'
                  'img{max-width:100%;border:1px solid #ccc;margin:8px 0}'
                  '.shots img{width:32%}</style>')
        out.write('<h1>Festenao themes</h1>')
        for name in names:
            out.write(f'<h2>{name[6:-4]}</h2><a href="{name}"><img src="{name}"></a>')
        out.write('<h2>Every shot</h2><div class="shots">')
        for name in shots:
            out.write(f'<a href="{name}" title="{name}"><img src="{name}"></a>')
        out.write('</div>')
    print('wrote', os.path.join(directory, 'index.html'))


main()
