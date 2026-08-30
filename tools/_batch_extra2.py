# -*- coding: utf-8 -*-
"""二遍补漏: 只处理产物缺失的单位(一遍被限流跳过的)
create 间距 16s, 限流错误退避 65s 重试"""
import glob
import io
import json
import os
import subprocess
import sys
import time

CFG = json.load(io.open('tools/unit_animations_extra.json', encoding='utf-8'))
BASE = r'资料/单位分帧动画'
ERAS = ['ww1', 'ww2', 'cold', 'mod', 'fut']

todo = []
for e in ERAS:
    for k in CFG:
        if not k.startswith(e + '_'):
            continue
        d = os.path.join(BASE, '%s_%s' % (k, CFG[k]['name']))
        lack = []
        for anim in ('idle', 'attack'):
            ad = os.path.join(d, anim)
            fs = glob.glob(os.path.join(ad, 'f*.png')) if os.path.isdir(ad) else []
            if len(fs) < 6:
                lack.append(anim)
        if not os.path.isdir(d) or lack:
            todo.append((k, lack))
print('二遍待补:', len(todo))
for k, lack in todo:
    print(' ', k, lack)

LOG = open('tools/_batch_extra2.log', 'a', encoding='utf-8')


def log(m):
    LOG.write(time.strftime('%H:%M:%S ') + m + '\n')
    LOG.flush()
    print(m, flush=True)


def run(*a):
    return subprocess.run([sys.executable] + list(a), capture_output=True,
                          text=True, encoding='utf-8', errors='replace')


def create_retry(key, anim, tries=3):
    for t in range(1, tries + 1):
        r = run('tools/generate_unit_animations.py', 'create', key, anim)
        if r.returncode == 0:
            return True
        err = (r.stderr or '') + (r.stdout or '')
        if 'rate_limit' in err or 'mit exceeded' in err or '全部失败' in err:
            log('%s %s create 限流, 退避65s (第%d次)' % (key, anim, t))
            time.sleep(65)
            continue
        log('%s %s create FAIL: %s' % (key, anim, err[-160:]))
        return False
    return False


for n, (key, lack) in enumerate(todo, 1):
    name = CFG[key]['name']
    tag = '[%d/%d] %s(%s)' % (n, len(todo), key, name)
    ok = True
    for anim in lack:
        if not create_retry(key, anim):
            ok = False
            continue
        time.sleep(16)
    if not ok:
        log('%s SKIP(create)' % tag)
        continue
    for anim in lack:
        r = run('tools/generate_unit_animations.py', 'poll', key, anim)
        if r.returncode != 0:
            log('%s poll %s FAIL: %s' % (tag, anim, (r.stderr or '')[-160:]))
            ok = False
    if not ok:
        continue
    # 自检: FAIL 重 roll 一次
    for anim in lack:
        for attempt in (1, 2):
            r = run('tools/anim_video_selfcheck.py', '%s_%s' % (key, name))
            line = [l for l in (r.stdout or '').splitlines()
                    if ('/%s' % anim) in l and ('PASS' in l or 'FAIL' in l)]
            if not line or 'FAIL' not in line[0]:
                break
            log('%s selfcheck %s FAIL(attempt %d)' % (tag, anim, attempt))
            if attempt == 1:
                if not create_retry(key, anim):
                    break
                time.sleep(16)
                if run('tools/generate_unit_animations.py', 'poll', key, anim).returncode != 0:
                    break
        else:
            log('%s GATE-FAIL %s — 放行待修复轮' % (tag, anim))
    for anim in lack:
        r = run('tools/generate_unit_animations.py', 'build', key, anim)
        if r.returncode != 0:
            log('%s build %s FAIL: %s' % (tag, anim, (r.stderr or '')[-160:]))
    log('%s DONE' % tag)
log('=== pass2 end ===')
LOG.close()
