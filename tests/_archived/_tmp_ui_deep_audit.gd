extends Node
## v6.14 UI 深度审计（临时探针②）：纯脚本弹窗带数据实测 + 教程 overlay 真实挂载实测。
## 上一轮探针只测 .tscn 场景且统一 CenterContainer 挂载——本探针补盲区：
## ① tutorial_overlay 按 main.gd 真实方式挂到 CanvasLayer（裸挂、不补尺寸）
## ② offline_reward / afk_settlement / intel_reveal / feature_unlock / deploy_wheel 带合成数据
## 安全：不调 save_game / load_game；全程不写用户数据（feature_unlock 用 show_now 不落盘）。

const VW := 1280.0
const VH := 720.0
const TOL := 8.0

var _log: FileAccess
var _report: Array = []

func _l(line: String) -> void:
	print(line)
	if _log == null:
		_log = FileAccess.open("user://ui_deep_audit.log", FileAccess.WRITE)
	if _log != null:
		_log.store_string(line + "\n")
		_log.flush()

func _ready() -> void:
	_l("===== UI DEEP AUDIT START =====")
	# 等 bootstrap 期结束——_ready 期间 root.add_child 会被 "busy setting up children" 拒绝
	await get_tree().process_frame
	# 钉到 1280x720（headless 默认 visible_rect 是 1280x1280，会污染视口锚定几何）
	get_window().size = Vector2i(int(VW), int(VH))
	await get_tree().process_frame
	_l("[INFO] window.size=%s visible_rect=%s" % [str(get_window().size), str(get_viewport().get_visible_rect())])
	# 1280x720 定尺寸包装层：镜像 PopupLayer 在 16:9 下的真实几何（消除 headless 视口高度异常）
	var popup_layer := Control.new()
	popup_layer.name = "PopupLayerSim"
	popup_layer.size = Vector2(VW, VH)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(popup_layer)

	await _test_tutorial_real_mount()
	await _test_offline_reward_dialog(popup_layer)
	await _test_afk_settlement_dialog(popup_layer)
	await _test_intel_reveal_popup(popup_layer)
	await _test_feature_unlock_popup(popup_layer)
	await _test_deploy_command_wheel(popup_layer)

	_l("===== REPORT =====")
	for r in _report:
		_l(str(r))
	_l("===== END (%d findings) =====" % _report.size())
	get_tree().quit(0)

# ── ① 教程 overlay 真实挂载（复刻 main.gd _show_tutorial_overlay：裸挂 CanvasLayer）──
func _test_tutorial_real_mount() -> void:
	_l("[RUN] >>> tutorial_overlay (real CanvasLayer mount)")
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayerSim"
	hud_layer.layer = 40
	get_tree().root.add_child(hud_layer)
	var tm: Node = get_node_or_null("/root/TutorialProgressionManager")
	if tm == null:
		_l("[SKIP] TutorialProgressionManager 不存在")
		return
	var content: Dictionary = tm.get_tutorial_content()  # 副作用 NONE → INTRO_WELCOME
	_l("[INFO] current_step=%s content_keys=%s title='%s' desc_len=%d" % [
		str(tm.get("current_step")), str(content.keys()),
		str(content.get("title", "")), str(content.get("description", "")).length()])
	var ps: PackedScene = load("res://scenes/ui/tutorial_overlay.tscn")
	var overlay: Node = ps.instantiate()
	hud_layer.add_child(overlay)  # 与 main.gd 完全一致：不设尺寸不设锚
	for i in 10:
		await get_tree().process_frame
	var root_ctl := overlay as Control
	_l("[INFO] overlay root rect=%s size_in_tree=%s" % [
		str(root_ctl.get_global_rect()) if root_ctl else str(Vector2()),
		str(root_ctl.size) if root_ctl else str(Vector2())])
	var box: Control = root_ctl.get_node_or_null("TutorialBox")
	if box != null:
		var br := box.get_global_rect()
		_l("[INFO] TutorialBox global rect=%s" % str(br))
		var off_l: float = -br.position.x
		var off_t: float = -br.position.y
		if off_l > TOL or off_t > TOL:
			_report.append("[BUG] TutorialBox 越出屏幕左/上：left 超出 %.0fpx, top 超出 %.0fpx（根 Control 零尺寸所致，标题文字被切在屏外）" % [off_l, off_t])
		else:
			_report.append("[OK] TutorialBox 在界内")
	var title_lbl: Label = root_ctl.get_node_or_null("TutorialBox/Margin/VBox/TitleLabel")
	if title_lbl != null:
		var tr := title_lbl.get_global_rect()
		_l("[INFO] TitleLabel rect=%s text='%s'" % [str(tr), title_lbl.text])
		if tr.position.y < -TOL or tr.end.x <= 0 or tr.end.y <= 0:
			_report.append("[BUG] 标题被切出屏幕外（rect=%s）" % str(tr))
	_find_overflows(overlay, "tutorial_overlay")
	overlay.queue_free()
	hud_layer.queue_free()
	await get_tree().process_frame

# ── ② 离线奖励弹窗（合成满额数据：5 货币 + 战利品 + 经验 + 解锁）──
func _test_offline_reward_dialog(popup_layer: Node) -> void:
	_l("[RUN] >>> offline_reward_dialog (rich data)")
	var script: GDScript = load("res://scenes/ui/offline_reward_dialog.gd")
	var result := {
		"capped_sec": 5 * 3600,
		"battles": 12,
		"level": 8,
		"currencies": {
			"nano_material": 12345, "alloy": 678, "crystal": 90,
			"energy_block": 1234, "intel_point": 56,
		},
		"drop_preview_count": 6,
		"phase_field_xp": 420,
		"levels_unlocked": [9, 14],
	}
	var dialog: Node = script.call("create", popup_layer, result)
	for i in 8:
		await get_tree().process_frame
	_find_overflows(dialog, "offline_reward_dialog")
	var panel := _deepest_panel(dialog)
	if panel != null:
		_l("[INFO] 面板 rect=%s" % str(panel.get_global_rect()))
	dialog.queue_free()
	await get_tree().process_frame

# ── ③ 挂机结算弹窗（14 条缴获压测滚动）──
func _test_afk_settlement_dialog(popup_layer: Node) -> void:
	_l("[RUN] >>> afk_settlement_dialog (14 reward lines)")
	var script: GDScript = load("res://scenes/ui/afk_settlement_dialog.gd")
	var rewards := {}
	for i in 14:
		rewards["item_%02d" % i] = (14 - i) * 3
	var result := {"wins": 9, "losses": 2, "failed": false, "rewards": rewards}
	var dialog: Node = script.call("create", popup_layer, result)
	for i in 8:
		await get_tree().process_frame
	_find_overflows(dialog, "afk_settlement_dialog")
	var panel := _deepest_panel(dialog)
	if panel != null:
		_l("[INFO] 面板 rect=%s（固定 480x580 设计）" % str(panel.get_global_rect()))
	dialog.queue_free()
	await get_tree().process_frame

# ── ④ 情报揭示弹窗 ──
func _test_intel_reveal_popup(popup_layer: Node) -> void:
	_l("[RUN] >>> intel_reveal_popup (3 events)")
	var script: GDScript = load("res://scenes/ui/intel_reveal_popup.gd")
	var popup: Node = script.call("create", popup_layer)
	var events := [
		{"icon": "✦", "title": "敌情揭示·测试", "desc": "这是审计合成数据的一段较长描述文本，用于检验文本换行与面板高度。"},
		{"icon": "✧", "title": "进化线索·测试", "desc": "第二条揭示。"},
		{"icon": "✷", "title": "隐秘情报·测试", "desc": "第三条揭示。"},
	]
	popup.call("show_reveals", events)
	for i in 8:
		await get_tree().process_frame
	_find_overflows(popup, "intel_reveal_popup")
	popup.call("queue_free")
	await get_tree().process_frame

# ── ⑤ 首解锁弹窗（show_now 不写盘）──
func _test_feature_unlock_popup(popup_layer: Node) -> void:
	_l("[RUN] >>> feature_unlock_popup (show_now)")
	var before := _root_children_snapshot()
	var script: GDScript = load("res://scenes/ui/feature_unlock_popup.gd")
	script.call("show_now", "功能解锁·审计测试", "这是首解锁弹窗的一句话说明审计文本。")
	for i in 8:
		await get_tree().process_frame
	var created := _newest_root_node(before)
	if created == null:
		_report.append("[BUG] feature_unlock show_now 未产生任何节点")
	else:
		_find_overflows(created, "feature_unlock_popup")
		var panel := _deepest_panel(created)
		if panel != null:
			_l("[INFO] 弹窗 rect=%s" % str(panel.get_global_rect()))

# ── ⑥ 部署指令轮盘（中心 + 屏幕角落两次开合）──
func _test_deploy_command_wheel(popup_layer: Node) -> void:
	_l("[RUN] >>> deploy_command_wheel (center + corner)")
	var script: GDScript = load("res://scenes/ui/deploy_command_wheel.gd")
	var wheel: Node = script.new()
	popup_layer.add_child(wheel)
	for anchor in [Vector2(640, 360), Vector2(10, 10), Vector2(1270, 710)]:
		wheel.call("open", anchor)
		for i in 6:
			await get_tree().process_frame
		var wctl := wheel as Control
		var wr := wctl.get_global_rect()
		_l("[INFO] open(%s) -> wheel rect=%s size=%s visible=%s" % [str(anchor), str(wr), str(wctl.size), str(wctl.visible)])
		for b in wctl.get_children():
			if b is Button:
				_l("[INFO]   btn '%s' global=%s" % [(b as Button).text, str((b as Control).get_global_rect())])
		var over_r: float = wr.end.x - (VW + TOL)
		var over_b: float = wr.end.y - (VH + TOL)
		if over_r > 0.0 or over_b > 0.0 or wr.position.x < -TOL or wr.position.y < -TOL:
			_report.append("[BUG] deploy_command_wheel open(%s) 越界 rect=%s（无边缘钳制）" % [str(anchor), str(wr)])
		wheel.call("close")
	_find_overflows(wheel, "deploy_command_wheel")
	wheel.queue_free()
	await get_tree().process_frame

# ── 工具 ──
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
			# 零尺寸但可见子节点存在 = 布局断裂（教程 overlay 根节点即此类）
			var has_visible_child := false
			for ch in c.get_children():
				if ch is Control and (ch as Control).is_visible_in_tree():
					has_visible_child = true
					break
			if has_visible_child:
				_l("[INFO] %s :: 零尺寸根 %s (%s) 但有可见子节点 → 子级锚定全部以 (0,0) 为基准" % [tag, c.name, c.get_class()])
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

func _deepest_panel(root: Node) -> Control:
	var stack: Array = [root]
	var best: Control = null
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is Panel and best == null:
			best = n as Panel
	return best

func _root_children_snapshot() -> Array:
	var out: Array = []
	for c in get_tree().root.get_children():
		out.append(c)
	return out

func _newest_root_node(before: Array) -> Node:
	var newest: Node = null
	for c in get_tree().root.get_children():
		if not before.has(c):
			newest = c
	return newest
