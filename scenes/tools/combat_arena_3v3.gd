## 3v3 群战演练场
## 我方 3 单位 vs 敌方 3 单位自动对打（通过 spatial_grid 自动索敌，复用真实战斗逻辑）。
## 比战斗效果检查场(1v1)更像真实混战——能看到群体命中/溅射/多目标弹道/大招弹道。
## 100% 复用项目真实战斗效果：卡图缩放对齐 / bullet 弹道 / 击中特效 / 伤害数字 / 空间分区索敌。
##
## 用法：主菜单 → ⚔ 3v3 群战演练 → 选我方卡 + 敌方 archetype → 切换 → 自动开打。
extends Node2D

const GC := preload("res://resources/game_constants.gd")
const DefaultCards := preload("res://data/default_cards.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const UnitStatsTable := preload("res://resources/unit_stats_table.gd")

const ConstructUnitScene := preload("res://scenes/units/construct_unit.tscn")
const EnemyUnitScene := preload("res://scenes/units/enemy_unit.tscn")

# --- 3v3 布阵坐标 ---
# 我方一列(x=380) + 敌方一列(x=900)，各 3 个单位错落 Y（与真实格子战三行布局一致）
const PLAYER_POS_X := 380.0
const ENEMY_POS_X := 900.0
# 3 个单位的 Y 坐标（上/中/下，与 CardGridBattleLayout 三行布局风格一致）
const ROW_YS := [370.0, 420.0, 470.0]
const UNITS_PER_SIDE := 3

# --- 运行时状态 ---
var _player_units: Array = []  # Array[Node] 我方 3 单位
var _enemy_units: Array = []   # Array[Node] 敌方 3 单位

var _player_card_id: String = ""
var _enemy_archetype_id: String = ""

# 下拉框数据（并行数组）
var _player_ids: Array = []   # String card_id
var _enemy_ids: Array = []    # String archetype_id

# 控制状态
var _player_fire_on: bool = true
var _enemy_fire_on: bool = true

# UI 节点引用
@onready var _player_units_node: Node = $Battlefield/PlayerUnits
@onready var _enemy_units_node: Node = $Battlefield/EnemyUnits
@onready var _player_opt: OptionButton = $UiLayer/PlayerSelectPanel/PlayerOptionButton
@onready var _enemy_opt: OptionButton = $UiLayer/EnemySelectPanel/EnemyOptionButton
@onready var _player_switch_btn: Button = $UiLayer/PlayerSelectPanel/PlayerSwitchButton
@onready var _enemy_switch_btn: Button = $UiLayer/EnemySelectPanel/EnemySwitchButton
@onready var _player_fire_toggle: CheckButton = $UiLayer/ControlPanel/PlayerFireToggle
@onready var _enemy_fire_toggle: CheckButton = $UiLayer/ControlPanel/EnemyFireToggle
@onready var _play_pause_btn: Button = $UiLayer/ControlPanel/PlayPauseButton
@onready var _step_btn: Button = $UiLayer/ControlPanel/StepButton
@onready var _reset_btn: Button = $UiLayer/ControlPanel/ResetButton
@onready var _back_btn: Button = $UiLayer/ControlPanel/BackButton
@onready var _speed_slider: HSlider = $UiLayer/ControlPanel/SpeedSlider
@onready var _speed_label: Label = $UiLayer/ControlPanel/SpeedLabel
@onready var _step_frames_slider: HSlider = $UiLayer/ControlPanel/StepFramesSlider
@onready var _step_frames_label: Label = $UiLayer/ControlPanel/StepFramesLabel
@onready var _info_panel: RichTextLabel = $UiLayer/InfoPanel


func _ready() -> void:
	# 接信号
	_player_switch_btn.pressed.connect(_on_player_switch)
	_enemy_switch_btn.pressed.connect(_on_enemy_switch)
	_player_fire_toggle.toggled.connect(_on_player_fire_toggled)
	_enemy_fire_toggle.toggled.connect(_on_enemy_fire_toggled)
	_play_pause_btn.pressed.connect(_on_play_pause)
	_step_btn.pressed.connect(_on_step)
	_reset_btn.pressed.connect(_on_reset)
	_back_btn.pressed.connect(_on_back)
	_speed_slider.value_changed.connect(_on_speed_changed)
	_step_frames_slider.value_changed.connect(_on_step_frames_changed)

	# 让 BattleManager 进入战斗态（建 spatial_grid + 四个 batch，单位自动索敌+子弹弹道才完整）
	_setup_battle_manager()

	# 填充下拉框
	_populate_player_options()
	_populate_enemy_options()

	# 选默认项并生成单位
	if _player_ids.size() > 0:
		_player_card_id = _player_ids[0]
		_player_opt.select(0)
	if _enemy_ids.size() > 0:
		_enemy_archetype_id = _enemy_ids[0]
		_enemy_opt.select(0)

	_spawn_both()
	set_process(true)


func _exit_tree() -> void:
	# 还原 time_scale，避免影响其他场景
	Engine.time_scale = 1.0
	# 关闭 BattleManager 战斗态（避免它的 _process 继续跑）
	if BattleManager != null:
		BattleManager.battle_active = false


# ============================================================
# BattleManager 就绪：建 spatial_grid + 四个 batch
# ============================================================
func _setup_battle_manager() -> void:
	if BattleManager == null:
		push_error("[Arena3v3] BattleManager autoload 不存在，无法启动")
		return
	BattleManager.battlefield = $Battlefield
	if BattleManager.spatial_grid == null or not is_instance_valid(BattleManager.spatial_grid):
		BattleManager._setup_spatial_grid()
	if BattleManager.player_projectile_batch == null or not is_instance_valid(BattleManager.player_projectile_batch):
		BattleManager._setup_player_projectile_batch()
	if BattleManager.enemy_projectile_batch == null or not is_instance_valid(BattleManager.enemy_projectile_batch):
		BattleManager._setup_enemy_projectile_batch()
	if BattleManager.player_indirect_batch == null or not is_instance_valid(BattleManager.player_indirect_batch):
		BattleManager._setup_player_indirect_batch()
	if BattleManager.enemy_indirect_batch == null or not is_instance_valid(BattleManager.enemy_indirect_batch):
		BattleManager._setup_enemy_indirect_batch()
	BattleManager.battle_active = true


# ============================================================
# 下拉框填充
# ============================================================
func _populate_player_options() -> void:
	_player_opt.clear()
	_player_ids.clear()
	var all_ids: Array = DefaultCards.get_all_blueprint_ids_lightweight()
	for cid in all_ids:
		var card = DefaultCards.get_card_by_id(cid)
		if card == null:
			continue
		if card.card_type != GC.CardType.COMBAT_UNIT:
			continue  # 排除能量卡
		# v16.2: 玩家卡 weapon_type 是新枚举 4 值，查 weapon_mode_short（旧 12 武器表会把 0 错译成"冲锋枪"）
		var wt_name: String = RealWorldUnitLabels.weapon_mode_short(int(card.weapon_type))
		var era_name: String = GC.get_era_name(int(card.era))
		var dname: String = String(card.display_name)
		var display: String
		if not dname.is_empty():
			display = "%s (%s) [%s·%s]" % [dname, cid, era_name, wt_name]
		else:
			display = "%s [%s·%s]" % [cid, era_name, wt_name]
		_player_opt.add_item(display)
		_player_ids.append(cid)
	_sort_option_button(_player_opt, _player_ids)


func _populate_enemy_options() -> void:
	_enemy_opt.clear()
	_enemy_ids.clear()
	var all_ids: Array = EnemyArchetypes.get_all_ids()
	for aid in all_ids:
		var cfg: Dictionary = EnemyArchetypes.get_config(aid)
		var display_name: String = String(cfg.get("display_name", cfg.get("name", "")))
		var wt_name: String = GC.get_weapon_type_name(int(cfg.get("weapon_type", 0)))
		var display: String = "%s  [%s·%s]" % [aid, display_name, wt_name] if not display_name.is_empty() else "%s  [%s]" % [aid, wt_name]
		_enemy_opt.add_item(display)
		_enemy_ids.append(aid)
	_sort_option_button(_enemy_opt, _enemy_ids)


func _sort_option_button(opt: OptionButton, ids: Array) -> void:
	var n: int = opt.item_count
	for i in n - 1:
		var best: int = i
		for j in range(i + 1, n):
			if opt.get_item_text(j) < opt.get_item_text(best):
				best = j
		if best != i:
			var tmp_text: String = opt.get_item_text(i)
			opt.set_item_text(i, opt.get_item_text(best))
			opt.set_item_text(best, tmp_text)
			var tmp_id = ids[i]
			ids[i] = ids[best]
			ids[best] = tmp_id


# ============================================================
# 单位生成（每方 3 个，布阵错落 Y）
# ============================================================
func _spawn_both() -> void:
	_clear_units()
	_spawn_player_side()
	_spawn_enemy_side()
	_apply_fire_toggles()


func _spawn_player_side() -> void:
	if _player_card_id.is_empty():
		return
	var card = DefaultCards.get_card_by_id(_player_card_id)
	if card == null:
		push_error("[Arena3v3] 找不到我方卡牌: %s" % _player_card_id)
		return
	var card_clone = card.clone()  # 模板只读，用 clone 构建 stats（养成隔离铁律）
	var stats = UnitStatsTable.build_stats_from_card(card_clone)
	# 射程过大时拉近 X，保证在射程内（与 combat_check 同逻辑）
	var px: float = PLAYER_POS_X
	var max_range: float = float(stats.attack_range) if stats != null else 300.0
	var spacing: float = ENEMY_POS_X - PLAYER_POS_X
	if max_range > spacing:
		px = ENEMY_POS_X - max_range - 60.0
		px = clampf(px, 60.0, PLAYER_POS_X)
	for i in range(UNITS_PER_SIDE):
		var u = ConstructUnitScene.instantiate()
		_player_units_node.add_child(u)
		var s = UnitStatsTable.build_stats_from_card(card.clone())  # 每个单位独立 stats 实例
		u.setup(true, s)  # is_player=true
		u.global_position = Vector2(px, ROW_YS[i])
		if u.has_method("apply_card_grid_combat_started"):
			u.apply_card_grid_combat_started()
		# 注册到空间分区——单位的 _find_target 会通过它自动找最近敌人
		if BattleManager != null and BattleManager.spatial_grid != null:
			BattleManager.spatial_grid.insert(u)
		_player_units.append(u)


func _spawn_enemy_side() -> void:
	if _enemy_archetype_id.is_empty():
		return
	for i in range(UNITS_PER_SIDE):
		var e = EnemyUnitScene.instantiate()
		_enemy_units_node.add_child(e)
		e.setup(false, 1, _enemy_archetype_id)  # wave=1 不受难度缩放干扰
		e.global_position = Vector2(ENEMY_POS_X, ROW_YS[i])
		if e.has_method("apply_card_grid_enemy_presentation"):
			e.apply_card_grid_enemy_presentation()
		# 注册到空间分区
		if BattleManager != null and BattleManager.spatial_grid != null:
			BattleManager.spatial_grid.insert(e)
		_enemy_units.append(e)


func _clear_units() -> void:
	for u in _player_units:
		if u != null and is_instance_valid(u):
			u.queue_free()
	_player_units.clear()
	for e in _enemy_units:
		if e != null and is_instance_valid(e):
			e.queue_free()
	_enemy_units.clear()


# ============================================================
# 攻击控制
# ============================================================
func _apply_fire_toggles() -> void:
	for u in _player_units:
		if u != null and is_instance_valid(u):
			u.set_physics_process(_player_fire_on)
	for e in _enemy_units:
		if e != null and is_instance_valid(e):
			e.set_physics_process(_enemy_fire_on)


func _on_player_fire_toggled(pressed: bool) -> void:
	_player_fire_on = pressed
	_apply_fire_toggles()


func _on_enemy_fire_toggled(pressed: bool) -> void:
	_enemy_fire_on = pressed
	_apply_fire_toggles()


func _on_play_pause() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var now_paused: bool = tree.paused
	tree.paused = not now_paused
	_play_pause_btn.text = "▶ 播放" if tree.paused else "⏸ 暂停"


func _on_step() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = true
	_play_pause_btn.text = "▶ 播放"
	var frames: int = int(_step_frames_slider.value)
	for _i in frames:
		await get_tree().physics_frame
	tree.paused = true


func _on_speed_changed(value: float) -> void:
	Engine.time_scale = value
	_speed_label.text = "速度: %.1fx" % value


func _on_step_frames_changed(value: float) -> void:
	_step_frames_label.text = "步进帧数: %d" % int(value)


# ============================================================
# 切换 / 重置 / 返回
# ============================================================
func _on_player_switch() -> void:
	var idx: int = _player_opt.selected
	if idx < 0 or idx >= _player_ids.size():
		return
	var new_id: String = _player_ids[idx]
	if new_id == _player_card_id:
		return
	_player_card_id = new_id
	# 只重生我方，敌方保留
	for u in _player_units:
		if u != null and is_instance_valid(u):
			u.queue_free()
	_player_units.clear()
	_spawn_player_side()
	_apply_fire_toggles()


func _on_enemy_switch() -> void:
	var idx: int = _enemy_opt.selected
	if idx < 0 or idx >= _enemy_ids.size():
		return
	var new_id: String = _enemy_ids[idx]
	if new_id == _enemy_archetype_id:
		return
	_enemy_archetype_id = new_id
	for e in _enemy_units:
		if e != null and is_instance_valid(e):
			e.queue_free()
	_enemy_units.clear()
	_spawn_enemy_side()
	_apply_fire_toggles()


func _on_reset() -> void:
	Engine.time_scale = 1.0
	_speed_slider.value = 1.0
	_speed_label.text = "速度: 1.0x"
	get_tree().paused = false
	_play_pause_btn.text = "⏸ 暂停"
	_spawn_both()


func _on_back() -> void:
	Engine.time_scale = 1.0
	if BattleManager != null:
		BattleManager.battle_active = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


# ============================================================
# InfoPanel：实时显示双方 3 单位数据
# ============================================================
func _process(_delta: float) -> void:
	_refresh_info_panel()


func _refresh_info_panel() -> void:
	if _info_panel == null:
		return
	var p_text: String = _describe_side(_player_units, true, _player_card_id)
	var e_text: String = _describe_side(_enemy_units, false, _enemy_archetype_id)
	var tree := get_tree()
	var paused_str: String = "暂停" if (tree != null and tree.paused) else "运行"
	var extra: String = "\n[color=#888][状态] %s | 速度 %.1fx | 我方开火 %s | 敌方开火 %s[/color]" % [
		paused_str, Engine.time_scale,
		"ON" if _player_fire_on else "OFF",
		"ON" if _enemy_fire_on else "OFF"
	]
	_info_panel.text = "[color=#3ce66c]【我方 ×%d】[/color]\n%s\n[color=#f06666]【敌方 ×%d】[/color]\n%s%s" % [
		_player_units.size(), p_text, _enemy_units.size(), e_text, extra]


func _describe_side(units: Array, is_player: bool, id_label: String) -> String:
	if units.is_empty():
		return "(未生成)"
	var lines: Array = []
	# 阵营标识行
	if is_player:
		var card = DefaultCards.get_card_by_id(id_label)
		var dname: String = String(card.display_name) if card != null else ""
		lines.append("卡: %s%s" % [dname + " " if not dname.is_empty() else "", id_label])
	else:
		var cfg: Dictionary = EnemyArchetypes.get_config(id_label)
		var dname: String = String(cfg.get("display_name", cfg.get("name", "")))
		lines.append("敌: %s%s" % [dname + " " if not dname.is_empty() else "", id_label])
	# 每个单位一行（血量为主，武器类型在标识行已知）
	for i in range(units.size()):
		var u = units[i]
		if u == null or not is_instance_valid(u):
			lines.append("  [%d] 已阵亡" % (i + 1))
			continue
		var hp: float = float(u.hp)
		var mhp: float = float(u.max_hp) if "max_hp" in u else hp
		var hp_pct: float = hp / mhp * 100.0 if mhp > 0.0 else 0.0
		# 血量颜色：<30% 红，<70% 黄，否则绿
		var hp_color: String = "#f06666" if hp_pct < 30.0 else ("#f0c66c" if hp_pct < 70.0 else "#3ce66c")
		lines.append("  [%d] [color=%s]HP %.0f/%.0f (%.0f%%)[/color]" % [i + 1, hp_color, hp, mhp, hp_pct])
	return "\n".join(lines)
