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
var _ring_sb := StyleBoxFlat.new()   # 环描边缓存体（_draw 只改 border_color 透明度）
var _pulse := 0.0
var _hole := Rect2()
var _follow_ph := 0.0


## 静态工厂：创建聚光层并挂到 host（插在最前=画在 host 其余子节点之下）。
## host 应是教程覆盖层根（full-rect）；target 必须已在树中。失败回退 null。
static func attach(host: Control, target: Control, tip_text: String) -> Control:
	if host == null or target == null or not target.is_inside_tree():
		return null
	var sp: Control = load("res://scripts/ui/tutorial_spotlight.gd").new()
	sp.name = "TutorialSpotlight"
	sp.set_anchors_preset(Control.PRESET_FULL_RECT)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(sp)
	host.move_child(sp, 0)
	sp._setup(target, tip_text)
	return sp


func _init() -> void:
	_ring_sb.bg_color = Color(0, 0, 0, 0)
	_ring_sb.set_border_width_all(int(RING_WIDTH))
	_ring_sb.set_corner_radius_all(4)
	_ring_sb.content_margin_left = 0.0
	_ring_sb.content_margin_right = 0.0
	_ring_sb.content_margin_top = 0.0
	_ring_sb.content_margin_bottom = 0.0


func _setup(target: Control, tip_text: String) -> void:
	_target = target
	_tip_base = tip_text if tip_text != "" else "点这里"
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
	# 暗幕=四条挖孔外矩形（孔内保持原亮）
	draw_rect(Rect2(own.position, Vector2(own.size.x, _hole.position.y)), DIM_COLOR)
	draw_rect(Rect2(Vector2(own.position.x, _hole.end.y), Vector2(own.size.x, own.end.y - _hole.end.y)), DIM_COLOR)
	draw_rect(Rect2(Vector2(own.position.x, _hole.position.y), Vector2(_hole.position.x - own.position.x, _hole.size.y)), DIM_COLOR)
	draw_rect(Rect2(Vector2(_hole.end.x, _hole.position.y), Vector2(own.end.x - _hole.end.x, _hole.size.y)), DIM_COLOR)
	# 金色脉冲环（motion_reduce=恒亮不闪）
	var k := 0.62 + 0.38 * sin(_pulse / PULSE_PERIOD * TAU)
	if DT.is_motion_reduce():
		k = 0.9
	_ring_sb.border_color = Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, 0.35 + 0.65 * k)
	draw_style_box(_ring_sb, _hole)
