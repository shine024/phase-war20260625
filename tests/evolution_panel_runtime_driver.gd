extends Node
## 制造面板运行时驱动（v26 批次4 改造，原"进化面板运行时驱动"）：
##   godot --headless --path . res://tests/evolution_panel_runtime_driver.tscn
## 验证 v26 制造中心（evolution_panel.gd 重写）的运行时链路：
##   1) 打开面板 → 左侧配方目录渲染（38 配方，全档）
##   2) 点击配方行 → 右侧详情渲染条件行（情报/授权/资源）
##   3) 中栏品质概率池渲染（GATE 档位条）
##   4) 制造按钮存在且为"制造一张"

const PANEL_SCENE := "res://scenes/ui/evolution_panel.tscn"
const SRC_CARD_ID := "ww1_mp18"

var _fails: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()
	get_tree().quit(0 if _fails.is_empty() else 1)

func _fail(msg: String) -> void:
	push_error("[FAIL] " + msg)
	_fails.append(msg)

func _collect_text(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	if node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		_collect_text(c, out)

func _run() -> void:
	print("=== MANUFACTURE PANEL RUNTIME DRIVER START ===")
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null:
		_fail("InstanceRegistry autoload 缺失")
		return
	var inst: CardResource = ir.create_instance(SRC_CARD_ID)
	if inst == null:
		_fail("无法创建源卡实例 %s" % SRC_CARD_ID)
		return

	var panel: Control = load(PANEL_SCENE).instantiate()
	get_tree().root.add_child(panel)
	await get_tree().process_frame

	# ── 1. 配方目录渲染 ──
	panel.set_selected_card(inst)
	# 配方目录刷新挂在打开管线（on_overlay_opened → 可见时 _refresh_all）
	panel.show_panel()
	panel.on_overlay_opened()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# 配方目录容器（左栏）= %CardListContainer；%EvolutionTree 是中栏品质池
	var list_box: Node = panel.get_node_or_null("%CardListContainer")
	var tree_box: Node = panel.get_node_or_null("%EvolutionTree")
	if list_box == null:
		_fail("配方目录容器 %CardListContainer 缺失")
	else:
		var recipe_rows := 0
		for c in list_box.get_children():
			if c is Button and c.has_meta("recipe_id"):
				recipe_rows += 1
		if recipe_rows < 30:
			_fail("配方目录行数 %d < 30（应为 38 配方）" % recipe_rows)
		else:
			print("[OK] 配方目录渲染：%d 行" % recipe_rows)

		# ── 2. 点击配方 → 详情条件列表 ──
		var first_row: Button = null
		for c in list_box.get_children():
			if c is Button and c.has_meta("recipe_id"):
				first_row = c
				break
		if first_row == null:
			_fail("目录无可点击配方行")
		else:
			var rid: String = String(first_row.get_meta("recipe_id"))
			panel._on_recipe_selected(rid)
			await get_tree().process_frame
			var dtexts: Array[String] = []
			_collect_text(panel.get_node("%ReqList"), dtexts)
			var djoined := "\n".join(PackedStringArray(dtexts))
			if djoined.strip_edges().is_empty():
				_fail("配方 %s 详情未渲染条件行（ReqList 为空）" % rid)
			elif not (djoined.contains("情报") or djoined.contains("资源") or djoined.contains("授权")):
				_fail("条件行缺少制造语义关键词（情报/资源/授权）：%s" % djoined.substr(0, 80))
			else:
				print("[OK] 配方详情条件列表渲染正常（含制造条件关键词）")

		# ── 3. 品质概率池（中栏应渲染出稀有度条） ──
		if tree_box == null:
			_fail("品质池容器 %EvolutionTree 缺失")
		elif tree_box.get_child_count() == 0:
			_fail("品质概率池为空（应渲染 GATE 档位条）")
		else:
			print("[OK] 品质概率池渲染正常（%d 个节点）" % tree_box.get_child_count())

	# ── 4. 制造按钮 ──
	var evolve_btn: Button = panel.get_node_or_null("%EvolveButton")
	if evolve_btn == null:
		_fail("制造按钮 %EvolveButton 缺失")
	elif String(evolve_btn.text) != "制造一张":
		_fail("制造按钮文本应为「制造一张」，实际「%s」" % evolve_btn.text)
	else:
		print("[OK] 制造按钮存在且文案正确")

	panel.queue_free()
	ir.dispose_instance(String(inst.instance_id))
	print("=== MANUFACTURE PANEL RUNTIME DRIVER %s ===" % ("ALL PASS" if _fails.is_empty() else "FAILED"))
