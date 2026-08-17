# -*- coding: utf-8 -*-
"""生成特效贴图蒙太奇审阅图（棋盘格显 alpha，红/黄/蓝框标注机器flag）"""
import os, json
from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SCAN = json.load(open(os.path.join(ROOT, "docs/effect_check_reports/vfx_audit_20260817/scan_result.json"), encoding="utf-8"))
OUT = os.path.join(ROOT, "docs", "effect_check_reports", "vfx_audit_20260817")
tex = sorted(SCAN["textures"], key=lambda t: t["rel"])

THUMB, COLS, ROWS = 150, 8, 4
PER = COLS * ROWS

def checker(size, a=8):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(0, size, a):
        for x in range(0, size, a):
            c = (70, 70, 70, 255) if ((x // a + y // a) % 2) else (110, 110, 110, 255)
            d.rectangle([x, y, x + a - 1, y + a - 1], fill=c)
    return img

for si in range(0, len(tex), PER):
    batch = tex[si:si + PER]
    CW, CH = THUMB + 8, THUMB + 26
    sheet = Image.new("RGB", (COLS * CW + 16, ROWS * CH + 30), (24, 24, 28))
    dr = ImageDraw.Draw(sheet)
    dirs = sorted({os.path.dirname(t["rel"]) for t in batch})
    dr.text((10, 6), f"sheet {si//PER+1}: {(' | '.join(dirs))[:110]}", fill=(220, 220, 120))
    for i, t in enumerate(batch):
        r, c = divmod(i, COLS)
        x0, y0 = 8 + c * CW, 26 + r * CH
        im = Image.open(os.path.join(ROOT, t["rel"])).convert("RGBA")
        im.thumbnail((THUMB, THUMB))
        bg = checker(THUMB + 4)
        bg.paste(im, ((THUMB + 4 - im.width) // 2, (THUMB + 4 - im.height) // 2), im)
        sheet.paste(bg.convert("RGB"), (x0, y0))
        # flag 边框: 红=corner/方框, 黄=hole>0.5%, 蓝=ring>8%出血, 绿=引用为none死资产
        flags = []
        if t["corner_alpha_max"] >= 10 or t["opaque_ratio"] > 0.95: flags.append((255, 60, 60))
        if t["hole_ratio"] and t["hole_ratio"] > 0.005: flags.append((255, 220, 40))
        if t["ring6_content_pct"] > 0.08: flags.append((70, 150, 255))
        if t["ref"] == "none": flags.append((60, 255, 120))
        for k, col in enumerate(flags):
            off = k * 2
            dr.rectangle([x0 - 1 - off, y0 - 1 - off, x0 + THUMB + 4 + off, y0 + THUMB + 4 + off], outline=col)
        bn = os.path.basename(t["rel"])
        label = bn[:26] + ("…" if len(bn) > 26 else "")
        dr.text((x0 + 2, y0 + THUMB + 7), label, fill=(200, 200, 200))
    p = os.path.join(OUT, f"montage_{si//PER+1:02d}.png")
    sheet.save(p)
    print("saved", p, f"({si//PER+1}/{(len(tex)+PER-1)//PER})", "flags:", sum(1 for t in batch if t['corner_alpha_max']>=10 or t['opaque_ratio']>0.95 or (t['hole_ratio'] and t['hole_ratio']>0.005) or t['ring6_content_pct']>0.08))
