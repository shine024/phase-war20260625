extends Control
class_name AFKPanel
## 挂机模式面板 UI
## v36 实机验收改版：选关槽位退役（本关循环/向前推进双模式）——不再选关，
## 循环=停靠关反复刷，推进=胜利后向下一关行进（关间行进节拍由管理器驱动）。

signal closed

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

const _HIGHLIGHT := DT.COLOR_ACCENT_MINT
const _NORMAL_FONT := Color(0.5, 0.5, 0.6, 0.8)
const _SELECTED_BG := Color(0, 0.18, 0.32, 0.95)
const _NORMAL_BG := Color(0.06, 0.1, 0.18, 0.85)

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: Panel = $Panel

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
## v32.0 B1-4: 观看战场按钮（隐藏面板不停机）
var _watch_btn: Button = null

# 子面板引用
var _afk_manager: AFKModeManager = null
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

	# v7.x 面板统一：青色签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）。
	# 注意：本面板的 Backdrop/Panel/自身三层可见性协议特殊（main.gd 依赖），保持不变。
	var accent := DT.COLOR_ACCENT_CYAN
	panel.add_theme_stylebox_override("panel", PanelStyles.make_panel_frame_textured(accent))
	var chrome = PanelChrome.attach_to($Panel/MarginContainer/MainVBox, "自动哨戒", accent, "自动作战")
	chrome.closed.connect(_on_close)
	start_btn.pressed.connect(_on_start)
	stop_btn.pressed.connect(_on_stop)
	cycle_btn.pressed.connect(func(): _set_mode(AFKModeManager.Mode.CYCLE))
	push_btn.pressed.connect(func(): _set_mode(AFKModeManager.Mode.PUSH))
	# v24.2 → v36: 模式语义就地解释（选关退役后的新口径）
	cycle_btn.tooltip_text = "本关循环：反复出击卡车当前停靠的关卡（适合刷材料）"
	push_btn.tooltip_text = "向前推进：胜利后向下一关行进，直到失败或第 100 关\n关与关之间有行进时间（车队赶路）；起点为当前停靠关\n世界地图的\"自动部署\"入口同样从停靠关开推"

	# 初始化模式按钮样式
	_set_mode_button_style(cycle_btn, true)
	_set_mode_button_style(push_btn, false)

	# v36：选关槽位退役——整行隐藏（.tscn 结构保留，回滚开关=删掉这一行）
	var slots_hbox := get_node_or_null("Panel/MarginContainer/MainVBox/SlotsHBox")
	if slots_hbox != null:
		slots_hbox.visible = false

	# v6.6(挂机): 实例化关卡信息（get_level_display_name 是实例方法）
	# v7.x 性能：用全局单例，避免每次打开挂机面板重建 100 关字典
	_level_info = _LevelInfoScript.get_shared()
	# v6.6(挂机缩略图): 缓存战斗 SubViewport 引用（延迟到首次 refresh 时再查，此时 BattleContainer 可能还未就绪）
	call_deferred("_cache_battle_viewport")
	# v32.0 B1-4: 观看战场按钮（定位转向 B1 观战体验批）
	_build_watch_btn()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if visible:
			_on_close()
			# P0: 不 consume 会让 main._close_top_overlay 再关一层（ESC 一次关两层）
			get_viewport().set_input_as_handled()


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
## 反映读档恢复的 mode/push_level/accumulated_rewards。
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
	# B4: 首次打开挂机模式给一句话说明（学黑猴首解锁引导，仅弹一次）
	# v36：文案随"选关退役"改版
	FeatureUnlockPopup.show_once("afk_mode", "自动哨戒",
		"基地车自动作战：本关循环刷材料，或向前推进直到失败。离线收益回来一键领取。")
	_update_stats_display()


## 循环模式无关联槽位时，自动从 GameManager.current_level 填入第一个空槽位。
func _auto_fill_slot_from_current_level() -> void:
	if not _afk_manager:
		return
	if _afk_manager.mode != AFKModeManager.Mode.CYCLE:
		return
	if _afk_manager.get_valid_slot_count() > 0:
		return  # 已有关联槽位，不覆盖用户设置
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var lvl: int = int(gm.get("current_level"))
	if lvl < 1:
		return
	_afk_manager.set_slot(0, lvl)


func _close() -> void:
	visible = false
	backdrop.visible = false
	panel.visible = false
	closed.emit()


func _on_close() -> void:
	_close()


# ── v32.0 B1-4: 观看战场（挂机观战入口）──
## 隐藏挂机面板但不停机，玩家全屏直接看 AFK 战斗。AFK 战斗本就在面板后全屏运行
##（缩略图是活的 ViewportTexture），管理器生命周期与面板无关（stop_afk 只由 StopBtn
## 触发）；回来走底部功能栏「挂机」重开面板。配合 B1-1 的倍速/跳过按钮即可全程控场。
func _build_watch_btn() -> void:
	var preview_area: Panel = get_node_or_null("Panel/MarginContainer/MainVBox/PreviewArea") as Panel
	if preview_area == null:
		return
	_watch_btn = Button.new()
	_watch_btn.text = "▶ 观看战场"
	_watch_btn.tooltip_text = "隐藏本面板、全屏观看挂机战斗（挂机不会停止）\n从底部功能栏「挂机」回到本面板"
	_watch_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_watch_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_watch_btn.offset_left = -136
	_watch_btn.offset_top = -40
	_watch_btn.offset_right = -10
	_watch_btn.offset_bottom = -10
	_watch_btn.pressed.connect(_on_watch_battle)
	preview_area.add_child(_watch_btn)


func _on_watch_battle() -> void:
	var pm := get_node_or_null("/root/PerformanceMetricsManager")
	if pm != null and pm.has_method("count_event"):
		pm.count_event("afk_watch")
	_close()
	SignalBus.show_toast.emit("挂机战斗继续进行中——从底部功能栏「挂机」回到面板")


# ── 模式选择（v36：本关循环 / 向前推进，选关槽位已退役）──

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
	# v24.2: 切模式立即刷新统计行（推图模式显示起点，循环模式显示关联数）
	_update_stats_display()


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
	# ui-review·易用性：可交互处必须有多个状态（hover 亮边、pressed 同色）
	var hover_sb: StyleBoxFlat = style.duplicate()
	hover_sb.bg_color = style.bg_color.lightened(0.10)
	hover_sb.border_color = style.border_color.lightened(0.18)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", style.duplicate())


# ── 开始/停止 ──

func _on_start() -> void:
	if not _afk_manager:
		return

	# v36：选关槽位退役——两种模式都不再依赖槽位关联（循环/推进起点=卡车停靠关）
	var success = _afk_manager.start_afk()
	if not success:
		_notify("无法开始挂机")
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
		AFKModeManager.State.TRAVELING:
			# v36：关间行进节拍（胜利后赶往下一关）
			start_btn.visible = false
			stop_btn.visible = true
			if _afk_manager:
				status_label.text = "状态: 行进中——驶向第 %d 关" % int(_afk_manager._pending_level)
			else:
				status_label.text = "状态: 行进中"
	# v6.6(挂机缩略图): 状态切换时刷新缩略图可见性
	_refresh_battle_preview()


func _on_level_completed(level: int, won: bool) -> void:
	# 每关结束后刷新累计奖励显示
	_update_stats_display()
	# v6.6(挂机缩略图): 每关结束重新取一次纹理，保持新鲜
	_refresh_battle_preview()


## v32.3 A5：战斗中暂存的结算（战斗结束再弹，防"进关瞬间蹦结算"）
var _pending_settlement: Dictionary = {}
var _pending_settlement_connected: bool = false

## 战斗占位判定：交战中或出征战报黑幕还在屏上
func _is_battle_busy() -> bool:
	var bm: Node = get_node_or_null("/root/BattleManager")
	if bm != null and "battle_active" in bm and bool(bm.get("battle_active")):
		return true
	return SortieInterstitial.is_showing()


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
	# v32.3 A5：战斗中（含出征过场）只暂存，battle_ended 后再弹——玩家点出击进关
	# 的路上不再蹦结算窗
	if _is_battle_busy():
		_pending_settlement = rewards
		if not _pending_settlement_connected:
			_pending_settlement_connected = true
			var sb: Node = get_node_or_null("/root/SignalBus")
			if sb != null and sb.has_signal("battle_ended"):
				sb.battle_ended.connect(_on_battle_ended_flush_settlement)
		return
	# 弹出结算汇总弹窗（显示完整掉落明细 + 战绩）
	_show_settlement_dialog(rewards)


## v32.3 A5：战斗结束后补弹暂存的挂机结算
func _on_battle_ended_flush_settlement(_won: bool) -> void:
	if _pending_settlement.is_empty():
		return
	var rewards := _pending_settlement
	_pending_settlement = {}
	_show_settlement_dialog.call_deferred(rewards)


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

func _update_stats_display() -> void:
	if not _afk_manager:
		return

	wins_label.text = "胜: %d" % _afk_manager.total_wins
	losses_label.text = "负: %d" % _afk_manager.total_losses
	# 挂机运行中显示累计奖励件数；待机时按模式显示目标关（v36：起点/目标=卡车停靠关）
	if _afk_manager.is_running and not _afk_manager.accumulated_rewards.is_empty():
		var total_count: int = 0
		for key in _afk_manager.accumulated_rewards:
			total_count += int(_afk_manager.accumulated_rewards[key])
		slots_used_label.text = "累计: %d 件" % total_count
	elif _afk_manager.mode == AFKModeManager.Mode.PUSH:
		slots_used_label.text = "推进起点: 第 %d 关" % _push_start_hint()
		slots_used_label.tooltip_text = "向前推进从当前停靠关开始\n胜利后自动向下一关行进（关间有赶路时间）；失败后可从进度续推"
	else:
		slots_used_label.text = "循环目标: 第 %d 关" % _parked_hint()
		slots_used_label.tooltip_text = "本关循环反复出击卡车当前停靠的关卡（刷材料）\n换关=移动基地行军到新关卡后重启挂机"


## v36：循环目标预览（=停靠关，与 start_afk 的 _resolve_parked_level 同口径）
func _parked_hint() -> int:
	var bm := get_node_or_null("/root/BunkerManager")
	if bm != null and bm.has_method("get_parked_level"):
		return clampi(int(bm.get_parked_level()), 1, 100)
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and "current_level" in gm:
		return clampi(int(gm.get("current_level")), 1, 100)
	return 1


## 推进起点预览：v36 口径=停靠关（胜利后 +1 推进，失败重试同关）
func _push_start_hint() -> int:
	return _parked_hint()
