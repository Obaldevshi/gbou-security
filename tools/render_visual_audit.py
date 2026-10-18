"""Create a review contact sheet from synthetic emulator captures, not user data."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
folder = ROOT / 'artifacts/visual-audit/android'
paths = sorted(folder.glob('*.png'))
font = ImageFont.load_default()
for start in range(0, len(paths), 8):
    batch = paths[start:start + 8]
    canvas = Image.new('RGB', (960, 940), '#dae3ec')
    draw = ImageDraw.Draw(canvas)
    for index, path in enumerate(batch):
        picture = Image.open(path).convert('RGB')
        picture.thumbnail((232, 440))
        x, y = (index % 4) * 240 + 4, (index // 4) * 470 + 25
        canvas.paste(picture, (x, y))
        draw.text((x, y - 20), path.stem[:31], fill='black', font=font)
    canvas.save(folder.parent / f'contact-{start // 8 + 1}.jpg', quality=88)
print(f'{len(paths)} individual emulator captures; {(len(paths) + 7) // 8} review sheets')
