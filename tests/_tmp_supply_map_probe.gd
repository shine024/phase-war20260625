extends Control
## v6.71 步骤5 视觉探针：实例化 world_map（s12 布局）→ 真实渲染截屏落盘 → 退出。
## CLI 窗口化运行（非 headless——验证纪律：渲染类必须真实渲染目检）。


func _ready() -> void:
	var wm: Control = preload("res://scenes/world_map.tscn").instantiate()
	add_child(wm)
	for i in range(6):
		await get_tree().process_frame
	await get_tree().create_timer(1.2).timeout
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.godot/v671_shots")
	var err := img.save_png("res://.godot/v671_shots/world_map_s12.png")
	print("[probe] saved err=", err, " size=", img.get_width(), "x", img.get_height())
	get_tree().quit()
