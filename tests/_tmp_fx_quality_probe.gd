extends SceneTree
## 临时探针：解码特效目录实际导入纹理（修复复检用），落盘供与源 PNG 逐像素对比。

func _initialize() -> void:
	var out_dir := "res://.godot/bg_quality_probe"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var paths := [
		"res://assets/effects/projectiles/weapons_realistic/weapon_artillery_impact.png",
		"res://assets/effects/nuclear/nuke_fireball.png",
		"res://assets/effects/spell_burst/chain_lightning.png",
		"res://assets/effects/explosion_frames/explosion_conv_f0.png",
	]
	for path in paths:
		var tex := load(path) as Texture2D
		if tex == null:
			push_error("load failed: " + path)
			continue
		var img := tex.get_image()
		if img == null or img.is_empty():
			push_error("get_image empty: " + path)
			continue
		var base: String = path.get_file().get_basename()
		print(base, " imported fmt=", img.get_format(), " size=", img.get_size())
		img.convert(Image.FORMAT_RGBA8)
		img.save_png(out_dir + "/fx_%s_imported.png" % base)
	quit()
