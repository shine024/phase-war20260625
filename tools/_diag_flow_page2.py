#!/usr/bin/env python3
"""临时诊断2：完整观察 Flow 页面生命周期（URL / recaptcha 脚本 / grecaptcha）。"""
import glob
import os
import sys

from playwright.sync_api import sync_playwright

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

prof = glob.glob(os.path.expandvars(r"%LOCALAPPDATA%\ffroliva\gflow-cli\profile_*"))[0]

JS = """() => {
  const scripts = [...document.querySelectorAll('script[src*="recaptcha"]')]
      .map(s => s.src.slice(0, 140));
  return {
    scripts,
    enterprise_js: scripts.filter(s => s.includes('enterprise.js')).length,
    grecaptcha: typeof grecaptcha !== 'undefined',
    ent_ready: typeof grecaptcha !== 'undefined' && !!grecaptcha.enterprise,
  };
}"""

with sync_playwright() as pw:
    ctx = pw.chromium.launch_persistent_context(
        user_data_dir=prof, headless=False, channel="chrome",
        args=["--no-sandbox", "--disable-blink-features=AutomationControlled"],
        viewport={"width": 1280, "height": 720})
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.goto("https://labs.google/fx/tools/flow", wait_until="domcontentloaded", timeout=60000)
    for i in range(20):
        page.wait_for_timeout(3000)
        try:
            info = page.evaluate(JS)
        except Exception as exc:
            print(f"t={3*(i+1)}s evaluate失败: {exc}")
            continue
        print(f"t={3*(i+1)}s url={page.url[:90]} ent_js={info['enterprise_js']} "
              f"grecaptcha={info['grecaptcha']} ent_ready={info['ent_ready']}")
        if i in (0, 6, 12, 19):
            body = page.evaluate("() => document.body.innerText.replace(/\\s+/g, ' ').slice(0, 150)")
            print(f"   body: {body}")
    ctx.close()
