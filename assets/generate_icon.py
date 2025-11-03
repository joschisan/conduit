#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont

# Configuration
ICON_SIZE = 1024
BACKGROUND_COLOR = '#000000'  # Black background
TEXT_COLOR = 'white'
SYMBOL = 'ℂ'  # Complex numbers symbol
FONT_SIZE = 850

# Create app icon with black background
img = Image.new('RGB', (ICON_SIZE, ICON_SIZE), color=BACKGROUND_COLOR)
draw = ImageDraw.Draw(img)

# Create logo with transparent background for use in app
logo_img = Image.new('RGBA', (ICON_SIZE, ICON_SIZE), color=(0, 0, 0, 0))
logo_draw = ImageDraw.Draw(logo_img)

# Try to find a font that supports the ℂ character
font_paths = [
    '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    '/System/Library/Fonts/Helvetica.ttc',
    '/System/Library/Fonts/SFNSText.ttf',
]

font = None
for font_path in font_paths:
    try:
        font = ImageFont.truetype(font_path, FONT_SIZE)
        break
    except:
        continue

if font is None:
    print("Warning: Using default font, may not display ℂ correctly")
    font = ImageFont.load_default()

# Draw the symbol centered - account for bounding box offsets
bbox = draw.textbbox((0, 0), SYMBOL, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]

# Calculate position to truly center the visual bounds
x = (ICON_SIZE - text_width) / 2 - bbox[0]  # Subtract left offset
y = (ICON_SIZE - text_height) / 2 - bbox[1]  # Subtract top offset

draw.text((x, y), SYMBOL, fill=TEXT_COLOR, font=font)
logo_draw.text((x, y), SYMBOL, fill=TEXT_COLOR, font=font)

# Save the app icon and logo
img.save('icon.png')
logo_img.save('logo.png')
print(f"✓ Icon saved as icon.png ({ICON_SIZE}x{ICON_SIZE})")
print(f"  Background: {BACKGROUND_COLOR}")
print(f"  Symbol: {SYMBOL}")
print(f"✓ Logo saved as logo.png ({ICON_SIZE}x{ICON_SIZE}, transparent)")

