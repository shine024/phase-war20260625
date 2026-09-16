extends RefCounted
## v7.0: 蓝图道具系统
## 蓝图是战斗掉落和商店可购买的**永久解锁凭证**（非消耗品）。
## 每个改造模块和进化路径都有对应的蓝图，获得后永久持有。
##
## v6.6 设计澄清：早期设计文档（DEEPV.md 等）曾将蓝图描述为"6种消耗品"，
## 但实际实现采用永久持有模式——玩家收集蓝图作为能力解锁凭证，
## 改造/进化时检查 has_item 但不消耗。此设计更符合"收集成长"玩法，
## consume_item 方法保留但当前无调用方（预留未来消耗型道具扩展）。
##
## 蓝图类型：
##   - 改造蓝图：blueprint_<mod_id> — 允许安装对应改造模块
##   - 进化蓝图：blueprint_evol_<from>_<to> — 允许对应进化操作
##
## 获取方式：
##   - 战斗掉落（基于敌人类型）
##   - 商店购买

const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
const PowerTiers = preload("res://data/power_tiers.gd")

## ── 商店可售卖的蓝图列表 ────────────────────────────────────

## 所有可在商店购买的蓝图ID
## 随着游戏进程解锁，这里列出初始可用的蓝图
const ALL_TYPES: Array[String] = [
	## 步兵改造蓝图 (LIGHT unit_type = 0)
	"blueprint_inf_01_submachine_gun",
	"blueprint_inf_02_assault_rifle",
	"blueprint_inf_05_ap_ammo",
	"blueprint_inf_11_armor_insert",
	## 装甲改造蓝图 (ARMOR unit_type = 1)
	"blueprint_arm_01_sloped_armor",
	"blueprint_arm_06_apfsds",
	"blueprint_arm_11_fire_control",
	## 更多蓝图将在游戏进程中解锁
]

## ── 蓝图类型前缀 ──────────────────────────────────────────

const PREFIX_MOD := "blueprint_"           ## 改造蓝图前缀
const PREFIX_EVOL := "blueprint_evol_"      ## 进化蓝图前缀

## ── 静态方法 ─────────────────────────────────────────────

## 判断蓝图ID是否有效
static func is_valid_blueprint(blueprint_id: String) -> bool:
	if blueprint_id.begins_with(PREFIX_MOD):
		return true
	if blueprint_id.begins_with(PREFIX_EVOL):
		return true
	return false

## 判断是否为改造蓝图
static func is_mod_blueprint(blueprint_id: String) -> bool:
	return BlueprintDefinitions.is_mod_blueprint(blueprint_id)

## 判断是否为进化蓝图
static func is_evolution_blueprint(blueprint_id: String) -> bool:
	return BlueprintDefinitions.is_evolution_blueprint(blueprint_id)

## 获取蓝图显示名称
static func get_blueprint_name(blueprint_id: String) -> String:
	if is_mod_blueprint(blueprint_id):
		var mod_id = BlueprintDefinitions.extract_mod_id(blueprint_id)
		return BlueprintDefinitions.get_mod_blueprint_name(mod_id)
	elif is_evolution_blueprint(blueprint_id):
		# 进化蓝图名称由调用者提供
		return "退役图纸"
	return "未知图纸"

## 获取蓝图稀有度
static func get_blueprint_rarity(blueprint_id: String) -> String:
	if is_mod_blueprint(blueprint_id):
		var mod_id = BlueprintDefinitions.extract_mod_id(blueprint_id)
		return BlueprintDefinitions.get_mod_blueprint_rarity(mod_id)
	elif is_evolution_blueprint(blueprint_id):
		return "epic"  # 进化图纸默认史诗
	return "common"

## 获取稀有度颜色（透传 GC.get_rarity_color，全项目唯一权威源）
const _GC = preload("res://resources/game_constants.gd")
static func get_rarity_color(rarity: String) -> Color:
	return _GC.get_rarity_color(rarity)

## 获取稀有度名称
static func get_rarity_name(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"uncommon": return "优秀"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传说"
		"mythic": return "神话"
		_: return "未知"

## 随机掉落一个改造蓝图（基于敌人类型）
## enemy_type: "infantry", "armor", "artillery", "air", "recon", etc.
## rank: "normal" / "elite" / "boss"
## power_tier: v6.14 可选，PowerTiers.Tier 枚举值（-1 表示不启用，走原 rank 逻辑）。
##             非空时用它决定的稀有度梯度覆盖 rank 的稀有度权重，实现"不同战力敌人掉不同改造"。
## bias_unit_types: v6.14 可选，占领势力偏好的改造类型（ModificationRegistry unit_type 字符串数组）。
##                  非空时：70% 概率从 bias 类型池抽（势力占领偏好），30% 走原 enemy_type 池（保留多样性）。
## max_era: v6.14 可选，玩家当前战役时代（0-4）——掉落侧对齐安装侧的 era_band 硬门：
##          普通件只掉时代带覆盖当前时代的改造（无 band=全带恒过），前期不再掉"当前装不上"
##          的期货图纸。v6.14.1（用户拍板）：极特殊件（史诗/传说/神话）允许按关卡所处时代
##          跨一级（下一时代）前瞻掉落——日常件即时可用，期货只以稀有惊喜形态偶发。
##          负值=不过滤（旧行为）；过滤后空池回退全量（有掉落总比没有强）。
static func roll_random_mod_blueprint(enemy_type: String, rank: String, power_tier: int = -1, bias_unit_types: Array = [], max_era: int = -1) -> Dictionary:
	# ModificationRegistry 已在类顶部 const 声明，无需重复声明

	# v6.14: 占领势力 bias —— 若指定 bias_unit_types，70% 概率改用 bias 池
	# unit_type 是 int（CombatKind：0=LIGHT, 1=ARMOR, 2=SUPPORT, 3=AIR, 4=FORT...）
	var effective_unit_type: int = _enemy_type_to_unit_type(enemy_type)
	if not bias_unit_types.is_empty() and randf() < 0.70:
		# 从 bias 里随机选一个类型名，转 int
		var bias_pick: String = String(bias_unit_types[randi() % bias_unit_types.size()])
		var bias_int: int = _unit_type_name_to_int(bias_pick)
		if bias_int >= 0:
			effective_unit_type = bias_int

	# 获取该单位类型可掉落的改造列表
	var available_mods = ModificationRegistry.get_for_unit_type(effective_unit_type)

	if available_mods.is_empty():
		# bias 池为空时回退原 enemy_type 池
		available_mods = ModificationRegistry.get_for_unit_type(_enemy_type_to_unit_type(enemy_type))
		if available_mods.is_empty():
			return {}

	# v6.14: 时代带过滤——与 ModificationRegistry.is_mod_era_compatible（安装门）同一判定。
	# v6.14.1（用户拍板）：普通件限当前时代；极特殊件（epic/legendary/mythic）允许跨一级
	# （下一时代）前瞻掉落，era_hi 钳到 4（近未来无下一时代=无前瞻）。
	if max_era >= 0:
		var era_hi: int = mini(max_era + 1, 4)
		var era_filtered: Array = []
		for mod_id in available_mods:
			var md: Dictionary = ModificationRegistry.get_data(mod_id)
			if ModificationRegistry.is_mod_era_compatible(md, max_era):
				era_filtered.append(mod_id)
			elif era_hi > max_era \
					and String(md.get("rarity", "common")) in ["epic", "legendary", "mythic"] \
					and ModificationRegistry.is_mod_era_compatible(md, era_hi):
				era_filtered.append(mod_id)
		if not era_filtered.is_empty():
			available_mods = era_filtered

	# 根据稀有度权重随机选择
	var weighted_pool = []
	for mod_id in available_mods:
		var mod_data = ModificationRegistry.get_data(mod_id)
		var rarity = mod_data.get("rarity", "common")
		var weight = _get_rarity_drop_weight(rarity, rank)
		# v6.14: 战力档位对稀有度权重做梯度调整（高档位抬高高稀有度权重）
		if power_tier >= 0:
			weight = _apply_power_tier_to_weight(weight, rarity, power_tier)
		if weight > 0:
			weighted_pool.append({"mod_id": mod_id, "weight": weight})

	var total_weight = 0
	for entry in weighted_pool:
		total_weight += entry.weight

	if total_weight == 0:
		return {}

	var roll = randi() % total_weight
	var cumulative = 0
	for entry in weighted_pool:
		cumulative += entry.weight
		if roll < cumulative:
			var blueprint_id = BlueprintDefinitions.get_mod_blueprint_id(entry.mod_id)
			return {
				"item_type": blueprint_id,
				"name": get_blueprint_name(blueprint_id),
				"rarity": get_blueprint_rarity(blueprint_id),
				"mod_id": entry.mod_id,
			}

	return {}

## v6.14.2: 缴获语义——从指定敌人实际携带的模块（配装档位切片）中随机掉一张蓝图。
## 与 roll_random_mod_blueprint 同返回形；kit 内无效 id / 时代带不符（max_era≥0 时）的
## 条目剔除，剔完为空返回 {}（调用方回退全池 roll）。不做稀有度加权——敌人带什么掉什么。
static func roll_mod_blueprint_from_kit(kit_mods: Array, max_era: int = -1) -> Dictionary:
	var candidates: Array = []
	for mod_id in kit_mods:
		var mid := String(mod_id)
		if mid.is_empty():
			continue
		var md: Dictionary = ModificationRegistry.get_data(mid)
		if md.is_empty():
			continue
		if max_era >= 0 and not ModificationRegistry.is_mod_era_compatible(md, max_era):
			continue
		candidates.append(mid)
	if candidates.is_empty():
		return {}
	var picked: String = candidates[randi() % candidates.size()]
	var blueprint_id := BlueprintDefinitions.get_mod_blueprint_id(picked)
	return {
		"item_type": blueprint_id,
		"name": get_blueprint_name(blueprint_id),
		"rarity": get_blueprint_rarity(blueprint_id),
		"mod_id": picked,
	}

## 掉落侧时代口径（v6.14.1，用户拍板）：普通件时代带覆盖 max_era 即可；
## 极特殊件（epic/legendary/mythic）允许跨一级（下一时代，钳 4）前瞻。
static func _era_ok_for_drop(md: Dictionary, max_era: int) -> bool:
	if max_era < 0:
		return true
	if ModificationRegistry.is_mod_era_compatible(md, max_era):
		return true
	var era_hi: int = mini(max_era + 1, 4)
	return era_hi > max_era \
		and String(md.get("rarity", "common")) in ["epic", "legendary", "mythic"] \
		and ModificationRegistry.is_mod_era_compatible(md, era_hi)

## v6.14.4 比例发现腿（用户拍板 75/25 分流的发现侧）：全注册表按稀有度加权 roll——
## 保证全图鉴 249 件保持战斗可发现（发现 → 进见过集合 → 进随机箱池/定向列表）。
## 时代口径与 roll_random_mod_blueprint 一致（_era_ok_for_drop）；候选优先 is_seen
## 回调判否的"未见模块"（发现语义，直接怼缺口），全见过时退化为普通全池补给；
## rank/power_tier 沿用现有稀有度权重梯度（精英/Boss 更易出高稀有）。
static func roll_discovery_mod_blueprint(rank: String, power_tier: int, max_era: int, is_seen: Callable = Callable()) -> Dictionary:
	var pool: Array = []
	for ut in range(5):
		for mod_id in ModificationRegistry.get_for_unit_type(ut):
			var mid := String(mod_id)
			if pool.has(mid):
				continue
			var md: Dictionary = ModificationRegistry.get_data(mid)
			if md.is_empty() or not _era_ok_for_drop(md, max_era):
				continue
			pool.append(mid)
	if pool.is_empty():
		return {}
	var candidates: Array = pool
	if is_seen.is_valid():
		var unseen: Array = []
		for mid in pool:
			if not bool(is_seen.call(mid)):
				unseen.append(mid)
		if not unseen.is_empty():
			candidates = unseen
	var weighted: Array = []
	for mid in candidates:
		var md: Dictionary = ModificationRegistry.get_data(mid)
		var rarity := String(md.get("rarity", "common"))
		var w := _get_rarity_drop_weight(rarity, rank)
		if power_tier >= 0:
			w = _apply_power_tier_to_weight(w, rarity, power_tier)
		if w > 0:
			weighted.append({"mod_id": mid, "weight": w})
	var total_weight := 0
	for e in weighted:
		total_weight += int(e.weight)
	if total_weight == 0:
		return {}
	var roll := randi() % total_weight
	var cumulative := 0
	for e in weighted:
		cumulative += int(e.weight)
		if roll < cumulative:
			var picked := String(e.mod_id)
			var blueprint_id := BlueprintDefinitions.get_mod_blueprint_id(picked)
			return {
				"item_type": blueprint_id,
				"name": get_blueprint_name(blueprint_id),
				"rarity": get_blueprint_rarity(blueprint_id),
				"mod_id": picked,
			}
	return {}

## 随机掉落一个进化蓝图
## rank: "normal" / "elite" / "boss"
## v7.1: 实现——从 8 类进化路径的所有"进化跳"中按稀有度加权随机
## （允许掉重复：不查背包，已拥有的蓝图数量+1但不影响解锁状态）
static func roll_random_evolution_blueprint(rank: String) -> Dictionary:
	# 进化蓝图只从精英和Boss掉落
	if rank == "normal":
		return {}

	# 收集所有进化路径的"进化跳"（from_card → to_card）
	var all_evo_steps = _collect_all_evolution_steps()

	if all_evo_steps.is_empty():
		return {}

	# 按稀有度加权随机选择
	var weighted_pool = []
	for step in all_evo_steps:
		var rarity = _era_to_rarity(step.get("to_era", "WW1"))
		var weight = _get_rarity_drop_weight(rarity, rank)
		if weight > 0:
			weighted_pool.append({
				"from": step["from"],
				"to": step["to"],
				"rarity": rarity,
				"weight": weight,
			})

	if weighted_pool.is_empty():
		return {}

	# 加权随机
	var total_weight = 0
	for entry in weighted_pool:
		total_weight += entry.weight
	var roll = randi() % total_weight
	var cumulative = 0
	for entry in weighted_pool:
		cumulative += entry.weight
		if roll < cumulative:
			var blueprint_id = BlueprintDefinitions.get_evolution_blueprint_id(entry.from, entry.to)
			return {
				"item_type": blueprint_id,
				"name": get_blueprint_name(blueprint_id),
				"rarity": entry.rarity,
				"from": entry.from,
				"to": entry.to,
			}
	return {}

## ── 内部工具 ─────────────────────────────────────────────

## v7.1: 收集所有进化路径的进化跳（每条路径的相邻节点配对）
## 返回: [{from, to, to_era}, ...]
## v7.x 数据断裂修复：原从 evolution_paths/*.gd 取进化跳（与 LINEAGES 分叉，含15个不存在的卡），
## 改为以 LINEAGES 为唯一权威——从 UnitLineageConfig.get_merged_lineages() 遍历提取所有 from→to 跳，
## 保证掉落的进化蓝图全部指向判定认可的路径，玩家拿到的蓝图一定能用上。
static func _collect_all_evolution_steps() -> Array:
	var steps: Array = []
	var lineages: Dictionary = UnitLineageConfig.get_merged_lineages()
	var seen_pairs: Dictionary = {}  # "from\x1fto" 去重（势力分支可能产生重复对）
	for source_id in lineages.keys():
		var cfg: Dictionary = lineages[source_id]
		if cfg.is_empty():
			continue
		# 主线跳（evolution_1）
		var evo_1: String = String(cfg.get("evolution_1", ""))
		if not evo_1.is_empty():
			_add_evo_step(steps, seen_pairs, String(source_id), evo_1)
		# 势力分支跳（faction_branches: {faction_id: target_card_id}）
		var branches: Dictionary = cfg.get("faction_branches", {})
		for faction_id in branches.keys():
			var target: String = String(branches[faction_id])
			if not target.is_empty():
				_add_evo_step(steps, seen_pairs, String(source_id), target)
	return steps

## v7.x: 添加单条进化跳（去重 + era 推断）
static func _add_evo_step(steps: Array, seen_pairs: Dictionary, from_id: String, to_id: String) -> void:
	var pair_key: String = from_id + "\u001f" + to_id  # 单元分隔符防止 card_id 拼接歧义
	if seen_pairs.has(pair_key):
		return
	seen_pairs[pair_key] = true
	steps.append({
		"from": from_id,
		"to": to_id,
		"to_era": _infer_era_from_card_id(to_id),
	})

## v7.x: 从 card_id 前缀推断时代字符串（LINEAGES 无 era 字段，复用 _era_to_rarity 映射）
static func _infer_era_from_card_id(card_id: String) -> String:
	if card_id.begins_with("ww1_"):
		return "WW1"
	if card_id.begins_with("ww2_"):
		return "WW2"
	if card_id.begins_with("cold_"):
		return "Cold"
	if card_id.begins_with("mod_") or card_id.begins_with("omega_"):
		return "Modern"
	if card_id.begins_with("fut_"):
		return "Future"
	return "WW1"  # 默认（保守，走最低稀有度权重）

## v7.1: 从单条进化路径（Dictionary，按stage排序）中提取相邻卡配对
static func _append_steps_from_path(steps: Array, path: Dictionary) -> void:
	if path.is_empty():
		return
	# 按stage排序
	var sorted: Array = []
	for key in path.keys():
		var node: Dictionary = path[key]
		sorted.append({"stage": int(node.get("stage", 0)), "node": node})
	sorted.sort_custom(func(a, b): return a.stage < b.stage)
	# 相邻配对
	var prev_card := ""
	for entry in sorted:
		var card_id: String = entry.node.get("card_id", "")
		if card_id.is_empty():
			continue
		if not prev_card.is_empty():
			steps.append({
				"from": prev_card,
				"to": card_id,
				"to_era": entry.node.get("era", "WW1"),
			})
		prev_card = card_id

## v7.1: 进化目标卡 era → 稀有度映射（影响掉落权重）
static func _era_to_rarity(era: String) -> String:
	match era:
		"WW1", "WW2": return "common"
		"Cold": return "uncommon"
		"Modern": return "rare"
		"Future", "Ultimate": return "epic"
		_: return "common"

static func _enemy_type_to_unit_type(enemy_type: String) -> int:
	# 将敌人类型转换为unit_type（CombatKind）
	# v6.4: 补全 flame/stealth/anti_air/boss/medic/command 等映射，避免只掉步兵蓝图
	match enemy_type:
		"infantry", "recon", "flame", "medic", "scout": return 0  # LIGHT（步兵系）
		"armor", "heavy_armor", "command": return 1  # ARMOR（装甲系，指挥官归装甲）
		"artillery", "engineer", "anti_air": return 2  # SUPPORT（炮兵/工兵/防空）
		"air", "stealth": return 3  # AIR（空军/隐身单位归空军）
		"fort", "boss_nano", "boss_phase": return 4  # FORT（堡垒/Boss 归堡垒）
		_: return 0  # 默认 LIGHT

## v6.14: 改造类型名（faction_conquest_buffs.FACTION_MOD_BIAS 用的 key）→ unit_type int。
## 与 _enemy_type_to_unit_type 的 CombatKind 取值对齐（0/1/2/3/4）。
## universal 表示通用池（返回 -1 触发回退逻辑），unknown 返回 -1。
static func _unit_type_name_to_int(type_name: String) -> int:
	match type_name:
		"infantry", "recon": return 0   # LIGHT
		"armor": return 1               # ARMOR
		"artillery", "engineer", "anti_air": return 2  # SUPPORT
		"air": return 3                 # AIR
		"fort": return 4                # FORT
		"universal": return -1          # 通用：调用方走 enemy_type 默认池
		_: return -1

static func _get_rarity_drop_weight(rarity: String, rank: String) -> int:
	# 根据稀有度和敌人等级返回掉落权重
	# v27：mythic 0→1（极稀）——gen_21~23 三件 mythic 行为改写改造自此可掉落；
	# boss ×3 也仅 3 权重，与 legendary(基础2) 同量级，制造箱仍是主通道。
	var base = 0
	match rarity:
		"common": base = 40
		"uncommon": base = 25
		"rare": base = 12
		"epic": base = 5
		"legendary": base = 2
		"mythic": base = 1
		_: base = 0

	match rank:
		"boss": return base * 3
		"elite": return base * 2
		_: return base


## v6.14: 战力档位对改造稀有度权重做梯度调整。
## 档位越高（CHAMPION/OVERLORD），高稀有度（rare/epic/legendary）权重越高，
## 低稀有度（common）权重越低，体现"强敌掉好货"。
## 设计为温和乘子，不改变 rank 的基础量级，只做梯度偏移。
static func _apply_power_tier_to_weight(base_weight: int, rarity: String, power_tier: int) -> int:
	if base_weight <= 0:
		return 0
	# 档位梯度：GRUNT/VETERAN 不调整；ELITE 略提稀有；CHAMPION 明显提稀有；OVERLORD 强提稀有
	var shift: float = 1.0
	match power_tier:
		PowerTiers.Tier.GRUNT, PowerTiers.Tier.VETERAN:
			shift = 1.0
		PowerTiers.Tier.ELITE:
			match rarity:
				"common": shift = 0.85
				"rare", "epic": shift = 1.20
				"legendary": shift = 1.40
				_: shift = 1.0
		PowerTiers.Tier.CHAMPION:
			match rarity:
				"common": shift = 0.65
				"uncommon": shift = 0.90
				"rare": shift = 1.30
				"epic": shift = 1.60
				"legendary": shift = 1.80
				_: shift = 1.0
		PowerTiers.Tier.OVERLORD:
			match rarity:
				"common": shift = 0.45
				"uncommon": shift = 0.70
				"rare": shift = 1.40
				"epic": shift = 1.90
				"legendary": shift = 2.40
				_: shift = 1.0
		_:
			shift = 1.0
	return maxi(0, int(round(float(base_weight) * shift)))

## ── 蓝图定义查询 ───────────────────────────────────────────

## 获取蓝图定义信息
## Returns: {name, desc, rarity, type}
static func get_def(blueprint_id: String) -> Dictionary:
	if not is_valid_blueprint(blueprint_id):
		push_warning("[IntelManualItems] 无效蓝图ID: %s" % blueprint_id)
		return {}

	if is_mod_blueprint(blueprint_id):
		var mod_id = BlueprintDefinitions.extract_mod_id(blueprint_id)
		var mod_data = ModificationRegistry.get_data(mod_id)
		if mod_data.is_empty():
			push_warning("[IntelManualItems] 改造模块不存在: %s" % mod_id)
			return {}
		var rarity = mod_data.get("rarity", "common")
		return {
			"name": BlueprintDefinitions.get_mod_blueprint_name(mod_id),
			"desc": _get_mod_blueprint_desc(mod_id, rarity),
			"rarity": rarity,
			"type": "mod",
			"mod_id": mod_id,
			"icon": "res://assets/ui/icons/icon_modification.svg",
		}
	elif is_evolution_blueprint(blueprint_id):
		## 进化蓝图定义
		var info = BlueprintDefinitions.extract_evolution_info(blueprint_id)
		var from_card = info.get("from", "")
		var to_card = info.get("to", "")
		if from_card.is_empty() or to_card.is_empty():
			push_warning("[IntelManualItems] 进化蓝图解析失败: %s, from=%s, to=%s" % [blueprint_id, from_card, to_card])
			return {}
		return {
			"name": "退役图纸：%s → %s" % [from_card, to_card],
			"desc": "（谱系已退役）此图纸不再有用途，仅作纪念收藏",
			"rarity": "epic",
			"type": "evolution",
			"from": from_card,
			"icon": "res://assets/ui/icons/icon_blueprint.svg",
			"to": to_card,
		}
	push_warning("[IntelManualItems] 未知的蓝图类型: %s" % blueprint_id)
	return {}

## 获取改造蓝图描述
static func _get_mod_blueprint_desc(mod_id: String, rarity: String) -> String:
	var rarity_name = get_rarity_name(rarity)
	return "允许安装【%s】改造模块（%s）" % [mod_id, rarity_name]

## 获取商店价格（基于稀有度）
## R1-4（设计审查 F-10，2026-09-13）：common/uncommon/rare 与制造补给站同价目对齐
## （制造定向兑换 80/150/280 纳米，mod_manufacture.gd）——原 100/250/600 与制造价差
## 最高 2.1 倍（rare 600 vs 280），同物双渠道明码冲突，理性玩家永远绕开商店。
## 现按"制造价 ×1.5 直购便利溢价"定价；epic+ 制造侧只能开随机箱（无定向渠道），
## 商店高价定位为"跳过随机的奢侈品通道"，无冲突，维持原价。
static func get_shop_price(blueprint_id: String) -> int:
	var def = get_def(blueprint_id)
	if def.is_empty():
		return 0
	var rarity = def.get("rarity", "common")
	match rarity:
		"common": return 120
		"uncommon": return 225
		"rare": return 420
		"epic": return 1500
		"legendary": return 3500
		_: return 120

# v9.x（P1-5 批次4）：get_available_blueprints（声望解锁 TODO 死函数，零调用方）已删除
# ——蓝图体系 2026-08-22 退役后该入口再无消费方，蓝图解锁逻辑随体系消亡

