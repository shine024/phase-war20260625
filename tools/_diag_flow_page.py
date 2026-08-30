#!/usr/bin/env python3
"""临时诊断：原 profile 打开 Flow 落地页，观察 recaptcha 脚本注入时机。"""
import glob
import os
import sys

from playwright.sync_api import sync_playwright

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

prof = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\ffroliva\gflow-cli\profile_*"))[0]
print("profile:", prof)

JS = """() => {
  const scripts = [...document.querySelectorAll('script[src*="recaptcha"]')].map(s => s.src.slice(0, 140));
  return {
    scripts,
    grecaptcha: typeof grecaptcha !== 'undefined',
    enterprise: typeof grecaptcha !== 'undefined' && !!grecaptcha.enterprise,
  };
}"""

with sync_playwright() as pw:
    ctx = pw.chromium.launch_persistent_context(
        user_data_dir=prof, headless=False, channel="chrome",
        args=["--no-sandbox", "--disable-blink-features=AutomationControlled"],
        viewport={"width": 1280, "height": 720})
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    bearer_hits = []
    page.on("request", lambda r: bearer_hits.append(r.url[:90])
            if r.headers.get("authorization", "").startswith("Bearer ya29") else None)
    page.goto("https://labs.google/fx/tools/flow", wait_until="domcontentloaded", timeout=60000)
    found = False
    for i in range(12):
        page.wait_for_timeout(3000)
        info = page.evaluate(JS)
        print(f"t={3*(i+1)}s recaptcha_scripts={len(info['scripts'])} "
              f"grecaptcha={info['grecaptcha']} enterprise={info['enterprise']} ya29={len(bearer_hits)}")
        if info["scripts"]:
            for s in info["scripts"][:3]:
                print("   script:", s)
        if info["enterprise"]:
            found = True
            break
    print("title:", page.title())
    body = page.evaluate("() => document.body.innerText.replace(/\\s+/g, ' ').slice(0, 400)")
    print("body text:", body)
    print("ENTERPRISE_READY:", found)
    ctx.close()
