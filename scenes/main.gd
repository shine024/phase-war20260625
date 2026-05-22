extends Control
## 主界面：战前准备 ↔ 战斗 ↔ 战后结算
## 新布局：BattleContainer(上) + HudLayer(CanvasLayer 40：顶部状态栏/资源信息/底部统一栏) + PopupLayer(100 弹窗)
## 弹出面板由 PopupLayer 管理；常驻 HUD 在独立 CanvasLayer，避免与战场 Control 树顺序导致的遮挡错乱

## 播放音效（Autoload AudioManager；get_node_or_null 兜底）
func _play_sfx(name: String) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(name)

const ActiveLawEffects = preload("res://managers/active_law_effects.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const BattleResultDialog = preload("res://scenes/ui/battle_result_dialog.gd")
const ToastUtils = preload("res://scripts/toast_utils.gd")
const CardEnhancementPanelScene = preload("res://scenes/ui/card_enhancement_panel.tscn")
const DEBUG_MAIN_LOG := false
const DEBUG_LOG_PATH := "debug-22f19e.log"

var _blueprints_unlocked_this_battle: Array = []
var _phase_field_xp_before_battle: int = 0
var _phase_field_level_before_battle: int = 1
var _deploy_toast: ToastUtils = null
var _save_toast: ToastUtils = null

func _debug_log(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	var payload := {
		"sessionId": "22f19e",
		"runId": "initial",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000
	}
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(DEBUG_LOG_PATH) else FileAccess.WRITE_READ
	var f := FileAccess.open(DEBUG_LOG_PATH, mode)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()

#region agent log
func _agent_log(hypothesis_id: String, message: String, data: Dictionary) -> void:
	var f := FileAccess.open("debug-1776fa.log", FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	var payload := {
		"sessionId": "1776fa",
		"runId": "law_bullet_debug_v1",
		"hypothesisId": hypothesis_id,
		"location": "Main.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion


#region agent log
func _agent_log_67fe53(hypothesis_id: String, location: String, message: String, data: Dictionary = {}, run_id: String = "run1") -> void:
	var payload := {
		"sessionId": "67fe53",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000
	}
	var f := FileAccess.open("debug-67fe53.log", FileAccess.READ_WRITE if FileAccess.file_exists("debug-67fe53.log") else FileAccess.WRITE_READ)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion


# ── 节点引用 ──────────────────────────────────────────────────
@onready var battle_container: Control            = $BattleContainer
@onready var bottom_instrument_bar                = $HudLayer/BattleBottomBar/BottomInstrumentBar
@onready var bottom_function_bar                 = $HudLayer/BattleBottomBar/BottomFunctionBar
@onready var popup_layer: CanvasLayer            = $PopupLayer

# Overlays（在 PopupLayer 下）
@onready var quest_overlay: Control              = $PopupLayer/QuestOverlay
@onready var store_overlay: Control              = $PopupLayer/StoreOverlay
@onready var phase_law_overlay: Control          = $PopupLayer/PhaseLawOverlay
@onready var backpack_overlay: Control           = $PopupLayer/BackpackOverlay
@onready var faction_overlay: Control            = $PopupLayer/FactionOverlay
@onready var map_overlay: Control                = $PopupLayer/MapOverlay
@onready var settings_overlay: Control           = $PopupLayer/SettingsOverlay
@onready var leaderboard_panel: PopupPanel       = $PopupLayer/LeaderboardPanel
@onready var manufacture_overlay: Control      = $PopupLayer/ManufactureOverlay
@onready var intelligence_overlay: Control     = $PopupLayer/IntelligenceOverlay
@onready var level_display: Label = $HudLayer/TopCenterMeta/LevelDisplay

func _ready() -> void:
	#region agent log
	_agent_log_67fe53("H3", "main.gd:_ready", "main ready entered", {
		"self_path": str(get_path()),
		"scene_file_path": str(scene_file_path),
		"has_popup_layer": has_node("PopupLayer"),
		"has_manufacture_overlay": has_node("PopupLayer/ManufactureOverlay"),
		"has_center_container": has_node("PopupLayer/ManufactureOverlay/CenterContainer")
	})
	#endregion
	if DEBUG_MAIN_LOG:
		print("[Main] _ready() 被调用，主界面初始化开始")
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 连接底部仪表栏信号
	if DEBUG_MAIN_LOG:
		print("[Main] 底部仪表栏检查: %s" % ("存在" if bottom_instrument_bar != null else "不存在"))
	if bottom_instrument_bar:
		if DEBUG_MAIN_LOG:
			print("[Main] 连接底部仪表栏信号...")
		bottom_instrument_bar.instrument_area_clicked.connect(_on_instrument_area_clicked)
		bottom_instrument_bar.law_area_clicked.connect(_on_law_area_clicked)
		bottom_instrument_bar.law_slot_clicked.connect(_on_law_slot_clicked)
		bottom_instrument_bar.phase_level_label_clicked.connect(_on_phase_level_label_clicked)

	# 连接底部功能键栏信号
	if bottom_function_bar:
		bottom_function_bar.btn_backpack_pressed.connect(_on_backpack_pressed)
		bottom_function_bar.btn_progression_pressed.connect(_on_progression_pressed)
		bottom_function_bar.btn_faction_pressed.connect(_on_faction_pressed)
		bottom_function_bar.btn_quest_pressed.connect(_on_quest_pressed)
		bottom_function_bar.btn_store_pressed.connect(_on_store_pressed)
		bottom_function_bar.btn_leaderboard_pressed.connect(_on_leaderboard_pressed)
		bottom_function_bar.btn_info_pressed.connect(_on_info_pressed)
		bottom_function_bar.btn_map_pressed.connect(_on_map_pressed)
		bottom_function_bar.btn_settings_pressed.connect(_on_settings_pressed)
		bottom_function_bar.btn_save_pressed.connect(_on_manual_save_pressed)
		bottom_function_bar.btn_start_battle_pressed.connect(_on_start_battle)
		bottom_function_bar.btn_pause_pressed.connect(_on_pause_pressed)
		bottom_function_bar.btn_back_pressed.connect(_on_back_to_title)

	# 连接各面板 closed 信号
	_connect_panel_closed_signals()
	_connect_intelligence_hub_signals()

	# 注册到 GameManager
	if GameManager:
		GameManager.set_main_scene(self)
		var bf = _get_battlefield()
		if bf:
			GameManager.set_battle_scene(bf)
		if GameManager.has_signal("current_level_changed"):
			GameManager.current_level_changed.connect(_on_current_level_changed)

	_update_level_display()

	if SignalBus:
		SignalBus.blueprint_unlocked.connect(_on_blueprint_unlocked)
		SignalBus.active_law_cast_at.connect(_on_active_law_cast_at)
		SignalBus.battle_ended.connect(_on_battle_ended_clear_pending)
		SignalBus.player_deploy_failed.connect(_on_player_deploy_failed)

	# 全局 UI 贴图：关闭按钮等（依赖 PopupLayer 子树已实例化）
	call_deferred("_apply_global_ui_textures")
	# 非关键初始化延后，降低主界面首帧压力
	call_deferred("_deferred_non_critical_init")
	# 启动后释放预置面板实例，转按需加载，减少常驻开销
	call_deferred("_prune_preloaded_panels")
	# 记录主界面 TTI
	call_deferred("_mark_main_interactive")

func _apply_global_ui_textures() -> void:
	if popup_layer:
		UiAssetLoader.apply_close_icons_recursive(popup_layer)


func _deferred_non_critical_init() -> void:
	# 注册新的游戏系统管理器
	_setup_new_managers()
	# 集成新系统
	_integrate_new_systems()
	# 启动新手教程（如果是新游戏）
	_start_tutorial_if_needed()
	# 初始化日常任务
	_init_daily_tasks()
	# 空闲期预加载高频弹窗，降低首次打开卡顿
	_preload_common_panels()
	# 连接蓝图升星信号，用于刷新词条面板
	if BlueprintManager and BlueprintManager.has_signal("blueprint_star_upgraded") and not BlueprintManager.blueprint_star_upgraded.is_connected(_on_blueprint_star_upgraded):
		BlueprintManager.blueprint_star_upgraded.connect(_on_blueprint_star_upgraded)

func _preload_common_panels() -> void:
	var panel_paths: Array[String] = [
		"res://scenes/ui/backpack_panel.tscn",
		"res://scenes/ui/phase_law_panel.tscn",
		"res://scenes/ui/quest_panel.tscn",
	]
	for path in panel_paths:
		if ResourceLoader.has_cached(path):
			continue
		ResourceLoader.load_threaded_request(path)

func _mark_main_interactive() -> void:
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("mark_main_interactive"):
		PerformanceMetricsManager.mark_main_interactive()

func _prune_preloaded_panels() -> void:
	var overlay_to_container_path := {
		"backpack": "BackpackVBox/CenterRow/BackpackCenter",
		"progression": "CenterContainer",
		"quest": "CenterContainer",
		"store": "CenterContainer",
		"phase_law": "CenterContainer",
		"faction": "CenterContainer",
		"settings": "CenterContainer",
	}
	for panel_id in overlay_to_container_path:
		var overlay := _overlay_for_panel_key(panel_id)
		if overlay == null:
			continue
		var container: Node = overlay.get_node_or_null(String(overlay_to_container_path[panel_id]))
		if container == null:
			continue
		for child in container.get_children():
			if child is Control and (String(child.name).findn("panel") >= 0 or child.has_signal("closed")):
				# #region agent log
				_debug_log("H3", "Main.gd:_prune_preloaded_panels", "pruning preloaded panel child", {
					"panel_id": panel_id,
					"overlay": overlay.name,
					"child_name": child.name
				})
				# #endregion
				child.queue_free()

func _update_level_display() -> void:
	if level_display == null:
		return
	var level = 1
	if GameManager and "current_level" in GameManager:
		level = int(GameManager.current_level)
	level_display.text = "第 %d 关" % level

func _on_current_level_changed(_level: int) -> void:
	_update_level_display()
	var battlefield = _get_battlefield()
	if battlefield and battlefield.has_method("_update_background"):
		battlefield._update_background()

## 键盘快捷键处理
func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	# 只处理键盘事件
	if not event is InputEventKey:
		return

	if not event.is_pressed():
		return

	# ESC键：关闭当前面板
	if event.is_action("ui_cancel"):
		_close_all_overlays()
		return

	# 只有在非战斗状态才响应快捷键
	var battlefield = _get_battlefield()
	var in_battle = false
	if battlefield and battlefield.has_method("is_battle_active"):
		in_battle = battlefield.is_battle_active()

	if in_battle:
		# 战斗中的快捷键
		if event.is_action("ui_pause") or event.keycode == KEY_SPACE:
			_on_pause_pressed()
			return
	else:
		# 战前准备状态的快捷键
		match event.keycode:
			KEY_1, KEY_B:
				_on_backpack_pressed()
			KEY_4, KEY_F:
				_on_faction_pressed()
			KEY_5, KEY_Q:
				_on_quest_pressed()
			KEY_6, KEY_T:
				_on_store_pressed()
			KEY_7:
				_on_progression_pressed()
			KEY_8, KEY_L:
				_on_leaderboard_pressed()
			KEY_9:
				_on_settings_pressed()
			KEY_ESCAPE:
				_close_all_overlays()
			KEY_ENTER:
				_on_start_battle()
			KEY_SPACE:
				_on_start_battle()

func _connect_panel_closed_signals() -> void:
	var manufacture_cc := get_node_or_null("PopupLayer/ManufactureOverlay/CenterContainer")
	#region agent log
	_agent_log_67fe53("H1_H4", "main.gd:_connect_panel_closed_signals", "before connecting panel closed signals", {
		"has_manufacture_cc": manufacture_cc != null,
		"manufacture_cc_child_count": manufacture_cc.get_child_count() if manufacture_cc != null else -1,
		"has_progression_path": has_node("PopupLayer/ManufactureOverlay/CenterContainer/CardEnhancementPanel")
	})
	#endregion
	if manufacture_cc != null:
		var child_names: Array[String] = []
		for child in manufacture_cc.get_children():
			child_names.append(str(child.name))
		#region agent log
		_agent_log_67fe53("H2", "main.gd:_connect_panel_closed_signals", "manufacture center container children snapshot", {
			"child_names": child_names
		})
		#endregion
	# CardEnhancementPanel 由 _ensure_card_enhancement_panel 按需创建，勿在 _ready 用 $ 强引用
	var progression_panel: Node = get_node_or_null("PopupLayer/ManufactureOverlay/CenterContainer/CardEnhancementPanel")
	var panels := {
		"quest":              $PopupLayer/QuestOverlay/CenterContainer/QuestPanel,
		"store":              $PopupLayer/StoreOverlay/CenterContainer/StorePanel,
		"phase_law":          $PopupLayer/PhaseLawOverlay/CenterContainer/PhaseLawPanel,
		"faction":            $PopupLayer/FactionOverlay/CenterContainer/FactionPanel,
		"leaderboard":        $PopupLayer/LeaderboardPanel,
		"backpack":           $PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/BackpackPanel,
		"progression":        progression_panel,
		"settings":           $PopupLayer/SettingsOverlay/CenterContainer/SettingsPanel,
		"info":               $PopupLayer/IntelligenceOverlay/CenterContainer/IntelligenceHubPanel,
	}
	#region agent log
	_agent_log_67fe53("H1", "main.gd:_connect_panel_closed_signals", "panels dictionary built", {
		"keys": panels.keys()
	})
	#endregion
	for key in panels:
		var panel = panels[key]
		if panel == null:
			continue
		if panel.has_signal("closed") and not panel.closed.is_connected(_on_panel_closed.bind(key)):
			panel.closed.connect(_on_panel_closed.bind(key))

# ── overlay 统一开关 ─────────────────────────────────────────
func _open_overlay(overlay: Control, panel_key: String = "") -> void:
	if overlay == null:
		return
	_ensure_lazy_panel(panel_key)
	# 暂时禁用panel刷新，避免潜在问题
	# var panel: Node = null
	# var cc = overlay.get_node_or_null("CenterContainer")
	# if cc and cc.get_child_count() > 0:
	# 	panel = cc.get_child(0)
	# else:
	# 	panel = overlay.find_child("BackpackPanel", true, false)
	# if panel and panel.has_method("refresh"):
	# 	panel.refresh()
	overlay.visible = true
	# 防止子级曾被误 hide（例如旧版设置关闭只藏了 CenterContainer）
	var cc_reset: Node = overlay.get_node_or_null("CenterContainer")
	if cc_reset is Control:
		(cc_reset as Control).visible = true
	# 地图面板常驻主场景：打开时刷新一次状态（关卡高亮/可解锁信息）
	if panel_key == "map":
		var world_map_panel: Node = overlay.get_node_or_null("CenterContainer/WorldMapPanel")
		if world_map_panel and world_map_panel.has_method("refresh"):
			world_map_panel.refresh()
	elif panel_key == "backpack":
		var backpack_panel: Node = overlay.get_node_or_null("BackpackVBox/CenterRow/BackpackCenter/BackpackPanel")
		if backpack_panel == null:
			backpack_panel = overlay.find_child("BackpackPanel", true, false)
		if backpack_panel and backpack_panel.has_method("on_overlay_opened"):
			backpack_panel.on_overlay_opened()
			if PerformanceMetricsManager and PerformanceMetricsManager.has_method("mark_backpack_open_ready"):
				PerformanceMetricsManager.mark_backpack_open_ready()
	elif panel_key == "info":
		var hub: Node = overlay.get_node_or_null("CenterContainer/IntelligenceHubPanel")
		if hub and hub.has_method("refresh"):
			hub.refresh()
	# 性能优化：非战斗中打开面板时，冻结 SubViewport 避免无谓渲染
	_freeze_subviewport_if_not_in_battle()

func _close_overlay(overlay: Control, panel_key: String = "") -> void:
	# 成长面板关闭前尝试收拢可能存在的内嵌弹窗，避免输入焦点残留
	if overlay != null and overlay == manufacture_overlay:
		var mp: Node = manufacture_overlay.get_node_or_null("CenterContainer/CardEnhancementPanel")
		if mp == null:
			mp = manufacture_overlay.find_child("CardEnhancementPanel", true, false)
		if mp and mp.has_method("close_embedded_popups"):
			mp.close_embedded_popups()
	if overlay:
		overlay.visible = false
	if panel_key != "" and bottom_function_bar:
		bottom_function_bar.notify_panel_closed(panel_key)
	# 性能优化：面板全部关闭后，若无其他面板打开，恢复 SubViewport 状态
	_restore_subviewport_if_needed()

func _toggle_overlay(overlay: Control, panel_key: String = "") -> void:
	if overlay == null:
		return
	if overlay.visible:
		_close_overlay(overlay, panel_key)
	else:
		_open_overlay(overlay, panel_key)

# ── 面板关闭回调（统一入口） ──────────────────────────────────
func _on_panel_closed(key: String) -> void:
	match key:
		"quest":              _close_overlay(quest_overlay, "quest")
		"store":              _close_overlay(store_overlay, "store")
		"phase_law":
			_close_overlay(phase_law_overlay, "law")
			if bottom_instrument_bar and bottom_instrument_bar.has_method("refresh"):
				bottom_instrument_bar.refresh()
		"faction":            _close_overlay(faction_overlay, "faction")
		"map":                _close_overlay(map_overlay, "map")
		"settings":           _close_overlay(settings_overlay, "settings")
		"leaderboard":
			if bottom_function_bar:
				bottom_function_bar.notify_panel_closed("leaderboard")
		"backpack":           _close_overlay(backpack_overlay, "backpack")
		"progression":        _close_overlay(manufacture_overlay, "progression")
		"info":               _close_overlay(intelligence_overlay, "info")

# ── 排行榜：PopupPanel 特殊处理 ──────────────────────────────
func _toggle_leaderboard() -> void:
	if leaderboard_panel == null:
		return
	if leaderboard_panel.visible:
		_close_leaderboard()
	else:
		if leaderboard_panel.has_method("refresh"):
			leaderboard_panel.refresh()
		leaderboard_panel.popup_centered()
		if bottom_function_bar:
			bottom_function_bar.notify_panel_closed("")  # 排行榜不在功能键高亮列表

func _close_leaderboard() -> void:
	if leaderboard_panel:
		leaderboard_panel.hide()

# ── 底部仪表栏信号 ────────────────────────────────────────────
func _on_instrument_area_clicked() -> void:
	# 战前点击相位仪槽位：无操作（装配通过背包拖拽完成）
	pass

func _on_phase_level_label_clicked() -> void:
	# 点击相位仪等级标签：打开相位仪选择面板
	_open_phase_instrument_selector()

func _on_law_area_clicked() -> void:
	# 法则面板主流程下线：法则作为普通卡牌在成长/背包里处理
	return

func _on_law_slot_clicked(law_id: String, kind: String, origin_global: Vector2) -> void:
	# 战斗中点击主动法则格子：进入选点释放模式
	var in_battle: bool = (BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active)
	if not in_battle:
		return
	if kind == "active":
		# 确保法则已在 PhaseLawManager 的 equipped_active_laws 中（防止 UI 显示但实际未同步的情况）
		var pim: Node = PhaseInstrumentManager
		if pim and pim.has_method("sync_law_cards_to_phase_law_manager"):
			pim.sync_law_cards_to_phase_law_manager()
		var plm: Node = PhaseLawManager
		if plm and "equipped_active_laws" in plm:
			var actives: Array = plm.equipped_active_laws
			if not actives.has(law_id):
				# 同步后仍无此法则：强制加入 equipped_active_laws 和 active_law_states
				actives.append(String(law_id))
				plm.equipped_active_laws = actives
				if plm.has_method("ensure_law_unlocked"):
					plm.ensure_law_unlocked(String(law_id))
				# 同时补入 active_law_states（如果是战中且尚未初始化）
				if "active_law_states" in plm:
					if not plm.active_law_states.has(law_id):
						plm.active_law_states[law_id] = {"casts_used": 0, "casts_limit": 999999}
				print("[Main] 强制同步主动法则到 PhaseLawManager: ", law_id)
		if SignalBus:
			BattleInputState.pending_deploy_platform_card_id = ""
			BattleInputState.pending_deploy_origin_global = Vector2.ZERO
			BattleInputState.pending_cast_law_id = String(law_id)
			BattleInputState.pending_cast_law_origin_global = origin_global

# ── 功能键信号 ────────────────────────────────────────────────
func _on_backpack_pressed() -> void:
	_play_sfx("button")
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("mark_backpack_open_begin"):
		PerformanceMetricsManager.mark_backpack_open_begin()
	_toggle_overlay(backpack_overlay, "backpack")

func _overlay_for_panel_key(panel_key: String) -> Control:
	match panel_key:
		"backpack": return backpack_overlay
		"progression": return manufacture_overlay
		"quest": return quest_overlay
		"store": return store_overlay
		"law": return phase_law_overlay
		"phase_law": return phase_law_overlay
		"faction": return faction_overlay
		"map": return map_overlay
		"settings": return settings_overlay
		"info": return intelligence_overlay
	return null

func _ensure_lazy_panel(panel_key: String) -> void:
	if panel_key.is_empty() or UILazyLoader == null or not UILazyLoader.has_method("get_panel"):
		return
	var lazy_id: String = ""
	var container_path: String = "CenterContainer"
	match panel_key:
		"backpack":
			lazy_id = "backpack"
			container_path = "BackpackVBox/CenterRow/BackpackCenter"
		"progression":
			lazy_id = "manufacture"
		"quest":
			lazy_id = "quest"
		"store":
			lazy_id = "store"
		"law":
			lazy_id = "phase_law"
		"faction":
			lazy_id = "faction"
		"map":
			lazy_id = "map"
		"settings":
			lazy_id = "settings"
		_:
			return
	var overlay: Control = _overlay_for_panel_key(lazy_id)
	if overlay == null:
		return
	var container: Node = overlay.get_node_or_null(container_path)
	if container == null:
		return
	for child in container.get_children():
		if not (child is Control):
			continue
		var child_name_lc: String = String(child.name).to_lower()
		var is_panel_node: bool = child.has_signal("closed") or child_name_lc.find("panel") >= 0
		if panel_key == "progression" and child.name == "CardEnhancementPanel":
			is_panel_node = true
		if is_panel_node:
			# #region agent log
			_debug_log("H4", "Main.gd:_ensure_lazy_panel:reuse_existing", "existing panel found in container", {
				"panel_key": panel_key,
				"lazy_id": lazy_id,
				"child_name": child.name
			})
			# #endregion
			_connect_panel_closed_runtime(child, lazy_id)
			return
	# #region agent log
	_debug_log("H4", "Main.gd:_ensure_lazy_panel:request_lazy_load", "no panel found, requesting UILazyLoader", {
		"panel_key": panel_key,
		"lazy_id": lazy_id,
		"container_path": container_path
	})
	# #endregion
	var loaded_panel: Control = UILazyLoader.get_panel(lazy_id)
	if loaded_panel != null:
		_connect_panel_closed_runtime(loaded_panel, lazy_id)

func _connect_panel_closed_runtime(panel: Node, panel_key: String) -> void:
	if panel == null or not (panel is Control):
		return
	if panel.has_signal("closed") and not panel.closed.is_connected(_on_panel_closed.bind(panel_key)):
		panel.closed.connect(_on_panel_closed.bind(panel_key))


func _connect_intelligence_hub_signals() -> void:
	var hub: Node = get_node_or_null("PopupLayer/IntelligenceOverlay/CenterContainer/IntelligenceHubPanel")
	if hub == null:
		return
	if hub.has_signal("open_progression_requested") and not hub.open_progression_requested.is_connected(_on_intelligence_open_progression):
		hub.open_progression_requested.connect(_on_intelligence_open_progression)


func _on_intelligence_open_progression(card_id: String) -> void:
	_close_overlay(intelligence_overlay, "info")
	_ensure_card_enhancement_panel()
	_open_overlay(manufacture_overlay, "progression")
	var panel: Node = manufacture_overlay.get_node_or_null("CenterContainer/CardEnhancementPanel")
	if panel == null:
		panel = manufacture_overlay.find_child("CardEnhancementPanel", true, false)
	if panel and panel.has_method("select_card_by_id") and not card_id.is_empty():
		panel.select_card_by_id(card_id)


func _on_blueprint_star_upgraded(card_id: String, new_star: int) -> void:
	pass

func _on_faction_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(faction_overlay, "faction")

func _on_quest_pressed() -> void:
	_toggle_overlay(quest_overlay, "quest")

func _on_store_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(store_overlay, "store")

func _on_progression_pressed() -> void:
	_play_sfx("button")
	# 主流程切换：制造/蓝图工坊下线，成长统一进入卡牌强化面板
	_ensure_card_enhancement_panel()
	_toggle_overlay(manufacture_overlay, "progression")

func _ensure_card_enhancement_panel() -> void:
	if manufacture_overlay == null:
		return
	var cc: Node = manufacture_overlay.get_node_or_null("CenterContainer")
	if cc == null:
		return
	var existing: Node = cc.get_node_or_null("CardEnhancementPanel")
	if existing != null:
		return
	for child in cc.get_children():
		child.queue_free()
	var panel: Node = CardEnhancementPanelScene.instantiate()
	if panel == null:
		return
	panel.name = "CardEnhancementPanel"
	cc.add_child(panel)
	if panel.has_signal("closed") and not panel.closed.is_connected(_on_panel_closed.bind("progression")):
		panel.closed.connect(_on_panel_closed.bind("progression"))

func _on_map_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(map_overlay, "map")

func _on_settings_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(settings_overlay, "settings")

func _on_manual_save_pressed() -> void:
	_play_sfx("button")
	if SaveManager == null or not SaveManager.has_method("save_game"):
		_show_save_result_toast("存档系统未就绪", true)
		return
	var ok: bool = SaveManager.save_game()
	if ok:
		_play_sfx("card_place")
		_show_save_result_toast("游戏已保存", false)
	else:
		_play_sfx("error")
		_show_save_result_toast("存档失败，请重试", true)

func _on_leaderboard_pressed() -> void:
	_play_sfx("button")
	_toggle_leaderboard()

func _on_info_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(intelligence_overlay, "info")

# ── 战斗控制 ─────────────────────────────────────────────────
func _on_start_battle() -> void:
	_run_start_battle_sequence()


func _run_start_battle_sequence() -> void:
	_play_sfx("button")
	# 关闭所有弹出面板
	_close_all_overlays()
	if bottom_function_bar:
		var phase_master_ui: bool = (
			GameManager
			and GameManager.has_method("is_phase_master_battle")
			and GameManager.is_phase_master_battle()
		)
		if phase_master_ui:
			bottom_function_bar.set_start_battle_text("战斗中")
		else:
			bottom_function_bar.set_start_battle_text("格子布阵")
	var tree := get_tree()
	if tree:
		tree.paused = false
		if bottom_function_bar:
			bottom_function_bar.set_pause_text("暂停")
	_show_battle()
	var battlefield = _get_battlefield()
	if not battlefield:
		if bottom_function_bar:
			bottom_function_bar.set_start_battle_text("开始战斗")
		return
	var plm = PhaseLawManager
	var actives: Array = []
	if plm and "equipped_active_laws" in plm:
		actives = plm.equipped_active_laws
	_blueprints_unlocked_this_battle.clear()
	var pim: Node = PhaseInstrumentManager
	if pim and pim.has_method("get_phase_field_xp_progress"):
		var phase_prog: Dictionary = pim.get_phase_field_xp_progress()
		_phase_field_xp_before_battle = int(phase_prog.get("xp", 0))
		_phase_field_level_before_battle = int(phase_prog.get("level", 1))
	if GameManager:
		GameManager.set_battle_scene(battlefield)
		call_deferred("_deferred_go_to_battle")

func _deferred_go_to_battle() -> void:
	if GameManager:
		GameManager.go_to_battle()

func _on_pause_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = not tree.paused
	if bottom_function_bar:
		bottom_function_bar.set_pause_text("继续" if tree.paused else "暂停")

func _on_back_to_title() -> void:
	if SaveManager:
		SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _on_world_map() -> void:
	_open_overlay(map_overlay, "map")

# ── 关闭所有弹出面板 ─────────────────────────────────────────
func _close_all_overlays() -> void:
	var overlays := [
		quest_overlay, store_overlay, phase_law_overlay,
		backpack_overlay, faction_overlay,
		map_overlay, settings_overlay, intelligence_overlay,
	]
	for ov in overlays:
		if ov:
			ov.visible = false
	# PopupPanel 类型的排行榜单独处理
	if leaderboard_panel:
		leaderboard_panel.hide()
	if bottom_function_bar:
		bottom_function_bar.notify_panel_closed("")

# ── 战场显示控制 ─────────────────────────────────────────────
func _show_battle() -> void:
	if battle_container:
		battle_container.visible = true
	# 性能优化：只在战斗时持续渲染 SubViewport
	var viewport = get_node_or_null("BattleContainer/SubViewportContainer/SubViewport")
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var battlefield = _get_battlefield()
	if battlefield:
		if battlefield.has_method("ensure_phase_driver"):
			battlefield.ensure_phase_driver()
		var pu = battlefield.get_node_or_null("PlayerUnits")
		var eu = battlefield.get_node_or_null("EnemyUnits")
		if pu:
			for c in pu.get_children():
				c.queue_free()
		if eu:
			for c in eu.get_children():
				c.queue_free()
		var enemy_driver := battlefield.get_node_or_null("EnemyPhaseFieldDriver")
		if enemy_driver != null and is_instance_valid(enemy_driver):
			if enemy_driver.has_method("stop_production"):
				enemy_driver.stop_production()
			enemy_driver.queue_free()

func _get_battlefield() -> Node2D:
	return get_node_or_null("BattleContainer/SubViewportContainer/SubViewport/Battlefield") as Node2D

## 非战斗时打开/关闭 overlay，冻结/恢复 SubViewport 渲染（减少 GPU 负载）
func _is_any_overlay_open() -> bool:
	for o in [backpack_overlay, quest_overlay,
			store_overlay, phase_law_overlay, faction_overlay,
			map_overlay, settings_overlay, manufacture_overlay]:
		if o and o.visible:
			return true
	return false

func _is_in_battle() -> bool:
	return BattleManager != null and BattleManager.battle_active

func _freeze_subviewport_if_not_in_battle() -> void:
	if _is_in_battle():
		return
	var vp = get_node_or_null("BattleContainer/SubViewportContainer/SubViewport")
	if vp and vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _restore_subviewport_if_needed() -> void:
	if _is_any_overlay_open():
		return  # 还有其他面板打开，保持冻结
	if _is_in_battle():
		return  # 战斗中由 _show_battle / _on_battle_ended 控制
	var vp = get_node_or_null("BattleContainer/SubViewportContainer/SubViewport")
	if vp and vp.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE

# ── 战斗相关回调 ─────────────────────────────────────────────
func _on_battle_ended_clear_pending(_player_won: bool) -> void:
	# 性能优化：战斗结束后停止持续渲染 SubViewport
	var viewport = get_node_or_null("BattleContainer/SubViewportContainer/SubViewport")
	if viewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if SignalBus:
		BattleInputState.clear_all_pending()

func _on_player_deploy_failed(_reason_code: String, message: String) -> void:
	_show_deploy_failure_toast(message)

func _show_deploy_failure_toast(message: String) -> void:
	if _deploy_toast == null:
		_deploy_toast = ToastUtils.new()
	_deploy_toast.show_toast(self, message, true)

func _show_save_result_toast(message: String, is_error: bool) -> void:
	if _save_toast == null:
		_save_toast = ToastUtils.new()
	_save_toast.show_toast(self, message, is_error, -200.0, 200.0, -120.0, -72.0, 1.6)

func _on_active_law_cast_at(law_id: String, world_pos: Vector2) -> void:
	var bf := _get_battlefield()
	if bf == null:
		#region agent log
		_agent_log("H2_law_apply", "active_law_cast_no_battlefield", {"law_id": law_id, "world_pos": world_pos})
		#endregion
		return
	#region agent log
	_agent_log("H2_law_apply", "active_law_cast_received", {
		"law_id": law_id,
		"world_pos": world_pos,
		"battlefield_name": bf.name
	})
	#endregion
	var CastEffect = preload("res://scenes/effects/cast_effect.gd")
	var effect := Node2D.new()
	effect.set_script(CastEffect)
	effect.position = world_pos
	bf.add_child(effect)
	ActiveLawEffects.apply_active_law_effect(law_id, world_pos, bf)
	# 记录施放：扣除纳米材料、递增施放次数、应用环境变化
	if PhaseLawManager and PhaseLawManager.has_method("record_cast"):
		PhaseLawManager.record_cast(law_id)
	if SignalBus and SignalBus.has_signal("phase_law_cast"):
		var fam: String = PhaseLaws.get_family(law_id)
		SignalBus.phase_law_cast.emit(law_id, world_pos, fam)

func _on_blueprint_unlocked(card_id: String) -> void:
	if not _blueprints_unlocked_this_battle.has(card_id):
		_blueprints_unlocked_this_battle.append(card_id)

# ── 战斗结果 ─────────────────────────────────────────────────
func show_battle_result(player_won: bool) -> void:
	var reward_summary: Dictionary = {}
	if GameManager != null and ("last_battle_reward_summary" in GameManager):
		reward_summary = GameManager.last_battle_reward_summary
	BattleResultDialog.create(self, player_won, _blueprints_unlocked_this_battle, \
		_phase_field_xp_before_battle, _phase_field_level_before_battle, reward_summary)
	_blueprints_unlocked_this_battle.clear()

func _on_result_confirmed() -> void:
	_clear_battlefield_units()
	if SignalBus:
		BattleInputState.clear_all_pending()
	if bottom_function_bar:
		bottom_function_bar.set_start_battle_text("开始战斗")
	if GameManager:
		GameManager.return_to_prep()
	# 刷新底部仪表栏
	if bottom_instrument_bar and bottom_instrument_bar.has_method("refresh"):
		bottom_instrument_bar.refresh()
	_update_level_display()

func _clear_battlefield_units() -> void:
	var bf := _get_battlefield()
	if bf == null:
		return

	var pu := bf.get_node_or_null("PlayerUnits")
	if pu:
		for c in pu.get_children():
			if c:
				c.queue_free()

	var eu := bf.get_node_or_null("EnemyUnits")
	if eu:
		for c in eu.get_children():
			if c:
				c.queue_free()

	# 清理临时节点（须保留 BattleSlotGrid，否则下一场无法部署）
	if bf.has_method("prune_transient_children"):
		bf.prune_transient_children()

## 打开相位仪选择面板
func _open_phase_instrument_selector() -> void:
	var selector_scene = preload("res://scenes/ui/phase_instrument_selector.tscn")
	var selector = selector_scene.instantiate()
	if selector == null:
		push_error("[Main] 无法实例化相位仪选择器")
		return

	for c in popup_layer.get_children():
		if c.is_in_group("phase_instrument_selector"):
			return
	# 使用普通 Control 全屏遮罩，避免 Window/AcceptDialog 在 CanvasLayer 下无法显示
	popup_layer.add_child(selector)
	selector.instrument_selected.connect(_on_phase_selector_selected.bind(selector))

func _on_phase_selector_selected(_instrument_id: String, selector: Node) -> void:
	if is_instance_valid(selector):
		selector.queue_free()
	# 刷新底部仪表栏
	if bottom_instrument_bar and bottom_instrument_bar.has_method("refresh"):
		bottom_instrument_bar.refresh()

# ── 新系统管理器集成 ─────────────────────────────────────────────

## 注册新的游戏系统管理器
func _setup_new_managers() -> void:
	# 简化版本：只检查已在autoload中的管理器，不再动态创建
	var managers_to_check = [
		"TutorialProgressionManager",
		"DailyTaskManager",
		"ChallengeModeManager",
		"CardCollectionManager"
	]

	for manager_name in managers_to_check:
		var existing = get_node_or_null("/root/" + manager_name)
		if existing:
			if DEBUG_MAIN_LOG:
				print("[Main] 管理器已加载: ", manager_name)
		else:
			if DEBUG_MAIN_LOG:
				print("[Main] 管理器未找到: ", manager_name)

## 启动新手教程（如果是新游戏）
func _start_tutorial_if_needed() -> void:
	var tutorial_manager = get_node_or_null("/root/TutorialProgressionManager")
	if tutorial_manager and tutorial_manager.has_method("should_show_tutorial") and tutorial_manager.should_show_tutorial():
		if DEBUG_MAIN_LOG:
			print("[Main] 应该显示新手教程")
		# 暂时不自动启动教程，避免潜在问题

## 初始化日常任务
func _init_daily_tasks() -> void:
	var task_manager = get_node_or_null("/root/DailyTaskManager")
	if task_manager:
		task_manager.refresh_daily_tasks()
		if DEBUG_MAIN_LOG:
			print("[Main] 日常任务已初始化")

## 集成新系统
func _integrate_new_systems() -> void:
	# 暂时跳过系统集成，直到新系统完全就绪
	if DEBUG_MAIN_LOG:
		print("[Main] 跳过新系统集成")

func _exit_tree() -> void:
	if _deploy_toast:
		_deploy_toast.cleanup()
		_deploy_toast = null
	if _save_toast:
		_save_toast.cleanup()
		_save_toast = null

# ── 工具函数 ─────────────────────────────────────────────────
