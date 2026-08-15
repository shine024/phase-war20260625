extends Control
## 相位仪栏符文槽实拍工具：装备符文（含修复过的3张）+ 一张卡对比 → 拍底部栏。

var _timer: Timer
var _idx: int = -1
var _bar: Control = null
var _settle: int = 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://panel_tour")
	_timer = Timer.new()
	_timer.wait_time = 0.35
	_timer.autostart = true
	_timer.timeout.connect(_tick)
	add_child(_timer)
	print("[RUNEBAR] start")

func _seed() -> void:
	var pm: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pm == null:
		push_error("[RUNEBAR] PhaseInstrumentManager 不可用")
		return
	# 13 槽满载：green 0-8 装卡 + rune 0-3 装符文（复现动态收窄后的右裁问题）
	var card_ids: Array = [
		"ww1_arm_ft17", "ww1_inf_enfield", "ww1_arty_77mm",
		"ww2_arm_sherman", "ww2_arm_tiger", "ww2_arty_pak40",
		"cold_t72", "mod_arm_m1a2sep", "fut_arm_omega",
	]
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	var ci: int = 0
	for cid in card_ids:
		if ir == null or not ir.has_method("create_instance"):
			break
		ir.create_instance(String(cid))
		var ids: Array = ir.get_all_instance_ids()
		var card = ir.get_instance(ids[ids.size() - 1])
		if card and pm.has_method("equip_card"):
			var okc: bool = pm.equip_card(ci, card)
			print("[RUNEBAR] equip card %d=%s -> %s" % [ci, cid, okc])
		ci += 1
	var runes: Array = [
		"attack_03", "defense_01", "attack_07", "attack_01",
	]
	for rid in runes:
		if pm.has_method("add_owned_rune"):
			pm.add_owned_rune(String(rid))
	for i in range(runes.size()):
		if pm.has_method("equip_rune"):
			var ok: bool = pm.equip_rune(i, String(runes[i]))
			print("[RUNEBAR] equip rune %d=%s -> %s" % [i, runes[i], ok])

func _tick() -> void:
	if _bar == null:
		_idx += 1
		match _idx:
			0:
				_seed()
			1:
				var ps: PackedScene = load("res://scenes/ui/bottom_instrument_bar.tscn")
				_bar = ps.instantiate()
				_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
				add_child(_bar)
			_:
				print("[RUNEBAR] done")
				get_tree().quit()
	else:
		_settle += 1
		if _settle >= 10:
			_capture()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var tag: String = "rune_bar13_after"
	if String(get_meta("tag", "")) != "":
		tag = String(get_meta("tag"))
	img.save_png("user://panel_tour/%s.png" % tag)
	print("[RUNEBAR] shot saved: ", tag)
	_bar.queue_free()
	_bar = null
