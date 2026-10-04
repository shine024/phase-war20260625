## unit_anims 条带契约冒烟：counts 与 sheet 实宽精确锁（v6.39 立项）
## 背景：2026-10-03 美术体检发现 drop_smg_mk2/drop_thunder_field 的 anim.json counts(8/12)
## 大于条带实帧(6/10)——_load_seq 按 counts 盲切越界区域渲染全空，战斗中单位周期性隐身。
## 本冒烟全量扫描 unit_anims，锁死 bug 类：sheet 实宽必须 == counts*frame_size。
## boss 独立帧目录（idle_f0.png 散帧、无 anim.json）不在契约内，跳过。
## 运行：Godot --headless --path . --script tests/unit_anim_sheet_dims_smoke.gd
extends SceneTree

const ANIM_ROOT := "res://assets/effects/unit_anims/"

var _pass: int = 0
var _fail: int = 0
var _checked: int = 0
var _bad: PackedStringArray = []

func _initialize() -> void:
	var dir := DirAccess.open(ANIM_ROOT)
	if dir == null:
		printerr("[sheet-dims] unit_anims 目录打不开")
		quit(1)
		return
	for d in dir.get_directories():
		var aj_path := ANIM_ROOT + d + "/anim.json"
		if not FileAccess.file_exists(aj_path):
			continue  # boss 散帧目录等，无契约
		var fj := FileAccess.open(aj_path, FileAccess.READ)
		var meta_v: Variant = JSON.parse_string(fj.get_as_text())
		if typeof(meta_v) != TYPE_DICTIONARY:
			_fail_unit(d, "anim.json 解析失败")
			continue
		var meta: Dictionary = meta_v
		if not meta.has("counts"):
			continue  # boss 散帧目录（仅 outline 元数据，无 sheet 契约，归 boss_idle 冒烟管）
		var fs := int(meta.get("frame_size", 0))
		if fs <= 0:
			_fail_unit(d, "frame_size 非法")
			continue
		var counts: Dictionary = meta.get("counts", {})
		var any := false
		for kind: String in ["idle", "attack"]:
			var n := int(counts.get(kind, 0))
			var sheet_path := ANIM_ROOT + d + "/sheet_%s.png" % kind
			var exists := ResourceLoader.exists(sheet_path)
			if n > 0:
				any = true
				if not exists:
					_fail_unit(d, "counts.%s=%d 但条带缺失" % [kind, n])
					continue
				var tex: Texture2D = load(sheet_path)
				if tex == null:
					_fail_unit(d, "%s 条带加载失败" % kind)
					continue
				var w := int(tex.get_width())
				var h := int(tex.get_height())
				if w != n * fs or h != fs:
					_fail_unit(d, "%s 实宽 %dx%d != counts %d × fs %d" % [kind, w, h, n, fs])
				else:
					_pass += 1
			elif exists:
				# counts=0 却留着条带 = 陈旧孤儿（同一管线脱同步的另一种表现）
				_fail_unit(d, "counts.%s=0 但条带仍在（陈旧孤儿）" % kind)
		if any:
			_checked += 1
	print("=== unit_anims 条带契约: %d 目录已检 / %d pass / %d fail ===" % [_checked, _pass, _fail])
	for b in _bad:
		printerr("  [FAIL] " + b)
	print("=== 结果: %s ===" % ("PASS" if _fail == 0 else "FAIL"))
	quit(0 if _fail == 0 else 1)

func _fail_unit(dir_name: String, msg: String) -> void:
	_fail += 1
	_bad.append("%s: %s" % [dir_name, msg])
