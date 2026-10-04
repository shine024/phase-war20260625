extends Control
## v6.20 教程聚光指向组件（ui-review「点读机」便捷性）：
## 教程文字框指向哪个按钮，就把那个按钮"点亮"——
##   全屏暗幕挖孔（目标区域保持原亮）+ 金色脉冲环圈住目标 + 旁挂悬浮提示条（缓动呼吸）。
## 纯视觉层：mouse_filter 全 IGNORE，目标按钮仍由玩家直接点击（配合教程覆盖层的
## press_advances 接线，点真按钮等效点教程"下一步"）。
##
## 用法（静态工厂，挂到教程覆盖层根——画在导航框之下、游戏画面之上）：
##   var sp := TutorialSpotlight.attach(overlay_root, target_btn, "点这里打开卡仓")
##   sp.dismiss()  # 或随宿主一起 queue_free（本组件是宿主子节点，自动回收）
## 目标离树/隐藏自动暂停显示；重入树自动恢复。缩放/布局变化每帧跟随（热区随窗口重排）。

const DT = preload("res://resources/design_tokens.gd")

const DIM_COLOR := Color(0, 0, 0, 0.55)   # 对齐 COLOR_BACKDROP 标准遮罩档
const RING_COLOR := Color(0.984, 0.749, 0.141)   # DT.COLOR_AMBER_SOFT 同值（金脉冲）
const HOLE_PAD := 10.0                    # 挖孔四周外扩
const RING_WIDTH := 3.0
const PULSE_PERIOD := 1.1                 # 秒/次（motion_reduce 时静止）

var _target: Control = null
var _tip: Label = null
var _tip_back: PanelContainer = null
var _tip_base := ""    # 不带箭头的基底文案（箭头随上下方位每帧拼）
var _dim_alpha := DIM_COLOR.a   # 暗幕浓度（教学步 0.55 / v6.39 挂起指路标 0.30 柔和档）
var _ring_sb := StyleBoxFlat.new()   # 环描边缓存体（_draw 只改 border_color 透明度）
var _pulse := 0.0
var _hole := Rect2()
var _follow_ph := 0.0


## 静态工厂：创建聚光层并挂到 host（插在最前=画在 host 其余子节点之下）。
## host 应是教程覆盖层根（full-rect）；target 必须已在树中。失败回退 null。
## dim_alpha：暗幕浓度，<=0 用默认档（教学步 0.55）。
static func attach(host: Control, target: Control, tip_text: String, dim_alpha: float = -1.0) -> Control:
	if host == null or target == null or not target.is_inside_tree():
		return null
	var sp: Control = load("res://scripts/ui/tutorial_spotlight.gd").new()
	sp.name = "TutorialSpotlight"
	sp.set_anchors_preset(Control.PRESET_FULL_RECT)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(sp)
	host.move_child(sp, 0)
	sp._setup(target, tip_text, dim_alpha)
	return sp


## ── v6.39 朝露式指路（点播段挂起等待的「下一步去哪」）──────────────
## 常驻指路标 = 独立覆盖层宿主「TutorialStepPointer」+ 柔和聚光（暗幕 0.30 不压屏）。
## 宿主挂在 root 最后（画在最上），与教程 overlay 平级——overlay 收起后仍驻留，
## 由 overlay 重现（_ready）/ TPM tutorial_pointer_requested(false) / 场景退树收编。
## 幂等：亮之前先收旧标。解析失败由调用侧保证不调本函数（目标 null/不可见跳过）。
## v6.41.1 指路标宿主序号（进程内唯一）：旧宿主 queue_free 帧末才消失，若新宿主复用
## 同名会被 Godot 撞名静默改名（@Control@N），此后按名消散永远找不到它=旧标跨步堆积、
## 点目标按钮也不消散（实机三标并存根因，tests/_tmp_v642_pointer_probe.gd 实证）。
static var _pointer_serial: int = 0


static func show_step_pointer(root: Node, target: Control, tip_text: String) -> void:
	if root == null or not root.is_inside_tree():
		return
	dismiss_step_pointer(root)
	var host := Control.new()
	_pointer_serial += 1
	host.name = "TutorialStepPointer_%d" % _pointer_serial
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(host)
	attach(host, target, tip_text, 0.30)


static func dismiss_step_pointer(root: Node) -> void:
	if root == null or not root.is_inside_tree():
		return
	# owned=false：指路标宿主由本工厂代码构建，无场景 owner。
	# 通配匹配：兼容 v6.41.1 前的精确名宿主与唯一名后缀宿主（v6.41.1 前同帧撞名
	# 改名的 @Control@N 宿主救不回，随会话结束自然消亡）。
	for n in root.find_children("TutorialStepPointer*", "Control", true, false):
		n.queue_free()


## 聚光目标解析（教程 overlay 与指路标共用）：
## 基地链=truck_base 热区（get_hotspot_button_for_key）；主场景链=底栏抽屉
## （get_button_for_key，growth 工位在底栏键名=progression）。找不到回 null。
static func resolve_target(from: Node, key: String) -> Control:
	if from == null or key.is_empty() or not from.is_inside_tree():
		return null
	var host: Node = from
	while host != null:
		if host.has_method("get_hotspot_button_for_key"):
			var hb: Button = host.get_hotspot_button_for_key(key)
			if hb != null:
				return hb
		host = host.get_parent()
	var bar_key := "progression" if key == "growth" else key
	for n in from.get_tree().root.find_children("BottomFunctionBar", "Control", true, false):
		if n.has_method("get_button_for_key"):
			var bb: BaseButton = n.get_button_for_key(bar_key)
			if bb != null:
				return bb
	return null


func _init() -> void:
	_ring_sb.bg_color = Color(0, 0, 0, 0)
	_ring_sb.set_border_width_all(int(RING_WIDTH))
	_ring_sb.set_corner_radius_all(4)
	_ring_sb.content_margin_left = 0.0
	_ring_sb.content_margin_right = 0.0
	_ring_sb.content_margin_top = 0.0
	_ring_sb.content_margin_bottom = 0.0


func _setup(target: Control, tip_text: String, dim_alpha: float = -1.0) -> void:
	_target = target
	_tip_base = tip_text if tip_text != "" else "点这里"
	if dim_alpha > 0.0:
		_dim_alpha = dim_alpha
	# 悬浮提示条：深底金边小胶囊 + 箭头字符指向目标（放在挖孔上方，不够空间则下方）
	_tip_back = PanelContainer.new()
	_tip_back.name = "TipBack"
	_tip_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_back.z_index = 10
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.94)
	sb.border_color = RING_COLOR
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)   # chip 档
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	_tip_back.add_theme_stylebox_override("panel", sb)
	_tip = Label.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	_tip.add_theme_color_override("font_color", Color(0.99, 0.92, 0.75))
	_tip.text = _tip_base
	_tip_back.add_child(_tip)
	add_child(_tip_back)
	set_process(true)


func dismiss() -> void:
	queue_free()


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	var active := _target.is_visible_in_tree() and is_visible_in_tree()
	if not active:
		if _tip_back.visible:
			_tip_back.visible = false
		return
	if not _tip_back.visible:
		_tip_back.visible = true
	_pulse = fmod(_pulse + delta, PULSE_PERIOD)
	_follow_ph = fmod(_follow_ph + delta, 2.4)
	_relayout()
	queue_redraw()


## 每帧跟随目标（热区随布局重排/窗口缩放自动跟）
func _relayout() -> void:
	var own := Rect2(Vector2.ZERO, size)
	# 目标全局矩形 → 本组件本地坐标（宿主带偏移/缩放时也对）
	var xf := get_global_transform().affine_inverse()
	var gr := _target.get_global_rect()
	var lp := xf * gr.position
	_hole = Rect2(lp - Vector2(HOLE_PAD, HOLE_PAD),
			gr.size * Vector2(xf.get_scale()) + Vector2(HOLE_PAD, HOLE_PAD) * 2.0)
	_hole = _hole.intersection(own)
	if _hole.size.x <= 1.0 or _hole.size.y <= 1.0:
		_tip_back.visible = false
		return
	# 提示条：优先挖孔上方（箭头 ▼ 指向下方的目标），顶空不足放下方（▲）
	var above := _hole.position.y >= 66.0
	var ts := _tip_back.get_combined_minimum_size()
	_tip.text = _tip_base + (" ▼" if above else "▲ ")
	var tx: float = clampf(_hole.get_center().x - ts.x * 0.5, 8.0, own.size.x - ts.x - 8.0)
	var ty: float = (_hole.position.y - ts.y - 8.0) if above else (_hole.end.y + 8.0)
	if not DT.is_motion_reduce():
		ty += sin(_follow_ph * TAU) * 3.0   # 轻呼吸浮动
	_tip_back.position = Vector2(tx, ty)


func _draw() -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		return
	if _hole.size.x <= 1.0 or _hole.size.y <= 1.0:
		return
	var own := Rect2(Vector2.ZERO, size)
	var dim := Color(DIM_COLOR.r, DIM_COLOR.g, DIM_COLOR.b, _dim_alpha)
	# 暗幕=四条挖孔外矩形（孔内保持原亮）
	draw_rect(Rect2(own.position, Vector2(own.size.x, _hole.position.y)), dim)
	draw_rect(Rect2(Vector2(own.position.x, _hole.end.y), Vector2(own.size.x, own.end.y - _hole.end.y)), dim)
	draw_rect(Rect2(Vector2(own.position.x, _hole.position.y), Vector2(_hole.position.x - own.position.x, _hole.size.y)), dim)
	draw_rect(Rect2(Vector2(_hole.end.x, _hole.position.y), Vector2(own.end.x - _hole.end.x, _hole.size.y)), dim)
	# 金色脉冲环（motion_reduce=恒亮不闪）
	var k := 0.62 + 0.38 * sin(_pulse / PULSE_PERIOD * TAU)
	if DT.is_motion_reduce():
		k = 0.9
	_ring_sb.border_color = Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, 0.35 + 0.65 * k)
	draw_style_box(_ring_sb, _hole)
