# -*- coding: utf-8 -*-
"""校验 intro 面板贴图：引用存在 + 尺寸 1280x720。"""
import re, os, sys
from PIL import Image

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

src = open(r"data\intro_comic_panels.gd", encoding="utf-8").read()
paths = sorted(set(re.findall(r'res://(assets/intro/[^"]+\.png)', src)))
print(f"panels reference {len(paths)} textures:")
bad = 0
for p in paths:
    fp = p.replace("/", os.sep)
    if not os.path.exists(fp):
        print(f"  MISSING {p}")
        bad += 1
        continue
    im = Image.open(fp)
    ok = im.size == (1280, 720)
    if not ok:
        bad += 1
    print(f"  {'OK ' if ok else 'BAD'} {os.path.basename(fp):26s} {im.size}")

wp = r"assets\intro\wakeup_snowfield.png"
im = Image.open(wp)
ok = im.size == (1280, 720)
if not ok:
    bad += 1
print(f"  {'OK ' if ok else 'BAD'} wakeup_snowfield.png          {im.size}")
print("ALL OK" if bad == 0 else f"{bad} PROBLEMS")
sys.exit(0 if bad == 0 else 1)
