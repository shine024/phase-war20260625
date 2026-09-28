extends Node
## v6.23 记录5 两条"挂起待实机"实机目验探针（临时工具）：
## - #15 卡仓三字段（能量/上场次数/等级）：v6.24#4 信息条+双角标实拍 + 文本转储
## - #16 改造格子视觉检查：改造面板网格实拍逐格目验
## 槽 2 新档 → truck_base → 跳教程/序章弹窗 → 关 feature 门控 → 开 backpack 截图
## → 开 modification 截图。只动槽 2（新档本为测试专档）；截图落 .godot/agent_tools/。
## 运行（窗口化，非 headless）：$GODOT --path . res://tests/_tmp_record5_suspended_probe.tscn

const SHOT_BP := "res://.godot/agent_tools/record5_sus_bp.png"
const SHOT_MOD := "res://.godot/agent_tools/record5_sus_mod.png"

func _ready() -> void:
	await _wait_frames(20)
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null:
		push_error("[probe] SaveManager missing")
		get_tree().quit(1)
		return
	sm.call("set_slot", 2)
	for f in ["user://save_slot_2.json", "user://save_slot_2.json.prior",
			"user://save_slot_2.json.tmp", "user://save_slot_2_backup.json"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	await _wait_frames(10)
	sm.call("start_new_game")
	await _wait_frames(40)
	# 教程链跳到自由态（防聚光/挂起链盖面板）
	var tpm: Node = get_node_or_null("/root/TutorialProgressionManager")
	if tpm != null and tpm.has_method("skip_tutorial"):
		tpm.call("skip_tutorial")
		print("[probe] tutorial skipped -> FREEDOM_MODE")
	# v34 门控总开关关=全开（改造默认 L6 解锁，探针直开）
	var gcfg = load("res://resources/game_config.gd").get_default()
	gcfg.set("feature_gates_enabled", false)
	await _wait_frames(10)

	var truck: Node = _mount("res://scenes/bunker/truck_base.tscn")
	await _wait_frames(30)
	if truck.has_method("_finish_wakeup"):
		truck.call("_finish_wakeup")
		await _wait_frames(10)
	var skip := _find_button_by_text(get_tree().root, "跳过")
	if skip != null:
		skip.pressed.emit()
		print("[probe] intro popup dismissed")
	await _wait_frames(20)

	# ── #15 卡仓 ──
	truck.call("_open_panel", "backpack")
	await _wait_frames(45)
	var bar := _find_by_name(get_tree().root, "BottomInstrumentBar")
	_dump_instrument_state(bar, truck)
	_shot(SHOT_BP)
	await _wait_frames(5)

	# ── #16 改造格子 ──
	truck.call("_open_panel", "modification")
	await _wait_frames(45)
	var mod_panel := _find_by_name(get_tree().root, "ModificationPanel")
	if mod_panel == null and truck != null:
		mod_panel = _find_by_name(truck, "ModificationPanel")
	_dump_mod_grid(mod_panel)
	_shot(SHOT_MOD)
	await _wait_frames(5)

	print("[probe] RECORD5_SUSPENDED_PROBE_OK")
	get_tree().quit(0)

## 相位仪槽信息条 + 卡格角标客观证据
func _dump_instrument_state(bar: Node, truck: Node) -> void:
	if bar == null and truck != null:
		bar = _find_by_name(truck, "BottomInstrumentBar")
	if bar == null:
		print("[probe][bp] BottomInstrumentBar 未找到")
		return
	var strips: Array[String] = []
	_collect_labels(bar, "SlotInfoStrip", strips)
	print("[probe][bp] SlotInfoStrip 条数=%d" % strips.size())
	for s in strips:
		print("[probe][bp] strip: ", s)
	# 战斗卡 tab 网格上的角标（费用/部署）——收集网格卡片容器里的短文本 Label
	var grid := _find_by_name(bar, "CardGrid")
	if grid == null and truck != null:
		grid = _find_by_name(truck, "CardGrid")
	if grid != null:
		var badges: Array[String] = []
		_collect_label_texts(grid, badges, 6)
		print("[probe][bp] CardGrid 子 Label 采样 %d 条:" % badges.size())
		for b in badges:
			print("[probe][bp] grid: ", b)
	else:
		print("[probe][bp] CardGrid 未找到（卡仓战斗 tab 未建?）")

## 改造面板网格客观证据
func _dump_mod_grid(panel: Node) -> void:
	if panel == null:
		print("[probe][mod] ModificationPanel 未找到")
		return
	var grid := _find_by_name(panel, "CardGrid")
	if grid == null:
		grid = _find_by_name(panel, "GridContainer")
	print("[probe][mod] 网格=%s 子节点=%d" % [str(grid != null), grid.get_child_count() if grid else 0])
	if grid != null:
		var texts: Array[String] = []
		_collect_label_texts(grid, texts, 12)
		for t in texts:
			print("[probe][mod] cell: ", t)

func _mount(path: String) -> Node:
	var ps: PackedScene = load(path)
	var inst := ps.instantiate()
	get_tree().root.add_child(inst)
	get_tree().current_scene = inst
	return inst

func _find_button_by_text(root: Node, txt: String) -> Button:
	if root is Button and String(root.text).contains(txt):
		return root
	for c in root.get_children():
		var r := _find_button_by_text(c, txt)
		if r != null:
			return r
	return null

func _find_by_name(root: Node, n: String) -> Node:
	if String(root.name) == n:
		return root
	for c in root.get_children():
		var r := _find_by_name(c, n)
		if r != null:
			return r
	return null

func _collect_labels(root: Node, ln: String, out: Array[String]) -> void:
	if String(root.name) == ln and root is Label:
		out.append(String(root.text))
	for c in root.get_children():
		_collect_labels(c, ln, out)

func _collect_label_texts(root: Node, out: Array[String], limit: int) -> void:
	if out.size() >= limit:
		return
	if root is Label and not String(root.text).strip_edges().is_empty():
		out.append("%s=%s" % [root.name, root.text])
	for c in root.get_children():
		_collect_label_texts(c, out, limit)

func _shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(path))
	print("[probe] shot -> ", path)

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
