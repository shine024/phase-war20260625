extends Node2D
## 序章可玩梦境战（docs/开场剧情_10方案.md 方案10-lite，v24.3）
## B2 分格点击后坠入：真实战斗单位/弹道/特效的脚本化四幕——
##   ①抵抗（起始三卡 vs 侦察机甲）②压倒（重装+枢纽压境，红幕）③递卡（未来的自己：
##   "接住它"——唯一交互）④反转（巨神机甲登场清场）→ 回 comic 续播 B3–B7。
##
## 零侵入搭建（复刻 combat_arena_3v3 模式）：BattleManager 只开 spatial_grid+四 batch，
## 单位走真实场景/池；**绝不 emit battle_ended**（不碰奖励/精神值/存档）。
## 干跑（META_DRY_RUN）：压缩时间线自动演完，收尾只发信号+落 meta，不切场景。

signal battle_finished

const GC := preload("res://resources/game_constants.gd")
const DefaultCards := preload("res://data/default_cards.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const UnitStatsTable := preload("res://resources/unit_stats_table.gd")
const ConstructUnitScene := preload("res://scenes/units/construct_unit.tscn")
const EnemyUnitScene := preload("res://scenes/units/enemy_unit.tscn")
const ShakeScript = preload("res://scenes/effects/screen_shake.gd")   # v24.4：战斗同款震屏（含减动效无障碍开关）
const VfxFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const BG_PATH := "res://assets/intro/battle_bg.png"                   # FLOW 生成战场背景（缺图回退平底色）

const META_COMIC_PENDING := "bunker_intro_comic_pending"
const META_WAKEUP := "bunker_intro_wakeup_pending"
const META_DRY_RUN := "bunker_intro_dry_run"
const META_BATTLE_RESUME := "bunker_intro_battle_resume"
const COMIC_SCENE := "res://scenes/intro/comic_intro.tscn"
const BUNKER_SCENE := "res://scenes/bunker/bunker_main.tscn"

const DEFENDERS := ["ww1_mauser", "ww1_arty_m81", "ww1_arm_ft17"]   # v20.31 起始三卡
const FOE_SCOUT := "foe_fut_inf_scout_mech"
const FOE_HEAVY := "foe_fut_arm_heavy_mech"
const FOE_NEXUS := "foe_fut_arm_nexus"
const GOLDEN_CARD_ID := "fut_colossus"        # 巨神机甲——未来的自己递来的卡

const PLAYER_X := 380.0
const ENEMY_X := 900.0
const GROUND_Y := 430.0
const ROW_YS := [370.0, 420.0, 470.0, 340.0, 450.0, 310.0, 480.0, 395.0, 440.0, 355.0]

var DT = preload("res://resources/design_tokens.gd")

enum Phase { FADE_IN, FIGHT, DOOM, ERASE, CARD_OFFER, REVERSAL, DONE }

var _phase: int = Phase.FADE_IN
var _finished := false
var _caught := false
var _player_units: Array = []
var _enemy_units: Array = []
var _spawned_y := 0

var _world: Node2D
var _doom_tint: ColorRect
var _cam: Camera2D
var _ui_layer: CanvasLayer
var _battlefield: Node2D
var _player_units_node: Node2D
var _enemy_units_node: Node2D
var _vignette: ColorRect
var _flash: ColorRect
var _curtain: ColorRect
var _title_label: Label
var _sub_label: Label
var _offer_box: PanelContainer
var _offer_hint: Label
var _skip_btn: Button
var _pulse_tween: Tween

func _ready() -> void:
	DesignTokens.ensure_cjk_fallback()
	_build_layers()
	_setup_battle_manager()
	if AudioManager != null and AudioManager.has_method("play_music"):
		AudioManager.play_music("battle_future")
	_skip_btn.pressed.connect(_skip_all)
	if Engine.has_meta(META_DRY_RUN):
		_run_dry_timeline()
	else:
		_run_timeline()

func _exit_tree() -> void:
	# arena 惯例：还原战斗态与时间缩放，别污染真实战斗
	if BattleManager != null:
		BattleManager.battle_active = false
	Engine.time_scale = 1.0
	get_tree().paused = false

# ───────────────────── 界面搭建 ─────────────────────

func _build_layers() -> void:
	# v24.4：世界层（背景+单位同受相机震动/推近影响）；背景图缺图回退平底色
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	if ResourceLoader.exists(BG_PATH):
		var bg := TextureRect.new()
		bg.texture = load(BG_PATH)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.size = Vector2(1280, 720)
		bg.modulate = Color(0.62, 0.58, 0.6)   # 压暗保单位/字幕可读
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.add_child(bg)
		var ground := ColorRect.new()
		ground.color = Color(0.03, 0.025, 0.03, 0.55)
		ground.position = Vector2(0, GROUND_Y + 46)
		ground.size = Vector2(1280, 720 - GROUND_Y - 46)
		ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.add_child(ground)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.02, 0.02, 0.045)
		bg.size = Vector2(1280, 720)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.add_child(bg)
		var ground := ColorRect.new()
		ground.color = Color(0.05, 0.045, 0.06)
		ground.position = Vector2(0, GROUND_Y + 46)
		ground.size = Vector2(1280, 720 - GROUND_Y - 46)
		ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_world.add_child(ground)
	# 绝境红染（世界层，随震屏；alpha 由 DOOM 段推起）
	_doom_tint = ColorRect.new()
	_doom_tint.color = Color(0.55, 0.05, 0.03, 0.0)
	_doom_tint.size = Vector2(1280, 720)
	_doom_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_doom_tint)
	_build_embers()
	# 相机：震屏 + 26s 缓慢推近（张力）
	_cam = Camera2D.new()
	_cam.name = "DreamCam"
	_cam.position = Vector2(640, 360)
	_cam.set_script(ShakeScript)
	add_child(_cam)
	_cam.make_current()
	var zt := create_tween()
	zt.tween_property(_cam, "zoom", Vector2(1.07, 1.07), 26.0).from(Vector2.ONE)

## 余烬粒子（世界层，全场飘落）
func _build_embers() -> void:
	var p := CPUParticles2D.new()
	p.name = "Embers"
	p.position = Vector2(640, -20)
	p.amount = 42
	p.lifetime = 5.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700, 8)
	p.direction = Vector2(-0.25, 1)
	p.spread = 12.0
	p.gravity = Vector2(12, 26)
	p.initial_velocity_min = 24.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.2
	p.color = Color(1.0, 0.55, 0.2, 0.5)
	_world.add_child(p)

	_battlefield = Node2D.new()
	_battlefield.name = "Battlefield"
	add_child(_battlefield)
	_player_units_node = Node2D.new()
	_player_units_node.name = "PlayerUnits"
	_player_units_node.y_sort_enabled = true   # v24.2 深度层级惯例
	_battlefield.add_child(_player_units_node)
	_enemy_units_node = Node2D.new()
	_enemy_units_node.name = "EnemyUnits"
	_enemy_units_node.y_sort_enabled = true
	_battlefield.add_child(_enemy_units_node)

	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	_vignette = ColorRect.new()
	_vignette.color = Color(0.7, 0.06, 0.04, 0.0)
	_vignette.size = Vector2(1280, 720)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_vignette)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = Vector2(1280, 720)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_flash)

	_title_label = Label.new()
	_title_label.position = Vector2(140, 96)
	_title_label.size = Vector2(1000, 56)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
	_title_label.modulate.a = 0.0
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_title_label)
	_sub_label = Label.new()
	_sub_label.position = Vector2(140, 160)
	_sub_label.size = Vector2(1000, 44)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_LARGE)
	_sub_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78, 0.9))
	_sub_label.modulate.a = 0.0
	_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_sub_label)

	_offer_box = _build_offer_card()
	_ui_layer.add_child(_offer_box)

	_skip_btn = Button.new()
	_skip_btn.text = "跳过序章 ▸"
	_skip_btn.position = Vector2(1130, 14)
	_skip_btn.size = Vector2(136, 38)
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var styles: Dictionary = preload("res://scripts/ui/panel_styles.gd").make_button_styles(Color(0.45, 0.48, 0.55), "solid")
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		_skip_btn.add_theme_stylebox_override(key, styles[key])
	_skip_btn.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	_skip_btn.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	_ui_layer.add_child(_skip_btn)

	_curtain = ColorRect.new()
	_curtain.color = Color(0, 0, 0, 1)
	_curtain.size = Vector2(1280, 720)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_curtain)
	var tw := create_tween()
	tw.tween_property(_curtain, "color:a", 0.0, 0.9)

func _build_offer_card() -> PanelContainer:
	var box := PanelContainer.new()
	box.position = Vector2(490, 240)
	box.size = Vector2(300, 220)
	box.visible = false
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.03, 0.96)
	sb.border_color = Color(1.0, 0.78, 0.32)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_size = 24
	sb.shadow_color = Color(1.0, 0.72, 0.32, 0.35)
	sb.set_content_margin_all(18.0)
	box.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	box.add_child(vbox)
	var tag := Label.new()
	tag.text = "精神具现 · 初始卡"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	tag.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	vbox.add_child(tag)
	var name_lbl := Label.new()
	var card = DefaultCards.get_card_by_id(GOLDEN_CARD_ID)
	name_lbl.text = str(card.display_name) if card != null and str(card.display_name) != "" else GOLDEN_CARD_ID
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", DT.FONT_SIZE_TITLE)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
	vbox.add_child(name_lbl)
	_offer_hint = Label.new()
	_offer_hint.text = "「接住它。」——梦里的你\n点击接住 ▼"
	_offer_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_offer_hint.add_theme_font_size_override("font_size", DT.FONT_SIZE_BODY)
	_offer_hint.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	vbox.add_child(_offer_hint)
	return box

# ───────────────────── BattleManager 就绪（arena 模式） ─────────────────────

func _setup_battle_manager() -> void:
	if BattleManager == null:
		push_error("[DreamBattle] BattleManager autoload 不存在")
		return
	BattleManager.battlefield = _battlefield
	if BattleManager.spatial_grid == null or not is_instance_valid(BattleManager.spatial_grid):
		BattleManager._setup_spatial_grid()
	if BattleManager.player_projectile_batch == null or not is_instance_valid(BattleManager.player_projectile_batch):
		BattleManager._setup_player_projectile_batch()
	if BattleManager.enemy_projectile_batch == null or not is_instance_valid(BattleManager.enemy_projectile_batch):
		BattleManager._setup_enemy_projectile_batch()
	if BattleManager.player_indirect_batch == null or not is_instance_valid(BattleManager.player_indirect_batch):
		BattleManager._setup_player_indirect_batch()
	if BattleManager.enemy_indirect_batch == null or not is_instance_valid(BattleManager.enemy_indirect_batch):
		BattleManager._setup_enemy_indirect_batch()
	BattleManager.battle_active = true

# ───────────────────── 单位生成（arena 同款） ─────────────────────

func _next_y() -> float:
	var y: float = ROW_YS[_spawned_y % ROW_YS.size()]
	_spawned_y += 1
	return y

func _spawn_player_card(card_id: String, pos: Vector2) -> Node:
	var card = DefaultCards.get_card_by_id(card_id)
	if card == null:
		push_warning("[DreamBattle] 找不到我方卡: " + card_id)
		return null
	var u = ConstructUnitScene.instantiate()
	_player_units_node.add_child(u)
	var s = UnitStatsTable.build_stats_from_card(card.clone())   # 模板只读，clone 构建 stats（养成隔离铁律）
	u.setup(true, s)
	u.global_position = pos
	if u.has_method("apply_card_grid_combat_started"):
		u.apply_card_grid_combat_started()
	if BattleManager != null and BattleManager.spatial_grid != null:
		BattleManager.spatial_grid.insert(u)
	_player_units.append(u)
	return u

func _spawn_foe(archetype_id: String, pos: Vector2, count := 1) -> void:
	for i in count:
		var e = EnemyUnitScene.instantiate()
		_enemy_units_node.add_child(e)
		e.setup(false, 1, archetype_id)   # wave=1 免难度缩放
		e.global_position = Vector2(pos.x + randf_range(-30.0, 30.0), pos.y)
		if e.has_method("apply_card_grid_enemy_presentation"):
			e.apply_card_grid_enemy_presentation()
		if BattleManager != null and BattleManager.spatial_grid != null:
			BattleManager.spatial_grid.insert(e)
		_enemy_units.append(e)

func _spawn_defenders() -> void:
	for i in DEFENDERS.size():
		_spawn_player_card(DEFENDERS[i], Vector2(PLAYER_X, ROW_YS[i]))

func _alive(units: Array) -> int:
	var n := 0
	for u in units:
		if u != null and is_instance_valid(u) and float(u.hp) > 0.0:
			n += 1
	return n

## 绝境段脚本化炮击：随机砸一名幸存防守者（视觉+震屏，不直接扣血——战局交给真实弹道）
func _scripted_strike() -> void:
	var targets: Array = []
	for u in _player_units:
		if u != null and is_instance_valid(u) and float(u.hp) > 0.0:
			targets.append(u)
	if targets.is_empty():
		return
	var u = targets[randi() % targets.size()]
	var pos: Vector2 = u.global_position + Vector2(randf_range(-26.0, 26.0), randf_range(-14.0, 14.0))
	VfxFactory.spawn_shockwave(_battlefield, pos, 56.0, Color(1.0, 0.5, 0.2, 0.85), 2.0)
	VfxFactory.spawn_smoke_column(_battlefield, pos + Vector2(0, -10))
	ShakeScript.light_shake(_cam)

# ───────────────────── 字幕 / 特效助手 ─────────────────────

func _say(title: String, sub: String, fade := 0.6) -> void:
	_title_label.text = title
	_sub_label.text = sub
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_title_label, "modulate:a", 1.0, fade)
	tw.tween_property(_sub_label, "modulate:a", 1.0, fade).set_delay(0.2)

func _fade_caption(out_delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(out_delay)
	tw.set_parallel(true)
	tw.tween_property(_title_label, "modulate:a", 0.0, 0.5)
	tw.tween_property(_sub_label, "modulate:a", 0.0, 0.5)

func _play_sfx(sfx_name: String) -> void:
	if SignalBus != null and SignalBus.has_signal("play_sound"):
		SignalBus.play_sound.emit(sfx_name)

# ───────────────────── 正式时间线 ─────────────────────

func _run_timeline() -> void:
	# ① 抵抗
	_say("入侵之夜", "这一夜，梦不再是梦。")
	await get_tree().create_timer(1.2).timeout
	if _finished: return
	_spawn_defenders()
	_spawn_foe(FOE_SCOUT, Vector2(ENEMY_X, ROW_YS[0]), 3)
	VfxFactory.spawn_shockwave(_battlefield, Vector2(ENEMY_X, 420.0), 90.0, Color(1.0, 0.45, 0.2, 0.85), 2.0)
	ShakeScript.light_shake(_cam)
	_play_sfx("cast")
	await get_tree().create_timer(7.8).timeout
	if _finished: return
	_fade_caption(0.0)
	# ② 压倒
	_say("·", "它们不发自任何国家，也不为任何理由。")
	_spawn_foe(FOE_SCOUT, Vector2(ENEMY_X, ROW_YS[2]), 4)
	VfxFactory.spawn_shockwave(_battlefield, Vector2(ENEMY_X, 420.0), 110.0, Color(1.0, 0.45, 0.2, 0.85), 2.0)
	ShakeScript.medium_shake(_cam)
	await get_tree().create_timer(6.5).timeout
	if _finished: return
	_fade_caption(0.0)
	# ③ 绝境（脚本化：无论战况如何，梦都走向这里）
	_phase = Phase.DOOM
	_say("（跑——快跑——）", "")
	_spawn_foe(FOE_HEAVY, Vector2(ENEMY_X, ROW_YS[1]), 3)
	_spawn_foe(FOE_NEXUS, Vector2(ENEMY_X + 60.0, ROW_YS[3]), 2)
	_spawn_foe(FOE_SCOUT, Vector2(ENEMY_X, ROW_YS[4]), 3)
	ShakeScript.heavy_shake(_cam)
	_play_sfx("boss_warn")
	VfxFactory.spawn_shockwave(_battlefield, Vector2(ENEMY_X + 40.0, 420.0), 150.0, Color(1.0, 0.3, 0.15, 0.9), 2.0)
	var dtint := create_tween()
	dtint.tween_property(_doom_tint, "color:a", 0.26, 2.2)
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(_vignette, "color:a", 0.22, 0.7)
	_pulse_tween.tween_property(_vignette, "color:a", 0.06, 0.7)
	# 等我方全灭（下限 4s 保演出量），或 8s 兜底；期间脚本化炮击砸我方阵地
	var t := 0.0
	var next_strike := 0.9
	while t < 8.0:
		await get_tree().create_timer(0.4).timeout
		t += 0.4
		if _finished: return
		if _alive(_player_units) == 0 and t >= 4.0:
			break
		if t >= next_strike:
			next_strike += 1.3
			_scripted_strike()
	# ④ 抹除
	_phase = Phase.ERASE
	_fade_caption(0.0)
	_play_sfx("error")
	_flash.color = Color(0.75, 0.1, 0.05, 0.5)
	var fw := create_tween()
	fw.tween_property(_flash, "color:a", 0.0, 0.7)
	ShakeScript.extreme_shake(_cam)
	var idx := 0
	for u in _player_units:
		if u != null and is_instance_valid(u):
			u.set_physics_process(false)
			var upos: Vector2 = u.global_position
			VfxFactory.spawn_shockwave(_battlefield, upos, 64.0, Color(1.0, 0.35, 0.15, 0.85), 2.0)
			VfxFactory.spawn_smoke_column(_battlefield, upos + Vector2(0, -12))
			var dt := create_tween()
			dt.tween_interval(idx * 0.12)
			dt.tween_property(u, "modulate:a", 0.0, 0.55)
			idx += 1
	if idx > 0:
		_play_sfx("base_destroy")
	_say("·", "世界在梦里烧成了灰。")
	await get_tree().create_timer(2.2).timeout
	if _finished: return
	# ⑤ 递卡（唯一交互）
	_phase = Phase.CARD_OFFER
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_vignette.color.a = 0.0
	var tint_out := create_tween()
	tint_out.tween_property(_doom_tint, "color:a", 0.0, 1.2)
	_fade_caption(0.0)
	_offer_box.visible = true
	_offer_box.modulate.a = 0.0
	var ot := create_tween()
	ot.tween_property(_offer_box, "modulate:a", 1.0, 0.5)
	_play_sfx("card_pickup")
	var blink := create_tween()
	blink.set_loops()
	blink.tween_property(_offer_hint, "modulate:a", 0.35, 0.55)
	blink.tween_property(_offer_hint, "modulate:a", 1.0, 0.55)
	await _card_caught
	if _finished: return
	blink.kill()
	# ⑥ 反转：接卡瞬间慢动作定帧，再恢复
	Engine.time_scale = 0.3
	await get_tree().create_timer(0.45, true, false, true).timeout   # 忽略 time_scale 的真实时钟
	Engine.time_scale = 1.0
	if _finished: return
	_phase = Phase.REVERSAL
	_play_sfx("enhance")
	_flash.color = Color(1.0, 0.95, 0.8, 0.85)
	var rw := create_tween()
	rw.tween_property(_flash, "color:a", 0.0, 0.8)
	_offer_box.visible = false
	# 巨神登场：金色召唤门 + 光柱 + 极震
	var birth := Vector2(500.0, GROUND_Y - 10.0)
	VfxFactory.spawn_summon_portal(_battlefield, birth + Vector2(0, -30), Color(1.0, 0.78, 0.32, 0.9), 0.9)
	VfxFactory.spawn_energy_pillar(_battlefield, birth + Vector2(0, -20), Color(1.0, 0.8, 0.35, 0.7), 460.0)
	ShakeScript.extreme_shake(_cam)
	_spawn_player_card(GOLDEN_CARD_ID, birth)
	_say("·", "这一夜之后，你不再只能看着。")
	# 巨神清场：真打 2.6s 后剩余敌人 scripted 抹除，保证节奏
	await get_tree().create_timer(2.6).timeout
	if _finished: return
	for i in _enemy_units.size():
		var e = _enemy_units[i]
		if e != null and is_instance_valid(e):
			e.set_physics_process(false)
			var epos: Vector2 = e.global_position
			VfxFactory.spawn_shockwave(_battlefield, epos, 40.0, Color(1.0, 0.8, 0.35, 0.85), 2.0)
			var et := create_tween()
			et.tween_interval(i * 0.1)
			et.tween_property(e, "modulate:a", 0.0, 0.4)
	_play_sfx("achievement")
	await get_tree().create_timer(2.4).timeout
	if _finished: return
	_hand_off(false)

# ───────────────────── 干跑时间线（冒烟） ─────────────────────

func _run_dry_timeline() -> void:
	_say("dry", "compressed timeline")
	await get_tree().create_timer(0.2).timeout
	if _finished: return
	_spawn_defenders()
	_spawn_foe(FOE_SCOUT, Vector2(ENEMY_X, ROW_YS[0]), 1)
	await get_tree().create_timer(0.4).timeout
	if _finished: return
	_spawn_player_card(GOLDEN_CARD_ID, Vector2(500.0, GROUND_Y - 10.0))
	await get_tree().create_timer(0.4).timeout
	if _finished: return
	_hand_off(true)

# ───────────────────── 交互 / 收尾 ─────────────────────

signal _card_caught

func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		_skip_all()
		return
	if _phase == Phase.CARD_OFFER and event is InputEventMouseButton 			and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		_caught = true
		_card_caught.emit()

## 战毕回 comic 续播 B3–B7（resume meta + pending 仍武装 → comic 收尾落 wakeup）
## 干跑：只落 meta + 发信号，不切场景。
func _hand_off(dry: bool) -> void:
	if _finished:
		return
	_finished = true
	_phase = Phase.DONE
	Engine.set_meta(META_BATTLE_RESUME, 2)
	if dry:
		battle_finished.emit()
		return
	var tw := create_tween()
	tw.tween_property(_curtain, "color:a", 1.0, 0.6)
	tw.tween_callback(func():
		battle_finished.emit()
		SceneTransition.change(get_tree(), COMIC_SCENE))

## 任意时刻跳过 = 跳过整段序章：直落基地（bunker 侧消费 wakeup + mark comic_seen）
func _skip_all() -> void:
	if _finished:
		return
	_finished = true
	_phase = Phase.DONE
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	Engine.remove_meta(META_BATTLE_RESUME)
	Engine.remove_meta(META_COMIC_PENDING)
	Engine.set_meta(META_WAKEUP, true)
	battle_finished.emit()
	SceneTransition.change(get_tree(), BUNKER_SCENE)
