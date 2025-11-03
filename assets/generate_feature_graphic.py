#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont

# Configuration
WIDTH = 1024
HEIGHT = 500
BACKGROUND_COLOR = 'black'
TEXT_COLOR = 'white'

# Create feature graphic
img = Image.new('RGB', (WIDTH, HEIGHT), color=BACKGROUND_COLOR)
draw = ImageDraw.Draw(img)

# Font setup - use same font as icon for consistent ℂ
font_paths = [
    '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
    '/System/Library/Fonts/SFNSText.ttf',
]

font = None
for font_path in font_paths:
    try:
        font = ImageFont.truetype(font_path, 120)
        break
    except:
        continue

if font is None:
    font = ImageFont.load_default()

# Draw ℂ larger, then "onduit" at normal size
font_large = None
for font_path in font_paths:
    try:
        font_large = ImageFont.truetype(font_path, 160)
        break
    except:
        continue

# Calculate positions to center the combined text
c_text = "ℂ"
rest_text = "onduit"

c_bbox = draw.textbbox((0, 0), c_text, font=font_large)
rest_bbox = draw.textbbox((0, 0), rest_text, font=font)

c_width = c_bbox[2] - c_bbox[0]
rest_width = rest_bbox[2] - rest_bbox[0]
total_width = c_width + rest_width

start_x = (WIDTH - total_width) // 2

# Align baselines
c_height = c_bbox[3] - c_bbox[1]
rest_height = rest_bbox[3] - rest_bbox[1]
center_y = HEIGHT // 2

c_y = center_y - c_height // 2 - c_bbox[1]
rest_y = center_y - rest_height // 2 - rest_bbox[1]

draw.text((start_x - c_bbox[0], c_y), c_text, fill=TEXT_COLOR, font=font_large)
draw.text((start_x + c_width - rest_bbox[0], rest_y), rest_text, fill=TEXT_COLOR, font=font)

# Save
img.save('feature-graphic.png')
print(f"✓ Feature graphic saved as feature-graphic.png ({WIDTH}x{HEIGHT})")
