extends Node
## v23.6(归仓) 端到端临时驱动：真场景验证 归仓→气泡出现→收取→气泡消失 闭环。
## 运行：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_escrow_bubble_check.tscn
## 保留为可复跑验证件（tests/_tmp_* 惯例）。

var _fail := 0

func _fail_msg(msg: String) -> void:
	_fail += 1
	push_error("[FAIL] " + msg)

func _ready() -> void:
	print("═══ v23.6 归仓气泡端到端检查 ═══")
	var dm: Node = get_node_or_null("/root/DropManager")
	if dm == null or not dm.has_method("deposit_pending_to_escrow"):
		_fail_msg("DropManager autoload 不可用或缺归仓 API")
		_finish()
		return

	# 1) 造三类掉落 → 归仓
	var DropTables = load("res://resources/drop_tables.gd")
	dm.pending_drops.append(DropTables.DropResult.new(
		DropTables.DropEntry.new("nano_materials", DropTables.DropType.MATERIAL, 1.0, 30, 30), 30, "test"))
	dm.pending_drops.append(DropTables.DropResult.new(
		DropTables.DropEntry.new("ww1_mauser", DropTables.DropType.DROPPED_CARD, 1.0, 2, 2), 2, "test"))
	dm.pending_drops.append(DropTables.DropResult.new(
		DropTables.DropEntry.new("stat_boost_hp", DropTables.DropType.STAT_BOOST, 1.0, 1, 1), 1, "test"))
	var moved: int = dm.deposit_pending_to_escrow()
	if moved != 33:
		_fail_msg("归仓件数 %d != 33" % moved)
	else:
		print("  [1] 归仓 33 件 OK（material+card+stat_boost）")

	# 2) 实例化基地场景（新档默认：depot/locked → 物资+战利品回退入口大厅；强化→相位实验室）
	var packed: PackedScene = load("res://scenes/bunker/bunker_main.tscn")
	if packed == null:
		_fail_msg("bunker_main.tscn 加载失败")
		_finish()
		return
	var bunker: Node = packed.instantiate()
	add_child(bunker)
	await get_tree().process_frame
	await get_tree().process_frame

	var layer: Node = bunker.get_node_or_null("RewardBubbleLayer")
	if layer == null:
		_fail_msg("气泡层不存在")
	else:
		var bubbles: int = layer.get_child_count()
		# 新档默认：入口大厅(material+card) + 相位实验室(stat_boost) = 2 泡
		if bubbles != 2:
			_fail_msg("气泡数 %d != 2" % bubbles)
		else:
			print("  [2] 气泡 2 枚 OK（入口大厅=物资+战利品 回退 / 相位实验室=强化）")
		# 3) 收取强化类别 → 相位实验室气泡消失、入口大厅仍在
		var collected: Array = dm.collect_escrow(["stat_boost"])
		if collected.is_empty():
			_fail_msg("收取强化类别返回空")
		await get_tree().process_frame  # escrow_changed → deferred refresh
		await get_tree().process_frame
		var after: int = layer.get_child_count()
		if after != 1:
			_fail_msg("收取后气泡数 %d != 1" % after)
		else:
			print("  [3] 按类别收取后剩 1 泡 OK")
		# 4) 全收 → 清空
		dm.collect_escrow()
		await get_tree().process_frame
		await get_tree().process_frame
		if layer.get_child_count() != 0 or dm.get_escrow_total_count() != 0:
			_fail_msg("全收后未清空（气泡 %d / 仓 %d）" % [layer.get_child_count(), dm.get_escrow_total_count()])
		else:
			print("  [4] 全收清空 OK")

	bunker.queue_free()
	_finish()

func _finish() -> void:
	if _fail == 0:
		print("═══ ALL PASS ═══")
	else:
		print("═══ FAILED: %d ═══" % _fail)
	get_tree().quit(_fail)
