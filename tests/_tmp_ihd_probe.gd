extends Node
## v6.14 探针：情报收获事件化摘要的视觉验收（两态并排截图）
## A=有事件仗（首遇/新揭示/跨档/常规混合）；B=纯常规仗（只剩汇总行）。

func _ready() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)

	var data_a := {
		"harvests": [
			{"card_id": "ww1_inf_mp18", "enemy_type": "infantry", "first_encounter": true,
				"mod_points": 2, "dimensions": {"intel": {"old_val": 0.0, "new_val": 0.12, "delta": 0.12}}},
			{"card_id": "ww1_arm_a7v", "enemy_type": "heavy_armor", "first_encounter": false,
				"dimensions": {"intel": {"old_val": 0.70, "new_val": 0.74, "delta": 0.04}}},
			{"card_id": "ww1_inf_flame", "enemy_type": "flame", "first_encounter": false,
				"dimensions": {"intel": {"old_val": 0.20, "new_val": 0.50, "delta": 0.30}}},
			{"card_id": "ww1_inf_sniper_x", "enemy_type": "stealth", "first_encounter": false,
				"dimensions": {"intel": {"old_val": 0.10, "new_val": 0.12, "delta": 0.02}}},
			{"card_id": "ww1_arty_m81_x", "enemy_type": "artillery", "first_encounter": false,
				"dimensions": {"intel": {"old_val": 0.30, "new_val": 0.33, "delta": 0.03}}},
			{"card_id": "ww1_sup_ford_x", "enemy_type": "infantry", "first_encounter": false,
				"dimensions": {"intel": {"old_val": 0.40, "new_val": 0.42, "delta": 0.02}}},
		],
		"reveal_events": [{"card_id": "ww1_arm_a7v"}],
		"intel_item_drops": [{"name": "blueprint_inf_14_knee_pads", "desc": "改造图纸 ×1（安装消耗品）"}],
	}
	var data_b := {
		"harvests": [
			{"card_id": "ww1_inf_mauser_x", "enemy_type": "infantry", "first_encounter": false,
				"dimensions": {"intel": {"old_val": 0.60, "new_val": 0.63, "delta": 0.03}}},
			{"card_id": "ww1_arm_ft17_x", "enemy_type": "heavy_armor", "first_encounter": false,
				"dimensions": {"intel": {"old_val": 0.55, "new_val": 0.57, "delta": 0.02}}},
			{"card_id": "ww1_arty_m81_y", "enemy_type": "artillery", "first_encounter": false,
				"dimensions": {"intel": {"old_val": 0.44, "new_val": 0.47, "delta": 0.03}}},
		],
		"reveal_events": [],
		"intel_item_drops": [],
	}

	for i in range(2):
		var ui := preload("res://scenes/ui/intel_harvest_display.gd").new()
		ui.set_data(data_a if i == 0 else data_b)
		var wrap := PanelContainer.new()
		wrap.position = Vector2(40, 40 + i * 0)
		wrap.custom_minimum_size = Vector2(640, 0)
		wrap.add_child(ui)
		var slot := VBoxContainer.new()
		slot.position = Vector2(40, 40 if i == 0 else 320)
		slot.custom_minimum_size = Vector2(640, 0)
		slot.add_child(wrap)
		host.add_child(slot)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.godot/agent_tools/intel_harvest_probe.png")
	print("[probe] saved")
	get_tree().quit(0)
