extends Node
## 实机护盾罩验证探针 v2（临时工具，可删）：
## 完整模拟玩家真实路径：槽1 存档复制到槽3（槽1 只读）→ 标题屏「继续」→ 正规转场进 main
## → 等自动开战（level_auto_start_pending 同款 meta 由 _on_continue 置）→ 等护盾
## → 对场上带盾单位（敌我）全量转储 + 截屏 + 像素扫真实脚线。
## 运行（窗口化）：$GODOT --path . res://tests/_tmp_shield_live_probe.tscn

const SAVE_DIR := "user://"
const BACKUP_DIR := "res://.godot/save_backup_shield_live/"
const SHOT_PREFIX := "res://.godot/agent_tools/shield_live_"

var _start_msec := 0
var _battle_seen := false
var _shield_seen := false
var _last_scan_msec := 0
var _last_action_msec := 0
var _scanned_feet_for: Dictionary = {}
var _shield_seen_msec := 0


func _ready() -> void:
	# main 入树瞬间把关卡改到 90（驻守相位师战，敌方 mega_shield 必现）——
	# node_added 在 _ready 前触发，赶在 meta 消费（go_to_battle 读 current_level）之前
	get_tree().node_added.connect(_on_node_added)
	await _wait_frames(20)
	_backup_and_copy_save()
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null:
		push_error("[live] SaveManager missing")
		get_tree().quit(1)
		return
	sm.call("set_slot", 3)
	# 挂标题屏，走玩家真实路径
	var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	print("[live] title mounted, pressing continue...")
	_start_msec = Time.get_ticks_msec()
	_poll_loop()


func _on_node_added(n: Node) -> void:
	if _battle_seen:
		return
	var sc := n.get_script() as Script
	if sc != null and sc.resource_path.ends_with("main.gd"):
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("set_current_level"):
			gm.call("set_current_level", 90)
			print("[live] main entering tree -> current_level forced 90 (garrison)")


func _poll_loop() -> void:
	var last_status := 0
	while Time.get_ticks_msec() - _start_msec < 420000:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		# 每 6s 做一次流程推进（跳弹窗/点继续）
		if now - _last_action_msec > 6000:
			_last_action_msec = now
			_press_continue_or_skip()
		# 每 15s 状态 + 截屏
		if now - last_status > 15000:
			last_status = now
			var bm0: Node = get_node_or_null("/root/BattleManager")
			var ba: bool = bool(bm0.get("battle_active")) if bm0 != null and "battle_active" in bm0 else false
			var cs := get_tree().current_scene
			print("[live][t=%ds] battle_active=%s scene=%s" % [
				(now - _start_msec) / 1000, str(ba), cs.name if cs != null else "?"])
			_shot("s%d" % ((now - _start_msec) / 1000))
		var bm: Node = get_node_or_null("/root/BattleManager")
		var in_battle: bool = bool(bm.get("battle_active")) if bm != null and "battle_active" in bm else false
		if in_battle:
			if not _battle_seen:
				_battle_seen = true
				print("[live] BATTLE STARTED t=%.1fs" % ((now - _start_msec) / 1000.0))
			if now - _last_scan_msec < 2000:
				continue
			_last_scan_msec = now
			var shielded := _find_shielded_units()
			if not shielded.is_empty():
				if not _shield_seen:
					_shield_seen = true
					_shield_seen_msec = now
					print("[live] SHIELD SPOTTED t=%.1fs" % ((now - _start_msec) / 1000.0))
				_dump_units(shielded)
				_shot("t%d" % ((now - _start_msec) / 1000))
				# 拍够 40s 即退（截图已到手，不空耗窗口）
				if now - _shield_seen_msec > 40000:
					print("[live] captured enough, exit")
					get_tree().quit(0)
					return
	print("[live] window done (battle_seen=%s shield_seen=%s)" % [str(_battle_seen), str(_shield_seen)])
	get_tree().quit(0)


func _press_continue_or_skip() -> void:
	var cs := get_tree().current_scene
	if cs == null:
		return
	var s := cs.get_script() as Script
	var is_title: bool = s != null and s.resource_path.ends_with("title_screen.gd")
	if is_title:
		var btn: Button = cs.get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/ContinueButton") as Button
		if btn != null and not btn.disabled:
			btn.pressed.emit()
			print("[live] continue pressed")
		return
	# 战斗/基地场景里的弹窗（欢迎登车/战报）点「启程」或「跳过」
	for needle in ["启程", "跳过", "进入该关", "开始战斗"]:
		var b := _find_button_by_text(cs, needle)
		if b != null and b.is_visible_in_tree() and not b.disabled:
			b.pressed.emit()
			print("[live] pressed: ", needle)
			return


func _find_shielded_units() -> Array:
	var out: Array = []
	for g in ["enemy_units", "player_units"]:
		for u in get_tree().get_nodes_in_group(g):
			if is_instance_valid(u) and "shield" in u and float(u.get("shield")) > 0.0:
				out.append(u)
	return out


func _dump_units(units: Array) -> void:
	for u in units:
		if not is_instance_valid(u):
			continue
		var spr := u.get_node_or_null("Sprite") as Sprite2D
		if spr == null or spr.texture == null:
			continue
		var tex := spr.texture
		var aura = u.get("_shield_aura")
		var aura_node := aura as Node2D
		var aura_pos: Vector2 = aura_node.position if aura_node != null and is_instance_valid(aura_node) else Vector2.INF
		var aura_g: Vector2 = aura_node.global_position if aura_node != null and is_instance_valid(aura_node) else Vector2.INF
		var dome := aura_node.get_node_or_null("ShieldTexDome") as Sprite2D if aura_node != null else null
		var chain := ""
		var n: Node = aura_node if aura_node != null else u
		while n != null:
			if n is Node2D and not ((n as Node2D).scale as Vector2).is_equal_approx(Vector2.ONE):
				chain += "%s×%s " % [n.name, str((n as Node2D).scale)]
			n = n.get_parent()
		var cam := get_viewport().get_camera_2d()
		var zoom: Vector2 = cam.zoom if cam != null else Vector2.INF
		var label: String = str(u.get_meta("archetype_id", u.get("_visual_archetype_id") if "_visual_archetype_id" in u else "?"))
		print("[live][%s][%s] shield=%.0f tex=%s/%s off=%s scale=%.3f spr.y=%.1f unit.scale=%s" % [
			"敌" if u.is_in_group("enemy_units") else "我", label, float(u.get("shield")),
			tex.get_class(), String(tex.resource_path).get_file().get_basename() if not String(tex.resource_path).is_empty() else "<atlas>",
			str(spr.offset), spr.scale.y, spr.position.y, str(u.scale)])
		print("    aura_pos=%s aura_global=%s unit_global=%s dome=%s zoom=%s scaled_chain=[%s]" % [
			str(aura_pos), str(aura_g), str((u as Node2D).global_position),
			str(dome.position) + "/" + str(dome.scale) if dome != null else "null",
			str(zoom), chain.strip_edges()])
		var feet := _feet_world_y(spr)
		if is_finite(feet):
			var dev: float = aura_g.y - feet
			print("    真实脚线global=%.1f vs aura_global=%.1f 偏差=%.1f px" % [feet, aura_g, dev])
		else:
			print("    脚线扫描失败(tex=%s)" % [tex.get_class()])


func _feet_world_y(spr: Sprite2D) -> float:
	var tex := spr.texture
	var img: Image = null
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var src_img: Image = (at.atlas as Texture2D).get_image()
		if src_img != null:
			if src_img.is_compressed():
				src_img.decompress()
			img = src_img.get_region(at.region)
	else:
		img = tex.get_image()
	if img == null:
		return NAN
	if img.is_compressed():
		img.decompress()
	var bottom := -1
	for y in range(img.get_height() - 1, -1, -1):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.05:
				bottom = y
				break
		if bottom >= 0:
			break
	if bottom < 0:
		return NAN
	var centered_frac: float = (float(bottom) + 0.5) / float(img.get_height()) - 0.5
	var s: float = absf(spr.scale.y)
	return spr.global_position.y + (spr.offset.y + centered_frac * float(img.get_height())) * s


func _find_button_by_text(node: Node, needle: String) -> Button:
	if node is Button and String((node as Button).text).contains(needle):
		return node as Button
	for ch in node.get_children():
		var r := _find_button_by_text(ch, needle)
		if r != null:
			return r
	return null


func _backup_and_copy_save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/agent_tools"))
	for f: String in ["save_slot_1.json", "save_slot_1.json.prior", "save_slot_1_backup.json"]:
		var src: String = SAVE_DIR + f
		if FileAccess.file_exists(src):
			var bak: String = BACKUP_DIR + f
			var dst: String = SAVE_DIR + "save_slot_3.json" if f == "save_slot_1.json" else ""
			DirAccess.copy_absolute(src, bak)
			if dst != "":
				if FileAccess.file_exists(dst):
					DirAccess.remove_absolute(dst)
				DirAccess.copy_absolute(src, dst)
				print("[live] copied slot1 -> slot3 (backup at .godot/save_backup_shield_live/)")


func _shot(tag: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(SHOT_PREFIX + tag + ".png")


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
