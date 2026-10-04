extends Node
## v6.39 指路标真机探针（窗口化跑，非 headless）：真实 autoload + 真实 truck_base 场景，
## 模拟点播段等待（ENHANCEMENT→growth 工位），验证 TutorialStepPointer 真实亮出，
## 截图落 .godot/v639_pointer_shot.png 供目检。跑前已备份 user:// 存档目录。

func _ready() -> void:
	var tpm := get_node("/root/TutorialProgressionManager")
	# 状态注入：等待技能树工位（覆盖读档态）
	tpm.current_step = 4  # ENHANCEMENT
	tpm.completed_steps = [1, 2, 3, 7]
	tpm.chain_paused = true
	tpm.pending_close_surface = ""
	var base: Node = load("res://scenes/bunker/truck_base.tscn").instantiate()
	add_child(base)
	await get_tree().create_timer(1.5).timeout
	var fails := 0
	var ptr: Node = base.get_node_or_null("TutorialStepPointer")
	if ptr == null:
		printerr("FAIL TutorialStepPointer 未亮出")
		fails += 1
	else:
		print("  ok  TutorialStepPointer 在树上（子节点数=%d）" % ptr.get_child_count())
		if ptr.get_child_count() == 0:
			printerr("FAIL 指路标宿主下无聚光层")
			fails += 1
	# TPM 查询口
	print("  info get_pending_surface=", tpm.get_pending_surface(), " tip=", tpm.get_pointer_tip())
	if String(tpm.get_pending_surface()) != "growth":
		printerr("FAIL pending surface != growth")
		fails += 1
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://.godot/v639_pointer_shot.png"))
	print("  ok  截图已存 v639_pointer_shot.png")
	print("V639_POINTER_OK" if fails == 0 else "V639_POINTER_FAIL(%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
