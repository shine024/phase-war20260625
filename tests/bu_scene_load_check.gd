extends SceneTree
## BU（战斗界面美化，2026-08-24）场景资源加载校验。
## 只 instantiate 不进树（跑 _init/解析链，不触发依赖 autoload 的 _ready），
## 秒级捕获 tscn 结构错/脚本挂载断链。用法：
##   godot --headless --path . --script tests/bu_scene_load_check.gd

const SCENES: Array[String] = [
	"res://scenes/ui/settings_panel.tscn",
	"res://scenes/ui/bottom_instrument_bar.tscn",
	"res://scenes/ui/bottom_function_bar.tscn",
	"res://scenes/ui/top_hud_bar.tscn",
	"res://scenes/ui/battle_announcer.tscn",
	"res://scenes/ui/battle_log.tscn",
	"res://scenes/ui/buff_fold_card.tscn",
	"res://scenes/units/unit_hp_bar.tscn",
	"res://scenes/units/phase_field_driver.tscn",
	"res://scenes/units/enemy_phase_field_driver.tscn",
	"res://scenes/battlefield/battlefield.tscn",
]

func _init() -> void:
	var fails: Array[String] = []
	for path in SCENES:
		var packed: PackedScene = load(path)
		if packed == null:
			fails.append("load 失败: %s" % path)
			continue
		var inst: Node = packed.instantiate()
		if inst == null:
			fails.append("实例化失败: %s" % path)
			continue
		inst.free()
	if fails.is_empty():
		print("✅ BU 场景加载校验 ALL PASS（%d 个 tscn）" % SCENES.size())
	else:
		for f in fails:
			print("❌ " + f)
		print("❌ BU 场景加载校验 FAIL（%d/%d）" % [fails.size(), SCENES.size()])
	quit(0 if fails.is_empty() else 1)
