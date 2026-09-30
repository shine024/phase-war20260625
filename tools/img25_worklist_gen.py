# -*- coding: utf-8 -*-
"""img25 批量队列重建器（旧 vid_batch_worklist_gen.py 已随视频路线删除，09-29 重写为生图版）。
扫描 assets/effects/unit_anims/*，用 §八 签名判定找出"程序合成攻击动画"单位：
  攻击帧身体与 idle f0 纯平移逐像素相等（±2、滤橙黄/蓝火光、shift ±8）max≥0.95 → 程序合成 → 入队。
输出 .godot/unit_review/img25_worklist.json：{key: {score, energy, weapon}}（已完成单位自动扣除）。
用法：python tools/img25_worklist_gen.py [--all]（--all 含已完成的也列出，供对账）"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "assets", "effects", "unit_anims")
OUT = os.path.join(ROOT, ".godot", "unit_review", "img25_worklist.json")

DONE = {
    "cold_leo1", "fut_heavy_trooper", "fut_shield", "drop_railgun",
    "drop_thunder_field", "drop_smg_mk2", "fut_swarm",
    "guardian_modern_stealth",  # 待机已采纳（攻击未出）
}

# 词根 → (能量?, 武器短语)。能量词进 ENERGY 词表（flash 颜色通道）；weapon 只影响提示词风味。
ENERGY_WORDS = ("能量", "激光", "光束", "电", "磁轨", "轨道", "相位", "等离子")
EN = True
KN = False
RULES = [
    (("plasma", "laser", "rail", "tesla", "ion", "phase", "prism", "storm", "thunder",
      "pulse", "shield", "swarm", "hel30", "ssc1", "nexus", "colossus", "ps9"), EN, "能量脉冲武器"),
    (("flame",), EN, "喷火器"),
    (("mg", "vickers", "browning", "rpk", "pk", "hmg"), KN, "重机枪"),
    (("smg", "mp18", "mp40", "thompson", "pps", "sten"), KN, "冲锋枪"),
    (("rifle", "mauser", "enfield", "garand", "kar98k", "m14", "m76", "ak", "c96", "inf_"), KN, "步枪"),
    (("sniper", "metis", "javelin", "stinger", "tow", "panzerschrek", "pschrek", "bazooka", "rpg"), KN, "反坦克武器"),
    (("arty", "howitzer", "mortar", "m81", "77mm", "105mm", "m120", "mlrs", "himars", "m270", "rq7"), KN, "榴弹炮"),
    (("fort", "bunker", "pillbox", "citadel", "phalanx", "radar"), KN, "堡垒武器"),
    (("saucer", "probe"), EN, "能量射线"),
]


def classify(key):
    k = key.lower()
    for roots, en, wpn in RULES:
        if any(r in k for r in roots):
            return en, wpn
    if "xeno" in k or k.startswith("vis_"):
        return EN, "生物能量攻击"
    if any(r in k for r in ("tank", "tiger", "t34", "pz", "leo", "m1", "t90", "abrams", "t55", "t62", "t72",
                            "arm_", "sherman", "panther", "is2", "challenger", "ft17", "rolls", "a7v", "av7",
                            "mark4", "kingtiger", "bmd", "bmp", "btr", "bradley", "stryker", "hummer", "m113",
                            "hovertank", "sdkfz", "technical", "ifv")):
        return KN, "坦克主炮"
    if any(r in k for r in ("mig", "_f4", "air_", "bomber", "fighter", "drone", "stealth", "multirole",
                            "carrier", "hover", "apache", "ah1", "ah64", "uh60")):
        return KN, "机载武器"
    return KN, "武器开火"


def flash_mask(a, energy):
    rgb = a[:, :, :3].astype(np.int16)
    orange = (rgb[:, :, 0] > 225) & (rgb[:, :, 1] > 115) & (rgb[:, :, 2] < 170)
    blue = (rgb[:, :, 2] > 195) & (rgb[:, :, 1] > 135) & (rgb[:, :, 0] < 185)
    return orange | blue


def match_ratio(frame, f0, fm):
    """frame 与 f0 的纯平移匹配率（±8px、逐通道 ±2、滤火光像素、隔行采样）。"""
    best = 0.0
    h, w = f0.shape[:2]
    for dy in range(-8, 9, 2):
        for dx in range(-8, 9, 2):
            fy0, fy1 = max(0, dy), min(h, h + dy)
            fx0, fx1 = max(0, dx), min(w, w + dx)
            f0y0, f0y1 = max(0, -dy), min(h, h - dy)
            f0x0, f0x1 = max(0, -dx), min(w, w - dx)
            fa = frame[fy0:fy1:2, fx0:fx1:2, :3].astype(np.int16)
            fb = f0[f0y0:f0y1:2, f0x0:f0x1:2, :3].astype(np.int16)
            m = ~(fm[fy0:fy1:2, fx0:fx1:2] | fm[f0y0:f0y1:2, f0x0:f0x1:2])
            n = int(m.sum())
            if n < 500:
                continue
            eq = (np.abs(fa - fb) <= 2).all(axis=2) & m
            r = float(eq.sum()) / n
            if r > best:
                best = r
                if best >= 0.97:
                    return best
    return best


def scan(key):
    d = os.path.join(BASE, key)
    ap = os.path.join(d, "sheet_attack.png")
    ip = os.path.join(d, "sheet_idle.png")
    if not (os.path.exists(ap) and os.path.exists(ip)):
        return None
    try:
        meta = json.load(open(os.path.join(d, "anim.json"), encoding="utf-8"))
        n_attack = int(meta.get("counts", {}).get("attack", 6))
    except Exception:
        n_attack = 6
    fs = 256
    idle = Image.open(ip).convert("RGB")
    f0 = np.asarray(idle.crop((0, 0, fs, fs)))
    fm = flash_mask(f0, False)
    attack = Image.open(ap).convert("RGB")
    best = 0.0
    for i in range(min(n_attack, max(1, attack.width // fs))):
        fr = np.asarray(attack.crop((i * fs, 0, (i + 1) * fs, fs)))
        r = match_ratio(fr, f0, fm)
        best = max(best, r)
        if best >= 0.95:
            break
    return best


def main():
    show_all = "--all" in sys.argv
    done = DONE if not show_all else set()
    result = {}
    for key in sorted(os.listdir(BASE)):
        if key in done:
            continue
        d = os.path.join(BASE, key)
        if not os.path.isdir(d) or key.startswith("drop_overclock"):
            continue
        r = scan(key)
        if r is None:
            continue
        if r >= 0.95:
            en, wpn = classify(key)
            result[key] = {"score": round(r, 3), "energy": en, "weapon": wpn}
    json.dump(result, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("WORKLIST %d units -> %s" % (len(result), os.path.relpath(OUT, ROOT)))
    for k in result:
        print(" ", k, result[k]["score"], "EN" if result[k]["energy"] else "KN", result[k]["weapon"])


if __name__ == "__main__":
    main()
