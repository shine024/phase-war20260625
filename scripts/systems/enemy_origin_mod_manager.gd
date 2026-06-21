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
	# v6.6: 移除自加载，由 SaveManager 统一加载（避免与统一存档重复加载/覆盖）
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

## v6.6: 统一存档接口（供 SaveManager 调用，约定接口名 save_state/load_state）
func save_state() -> Dictionary:
	return {
		"unlocked": _unlocked.duplicate(),
		"fragments": _fragments.duplicate(),
	}

## v6.6: 统一存档加载接口。data 为空时尝试兼容读取旧独立文件，再不行则保持默认空状态
func load_state(data: Dictionary) -> void:
	if data.is_empty():
		# 向后兼容：首次从独立文件迁移时读取旧存档
		var legacy: Dictionary = SaveUtils.load_data_from_file(STATE_SAVE_NAME)
		if not legacy.is_empty():
			_unlocked = legacy.get("unlocked", {})
			_fragments = legacy.get("fragments", {})
		return
	_unlocked = data.get("unlocked", {})
	_fragments = data.get("fragments", {})

## 退出时写入独立文件（双保险，SaveManager 已统一保存）
func _save_state() -> void:
	SaveUtils.save_data_to_file(save_state(), STATE_SAVE_NAME)

## 兼容旧调用（部分内部逻辑仍调用 _load_state）
func _load_state() -> void:
	var legacy: Dictionary = SaveUtils.load_data_from_file(STATE_SAVE_NAME)
	load_state(legacy)

## v6.6: 新游戏重置——清空所有字段，不读旧文件（区别于 load_state({}) 的兼容读取）
func reset_progress() -> void:
	_unlocked.clear()
	_fragments.clear()

# ── 解锁 ───────────────────────────────────────────────────────────

## 解锁敌源MOD（从揭示事件触发或手动调用）
func unlock_mod(mod_id: String) -> void:
	if _unlocked.has(mod_id):
		return
	if not EnemyOriginMods.has_mod(mod_id):
		return
	_unlocked[mod_id] = true
	eom_unlocked.emit(mod_id)
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
	if bpm and bpm.blueprint_enemy_origin_mod is Dictionary:
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
	return true

## 卸载敌源MOD
func unequip_eom(card_id: String) -> void:
	var bpm: Node = get_node_or_null("/root/BlueprintManager")
	if bpm == null:
		return
	if bpm.blueprint_enemy_origin_mod is Dictionary:
		bpm.blueprint_enemy_origin_mod.erase(card_id)

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

# ── 战斗效果应用 ──────────────────────────────────────────────────

## 将某张卡装备的敌源MOD效果应用到 UnitStats
## 在 battle_spawn_system._compute_unit_stats() 的符文应用之后调用
## 返回 true 表示已应用（有 EOM 装备且生效）
func apply_eom_to_stats(card_id: String, stats: Resource) -> bool:
	var eom_id: String = get_equipped_eom(card_id)
	if eom_id.is_empty():
		return false
	if not _unlocked.has(eom_id):
		return false
	var tier: int = get_effective_tier(eom_id)
	if tier <= 0:
		return false
	var effects: Dictionary = EnemyOriginMods.get_tier_effects(eom_id, tier)
	if effects.is_empty():
		return false
	## 数值型效果直接映射到 UnitStats 字段
	# 生命值（固定值）
	if effects.has("hp_flat"):
		stats.max_hp += float(effects["hp_flat"])
	# 防御百分比（映射到 defense）
	if effects.has("defense_pct"):
		stats.defense += float(effects["defense_pct"]) * 50.0  ## defense 参与格子减伤 def/(def+50)，0.1→+5 def
	# 装甲百分比（映射到三个防御维度）
	if effects.has("armor_pct"):
		var armor_mult: float = 1.0 + float(effects["armor_pct"])
		stats.defense_light *= armor_mult
		stats.defense_armor *= armor_mult
		stats.defense_air *= armor_mult
	# 火焰抗性 / 爆炸抗性 / 伤害减免（统一映射到 damage_reduction）
	if effects.has("fire_resist"):
		stats.damage_reduction = clampf(stats.damage_reduction + float(effects["fire_resist"]) * 0.5, 0.0, 0.8)
	if effects.has("explosion_resist"):
		stats.damage_reduction = clampf(stats.damage_reduction + float(effects["explosion_resist"]) * 0.5, 0.0, 0.8)
	# 生命恢复（百分比 → 每秒回血率）
	if effects.has("hp_regen_pct"):
		stats.hp_regen += float(effects["hp_regen_pct"])
	# 命中率
	if effects.has("accuracy_pct"):
		stats.faction_accuracy_bonus = clampf(stats.faction_accuracy_bonus + float(effects["accuracy_pct"]), 0.0, 1.0)
	# 暴击
	if effects.has("crit_bonus"):
		stats.crit_chance = clampf(stats.crit_chance + float(effects["crit_bonus"]), 0.0, 0.95)
	# 闪避
	if effects.has("dodge_pct"):
		stats.dodge_chance = clampf(stats.dodge_chance + float(effects["dodge_pct"]), 0.0, 0.75)
	# 攻击速度
	if effects.has("attack_speed_pct"):
		var speed_mult: float = 1.0 + float(effects["attack_speed_pct"])
		stats.attack_light_speed *= speed_mult
		stats.attack_armor_speed *= speed_mult
		stats.attack_air_speed *= speed_mult
		stats.attack_interval /= speed_mult
	# 射程（格子数 → 像素，每格约 64px）
	if effects.has("range_flat"):
		stats.attack_range += float(effects["range_flat"]) * 64.0
	## 特殊型效果写入 meta，供运行时消费方读取
	var specials: Dictionary = {}
	for key in ["cover_bonus", "reflect_fire", "reflect_proj", "entrenchment", "fire_immunity",
				"adaptive_armor", "precision_strike", "cloak_deploy", "first_strike_bonus",
				"enemy_accuracy_penalty", "dive_bonus", "evasive_manuver", "revive_chance",
				"nano_surge", "resurrect_full", "vision_range", "recon_bonus_pct",
				"enemy_speed_penalty", "mark_target", "ally_damage_pct", "ally_speed_pct",
				"morale_boost", "formation_bonus"]:
		if effects.has(key):
			specials[key] = effects[key]
	if not specials.is_empty():
		var existing: Array = stats.get_meta("eom_specials", []) as Array
		existing.append({"mod_id": eom_id, "tier": tier, "effects": specials})
		stats.set_meta("eom_specials", existing)
	return true

## 结算战斗掉落的 EOM 碎片：写入计数，碎片满额时自动解锁
## 由 IntelDiscoveryManager.generate_battle_intel_harvest 调用
## eom_drops: [{"type":"eom_fragment", "mod_id":..., "count":1}, ...]
func settle_battle_eom_drops(eom_drops: Array) -> Dictionary:
	var unlocked_now: Array = []
	var fragments_gained: Dictionary = {}
	const FRAGMENTS_TO_UNLOCK: int = 5  ## 碎片集齐5个自动解锁
	for drop in eom_drops:
		if not drop is Dictionary:
			continue
		var mod_id: String = drop.get("mod_id", "")
		if mod_id.is_empty() or not EnemyOriginMods.has_mod(mod_id):
			continue
		var count: int = int(drop.get("count", 1))
		var total: int = add_fragments(mod_id, count)
		fragments_gained[mod_id] = total
		## 碎片满额且未解锁 → 自动解锁
		if total >= FRAGMENTS_TO_UNLOCK and not _unlocked.has(mod_id):
			unlock_mod(mod_id)
			unlocked_now.append(mod_id)
	return {"fragments_gained": fragments_gained, "unlocked_now": unlocked_now}
