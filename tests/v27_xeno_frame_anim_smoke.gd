extends Node
## v27.2 星冥帧动画继承验证（场景模式）：数据解析 20/20 + 场上驱动真实挂载 + attack 播放
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/v27_xeno_frame_anim_smoke.tscn
##
## 覆盖：
##   1. 数据层：20 单位经 visual_id 继承雪碧条（19）或 boss 独立帧（xeno_templar→fut_boss_nexus）；
##      captured_xeno_* 缴获镜像同链解析
##   2. 场景层：真实无尽开战后——普通单位 UnitFrameAnimDriver 挂载（idle ping-pong）+
##      notify_fire 播 attack 一遍回 idle；boss 词缀单位 BossIdleFrameDriver；
##      雪碧条星冥上 boss 词缀 → xeno 兜底雪碧条驱动

const XenoUnits = preload("res://data/xeno_units.gd")
const UnitFrameAnim = preload("res://scripts/battle/unit_frame_anim.gd")
const BossIdleAnim = preload("res://scripts/battle/boss_idle_anim.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")

var _log: PackedStringArray = []
var _errs: PackedStringArray = []


func _ready() -> void:
	await _run()
	for e in _errs:
		printerr("[v27] FAIL: " + e)
	for l in _log:
		print(l)
	if _errs.is_empty():
		print("[v27] FRAME-ANIM-SMOKE PASS")
	get_tree().quit(0 if _errs.is_empty() else 1)


func _ok(s: String) -> void:
	_log.append("  ✓ " + s)


func _fail(s: String) -> void:
	_errs.append(s)
	_log.append("  [FAIL] " + s)


func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_sec(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _find_driver(unit: Node, driver_name: String) -> Node:
	if unit == null or not is_instance_valid(unit):
		return null
	return unit.find_child(driver_name, true, false)


func _run() -> void:
	# ── 1. 数据层解析 ──
	_log.append("═══ 1. 数据层：visual_id 帧资产继承 ═══")
	var sheet_units: Array = []
	var boss_units: Array = []
	for xid in XenoUnits.ID_ORDER:
		var key: String = UnitFrameAnim._resolve_key(String(xid))
		if not key.is_empty():
			sheet_units.append("%s→%s" % [String(xid), key])
		else:
			var vis: String = EnemyUnitManifest.visual_id_for_archetype(String(xid))
			if ResourceLoader.exists("res://assets/effects/unit_anims/%s/idle_f0.png" % vis) \
					and ResourceLoader.exists("res://assets/effects/unit_anims/%s/idle_f1.png" % vis):
				boss_units.append("%s→%s(boss帧)" % [String(xid), vis])
			else:
				_fail("%s 无任何帧资产可继承（vis=%s）" % [String(xid), vis])
	_log.append("  雪碧条继承 %d：%s" % [sheet_units.size(), str(sheet_units)])
	_log.append("  boss 帧继承 %d：%s" % [boss_units.size(), str(boss_units)])
	if sheet_units.size() + boss_units.size() != 20:
		_fail("帧资产覆盖 %d/20" % (sheet_units.size() + boss_units.size()))
	else:
		_ok("20/20 单位有帧动画可继承")
	# 缴获镜像（captured_ 前缀同链）
	var cap_miss: Array = []
	for xid in XenoUnits.ID_ORDER:
		var key: String = UnitFrameAnim._resolve_key("captured_" + String(xid))
		if key.is_empty() and String(xid) != "xeno_templar":
			cap_miss.append(String(xid))
	if not cap_miss.is_empty():
		_fail("缴获镜像雪碧条解析 miss: %s" % str(cap_miss))
	else:
		_ok("captured_xeno_* 镜像雪碧条解析 20/20 全命中")

	# ── 2. 场景层 ──
	_log.append("═══ 2. 场景层：无尽开战后驱动真实挂载 ═══")
	var main_packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if main_packed == null:
		_fail("main.tscn 加载失败")
		return
	var main: Node = main_packed.instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait_frames(90)
	var gm: Node = get_tree().root.get_node_or_null("/root/GameManager")
	var bm: Node = get_tree().root.get_node_or_null("/root/BattleManager")
	if gm == null or bm == null:
		_fail("autoload 缺失")
		return
	if gm.get("battle_scene") == null:
		await _wait_frames(90)
	if gm.get("battle_scene") == null:
		_fail("battle_scene 未就绪")
		return
	gm.set_current_level(100)
	gm.start_endless_battle()
	gm.go_to_battle()
	await _wait_frames(40)
	if not bool(bm.get("battle_active")):
		await _wait_frames(90)
	if not bool(bm.get("battle_active")):
		_fail("无尽开战失败")
		return
	var bss = bm.get("_spawn_system")
	var bf: Node = gm.get("battle_scene")
	# 清场（首波别干扰）
	var eu: Node = bf.get_node_or_null("EnemyUnits")
	if eu != null:
		for c in eu.get_children():
			c.queue_free()
	await _wait_frames(4)
	bss.sync_enemy_unit_count_from_field()

	# 2a. 普通星冥：UnitFrameAnimDriver + idle + attack
	var zealot: Node = bss.call("_create_enemy_unit_with_id", "xeno_zealot")
	bss.spawn_enemy_unit_on_card_grid(zealot, -1)
	await _wait_sec(0.8)
	var drv: Node = _find_driver(zealot, "UnitFrameAnimDriver")
	if drv == null:
		_fail("xeno_zealot 未挂 UnitFrameAnimDriver（雪碧条继承失效）")
	else:
		var idle_n: int = int(drv.get("idle_frames").size())
		var atk_n: int = int(drv.get("attack_frames").size())
		var mode: String = str(drv.get("_mode"))
		if idle_n < 2:
			_fail("xeno_zealot idle 帧 %d < 2" % idle_n)
		elif mode != "idle":
			_fail("初始模式 %s != idle" % mode)
		else:
			_ok("渡暮狂战士：UnitFrameAnimDriver（idle %d 帧 ping-pong，attack %d 帧）" % [idle_n, atk_n])
		# attack 播放：notify_fire → attack → 播完回 idle
		if atk_n > 0:
			var spr: Sprite2D = drv.get_parent() as Sprite2D
			UnitFrameAnim.notify_fire(spr)
			await _wait_frames(2)
			if str(drv.get("_mode")) != "attack":
				_fail("notify_fire 后未进 attack 模式")
			else:
				var fps: float = maxf(float(drv.get("fps")), 0.1)
				await _wait_sec((atk_n + 2) / fps)
				if str(drv.get("_mode")) != "idle":
					_fail("attack 播完未回 idle")
				else:
					_ok("开火→attack 单次播放→回 idle")

	# 2b. 首领词缀星冥（占位全部雪碧条资产 → xeno 兜底分支挂 UnitFrameAnimDriver；
	# boss 独立帧目录无敌方原图，v27.2 全员雪碧条）
	var templar: Node = bss.call("_create_enemy_unit_with_id", "xeno_templar")
	templar.apply_elite_affixes("boss")
	bss.spawn_enemy_unit_on_card_grid(templar, -1)
	await _wait_sec(0.8)
	var bdrv: Node = _find_driver(templar, "UnitFrameAnimDriver")
	if bdrv == null:
		_fail("xeno_templar(boss 词缀) 未走雪碧条兜底（词缀首领无动画）")
	else:
		_ok("高阶圣堂武士(boss 词缀)：雪碧条驱动（idle %d 帧 + attack %d 帧 + 威压摇摆）" % [
			int(bdrv.get("idle_frames").size()), int(bdrv.get("attack_frames").size())])

	# 2c. 首领词缀 + 雪碧条占位（xeno_swarmling→fut_drone，走 xeno 兜底分支）
	var swarm: Node = bss.call("_create_enemy_unit_with_id", "xeno_swarmling")
	swarm.apply_elite_affixes("boss")
	bss.spawn_enemy_unit_on_card_grid(swarm, -1)
	await _wait_sec(0.8)
	var sdrv: Node = _find_driver(swarm, "UnitFrameAnimDriver")
	if sdrv == null:
		_fail("xeno_swarmling(boss 词缀) 未走雪碧条兜底（词缀星冥无动画）")
	else:
		_ok("蚀群幼体(boss 词缀)：雪碧条兜底驱动（idle %d 帧）" % int(sdrv.get("idle_frames").size()))
