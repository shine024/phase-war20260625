extends RefCounted
class_name DotVfxManager
## v9.x: 单位级 DOT 持续视觉管理器（单位身上 Sprite 贴图，跟着单位移动）
##
## 给 burn/chem/emp/nano 四种 DOT 挂持续视觉：单位身上一个 Sprite2D 贴图 + ADD 混合脉动，
## DOT 结束自动移除。同一单位同一类型只挂一个（meta 标记防重复）。
##
## 设计：
## 1. Sprite 作为单位子节点，跟着单位移动，单位死亡 queue_free 自动清理（零泄漏）
## 2. 贴图 ADD 混合 + Tween 脉动（缩放/透明度呼吸），比静态贴图生动
## 3. 贴图缺失回退程序化（Polygon2D 色环），永远有视觉
## 4. 12 单位 × 4 类型最多 48 个 Sprite，性能可控
##
## 接入点（module_effect_handler.gd）：
##   _apply_burn/chem/emp/nano_on_hit → attach_dot_vfx(target, type)
##   _tick_dot_damage                 → refresh_dot_vfx(unit) 清理过期

const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const DT = preload("res://resources/design_tokens.gd")

# v9.2: 共享 ADD 混合材质（lazy 单例）——5 处 attach_dot_vfx 原本每次 new CanvasItemMaterial，
# DOT 上百次 attach/detach 造成 GC 压力。ADD 材质无状态可全局共享（与 vfx_impact_factory._add_mat 同范式）。
static var _shared_add_mat: CanvasItemMaterial = null

static func _get_add_mat() -> CanvasItemMaterial:
	if _shared_add_mat == null:
		_shared_add_mat = CanvasItemMaterial.new()
		_shared_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_add_mat

# 4 种 DOT 的配置：节点名、贴图路径、回退色、目标尺寸（贴图宽度像素）
const DOT_CONFIGS: Dictionary = {
	"burn": {
		"node_name": "DotVfxBurn",
		"tex_path": "res://assets/effects/dot/dot_burn.png",
		"fallback_color": Color(1.0, 0.4, 0.1, 0.7),
		"target_width": 80.0,
		"y_offset": -10.0,  # 火焰在脚下偏下
	},
	"chem": {
		"node_name": "DotVfxChem",
		"tex_path": "res://assets/effects/dot/dot_chem.png",
		"fallback_color": Color(0.3, 1.0, 0.2, 0.65),
		"target_width": 90.0,
		"y_offset": -15.0,  # 毒雾在身周偏上
	},
	"emp": {
		"node_name": "DotVfxEmp",
		"tex_path": "res://assets/effects/dot/dot_emp.png",
		"fallback_color": Color(0.75, 0.35, 1.0, 0.7),
		"target_width": 70.0,
		"y_offset": -25.0,  # 电弧在身上偏上
	},
	"nano": {
		"node_name": "DotVfxNano",
		"tex_path": "res://assets/effects/dot/dot_nano.png",
		"fallback_color": Color(0.2, 0.9, 1.0, 0.65),
		"target_width": 85.0,
		"y_offset": -15.0,  # 纳米光点在身周
	},
}

# 贴图缓存（避免每次 attach 都 load）
static var _tex_cache: Dictionary = {}

## 挂载 DOT 持续视觉（单位身上 Sprite）。同一单位同一类型只挂一个（meta 标记防重复）。
## unit: 受 DOT 的单位；dot_type: "burn"/"chem"/"emp"/"nano"
static func attach_dot_vfx(unit: Node, dot_type: String) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not DOT_CONFIGS.has(dot_type):
		return
	if DT.is_motion_reduce():
		return  # 减动效：跳过持续视觉
	var cfg: Dictionary = DOT_CONFIGS[dot_type]
	var node_name: String = cfg["node_name"]
	# 防重复：已有同类型视觉则不重建
	if unit.has_node(node_name):
		return  # 已挂载，刷新时机由 refresh 控制
	# 加载贴图（带缓存）
	var tex: Texture2D = _get_texture(dot_type)
	# 创建视觉节点
	var vfx: Node2D = null
	if tex != null:
		vfx = Sprite2D.new()
		(vfx as Sprite2D).texture = tex
		var tw: float = float(tex.get_width())
		var s: float = cfg["target_width"] / tw if tw > 0.0 else 1.0
		(vfx as Sprite2D).scale = Vector2(s, s)
		(vfx as Sprite2D).modulate = Color(1.0, 1.0, 1.0, 0.85)
		# ADD 混合（发光感）——v9.2: 复用共享材质
		(vfx as Sprite2D).material = _get_add_mat()
	else:
		# 回退：程序化色环（Polygon2D）
		vfx = _make_fallback_ring(cfg["fallback_color"], cfg["target_width"] * 0.5)
	vfx.name = node_name
	vfx.position = Vector2(0, cfg["y_offset"])
	vfx.z_index = 25  # 盖在单位身上
	# 脉动动画（缩放呼吸，让持续视觉不死板）
	_start_pulse(vfx)
	unit.add_child(vfx)
	# v9.1 类型特定动态 aura（让 4 种 DOT 各有独特动态特征）
	_attach_dynamic_aura(vfx, dot_type)


## v9.1 按 DOT 类型附加动态特征（火焰环/毒液环/六边形脉冲/电弧闪烁）。
## 挂在 vfx 主节点下，vfx queue_free 时自动清理。
static func _attach_dynamic_aura(vfx: Node2D, dot_type: String) -> void:
	match dot_type:
		"burn": _attach_burn_aura(vfx)
		"chem": _attach_chem_aura(vfx)
		"nano": _attach_nano_aura(vfx)
		"emp": _attach_emp_aura(vfx)


## 火焰旋转环（橙红，快速旋转）
static func _attach_burn_aura(dot_node: Node2D) -> void:
	var ring := Polygon2D.new()
	var segments := 12
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * 18.0)
	ring.polygon = pts
	ring.position = Vector2(0, -2)
	ring.color = Color(1.0, 0.5, 0.15, 0.45)
	ring.material = _get_add_mat()  # v9.2: 复用共享 ADD 材质
	dot_node.add_child(ring)
	var tw := ring.create_tween()
	tw.set_loops()
	tw.tween_property(ring, "rotation", TAU, 2.0).set_trans(Tween.TRANS_LINEAR)


## 毒液环（绿色，反向慢转）
static func _attach_chem_aura(dot_node: Node2D) -> void:
	var ring := Polygon2D.new()
	var segments := 10
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(ang), sin(ang)) * 16.0)
	ring.polygon = pts
	ring.position = Vector2(0, -4)
	ring.color = Color(0.35, 1.0, 0.25, 0.40)
	ring.material = _get_add_mat()  # v9.2: 复用共享 ADD 材质
	dot_node.add_child(ring)
	var tw := ring.create_tween()
	tw.set_loops()
	tw.tween_property(ring, "rotation", -TAU, 3.0).set_trans(Tween.TRANS_LINEAR)


## 六边形脉冲（青蓝，快速呼吸）
static func _attach_nano_aura(dot_node: Node2D) -> void:
	var hex := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := TAU * float(i) / 6.0 + PI / 6.0
		pts.append(Vector2(cos(ang), sin(ang)) * 20.0)
	hex.polygon = pts
	hex.position = Vector2(0, -3)
	hex.color = Color(0.2, 0.9, 1.0, 0.40)
	hex.material = _get_add_mat()  # v9.2: 复用共享 ADD 材质
	dot_node.add_child(hex)
	var tw := hex.create_tween()
	tw.set_loops()
	tw.tween_property(hex, "scale", Vector2(1.25, 1.25), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(hex, "scale", Vector2(0.75, 0.75), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## 电弧闪烁（紫色，随机透明度抖动）
static func _attach_emp_aura(dot_node: Node2D) -> void:
	var arc := Line2D.new()
	arc.width = 2.0
	arc.default_color = Color(0.85, 0.6, 1.0, 1.0)
	arc.joint_mode = Line2D.LINE_JOINT_ROUND
	arc.add_point(Vector2(-10, -8))
	arc.add_point(Vector2(-3, 2))
	arc.add_point(Vector2(5, -4))
	arc.add_point(Vector2(10, 8))
	arc.position = Vector2(0, -6)
	dot_node.add_child(arc)
	var tw := arc.create_tween()
	tw.set_loops()
	tw.tween_property(arc, "modulate:a", 0.15, 0.06)
	tw.tween_property(arc, "modulate:a", 1.0, 0.06)
	tw.tween_property(arc, "modulate:a", 0.25, 0.06)
	tw.tween_property(arc, "modulate:a", 1.0, 0.06)
	tw.tween_interval(0.12)


## 刷新单位的所有 DOT 视觉：过期的移除，激活的保留。
## 在 _tick_dot_damage 每次结算时调用（节流 0.25s 一次，开销可忽略）。
## emp 无 _xxx_until meta（它是即时 debuff + ECM meta），单独按 _ecm_debuffed_until 判断。
static func refresh_dot_vfx(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	# 4 种 DOT 的过期判断（meta → until 时间戳）
	var states: Array = [
		{"type": "burn", "until_meta": "_burn_until"},
		{"type": "chem", "until_meta": "_chem_until"},
		{"type": "nano", "until_meta": "_nano_until"},
		{"type": "emp", "until_meta": "_ecm_debuffed_until"},  # EMP 走 ECM debuff 时效
	]
	for st in states:
		var dot_type: String = st["type"]
		var cfg: Dictionary = DOT_CONFIGS.get(dot_type, {})
		if cfg.is_empty():
			continue
		var node_name: String = cfg["node_name"]
		var has_node: bool = unit.has_node(node_name)
		# 判断 DOT 是否仍在激活（until 时间未过期）
		var active: bool = false
		var until_meta: String = st["until_meta"]
		if unit.has_meta(until_meta):
			var until_val: Variant = unit.get_meta(until_meta)
			# until 可能是秒（float）或毫秒（int，ECM 用 now_msec + 4000）
			var until_f: float = float(until_val)
			# ECM 用毫秒，其他用秒——简单判断：>1e6 视为毫秒
			if until_f > 1e6:
				active = now * 1000.0 < until_f
			else:
				active = now < until_f
		if not active and has_node:
			# 过期：移除视觉节点
			var node: Node = unit.get_node(node_name)
			if node != null and is_instance_valid(node):
				node.queue_free()
		# active 但无节点：不在此重建（重建在 attach_dot_vfx 命中时触发，refresh 只负责清理）


## 获取贴图（带缓存）。缺失返回 null（调用方走回退）。
static func _get_texture(dot_type: String) -> Texture2D:
	if _tex_cache.has(dot_type):
		return _tex_cache[dot_type]
	var cfg: Dictionary = DOT_CONFIGS.get(dot_type, {})
	if cfg.is_empty():
		return null
	var path: String = cfg.get("tex_path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		_tex_cache[dot_type] = null  # 缓存 null 避免重复 exists 查询
		return null
	var tex: Texture2D = load(path)
	_tex_cache[dot_type] = tex
	return tex


## 程序化回退色环（无贴图时）。空心环 + ADD 混合。
static func _make_fallback_ring(color: Color, radius: float) -> Node2D:
	var poly := Polygon2D.new()
	var segments := 24
	var pts := PackedVector2Array()
	for i in range(segments):
		var ang := (TAU * i) / segments
		pts.append(Vector2(cos(ang), sin(ang)) * radius)
	poly.polygon = pts
	poly.color = color
	poly.material = _get_add_mat()  # v9.2: 复用共享 ADD 材质
	return poly


## 脉动动画（缩放 0.85↔1.15 循环呼吸，透明度微变）。让持续视觉不死板。
static func _start_pulse(vfx: Node2D) -> void:
	var tw := vfx.create_tween()
	tw.set_loops()  # 无限循环，节点 queue_free 时自动停止
	tw.tween_property(vfx, "scale", vfx.scale * 1.15, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(vfx, "scale", vfx.scale * 0.85, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
