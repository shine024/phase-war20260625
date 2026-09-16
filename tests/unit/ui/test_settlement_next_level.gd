class_name SettlementNextLevelTest
extends GdUnitTestSuite
## v34 B1 再战回路回归锁：mvp_panel「▶ 出击下一关」直通键的显隐矩阵（_compute_next_level）。
## 契约：胜利 · 非挂机 · 教程已完（教程期战后要回基地续播步 5）· 本战关号+1 ∈ [1,100]
## 且已解锁 —— 四条件全过才给直通键；下一关取 _pending_battle_level（本战实际打的关），
## 防"重打旧关后 current_level 已被推进到最高解锁关"时按钮指向跳变。

const MvpPanelScene := preload("res://scenes/ui/mvp_panel.tscn")


func _make_panel(won: bool, is_afk: bool) -> Node:
	var panel: Node = MvpPanelScene.instantiate()
	add_child(panel)
	panel.player_won = won
	panel._is_afk = is_afk
	return panel


func _setup_states() -> Dictionary:
	## 快照三处全局态（教程步/GameManager 战关/LPM 进度），返回还原用
	var bak: Dictionary = {}
	var tm: Node = get_node_or_null("/root/TutorialProgressionManager")
	if tm != null:
		bak["tm_step"] = tm.current_step
		tm.current_step = 13  # FREEDOM_MODE = 教程完成
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and "_pending_battle_level" in gm:
		bak["gm_played"] = gm._pending_battle_level
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	if lpm != null:
		bak["lpm"] = lpm.save_state()
		# L1-L6 已解锁（max=6）：played=5 → next=6 在解锁集内
		lpm.reset_progress()
		for lv in range(1, 6):
			lpm.unlocked_levels.append(lv + 1)
		lpm.max_unlocked_level = 6
	return bak


func _restore_states(bak: Dictionary) -> void:
	var tm: Node = get_node_or_null("/root/TutorialProgressionManager")
	if tm != null and bak.has("tm_step"):
		tm.current_step = bak["tm_step"]
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and bak.has("gm_played"):
		gm._pending_battle_level = bak["gm_played"]
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	if lpm != null and bak.has("lpm"):
		lpm.load_state(bak["lpm"])


func test_next_level_matrix() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	var tm: Node = get_node_or_null("/root/TutorialProgressionManager")
	if gm == null or lpm == null or tm == null:
		print("  autoload 不全，跳过")
		return
	var bak := _setup_states()
	gm._pending_battle_level = 5

	# ① 胜利+教程完+下一关已解锁 → 6
	var p1: Node = _make_panel(true, false)
	assert_int(p1._compute_next_level()).is_equal(6)
	p1.queue_free()

	# ② 败局 → 0
	var p2: Node = _make_panel(false, false)
	assert_int(p2._compute_next_level()).is_equal(0)
	p2.queue_free()

	# ③ 挂机结算 → 0
	var p3: Node = _make_panel(true, true)
	assert_int(p3._compute_next_level()).is_equal(0)
	p3.queue_free()

	# ④ 教程进行中 → 0（战后回基地续播教程步）
	tm.current_step = 4
	var p4: Node = _make_panel(true, false)
	assert_int(p4._compute_next_level()).is_equal(0)
	p4.queue_free()
	tm.current_step = 13

	# ⑤ 打的关是最后一关（played=100）→ 0
	gm._pending_battle_level = 100
	var p5: Node = _make_panel(true, false)
	assert_int(p5._compute_next_level()).is_equal(0)
	p5.queue_free()

	# ⑥ 打的关是当前最高解锁关（played=6 → next=7 未解锁）→ 0
	gm._pending_battle_level = 6
	var p6: Node = _make_panel(true, false)
	assert_int(p6._compute_next_level()).is_equal(0)
	p6.queue_free()

	_restore_states(bak)


func test_growth_and_first_clear_render() -> void:
	## B2/B3 数据通道：结算摘要键名契约（game_manager 写 first_clear/card_growth →
	## mvp_panel 缴获页消费）+ 两个渲染函数对真实数据只消费不崩溃且确实生成行
	var panel: Node = _make_panel(true, false)
	panel._reward_summary = {
		"first_clear": {"level": 3, "reward": {"crystal": 26, "nano_materials": 290, "energy_block": 6}},
		"card_growth": [
			{"iid": "ww1_mauser#1", "name": "毛瑟步枪班", "xp": 30, "lv": 2, "leveled": true},
			{"iid": "ww1_arty_m81#1", "name": "81mm 迫击炮组", "xp": 30, "lv": 1, "leveled": false},
		],
	}
	var host := VBoxContainer.new()
	panel.add_child(host)
	panel._render_first_clear(host)
	panel._render_card_growth(host)
	# 首通区块：分隔线+标题+列表 ≥3 节点；成长区块同构且升级行金色高亮存在
	assert_int(host.get_child_count()).is_greater_equal(6)
	var gold_rows: int = _count_gold_rows(host)
	assert_int(gold_rows).is_equal(1)
	# 空数据静默跳过（无 first_clear/card_growth 键不生成任何节点）
	var host2 := VBoxContainer.new()
	panel.add_child(host2)
	panel._reward_summary = {}
	panel._render_first_clear(host2)
	panel._render_card_growth(host2)
	assert_int(host2.get_child_count()).is_equal(0)
	panel.queue_free()


## 升级行（金色高亮）在 list VBox 内层——递归统计"升级 →"标签数
func _count_gold_rows(node: Node) -> int:
	var count: int = 0
	for c in node.get_children():
		if c is Label and String((c as Label).text).contains("升级 →"):
			count += 1
		count += _count_gold_rows(c)
	return count
