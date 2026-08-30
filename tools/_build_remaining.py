# -*- coding: utf-8 -*-
import subprocess
import sys

for u, a in [('ww2_garand', 'idle'), ('cold_ak', 'idle'), ('cold_m60', 'attack'), ('fut_spectre', 'idle')]:
    r = subprocess.run([sys.executable, 'tools/generate_unit_animations.py', 'build', u, a],
                       capture_output=True, text=True, encoding='utf-8', errors='replace')
    tail = (r.stdout or '').strip().splitlines()
    print('[build %s/%s] rc=%d | %s' % (u, a, r.returncode, ' | '.join(tail[-2:])))
    if r.returncode != 0:
        print((r.stderr or '')[-300:])
