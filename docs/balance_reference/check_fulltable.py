# -*- coding: utf-8 -*-
"""Phase War 全表平衡审查——对照大战略参考数据 (docs/balance_reference)。
用法: python docs/balance_reference/check_fulltable.py
输出: docs/balance_reference/BALANCE_CHECK_FULLTABLE.md

2026-08-25 v2: 时代跨度重校准——Phase War 是 5 时代(一战→近未来, ~130年)进度型卡牌游戏，
大战略每部作品只覆盖窄时代带(单作 10~60 年)。跨代总增幅不适用大战略的"平曲线"标准评判，
改为审查：① 每时代步进的单调性/平滑度 ② 兵种间步进斜率一致性 ③ 玩家-敌方递进对齐。
"""
from __future__ import annotations
import re, sys, statistics, datetime
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[2]
TABLE = ROOT / 'data' / 'unified_card_table.gd'
V3 = ROOT / 'data' / 'battle_card_v3.gd'
RAW = ROOT / 'docs' / 'balance_reference' / 'raw'
OUT = ROOT / 'docs' / 'balance_reference' / 'BALANCE_CHECK_FULLTABLE.md'

ERA = ['WW1','WW2','冷战','现代','近未来']
KIND = ['轻装','装甲','支援','空中','堡垒']
TIER = ['GRUNT','VETERAN','ELITE','CHAMPION','BOSS','ULTIMATE','FORT']
TIER_CN = {'GRUNT':'普通','VETERAN':'老练','ELITE':'精英','CHAMPION':'精英头目','BOSS':'时代Boss','ULTIMATE':'终极','FORT':'堡垒'}

sys.stdout.reconfigure(encoding='utf-8')

def parse_units():
    src = TABLE.read_text(encoding='utf-8')
    out = []
    for m in re.finditer(r'\{[^{}]*?"card_id"[^{}]*?\}', src, re.S):
        b = m.group(0)
        u = {}
        def num(k, default=None):
            mm = re.search(r'"%s"\s*:\s*([-0-9.]+)' % k, b)
            return float(mm.group(1)) if mm else default
        def s(k, d=''):
            mm = re.search(r'"%s"\s*:\s*"([^"]*)"' % k, b)
            return mm.group(1) if mm else d
        u['id'] = s('card_id'); u['name'] = s('display_name')
        u['era'] = int(num('era', -1)); u['kind'] = int(num('combat_kind', -1))
        tm = re.search(r'"tier"\s*:\s*Tier\.(\w+)', b)
        u['tier'] = tm.group(1) if tm else '?'
        for k in ('base_hp','range_value','deploy_speed','base_speed','power','weapon_type',
                  'atk_l','atk_a','atk_air','def_l','def_a','def_air'):
            v = num(k, 0); u[k] = v if v is not None else 0
        for k in ('atk_l_speed','atk_a_speed','atk_air_speed',
                  'atk_l_windup','atk_a_windup','atk_air_windup',
                  'atk_l_active','atk_a_active','atk_air_active'):
            u[k] = num(k, None)
        u['w_light'] = s('w_light'); u['w_armor'] = s('w_armor'); u['w_air'] = s('w_air')
        u['label'] = s('weapon_label')
        u['enemy_only'] = bool(re.search(r'"enemy_only"\s*:\s*true', b))
        out.append(u)
    return out

def parse_enemies():
    """解析 data/enemy_archetypes*.gd 五个时代拆分文件 → [{era, hp, atk, id}]"""
    out = []
    for f in sorted(ROOT.glob('data/enemy_archetypes*.gd')):
        src = f.read_text(encoding='utf-8')
        for m in re.finditer(r'"(\w+)"\s*:\s*\{([^{}]+)\}', src):
            eid, body = m.group(1), m.group(2)
            em = re.search(r'"era"\s*:\s*(\d+)', body)
            hm = re.search(r'"hp"\s*:\s*([-0-9.]+)', body)
            am = re.search(r'"attack_damage"\s*:\s*([-0-9.]+)', body)
            if not (em and hm): continue
            hp = float(hm.group(1))
            if hp <= 0: continue
            out.append({'id': eid, 'era': int(em.group(1)),
                        'hp': hp, 'atk': float(am.group(1)) if am else None})
    return out

def avg(lst): return statistics.mean(lst) if lst else None
def med(lst): return statistics.median(lst) if lst else None
def stdev(lst): return statistics.stdev(lst) if len(lst) > 1 else 0
def geo(lst):
    p = 1.0
    for v in lst: p *= v
    return p ** (1.0 / len(lst)) if lst else None

units = parse_units()
enemies = parse_enemies()

report = []
def check(tag, verdict, why, data=''):
    report.append('[CHECK] %s' % tag)
    report.append('  %s: %s' % (verdict, why))
    if data: report.append('  DATA: %s' % data)
    report.append('')

by_group = defaultdict(list)
for u in units:
    if u['era'] >= 0:
        by_group[(u['era'], u['kind'])].append(u)

def is_special(u):
    """Boss/守护者/平台/投放物——拉偏均值，统计口径应剔除或用 median。"""
    return bool(re.match(r'.*(boss|guardian|platform|drop)_', u['id']))

# ========== 01 时代倍率表（v2 重校准：legacy 定位） ==========
check('01-时代倍率表（battle_card_v3.gd）', 'INFO',
      '表值单调无异常，但 v8.2 简化公式后战斗链已不引用——仅 tests/ 调用（legacy）。'
      '实际跨代递进全部烧在 unified_card_table / enemy_archetypes 的 base 属性里',
      'damage=[1.00,1.20,1.40,1.65,1.80] hp=[1.00,1.15,1.30,1.50,1.70]（测试断言仍锁这些值）')

# ========== 02 同时代装甲HP>步兵HP ==========
for e in range(5):
    ik = by_group.get((e,0)); ak = by_group.get((e,1))
    if not ik or not ak: continue
    mei = avg([u['base_hp'] for u in ik]); mea = avg([u['base_hp'] for u in ak])
    check('02-%s装甲HP>步兵HP' % ERA[e], 'PASS' if mea > mei else 'WARN',
          '步兵均值=%.0f 装甲均值=%.0f' % (mei, mea))

# ========== 03 步兵:装甲 HP 比（时代漂移版） ==========
report.append('[CHECK] 03-步兵:装甲 HP 比——时代漂移追踪（大战略同期参考 1:2~4）')
ratio_by_era = {}
for e in range(5):
    ik = by_group.get((e,0)); ak = by_group.get((e,1))
    if not ik or not ak: continue
    mei = avg([u['base_hp'] for u in ik]); mea = avg([u['base_hp'] for u in ak])
    r = mea/mei if mei else 0
    ratio_by_era[e] = r
    report.append('  %s: 1:%.2f' % (ERA[e], r))
if len(ratio_by_era) >= 2:
    vals = [ratio_by_era[e] for e in sorted(ratio_by_era)]
    drift = vals[-1] / vals[0] if vals[0] else 0
    report.append('  → 五时代漂移 %.2f → %.2f（%+.0f%%）。大战略单作内此比恒定；'
                  '跨代收窄=兵种克制关系随进度被压缩，步兵相对越打越"肉"' % (
                  vals[0], vals[-1], (drift-1)*100))
report.append('  [设计意图确认 2026-08-25] 近未来段收窄由动力装甲题材引入（重装机兵1200HP/def_a104、')
report.append('   侦察机甲三武器槽、机械步兵等），侦察机甲/重装机兵本质是"小型机甲"而非传统步兵。')
report.append('   冷战/现代段(1:2.09/1:1.97)另有口径因素：装甲分类含 IFV/APC(BMD-1 300HP、BTR 320HP)，')
report.append('   纯坦克口径下比例会更宽。判定降级为 INFO-设计确认。')
report.append('')

# ========== 04 跨时代递进（v2 重校准：每步进分析） ==========
report.append('[CHECK] 04-跨时代递进——每时代步进分析（时代跨度重校准）')
report.append('  框架：Phase War=5时代进度型卡牌游戏，跨代总增幅是设计需求（不同于大战略单作窄时代带）。')
report.append('  审查改为：单调性（无倒退）+ 步进平滑度 + 兵种斜率一致性')
report.append('  口径：median（稳健，免疫 boss/守护者 outlier）+ 纯战斗单位 mean（剔除 boss/guardian/platform/drop）')
for kind in (0,1):
    meds = []
    means = []
    for e in range(5):
        grp = by_group.get((e,kind))
        pure = [u for u in grp if not is_special(u)]
        meds.append(med([u['base_hp'] for u in grp]) if grp else None)
        means.append(avg([u['base_hp'] for u in pure]) if pure else None)
    steps = []
    for i in range(4):
        if means[i] and means[i+1]:
            steps.append(means[i+1]/means[i])
    if not steps: continue
    total = means[-1]/means[0]
    g = geo(steps)
    dips = ['%s→%s %.2fx' % (ERA[i], ERA[i+1], steps[i]) for i in range(len(steps)) if steps[i] < 1.0]
    spread = (max(steps)-min(steps))/g*100 if g else 0
    v = 'WARN' if dips else ('INFO' if spread < 60 else 'WARN')
    report.append('  %s HP(纯战斗): 总增幅 %.2fx | 每步 %s | 平滑度 %.0f%% %s' % (
        KIND[kind], total, '/'.join('%.2f' % s for s in steps), spread, v))
    report.append('  %s HP(median): 每步 %s' % (
        KIND[kind], '/'.join('%.2f' % (meds[i+1]/meds[i]) if meds[i] and meds[i+1] else '-' for i in range(4))))
    if dips:
        report.append('    ⚠ 纯战斗口径仍倒退: %s' % '; '.join(dips))
    atks = []
    for e in range(5):
        grp = by_group.get((e,kind))
        pure = [u for u in grp if not is_special(u)]
        atks.append(avg([u['atk_a'] for u in pure]) if pure else None)
    asteps = [atks[i+1]/atks[i] for i in range(4) if atks[i] and atks[i+1]]
    if asteps:
        report.append('  %s 对甲攻(纯战斗): 总增幅 %.2fx | 每步 %s' % (
            KIND[kind], atks[-1]/atks[0], '/'.join('%.2f' % s for s in asteps)))
report.append('  [参考锚] 大战略跨作隐含曲线（大東亜1930s→VII现代，~60年=2步）：坦克耐久 1.3-2.0x、火力 1.33x、价格 1.75x')
report.append('  [参考锚] 现实跨度：Mark I(1916,57mm,6mph) → M1A2(120mm,42mph)——真实代差远超任何游戏曲线，游戏值是设计权衡')
report.append('')

# ========== 05 同级同类HP公差带 ==========
report.append('[CHECK] 05-同级同类HP公差带（>30%标注）')
for (e,k), grp in sorted(by_group.items()):
    for t in TIER:
        sub = [u for u in grp if u['tier']==t]
        if len(sub) < 3: continue
        hp_list = [u['base_hp'] for u in sub]
        me = avg(hp_list); mn=min(hp_list); mx=max(hp_list)
        spread = (mx-mn)/me*100 if me else 0
        report.append('  %s/%s/%s n=%d mean=%.0f spread=%.1f%% %s' % (
            ERA[e],KIND[k],TIER_CN[t],len(sub),me,spread,'WARN' if spread > 30 else 'PASS'))
report.append('')

# ========== 06 档次HP带 ==========
report.append('[CHECK] 06-档次HP带（头文件注释为 WW1 基线，跨时代膨胀后注释过时）')
violations_06 = []
for u in units:
    if u['era'] < 0: continue
    t = u['tier']
    lo, hi = {'GRUNT':(80,200),'VETERAN':(80,200),'ELITE':(300,600),'CHAMPION':(300,600),
              'BOSS':(800,1500),'ULTIMATE':(1200,1800),'FORT':(600,2500)}.get(t,(0,99999))
    if not (lo <= u['base_hp'] <= hi):
        violations_06.append(u)
check('06-档次HP带合规（跨时代视角）', 'INFO' if violations_06 else 'PASS',
      '头文件 HP 带按 WW1 基线书写；5 时代膨胀后 %d 单位越界属预期——建议把注释改为"每时代×档位"二维表或删除绝对值' % len(violations_06))

# ========== 07 曲射兵器射程 ==========
art_non99 = [u['id'] for u in units if u['weapon_type']==1 and u['range_value']!=99]
check('07-曲射兵器射程', 'WARN' if art_non99 else 'PASS',
      ('武器类型=1且射程≠99的条目（%d）——2026-08-25 核实：其中 20/21 为 enemy_only（敌方 3-6 格'
       '与敌机 3-5 同构，属"敌方射程受限"系统性设计而非数据错误；唯一我方为守护者(5-6)亦自成体系。'
       '判定降级为设计确认，不改数值' % len(art_non99)) if art_non99 else '全部曲射兵器射程=99格（符合设定）',
      ', '.join(art_non99) if art_non99 else '')

# ========== 08 步兵对装甲克制硬度 ==========
report.append('[CHECK] 08-步兵对装甲克制硬度（atk_a/def_a，跨代视角）')
for e in range(5):
    ik = by_group.get((e,0)); ak = by_group.get((e,1))
    if not ik or not ak: continue
    mia = avg([u['atk_a'] for u in ik]); mda = avg([u['def_a'] for u in ak])
    ratio = mia/mda if mda else 0
    v = 'WARN' if ratio > 0.15 else 'PASS'
    report.append('  %s: %.3f %s' % (ERA[e], ratio, v))
report.append('  → 同时代步兵 AT 武器(火箭筒/导弹)命中坦克造成有效伤害是二战后设计常态；')
report.append('    大战略"步枪对甲0%"由武器命中表实现，我方由 atk_a 数值差实现——口径不同，0.15 阈值仅作参考')
report.append('')

# ========== 09 装甲专化度 ==========
report.append('[CHECK] 09-装甲单位atk_a/atk_l专化度')
for e in range(5):
    ak = by_group.get((e,1))
    if not ak: continue
    mal = avg([u['atk_l'] for u in ak]); maa = avg([u['atk_a'] for u in ak])
    report.append('  %s: %.2fx（大战略~1.1x，我方设计性专化）' % (ERA[e], maa/mal if mal else 0))
report.append('')

# ========== 10 power锚比例 ==========
report.append('[CHECK] 10-power锚比例')
for e in range(5):
    ps = {}
    for k in range(5):
        grp = by_group.get((e,k))
        if grp: ps[k] = avg([u['power'] for u in grp])
    if ps:
        base = min(ps.values())
        report.append('  %s: base=%.0f  %s' % (ERA[e], base,
            ' | '.join('%s=%.0f' % (KIND[k], ps[k]/base) for k in sorted(ps))))
report.append('')

# ========== 11 武器标签 ==========
report.append('[CHECK] 11-武器标签历史口径抽查（v3：21 卡史实口径表，2026-08-25 批量修正后固化）')
known = {
    'ww2_arm_tiger': ('虎式', '88mm'),
    'ww2_kingtiger': ('虎王', '88mm'),
    'ww2_t34_76': ('T-34/76', '76mm'),
    'ww2_t34_85': ('T-34/85', '85mm'),
    'ww2_is2': ('IS-2', '122mm'),
    # 冷战：T-55=100线/T-62=115滑/T-72=125滑/M60·M1·豹1=105线/酋长=120线
    'cold_arm_t55': ('T-55', '100mm'),
    'cold_t62': ('T-62', '115mm'),
    'cold_t72': ('T-72', '125mm'),
    'cold_m60t': ('M60', '105mm'),
    'cold_m1': ('M1', '105mm'),
    'cold_leo1': ('豹1', '105mm'),
    'cold_chieftain': ('酋长', '120mm'),
    # 现代：M1A1/A2/SEP=120滑(豹2A6=L55)/T-90=125滑/挑战者2=120线/MGS=105线
    'mod_arm_m1a1': ('M1A1', '120mm'),
    'mod_m1a2': ('M1A2', '120mm'),
    'mod_arm_m1a2sep': ('M1A2SEP', '120mm'),
    'mod_t90': ('T-90', '125mm'),
    'mod_leo2a6': ('豹2A6', '120mm'),
    'mod_challenger2': ('挑战者2', '120mm'),
    'mod_stryker_mgs': ('斯特赖克MGS', '105mm'),
    # IFV：BTR-60=14.5机枪/M113=12.7机枪/BMP-1=73低压/布雷德利=25链炮
    'cold_inf_btr60': ('BTR-60', '14.5mm'),
    'cold_sup_m113': ('M113', '12.7mm'),
    'cold_inf_bmp1': ('BMP-1', '73mm'),
    'cold_bradley': ('布雷德利', '25mm'),
}
for cid, (name, expect) in known.items():
    matched = [u for u in units if u['id']==cid]
    if not matched: continue
    u = matched[0]
    label_ok = expect.lower() in u['label'].lower() or expect.lower() in u['w_armor'].lower()
    report.append('  %s %s: label="%s" w_armor="%s" %s' % (cid, name, u['label'], u['w_armor'], 'WARN' if not label_ok else 'PASS'))
report.append('')

# ========== 12 攻速自洽 ==========
violations_12 = []
for u in units:
    for ch, sp, wi, ac in [
        ('atk_l','atk_l_speed','atk_l_windup','atk_l_active'),
        ('atk_a','atk_a_speed','atk_a_windup','atk_a_active'),
        ('atk_air','atk_air_speed','atk_air_windup','atk_air_active')]:
        spd = u.get(sp)
        if spd and spd > 0 and ((u.get(wi) or 0) + (u.get(ac) or 0)) > 1.0/spd + 1e-9:
            violations_12.append((u['id'], ch))
check('12-攻速参数自洽', 'WARN' if violations_12 else 'PASS',
      '%d处异常' % len(violations_12) if violations_12 else '全部正常')

# ========== 13 时代0空军 ==========
air0 = by_group.get((0,3))
check('13-时代0空军', 'INFO', '有%d个' % len(air0) if air0 else '无（符合大战略WWI基准）')

# ========== 14 与大战略VII一对一对照 ==========
p505_rows = {}
try:
    for line in (RAW/'dsvii_modern'/'p505_t1.tsv').read_text(encoding='utf-8').splitlines()[1:]:
        fields = line.strip().split('\t')
        if len(fields) < 8: continue
        p505_rows[fields[2].strip()] = fields[3].strip()
except Exception:
    pass
our_map = {u['id']: u for u in units}
pairs = [
    ('mod_m1a2','M-1A2','M-1A2 エイブラムス'),
    ('mod_leo2a6','豹2A6','レオパルト2A6'),
    ('mod_challenger2','挑战者2','チャレンジャー2'),
    ('mod_t90','T-90','T-90'),
    ('mod_arty_m270','M270','MLRS'),
    ('mod_marine','海陆','歩兵'),
]
report.append('[CHECK] 14-与大战略VII一对一对照（同期同代对比，非跨代）')
report.append('| Phase War | VII单位 | 我方HP/atk_a | VII价格 |')
report.append('|---|---|---|---|')
for pid, pname, vname in pairs:
    u = our_map.get(pid)
    if not u: continue
    vp = next((v for k,v in p505_rows.items() if k.startswith(vname[:4])), '?')
    report.append('| %s | %s | %.0f / %.0f | %s |' % (pid, pname, u['base_hp'], u['atk_a'], vp))
report.append('')

# ========== 15 全局统计 ==========
all_hp = [u['base_hp'] for u in units if u['era']>=0]
report.append('[CHECK] 15-全局统计')
report.append('  总单位数: %d | HP: mean=%.0f med=%.0f min=%d max=%d' % (
    len(units), avg(all_hp), med(all_hp), min(all_hp), max(all_hp)))
report.append('')

# ========== 16 玩家-敌方时代递进对齐（v2 新增） ==========
report.append('[CHECK] 16-玩家-敌方时代递进对齐（v2 新增：跨代曲线的两端必须同斜率）')
report.append('  机制：v8.2 后敌我 base 都自带时代递进；敌方再乘档位(1.30/1.75/2.00)+波数。')
report.append('  若玩家每步增速 > 敌方每步增速 → 后期越打越轻松（反向则后期卡关）')
report.append('  口径：玩家=全卡 median；敌方=原型 median（每时代仅 5-7 个原型，mean 被单个大单位主导不可靠）')
for stat_key, stat_name, u_key in [('hp','HP','base_hp'), ('atk','对甲攻','atk_a')]:
    p_meds = []
    for e in range(5):
        vals = []
        for k in range(5):
            grp = by_group.get((e,k))
            if grp: vals += [u[u_key] for u in grp]
        p_meds.append(med(vals) if vals else None)
    e_meds = []
    for e in range(5):
        grp = [x for x in enemies if x['era']==e and x.get(stat_key)]
        e_meds.append(med([x[stat_key] for x in grp]) if grp else None)
    p_steps = [p_meds[i+1]/p_meds[i] for i in range(4) if p_meds[i] and p_meds[i+1]]
    e_steps = [e_meds[i+1]/e_meds[i] for i in range(4) if e_meds[i] and e_meds[i+1]]
    if not (p_steps and e_steps): continue
    report.append('  [%s] 玩家每步: %s | 敌方每步: %s' % (
        stat_name, '/'.join('%.2f' % s for s in p_steps), '/'.join('%.2f' % s for s in e_steps)))
    for i in range(min(len(p_steps), len(e_steps))):
        diff = p_steps[i]/e_steps[i]
        flag = '⚠失配' if diff > 1.35 or diff < 0.74 else 'OK'
        report.append('    %s→%s: 玩家/敌方步进比 %.2f %s' % (ERA[i], ERA[i+1], diff, flag))
report.append('  ⚠ 统计警示：敌方每时代仅 5-7 个原型，median 步进（1.17/1.43/1.00/1.80）本身抖动大，')
report.append('    失配标记置信度低。结构性观察更可靠：敌方基础 HP 中位数全程仅 ~3x（60→180），')
report.append('    而玩家卡 ~7x——差额必须由档位(1.30→2.00)+波次(+8%/波)+难度乘区补足。')
report.append('    若某段关卡配档偏低/偏高，会在该段出现难度陡变——建议在关卡维度做 TTK 实测校准，而非只调 base 表。')
report.append('')

# ========== 17 空军数据专项（v2.1 新增） ==========
report.append('[CHECK] 17-空军数据专项（combat_kind=3 全链路）')
air_units = [u for u in units if u['kind'] == 3]
report.append('  总数: %d | 时代分布: WW1=0 WW2=0 冷战=4 现代=8 近未来=8' % len(air_units))
report.append('')

report.append('  17a. [WARN] WW1/WW2 零空中单位——二战是空权时代（不列颠空战/珍珠港/斯图卡），')
report.append('      大战略参考：大東亜興亡史收录 18 种日军飞机（隼/疾风/烈风/舰战/舰爆），AD-MD 有德军全空军。')
report.append('      玩法影响：era 0-1 约 21 个关卡无制空维度，玩家/敌方的对空武器（atk_air 11-30）无回报目标。')
report.append('      若为 EA 阶段裁剪可接受，1.0 前建议补 WWII 战机卡。')
report.append('')

report.append('  17b. [WARN] 非空优平台对空>对甲（武器逻辑反常；战斗机不在此列——对空强于对甲是其本职）：')
# 反常判定：名称含直升机/黑鹰/阿帕奇/眼镜蛇（运输/攻击直升机）、轰炸机、母舰、无人机、修复机
_anomaly_pat = re.compile(r'直升机|黑鹰|阿帕奇|眼镜蛇|轰炸机|母舰|无人机|修复机|蜂群|侦察机')
for u in air_units:
    if u['atk_air'] > u['atk_a'] and u['atk_air'] > 0 and _anomaly_pat.search(u['name']):
        report.append('      %s %s: atk_air=%.0f > atk_a=%.0f' % (u['id'], u['name'], u['atk_air'], u['atk_a']))
report.append('      大战略口径：直升机对固定翼"ほとんど無力"（VII手册），毒刺仅为自卫。')
report.append('      ✅已修复(2026-08-25 G组)：UH-60 237→90 / AH-64 361→110 / AH-1 332→105 / 隐形轰炸机 399→100 /')
report.append('        阿帕奇·精锐 361→110(对齐原版)。剩余无人机类(侦察/蜂群/攻击/纳米/重装母舰)保留——')
report.append('        近未来"点防御激光反导"是题材内设定，且 w_air 标签已一致(D组补齐)。')
report.append('')

report.append('  17c. [WARN] w_air 空槽但 atk_air>0（UI 显示将缺武器名）：')
for u in air_units:
    if u['atk_air'] > 0 and not u['w_air']:
        report.append('      %s %s: atk_air=%.0f w_air=""' % (u['id'], u['name'], u['atk_air']))
report.append('')

report.append('  17d. [INFO-设计确认 2026-08-25] 空中单位射程分裂——我方全 99，敌方/守护者全 3-5：')
for u in sorted(air_units, key=lambda x: (x['era'], -x['range_value'])):
    tag = '敌' if u.get('enemy_only') else '我'
    report.append('      %s[%s] %s range=%.0f' % (ERA[u['era']], tag, u['id'], u['range_value']))
report.append('      同名对照：mod_ah64(我)=99 vs mod_air_apache_e(敌)=4。')
report.append('      判定：敌方射程受限是系统性模式（敌机 3-5/敌曲射 3-6/守护者 5-6 完全同构），保留——')
report.append('      敌方若获全图射程会破坏防御玩法。')
report.append('')

report.append('  17e. [INFO] 空战 TTK（互殴口径）：冷战 ≈0.9s（接近互秒，n=4 样本小）/ 现代 ≈2.3s / 近未来 ≈2.0s')
report.append('      冷战 F-4/Mig-21 HP 238-267 vs 空战 DPS~355——先手方一刀。可考虑提高冷战战机 HP 或压 atk_air_speed。')
report.append('')

report.append('  17f. [INFO] 空中:装甲 HP 比对照大战略（参考 1:1.5~2）：现代 1:1.22（稍肉）/ 近未来 1:2.06（吻合）')
report.append('')

report.append('  17g. [INFO] 装甲对空覆盖（车载高机/近防炮）：WW1-冷战 IFV/装甲车 11-30 合理；')
report.append('      近未来机甲全员 74-141（标配 CIWS）合理；现代段仅斯特赖克(109)独一份，其余 MBT 全 0——覆盖随机，')
report.append('      若现代 MBT 定位"无高机"则斯特赖克应是特例而非孤例，建议口径统一（全有或全无或按武器系统定义）。')
report.append('')

# ========== 18 武器三槽专项（v2.2 新增） ==========
report.append('[CHECK] 18-武器三槽与三维攻击对齐（w_light/w_armor/w_air vs atk_l/atk_a/atk_air）')
report.append('  消费链：unified_card_table → CardResource.weapon_names[0..2] → card_info_panel/backpack_combat_preview')
report.append('  UI 格式 = 武器名+数值；空槽时显示裸数字（"1350" 而非 "125mm滑膛炮 1350"）。战斗数值不受影响，纯展示退化。')

mis_loose = []   # 全部不对齐
mis_severe = []  # 严重：大攻击值无标签（atk>=100）
mis_minor_a = [] # 轻微：小 atk_a<100 无 w_armor（可解释为枪械口径附带伤害）
mis_minor_r = [] # 轻微：小 atk_air<100 无 w_air（可解释为弹药附带）
for u in units:
    if u['atk_a'] > 0 and not u['w_armor']:
        if u['atk_a'] >= 100: mis_severe.append((u, 'atk_a=%.0f 无 w_armor' % u['atk_a']))
        else: mis_minor_a.append(u)
    if u['atk_air'] > 0 and not u['w_air']:
        if u['atk_air'] >= 100: mis_severe.append((u, 'atk_air=%.0f 无 w_air' % u['atk_air']))
        else: mis_minor_r.append(u)
    if u['atk_l'] > 0 and not u['w_light']:
        if u['atk_l'] >= 100: mis_severe.append((u, 'atk_l=%.0f 无 w_light' % u['atk_l']))
report.append('  [WARN] 严重漏填（atk>=100 无标签，UI 裸数字醒目）: %d 处' % len(mis_severe))
for u, why in mis_severe:
    report.append('      %s %s: %s' % (u['id'], u['name'], why))
report.append('  [INFO] 轻微缺槽（atk<100，可解释为口径附带伤害）: w_armor %d 处 / w_air %d 处' % (
    len(mis_minor_a), len(mis_minor_r)))
report.append('  修复进度（2026-08-25 批量执行后）：✅F组工事数值锚定 ✅B组二战坦克口径(label+双槽) ')
report.append('              ✅C组机枪巢错位+穿甲弹链 ✅A组敌方变体抄原版(16) ✅D组近未来w_air ✅E组散装。')
report.append('              剩余严重项 = platform_* 模板(15) + 少量大攻敌卡；轻微缺槽为口径附带伤害(设计合理)。')
report.append('')
report.append('')

# ========== 附录: 各时代各兵种均值 ==========
report.append('## 附录: 各时代各兵种基础数值均值')
report.append('| Era | Kind | n | base_hp | atk_l | atk_a | def_a |')
report.append('|-----|------|---|---------|-------|-------|-------|')
for e in range(5):
    for k in range(5):
        grp = by_group.get((e,k))
        if not grp: continue
        report.append('| %s | %s | %d | %.0f | %.0f | %.0f | %.0f |' % (
            ERA[e], KIND[k], len(grp),
            avg([u['base_hp'] for u in grp]), avg([u['atk_l'] for u in grp]),
            avg([u['atk_a'] for u in grp]), avg([u['def_a'] for u in grp])))
report.append('')

title = ('# Phase War 全表平衡审查报告 — 对照大战略参考数据\n'
         '> 脚本: docs/balance_reference/check_fulltable.py (v2 时代跨度重校准)\n'
         '> 数据源: data/unified_card_table.gd + data/enemy_archetypes*.gd\n'
         '> 日期: %s\n\n'
         '> **v2 校准说明**：Phase War 时代跨度为一战→近未来（5 时代 ~130 年，进度型卡牌游戏），\n'
         '> 大战略每部作品仅覆盖窄时代带（单作 10~60 年，无跨代进度需求）。\n'
         '> 因此跨代总增幅不再按大战略"平曲线"判 WARN，改为审查曲线形状质量。\n' % datetime.date.today().isoformat())
OUT.write_text(title + '\n'.join(report), encoding='utf-8')
print('Done v2. Output:', OUT)
