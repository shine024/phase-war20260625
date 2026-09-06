# -*- coding: utf-8 -*-
"""truck_cutaway_mockup.html 实拍验证：起 http.server + playwright 点击测试 + 截图"""
import threading, functools, os
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, '.verify_cutaway')
os.makedirs(OUT, exist_ok=True)

handler = functools.partial(SimpleHTTPRequestHandler, directory=ROOT)
srv = ThreadingHTTPServer(('127.0.0.1', 8791), handler)
threading.Thread(target=srv.serve_forever, daemon=True).start()

errors = []
with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={'width': 1600, 'height': 900})
    pg.on('pageerror', lambda e: errors.append('PAGEERROR: %s' % e))
    pg.on('console', lambda m: errors.append('CONSOLE-ERR: %s' % m.text) if m.type == 'error' else None)
    pg.goto('http://127.0.0.1:8791/truck_cutaway_mockup.html')
    pg.wait_for_timeout(1000)
    pg.screenshot(path=os.path.join(OUT, '01_base.png'))

    # ① 指挥电脑 → 统计终端（战绩 tab 默认）
    pg.click('#hs_term')
    pg.wait_for_timeout(400)
    pg.screenshot(path=os.path.join(OUT, '02_terminal_wip.png'))
    # ② 资源 / 战线 / 收集 tab
    pg.click('[data-tab="res"]');   pg.wait_for_timeout(300)
    pg.screenshot(path=os.path.join(OUT, '03_terminal_res.png'))
    pg.click('[data-tab="front"]'); pg.wait_for_timeout(300)
    pg.screenshot(path=os.path.join(OUT, '04_terminal_front.png'))
    pg.click('[data-tab="coll"]');  pg.wait_for_timeout(300)
    pg.screenshot(path=os.path.join(OUT, '05_terminal_coll.png'))
    pg.keyboard.press('Escape'); pg.wait_for_timeout(200)

    # ③ 热区开关（全轮廓）
    pg.click('#btnHot'); pg.wait_for_timeout(300)
    pg.screenshot(path=os.path.join(OUT, '06_showall.png'))
    pg.click('#btnHot'); pg.wait_for_timeout(200)

    # ④ 驾驶室 → 出击简报 → 出击演出
    pg.click('#hs_cab'); pg.wait_for_timeout(300)
    pg.screenshot(path=os.path.join(OUT, '07_sortie.png'))
    pg.click('#btnGo')
    pg.wait_for_timeout(500);  pg.screenshot(path=os.path.join(OUT, '08_battle.png'))
    pg.wait_for_timeout(2100)  # 等演出结束
    # ⑤ 售货机占位面板
    pg.click('#hs_vend'); pg.wait_for_timeout(300)
    pg.screenshot(path=os.path.join(OUT, '09_vend_panel.png'))
    pg.keyboard.press('Escape')

    # 探针：热区数量 / 终端tab渲染 / 图表svg存在
    probes = pg.evaluate('''() => ({
        hs: document.querySelectorAll('.hs').length,
        modalOpen: document.getElementById('modal').classList.contains('on'),
    })''')
    print('PROBES:', probes)
    b.close()
srv.shutdown()
print('JS_ERRORS:', len(errors))
for e in errors: print(' ', e)
print('DONE')
