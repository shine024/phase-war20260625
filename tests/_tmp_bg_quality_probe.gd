extends SceneTree
## 临时探针：解码实际导入的背景纹理（游戏真正渲染的字节），落盘供与源 PNG 对比。
## 用法：godot --path . --script tests/_tmp_bg_quality_probe.gd（窗口化，非 headless——CompressedTexture2D 解码需真渲染器）

func _initialize() -> void:
	var out_dir := "res://.godot/bg_quality_probe"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var keys := ["bg_level_01", "bg_level_05", "bg_level_09"]
	for key in keys:
		var path := "res://assets/backgrounds/%s.png" % key
		var tex := load(path) as Texture2D
		if tex == null:
			push_error("load failed: " + path)
			continue
		var img := tex.get_image()
		if img == null or img.is_empty():
			push_error("get_image empty: " + path)
			continue
		print(key, " imported fmt=", img.get_format(), " size=", img.get_size())
		img.convert(Image.FORMAT_RGB8)
		var out := out_dir + "/%s_imported.png" % key
		img.save_png(out)
		print("saved ", out)
	quit()
