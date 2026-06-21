extends Control
class_name AFKPanel
## 挂机模式面板 UI
## 管理 4 个 slot 关卡关联、模式选择、开始/停止挂机

signal closed

const _HIGHLIGHT := Color(0, 0.94, 0.7, 1.0)
const _NORMAL_FONT := Color(0.5, 0.5, 0.6, 0.8)
const _SELECTED_BG := Color(0, 0.18, 0.32, 0.95)
const _NORMAL_BG := Color(0.06, 0.1, 0.18, 0.85)

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: Panel = $Panel
@onready var close_btn: Button = $Panel/MarginContainer/MainVBox/HeaderHBox/CloseBtn

# Slot 节点
@onready var slot_labels: Array[Label] = [
	$Panel/MarginContainer/MainVBox/SlotsHBox/Slot0/SlotLayout/SlotLabel0,
	$Panel/MarginContainer/MainVBox/SlotsHBox/Slot1/SlotLayout/SlotLabel1,
	$Panel/MarginContainer/MainVBox/SlotsHBox/Slot2/SlotLayout/SlotLabel2,
	$Panel/MarginContainer/MainVBox/SlotsHBox/Slot3/SlotLayout/SlotLabel3,
]
@onready var slot_panels: Array[Panel] = [
	$Panel/MarginContainer/MainVBox/SlotsHBox/Slot0,
	$Panel/MarginContainer/MainVBox/SlotsHBox/Slot1,
	$Panel/MarginContainer/MainVBox/SlotsHBox/Slot2,
	$Panel/MarginContainer/MainVBox/SlotsHBox/Slot3,
]

# 模式按钮
@onready var cycle_btn: Button = $Panel/MarginContainer/MainVBox/ModeRow/CycleRadio
@onready var push_btn: Button = $Panel/MarginContainer/MainVBox/ModeRow/PushRadio

# 操作按钮
@onready var start_btn: Button = $Panel/MarginContainer/MainVBox/StartBtn
@onready var stop_btn: Button = $Panel/MarginContainer/MainVBox/StopBtn

# 状态标签
@onready var status_label: Label = $Panel/MarginContainer/MainVBox/StatsHBox/StatusLabel
@onready var wins_label: Label = $Panel/MarginContainer/MainVBox/StatsHBox/WinsLabel
@onready var losses_label: Label = $Panel/MarginContainer/MainVBox/StatsHBox/LossesLabel
@onready var slots_used_label: Label = $Panel/MarginContainer/MainVBox/StatsHBox/SlotsUsedLabel

# v6.6(挂机缩略图): 战场预览
@onready var battle_preview: TextureRect = $Panel/MarginContainer/MainVBox/PreviewArea/BattlePreview
@onready var preview_label: Label = $Panel/MarginContainer/MainVBox/PreviewArea/PreviewLabel
## 缓存的战斗 SubViewport（取 ViewportTexture 的源）
var _battle_viewport: SubViewport = null

# 子面板引用
var _afk_manager: AFKModeManager = null
var _level_selector: AFKLevelSelector = null
var _current_editing_slot: int = -1
## 主场景引用（用于定位 BattleContainer 路径）
var _main_scene: Node = null

# v6.6(挂机): 关卡信息实例缓存（get_level_display_name 是实例方法，不能静态调用）
const _LevelInfoScript = preload("res://data/level_information.gd")
var _level_info: LevelInformation = null


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	close_btn.pressed.connect(_on_close)
	start_btn.pressed.connect(_on_start)
	stop_btn.pressed.connect(_on_stop)
	cycle_btn.pressed.connect(func(): _set_mode(AFKModeManager.Mode.CYCLE))
	push_btn.pressed.connect(func(): _set_mode(AFKModeManager.Mode.PUSH))
	
	# 初始化模式按钮样式
	_set_mode_button_style(cycle_btn, true)
	_set_mode_button_style(push_btn, false)
	
	# 初始化 slot 样式
	for pnl in slot_panels:
		_apply_slot_style(pnl, false)
	
	# 绑定 slot 点击
	for i in range(4):
		var idx = i
		slot_panels[idx].gui_input.connect(_on_slot_gui_input.bind(idx))
	
	# 预加载关卡选择器
	ResourceLoader.load_threaded_request("res://scenes/ui/afk_level_selector.tscn")

	# v6.6(挂机): 实例化关卡信息（get_level_display_name 是实例方法）
	_level_info = _LevelInfoScript.new()
	# v6.6(挂机缩略图): 缓存战斗 SubViewport 引用（延迟到首次 refresh 时再查，此时 BattleContainer 可能还未就绪）
	call_deferred("_cache_battle_viewport")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if visible:
			_on_close()


func set_afk_manager(manager: AFKModeManager) -> void:
	_afk_manager = manager
	if manager:
		# 断开旧连接防止重复
		if manager.state_changed.is_connected(_on_afk_state_changed):
			manager.state_changed.disconnect(_on_afk_state_changed)
		if manager.level_completed.is_connected(_on_level_completed):
			manager.level_completed.disconnect(_on_level_completed)
		if manager.afk_settled.is_connected(_on_afk_settled):
			manager.afk_settled.disconnect(_on_afk_settled)

		manager.state_changed.connect(_on_afk_state_changed)
		manager.level_completed.connect(_on_level_completed)
		manager.afk_settled.connect(_on_afk_settled)
	_update_stats_display()


## v6.6(挂机缩略图): 注入主场景引用（用于定位 BattleContainer）
func set_main_scene(main_node: Node) -> void:
	_main_scene = main_node
	_cache_battle_viewport()


## v6.6(挂机存档): 读档加载 AFK 状态后由 SaveManager 调用，刷新面板显示。
## 反映读档恢复的 slots/mode/push_level/accumulated_rewards。
func refresh_after_load() -> void:
	if _afk_manager == null:
		return
	# 同步模式按钮样式到读档的 mode
	match _afk_manager.mode:
		AFKModeManager.Mode.CYCLE:
			_set_mode_button_style(cycle_btn, true)
			_set_mode_button_style(push_btn, false)
		AFKModeManager.Mode.PUSH:
			_set_mode_button_style(cycle_btn, false)
			_set_mode_button_style(push_btn, true)
	_update_slot_display()
	_update_stats_display()


## v6.6(挂机缩略图): 缓存战斗 SubViewport（ViewportTexture 的源）
func _cache_battle_viewport() -> void:
	if _battle_viewport != null and is_instance_valid(_battle_viewport):
		return
	var root: Node = get_tree().root if get_tree() != null else null
	if root == null:
		return
	# main 场景挂在场景树根下，BattleContainer 是其子节点
	# 通过 _main_scene 引用或回退遍历根子节点查找
	var search_root: Node = _main_scene if _main_scene != null else null
	if search_root == null:
		for c in root.get_children():
			if c.has_node("BattleContainer"):
				search_root = c
				break
	if search_root == null:
		return
	_battle_viewport = search_root.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport") as SubViewport


## v6.6(挂机缩略图): 刷新战场缩略图——从战斗视口取 ViewportTexture 赋给 TextureRect。
## 仅在挂机运行中显示缩略图；待机/失败态显示占位文字。
func _refresh_battle_preview() -> void:
	if battle_preview == null or preview_label == null:
		return
	var running: bool = _afk_manager != null and _afk_manager.is_running
	if not running:
		battle_preview.visible = false
		battle_preview.texture = null
		preview_label.visible = true
		return
	# 运行中：尝试取战斗视口纹理
	if _battle_viewport == null or not is_instance_valid(_battle_viewport):
		_cache_battle_viewport()
	if _battle_viewport == null:
		battle_preview.visible = false
		preview_label.text = "战场未就绪"
		preview_label.visible = true
		return
	var tex: ViewportTexture = _battle_viewport.get_texture()
	if tex == null:
		battle_preview.visible = false
		preview_label.text = "战场未就绪"
		preview_label.visible = true
		return
	battle_preview.texture = tex
	battle_preview.visible = true
	preview_label.visible = false


func _open() -> void:
	visible = true
	backdrop.visible = true
	panel.visible = true
	_update_slot_display()
	_update_stats_display()


func _close() -> void:
	visible = false
	backdrop.visible = false
	panel.visible = false
	closed.emit()


func _on_close() -> void:
	_close()


# ── Slot 关卡关联 ──

func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _afk_manager and _afk_manager.is_running:
			return  # 挂机中不可编辑
		
		_current_editing_slot = slot_idx
		_show_level_selector(slot_idx)


func _show_level_selector(slot_idx: int) -> void:
	# 异步加载关卡选择器
	if _level_selector == null:
		var resource = ResourceLoader.load_threaded_get("res://scenes/ui/afk_level_selector.tscn")
		if resource is PackedScene:
			_level_selector = resource.instantiate()
			get_tree().root.add_child(_level_selector)
	
	if _level_selector == null:
		# 同步加载作为 fallback
		var scene = load("res://scenes/ui/afk_level_selector.tscn")
		if scene:
			_level_selector = scene.instantiate()
			get_tree().root.add_child(_level_selector)
	
	if _level_selector:
		_level_selector.level_selected.connect(_on_level_selected)
		_level_selector.cancelled.connect(_on_level_selector_cancel)
		_level_selector.show_selector(self, slot_idx)


func _on_level_selected(level: int) -> void:
	if _current_editing_slot < 0 or _current_editing_slot > 3:
		return
	if _afk_manager:
		_afk_manager.set_slot(_current_editing_slot, level)
	_update_slot_display(_current_editing_slot)
	_current_editing_slot = -1


func _on_level_selector_cancel() -> void:
	_current_editing_slot = -1


# ── 模式选择 ──

func _set_mode(m: AFKModeManager.Mode) -> void:
	if not _afk_manager:
		return
	_afk_manager.set_mode(m)
	match m:
		AFKModeManager.Mode.CYCLE:
			_set_mode_button_style(cycle_btn, true)
			_set_mode_button_style(push_btn, false)
		AFKModeManager.Mode.PUSH:
			_set_mode_button_style(cycle_btn, false)
			_set_mode_button_style(push_btn, true)


func _set_mode_button_style(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_color_override("font_color", _HIGHLIGHT)
		var style := btn.get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			(style as StyleBoxFlat).bg_color = _HIGHLIGHT
	else:
		btn.add_theme_color_override("font_color", _NORMAL_FONT)
		var style := btn.get_theme_stylebox("normal")
		if style is StyleBoxFlat:
			(style as StyleBoxFlat).bg_color = _NORMAL_BG


# ── 开始/停止 ──

func _on_start() -> void:
	if not _afk_manager:
		return
	
	var success = _afk_manager.start_afk()
	if success:
		_update_stats_display()
		# 立即进入第一关
		_afk_manager.enter_next_battle()


func _on_stop() -> void:
	if _afk_manager:
		_afk_manager.stop_afk()
		_update_stats_display()


# ── 信号回调 ──

func _on_afk_state_changed(new_state: int) -> void:
	match new_state:
		AFKModeManager.State.IDLE:
			start_btn.visible = true
			stop_btn.visible = false
			status_label.text = "状态: 待机中"
		AFKModeManager.State.RUNNING:
			start_btn.visible = false
			stop_btn.visible = true
			status_label.text = "状态: 运行中"
		AFKModeManager.State.FAILED:
			start_btn.visible = true
			stop_btn.visible = false
			status_label.text = "状态: 已失败"
	# v6.6(挂机缩略图): 状态切换时刷新缩略图可见性
	_refresh_battle_preview()


func _on_level_completed(level: int, won: bool) -> void:
	# 每关结束后刷新累计奖励显示
	_update_stats_display()
	# v6.6(挂机缩略图): 每关结束重新取一次纹理，保持新鲜
	_refresh_battle_preview()


## v6.6(挂机): 挂机结束（停止/失败）时收到累计奖励总账
func _on_afk_settled(rewards: Dictionary) -> void:
	_update_stats_display()
	# v6.6(挂机缩略图): 停止后恢复占位文字（is_running 已为 false，_refresh 会切回 PreviewLabel）
	_refresh_battle_preview()
	# 若有累计奖励，在状态栏汇总显示（最多列出条目数）
	if rewards.is_empty():
		status_label.text = "状态: 已结束（无奖励）"
	else:
		var total_items := rewards.size()
		var total_count: int = 0
		for key in rewards:
			total_count += int(rewards[key])
		status_label.text = "状态: 已结束 | 累计 %d 种 / %d 件" % [total_items, total_count]


# ── 显示更新 ──

func _update_slot_display(update_one: int = -1) -> void:
	if not _afk_manager:
		return
	
	for i in range(4):
		if update_one >= 0 and i != update_one:
			continue
		
		var level = _afk_manager.get_slot_level(i)
		var lbl = slot_labels[i]
		var pnl = slot_panels[i]
		
		if level > 0:
			# 尝试获取关卡显示名（v6.6: 用实例调用，get_level_display_name 是实例方法）
			var name := ""
			if _level_info and _level_info.has_method("get_level_display_name"):
				name = _level_info.get_level_display_name(level)
			if not name.is_empty():
				lbl.text = name
			else:
				lbl.text = "第 %d 关" % level
			_apply_slot_style(pnl, true)
		else:
			lbl.text = "未关联"
			_apply_slot_style(pnl, false)


func _apply_slot_style(pnl: Panel, active: bool) -> void:
	if active:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.08, 0.15, 0.9)
		style.border_color = Color(0, 0.65, 1, 0.3)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		pnl.add_theme_stylebox_override("panel", style)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.05, 0.08, 0.6)
		style.border_color = Color(0.15, 0.25, 0.4, 0.2)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		pnl.add_theme_stylebox_override("panel", style)


func _update_stats_display() -> void:
	if not _afk_manager:
		return

	wins_label.text = "胜: %d" % _afk_manager.total_wins
	losses_label.text = "负: %d" % _afk_manager.total_losses
	var count = _afk_manager.get_valid_slot_count()
	# 挂机运行中显示累计奖励件数；待机时显示关联槽位数
	if _afk_manager.is_running and not _afk_manager.accumulated_rewards.is_empty():
		var total_count: int = 0
		for key in _afk_manager.accumulated_rewards:
			total_count += int(_afk_manager.accumulated_rewards[key])
		slots_used_label.text = "累计: %d 件" % total_count
	else:
		slots_used_label.text = "已关联: %d/4关" % count
