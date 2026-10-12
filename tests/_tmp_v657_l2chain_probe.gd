extends Node
## v6.57 记录3#4 补充探针：玩家自然路径「基地出击 L1 → 胜利结算『出击下一关』→ L2」
## 全链复现（v1 探针只覆盖基地直进 L2）。监视两场战斗各自的波次/敌我数变化，
## 任一场 45s 状态零变化=疑似卡死 → 转储+截图+trace 尾巴后 quit(2)；两场都正常结束 quit(0)。
## 窗口化运行：
##   $GODOT --path . res://tests/_tmp_v657_l2chain_probe.tscn

const SHOT_DIR := "res://.godot/v657_l2chain/"

var _t0 := 0
var _battle_ended_count := 0
var _in_battle := false
var _won := false
var _sig := ""
var _last_change_msec := 0
var _go_done := false
var _last_action_msec := 0
var _battle_no := 0


func _ready() -> void:
	if not SignalBus.battle_ended.is_connected(_on_battle_ended):
		SignalBus.battle_ended.connect(_on_battle_ended)
	await _wait_frames(20)
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null:
		push_error("[l2c] SaveManager missing")
		get_tree().quit(1)
		return
	sm.call("set_slot", 3)
	var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	_t0 = Time.get_ticks_msec()
	_last_change_msec = _t0
	_last_action_msec = _t0
	print("[l2c] title mounted, polling...")
	_poll_loop()


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _on_battle_ended(player_won: bool) -> void:
	_battle_ended_count += 1
	_won = player_won
	print("[l2c] BATTLE #%d ENDED won=%s t=%.1fs" % [_battle_ended_count, str(player_won), (Time.get_ticks_msec() - _t0) / 1000.0])


func _poll_loop() -> void:
	var last_status := 0
	while Time.get_ticks_msec() - _t0 < 420000:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		if now - _last_action_msec > 5000:
			_last_action_msec = now
			_press_buttons()
		# 到基地（truck_base）后强制从第 1 关开始（复刻玩家顺序推图）
		if not _go_done:
			var cs := get_tree().current_scene
			var s: Script = cs.get_script() as Script if cs != null else null
			if s != null and s.resource_path.ends_with("truck_base.gd") and now - _t0 > 8000:
				var gm: Node = get_node_or_null("/root/GameManager")
				if gm != null:
					gm.call("set_current_level", 1)
					print("[l2c] truck_base reached (t=%ds) -> set level 1, go_to_battle" % [(now - _t0) / 1000])
					gm.call("go_to_battle")
					_go_done = true
					continue
		var bm: Node = get_node_or_null("/root/BattleManager")
		var active: bool = bool(bm.get("battle_active")) if bm != null and "battle_active" in bm else false
		if active and not _in_battle:
			_battle_no += 1
			_in_battle = true
			_sig = ""
			_last_change_msec = now
			print("[l2c] BATTLE #%d STARTED t=%.1fs" % [_battle_no, (now - _t0) / 1000.0])
		elif not active and _in_battle:
			_in_battle = false
		if _in_battle:
			if now - last_status > 5000:
				last_status = now
				var st := _battle_state_sig()
				if st != _sig:
					_sig = st
					_last_change_msec = now
					print("[l2c][b%d t=%ds] %s" % [_battle_no, (now - _t0) / 1000, st])
				var stall_ms := now - _last_change_msec
				if stall_ms > 45000:
					print("[l2c] ⚠ STALL DETECTED in battle #%d, frozen %.0fs: %s" % [_battle_no, stall_ms / 1000.0, _sig])
					_dump_field(bm)
					_dump_trace_tail()
					_shot("stall_b%d" % _battle_no)
					get_tree().quit(2)
					return
		elif _battle_ended_count >= 2:
			print("[l2c] verdict: both battles completed normally (last won=%s)" % str(_won))
			_shot("ended")
			await _wait_frames(30)
			get_tree().quit(0)
			return
	print("[l2c] window timeout (ended=%d in_battle=%s last=%s)" % [_battle_ended_count, str(_in_battle), _sig])
	_dump_trace_tail()
	_shot("timeout")
	get_tree().quit(3)


func _battle_state_sig() -> String:
	var bm: Node = get_node_or_null("/root/BattleManager")
	var wave := int(bm.get("enemy_wave_index")) if bm != null and "enemy_wave_index" in bm else -99
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
		print("[l2c][dump] %s count=%d" % [g, us.size()])
		for u in us.slice(0, 8):
			if is_instance_valid(u):
				print("    %s pos=%s hp=%s" % [u.name, str((u as Node2D).global_position) if u is Node2D else "?", str(u.get("hp")) if "hp" in u else "?"])
	var cs := get_tree().current_scene
	print("[l2c][dump] scene=%s" % (cs.name if cs != null else "?"))


func _dump_trace_tail() -> void:
	var f := FileAccess.open("user://trace.log", FileAccess.READ)
	if f == null:
		print("[l2c][trace] no trace.log")
		return
	var lines := f.get_as_text().split("\n")
	print("[l2c][trace] tail:")
	for ln in lines.slice(maxi(0, lines.size() - 25)):
		print("    ", ln)


func _press_buttons() -> void:
	var cs := get_tree().current_scene
	if cs == null:
		return
	var s: Script = cs.get_script() as Script
	if s != null and s.resource_path.ends_with("title_screen.gd"):
		var btn: Button = cs.get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/ContinueButton") as Button
		if btn != null and not btn.disabled:
			btn.pressed.emit()
			print("[l2c] continue pressed")
		return
	# 结算期优先点「出击下一关」（含"下一关"字样的可见按钮）
	if _battle_ended_count >= 1 and _battle_ended_count < 2:
		var b := _find_button_by_text(cs, "下一关")
		if b != null and b.is_visible_in_tree() and not b.disabled:
			b.pressed.emit()
			print("[l2c] pressed: 下一关")
			return
	for needle in ["启程", "跳过", "进入该关", "开始战斗", "出击"]:
		var b2 := _find_button_by_text(cs, needle)
		if b2 != null and b2.is_visible_in_tree() and not b2.disabled:
			b2.pressed.emit()
			print("[l2c] pressed: ", needle)
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
		print("[l2c] shot → ", p)
