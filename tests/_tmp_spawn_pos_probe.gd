extends Node
## _tmp 全战役敌方落点扫描（2026-09 槽位错位排查收口）：
## 对 LevelBattleLayouts 全部自定义布局关逐一走真实开战链（go_to_battle → 首波/驱动器首批），
## 断言每个敌方单位落点在敌带内；落进我方带（或越出敌带 40px 以上）判 FAIL。
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_spawn_pos_probe.tscn

const Layout = preload("res://scripts/card_grid_battle_layout.gd")
const LevelLayouts = preload("res://data/level_battle_layouts.gd")

var _errs: Array[String] = []
var _fails: Array[String] = []


func _ready() -> void:
	await _run()
	print("\n[SCAN] 完成：FAIL=%d" % _fails.size())
	for f in _fails:
		print("[SCAN][FAIL] ", f)
	for e in _errs:
		print("[SCAN][ERR] ", e)
	get_tree().quit(0 if (_fails.is_empty() and _errs.is_empty()) else 1)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	var main_packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if main_packed == null:
		_errs.append("main.tscn 加载失败")
		return
	var main: Node = main_packed.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait_frames(90)
	var gm: Node = get_tree().root.get_node_or_null("/root/GameManager")
	var bm: Node = get_tree().root.get_node_or_null("/root/BattleManager")
	if gm == null or bm == null:
		_errs.append("autoload 缺失")
		return
	if gm.get("battle_scene") == null:
		await _wait_frames(90)

	for level in LevelLayouts.LAYOUT_BY_LEVEL.keys():
		await _probe_level(gm, bm, int(level))
		if bool(bm.get("battle_active")):
			bm.call("end_battle", false)
			await _wait_frames(6)


func _probe_level(gm: Node, bm: Node, level: int) -> void:
	gm.set_current_level(level)
	gm.go_to_battle()
	await _wait_frames(30)
	if not bool(bm.get("battle_active")):
		await _wait_frames(90)
	if not bool(bm.get("battle_active")):
		_errs.append("L%d 开战失败" % level)
		return
	var is_pm: bool = bool(bm.get("_is_phase_master_battle"))
	var bf: Node = gm.get("battle_scene")
	# 等首波/驱动器首批进场
	await _wait_sec(3.0)
	# 断言阈值
	var e_left: float = Layout.enemy_band_start_x()
	var p_right: float = Layout.player_band_start_x() + Layout.side_band_width_px(false)
	var bad: Array = []
	var cnt: int = _check_positions(bf, e_left, p_right, bad)
	if bad.is_empty():
		print("L%-3d %-4s 敌带>=%.0f 实测 %d 单位全在带内 ✓" % [
			level, "PM" if is_pm else "普通", e_left, cnt])
	else:
		_fails.append("L%d 敌方越带: %s（敌带左缘=%.0f 我方带右缘=%.0f）" % [
			level, str(bad), e_left, p_right])


func _check_positions(bf: Node, e_left: float, p_right: float, bad: Array) -> int:
	var eu: Node = bf.get_node_or_null("EnemyUnits")
	if eu == null:
		return 0
	return _walk(eu, e_left, p_right, bad)


func _walk(n: Node, e_left: float, p_right: float, bad: Array) -> int:
	var cnt: int = 0
	for c in n.get_children():
		if c is Node2D and c.has_meta("card_grid_enemy_slot"):
			var gp: Vector2 = (c as Node2D).global_position
			var esi: int = int(c.get_meta("card_grid_enemy_slot", -1))
			if gp.x < e_left - 40.0 or gp.x < p_right:
				bad.append("槽%d@X%.0f" % [esi, gp.x])
			cnt += 1
		cnt += _walk(c, e_left, p_right, bad)
	return cnt
