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

## card_id -> 当前最大序号（用于分配下一个序号）
var _counter: Dictionary = {}

## 进化相关养成数据（CardResource 无对应字段，单独存）
## instance_id -> float（进化继承属性倍率，如 0.30 = +30%）
var _inherit_bonus: Dictionary = {}
## instance_id -> float（进化后 era0 HP 下限）
var _evolution_hp_floor: Dictionary = {}
## instance_id -> String（敌源MOD ID）
var _enemy_origin_mod: Dictionary = {}
## instance_id -> Dictionary（情报进化分支奖励 {extra_mod_slot, special_ability}）
var _intel_branch_bonus: Dictionary = {}


# ─────────────────────────────────────────────
#  实例生命周期
# ─────────────────────────────────────────────

## 创建一个新实例（制造/掉落/购买/初始时调用）
## card_id: 卡牌模板 ID（如 "cold_t72"）
## 返回：带 instance_id 的独立 CardResource clone（养成数据为初始空状态）
func create_instance(card_id: String) -> CardResource:
	var clone: CardResource = DefaultCards.clone_for_instance(card_id)
	if clone == null:
		push_error("[InstanceRegistry] 找不到卡牌模板: %s" % card_id)
		return null
	var instance_id := _allocate_instance_id(card_id)
	clone.instance_id = instance_id
	# 确保武器槽位初始化（武器槽是战斗必需的）
	if clone.has_method("_ensure_weapon_slots_initialized"):
		clone._ensure_weapon_slots_initialized()
	_instances[instance_id] = clone
	instance_created.emit(instance_id, card_id)
	return clone


## 分配一个新的 instance_id（card_id#序号）
func _allocate_instance_id(card_id: String) -> String:
	var seq: int = int(_counter.get(card_id, 0)) + 1
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

	# 恢复计数器
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


## 加载单个实例
func _load_one_instance(instance_id: String, inst_data: Dictionary) -> void:
	var card_id: String = String(inst_data.get("card_id", ""))
	if card_id.is_empty():
		return
	var clone: CardResource = DefaultCards.clone_for_instance(card_id)
	if clone == null:
		push_warning("[InstanceRegistry] 加载实例 %s 找不到模板 %s" % [instance_id, card_id])
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
