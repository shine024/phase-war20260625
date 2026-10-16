extends GdUnitTestSuite
## v6.70 回归锁：贴图导入无损政策（背景发糊主诉根修批）。
## 不变式：①assets/ 下所有纹理导入零 VRAM 压缩、零 size_limit；②detect_3d 自动压缩全禁
## （弹道/蜂群走 QuadMesh 3D 渲染，曾把特效目录静默重压回 VRAM——复发机制实锤）；
## ③project.godot 锁 hidpi 与 importer_defaults 两处防回归设置。
## ⚠️ 若本锁红：有人动过 .import 或项目设置——先读 AGENTS.md v6.70 节再改，勿顺手放行。

const _SCAN_ROOTS := ["res://assets"]
const _FX_DIRS_FIXED := [
	"res://assets/effects/dot",
	"res://assets/effects/explosion_frames",
	"res://assets/effects/nuclear",
	"res://assets/effects/spell_burst",
	"res://assets/effects/ultimate_projectiles",
	"res://assets/effects/projectiles/omega_platform",
	"res://assets/effects/projectiles/weapons_realistic",
]
const _BG_DIR := "res://assets/backgrounds"


func _read_param(txt: String, key: String) -> String:
	for line in txt.split("\n"):
		var s := line.strip_edges()
		if s.begins_with(key + "="):
			return s.substr(key.length() + 1)
	return ""


func _collect_import_files(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path + "/" + name
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect_import_files(full, out)
		elif name.ends_with(".png.import"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func test_backgrounds_are_lossless() -> void:
	var files: PackedStringArray = []
	_collect_import_files(_BG_DIR, files)
	assert_int(files.size()).is_greater(100)
	var bad: Array = []
	for f in files:
		var mode := _read_param(FileAccess.get_file_as_string(f), "compress/mode")
		if mode != "0":
			bad.append("%s compress/mode=%s" % [f, mode])
	assert_array(bad).is_empty()


func test_combat_vfx_are_lossless() -> void:
	var bad: Array = []
	for dir_path in _FX_DIRS_FIXED:
		var files: PackedStringArray = []
		_collect_import_files(dir_path, files)
		assert_int(files.size()).is_greater(0)
		for f in files:
			var mode := _read_param(FileAccess.get_file_as_string(f), "compress/mode")
			if mode != "0":
				bad.append("%s compress/mode=%s" % [f, mode])
	assert_array(bad).is_empty()


func test_no_texture_has_vram_size_limit_or_detect3d() -> void:
	var files: PackedStringArray = []
	for root in _SCAN_ROOTS:
		_collect_import_files(root, files)
	assert_int(files.size()).is_greater(2000)
	var vram: Array = []
	var sized: Array = []
	var detect3d: Array = []
	for f in files:
		var txt := FileAccess.get_file_as_string(f)
		if _read_param(txt, "compress/mode") == "2":
			vram.append(f)
		var sl := _read_param(txt, "process/size_limit")
		if sl != "" and sl != "0":
			sized.append("%s size_limit=%s" % [f, sl])
		if _read_param(txt, "detect_3d/compress_to") == "1":
			detect3d.append(f)
	assert_array(vram).is_empty()
	assert_array(sized).is_empty()
	assert_array(detect3d).is_empty()


func test_project_settings_locks() -> void:
	var proj := FileAccess.get_file_as_string("res://project.godot")
	# hidpi：高缩放显示器原生分辨率渲染（v6.70 用户拍板开启）
	assert_bool(proj.contains("window/dpi/allow_hidpi=true")).is_true()
	# importer_defaults：新贴图默认禁 detect_3d 自动压缩（防新资产复发）
	assert_bool(proj.contains("\"detect_3d/compress_to\": 0")).is_true()
