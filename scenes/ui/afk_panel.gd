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
## 缓存的 AtlasTexture：TextureRect 不支持 region，用 atlas 包装 ViewportTexture 取交战带子区域
var _preview_atlas: AtlasTexture = null

# 子面板引用
var _afk_manager: AFKModeManager = null
var _level_selector: AFKLevelSelector = null
var _current_editing_slot: int = -1
## 主场景引用（用于定位 BattleContainer 路径）
var _main_scene: Node = null

# v6.6(挂机): 关卡信息实例缓存（get_level_display_name 是实例方法，不能静态调用）
const _LevelInfoScript = preload("res://data/level_information.gd")
const _AFKSettlementDialog = preload("res://scenes/ui/afk_settlement_dialog.gd")
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
## region_rect 动态对齐战场实际部署带（敌我单位所在 y 范围），
## 让缩略图精准框选交战行而非视口中段（单位在视口约 80% 处，非 50%）。
const _PREVIEW_LANE_PADDING: float = 60.0  # 上下各留 60px，确保单位不被贴边裁切
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
	# TextureRect 无 region_enabled / region_rect（那是 Sprite2D 属性，赋值会报
	# "Invalid assignment of property 'region_enabled'"）。取交战带子区域改用
	# AtlasTexture 包装 ViewportTexture：region 设为部署带 y 范围即可框选交战行。
	var tex_w: float = float(tex.get_width())
	var tex_h: float = float(tex.get_height())
	if tex_w <= 0 or tex_h <= 0:
		# ViewportTexture 首帧尺寸可能为 0，回退用 SubViewport.size；仍为 0 则显示全图
		tex_w = float(_battle_viewport.size.x)
		tex_h = float(_battle_viewport.size.y)
	if tex_w > 0 and tex_h > 0:
		if _preview_atlas == null:
			_preview_atlas = AtlasTexture.new()
		_preview_atlas.atlas = tex
		_preview_atlas.region = _compute_battle_region(tex_w, tex_h)
		battle_preview.texture = _preview_atlas
	battle_preview.visible = true
	preview_label.visible = false


## 根据战场实际部署带计算缩略图 region_rect。
## 取 Battlefield.get_deploy_y_bounds() 的 y 范围，上下各加 padding，
## clamp 到纹理边界，返回以交战行为中心的矩形。
func _compute_battle_region(tex_w: float, tex_h: float) -> Rect2:
	var y_min: float = 0.0
	var y_max: float = tex_h
	if _main_scene != null and _main_scene.has_method("_get_battlefield"):
		var bf: Node = _main_scene._get_battlefield()
		if bf != null and bf.has_method("get_deploy_y_bounds"):
			var bounds: Vector2 = bf.get_deploy_y_bounds()
			# bounds = (deploy_y_min, deploy_y_max)，上下各加 padding
			y_min = clampf(bounds.x - _PREVIEW_LANE_PADDING, 0.0, tex_h)
			y_max = clampf(bounds.y + _PREVIEW_LANE_PADDING, 0.0, tex_h)
			# 若 clamp 后高度过小（部署带极窄），向下扩展到至少 140px
			if y_max - y_min < 140.0:
				var mid: float = (y_min + y_max) * 0.5
				y_min = clampf(mid - 70.0, 0.0, tex_h)
				y_max = clampf(mid + 70.0, 0.0, tex_h)
	# 宽度取纹理实际宽度，保证不超界
	# 最终保险：确保 y_min < y_max（clamp 可能导致反转）
	if y_min >= y_max:
		y_min = 0.0
		y_max = tex_h
	return Rect2(0.0, y_min, tex_w, maxf(1.0, y_max - y_min))


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
	# 首次打开才实例化 + 连接信号；后续复用同一实例，避免重复 connect 报错。
	if _level_selector == null:
		var resource = ResourceLoader.load_threaded_get("res://scenes/ui/afk_level_selector.tscn")
		if resource is PackedScene:
			_level_selector = resource.instantiate()

		if _level_selector == null:
			# 同步加载作为 fallback
			var scene = load("res://scenes/ui/afk_level_selector.tscn")
			if scene:
				_level_selector = scene.instantiate()

		if _level_selector:
			# 挂到 PopupLayer（layer=100），与项目其它弹出层一致，
			# 确保 z-order 高于主场景且不被 HudLayer(40) 遮挡。
			var popup: Node = get_node_or_null("/root/Main/PopupLayer")
			if popup == null:
				popup = get_tree().root  # 回退兜底
			popup.add_child(_level_selector)
			_level_selector.level_selected.connect(_on_level_selected)
			_level_selector.cancelled.connect(_on_level_selector_cancel)

	if _level_selector:
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
	# 使用独立 StyleBox 副本（duplicate），避免 get_theme_stylebox 返回的主题共享资源
	# 被直接修改而污染所有使用该主题的按钮。
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	if active:
		btn.add_theme_color_override("font_color", _HIGHLIGHT)
		style.bg_color = _HIGHLIGHT
		style.border_color = _HIGHLIGHT
	else:
		btn.add_theme_color_override("font_color", _NORMAL_FONT)
		style.bg_color = _NORMAL_BG
		style.border_color = Color(0.2, 0.45, 0.75, 0.4)
	btn.add_theme_stylebox_override("normal", style)


# ── 开始/停止 ──

func _on_start() -> void:
	if not _afk_manager:
		return

	# 循环模式必须至少关联 1 个 slot；推图模式依赖 push_level（始终有值），
	# 但若推图关卡也未解锁，start_afk 内部会 clamp，仍可能进入。
	var valid_count := _afk_manager.get_valid_slot_count()
	if _afk_manager.mode == AFKModeManager.Mode.CYCLE and valid_count == 0:
		_notify("请先在槽位关联至少一关")
		return

	var success = _afk_manager.start_afk()
	if not success:
		_notify("无法开始挂机，请检查槽位关联")
		return
	_update_stats_display()
	# 立即进入第一关
	_afk_manager.enter_next_battle()


## 通过 SignalBus.show_toast 弹出提示（ToastManager 已连接该信号）。
func _notify(message: String) -> void:
	var sb: Node = get_node_or_null("/root/SignalBus")
	if sb != null and sb.has_signal("show_toast"):
		sb.show_toast.emit(message)


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
	# 状态栏汇总（保留原文字提示，供面板未关闭时查看）
	var total_count: int = 0
	for key in rewards:
		total_count += int(rewards[key])
	if rewards.is_empty():
		status_label.text = "状态: 已结束（无奖励）"
	else:
		status_label.text = "状态: 已结束 | 累计 %d 种 / %d 件" % [rewards.size(), total_count]
	# 弹出结算汇总弹窗（显示完整掉落明细 + 战绩）
	_show_settlement_dialog(rewards)


## 弹出挂机结算弹窗。挂到 PopupLayer（layer=100），确保覆盖所有 UI。
func _show_settlement_dialog(rewards: Dictionary) -> void:
	# 判定是否为失败结束：当前状态为 FAILED
	var failed: bool = _afk_manager != null and _afk_manager.state == AFKModeManager.State.FAILED
	var wins: int = _afk_manager.total_wins if _afk_manager != null else 0
	var losses: int = _afk_manager.total_losses if _afk_manager != null else 0
	var result := {
		"wins": wins,
		"losses": losses,
		"rewards": rewards,
		"failed": failed,
	}
	# 定位 PopupLayer：优先 _main_scene，回退遍历场景树根
	var popup: Node = null
	if _main_scene != null:
		popup = _main_scene.get_node_or_null("PopupLayer")
	if popup == null:
		var root: Node = get_tree().root if get_tree() != null else null
		if root != null:
			for c in root.get_children():
				if c.has_node("PopupLayer"):
					popup = c.get_node("PopupLayer")
					break
	if popup == null:
		popup = get_tree().root  # 最终回退
	_AFKSettlementDialog.create(popup, result)


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
