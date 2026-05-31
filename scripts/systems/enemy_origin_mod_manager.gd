extends Node
## v6.0: 敌源改造（Enemy-Origin MOD）管理器
## 负责：
##   - 管理敌源MOD的解锁状态
##   - 处理敌源MOD装备/卸载
##   - 处理敌源MOD碎片进度
##   - 获取当前有效等级
##
## 依赖：
##   - IntelManual（素材情报进度）
##   - IntelDiscoveryManager（解锁信号）
##   - EnemyOriginMods（MOD定义）
##   - BlueprintManager（装备状态存储）

const EnemyOriginMods = preload("res://data/enemy_origin_mods.gd")
const IntelDimensions = preload("res://data/intel_dimensions.gd")
const GC = preload("res://resources/game_constants.gd")

# ── 信号 ──────────────────────────────────────────────────────────

## 敌源MOD解锁 signal(mod_id)
signal eom_unlocked(mod_id: String)
## 敌源MOD等级提升 signal(mod_id, old_tier, new_tier)
signal eom_tier_upgraded(mod_id: String, old_tier: int, new_tier: int)
## 敌源MOD装备 signal(card_id, mod_id)
signal eom_equipped(card_id: String, mod_id: String)
## 敌源MOD碎片掉落 signal(mod_id, amount, total)
signal eom_fragment_dropped(mod_id: String, amount: int, total: int)

# ── 内部状态 ──────────────────────────────────────────────────────

## 已解锁的敌源MOD: mod_id -> true
var _unlocked: Dictionary = {}

## 敌源MOD碎片进度: mod_id -> int
var _fragments: Dictionary = {}

# ── 生命周期 ──────────────────────────────────────────────────────

func _ready() -> void:
	_load_state()
	## 连接揭示事件信号（情报系统解锁敌源MOD时同步）
	var idm: Node = get_node_or_null("/root/IntelDiscoveryManager")
	if idm and idm.has_signal("eom_unlocked"):
		idm.eom_unlocked.connect(_on_eom_unlocked_from_discovery)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()

# ── 存档 ───────────────────────────────────────────────────────────

const SaveUtils = preload("res://scripts/save_utils.gd")
const STATE_SAVE_NAME: String = "eom_manager_state"

func _save_state() -> void:
	var data: Dictionary = {
		"unlocked": _unlocked.duplicate(),
		"fragments": _fragments.duplicate(),
	}
	SaveUtils.save_data_to_file(data, STATE_SAVE_NAME)

func _load_state() -> void:
	var data: Dictionary = SaveUtils.load_data_from_file(STATE_SAVE_NAME)
	_unlocked = data.get("unlocked", {})
	_fragments = data.get("fragments", {})
	print("[EnemyOriginModManager] 加载完成，已解锁 %d 种敌源MOD" % _unlocked.size())

# ── 解锁 ───────────────────────────────────────────────────────────

## 解锁敌源MOD（从揭示事件触发或手动调用）
func unlock_mod(mod_id: String) -> void:
	if _unlocked.has(mod_id):
		return
	if not EnemyOriginMods.has_mod(mod_id):
		return
	_unlocked[mod_id] = true
	eom_unlocked.emit(mod_id)
	print("[EnemyOriginModManager] 🧬 解锁敌源MOD: %s" % mod_id)
	_save_state()

## 检查敌源MOD是否已解锁
func is_mod_unlocked(mod_id: String) -> bool:
	return _unlocked.has(mod_id)

## 从IntelDiscoveryManager的揭示事件同步解锁
func _on_eom_unlocked_from_discovery(mod_id: String) -> void:
	unlock_mod(mod_id)

# ── 查询 ───────────────────────────────────────────────────────────

## 获取所有已解锁的敌源MOD（含完整定义）
func get_unlocked_mods() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mod_id in _unlocked:
		var mod: Dictionary = EnemyOriginMods.get_mod(mod_id)
		if not mod.is_empty():
			mod = mod.duplicate(true)
			mod["_tier"] = get_effective_tier(mod_id)
			result.append(mod)
	return result

## 获取适合某张卡的所有已解锁敌源MOD
func get_available_mods_for_card(card_id: String) -> Array[Dictionary]:
	var bpm: Node = get_node_or_null("/root/BlueprintManager")
	var combat_kind: int = -1
	if bpm and bpm.has_method("get_combat_kind"):
		combat_kind = bpm.get_combat_kind(card_id)
	if combat_kind < 0:
		## 尝试从DefaultCards获取
		var DC = preload("res://data/default_cards.gd")
		var card = DC.get_card_by_id(card_id) if DC else null
		if card and card.get("combat_kind") != null:
			combat_kind = int(card.combat_kind)
	if combat_kind < 0:
		return []
	## D槽解锁检查：需要任意敌人的素材情报 ≥ 30%
	if not is_slot_unlocked_for_card():
		return []
	var result: Array[Dictionary] = []
	for mod_id in _unlocked:
		if EnemyOriginMods.is_compatible(mod_id, combat_kind):
			var mod: Dictionary = EnemyOriginMods.get_mod(mod_id).duplicate(true)
			mod["_tier"] = get_effective_tier(mod_id)
			result.append(mod)
	return result

## D槽是否已解锁（需要素材情报总进度 ≥ 30%）
func is_slot_unlocked_for_card() -> bool:
	var im: Node = get_node_or_null("/root/IntelManual")
	if im == null:
		return false
	## 检查是否有任何敌人的素材情报达到阈值
	for card_id in im.get_known_card_ids():
		var mat_progress: float = im.get_dimension_progress(card_id, IntelDimensions.DIM_MATERIAL)
		if mat_progress >= GC.ENEMY_ORIGIN_MOD_SLOT_UNLOCK_INTEL:
			return true
	return false

## 获取某张卡当前装备的敌源MOD ID
func get_equipped_eom(card_id: String) -> String:
	var bpm: Node = get_node_or_null("/root/BlueprintManager")
	if bpm and bpm.has("blueprint_enemy_origin_mod"):
		return str(bpm.blueprint_enemy_origin_mod.get(card_id, ""))
	return ""

## 获取敌源MOD当前有效等级
func get_effective_tier(mod_id: String) -> int:
	var mod: Dictionary = EnemyOriginMods.get_mod(mod_id)
	if mod.is_empty():
		return 0
	var enemy_type: String = mod.get("source_enemy_type", "")
	## 查找该敌人类型的素材情报进度
	var im: Node = get_node_or_null("/root/IntelManual")
	if im == null:
		return 0
	## 遍历所有已知敌人，找到匹配类型的最高素材情报
	var best_material_intel: float = 0.0
	for card_id in im.get_known_card_ids():
		var et: String = im.get_enemy_type(card_id)
		if et == enemy_type or et.is_empty():
			var mat: float = im.get_dimension_progress(card_id, IntelDimensions.DIM_MATERIAL)
			best_material_intel = maxf(best_material_intel, mat)
	return EnemyOriginMods.get_effective_tier(mod_id, best_material_intel)

# ── 装备 / 卸载 ──────────────────────────────────────────────────

## 装备敌源MOD到某张卡
func equip_eom(card_id: String, mod_id: String) -> bool:
	if not is_mod_unlocked(mod_id):
		return false
	if not is_slot_unlocked_for_card():
		return false
	var bpm: Node = get_node_or_null("/root/BlueprintManager")
	if bpm == null:
		return false
	if not bpm.blueprint_enemy_origin_mod is Dictionary:
		bpm.blueprint_enemy_origin_mod = {}
	bpm.blueprint_enemy_origin_mod[card_id] = mod_id
	eom_equipped.emit(card_id, mod_id)
	print("[EnemyOriginModManager] 装备敌源MOD: %s → %s" % [mod_id, card_id])
	return true

## 卸载敌源MOD
func unequip_eom(card_id: String) -> void:
	var bpm: Node = get_node_or_null("/root/BlueprintManager")
	if bpm == null:
		return
	if bpm.blueprint_enemy_origin_mod is Dictionary:
		bpm.blueprint_enemy_origin_mod.erase(card_id)
		print("[EnemyOriginModManager] 卸载敌源MOD: %s" % card_id)

# ── 碎片 ───────────────────────────────────────────────────────────

## 添加敌源MOD碎片
func add_fragments(mod_id: String, amount: int) -> int:
	_fragments[mod_id] = int(_fragments.get(mod_id, 0)) + amount
	eom_fragment_dropped.emit(mod_id, amount, int(_fragments[mod_id]))
	_save_state()
	return int(_fragments[mod_id])

## 获取碎片数量
func get_fragments(mod_id: String) -> int:
	return int(_fragments.get(mod_id, 0))

# ── 战力计算辅助 ──────────────────────────────────────────────────

## 获取某张卡敌源MOD的战力加成（用于EvolutionHelpers）
static func calc_eom_power_bonus(card_id: String, bpm_ref: Node) -> float:
	var eom_id: String = ""
	if bpm_ref.blueprint_enemy_origin_mod is Dictionary:
		eom_id = str(bpm_ref.blueprint_enemy_origin_mod.get(card_id, ""))
	if eom_id.is_empty():
		return 0.0
	var mgr: Node = Engine.get_main_loop().root.get_node_or_null("/root/EnemyOriginModManager")
	if mgr == null:
		return 0.0
	var tier: int = mgr.get_effective_tier(eom_id)
	var effects: Dictionary = EnemyOriginMods.get_tier_effects(eom_id, tier)
	if effects.is_empty():
		return 0.0
	## 简化计算：每个效果大约+5-15战力
	return float(effects.size()) * 8.0
