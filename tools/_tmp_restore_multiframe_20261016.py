# -*- coding: utf-8 -*-
"""批量恢复多帧 attack(2026-10-16,交接文档 §五):4 格布置 → 旧多帧版。

对象=备份 25 卡中仍处四格版(counts=4,baked=false)的目录(zsu23/citadel 已恢复故跳过)。
步骤:备份 sheet_attack.png 拷回 + git checkout anim.json(HEAD 版 counts/outline)。
无备份 7 卡(首次布置,无多帧素材)保留四格版不动。
校验:sheet 宽//frame_size == counts.attack。
"""
import json
import os
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BAK = os.path.join(ROOT, ".godot", "unit_anims_backup_20261016")
ANIM = os.path.join(ROOT, "assets", "effects", "unit_anims")

done = {"cold_sup_zsu23", "mod_fort_citadel"}  # 交接 §四 已恢复
restored, kept = [], []
for uid in sorted(os.listdir(BAK)):
    dst = os.path.join(ANIM, uid)
    jp = os.path.join(dst, "anim.json")
    if not os.path.isfile(jp) or uid in done:
        continue
    meta = json.load(open(jp, encoding="utf-8"))
    if int(meta.get("counts", {}).get("attack", 0)) == 4 and not meta.get("outline", {}).get("baked", False):
        import shutil
        shutil.copyfile(os.path.join(BAK, uid, "sheet_attack.png"),
                        os.path.join(dst, "sheet_attack.png"))
        subprocess.run(["git", "checkout", "--", os.path.relpath(jp, ROOT).replace("\\", "/")],
                       cwd=ROOT, check=True)
        restored.append(uid)
    else:
        kept.append(uid)

print("恢复 %d:" % len(restored))
bad = []
for uid in restored:
    dst = os.path.join(ANIM, uid)
    meta = json.load(open(os.path.join(dst, "anim.json"), encoding="utf-8"))
    from PIL import Image
    w = Image.open(os.path.join(dst, "sheet_attack.png")).size[0]
    fr = w // int(meta.get("frame_size", 256))
    cnt = int(meta.get("counts", {}).get("attack", 0))
    mark = "OK" if fr == cnt else "MISMATCH"
    if fr != cnt:
        bad.append(uid)
    print("  %-24s sheet %d帧 vs counts %d %s" % (uid, fr, cnt, mark))
print("保留四格版(备份中非四格):", kept)
print("BAD:", bad if bad else "none")
