extends Control
## 全 UI 面板体检探针（窗口化跑一次自存报告+截图自退出）
## 检测三类问题（v6.19.3 结算四键重叠/菜单按钮失效同族缺陷）：
##   A. 同尺度可点控件被后绘制者大面积盖住（≥70%，尺寸比<3x）——按钮排布算错类 bug
##   B. 可点控件 ≥20% 面积出视口；非交互可见控件整体出视口（>20x20 才报）
##   C. 可见 BaseButton 面积≈0（布局断裂）
## 每面板截图 .godot/agent_tools/ui_audit/<name>.png，报告 ui_audit_report.txt。
## 运行：godot --rendering-driver opengl3 --path . res://tests/_tmp_ui_audit_probe.tscn
## ⚠️ 面板 _ready 可能触发 show_once/自动存档等写盘——运行前必须备份 user:// 目录。

const VP := Rect2(0, 0, 1280, 720)
const SHOT_DIR := "res://.godot/agent_tools/ui_audit/"
const COVER_MIN_FRACTION := 0.7
const SIZE_RATIO_MAX := 3.0
const OFFSCREEN_FRACTION := 0.2

# 已知"按设计叠放"的场景跳过独立审计（mvp_panel 走 create 特例，main 走合成审计）
const SKIP_STANDALONE := ["mvp_panel.tscn"]
# 特殊构建的面板（路径 → 预处理回调名），其余走通用 instantiate
const EXTRA_SCENES := [
	"res://scenes/title_screen.tscn",
	"res://scenes/world_map.tscn",
	"res://scenes/bunker/truck_base.tscn",
]

var report: Array[String] = []
var fail_count: int = 0


func _ready() -> void:
	# 记录4 视觉体检：先归一化窗口/缩放（本机 DPI 虚拟化会给出 896 高的窗口，
	# 而出界判定 VP 是 16:9 设计空间 1280×720——不归一会产生测量框错位的假出界）
	var win0 := get_window()
	win0.mode = Window.MODE_WINDOWED
	win0.size = Vector2i(1280, 720)
	win0.content_scale_factor = 1.0
	win0.position = Vector2i(60, 60)
	await _settle(3)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var scenes: Array[String] = []
	var dir := DirAccess.open("res://scenes/ui")
	if dir != null:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".tscn") and not SKIP_STANDALONE.has(f):
				scenes.append("res://scenes/ui/" + f)
			f = dir.get_next()
	scenes.sort()
	scenes.append_array(EXTRA_SCENES)
	for p in scenes:
		await _audit_scene(p)
		if EXTRA_SCENES.has(p):
			_reset_window()
	await _audit_mvp()
	await _audit_main_composite()
	_flush_report()
	get_tree().quit()


# ───────────────────────── 通用单场景审计 ─────────────────────────

func _audit_scene(path: String) -> void:
	print("PROBE >>> ", path.get_file())
	var packed: PackedScene = load(path)
	if packed == null:
		_add(path.get_file(), "!! 场景加载失败")
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		_add(path.get_file(), "!! 实例化失败")
		return
	add_child(inst)
	await _settle(3)
	_shot(path.get_file().get_basename())
	_audit_tree(inst, path.get_file())
	inst.queue_free()
	await _settle(1)


## mvp_panel 特例：走真实 create()（胜利四键态，BunkerManager 懒加载拉起）
func _audit_mvp() -> void:
	var tpm := get_node_or_null("/root/TutorialProgressionManager")
	if tpm != null:
		tpm.set("current_step", 13)
	var gm := get_node_or_null("/root/GameManager")
	if gm != null:
		gm.set("current_level", 5)
		gm.set("_pending_battle_level", 5)
	var lpm := get_node_or_null("/root/LevelProgressManager")
	if lpm != null and lpm.get("unlocked_levels") is Array:
		for lv in [5, 6]:
			if not (lpm.get("unlocked_levels") as Array).has(lv):
				(lpm.get("unlocked_levels") as Array).append(lv)
	var mll := get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("bunker")
	await _settle(1)
	var panel: Control = load("res://scenes/ui/mvp_panel.gd").create(self, true, [], 0, 1, {}, false)
	await _settle(3)
	_shot("mvp_panel_victory")
	_audit_tree(panel, "mvp_panel(victory create)")
	panel.queue_free()
	await _settle(1)


## main.tscn 合成审计：HUD 各条在真实父链下的互相覆盖；抽屉展开态再测一遍
func _audit_main_composite() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_add("main.tscn", "!! 场景加载失败")
		return
	var inst: Node = packed.instantiate()
	add_child(inst)
	await _settle(4)
	_shot("main_hud_default")
	_audit_tree(inst, "main.tscn(默认态)")
	# 抽屉展开态（v38.2 reparent 后在 HudLayer 直下）
	var fb: Node = inst.get_node_or_null("HudLayer/BottomFunctionBar")
	if fb == null:
		fb = inst.get_node_or_null("HudLayer/BattleBottomBar/BottomFunctionBar")
	if fb != null and fb.has_method("toggle_drawer"):
		fb.toggle_drawer()
		await _settle(3)
		_shot("main_hud_drawer_open")
		_audit_tree(inst, "main.tscn(抽屉展开)")
	else:
		_add("main.tscn(抽屉展开)", "!! BottomFunctionBar 未找到，抽屉态未测")
	inst.queue_free()
	await _settle(1)


# ───────────────────────── 检测器 ─────────────────────────

func _audit_tree(root: Node, label: String) -> void:
	# DFS 先序 = 同层 CanvasLayer 内的绘制顺序
	var order: Array[Control] = []
	_collect_controls(root, order)
	var leaves: Array[Control] = []
	for c in order:
		if not c.is_visible_in_tree():
			continue
		if _in_subviewport(c) or _in_scroll(c):
			continue
		if _is_interactive_leaf(c):
			leaves.append(c)
	for c in leaves:
		var r := c.get_global_rect()
		# C. 零尺寸可点
		if r.size.x < 2.0 or r.size.y < 2.0:
			_add(label, "C 零尺寸可点控件: %s (%s) rect=%s" % [_rel(c, root), c.get_class(), str(r.size)])
			continue
		# B. 出界
		var outside := _outside_fraction(r)
		if outside >= OFFSCREEN_FRACTION:
			_add(label, "B 可点控件出界 %.0f%%: %s rect=%s" % [outside * 100.0, _rel(c, root), str(r)])
	for c in order:
		if c.is_visible_in_tree() and not _in_subviewport(c) and not _in_scroll(c) \
				and not _is_interactive_leaf(c):
			var r2 := c.get_global_rect()
			if r2.size.x > 20.0 and r2.size.y > 20.0 and _outside_fraction(r2) >= 0.999:
				_add(label, "B 非交互控件整体出界: %s rect=%s" % [_rel(c, root), str(r2)])
	# A. 同尺度覆盖（双全屏层叠=背景/点击捕获分层设计，豁免）
	for i in range(leaves.size()):
		for j in range(i + 1, leaves.size()):
			var a: Control = leaves[i]
			var b: Control = leaves[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var ra := a.get_global_rect()
			var rb := b.get_global_rect()
			if ra.get_area() >= VP.get_area() * 0.85 and rb.get_area() >= VP.get_area() * 0.85:
				continue
			var inter := ra.intersection(rb)
			if inter.size.x <= 2.0 or inter.size.y <= 2.0:
				continue
			var frac := inter.get_area() / maxf(ra.get_area(), 1.0)
			var ratio := maxf(ra.get_area(), rb.get_area()) / maxf(minf(ra.get_area(), rb.get_area()), 1.0)
			if frac >= COVER_MIN_FRACTION and ratio <= SIZE_RATIO_MAX:
				_add(label, "A 覆盖: %s 被 %s 盖住 %.0f%%（同尺度可点控件）" % [_rel(a, root), _rel(b, root), frac * 100.0])


func _collect_controls(node: Node, out: Array[Control]) -> void:
	if node is Control:
		out.append(node)
	for ch in node.get_children():
		_collect_controls(ch, out)


func _is_interactive_leaf(c: Control) -> bool:
	if c is BaseButton:
		return not _has_interactive_descendant(c)
	if c.mouse_filter == Control.MOUSE_FILTER_STOP:
		return not _has_interactive_descendant(c)
	return false


func _has_interactive_descendant(c: Control) -> bool:
	for ch in c.get_children():
		if ch is Control:
			var cc := ch as Control
			if cc is BaseButton or cc.mouse_filter == Control.MOUSE_FILTER_STOP:
				return true
			if _has_interactive_descendant(cc):
				return true
	return false


func _in_subviewport(c: Control) -> bool:
	var n: Node = c
	while n != null:
		if n is SubViewport:
			return true
		n = n.get_parent()
	return false


## ScrollContainer 内容本来就排出视口外靠滚动查看——子树整体豁免
func _in_scroll(c: Control) -> bool:
	var n: Node = c
	while n != null:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false


func _outside_fraction(r: Rect2) -> float:
	var inter := r.intersection(VP)
	if inter.size.x <= 0.0 or inter.size.y <= 0.0:
		return 1.0
	return 1.0 - inter.get_area() / maxf(r.get_area(), 1.0)


func _rel(c: Node, root: Node) -> String:
	var p := c.get_path()
	var rp := root.get_path()
	var s := str(p)
	var base := str(rp)
	if s.begins_with(base):
		s = s.substr(base.length())
	return s


# ───────────────────────── 报告/截图 ─────────────────────────

## title_screen 会按存档设置改窗口模式/分辨率——每个大场景审完复位，保坐标系一致
func _reset_window() -> void:
	var win := get_window()
	if win == null:
		return
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1280, 720)
	win.position = Vector2i(60, 60)
	await _settle(2)

func _add(label: String, issue: String) -> void:
	var line := "%s :: %s" % [label, issue]
	report.append(line)
	if issue.begins_with("A") or issue.begins_with("B") or issue.begins_with("C"):
		fail_count += 1
		print("UI_AUDIT_FAIL ", line)
	else:
		print("UI_AUDIT_INFO ", line)


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(SHOT_DIR + name + ".png")


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _flush_report() -> void:
	var f := FileAccess.open(SHOT_DIR + "ui_audit_report.txt", FileAccess.WRITE)
	if f != null:
		for line in report:
			f.store_line(line)
		f.store_line("—— 共 %d 条，其中 A/B/C 失败 %d 条" % [report.size(), fail_count])
		f.close()
	print("UI_AUDIT_DONE total=%d fail=%d" % [report.size(), fail_count])
