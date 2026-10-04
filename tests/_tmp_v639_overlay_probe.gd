extends Node
## v6.39 overlay 探针：进度标签 + 跳过确认框渲染验证（窗口化跑）。

func _ready() -> void:
	var tpm := get_node("/root/TutorialProgressionManager")
	tpm.current_step = 1  # INTRO_WELCOME（第 1/14 步）
	tpm.completed_steps = []
	tpm.chain_paused = false
	tpm.pending_close_surface = ""
	var overlay: Node = load("res://scenes/ui/tutorial_overlay.tscn").instantiate()
	add_child(overlay)
	await get_tree().create_timer(0.6).timeout
	var fails := 0
	var lbl: Label = overlay.get_node_or_null("TutorialBox/Margin/VBox/StepLabel")
	if lbl == null or lbl.visible == false or not str(lbl.text).contains("1 / 14"):
		printerr("FAIL StepLabel 进度异常: ", lbl.text if lbl else "<null>", " visible=", lbl.visible if lbl else false)
		fails += 1
	else:
		print("  ok  进度标签: ", lbl.text)
	# 跳过 → 确认框（不确认，直接截图）
	overlay.get_node("TutorialBox/Margin/VBox/ButtonRow/SkipButton").pressed.emit()
	await get_tree().create_timer(0.4).timeout
	var dlg: ConfirmationDialog = null
	for c in overlay.get_children():
		if c is ConfirmationDialog:
			dlg = c
	if dlg == null or not dlg.visible:
		printerr("FAIL 跳过确认框未弹出")
		fails += 1
	else:
		print("  ok  跳过确认框已弹出: ", str(dlg.dialog_text).left(20), "...")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/v639_skip_confirm_shot.png"))
	print("V639_OVERLAY_OK" if fails == 0 else "V639_OVERLAY_FAIL(%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
