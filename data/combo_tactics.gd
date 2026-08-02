extends RefCounted
class_name ComboTactics
## v9.1 我方组合技套路系统 — 6 套路定义
##
## 每套路是一条"状态链"：A 投射写状态 → B 投射读状态增伤/变形。
## 激活条件两种（叠加生效）：
##   - 改造组合：单卡装了 ≥2 个该套路配套改造 → 该卡获得套路增益
##   - 兵种组合：场上同时有指定 combat_kind 组合 → 全队解锁新机制 flag
##
## 本文件只负责"定义 + 检测激活"，新机制的实际执行在 combo_engine / module_effect_handler / bullet.gd。

const ComboFieldState = preload("res://scripts/battle/combo_field_state.gd")

# ─────────────────────────────────────────────
#  套路 ID 常量
# ─────────────────────────────────────────────
const COMBO_INCENDIARY   := "incendiary_chain"     # 套路1 助燃燃烧链
const COMBO_EMP          := "emp_chain"             # 套路2 电磁脉冲链
const COMBO_NANO         := "nano_field"            # 套路3 纳米浓度场
const COMBO_LASER        := "laser_resonance"       # 套路4 光束谐振链
const COMBO_RECON        := "recon_chain"           # 套路5 侦察链式
const COMBO_CHEM         := "chem_pollution"        # 套路6 化学污染场

# CombatKind 整数（硬编码避免跨类求值时序问题）
const _KIND_LIGHT  := 0
const _KIND_ARMOR  := 1
const _KIND_SUPPORT := 2
const _KIND_AIR    := 3
const _KIND_FORT   := 4

## 6 套路完整定义
## - name/icon/desc: 展示用
## - mod_ids: 配套改造 id 列表（改造组合检测：单卡装 ≥2 个即激活单卡增益）
## - mod_combo_min: 触发单卡增益所需的最少配套改造数（默认 2）
## - kind_combo: 兵种组合条件（字典 {kind: min_count}，全满足即解锁全队新机制）
## - fields: 该套路关联的战场浓度 tag（激活时引擎会主动累积/读取）
## - mechanisms: 新机制 flag 列表（供 bullet/module_effect_handler 读取后执行特殊逻辑）
const COMBOS: Dictionary = {
	COMBO_INCENDIARY: {
		"id": COMBO_INCENDIARY,
		"name": "助燃燃烧链",
		"icon": "🔥",
		"desc": "助燃剂+燃烧弹协同，燃烧层数上限翻倍并触发化学爆发",
		"mod_ids": ["art_incendiary_mix", "art_white_phosphorus", "air_thermolite_bomb", "gen_combustion_catalyst"],
		"mod_combo_min": 2,
		"kind_combo": {_KIND_SUPPORT: 1},   # ≥1 支援单位解锁全队新机制
		"fields": [],
		"mechanisms": ["incendiary_boost", "chem_burst"],   # 燃烧层数上限5→10 + 化学爆发扩散
	},
	COMBO_EMP: {
		"id": COMBO_EMP,
		"name": "电磁脉冲链",
		"icon": "⚡",
		"desc": "石墨纤维累积电子损坏，电磁武器触发脉冲反射",
		"mod_ids": ["art_graphite_fiber", "aa_emp_warhead", "air_antiradiation_missile", "gen_overload_capacitor"],
		"mod_combo_min": 2,
		"kind_combo": {_KIND_LIGHT: 1, _KIND_AIR: 1},   # 步兵+空中解锁全队新机制
		"fields": [],
		"mechanisms": ["graphite_accumulate", "emp_reflect"],   # 石墨累积 + 电磁脉冲反射
	},
	COMBO_NANO: {
		"id": COMBO_NANO,
		"name": "纳米浓度场",
		"icon": "🧬",
		"desc": "纳米蜂群提升战场纳米浓度，纳米病毒感染扩散",
		"mod_ids": ["art_nano_amp", "sup_nano_seeder", "gen_nano_catalyst"],
		"mod_combo_min": 2,
		"kind_combo": {_KIND_SUPPORT: 1, _KIND_FORT: 1},
		"fields": [ComboFieldState.FIELD_NANO],
		"mechanisms": ["nano_concentration", "nano_spread"],   # 浓度增伤 + 感染扩散
	},
	COMBO_LASER: {
		"id": COMBO_LASER,
		"name": "光束谐振链",
		"icon": "✨",
		"desc": "激光标记积累谐振，光束武器多重攻击+反射",
		"mod_ids": ["gen_beam_splitter", "gen_reflector_array", "air_targeting_laser", "eng_optical_fiber"],
		"mod_combo_min": 2,
		"kind_combo": {_KIND_AIR: 1, _KIND_LIGHT: 1},
		"fields": [],
		"mechanisms": ["laser_resonance", "beam_split", "beam_reflect"],   # 谐振累积 + 多重攻击 + 反射
	},
	COMBO_RECON: {
		"id": COMBO_RECON,
		"name": "侦察链式",
		"icon": "🎯",
		"desc": "无人机+雷达双标记，狙击手集火链式触发弱点暴露",
		"mod_ids": ["rec_phased_radar", "sup_targeting_drone", "gen_weakpoint_analyzer"],
		"mod_combo_min": 2,
		"kind_combo": {_KIND_LIGHT: 2},   # ≥2 轻装（含狙击/侦察）
		"fields": [],
		"mechanisms": ["radar_lock", "weakpoint_expose"],   # 雷达锁定 + 弱点暴露
	},
	COMBO_CHEM: {
		"id": COMBO_CHEM,
		"name": "化学污染场",
		"icon": "☠",
		"desc": "化学弹累积战场污染，腐蚀降防+污染扩散",
		"mod_ids": ["art_chem_cluster", "aa_acid_warhead", "eng_chem_sprayer", "gen_pollution_accumulator"],
		"mod_combo_min": 2,
		"kind_combo": {_KIND_SUPPORT: 1, _KIND_ARMOR: 1},
		"fields": [ComboFieldState.FIELD_CHEM],
		"mechanisms": ["chem_corrosion", "chem_spread"],   # 化学腐蚀降防 + 污染扩散
	},
}

# ─────────────────────────────────────────────
#  检测 API
# ─────────────────────────────────────────────

## 检测单卡激活的套路（改造组合）。
## 参数 mods_on_card: 该卡已安装的改造 id 列表（String）。
## 返回：该卡激活的 combo_id 数组（可能多套路同时激活）。
static func detect_card_combos(mods_on_card: Array) -> Array:
	var active: Array = []
	if mods_on_card.is_empty():
		return active
	for combo_id in COMBOS.keys():
		var def: Dictionary = COMBOS[combo_id]
		var mod_ids: Array = def.get("mod_ids", [])
		if mod_ids.is_empty():
			continue
		var hit: int = 0
		for mid in mod_ids:
			if mods_on_card.has(String(mid)):
				hit += 1
		if hit >= int(def.get("mod_combo_min", 2)):
			active.append(combo_id)
	return active

## 检测全队激活的套路（兵种组合，解锁新机制 flag）。
## 参数 allies: 友军单位列表；kind_counter: {combat_kind: count}（可选，为空时引擎从 allies 统计）。
## 返回：全队激活的 combo_id 数组。
static func detect_team_combos(allies: Array, kind_counter: Dictionary = {}) -> Array:
	var counts: Dictionary = kind_counter
	if counts.is_empty():
		counts = _count_kinds(allies)
	var active: Array = []
	for combo_id in COMBOS.keys():
		var def: Dictionary = COMBOS[combo_id]
		var kc: Dictionary = def.get("kind_combo", {})
		if kc.is_empty():
			continue
		var ok: bool = true
		for k in kc.keys():
			var need: int = int(kc[k])
			var have: int = int(counts.get(int(k), 0))
			if have < need:
				ok = false
				break
		if ok:
			active.append(combo_id)
	return active

## 获取套路定义
static func get_combo_def(combo_id: String) -> Dictionary:
	return COMBOS.get(combo_id, {})

## 获取全队激活套路的"新机制 flag"合集（供 bullet/module_effect_handler 查询）。
## 返回 Array[String]，如 ["chem_burst", "emp_reflect", ...]
static func get_active_mechanisms(team_combos: Array) -> Array:
	var mechs: Array = []
	for combo_id in team_combos:
		var def: Dictionary = COMBOS.get(String(combo_id), {})
		for m in def.get("mechanisms", []):
			var ms: String = String(m)
			if not mechs.has(ms):
				mechs.append(ms)
	return mechs

## 获取所有套路配套改造 id 的扁平集合（供 modification_registry 注册新改造时校验）。
static func get_all_combo_mod_ids() -> Array:
	var all: Array = []
	for combo_id in COMBOS.keys():
		for mid in COMBOS[combo_id].get("mod_ids", []):
			var ms: String = String(mid)
			if not all.has(ms):
				all.append(ms)
	return all

# ─────────────────────────────────────────────
#  辅助
# ─────────────────────────────────────────────

static func _count_kinds(allies: Array) -> Dictionary:
	var counts: Dictionary = {}
	for u in allies:
		if u == null or not is_instance_valid(u):
			continue
		var kind: int = -1
		if "stats" in u and u.stats != null and "combat_kind" in u.stats:
			kind = int(u.stats.combat_kind)
		if kind >= 0:
			counts[kind] = int(counts.get(kind, 0)) + 1
	return counts
