extends Node
## v6.14 UI 全面板越界审计（临时探针）：实例化 scenes/ui 全部 .tscn，
## 测量所有可见 Control 的 global rect 是否超出 1280x720 视口。
## 安全：启动即断开 SaveManager about_to_quit 自动存档，全程不写存档。

const VW := 1280.0
const VH := 720.0
const TOL := 8.0
## 组件级场景（行/格/条目，独立实例化仅验证不炸，越界无意义）
const COMPONENTS := [
	"backpack_card_item", "store_item_row", "store_instrument_row",
	"resource_slot_item", "phase_slot", "buff_fold_card",
	"unit_hover_info", "resource_bar",
]

var _report: Array = []
var _log: FileAccess

func _l(line: String) -> void:
	print(line)
	if _log == null:
		_log = FileAccess.open("user://ui_bounds_audit.log", FileAccess.WRITE)
	if _log != null:
		_log.store_string(line + "\n")
		_log.flush()

func _ready() -> void:
	# 安全闸：断开程序化退出的强制存档（字符串式 API，与 SaveManager 的 connect 同形）
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null:
		var cb := Callable(sm, "_on_about_to_quit")
		if get_tree().has_signal("about_to_quit") and get_tree().is_connected("about_to_quit", cb):
			get_tree().disconnect("about_to_quit", cb)
			_l("[BoundsAudit] about_to_quit 自动存档已断开")
		else:
			_l("[BoundsAudit] about_to_quit 未连接（has_signal=%s）" % str(get_tree().has_signal("about_to_quit")))
	var scenes: Array = []
	var dir := DirAccess.open("res://scenes/ui")
	for f in dir.get_files():
		if f.ends_with(".tscn"):
			scenes.append("res://scenes/ui/" + f)
	var lb_dir := DirAccess.open("res://scenes/ui/leaderboard")
	if lb_dir != null:
		for f in lb_dir.get_files():
			if f.ends_with(".tscn"):
				scenes.append("res://scenes/ui/leaderboard/" + f)
	scenes.sort()
	for p in scenes:
		await _audit_scene(p)
	_l("===== BOUNDS AUDIT REPORT =====")
	for line in _report:
		_l(str(line))
	_l("===== END (%d findings) =====" % _report.size())
	get_tree().quit(0)

func _audit_scene(path: String) -> void:
	var fname := path.get_file().get_basename()
	var is_comp := false
	for c in COMPONENTS:
		if fname.begins_with(c) or fname.ends_with("_row"):
			is_comp = true
	_l("[RUN] >>> " + fname)
	var ps: PackedScene = load(path)
	if ps == null:
		_l("[LOAD-FAIL] " + path)
		_report.append("[LOAD-FAIL] " + path)
		return
	# 镜像真实挂载：main.tscn 的 overlay 都是全屏 CenterContainer 按面板最小尺寸居中
	# 注意：默认点锚（0,0）+ 显式 size；在树外调全屏 preset 进树后会被根窗口覆盖
	var frame := CenterContainer.new()
	frame.name = "AuditFrame"
	frame.size = Vector2(VW, VH)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(frame)
	var node: Node = ps.instantiate()
	frame.add_child(node)
	for i in 6:
		await get_tree().process_frame
	if node.has_method("show_panel") and not fname.begins_with("growth_panel"):
		node.call("show_panel")
	elif node.has_method("refresh"):
		node.call("refresh")
	for i in 4:
		await get_tree().process_frame
	var findings := _walk(node, is_comp)
	if findings.is_empty():
		_l("[OK] %s (%s)" % [fname, "component" if is_comp else "panel"])
		_report.append("[OK] %s" % fname)
	else:
		for f in findings:
			_l("[OVERFLOW] %s :: %s" % [fname, f])
			_report.append("[OVERFLOW] %s :: %s" % [fname, f])
	node.queue_free()
	frame.queue_free()
	await get_tree().process_frame

func _inside_clipper(c: Control) -> bool:
	var cur: Node = c
	while cur != null:
		if cur is ScrollContainer:
			return true
		if cur is Control and (cur as Control).clip_contents:
			return true
		cur = cur.get_parent()
	return false

func _walk(root: Node, is_comp: bool) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if not (n is Control):
			continue
		if not is_instance_valid(n):
			continue
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if _inside_clipper(c):
			continue  # 滚动/裁剪区内内容属正常设计
		var over_r: float = r.end.x - (VW + TOL)
		var over_b: float = r.end.y - (VH + TOL)
		var over_l: float = -TOL - r.position.x
		var over_t: float = -TOL - r.position.y
		var worst: float = max(max(over_r, over_b), max(over_l, over_t))
		if worst <= 0.0:
			continue
		var script := ""
		if c.get_script() != null:
			script = (c.get_script() as Script).resource_path.get_file()
		out.append("%s (%s) rect=%s over=%.0fpx script=%s%s" % [
			c.name, c.get_class(), str(r), worst, script,
			" [component]" if is_comp else ""])
	return out
