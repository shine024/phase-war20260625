extends Node
## v6.57 记录3#4：第2关卡死复现探针（临时工具，跑完可删）。
## 槽1 复制到槽3（槽1 只读）→ 标题屏「继续」→ 真实路径 → 到基地后强制 current_level=2
## → go_to_battle 正规进战 → 监视波次/敌我单位数/胜负；战斗中 45s 状态零变化=疑似卡死
## → 全量转储+截图+trace 尾巴后 quit(2)。窗口化运行：
##   $GODOT --path . res://tests/_tmp_v657_l2_probe.tscn

const BACKUP_DIR := "res://.godot/save_backup_v657_l2/"
const SHOT_DIR := "res://.godot/v657_l2/"

var _t0 := 0
var _battle_seen := false
var _battle_ended := false
var _won := false
var _sig := ""
var _last_change_msec := 0
var _go_done := false
var _last_action_msec := 0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	if not SignalBus.battle_ended.is_connected(_on_battle_ended):
		SignalBus.battle_ended.connect(_on_battle_ended)
	await _wait_frames(20)
	_backup_save()
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null:
		push_error("[l2] SaveManager missing")
		get_tree().quit(1)
		return
	sm.call("set_slot", 3)
	var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	_t0 = Time.get_ticks_msec()
	_last_change_msec = _t0
	_last_action_msec = _t0
	print("[l2] title mounted, polling...")
	_poll_loop()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _backup_save() -> void:
	DirAccess.make_dir_recursive_absolute(BACKUP_DIR)
	for f in ["save_slot_1.json", "save_slot_2.json", "save_slot_3.json", "settings.cfg", "battle_speed.cfg"]:
		if FileAccess.file_exists("user://" + f):
			var dst: String = BACKUP_DIR + f
			if FileAccess.file_exists(dst):
				DirAccess.remove_absolute(dst)
			DirAccess.copy_absolute("user://" + f, dst)
	print("[l2] save backed up → ", BACKUP_DIR)


func _on_node_added(n: Node) -> void:
	var sc := n.get_script() as Script
	if sc != null and sc.resource_path.ends_with("main.gd"):
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and gm.has_method("set_current_level"):
			gm.call("set_current_level", 2)
			print("[l2] main entering tree -> current_level forced 2")


func _on_battle_ended(player_won: bool) -> void:
	_battle_ended = true
	_won = player_won
	print("[l2] BATTLE ENDED won=%s t=%.1fs" % [str(player_won), (Time.get_ticks_msec() - _t0) / 1000.0])


func _poll_loop() -> void:
	var last_status := 0
	while Time.get_ticks_msec() - _t0 < 420000:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		if now - _last_action_msec > 5000:
			_last_action_msec = now
			_press_continue_or_skip()
		# 到基地（truck_base）后强制进第 2 关
		if not _go_done:
			var cs := get_tree().current_scene
			var s: Script = cs.get_script() as Script if cs != null else null
			if s != null and s.resource_path.ends_with("truck_base.gd") and now - _t0 > 8000:
				var gm: Node = get_node_or_null("/root/GameManager")
				if gm != null:
					gm.call("set_current_level", 2)
					print("[l2] truck_base reached (t=%ds) -> set level 2, go_to_battle" % [(now - _t0) / 1000])
					gm.call("go_to_battle")
					_go_done = true
					continue
		var bm: Node = get_node_or_null("/root/BattleManager")
		var in_battle: bool = bool(bm.get("battle_active")) if bm != null and "battle_active" in bm else false
		if in_battle:
			if not _battle_seen:
				_battle_seen = true
				print("[l2] BATTLE STARTED t=%.1fs" % [(now - _t0) / 1000.0])
			if now - last_status > 5000:
				last_status = now
				var st := _battle_state_sig(bm)
				if st != _sig:
					_sig = st
					_last_change_msec = now
					print("[l2][t=%ds] %s" % [(now - _t0) / 1000, st])
				var stall_ms := now - _last_change_msec
				if stall_ms > 45000:
					print("[l2] ⚠ STALL DETECTED: battle state frozen %.0fs: %s" % [stall_ms / 1000.0, _sig])
					_dump_field(bm)
					_dump_trace_tail()
					_shot("stall")
					get_tree().quit(2)
					return
		elif _battle_seen and _battle_ended:
			print("[l2] verdict: battle completed normally won=%s" % str(_won))
			_shot("ended")
			await _wait_frames(30)
			get_tree().quit(0)
			return
	print("[l2] window timeout (battle_seen=%s ended=%s last=%s)" % [str(_battle_seen), str(_battle_ended), _sig])
	_dump_trace_tail()
	_shot("timeout")
	get_tree().quit(3)


func _battle_state_sig(bm: Node) -> String:
	var wave := int(bm.get("enemy_wave_index")) if "enemy_wave_index" in bm else -1
	var ec := 0
	var pc := 0
	for g in ["enemy_units", "player_units"]:
		var n := 0
		for u in get_tree().get_nodes_in_group(g):
			if is_instance_valid(u):
				n += 1
		if g == "enemy_units":
			ec = n
		else:
			pc = n
	return "wave=%d enemy=%d player=%d" % [wave, ec, pc]


func _dump_field(bm: Node) -> void:
	for g in ["enemy_units", "player_units"]:
		var us := get_tree().get_nodes_in_group(g)
		print("[l2][dump] %s count=%d" % [g, us.size()])
		for u in us.slice(0, 8):
			if is_instance_valid(u):
				print("    %s pos=%s hp=%s" % [u.name, str((u as Node2D).global_position) if u is Node2D else "?", str(u.get("hp")) if "hp" in u else "?"])
	var cs := get_tree().current_scene
	print("[l2][dump] scene=%s battle_active=%s" % [cs.name if cs != null else "?", str(bool(bm.get("battle_active"))) if bm != null else "?"])


func _dump_trace_tail() -> void:
	var f := FileAccess.open("user://trace.log", FileAccess.READ)
	if f == null:
		print("[l2][trace] no trace.log")
		return
	var lines := f.get_as_text().split("\n")
	print("[l2][trace] tail:")
	for ln in lines.slice(maxi(0, lines.size() - 25)):
		print("    ", ln)


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
			print("[l2] continue pressed")
		return
	for needle in ["启程", "跳过", "进入该关", "开始战斗", "出击"]:
		var b := _find_button_by_text(cs, needle)
		if b != null and b.is_visible_in_tree() and not b.disabled:
			b.pressed.emit()
			print("[l2] pressed: ", needle)
			return


func _find_button_by_text(root: Node, needle: String) -> Button:
	if root is Button:
		var b := root as Button
		if b.text.contains(needle):
			return b
	for c in root.get_children():
		var r := _find_button_by_text(c, needle)
		if r != null:
			return r
	return null


func _shot(tag: String) -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var p := "%s%s_%d.png" % [SHOT_DIR, tag, Time.get_ticks_msec()]
		img.save_png(p)
		print("[l2] shot → ", p)
