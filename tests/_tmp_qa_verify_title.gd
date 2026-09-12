extends SceneTree
## 可玩性检查修复验证（临时工具）：标题屏截图——移动基地英文副标 + SlotLabel 缩进
## 用法：godot --rendering-driver opengl3 --path . --script tests/_tmp_qa_verify_title.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	await process_frame
	var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	root.add_child(title)
	current_scene = title
	# 等入场动画推进到按钮就位（_play_intro_animation 有淡入链）
	for i in 240:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png("res://.godot/agent_tools/qa_verify_title.png")
		print("[VerifyTitle] saved")
	else:
		print("[VerifyTitle] EMPTY capture")
	quit(0)
