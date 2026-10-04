extends SceneTree
## v6.42 编译探针：逐个 load 本批修改的 .gd（完整编译含全局类解析），+ 音频资产在位断言。
## 跑法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_v642_compile_probe.gd

const FILES := [
	"res://managers/endless_blackgate_manager.gd",
	"res://managers/bunker_manager.gd",
	"res://managers/audio_manager.gd",
	"res://managers/game_manager.gd",
	"res://scenes/world_map.gd",
	"res://scenes/main.gd",
	"res://scenes/ui/mvp_panel.gd",
	"res://scenes/ui/afk_panel.gd",
	"res://scenes/ui/resource_slot_item.gd",
	"res://scenes/ui/backpack_panel.gd",
	"res://scripts/ui/hover_tip.gd",
	"res://scripts/systems/main_reward.gd",
	"res://scripts/systems/afk_mode_manager.gd",
	"res://scenes/bunker/truck_base.gd",
	"res://scenes/units/bullet.gd",
	"res://managers/battle/simple_player_projectile_batch.gd",
	"res://managers/battle/simple_enemy_projectile_batch.gd",
	"res://managers/battle/simple_indirect_projectile_batch.gd",
	"res://tests/unit/systems/test_travel_cancel.gd",
	"res://tests/unit/battle/test_gate_core_structure.gd",
]
const ASSETS := [
	"res://assets/sfx/button.ogg",
	"res://assets/sfx/win.ogg",
	"res://assets/sfx/cannon_fire.ogg",
	"res://assets/sfx/impact_light.ogg",
	"res://assets/sfx/impact_heavy.ogg",
	"res://assets/sfx/explosion_big.ogg",
	"res://assets/sfx/ambient_wakeup_wind.wav",
]


func _initialize() -> void:
	var fails: Array[String] = []
	for f in FILES:
		var s: Variant = load(f)
		if s == null:
			fails.append("LOAD FAIL: " + f)
	# HoverTip 全局类解析
	if load("res://scripts/ui/hover_tip.gd") == null:
		fails.append("HoverTip load fail")
	for a in ASSETS:
		if not ResourceLoader.exists(a):
			fails.append("ASSET MISSING: " + a)
	# 相位师 JSON 有效性 + 首位名抽查
	var ej: Dictionary = load("res://data/json/enemy_phase_masters.json").data if ResourceLoader.exists("res://data/json/enemy_phase_masters.json") else {}
	# JSON 经 ResourceLoader 是 Dictionary 包装；直接 FileAccess 双保险
	var txt := FileAccess.get_file_as_string("res://data/json/enemy_phase_masters.json")
	if not txt.contains("埃蒂安·勒梅特") or not txt.contains("贺同舟"):
		fails.append("master names check fail")
	# EBM 首场波数逻辑
	var ebm_s: GDScript = load("res://managers/endless_blackgate_manager.gd")
	var ebm: Node = ebm_s.new()
	ebm.gate_cleared_once = false
	ebm.begin_run()
	if int(ebm.gate_core_wave) != int(ebm.FIRST_GATE_CORE_WAVE):
		fails.append("first gate wave != FIRST_GATE_CORE_WAVE (got %d)" % int(ebm.gate_core_wave))
	ebm.gate_cleared_once = true
	ebm.run_active = false
	ebm.begin_run()
	if int(ebm.gate_core_wave) < 200 or int(ebm.gate_core_wave) > 320:
		fails.append("endless roll out of range (got %d)" % int(ebm.gate_core_wave))
	ebm.free()
	for e in fails:
		printerr("[v642-compile] FAIL: " + e)
	print("[v642-compile] %s (%d scripts, %d assets)" % ["PASS" if fails.is_empty() else "FAIL", FILES.size(), ASSETS.size()])
	quit(0 if fails.is_empty() else 1)
