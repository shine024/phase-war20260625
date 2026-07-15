extends RefCounted
## 默认战斗卡数据(v5.0:110单位 + 每目标攻击速度 + 堡垒类)
##
## v8.0: 数据源统一——战斗卡基础数值改从 UnifiedCardTable（统一卡牌表）读取，
## 消灭三套并行数据源（default_cards / captured_card_stats / enemy_archetypes）的量级混乱。
## create_all() 现从 UnifiedCardTable.get_player_card_entries() 构造 CardResource，
## 原 110 张硬编码 _unit() 调用已废弃（保留 _unit 函数体供历史兼容/测试引用）。

const GC = preload("res://resources/game_constants.gd")
const RealWorldUnitLabels = preload("res://data/real_world_unit_labels.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyBlueprints = preload("res://data/enemy_blueprints.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
# v7.x：卡牌ID规范化迁移表（旧ID → 最新ID）。无循环依赖（migration_config 仅 extends RefCounted）。
const UnitIdMigration = preload("res://data/unit_id_migration_config.gd")
# v8.0: 统一卡牌表（单一真值源）
const UnifiedCardTable = preload("res://data/unified_card_table.gd")
# v7.x 性能：势力专属卡（提为类常量，get_all_blueprint_ids_lightweight 和 create_all 共用）
const EC = preload("res://data/faction_exclusive_cards.gd")

## 静态缓存:避免每次 get_card_by_id 都重新创建
static var _all_cards_cache: Array = []
static var _id_lookup_cache: Dictionary = {}

static var _cache_building: bool = false

## 确保缓存已构建
static func _ensure_card_cache() -> void:
	if not _all_cards_cache.is_empty():
		return
	if _cache_building:
		push_warning("[DefaultCards] 缓存正在构建中,防止重入")
		return # 防重入:构建过程中被间接回调时直接返回,避免无限递归
	_cache_building = true
	_all_cards_cache = create_all()
	for c in _all_cards_cache:
		if c is CardResource:
			_id_lookup_cache[c.card_id] = c
		else:
			push_error("[DefaultCards] create_all() 返回了非 CardResource 对象: %s" % str(c))
	_cache_building = false
	if OS.is_debug_build():
		print("[DefaultCards] 缓存构建完成,共 %d 张卡牌" % _all_cards_cache.size())

## 参数:id, name, era(0-4), combat_kind(0-4), power, deploy_speed, range, energy_cost, hp,
##      attack_light, attack_light_speed, attack_light_windup, attack_light_active,
##      attack_armor, attack_armor_speed, attack_armor_windup, attack_armor_active,
##      attack_air, attack_air_speed, attack_air_windup, attack_air_active,
##      defense_light, defense_armor, defense_air,
##      weapon_light_name, weapon_armor_name, weapon_air_name
static func _unit(
	id: String, name: String, era: int, combat_kind: int, power: int,
	deploy_speed: int, range_val: int, energy_cost: int, hp: int,
	atk_l: int, atk_l_speed: float, atk_l_windup: float, atk_l_active: float,
	atk_a: int, atk_a_speed: float, atk_a_windup: float, atk_a_active: float,
	atk_air: int, atk_air_speed: float, atk_air_windup: float, atk_air_active: float,
	def_l: int, def_a: int, def_air: int, w_light: String = "", w_armor: String = "", w_air: String = ""
) -> CardResource:
	var c = CardResource.new()

	c.card_id = id
	c.display_name = name
	c.card_type = GC.CardType.COMBAT_UNIT
	c.era = era
	c.combat_kind = combat_kind
	c.power = power
	c.deploy_speed = deploy_speed
	c.range_value = range_val
	c.energy_cost = energy_cost
	c.base_hp = float(hp)

	# 攻击属性
	c.attack_light = atk_l
	c.attack_light_speed = atk_l_speed
	c.attack_light_windup = atk_l_windup
	c.attack_light_active = atk_l_active

	c.attack_armor = atk_a
	c.attack_armor_speed = atk_a_speed
	c.attack_armor_windup = atk_a_windup
	c.attack_armor_active = atk_a_active

	c.attack_air = atk_air
	c.attack_air_speed = atk_air_speed
	c.attack_air_windup = atk_air_windup
	c.attack_air_active = atk_air_active

	# 防御属性
	c.defense_light = def_l
	c.defense_armor = def_a
	c.defense_air = def_air

	# 武器名称
	c.weapon_names[0] = w_light
	c.weapon_names[1] = w_armor
	c.weapon_names[2] = w_air

	# 派生属性
	c.attack_speed = _calculate_attack_speed(atk_l, atk_a, atk_air, atk_l_speed, atk_a_speed, atk_air_speed)
	c.weapon_type = _infer_weapon_type(combat_kind, range_val, atk_l, atk_a, atk_air)
	c.unit_subtype = _infer_unit_subtype(combat_kind, range_val, atk_l, atk_a, atk_air, w_light, w_armor, w_air)
	c.rarity = _infer_rarity(era, power)
	c.type_line = _format_type_line(era, combat_kind)
	c.summary_line = _format_summary(c)

	# 基础属性
	c.platform_type = combat_kind

	return c

## 计算综合攻击速度(取主要攻击类型的攻速)
static func _calculate_attack_speed(atk_l: int, atk_a: int, atk_air: int, speed_l: float, speed_a: float, speed_air: float) -> float:
	if atk_l >= atk_a and atk_l >= atk_air:
		return speed_l
	elif atk_a >= atk_l and atk_a >= atk_air:
		return speed_a
	else:
		return speed_air

## v6.2: 推断单位子类标记（用于战斗定位差异化修正）
## 规则：
##   - combat_kind=4 (FORT) → FORT 子类
##   - combat_kind=2 (SUPPORT) 中：
##       * range≥99 或 atk_a≥atk_l（重火力）→ ARTILLERY 火炮
##       * atk_air 为主要攻击（防空炮）→ ANTI_AIR 防空特化
##       * 其余（机枪巢/工兵）→ SUPPORT 辅助
##   - combat_kind=0/1/3 → NONE（普通轻装/装甲/空中）
##   注：combat_kind 值保持不变（仍为0-4），子类仅用于修正差异化。
static func _infer_unit_subtype(combat_kind: int, range_val: int, atk_l: int, atk_a: int, atk_air: int, w_light: String, w_armor: String, w_air: String) -> int:
	if combat_kind == GC.CombatKind.FORT:
		return GC.UnitSubType.FORT
	if combat_kind == GC.CombatKind.SUPPORT:
		# 防空特化：对空攻击是主要攻击维度
		if atk_air > atk_l and atk_air > atk_a and atk_air > 0:
			return GC.UnitSubType.ANTI_AIR
		# 火炮：远射程 或 对装甲为主攻击（重火力）
		if range_val >= 99 or atk_a >= atk_l and atk_a > 0:
			return GC.UnitSubType.ARTILLERY
		# 其余支援（机枪巢/工兵）
		return GC.UnitSubType.SUPPORT
	return GC.UnitSubType.NONE

static func create_all() -> Array:
	var list: Array = []

	# v8.0: 战斗卡基础数值从 UnifiedCardTable（统一卡牌表）读取。
	# 原 110 张硬编码 _unit() 调用已废弃，改为统一表驱动——确保玩家卡/敌方原型/缴获卡
	# 三者共享同一套基础数值，消灭量级混乱（缴获卡 240 血 vs 原生卡 2200 血的 bug）。
	for entry in UnifiedCardTable.get_player_card_entries():
		var card: CardResource = UnifiedCardTable.build_card_resource(String(entry.get("card_id", "")))
		if card != null:
			list.append(card)

	# ─── 势力专属卡(14张)───
	# v7.x: EC 已提为类常量
	for cfg in EC.EXCLUSIVE_CARDS:
		list.append(EC.create_card(cfg))

	return list
## 返回所有蓝图 ID(战斗卡 + 能量卡 + 敌人蓝图)
static func get_all_blueprint_ids() -> Array:
	var ids: Array = []
	_ensure_card_cache()
	for c in _all_cards_cache:
		if c is CardResource:
			var card := c as CardResource
			if card.card_type == GC.CardType.COMBAT_UNIT or card.card_type == GC.CardType.ENERGY:
				ids.append(card.card_id)
	# 添加敌人掉落的高级蓝图ID
	for id in EnemyBlueprints.get_all_enemy_blueprint_ids():
		if id is String and not ids.has(id):
			ids.append(id)
	return ids

## v7.x 性能：返回所有蓝图 ID 的轻量版——不构建任何 CardResource。
## get_all_blueprint_ids() 会触发 _ensure_card_cache() 构建 133 张完整卡对象，
## 但 BlueprintManager._unlock_default_blueprints 等调用方只需 card_id 字符串做集合判断。
## 轻量版直接从数据表提取 id，启动期可省去 133 次 CardResource.new() + 派生计算。
## 与 get_all_blueprint_ids() 返回的 id 集合完全一致（玩家战斗卡 + 势力专属卡 + 敌人蓝图）。
static func get_all_blueprint_ids_lightweight() -> Array:
	var ids: Array = []
	# 1. 玩家战斗卡 id（直接从统一表取，不构建 CardResource）
	for entry in UnifiedCardTable.get_player_card_entries():
		var cid: String = String(entry.get("card_id", ""))
		if not cid.is_empty() and not ids.has(cid):
			ids.append(cid)
	# 2. 势力专属卡 id（从配置字典取 "id" 字段，不构建 CardResource）
	for cfg in EC.EXCLUSIVE_CARDS:
		var eid: String = String(cfg.get("id", ""))
		if not eid.is_empty() and not ids.has(eid):
			ids.append(eid)
	# 3. 敌人掉落的高级蓝图 id（已走 _get_all_cached 缓存）
	for eid in EnemyBlueprints.get_all_enemy_blueprint_ids():
		if eid is String and not ids.has(eid):
			ids.append(eid)
	return ids

## 根据 PhaseLaws 定义生成法则卡模板(印制/发奖时用 clone())
static func create_law_card_resource(law_id: String) -> CardResource:
	var law: Dictionary = PhaseLaws.get_by_id(law_id)
	if law.is_empty():
		return null
	var kind: String = String(law.get("kind", ""))
	var c := CardResource.new()
	c.card_id = law_id
	c.linked_law_id = law_id
	var lname: String = String(law.get("name", ""))
	c.display_name = lname if not lname.is_empty() else law_id
	c.card_type = GC.CardType.LAW
	c.rarity = "rare" if kind == "passive" else "epic"
	var bc: Dictionary = law.get("battle_cost", {})
	var ac: Dictionary = law.get("activate_cost", {})
	if kind == "active":
		c.energy_cost = float(bc.get("energy", 0.0))
		c.type_line = "法则 — 主动"
		var nano_b: int = int(bc.get("nano", 0))
		if nano_b > 0:
			c.summary_line = "战中 %d⚡｜纳米 %d" % [int(c.energy_cost), nano_b]
		else:
			c.summary_line = "战中能耗 %d⚡" % int(c.energy_cost)
	else:
		c.energy_cost = float(ac.get("nano", 0))
		c.type_line = "法则 — 被动"
		c.summary_line = "激活纳米 %d" % int(ac.get("nano", 0))
	c.description = "自蓝图印制；装配至相位仪红/蓝槽后,在战前环境满足时可激活。"
	c.flavor_text = "\"法则需要载体。\""
	return c

## 根据 card_id 获取卡牌(兼容层)
static func get_card_by_id(card_id: String) -> CardResource:
	_ensure_card_cache()
	if _id_lookup_cache.has(card_id):
		return _id_lookup_cache[card_id] as CardResource
	# v7.x：旧ID迁移兜底。卡牌规范化重命名（inf/arm/arty/sup/fort 前缀）后，
	# 旧存档/旧引用查不到时，通过迁移表查最新ID。所有调用方自动受益。
	if UnitIdMigration.needs_migration(card_id):
		var migrated_id: String = UnitIdMigration.get_new_id(card_id)
		if migrated_id != card_id and _id_lookup_cache.has(migrated_id):
			return _id_lookup_cache[migrated_id] as CardResource
	return null

## v7.0: 克隆一份模板卡的副本用于实例化（不污染单例缓存）
## 返回独立 CardResource 对象，instance_id 为空（待 InstanceRegistry 分配）
static func clone_for_instance(card_id: String) -> CardResource:
	var template: CardResource = get_card_by_id(card_id)
	if template == null:
		return null
	var clone: CardResource = template.clone()
	# 确保养成字段是干净的初始状态（防御性：模板可能被旧代码污染）
	clone.instance_id = ""
	clone.enhance_level = 0
	clone.mods = []
	clone.module_slots = []
	clone.weapon_slots = Array()
	return clone

## 注册动态生成的卡（混血卡/敌源变体/缴获卡等）到缓存，使 get_card_by_id / get_all_cards 可用。
## 用于运行时生成的卡牌，不参与 create_all() 的静态表。
## v7.x 修复：同时更新 _all_cards_cache + _id_lookup_cache（原只更新 lookup 导致两缓存不一致）。
static func register_dynamic_card(card: CardResource) -> void:
	if card == null or card.card_id.is_empty():
		return
	if not _id_lookup_cache.has(card.card_id):
		_all_cards_cache.append(card)
	_id_lookup_cache[card.card_id] = card

## 创建战斗单位辅助函数(v5.0:24参数,v6.0:含武器名参数)

## 推断武器类型
static func _infer_weapon_type(combat_kind: int, range: int, atk_light: int, atk_armor: int, atk_air: int) -> int:
	# 纯辅助/无攻击力单位 → 标记为 SUPPORT
	if atk_light == 0 and atk_armor == 0 and atk_air == 0:
		return GC.WeaponType.SUPPORT
	# 空中单位 → AERIAL
	if combat_kind == 3:  # AIR
		return GC.WeaponType.AERIAL
	# 支援单位（火炮/迫击炮等）→ INDIRECT（优先判定）
	if combat_kind == 2:  # SUPPORT
		return GC.WeaponType.INDIRECT
	# 曲射单位(range>=99)→ INDIRECT
	if range >= 99:
		return GC.WeaponType.INDIRECT
	# 默认直射(包括堡垒类 range<99)
	return GC.WeaponType.DIRECT

## 推断稀有度
static func _infer_rarity(era: int, power: int) -> String:
	if era <= 1:
		return "common"
	elif era == 2:
		return "rare" if power > 400 else "uncommon"
	elif era == 3:
		return "epic" if power > 800 else "rare"
	else:  # era 4
		return "mythic" if power > 1500 else "legendary"

## 格式化类型行
static func _format_type_line(era: int, combat_kind: int) -> String:
	var era_names = ["一战", "二战", "冷战", "现代", "近未来"]
	var kind_names = ["轻装", "装甲", "支援", "空中", "堡垒"]
	return "%s — %s" % [era_names[era], kind_names[combat_kind]]

## 格式化摘要
static func _format_summary(c: CardResource) -> String:
	var parts = []
	parts.append("战力 %d" % c.power)

	if c.attack_speed > 0:
		parts.append("攻速 %.1f/s" % c.attack_speed)

	parts.append("部署 %d" % c.deploy_speed)

	if c.range_value < 99:
		parts.append("射程 %d" % c.range_value)
	else:
		parts.append("全图")

	# 显示主要攻击类型(使用主目标攻击速度)
	var main_atk = 0
	var main_type = ""
	var main_speed = c.attack_speed
	if c.attack_light >= c.attack_armor and c.attack_light >= c.attack_air:
		main_atk = c.attack_light
		main_type = "直射"
		main_speed = c.attack_light_speed
	elif c.attack_armor >= c.attack_light and c.attack_armor >= c.attack_air:
		main_atk = c.attack_armor
		main_type = "曲射"
		main_speed = c.attack_armor_speed
	else:
		main_atk = c.attack_air
		main_type = "空射"
		main_speed = c.attack_air_speed

	if main_atk > 0:
		parts.append("%s %d(%.1f)" % [main_type, main_atk, main_speed])

	return "｜".join(parts)

## 平台类型显示名(兼容旧 platform_type 引用)
static func get_platform_display_name(platform_type: int) -> String:
	return RealWorldUnitLabels.platform_chassis_long(platform_type)

## 武器类型显示名（v6.5：当前 WeaponType 为4值攻击方式枚举，返回战斗方式描述；
## 具体武器型号应由 card.weapon_names[] 提供）
static func get_weapon_display_name(weapon_type: int) -> String:
	return RealWorldUnitLabels.weapon_mode_name(weapon_type)

## 统一安全获取卡牌中文名:依次尝试 DefaultCards → EnemyPhaseEquipment → EnemyArchetypes → 返回 ID 本身
## 所有 UI 层的 ID 回退都应使用此函数,杜绝显示原始 card_id
static func get_safe_display_name(card_id: String) -> String:
	if card_id.is_empty():
		push_warning("[DefaultCards] get_safe_display_name: card_id 为空")
		return ""
	_ensure_card_cache()
	var c: CardResource = _id_lookup_cache.get(card_id) as CardResource
	if c != null and not c.display_name.is_empty() and not _looks_like_id(c.display_name):
		return c.display_name
	# 尝试敌方相位装备(platform 或 weapon)- 延迟加载避免循环依赖
	var eq_epe: GDScript = load("res://data/enemy_phase_equipment.gd")
	if eq_epe:
		var eq_data: Dictionary = eq_epe.get_war_platform(card_id)
		if not eq_data.is_empty():
			var eq_name: String = String(eq_data.get("name", ""))
			if not eq_name.is_empty():
				return eq_name
		eq_data = eq_epe.get_war_weapon(card_id)
		if not eq_data.is_empty():
			var eq_name: String = String(eq_data.get("name", ""))
			if not eq_name.is_empty():
				return eq_name
	# 尝试敌方原型表(enemy_* 格式)
	var arch_cfg: Dictionary = EnemyArchetypes.get_config(card_id)
	var arch_name: String = String(arch_cfg.get("display_name", "")) if not arch_cfg.is_empty() else ""
	if not arch_name.is_empty() and not _looks_like_id(arch_name):
		return arch_name
	# 尝试敌人掉落蓝图(bp_* 格式)
	var bp_card: CardResource = EnemyBlueprints.get_card_by_id(card_id)
	if bp_card != null and not bp_card.display_name.is_empty() and not _looks_like_id(bp_card.display_name):
		return bp_card.display_name
	# 所有回退都失败,记录警告并返回ID
	push_error("[DefaultCards] 无法找到卡牌名称: %s,将显示原始ID" % card_id)
	return card_id

## 从 CardResource 对象安全获取显示名称；display_name 为空或像 ID 时回退到 get_safe_display_name
static func safe_name(card: CardResource) -> String:
	if card == null:
		push_warning("[DefaultCards] safe_name: card 为 null")
		return ""
	if not card.display_name.is_empty() and not _looks_like_id(card.display_name):
		return card.display_name
	var fallback: String = get_safe_display_name(card.card_id)
	if fallback.is_empty():
		push_error("[DefaultCards] safe_name: 无法获取卡牌 %s 的名称" % card.card_id)
		return card.card_id  # 最后回退到ID,避免完全空白
	return fallback

## v7.x：从卡牌 instance_id 提取序号后缀（同名卡区分用）。
## instance_id 形如 "cold_t72#1" → 返回 " #1"；空 instance_id（共享模板）返回 ""。
## 用于背包/相位仪/情报面板等显示卡牌名时统一追加序号。
static func seq_suffix(card: CardResource) -> String:
	if card == null:
		return ""
	var iid: String = String(card.instance_id)
	if iid.is_empty():
		return ""
	var h: int = iid.rfind("#")
	if h < 0:
		return ""
	return " #%s" % iid.substr(h + 1)

## 判断一个字符串是否看起来像内部 ID 而非人类可读名称
static func _looks_like_id(s: String) -> bool:
	if s.is_empty():
		return false
	# 以常见 ID 前缀开头,或全是英文小写+下划线+数字且无中文
	if s.begins_with("bp_") or s.begins_with("enemy_") or s.begins_with("captured_") or s.begins_with("ww") or s.begins_with("cold_") or s.begins_with("modern_") or s.begins_with("future_"):
		return true
	# 纯 ASCII 小写+下划线+数字(无中文、无空格)= 大概率是 ID
	if s.to_utf8_buffer().size() == s.length() and s.find(" ") < 0:
		# 全 ASCII 且无空格:检查是否像 snake_case ID
		var has_underscore: bool = s.find("_") >= 0
		var has_digit: bool = false
		for ch in s:
			if ch >= '0' and ch <= '9':
				has_digit = true
				break
		if has_underscore and has_digit:
			return true
	return false
