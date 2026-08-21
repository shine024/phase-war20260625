extends RefCounted
class_name LevelTacticalThemes
## v10 解题式玩法 Phase 1：关卡战术主题（题面系统）。
##
## 背景：此前 100 关波次 bias 是随机 roll（0-3 掷骰），敌方构成没有"战术特征"，
## 玩家无从针对性构筑，只能数值碾压。本表为每关分配一个确定性的"战术主题"，
## 作为玩家可侦察、可解的"题面"：
##   - 战前：world_map 关卡弹窗显示"敌情简报"（主题 + 威胁 + 建议解法）
##   - 战中：enemy_spawn_hud 波次预警按主题显示下波构成（Phase 2）
##   - 生成：LevelSpawnSequences 读主题生成波次 bias 模式（取代随机 roll）
##
## 分配规则（可复现，种子 = level × 2654435761，与 LevelSpawnSequences 同模式）：
##   1. 每时代首关（Lv1/21/41/61/81 教学关）固定 SWARM_RUSH（轻量，全 basic）
##   2. 其余关卡 hash 分配；一战时代（1-20）池内无 aircraft archetype，
##      AIR_SUPREMACY 不参与该时代分配（时代约束表 ERA_AVAILABLE_THEMES）
##   3. 时代内相邻关卡主题去重（连续两关不同题，避免重复感）
##
## 容错：_pick_archetype_with_bias 匹配池为空时回退全池随机（battle_spawn_system），
##       主题 bias 在时代池内无匹配也不会崩，只是退化为普通波。

const LevelEras = preload("res://data/level_eras.gd")

## 主题 ID 常量（供外部引用，避免魔法字符串）
const ARMOR_PUSH := "armor_push"
const AIR_SUPREMACY := "air_supremacy"
const ARTILLERY_POSITION := "artillery_position"
const SWARM_RUSH := "swarm_rush"
const FORTRESS_HOLD := "fortress_hold"
const INFILTRATION := "infiltration"
const MIXED_GRIND := "mixed_grind"
const ELITE_PUSH := "elite_push"

## 主题定义表
## 结构：
##   name        — 中文名（战报/弹窗显示）
##   threat      — 威胁描述（题面：敌方在做什么）
##   advice      — 建议解法（提示玩家可用什么破解，引导构筑）
##   color       — 显示色（弹窗/预警 HUD 用，hex）
##   wave_patterns — 波次 bias 模式：[{w: 权重, tags: [...]}, ...]
##                   生成时按权重抽一档（rng 可复现）；tags 空数组 = 不限
##   comp_mod    — composition 修正（叠加在 LevelSpawnSequences 默认值上）：
##                   elite_delta / basic_floor：ELITE_PUSH 提精英，SWARM_RUSH 保基础量
const THEMES: Dictionary = {
	ARMOR_PUSH: {
		"name": "装甲突击",
		"threat": "敌方以装甲/坦克单位为主力推进，防御高、对轻装伤害高",
		"advice": "建议：穿甲改造/反坦克单位/工兵爆破专精",
		"color": "#e0a458",
		"wave_patterns": [
			{"w": 0.75, "tags": ["armored", "tank"]},
			{"w": 0.15, "tags": []},
			{"w": 0.10, "tags": ["infantry"]},
		],
		"comp_mod": {},
	},
	AIR_SUPREMACY: {
		"name": "空中压制",
		"threat": "敌方掌握制空权，空中单位高速突袭后排",
		"advice": "建议：防空单位（空域封锁）/堡垒对空特攻",
		"color": "#7fd4ff",
		"wave_patterns": [
			{"w": 0.70, "tags": ["aircraft"]},
			{"w": 0.20, "tags": []},
			{"w": 0.10, "tags": ["infantry"]},
		],
		"comp_mod": {},
	},
	ARTILLERY_POSITION: {
		"name": "炮兵阵地",
		"threat": "敌方构筑炮兵阵地，曲射火力覆盖我方全阵",
		"advice": "建议：快速单位近身穿插/侦察标记反炮兵",
		"color": "#d47fd4",
		"wave_patterns": [
			{"w": 0.55, "tags": ["artillery"]},
			{"w": 0.30, "tags": ["infantry"]},   # 护卫波
			{"w": 0.15, "tags": ["armored"]},
		],
		"comp_mod": {},
	},
	SWARM_RUSH: {
		"name": "蜂群冲锋",
		"threat": "敌方以大量基础单位持续冲击，靠数量淹没阵地",
		"advice": "建议：溅射/范围伤害/堡垒阵地坚守",
		"color": "#a0d468",
		"wave_patterns": [
			{"w": 0.85, "tags": ["infantry"]},
			{"w": 0.15, "tags": []},
		],
		"comp_mod": {"elite_delta": -0.10},   # 蜂群关精英更少、基础量更大
	},
	FORTRESS_HOLD: {
		"name": "阵地防御",
		"threat": "敌方依托固定阵地防御，火力持续且纵深梯次配置",
		"advice": "建议：温压弹/攻城武器（对堡垒特攻）/远程消耗",
		"color": "#ac92eb",
		"wave_patterns": [
			# turret 仅一战池存在；其余时代由 spawn 侧回退全池（tag 匹配空→随机），
			# 因此中后期此主题自然表现为"支援/持续火力阵地"
			{"w": 0.55, "tags": ["turret", "sustained", "support"]},
			{"w": 0.25, "tags": ["artillery"]},
			{"w": 0.20, "tags": ["infantry"]},
		],
		"comp_mod": {},
	},
	INFILTRATION: {
		"name": "斩首渗透",
		"threat": "敌方高速渗透单位绕过前线，直击我方后排核心",
		"advice": "建议：堡垒护后排/侦察预警/堡垒对空+对地拦截",
		"color": "#ed5565",
		"wave_patterns": [
			{"w": 0.55, "tags": ["fast"]},
			{"w": 0.25, "tags": ["stealth"]},   # stealth 仅近未来池存在，前期自然退化为 fast
			{"w": 0.20, "tags": []},
		],
		"comp_mod": {},
	},
	MIXED_GRIND: {
		"name": "混合绞杀",
		"threat": "敌方多兵种混编协同，需要同时应对地面与空中威胁",
		"advice": "建议：均衡编队/多功能单位/防空+反甲双解",
		"color": "#f6bb42",
		"wave_patterns": [
			{"w": 0.25, "tags": ["armored"]},
			{"w": 0.25, "tags": ["infantry"]},
			{"w": 0.25, "tags": ["aircraft"]},
			{"w": 0.25, "tags": []},
		],
		"comp_mod": {},
	},
	ELITE_PUSH: {
		"name": "精锐推进",
		"threat": "敌方精锐部队小规模高质量推进，单体战力极强",
		"advice": "建议：集火标记/暴击流/控制类改造逐个击破",
		"color": "#ff8a9c",
		"wave_patterns": [
			{"w": 0.50, "tags": []},
			{"w": 0.30, "tags": ["armored"]},
			{"w": 0.20, "tags": ["fast"]},
		],
		"comp_mod": {"elite_delta": 0.15},   # 精英比例显著提高
	},
}

## 时代可用主题约束：一战（Era.WW1=0）池内无 aircraft archetype，AIR_SUPREMACY 不参与分配。
## 教学关固定 SWARM_RUSH 不在约束表内单独处理。
const ERA_AVAILABLE_THEMES: Dictionary = {
	0: [ARMOR_PUSH, ARTILLERY_POSITION, SWARM_RUSH, FORTRESS_HOLD, INFILTRATION, MIXED_GRIND, ELITE_PUSH],
	1: [ARMOR_PUSH, AIR_SUPREMACY, ARTILLERY_POSITION, SWARM_RUSH, FORTRESS_HOLD, INFILTRATION, MIXED_GRIND, ELITE_PUSH],
	2: [ARMOR_PUSH, AIR_SUPREMACY, ARTILLERY_POSITION, SWARM_RUSH, FORTRESS_HOLD, INFILTRATION, MIXED_GRIND, ELITE_PUSH],
	3: [ARMOR_PUSH, AIR_SUPREMACY, ARTILLERY_POSITION, SWARM_RUSH, FORTRESS_HOLD, INFILTRATION, MIXED_GRIND, ELITE_PUSH],
	4: [ARMOR_PUSH, AIR_SUPREMACY, ARTILLERY_POSITION, SWARM_RUSH, FORTRESS_HOLD, INFILTRATION, MIXED_GRIND, ELITE_PUSH],
}

## 手工关卡主题覆盖表：level → theme_id。
## 关卡题面 = 关卡级"战斗配制"（确定的构成倾向，不是随机的）。
## 程序分配（种子哈希）保证未手工配置的关卡也有确定题面；此表为设计精调入口。
## 示例：{10: ARTILLERY_POSITION, 25: AIR_SUPREMACY}
const MANUAL_OVERRIDES: Dictionary = {}

## 主题分配缓存：level → theme_id
static var _assignment_cache: Dictionary = {}


## 获取指定关卡的战术主题 ID（确定性：同关恒同主题）。
static func get_theme_id_for_level(level: int) -> String:
	var lv: int = clampi(level, 1, 100)
	if _assignment_cache.has(lv):
		return String(_assignment_cache[lv])
	var theme_id: String = _assign_theme(lv)
	_assignment_cache[lv] = theme_id
	return theme_id


## 获取主题完整定义（含 name/threat/advice/color/wave_patterns/comp_mod）。
## 主题 ID 无效时返回 SWARM_RUSH 定义（防御性兜底）。
static func get_theme(theme_id: String) -> Dictionary:
	var t: Dictionary = THEMES.get(theme_id, {})
	if t.is_empty():
		t = THEMES[SWARM_RUSH]
	return t


## 获取指定关卡主题的显示信息（world_map 弹窗 / HUD 用）。
## 返回 {id, name, threat, advice, color}；level 越界按 clamp 后处理。
static func get_theme_display(level: int) -> Dictionary:
	var tid: String = get_theme_id_for_level(level)
	var t: Dictionary = get_theme(tid)
	return {
		"id": tid,
		"name": String(t.get("name", "")),
		"threat": String(t.get("threat", "")),
		"advice": String(t.get("advice", "")),
		"color": String(t.get("color", "#ffffff")),
	}


## 按主题生成单波 bias_tags（供 LevelSpawnSequences._make_wave_spec 调用）。
## rng 由调用方传入（保证整关序列可复现）；tags 空数组 = 本波不限。
static func roll_wave_bias(theme_id: String, rng: RandomNumberGenerator) -> Array:
	var t: Dictionary = get_theme(theme_id)
	var patterns: Array = t.get("wave_patterns", [])
	if patterns.is_empty():
		return []
	var total_w: float = 0.0
	for p in patterns:
		total_w += float(p.get("w", 0.0))
	if total_w <= 0.0:
		return []
	var roll: float = rng.randf() * total_w
	var acc: float = 0.0
	for p in patterns:
		acc += float(p.get("w", 0.0))
		if roll <= acc:
			var tags: Array = p.get("tags", [])
			return tags if tags is Array else []
	# 浮点边界兜底：取最后一档
	var last: Dictionary = patterns[patterns.size() - 1]
	var fallback_tags: Array = last.get("tags", [])
	return fallback_tags if fallback_tags is Array else []


## archetype tag → 中文显示名（波次预警 HUD 用）
const TAG_NAMES_CN: Dictionary = {
	"infantry": "步兵",
	"vehicle": "载具",
	"armored": "装甲",
	"tank": "坦克",
	"aircraft": "空中",
	"artillery": "炮兵",
	"turret": "工事",
	"fast": "快速",
	"stealth": "潜行",
	"support": "支援",
	"sustained": "持续",
	"antitank": "反坦克",
	"frontline": "前线",
	"backline": "后排",
}


## tag 同义归并表（显示层去重）：键值对映射到同一中文显示。
## armored/tank 都是"装甲"，vehicle 是"载具"独立保留。
const TAG_SYNONYM_MERGE: Dictionary = {
	"tank": "armored",  # tank 归并到 armored 显示
}


## tag 数组 → 预警显示文本（如 ["armored","tank"] → "装甲"，同义 tag 归并去重）。
static func tags_to_display(tags: Array) -> String:
	if tags.is_empty():
		return "混合"
	var names: Array[String] = []
	for t in tags:
		var key: String = String(t)
		# 同义归并（tank → armored 再查中文名）
		key = String(TAG_SYNONYM_MERGE.get(key, key))
		var cn: String = String(TAG_NAMES_CN.get(key, ""))
		if not cn.is_empty() and not names.has(cn):
			names.append(cn)
	if names.is_empty():
		return "混合"
	return "·".join(names)


## 获取主题的 composition 修正（叠加在默认比例上）。
## 返回 {elite_delta: float}；无修正返回空字典。
static func get_composition_mod(theme_id: String) -> Dictionary:
	var t: Dictionary = get_theme(theme_id)
	var mod: Dictionary = t.get("comp_mod", {})
	return mod if mod is Dictionary else {}


## ─────────────────────────────────────────────
##  内部：主题分配
## ─────────────────────────────────────────────

static func _assign_theme(level: int) -> String:
	# 手工覆盖优先：设计入口（关卡题面最终形态是手工设计，程序分配只是占位）
	if MANUAL_OVERRIDES.has(level):
		var manual_id: String = String(MANUAL_OVERRIDES[level])
		if THEMES.has(manual_id):
			return manual_id

	var era: int = LevelEras.get_era(level)
	var in_era: int = ((level - 1) % 20) + 1  # 1..20 时代内进度

	# 每时代首关 = 教学关，固定蜂群冲锋（全基础单位，无战术复杂度）
	if in_era == 1:
		return SWARM_RUSH

	var candidates: Array = ERA_AVAILABLE_THEMES.get(era, [])
	if candidates.is_empty():
		return SWARM_RUSH

	# hash 分配（可复现，与 LevelSpawnSequences 的种子模式一致）
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 2654435761
	var theme_id: String = String(candidates[rng.randi_range(0, candidates.size() - 1)])

	# 相邻关去重：若与上一关同主题，改抽下一档（保持确定性——同关恒同结果）
	if level > 1:
		var prev_id: String = _assign_theme_uncached(level - 1)
		if prev_id == theme_id:
			var idx: int = candidates.find(theme_id)
			var next_idx: int = (idx + 1) % candidates.size()
			theme_id = String(candidates[next_idx])
	# 时代末关去重：下一关（新时代首关）固定 SWARM_RUSH 教学，末关不得与它撞车
	# （Lv40/41 曾出现 swarm_rush 相邻重复——去重只查上一关不知道下一关是教学关）
	if in_era == 20 and theme_id == SWARM_RUSH and candidates.size() > 1:
		var end_idx: int = candidates.find(SWARM_RUSH)
		theme_id = String(candidates[(end_idx + 1) % candidates.size()])
	return theme_id


## 无缓存的分配（供相邻关去重查询，避免缓存污染判断链）。
static func _assign_theme_uncached(level: int) -> String:
	if _assignment_cache.has(level):
		return String(_assignment_cache[level])
	return _assign_theme(level)
