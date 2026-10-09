extends Node2D
## _tmp 实机对射探针：omega(真实玩家乘区) vs 三档 WWI 敌
## 完全复刻 combat_check 的 spawn 逻辑，连 unit_damaged 记录每发真实扣血。

const GC := preload("res://resources/game_constants.gd")
const DefaultCards := preload("res://data/default_cards.gd")
const UnitStatsTable := preload("res://resources/unit_stats_table.gd")
const ConstructUnitScene := preload("res://scenes/units/construct_unit.tscn")
const EnemyUnitScene := preload("res://scenes/units/enemy_unit.tscn")

const ENEMY_LIST: Array = ["ww1_inf_rifle", "ww1_arm_rolls_mk2", "ww1_fort_pillbox", "ww1_boss_av7"]
const ROUND_SEC := 6.0

var _player_unit: Node = null
var _enemy_unit: Node = null
var _idx := 0
var _hits: Array = []
var _done := false

func _ready() -> void:
	SignalBus.unit_damaged.connect(_on_dmg)
	# 后台异步跑完整个流程后退出
	_run_all()

func _run_all() -> void:
	# 先复现玩家乘区(探针 v2 同款):技能树+符文
	var f = FileAccess.open("C:/Users/jianchang.tan/AppData/Roaming/Godot/app_userdata/phase-war/save_slot_1.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var PMSM = load("res://managers/phase_master_skill_manager.gd").new()
	PMSM._unlocked_nodes = data.get("phase_master_skill", {}).get("unlocked_nodes", [])
	var sb: Dictionary = PMSM.get_active_effects().get("stat_bonus", {})
	var BSS = load("res://managers/battle/battle_spawn_system.gd").new()
	var card = DefaultCards.get_card_by_id("fut_arm_omega").clone()
	var stats = UnitStatsTable.build_stats_from_card(card)
	BSS._apply_active_faction_stat_bonus(stats, sb)
	# 符文(玩家真实装备:attack+0.83/hp+0.38/crit+0.15)
	var PIM = load("res://managers/phase_instrument_manager.gd").new()
	PIM._rune_slots = data.get("phase_instrument", {}).get("rune_state", {}).get("rune_slots", [])
	var rb: Dictionary = PIM.get_rune_bonus()
	if not rb.is_empty() and rb.has("stats"):
		BSS._apply_rune_bonus_to_stats(stats, rb)
	print("[PROBE] omega atk_l=%.0f atk_a=%.0f slot0=%.0f slot1=%.0f (悬停HUD显示 maxf=%.0f)" % [
		stats.attack_light, stats.attack_armor, stats.weapon_slots[0].damage, stats.weapon_slots[1].damage,
		maxf(stats.attack_light, maxf(stats.attack_armor, stats.attack_air))])

	for eid in ENEMY_LIST:
		_hits.clear()
		_spawn_pair(eid, stats)
		await get_tree().create_timer(ROUND_SEC).timeout
		var total := 0.0
		for h in _hits:
			total += float(h)
		var avg := total / maxf(1.0, float(_hits.size()))
		var e_hp: float = float(_enemy_unit.hp) if _enemy_unit != null and is_instance_valid(_enemy_unit) else -1.0
		print("[PROBE] vs %s: 命中 %d 发, 单发 avg=%.0f min=%.0f max=%.0f, 总扣=%.0f, 敌余血=%.0f" % [
			eid, _hits.size(), avg, _hits.min() if _hits.size() > 0 else 0.0, _hits.max() if _hits.size() > 0 else 0.0, total, e_hp])
		_cleanup_pair()
	_done = true
	print("[PROBE] ALL DONE")

func _spawn_pair(eid: String, player_stats) -> void:
	_cleanup_pair()
	var u = ConstructUnitScene.instantiate()
	$Battlefield/PlayerUnits.add_child(u)
	u.setup(true, player_stats)
	u.global_position = Vector2(380.0, 420.0)
	if u.has_method("apply_card_grid_combat_started"):
		u.apply_card_grid_combat_started()
	_player_unit = u
	var e = EnemyUnitScene.instantiate()
	$Battlefield/EnemyUnits.add_child(e)
	e.setup(false, 1, eid)
	e.global_position = Vector2(900.0, 420.0)
	if e.has_method("apply_card_grid_enemy_presentation"):
		e.apply_card_grid_enemy_presentation()
	_enemy_unit = e
	u.target = e
	e.target = u
	# 敌方只挨打不还手(避免玩家单位被秒)
	e.set_physics_process(false)
	# 诊断:目标 kind 与实际选中的武器槽
	var ts = e.get("stats")
	var tk: int = int(ts.combat_kind) if ts != null else -99
	var w = load("res://scripts/battle/attack_calculator.gd").get_weapon_for_target(player_stats, tk)
	var w_idx := -1
	for i in range(player_stats.weapon_slots.size()):
		if player_stats.weapon_slots[i] == w:
			w_idx = i
	print("[PROBE] %s: target_kind=%d def=%.0f hp=%.0f → 选中 slot[%d] dmg=%.0f" % [
		eid, tk, float(ts.defense) if ts != null else -1.0, float(e.hp), w_idx,
		float(w.damage) if w != null else -1.0])
	# 诊断:敌方 stats 全减伤字段 dump + 手动单发复现
	if ts != null:
		print("[PROBE]   敌 stats: def_l/a/air=%.0f/%.0f/%.0f dmg_red=%.2f node_dmg_red=%.2f dodge=%.2f urban=%.2f armor_pen_atk=%.2f" % [
			float(ts.defense_light), float(ts.defense_armor), float(ts.defense_air),
			float(ts.damage_reduction), float(e.get("damage_reduction") if e.get("damage_reduction") != null else 0.0),
			float(ts.dodge_chance), float(ts.urban_defense_bonus),
			float(player_stats.armor_penetration)])
		var AC2 = load("res://scripts/battle/attack_calculator.gd")
		var dim: int = AC2.attack_dim_for_target(player_stats, tk)
		print("[PROBE]   attack_dim_for_target(omega, kind=%d) = %d (1=ARMOR维)" % [tk, dim])
		# 直接种一发了结:手动 take_damage 全额
		var before: float = float(e.hp)
		e.take_damage(float(w.damage), u)
		var loss: float = before - float(e.hp)
		print("[PROBE]   手动 take_damage(%.0f) → 实扣 %.0f (×%.3f)" % [float(w.damage), loss, loss / maxf(1.0, float(w.damage))])

func _cleanup_pair() -> void:
	if _player_unit != null and is_instance_valid(_player_unit):
		_player_unit.queue_free()
	if _enemy_unit != null and is_instance_valid(_enemy_unit):
		_enemy_unit.queue_free()
	_player_unit = null
	_enemy_unit = null

func _on_dmg(_unit: Node, is_player: bool, amount: float, _pos: Vector2) -> void:
	# is_player=true 表示玩家单位受击;这里只记录敌方被扣的血
	if not is_player:
		_hits.append(amount)
