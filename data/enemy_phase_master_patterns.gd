extends RefCounted
class_name EnemyPhaseMasterPatterns
## v9.0 敌方相位师固定套路系统（参考龙崖/巴尔的遗产 Boss 套路设计）
##
## 核心理念：每个相位师有明确的"套路身份"——固定的配兵逻辑 + 补兵规则。
## 单位死亡后按套路精准补位（哪个兵掉了补哪个兵），而非纯随机。
## 补兵频率随玩家击杀速度动态调整（杀得快→补得慢，给玩家压制窗口；
## 杀得慢→补得快，维持压力）。
##
## 6 套固定套路：
##   iron_bastion     钢铁壁垒   护盾+单位数防御，优先补装甲/堡垒维持前排墙
##   inferno_furnace  炼狱熔炉   DoT+死亡爆炸，优先补高HP单位撑时间
##   thunder_cataclysm 雷霆万钧  连锁闪电+能量阈值，优先补高攻速步兵/空中
##   void_devour      虚空吞噬   能量吸血+斩杀，优先补支援/空中维持虹吸链
##   synergy_hybrid   协同复合   双势力协同，优先补缺失协同元素
##   omni_ultimate    终焉全能   全能型，按原序列+反制灵活补
##
## 消费方：enemy_phase_field_driver.gd（setup 时识别套路，单位死亡时按套路补位）

const GC = preload("res://resources/game_constants.gd")

# ─────────────────────────────────────────────
#  套路 ID 常量
# ─────────────────────────────────────────────
const PATTERN_IRON_BASTION    := "iron_bastion"
const PATTERN_INFERNO_FURNACE := "inferno_furnace"
const PATTERN_THUNDER_CATACLYSM := "thunder_cataclysm"
const PATTERN_VOID_DEVOUR     := "void_devour"
const PATTERN_SYNERGY_HYBRID  := "synergy_hybrid"
const PATTERN_OMNI_ULTIMATE   := "omni_ultimate"
const PATTERN_NONE            := "none"   # 兜底：未识别套路，走原序列补兵

# CombatKind 整数（避免 const 字典跨类求值时序问题，硬编码更稳）
# LIGHT=0, ARMOR=1, SUPPORT=2, AIR=3, FORT=4
const _KIND_LIGHT  := 0
const _KIND_ARMOR  := 1
const _KIND_SUPPORT := 2
const _KIND_AIR    := 3
const _KIND_FORT   := 4

## 6 套路定义（补兵策略 + 识别条件 + 动态参数）
## - preferred_kinds: 补兵时优先选的 combat_kind（从 platforms 池中筛）
## - fallback_any: preferred 池无候选时是否回退任意平台（默认 true，避免卡死不出兵）
## - respawn_delay_base: 基础补兵延迟（秒）
## - respawn_delay_min/max: 动态调节上下限
## - max_respawns_per_slot: 每个槽位最多补兵次数（鼓励玩家速杀，超过即永久留空）
## - kill_speed_sensitivity: 玩家击杀速度对补兵延迟的影响系数（1.0=标准，0=不受影响）
## - detect_traits: 自动识别用的 trait effects key（命中任一即判定该套路）
## - detect_spell_effects: 自动识别用的 active/passive spell effect key
const PATTERNS: Dictionary = {
	PATTERN_IRON_BASTION: {
		"id": PATTERN_IRON_BASTION,
		"name": "钢铁壁垒",
		"icon": "🛡",
		"description": "护盾再生+单位数防御，越打越硬",
		"preferred_kinds": [_KIND_ARMOR, _KIND_FORT],
		"preferred_tags": ["tank", "armored", "fortress", "turret"],
		"fallback_any": true,
		"respawn_delay_base": 3.5,
		"respawn_delay_min": 2.0,
		"respawn_delay_max": 8.0,
		"max_respawns_per_slot": 3,
		"kill_speed_sensitivity": 1.2,   # 玩家速杀时拉长补兵（坦克套路更需要压制窗口）
		"detect_traits": ["damage_cap", "unit_count_defense", "cheat_death_chance"],
		"detect_spell_effects": ["ward_bulwark", "energy_shield", "plate_shield", "dome_barrier", "death_shield"],
	},
	PATTERN_INFERNO_FURNACE: {
		"id": PATTERN_INFERNO_FURNACE,
		"name": "炼狱熔炉",
		"icon": "🔥",
		"description": "全局灼烧+死亡爆炸，时间压力型",
		"preferred_kinds": [_KIND_ARMOR, _KIND_SUPPORT],
		"preferred_tags": ["vehicle", "tank", "artillery", "armored"],
		"fallback_any": true,
		"respawn_delay_base": 3.0,
		"respawn_delay_min": 2.0,
		"respawn_delay_max": 7.0,
		"max_respawns_per_slot": 3,
		"kill_speed_sensitivity": 1.0,
		"detect_traits": ["global_dot", "auto_resurrect", "auto_revive_once", "full_resurrect_once"],
		"detect_spell_effects": ["napalm_explosion", "hellfire_explosion", "meteor_apocalypse", "hell_inferno", "death_explosion", "burning_aura", "self_damage_aura"],
	},
	PATTERN_THUNDER_CATACLYSM: {
		"id": PATTERN_THUNDER_CATACLYSM,
		"name": "雷霆万钧",
		"icon": "⚡",
		"description": "连锁闪电+能量阈值爆发",
		"preferred_kinds": [_KIND_LIGHT, _KIND_AIR],
		"preferred_tags": ["infantry", "fast", "elite", "frontline"],
		"fallback_any": true,
		"respawn_delay_base": 2.5,   # 雷霆套路节奏快，补兵略快
		"respawn_delay_min": 1.5,
		"respawn_delay_max": 6.0,
		"max_respawns_per_slot": 4,
		"kill_speed_sensitivity": 0.8,
		"detect_traits": [],
		"detect_spell_effects": ["tesla_chain", "thunderstorm_chain", "lightning_chain", "thunder_chain", "chain_lightning", "auto_lightning", "death_chain_lightning"],
	},
	PATTERN_VOID_DEVOUR: {
		"id": PATTERN_VOID_DEVOUR,
		"name": "虚空吞噬",
		"icon": "🕳",
		"description": "能量吸血+最大HP抽血+斩杀",
		"preferred_kinds": [_KIND_SUPPORT, _KIND_AIR, _KIND_LIGHT],
		"preferred_tags": ["elite", "infantry", "fast", "support"],
		"fallback_any": true,
		"respawn_delay_base": 3.2,
		"respawn_delay_min": 2.0,
		"respawn_delay_max": 7.0,
		"max_respawns_per_slot": 3,
		"kill_speed_sensitivity": 1.0,
		"detect_traits": ["permanent_darkness", "mass_convert_once", "instant_delete", "void_damage_boost"],
		"detect_spell_effects": ["void_apocalypse", "void_explosion", "abyss_apocalypse", "devour_single", "darkness_debuff", "max_hp_drain", "energy_drain", "life_energy_drain"],
	},
	PATTERN_SYNERGY_HYBRID: {
		"id": PATTERN_SYNERGY_HYBRID,
		"name": "协同复合",
		"icon": "☯",
		"description": "双势力协同，维持元素链",
		"preferred_kinds": [],   # 协同套路按 faction tag 补，不按 combat_kind
		"preferred_tags": [],    # 动态：setup 时按 master faction 填充
		"fallback_any": true,
		"respawn_delay_base": 3.0,
		"respawn_delay_min": 2.0,
		"respawn_delay_max": 7.0,
		"max_respawns_per_slot": 3,
		"kill_speed_sensitivity": 1.0,
		"detect_traits": ["synergy_boost"],
		"detect_spell_effects": [],
	},
	PATTERN_OMNI_ULTIMATE: {
		"id": PATTERN_OMNI_ULTIMATE,
		"name": "终焉全能",
		"icon": "★",
		"description": "三技能循环+无限成长，速杀或灭亡",
		"preferred_kinds": [_KIND_ARMOR, _KIND_AIR, _KIND_LIGHT],   # 全能型混合补
		"preferred_tags": ["tank", "elite", "infantry", "vehicle"],
		"fallback_any": true,
		"respawn_delay_base": 2.5,   # 终极套路补兵快，维持高压
		"respawn_delay_min": 1.5,
		"respawn_delay_max": 6.0,
		"max_respawns_per_slot": 5,   # 终极套路补兵次数多，玩家必须杀 boss 而非清兵
		"kill_speed_sensitivity": 0.6,   # 受玩家击杀速度影响小（boss 本身才是目标）
		"detect_traits": ["infinite_scaling", "scaling_per_cast", "time_scaling"],
		"detect_spell_effects": [],
	},
}

# ─────────────────────────────────────────────
#  30 位相位师手填套路分配（权威表）
#  缺失 pattern_id 时 detect_pattern 自动识别兜底
# ─────────────────────────────────────────────
const MASTER_PATTERN_MAP: Dictionary = {
	# 钢铁壁垒（6）
	"enemy_master_001": PATTERN_IRON_BASTION,   # 马库斯
	"enemy_master_005": PATTERN_IRON_BASTION,   # 克劳斯
	"enemy_master_009": PATTERN_IRON_BASTION,   # 费米
	"enemy_master_016": PATTERN_IRON_BASTION,   # 阿特拉斯
	"enemy_master_022": PATTERN_IRON_BASTION,   # 铁骑
	"enemy_master_026": PATTERN_IRON_BASTION,   # 赫淮斯托斯
	# 炼狱熔炉（6）
	"enemy_master_002": PATTERN_INFERNO_FURNACE, # 伊格尼斯
	"enemy_master_006": PATTERN_INFERNO_FURNACE, # 赫卡特
	"enemy_master_010": PATTERN_INFERNO_FURNACE, # 普罗米修斯
	"enemy_master_017": PATTERN_INFERNO_FURNACE, # 苏尔特
	"enemy_master_023": PATTERN_INFERNO_FURNACE, # 凤凰
	"enemy_master_027": PATTERN_INFERNO_FURNACE, # 赫卡特神
	# 雷霆万钧（6）
	"enemy_master_003": PATTERN_THUNDER_CATACLYSM, # 沃尔特
	"enemy_master_007": PATTERN_THUNDER_CATACLYSM, # 索尔
	"enemy_master_011": PATTERN_THUNDER_CATACLYSM, # 宙斯
	"enemy_master_018": PATTERN_THUNDER_CATACLYSM, # 雷神
	"enemy_master_024": PATTERN_THUNDER_CATACLYSM, # 赛勒斯
	"enemy_master_028": PATTERN_THUNDER_CATACLYSM, # 托尔
	# 虚空吞噬（6）
	"enemy_master_004": PATTERN_VOID_DEVOUR, # 奈克萨斯
	"enemy_master_008": PATTERN_VOID_DEVOUR, # 萨洛斯
	"enemy_master_012": PATTERN_VOID_DEVOUR, # 阿扎托斯
	"enemy_master_019": PATTERN_VOID_DEVOUR, # 尼德霍格
	"enemy_master_025": PATTERN_VOID_DEVOUR, # 深渊
	"enemy_master_029": PATTERN_VOID_DEVOUR, # 尼克斯
	# 协同复合（5）
	"enemy_master_013": PATTERN_SYNERGY_HYBRID, # 卡尔 steel_flame
	"enemy_master_014": PATTERN_SYNERGY_HYBRID, # 维克多 thunder_steel
	"enemy_master_015": PATTERN_SYNERGY_HYBRID, # 塞拉菲娜 void_flame
	"enemy_master_020": PATTERN_SYNERGY_HYBRID, # 泰尔 steel_thunder
	"enemy_master_021": PATTERN_SYNERGY_HYBRID, # 克尔加 flame_void
	# 终焉全能（1）
	"enemy_master_030": PATTERN_OMNI_ULTIMATE, # 奥米伽
}

# ─────────────────────────────────────────────
#  势力 family → tag 映射（协同套路补兵用）
#  master faction 如 "steel_flame" 拆成 ["steel", "flame"]，按 tag 匹配平台
# ─────────────────────────────────────────────
const FACTION_TAGS: Dictionary = {
	"steel":   ["tank", "armored", "vehicle", "turret", "fortress"],
	"flame":   ["vehicle", "artillery", "fast"],
	"thunder": ["infantry", "elite", "fast"],
	"void":    ["elite", "infantry", "fast", "support"],
	"all":     ["tank", "elite", "infantry", "vehicle"],
}

# ─────────────────────────────────────────────
#  API
# ─────────────────────────────────────────────

## 获取相位师套路：优先手填 MASTER_PATTERN_MAP，缺失则按数据自动识别
static func get_pattern(master_config: Dictionary) -> String:
	var mid: String = String(master_config.get("id", ""))
	# 1. 手填权威表
	if not mid.is_empty() and MASTER_PATTERN_MAP.has(mid):
		return String(MASTER_PATTERN_MAP[mid])
	# 2. 数据自带 pattern_id 字段
	var explicit: String = String(master_config.get("pattern_id", ""))
	if not explicit.is_empty() and PATTERNS.has(explicit):
		return explicit
	# 3. 自动识别兜底
	return detect_pattern(master_config)

## 自动识别套路（按 traits/spell effects 关键字匹配，得分最高者胜出）
static func detect_pattern(master_config: Dictionary) -> String:
	var scores: Dictionary = {
		PATTERN_IRON_BASTION: 0,
		PATTERN_INFERNO_FURNACE: 0,
		PATTERN_THUNDER_CATACLYSM: 0,
		PATTERN_VOID_DEVOUR: 0,
		PATTERN_SYNERGY_HYBRID: 0,
		PATTERN_OMNI_ULTIMATE: 0,
	}
	# 收集该 master 所有的 trait effect keys
	var trait_keys: Array = _collect_trait_effect_keys(master_config)
	# 收集该 master 所有的 spell effect keys
	var spell_keys: Array = _collect_spell_effect_keys(master_config)
	# 协同套路：faction 含 "_" 直接判定
	var faction: String = String(master_config.get("faction", ""))
	if faction.find("_") >= 0:
		scores[PATTERN_SYNERGY_HYBRID] += 3
	# 按各套路的 detect 列表计分
	for pattern_id in scores.keys():
		var pat: Dictionary = PATTERNS.get(pattern_id, {})
		for k in pat.get("detect_traits", []):
			if trait_keys.has(k):
				scores[pattern_id] += 2
		for k in pat.get("detect_spell_effects", []):
			if spell_keys.has(k):
				scores[pattern_id] += 1
	# 取最高分（平分时按固定优先级：终焉>协同>虚空>雷霆>炼狱>钢铁）
	var best_id: String = PATTERN_NONE
	var best_score: int = -1
	var priority_order: Array = [
		PATTERN_OMNI_ULTIMATE, PATTERN_SYNERGY_HYBRID, PATTERN_VOID_DEVOUR,
		PATTERN_THUNDER_CATACLYSM, PATTERN_INFERNO_FURNACE, PATTERN_IRON_BASTION,
	]
	for pid in priority_order:
		var s: int = int(scores.get(pid, 0))
		if s > best_score:
			best_score = s
			best_id = pid
	if best_score <= 0:
		return PATTERN_NONE
	return best_id

## 获取套路配置
static func get_pattern_config(pattern_id: String) -> Dictionary:
	return PATTERNS.get(pattern_id, {})

## 获取套路的协同补兵 tags（协同套路专用：按 master faction 派生）
static func get_synergy_tags(master_config: Dictionary) -> Array:
	var faction: String = String(master_config.get("faction", ""))
	var parts: Array = []
	if faction.find("_") >= 0:
		parts = faction.split("_")
	else:
		parts = [faction]
	var tags: Array = []
	for p in parts:
		var pstr: String = String(p)
		if FACTION_TAGS.has(pstr):
			for t in FACTION_TAGS[pstr]:
				if not tags.has(t):
					tags.append(t)
	return tags

# ─────────────────────────────────────────────
#  补兵选平台（核心：哪个兵掉了补哪个兵）
# ─────────────────────────────────────────────

## 按套路从 platforms_pool 中选一个补位平台。
## 核心规则："那个兵掉了补那个兵"——优先补位与死亡单位同类型的平台，维持阵型。
## 仅当死亡单位类型未知/不在池中时，才退回套路 preferred 选兵。
## 参数：
##   pattern_id      当前套路
##   platforms_pool  候选平台 id 列表（master equipment.platforms）
##   dead_platform_id 死亡单位的 archetype/platform id（空=未知，走套路 preferred）
##   dead_kind       死亡单位的 combat_kind（-1=未知）
##   alive_units     当前存活敌方单位列表（协同套路判断缺失元素用）
##   archetype_cfg_lookup  回调：platform_id -> archetype cfg（driver 注入，避免此处 preload 依赖）
## 返回：选中的 platform_id（空字符串=无候选）
static func pick_respawn_platform(
		pattern_id: String,
		platforms_pool: Array,
		dead_platform_id: String,
		dead_kind: int,
		alive_units: Array,
		archetype_cfg_lookup: Callable) -> String:
	if platforms_pool.is_empty():
		return ""

	# 规则1（最高优先）：死亡单位类型在池中 → 补同款（"那个兵掉了补那个兵"）
	if not dead_platform_id.is_empty() and platforms_pool.has(dead_platform_id):
		return dead_platform_id

	var pat: Dictionary = PATTERNS.get(pattern_id, {})
	if pat.is_empty():
		# 未识别套路且无死亡类型线索：随机选
		return String(platforms_pool[randi() % platforms_pool.size()])

	# 协同套路：优先补缺失的协同 tag
	if pattern_id == PATTERN_SYNERGY_HYBRID:
		return _pick_synergy_platform(platforms_pool, alive_units, archetype_cfg_lookup)

	# 通用套路：按 preferred_kinds / preferred_tags 筛选
	var preferred_kinds: Array = pat.get("preferred_kinds", [])
	var preferred_tags: Array = pat.get("preferred_tags", [])
	var candidates: Array = []   # 命中 preferred 的平台
	var others: Array = []       # 未命中的平台（fallback 用）
	for pid in platforms_pool:
		var pid_str := String(pid)
		var cfg: Dictionary = archetype_cfg_lookup.call(pid_str)
		if cfg.is_empty():
			others.append(pid_str)
			continue
		var kind: int = int(cfg.get("combat_kind", -1))
		var tags: Array = cfg.get("tags", [])
		var matched: bool = false
		if preferred_kinds.has(kind):
			matched = true
		else:
			for t in preferred_tags:
				if tags.has(t):
					matched = true
					break
		if matched:
			candidates.append(pid_str)
		else:
			others.append(pid_str)
	# 优先选 matched 候选；fallback_any 时回退 others
	if not candidates.is_empty():
		return String(candidates[randi() % candidates.size()])
	if bool(pat.get("fallback_any", true)) and not others.is_empty():
		return String(others[randi() % others.size()])
	return ""

## 协同套路补兵：优先补"场上缺失的协同元素"
static func _pick_synergy_platform(
		platforms_pool: Array,
		alive_units: Array,
		archetype_cfg_lookup: Callable) -> String:
	# 收集存活单位的 tags
	var alive_tags: Dictionary = {}   # tag -> count
	for u in alive_units:
		if u == null or not is_instance_valid(u):
			continue
		var arch_id: String = ""
		if "archetype_id" in u:
			arch_id = String(u.archetype_id)
		elif u.has_meta("archetype_id"):
			arch_id = String(u.get_meta("archetype_id"))
		if arch_id.is_empty():
			continue
		var cfg: Dictionary = archetype_cfg_lookup.call(arch_id)
		for t in cfg.get("tags", []):
			var ts: String = String(t)
			alive_tags[ts] = int(alive_tags.get(ts, 0)) + 1
	# 从池中选"存活最少"的协同元素平台（补缺）
	var best_pid: String = ""
	var best_score: int = 999999   # 越小越优先（存活数少）
	for pid in platforms_pool:
		var pid_str := String(pid)
		var cfg: Dictionary = archetype_cfg_lookup.call(pid_str)
		if cfg.is_empty():
			continue
		var tags: Array = cfg.get("tags", [])
		var min_alive: int = 999999
		for t in tags:
			var ts: String = String(t)
			min_alive = mini(min_alive, int(alive_tags.get(ts, 0)))
		if min_alive < best_score:
			best_score = min_alive
			best_pid = pid_str
	if not best_pid.is_empty():
		return best_pid
	# fallback：随机
	return String(platforms_pool[randi() % platforms_pool.size()]) if not platforms_pool.is_empty() else ""

# ─────────────────────────────────────────────
#  动态补兵延迟（玩家击杀速度影响）
# ─────────────────────────────────────────────

## 根据玩家近期击杀间隔计算补兵延迟。
## 击杀快（间隔短）→ 延迟拉长（给玩家压制窗口）；
## 击杀慢（间隔长）→ 延迟缩短（维持压力）。
## 参数：
##   pattern_id            当前套路
##   recent_kill_intervals 近期击杀间隔数组（秒，空数组=无数据用 base）
## 返回：本次补兵的延迟（秒）
static func compute_respawn_delay(pattern_id: String, recent_kill_intervals: Array) -> float:
	var pat: Dictionary = PATTERNS.get(pattern_id, {})
	var base: float = float(pat.get("respawn_delay_base", 3.0))
	var lo: float = float(pat.get("respawn_delay_min", 2.0))
	var hi: float = float(pat.get("respawn_delay_max", 7.0))
	var sens: float = float(pat.get("kill_speed_sensitivity", 1.0))
	if recent_kill_intervals.is_empty() or sens <= 0.0:
		return clampf(base, lo, hi)
	# 近期平均击杀间隔
	var avg: float = 0.0
	var n: int = 0
	for v in recent_kill_intervals:
		avg += float(v)
		n += 1
	if n > 0:
		avg /= float(n)
	else:
		return clampf(base, lo, hi)
	# 击杀间隔 < base 表示玩家杀得快 → 延迟 = base + (base - avg) × sens
	# 击杀间隔 > base 表示玩家杀得慢 → 延迟 = base - (avg - base) × sens × 0.5
	var delta: float = avg - base
	var adjusted: float = base
	if delta < 0.0:
		# 玩家杀得快：补兵变慢（惩罚速杀流，给压制窗口）
		adjusted = base + (-delta) * sens
	else:
		# 玩家杀得慢：补兵变快（维持压力）
		adjusted = base - delta * sens * 0.5
	return clampf(adjusted, lo, hi)

# ─────────────────────────────────────────────
#  辅助：收集 trait/spell effect keys
# ─────────────────────────────────────────────

static func _collect_trait_effect_keys(master_config: Dictionary) -> Array:
	var keys: Array = []
	for tr in master_config.get("traits", []):
		if not (tr is Dictionary):
			continue
		var effects: Dictionary = tr.get("effects", {})
		for k in effects.keys():
			var ks: String = String(k)
			if not keys.has(ks):
				keys.append(ks)
	return keys

static func _collect_spell_effect_keys(master_config: Dictionary) -> Array:
	var keys: Array = []
	for sp in master_config.get("active_spells", []) + master_config.get("passive_spells", []):
		if not (sp is Dictionary):
			continue
		var eff: String = String(sp.get("effect", ""))
		if not eff.is_empty() and not keys.has(eff):
			keys.append(eff)
	return keys
