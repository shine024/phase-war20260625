# -*- coding: utf-8 -*-
"""生成 72 个补充单位的动画配置:
1. 从 manifest 数组取 id 列表(A28-虎式/B6/E10/POOL29)
2. unified_card_table.gd / manifest / 堡垒表 取中文名
3. 定位卡图 png, 生成白底 _ref/<id>_white.jpg
4. 按类目模板生成 idle/attack prompt
5. 输出 tools/unit_animations_extra.json
"""
import glob
import io
import json
import os
import re

from PIL import Image

MANI = io.open('data/enemy_unit_manifest.gd', encoding='utf-8').read()
UCT = io.open('data/unified_card_table.gd', encoding='utf-8').read()


def seg(name):
    i = MANI.index(name)
    i = MANI.index('[', MANI.index('=', i))
    j = MANI.index(']', i)
    return re.findall(r'"([a-z0-9_]+)"', MANI[i:j])


A = seg('FOE_PLATFORM_CARD_IDS')
B = seg('FOE_SPECIAL_CARD_IDS')
E = seg('FORT_ENEMY_IDS')
P = seg('POOL_ENEMY_IDS')

# unified_card_table display_name
uct_names = dict(re.findall(r'\{"card_id":"([a-z0-9_]+)","display_name":"([^"]+)"', UCT))
# manifest _get_foe_display_name
mf = re.findall(r'"([a-z0-9_]+)":\s*return\s*"([^"]+)"', MANI)
mani_names = dict(mf)
# 堡垒名
fort_names = {
    'ww1_fort_pillbox': '混凝土机枪碉堡', 'ww1_fort_artillery': '要塞炮台',
    'ww2_fort_bunker': '混凝土碉堡', 'ww2_fort_flak': '88mm防空塔',
    'cold_fort_missile': '导弹发射井', 'cold_fort_radar': '雷达站',
    'mod_fort_citadel': '要塞核心', 'mod_fort_phalanx': '近防炮系统',
    'fut_fort_ion': '离子炮台', 'fut_fort_shield': '能量护盾发生器',
}

units = []
def add(uid, art):
    name = (uct_names.get(uid) or mani_names.get(uid) or fort_names.get(uid)
            or uct_names.get(uid.replace('_x', '')) or uid)
    units.append({'key': uid, 'name': name, 'art': art})

for i, uid in enumerate(A):
    if uid == 'ww2_arm_tiger':
        continue  # 已有 ww2_tiger 动画
    add(uid, 'assets/card_icons/enemy/vis_enemy_%03d.png' % (i + 1))
for i, uid in enumerate(B):
    add(uid, 'assets/card_icons/enemy/vis_enemy_%03d.png' % (30 + i))
for i, uid in enumerate(E):
    add(uid, 'assets/card_icons/enemy/vis_enemy_%03d.png' % (72 + i))
for uid in P:
    add(uid, 'assets/card_icons/enemy/%s.png' % uid)

print('units:', len(units))
missing = [u for u in units if not os.path.exists(u['art'])]
print('缺图:', [u['key'] for u in missing])

# ---------- 类目模板 ----------
def cat_of(name, uid):
    s = name + uid
    if any(k in s for k in ('碉堡', '炮台', '发射井', '雷达站', '要塞核心', '近防炮', '离子炮', '护盾发生器')) or '_fort_' in uid:
        return 'fort'
    if any(k in s for k in ('机兵', '机甲', '机动舱')):
        return 'mech'
    if any(k in s for k in ('直升机', '无人机', '无人侦察')):
        return 'air'
    if any(k in s for k in ('舰', '航母', '气球')):
        return 'ship'
    # 名字关键词优先于 id 前缀(ww2_inf_hellcat 是歼击车, mod_inf_technical 是皮卡)
    if any(k in s for k in ('迫击炮', '榴弹', '火炮', '火箭', '自行炮', '岸防', '帕拉丁', '海马斯', 'HIMARS', '野战炮', '防空塔', 'Pak', 'pak', '毫米', '炮组', '反坦克')):
        return 'artillery'
    if any(k in s for k in ('坦克', '歼击', '突击炮', '地狱猫', '狼獾', 'T-72', 'T-55', '谢尔曼', '豹2', '艾布拉姆斯', '马克V', '马克V型')):
        return 'tank'
    if uid in ('fut_inf_storm_rider', 'fut_arm_titan_mk2'):  # B段: 狼獾歼击车/马克V·改
        return 'tank'
    if uid == 'fut_arm_nexus':  # 全装型机动舱(omega 机甲)
        return 'mech'
    if any(k in s for k in ('车', '卡车', '皮卡', '救护', '牵引', '布雷德利', '突击车')):
        return 'vehicle'
    if any(k in s for k in ('班', '兵', '狙击', '组', '队', '斥候', '工兵', '骑兵', '特')):
        return 'infantry'
    if '_inf_' in uid:
        return 'infantry'
    return 'vehicle'

IDLE_TMPL = {
    'infantry': '士兵们保持站立姿态原地待机：身体轻微呼吸起伏，重心微微左右转移，武器握持姿势不变。',
    'vehicle': '车辆原地静止待机：发动机怠速带来车身极轻微颤动，天线轻微摆动，车轮纹丝不动。',
    'tank': '坦克原地静止待机：发动机怠速带来车体极轻微颤动，炮管保持指向画面左侧，履带纹丝不动。',
    'artillery': '火炮原地静止待机：炮架稳定，炮管指向画面左侧微微晃动，炮手们保持待命姿态轻微呼吸。',
    'air': '飞行器原地悬停：机身随气流轻微上下浮动后回到初始高度，旋翼或推进器保持清晰实体桨叶，绝不画成半透明模糊圆盘。',
    'ship': '舰船原地悬浮待机：舰体随波浪轻微起伏后回位，上层建筑灯光闪烁。',
    'mech': '机甲原地站立不动：伺服系统带来装甲板极轻微震颤，关节指示灯闪烁，头部微幅扫描环视。',
    'fort': '固定建筑原地待机：结构纹丝不动，仅观察窗灯光与指示灯闪烁，雷达天线缓慢旋转，炮塔极缓慢左右微摆。',
}
ATTACK_TMPL = {
    'infantry': '士兵们向画面左侧连续射击：枪口火光清晰可见地连续闪烁，枪身后坐，弹壳向右后方抛出，无烟雾弥漫，背景保持纯白。',
    'vehicle': '车载武器向画面左侧连续射击：枪口火光连续闪烁，车身轻微后坐震动，弹壳或弹链运动，无烟雾弥漫。',
    'tank': '主炮向画面左侧开火：炮口火光大幅闪现并伴随炮管明显后坐，车体震颤，随后炮口焰消散恢复。',
    'artillery': '火炮向画面左侧开火：炮口火光闪现，炮管后坐，弹丸向画面左上方射出，炮手们配合操作，无烟雾弥漫，背景保持纯白。',
    'air': '飞行器向画面左侧开火：武器挂点火光连续闪现，弹药轨迹射向画面左侧，机身轻微后坐浮动。',
    'ship': '舰船向画面左侧开火：舰炮火光闪现并后坐，全舰轻微震动。',
    'mech': '机甲向画面左侧开火：武器臂发射口火光连续闪现，能量弹道射向画面左侧，机甲整体随之后坐轻微摇晃然后稳定。',
    'fort': '堡垒炮塔向画面左侧开火：炮口火光大幅闪现并伴随后坐，建筑主体轻微震动，随后火光消散。',
}

FIX_HEAD = ('严格保持首帧图像中该单位的外观、比例、涂装与细节完全一致，不改变设计。'
            '该单位始终保持首帧的朝向，武器指向画面左侧，绝不掉头，绝不转向。'
            '严格2D游戏精灵风格，平面正交正侧视。')
FIX_TAIL_IDLE = ('镜头完全锁定，无运镜，无变焦，无平移，单位始终完整在画面内不被裁切。'
                 '纯白色无缝背景，无地面，无阴影，无文字，无水印。'
                 '动作结尾精确回到起始姿态，首尾帧一致，动作平滑无缝循环。')
FIX_TAIL_ATK = ('镜头完全锁定，无运镜，无变焦，单位始终完整在画面内。'
                '纯白色无缝背景，无地面，无阴影，无文字，无水印。')

REF_DIR = r'资料/单位分帧动画/_ref'
os.makedirs(REF_DIR, exist_ok=True)

cfg = {}
for u in units:
    c = cat_of(u['name'], u['key'])
    cfg[u['key']] = {
        'name': u['name'],
        'ref': u['key'] + '_white.jpg',
        'art': u['art'],
        'category': c,
        'air': c in ('air', 'ship'),
        'anims': {
            'idle': {'seconds': '4', 'prompt': FIX_HEAD + IDLE_TMPL[c] + FIX_TAIL_IDLE},
            'attack': {'seconds': '5', 'prompt': FIX_HEAD + ATTACK_TMPL[c] + FIX_TAIL_ATK},
        },
    }
    # 白底参考图
    ref_path = os.path.join(REF_DIR, u['key'] + '_white.jpg')
    if not os.path.exists(ref_path):
        im = Image.open(u['art']).convert('RGBA')
        bg = Image.new('RGB', im.size, (255, 255, 255))
        bg.paste(im, (0, 0), im)
        bg = bg.resize((512, 512), Image.LANCZOS)
        bg.save(ref_path, quality=92)

io.open('tools/unit_animations_extra.json', 'w', encoding='utf-8').write(
    json.dumps(cfg, ensure_ascii=False, indent=1))
print('refs + json done:', len(cfg))
from collections import Counter
print(Counter(v['category'] for v in cfg.values()))
for k, v in list(cfg.items())[:6]:
    print(' ', k, v['name'], v['category'], v['air'])
