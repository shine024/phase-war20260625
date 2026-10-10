extends Node
## v6.55 尺寸链真机验证探针（临时工具，可删）：
## 真实路径：槽1 存档复制到槽3 → 标题屏「继续」→ 正规转场进 main → 强制第 35 关
## （常规混编关：步兵/装甲/支援齐出）→ 自动开战 → 单位入屏后连拍 3 张
## （.godot/subject_audit/battle_live_*.png）+ 逐单位实测屏上主体高转储。
## 运行（窗口化）：$GODOT --path . res://tests/_tmp_v655_battle_live_probe.tscn

const SAVE_DIR := "user://"
const BACKUP_DIR := "res://.godot/save_backup_v655_live/"
const SHOT_DIR := "res://.godot/subject_audit"
const TARGET_LEVEL := 35

var _start_msec := 0
var _battle_seen := false
var _shots := 0
var _last_shot_msec := 0
var _dumped := false


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	await _wait_frames(20)
	_backup_and_copy_save()
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null:
		push_error("[v655] SaveManager missing")
		get_tree().quit(1)
		return
	sm.call("set_slot", 3)
	var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	print("[v655] title mounted, pressing continue...")
	_start_msec = Time.get_ticks_msec()
	_poll_loop()


func _on_node_added(n: Node) -> void:
	if _battle_seen:
		return
	var sc := n.get_script() as Script
	if sc != null and sc.resource_path.ends_with("main.gd"):
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("set_current_level"):
			gm.call("set_current_level", TARGET_LEVEL)
			print("[v655] main entering tree -> current_level=%d" % TARGET_LEVEL)


func _poll_loop() -> void:
	var last_action := 0
	while Time.get_ticks_msec() - _start_msec < 180000:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		if now - last_action > 6000:
			last_action = now
			_press_continue_or_skip()
		var bm: Node = get_node_or_null("/root/BattleManager")
		var in_battle: bool = bool(bm.get("battle_active")) if bm != null and "battle_active" in bm else false
		if in_battle:
			if not _battle_seen:
				_battle_seen = true
				print("[v655] BATTLE STARTED t=%.1fs" % ((now - _start_msec) / 1000.0))
			if _shots >= 3:
				continue
			if now - _last_shot_msec < 3500:
				continue
			var pu := get_tree().get_nodes_in_group("player_units")
			var eu := get_tree().get_nodes_in_group("enemy_units")
			if pu.size() + eu.size() < 4:
				continue
			_last_shot_msec = now
			_shots += 1
			if not _dumped:
				_dumped = true
				_dump_subject_heights(pu, eu)
			_shot("battle_live_%d" % _shots)
			print("[v655] shot %d/3 t=%.1fs (我%d 敌%d)" % [_shots, (now - _start_msec) / 1000.0, pu.size(), eu.size()])
	print("[v655] done (battle_seen=%s shots=%d)" % [str(_battle_seen), str(_shots)])
	get_tree().quit(0)


## 逐单位实测屏上主体高（当前纹理内容 bbox × scale），验证呈现链产物
func _dump_subject_heights(pu: Array, eu: Array) -> void:
	for u in pu + eu:
		if not is_instance_valid(u):
			continue
		var spr := u.get_node_or_null("Sprite") as Sprite2D
		if spr == null:
			spr = u.get_node_or_null("Sprite2D") as Sprite2D
		if spr == null or spr.texture == null:
			continue
		var img: Image = spr.texture.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		var maxy := -1
		var miny := img.get_height()
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				if img.get_pixel(x, y).a > 0.05:
					if y < miny:
						miny = y
					maxy = y
					break
		if maxy < 0:
			continue
		var h_px: float = float(maxy - miny + 1) * absf(spr.scale.y)
		var label: String = str(u.get_meta("archetype_id", u.get("_visual_archetype_id") if "_visual_archetype_id" in u else "?"))
		print("[v655][%s] %s 屏高=%.1fpx scale=%.3f" % [
			"敌" if u.is_in_group("enemy_units") else "我", label, h_px, spr.scale.y])


func _shot(tag: String) -> void:
	await _wait_frames(2)
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	var path := "%s/%s.png" % [SHOT_DIR, tag]
	img.save_png(ProjectSettings.globalize_path(path))
	print("[v655] saved ", path)


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
			print("[v655] continue pressed")
		return
	for needle in ["启程", "跳过", "进入该关", "开始战斗"]:
		var b := _find_button_by_text(cs, needle)
		if b != null and b.is_visible_in_tree() and not b.disabled:
			b.pressed.emit()
			print("[v655] pressed: ", needle)
			return


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
	var src := ProjectSettings.globalize_path(SAVE_DIR)
	var dst := ProjectSettings.globalize_path(BACKUP_DIR)
	_copy_dir(src, dst)
	# 槽1 → 槽3（槽1 只读）
	for f in ["save_slot_1.json"]:
		var p := src + f
		if FileAccess.file_exists(p):
			var txt := FileAccess.get_file_as_string(p)
			var out := FileAccess.open(src + "save_slot_3.json", FileAccess.WRITE)
			out.store_string(txt)
			out.close()
	print("[v655] save backed up to ", BACKUP_DIR)


func _copy_dir(from: String, to: String) -> void:
	var d := DirAccess.open(from)
	if d == null:
		return
	for f in d.get_files():
		if f.begins_with("save_slot") or f.begins_with("settings") or f.begins_with("save.json"):
			d.copy(from + f, to + f)


func _wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
