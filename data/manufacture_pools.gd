extends RefCounted
class_name ManufacturePools
## 制造系统静态数据（v26 批次2）
## 设计文档：docs/design_manufacture_system.md
##
## 配方判定 = DefaultCards 卡池 ∩ EnemyCardModMap.has_entry（存在敌形原型的卡种才可制造）
## 品质轴   = CardResource.rarity（common/uncommon/rare/epic/legendary/mythic）
## 情报轴   = IntelManual.get_base_progress（历史峰值，只增不减）
## 本文件只放静态表与纯函数；有副作用的执行在 managers/manufacture_manager.gd。

## ── 情报档位门槛（base_progress）──
const GATE_RECIPE := 0.25   # 解锁配方（白板起步，普通 100%）
const TIER_STEP2 := 0.50    # 品质池扩：优秀/稀有入池
const TIER_STEP3 := 0.75    # 品质池扩：史诗/传说入池
const TIER_FULL := 1.00     # 满池：神话入池

## ── 品质概率池（下标 = 档位 1-4；w 任意正数，roll 时归一化）──
## 对齐设计文档示意表：25%=普通100 / 50%=70·25·5 / 75%=45·30·15·8·2 / 100%=20·28·26·15·8·3
const POOLS := {
	1: [
		{"r": "common", "w": 100.0},
	],
	2: [
		{"r": "common", "w": 70.0}, {"r": "uncommon", "w": 25.0}, {"r": "rare", "w": 5.0},
	],
	3: [
		{"r": "common", "w": 45.0}, {"r": "uncommon", "w": 30.0}, {"r": "rare", "w": 15.0},
		{"r": "epic", "w": 8.0}, {"r": "legendary", "w": 2.0},
	],
	4: [
		{"r": "common", "w": 20.0}, {"r": "uncommon", "w": 28.0}, {"r": "rare", "w": 26.0},
		{"r": "epic", "w": 15.0}, {"r": "legendary", "w": 8.0}, {"r": "mythic", "w": 3.0},
	],
}

## ── 稀有+ 暗保底：连续 N 抽未出 rare 以上 → rare 以上权重 ×2（不显示给玩家）──
const PITY_THRESHOLD := 3
const PITY_BOOST := 2.0
const PITY_FLOOR := "rare"

## ── 缴获卡品质滚动（v26 批次3）：获取时 roll，与玩家卡同一稀有度轴 ──
## 无神话（神话为制造满池专属）；权重示意，balance-check 可调。
const CAPTURED_ROLL_WEIGHTS := {
	"common": 55.0, "uncommon": 25.0, "rare": 12.0, "epic": 6.0, "legendary": 2.0,
}

## ── 分析仪产出（v26 批次3）：按缴获卡品质给情报增量（base 轴 0-1）──
## 设计文档 §2.4：普通+8% / 精良+12% / 稀有+16% / 史诗+22% / 传说+30%
const ANALYZER_YIELD := {
	"common": 0.08, "uncommon": 0.12, "rare": 0.16,
	"epic": 0.22, "legendary": 0.30, "mythic": 0.30,
}

## 稀有度顺序（rank 越大越稀有）
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]

## ── 制造资源消耗（下标 = GameConstants.Era：0=一战 … 4=近未来）──
## 锚点：日均纳米收入 200-400；工坊等级折扣在 ManufactureManager.get_cost 应用。
const COSTS := [
	{"nano_materials": 100, "energy_block": 20},
	{"nano_materials": 180, "energy_block": 35},
	{"nano_materials": 260, "energy_block": 50, "alloy": 30},
	{"nano_materials": 350, "energy_block": 70, "alloy": 60},
	{"nano_materials": 450, "energy_block": 90, "alloy": 90, "crystal": 40},
]

## 资源完整 id → 显示名（与 data/basic_resources.gd 对齐）
const RESOURCE_NAMES := {
	"nano_materials": "纳米",
	"alloy": "合金",
	"crystal": "晶体",
	"energy_block": "能量块",
}

## 情报进度 → 档位（0=配方未解锁）
static func get_pool_tier(progress: float) -> int:
	if progress >= TIER_FULL: return 4
	if progress >= TIER_STEP3: return 3
	if progress >= TIER_STEP2: return 2
	if progress >= GATE_RECIPE: return 1
	return 0

## 档位 → 基础概率池（含未解锁 0 档返回空）
static func get_pool(tier: int) -> Array:
	return POOLS.get(tier, [])

static func _rarity_rank(r: String) -> int:
	return RARITY_ORDER.find(r)

static func is_high_rarity(r: String) -> bool:
	return _rarity_rank(r) >= _rarity_rank(PITY_FLOOR)

## 有效概率池（含暗保底放大 + 档案室 Lv3 高品权重，纯函数供 UI 预览与 roll 共用同一权重源）。
## high_boost：epic+ 权重乘数（暗保底只作用 rare+，与档案室 Lv3 的"高品质 ×1.5"分层）。
static func get_effective_pool(progress: float, pity: int, high_boost: float = 1.0) -> Array:
	var pool := get_pool(get_pool_tier(progress))
	if pool.is_empty():
		return []
	var boosted := pity >= PITY_THRESHOLD
	var out: Array = []
	for entry in pool:
		var e: Dictionary = entry.duplicate()
		var r := String(e["r"])
		if boosted and is_high_rarity(r):
			e["w"] = float(e["w"]) * PITY_BOOST
		if high_boost > 1.0 and _rarity_rank(r) >= _rarity_rank("epic"):
			e["w"] = float(e["w"]) * high_boost
		out.append(e)
	return out

## 掷品质。返回 "" 表示进度未达门槛（调用方不应执行制造）。
static func roll_rarity(progress: float, pity: int, high_boost: float = 1.0) -> String:
	var pool := get_effective_pool(progress, pity, high_boost)
	if pool.is_empty():
		return ""
	var total := 0.0
	for e in pool:
		total += float(e["w"])
	var roll := randf() * total
	for e in pool:
		roll -= float(e["w"])
		if roll <= 0.0:
			return String(e["r"])
	return String(pool[pool.size() - 1]["r"])

## 时代 → 消耗表（越界收敛到近未来；era<0 视为一战）
static func get_cost_for_era(era: int) -> Dictionary:
	var idx := clampi(era, 0, COSTS.size() - 1)
	return COSTS[idx]

## 消耗 → "纳米×100 · 能量块×20" 文本（面板/条件行共用）
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for rid in cost:
		parts.append("%s×%d" % [RESOURCE_NAMES.get(String(rid), String(rid)), int(cost[rid])])
	return " · ".join(parts)

## ───────────────────── 缴获卡品质（v26 批次3） ─────────────────────

## 掷缴获卡稀有度（获取时调用；权重见 CAPTURED_ROLL_WEIGHTS）
static func roll_captured_rarity() -> String:
	var total := 0.0
	for r in CAPTURED_ROLL_WEIGHTS:
		total += float(CAPTURED_ROLL_WEIGHTS[r])
	var roll := randf() * total
	for r in CAPTURED_ROLL_WEIGHTS:
		roll -= float(CAPTURED_ROLL_WEIGHTS[r])
		if roll <= 0.0:
			return String(r)
	return "common"

## 缴获卡实例品质就地滚动（非 captured_ 前缀卡不动）。
## 调用点=获取通道：掉落/商店/势力商店（InstanceRegistry.create_instance 之后）。
static func apply_captured_quality(inst: CardResource) -> void:
	if inst == null:
		return
	if not String(inst.card_id).begins_with("captured_"):
		return
	inst.rarity = roll_captured_rarity()

## 分析仪产出：按缴获卡稀有度给情报增量（0-1 轴）
static func analyzer_yield(rarity: String) -> float:
	return float(ANALYZER_YIELD.get(String(rarity), 0.08))
