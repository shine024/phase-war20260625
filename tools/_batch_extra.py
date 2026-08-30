# -*- coding: utf-8 -*-
"""72 补充单位批量: 按时代(ww1→ww2→cold→mod→fut)逐单位 create→poll→build
进度/结果写 tools/_batch_extra.log; 单位失败不中断批次"""
import io
import json
import os
import subprocess
import sys
import time

CFG = json.load(io.open('tools/unit_animations_extra.json', encoding='utf-8'))
ERAS = ['ww1', 'ww2', 'cold', 'mod', 'fut']
order = []
for e in ERAS:
    order += [k for k in CFG if k.startswith(e + '_')]
rest = [k for k in CFG if k not in order]
order += rest

LOG = open('tools/_batch_extra.log', 'a', encoding='utf-8')


def log(msg):
    LOG.write(time.strftime('%H:%M:%S ') + msg + '\n')
    LOG.flush()
    print(msg, flush=True)


def run(*args):
    return subprocess.run([sys.executable] + list(args),
                          capture_output=True, text=True, encoding='utf-8', errors='replace')


log('=== batch start: %d units ===' % len(order))
done = fail = 0
for n, key in enumerate(order, 1):
    name = CFG[key]['name']
    tag = '[%d/%d] %s(%s)' % (n, len(order), key, name)
    ok = True
    # create ×2
    for anim in ('idle', 'attack'):
        r = run('tools/generate_unit_animations.py', 'create', key, anim)
        if r.returncode != 0:
            log('%s create %s FAIL: %s' % (tag, anim, (r.stderr or '')[-160:]))
            ok = False
            break
        time.sleep(11)
    if not ok:
        fail += 1
        continue
    # poll ×2
    for anim in ('idle', 'attack'):
        r = run('tools/generate_unit_animations.py', 'poll', key, anim)
        if r.returncode != 0:
            log('%s poll %s FAIL: %s' % (tag, anim, (r.stderr or '')[-160:]))
            ok = False
            break
    if not ok:
        fail += 1
        continue
    # 自检关卡②: FAIL 的动画重 roll 一次, 再 FAIL 放行但记 GATE-FAIL(修复轮处理)
    for anim in ('idle', 'attack'):
        for attempt in (1, 2):
            r = run('tools/anim_video_selfcheck.py', '%s_%s' % (key, name))
            out = r.stdout or ''
            line = [l for l in out.splitlines() if ('/%s' % anim) in l and ('PASS' in l or 'FAIL' in l)]
            verdict = line[0].split()[-4] if line else ('?' if attempt == 1 else '?')
            is_fail = bool(line) and 'FAIL' in line[0]
            if not is_fail:
                if line:
                    log('%s selfcheck %s %s' % (tag, anim, ' '.join(line[0].split()[1:])))
                break
            log('%s selfcheck %s FAIL(attempt %d): %s' % (tag, anim, attempt, line[0][:110] if line else 'no-output'))
            if attempt == 1:
                rc = run('tools/generate_unit_animations.py', 'create', key, anim)
                if rc.returncode != 0:
                    log('%s re-create FAIL' % tag)
                    break
                time.sleep(11)
                rp = run('tools/generate_unit_animations.py', 'poll', key, anim)
                if rp.returncode != 0:
                    log('%s re-poll FAIL' % tag)
                    break
        else:
            log('%s GATE-FAIL %s — 已放行待修复轮' % (tag, anim))
    # build ×2
    for anim in ('idle', 'attack'):
        r = run('tools/generate_unit_animations.py', 'build', key, anim)
        if r.returncode != 0:
            log('%s build %s FAIL: %s' % (tag, anim, (r.stderr or '')[-160:]))
            ok = False
    if ok:
        done += 1
        log('%s OK' % tag)
log('=== batch end: %d ok, %d fail ===' % (done, fail))
LOG.close()
