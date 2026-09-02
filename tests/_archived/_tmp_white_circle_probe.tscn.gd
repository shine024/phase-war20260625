extends Node
## 临时探针：复现"纳米虫群相位仪 → 战场中心白色大圆不消散"
## 装虚空女神(pi_void_05, nano_swarm) → 4 关 AFK 开打 → 周期 dump Battlefield
## 子树（类/名/位置/缩放/颜色/z序/贴图）+ 截图，定位白圆真身。

const GC := preload("res://resources/game_constants.gd")
const DefaultCards := preload("res://data/default_cards.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUT_DIR := "user://white_circle_probe/"

var _main: Node = null
var _shot_idx := 0

func _ready() -> void:
	var d := DirAccess.open("user://")
	if d != null:
		d.make_dir_recursive("white_circle_probe")
	var main_node: Node = MAIN_SCENE.instantiate()
	_main = main_node
	get_tree().root.add_child.call_deferred(main_node)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) 装纳米虫群相位仪（虚空女神）
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pim == null:
		print("[PROBE] FAIL: no PIM")
		get_tree().quit(1)
		return
	if pim.has_method("unlock_instrument"):
		pim.unlock_instrument("pi_void_05")
	var eq_ok: bool = pim.equip_instrument("pi_void_05")
	print("[PROBE] equip pi_void_05 = %s" % eq_ok)

	# 2) 绿槽装一战时代战斗卡
	var counts: Dictionary = pim.get_current_instrument().get("slot_counts", {})
	var green_off: int = int(counts.get("red", 0)) + int(counts.get("blue", 0))
	var green_cnt: int = int(counts.get("green", 0))
	var pool: Array = []
	for id in DefaultCards.get_all_blueprint_ids():
		var c: CardResource = DefaultCards.get_card_by_id(String(id))
		if c != null and c.card_type == GC.CardType.COMBAT_UNIT and c.era == 0:
			pool.append(c)
	pool.sort_custom(func(a, b): return a.power > b.power)
	var equipped := 0
	for i in range(mini(green_cnt, pool.size())):
		if pim.call("equip_card", green_off + i, pool[i]):
			equipped += 1
	print("[PROBE] equipped %d cards (green=%d)" % [equipped, green_cnt])

	# 3) 4 关开打
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("set_current_level"):
		gm.call("set_current_level", 4)
	var afk: RefCounted = _main.get("_afk_manager")
	if afk == null:
		print("[PROBE] FAIL: no afk manager")
		get_tree().quit(1)
		return
	afk.set_mode(1)
	afk.set("push_level", 4)
	afk.call("start_afk")
	afk.set("_pending_level", 4)
	afk.call("enter_next_battle")
	print("[PROBE] battle started")

	# 4) 周期观察（相对间隔 3/5/6/6/8/8s）
	var plan := [3.0, 5.0, 6.0, 6.0, 8.0, 8.0]
	var elapsed := 0.0
	for dt in plan:
		await get_tree().create_timer(dt).timeout
		elapsed += dt
		await get_tree().process_frame
		_dump_battlefield(elapsed)
		await _shot(elapsed)
	print("[PROBE] done")
	get_tree().quit(0)

func _shot(t: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		var fname := "probe_%02ds.png" % int(t)
		img.save_png(OUT_DIR + fname)
		print("[PROBE] shot %s" % fname)

func _dump_battlefield(t: float) -> void:
	var bf: Node = _main.get_node_or_null("BattleContainer/SubViewportContainer/SubViewport/Battlefield")
	if bf == null:
		print("[PROBE] t=%.0f Battlefield 不存在" % t)
		return
	# 浓度场状态
	var cfs: Variant = bf.get("_combo_field_state")
	var nano_amt: float = -1.0
	if cfs != null and cfs.has_method("get_field"):
		nano_amt = cfs.call("get_field", "nano_concentration")
	print("[PROBE] === t=%.0f nano浓度=%.1f ===" % [t, nano_amt])
	_dump_children(bf, 0)

func _dump_children(node: Node, depth: int) -> void:
	for ch in node.get_children():
		if ch is CanvasItem:
			var line := "%s%s(%s)" % ["  ".repeat(depth + 1), ch.name, ch.get_class()]
			if ch is Node2D:
				line += " pos=%s scale=%s z=%d vis=%s modulate=%s" % [
					(ch as Node2D).position, (ch as Node2D).scale,
					(ch as Node2D).z_index, str((ch as Node2D).visible), str((ch as CanvasItem).modulate)]
			if ch is Polygon2D:
				var pg := ch as Polygon2D
				var maxr := 0.0
				for p in pg.polygon:
					maxr = maxf(maxr, p.length())
				line += " color=%s poly_max_r=%.0f" % [str(pg.color), maxr]
			if ch is Sprite2D:
				var sp := ch as Sprite2D
				var tex_path := ""
				if sp.texture != null:
					tex_path = str(sp.texture.resource_path.get_file())
				line += " tex=%s" % tex_path
			if ch is CPUParticles2D:
				var cp := ch as CPUParticles2D
				line += " emitting=%s amount=%d tex=%s" % [
					str(cp.emitting), cp.amount,
					str(cp.texture.resource_path.get_file()) if cp.texture != null else "-"]
			print("[PROBE]", line)
			if depth < 3:
				_dump_children(ch, depth + 1)
		elif ch is Node:
			print("[PROBE]%s%s(%s) [非视觉]" % ["  ".repeat(depth + 1), ch.name, ch.get_class()])
			if depth < 2:
				_dump_children(ch, depth + 1)
