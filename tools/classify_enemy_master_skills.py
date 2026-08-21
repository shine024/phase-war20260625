# -*- coding: utf-8 -*-
"""敌方相位师技能归类扫描器（四源重构 批次0）

扫描 5 个时代数据文件的 traits / active_spells / passive_spells，按四源规则归类，
并复刻 EnemyMasterSkillEngine 的关键字分发逻辑，判定每个技能的落实状态：
  ✅ 落实 / ⚠️ 误路由（子串误匹配，数值生效但语义错）/ ❌ 空转（无任何执行路径）

输出：
  docs/敌方相位师技能归类_当前数据.md   归类表 + 空转/误路由/重复清单（人工过目）
  docs/migration_baseline.json          30 master 原始数据快照 + 引擎分发结果（批次5守恒对比基线）

用法：python tools/classify_enemy_master_skills.py
"""
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DATA_FILES = [
    ("WW1一战", "data/enemy_phase_masters_ww1.gd"),
    ("WW2二战", "data/enemy_phase_masters_ww2.gd"),
    ("冷战", "data/enemy_phase_masters_cold.gd"),
    ("现代", "data/enemy_phase_masters_modern.gd"),
    ("近未来", "data/enemy_phase_masters_future.gd"),
]

# ============================================================
# GDScript 字典字面量解析器（tokenizer + 递归下降）
# ============================================================

def strip_comments(text: str) -> str:
    out = []
    i, n = 0, len(text)
    in_str = False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
        else:
            if c == "#":
                while i < n and text[i] != "\n":
                    i += 1
            else:
                if c == '"':
                    in_str = True
                out.append(c)
                i += 1
    return "".join(out)


TOKEN_RE = re.compile(
    r'"(?:[^"\\]|\\.)*"'          # string
    r"|-?\d+\.\d+"                # float
    r"|-?\d+"                     # int
    r"|[A-Za-z_][A-Za-z0-9_]*"    # ident
    r"|[{}\[\],:=]"               # punct
)


def tokenize(text: str):
    return TOKEN_RE.findall(text)


class Parser:
    def __init__(self, tokens):
        self.toks = tokens
        self.pos = 0

    def peek(self):
        return self.toks[self.pos] if self.pos < len(self.toks) else None

    def next(self):
        t = self.peek()
        self.pos += 1
        return t

    def parse_value(self):
        t = self.peek()
        if t is None:
            raise ValueError("unexpected EOF")
        if t == "{":
            return self.parse_dict()
        if t == "[":
            return self.parse_array()
        # 标量 token：先消费再返回
        self.next()
        if t.startswith('"'):
            return t[1:-1]
        if t == "true":
            return True
        if t == "false":
            return False
        if t == "null":
            return None
        if re.fullmatch(r"-?\d+(\.\d+)?", t):
            return float(t) if "." in t else int(t)
        # ident 等未识别 token（Color/Vector2 等）——跳过并返回 None
        return None

    def parse_dict(self):
        assert self.next() == "{"
        d = {}
        while self.peek() != "}":
            key = self.next()
            if key is None:
                break
            key = key.strip('"') if key.startswith('"') else key
            sep = self.next()  # ":"
            if sep != ":":
                continue
            d[key] = self.parse_value()
            if self.peek() == ",":
                self.next()
        self.next()  # "}"
        return d

    def parse_array(self):
        assert self.next() == "["
        arr = []
        while self.peek() != "]":
            arr.append(self.parse_value())
            if self.peek() == ",":
                self.next()
        self.next()  # "]"
        return arr


def load_era_masters(path: str) -> list:
    text = strip_comments(open(path, encoding="utf-8").read())
    m = re.search(r"ERA_MASTERS\s*(?::[^=]+)?=\s*", text)
    if not m:
        raise ValueError(f"{path}: 找不到 ERA_MASTERS")
    toks = tokenize(text[m.end():])
    p = Parser(toks)
    arr = p.parse_array()
    return [x for x in arr if isinstance(x, dict)]


# ============================================================
# 引擎分发逻辑复刻（enemy_master_skill_engine.gd，2026-08 当前版）
# 顺序敏感：先匹配更具体的
# ============================================================

AOE_KW = ["explosion", "meteor", "aoe", "global_damage", "global_dot", "nuke",
          "bombard", "quake", "void_apocalypse", "hell", "solar", "flame_wave",
          "pyroblast", "black_hole", "hammer_smash", "massive", "instant_kill_zone",
          "damage_aura", "burning", "chaos", "apocalypse"]
CHAIN_KW = ["chain", "lightning", "tesla", "thunder"]
SUMMON_KW = ["summon", "deploy", "portal", "clones", "mech", "forge"]
DEBUFF_KW = ["slow", "stun", "darkness", "emp", "weakness", "debuff", "wind_push"]
SHIELD_KW = ["shield", "dome", "barrier", "ward", "bulwark"]
SINGLE_KW = ["single", "snipe", "god_weapon", "piercing_shot", "devour"]

AURA_KW = ["aura", "drain", "entropy", "damage_aura", "burning_aura",
           "self_damage", "time_based", "life_energy"]
HEAL_AURA_KW = ["heal", "healing", "massive_heal"]


def _hit(effect: str, kws) -> bool:
    return any(k in effect for k in kws)


def active_dispatch(effect: str):
    """返回执行函数名，未匹配返回 None（_trigger_spell 静默跳过）"""
    if _hit(effect, AOE_KW):
        return "_exec_aoe_damage"
    if _hit(effect, CHAIN_KW):
        return "_exec_chain_lightning"
    if _hit(effect, SUMMON_KW):
        return "_exec_summon"
    if _hit(effect, DEBUFF_KW):
        return "_exec_debuff_players"
    if _hit(effect, SHIELD_KW):
        return "_exec_shield_self"
    if _hit(effect, SINGLE_KW):
        return "_exec_single_target"
    return None


def passive_branch(effect: str):
    """_apply_passive_buffs 的 if/elif 分支（首个命中生效）"""
    if _hit(effect, ["armor", "defence", "defense"]):
        return ("B1_防御加成", "全队三维防御×(1+bonus)")
    if _hit(effect, ["damage", "boost", "mastery", "formation"]):
        return ("B2_攻击加成", "全队三维攻击×(1+boost)")
    if _hit(effect, ["thorn", "spike", "reflect"]):
        return ("B3_反伤", "boss 反伤")
    if "energy_shield" in effect or effect == "shield_base":
        return ("B4_自护盾", "boss 护盾")
    if _hit(effect, ["high_energy", "overcharge"]):
        return ("B5_能量阈值攻速", "meta 标记")
    if _hit(effect, ["heal", "healing", "massive_heal"]):
        return ("B6_治疗meta", "meta 标记+toast")
    if "death_shield" in effect:
        return ("B7_亡语回盾", "meta 标记")
    return None


def aura_tick(effect: str):
    """update_passives 的 tick 分支（aura 判定优先于 heal 判定——顺序坑）"""
    if _hit(effect, AURA_KW):
        return "伤害tick"
    if _hit(effect, HEAL_AURA_KW):
        return "治疗tick"
    return None


def boss_destroyed(effect: str):
    if "death" in effect and ("explosion" in effect or "blast" in effect):
        return "死亡爆炸"
    return None


TRAIT_SUPPORTED_KEYS = {"atk_light", "atk_armor", "atk_air",
                        "def_light", "def_armor", "def_air",
                        "hp", "crit_chance", "dodge_chance"}

# ============================================================
# 语义意图表：已知"引擎分支 ≠ 设计意图"的误路由（人工核对过的）
# ============================================================

MISROUTE = {
    "damage_aura": "⚠️ 双算：伤害tick正确，另被子串'damage'误命中B2→全队意外攻击+20%（params无boost键取默认0.20）",
    "burning_aura": "⚠️ 双算：同 damage_aura",
    "self_damage_aura": "⚠️ 双算：伤害tick正确，另被B2误命中→意外攻击+20%",
    "massive_heal_aura": "⚠️ 误路由：含'aura'→优先走伤害tick（默认30dps打玩家），治疗tick永不执行；B6治疗meta正常标记",
    "healing_aura": "⚠️ 误路由：同 massive_heal_aura",
    "lightning_aura": "✅ 落实（伤害tick，params.damage）",
    "splash_damage": "⚠️ 误路由：设计'攻击溅射30%'，被子串'damage'命中B2→全队攻击+20%（params无boost键）",
    "damage_cap": "⚠️ 误路由：设计'单次伤害上限'，被'damage'命中B2→全队攻击+20%",
    "scaling_damage": "⚠️ 误路由：设计'随时间成长'，被B2当一次性攻击加成",
    "speed_boost": "⚠️ 误路由：设计'移速提升'，被'boost'命中B2→当攻击加成",
    "low_hp_defense_boost": "⚠️ 误路由：设计'低血触发防御翻倍'，被'defense'命中B1→无条件常驻防御",
    "unit_count_defense": "⚠️ 误路由：设计'按单位数叠防御'，被B1→无条件常驻防御",
    "armor_ignore_chance": "⚠️ 误路由：设计'穿甲概率'，被'armor'命中B1→当防御加成",
    "enemy_defense_reduction": "⚠️ 误路由：设计'削玩家防御'，被B1→给敌队加防御（方向反了）",
    "synergy_boost": "⚠️ 语义近似：协同加成被B2当通用攻击加成（协同语义丢失）",
    "dual_element_boost": "⚠️ 语义近似：双元素加成被B2当通用攻击加成",
    "elemental_mastery": "⚠️ 语义近似：元素精通被B2当通用攻击加成",
    "goddess_mastery": "⚠️ 语义近似：虚空系加成被B2当通用攻击加成",
    "omni_mastery": "⚠️ 语义近似：全系加成被B2当通用攻击加成",
    "fire_damage_boost": "⚠️ 语义近似：火焰系加成被B2当通用攻击加成（无元素系统）",
    "elemental_damage_boost": "⚠️ 语义近似：元素伤害加成被B2当通用攻击加成",
    "global_damage_boost": "✅ 落实（全局攻击加成语义一致）",
    "thunder_mastery": "⚠️ 语义近似：雷系加成被B2当通用攻击加成",
}

# 空转确认表：无任何执行路径（引擎分支 None 且无 tick 且非死亡爆炸 且非 trait 支持键）
IDLE_NOTE = {
    "teleport_behind": "瞬移机制未实装",
    "execute_damage": "处决机制未实装",
    "auto_resurrect": "复活机制未实装",
    "phoenix_rebirth_auto": "复活机制未实装",
    "auto_production": "自动产兵机制未实装",
    "auto_production_fast": "自动产兵机制未实装",
    "chain_attack": "攻击跳跃机制未实装",
    "ignite_chance": "点燃机制未实装",
    "burn_slow": "燃减速机制未实装",
    "periodic_electric_shock": "周期电击机制未实装",
    "immunity": "免疫机制未实装",
    "infinite_scaling": "无上限成长机制未实装",
    "permanent_darkness": "永久致盲机制未实装",
    "time_based_upgrade": "时间成长机制未实装",
    "storm_speed": "移速攻速加成机制未实装",
    "energy_drain": "抽能量机制未实装",
    "full_energy_trigger": "满能量触发机制未实装",
    "death_avoid_teleport": "致命伤闪避机制未实装",
    "proc_explosion": "概率爆炸机制未实装",
    "fire_lifesteal_chance": "火吸血机制未实装",
    "teleport": "瞬移机制未实装",
}

# 势力技能树候选（A 规则）：协同类 + 双势力 master 的主题 trait
SYNERGY_IDS = {"synergy_boost", "forgemaster", "electromagnetic_armor",
               "chaos_flame_trait", "void_goddess_trait", "dual_element_boost"}


def classify_skill(field: str, spell: dict, master_faction: str) -> str:
    """四源归类：D相位仪 / B技能树-数值 / C技能树-机制 / A势力技能树"""
    sid = str(spell.get("id", ""))
    effect = str(spell.get("effect", ""))
    if field == "active_spells":
        return "4-相位仪"
    # traits / passive_spells
    if sid in SYNERGY_IDS or "synergy" in sid or "synergy" in effect:
        return "3-势力技能树"
    if field == "traits":
        keys = set((spell.get("effects") or {}).keys())
        if keys <= TRAIT_SUPPORTED_KEYS:
            return "2-技能树·数值"
        return "2-技能树·数值(含未支持key)"
    # passive：命中数值分支且语义正确 → 数值；其余 → 机制
    eff_key = effect if effect else sid
    br = passive_branch(eff_key)
    if br and eff_key not in MISROUTE:
        return "2-技能树·数值"
    if br and eff_key in MISROUTE and MISROUTE[eff_key].startswith("✅"):
        return "2-技能树·数值"
    return "2-技能树·机制"


def judge(field: str, spell: dict) -> str:
    """落实状态判定"""
    sid = str(spell.get("id", ""))
    effect = str(spell.get("effect", "")).lower()
    eff_key = effect if effect else sid
    if field == "active_spells":
        fn = active_dispatch(effect)
        if fn:
            return f"✅ 落实（{fn}）"
        return f"❌ 空转（无关键词匹配，_trigger_spell 静默跳过）"
    if field == "traits":
        keys = set((spell.get("effects") or {}).keys())
        unsupported = keys - TRAIT_SUPPORTED_KEYS
        if unsupported:
            return f"⚠️ 部分落实（未支持 key: {sorted(unsupported)}，代码注释明示不映射）"
        return "✅ 落实（driver trait 8键直映）"
    # passive_spells
    parts = []
    br = passive_branch(eff_key)
    tick = aura_tick(eff_key)
    destroyed = boss_destroyed(eff_key)
    if eff_key in MISROUTE and not MISROUTE[eff_key].startswith("✅"):
        return MISROUTE[eff_key]
    if br:
        parts.append(f"B分支:{br[0]}")
    if tick:
        parts.append(f"tick:{tick}")
    if destroyed:
        parts.append(destroyed)
    if parts:
        return "✅ 落实（" + " + ".join(parts) + "）"
    return f"❌ 空转（{IDLE_NOTE.get(eff_key, '无任何执行路径')}）"


# ============================================================
# 主流程
# ============================================================

def main():
    masters = []
    for era_name, rel in DATA_FILES:
        path = os.path.join(ROOT, rel)
        for m in load_era_masters(path):
            m["_era"] = era_name
            m["_file"] = rel
            masters.append(m)

    lines = []
    lines.append("# 敌方相位师技能归类表（按当前数据重新生成）\n")
    lines.append("> 生成时间：%s  |  数据源：5 个时代 master 数据文件（当前真身，非 2026-07-29 旧文档）" % __import__("time").strftime("%Y-%m-%d %H:%M"))
    lines.append("> 落实状态由 tools/classify_enemy_master_skills.py 复刻 EnemyMasterSkillEngine 关键字分发逻辑判定\n")

    stat = {"total": 0, "ok": 0, "misroute": 0, "idle": 0, "partial": 0}
    src_count = {}
    idle_list, misroute_list, partial_trait_list, idle_active_list = [], [], [], []
    baseline = []

    for m in masters:
        mid = m.get("id", "?")
        name = m.get("name", "?")
        faction = m.get("faction", "")
        level = m.get("level", 0)
        equip = m.get("equipment", {}) or {}
        inst = equip.get("phase_instrument", "")
        dual = "_" in faction
        lines.append(f"\n## {mid} {name}（{m['_era']} · Lv{level} · {faction}{' · 双势力' if dual else ''} · {inst}）\n")
        lines.append("| 来源字段 | 技能ID | 技能名 | effect | 归类 | 落实状态 |")
        lines.append("|---|---|---|---|---|---|")

        m_base = {
            "id": mid, "name": name, "era": m["_era"], "file": m["_file"],
            "faction": faction, "level": level, "phase_instrument": inst,
            "stats": m.get("stats", {}), "traits": [], "active_spells": [], "passive_spells": [],
        }
        for field, label in [("traits", "traits"), ("active_spells", "active_spells"), ("passive_spells", "passive_spells")]:
            for s in (m.get(field) or []):
                if not isinstance(s, dict):
                    continue
                sid = str(s.get("id", ""))
                sname = str(s.get("name", ""))
                effect = str(s.get("effect", "")) or (("(trait effects: %s)" % ",".join((s.get("effects") or {}).keys())))
                cls = classify_skill(field, s, faction)
                status = judge(field, s)
                cd = s.get("cooldown", "")
                cd_s = f" CD{cd}s" if cd != "" else ""
                lines.append(f"| {label} | {sid} | {sname} | {effect}{cd_s} | {cls} | {status} |")
                stat["total"] += 1
                src_count[cls] = src_count.get(cls, 0) + 1
                if status.startswith("✅"):
                    stat["ok"] += 1
                elif status.startswith("⚠️"):
                    stat["misroute"] += 1
                    (partial_trait_list if field == "traits" else misroute_list).append(
                        f"{mid} {sname}({sid}) [{effect}] → {status}")
                elif status.startswith("❌"):
                    stat["idle"] += 1
                    (idle_active_list if field == "active_spells" else idle_list).append(
                        f"{mid} {sname}({sid}) [{effect}] → {status}")
                # 基线快照（原始数据 + 引擎分发结果）
                snap = dict(s)
                if field == "active_spells":
                    snap["_engine_dispatch"] = active_dispatch(str(s.get("effect", "")).lower())
                elif field == "passive_spells":
                    e = (str(s.get("effect", "")) or "").lower()
                    snap["_engine"] = {"branch": passive_branch(e), "tick": aura_tick(e),
                                       "destroyed": boss_destroyed(e)}
                m_base[field].append(snap)
        baseline.append(m_base)

    # 汇总
    lines.append("\n## 汇总统计\n")
    lines.append(f"- 技能总数：{stat['total']}")
    lines.append(f"- ✅ 落实：{stat['ok']}（{stat['ok']*100//max(stat['total'],1)}%）")
    lines.append(f"- ⚠️ 误路由/部分：{stat['misroute']}")
    lines.append(f"- ❌ 空转：{stat['idle']}")
    lines.append("\n### 按四源归类分布\n")
    lines.append("| 归类 | 数量 |")
    lines.append("|---|---|")
    for k in sorted(src_count):
        lines.append(f"| {k} | {src_count[k]} |")

    lines.append("\n## ❌ 空转清单（passive/traits，共 %d）\n" % len(idle_list))
    lines.extend(f"- {x}" for x in idle_list)
    lines.append("\n## ❌ 空转清单（active 大招，共 %d）\n" % len(idle_active_list))
    lines.extend(f"- {x}" for x in idle_active_list)
    lines.append("\n## ⚠️ 误路由清单（共 %d）\n" % len(misroute_list))
    lines.extend(f"- {x}" for x in misroute_list)
    lines.append("\n## ⚠️ traits 未支持 key（共 %d）\n" % len(partial_trait_list))
    lines.extend(f"- {x}" for x in partial_trait_list)
    lines.append("\n## 迁移说明\n")
    lines.append("- active_spells 全部 → 相位仪（批次2 物理搬迁）")
    lines.append("- traits/passive_spells 中纯数值 → 技能树·数值节点（批次3）")
    lines.append("- 条件/触发/光环类 → 技能树·机制节点（误路由在迁移时按显式节点类型修复）")
    lines.append("- synergy/双势力主题 → 势力技能树（批次3）")
    lines.append("- 空转项在归类后标记 implemented:false，保持现状空转，进补齐 TODO")

    doc_path = os.path.join(ROOT, "docs", "敌方相位师技能归类_当前数据.md")
    with open(doc_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    base_path = os.path.join(ROOT, "docs", "migration_baseline.json")
    with open(base_path, "w", encoding="utf-8") as f:
        json.dump({"masters": baseline, "stat": stat}, f, ensure_ascii=False, indent=1)

    print(f"masters: {len(masters)}  skills: {stat['total']}")
    print(f"✅ {stat['ok']}  ⚠️ {stat['misroute']}  ❌ {stat['idle']}")
    print(f"归类: {src_count}")
    print(f"输出: {doc_path}")
    print(f"输出: {base_path}")


if __name__ == "__main__":
    main()
