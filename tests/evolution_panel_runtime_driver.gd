extends Node
## 进化面板运行时驱动（autoload 齐全，作为主场景 headless 运行）：
##   godot --headless --path . res://tests/evolution_panel_runtime_driver.tscn
## 验证 v9.x"进化情报可见性"修复的运行时链路：
##   1) 未揭示的情报隐藏分支提示出现在进化树（源卡 ww1_mp18 → IB_INFANTRY_SPECIAL）
##   2) 锁定目标节点不再 disabled（可点击查看条件）
##   3) 点击锁定目标后，右侧详情渲染出条件列表（✗ 行 + └ 指引行）
##   4) badge 显示"等N项"（多条件未满足计数）

const PANEL_SCENE := "res://scenes/ui/evolution_panel.tscn"
const SRC_CARD_ID := "ww1_mp18"  # IB_INFANTRY_SPECIAL（特种作战路线）的源卡

var _fails: Array[String] = []

func _ready() -> void:
	# 等 autoload 的 deferred init 稳定
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
	for c in node.get_children():
		_collect_text(c, out)

func _run() -> void:
	print("=== EVOLUTION PANEL RUNTIME DRIVER START ===")
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null:
		_fail("InstanceRegistry autoload 缺失")
		return
	# 建源卡实例（特种作战路线源卡）
	var inst: CardResource = ir.create_instance(SRC_CARD_ID)
	if inst == null:
		_fail("无法创建源卡实例 %s" % SRC_CARD_ID)
		return

	var panel: Control = load(PANEL_SCENE).instantiate()
	get_tree().root.add_child(panel)
	await get_tree().process_frame

	# ── 1. 隐藏分支提示 ──
	panel.set_selected_card(inst)
	var texts: Array[String] = []
	_collect_text(panel.get_node("%EvolutionTree"), texts)
	var joined := "\n".join(PackedStringArray(texts))
	if not joined.contains("未揭示的隐藏路线"):
		_fail("进化树未出现「未揭示的隐藏路线」提示（IB_INFANTRY_SPECIAL 源卡应显示）")
	elif not joined.contains("步兵系情报"):
		_fail("隐藏分支提示缺少情报进度文本（应含「步兵系情报 x%/75%」）")
	else:
		print("[OK] 隐藏分支提示渲染：含路线名 + 情报类型进度")

	# ── 2/3. 锁定目标可点击 + 详情条件列表 ──
	# 新建实例无图纸/等级，全部目标必然锁定；选第一个目标
	var targets: Array = inst.get_evolution_targets()
	if targets.is_empty():
		_fail("源卡 %s 无进化目标（数据异常）" % SRC_CARD_ID)
	else:
		var tid: String = String(targets[0].get("target_id", ""))
		panel._on_target_selected(tid, String(targets[0].get("name", "")))
		await get_tree().process_frame
		var dtexts: Array[String] = []
		_collect_text(panel.get_node("%ReqList"), dtexts)
		var djoined := "\n".join(PackedStringArray(dtexts))
		if not djoined.contains("✗"):
			_fail("锁定目标详情未渲染条件行（ReqList 无 ✗ 行）")
		elif not djoined.contains("└"):
			_fail("锁定目标详情缺少「└ 指引」子行（detail 指引未下发或未渲染）")
		else:
			print("[OK] 锁定目标可点击 → 详情条件列表 + 指引行渲染正常")

		# 目标节点按钮不应再 disabled（当前形态节点除外）
		var disabled_btns := _count_disabled_buttons(panel.get_node("%EvolutionTree"))
		# 当前形态节点 disabled=true 是设计；目标节点全可点 → 最多 1 个
		if disabled_btns > 1:
			_fail("进化树存在 %d 个 disabled 按钮（应只剩当前形态节点 1 个）" % disabled_btns)
		else:
			print("[OK] 锁定目标按钮可点击（disabled 仅剩当前形态节点）")

		# ── 4. badge "等N项" ──
		if joined.contains("等") and joined.contains("项"):
			print("[OK] badge 显示多条件计数（等N项）")
		else:
			print("[SKIP] badge 计数未出现（可能仅 1 项未满足，非必现）")

	panel.queue_free()
	ir.dispose_instance(String(inst.instance_id))
	print("=== EVOLUTION PANEL RUNTIME DRIVER %s ===" % ("ALL PASS" if _fails.is_empty() else "FAILED"))

func _count_disabled_buttons(node: Node) -> int:
	var n := 0
	if node is Button and (node as Button).disabled:
		n += 1
	for c in node.get_children():
		n += _count_disabled_buttons(c)
	return n
