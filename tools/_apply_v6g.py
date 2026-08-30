# -*- coding: utf-8 -*-
"""alpha_of 改 v6g: edge_mode 参数化(默认关) + 白机身单位开 matte_edge 标记"""
import io

p = 'tools/generate_unit_animations.py'
src = io.open(p, encoding='utf-8').read()

# 1) 签名
old = 'def alpha_of(path, luma_ref=None, sat_max=75, mn_floor=135):'
assert src.count(old) == 1
src = src.replace(old, 'def alpha_of(path, luma_ref=None, sat_max=75, mn_floor=135, edge_mode=False):')

# 2) 边缘密封段包进 edge_mode 分支
i = src.index('        # v6e 边缘密封泛洪')
j = src.index('        # v6d-2 边界可达近白修剪')
seg = src[i:j]
indented = '\n'.join(('    ' + ln if ln.strip() else ln) for ln in seg.splitlines())
new_seg = (
    '        if edge_mode:\n'
    '            # v6e 边缘密封救援(仅白机身单位): 深色描边把白底挡在轮廓外,\n'
    '            #   与边框隔离的密封区=候选主体(救回贴边白色部件/银白机身);\n'
    '            #   副作用=深灰硝烟云也会连通, 故默认关闭走纯 v6c\n'
    + indented + '\n'
    '        else:\n'
    '            union = keepc.astype(np.uint8)\n'
    '            n3, lab3, st3, _ = cv2.connectedComponentsWithStats(union)\n'
    '            if n3 > 1:\n'
    '                big = 1 + int(np.argmax(st3[1:, cv2.CC_STAT_AREA]))\n'
    '                keep = lab3 == big\n'
    '            else:\n'
    '                keep = keepc\n'
)
src = src[:i] + new_seg + src[j:]

# 3) v6d-2 修剪段与脚线段保持原样(在两种模式下都跑, 实测0副作用)

# 4) step_build 调用点传 edge_mode
old_call = '        im, a = alpha_of(p, luma_ref, mn_floor=unit_mn_floor)'
assert src.count(old_call) == 1
src = src.replace(old_call,
                  '        im, a = alpha_of(p, luma_ref, mn_floor=unit_mn_floor, edge_mode=unit_edge)')

old_floor = '    unit_mn_floor = int(UNITS.get(unit, {}).get("mn_floor", 135))'
assert src.count(old_floor) == 1
src = src.replace(old_floor,
                  '    unit_mn_floor = int(UNITS.get(unit, {}).get("mn_floor", 135))\n'
                  '    unit_edge = bool(UNITS.get(unit, {}).get("matte_edge", False))')

# 5) 白机身单位开 matte_edge + mig 已有 mn_floor
FLAGS = {
    '"ref": "cold_mig_white.jpg",': '"ref": "cold_mig_white.jpg",\n        "matte_edge": True,',
    '"ref": "mod_marine_white.jpg",': '"ref": "mod_marine_white.jpg",\n        "matte_edge": True,',
    '"ref": "mod_technical_white.jpg",': '"ref": "mod_technical_white.jpg",\n        "matte_edge": True,',
    '"ref": "mod_mlrs_white.jpg",': '"ref": "mod_mlrs_white.jpg",\n        "matte_edge": True,',
    '"ref": "mod_abrams_white.jpg",': '"ref": "mod_abrams_white.jpg",\n        "matte_edge": True,',
}
for k, v in FLAGS.items():
    assert src.count(k) == 1, k
    src = src.replace(k, v)

io.open(p, 'w', encoding='utf-8', newline='').write(src)
print('v6g applied OK')
