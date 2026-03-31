#!/usr/bin/env python3
import subprocess
import sys
import os

# Auto-setup venv if needed
script_dir = os.path.dirname(os.path.abspath(__file__))
venv_dir = os.path.join(script_dir, '.venv')
venv_python = os.path.join(venv_dir, 'bin', 'python3')

if not os.path.exists(venv_python):
    print("Setting up virtual environment...")
    subprocess.check_call([sys.executable, '-m', 'venv', venv_dir])
    subprocess.check_call([venv_python, '-m', 'pip', 'install', '-q', 'Pillow', 'cairosvg'])
    os.execv(venv_python, [venv_python] + sys.argv)
elif sys.executable != venv_python:
    os.execv(venv_python, [venv_python] + sys.argv)

from PIL import Image, ImageDraw
import cairosvg
from io import BytesIO

ICON_SIZE = 512
ICON_COLOR = '#FFFFFF'
BG_COLOR = (0, 0, 0, 255)
PADDING = 120

# Phosphor Regular SVG paths (viewBox 0 0 256 256)
ICONS = {
    'qr_icon_lightning': 'M215.79,118.17a8,8,0,0,0-5-5.66L153.18,90.9l14.66-73.33a8,8,0,0,0-13.69-7l-112,120a8,8,0,0,0,3,13l57.63,21.61L88.16,238.43a8,8,0,0,0,13.69,7l112-120A8,8,0,0,0,215.79,118.17ZM109.37,214l10.47-52.38a8,8,0,0,0-5-9.06L62,132.71l84.62-90.66L136.16,94.43a8,8,0,0,0,5,9.06l52.8,19.8Z',
    'qr_icon_onchain': 'M240,88.23a54.43,54.43,0,0,1-16,37L189.25,160a54.27,54.27,0,0,1-38.63,16h-.05A54.63,54.63,0,0,1,96,119.84a8,8,0,0,1,16,.45A38.62,38.62,0,0,0,150.58,160h0a38.39,38.39,0,0,0,27.31-11.31l34.75-34.75a38.63,38.63,0,0,0-54.63-54.63l-11,11A8,8,0,0,1,135.7,59l11-11A54.65,54.65,0,0,1,224,48,54.86,54.86,0,0,1,240,88.23ZM109,185.66l-11,11A38.41,38.41,0,0,1,70.6,208h0a38.63,38.63,0,0,1-27.29-65.94L78,107.31A38.63,38.63,0,0,1,144,135.71a8,8,0,0,0,16,.45A54.86,54.86,0,0,0,144,96a54.65,54.65,0,0,0-77.27,0L32,130.75A54.62,54.62,0,0,0,70.56,224h0a54.28,54.28,0,0,0,38.64-16l11-11A8,8,0,0,0,109,185.66Z',
    'qr_icon_ecash': 'M198.51,56.09C186.44,35.4,169.92,24,152,24H104C86.08,24,69.56,35.4,57.49,56.09,46.21,75.42,40,101,40,128s6.21,52.58,17.49,71.91C69.56,220.6,86.08,232,104,232h48c17.92,0,34.44-11.4,46.51-32.09C209.79,180.58,216,155,216,128S209.79,75.42,198.51,56.09ZM199.79,120h-32a152.78,152.78,0,0,0-9.68-48H188.7C194.82,85.38,198.86,102,199.79,120Zm-20.6-64H150.46a83.13,83.13,0,0,0-12-16H152C162,40,171.4,46,179.19,56ZM56,128c0-47.7,22-88,48-88s48,40.3,48,88-22,88-48,88S56,175.7,56,128Zm96,88H138.49a83.13,83.13,0,0,0,12-16h28.73C171.4,210,162,216,152,216Zm36.7-32H158.12a152.78,152.78,0,0,0,9.68-48h32C198.86,154,194.82,170.62,188.7,184Z',
}

SVG_TEMPLATE = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <path fill="{color}" d="{path}"/>
</svg>'''

for name, path_data in ICONS.items():
    svg_content = SVG_TEMPLATE.format(color=ICON_COLOR, path=path_data)

    inner_size = ICON_SIZE - (PADDING * 2)
    png_data = cairosvg.svg2png(
        bytestring=svg_content.encode(),
        output_width=inner_size,
        output_height=inner_size,
    )
    icon_img = Image.open(BytesIO(png_data)).convert('RGBA')

    # Center the icon
    bbox = icon_img.getbbox()
    if bbox:
        cropped = icon_img.crop(bbox)
        centered = Image.new('RGBA', (inner_size, inner_size), (0, 0, 0, 0))
        paste_x = (inner_size - cropped.width) // 2
        paste_y = (inner_size - cropped.height) // 2
        centered.paste(cropped, (paste_x, paste_y))
        icon_img = centered

    # Place on black circle background
    result = Image.new('RGBA', (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(result)
    circle_margin = 60
    draw.ellipse([circle_margin, circle_margin, ICON_SIZE - 1 - circle_margin, ICON_SIZE - 1 - circle_margin], fill=BG_COLOR)
    result.paste(icon_img, (PADDING, PADDING), icon_img)

    result.save(f'{name}.png')
    print(f"  {name}.png ({ICON_SIZE}x{ICON_SIZE})")
