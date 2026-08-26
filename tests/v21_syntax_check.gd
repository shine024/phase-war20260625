extends SceneTree
## v21.x 改动文件语法冒烟：load() 触发编译但不执行
## 用法: godot --headless --rendering-driver opengl3 --path . --script tests/v21_syntax_check.gd

var files := [
	"res://data/phase_instruments.gd",
	"res://managers/phase_instrument_manager.gd",
	"res://scenes/ui/store_panel.gd",
	"res://scenes/ui/phase_instrument_selector.gd",
	"res://scenes/ui/bottom_instrument_bar.gd",
	"res://scenes/ui/backpack_panel.gd",
	"res://scenes/battlefield/Battlefield.gd",
]

func _initialize() -> void:
	var failed: Array[String] = []
	for f in files:
		var s = load(f)
		if s == null:
			failed.append(f)
		else:
			print("OK  %s" % f)
	if failed.is_empty():
		print("[v21_syntax_check] PASS — %d 个文件全部编译通过" % files.size())
		quit(0)
	else:
		print("[v21_syntax_check] FAIL — %d 个文件加载失败" % failed.size())
		for f in failed:
			print("  FAIL %s" % f)
		quit(1)
