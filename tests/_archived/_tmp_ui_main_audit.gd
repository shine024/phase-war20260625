extends Node
## v6.14 UI 主场景审计（临时探针③）：真实 main.tscn 上下文逐个开关 17 个 overlay。
## 抓两类问题：①真实挂载几何下的越界；②空壳面板（overlay 开了但面板没内容——
## 同成就面板 9e5b7a9 启动竞态空壳一类）。安全：不调 save_game；结束还原存档由外部脚本负责。

const VW := 1280.0
const VH := 720.0
const TOL := 8.0

var _log: FileAccess
var _report: Array = []
var _main: Node = null

func _l(line: String) -> void:
	print(line)
	if _log == null:
		_log = FileAccess.open("user://ui_main_audit.log", FileAccess.WRITE)
	if _log != null:
		_log.store_string(line + "\n")
		_log.flush()

func _ready() -> void:
	_l("===== UI MAIN AUDIT START =====")
	await get_tree().process_frame
	# 尝试把窗口/视口钉到 1280x720（headless 默认 visible_rect 是 1280x1280，会污染居中几何）
	get_window().size = Vector2i(int(VW), int(VH))
	await get_tree().process_frame
	_l("[INFO] window.size=%s visible_rect=%s" % [str(get_window().size), str(get_viewport().get_visible_rect())])

	# 真实读档（与 _tmp_panel_shots 先例一致）
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")

	var ps: PackedScene = load("res://scenes/main.tscn")
	if ps == null:
		_l("[LOAD-FAIL] main.tscn")
		get_tree().quit(1)
		return
	_main = ps.instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main  # steam_cap 先例：禁用 change_scene
	for i in 45:
		await get_tree().process_frame

	# 清掉启动期自动弹的离线奖励弹窗（会遮挡测量）
	var popup_layer: Node = _main.get_node_or_null("PopupLayer")
	if popup_layer != null:
		for c in popup_layer.get_children():
			if c.get_script() != null and str((c.get_script() as Script).resource_path).ends_with("offline_reward_dialog.gd"):
				c.queue_free()
				_l("[INFO] 已清除启动期离线奖励弹窗")
	await get_tree().process_frame

	# 逐 overlay 开关
	var overlays: Array = _main.call("_all_overlays")
	for entry in overlays:
		var ov: Control = entry.get("overlay")
		var key: String = str(entry.get("key", ""))
		if ov == null:
			_report.append("[NULL] overlay 注册表存在 null 项: " + key)
			continue
		await _audit_overlay(ov, key)
		_main.call("_close_all_overlays")
		for i in 8:
			await get_tree().process_frame

	_l("===== REPORT =====")
	for r in _report:
		_l(str(r))
	_l("===== END (%d findings) =====" % _report.size())
	_main.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)

func _audit_overlay(ov: Control, key: String) -> void:
	_l("[RUN] >>> overlay '%s'" % key)
	_main.call("_toggle_overlay", ov, key)
	for i in 20:
		await get_tree().process_frame
	if not ov.visible:
		_report.append("[FAIL-OPEN] overlay '%s' toggle 后仍不可见" % key)
		return
	# 面板节点：子树里带脚本且文件名含 panel 的最大 Control
	var panel := _find_panel(ov)
	var score := 0
	if panel != null:
		score = _content_score(panel)
		_l("[INFO] panel=%s(%s) content_score=%d" % [panel.name, panel.get_class(), score])
		if score < 3:
			_report.append("[EMPTY] overlay '%s' 面板疑似空壳（content_score=%d，面板=%s）" % [key, score, panel.name])
	else:
		_report.append("[EMPTY?] overlay '%s' 未找到带脚本的 panel 节点" % key)
	_find_overflows(ov, "overlay:" + key)

func _find_panel(root: Node) -> Control:
	var best: Control = null
	var best_area := 0.0
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if not (n is Control):
			continue
		var c := n as Control
		if c.get_script() == null:
			continue
		var sp := str((c.get_script() as Script).resource_path)
		if not sp.contains("panel"):
			continue
		var area := c.size.x * c.size.y
		if area > best_area:
			best_area = area
			best = c
	return best

func _content_score(root: Node) -> int:
	var score := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is Label and str((n as Label).text).strip_edges() != "":
			score += 1
		elif n is RichTextLabel and (n as RichTextLabel).get_parsed_text().strip_edges() != "":
			score += 1
		elif n is Button and str((n as Button).text).strip_edges() != "":
			score += 1
		elif n is TextureRect and (n as TextureRect).texture != null:
			score += 1
		elif n is ItemList and (n as ItemList).item_count > 0:
			score += 1
		elif n is Tree and (n as Tree).get_root() != null:
			score += 1
	return score

func _inside_clipper(c: Control) -> bool:
	var cur: Node = c
	while cur != null:
		if cur is ScrollContainer:
			return true
		if cur is Control and (cur as Control).clip_contents:
			return true
		cur = cur.get_parent()
	return false

func _find_overflows(root: Node, tag: String) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if not (n is Control) or not is_instance_valid(n):
			continue
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		var r := c.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if _inside_clipper(c):
			continue
		var over_r: float = r.end.x - (VW + TOL)
		var over_b: float = r.end.y - (VH + TOL)
		var over_l: float = -TOL - r.position.x
		var over_t: float = -TOL - r.position.y
		var worst: float = max(max(over_r, over_b), max(over_l, over_t))
		if worst <= 0.0:
			continue
		_report.append("[OVERFLOW] %s :: %s (%s) rect=%s over=%.0fpx" % [tag, c.name, c.get_class(), str(r), worst])
