#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""v3 阶段二：按 key 并行建 flak×2 任务 → 6 路并行轮询下载 → 顺序 build。

并行依据（用户确认）：多个 key 可同时调用，各自独立限流。
key#2 已 401 作废，用 #1/#3 双 worker。
"""
import json
import os
import ssl
import sys
import threading
import time
import traceback
import urllib.parse

ssl._create_default_https_context = ssl._create_unverified_context
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.path.insert(0, r"F:\godot fair duet\create\phase-war\tools")

import importlib.util
spec = importlib.util.spec_from_file_location(
    "gua", r"F:\godot fair duet\create\phase-war\tools\generate_unit_animations.py")
gua = importlib.util.module_from_spec(spec)
try:
    spec.loader.exec_module(gua)
except SystemExit:
    pass

KEYS = gua.api_keys()
assert len(KEYS) >= 3, "key 文件异常"
KEY_A, KEY_B = KEYS[0], KEYS[2]  # #1 可用；#2 401 作废；#3 独立账号
BASE = "https://apihub.agnes-ai.com/v1"
QUERY = "https://apihub.agnes-ai.com/agnesapi"

ANTI = gua.UNITS  # 已含 extra 合并（仅复用其配置；prompt 沿用阶段一同款不重建——flak 走模板+前缀）

# ── 与阶段一一致的 prompt/参数补丁（保证 flak 两条也是抗漂移版）──
ANTI_DRIFT = ("主体在画面中的大小、位置与构图全程与首帧完全一致，绝不放大，绝不缩小，绝不平移，绝不俯视，绝不仰视。"
              "画面中只有这一个单位，没有任何其他物体、碎片或漂浮物。")
for u in ("ww1_arm_rolls", "ww2_fort_flak"):
    for a in ("idle", "attack"):
        p = gua.UNITS[u]["anims"][a]["prompt"]
        if not p.startswith(ANTI_DRIFT):
            gua.UNITS[u]["anims"][a]["prompt"] = ANTI_DRIFT + p


def create_with_key(unit, anim, key):
    cfg = gua.UNITS[unit]["anims"][anim]
    ref = os.path.join(gua.REF_DIR, gua.UNITS[unit]["ref"])
    url = gua.imgbb_upload(ref)
    print("[%s/%s] imgbb ok" % (unit, anim), flush=True)
    payload = {
        "model": gua.MODEL, "prompt": cfg["prompt"], "seconds": cfg["seconds"],
        "mode": "keyframe", "size": "720P", "aspect_ratio": "16:9", "first_frame": url,
    }
    last = None
    for i in range(20):  # 429 退避重试，最多 ~10 分钟
        try:
            _, data = gua.http_json(BASE + "/videos", payload,
                                    headers={"Authorization": "Bearer " + key}, timeout=120)
            vid = data.get("video_id") or data.get("id") or data.get("task_id")
            print("[%s/%s] created %s" % (unit, anim, str(vid)[:26]), flush=True)
            with open(gua.task_file(unit, anim), "w", encoding="utf-8") as f:
                json.dump({"video_id": vid, "img_url": url, "created": time.time()}, f, ensure_ascii=False)
            return vid
        except Exception as e:
            last = repr(e)[:140]
            print("[%s/%s] create retry %d: %s" % (unit, anim, i + 1, last), flush=True)
            time.sleep(30)
    raise RuntimeError("create 放弃: " + last)


def poll_build_with_key(unit, anim, key):
    with open(gua.task_file(unit, anim), encoding="utf-8") as f:
        vid = json.load(f)["video_id"]
    t0 = time.time()
    while time.time() - t0 < 900:
        try:
            url = QUERY + "?" + urllib.parse.urlencode({"video_id": vid, "model_name": gua.MODEL})
            _, data = gua.http_json(url, headers={"Authorization": "Bearer " + key}, timeout=60)
            status = str(data.get("status", "")).lower()
            if "fail" in status or "error" in status:
                raise RuntimeError("任务失败: " + json.dumps(data, ensure_ascii=False)[:300])
            if {"complet", "success", "done"} & {status} or "complet" in status:
                hits = gua.find_video_url(data)
                if not hits:
                    raise RuntimeError("无视频URL: " + json.dumps(data)[:300])
                mp4 = os.path.join(gua.anim_dir(unit, anim), "source.mp4")
                n = gua.download(hits[0][1], mp4)
                print("[%s/%s] mp4 %dB -> build" % (unit, anim, n), flush=True)
                gua.step_build(unit, anim)
                print("[%s/%s] BUILD DONE" % (unit, anim), flush=True)
                return
            print("[%s/%s] %.0fs %s" % (unit, anim, time.time() - t0, status or "?"), flush=True)
        except RuntimeError:
            raise
        except Exception as e:
            print("[%s/%s] poll err %s" % (unit, anim, repr(e)[:100]), flush=True)
        time.sleep(8)
    raise RuntimeError("轮询超时")


results = {}

def worker(name, fn):
    try:
        fn()
        results[name] = "OK"
    except Exception as e:
        results[name] = "FAIL: " + str(e)[:200]
        traceback.print_exc()

# ── A: 并行建 flak×2（key#1 / key#3 各一）──
ta = threading.Thread(target=worker, args=("create flak/idle", lambda: create_with_key("ww2_fort_flak", "idle", KEY_A)))
tb = threading.Thread(target=worker, args=("create flak/attack", lambda: create_with_key("ww2_fort_flak", "attack", KEY_B)))
ta.start(); tb.start(); ta.join(); tb.join()
print("== create phase:", results, flush=True)

# ── B: 6 路并行轮询+下载+build ──
ALL = [("fut_inf_c96", "idle"), ("fut_inf_c96", "attack"),
       ("ww1_arm_rolls", "idle"), ("ww1_arm_rolls", "attack"),
       ("ww2_fort_flak", "idle"), ("ww2_fort_flak", "attack")]
threads = []
for i, (u, a) in enumerate(ALL):
    k = KEY_A if i % 2 == 0 else KEY_B
    th = threading.Thread(target=worker, args=("pb %s/%s" % (u, a), lambda uu=u, aa=a, kk=k: poll_build_with_key(uu, aa, kk)))
    th.start(); threads.append(th)
for th in threads:
    th.join()

print("== final:", json.dumps(results, ensure_ascii=False), flush=True)
bad = [k for k, v in results.items() if v != "OK"]
print("[PHASE2 COMPLETE]", "ALL OK" if not bad else "FAILED: %s" % bad, flush=True)
