#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成星冥族 20 张专属卡图（v27 黑门）：agnes-image-2.1-flash → 白底 PNG 供审核。

输出: docs/待生成卡图_xeno/vis_xeno_<short>_white.png
配置: tools/xeno_assets_config.py（prompt 单一真身）
部署: tools/deploy_xeno_card_icons.py（白转透 512 + enemy/ + player/ 翻转）
跑法: python tools/generate_xeno_card_icons.py            # 全部缺的
      python tools/generate_xeno_card_icons.py vis_xeno_zealot ...  # 指定 key
"""
import json
import os
import re
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xeno_assets_config import UNITS, card_prompt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_MD = os.path.join(ROOT, "tools", "_agnes_image_api.md")
OUT_DIR = os.path.join(ROOT, "docs", "待生成卡图_xeno")
MODEL = "agnes-image-2.1-flash"
SIZE = "1024x1024"
BASE_URLS = ["https://apihub.agnes-ai.com/v1", "https://api.agnes-ai.cn/v1"]


def load_keys():
    src = open(KEY_MD, "r", encoding="utf-8").read()
    keys = re.findall(r"sk-[A-Za-z0-9]{20,}", src)
    if not keys:
        raise SystemExit("tools/_agnes_image_api.md 里找不到 key")
    return keys


def call_api(prompt, key, out):
    payload = json.dumps({"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1})
    tmp, resp = out + ".payload.json", out + ".resp.json"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(payload)
    ok = False
    for base in BASE_URLS:
        subprocess.run(["curl", "--http1.1", "-s", "-X", "POST", base + "/images/generations",
                        "-H", "Authorization: Bearer " + key, "-H", "Content-Type: application/json",
                        "--data-binary", "@" + tmp, "-o", resp, "--max-time", "180"],
                       capture_output=True, text=True, timeout=200)
        content = open(resp, "r", encoding="utf-8", errors="replace").read() if os.path.exists(resp) else ""
        try:
            data = json.loads(content)
        except json.JSONDecodeError:
            continue
        url = (data.get("data") or [{}])[0].get("url", "")
        b64 = (data.get("data") or [{}])[0].get("b64_json", "")
        if url:
            subprocess.run(["curl", "--http1.1", "-s", "-L", "-o", out, url, "--max-time", "180"],
                           capture_output=True, text=True, timeout=200)
            ok = os.path.exists(out) and os.path.getsize(out) > 5000
        elif b64:
            import base64
            with open(out, "wb") as f:
                f.write(base64.b64decode(b64))
            ok = os.path.exists(out) and os.path.getsize(out) > 5000
        if ok:
            break
    for f in (tmp, resp):
        try:
            os.unlink(f)
        except OSError:
            pass
    return ok


def main():
    only = set(sys.argv[1:])
    os.makedirs(OUT_DIR, exist_ok=True)
    keys = load_keys()
    todo = [u for u in UNITS if not only or u["key"] in only]
    print("星冥卡图生成：%d 张（模型 %s %s）" % (len(todo), MODEL, SIZE))
    n_ok = 0
    for i, u in enumerate(todo):
        out = os.path.join(OUT_DIR, u["key"] + "_white.png")
        if os.path.exists(out) and os.path.getsize(out) > 5000:
            print("[%02d/%02d] %s 已存在，跳过" % (i + 1, len(todo), u["key"]))
            n_ok += 1
            continue
        prompt = card_prompt(u)
        key = keys[i % len(keys)]
        ok = call_api(prompt, key, out)
        # 失败重试一次（换 key）
        if not ok:
            key = keys[(i + 1) % len(keys)]
            ok = call_api(prompt, key, out)
        print("[%02d/%02d] %s(%s) %s" % (i + 1, len(todo), u["key"], u["display"], "OK" if ok else "FAIL"))
        n_ok += 1 if ok else 0
    print("完成：%d/%d → %s" % (n_ok, len(todo), OUT_DIR))


if __name__ == "__main__":
    main()
