extends Control
## 改造图标复验专用：造实例卡 + 改造图纸 → 拍背包改造 Tab + 改造面板。

var _bg: ColorRect
var _center: CenterContainer
var _timer: Timer
var _idx: int = -1
var _settle: int = 0
var _current: Control = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://panel_tour")
	_bg = ColorRect.new()
	_bg.color = Color(0.03, 0.05, 0.09, 1)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_timer = Timer.new()
	_timer.wait_time = 0.35
	_timer.autostart = true
	_timer.timeout.connect(_tick)
	add_child(_timer)
	print("[TOUR] start")

func _seed_cards() -> void:
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null or not ir.has_method("create_instance"):
		return
	if ir.has_method("get_all_instance_ids") and ir.get_all_instance_ids().size() > 0:
		print("[TOUR] 已有实例，跳过造卡")
		return
	var want: Array = [
		"ww1_inf_enfield", "ww1_arm_ft17", "ww1_arty_77mm",
		"ww2_arm_sherman", "ww2_arm_tiger", "ww2_arty_pak40",
		"cold_t72", "cold_inf_ak", "cold_chieftain",
		"mod_arm_m1a2sep", "mod_ah64", "mod_arm_himars",
		"fut_arm_omega", "fut_air_drone", "fut_arm_heavy_mech",
		"fut_colossus",
	]
	var dc = load("res://data/default_cards.gd")
	var all_ids: Array = dc.get_all_blueprint_ids() if dc else []
	var n: int = 0
	for cid in want:
		if all_ids.has(cid):
			ir.create_instance(cid)
			n += 1
	print("[TOUR] seeded ", n, " cards")

func _seed_mods() -> void:
	var bag: Node = get_node_or_null("/root/IntelItemBag")
	if bag == null or not bag.has_method("add_item"):
		push_error("[TOUR] IntelItemBag 不可用")
		return
	# 跨兵种/稀有度取样
	var mods: Array = [
		"gen_14_phase_shield_gen", "arm_09_turbine",
		"inf_01_submachine_gun", "inf_02_assault_rifle", "eng_05_shovel",
		"arm_01_sloped_armor", "arm_03_reactive_armor", "arm_06_apfsds", "arm_08_autoloader",
		"art_01_he_rounds", "art_04_cluster", "art_06_fire_computer",
		"aa_01_radar", "aa_05_proximity_fuze",
		"air_01_afterburner", "air_05_helmet_sight",
		"gen_01_light_engine", "gen_09_ecm",
	]
	var n: int = 0
	for mid in mods:
		bag.add_item("blueprint_" + String(mid), 1)
		n += 1
	print("[TOUR] seeded ", n, " mod blueprints")

func _tick() -> void:
	if _current == null:
		_idx += 1
		match _idx:
			0:
				_seed_cards()
				_seed_mods()
			1:
				_spawn("res://scenes/ui/backpack_panel.tscn", "on_overlay_opened")
			2:
				_spawn("res://scenes/ui/modification_panel.tscn", "on_overlay_opened")
			_:
				print("[TOUR] done")
				get_tree().quit()
	else:
		_settle += 1
		if _settle >= 8:
			_capture_stage()

func _spawn(path: String, open: String) -> void:
	_settle = 0
	var ps: PackedScene = load(path)
	_current = ps.instantiate()
	_center.add_child(_current)
	_current.visible = true
	if _current.has_method(open):
		_current.call_deferred(open)

func _capture_stage() -> void:
	var panel := _current
	var tag: String = "stage_%d" % _idx
	_current = null
	if _idx == 1:
		# 背包阶段：切到改造 Tab（TabIndex.INTEL = 1），多等一拍再拍
		var tc: TabContainer = panel.find_child("TabContainer", true, false) as TabContainer
		if tc and tc.get_tab_count() > 1:
			tc.current_tab = 1
		_delayed_capture(panel, "bp_mod_tab")
		return
	_do_capture(panel, tag)

func _delayed_capture(panel: Control, tag: String) -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(panel):
		return
	_do_capture(panel, tag)

func _do_capture(panel: Control, tag: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://panel_tour/%s.png" % tag)
	print("[TOUR] shot: ", tag)
	if is_instance_valid(panel):
		panel.queue_free()
