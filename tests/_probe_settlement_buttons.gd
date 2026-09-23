extends Node
## [诊断探针，用完即删] 胜利结算面板按钮几何 dump v2——伪造玩家中期状态
## （教程完 / 1-5 关解锁 / 第 3 关胜利 / BunkerManager 在场）复现用户实机四键布局。

class FakeBunker extends Node:
	func get_day() -> int: return 3
	func get_sanity() -> float: return 80.0
	func get_hero_fragment_count() -> int: return 2
	func get_drop_reward_multiplier() -> float: return 1.0
	func get_room_state(_rid: String) -> int: return 0
	func get_room_progress(_rid: String) -> float: return 0.0
	func is_repair_frozen(_rid: String) -> bool: return false
	func get_completed_today() -> Array: return []

func _ready() -> void:
	await get_tree().process_frame
	var gm := get_node("/root/GameManager")
	var lpm := get_node("/root/LevelProgressManager")
	var tpm := get_node("/root/TutorialProgressionManager")
	tpm.skip_tutorial()
	for lv in [1, 2, 3, 4, 5]:
		if not lpm.is_level_unlocked(lv):
			lpm.unlocked_levels.append(lv)
	lpm.max_unlocked_level = 5
	gm.current_level = 3
	gm._pending_battle_level = 3
	var fb := FakeBunker.new()
	fb.name = "BunkerManager"
	get_tree().root.add_child(fb)

	var panel: Control = load("res://scenes/ui/mvp_panel.gd").create(self, true, [], 0, 1, {}, false)
	await get_tree().process_frame
	await get_tree().process_frame
	print("=== flags: afk=%s bunker=%s next=%d replay=%d ===" % [
		str(panel.get("_is_afk")), str(panel.get("_bunker_return_available")),
		panel.get("_next_level"), panel.get("_replay_level")])
	var overlay := panel.get_node_or_null("MvpPanelOverlay")
	var p: Control = overlay.get_node("Panel")
	print("Panel rect=", p.get_global_rect())
	var btns: Array = []
	for ch in p.get_children():
		if ch is Button and ch.visible:
			btns.append(ch)
			print("BTN rect=", ch.get_global_rect(), " text=", ch.text)
	for i in btns.size():
		for j in range(i + 1, btns.size()):
			var a: Rect2 = btns[i].get_global_rect()
			var b: Rect2 = btns[j].get_global_rect()
			var inter := a.intersection(b)
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				print("OVERLAP! [%s] x [%s] inter=%s" % [btns[i].text, btns[j].text, inter])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/settlement_probe_v2.png")
	print("SHOT_SAVED")
	get_tree().quit(0)
