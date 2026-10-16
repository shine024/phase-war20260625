extends SceneTree
## 临时探针：真实渲染链验证——把导入后背景经 Sprite2D 1:1 画进窗口并截屏（复刻 battlefield.gd 的直绘方式）。

func _initialize() -> void:
	_run()

func _run() -> void:
	var out_dir := "res://.godot/bg_quality_probe"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for key in ["bg_level_01", "bg_level_05"]:
		var spr := Sprite2D.new()
		spr.texture = load("res://assets/backgrounds/%s.png" % key)
		spr.centered = false
		root.add_child(spr)
		await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		img.save_png(out_dir + "/render_%s.png" % key)
		print("rendered ", key, " ", img.get_size())
		spr.queue_free()
		await process_frame
	quit()
