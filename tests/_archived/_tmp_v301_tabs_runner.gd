extends Node
## v30.1 R3 结算三页签冒烟 + 实拍：
##  ① TabContainer 三页齐全（战报/缴获/养成），默认页=战报
##  ② 基地状态默认折叠（▸ 头 + body 隐藏），点击展开（▾）
##  ③ 挂机态：战报页隐藏、默认页=缴获
##  ④ 三页各拍一张 PNG（.godot/agent_tools/t31_tab_*.png）
## 跑法（实拍需非 headless，带窗口）：
##   godot --rendering-driver opengl3 --path . res://tests/_tmp_v301_tabs_boot.tscn

var _fails: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var mvp_script = load("res://scenes/ui/mvp_panel.gd")
	# BunkerManager 为懒加载 autoload（ManagerLazyLoader），boot 后须显式拉起才有基地状态段
	if ManagerLazyLoader != null:
		ManagerLazyLoader.ensure_loaded("bunker")
	var panel: Node = mvp_script.create(get_tree().root, true, [], 100, 2, _fake_summary(), false)
	await get_tree().process_frame
	await get_tree().process_frame

	# ① 三页结构 + ④ 实拍
	var tabs: TabContainer = _find_tab_container(panel)
	_chk(tabs != null, "TabContainer 未找到")
	if tabs != null:
		_chk(tabs.get_tab_count() == 3, "页签数 != 3（实际 %d）" % tabs.get_tab_count())
		_chk(tabs.get_tab_title(0) == "战报", "页0 标题 != 战报")
		_chk(tabs.get_tab_title(1) == "缴获", "页1 标题 != 缴获")
		_chk(tabs.get_tab_title(2) == "养成", "页2 标题 != 养成")
		_chk(tabs.current_tab == 0, "默认页 != 战报")
		await _shot("t31_tab_report.png")
		tabs.current_tab = 1
		await _shot("t31_tab_loot.png")
		tabs.current_tab = 2
		await _shot("t31_tab_growth.png")
		# ② 基地状态折叠态（养成页内）
		var head: Button = panel.get("_bunker_head")
		var body: VBoxContainer = panel.get("_bunker_body")
		_chk(head != null and body != null, "基地状态折叠头/体缺失")
		if head != null and body != null:
			_chk(not body.visible, "基地状态未默认折叠")
			_chk(head.text.begins_with("▸ "), "折叠头箭头缺失")
			head.emit_signal("pressed")
			await get_tree().process_frame
			_chk(body.visible, "点击后未展开")
			_chk(head.text.begins_with("▾ "), "展开头箭头缺失")
			await _shot("t31_tab_growth_expanded.png")

	# ③ 挂机态：战报页应隐藏、默认页=缴获
	panel.queue_free()
	await get_tree().process_frame
	var afk_panel: Node = mvp_script.create(get_tree().root, true, [], 100, 2, _fake_summary(), true)
	await get_tree().process_frame
	var afk_tabs: TabContainer = _find_tab_container(afk_panel)
	_chk(afk_tabs != null and afk_tabs.is_tab_hidden(0), "挂机未隐藏战报页")
	_chk(afk_tabs != null and afk_tabs.current_tab == 1, "挂机默认页 != 缴获")
	afk_panel.queue_free()
	await get_tree().process_frame

	if _fails.is_empty():
		print("[T31Tabs] ALL PASS")
		get_tree().quit(0)
	else:
		for f in _fails:
			printerr("[T31Tabs] FAIL: " + f)
		get_tree().quit(1)

func _fake_summary() -> Dictionary:
	return {
		"energy_block_gain": 12, "basic_nano_gain": 240,
		"fragment_gain_total": 3, "intel_harvest": {},
		"collected_rewards": [], "sanity_penalty": {"nano": 30, "energy": 2},
	}

func _find_tab_container(node: Node) -> TabContainer:
	if node is TabContainer:
		return node
	for c in node.get_children():
		var t: TabContainer = _find_tab_container(c)
		if t != null:
			return t
	return null

func _shot(fname: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("res://.godot/agent_tools/" + fname)
		print("[T31Tabs] shot saved: " + fname)

func _chk(cond: bool, label: String) -> void:
	if cond:
		print("[T31Tabs] PASS: " + label)
	else:
		_fails.append(label)
