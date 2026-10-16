extends RefCounted
class_name SupplyExchange
## 关卡兑换静态表（v6.71 动态补给网 M3.1）——纯静态表与纯函数，无副作用。
## 执行侧在 managers/supply_network_manager.gd:exchange_box。
##
## 口径（拍板决策 4）：关卡不产出资源，评分=兑换权限——每关记最近一次评分，
## 不打就凭上次评分随时兑换对应档箱子（能量块支付，不限次数）。
## degraded（降级）态只开放 C 档；fallen 一切功能停。
##
## C3：内容池与概率全常量+明示；软保底权重提升、严禁「必出」字样；
## 文案单一源（describe_* 系列是 UI 唯一取文处）。

# ─────────────────────────────────────────────────────────────
#  箱子三阶（评分档门槛 + 能量定价）
# ─────────────────────────────────────────────────────────────

## 档位：普通（C/B 可兑）/ 高级（A 解锁）/ 特级（S 解锁）
const TIER_NORMAL: String = "normal"
const TIER_ADVANCED: String = "advanced"
const TIER_PREMIUM: String = "premium"

## 评分档位排名（与 BattleEvaluation.GRADE_ORDER 同轴）
##   normal: rank≥1（C 及以上） / advanced: rank≥3（A+） / premium: rank=4（S）
const TIER_GRADE_GATE: Dictionary = {
	"normal": 1,
	"advanced": 3,
	"premium": 4,
}

## 能量定价（锚 Manufacture RANDOM_BOX_COST energy_block=60 量级，按箱子档上浮）
const BOX_COSTS: Dictionary = {
	"normal": 60,
	"advanced": 150,
	"premium": 320,
}

## 时代价格系数（时代档微调：一战 1.0 → 未来 1.6）
const ERA_PRICE_FACTOR: Dictionary = {
	1: 1.0, 2: 1.15, 3: 1.3, 4: 1.45, 5: 1.6,
}

## 软保底（全箱子共享一份 pity，全局非逐关）：连续 N 次未出遗物箱 → 遗物箱权重 ×2。
## 语义与文案对齐 ModManufacture.describe_box_pity 模式（软保底、无「必出」）。
const PITY_THRESHOLD: int = 8
const PITY_BOOST: float = 2.0

## 遗物箱条目在池中的 key（pity 只作用于此条）
const RELIC_POOL_KEY: String = "relic_box"

# ─────────────────────────────────────────────────────────────
#  内容池（概率和=100，全常量明示）
# ─────────────────────────────────────────────────────────────

## 条目 key 语义：
##   res_nano/res_alloy/res_crystal 资源包（按时代缩放）
##   discount_coupon 制造折扣券 / captured_card 缴获风格卡 / mod_blueprint 改造图纸
##   relic_box 遗物箱（仅高级以上）
const BOX_POOLS: Dictionary = {
	"normal": [
		{"key": "res_nano",       "label": "纳米材料包", "pct": 30.0},
		{"key": "res_alloy",      "label": "合金包",     "pct": 25.0},
		{"key": "res_crystal",    "label": "晶体包",     "pct": 15.0},
		{"key": "discount_coupon", "label": "制造折扣券", "pct": 12.0},
		{"key": "captured_card",  "label": "缴获风格卡", "pct": 10.0},
		{"key": "mod_blueprint",  "label": "改造图纸",   "pct": 8.0},
	],
	"advanced": [
		{"key": "res_nano",       "label": "纳米材料包", "pct": 25.0},
		{"key": "res_alloy",      "label": "合金包",     "pct": 10.0},
		{"key": "res_crystal",    "label": "晶体包",     "pct": 10.0},
		{"key": "discount_coupon", "label": "制造折扣券", "pct": 15.0},
		{"key": "captured_card",  "label": "缴获风格卡", "pct": 15.0},
		{"key": "mod_blueprint",  "label": "改造图纸",   "pct": 15.0},
		{"key": "relic_box",      "label": "遗物箱",     "pct": 10.0},
	],
	"premium": [
		{"key": "res_nano",       "label": "纳米材料包", "pct": 20.0},
		{"key": "res_crystal",    "label": "晶体包",     "pct": 10.0},
		{"key": "discount_coupon", "label": "制造折扣券", "pct": 20.0},
		{"key": "captured_card",  "label": "缴获风格卡", "pct": 20.0},
		{"key": "mod_blueprint",  "label": "改造图纸",   "pct": 20.0},
		{"key": "relic_box",      "label": "遗物箱",     "pct": 10.0},
	],
}

## 资源包基准量（×时代价格系数；异族战结算量级对齐 basic_resources.get_drops_for_level 轻量侧）
const RESOURCE_PACK_BASE: Dictionary = {
	"res_nano": 400,
	"res_alloy": 40,
	"res_crystal": 60,
}

# ─────────────────────────────────────────────────────────────
#  纯函数
# ─────────────────────────────────────────────────────────────

## 评分档是否解锁箱子档
static func tier_unlocked_by_grade(box_tier: String, grade: String) -> bool:
	var gate: int = int(TIER_GRADE_GATE.get(box_tier, 99))
	return BattleEvaluation.grade_rank(grade) >= gate

## 实付能量价 = 基础价 × 时代系数（遗物折扣在执行侧另算，便于分别展示）
static func box_cost(box_tier: String, era: int) -> int:
	var base: int = int(BOX_COSTS.get(box_tier, 0))
	if base <= 0:
		return 0
	return roundi(base * float(ERA_PRICE_FACTOR.get(era, 1.0)))

## 该时代资源包实发量
static func resource_pack_amount(pack_key: String, era: int) -> int:
	var base: int = int(RESOURCE_PACK_BASE.get(pack_key, 0))
	return roundi(base * float(ERA_PRICE_FACTOR.get(era, 1.0)))

## 概率池（含软保底后的有效权重展示用）：
## 返回 [{key,label,pct_effective}]，relic_box 条目在 pity 激活时权重 ×PITY_BOOST，
## 其余条目 pct 等比压缩以保持总和=100。
static func effective_pool(box_tier: String, pity: int) -> Array:
	var pool: Array = (BOX_POOLS.get(box_tier, []) as Array).duplicate(true)
	if pool.is_empty():
		return []
	var boosted: bool = pity >= PITY_THRESHOLD
	if not boosted:
		return pool
	var total_plain: float = 0.0
	var relic_pct: float = 0.0
	for e in pool:
		total_plain += float(e.get("pct", 0.0))
		if String(e.get("key", "")) == RELIC_POOL_KEY:
			relic_pct = float(e.get("pct", 0.0))
	if relic_pct <= 0.0 or total_plain <= 0.0:
		return pool
	var new_relic: float = relic_pct * PITY_BOOST
	var plain_rest: float = total_plain - relic_pct
	var scale: float = (100.0 - new_relic) / plain_rest if plain_rest > 0.0 else 1.0
	for e in pool:
		if String(e.get("key", "")) == RELIC_POOL_KEY:
			e["pct"] = new_relic
		else:
			e["pct"] = snappedf(float(e.get("pct", 0.0)) * scale, 0.1)
	return pool

## roll 一格（返回条目 key）；池异常返回空串（执行侧退款防御）
static func roll_box(box_tier: String, pity: int) -> String:
	var pool: Array = effective_pool(box_tier, pity)
	if pool.is_empty():
		return ""
	var total: float = 0.0
	for e in pool:
		total += float(e.get("pct", 0.0))
	if total <= 0.0:
		return ""
	var roll: float = randf() * total
	var acc: float = 0.0
	for e in pool:
		acc += float(e.get("pct", 0.0))
		if roll <= acc:
			return String(e.get("key", ""))
	return String(pool[pool.size() - 1].get("key", ""))

## 考评结算 3 选 1 货架（M3.2）：按新评分档定池，能量定价，可放弃。
## 从 PREMIUM_SHELF 抽 3 件不重复；池不足 3 时有几件给几件。
const SHELF_SIZE: int = 3
const PREMIUM_SHELF: Array = [
	{"key": "mod_blueprint", "label": "改造图纸",   "cost": 90},
	{"key": "captured_card", "label": "缴获风格卡", "cost": 80},
	{"key": "discount_coupon", "label": "制造折扣券", "cost": 70},
	{"key": "res_nano",      "label": "纳米大包",   "cost": 60},
	{"key": "res_crystal",   "label": "晶体大包",   "cost": 75},
	{"key": "relic_box",     "label": "遗物箱",     "cost": 180},
]

static func roll_shelf(grade: String, rng: RandomNumberGenerator = null) -> Array:
	# 档位过滤：A 以下不出遗物箱货架位（兑换分区的常驻箱已按档把门）
	var gate: int = BattleEvaluation.grade_rank(grade)
	var pool: Array = []
	for e in PREMIUM_SHELF:
		if String(e.get("key", "")) == RELIC_POOL_KEY and gate < 3:
			continue
		pool.append(e)
	var picks: Array = []
	while picks.size() < mini(SHELF_SIZE, pool.size()):
		var idx: int = 0
		if rng != null:
			idx = rng.randi_range(0, pool.size() - 1)
		else:
			idx = randi_range(0, pool.size() - 1)
		var entry: Dictionary = pool[idx]
		var dup: bool = false
		for p in picks:
			if String(p.get("key", "")) == String(entry.get("key", "")):
				dup = true
				break
		if not dup:
			picks.append(entry.duplicate(true))
	return picks

# ─────────────────────────────────────────────────────────────
#  文案（C3 单一来源；严禁「必出」）
# ─────────────────────────────────────────────────────────────

const TIER_LABELS: Dictionary = {
	"normal": "普通补给箱", "advanced": "高级补给箱", "premium": "特级补给箱",
}

const GRADE_GATE_LABELS: Dictionary = {
	"normal": "C", "advanced": "A", "premium": "S",
}

static func describe_tier(box_tier: String) -> String:
	return String(TIER_LABELS.get(box_tier, box_tier))

static func describe_gate(box_tier: String) -> String:
	return "评级 %s 及以上可兑" % String(GRADE_GATE_LABELS.get(box_tier, ""))

static func describe_box_pity(pity: int) -> String:
	if pity >= PITY_THRESHOLD:
		return "保底已激活：遗物箱概率 ×%.0f（出遗物箱即重置）" % PITY_BOOST
	if pity <= 0:
		return "保底 0/%d：连续 %d 次未出遗物箱后，遗物箱概率 ×%.0f" % [
			PITY_THRESHOLD, PITY_THRESHOLD, PITY_BOOST]
	return "保底 %d/%d（还差 %d 次）：遗物箱概率将 ×%.0f" % [
		pity, PITY_THRESHOLD, PITY_THRESHOLD - pity, PITY_BOOST]
