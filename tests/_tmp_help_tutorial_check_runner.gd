extends Node
## v26.33 引导/帮助重整检查 runner（v26.12-13 帮助补全 + FTUE A3 移动基地步的回归锁）
## 断言：
##   A) 教程 14 步制：STEP_ORDER 唯一/全有数据/字段完整；TRUCK_BASE 在首战后；
##      改造步=图纸口径（无"消耗合金"）；世界地图步=行军语义；进度 total=14；
##      save version=4；load v3 档原位续看；v1 旧档≥8 判完档；is_past_first_battle 含新步
##   B) 帮助面板 7 Tab：Tab 名含"移动基地"（非"基地与移动基地"）；内容含停哪打哪/
##      行军/工位/金色光点；无旧基地主内容（"余烬要塞（旧基地）"/"符文圣所"/"归仓气泡"）
##   C) 移动基地帮助入口：truck_base PANEL_SCENES 注册 help + help_panel 场景可加载
## 教程管理器用**本地实例**（不动 autoload 实值、零存档副作用）；帮助面板仅 UI 实例化。

var _fails: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame  # 等 deferred 挂载完成、autoload 稳定
	_check_tutorial()
	_check_help_panel()
	_check_truck_help_entry()
	for f in _fails:
		printerr("[HelpTut] FAIL: " + f)
	print("[HelpTut] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES"))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _fail(msg: String) -> void:
	_fails.append(msg)


# ─── A) 教程 14 步制 ───
func _check_tutorial() -> void:
	var tm_script: GDScript = load("res://managers/tutorial_progression_manager.gd")
	if tm_script == null:
		_fail("tutorial_progression_manager.gd 加载失败")
		return
	var tm: Node = tm_script.new()
	tm._initialize_tutorial_data()  # 本地实例不走 _ready（不进树），手动建数据

	# A1: 14 步、唯一、枚举值有效
	var order: Array = tm.STEP_ORDER
	if order.size() != 14:
		_fail("STEP_ORDER 应 14 步，实际 %d" % order.size())
	var seen := {}
	for s in order:
		if seen.has(s):
			_fail("STEP_ORDER 重复步骤 %s" % str(s))
		seen[s] = true

	# A2: 每步数据字段完整
	for s in order:
		var d: Dictionary = tm.tutorial_data.get(s, {})
		if d.is_empty():
			_fail("步骤 %s 无 tutorial_data" % str(s))
			continue
		for key in ["title", "description", "highlights", "action_text", "action_target"]:
			var v = d.get(key)
			if v == null or (v is String and String(v).is_empty()) or (v is Array and (v as Array).is_empty()):
				_fail("步骤 %s 字段 %s 空" % [str(s), key])

	# A3: 移动基地步=枚举 14、位置在首战后（战后续播首步）
	if int(tm.TutorialStep.TRUCK_BASE) != 14:
		_fail("TRUCK_BASE 枚举值应为 14（存档兼容），实际 %d" % int(tm.TutorialStep.TRUCK_BASE))
	var idx_first := order.find(tm.TutorialStep.FIRST_BATTLE)
	var idx_truck := order.find(tm.TutorialStep.TRUCK_BASE)
	if idx_truck != idx_first + 1:
		_fail("TRUCK_BASE 应紧跟 FIRST_BATTLE（idx %d→%d）" % [idx_first, idx_truck])
	# 移动基地步不切场景（overlay 活在 main 场景，动作为纯推进）
	if String(tm.tutorial_data[tm.TutorialStep.TRUCK_BASE]["action_target"]) != "next":
		_fail("TRUCK_BASE action_target 应为 next（不切场景）")

	# A4: 口径纠偏——改造步图纸消耗（v26.10），不得残留"消耗合金"
	var mod_text := String(tm.tutorial_data[tm.TutorialStep.MODIFICATION]["description"])
	if not mod_text.contains("图纸"):
		_fail("改造步描述应含图纸消耗口径")
	if mod_text.contains("消耗合金"):
		_fail("改造步描述残留旧口径「消耗合金」")
	# 世界地图步行军语义
	var map_text := String(tm.tutorial_data[tm.TutorialStep.WORLD_MAP]["description"])
	for kw in ["行军", "停靠", "停哪打哪"]:
		if not map_text.contains(kw):
			_fail("世界地图步描述缺关键词「%s」" % kw)

	# A5: 进度口径
	var prog: Dictionary = tm.get_tutorial_progress()
	if int(prog.get("total_steps", 0)) != 14:
		_fail("total_steps 应为 14，实际 %s" % str(prog.get("total_steps")))

	# A6: save/load——version 4；v3 档原位续看；v1 旧档 ≥8 判完档
	var sv: Dictionary = tm.save_state()
	if int(sv.get("version", 0)) != 4:
		_fail("save_state version 应为 4，实际 %s" % str(sv.get("version")))
	tm.load_state({"version": 3, "current_step": 5, "completed_steps": [1, 2, 3, 4]})
	if int(tm.current_step) != 5:
		_fail("v3 档 current_step=5 应原位续看，实际 %d" % int(tm.current_step))
	tm.load_state({"version": 1, "current_step": 8, "completed_steps": [1]})
	if int(tm.current_step) != int(tm.TutorialStep.FREEDOM_MODE):
		_fail("v1 档 step=8 应判完档 FREEDOM，实际 %d" % int(tm.current_step))

	# A7: 战后续播判定覆盖新步（TRUCK_BASE 在首战后 → is_past_first_battle=true）
	tm.current_step = tm.TutorialStep.TRUCK_BASE
	if not tm.is_past_first_battle():
		_fail("is_past_first_battle(TRUCK_BASE) 应为 true（战后续播首步）")

	tm.free()


# ─── B) 帮助面板 7 Tab ───
func _check_help_panel() -> void:
	var packed: PackedScene = load("res://scenes/ui/help_panel.tscn")
	if packed == null:
		_fail("help_panel.tscn 加载失败")
		return
	var panel: Control = packed.instantiate()
	add_child(panel)  # 进树触发 _ready → _populate_tabs
	await get_tree().process_frame

	var tabs: TabContainer = panel.get_node_or_null("Margin/VBox/TabContainer") as TabContainer
	if tabs == null:
		_fail("帮助面板无 TabContainer")
		panel.queue_free()
		return
	if tabs.get_tab_count() != 7:
		_fail("帮助面板应 7 Tab，实际 %d" % tabs.get_tab_count())
	var names := []
	for i in tabs.get_tab_count():
		names.append(tabs.get_tab_title(i))
	if not names.has("移动基地"):
		_fail("Tab 名应含「移动基地」，实际 %s" % str(names))
	if names.has("基地与移动基地"):
		_fail("旧 Tab 名「基地与移动基地」应已改名")

	# 内容口径：移动基地为主体的行军语义；旧基地主内容退场
	var base_text := String(panel._get_base_content())
	for kw in ["停哪打哪", "行军", "工位", "燃料", "睡觉"]:
		if not base_text.contains(kw):
			_fail("基地 Tab 缺关键词「%s」" % kw)
	for banned in ["余烬要塞（旧基地）", "归仓气泡", "纪念墙"]:
		if base_text.contains(banned):
			_fail("基地 Tab 残留旧基地主内容「%s」" % banned)
	if String(base_text).contains("已停用") != true:
		_fail("基地 Tab 应保留旧基地停用说明一句")
	var map_text := String(panel._get_map_content())
	for kw in ["金色光点", "行军", "家"]:
		if not map_text.contains(kw):
			_fail("地图 Tab 缺关键词「%s」" % kw)
	if map_text.contains("卡车标记"):
		_fail("地图 Tab 残留旧「卡车标记」表述（v26.20 起为金色光点）")
	var pi_text := String(panel._get_phase_instrument_content())
	if pi_text.contains("符文圣所"):
		_fail("相位仪 Tab 残留旧基地「符文圣所」表述")

	panel.queue_free()


# ─── C) 移动基地帮助入口 ───
func _check_truck_help_entry() -> void:
	var tb_script: GDScript = load("res://scenes/bunker/truck_base.gd")
	if tb_script == null:
		_fail("truck_base.gd 加载失败")
		return
	var panels: Dictionary = tb_script.PANEL_SCENES
	if not panels.has("help"):
		_fail("truck_base PANEL_SCENES 未注册 help")
	elif not String(panels["help"]).ends_with("help_panel.tscn"):
		_fail("PANEL_SCENES['help'] 路径异常: %s" % str(panels["help"]))
	if not FileAccess.file_exists("res://scenes/ui/help_panel.tscn"):
		_fail("help_panel.tscn 文件不存在")
