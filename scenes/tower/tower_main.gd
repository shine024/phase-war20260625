extends Control
## 爬塔主场景：管理层间流程、战斗入口、各面板切换

const TowerDefinitions = preload("res://data/tower_definitions.gd")
const TowerClimbManagerScript = preload("res://managers/tower_climb_manager.gd")
const BattleResultDialog = preload("res://scenes/ui/battle_result_dialog.gd")
const StartPanelScene = preload("res://scenes/tower/tower_start_panel.tscn")
const RewardPanelScene = preload("res://scenes/tower/tower_reward_panel.tscn")
const EventPanelScene = preload("res://scenes/tower/tower_event_panel.tscn")
const ResultPanelScene = preload("res://scenes/tower/tower_result_panel.tscn")

# ── 节点引用 ──────────────────────────────────────────────
@onready var battle_container: Control = $BattleContainer
@onready var tower_hud: Control = $TowerHUD
@onready var bottom_bar: Control = $BottomBar
@onready var popup_layer: CanvasLayer = $PopupLayer
@onready var start_overlay: Control = $PopupLayer/StartOverlay
@onready var reward_overlay: Control = $PopupLayer/RewardOverlay
@onready var event_overlay: Control = $PopupLayer/EventOverlay
@onready var result_overlay: Control = $PopupLayer/ResultOverlay
@onready var rest_overlay: Control = $PopupLayer/RestOverlay
@onready var deck_overlay: Control = $PopupLayer/DeckOverlay
@onready var relic_overlay: Control = $PopupLayer/RelicOverlay

var _start_panel: Control = null
var _reward_panel: Control = null
var _event_panel: Control = null
var _result_panel: Control = null
var _phase_field_xp_before_battle: int = 0
var _phase_field_level_before_battle: int = 1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 初始化面板
	_init_panels()

	# 注册到 GameManager（复用战场）
	if GameManager:
		GameManager.set_main_scene(self)
		var bf = _get_battlefield()
		if bf:
			GameManager.set_battle_scene(bf)

	# 连接信号
	if SignalBus:
		SignalBus.tower_state_changed.connect(_on_tower_state_changed)
		SignalBus.tower_floor_changed.connect(_on_tower_floor_changed)
		SignalBus.battle_ended.connect(_on_battle_ended)
		SignalBus.phase_driver_destroyed.connect(_on_phase_driver_destroyed)

	# 初始化战场
	_hide_battle()
	_update_hud()

	# 设置游戏模式
	_set_tower_game_mode(true)

	# 初始化爬塔状态
	var tower_mgr: Node = _get_tower_manager()
	if tower_mgr:
		if tower_mgr.is_active():
			# 断点续玩：Autoload 的信号在连接前已发射，需手动同步
			_on_tower_state_changed(int(tower_mgr.current_state))
			_update_hud()
		else:
			# 新游戏：进入选择起始相位仪
			tower_mgr._set_state(TowerClimbManagerScript.TowerState.SELECT_START)

func _exit_tree() -> void:
	_set_tower_game_mode(false)

func _init_panels() -> void:
	# 实例化各面板
	_start_panel = StartPanelScene.instantiate()
	start_overlay.add_child(_start_panel)
	if _start_panel != null and _start_panel.has_signal("starter_selected"):
		_start_panel.connect("starter_selected", Callable(self, "_on_starter_selected"))
	#endregion

	_reward_panel = RewardPanelScene.instantiate()
	reward_overlay.add_child(_reward_panel)
	if _reward_panel != null and _reward_panel.has_signal("reward_chosen"):
		_reward_panel.connect("reward_chosen", Callable(self, "_on_reward_chosen"))
	if _reward_panel != null and _reward_panel.has_signal("reward_skipped"):
		_reward_panel.connect("reward_skipped", Callable(self, "_on_reward_skipped"))
	#endregion

	var EventPanel = EventPanelScene
	_event_panel = EventPanel.instantiate()
	event_overlay.add_child(_event_panel)
	if _event_panel != null and _event_panel.has_signal("event_choice_made"):
		_event_panel.connect("event_choice_made", Callable(self, "_on_event_choice_made"))

	var ResultPanel = ResultPanelScene
	_result_panel = ResultPanel.instantiate()
	result_overlay.add_child(_result_panel)
	if _result_panel != null and _result_panel.has_signal("run_ended"):
		_result_panel.connect("run_ended", Callable(self, "_on_run_ended"))
	#endregion

# ── 状态机响应 ────────────────────────────────────────────

func _on_tower_state_changed(state: int) -> void:
	var tower_state: int = state
	match tower_state:
		TowerClimbManagerScript.TowerState.IDLE:
			_close_all_overlays()
		TowerClimbManagerScript.TowerState.SELECT_START:
			_close_all_overlays()
			start_overlay.visible = true
			_start_panel.refresh()
		TowerClimbManagerScript.TowerState.PRE_BATTLE:
			_close_all_overlays()
			_hide_battle()
			_update_hud()
		TowerClimbManagerScript.TowerState.BATTLE:
			_close_all_overlays()
			_show_battle()
			_start_floor_battle()
		TowerClimbManagerScript.TowerState.POST_BATTLE:
			_close_all_overlays()
			_handle_post_battle()
		TowerClimbManagerScript.TowerState.REWARD_SELECT:
			_close_all_overlays()
			_show_reward_panel()
		TowerClimbManagerScript.TowerState.EVENT:
			_close_all_overlays()
			_show_event_panel()
		TowerClimbManagerScript.TowerState.REST:
			_close_all_overlays()
			_show_rest_panel()
		TowerClimbManagerScript.TowerState.SHOP:
			_close_all_overlays()
			_show_event_panel()  # 复用事件面板显示商店
		TowerClimbManagerScript.TowerState.GAME_OVER:
			_close_all_overlays()
			_hide_battle()
			_show_result_panel(false)
		TowerClimbManagerScript.TowerState.VICTORY:
			_close_all_overlays()
			_hide_battle()
			_show_result_panel(true)

func _on_tower_floor_changed(_floor_num: int) -> void:
	_update_hud()

# ── 战斗控制 ──────────────────────────────────────────────

func _start_floor_battle() -> void:
	var tower_mgr: Node = _get_tower_manager()
	if not tower_mgr or not tower_mgr.is_active():
		return

	var floor_num: int = int(tower_mgr.get_current_floor())
	var floor_config := TowerDefinitions.get_floor_config(floor_num)
	var floor_type: String = str(floor_config.get("floor_type", "normal"))
	#endregion

	# 非战斗层不启动战斗
	if floor_type in ["rest", "shop", "event"]:
		return

	# 注入塔模式战斗配置到 GameManager
	if GameManager and GameManager.has_method("set_tower_mode"):
		GameManager.set_tower_mode(true, floor_config)

	# 与主界面一致：记录相位场经验基线，战后结算弹窗可显示本局增量
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim and pim.has_method("get_phase_field_xp_progress"):
		var phase_prog: Dictionary = pim.get_phase_field_xp_progress()
		_phase_field_xp_before_battle = int(phase_prog.get("xp", 0))
		_phase_field_level_before_battle = int(phase_prog.get("level", 1))
	# 启动战斗
	if GameManager and GameManager.has_method("go_to_battle"):
		GameManager.go_to_battle()

## 与 Main 对齐：GameManager 战后只认 `show_battle_result`；此处弹出结算并领取 DropManager 待领掉落（含敌方卡）。
func show_battle_result(player_won: bool) -> void:
	var reward_summary: Dictionary = {}
	if GameManager != null and ("last_battle_reward_summary" in GameManager):
		reward_summary = GameManager.last_battle_reward_summary
	BattleResultDialog.create(self, player_won, [], \
		_phase_field_xp_before_battle, _phase_field_level_before_battle, reward_summary)

func _on_result_confirmed() -> void:
	var bf := _get_battlefield()
	if bf:
		var pu = bf.get_node_or_null("PlayerUnits")
		var eu = bf.get_node_or_null("EnemyUnits")
		if pu:
			for c in pu.get_children():
				if c:
					c.queue_free()
		if eu:
			for c in eu.get_children():
				if c:
					c.queue_free()
	if SignalBus:
		BattleInputState.clear_all_pending()
	return_to_preparation()

func _on_battle_ended(player_won: bool) -> void:
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if not tower_mgr or not tower_mgr.is_active():
		return

	# 清除塔模式标记
	if GameManager and GameManager.has_method("set_tower_mode"):
		GameManager.set_tower_mode(false, {})

	if player_won:
		tower_mgr.on_floor_cleared({})
	else:
		tower_mgr.on_floor_failed()

func _on_phase_driver_destroyed() -> void:
	# 相位驱动器被摧毁 = 本局失败
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if tower_mgr and tower_mgr.is_active():
		tower_mgr.on_floor_failed()

# ── 面板回调 ──────────────────────────────────────────────

func _on_starter_selected(loadout_id: String) -> void:
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if tower_mgr:
		tower_mgr.start_new_run(loadout_id)

func _on_reward_chosen(reward: Dictionary) -> void:
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if tower_mgr:
		tower_mgr.apply_reward(reward)
		tower_mgr.advance_to_next_floor()

func _on_reward_skipped() -> void:
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if tower_mgr:
		tower_mgr.skip_reward()

func _on_event_choice_made(effect: Dictionary) -> void:
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if tower_mgr:
		# 扣除事件费用
		if effect.has("cost_gold"):
			tower_mgr.current_run["gold"] = max(0, int(tower_mgr.current_run["gold"]) - int(effect["cost_gold"]))
			if SignalBus:
				SignalBus.tower_gold_changed.emit(int(tower_mgr.current_run["gold"]))
		if effect.has("cost_hp"):
			tower_mgr._heal(-int(effect["cost_hp"]))
		tower_mgr.apply_event_effect(effect.get("effect", effect))

func _on_run_ended(action: String) -> void:
	match action:
		"restart":
			get_tree().reload_current_scene()
		"return_title":
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

# ── 面板显示 ──────────────────────────────────────────────

func _handle_post_battle() -> void:
	var tower_mgr: Node = _get_tower_manager()
	if not tower_mgr:
		return
	var floor_num: int = int(tower_mgr.get_current_floor())
	var floor_type := TowerDefinitions.get_floor_type(floor_num)

	match floor_type:
		"normal", "elite", "boss":
			tower_mgr._set_state(TowerClimbManagerScript.TowerState.REWARD_SELECT)
		"rest":
			tower_mgr._set_state(TowerClimbManagerScript.TowerState.REST)
		"event":
			tower_mgr._set_state(TowerClimbManagerScript.TowerState.EVENT)
		"shop":
			tower_mgr._set_state(TowerClimbManagerScript.TowerState.EVENT)
		_:
			tower_mgr.advance_to_next_floor()

func _show_reward_panel() -> void:
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if not tower_mgr:
		return
	var choices: Array = tower_mgr.generate_reward_choices()
	reward_overlay.visible = true
	if _reward_panel and _reward_panel.has_method("show_rewards"):
		_reward_panel.show_rewards(choices, tower_mgr.get_current_floor())

func _show_event_panel() -> void:
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if not tower_mgr:
		return
	var event: Dictionary = tower_mgr.get_current_event()
	event_overlay.visible = true
	if _event_panel and _event_panel.has_method("show_event"):
		_event_panel.show_event(event, int(tower_mgr.current_run.get("gold", 0)))

func _show_rest_panel() -> void:
	rest_overlay.visible = true
	if rest_overlay.has_node("CenterContainer"):
		var center = rest_overlay.get_node("CenterContainer")
		# 清理旧面板
		for child in center.get_children():
			child.queue_free()
		var panel := _create_rest_panel()
		center.add_child(panel)

func _show_result_panel(victory: bool) -> void:
	result_overlay.visible = true
	if _result_panel and _result_panel.has_method("show_result"):
		var tower_mgr: Node = _get_tower_manager()
		var run_data: Dictionary = tower_mgr.current_run if tower_mgr else {}
		#endregion
		_result_panel.show_result(run_data, victory)

func _create_rest_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.12, 0.10, 0.98)
	sb.border_color = Color(0.0, 0.9, 0.7, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "休息站"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.2, 0.95, 0.7, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "在安全的地方休整，为下一层战斗做准备。"
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0, 0.9, 0.7, 0.25))
	vbox.add_child(sep)

	# 选项 1: 回复生命
	var btn1 := Button.new()
	btn1.text = "休息恢复 (+25 HP)"
	btn1.custom_minimum_size = Vector2(250, 45)
	btn1.add_theme_font_size_override("font_size", 15)
	btn1.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6, 1))
	btn1.pressed.connect(func():
		rest_overlay.visible = false
		var mgr = get_node_or_null("/root/TowerClimbManager")
		if mgr:
			mgr.rest_heal()
			mgr.advance_to_next_floor()
	)
	vbox.add_child(btn1)

	# 选项 2: 提升最大生命
	var btn2 := Button.new()
	btn2.text = "强化工事 (+10 最大HP)"
	btn2.custom_minimum_size = Vector2(250, 45)
	btn2.add_theme_font_size_override("font_size", 15)
	btn2.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 1))
	btn2.pressed.connect(func():
		rest_overlay.visible = false
		var mgr = get_node_or_null("/root/TowerClimbManager")
		if mgr:
			mgr.rest_max_hp_up()
			mgr.advance_to_next_floor()
	)
	vbox.add_child(btn2)

	return panel

# ── 底部栏按钮 ────────────────────────────────────────────

func _on_start_floor_pressed() -> void:
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if tower_mgr and tower_mgr.is_active():
		if tower_mgr.current_state == TowerClimbManagerScript.TowerState.PRE_BATTLE:
			tower_mgr._set_state(TowerClimbManagerScript.TowerState.BATTLE)

func _on_view_deck_pressed() -> void:
	deck_overlay.visible = not deck_overlay.visible

func _on_view_relics_pressed() -> void:
	relic_overlay.visible = not relic_overlay.visible

func _on_abandon_pressed() -> void:
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if tower_mgr and tower_mgr.is_active():
		tower_mgr.abandon_run()
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

# ── 战场控制 ──────────────────────────────────────────────

func _show_battle() -> void:
	if battle_container:
		battle_container.visible = true
		var bf := _get_battlefield()
		if bf:
			if bf.has_method("ensure_phase_driver"):
				bf.ensure_phase_driver()
			# 清理旧单位
			var pu = bf.get_node_or_null("PlayerUnits")
			var eu = bf.get_node_or_null("EnemyUnits")
			if pu:
				for c in pu.get_children():
					c.queue_free()
			if eu:
				for c in eu.get_children():
					c.queue_free()
	if bottom_bar:
		bottom_bar.visible = false

func _hide_battle() -> void:
	if battle_container:
		battle_container.visible = false
	if bottom_bar:
		bottom_bar.visible = true

func _get_battlefield() -> Node2D:
	return get_node_or_null("BattleContainer/SubViewportContainer/SubViewport/Battlefield") as Node2D

func _update_hud() -> void:
	var tower_mgr = get_node_or_null("/root/TowerClimbManager")
	if tower_hud and tower_mgr and tower_hud.has_method("update_display"):
		tower_hud.update_display(
			tower_mgr.get_current_floor(),
			int(tower_mgr.current_run.get("hp", 100)),
			int(tower_mgr.current_run.get("max_hp", 100)),
			int(tower_mgr.current_run.get("gold", 0)),
			int(tower_mgr.current_run.get("score", 0)),
			tower_mgr.current_run.get("relics", []) as Array,
			tower_mgr.is_active()
		)

# ── 工具方法 ──────────────────────────────────────────────

func _close_all_overlays() -> void:
	for overlay in [start_overlay, reward_overlay, event_overlay, result_overlay, rest_overlay, deck_overlay, relic_overlay]:
		if overlay:
			overlay.visible = false

func _set_tower_mode(enabled: bool) -> void:
	if GameManager and GameManager.has_method("set_game_mode_tower"):
		GameManager.set_game_mode_tower(enabled)

func _set_tower_game_mode(enabled: bool) -> void:
	_set_tower_mode(enabled)
	#endregion

func _get_tower_manager() -> Node:
	return get_node_or_null("/root/TowerClimbManager")

func return_to_preparation() -> void:
	_hide_battle()
	if bottom_bar:
		bottom_bar.visible = true
	_update_hud()
