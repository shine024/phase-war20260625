extends Control
## 主界面：战前准备 ↔ 战斗 ↔ 战后结算
## 新布局：BattleContainer(上) + HudLayer(CanvasLayer 40：顶部状态栏/资源信息/底部统一栏) + PopupLayer(100 弹窗)
## 弹出面板由 PopupLayer 管理；常驻 HUD 在独立 CanvasLayer，避免与战场 Control 树顺序导致的遮挡错乱

## 播放音效（Autoload AudioManager；get_node_or_null 兜底）
func _play_sfx(name: String) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(name)

## P1-5: 运行期新增的 BaseButton 自动设手型光标（含懒加载面板/重建列表行的按钮）
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

const MainBattleSetup = preload("res://scripts/systems/main_battle_setup.gd")
const MainReward = preload("res://scripts/systems/main_reward.gd")
const ToastUtils = preload("res://scripts/toast_utils.gd")
const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
# v8.x: CardEnhancementPanelScene 已移除（强化②停用），养成改为自动经验升星 + 技能树
const AFKModeManagerScript = preload("res://scripts/systems/afk_mode_manager.gd")
const OfflineIdleManagerScript = preload("res://scripts/systems/offline_idle_manager.gd")
const OfflineRewardDialogScript = preload("res://scenes/ui/offline_reward_dialog.gd")
const DEBUG_MAIN_LOG := false

var _blueprints_unlocked_this_battle: Array = []
var _phase_field_xp_before_battle: int = 0
var _phase_field_level_before_battle: int = 1
var _battle_setup: MainBattleSetup = null
var _reward: MainReward = null
var _deploy_toast: ToastUtils = null
var _save_toast: ToastUtils = null
var _afk_manager: AFKModeManager = null
var _offline_idle_manager: OfflineIdleManager = null

# ── 节点引用 ──────────────────────────────────────────────────
@onready var battle_container: Control            = $BattleContainer
@onready var bottom_instrument_bar                = $HudLayer/BattleBottomBar/BottomInstrumentBar
@onready var bottom_function_bar                 = $HudLayer/BattleBottomBar/BottomFunctionBar
@onready var top_hud_bar                         = $HudLayer/TopHudBar
@onready var popup_layer: CanvasLayer            = $PopupLayer

# Overlays（在 PopupLayer 下）
@onready var quest_overlay: Control              = $PopupLayer/QuestOverlay
@onready var store_overlay: Control              = $PopupLayer/StoreOverlay
# D3 2026-08-22：成就/帮助面板接线（此前面板存在但无任何开启路径）
@onready var achievement_overlay: Control        = $PopupLayer/AchievementOverlay
@onready var help_overlay: Control               = $PopupLayer/HelpOverlay
# v7.x: PhaseLawOverlay 已删除——符文管理合并到背包 RunesTab,底部栏"法则区"点击改为打开背包符文 Tab
@onready var backpack_overlay: Control           = $PopupLayer/BackpackOverlay
@onready var faction_overlay: Control            = $PopupLayer/FactionOverlay
@onready var map_overlay: Control                = $PopupLayer/MapOverlay
@onready var settings_overlay: Control           = $PopupLayer/SettingsOverlay
# v7.x 面板统一：排行榜迁出 PopupPanel，改走常驻 Overlay（与其他面板同构）
@onready var leaderboard_overlay: Control       = $PopupLayer/LeaderboardOverlay
@onready var leaderboard_panel: Control         = $PopupLayer/LeaderboardOverlay/CenterContainer/LeaderboardPanel
@onready var intelligence_overlay: Control     = $PopupLayer/IntelligenceOverlay
@onready var growth_overlay: Control           = $PopupLayer/GrowthOverlay
@onready var collection_overlay: Control       = $PopupLayer/CollectionOverlay
# D3 2026-08-22：enhancement_overlay（强化②，v8.x 停用系统）已删除——
# UILazyLoader 无配置、无开启方，注释型死节点。
@onready var modification_overlay: Control    = $PopupLayer/ModificationOverlay
@onready var evolution_overlay: Control       = $PopupLayer/EvolutionOverlay
@onready var afk_overlay: Control             = $PopupLayer/AFKOverlay
# v7.x: 玩家相位师详细面板（点击底部栏相位场标签打开）
@onready var player_master_overlay: Control   = $PopupLayer/PlayerMasterOverlay
@onready var level_display: Label = null  # v7.x: 关卡名合并进 TopHudBar，此引用保留兼容（_update_level_display 改用 top_hud_bar.set_level）

func _ready() -> void:
	## 初始化拆分模块
	_battle_setup = MainBattleSetup.new()
	_battle_setup.main = self
	_reward = MainReward.new()
	_reward.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	# P1-5: 全局手型光标——所有 BaseButton 进入场景树即设 POINTING_HAND
	# （实测 Godot 4.5 Button 默认是箭头，仅 LinkButton 是手型；详见 panel_styles.gd 注释）
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	PanelStyles.apply_pointing_hand.call_deferred(self)
	# P1-9: 中文字体显式 fallback 链（此前依赖玩家机器系统字体隐式回退）
	DesignTokens.ensure_cjk_fallback()
	# 连接底部仪表栏信号
	if bottom_instrument_bar:
		bottom_instrument_bar.instrument_area_clicked.connect(_on_instrument_area_clicked)
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
		bottom_function_bar.btn_achievement_pressed.connect(_on_achievement_pressed)
		bottom_function_bar.btn_settings_pressed.connect(_on_settings_pressed)
		bottom_function_bar.btn_help_pressed.connect(_on_help_pressed)
		bottom_function_bar.btn_collection_pressed.connect(_on_collection_pressed)
		bottom_function_bar.btn_save_pressed.connect(_on_manual_save_pressed)
		bottom_function_bar.btn_afk_pressed.connect(_on_afk_pressed)
	# v7.x: 4 个战斗控制按钮（开始/暂停/撤退/返回）整合进顶部 TopHudBar
	if top_hud_bar:
		top_hud_bar.btn_start_battle_pressed.connect(_on_start_battle)
		top_hud_bar.btn_pause_pressed.connect(_on_pause_pressed)
		top_hud_bar.btn_retreat_pressed.connect(_on_retreat_pressed)
		top_hud_bar.btn_back_pressed.connect(_on_back_to_title)
	# 任务红点角标：连接 DailyTaskManager 信号刷新可领取数量
	_connect_quest_badge_signals()

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
		SignalBus.battle_ended.connect(_on_battle_ended_clear_pending)
		# v6.6 修复: toggle_* 信号原 emit 无 connect，教程引导的"打开面板"动作失效。
		if SignalBus.has_signal("toggle_backpack") and not SignalBus.toggle_backpack.is_connected(_on_backpack_pressed):
			SignalBus.toggle_backpack.connect(_on_backpack_pressed)
		if SignalBus.has_signal("toggle_phase_instrument") and not SignalBus.toggle_phase_instrument.is_connected(_on_toggle_phase_instrument_from_tutorial):
			SignalBus.toggle_phase_instrument.connect(_on_toggle_phase_instrument_from_tutorial)
		# v7.x 教程引导：强化/改造面板切换入口
		if SignalBus.has_signal("toggle_enhancement") and not SignalBus.toggle_enhancement.is_connected(_on_toggle_enhancement_from_tutorial):
			SignalBus.toggle_enhancement.connect(_on_toggle_enhancement_from_tutorial)
		if SignalBus.has_signal("toggle_modification") and not SignalBus.toggle_modification.is_connected(_on_toggle_modification_from_tutorial):
			SignalBus.toggle_modification.connect(_on_toggle_modification_from_tutorial)
		# v9.x（P2-4 批次6）：教程 8-12 步引导面板
		if SignalBus.has_signal("toggle_evolution") and not SignalBus.toggle_evolution.is_connected(_on_toggle_evolution_from_tutorial):
			SignalBus.toggle_evolution.connect(_on_toggle_evolution_from_tutorial)
		if SignalBus.has_signal("toggle_faction") and not SignalBus.toggle_faction.is_connected(_on_toggle_faction_from_tutorial):
			SignalBus.toggle_faction.connect(_on_toggle_faction_from_tutorial)
		if SignalBus.has_signal("toggle_store") and not SignalBus.toggle_store.is_connected(_on_toggle_store_from_tutorial):
			SignalBus.toggle_store.connect(_on_toggle_store_from_tutorial)
		if SignalBus.has_signal("toggle_world_map") and not SignalBus.toggle_world_map.is_connected(_on_toggle_world_map_from_tutorial):
			SignalBus.toggle_world_map.connect(_on_toggle_world_map_from_tutorial)
		if SignalBus.has_signal("open_phase_field_points") and not SignalBus.open_phase_field_points.is_connected(_on_open_phase_field_from_tutorial):
			SignalBus.open_phase_field_points.connect(_on_open_phase_field_from_tutorial)
		SignalBus.player_deploy_failed.connect(_on_player_deploy_failed)

	# 全局 UI 贴图：关闭按钮等（依赖 PopupLayer 子树已实例化）
	call_deferred("_apply_global_ui_textures")
	# BU-7（战斗界面美化）：暗角层（CanvasLayer 35，HUD 40 之下）+ 主菜单真网格
	_setup_battle_vignette()
	_setup_menu_grid_pattern()
	# 非关键初始化延后，降低主界面首帧压力
	call_deferred("_deferred_non_critical_init")
	# 启动后释放预置面板实例，转按需加载，减少常驻开销
	call_deferred("_prune_preloaded_panels")
	# 记录主界面 TTI
	call_deferred("_mark_main_interactive")

## BU-7：全屏暗角——radial 渐变（中心透明→边缘黑 0.32），把视线压向战场中心。
## 静态效果不涉及动效（motion_reduce 不受影响）；mouse_filter=IGNORE 不挡任何交互。
func _setup_battle_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "VignetteLayer"
	layer.layer = 35
	add_child(layer)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.32)])
	grad.offsets = PackedFloat32Array([0.55, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	var tr := TextureRect.new()
	tr.name = "Vignette"
	tr.texture = tex
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(tr)

## BU-7：GridPattern 处置——原 2% 青色块（不是网格）换成程序生成的 32px 真网格纹理
## （青线 alpha 0.05 平铺），只服务主菜单氛围层；战场内不需要（已有阵营地面着色）。
func _setup_menu_grid_pattern() -> void:
	var gp := get_node_or_null("GridPattern")
	if gp == null:
		return
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var line := Color(0.0, 0.941, 1.0, 0.05)
	for y in range(32):
		img.set_pixel(0, y, line)
	for x in range(32):
		img.set_pixel(x, 0, line)
	var tex := ImageTexture.create_from_image(img)
	var tr := TextureRect.new()
	tr.name = "GridPatternTex"
	tr.texture = tex
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.stretch_mode = TextureRect.STRETCH_TILE
	gp.get_parent().add_child(tr)
	gp.get_parent().move_child(tr, gp.get_index() + 1)
	gp.visible = false

func _apply_global_ui_textures() -> void:
	if popup_layer:
		UiAssetLoader.apply_close_icons_recursive(popup_layer)


## v6.6(挂机): 转发自动部署推进。
## AFKModeManager 是 RefCounted，无 _process 自动回调，故由主场景驱动。
## 非挂机时首行短路，几乎零开销。
func _process(delta: float) -> void:
	if _afk_manager != null:
		_afk_manager.process_auto_deploy(delta)


func _deferred_non_critical_init() -> void:
	# v9.x 清理：_setup_new_managers 为 no-op 检查（已删）
	# 集成新系统
	_integrate_new_systems()
	# 初始化挂机管理器
	_init_afk_manager()
	# v6.6(离线挂机): 初始化离线挂机管理器 + 检查离线奖励
	_init_offline_idle_manager()
	# 启动新手教程（如果是新游戏）
	_start_tutorial_if_needed()
	# 初始化日常任务
	_init_daily_tasks()
	# 空闲期预加载高频弹窗，降低首次打开卡顿
	_preload_common_panels()
	# v6.11: blueprint_star_upgraded 连接已移除（信号已删）
	# v7.x（关卡详情"自动部署"按钮）：world_map 用 Engine meta 传递意图，
	# 进 main 场景后自动切 AFK 推图模式 + start_afk（从指定关开始自动布阵战斗）。
	if Engine.has_meta("world_map_auto_deploy_level"):
		var _auto_lvl: int = int(Engine.get_meta("world_map_auto_deploy_level"))
		Engine.remove_meta("world_map_auto_deploy_level")
		call_deferred("_auto_start_afk_from_world_map", _auto_lvl)
	# v9.x 性能：SubViewportContainer(stretch) 入树时会把子视口强制 UPDATE_ALWAYS，
	# tscn/战斗结束还原的 UPDATE_ONCE 全被覆盖，非战斗期战场每帧空渲染。
	# 入树后补设一次即生效（容器不会再次改写）。挂机运行中除外（缩略图需要持续渲染）。
	# v9.x 修正：不立即设——主场景首帧布局/战场内容可能尚未收敛，UPDATE_ONCE 会把未收敛的
	# 早期帧定格（表现为战场区域迟迟不显示）。等短暂布局稳定期后再冻结。
	if not _is_in_battle() and (_afk_manager == null or not _afk_manager.is_running):
		_settle_freeze_battle_viewport()

func _settle_freeze_battle_viewport() -> void:
	await get_tree().create_timer(0.3).timeout
	# 等待期间进了战斗/开了挂机则放弃（战斗路径自会设 ALWAYS）
	if _is_in_battle() or (_afk_manager != null and _afk_manager.is_running):
		return
	if not is_inside_tree():
		return
	var boot_vp: Node = get_node_or_null("BattleContainer/SubViewportContainer/SubViewport")
	if boot_vp is SubViewport:
		boot_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _preload_common_panels() -> void:
	# v8.x 性能：后台线程预热高频面板的 .tscn 资源（不实例化、不占主线程）。
	# UILazyLoader.get_panel 走 load() 时会命中 ResourceLoader 缓存，
	# 把"首次打开面板同步编译 .tscn"的尖峰摊到启动后空闲期。
	# 只预热 .tscn 资源本身，preload 链内的子资源也会一并进缓存。
	var panel_paths: Array[String] = [
		# 高频养成面板（首开最易卡，每张都遍历 133 卡/实例全集）
		"res://scenes/ui/backpack_panel.tscn",
		"res://scenes/ui/quest_panel.tscn",
		"res://scenes/ui/store_panel.tscn",
		"res://scenes/ui/growth_panel.tscn",
		"res://scenes/ui/modification_panel.tscn",
		"res://scenes/ui/evolution_panel.tscn",
		"res://scenes/ui/collection_panel.tscn",
		# 战略面板（中频）
		"res://scenes/ui/faction_panel.tscn",
		"res://scenes/ui/occupation_panel.tscn",
		"res://scenes/ui/leaderboard_panel.tscn",
		"res://scenes/ui/intelligence_hub_panel.tscn",
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
		"growth": "CenterContainer",
		"quest": "CenterContainer",
		"store": "CenterContainer",
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
				child.queue_free()

func _update_level_display() -> void:
	var level = 1
	if GameManager and "current_level" in GameManager:
		level = int(GameManager.current_level)
	# v7.x: 关卡名合并进 TopHudBar
	if top_hud_bar and top_hud_bar.has_method("set_level"):
		top_hud_bar.set_level(level)
	elif level_display != null:
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

	# ESC键：P1-8 收敛为"关最上层面板"（原为一键全关，与各面板自己的逐级 ESC 行为不一致）；
	# 无面板打开时战斗中切换暂停
	if event.is_action("ui_cancel"):
		# P0: 撤退确认框打开时 ESC 等价"取消"（原会穿透到底层：关面板/切暂停）
		if _retreat_confirm != null and is_instance_valid(_retreat_confirm):
			_retreat_confirm.queue_free()
			_retreat_confirm = null
			get_viewport().set_input_as_handled()
			return
		_close_top_overlay()
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
		# P2-14: 数字键 1-9 快捷进入部署模式（第 N 个有战斗卡的绿槽，与点击槽位同链路）
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var slot_no: int = event.keycode - KEY_1 + 1
			if bottom_instrument_bar and bottom_instrument_bar.has_method("begin_deploy_from_slot_index"):
				bottom_instrument_bar.begin_deploy_from_slot_index(slot_no)
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
	var panels := {
		"quest":              $PopupLayer/QuestOverlay/CenterContainer/QuestPanel,
		"store":              $PopupLayer/StoreOverlay/CenterContainer/StorePanel,
		"faction":            $PopupLayer/FactionOverlay/CenterContainer/FactionPanel,
		"leaderboard":        $PopupLayer/LeaderboardOverlay/CenterContainer/LeaderboardPanel,
		"backpack":           get_node_or_null("PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/BackpackPanel"),
		"settings":           $PopupLayer/SettingsOverlay/CenterContainer/SettingsPanel,
		"info":               $PopupLayer/IntelligenceOverlay/CenterContainer/IntelligenceHubPanel,
		"occupation":         get_node_or_null("PopupLayer/OccupationOverlay/CenterContainer/OccupationPanel"),
		"growth":             get_node_or_null("PopupLayer/GrowthOverlay/CenterContainer/GrowthPanel"),
		"collection":         get_node_or_null("PopupLayer/CollectionOverlay/CenterContainer/CollectionPanel"),
		"afk":                get_node_or_null("PopupLayer/AFKOverlay/CenterContainer/AFKPanel"),
	}
	for key in panels:
		var panel = panels[key]
		if panel == null:
			continue
		if panel.has_signal("closed") and not panel.closed.is_connected(_on_panel_closed.bind(key)):
			panel.closed.connect(_on_panel_closed.bind(key))
	# v7.x: 玩家相位师详细面板 closed 信号 → 隐藏 overlay
	var pm_panel: Node = get_node_or_null("PopupLayer/PlayerMasterOverlay/CenterContainer/PlayerMasterPanel")
	if pm_panel and pm_panel.has_signal("closed") and not pm_panel.closed.is_connected(_on_player_master_panel_closed):
		pm_panel.closed.connect(_on_player_master_panel_closed)

# ── overlay 统一开关 ─────────────────────────────────────────
func _open_overlay(overlay: Control, panel_key: String = "") -> void:
	if overlay == null:
		print("[Main] _open_overlay: overlay is null for key=", panel_key)
		return
	_ensure_lazy_panel(panel_key)
	if DEBUG_MAIN_LOG:
		print("[Main] _open_overlay: showing overlay for key=", panel_key)
	# 先显示，再fade in
	overlay.visible = true
	# 防止子级曾被误 hide（例如旧版设置关闭只藏了 CenterContainer）
	var cc_reset: Node = overlay.get_node_or_null("CenterContainer")
	if cc_reset is Control:
		(cc_reset as Control).visible = true
	# v7.x 面板统一：打开通知收敛为 match + _notify_panel_opened 通用分发，
	# 仅保留行为特殊的面板特判（map 刷新 / backpack 性能打点 / growth 日志 / afk 显式 _open）。
	match panel_key:
		"map":
			var world_map_panel: Node = overlay.get_node_or_null("CenterContainer/WorldMapPanel")
			if world_map_panel and world_map_panel.has_method("refresh"):
				world_map_panel.refresh()
		"backpack":
			var backpack_panel: Node = overlay.get_node_or_null("BackpackVBox/CenterRow/BackpackCenter/BackpackPanel")
			if backpack_panel == null:
				backpack_panel = overlay.find_child("BackpackPanel", true, false)
			if backpack_panel and backpack_panel.has_method("on_overlay_opened"):
				backpack_panel.on_overlay_opened()
				if PerformanceMetricsManager and PerformanceMetricsManager.has_method("mark_backpack_open_ready"):
					PerformanceMetricsManager.mark_backpack_open_ready()
		"growth":
			var gp: Control = overlay.get_node_or_null("CenterContainer/GrowthPanel")
			if gp == null:
				gp = overlay.find_child("GrowthPanel", true, false)
			if gp and gp.has_method("show_panel"):
				if DEBUG_MAIN_LOG:
					print("[Main] Calling GrowthPanel.show_panel")
				gp.show_panel(null)
		"afk":
			# AFKPanel 在 _ready 中将自身 visible 置 false（依赖 _open() 控制），
			# 故 overlay 可见后必须显式调用面板 _open()，否则面板主体与 Backdrop 均不显示。
			var ap: Node = overlay.get_node_or_null("CenterContainer/AFKPanel")
			if ap and ap.has_method("_open"):
				ap._open()
		_:
			_notify_panel_opened(overlay, panel_key)
	# v7.x 面板统一：全局广播（高亮联动/统计解耦）
	if not panel_key.is_empty() and SignalBus and SignalBus.has_signal("panel_opened"):
		SignalBus.panel_opened.emit(panel_key)
	# 性能优化：非战斗中打开面板时，冻结 SubViewport 避免无谓渲染
	if panel_key != "growth":
		_freeze_subviewport_if_not_in_battle()

## v7.x 面板统一：通用打开通知。
## 按 on_overlay_opened → refresh → show_panel(null) → _refresh_all 顺序尝试，
## 覆盖 store/quest/faction/info/modification/evolution/collection/leaderboard/occupation 等
## 常规面板的打开契约，新面板无需再往 _open_overlay 加分支。
const _PANEL_NODE_NAMES := {
	"store": "StorePanel",
	"quest": "QuestPanel",
	"faction": "FactionPanel",
	"settings": "SettingsPanel",
	"info": "IntelligenceHubPanel",
	"modification": "ModificationPanel",
	"evolution": "EvolutionPanel",
	"collection": "CollectionPanel",
	"leaderboard": "LeaderboardPanel",
	"occupation": "OccupationPanel",
	# v9.x 修复：v7.x 面板统一重构时漏登——help 懒加载实例化后 _notify 查名
	# 落空早退，show_panel 永不被调，面板永远隐藏（空遮罩挡全屏无法关闭）
	"help": "HelpPanel",
}

func _notify_panel_opened(overlay: Control, panel_key: String) -> void:
	if overlay == null or panel_key.is_empty():
		return
	var panel_name: String = String(_PANEL_NODE_NAMES.get(panel_key, ""))
	if panel_name.is_empty():
		return
	var panel: Node = overlay.get_node_or_null("CenterContainer/" + panel_name)
	if panel == null:
		panel = overlay.find_child(panel_name, true, false)
	if panel == null:
		return
	# v8.x 性能：多数列表面板的刷新已从 _ready 移到 on_overlay_opened（拆帧），
	# 打开时显式调用以触发下一帧刷新，避免 LazyLoader 实例化同帧的列表构建尖峰。
	if panel.has_method("on_overlay_opened"):
		panel.on_overlay_opened()
	elif panel.has_method("refresh"):
		panel.refresh()
	elif panel.has_method("show_panel"):
		panel.show_panel(null)
	elif panel.has_method("_refresh_all"):
		panel._refresh_all()
	# 批次三 B4：情报中心首开一句话引导（面板静态实例化，_ready 在游戏启动时触发，
	# 必须挂打开路径而非面板 _ready）
	if panel_key == "info":
		FeatureUnlockPopup.show_once("intel_hub", "情报中心",
			"这里汇总进化图谱、符文图鉴与敌方情报手册——战斗中遇到看不懂的敌人，来这里查。")

func _close_overlay(overlay: Control, panel_key: String = "") -> void:
	if overlay == null:
		print("[Main] _close_overlay: overlay is null for key=", panel_key)
		return
	# AFKPanel 与 overlay 的可见性分离（_ready 强制 visible=false）。
	# 注意：此处不可调用 ap._close()——它发 closed 信号，而本函数常由 closed
	# 信号经 _on_panel_closed 触达，会形成无限递归（stack overflow）。
	# 统一走 _reset_afk_panel_visibility 复位三节点可见性，与 _open() 对称。
	if panel_key == "afk":
		_reset_afk_panel_visibility(false)
	if overlay:
		overlay.visible = false
	if panel_key != "" and bottom_function_bar:
		bottom_function_bar.notify_panel_closed(panel_key)
	# v7.x 面板统一：全局广播（高亮联动/统计解耦）
	if not panel_key.is_empty() and SignalBus and SignalBus.has_signal("panel_closed"):
		SignalBus.panel_closed.emit(panel_key)
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
		"faction":            _close_overlay(faction_overlay, "faction")
		"map":                _close_overlay(map_overlay, "map")
		"settings":           _close_overlay(settings_overlay, "settings")
		"leaderboard":        _close_overlay(leaderboard_overlay, "leaderboard")
		"backpack":           _close_overlay(backpack_overlay, "backpack")
		"growth":             _close_overlay(growth_overlay, "growth")
		"collection":         _close_overlay(collection_overlay, "collection")
		"info":               _close_overlay(intelligence_overlay, "info")
		"occupation":         _close_overlay(get_node_or_null("PopupLayer/OccupationOverlay"), "occupation")
		"modification":       _close_overlay(modification_overlay, "modification")
		"evolution":          _close_overlay(evolution_overlay, "evolution")
		"afk":                _close_overlay(afk_overlay, "afk")
		"achievement":        _close_overlay(achievement_overlay, "achievement")
		"help":               _close_overlay(help_overlay, "help")

# ── 排行榜：v7.x 面板统一，改走常驻 Overlay（与其他面板同构） ──────
func _toggle_leaderboard() -> void:
	_toggle_overlay(leaderboard_overlay, "leaderboard")

func _close_leaderboard() -> void:
	_close_overlay(leaderboard_overlay, "leaderboard")

# ── 底部仪表栏信号 ────────────────────────────────────────────
func _on_instrument_area_clicked() -> void:
	# 战前点击相位仪槽位：无操作（装配通过背包拖拽完成）
	pass

func _on_phase_level_label_clicked() -> void:
	# 点击底部相位仪等级标签 → 打开相位仪选择面板（切换相位仪）
	_open_phase_instrument_selector()

## v7.x: 打开背包并切到符文 Tab（教程引导共用入口）
func _open_backpack_runes_tab() -> void:
	_play_sfx("button")
	_open_overlay(backpack_overlay, "backpack")
	var bp: Node = backpack_overlay.get_node_or_null("BackpackVBox/CenterRow/BackpackCenter/BackpackPanel")
	if bp == null:
		bp = backpack_overlay.find_child("BackpackPanel", true, false)
	if bp and bp.has_method("switch_to_runes_tab"):
		bp.switch_to_runes_tab()

# v9.x（P2-7范围B）：_on_law_slot_clicked（主动法则选点）已随法则施放链退役移除

# ── 功能键信号 ────────────────────────────────────────────────
func _on_backpack_pressed() -> void:
	_play_sfx("button")
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("mark_backpack_open_begin"):
		PerformanceMetricsManager.mark_backpack_open_begin()
	_toggle_overlay(backpack_overlay, "backpack")

func _overlay_for_panel_key(panel_key: String) -> Control:
	match panel_key:
		"backpack": return backpack_overlay
		"quest": return quest_overlay
		"store": return store_overlay
		"growth": return growth_overlay
		"faction": return faction_overlay
		"map": return map_overlay
		"settings": return settings_overlay
		"info": return intelligence_overlay
		"achievement": return achievement_overlay
		"help": return help_overlay
		"modification": return modification_overlay
		"evolution": return evolution_overlay
		"afk": return afk_overlay
		"leaderboard": return leaderboard_overlay
		"collection": return collection_overlay
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
		# ⚠️ quest/store/faction/settings：_prune_preloaded_panels 启动释放静态实例，
		# 这四项必须走懒加载重建（v9.x 复查修复——误删导致商店等面板打不开）
		"quest":
			lazy_id = "quest"
		"store":
			lazy_id = "store"
		"faction":
			lazy_id = "faction"
		"settings":
			lazy_id = "settings"
		"growth":
			lazy_id = "growth"
		"achievement":
			lazy_id = "achievement"
		"help":
			lazy_id = "help"
		"modification":
			lazy_id = "modification"
		"evolution":
			lazy_id = "evolution"
		"collection":
			lazy_id = "collection"
		_:
			# v9.x 清理：map/leaderboard 分支确认为死分支——map 无懒加载配置且
			# WorldMapPanel 无 closed 信号；leaderboard 静态实例不在 prune 名单
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
		if is_panel_node:
			_connect_panel_closed_runtime(child, lazy_id)
			return
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


## 连接 DailyTaskManager 信号以刷新任务按钮红点角标
func _connect_quest_badge_signals() -> void:
	var dtm := get_node_or_null("/root/DailyTaskManager")
	if dtm == null:
		# 懒加载：经 ManagerLazyLoader 触发后再连
		var mll := get_node_or_null("/root/ManagerLazyLoader")
		if mll and mll.has_method("ensure_loaded"):
			mll.ensure_loaded("daily_task")
			dtm = get_node_or_null("/root/DailyTaskManager")
	if dtm == null:
		return
	if dtm.has_signal("task_completed") and not dtm.task_completed.is_connected(_refresh_quest_badge):
		dtm.task_completed.connect(_refresh_quest_badge)
	if dtm.has_signal("daily_tasks_refreshed") and not dtm.daily_tasks_refreshed.is_connected(_refresh_quest_badge):
		dtm.daily_tasks_refreshed.connect(_refresh_quest_badge)
	# 首次刷新一次
	_refresh_quest_badge()


## 刷新任务按钮红点：可领取(completed && !claimed)的任务数
func _refresh_quest_badge(_dummy = null) -> void:
	if bottom_function_bar == null or not bottom_function_bar.has_method("set_btn_badge"):
		return
	var dtm := get_node_or_null("/root/DailyTaskManager")
	if dtm == null or not dtm.has_method("get_daily_tasks"):
		return
	var claimable := 0
	for task in dtm.get_daily_tasks():
		if task.get("completed", false) and not task.get("claimed", false):
			claimable += 1
	bottom_function_bar.set_btn_badge("quest", claimable)


func _on_intelligence_open_progression(card_id: String) -> void:
	_close_overlay(intelligence_overlay, "info")
	_toggle_overlay(growth_overlay, "growth")
	var panel: Node = growth_overlay.get_node_or_null("CenterContainer/GrowthPanel")
	if panel == null:
		panel = growth_overlay.find_child("GrowthPanel", true, false)
	if panel and panel.has_method("select_card_by_id") and not card_id.is_empty():
		panel.select_card_by_id(card_id)


# v6.11: _on_blueprint_star_upgraded 回调已移除（战力星级系统②已删）

func _on_faction_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(faction_overlay, "faction")

## v6.6/v7.x: 教程引导"打开相位仪/符文面板"——改指向背包符文 Tab（独立 rune_panel 已删除）
func _on_toggle_phase_instrument_from_tutorial() -> void:
	_open_backpack_runes_tab()

## v7.x 教程引导：打开强化面板
## v8.x: 强化②（CardEnhancementPanel）已停用，养成改为自动经验升星 + 相位师技能树。
# 教程的"打开强化"重定向到成长中枢（growth_panel），那里展示强化等级/Lv.X/10，
# 且其"强化"按钮会打开相位师技能树面板——与 v8.x 养成入口一致。
# 原 enhancement_overlay 路径已断（UILazyLoader 无 "enhancement" 配置，
# _ensure_lazy_panel 会 push_error 并返回空 overlay，导致玩家无法关闭→死机）。
func _on_toggle_enhancement_from_tutorial() -> void:
	_play_sfx("button")
	_on_progression_pressed()

## v7.x 教程引导：打开改造面板（ModificationPanel）
func _on_toggle_modification_from_tutorial() -> void:
	_play_sfx("button")
	_toggle_overlay(modification_overlay, "modification")

## v9.x（P2-4 批次6）：教程中后期步骤引导（进化/势力/商店/世界地图/相位场加点）
func _on_toggle_evolution_from_tutorial() -> void:
	_play_sfx("button")
	_toggle_overlay(evolution_overlay, "evolution")

func _on_toggle_faction_from_tutorial() -> void:
	_play_sfx("button")
	_on_faction_pressed()

func _on_toggle_store_from_tutorial() -> void:
	_play_sfx("button")
	_on_store_pressed()

func _on_toggle_world_map_from_tutorial() -> void:
	_play_sfx("button")
	_on_map_pressed()

func _on_open_phase_field_from_tutorial() -> void:
	_play_sfx("button")
	_open_phase_instrument_selector()

func _on_quest_pressed() -> void:
	_toggle_overlay(quest_overlay, "quest")

## D3 2026-08-22：成就/帮助面板入口（此前无任何开启路径）
func _on_achievement_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(achievement_overlay, "achievement")

func _on_help_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(help_overlay, "help")

func _on_store_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(store_overlay, "store")

func _on_progression_pressed() -> void:
	_play_sfx("button")
	if DEBUG_MAIN_LOG:
		print("[Main] _on_progression_pressed called, growth_overlay=", growth_overlay)
	_toggle_overlay(growth_overlay, "growth")

func _on_map_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(map_overlay, "map")

func _on_settings_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(settings_overlay, "settings")

func _on_collection_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(collection_overlay, "collection")

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

# ── 挂机模式 ─────────────────────────────────────────────────
func _init_afk_manager() -> void:
	_afk_manager = AFKModeManagerScript.new()
	_afk_manager.init(self, _battle_setup)
	# 连接面板引用
	var afk_panel_node = afk_overlay.get_node_or_null("CenterContainer/AFKPanel")
	if afk_panel_node:
		if afk_panel_node.has_method("set_afk_manager"):
			afk_panel_node.set_afk_manager(_afk_manager)
		# v6.6(挂机缩略图): 注入主场景引用，供面板定位 BattleContainer 取 ViewportTexture
		if afk_panel_node.has_method("set_main_scene"):
			afk_panel_node.set_main_scene(self)

## v7.x（关卡详情"自动部署"按钮）：world_map 设的 Engine meta 触发，
## 进 main 后切 AFK 推图模式 + start_afk，从指定关自动布阵战斗。
## 用 call_deferred 调用，确保 _ready 中所有 manager 已初始化。
func _auto_start_afk_from_world_map(level: int) -> void:
	if _afk_manager == null:
		return
	# 钳制到已解锁上限，避免从未解锁关开始
	var lp = get_node_or_null("/root/LevelProgressManager")
	var max_unlocked: int = level
	if lp != null and lp.has_method("get_max_unlocked_level"):
		max_unlocked = lp.get_max_unlocked_level()
	var target_lvl: int = clampi(level, 1, maxi(1, max_unlocked))
	if GameManager != null and GameManager.has_method("set_current_level"):
		GameManager.set_current_level(target_lvl)
	# 切推图模式
	_afk_manager.set_mode(AFKModeManagerScript.Mode.PUSH)
	# 显式设推图起点：start_afk 现以 push_level 为推图起点（Bug#2 修复），
	# 不再读 GameManager.current_level，故此处须显式赋值玩家选定关。
	_afk_manager.push_level = target_lvl
	# 启动 AFK + 首战。Bug#1 修复：原仅 start_afk 不调 enter_next_battle，
	# 导致 world_map 入口挂机进入 RUNNING 后永远不开打。
	_afk_manager.start_afk()
	_afk_manager.enter_next_battle()

## v6.6(挂机): 暴露 AFK manager 给 SaveManager 桥接访问（RefCounted 非 autoload）。
## SaveManager 的 save/load/reset 经此 getter 访问 AFK 状态。
func get_afk_manager() -> AFKModeManager:
	return _afk_manager

# ── 离线挂机 ─────────────────────────────────────────────────
## v6.6(离线挂机): 初始化离线挂机管理器并检查离线奖励（延迟一帧确保 save 已加载）
func _init_offline_idle_manager() -> void:
	_offline_idle_manager = OfflineIdleManagerScript.new()
	_offline_idle_manager.init(self)
	# 延迟检查离线奖励：确保 save load（含 deferred）完成后再生效
	call_deferred("_maybe_show_offline_rewards")

## v6.6(离线挂机): 计算并弹出离线奖励（若离线时长超阈值）
func _maybe_show_offline_rewards() -> void:
	if _offline_idle_manager == null or SaveManager == null:
		return
	if not SaveManager.has_method("get_last_active_at"):
		return
	# 防重入：若已有离线奖励弹窗在显示，不再弹第二个
	if popup_layer != null:
		for c in popup_layer.get_children():
			if c is OfflineRewardDialog:
				return
	var last_active: int = SaveManager.get_last_active_at()
	var now: int = int(Time.get_unix_time_from_system())
	var result: Dictionary = _offline_idle_manager.compute_offline_rewards(last_active, now)
	if result.is_empty():
		return   # 离线不足/无时间戳，不弹
	_show_offline_reward_dialog(result)

## v6.6(离线挂机): 显示"欢迎回来"弹窗
## 必须加到 popup_layer（CanvasLayer layer=100）而非 Main 直接子节点，
## 否则会被 HudLayer(40)/PopupLayer(100) 遮挡导致玩家看不到。
func _show_offline_reward_dialog(result: Dictionary) -> void:
	var parent: Node = popup_layer if popup_layer != null else self
	var dialog := OfflineRewardDialogScript.create(parent, result)
	if dialog:
		dialog.claimed.connect(_on_offline_reward_claimed)

## v6.6(离线挂机): 玩家点领取后入账
func _on_offline_reward_claimed(rewards: Dictionary) -> void:
	if _offline_idle_manager != null:
		_offline_idle_manager.grant_rewards(rewards)

## v6.6(离线挂机): 暴露 manager（桥接/测试用）
func get_offline_idle_manager() -> OfflineIdleManager:
	return _offline_idle_manager

func _on_afk_pressed() -> void:
	_play_sfx("button")
	_toggle_overlay(afk_overlay, "afk")

# ── 战斗控制 ─────────────────────────────────────────────────
func _on_start_battle() -> void:
	_battle_setup.on_start_battle()

func _deferred_go_to_battle() -> void:
	_battle_setup.deferred_go_to_battle()

func _on_pause_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = not tree.paused
	if top_hud_bar:
		top_hud_bar.set_pause_text("继续" if tree.paused else "暂停")

# ── 撤退（放弃本场战斗，判定为失败） ───────────────────────────
# 用一个实例字段追踪当前确认框，避免重复弹出
var _retreat_confirm: Control = null

func _on_retreat_pressed() -> void:
	# 仅战斗中允许撤退（布阵/结算态点击无意义）
	var in_battle: bool = BattleManager != null and "battle_active" in BattleManager and BattleManager.battle_active
	if not in_battle:
		return
	# 已有确认框打开时不重复弹出
	if _retreat_confirm != null and is_instance_valid(_retreat_confirm):
		return
	# 暂停状态下先恢复，避免结算弹窗被暂停树卡住
	var tree := get_tree()
	if tree and tree.paused:
		tree.paused = false
		if top_hud_bar:
			top_hud_bar.set_pause_text("暂停")
	_retreat_confirm = _build_retreat_confirm_dialog()
	popup_layer.add_child(_retreat_confirm)

## 构建撤退确认对话框（自绘全屏遮罩，AcceptDialog 在 CanvasLayer 下不可显示）
func _build_retreat_confirm_dialog() -> Control:
	var overlay := Control.new()
	overlay.name = "RetreatConfirmOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	# C4/C6: 手写面板框+单态按钮（3 种红各写一遍）→ PanelStyles 工厂 + DT token
	var sb := PanelStyles.make_panel_frame(DT.COLOR_RED_DOWN)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "撤退"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", DT.COLOR_RED_DOWN)
	vbox.add_child(title)
	var body := Label.new()
	body.text = "本场战斗将判定为失败，确定撤退吗？"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.88, 0.9, 0.94, 1.0))
	vbox.add_child(body)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)
	var confirm_btn := Button.new()
	confirm_btn.text = "确认撤退"
	confirm_btn.custom_minimum_size = Vector2(120, 38)
	var c_styles := PanelStyles.make_button_styles(DT.COLOR_RED_DOWN, "danger")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		confirm_btn.add_theme_stylebox_override(state, c_styles[state])
	btn_row.add_child(confirm_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(120, 38)
	var n_styles := PanelStyles.make_button_styles(DT.COLOR_TEXT_DIM)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		cancel_btn.add_theme_stylebox_override(state, n_styles[state])
	btn_row.add_child(cancel_btn)
	# 关闭确认框
	var close := func() -> void:
		if _retreat_confirm != null and is_instance_valid(_retreat_confirm):
			_retreat_confirm.queue_free()
		_retreat_confirm = null
	confirm_btn.pressed.connect(func():
		close.call()
		# 判定战斗失败，走正常结算流程（battle_ended(false) → GameManager 失败结算）
		if BattleManager != null and BattleManager.has_method("end_battle"):
			BattleManager.end_battle(false)
	)
	cancel_btn.pressed.connect(close)
	return overlay

func _on_back_to_title() -> void:
	if SaveManager:
		SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _on_world_map() -> void:
	_open_overlay(map_overlay, "map")

# ── 关闭所有弹出面板 ─────────────────────────────────────────
## P1-8: 全量 overlay 注册表（原 _close_all_overlays 清单缺
## collection/occupation/enhancement/modification/evolution/player_master，
## 这些面板开着时按 ESC 关不掉）
func _all_overlays() -> Array:
	return [
		{"overlay": quest_overlay, "key": "quest"},
		{"overlay": store_overlay, "key": "store"},
		{"overlay": backpack_overlay, "key": "backpack"},
		{"overlay": faction_overlay, "key": "faction"},
		{"overlay": map_overlay, "key": "map"},
		{"overlay": settings_overlay, "key": "settings"},
		{"overlay": intelligence_overlay, "key": "info"},
		{"overlay": growth_overlay, "key": "growth"},
		{"overlay": afk_overlay, "key": "afk"},
		{"overlay": leaderboard_overlay, "key": "leaderboard"},
		{"overlay": collection_overlay, "key": "collection"},
		{"overlay": get_node_or_null("PopupLayer/OccupationOverlay"), "key": "occupation"},
		{"overlay": achievement_overlay, "key": "achievement"},
		{"overlay": help_overlay, "key": "help"},
		{"overlay": modification_overlay, "key": "modification"},
		{"overlay": evolution_overlay, "key": "evolution"},
		{"overlay": player_master_overlay, "key": "player_master"},
	]

## P1-8: ESC 语义——只关最上层可见 overlay（PopupLayer 子序最大者），
## 全关后战斗中再次按 ESC 切换暂停
func _close_top_overlay() -> void:
	# BU-1: 功能抽屉比 overlay 更浅——ESC 先收抽屉
	if bottom_function_bar != null \
			and bottom_function_bar.has_method("is_drawer_open") \
			and bottom_function_bar.is_drawer_open():
		bottom_function_bar.set_drawer_open(false)
		return
	var top: Control = null
	var top_key: String = ""
	var top_idx: int = -1
	if popup_layer == null:
		return
	for entry in _all_overlays():
		var ov: Control = entry.get("overlay")
		if ov == null or not ov.visible:
			continue
		var idx: int = ov.get_index()
		if idx > top_idx:
			top_idx = idx
			top = ov
			top_key = String(entry.get("key", ""))
	if top != null:
		_close_overlay(top, top_key)
		return
	# 无面板：战斗中 ESC 切换暂停（与 SPACE 一致）
	if _is_in_battle():
		_on_pause_pressed()

func _close_all_overlays() -> void:
	for entry in _all_overlays():
		var ov: Control = entry.get("overlay")
		if ov == null:
			continue
		# v6.6(挂机缩略图): 挂机运行中保持 AFK 面板可见，让战场缩略图实时显示。
		# run_start_battle_sequence 每场战斗开头会调此方法，跳过 afk_overlay 才能持续预览。
		if ov == afk_overlay and _afk_manager != null and _afk_manager.is_running:
			continue
		# AFKOverlay 与内部 AFKPanel 可见性分离（_ready 强制 visible=false），
		# 须统一复位面板/backdrop 可见性，避免下次打开时状态错乱。
		if ov == afk_overlay:
			_reset_afk_panel_visibility(false)
		ov.visible = false
	# BU-1：功能抽屉随全关一并收起（战斗开场序列调用本函数时抽屉不该残留在战场上）
	if bottom_function_bar != null and bottom_function_bar.has_method("set_drawer_open"):
		bottom_function_bar.set_drawer_open(false, false)
	if bottom_function_bar:
		bottom_function_bar.notify_panel_closed("")


## v6.6(挂机): 统一复位 AFKPanel/backdrop/panel 三个节点的可见性。
## AFKPanel._ready 强制 visible=false，其 _open()/_close() 又分别管理这三个节点，
## 故 overlay 层的开关逻辑须统一走此方法，避免 AFKOverlay.visible 与内部状态不同步。
## open=true 时设全部可见（对应 _open）；open=false 时全部隐藏（对应 _close 的可见性部分）。
func _reset_afk_panel_visibility(open: bool) -> void:
	if afk_overlay == null:
		return
	var ap: Node = afk_overlay.get_node_or_null("CenterContainer/AFKPanel")
	if not (ap is Control):
		return
	(ap as Control).visible = open
	var bd: Node = (ap as Control).get_node_or_null("Backdrop")
	if bd is Control:
		(bd as Control).visible = open
	var pn: Node = (ap as Control).get_node_or_null("Panel")
	if pn is Control:
		(pn as Control).visible = open

# ── 战场显示控制 ─────────────────────────────────────────────
func _show_battle() -> void:
	_battle_setup.show_battle()

func _get_battlefield() -> Node2D:
	return get_node_or_null("BattleContainer/SubViewportContainer/SubViewport/Battlefield") as Node2D

## 非战斗时打开/关闭 overlay，冻结/恢复 SubViewport 渲染（减少 GPU 负载）
func _is_any_overlay_open() -> bool:
	for o in [backpack_overlay, quest_overlay,
			store_overlay, faction_overlay,
			map_overlay, settings_overlay, afk_overlay]:
		if o and o.visible:
			return true
	return false

func _is_in_battle() -> bool:
	return BattleManager != null and BattleManager.battle_active

func _freeze_subviewport_if_not_in_battle() -> void:
	if _is_in_battle():
		return
	# v6.6(挂机缩略图): 挂机运行中保持战斗视口持续渲染（UPDATE_ALWAYS），
	# 供 AFK 面板的战场缩略图镜像 ViewportTexture。
	if _afk_manager != null and _afk_manager.is_running:
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
func _on_battle_ended_clear_pending(player_won: bool) -> void:
	_reward.on_battle_ended_clear_pending(player_won)

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

# 2026-08-22：_on_blueprint_unlocked 已删除——信号已随蓝图体系移除，处理器为死代码。
# v9.x（P2-7范围B）：_on_active_law_cast_at（法则施放演出+效果应用）已随法则系统退役移除。

# ── 战斗结果 ─────────────────────────────────────────────────
func show_battle_result(player_won: bool) -> void:
	_reward.show_battle_result(player_won)

func _on_result_confirmed() -> void:
	_reward.on_result_confirmed()

func _clear_battlefield_units() -> void:
	_reward.clear_battlefield_units()

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

## v7.x: 打开玩家相位师详细面板（9维战力分解 + 星级 + Lv + 构成明细）
func _open_player_master_panel() -> void:
	_play_sfx("button")
	if player_master_overlay == null:
		return
	var panel: Node = player_master_overlay.get_node_or_null("CenterContainer/PlayerMasterPanel")
	if panel and panel.has_method("open_panel"):
		panel.open_panel()
	player_master_overlay.visible = true
	var cc: Node = player_master_overlay.get_node_or_null("CenterContainer")
	if cc is Control:
		(cc as Control).visible = true

## v7.x: 玩家相位师详细面板关闭 → 隐藏 overlay
func _on_player_master_panel_closed() -> void:
	if player_master_overlay != null:
		player_master_overlay.visible = false

func _on_phase_selector_selected(_instrument_id: String, selector: Node) -> void:
	if is_instance_valid(selector):
		selector.queue_free()
	# 刷新底部仪表栏
	if bottom_instrument_bar and bottom_instrument_bar.has_method("refresh"):
		bottom_instrument_bar.refresh()

# ── 新系统管理器集成 ─────────────────────────────────────────────

## 启动新手教程（如果是新游戏）
## v7.x(A5): 接线 tutorial_overlay —— 新存档首次进入主界面时实例化覆盖层。
## overlay 自身在 _ready 检查 should_show_tutorial，教程已结束（FREEDOM_MODE）会自 queue_free。
## 完成首步后 current_step 推进，后续不会再弹（除非 settings 里 reset）。
func _start_tutorial_if_needed() -> void:
	var tutorial_manager = get_node_or_null("/root/TutorialProgressionManager")
	if tutorial_manager == null or not tutorial_manager.has_method("should_show_tutorial"):
		return
	if not tutorial_manager.should_show_tutorial():
		return
	# 仅在 current_step == NONE（全新存档，从未看过教程）时触发，避免每次进主界面都弹。
	if "current_step" in tutorial_manager and int(tutorial_manager.current_step) != 0:
		return
	# 推进到首步，让 overlay 取得到内容。
	if tutorial_manager.has_method("get_tutorial_content"):
		tutorial_manager.get_tutorial_content()  # 副作用：NONE → INTRO_WELCOME
	# 实例化 overlay 到 HudLayer（z_index 高，覆盖战场下方 UI）。
	var TutorialOverlayScene := load("res://scenes/ui/tutorial_overlay.tscn") as PackedScene
	if TutorialOverlayScene == null:
		return
	var overlay := TutorialOverlayScene.instantiate()
	var hud := get_node_or_null("HudLayer")
	if hud != null:
		hud.add_child(overlay)
	else:
		add_child(overlay)

## 初始化日常任务
func _init_daily_tasks() -> void:
	# v7.x 性能：DailyTaskManager 延迟加载，进入主界面时确保实例化
	var _mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if _mll and _mll.has_method("ensure_loaded"):
		_mll.ensure_loaded("daily_task")
	var task_manager = get_node_or_null("/root/DailyTaskManager")
	if task_manager:
		task_manager.refresh_daily_tasks()

## 集成新系统：实例化 NewSystemsIntegration 节点
## 该节点连接 SignalBus 信号，负责：
##   - 战斗胜利 → 更新日常任务进度（DailyTaskManager.BATTLE_VICTORY）
##   - 战斗胜利 → 检查成就（first_victory 等）
##   - 单位受伤/死亡 → 战斗反馈（伤害数字、屏幕震动）
##   - 相位法则施放 → 特效
##   - 蓝图解锁 → 更新卡牌收集状态
func _integrate_new_systems() -> void:
	# 防重复：已实例化则跳过
	if get_node_or_null("/root/NewSystemsIntegration"):
		return
	var script = load("res://managers/new_systems_integration.gd")
	if script == null:
		push_error("[Main] 无法加载 NewSystemsIntegration 脚本")
		return
	var node = script.new()
	node.name = "NewSystemsIntegration"
	# 挂到场景树根节点，模拟 autoload 行为（/root/NewSystemsIntegration 可访问）
	var root = get_tree().root
	if root.is_node_ready():
		root.add_child(node)
	else:
		root.call_deferred("add_child", node)

func _exit_tree() -> void:
	if _deploy_toast:
		_deploy_toast.cleanup()
		_deploy_toast = null
	if _save_toast:
		_save_toast.cleanup()
		_save_toast = null

# ── 工具函数 ─────────────────────────────────────────────────
