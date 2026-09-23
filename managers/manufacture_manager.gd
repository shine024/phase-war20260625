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
const ModManufacture = preload("res://data/mod_manufacture.gd")
const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
const GC = preload("res://resources/game_constants.gd")   # v30.5 R5: CardType 过滤

## 存档键（SaveManager 段 "manufacture_state"）
const SAVE_KEY_PITY := "pity"
const SAVE_KEY_MOD_PITY := "mod_box_pity"  # v26.x 改造图纸随机箱：连续未出 legendary+ 次数

var _recipe_cache: Array = []
var _recipe_built := false
var _arch_index: Dictionary = {}   # player_card_id -> Array[String]（对应敌形原型 id 列表）
var _pity: Dictionary = {}   # card_id -> int（连续未出 rare+ 的制造次数）
var _mod_box_pity: int = 0  # v26.x 改造随机箱单计数器（箱全局一个，非按 mod 分池）

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
	# v30.5 R5（设计审查 F-11）：era0/1 直接入池——前期（新手留存敏感期）卡池更新率
	# 最低，放宽"须有敌形原型"口径：WW1/WW2 玩家战斗卡无原型也进配方目录。
	# 无原型卡情报轴恒 0 → 恒 tier1 白板池（与"配方解锁=白板起步"语义一致；
	# era2+ 维持原型口径，情报驱动解锁的中后期节奏不变）。
	for pid_v in valid_ids:
		var pid2 := String(pid_v)
		if _arch_index.has(pid2) or pid2.begins_with("captured_"):
			continue
		var card = DefaultCards.get_card_by_id(pid2)
		if card == null or not (card is CardResource):
			continue
		var cres := card as CardResource
		if cres.era <= 1 and cres.card_type == GC.CardType.COMBAT_UNIT:
			_arch_index[pid2] = []
			_recipe_cache.append(pid2)

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
## v30.5 R5：era0/1 直入卡无原型 → 情报恒 0，特判为白板档 1（否则恒 0=“未解锁”
## 被配方门挡死，扩容失效）。白板档=普通 100%，与“配方解锁=白板起步”语义一致。
func get_pool_tier(card_id: String) -> int:
	var tier := ManufacturePools.get_pool_tier(get_intel_base(card_id))
	if tier == 0 and _arch_index.has(card_id) and (_arch_index[card_id] as Array).is_empty():
		return 1
	return tier

## v30.5 R5：era0/1 直入卡判定（在目录且无敌形原型）
func is_direct_pool_card(card_id: String) -> bool:
	return _arch_index.has(card_id) and (_arch_index[card_id] as Array).is_empty()

## 档案室 Lv3 高品权重（epic+ ×1.5；BunkerManager 缺省=无加成）
func get_pool_high_boost() -> float:
	var bunker: Node = get_node_or_null("/root/BunkerManager")
	if bunker != null and bunker.has_method("get_pool_high_boost"):
		return float(bunker.get_pool_high_boost())
	return 1.0

## v30.5 R5：直入卡（era0/1 无原型）按白板档口径取池——intel 0 视作刚过配方门
## （GATE_RECIPE 0.25 → tier1），否则 roll 空 pool。
func _pool_base(card_id: String) -> float:
	var base := get_intel_base(card_id)
	if base < ManufacturePools.GATE_RECIPE and is_direct_pool_card(card_id):
		return ManufacturePools.GATE_RECIPE
	return base

## 有效概率池（含暗保底 + 档案室 Lv3 高品权重；UI 预览与 roll 同源）
func get_effective_pool(card_id: String) -> Array:
	return ManufacturePools.get_effective_pool(_pool_base(card_id), get_pity(card_id), get_pool_high_boost())

## 基础消耗（按卡时代；未乘折扣）
func get_base_cost(card_id: String) -> Dictionary:
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	var era := 0
	if card != null:
		era = int(card.era)
	return ManufacturePools.get_cost_for_era(era)

## 实际消耗（×工坊等级折扣，逐项向上取整、至少 1）
func get_cost(card_id: String) -> Dictionary:
	return _apply_workshop_discount(get_base_cost(card_id))

## 工坊等级折扣（逐项向上取整、至少 1；BunkerManager 缺省=无折扣）。
## v26.x 起卡牌制造与改造图纸制造共用。
func _apply_workshop_discount(base: Dictionary) -> Dictionary:
	if base.is_empty():
		return base
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
			"reason_zh": "该卡种无法制造（不在配方目录）",
			"conditions": conditions}
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return {"ok": false, "reason_zh": "卡牌数据缺失：%s" % card_id, "conditions": conditions}

	# 1. 情报档（≥25% 解锁配方；v30.5 R5：era0/1 直入卡免情报门，tier 特判白板档）
	var base := get_intel_base(card_id)
	var direct := is_direct_pool_card(card_id)
	var tier := get_pool_tier(card_id)
	var intel_ok := tier >= 1
	conditions.append({
		"key": "intel", "met": intel_ok,
		"current_text": ("直接入目录" if direct else "%d%%" % int(round(base * 100.0))),
		"required_text": "—" if direct else "25%",
		"detail": "一战/二战卡种直接入目录（白板起步）" if direct
			else "击败该敌形、分析仪烧缴获卡、获取缴获卡都会累积情报",
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
				"seen": return "尚未获得过该图纸（先经战斗掉落解锁制造资格）"
				"zone": return "史诗及以上改造只能通过随机箱补给"
				"pool": return "图鉴中尚无史诗+改造图纸（先经战斗掉落获得）"
	return "条件未满足"

## ───────────────────────── 执行制造 ─────────────────────────

## v6.14.5（用户拍板）：品质 → 出厂附送改造条数（白板 0 起步，神话 5）。
## 数值轮可调常量——改这里即可整体调出厂强度。
const STARTUP_MOD_COUNT := {
	"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4, "mythic": 5,
}

## 纯选取：按品质档从该卡可用改造（兵种+时代带口径 get_installable_mods_for_card）
## 随机选 N 条；改造稀有度上限 = 本卡品质档；conflict_group 去重。返回 mod_id 数组。
static func pick_startup_mods(card_id: String, card_era: int, rarity: String) -> Array:
	var n := int(STARTUP_MOD_COUNT.get(rarity, 0))
	if n <= 0:
		return []
	var quality_rank: int = ModManufacture.rank_of(rarity)
	var pool: Array = []
	for mid in ModificationRegistry.get_installable_mods_for_card(card_id, card_era):
		var mid_s := String(mid)
		var md: Dictionary = ModificationRegistry.get_data(mid_s)
		if md.is_empty():
			continue
		if ModManufacture.rank_of(String(md.get("rarity", "common"))) > quality_rank:
			continue
		pool.append(mid_s)
	var granted: Array = []
	var used_groups: Dictionary = {}
	for _i in range(n):
		var candidates: Array = []
		for mid_s in pool:
			if granted.has(mid_s):
				continue
			var g := String(ModificationRegistry.get_data(mid_s).get("conflict_group", ""))
			if not g.is_empty() and used_groups.has(g):
				continue
			candidates.append(mid_s)
		if candidates.is_empty():
			break
		var pick: String = candidates[randi() % candidates.size()]
		var pg := String(ModificationRegistry.get_data(pick).get("conflict_group", ""))
		if not pg.is_empty():
			used_groups[pg] = true
		granted.append(pick)
	return granted

## 制造一张卡。返回 {"ok", "reason_zh", "instance_id", "rarity", "card_id", "startup_mods"}。
func manufacture(card_id: String) -> Dictionary:
	var check := can_manufacture(card_id)
	if not check.get("ok", false):
		return {"ok": false, "reason_zh": String(check.get("reason_zh", "无法制造"))}

	var cost := get_cost(card_id)
	for rid in cost:
		BasicResourceManager.consume(String(rid), int(cost[rid]))

	# 失败退款防御：掷品质/建实例任何一步失败，资源原路退回
	# v6.14.7：roll 口径对齐 UI（_pool_base）——era0/1 直入卡 get_intel_base 恒 0，
	# 直查 roll 恒空池必失败"品质池异常"；_pool_base 的直入特判（白板档）才是
	# can_manufacture/get_effective_pool 同源口径，UI 预览与实际 roll 不得分叉。
	var rarity := ManufacturePools.roll_rarity(_pool_base(card_id), get_pity(card_id), get_pool_high_boost())
	if rarity.is_empty():
		_refund(cost)
		return {"ok": false, "reason_zh": "品质池异常（进度未达门槛）"}

	var inst: CardResource = InstanceRegistry.create_instance(card_id)
	if inst == null:
		_refund(cost)
		return {"ok": false, "reason_zh": "卡牌模板缺失：%s" % card_id}
	inst.rarity = rarity

	# v6.14.5（用户拍板）：出厂随机改造——按品质档附送 N 条（白板 0 → 神话 5）。
	# 选取口径与安装同源（兵种+时代带），改造稀有度 ≤ 本卡品质档，冲突组去重；
	# 赠品免费（paid_cost=0，不耗图纸/纳米），等级档位门对出厂赠品豁免
	#（品质 roll 本身就是稀有度回报，稀有品质的卡理应带得起稀有件）。
	var startup_mods: Array = pick_startup_mods(card_id, int(inst.era), rarity)
	for mid_s in startup_mods:
		inst.mods.append({
			id = mid_s,
			installed_at = Time.get_unix_time_from_system(),
			enabled = true,
			paid_cost = 0,
			gift = true,   # v6.14.6 卸下判定：赠品无纳米返还、其图纸从未存在亦不返还
		})

	# 暗保底记账：出 rare+ 清零，否则 +1
	if ManufacturePools.is_high_rarity(rarity):
		_pity[card_id] = 0
	else:
		_pity[card_id] = get_pity(card_id) + 1
	# v6.19.1 核验清单#3 补遗：首次制造出神话卡（mythic 卡为制造满池专属，此前只有 mythic 改造有埋点）
	if rarity == "mythic":
		var _pm_mc: Node = get_node_or_null("/root/PerformanceMetricsManager")
		if _pm_mc != null and _pm_mc.has_method("record_milestone"):
			_pm_mc.record_milestone("first_mythic_card")

	# 入包广播（收集计数/背包实时刷新）+ 制造信号
	SignalBus.card_added_to_backpack.emit(inst)
	SignalBus.card_manufactured.emit(card_id, rarity)
	# v26.6 批4b: 死信号审计 B 类补反馈链——制造成功 toast（原信号无人监听）
	const IntelItems := preload("res://data/intel_manual_items.gd")
	var toast_text := "✦ 制造成功：%s（%s）" % [inst.display_name, IntelItems.get_rarity_name(rarity)]
	if not startup_mods.is_empty():
		toast_text += "·随附改造×%d" % startup_mods.size()
	SignalBus.show_toast.emit(toast_text)

	return {"ok": true, "reason_zh": "制造成功", "instance_id": String(inst.instance_id),
		"rarity": rarity, "card_id": card_id, "startup_mods": startup_mods}

func _refund(cost: Dictionary) -> void:
	for rid in cost:
		BasicResourceManager.add_resource(String(rid), int(cost[rid]))

## ───────────────────────── 改造图纸制造（v26.x 消耗品化·制造通道） ─────────────────────────
## 门槛规则：得到过就可造（IntelItemBag「见过集合」）——掉落负责发现，制造负责补给。
## 混合形态：common/uncommon/rare 定向兑换；epic+ 只能随机箱 roll（含暗保底）。

## 见过集合中有效改造的 mod_id 列表（ModificationRegistry 存在）
func get_seen_mod_ids() -> Array:
	var out: Array = []
	if IntelItemBag == null or not IntelItemBag.has_method("get_seen_item_ids"):
		return out
	for item_type in IntelItemBag.get_seen_item_ids():
		var s := String(item_type)
		if not IntelManualItems.is_mod_blueprint(s):
			continue
		var mod_id := BlueprintDefinitions.extract_mod_id(s)
		if mod_id.is_empty() or out.has(mod_id):
			continue
		if ModificationRegistry.get_data(mod_id).is_empty():
			continue
		out.append(mod_id)
	return out

## 定向区配方目录（见过 ∩ common/uncommon/rare，稀有度升序）。
## 返回 [{mod_id, name, rarity, stock}]
func get_mod_direct_recipes() -> Array:
	var out: Array = []
	for mod_id in get_seen_mod_ids():
		var mod_data: Dictionary = ModificationRegistry.get_data(String(mod_id))
		var rarity := String(mod_data.get("rarity", "common"))
		if not ModManufacture.is_direct_rarity(rarity):
			continue
		out.append({
			mod_id = String(mod_id),
			name = String(mod_data.get("name", mod_id)),
			rarity = rarity,
			stock = get_mod_blueprint_stock(String(mod_id)),
		})
	out.sort_custom(func(a, b):
		return ModManufacture.rank_of(String(a.rarity)) < ModManufacture.rank_of(String(b.rarity)))
	return out

## 随机箱池（见过 ∩ epic+）：[{mod_id, rarity}]
func get_mod_box_pool() -> Array:
	var out: Array = []
	for mod_id in get_seen_mod_ids():
		var mod_data: Dictionary = ModificationRegistry.get_data(String(mod_id))
		var rarity := String(mod_data.get("rarity", "common"))
		if ModManufacture.is_random_rarity(rarity):
			out.append({mod_id = String(mod_id), rarity = rarity})
	return out

func get_mod_blueprint_stock(mod_id: String) -> int:
	if IntelItemBag == null or not IntelItemBag.has_method("get_count"):
		return 0
	return int(IntelItemBag.get_count("blueprint_" + mod_id))

## 随机箱暗保底计数（与卡牌制造 get_pity 同暴露口径，供 UI 显示"连续未出"提示）
func get_mod_box_pity() -> int:
	return _mod_box_pity

## v32.0 B3-S2: 晶体 sink 管线①——晶体垫改造随机箱 pity（结构层，占位价 80/+1）
## v6.19.1 核验清单#4 落地原 TODO：pity ≤ 阈值-1 封顶（不卖免费保底）——
## 已到激活线前拒绝垫付；未到线按剩余额度部分成交（请求 3 只剩 1 额度 → 只扣 1 份晶体）。
const CRYSTAL_PER_PITY := 80

func advance_mod_box_pity_with_crystals(times: int = 1) -> Dictionary:
	if BasicResourceManager == null:
		return {ok = false, reason = "资源管理器未就绪"}
	var cap: int = ModManufacture.PITY_THRESHOLD - 1
	if _mod_box_pity >= cap:
		return {ok = false, reason = "保底已就绪（下次开箱传说+ 概率已提升），无需垫付", pity = _mod_box_pity}
	var requested := clampi(times, 1, 3)
	var n := mini(requested, cap - _mod_box_pity)
	var price := n * CRYSTAL_PER_PITY
	if not BasicResourceManager.can_afford("crystal", price):
		return {ok = false, reason = "晶体不足（需 %d）" % price}
	# 2026-09-19：spend_resource 方法不存在（原靠 has_method 兜底），统一走 consume
	BasicResourceManager.consume("crystal", price)
	_mod_box_pity += n
	return {ok = true, advanced = n, crystal_spent = price, pity = _mod_box_pity,
		capped = n < requested}


## 随机箱各稀有度出率（池内数量 × 稀有度权重归一；供 UI 预览池条）。
## 返回 [{r: String, w: float, pct: float}]，空池返回 []。
func get_mod_box_odds() -> Array:
	var per: Dictionary = {}
	for e in get_mod_box_pool():
		var r := String(e.get("rarity", "epic"))
		per[r] = int(per.get(r, 0)) + 1
	var out: Array = []
	var total := 0.0
	for r in per:
		var w := float(ModManufacture.RANDOM_BOX_WEIGHTS.get(String(r), 1.0)) * int(per[r])
		out.append({r = String(r), w = w})
		total += w
	if total <= 0.0:
		return []
	for e in out:
		e["pct"] = float(e["w"]) / total
	return out

## 定向兑换实际价（×工坊折扣）
func get_mod_direct_cost(mod_id: String) -> Dictionary:
	var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
	return _apply_workshop_discount(
		ModManufacture.get_direct_cost(String(mod_data.get("rarity", "common"))))

## 随机箱实际价（×工坊折扣）
func get_mod_box_cost() -> Dictionary:
	return _apply_workshop_discount(ModManufacture.RANDOM_BOX_COST.duplicate())

## 定向兑换资格。条件快照结构与 can_manufacture 同形，面板复用逐条件渲染器。
func can_craft_mod_direct(mod_id: String) -> Dictionary:
	var conditions: Array = []
	var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
	if mod_data.is_empty():
		return {"ok": false, "reason_zh": "改造数据缺失：%s" % mod_id, "conditions": conditions}
	var rarity := String(mod_data.get("rarity", "common"))

	# 1. 见过（得到过——制造只补给已发现的图纸）
	var seen_ok := IntelItemBag != null and IntelItemBag.has_method("has_seen") \
		and IntelItemBag.has_seen("blueprint_" + mod_id)
	conditions.append({
		"key": "seen", "met": seen_ok,
		"current_text": "已获得" if seen_ok else "未获得", "required_text": "已获得",
		"detail": "得到过该图纸才可补给（战斗掉落/相位师战利品可得）",
	})

	# 2. 稀有度属定向区（epic+ 走随机箱）
	var zone_ok := ModManufacture.is_direct_rarity(rarity)
	conditions.append({
		"key": "zone", "met": zone_ok,
		"current_text": rarity, "required_text": "普通/优秀/稀有",
		"detail": "史诗及以上改造只能通过随机箱补给",
	})

	# 3. 资源
	var cost := get_mod_direct_cost(mod_id)
	var res_ok := _can_afford(cost)
	conditions.append({
		"key": "resources", "met": res_ok,
		"current_text": "充足" if res_ok else "不足",
		"required_text": ManufacturePools.cost_text(cost),
		"detail": "制造消耗资源；工坊 Lv2/Lv3 可享 10%/20% 折扣",
	})

	var ok := seen_ok and zone_ok and res_ok
	return {"ok": ok, "reason_zh": "" if ok else _first_unmet_reason(conditions),
		"conditions": conditions}

## 随机箱资格
func can_craft_mod_random() -> Dictionary:
	var conditions: Array = []
	var pool := get_mod_box_pool()
	var pool_ok := not pool.is_empty()
	conditions.append({
		"key": "pool", "met": pool_ok,
		"current_text": "%d 种" % pool.size(), "required_text": "≥1 种",
		"detail": "图鉴中存在史诗+改造图纸才可开箱（战斗掉落可得）",
	})
	var cost := get_mod_box_cost()
	var res_ok := _can_afford(cost)
	conditions.append({
		"key": "resources", "met": res_ok,
		"current_text": "充足" if res_ok else "不足",
		"required_text": ManufacturePools.cost_text(cost),
		"detail": "开箱消耗资源；工坊 Lv2/Lv3 可享 10%/20% 折扣",
	})
	var ok := pool_ok and res_ok
	return {"ok": ok, "reason_zh": "" if ok else _first_unmet_reason(conditions),
		"conditions": conditions}

## 定向兑换一张改造图纸。返回 {"ok", "reason_zh", "mod_id"}。
func craft_mod_blueprint_direct(mod_id: String) -> Dictionary:
	var check := can_craft_mod_direct(mod_id)
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason_zh": String(check.get("reason_zh", "无法制造"))}
	var cost := get_mod_direct_cost(mod_id)
	for rid in cost:
		BasicResourceManager.consume(String(rid), int(cost[rid]))
	if not _grant_mod_blueprint(mod_id):
		_refund(cost)
		return {"ok": false, "reason_zh": "入包失败（卡仓异常）"}
	return {"ok": true, "reason_zh": "制造成功", "mod_id": mod_id}

## 开一次随机箱（从见过集合的 epic+ 池按稀有度加权 roll，含暗保底）。
## 返回 {"ok", "reason_zh", "mod_id", "rarity"}。
func craft_mod_blueprint_random() -> Dictionary:
	var check := can_craft_mod_random()
	if not bool(check.get("ok", false)):
		return {"ok": false, "reason_zh": String(check.get("reason_zh", "无法制造"))}
	var cost := get_mod_box_cost()
	for rid in cost:
		BasicResourceManager.consume(String(rid), int(cost[rid]))
	var mod_id := ModManufacture.roll_box_mod(get_mod_box_pool(), _mod_box_pity)
	if mod_id.is_empty() or not _grant_mod_blueprint(mod_id):
		_refund(cost)
		return {"ok": false, "reason_zh": "入包失败（卡仓/随机池异常）"}
	# 暗保底记账：出 legendary+ 清零，否则 +1
	var rolled_rarity := String(ModificationRegistry.get_data(mod_id).get("rarity", "epic"))
	if ModManufacture.is_pity_reset_rarity(rolled_rarity):
		_mod_box_pity = 0
	else:
		_mod_box_pity += 1
	# v6.19 P2-T2.2 流派成型埋点：首次开出神话档改造
	if rolled_rarity == "mythic":
		var _pm_mythic: Node = get_node_or_null("/root/PerformanceMetricsManager")
		if _pm_mythic != null and _pm_mythic.has_method("record_milestone"):
			_pm_mythic.record_milestone("first_mythic_mod")
	return {"ok": true, "reason_zh": "制造成功", "mod_id": mod_id, "rarity": rolled_rarity}

## 图纸入包 + toast（失败路径由调用方退款）
func _grant_mod_blueprint(mod_id: String) -> bool:
	if IntelItemBag == null or not IntelItemBag.has_method("add_item"):
		return false
	IntelItemBag.add_item("blueprint_" + mod_id, 1)
	var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
	SignalBus.show_toast.emit("✦ 补给成功：%s 改造图纸" % String(mod_data.get("name", mod_id)))
	return true

## ───────────────────────── 存档 ─────────────────────────

func save_state() -> Dictionary:
	return {SAVE_KEY_PITY: _pity.duplicate(), SAVE_KEY_MOD_PITY: _mod_box_pity}

func load_state(data: Dictionary) -> void:
	if data.is_empty():
		_pity = {}
		_mod_box_pity = 0
		return
	var pity: Variant = data.get(SAVE_KEY_PITY, {})
	_pity = {}
	if pity is Dictionary:
		for k in pity:
			_pity[str(k)] = maxi(0, int(pity[k]))
	_mod_box_pity = maxi(0, int(data.get(SAVE_KEY_MOD_PITY, 0)))
