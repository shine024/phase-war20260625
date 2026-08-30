#!/usr/bin/env python3
"""临时诊断4：纯观察——新开浏览器后 Google 会话是否持久（不点任何东西）。"""
import glob
import os
import sys

from playwright.sync_api import sync_playwright

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

prof = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\ffroliva\gflow-cli\profile_*"))[0]
JS = "() => typeof grecaptcha !== 'undefined' && !!grecaptcha.enterprise"

with sync_playwright() as pw:
    ctx = pw.chromium.launch_persistent_context(
        user_data_dir=prof, headless=False, channel="chrome",
        args=["--no-sandbox", "--disable-blink-features=AutomationControlled"],
        viewport={"width": 1280, "height": 720})
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.goto("https://labs.google/fx/tools/flow", wait_until="domcontentloaded", timeout=60000)
    for i in range(8):
        page.wait_for_timeout(4000)
        try:
            ent = page.evaluate(JS)
        except Exception:
            ent = "nav"
        print(f"t={4*(i+1)}s url={page.url[:70]} ent={ent}", flush=True)
    ctx.close()
