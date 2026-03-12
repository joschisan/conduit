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

from PIL import Image
import cairosvg
from io import BytesIO

# Configuration
ICON_SIZE = 1024
BACKGROUND_COLOR = '#000000'  # Black background
ICON_COLOR = '#FFFFFF'  # White icon
PADDING = 180  # Padding around the icon

# SVG with the lightning bolt icon (Phosphor Icons)
SVG_TEMPLATE = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">
  <path fill="{color}" d="M215.79,118.17a8,8,0,0,0-5-5.66L153.18,90.9l14.66-73.33a8,8,0,0,0-13.69-7l-112,120a8,8,0,0,0,3,13l57.63,21.61L88.16,238.43a8,8,0,0,0,13.69,7l112-120A8,8,0,0,0,215.79,118.17ZM109.37,214l10.47-52.38a8,8,0,0,0-5-9.06L62,132.71l84.62-90.66L136.16,94.43a8,8,0,0,0,5,9.06l52.8,19.8Z"/>
</svg>'''

# Generate colored SVG
svg_content = SVG_TEMPLATE.format(color=ICON_COLOR)

# Render SVG to PNG at high resolution
icon_inner_size = ICON_SIZE - (PADDING * 2)
png_data = cairosvg.svg2png(bytestring=svg_content.encode(), output_width=icon_inner_size, output_height=icon_inner_size)
icon_img = Image.open(BytesIO(png_data)).convert('RGBA')

# Find the actual bounding box of non-transparent pixels and center
bbox = icon_img.getbbox()
if bbox:
    cropped = icon_img.crop(bbox)
    centered = Image.new('RGBA', (icon_inner_size, icon_inner_size), (0, 0, 0, 0))
    paste_x = (icon_inner_size - cropped.width) // 2
    paste_y = (icon_inner_size - cropped.height) // 2
    centered.paste(cropped, (paste_x, paste_y))
    icon_img = centered

# Create background
background = Image.new('RGB', (ICON_SIZE, ICON_SIZE), color=BACKGROUND_COLOR)

# Paste icon centered on background
offset = PADDING
background.paste(icon_img, (offset, offset), icon_img)

# Save the app icon (with black background)
background.save('icon.png')
print(f"✓ Icon saved as icon.png ({ICON_SIZE}x{ICON_SIZE})")
print(f"  Background: {BACKGROUND_COLOR}")
print(f"  Icon color: {ICON_COLOR}")

# Save the logo (transparent background, for in-app use)
icon_img.save('logo.png')
print(f"✓ Logo saved as logo.png ({icon_inner_size}x{icon_inner_size}, transparent)")

