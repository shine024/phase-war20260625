extends RefCounted
class_name ComboTactics
## v9.1 我方组合技套路系统 — 6 套路定义
##
## 每套路是一条"状态链"：A 投射写状态 → B 投射读状态增伤/变形。
## 激活条件两种（叠加生效）：
##   - 改造组合：单卡装了 ≥2 个该套路配套改造 → 该卡获得套路增益
##   - 兵种组合：场上同时有指定 combat_kind 组合 → 全队解锁新机制 flag
## v21 P1：新增套装档位——单卡装满全部配套改造（mod_combo_full）→ 该套路升级为满档，
##   引擎（combo_engine）把 full_mechanisms flag 并入全队机制表，机制执行函数读档位分支。
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
## - mod_combo_full: v21 P1 满档（4 件套）所需改造 id 列表——单卡通关全部列表即"满档"。
##   计划 §P1-1 的"4 件套"按"集齐该套路全部配套改造"落地：4 条配套的套路即原 4 件套；
##   纳米/侦察仅 3 条配套改造（数据既定），集齐 3 条即满档（低配满档，已在此注释声明）。
## - full_mechanisms: v21 P1 满档解锁的机制升级 flag（由 combo_engine 并入全队机制表，
##   机制执行函数读档位分支执行；执行落点全在既有机制消费点，不动 bullet/batch 路由）
## - desc_full: v21 P1 满档文案（UI tooltip 用）
## - kind_combo: 兵种组合条件（字典 {kind: min_count}，全满足即解锁全队新机制）
## - fields: 该套路关联的战场浓度 tag（激活时引擎会主动累积/读取）
## - mechanisms: 新机制 flag 列表（供 bullet/module_effect_handler 读取后执行特殊逻辑）
## v9.x（P2-1）：icon_tex 字段已删——全项目零读取方（strip UI 用文字 icon），且指向不存在的 combo_icons/ 目录
const COMBOS: Dictionary = {
	COMBO_INCENDIARY: {
		"id": COMBO_INCENDIARY,
		"name": "助燃燃烧链",
		"icon": "🔥",
		"desc": "助燃剂+燃烧弹协同，燃烧层数上限翻倍并触发化学爆发",
		"mod_ids": ["art_incendiary_mix", "art_white_phosphorus", "air_thermolite_bomb", "gen_combustion_catalyst"],
		"mod_combo_min": 2,
		"mod_combo_full": ["art_incendiary_mix", "art_white_phosphorus", "air_thermolite_bomb", "gen_combustion_catalyst"],
		"desc_full": "燃烧目标死亡时留火种：继承 50% 燃烧层数的范围 DOT",
		"kind_combo": {_KIND_SUPPORT: 1},   # ≥1 支援单位解锁全队新机制
		"fields": [],
		"mechanisms": ["incendiary_boost", "chem_burst"],   # 燃烧层数上限5→10 + 化学爆发扩散
		"full_mechanisms": ["incendiary_death_seed"],        # v21 P1 满档：死亡留火种
	},
	COMBO_EMP: {
		"id": COMBO_EMP,
		"name": "电磁脉冲链",
		"icon": "⚡",
		"desc": "石墨纤维累积电子损坏，电磁武器触发脉冲反射",
		"mod_ids": ["art_graphite_fiber", "aa_emp_warhead", "air_antiradiation_missile", "gen_overload_capacitor"],
		"mod_combo_min": 2,
		"mod_combo_full": ["art_graphite_fiber", "aa_emp_warhead", "air_antiradiation_missile", "gen_overload_capacitor"],
		"desc_full": "脉冲反射附带 0.5s 瘫痪（_hit_stun_left）",
		"kind_combo": {_KIND_LIGHT: 1, _KIND_AIR: 1},   # 步兵+空中解锁全队新机制
		"fields": [],
		"mechanisms": ["graphite_accumulate", "emp_reflect"],   # 石墨累积 + 电磁脉冲反射
		"full_mechanisms": ["emp_reflect_stun"],                # v21 P1 满档：反射附带瘫痪
	},
	COMBO_NANO: {
		"id": COMBO_NANO,
		"name": "纳米浓度场",
		"icon": "🧬",
		"desc": "纳米蜂群提升战场纳米浓度，纳米病毒感染扩散",
		"mod_ids": ["art_nano_amp", "sup_nano_seeder", "gen_nano_catalyst"],
		"mod_combo_min": 2,
		"mod_combo_full": ["art_nano_amp", "sup_nano_seeder", "gen_nano_catalyst"],
		"desc_full": "纳米浓度自然衰减 -50%（浓度场保持更久）",
		"kind_combo": {_KIND_SUPPORT: 1, _KIND_FORT: 1},
		"fields": [ComboFieldState.FIELD_NANO],
		"mechanisms": ["nano_concentration", "nano_spread"],   # 浓度增伤 + 感染扩散
		"full_mechanisms": ["nano_decay_half"],                # v21 P1 满档：浓度衰减减半
	},
	COMBO_LASER: {
		"id": COMBO_LASER,
		"name": "光束谐振链",
		"icon": "✨",
		"desc": "激光标记积累谐振，光束武器多重攻击+反射",
		"mod_ids": ["gen_beam_splitter", "gen_reflector_array", "air_targeting_laser", "eng_optical_fiber"],
		"mod_combo_min": 2,
		"mod_combo_full": ["gen_beam_splitter", "gen_reflector_array", "air_targeting_laser", "eng_optical_fiber"],
		"desc_full": "光束反射次数 +1（单次命中最多反射 2 个相邻目标）",
		"kind_combo": {_KIND_AIR: 1, _KIND_LIGHT: 1},
		"fields": [],
		"mechanisms": ["laser_resonance", "beam_split", "beam_reflect"],   # 谐振累积 + 多重攻击 + 反射
		"full_mechanisms": ["beam_reflect_plus1"],                          # v21 P1 满档：反射次数+1
	},
	COMBO_RECON: {
		"id": COMBO_RECON,
		"name": "侦察链式",
		"icon": "🎯",
		"desc": "无人机+雷达双标记，狙击手集火链式触发弱点暴露",
		"mod_ids": ["rec_phased_radar", "sup_targeting_drone", "gen_weakpoint_analyzer"],
		"mod_combo_min": 2,
		"mod_combo_full": ["rec_phased_radar", "sup_targeting_drone", "gen_weakpoint_analyzer"],
		"desc_full": "弱点暴露全队共享（任意友军命中双标记目标即可触发）",
		"kind_combo": {_KIND_LIGHT: 2},   # ≥2 轻装（含狙击/侦察）
		"fields": [],
		"mechanisms": ["radar_lock", "weakpoint_expose"],   # 雷达锁定 + 弱点暴露
		"full_mechanisms": ["weakpoint_team_share"],         # v21 P1 满档：弱点暴露全队共享
	},
	COMBO_CHEM: {
		"id": COMBO_CHEM,
		"name": "化学污染场",
		"icon": "☠",
		"desc": "化学弹累积战场污染，腐蚀降防+污染扩散",
		"mod_ids": ["art_chem_cluster", "aa_acid_warhead", "eng_chem_sprayer", "gen_pollution_accumulator"],
		"mod_combo_min": 2,
		"mod_combo_full": ["art_chem_cluster", "aa_acid_warhead", "eng_chem_sprayer", "gen_pollution_accumulator"],
		"desc_full": "污染跨列蔓延（扩散不再限邻接，可感染异列目标）",
		"kind_combo": {_KIND_SUPPORT: 1, _KIND_ARMOR: 1},
		"fields": [ComboFieldState.FIELD_CHEM],
		"mechanisms": ["chem_corrosion", "chem_spread"],   # 化学腐蚀降防 + 污染扩散
		"full_mechanisms": ["chem_cross_column"],           # v21 P1 满档：污染跨列蔓延
	},
}

# ─────────────────────────────────────────────
#  检测 API
# ─────────────────────────────────────────────

## v21 P1 套装档位常量（detect_card_combo_tiers 返回值）
const TIER_BASIC := "basic"
const TIER_FULL := "full"

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


## v21 P1: 检测单卡激活的套路档位（向后兼容 detect_card_combos——其返回 Array 行为不变）。
## 参数 mods_on_card: 该卡已安装的改造 id 列表（String）。
## 返回：{combo_id: TIER_BASIC|TIER_FULL}。
##   basic = 装 ≥mod_combo_min 个配套改造（现有效果不变）
##   full  = 集齐 mod_combo_full 全部配套改造（4 件套机制升级；纳米/侦察为 3 条集齐）
## 混装不误触发：只认本套路列表内的 id，凑不满 min 不入表。
static func detect_card_combo_tiers(mods_on_card: Array) -> Dictionary:
	var tiers: Dictionary = {}
	if mods_on_card.is_empty():
		return tiers
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
			# 满档判定：mod_combo_full 列表内的 id 全部命中（缺一不可）
			var full_list: Array = def.get("mod_combo_full", [])
			var is_full: bool = not full_list.is_empty()
			for fid in full_list:
				if not mods_on_card.has(String(fid)):
					is_full = false
					break
			tiers[combo_id] = TIER_FULL if is_full else TIER_BASIC
	return tiers

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


## v21 P1: 从档位表（detect_card_combo_tiers 产物）提取满档套路的机制升级 flag 合集。
## 参数 full_tier_combos: 满档 combo_id 数组（任一友军卡达成满档即计入）。
## 返回 Array[String]，如 ["incendiary_death_seed", ...]——combo_engine 把它并入全队机制表。
static func get_full_mechanisms(full_tier_combos: Array) -> Array:
	var mechs: Array = []
	for combo_id in full_tier_combos:
		var def: Dictionary = COMBOS.get(String(combo_id), {})
		for m in def.get("full_mechanisms", []):
			var ms: String = String(m)
			if not mechs.has(ms):
				mechs.append(ms)
	return mechs


# ─────────────────────────────────────────────
#  v21 P2 搭档协同（P2-1 五对）
# ─────────────────────────────────────────────
## 角色常量（引用 UnitRoles，避免数值双写）
const PAIR_ROLES := {
	"INFANTRY": 0, "ARMOR": 1, "ARTILLERY": 2, "ANTI_AIR": 3, "AIR": 4,
	"RECON": 5, "ENGINEER": 6, "FORT": 7, "UNIVERSAL": 8,
}

## 5 对搭档定义。激活条件：双方角色各至少 1 个存活单位在场（pair_synergy_engine 扫描）。
## - id/name/icon/desc: UI（combo_status_strip"搭档协同"区）用
## - pair: [角色A, 角色B]
## - kind: 机制类型
##     mark       — A 侧命中写目标 meta 标记，B 侧攻击消费（无持久 buff，无需记账）
##     onetime    — 首次共存一次性生效（battle-local stats 改写，不撤销；注释声明）
##     numeric    — 数值增益，对称 apply/revoke（H11 记账范式，meta _pair_buff_applied）
## - effect: 执行参数（消费点各自解读）
const PAIR_SYNERGIES: Dictionary = {
	"pair_recon_artillery": {
		"id": "pair_recon_artillery",
		"name": "侦察×火炮",
		"icon": "🎯",
		"desc": "侦察命中标记目标：火炮攻击必暴 + 溅射伤害 +50%",
		"pair": [5, 2],   # RECON × ARTILLERY
		"kind": "mark",
		"effect": {mark_meta = "_pair_art_mark_until", mark_duration = 5.0, crit_force = true, splash_mult = 1.5},
	},
	"pair_engineer_infantry": {
		"id": "pair_engineer_infantry",
		"name": "工程×步兵",
		"icon": "🛠",
		"desc": "工程在场：步兵防御（轻装轴）+20%（一次性，战斗内持续）",
		"pair": [6, 0],   # ENGINEER × INFANTRY
		"kind": "onetime",
		"effect": {target_role = 0, stat_field = "defense_light", bonus = 0.20},
	},
	"pair_aa_air": {
		"id": "pair_aa_air",
		"name": "防空×己方空中",
		"icon": "🛡",
		"desc": "防空与己方空中共存：防空对空攻速 +15%（可撤销）",
		"pair": [3, 4],   # ANTI_AIR × AIR
		"kind": "numeric",
		"effect": {target_role = 3, speed_mult = 1.15},
	},
	"pair_armor_infantry": {
		"id": "pair_armor_infantry",
		"name": "装甲×轻装",
		"icon": "⚔",
		"desc": "装甲与轻装共存：双方部署延迟 -15%（可撤销）",
		"pair": [1, 0],   # ARMOR × INFANTRY
		"kind": "numeric",
		"effect": {roles = [1, 0], deploy_delay_bonus = -0.15},
	},
	"pair_fort_support": {
		"id": "pair_fort_support",
		"name": "堡垒×支援",
		"icon": "🏰",
		"desc": "堡垒与支援共存：堡垒防护光环范围 +1 列",
		"pair": [7, 8],   # FORT × UNIVERSAL（支援主类无独立角色，归一为兜底角色，见 unit_roles 注释）
		"kind": "aura_range",
		"effect": {category = 4, range_bonus = 1},   # category 4 = AuraData.Category.FORTRESS_DEF
	},
}

## 获取全对激活状态（pair_synergy_engine 产出的 {pair_id: bool}）
static func get_active_pair_defs(active_pairs: Array) -> Array:
	var defs: Array = []
	for pid in active_pairs:
		var d: Dictionary = PAIR_SYNERGIES.get(String(pid), {})
		if not d.is_empty():
			defs.append(d)
	return defs


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
