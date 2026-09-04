extends Node

## 四系统面板视觉检查 harness（相位师技能树 / 玩家相位师 / 改造 / 势力）
## 仿 backpack_shot.gd：种子数据 → 逐面板打开 → 稳定后拍全视口 → user://panel_tour/
## 运行（需真实渲染）：godot --path . res://scenes/tools/system_check_shot.tscn

const OUT_DIR := "user://panel_tour/"

func _ready() -> void:
	var win := get_window()
	win.borderless = true
	win.size = Vector2i(1280, 720)
	win.position = Vector2i(0, 0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.09, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_run()

func _run() -> void:
	await _wait(0.5)
	_seed_all()
	# ① 相位师技能树（host 自带 CanvasLayer + backdrop）
	var host_script := load("res://scripts/ui/phase_master_skill_host.gd")
	var host: Node = host_script.open(get_tree(), false)
	await _wait(1.8)
	await _capture("skill_tree")
	if host != null and host.has_method("close"):
		host.call("close")
	await _wait(0.3)
	# ② 玩家相位师详细面板
	var pm: Control = _spawn("res://scenes/ui/player_master_panel.tscn", "open_panel")
	await _wait(1.4)
	await _capture("player_master")
	_free(pm)
	# ③ 改造面板（名册态）
	var mp: Control = _spawn("res://scenes/ui/modification_panel.tscn", "on_overlay_opened")
	await _wait(2.0)
	await _capture("modification")
	# ④ 改造面板（选中模块后的安装工作台态：直调 _on_mod_selected）
	if mp != null and is_instance_valid(mp) and mp.has_method("_on_mod_selected"):
		var reg: Node = get_node_or_null("/root/ModificationRegistry")
		if reg != null and reg.has_method("get_data"):
			mp.call("_on_mod_selected", "arm_01_sloped_armor", reg.get_data("arm_01_sloped_armor"))
	await _wait(1.2)
	await _capture("modification_detail")
	_free(mp)
	# ⑤ 势力面板（7 势力 + 技能区）
	var fp: Control = _spawn("res://scenes/ui/faction_panel.tscn", "")
	await _wait(1.6)
	await _capture("faction")
	_free(fp)
	print("[SYSCHECK] done")
	get_tree().quit()

func _seed_all() -> void:
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir != null and ir.has_method("create_instance"):
		if not (ir.has_method("get_all_instance_ids") and ir.get_all_instance_ids().size() > 0):
			for cid in ["ww1_inf_enfield", "ww1_arm_ft17", "cold_t72", "cold_inf_ak", "mod_arm_himars", "fut_arm_omega"]:
				ir.create_instance(cid)
		var bag: Node = get_node_or_null("/root/IntelItemBag")
		if bag != null and bag.has_method("add_item"):
			for mid in ["inf_01_submachine_gun", "inf_02_assault_rifle", "arm_01_sloped_armor", "arm_08_autoloader", "art_01_he_rounds", "aa_01_radar", "air_01_afterburner", "gen_09_ecm"]:
				bag.add_item("blueprint_" + String(mid), 2)
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm != null and fsm.has_method("add_faction_reputation"):
		for fid in ["aegis", "helix", "nova", "iron", "umbra", "eon"]:
			fsm.add_faction_reputation(fid, 600)
	# 技能树点亮几个芯片（看通电态视觉；先给技能点，unlock_node 会校验点数）
	var pm: Node = get_node_or_null("/root/PhaseMasterSkillManager")
	if pm != null:
		if pm.has_method("add_bonus_points"):
			pm.add_bonus_points(20)
		if pm.has_method("unlock_node"):
			for nid in ["pms_cmd_0", "pms_cmd_1a", "pms_int_0", "pms_fire_0"]:
				var ok: bool = pm.unlock_node(String(nid))
				print("[SYSCHECK] unlock %s -> %s" % [nid, ok])
	print("[SYSCHECK] seeded")

func _spawn(path: String, open_method: String) -> Control:
	var ps: PackedScene = load(path)
	var c: Control = ps.instantiate()
	add_child(c)
	c.visible = true
	if open_method != "" and c.has_method(open_method):
		c.call_deferred(open_method)
	return c

func _free(c: Control) -> void:
	if c != null and is_instance_valid(c):
		c.queue_free()

func _find_first_button(root: Node) -> Control:
	if root is BaseButton and (root as Control).visible:
		return root
	for ch in root.get_children():
		var r := _find_first_button(ch)
		if r != null:
			return r
	return null

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _capture(tag: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR + "syscheck_%s.png" % tag)
	print("[SYSCHECK] shot: ", tag)
