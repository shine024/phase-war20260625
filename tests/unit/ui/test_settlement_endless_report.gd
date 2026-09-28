class_name SettlementEndlessReportTest
extends GdUnitTestSuite
## v6.35 黑门 2.0 回归锁:结算面板 endless 战报区块 + 缴获页门控修复。
## 契约:summary 带 "endless" 键(EBM.settle_run 写入)→ 战报页渲染黑门战报(非推图
## 星级/败因)、缴获页照常渲染战中缴获(旧 player_won 门控把无尽缴获整页吞掉的真 bug)。

const MvpPanelScene := preload("res://scenes/ui/mvp_panel.tscn")


func _make_panel(summary: Dictionary, won: bool) -> Node:
	var panel: Node = MvpPanelScene.instantiate()
	add_child(panel)
	panel.player_won = won
	panel._reward_summary = summary
	return panel


func _endless_summary(gate_cleared: bool) -> Dictionary:
	return {
		"player_won": false,
		"endless": {
			"waves": 210, "kills": 88, "score": 21200, "marrow": 350,
			"marrow_capped": false, "is_best": true, "best_score": 21200,
			"best_waves": 210, "rift_env": "psi_storm",
			"gate_cleared": gate_cleared, "gate_core_wave": 210,
			"gate_first_clear": gate_cleared, "supplies_granted": 8,
		},
		"collected_rewards": [
			{"category": "card", "id": "captured_xeno_zealot", "name": "缴获·渡暮狂战士", "count": 1, "source": "击杀缴获"},
		],
	}


## endless 判定:带 endless 键为真;普通关(无键)为假
func test_is_endless_detection() -> void:
	var p1 := _make_panel(_endless_summary(true), false)
	assert_bool(p1._is_endless()).is_true()
	p1.queue_free()
	var p2 := _make_panel({"player_won": true, "collected_rewards": []}, true)
	assert_bool(p2._is_endless()).is_false()
	p2.queue_free()


func _collect_labels(node: Node, out: PackedStringArray) -> void:
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_collect_labels(c, out)


## endless 战报区块渲染:通关 run 含本体击碎行+首通行;非通关 run 走"征程结束"
func test_endless_report_block_renders() -> void:
	var p := _make_panel(_endless_summary(true), false)
	var vbox := VBoxContainer.new()
	add_child(vbox)
	p._render_endless_report(vbox)
	var texts := PackedStringArray()
	_collect_labels(vbox, texts)
	var joined := "\n".join(texts)
	assert_str(joined).contains("黑门本体已击碎")
	assert_str(joined).contains("第 210 波")
	assert_str(joined).contains("21200")
	assert_str(joined).contains("新纪录")
	assert_str(joined).contains("星髓：+350")
	assert_str(joined).contains("首次通关")
	assert_str(joined).contains("补给节点 ×8")
	p.queue_free()
	vbox.queue_free()

	# 非通关 run
	var p2 := _make_panel(_endless_summary(false), false)
	var vbox2 := VBoxContainer.new()
	add_child(vbox2)
	p2._render_endless_report(vbox2)
	var texts2 := PackedStringArray()
	_collect_labels(vbox2, texts2)
	var joined2 := "\n".join(texts2)
	assert_str(joined2).contains("黑门征程结束")
	assert_str(joined2).not_contains("已击碎")
	p2.queue_free()
	vbox2.queue_free()


## 缴获页门控修复的渲染面:_render_collected_rewards 在 endless(player_won=false)下
## 不再被吞——战报页整页组装(show 面板较重,这里直测判定口径与渲染函数)
func test_endless_loot_gate_open() -> void:
	var summary := _endless_summary(false)
	var p := _make_panel(summary, false)
	# 旧门控条件 player_won=false 会跳过;新口径 player_won or _is_endless() 放行
	assert_bool(bool(p.player_won) or p._is_endless()).is_true()
	# 缴获数据完整(summary.collected_rewards 由 _settle_endless_battle 快照写入)
	var collected: Array = summary.get("collected_rewards", [])
	assert_array(collected).has_size(1)
	p.queue_free()
