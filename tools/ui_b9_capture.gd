extends SceneTree
## 批次三 B9（2026-08-25）：分辨率适配截图工具。
## 用法（带窗口跑，闪一下窗口属预期）：
##   UI_B9_W=1680 UI_B9_H=720 godot --path . --script tools/ui_b9_capture.gd
## --script 模式下 --resolution 旗标无效，环境变量在首帧窗口就绪后手动设尺寸。
## 截图存 user://ui_b9/<WxH>.png，供四档分辨率（16:9/16:10/21:9/超宽）人工验收
## 顶栏资源、底栏槽位、面板居中出血是否破版。

var _frames := 0
var _resized := false
const WAIT_FRAMES := 300  # resize 后约 5 秒，等面板/底栏构建完成

func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")

func _process(_delta: float) -> bool:
	if not _resized:
		_resized = true
		var w := int(OS.get_environment("UI_B9_W"))
		var h := int(OS.get_environment("UI_B9_H"))
		print("[B9] env=", w, "x", h)
		if w > 0 and h > 0:
			DisplayServer.window_set_size(Vector2i(w, h))
		_frames = 0
		return false
	_frames += 1
	if _frames < WAIT_FRAMES:
		return false
	var win := DisplayServer.window_get_size()
	var tag := "%dx%d" % [int(win.x), int(win.y)]
	var dir := "user://ui_b9"
	DirAccess.make_dir_recursive_absolute(dir)
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [dir, tag]
	img.save_png(path)
	print("[B9] screenshot -> ", path)
	quit()
	return true
