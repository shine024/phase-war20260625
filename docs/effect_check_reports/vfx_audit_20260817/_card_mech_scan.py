# -*- coding: utf-8 -*-
# 敌方/我方战斗卡机制分布 + 数值异常扫描（审查用，只读不改）
import re, json, sys
from collections import Counter, defaultdict

SRC = r"F:/godot fair duet/create/phase-war/data/unified_card_table.gd"
text = open(SRC, encoding="utf-8").read()
# 剥离注释行（条目间穿插的 # 注释会打断条目切分）
text = re.sub(r'(?m)^\s*#[^\n]*\n', '', text)

# 提取 {...} 卡条目（兼容空行分隔与紧邻分隔两种排版；tier 为 Tier.XXX 枚举引用）
entries = []
pattern = re.compile(r'\{"card_id":"([^"]+)"(.*?)\},(?=\s*\n\s*\{)', re.S)
TIER_ENUM = {"Tier.GRUNT":0,"Tier.VETERAN":1,"Tier.ELITE":2,"Tier.CHAMPION":3,"Tier.BOSS":4,"Tier.ULTIMATE":5,"Tier.FORT":6}
for m in pattern.finditer(text):
    cid, body = m.group(1), m.group(2)
    d = {"card_id": cid}
    for km in re.finditer(r'"([a-z_0-9]+)":\s*("[^"]*"|Tier\.\w+|[^,\n]+)', body):
        k, v = km.group(1), km.group(2).strip()
        if v.startswith('"'):
            d[k] = v[1:-1]
        elif v in TIER_ENUM:
            d[k] = TIER_ENUM[v]
        else:
            try:
                d[k] = float(v) if '.' in v else int(v)
            except ValueError:
                d[k] = v
    entries.append(d)
# 兜底：最后一组条目（其后是 ] 而非下一个条目）
tail = text.rfind('"card_id"')
if tail != -1:
    i = text.rfind('{"card_id"', 0, tail + 200)
    if i != -1:
        j = text.find('},', i)
        if j != -1:
            seg = text[i:j+1]
            cid = re.match(r'\{"card_id":"([^"]+)"', seg).group(1)
            if not any(e['card_id'] == cid for e in entries):
                d = {"card_id": cid}
                for km in re.finditer(r'"([a-z_0-9]+)":\s*("[^"]*"|Tier\.\w+|[^,\n]+)', seg):
                    k, v = km.group(1), km.group(2).strip()
                    if v.startswith('"'): d[k] = v[1:-1]
                    elif v in TIER_ENUM: d[k] = TIER_ENUM[v]
                    else:
                        try: d[k] = float(v) if '.' in v else int(v)
                        except ValueError: d[k] = v
                entries.append(d)

print(f"parsed entries: {len(entries)}")

TIER_NAMES = {0:"GRUNT",1:"VETERAN",2:"ELITE",3:"CHAMPION",4:"BOSS",5:"ULTIMATE",6:"FORT"}
KIND_NAMES = {0:"轻装",1:"装甲",2:"支援",3:"空中",4:"堡垒"}
ERA_NAMES = {0:"一战",1:"二战",2:"冷战",3:"现代",4:"近未来"}

# ── 模拟 default_cards._infer_unit_subtype ──
def infer_subtype(ck, rng, al, aa, aair):
    if ck == 4: return "FORT"
    if ck == 2:
        if aair > al and aair > aa and aair > 0: return "ANTI_AIR"
        if rng >= 99 or (aa >= al and aa > 0): return "ARTILLERY"
        return "SUPPORT"
    return "NONE"

# ── 模拟 unit_stats_table._apply_v8_unit_type_meta 的前缀匹配（v8.7 收紧后口径）──
def special_matches(cid):
    cid = cid.lower()
    out = []
    if "stalker" in cid or "stealth" in cid or "spectre" in cid or "recon" in cid: out.append("stalker")
    if "engineer" in cid or "support" in cid or "combat_eng" in cid: out.append("engineer")
    if "ecm" in cid or "jammer" in cid or "growler" in cid or "electronic" in cid: out.append("ecm")
    if "sniper" in cid or "marksman" in cid or "spetsnaz" in cid: out.append("sniper")
    return out

# ── 模拟 apply_combat_kind_modifiers 固定机制 ──
def fixed_mechs(e):
    ck = e.get("combat_kind"); sub = infer_subtype(ck, e.get("range_value",0),
        e.get("atk_l",0), e.get("atk_a",0), e.get("atk_air",0))
    out = []
    if ck in (0,2):
        if sub == "ARTILLERY": out.append("炮兵反炮兵")
        elif sub == "ANTI_AIR": out.append("防空封锁")
        elif sub == "SUPPORT": out.append("工兵爆破")
        else: out.append("步兵掩蔽")  # 侦察按前缀，下面另算
    elif ck in (1,4):
        if ck == 4 or sub == "FORT": out.append("堡垒坚守")
        else: out.append("装甲碾压")
    elif ck == 3:
        out.append("空袭突击")
    return sub, out

# 侦察前缀列表（unit_stats_table._RECON_PREFIXES，需读取确认）
RECON_PREFIXES = ["scout", "recon", "razak", "pathfi", "pathfinder", "watcher", "hunter_killer", "spec_"]
def is_recon(cid):
    c = cid.lower()
    return any(c.startswith(p) or p in c for p in ["scout", "recon"])

rows = []
mech_count = Counter()
for e in entries:
    cid = e["card_id"]
    sub, fixed = fixed_mechs(e)
    spec = special_matches(cid)
    rec = is_recon(cid)
    total = len(fixed) + len(spec) + (1 if rec else 0)
    mech_count[total] += 1
    rows.append((cid, e.get("display_name",""), ERA_NAMES.get(e.get("era"),"?"),
                 KIND_NAMES.get(e.get("combat_kind"),"?"), sub, fixed, spec, rec, total))

print("\n===== 机制数量分布（每卡命中机制条数 → 卡数）=====")
for n in sorted(mech_count):
    print(f"  {n} 条机制: {mech_count[n]} 张卡")

print("\n===== 0 条机制的卡（固定机制应为每卡至少1条，出现0=异常）=====")
for r in rows:
    if r[8] == 0:
        print("  ", r[0], r[1], r[2], r[3])

print("\n===== 特殊机制叠加 ≥2 的卡（前缀误伤/堆叠）=====")
for r in rows:
    if len(r[6]) >= 2:
        print(f"   {r[0]} ({r[1]}, {r[2]}{r[3]}): {r[6]}")

print("\n===== 特殊机制命中明细（stalker/engineer/ecm/sniper）=====")
for tag in ("stalker","engineer","ecm","sniper"):
    hits = [r for r in rows if tag in r[6]]
    print(f"  [{tag}] {len(hits)} 张:")
    for r in hits:
        print(f"     {r[0]} ({r[1]}, {r[2]}{r[3]}/{r[4]})")

print("\n===== 侦察前缀命中（潜入开局减伤）=====")
for r in rows:
    if r[7]:
        print(f"   {r[0]} ({r[1]}, {r[2]}{r[3]}/{r[4]})")

# ── 武器标签错乱扫描 ──
print("\n===== 武器标签异常扫描 =====")
KNOWN_LABELS = {
    "地狱火导弹/127mm舰炮": "现代舰艇/阿帕奇系武器",
    "地狱火导弹": "阿帕奇直升机武器",
    "127mm舰炮": "舰炮",
    "空空导弹/20mm机炮": "冷战战斗机武器",
    "空天导弹/粒子炮": "近未来空天武器",
    "轨道炮/激光": "近未来武器",
}
suspicious = []
for e in entries:
    cid = e["card_id"]; era = e.get("era"); wl = e.get("w_light",""); wa = e.get("w_armor",""); wai = e.get("w_air",""); lab = e.get("weapon_label","")
    # 时代错配：早期卡带晚期武器名
    if "地狱火" in (wl+wa+wai+lab) and era is not None and era < 3:
        suspicious.append((cid, e.get("display_name",""), era, f"地狱火出现在 era<{era} 的武器槽: {lab}|{wl}|{wa}|{wai}"))
    if "127mm舰炮" in (wl+wa+wai+lab):
        suspicious.append((cid, e.get("display_name",""), era, f"127mm舰炮出现在: {lab}|{wl}|{wa}|{wai}"))
    if "轨道炮" in (wl+wa+wai+lab) and era is not None and era < 4:
        suspicious.append((cid, e.get("display_name",""), era, f"轨道炮出现在 era<{era}: {lab}|{wl}|{wa}|{wai}"))
    if "空天" in (wl+wa+wai+lab) and era is not None and era < 4:
        suspicious.append((cid, e.get("display_name",""), era, f"空天武器出现在 era<{era}: {lab}|{wl}|{wa}|{wai}"))
    # 武器主标签 vs w_槽明显不一致
    if lab and lab not in (wl+wa+wai) and wa:  # lab 不在任何槽里（粗查）
        pass
for s in suspicious:
    print(f"   [{s[0]}] {s[1]} (era={s[2]}): {s[3]}")

# ── 时代递进异常扫描：同 combat_kind+tier 下 era 递进 ──
print("\n===== 时代递进异常（HP 非单调递增，同兵种同类卡跨时代）=====")
groups = defaultdict(list)
for e in entries:
    key = (e.get("combat_kind"), TIER_NAMES.get(e.get("tier"),"?"))
    groups[key].append((e.get("era"), e.get("base_hp"), e["card_id"], e.get("display_name","")))
for key in sorted(groups):
    lst = sorted(groups[key], key=lambda x:(x[0], -x[1]))
    era_map = {}
    for era, hp, cid, name in lst:
        era_map.setdefault(era, []).append((hp, cid, name))
    eras = sorted(era_map)
    for i in range(1, len(eras)):
        prev_max = max(h[0] for h in era_map[eras[i-1]])
        cur_min = min(h[0] for h in era_map[eras[i]])
        if cur_min < prev_max * 0.55:
            print(f"   [{KIND_NAMES.get(key[0])}/{key[1]}] {ERA_NAMES[eras[i-1]]}最高HP={prev_max} → {ERA_NAMES[eras[i]]}最低HP={cur_min}:")
            for h in era_map[eras[i]]:
                if h[0] < prev_max * 0.55:
                    print(f"      {h[1]} ({h[2]}) HP={h[0]}")

# ── 攻击数值非单调（飞机线专项）────
print("\n===== 空中兵种跨时代数值链 =====")
airs = [e for e in entries if e.get("combat_kind") == 3]
airs.sort(key=lambda e:(e.get("era"), -(e.get("base_hp") or 0)))
for e in airs:
    print(f"   era{e.get('era')} {ERA_NAMES.get(e.get('era'))} [{TIER_NAMES.get(e.get('tier'))}] {e['card_id']} {e.get('display_name','')}: HP={e.get('base_hp')} atk_l={e.get('atk_l')} atk_a={e.get('atk_a')} atk_air={e.get('atk_air')} label={e.get('weapon_label','')}")
