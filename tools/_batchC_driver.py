# -*- coding: utf-8 -*-
"""批C(1+2) codeanim 重做驱动（staging，绝不写 assets/）。

工单来源: tools/card_anim_review_marks (要修改的).json（42家）中走 codeanim 路线的
25 家 + plat 基础 8 家自建动画键。全部从「玩家域卡图」提取锚定并预翻朝左
（plat17 同款配方，复用 fam43_card_anchors.extract / purge_pink_pockets）。

用法:
  python tools/_batchC_driver.py extract          # 提取锚定 + 接触页（人工目检朝向/枪口）
  python tools/_batchC_driver.py gen [k1 k2..]    # 写配置 + codeanim_gen 生成（缺省全部）
产物:
  .godot/unit_review/fam44_anchor_from_card/<key>_anchor_raw.png + _probe_fam44.png
  .godot/unit_review/codeanim_configs/_configs_fam44.json
  .godot/unit_review/codeanim/<key>_codeanim_{layers,sheet,anim.gif}
"""
import io
import json
import os
import subprocess
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
import numpy as np  # noqa: E402
import fam43_card_anchors as fca  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, ".godot", "unit_review", "fam44_anchor_from_card")
CFG = os.path.join(ROOT, ".godot", "unit_review", "codeanim_configs", "_configs_fam44.json")

C_ORANGE = [255, 120, 30]
C_CYAN = [110, 225, 255]
C_PURPLE = [160, 110, 255]
C_AETHER = [170, 220, 255]
C_OMEGA = [70, 170, 255]

# key: (卡图相对路径, mode, cat, flash_color, flash_angle, extra)
U = {
    # ── 批C1 新锚定 ──
    "ww1_arm_ft17":               ("assets/card_icons/player/vis_player_042.png", "vfx", "ground", C_ORANGE, -3, dict(recoil=1, smoke_n=0)),
    "guardian_ww1_ironclad":      ("assets/card_icons/player/vis_player_110.png", "vfx", "ground", [255, 140, 40], -2, dict(recoil=1, smoke_n=1)),
    "fe_iron_wall_bastion":       ("assets/card_icons/player/fe_iron_wall_bastion.png", "vfx", "ground", C_CYAN, -2, dict(recoil=1, smoke_n=0)),
    "fe_iron_wall_juggernaut":    ("assets/card_icons/player/fe_iron_wall_juggernaut.png", "vfx", "ground", C_CYAN, -18, dict(recoil=2, smoke_n=0)),  # 用户: 要做抬枪
    "fe_aether_hover_cavalry":    ("assets/card_icons/player/fe_aether_hover_cavalry.png", "vfx", "air", C_AETHER, -3, dict(recoil=1, smoke_n=0)),
    "fe_aether_swarm_queen":      ("assets/card_icons/player/fe_aether_swarm_queen.png", "vfx", "air", C_AETHER, -2, dict(recoil=0, smoke_n=0)),
    "fe_void_phase_cannon":       ("assets/card_icons/player/fe_void_phase_cannon.png", "vfx", "ground", C_PURPLE, -4, dict(recoil=2, smoke_n=0)),
    "fe_frontier_mixed_company":  ("assets/card_icons/player/fe_frontier_mixed_company.png", "vfx", "ground", C_ORANGE, -3, dict(recoil=1, smoke_n=0)),
    "drop_smg_mk2":               ("assets/card_icons/player/drop_smg_mk2.png", "vfx", "ground", C_ORANGE, -2, dict(recoil=1, smoke_n=0)),  # 用户: 开火位置不对
    "drop_thunder_field":         ("assets/card_icons/player/drop_thunder_field.png", "vfx", "ground", C_CYAN, -2, dict(recoil=0, smoke_n=0)),
    "drop_mega_particle_cannon":  ("assets/card_icons/player/vis_player_071.png", "vfx", "ground", C_CYAN, -2, dict(recoil=3, smoke_n=1, flash_scale=1.3)),
    "mod_stryker_m2":             ("assets/card_icons/player/mod_stryker_m2.png", "vfx", "ground", C_ORANGE, -3, dict(recoil=1, smoke_n=0)),
    "ww1_arm_rolls":              ("assets/card_icons/player/vis_player_001.png", "vfx", "ground", C_ORANGE, -3, dict(recoil=1, smoke_n=0)),
    # ── PoC 老锚定重掷（用户翻案 diff/都要重做）──
    "fut_space_fighter":          ("assets/card_icons/player/vis_player_093.png", "vfx", "air", None, -2, dict(recoil=4, smoke_n=3, flash_scale=0.9)),
    "fut_nano_drone":             ("assets/card_icons/player/fut_nano_drone.png", "vfx", "air", None, -2, dict(recoil=3, smoke_n=3, flash_scale=0.8)),
    "guardian_future_omega":      ("assets/card_icons/player/vis_player_114.png", "vfx", "ground", C_OMEGA, -2, dict(recoil=3, smoke_n=2)),
    "drop_phase_lance":           ("assets/card_icons/player/drop_phase_lance.png", "vfx", "ground", C_CYAN, -29, dict(recoil=1, smoke_n=0, flash_scale=0.8)),  # 枪刃仰角29°几何不变
    # ── 批C2 plat 基础 8 家（自建动画键，不碰共享家族动画）──
    "steel_fortress_basic":       ("assets/card_icons/steel_fortress_basic.png", "vfx", "ground", C_CYAN, -2, dict(recoil=1, smoke_n=0)),
    "steel_titan_basic":          ("assets/card_icons/steel_titan_basic.png", "vfx", "ground", C_CYAN, -2, dict(recoil=2, smoke_n=0)),
    "flame_raider_basic":         ("assets/card_icons/flame_raider_basic.png", "vfx", "ground", C_ORANGE, -4, dict(recoil=1, smoke_n=0, flash_scale=1.2)),
    "flame_siege_basic":          ("assets/card_icons/flame_siege_basic.png", "vfx", "ground", C_ORANGE, -6, dict(recoil=1, smoke_n=0, flash_scale=1.3)),
    "thunter_striker_basic":      ("assets/card_icons/thunter_striker_basic.png", "vfx", "ground", C_CYAN, -3, dict(recoil=1, smoke_n=0)),
    "thunter_sniper_basic":       ("assets/card_icons/thunter_sniper_basic.png", "vfx", "ground", C_CYAN, -6, dict(recoil=1, smoke_n=0)),
    "void_stealth_basic":         ("assets/card_icons/void_stealth_basic.png", "vfx", "air", C_PURPLE, -2, dict(recoil=0, smoke_n=0)),
    "void_mage_basic":            ("assets/card_icons/void_mage_basic.png", "vfx", "ground", C_PURPLE, -8, dict(recoil=1, smoke_n=0)),
}
# fe_helix_phantom 已由 plat17+cards_redo3 处理（工单已 r=no）；fe_frontier_veteran 走生图批（要先变攻击姿势）


def extract_all(keys):
    os.makedirs(SRC, exist_ok=True)
    for k in keys:
        card, _m, _c, _f, _a, _e = U[k]
        p = os.path.join(ROOT, card)
        assert os.path.exists(p), "无卡图: " + p
        arr = fca.extract(p)
        arr = arr[:, ::-1, :]  # 玩家域卡图朝右 → 预翻朝左（codeanim 终稿契约）
        arr, npix = fca.purge_pink_pockets(arr)
        Image.fromarray(arr).save(os.path.join(SRC, "%s_anchor_raw.png" % k))
        a = np.asarray(Image.fromarray(arr).convert("RGB"))
        dist = np.sqrt(((a.astype(int) - np.array([255, 0, 255])) ** 2).sum(axis=2))
        ys, xs = np.where(dist >= 100)
        print("[anchor] %-26s pocket=%d autoL=(%d,%d)" % (k, npix, xs.min(), int(ys[xs == xs.min()].mean())))


def probe_page(keys):
    """接触页：460px 缩略 + 100px 网格 + autoL 十字，人工目检朝向/枪口。"""
    TH, cols = 460, 4
    rows = (len(keys) + cols - 1) // cols
    page = Image.new("RGB", (cols * TH, rows * (TH + 20)), (24, 24, 28))
    d0 = ImageDraw.Draw(page)
    for i, k in enumerate(keys):
        p = os.path.join(SRC, "%s_anchor_raw.png" % k)
        im = Image.open(p).convert("RGB").resize((TH, TH), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        sc = TH / 1024.0
        for v in range(0, 1025, 100):
            d.line((v * sc, 0, v * sc, TH), fill=(0, 255, 120))
            d.line((0, v * sc, TH, v * sc), fill=(0, 255, 120))
        a = np.asarray(Image.open(p).convert("RGB"))
        dist = np.sqrt(((a.astype(int) - np.array([255, 0, 255])) ** 2).sum(axis=2))
        ys, xs = np.where(dist >= 100)
        if len(xs):
            x0, y0 = int(xs.min()), int(ys[xs == xs.min()].mean())
            cx, cy = x0 * sc, y0 * sc
            d.line((cx - 9, cy, cx + 9, cy), fill=(255, 255, 0), width=2)
            d.line((cx, cy - 9, cx, cy + 9), fill=(255, 255, 0), width=2)
        x, y = (i % cols) * TH, (i // cols) * (TH + 20)
        page.paste(im, (x, y))
        d0.text((x + 4, y + TH + 3), "%s  autoL=(%d,%d)@1024" % (
            k, int(xs.min()), int(ys[xs == xs.min()].mean())) if len(xs) else k,
            fill=(255, 220, 120))
    out = os.path.join(SRC, "_probe_fam44.png")
    page.save(out)
    print("[probe] %s (%d家)" % (out, len(keys)))


def write_configs(keys):
    cfg = {}
    if os.path.exists(CFG):
        try:
            cfg = json.load(open(CFG, encoding="utf-8"))
        except Exception:
            cfg = {}
    base = dict(flip=False, outline=False, gain=1.0, pink_scrub=True, src=SRC)
    for k in keys:
        _card, mode, cat, fc, ang, extra = U[k]
        a = np.asarray(Image.open(os.path.join(SRC, "%s_anchor_raw.png" % k)).convert("RGB"))
        dist = np.sqrt(((a.astype(int) - np.array([255, 0, 255])) ** 2).sum(axis=2))
        ys, xs = np.where(dist >= 100)
        mx, my = int(xs.min()), int(ys[xs == xs.min()].mean())
        c = dict(base, mode=mode, cat=cat, muzzle=[mx, my], flash_angle=ang)
        if fc:
            c["flash_color"] = fc
        c.update(extra)
        cfg[k] = c
    os.makedirs(os.path.dirname(CFG), exist_ok=True)
    json.dump(cfg, open(CFG, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("[cfg] +%d → %s" % (len(keys), CFG))


def gen(keys):
    for k in keys:
        r = subprocess.run([sys.executable, "tools/codeanim_gen.py", "--configs",
                            os.path.relpath(CFG, ROOT), k],
                           capture_output=True, text=True, cwd=ROOT)
        line = [l for l in r.stdout.split("\n") if k in l or "md5" in l.lower()]
        print(line[0] if line else (r.stdout[-160:] or r.stderr[-160:]), flush=True)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    keys = sys.argv[2:] if len(sys.argv) > 2 else list(U)
    if cmd == "extract":
        extract_all(keys)
        probe_page(keys)
    elif cmd == "cfg":
        write_configs(keys)
    elif cmd == "gen":
        write_configs(keys)
        gen(keys)
    else:
        print(__doc__)
