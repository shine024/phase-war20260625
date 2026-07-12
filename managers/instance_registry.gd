extends Node
## InstanceRegistry — 卡牌实例注册表（v7.0 实例化养成）
##
## 所有卡牌实例的唯一真相源。每张卡是独立的 CardResource clone 对象，
## 带有唯一 instance_id（格式 card_id#序号，如 cold_t72#1）。
## 养成数据（enhance_level / mods / module_slots / weapon_slots / inherit_bonus /
## evolution_hp_floor / enemy_origin_mod / intel_branch_bonus）全部存在实例对象本身，
## 不再用 Dictionary[card_id] 查表。
##
## 生命周期：
##   - create_instance(card_id) → 制造/掉落/购买/初始时调用，返回带 instance_id 的 clone
##   - get_instance(instance_id) → 取实例（带养成）
##   - dispose_instance(instance_id) → 进化消耗/拆解时调用
##   - save_state / load_state → 序列化所有实例（含完整养成数据）
##
## 设计决策：
## 1. 养成数据挂在实例对象本身 —— CardResource 已有这些字段，实例化后自然隔离
## 2. 序号按 card_id 分别计数 —— cold_t72#1/#2/#3 与 ww2_tiger#1/#2 互不干扰
## 3. instance_id 格式 card_id#序号 —— 可读性强，调试方便，玩家背包一眼区分
## 4. 补上 enhance_level 存档缺口 —— 单例时代 enhance_level 不存档（重启丢失），
##    实例化后必然存，顺带修复

signal instance_created(instance_id: String, card_id: String)
signal instance_disposed(instance_id: String)

const DefaultCards = preload("res://data/default_cards.gd")
const GC = preload("res://resources/game_constants.gd")

## instance_id -> CardResource（独立 clone 对象，带完整养成）
var _instances: Dictionary = {}

## 加载失败的 instance_id（模板找不到），供调试/诊断用
var _load_failed_ids: Array = []

## card_id -> 当前最大序号（用于分配下一个序号）
var _counter: Dictionary = {}

## 进化相关养成数据（CardResource 无对应字段，单独存）
## instance_id -> float（进化继承属性倍率，如 0.30 = +30%）
var _inherit_bonus: Dictionary = {}
## instance_id -> float（进化后 era0 HP 下限）
var _evolution_hp_floor: Dictionary = {}
## instance_id -> String（敌源MOD ID）
## v7.x 现状说明：实际 EOM 装备走 BlueprintManager.blueprint_enemy_origin_mod（card_id 字典），
## 本字段从未被 EnemyOriginModManager.equip_eom 写入，当前为预留/未接入死字段。
## card_evolution_manager 进化迁移读此字段，因无写入方故恒读到空串（迁移空转，无害）。
## 若未来 EOM 重接战斗注入，需把 equip_eom 改为写本字段（走 instance 级隔离）。
var _enemy_origin_mod: Dictionary = {}
## instance_id -> Dictionary（情报进化分支奖励 {extra_mod_slot, special_ability}）
var _intel_branch_bonus: Dictionary = {}


# ─────────────────────────────────────────────
#  实例生命周期
# ─────────────────────────────────────────────

## 创建一个新实例（制造/掉落/购买/初始时调用）
## card_id: 卡牌模板 ID（如 "cold_t72"）
## 返回：带 instance_id 的独立 CardResource clone（养成数据为初始空状态）
## 注：仅支持已注册到 DefaultCards 缓存的卡（绝大多数战斗卡/能量卡）。
## 法则卡/缴获卡/混血卡等动态卡用 create_instance_from_template。
func create_instance(card_id: String) -> CardResource:
	var clone: CardResource = DefaultCards.clone_for_instance(card_id)
	if clone == null:
		push_error("[InstanceRegistry] 找不到卡牌模板: %s" % card_id)
		return null
	return _register_clone(clone, card_id)


## 从任意 CardResource 模板创建实例（法则卡/缴获卡/混血卡等动态卡用）
## template: 已构建好的 CardResource 模板对象（不会被修改，内部 clone）
## 返回：带 instance_id 的独立 CardResource clone
func create_instance_from_template(template: CardResource) -> CardResource:
	if template == null:
		push_error("[InstanceRegistry] create_instance_from_template: 模板为空")
		return null
	var clone: CardResource = template.clone()
	# 养成字段重置为干净初始状态（防御性）
	clone.enhance_level = 0
	clone.mods = []
	clone.module_slots = []
	clone.weapon_slots = Array()
	if clone.weapon_slots.is_empty() and clone.has_method("_ensure_weapon_slots_initialized"):
		clone._ensure_weapon_slots_initialized()
	return _register_clone(clone, template.card_id)


## 内部：注册一个 clone 到实例表并分配 instance_id
func _register_clone(clone: CardResource, card_id: String) -> CardResource:
	var instance_id := _allocate_instance_id(card_id)
	clone.instance_id = instance_id
	if clone.weapon_slots.is_empty() and clone.has_method("_ensure_weapon_slots_initialized"):
		clone._ensure_weapon_slots_initialized()
	_instances[instance_id] = clone
	instance_created.emit(instance_id, card_id)
	return clone


## 分配一个新的 instance_id（card_id#序号）
## v7.x 防御：若 _counter 与 _instances 状态不一致（极端情况，如计数器丢失/手工写入实例），
## 递增序号直到找到 _instances 中不存在的 id，绝不覆盖已存实例的养成数据。
func _allocate_instance_id(card_id: String) -> String:
	var seq: int = int(_counter.get(card_id, 0)) + 1
	while _instances.has("%s#%d" % [card_id, seq]):
		# 计数器落后于实例表（撞号），递增直到找到空位
		seq += 1
	_counter[card_id] = seq
	return "%s#%d" % [card_id, seq]


## 获取实例对象（带完整养成数据）
## 找不到返回 null
func get_instance(instance_id: String) -> CardResource:
	if instance_id.is_empty():
		return null
	return _instances.get(instance_id, null)


## 获取实例的 card_id（从 instance_id 解析）
## "cold_t72#1" → "cold_t72"
func get_card_id_of(instance_id: String) -> String:
	if instance_id.is_empty():
		return ""
	var hash_idx: int = instance_id.rfind("#")
	if hash_idx < 0:
		return instance_id  # 无序号后缀，本身就是 card_id
	return instance_id.substr(0, hash_idx)


## 销毁实例（进化消耗/拆解时调用）
## 清除实例对象及所有关联养成数据
func dispose_instance(instance_id: String) -> void:
	_instances.erase(instance_id)
	_inherit_bonus.erase(instance_id)
	_evolution_hp_floor.erase(instance_id)
	_enemy_origin_mod.erase(instance_id)
	_intel_branch_bonus.erase(instance_id)
	instance_disposed.emit(instance_id)
	# v7.x：转发到 SignalBus，让背包列表/存档队列同步清理该 instance_id，
	# 避免出现"背包列表有幽灵 id 但 Registry 无实例"的不一致（表现为 get_all_cards 告警+复用同名实例）。
	# 进化消耗源实例（card_evolution_manager）、相位仪清理能量卡（phase_instrument_manager）、
	# 背包拆解（backpack_presenter）三条路径都走 dispose_instance，在此统一通知最可靠。
	var sb = get_node_or_null("/root/SignalBus")
	if sb != null and sb.has_signal("instance_disposed"):
		sb.instance_disposed.emit(instance_id)


## 判断实例是否存在
func has_instance(instance_id: String) -> bool:
	return _instances.has(instance_id)


## 获取所有实例ID
func get_all_instance_ids() -> Array:
	return _instances.keys()


## 获取某 card_id 的所有实例ID（背包展示/统计用）
func get_instances_by_card_id(card_id: String) -> Array:
	var result: Array = []
	for iid in _instances:
		if get_card_id_of(iid) == card_id:
			result.append(iid)
	return result


# ─────────────────────────────────────────────
#  进化养成数据（CardResource 无对应字段，单独管理）
# ─────────────────────────────────────────────

## 进化继承属性倍率
func get_inherit_bonus(instance_id: String) -> float:
	return float(_inherit_bonus.get(instance_id, 0.0))

func set_inherit_bonus(instance_id: String, bonus: float) -> void:
	_inherit_bonus[instance_id] = clampf(bonus, 0.0, 0.9)

## 进化后 era0 HP 下限
func get_evolution_hp_floor(instance_id: String) -> float:
	return float(_evolution_hp_floor.get(instance_id, 0.0))

func set_evolution_hp_floor(instance_id: String, floor_base: float) -> void:
	_evolution_hp_floor[instance_id] = floor_base

## 敌源MOD ID
func get_enemy_origin_mod(instance_id: String) -> String:
	return String(_enemy_origin_mod.get(instance_id, ""))

func set_enemy_origin_mod(instance_id: String, mod_id: String) -> void:
	if mod_id.is_empty():
		_enemy_origin_mod.erase(instance_id)
	else:
		_enemy_origin_mod[instance_id] = mod_id

## 情报进化分支奖励
func get_intel_branch_bonus(instance_id: String) -> Dictionary:
	return _intel_branch_bonus.get(instance_id, {})

func set_intel_branch_bonus(instance_id: String, bonus: Dictionary) -> void:
	if bonus.is_empty():
		_intel_branch_bonus.erase(instance_id)
	else:
		_intel_branch_bonus[instance_id] = bonus


# ─────────────────────────────────────────────
#  存档序列化
# ─────────────────────────────────────────────

## 序列化所有实例（含完整养成数据）
## 每个 instance 序列化为 {card_id, enhance_level, mods, module_slots, weapon_slots, ...}
func save_state() -> Dictionary:
	var data: Dictionary = {}
	for instance_id in _instances:
		var card: CardResource = _instances[instance_id]
		if card == null:
			continue
		data[instance_id] = _serialize_instance(instance_id, card)
	data["_counter"] = _counter.duplicate(true)
	return data


## 序列化单个实例的完整养成数据
func _serialize_instance(instance_id: String, card: CardResource) -> Dictionary:
	var out: Dictionary = {
		"card_id": get_card_id_of(instance_id),
		"enhance_level": int(card.enhance_level),
		"mods": _serialize_mods(card.mods),
		"module_slots": _serialize_module_slots(card.module_slots),
		"weapon_slots": _serialize_weapon_slots(card.weapon_slots),
		"evolution_stage": int(card.evolution_stage),
		"inherit_bonus": get_inherit_bonus(instance_id),
		"evolution_hp_floor": get_evolution_hp_floor(instance_id),
		"enemy_origin_mod": get_enemy_origin_mod(instance_id),
		"intel_branch_bonus": get_intel_branch_bonus(instance_id),
	}
	return out


## 反序列化所有实例
func load_state(data: Dictionary) -> void:
	_instances.clear()
	_counter.clear()
	_inherit_bonus.clear()
	_evolution_hp_floor.clear()
	_enemy_origin_mod.clear()
	_intel_branch_bonus.clear()

	if data.is_empty():
		return

	# 恢复计数器（存档有此字段时；缺字段时下方 _reconcile_counter_from_instances 会从实例重建）
	if data.has("_counter") and data["_counter"] is Dictionary:
		_counter = (data["_counter"] as Dictionary).duplicate(true)

	# 恢复实例
	for instance_id in data.keys():
		if instance_id == "_counter":
			continue
		var inst_data: Dictionary = data[instance_id]
		if not inst_data is Dictionary:
			continue
		_load_one_instance(instance_id, inst_data)

	# v7.x 修复：从已加载实例重建计数器，杜绝 _counter 丢失导致序号回卷撞号。
	# 旧存档/v8 迁移期存档可能缺 _counter 字段，且 _load_one_instance 直接写 _instances
	# 不推进计数器——两因素叠加会让后续 create_instance 从 #1 重新分配，覆盖已存实例
	# 的养成数据（表现为"商店买的和缴获的都是 #1"）。无论存档有无 _counter，都以
	# _instances 实际状态为准做 max 合并，确保计数器永不落后于实例表。
	_reconcile_counter_from_instances()


## 加载单个实例
func _load_one_instance(instance_id: String, inst_data: Dictionary) -> void:
	var card_id: String = String(inst_data.get("card_id", ""))
	if card_id.is_empty():
		return
	var clone: CardResource = DefaultCards.clone_for_instance(card_id)
	if clone == null:
		# v7.x: 模板找不到意味着养成数据将永久丢失（该实例无法重建），用 push_error 暴露问题
		# （原 push_warning 易被忽略，旧存档卡模板被删/改名时玩家无感知）
		push_error("[InstanceRegistry] 加载实例 %s 失败：找不到卡牌模板 %s（养成数据将丢失）" % [instance_id, card_id])
		_load_failed_ids.append(instance_id)
		return
	clone.instance_id = instance_id
	clone.enhance_level = int(inst_data.get("enhance_level", 0))
	clone.mods = _deserialize_mods(inst_data.get("mods", []))
	clone.module_slots = _deserialize_module_slots(inst_data.get("module_slots", []))
	clone.weapon_slots = _deserialize_weapon_slots(inst_data.get("weapon_slots", []))
	clone.evolution_stage = int(inst_data.get("evolution_stage", 0))
	# 确保武器槽位初始化（防御性）
	if clone.weapon_slots.is_empty() and clone.has_method("_ensure_weapon_slots_initialized"):
		clone._ensure_weapon_slots_initialized()
	_instances[instance_id] = clone
	# 进化养成数据
	_inherit_bonus[instance_id] = float(inst_data.get("inherit_bonus", 0.0))
	_evolution_hp_floor[instance_id] = float(inst_data.get("evolution_hp_floor", 0.0))
	var eom: String = String(inst_data.get("enemy_origin_mod", ""))
	if not eom.is_empty():
		_enemy_origin_mod[instance_id] = eom
	var ibb = inst_data.get("intel_branch_bonus", {})
	if ibb is Dictionary and not (ibb as Dictionary).is_empty():
		_intel_branch_bonus[instance_id] = (ibb as Dictionary).duplicate(true)


## 从 _instances 实际状态重建计数器（load_state 收尾用）。
## 对每个已注册实例，取其 instance_id 的序号后缀，把 _counter[card_id] 推进到 max(已存值, 序号)。
## 作用：修复旧存档/v8 迁移期存档缺 _counter 字段、或 _counter 与实例表不一致时，
## 后续 create_instance 回卷到 #1 覆盖已存实例养成数据的严重 bug。
## 幂等：重复调用无副作用（max 合并，只会抬升计数器，永不回退）。
func _reconcile_counter_from_instances() -> void:
	for instance_id in _instances:
		var card_id := get_card_id_of(instance_id)
		if card_id.is_empty():
			continue
		var hash_idx: int = instance_id.rfind("#")
		if hash_idx < 0:
			continue
		var seq: int = instance_id.substr(hash_idx + 1).to_int()
		if seq <= 0:
			continue
		_counter[card_id] = maxi(int(_counter.get(card_id, 0)), seq)


# ─────────────────────────────────────────────
#  序列化辅助
# ─────────────────────────────────────────────

## 序列化 mods 数组（每项可能是 {id, level, enabled} 或 String）
func _serialize_mods(mods: Array) -> Array:
	var out: Array = []
	for m in mods:
		if m is Dictionary:
			out.append((m as Dictionary).duplicate(true))
		else:
			out.append(m)
	return out

func _deserialize_mods(data: Array) -> Array:
	var out: Array = []
	for m in data:
		if m is Dictionary:
			out.append((m as Dictionary).duplicate(true))
		else:
			out.append(m)
	return out

## 序列化 module_slots（Array[ModuleSlot]）
func _serialize_module_slots(slots: Array) -> Array:
	var out: Array = []
	for s in slots:
		if s != null and s.has_method("to_dict"):
			out.append(s.to_dict())
		elif s is Dictionary:
			out.append((s as Dictionary).duplicate(true))
	return out

func _deserialize_module_slots(data: Array) -> Array:
	var out: Array = []
	for sd in data:
		if sd is Dictionary:
			# ModuleSlot.from_dict 是 static 方法，直接用 class_name 调用
			out.append(ModuleSlot.from_dict(sd))
	return out

## 序列化 weapon_slots（Array[WeaponResource]）
func _serialize_weapon_slots(slots: Array) -> Array:
	var out: Array = []
	for w in slots:
		if w != null and w.has_method("clone"):
			# WeaponResource 无内置 to_dict，用字段提取
			# v7.x 健壮性: _mod_effects 先单独取并做类型校验——异常 mod 写入可能塞入非
			# Dictionary 值（如 Array），`as Dictionary` 会得 null，再 .duplicate(true) 将
			# null 解引用崩溃，中断整个 save_state 导致所有实例养成数据丢失。
			# 非 Dictionary 一律存 {}，保证存档永不因此字段中断。
			var _me_raw = w.get("_mod_effects")
			var _me_out: Dictionary = {}
			if _me_raw != null and typeof(_me_raw) == TYPE_DICTIONARY:
				_me_out = (_me_raw as Dictionary).duplicate(true)
			out.append({
				"weapon_id": String(w.weapon_id),
				"slot_type": int(w.slot_type),
				"display_name": String(w.display_name),
				"weapon_label": String(w.weapon_label),
				"enabled": bool(w.enabled),
				"damage": float(w.damage),
				"attack_speed": float(w.attack_speed),
				"windup": float(w.windup),
				"active": float(w.active),
				"weapon_type": int(w.weapon_type),
				"range_value": int(w.range_value),
				"projectile_scene": String(w.projectile_scene),
				"hit_effect_scene": String(w.hit_effect_scene),
				"sound_id": String(w.sound_id),
				# v7.3 修复: 补 _mod_effects（改造模块写入的武器级动态效果，如 slot_damage_mult）。
				"mod_effects": _me_out,
			})
	return out

func _deserialize_weapon_slots(data: Array) -> Array:
	var out: Array = []
	var wr_script = load("res://resources/weapon_resource.gd")
	for wd in data:
		if not (wd is Dictionary):
			continue
		var wd_dict: Dictionary = wd
		if wr_script == null:
			continue
		var w = wr_script.new()
		w.weapon_id = String(wd_dict.get("weapon_id", ""))
		w.slot_type = int(wd_dict.get("slot_type", 0))
		w.display_name = String(wd_dict.get("display_name", ""))
		w.weapon_label = String(wd_dict.get("weapon_label", ""))
		w.enabled = bool(wd_dict.get("enabled", true))
		w.damage = float(wd_dict.get("damage", 0.0))
		w.attack_speed = float(wd_dict.get("attack_speed", 1.0))
		w.windup = float(wd_dict.get("windup", 0.2))
		w.active = float(wd_dict.get("active", 0.1))
		w.weapon_type = int(wd_dict.get("weapon_type", 0))
		w.range_value = int(wd_dict.get("range_value", 3))
		w.projectile_scene = String(wd_dict.get("projectile_scene", ""))
		w.hit_effect_scene = String(wd_dict.get("hit_effect_scene", ""))
		w.sound_id = String(wd_dict.get("sound_id", ""))
		# v7.3 修复: 恢复 _mod_effects（武器级改造加成）
		var me: Dictionary = wd_dict.get("mod_effects", {})
		if me is Dictionary and not me.is_empty():
			w._mod_effects = me.duplicate(true)
		out.append(w)
	return out


# ─────────────────────────────────────────────
#  调试 / 统计
# ─────────────────────────────────────────────

func get_instance_count() -> int:
	return _instances.size()

func clear_all() -> void:
	_instances.clear()
	_counter.clear()
	_inherit_bonus.clear()
	_evolution_hp_floor.clear()
	_enemy_origin_mod.clear()
	_intel_branch_bonus.clear()
