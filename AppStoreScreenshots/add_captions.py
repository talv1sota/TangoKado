#!/usr/bin/env python3
"""
Add App Store-style captions to TangoKado screenshots.
Creates framed screenshots with caption text above a scaled-down device screenshot,
on a gradient background.

Output sizes:
  - iPhone 6.7": 1320x2868
  - iPad 13":    2064x2752
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

# Font
FONT_PATH = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
FONT_FALLBACK = "/System/Library/Fonts/SFNS.ttf"
CAPTION_COLOR = (255, 255, 255)

SHADOW_OFFSET = 15
SHADOW_BLUR = 30

SCREENSHOTS_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCREENSHOTS_DIR, "Captioned")

# --- iPhone 6.7" screenshots (1320x2868) ---
IPHONE_SCREENSHOTS = [
    {
        "file": "Simulator Screenshot - iPhone 17 Pro Max - 2026-03-19 at 14.26.22.png",
        "line1": "Learn the Most Common",
        "line2": "Words in 14 Languages",
        "bg_top": (88, 86, 214),
        "bg_bottom": (59, 130, 246),
    },
    {
        "file": "Simulator Screenshot - iPhone 17 Pro Max - 2026-03-19 at 13.55.22.png",
        "line1": "Study with Interactive",
        "line2": "Flashcards",
        "bg_top": (99, 102, 241),
        "bg_bottom": (129, 140, 248),
    },
    {
        "file": "Simulator Screenshot - iPhone 17 Pro Max - 2026-03-19 at 13.55.23.png",
        "line1": "Translations &",
        "line2": "Example Sentences",
        "bg_top": (37, 99, 235),
        "bg_bottom": (56, 189, 248),
    },
    {
        "file": "Simulator Screenshot - iPhone 17 Pro Max - 2026-03-19 at 13.58.50.png",
        "line1": "Test Yourself",
        "line2": "by Typing",
        "bg_top": (124, 58, 237),
        "bg_bottom": (99, 102, 241),
    },
    {
        "file": "Simulator Screenshot - iPhone 17 Pro Max - 2026-03-19 at 13.57.16.png",
        "line1": "Instant Feedback",
        "line2": "on Every Answer",
        "bg_top": (34, 197, 94),
        "bg_bottom": (16, 185, 129),
    },
    {
        "file": "Simulator Screenshot - iPhone 17 Pro Max - 2026-03-19 at 14.29.48.png",
        "line1": "Track Your",
        "line2": "Progress",
        "bg_top": (88, 86, 214),
        "bg_bottom": (168, 85, 247),
    },
    {
        "file": "Simulator Screenshot - iPhone 17 Pro Max - 2026-03-19 at 14.27.50.png",
        "line1": "Beautiful Light",
        "line2": "& Dark Mode",
        "bg_top": (30, 30, 46),
        "bg_bottom": (55, 48, 107),
    },
]

# --- iPad 13" screenshots (2064x2752) ---
IPAD_SCREENSHOTS = [
    {
        "file": "Simulator Screenshot - iPad (A16) - 2026-03-19 at 14.32.52.png",
        "line1": "Learn the Most Common",
        "line2": "Words in 14 Languages",
        "bg_top": (88, 86, 214),
        "bg_bottom": (59, 130, 246),
    },
    {
        "file": "Simulator Screenshot - iPad (A16) - 2026-03-19 at 14.32.55.png",
        "line1": "Track Your",
        "line2": "Progress",
        "bg_top": (88, 86, 214),
        "bg_bottom": (168, 85, 247),
    },
]


def create_gradient_fast(width, height, top_color, bottom_color):
    """Create a vertical gradient image."""
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)
    for y in range(height):
        ratio = y / height
        r = int(top_color[0] * (1 - ratio) + bottom_color[0] * ratio)
        g = int(top_color[1] * (1 - ratio) + bottom_color[1] * ratio)
        b = int(top_color[2] * (1 - ratio) + bottom_color[2] * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    return img


def round_corners(img, radius):
    """Apply rounded corners to an image."""
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (img.size[0] - 1, img.size[1] - 1)], radius, fill=255)
    result = img.copy()
    result.putalpha(mask)
    return result


def load_font(size):
    """Load font with fallback."""
    try:
        return ImageFont.truetype(FONT_PATH, size)
    except OSError:
        return ImageFont.truetype(FONT_FALLBACK, size)


def create_captioned_screenshot(config, index, output_w, output_h, font_size, caption_h, phone_top, side_margin, corner_radius, prefix):
    """Create a single captioned screenshot."""
    # Create gradient background
    bg = create_gradient_fast(output_w, output_h, config["bg_top"], config["bg_bottom"])
    bg = bg.convert("RGBA")

    # Load and scale the screenshot
    screenshot_path = os.path.join(SCREENSHOTS_DIR, config["file"])
    screenshot = Image.open(screenshot_path).convert("RGBA")

    # Scale screenshot to fit within the frame area
    available_w = output_w - (side_margin * 2)
    available_h = output_h - phone_top - 60

    scale = min(available_w / screenshot.width, available_h / screenshot.height)
    new_w = int(screenshot.width * scale)
    new_h = int(screenshot.height * scale)
    screenshot = screenshot.resize((new_w, new_h), Image.LANCZOS)

    # Round the corners
    screenshot = round_corners(screenshot, corner_radius)

    # Center horizontally
    x_offset = (output_w - new_w) // 2
    y_offset = phone_top

    # Create shadow
    shadow_img = Image.new("RGBA", (new_w, new_h), (0, 0, 0, 0))
    shadow_mask = Image.new("L", (new_w, new_h), 0)
    shadow_draw = ImageDraw.Draw(shadow_mask)
    shadow_draw.rounded_rectangle(
        [(0, 0), (new_w - 1, new_h - 1)], corner_radius, fill=100
    )
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(SHADOW_BLUR))
    shadow_img.putalpha(shadow_mask)
    bg.paste(shadow_img, (x_offset + SHADOW_OFFSET, y_offset + SHADOW_OFFSET), shadow_img)

    # Paste screenshot onto background
    bg.paste(screenshot, (x_offset, y_offset), screenshot)

    # Add caption text
    draw = ImageDraw.Draw(bg)
    font = load_font(font_size)

    bbox1 = draw.textbbox((0, 0), config["line1"], font=font)
    text1_w = bbox1[2] - bbox1[0]
    text1_h = bbox1[3] - bbox1[1]

    bbox2 = draw.textbbox((0, 0), config["line2"], font=font)
    text2_w = bbox2[2] - bbox2[0]
    text2_h = bbox2[3] - bbox2[1]

    total_text_h = text1_h + 20 + text2_h
    text_y_start = (caption_h - total_text_h) // 2 + 30

    draw.text(
        ((output_w - text1_w) // 2, text_y_start),
        config["line1"],
        fill=CAPTION_COLOR,
        font=font,
    )
    draw.text(
        ((output_w - text2_w) // 2, text_y_start + text1_h + 20),
        config["line2"],
        fill=CAPTION_COLOR,
        font=font,
    )

    # Save
    output_filename = f"{prefix}{index + 1:02d}_{config['line1'].replace(' ', '_')}.png"
    output_path = os.path.join(OUTPUT_DIR, output_filename)
    bg.convert("RGB").save(output_path, "PNG", quality=95)
    print(f"  Created: {output_filename}")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # iPhone 6.7" (1320x2868)
    print(f"Creating {len(IPHONE_SCREENSHOTS)} iPhone captioned screenshots...\n")
    for i, config in enumerate(IPHONE_SCREENSHOTS):
        path = os.path.join(SCREENSHOTS_DIR, config["file"])
        if not os.path.exists(path):
            print(f"  MISSING: {config['file']}")
            continue
        create_captioned_screenshot(
            config, i,
            output_w=1320, output_h=2868,
            font_size=82, caption_h=520, phone_top=540,
            side_margin=80, corner_radius=60,
            prefix="iPhone_",
        )

    # iPad 13" (2064x2752)
    print(f"\nCreating {len(IPAD_SCREENSHOTS)} iPad captioned screenshots...\n")
    for i, config in enumerate(IPAD_SCREENSHOTS):
        path = os.path.join(SCREENSHOTS_DIR, config["file"])
        if not os.path.exists(path):
            print(f"  MISSING: {config['file']}")
            continue
        create_captioned_screenshot(
            config, i,
            output_w=2064, output_h=2752,
            font_size=90, caption_h=460, phone_top=480,
            side_margin=120, corner_radius=40,
            prefix="iPad_",
        )

    print(f"\nDone! Captioned screenshots saved to: {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
