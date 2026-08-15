extends Node2D
## v13.1 战斗阵营辨识实拍：左右两侧同屏对比——命中环阵营色 / 攻击追踪线 / 伤害数字双色。

const Vfx = preload("res://scripts/battle/vfx_impact_factory.gd")

var _t: float = 0.0
var _spawned: bool = false
var _shot_done: bool = false

func _ready() -> void:
	# 深色战场底
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.11, 1.0)
	bg.size = Vector2(1280, 720)
	bg.position = Vector2(-640, -360)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# 标注（帮助读图）
	_add_caption("我方攻击（青环 / 青追踪线 / 青数字）", Vector2(-320, -280))
	_add_caption("敌方攻击（橙红环 / 橙红追踪线 / 暖红数字）", Vector2(80, -280))

func _add_caption(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	l.position = pos
	add_child(l)

func _process(delta: float) -> void:
	_t += delta
	if not _spawned and _t >= 0.1:
		_spawned = true
		_spawn_all()
	if _spawned and _t >= 0.24 and not _shot_done:
		_shot_done = true
		_capture()

func _spawn_all() -> void:
	# 左列 = 我方攻击(is_player=true)，右列 = 敌方攻击(is_player=false)
	var i: int = 0
	for wt in [0, 3, 8, 1]:
		var y: float = -160.0 + i * 90.0
		Vfx.spawn_layered_impact(self, Vector2(-280, y), int(wt), true, -1)
		Vfx.spawn_layered_impact(self, Vector2(220, y), int(wt), false, -1)
		i += 1
	# 攻击追踪线：我方(左→右) / 敌方(右→左)
	Vfx.spawn_attack_tracer(self, Vector2(-560, 240), Vector2(-80, 260), true)
	Vfx.spawn_attack_tracer(self, Vector2(520, 240), Vector2(40, 260), false)
	# 伤害数字（对象池）：out=我方输出 / in=敌方输出 / neutral 对照
	var DN = load("res://scenes/effects/damage_number_display.gd")
	DN.create_damage_number(self, Vector2(-280, 60), 55, false, "normal", "out")
	DN.create_damage_number(self, Vector2(-80, 60), 120, true, "critical", "out")
	DN.create_damage_number(self, Vector2(220, 60), 55, false, "normal", "in")
	DN.create_damage_number(self, Vector2(420, 60), 120, true, "critical", "in")

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://panel_tour/vfx_side.png")
	print("[VFXSIDE] shot saved")
	get_tree().quit()
