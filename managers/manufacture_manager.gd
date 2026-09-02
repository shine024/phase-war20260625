extends Node
## 制造管理器（v26 批次2）：进化退役后的新卡获取唯一通道。
## 设计文档：docs/design_manufacture_system.md
##
## 挂载：ManagerLazyLoader（"manufacture"，非 autoload），SaveManager 段 SK_MANUFACTURE。
##
## 职责：
##   配方目录：DefaultCards 卡池 ∩ EnemyCardModMap.has_entry（剔除 captured_ 缴获卡）
##   资格判定：情报档（base ≥25%）+ 时代授权（技能树，era0 一战豁免防 FTUE 死锁）+ 资源
##   执行制造：扣费（×工坊等级折扣）→ 掷品质（含暗保底）→ 建实例 → 入包广播
##
## 依赖：IntelManual（autoload）/ PhaseMasterSkillManager（autoload）/
##       BasicResourceManager（autoload）/ InstanceRegistry（autoload）/
##       BunkerManager.get_manufacture_discount（懒加载，缺省=无折扣）

const ManufacturePools = preload("res://data/manufacture_pools.gd")
const DefaultCards = preload("res://data/default_cards.gd")

## 存档键（SaveManager 段 "manufacture_state"）
const SAVE_KEY_PITY := "pity"

var _recipe_cache: Array = []
var _recipe_built := false
var _arch_index: Dictionary = {}   # player_card_id -> Array[String]（对应敌形原型 id 列表）
var _pity: Dictionary = {}   # card_id -> int（连续未出 rare+ 的制造次数）

## ───────────────────────── 配方目录 ─────────────────────────

## 全量可制造卡种（缓存构建一次）。
## 数据域说明（v26 修正）：EnemyCardModMap 的键是敌形原型 id（ww1_inf_mp18），
## 值里的 player_card_id（ww1_mp18）才是配方目标；情报也记在原型域。
func get_recipe_ids() -> Array:
	_ensure_recipes()
	return _recipe_cache.duplicate()

func _ensure_recipes() -> void:
	if _recipe_built:
		return
	_recipe_built = true
	_recipe_cache.clear()
	_arch_index.clear()
	var valid_ids := {}
	for id in DefaultCards.get_all_blueprint_ids():
		valid_ids[str(id)] = true
	for arch in EnemyCardModMap.get_all_archetype_ids():
		var cfg: Dictionary = EnemyCardModMap.get_config(String(arch))
		var pid := String(cfg.get("player_card_id", ""))
		if pid.is_empty() or not valid_ids.has(pid):
			continue   # 无玩家卡目标 / 玩家卡模板缺失
		if not _arch_index.has(pid):
			_arch_index[pid] = []
			_recipe_cache.append(pid)
		_arch_index[pid].append(String(arch))

func is_manufacturable(card_id: String) -> bool:
	_ensure_recipes()
	return _arch_index.has(card_id)

## 玩家卡 → 对应敌形原型列表（一个玩家卡可能对应多个敌形，如变形/Boss 档）
func get_archetypes_of(card_id: String) -> Array:
	_ensure_recipes()
	return (_arch_index.get(card_id, []) as Array).duplicate()

## ───────────────────────── 查询 ─────────────────────────

## 情报 base（0-1）：取该卡全部敌形原型 base 的最大值（IntelManual 未加载时 0）。
## 情报记在原型域（ww1_inf_mp18），配方域是玩家卡（ww1_mp18）。
## 注意：本管理器经 ManagerLazyLoader 挂载，可能尚未进树——autoload 一律用
## 全局标识符直引（get_node 绝对路径在树外会炸，2026-09 冒烟实测）。
func get_intel_base(card_id: String) -> float:
	var best := 0.0
	for arch in get_archetypes_of(card_id):
		best = maxf(best, clampf(float(IntelManual.get_base_progress(String(arch))), 0.0, 1.0))
	return best

## 品质档位（0=未解锁配方 … 4=满池）
func get_pool_tier(card_id: String) -> int:
	return ManufacturePools.get_pool_tier(get_intel_base(card_id))

## 档案室 Lv3 高品权重（epic+ ×1.5；BunkerManager 缺省=无加成）
func get_pool_high_boost() -> float:
	var bunker: Node = get_node_or_null("/root/BunkerManager")
	if bunker != null and bunker.has_method("get_pool_high_boost"):
		return float(bunker.get_pool_high_boost())
	return 1.0

## 有效概率池（含暗保底 + 档案室 Lv3 高品权重；UI 预览与 roll 同源）
func get_effective_pool(card_id: String) -> Array:
	return ManufacturePools.get_effective_pool(get_intel_base(card_id), get_pity(card_id), get_pool_high_boost())

## 基础消耗（按卡时代；未乘折扣）
func get_base_cost(card_id: String) -> Dictionary:
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	var era := 0
	if card != null:
		era = int(card.era)
	return ManufacturePools.get_cost_for_era(era)

## 实际消耗（×工坊等级折扣，逐项向上取整、至少 1）
func get_cost(card_id: String) -> Dictionary:
	var base := get_base_cost(card_id)
	var mult := 1.0
	var bunker: Node = get_node_or_null("/root/BunkerManager")
	if bunker != null and bunker.has_method("get_manufacture_discount"):
		mult = float(bunker.get_manufacture_discount())
	if absf(mult - 1.0) < 0.001:
		return base
	var out := {}
	for rid in base:
		out[rid] = maxi(1, int(ceil(float(base[rid]) * mult)))
	return out

func get_pity(card_id: String) -> int:
	return int(_pity.get(card_id, 0))

## ───────────────────────── 资格判定 ─────────────────────────

## 制造资格。返回 {"ok", "reason_zh", "conditions":[{key,met,current_text,required_text,detail}]}
## 条件快照结构与原进化条件同形，面板可复用逐条件渲染器。
func can_manufacture(card_id: String) -> Dictionary:
	var conditions: Array = []
	if not is_manufacturable(card_id):
		return {"ok": false,
			"reason_zh": "该卡种无法制造（无敌形原型，仅可经掉落/势力渠道获取）",
			"conditions": conditions}
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return {"ok": false, "reason_zh": "卡牌数据缺失：%s" % card_id, "conditions": conditions}

	# 1. 情报档（≥25% 解锁配方）
	var base := get_intel_base(card_id)
	var tier := ManufacturePools.get_pool_tier(base)
	var intel_ok := tier >= 1
	conditions.append({
		"key": "intel", "met": intel_ok,
		"current_text": "%d%%" % int(round(base * 100.0)), "required_text": "25%",
		"detail": "击败该敌形、分析仪烧缴获卡、获取缴获卡都会累积情报",
	})

	# 2. 时代授权（技能树指挥系节点，era0 一战豁免——开局唯一自造渠道，不得锁死）
	var era := int(card.era)
	var era_ok := true
	if era > 0:
		era_ok = bool(PhaseMasterSkillManager.is_evolution_era_unlocked(era))
	conditions.append({
		"key": "skill_tree_era", "met": era_ok,
		"current_text": "已解锁" if era_ok else "未解锁", "required_text": "已解锁",
		"detail": "在相位师技能树（指挥系）解锁对应时代的制造授权",
	})

	# 3. 资源
	var cost := get_cost(card_id)
	var res_ok := _can_afford(cost)
	conditions.append({
		"key": "resources", "met": res_ok,
		"current_text": "充足" if res_ok else "不足",
		"required_text": ManufacturePools.cost_text(cost),
		"detail": "制造消耗资源；工坊 Lv2/Lv3 可享 10%/20% 折扣",
	})

	var ok := intel_ok and era_ok and res_ok
	return {"ok": ok, "reason_zh": "" if ok else _first_unmet_reason(conditions),
		"conditions": conditions}

func _can_afford(cost: Dictionary) -> bool:
	if cost.is_empty():
		return true
	for rid in cost:
		if not BasicResourceManager.can_afford(String(rid), int(cost[rid])):
			return false
	return true

func _first_unmet_reason(conditions: Array) -> String:
	for c in conditions:
		if c is Dictionary and not bool(c.get("met", true)):
			match String(c.get("key", "")):
				"intel": return "情报不足（需 25% 以上）"
				"skill_tree_era": return "该时代的制造授权未在技能树解锁"
				"resources": return "资源不足（需 %s）" % str(c.get("required_text", ""))
	return "条件未满足"

## ───────────────────────── 执行制造 ─────────────────────────

## 制造一张卡。返回 {"ok", "reason_zh", "instance_id", "rarity", "card_id"}。
func manufacture(card_id: String) -> Dictionary:
	var check := can_manufacture(card_id)
	if not check.get("ok", false):
		return {"ok": false, "reason_zh": String(check.get("reason_zh", "无法制造"))}

	var cost := get_cost(card_id)
	for rid in cost:
		BasicResourceManager.consume(String(rid), int(cost[rid]))

	# 失败退款防御：掷品质/建实例任何一步失败，资源原路退回
	var rarity := ManufacturePools.roll_rarity(get_intel_base(card_id), get_pity(card_id), get_pool_high_boost())
	if rarity.is_empty():
		_refund(cost)
		return {"ok": false, "reason_zh": "品质池异常（进度未达门槛）"}

	var inst: CardResource = InstanceRegistry.create_instance(card_id)
	if inst == null:
		_refund(cost)
		return {"ok": false, "reason_zh": "卡牌模板缺失：%s" % card_id}
	inst.rarity = rarity

	# 暗保底记账：出 rare+ 清零，否则 +1
	if ManufacturePools.is_high_rarity(rarity):
		_pity[card_id] = 0
	else:
		_pity[card_id] = get_pity(card_id) + 1

	# 入包广播（收集计数/背包实时刷新）+ 制造信号
	SignalBus.card_added_to_backpack.emit(inst)
	SignalBus.card_manufactured.emit(card_id, rarity)
	# v26.6 批4b: 死信号审计 B 类补反馈链——制造成功 toast（原信号无人监听）
	const IntelItems := preload("res://data/intel_manual_items.gd")
	SignalBus.show_toast.emit("✦ 制造成功：%s（%s）" % [inst.display_name, IntelItems.get_rarity_name(rarity)])

	return {"ok": true, "reason_zh": "制造成功", "instance_id": String(inst.instance_id),
		"rarity": rarity, "card_id": card_id}

func _refund(cost: Dictionary) -> void:
	for rid in cost:
		BasicResourceManager.add_resource(String(rid), int(cost[rid]))

## ───────────────────────── 存档 ─────────────────────────

func save_state() -> Dictionary:
	return {SAVE_KEY_PITY: _pity.duplicate()}

func load_state(data: Dictionary) -> void:
	if data.is_empty():
		_pity = {}
		return
	var pity: Variant = data.get(SAVE_KEY_PITY, {})
	_pity = {}
	if pity is Dictionary:
		for k in pity:
			_pity[str(k)] = maxi(0, int(pity[k]))
