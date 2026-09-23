extends RefCounted
class_name ModManufacture
## 改造图纸制造静态表（v26.x 改造消耗品化·制造通道）
## 设计文档：docs/design_manufacture_system.md §改造图纸
##
## 门槛规则（单一心智模型）：得到过就可造——IntelItemBag「见过集合」判定，
## 掉落负责发现（第一次），制造负责补给（第 N 次）。随机箱池子用同一规则。
## 混合形态：common/uncommon/rare 定向兑换；epic/legendary/mythic 只能随机箱 roll。
## 本文件只放静态表与纯函数；有副作用的执行在 managers/manufacture_manager.gd。

## 稀有度档位（与 CardResource.rarity / ManufacturePools.RARITY_ORDER 同轴）
const RARITY_RANK := {
	"common": 0, "uncommon": 1, "rare": 2,
	"epic": 3, "legendary": 4, "mythic": 5,
}

## 定向区稀有度（明码标价）
const DIRECT_RARITIES := ["common", "uncommon", "rare"]
## 随机箱稀有度（只能 roll，保高级改造获取仪式感）
const RANDOM_RARITIES := ["epic", "legendary", "mythic"]

## 定向兑换价目（锚：日均纳米收入 200-400、卡牌制造 era0=纳米100——图纸是"小件"采购，
## 低于同稀有度卡牌制造；工坊等级折扣在 ManufactureManager 侧应用）
const DIRECT_COSTS := {
	"common":   {"nano_materials": 80,  "energy_block": 10},
	"uncommon": {"nano_materials": 150, "energy_block": 20},
	"rare":     {"nano_materials": 280, "energy_block": 40, "alloy": 20},
}

## 随机箱价目（≈ rare 定向 ×1.5，三资源门槛）
const RANDOM_BOX_COST := {"nano_materials": 420, "energy_block": 60, "alloy": 30}

## 随机箱品质权重（池内按 mod 所在稀有度加权——先建池再按 mod 权重 roll，
## 天然规避"roll 出池内不存在的稀有度"的空档回退）
const RANDOM_BOX_WEIGHTS := {
	"epic": 78.0, "legendary": 19.0, "mythic": 3.0,
}

## 随机箱暗保底：连续 N 次未出 legendary+ → 该档权重 ×2
## （对齐卡牌制造 PITY_THRESHOLD=3 / PITY_BOOST=2.0 模式，不显示给玩家）
const PITY_THRESHOLD := 3
const PITY_BOOST := 2.0
const PITY_FLOOR_RANK := 4  # legendary 的 RARITY_RANK

## 随机箱保底口径文案（v6.19 P1-T1.1 概率可见化：UI 唯一文案源，数值全读常量——
## 宪法 C3）。软保底概率提升、无"必出"，文案严禁写"必出"。
static func describe_box_pity(pity: int) -> String:
	if pity >= PITY_THRESHOLD:
		return "保底已激活：传说+ 概率 ×%.0f（开箱即重置）" % PITY_BOOST
	if pity <= 0:
		return "保底 0/%d：连续 %d 次未出传说+ 后，传说+ 概率 ×%.0f" % [
			PITY_THRESHOLD, PITY_THRESHOLD, PITY_BOOST]
	return "保底 %d/%d（还差 %d 次）：传说+ 概率将 ×%.0f" % [
		pity, PITY_THRESHOLD, PITY_THRESHOLD - pity, PITY_BOOST]

## 稀有度是否属定向区
static func is_direct_rarity(rarity: String) -> bool:
	return DIRECT_RARITIES.has(rarity)

## 稀有度是否属随机箱区
static func is_random_rarity(rarity: String) -> bool:
	return RANDOM_RARITIES.has(rarity)

## 稀有度档位（未知稀有度按最低档处理）
static func rank_of(rarity: String) -> int:
	return int(RARITY_RANK.get(rarity, 0))

## 定向价目（未知/越区稀有度返回空字典，调用方应已按区过滤）
static func get_direct_cost(rarity: String) -> Dictionary:
	if not is_direct_rarity(rarity):
		return {}
	return (DIRECT_COSTS[rarity] as Dictionary).duplicate()

## 随机箱：从池中按 mod 稀有度加权 roll 一张。
## pool: [{mod_id: String, rarity: String}, ...]（调用方保证非空且全为随机区稀有度）
## 返回 mod_id；池异常时返回池首项兜底。
static func roll_box_mod(pool: Array, pity: int) -> String:
	if pool.is_empty():
		return ""
	var boosted := pity >= PITY_THRESHOLD
	var entries: Array = []
	var total := 0.0
	for e in pool:
		var r := String(e.get("rarity", "epic"))
		var w := float(RANDOM_BOX_WEIGHTS.get(r, 1.0))
		if boosted and rank_of(r) >= PITY_FLOOR_RANK:
			w *= PITY_BOOST
		entries.append({mod_id = String(e.get("mod_id", "")), w = w})
		total += w
	if total <= 0.0:
		return String(pool[0].get("mod_id", ""))
	var roll := randf() * total
	for e in entries:
		roll -= float(e.w)
		if roll <= 0.0:
			return String(e.mod_id)
	return String(entries[entries.size() - 1].mod_id)

## 本次 roll 结果是否清零 pity（出 legendary+ 清零，否则 +1 由调用方记账）
static func is_pity_reset_rarity(rarity: String) -> bool:
	return rank_of(rarity) >= PITY_FLOOR_RANK
