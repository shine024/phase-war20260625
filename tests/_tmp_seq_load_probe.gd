## 2026-10-03 战斗美术体检·B 维度修复引擎侧探针：
## ① counts 对齐回归锁——sheet 实宽必须 == counts*frame_size（越界空帧 bug 类的根断言）
## ② AtlasTexture 区域逐帧不越界
## ③ 羽化处理后 6 单位条带经 Godot 导入器完整可载
## 运行：--headless --path . --script tests/_tmp_seq_load_probe.gd
extends SceneTree

const UnitFrameAnim := preload("res://scripts/battle/unit_frame_anim.gd")
## 2 个 counts 修复 + 6 个羽化单位
const UNITS := [
	"drop_smg_mk2", "drop_thunder_field",
	"fut_fort_ion", "cold_sup_zsu23", "ww1_av7",
	"fut_swarm", "fut_arm_prism", "mod_fort_phalanx",
]

var _pass: int = 0
var _fail: int = 0

func _initialize() -> void:
	print("=== 序列加载引擎探针（%d 单位）===" % UNITS.size())
	for id: String in UNITS:
		_probe_unit(id)
	print("=== 结果: %d pass / %d fail ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ✓ " + label)
	else:
		_fail += 1
		print("  [FAIL] " + label)

func _probe_unit(id: String) -> void:
	var key := UnitFrameAnim._resolve_key(id)
	_ok(not key.is_empty(), "%s _resolve_key 命中 → %s" % [id, key])
	if key.is_empty():
		return
	var aj := FileAccess.open("res://assets/effects/unit_anims/%s/anim.json" % key, FileAccess.READ)
	if aj == null:
		_ok(false, "%s anim.json 缺失" % key)
		return
	var meta: Dictionary = JSON.parse_string(aj.get_as_text())
	var fs := int(meta.get("frame_size", 0))
	_ok(fs > 0, "%s frame_size=%d" % [key, fs])
	var counts: Dictionary = meta.get("counts", {})
	for kind: String in ["idle", "attack"]:
		var n := int(counts.get(kind, 0))
		if n <= 0:
			continue
		var sheet_path := "res://assets/effects/unit_anims/%s/sheet_%s.png" % [key, kind]
		var sheet: Texture2D = load(sheet_path)
		if sheet == null:
			_ok(false, "%s %s 条带加载失败" % [key, kind])
			continue
		var w := int(sheet.get_width())
		var h := int(sheet.get_height())
		# 根断言：实宽必须精确等于 counts*frame_size（counts>实宽→越界空帧；<→尾帧丢失）
		_ok(w == n * fs and h == fs,
			"%s %s 实宽 %d == counts %d × fs %d" % [key, kind, w, n, fs])
		# 序列缓存路径取帧，逐帧区域不越界
		var frames := UnitFrameAnim._load_seq(key, kind, n, fs)
		var oob := 0
		for f in frames:
			var at := f as AtlasTexture
			if at == null or at.region.position.x + at.region.size.x > float(w):
				oob += 1
		_ok(frames.size() == n and oob == 0,
			"%s %s 序列 %d 帧 / 越界 %d" % [key, kind, frames.size(), oob])
