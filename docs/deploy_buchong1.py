#!/usr/bin/env python3
"""Process 补充1 images: remove white bg, resize to 512x512, deploy to card_icons."""

from PIL import Image, ImageChops
import os

source_dir = r"F:\godot fair duet\create\phase-war\assets\card_icons\补充1"
target_dir = r"F:\godot fair duet\create\phase-war\assets\card_icons"

def remove_white_bg(img):
    if img.mode == 'RGB':
        img = img.convert('RGBA')
    bg_sample = img.getpixel((img.size[0] // 2, 0))
    bg_img = Image.new('RGBA', img.size, bg_sample)
    diff = ImageChops.difference(img, bg_img)
    diff_gray = diff.convert('L')
    mask = diff_gray.point(lambda x: 255 if x > 30 else 0)
    orig_a = img.getchannel('A')
    new_alpha = mask
    if orig_a.getextrema()[0] < 255:
        new_alpha = ImageChops.lighter(mask, orig_a)
    r, g, b, _ = img.split()
    return Image.merge('RGBA', (r, g, b, new_alpha))

def process_and_deploy(filename):
    src_path = os.path.join(source_dir, filename)
    dst_path = os.path.join(target_dir, filename)
    
    img = Image.open(src_path)
    img = remove_white_bg(img)
    
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
        img.thumbnail((512, 512), Image.LANCZOS)
        canvas = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
        x = (512 - img.size[0]) // 2
        y = (512 - img.size[1]) // 2
        canvas.paste(img, (x, y), img)
        img = canvas
    
    img.save(dst_path, 'PNG')
    return img.size

files = sorted([f for f in os.listdir(source_dir) if f.endswith('.png') and not f.endswith('.import')])
print(f"Processing {len(files)} files from 补充1...")

ok = 0
fail = 0
for f in files:
    try:
        size = process_and_deploy(f)
        ok += 1
        print(f"  OK: {f} -> {size}")
    except Exception as e:
        fail += 1
        print(f"  FAIL: {f} - {e}")

print(f"\nDone: {ok} OK, {fail} failed")
