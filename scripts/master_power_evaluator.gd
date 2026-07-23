extends RefCounted
class_name MasterPowerEvaluator
## 相位师战斗力评估系统 v7.x 单分量版
##
## 新公式（敌我同口径，用户主导设计）：
##   相位师总战力 = Σ 每张装备卡经过完整加成后的实战力
##
## 设计原则：
##   - 相位仪/符文/势力/改造/强化/进化 等所有加成的价值，
##     全部通过"它们给装备卡 stats 带来的提升"体现到卡战力里。
##   - 不再有"相位仪本体分(A维)"和"符文分(H维)"——那是重复计算。
##   - 相位仪槽位多 → 装更多卡 → 总战力自然更高（星级差异由此体现）。
##   - 特定相位仪的加成越强 → 每张卡加成后战力越高 → 总战力越高。
##
## 卡战力计算（与战场实际部署链一致）：
##   - 玩家：MasterPlatformPower.compute_player_card_power（7 层全加成）
##   - 敌方：MasterPlatformPower.compute_enemy_platform_power（archetype + 固有加成）
##
## 星级：1★~7★，纯由总分决定。

const _PlatformPower = preload("res://scripts/master_platform_power.gd")
const _LevelEras = preload("res://data/level_eras.gd")

# ─────────────────────────────────────────────
#  星级阈值（v7.x 单分量公式）
# ─────────────────────────────────────────────

# v7.x A: 敌方 platforms 对称玩家补齐到 6 槽。实测分布 min 1312/max 20767/median 5089。
# 阈值标定（6 卡满配口径，敌我同）：
#   - 1★ 新锐：空装/极弱（0-800）
#   - 2★ 精英：一战弱师（800-2000）
#   - 3★ 高手：一战师/二战弱（2000-4000）
#   - 4★ 大师：二战/冷战师（4000-7000）
#   - 5★ 宗师：现代/近未来弱（7000-11000）
#   - 6★ 传说：近未来强师/玩家中配（11000-16000）
#   - 7★ 神话：近未来 boss/玩家满配（16000+）
const STAR_TIERS: Array[Dictionary] = [
	{"stars": 1, "name": "新锐",   "min_score": 0,     "max_score": 800,     "color": "#88CCFF"},
	{"stars": 2, "name": "精英",   "min_score": 800,   "max_score": 2000,    "color": "#44FF88"},
	{"stars": 3, "name": "高手",   "min_score": 2000,  "max_score": 4000,    "color": "#FFCC00"},
	{"stars": 4, "name": "大师",   "min_score": 4000,  "max_score": 7000,    "color": "#FF8800"},
	{"stars": 5, "name": "宗师",   "min_score": 7000,  "max_score": 11000,   "color": "#FF4466"},
	{"stars": 6, "name": "传说",   "min_score": 11000, "max_score": 16000,   "color": "#CC44FF"},
	{"stars": 7, "name": "神话",   "min_score": 16000, "max_score": 9999999, "color": "#FFD700"},
]

## 敌方 UI/排行榜默认 tier（满配威胁评估）
## 战斗中由 game_manager 注入真实派生 tier，覆盖此默认。
const ENEMY_DEFAULT_TIER: String = "HIGH"


# ═════════════════════════════════════════════
#  主评估函数
# ═════════════════════════════════════════════

## 评估一个相位师的综合战力
## master 数据结构：
##   玩家侧（由 master_player_assembler.build_player_master_dict 装配）：
##     - _player_platform_powers: Array[float] —— 每张装备卡加成后战力（已含 7 层加成）
##     - _player_card_breakdown:  Array[{name,power}] —— 供 UI 卡战力分解显示
##   敌方侧（master JSON / enriched）：
##     - equipment.platforms: Array[String] —— archetype id 列表
##     - equipment.runes / stats / equipment.phase_instrument —— 加成参数
##     - _eval_tier: String（可选）—— 覆盖默认 tier
static func evaluate(master: Dictionary) -> Dictionary:
	var scores: Dictionary = {}
	scores.equipment_slots = _eval_equipment_slots(master)

	# 单分量：总战力 = 卡战力之和
	var total: float = scores.equipment_slots
	var star_info: Dictionary = _score_to_stars(total)

	return {
		"total_score": total,
		"stars": star_info.stars,
		"star_name": star_info.name,
		"star_color": star_info.color,
		"scores": scores,
		"details": _build_details(master, scores, total, star_info),
	}


## 批量评估并返回排行榜（按战力降序），最多返回 top_n 条
static func evaluate_ranking(masters: Array, top_n: int = 50) -> Array:
	var results: Array = []
	for m in masters:
		results.append(evaluate(m))
	results.sort_custom(func(a, b): return a.total_score > b.total_score)
	var ranked: Array = []
	for i in mini(results.size(), top_n):
		var r: Dictionary = results[i].duplicate()
		r["rank"] = i + 1
		r["master_name"] = r.details.get("master_name", "?")
		r["faction"] = r.details.get("faction", "")
		ranked.append(r)
	return ranked


## 仅获取星级
static func get_stars(master: Dictionary) -> int:
	return evaluate(master).stars


## 获取星级显示文本 "4★ 大师"
static func get_stars_display(master: Dictionary) -> String:
	var r = evaluate(master)
	return "%d★ %s" % [r.stars, r.star_name]


# ═════════════════════════════════════════════
#  唯一维度：装备卡战力之和
# ═════════════════════════════════════════════

## 计算所有装备卡的"加成后战力"之和
## - 玩家侧：读 master._player_platform_powers（assembler 预算的 7 层加成后战力）
## - 敌方侧：对 equipment.platforms 每张 archetype id 调 MasterPlatformPower 算加成后战力
static func _eval_equipment_slots(master: Dictionary) -> float:
	# 玩家侧：assembler 已预算好含加成的每张卡战力
	var player_powers: Array = master.get("_player_platform_powers", [])
	if not player_powers.is_empty():
		var psum: float = 0.0
		for p in player_powers:
			psum += float(p)
		return psum

	# 敌方侧：逐张 archetype → 加成后战力
	var equip: Dictionary = master.get("equipment", {})
	var platforms: Array = equip.get("platforms", [])
	if platforms.is_empty():
		return 0.0
	# v7.x A: 对称玩家满配 6 槽 —— platforms <6 时循环补齐到 6
	# （master 数据普遍 2 张平台卡，补齐后战力量级对齐玩家满配）
	var plat_clean: Array = []
	for pid_v in platforms:
		var pid_s := String(pid_v)
		if not pid_s.is_empty():
			plat_clean.append(pid_s)
	if plat_clean.is_empty():
		return 0.0
	var padded: Array = plat_clean.duplicate()
	var i: int = 0
	while padded.size() < 6 and i < 100:
		padded.append(String(plat_clean[i % plat_clean.size()]))
		i += 1
	platforms = padded

	var tier: String = String(master.get("_eval_tier", ENEMY_DEFAULT_TIER))
	# era：优先读显式字段；无则按 master id 编号段推（数据约定：001-006 ww1, 007-012 ww2,
	# 013-018 cold, 019-024 modern, 025-030 future）。近未来倍率（×1.8）靠它生效。
	var era: int = int(master.get("era", master.get("stats", {}).get("era", -1)))
	if era < 0:
		var mid := String(master.get("id", ""))
		var us := mid.rfind("_")
		if us >= 0 and mid.substr(0, us).ends_with("master"):
			era = clampi((int(mid.substr(us + 1)) - 1) / 6, 0, 4)
		else:
			era = 0

	var total: float = 0.0
	for pid_var in platforms:
		var pid: String = String(pid_var)
		if pid.is_empty():
			continue
		total += _PlatformPower.compute_enemy_platform_power(pid, master, era, tier)
	return total


# ═════════════════════════════════════════════
#  辅助
# ═════════════════════════════════════════════

static func _score_to_stars(score: float) -> Dictionary:
	for tier in STAR_TIERS:
		if score >= tier.min_score and score < tier.max_score:
			return tier
	return STAR_TIERS[STAR_TIERS.size() - 1]


static func _build_details(master: Dictionary, scores: Dictionary,
		_total: float, _star_info: Dictionary) -> Dictionary:
	# 相位仪名（展示用，不计分）
	var instr_id: String = String(master.get("phase_instrument", ""))
	if instr_id.is_empty():
		instr_id = String(master.get("equipment", {}).get("phase_instrument", ""))

	var equip: Dictionary = master.get("equipment", {})
	var platforms: Array = equip.get("platforms", [])

	# 卡战力分解（UI 展示用）
	var card_breakdown: Array = master.get("_player_card_breakdown", [])

	return {
		"master_name": master.get("name", "?"),
		"title": master.get("title", ""),
		"faction": master.get("faction", ""),
		"phase_instrument": instr_id,
		"platform_count": platforms.size(),
		"equipment_slots_score": roundf(float(scores.get("equipment_slots", 0.0))),
		"card_breakdown": card_breakdown,
	}


## 打印排行榜（调试用）— disabled in production
static func print_ranking(ranking: Array) -> void:
	push_warning("[MasterPowerEvaluator] print_ranking() is disabled in production")


## 打印单个相位师详细评估 — disabled in production
static func print_detail(master: Dictionary) -> void:
	push_warning("[MasterPowerEvaluator] print_detail() is disabled in production")
