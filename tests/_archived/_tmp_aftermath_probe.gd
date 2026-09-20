## tests/_tmp_aftermath_probe.gd — v27.19 余波层隔离探针 R2：
## 完全复刻 boss_spell_audit 的引擎调用链（同 mock driver/同函数），1.03s 截图。
## 若可见 → 审计工具有环境差异；若不可见 → 引擎函数内部问题。
## 跑法：godot --path . --resolution 1280x720 res://tests/_tmp_aftermath_probe.tscn
extends Node2D

const SkillEngine = preload("res://managers/battle/enemy_master_skill_engine.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")

var _engine: RefCounted
var _boss_mock: Node2D

func _ready() -> void:
	var _win: Window = get_window()
	_win.borderless = true
	_win.size = Vector2i(1280, 720)
	_win.position = Vector2i(0, 0)
	var bg := ColorRect.new()
	bg.color = Color(0.078, 0.086, 0.11, 1.0)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	var box := ColorRect.new()
	box.color = Color(1.0, 0.45, 0.25, 0.15)
	box.size = Vector2(96, 96)
	box.position = Vector2(1050 - 48, 430 - 96)
	add_child(box)
	for i in 3:
		var dummy := Node2D.new()
		dummy.position = Vector2(200, 330.0 + 100.0 * i)
		dummy.add_to_group("player_units")
		dummy.set_meta("hp", 500.0)
		add_child(dummy)
	_engine = SkillEngine.new()
	_boss_mock = Node2D.new()
	_boss_mock.position = Vector2(1050, 430)
	add_child(_boss_mock)
	_engine.setup(_boss_mock, self)
	print("[probe] children before trigger=", get_child_count())
	# R3：先跑 inferno（等 2.6s + 清场，复刻审计案序），再跑 chain
	_engine._play_inferno_cinematic("hell_inferno", "测试相位师")
	await get_tree().create_timer(2.6).timeout
	var _stage_count := get_child_count()
	for c in get_children().slice(6, _stage_count):   # 跳过 bg/box/3 dummy/boss_mock 等 6 布景
		if not VfxImpactFactory.release_to_pool(c):
			remove_child(c)
			c.queue_free()
	print("[probe] after inferno+clear=", get_child_count())
	_engine._play_chain_cinematic("tesla_chain", "测试相位师")
	print("[probe] children after chain trigger=", get_child_count())
	await get_tree().create_timer(1.03).timeout
	print("[probe] children at capture=", get_child_count())
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://docs/boss_spell_shots/_aftermath_probe3.png")
	print("[probe3] saved")
	get_tree().quit(0)
