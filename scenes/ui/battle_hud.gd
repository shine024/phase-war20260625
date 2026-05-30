extends CanvasLayer
class_name BattleHUD
## Battle HUD - 战斗界面抬头显示
## 显示：HP条、能量条、我方刷新进度、波次信息、相位仪槽位、单位信息、伤害弹出数字

const DefaultCardsData = preload("res://data/default_cards.gd")

var _tween: Tween
var _wave_timer_tween: Tween

# 注意：TopLeftPanel、TopCenterPanel 和 BottomCenterPanel 已被移除
# 目前不再刷新/显示 TopRightPanel（相位仪槽位），改为完全由底部 `BottomInstrumentBar` 负责
const ENABLE_TOP_RIGHT_PANEL: bool = false

# ── 顶部右侧相位仪槽 ──────────────────────────────────────────
@onready var top_right_panel: PanelContainer = $TopRightPanel
@onready var slot1_panel: PanelContainer = $TopRightPanel/Margin/VBox/Slots/Slot1
@onready var slot2_panel: PanelContainer = $TopRightPanel/Margin/VBox/Slots/Slot2
@onready var slot3_panel: PanelContainer = $TopRightPanel/Margin/VBox/Slots/Slot3
@onready var slot4_panel: PanelContainer = $TopRightPanel/Margin/VBox/Slots/Slot4

# ── 信息显示面板 ────────────────────────────────────────────────
@onready var info_panel: PanelContainer = $InfoPanel
@onready var coins_label: Label = $InfoPanel/Margin/VBox/ResourceInfo/CoinsLabel
@onready var energy_label: Label = $InfoPanel/Margin/VBox/ResourceInfo/EnergyLabel
@onready var wave_label: Label = $InfoPanel/Margin/VBox/WaveInfo
@onready var timer_label: Label = $InfoPanel/Margin/VBox/TimerLabel

# ── 伤害数字层 ────────────────────────────────────────────────
@onready var damage_popup_layer: CanvasLayer = $DamagePopupLayer

# 槽位样式（用于切换有/无卡状态）
var _slot_style_empty: StyleBoxFlat
var _slot_style_filled: StyleBoxFlat

# 战斗 HUD：降低刷新频率，避免每帧统计单位数
var _battle_active: bool = false
var _battle_start_time: float = 0.0
var _hud_refresh_accum: float = 0.0
const HUD_REFRESH_INTERVAL: float = 0.12

func _ready() -> void:
	# TopRightPanel 被禁用：不连接 phase_slots_changed，避免任何刷新逻辑执行
	if ENABLE_TOP_RIGHT_PANEL:
		_cache_slot_styles()
		_connect_signals()
		_update_health(1.0)
		_update_energy(0.5)
		# 仅在启用时播放
		if top_right_panel:
			top_right_panel.visible = true
		_play_intro_animation()
	else:
		# 彻底禁用：即便外部调用了 set_phase_slot/update_phase_slot，也不会产生任何 UI 更新
		if top_right_panel:
			top_right_panel.visible = false
		_connect_signals()
	# 隐藏旧的冗余 HUD（它们在主视口 BattleContainer 中）
	_hide_legacy_huds()

func _hide_legacy_huds() -> void:
	# 延迟执行，确保主场景节点已加载
	await get_tree().process_frame
	# PlayerSpawnHUD 和 EnemySpawnHUD 已集成到 BattleHUD，可以隐藏
	# 注意：它们在主场景，而 BattleHUD 在 SubViewport 内，无法直接访问
	# 通过 SignalBus 通知
	pass

func _cache_slot_styles() -> void:
	# 从 slot1 拿 empty 样式，filled 样式从 tscn sub_resource 中提取
	if slot1_panel:
		_slot_style_empty = slot1_panel.get_theme_stylebox("panel") as StyleBoxFlat

	# 手动构建 filled 样式
	_slot_style_filled = StyleBoxFlat.new()
	_slot_style_filled.bg_color = Color(0.1, 1, 1, 0.15)
	_slot_style_filled.border_width_left   = 2
	_slot_style_filled.border_width_top    = 2
	_slot_style_filled.border_width_right  = 2
	_slot_style_filled.border_width_bottom = 2
	_slot_style_filled.border_color = Color(0, 1, 1, 1)
	_slot_style_filled.corner_radius_top_left     = 6
	_slot_style_filled.corner_radius_top_right    = 6
	_slot_style_filled.corner_radius_bottom_right = 6
	_slot_style_filled.corner_radius_bottom_left  = 6
	_slot_style_filled.shadow_color = Color(0, 1, 1, 0.5)
	_slot_style_filled.shadow_size = 6

func _connect_signals() -> void:
	if not SignalBus:
		return
	if not SignalBus.energy_changed.is_connected(_on_energy_changed):
		SignalBus.energy_changed.connect(_on_energy_changed)
	if not SignalBus.phase_driver_hp_changed.is_connected(_on_phase_driver_hp_changed):
		SignalBus.phase_driver_hp_changed.connect(_on_phase_driver_hp_changed)
	# TopRightPanel 被禁用时：不连接 phase_slots_changed，避免刷新
	if ENABLE_TOP_RIGHT_PANEL:
		if not SignalBus.phase_slots_changed.is_connected(_on_phase_slots_changed):
			SignalBus.phase_slots_changed.connect(_on_phase_slots_changed)
	if not SignalBus.wave_spawned.is_connected(_on_wave_spawned):
		SignalBus.wave_spawned.connect(_on_wave_spawned)
	if not SignalBus.unit_selected.is_connected(_on_unit_selected):
		SignalBus.unit_selected.connect(_on_unit_selected)
	if not SignalBus.unit_damaged.is_connected(_on_unit_damaged):
		SignalBus.unit_damaged.connect(_on_unit_damaged)
	if not SignalBus.battle_started.is_connected(_on_battle_started):
		SignalBus.battle_started.connect(_on_battle_started)
	if not SignalBus.battle_ended.is_connected(_on_battle_ended):
		SignalBus.battle_ended.connect(_on_battle_ended)
	if not SignalBus.unit_spawned.is_connected(_on_unit_spawned):
		SignalBus.unit_spawned.connect(_on_unit_spawned)
	if not SignalBus.unit_died.is_connected(_on_unit_died_hud):
		SignalBus.unit_died.connect(_on_unit_died_hud)

func _process(delta: float) -> void:
	if not _battle_active:
		return
	_hud_refresh_accum += delta
	if _hud_refresh_accum < HUD_REFRESH_INTERVAL:
		return
	_hud_refresh_accum = 0.0
	_update_info_panel(delta)

# ── 信号处理 ──────────────────────────────────────────────────

func _on_energy_changed(current: float, maximum: float) -> void:
	if energy_label:
		energy_label.text = "⚡ %d/%d" % [int(current), int(maximum)]

func _on_phase_driver_hp_changed(current: float, maximum: float) -> void:
	# 现在由 main.tscn 中的独立面板处理
	pass

func _on_phase_slots_changed(slots: Array) -> void:
	if not ENABLE_TOP_RIGHT_PANEL:
		return
	for i in range(4):
		if i < slots.size():
			var card = slots[i]
			if card and card is CardResource:
				var card_name = card.display_name if card.display_name else DefaultCardsData.get_safe_display_name(card.card_id)
				_update_phase_slot(i, card_name, true)
			else:
				_update_phase_slot(i, "", false)
		else:
			_update_phase_slot(i, "", false)

func _on_wave_spawned(wave_index: int) -> void:
	# 现在由 main.tscn 中的独立面板处理
	pass

func _on_unit_selected(unit: Node, _is_player: bool, _at_position: Vector2) -> void:
	# BottomCenterPanel 已被移除，单位信息现在由 UnitInfoPanel（暂停时）显示
	pass

func _on_unit_damaged(unit: Node, _is_player: bool, amount: float, at_position: Vector2) -> void:
	show_damage_popup(amount, at_position, unit)

func _on_battle_started() -> void:
	_battle_active = true
	_battle_start_time = Time.get_ticks_msec() / 1000.0

func _on_battle_ended(_player_won: bool) -> void:
	_battle_active = false

func _on_unit_spawned(_unit: Node, _is_player: bool) -> void:
	pass  # 由 _process 中 BattleManager 轮询统计

func _on_unit_died_hud(_unit: Node, _is_player: bool) -> void:
	pass  # 由 _process 中 BattleManager 轮询统计

## 更新信息面板显示
func _update_info_panel(_delta: float) -> void:
	# 更新战斗时间
	if timer_label and _battle_start_time > 0:
		var elapsed = Time.get_ticks_msec() / 1000.0 - _battle_start_time
		var minutes = int(elapsed / 60)
		var seconds = int(elapsed) % 60
		timer_label.text = "时间: %02d:%02d" % [minutes, seconds]

	# 更新波次信息和单位数
	if BattleManager and wave_label:
		var current_wave = int(BattleManager.get_enemy_wave_index())
		var total_waves = int(BattleManager.get_enemy_wave_total())

		# 获取敌我单位数
		var player_count = 0
		var enemy_count = 0
		if BattleManager.has_method("get_player_unit_count"):
			player_count = BattleManager.get_player_unit_count()
		if BattleManager.has_method("get_enemy_unit_count"):
			enemy_count = BattleManager.get_enemy_unit_count()

		# 显示波次和单位数
		if total_waves > 0:
			wave_label.text = "波次: %d/%d | 敌人:%d 我方:%d" % [current_wave, total_waves, enemy_count, player_count]
		else:
			wave_label.text = "波次: %d | 敌人:%d 我方:%d" % [current_wave, enemy_count, player_count]

		# 关闭底部红字“敌人来袭”提示。
		var warning_label = info_panel.get_node_or_null("Margin/VBox/WaveWarning")
		if warning_label:
			warning_label.visible = false

# ── UI 更新方法 ────────────────────────────────────────────────

func _get_slot_panel(slot_index: int) -> PanelContainer:
	match slot_index:
		0: return slot1_panel
		1: return slot2_panel
		2: return slot3_panel
		3: return slot4_panel
		_: return null

func _update_phase_slot(slot_index: int, card_name: String, is_filled: bool) -> void:
	if not ENABLE_TOP_RIGHT_PANEL:
		return
	var panel: PanelContainer = _get_slot_panel(slot_index)
	if panel == null:
		return
	var lbl: Label = panel.get_child(0) as Label if panel.get_child_count() > 0 else null
	if is_filled and card_name.length() > 0:
		panel.add_theme_stylebox_override("panel", _slot_style_filled)
		if lbl:
			lbl.text = card_name
			lbl.add_theme_color_override("font_color", Color(0, 1, 1, 1))
	else:
		panel.remove_theme_stylebox_override("panel")
		if lbl:
			lbl.text = str(slot_index + 1)
			lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.8))

func _update_health(pct: float) -> void:
	# 现在由 main.tscn 中的独立面板处理
	pass

func _update_energy(pct: float) -> void:
	# 现在由 main.tscn 中的独立面板处理
	pass

func _play_intro_animation() -> void:
	var panels = [
		get_node_or_null("TopRightPanel"),
	]
	for i in range(panels.size()):
		var panel = panels[i]
		if panel:
			panel.modulate.a = 0.0
			var t = create_tween()
			t.tween_property(panel, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)

func _make_danger_panel_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.04, 0.04, 0.95)
	s.border_width_left   = 3
	s.border_width_top    = 3
	s.border_width_right  = 3
	s.border_width_bottom = 3
	s.border_color = Color(1, 0.2, 0.2, 1)
	s.corner_radius_top_left     = 8
	s.corner_radius_top_right    = 8
	s.corner_radius_bottom_right = 8
	s.corner_radius_bottom_left  = 8
	s.shadow_color = Color(1, 0.2, 0.2, 0.5)
	s.shadow_size = 10
	return s

# ── 伤害弹出数字 ──────────────────────────────────────────────

const DamageNumberScript = preload("res://scenes/effects/damage_number_display.gd")

func show_damage_popup(damage: float, world_pos: Vector2, _unit: Node = null) -> void:
	# 使用对象池的 damage_number_display 替代每击创建 Label+Tween
	var parent: Node = null
	if _unit and is_instance_valid(_unit):
		parent = _unit.get_parent()
	if parent == null:
		parent = get_tree().current_scene if get_tree() else null
	if parent == null:
		return

	var dmg_type: String = "normal"
	if damage >= 80:
		dmg_type = "critical"
	elif damage >= 40:
		dmg_type = "normal"

	DamageNumberScript.create_damage_number(parent, world_pos, int(damage), damage >= 80, dmg_type)

# ── 公开 API（兼容旧调用） ────────────────────────────────────

func update_phase_slot(slot_index: int, card_name: String, is_filled: bool) -> void:
	if not ENABLE_TOP_RIGHT_PANEL:
		return
	_update_phase_slot(slot_index, card_name, is_filled)

func update_unit_info(unit_name: String, hp: float, damage: float, speed: float) -> void:
	# BottomCenterPanel 已被移除，单位信息现在由 UnitInfoPanel（暂停时）显示
	pass

func update_wave(wave_num: int) -> void:
	if wave_label:
		wave_label.text = "波次: %d" % int(wave_num)

## 更新金币显示（通过信号调用）
## 更新金币显示（通过信号调用）
func update_coins(amount: int) -> void:
	if coins_label:
		coins_label.text = "💰 %d" % int(amount)

func set_health_percentage(pct: float) -> void:
	# 现在由 main.tscn 中的独立面板处理
	pass

func set_energy_percentage(pct: float) -> void:
	# 现在由 main.tscn 中的独立面板处理
	pass

func set_phase_slot(index: int, card_name: String, filled: bool) -> void:
	if not ENABLE_TOP_RIGHT_PANEL:
		return
	_update_phase_slot(index, card_name, filled)

func set_unit_info(name: String, hp: float, dmg: float, spd: float) -> void:
	# BottomCenterPanel 已被移除，单位信息现在由 UnitInfoPanel（暂停时）显示
	pass

func set_wave(wave_num: int) -> void:
	if wave_label:
		wave_label.text = "波次: %d" % int(wave_num)

## 显示波次预警提示
func _show_wave_warning() -> void:
	if not info_panel:
		return

	# 创建或获取警告标签
	var warning_label = info_panel.get_node_or_null("Margin/VBox/WaveWarning")
	if not warning_label:
		warning_label = Label.new()
		warning_label.name = "WaveWarning"
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		warning_label.add_theme_font_size_override("font_size", 20)
		info_panel.get_node("Margin/VBox").add_child(warning_label)

	warning_label.text = "⚠️ 下一波敌人即将来袭！"
	warning_label.visible = true

	# 3秒后隐藏警告
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func():
		if warning_label and is_instance_valid(warning_label):
			warning_label.visible = false
	)
