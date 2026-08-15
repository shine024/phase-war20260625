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
	# 对比样本：归一修复过的5张小圆盘 + 原正常图对照；rune 槽共 4 个
	var runes: Array = [
		"attack_03",      # 归一修复（原 0.82 小盘）
		"defense_01",     # 归一修复（原 0.83 小盘）
		"attack_07",      # 归一修复（原 0.84 小盘）
		"attack_01",      # 正常对照
	]
	for rid in runes:
		if pm.has_method("add_owned_rune"):
			pm.add_owned_rune(String(rid))
	for i in range(runes.size()):
		if pm.has_method("equip_rune"):
			var ok: bool = pm.equip_rune(i, String(runes[i]))
			print("[RUNEBAR] equip %d=%s -> %s" % [i, runes[i], ok])
	# 绿槽装一张卡做尺寸对比
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir and pm.has_method("equip_card"):
		if ir.has_method("get_all_instance_ids") and ir.get_all_instance_ids().size() == 0:
			ir.create_instance("ww1_arm_ft17")
		var ids: Array = ir.get_all_instance_ids()
		if ids.size() > 0:
			var card = ir.get_instance(ids[0])
			if card:
				var okc: bool = pm.equip_card("green_1", card)
				print("[RUNEBAR] equip card -> ", okc)

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
	img.save_png("user://panel_tour/rune_bar.png")
	print("[RUNEBAR] shot saved")
	_bar.queue_free()
	_bar = null
