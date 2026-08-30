"""v23.6 一次性美术/动画资产完整性审计（临时件，可删）。"""
import os, re, glob

print('=== 字体文件 ===')
for f in ['Rajdhani-SemiBold.ttf', 'Rajdhani-Bold.ttf', 'Rajdhani-Regular.ttf',
          'data_font.ttf', 'title_font.ttf']:
    p = 'assets/fonts/' + f
    print(' ', 'OK ' if os.path.exists(p) else 'MISS', p)

print()
print('=== 音效名 vs assets/sfx ===')
sfx = set(f[:-4] for f in os.listdir('assets/sfx'))
calls = set()
emits = set()
for gd in glob.glob('**/*.gd', recursive=True):
    if gd.startswith('addons'):
        continue
    t = open(gd, encoding='utf-8', errors='ignore').read()
    calls.update(re.findall(r'play_sfx\("([a-z_0-9]+)"', t))
    emits.update(re.findall(r'play_sound\.emit\("([a-z_0-9]+)"', t))
print(' play_sfx 字面量调用:', len(calls), '| 缺文件:', sorted(c for c in calls if c not in sfx))
print(' play_sound.emit 名:', len(emits), '| 缺文件:', sorted(e for e in emits if e not in sfx))

print()
print('=== unit_anims 待机动画 ===')
dirs = sorted(os.listdir('assets/effects/unit_anims'))
print(' 现有动画 id:', dirs)
refs = set()
for gd in glob.glob('**/*.gd', recursive=True):
    if gd.startswith('addons'):
        continue
    t = open(gd, encoding='utf-8', errors='ignore').read()
    refs.update(re.findall(r'unit_anims.([a-z_0-9]+).', t))
print(' 代码引用 id:', sorted(refs))
print(' 引用但缺目录:', [r for r in refs if r not in dirs])

print()
print('=== 爆炸帧序列 ===')
for sd in sorted(os.listdir('assets/effects/explosion_frames')):
    n = len(glob.glob('assets/effects/explosion_frames/' + sd + '/*.png'))
    print(' ', sd, n, '帧')

print()
print('=== spell/ult 贴图（v20.29 已审，快速复核）===')
for d, n in [('assets/effects/spell_burst', None), ('assets/effects/ultimate_projectiles', None),
             ('assets/effects/nuclear', None), ('assets/effects/projectiles', None)]:
    if os.path.isdir(d):
        pngs = glob.glob(d + '/**/*.png', recursive=True)
        print(' ', d, len(pngs), 'png')
    else:
        print(' MISS 目录', d)
