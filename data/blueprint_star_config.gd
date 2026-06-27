extends RefCounted
## 蓝图星级：副本→星级换算、研究点消耗（v3 固定表）、默认强化池、改装门槛与消耗
## 与 BlueprintManager.MAX_BLUEPRINT_LEVEL 对齐；设定见 docs/BATTLE_CARD_V3.md §3.2、§5.1

const GC = preload("res://resources/game_constants.gd")

const MAX_STAR_LEVEL: int = 9

## 从当前星级 s 升到 s+1 所需研究点；索引 star-1 对应目标 2★…9★（v3.0.1 表）
const _NEXT_STAR_RESEARCH_BY_RARITY: Dictionary = {
	"common": [50, 100, 180, 280, 400, 550, 750, 1000],
	"uncommon": [80, 160, 280, 440, 640, 880, 1200, 1600],
	"rare": [120, 240, 420, 660, 960, 1320, 1800, 2400],
	"epic": [180, 360, 630, 990, 1440, 1980, 2700, 3600],
	"legendary": [250, 500, 875, 1375, 2000, 2750, 3750, 5000],
	"mythic": [400, 800, 1440, 2240, 3200, 4400, 6000, 8000],
}

## 稀有度 → 副本折算（越高品相对同副本数更易换算出高星）
const _RARITY_COPY_BIAS: Dictionary = {
	"common": 1.0,
	"uncommon": 1.05,
	"rare": 1.12,
	"epic": 1.2,
	"legendary": 1.28,
	"mythic": 1.38,
}

## 第 1/2/3 次改装研究点（v3 §5.1，不按稀有度缩放）
const _MOD_RESEARCH_FLAT: Array[int] = [200, 400, 800]

static func _copy_bias(rarity: String) -> float:
	return float(_RARITY_COPY_BIAS.get(String(rarity).to_lower(), 1.0))


## 由累计副本数换算星级（1~MAX_STAR_LEVEL）；0 副本视为 1★（由调用方再 clamp）
static func calculate_star(copies: int, rarity: String) -> int:
	if copies < 1:
		return 1
	var biased: float = float(copies) * _copy_bias(rarity)
	var best: int = 1
	for s in range(1, MAX_STAR_LEVEL + 1):
		var need: float = float(s * (s + 1)) / 2.0
		if biased >= need:
			best = s
	return best


## 从当前星级升到下一星所需研究点；已满星返回 0
static func get_research_cost_for_next_star(star: int, rarity: String) -> int:
	if star >= MAX_STAR_LEVEL:
		return 0
	var s: int = maxi(1, star)
	var idx: int = s - 1
	var r: String = String(rarity).to_lower()
	var row: Variant = _NEXT_STAR_RESEARCH_BY_RARITY.get(r, _NEXT_STAR_RESEARCH_BY_RARITY["common"])
	if row is Array:
		var arr: Array = row as Array
		if idx >= 0 and idx < arr.size():
			return maxi(1, int(arr[idx]))
	return maxi(1, int((_NEXT_STAR_RESEARCH_BY_RARITY["common"] as Array)[idx]))


## 第 mod_index 次改装所需研究点（0-based）；v3 表为固定值
static func get_mod_cost(_rarity: String, mod_index: int) -> int:
	var idx: int = clampi(mod_index, 0, _MOD_RESEARCH_FLAT.size() - 1)
	return _MOD_RESEARCH_FLAT[idx]


# v7.3: get_mod_permit_rule 已删除（许可证系统移除，原定义"改造所需许可数量"但从未被调用）


static func get_max_mod_times(_rarity: String) -> int:
	return 3


static func get_mod_unlock_star(mod_index: int) -> int:
	# 改造不再受星级门槛限制（返回0表示无星级要求）
	return 0


static func get_pool_for_card_type(card_type: int) -> Array:
	match card_type:
		GC.CardType.COMBAT_UNIT:
			return _POOL_PLATFORM.duplicate()
		GC.CardType.ENERGY:
			return _POOL_ENERGY.duplicate()
		GC.CardType.LAW:
			return _POOL_LAW.duplicate()
		_:
			return _POOL_GENERIC.duplicate()


static func roll_affix(pool: Array, is_mythic: bool) -> Dictionary:
	if pool.is_empty():
		return {}
	var pick: Variant = pool.pick_random()
	if pick is Dictionary:
		var d: Dictionary = (pick as Dictionary).duplicate(true)
		if is_mythic:
			d["value_base"] = float(d.get("value_base", 0.0)) * 1.08
			d["value_per_star"] = float(d.get("value_per_star", 0.0)) * 1.08
		return d
	return {}


## 按稳定下标取池内词条（用于星级展示/说明，避免 pick_random 偶发空或每次悬停抖动）
static func roll_affix_at(pool: Array, is_mythic: bool, index: int) -> Dictionary:
	if pool.is_empty():
		return {}
	var idx: int = absi(index) % pool.size()
	var pick: Variant = pool[idx]
	if pick is Dictionary:
		var d: Dictionary = (pick as Dictionary).duplicate(true)
		if is_mythic:
			d["value_base"] = float(d.get("value_base", 0.0)) * 1.08
			d["value_per_star"] = float(d.get("value_per_star", 0.0)) * 1.08
		return d
	return {}


const _POOL_PLATFORM: Array = [
	{"id": "plat_hp", "name": "结构强化", "value_base": 4.0, "value_per_star": 2.0},
	{"id": "plat_armor", "name": "装甲镀层", "value_base": 3.0, "value_per_star": 1.5},
	{"id": "plat_dodge", "name": "机动校准", "value_base": 2.0, "value_per_star": 1.0},
]

const _POOL_WEAPON: Array = [
	{"id": "wpn_dmg", "name": "火力增幅", "value_base": 4.0, "value_per_star": 2.0},
	{"id": "wpn_rof", "name": "射控优化", "value_base": 2.5, "value_per_star": 1.2},
	{"id": "wpn_crit", "name": "弱点解析", "value_base": 1.5, "value_per_star": 1.0},
]

const _POOL_ENERGY: Array = [
	{"id": "en_cap", "name": "电容扩展", "value_base": 3.0, "value_per_star": 1.5},
	{"id": "en_regen", "name": "回流线圈", "value_base": 2.0, "value_per_star": 1.0},
]

const _POOL_LAW: Array = [
	{"id": "law_pot", "name": "法则共鸣", "value_base": 3.0, "value_per_star": 1.5},
	{"id": "law_eff", "name": "相位聚焦", "value_base": 2.5, "value_per_star": 1.2},
]

const _POOL_GENERIC: Array = [
	{"id": "gen_all", "name": "系统调谐", "value_base": 2.0, "value_per_star": 1.0},
]