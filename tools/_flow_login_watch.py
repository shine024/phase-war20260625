#!/usr/bin/env python3
"""临时：打开有头 Chrome（原 profile）等用户人工完成 Google 登录，成功后自动退出。"""
import glob
import os
import sys
import time

from playwright.sync_api import sync_playwright

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

prof = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\ffroliva\gflow-cli\profile_*"))[0]
print("profile:", prof, flush=True)

with sync_playwright() as pw:
    ctx = pw.chromium.launch_persistent_context(
        user_data_dir=prof, headless=False, channel="chrome",
        args=["--no-sandbox", "--disable-blink-features=AutomationControlled"],
        viewport={"width": 1280, "height": 800})
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    ya29 = []
    page.on("request", lambda r: ya29.append(1)
            if r.headers.get("authorization", "").startswith("Bearer ya29") else None)
    page.goto("https://labs.google/fx/tools/flow", wait_until="domcontentloaded", timeout=60000)
    deadline = time.time() + 900  # 最多等 15 分钟
    while time.time() < deadline:
        page.wait_for_timeout(3000)
        try:
            ok = ("labs.google" in page.url and len(ya29) > 0
                  and page.evaluate("() => typeof grecaptcha !== 'undefined' && !!grecaptcha.enterprise"))
            print(f"   url={page.url[:80]} ya29={len(ya29)} ent={ok}", flush=True)
            if ok:
                print("AUTH_OK —— 登录态已恢复，profile 已保存", flush=True)
                page.wait_for_timeout(3000)
                break
        except Exception:
            pass
    else:
        print("TIMEOUT —— 15 分钟内未完成登录", flush=True)
    ctx.close()
