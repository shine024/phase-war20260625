# -*- coding: utf-8 -*-
"""MK8 部署批（2026-10-05）：mk8 生图/手术产物 → assets（备份 if-not-exists）。
清单：
  A. fe_helix_phantom 卡图 → player/（玩家专属卡，t2i 直出朝右）
  B. mod_sup_m4_carbine：卡图 → enemy/；玩家卡图 = 镜像；idle 8f + attack 6f（翻转成
     朝左与 idle 一致）→ bake_outline → unit_anims；counts attack 12→6
  C. fe_frontier_veteran：抬枪手术条（12f @256，描边继承自源帧，不重烘）→ sheet_attack
  D. fe_void_dimensional_soldier / fe_iron_wall_juggernaut：锚定路线成品（idle 8f γ 对齐+
     粉渍/灰楔清洗，attack 6f 归一条，均朝右=现役契约向）→ bake_outline → 256
用法: python tools/_mk8_deploy.py [a|b|c|d|abcd]   缺省 abc
"""
import io
import json
import os
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools")
UA = os.path.join(ROOT, "assets", "effects", "unit_anims")
CI = os.path.join(ROOT, "assets", "card_icons")
STG8 = os.path.join(ROOT, ".godot", "unit_review", "mk8_staging")
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_staging")
BAK = os.path.join(ROOT, ".godot", "art_backup_mk8_20261005")
FRAME = 256
os.makedirs(BAK, exist_ok=True)
sys.path.insert(0, TOOLS)
from deploy_unit_anims import bake_outline_on_sheet, outline_meta  # noqa: E402

from PIL import Image  # noqa: E402


def backup_once(path, tag):
    """if-not-exists 备份（MK7 教训：覆盖式备份链会冲掉无备份的后续编辑）。"""
    if not os.path.exists(path):
        return
    d = os.path.join(BAK, tag)
    os.makedirs(d, exist_ok=True)
    dst = os.path.join(d, os.path.basename(path))
    if not os.path.exists(dst):
        shutil.copy2(path, dst)
        print("  [bak] %s/%s" % (tag, os.path.basename(path)))


def deploy_sheet(src_path, unit, anim, flip=False, bake=True):
    """src（横条或 3×2 R2）→ 帧列表 → 256 横条 →（烘描边）→ 覆写 assets，更新 counts。"""
    im = Image.open(src_path).convert("RGBA")
    if im.height == im.width // 3:          # R2 3×2 网格（832 cells）
        cell = im.width // 3
        frames = [im.crop((c * cell, r * cell, (c + 1) * cell, (r + 1) * cell))
                  for r in range(2) for c in range(3)]
    else:                                    # 横条
        n = im.width // im.height
        frames = [im.crop((i * im.height, 0, (i + 1) * im.height, im.height))
                  for i in range(n)]
    od = os.path.join(UA, unit)
    jp = os.path.join(od, "anim.json")
    meta = json.load(open(jp, encoding="utf-8")) if os.path.exists(jp) else {}
    backup_once(os.path.join(od, "sheet_%s.png" % anim), unit)
    backup_once(jp, unit)
    strip = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        if flip:
            f = f.transpose(Image.FLIP_LEFT_RIGHT)
        if f.size != (FRAME, FRAME):
            f = f.resize((FRAME, FRAME), Image.LANCZOS)
        strip.paste(f, (i * FRAME, 0))
    if bake:
        strip = bake_outline_on_sheet(strip)
    strip.save(os.path.join(od, "sheet_%s.png" % anim))
    meta.setdefault("fps", 8)
    meta["frame_size"] = FRAME
    meta.setdefault("counts", {})[anim] = len(frames)
    if bake:
        meta["outline"] = outline_meta(FRAME)
    json.dump(meta, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
    print("[deploy] %-22s %-6s %d 帧 flip=%s bake=%s counts=%s" % (
        unit, anim, len(frames), flip, bake, meta["counts"]), flush=True)


def deploy_icon(src, dst, flip=False):
    backup_once(dst, os.path.basename(os.path.dirname(dst)))
    im = Image.open(src).convert("RGBA")
    if flip:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    im.save(dst)
    print("[icon] → %s%s" % (os.path.relpath(dst, ROOT), " (镜像)" if flip else ""), flush=True)


def main():
    which = (sys.argv[1] if len(sys.argv) > 1 else "abc").lower()
    if "a" in which:
        print("== A: fe_helix_phantom 卡图 ==", flush=True)
        deploy_icon(os.path.join(STG8, "fe_helix_phantom.png"),
                    os.path.join(CI, "player", "fe_helix_phantom.png"))
    if "b" in which:
        print("== B: mod_sup_m4_carbine ==", flush=True)
        deploy_icon(os.path.join(STG8, "mod_sup_m4_carbine.png"),
                    os.path.join(CI, "enemy", "mod_sup_m4_carbine.png"))
        deploy_icon(os.path.join(STG8, "mod_sup_m4_carbine.png"),
                    os.path.join(CI, "player", "mod_sup_m4_carbine.png"), flip=True)
        deploy_sheet(os.path.join(OUT, "mod_sup_m4_carbine_idle_sheet_512.png"),
                     "mod_sup_m4_carbine", "idle")
        deploy_sheet(os.path.join(OUT, "mod_sup_m4_carbine_MK8_attack_sheet_512.png"),
                     "mod_sup_m4_carbine", "attack", flip=True)   # 手术格朝右 → 翻转与 idle(朝左)一致
    if "c" in which:
        print("== C: fe_frontier_veteran 抬枪条 ==", flush=True)
        deploy_sheet(os.path.join(STG8, "fe_frontier_veteran_attack_raised.png"),
                     "fe_frontier_veteran", "attack", bake=False)  # 描边继承自现役源帧
    if "d" in which:
        print("== D: void/juggernaut 锚定路线成品 ==", flush=True)
        for u in ("fe_void_dimensional_soldier", "fe_iron_wall_juggernaut"):
            deploy_sheet(os.path.join(OUT, "%s_idle_sheet_512L.png" % u), u, "idle")
            deploy_sheet(os.path.join(OUT, "%s_attack_sheet_512n.png" % u), u, "attack")
    print("MK8 部署批结束。下一步: python tools/_tmp_anim_foot_frac.py && "
          "Godot --headless --path . --import", flush=True)


if __name__ == "__main__":
    main()
