# -*- coding: utf-8 -*-
"""W5 全量视觉审计·分片准备 v2（2026-09-14）。
读 .godot/agent_tools/w5_vision_audit_list.json（player 148 / enemy_only 94）。
实测修正（像素级验证）：enemy_only 94 张中 82 张 = 本轮 player 148 的镜像翻转
（继承判档不读图）；12 张（001/008/014/022/027/054/063/064/072/075/113/114）
非翻转等价 → 需单独读图。实际读图 160 张。
occupancy 口径 = 不透明像素外接框最大边 / 画幅（对齐历史审计：c96=73/helix=83.4/garand=88）。
产物：.godot/agent_tools/w5_vision_audit/
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, ".godot", "agent_tools", "w5_vision_audit")
os.makedirs(os.path.join(OUT, "shards"), exist_ok=True)

FUT_PREFIX = ("fe_", "fut_", "drop_")
HIST_PREFIX = ("ww1_", "ww2_", "cold_", "mod_")

ENEMY_MIRROR_INHERIT = []  # 运行时填充：82 张继承对


def rim_expect(cid: str) -> str:
    if cid.startswith(HIST_PREFIX):
        return "ice"
    if cid.startswith(FUT_PREFIX):
        return "neon"
    return "auto"  # vis_*：按外观判定链（写实装备→ice / 科幻外观→neon / xeno 语义→violet）


def metrics(path):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    a = np.asarray(img)
    m = a[:, :, 3] >= 16
    ys, xs = np.where(m)
    if len(xs) == 0:
        return 0.0, 0.0, w, h
    bw = (xs.max() - xs.min() + 1) * 100.0 / w
    bh = (ys.max() - ys.min() + 1) * 100.0 / h
    occ = max(bw, bh)
    rgb = a[:, :, :3][m].astype(np.int16)
    warm = (rgb[:, 0] > rgb[:, 2] + 30).sum() * 100.0 / len(rgb)
    return round(occ, 1), round(warm, 1), round(bw, 1), round(bh, 1)


def flip_eq(pe, pp):
    a = np.asarray(Image.open(pe).convert("RGBA"))
    b = np.asarray(Image.open(pp).convert("RGBA"))[:, ::-1]
    return a.shape == b.shape and bool((a == b).all())


def main():
    with open(os.path.join(ROOT, ".godot", "agent_tools", "w5_vision_audit_list.json"), encoding="utf-8") as f:
        listing = json.load(f)

    entries = []
    for cid in listing["player"]:
        full = os.path.join(ROOT, "assets", "card_icons", "player", cid + ".png")
        assert os.path.exists(full), cid
        occ, warm, bw, bh = metrics(full)
        entries.append({"id": cid, "path": full.replace("\\", "/"), "side": "player",
                        "rim_expect": rim_expect(cid), "occupancy_pct": occ,
                        "warm_pct": warm, "bbox_w": bw, "bbox_h": bh})

    # enemy_only：82 张镜像继承（不读图），12 张非等价单独读
    inherit, solo = [], []
    for cid in listing["enemy_only"]:
        efull = os.path.join(ROOT, "assets", "card_icons", "enemy", cid + ".png")
        num = cid.replace("vis_enemy_", "")
        pid = "vis_player_" + num
        pfull = os.path.join(ROOT, "assets", "card_icons", "player", pid + ".png")
        if os.path.exists(pfull) and flip_eq(efull, pfull):
            inherit.append({"id": cid, "mirror_of": pid, "in_player148": pid in set(listing["player"])})
        else:
            occ, warm, bw, bh = metrics(efull)
            solo.append({"id": cid, "path": efull.replace("\\", "/"), "side": "enemy",
                         "rim_expect": "auto", "occupancy_pct": occ, "warm_pct": warm,
                         "bbox_w": bw, "bbox_h": bh,
                         "note": "与 vis_player_%s 非翻转等价（player 侧属 09-08 抽中已判张）" % num})

    all_reads = entries + solo
    sizes = [12] * 13 + [4]
    shards, i = [], 0
    for s in sizes:
        shards.append(all_reads[i:i + s])
        i += s
    assert i == len(all_reads), (i, len(all_reads))

    manifest = {"total_list": 242, "reads": len(all_reads),
                "mirror_inherit": inherit, "mirror_inherit_n": len(inherit),
                "enemy_solo_n": len(solo), "shards": []}
    for idx, chunk in enumerate(shards, 1):
        p = os.path.join(OUT, "shards", "w5_shard_%02d.json" % idx)
        with open(p, "w", encoding="utf-8") as f:
            json.dump(chunk, f, ensure_ascii=False, indent=1)
        manifest["shards"].append({"file": p.replace("\\", "/"), "n": len(chunk),
                                   "ids": [e["id"] for e in chunk]})
    with open(os.path.join(OUT, "w5_manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)

    print("reads=%d (player %d + enemy_solo %d) mirror_inherit=%d shards=%d"
          % (len(all_reads), len(entries), len(solo), len(inherit), len(shards)))
    # 锚点核对
    for probe in ("fut_inf_c96", "ww2_arm_garand_para", "fe_helix_phantom"):
        e = next((x for x in entries if x["id"] == probe), None)
        if e:
            print("anchor %s occ=%s warm=%s" % (probe, e["occupancy_pct"], e["warm_pct"]))
    occ_over90 = [e["id"] for e in all_reads if e["occupancy_pct"] > 90]
    warm_over15 = [e["id"] for e in all_reads if e["warm_pct"] > 15]
    print("occ>90: %d %s" % (len(occ_over90), occ_over90[:15]))
    print("warm>15: %d" % len(warm_over15))


if __name__ == "__main__":
    main()
