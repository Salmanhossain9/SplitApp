#!/usr/bin/env python3
"""Renders sample receipts, runs Tesseract on them and stores the line boxes as JSON.

The app reads receipts on the phone with Google ML Kit; its output is a list of text lines with
bounding boxes, the same shape Tesseract gives here. These fixtures let the receipt parser be
tested against real OCR output (misread characters, split rows) without a phone.

  python3 tool/ocr_fixtures/make_fixtures.py        needs: pillow, tesseract on PATH
"""
import csv, io, json, math, os, random, subprocess, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'apps', 'mobile', 'test', 'fixtures', 'ocr')
MONO = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
SANS = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

# (text, right-aligned amount or None, bold)
RECEIPTS = {
    'chillox': [
        ('CHILLOX', None, True), ('House 12, Road 5, Gulshan 1, Dhaka', None, False),
        ('Tel: 01711-123456', None, False), ('Date: 21/09/2026  21:04', None, False),
        ('Table 4        Bill No: 10492', None, False), ('', None, False),
        ('Chicken burger', '345.00', False), ('Beef kala bhuna', '1,145.00', False),
        ('Fries', '240.00', False), ('Coke x3', '270.00', False), ('', None, False),
        ('Sub Total', '2,000.00', False), ('VAT 5.9%', '118.00', False),
        ('Service Charge 5.9%', '118.00', False), ('', None, False),
        ('TOTAL', '2,236.00', True), ('Cash', '2,300.00', False), ('Change', '64.00', False),
        ('Thank you for dining with us!', None, False),
    ],
    'backyard': [
        ('THE BACKYARD', None, True), ('Mirpur 10, Dhaka', None, False), ('', None, False),
        ('No Description        Qty   Rate   Amount', None, False),
        ('1  Chicken Biryani      2   320.00   640.00', None, False),
        ('2  Beef Tehari          1   280.00   280.00', None, False),
        ('3  Borhani              3    60.00   180.00', None, False),
        ('4  Mineral Water 500ml  4    25.00   100.00', None, False), ('', None, False),
        ('Total Items: 4', None, False), ('Subtotal', '1,200.00', False),
        ('Service Charge (10%)', '120.00', False), ('VAT (15%)', '198.00', False),
        ('Grand Total', '1,518.00', True),
    ],
    'pizza': [
        ('Pizza Roma', None, True), ('Banani, Dhaka', None, False), ('', None, False),
        ('Margherita Pizza', 'Tk 950', False), ('Garlic Bread', 'Tk 220', False),
        ('Lemonade x2', 'Tk 300/-', False), ('', None, False), ('Total', 'Tk 1,470', True),
    ],
}

def render(rows, mono, seed, size=26, blur=0.6, rot=0.6, grain=90):
    rnd = random.Random(seed)
    font = ImageFont.truetype(MONO if mono else SANS, size)
    bold = ImageFont.truetype(BOLD, size + 4)
    w, line_h = 760, size + 18
    img = Image.new('L', (w, line_h * (len(rows) + 2)), 245)
    d = ImageDraw.Draw(img)
    y = line_h // 2
    for text, amount, is_bold in rows:
        f = bold if is_bold else font
        if is_bold and amount is None:
            tw = d.textlength(text, font=f); d.text(((w - tw) / 2, y), text, font=f, fill=20)
        else:
            d.text((40, y), text, font=f, fill=20)
            if amount:
                aw = d.textlength(amount, font=f); d.text((w - 40 - aw, y), amount, font=f, fill=20)
        y += line_h
    angle = rnd.uniform(-rot, rot)  # PIL turns counter-clockwise for positive angles
    img = img.rotate(angle, fillcolor=245, resample=Image.BICUBIC)
    img = img.filter(ImageFilter.GaussianBlur(blur))
    px = img.load()
    for _ in range(img.width * img.height // grain):  # a little grain
        x, yy = rnd.randrange(img.width), rnd.randrange(img.height)
        px[x, yy] = max(0, px[x, yy] - rnd.randrange(40))
    return img, -math.radians(angle)  # radians, positive = clockwise (what ML Kit's corner points give)

def ocr_lines(path, tilt):
    out = subprocess.run(['tesseract', path, 'stdout', '--psm', '6', 'tsv'], capture_output=True, text=True, check=True).stdout
    words = [r for r in csv.DictReader(io.StringIO(out), delimiter='\t', quoting=csv.QUOTE_NONE) if r['level'] == '5' and r['text'].strip()]
    lines = {}
    for r in words:
        lines.setdefault((r['block_num'], r['par_num'], r['line_num']), []).append(r)
    result, split = [], []
    for ws in lines.values():
        ws.sort(key=lambda r: int(r['left']))
        box = lambda g: dict(left=min(int(r['left']) for r in g), top=min(int(r['top']) for r in g),
                             right=max(int(r['left']) + int(r['width']) for r in g),
                             bottom=max(int(r['top']) + int(r['height']) for r in g))
        result.append(dict(text=' '.join(r['text'] for r in ws), angle=tilt, **box(ws)))
        # ML Kit often cuts a row at a wide gap (name | price); mimic that.
        group = [ws[0]]
        avg = sum(int(r['width']) / max(1, len(r['text'])) for r in ws) / len(ws)
        for prev, cur in zip(ws, ws[1:]):
            gap = int(cur['left']) - (int(prev['left']) + int(prev['width']))
            if gap > avg * 4:
                split.append(dict(text=' '.join(r['text'] for r in group), angle=tilt, **box(group))); group = []
            group.append(cur)
        split.append(dict(text=' '.join(r['text'] for r in group), angle=tilt, **box(group)))
    return result, split

os.makedirs(OUT, exist_ok=True)
# A phone photo is worse than a render: smaller text, blur, tilt, grain.
NOISY = {'chillox_noisy': 'chillox', 'backyard_noisy': 'backyard'}
for i, (name, rows) in enumerate(list(RECEIPTS.items()) + [(n, RECEIPTS[src]) for n, src in NOISY.items()]):
    mono = not name.startswith('pizza')
    if name in NOISY:
        img, tilt = render(rows, mono, seed=i + 1, size=17, blur=1.1, rot=2.0, grain=40)
    else:
        img, tilt = render(rows, mono, seed=i + 1)
    path = os.path.join(OUT, f'{name}.png'); img.save(path)
    whole, split = ocr_lines(path, tilt)
    json.dump({'lines': whole, 'split': split}, open(os.path.join(OUT, f'{name}.json'), 'w'), indent=1)
    print(name, len(whole), 'lines')
