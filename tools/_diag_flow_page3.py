#!/usr/bin/env python3
"""临时诊断3：点账号选择页里的账号后，会话到底恢复没有。"""
import glob
import os
import sys

from playwright.sync_api import sync_playwright

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

prof = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\ffroliva\gflow-cli\profile_*"))[0]

with sync_playwright() as pw:
    ctx = pw.chromium.launch_persistent_context(
        user_data_dir=prof, headless=False, channel="chrome",
        args=["--no-sandbox", "--disable-blink-features=AutomationControlled"],
        viewport={"width": 1280, "height": 720})
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.goto("https://labs.google/fx/tools/flow", wait_until="domcontentloaded", timeout=60000)
    page.wait_for_timeout(6000)
    print("初始 url:", page.url[:110])
    if "accounts.google.com" in page.url:
        try:
            await_btn = page.locator("[data-identifier]").first
            await_btn.click(timeout=10000)
            print("已点击账号条目")
        except Exception as exc:
            print("点击失败:", str(exc)[:200])
        for i in range(10):
            page.wait_for_timeout(4000)
            print(f"  t={4*(i+1)}s url={page.url[:110]}")
            if "labs.google" in page.url:
                page.wait_for_timeout(5000)
                info = page.evaluate(
                    "() => ({ent: [...document.querySelectorAll('script[src*=\\'recaptcha\\']')]"
                    ".filter(s => s.src.includes('enterprise.js')).length,"
                    " g: typeof grecaptcha !== 'undefined',"
                    " body: document.body.innerText.replace(/\\s+/g,' ').slice(0,120)})")
                print("  回到 labs.google:", info)
                break
        else:
            print("  60s 内未回到 labs.google —— 会话无法自动恢复")
            body = page.evaluate("() => document.body.innerText.replace(/\\s+/g, ' ').slice(0, 200)")
            print("  当前页文本:", body)
    ctx.close()
