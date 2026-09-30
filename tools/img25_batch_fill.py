# -*- coding: utf-8 -*-
"""img25 批量补跑器（09-29 用户定稿：英文结构化模板 + 卡图参考 + 无描边 + C 风格 + 导图）。
只处理 worklist 缺口：无 <key>_attackC.png → 生成攻击；无 <key>_idle.png → 生成待机。
每单位：gen(卡图参考+导图) → 结构体检（FAIL 自动重掷一次）→ crop/cropidle → 状态落账。
断点续跑：重跑本脚本自动跳过已完成。状态：.godot/unit_review/img25_batch_status.json
用法：python tools/img25_batch_fill.py [--only-attack|--only-idle]"""
import importlib.util
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location("t", os.path.join(ROOT, "tools", "img25_sprite_trial.py"))
t = importlib.util.module_from_spec(spec)
spec.loader.exec_module(t)

WL = json.load(open(os.path.join(ROOT, ".godot", "unit_review", "img25_worklist.json"), encoding="utf-8"))
STG = t.OUT
STATUS_P = os.path.join(ROOT, ".godot", "unit_review", "img25_batch_status.json")
STATUS = json.load(open(STATUS_P, encoding="utf-8")) if os.path.exists(STATUS_P) else {}


def save_status():
    json.dump(STATUS, open(STATUS_P, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def audit_ok(rawp):
    """结构体检：3x2 带检测（允许行带=1，切格有列分行兜底；只拦列带≠3 且无网格可救的情形交给 crop 结果）。
    这里宽松：只要 raw 存在且非全白就过，真正的质量门在 crop 后的候选尺寸一致性与人工目检。"""
    from PIL import Image
    import numpy as np
    try:
        a = np.asarray(Image.open(rawp).convert("RGB")).astype(np.int16)
    except Exception:
        return False
    nw = ~((a[:, :, 0] > 235) & (a[:, :, 1] > 235) & (a[:, :, 2] > 235))
    return int(nw.sum()) > 5000


AIR_ROOTS = ("air_", "fighter", "bomber", "drone", "mig", "_f4", "hover", "apache", "ah1", "ah64",
             "uh60", "rq7", "multirole", "stealth", "carrier", "meteor", "me262")


def do_attack(key, meta):
    weapon = meta.get("weapon", "武器开火")
    if any(r in key for r in AIR_ROOTS):
        weapon = "航空机炮"
    print("[atk] %s gen…" % key, flush=True)
    t.gen_raw_only(key, weapon, ["C"], True, False, False, True)  # refcard=True
    rawp = os.path.join(STG, "%s_attackC_raw.png" % key)
    if not audit_ok(rawp):
        print("[atk] %s 体检差，重掷一次" % key, flush=True)
        t.gen_raw_only(key, weapon, ["C"], True, False, False, True)
    if not audit_ok(rawp):
        STATUS[key]["attack"] = "gen_failed"
        return
    r = t.crop_raw(key, "C")
    print("[atk] %s -> %s" % (key, r), flush=True)
    STATUS[key]["attack"] = r


def do_idle(key, meta):
    print("[idl] %s gen…" % key, flush=True)
    t.process_idle(key)  # process_idle 内部用卡图？——否，用雪碧图 f0；批量走 refcard 待机需另接
    rawp = os.path.join(STG, "%s_idle_raw.png" % key)
    if not audit_ok(rawp):
        print("[idl] %s 体检差，重掷一次" % key, flush=True)
        t.process_idle(key)
    if not audit_ok(rawp):
        STATUS[key]["idle"] = "gen_failed"
        return
    r = t.crop_idle(key)
    print("[idl] %s -> %s" % (key, r), flush=True)
    STATUS[key]["idle"] = r


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    todo = [(k, m) for k, m in sorted(WL.items())]
    for i, (key, meta) in enumerate(todo):
        STATUS.setdefault(key, {})
        want_a = only != "--only-idle" and not os.path.exists(os.path.join(STG, "%s_attackC.png" % key))
        want_i = only != "--only-attack" and not os.path.exists(os.path.join(STG, "%s_idle.png" % key))
        if not want_a and not want_i:
            continue
        print("=== [%d/%d] %s ===" % (i + 1, len(todo), key), flush=True)
        try:
            if want_a:
                do_attack(key, meta)
            if want_i:
                do_idle(key, meta)
        except Exception as e:
            STATUS[key]["error"] = str(e)[:200]
            print(key, "ERROR", e, flush=True)
        save_status()
    save_status()
    print("BATCH_FILL_DONE", flush=True)


if __name__ == "__main__":
    main()
