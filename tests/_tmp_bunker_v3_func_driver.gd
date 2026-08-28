extends Node
## v3 基地功能深检（临时探针）：全房间点击路径矩阵 / 全修复周期 / 全亮切片对位
## 运行：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_bunker_v3_func_driver.tscn

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")

var _fail_count := 0

func _ready() -> void:
	print("═══ v3 基地功能深检（PATH MATRIX / FULL REPAIR / SLICE ALIGN）═══")
	await _phase_a_path_matrix()
	await _phase_b_full_repair_cycle()
	await _phase_c_slice_align()
	_finish()

func _fail(m: String) -> void:
	_fail_count += 1
	print("[FAIL] " + m)

func _ok(m: String) -> void:
	print("[ OK ] " + m)

func _finish() -> void:
	if _fail_count == 0:
		print("═══════════ 深检全部通过（ALL PASS）═══════════")
		get_tree().quit(0)
	else:
		print("═══════════ 深检失败 %d 项 ═══════════" % _fail_count)
		get_tree().quit(1)

## 点击房间 → 轮询面板打开 → 校验标题 → 关面板
func _click_and_expect(inst: Control, rid: String, room_name: String, timeout := 10.0) -> bool:
	inst._on_room_clicked(rid)
	var panel: Node = inst.get("_panel")
	var t := 0.0
	while t < timeout:
		await get_tree().create_timer(0.2).timeout
		t += 0.2
		if panel != null and panel.call("is_open"):
			var title: String = panel.get("_title_label").text
			panel.call("close")
			return title == room_name
	return false

# ════════ Phase A：全房间点击路径矩阵（从入口出发） ════════

func _phase_a_path_matrix() -> void:
	var packed: PackedScene = load("res://scenes/bunker/bunker_main.tscn")
	var inst: Control = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame

	var mgr: Node = inst.get("_manager")
	mgr.reset_to_defaults()
	# 路径与房间状态无关（锁定房也可走过去开面板），全 14 间逐一验证
	var names := {}
	for r in BunkerRoomDefs.get_all_rooms():
		names[r["id"]] = r["name"]
	var hits := 0
	for rid in ["weather_station", "monument", "observatory", "depot", "comms",
			"honor_hall", "reactor", "war_room", "workshop", "archive",
			"medical", "mess_hall", "dormitory", "entry_hall"]:
		if await _click_and_expect(inst, rid, names[rid]):
			hits += 1
		else:
			_fail("路径矩阵：%s 未到达或面板标题错误" % rid)
	if hits == 14:
		_ok("路径矩阵：入口出发 14/14 全到达（含 via 双跳链 气象→纪念碑→闸塔）")
	# 回到宿舍后再次跨层（宿舍→观星台，验证从 via 链中段房间出发）
	if await _click_and_expect(inst, "observatory", names["observatory"]):
		_ok("二次路径：宿舍→观星台（隧道房出发）正常")
	else:
		_fail("二次路径：宿舍→观星台失败")
	inst.queue_free()

# ════════ Phase B：全修复周期（13 间全点亮 + 终局仍锁） ════════

func _phase_b_full_repair_cycle() -> void:
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	mgr.reset_to_defaults()
	for i in 10:
		mgr.debug_grant_resources()
	# 荣誉室碎片门槛：预置 10 枚（对齐游戏规则）
	for mid in ["enemy_master_001", "enemy_master_002", "enemy_master_003",
			"enemy_master_004", "enemy_master_005", "enemy_master_006",
			"enemy_master_008", "enemy_master_009", "enemy_master_010", "enemy_master_011"]:
		mgr.record_hero_fragment(mid)
	var started := 0
	for r in BunkerRoomDefs.get_all_rooms():
		if r["id"] == "observatory" or int(r["initial"]) == BunkerRoomDefs.STATE_ACTIVE:
			continue
		var res: Dictionary = mgr.start_repair(r["id"])
		if res.get("ok", false):
			started += 1
		else:
			_fail("%s 修复放行失败: %s" % [r["id"], str(res.get("reason", ""))])
	if started != 10:
		_fail("应放行 10 间修复（14-3初始亮-终局），实际 %d" % started)
	for i in 12:
		mgr.advance_after_battle(true)
	var active := 0
	for r in BunkerRoomDefs.get_all_rooms():
		var rid: String = r["id"]
		if rid == "observatory":
			if mgr.get_room_state(rid) != BunkerRoomDefs.STATE_LOCKED:
				_fail("观星台终局应恒锁")
			continue
		if mgr.get_room_state(rid) == BunkerRoomDefs.STATE_ACTIVE:
			active += 1
		else:
			_fail("%s 全修复周期后未点亮" % rid)
	if active == 13:
		_ok("全修复周期：13/13 全点亮，反应堆上线，观星台恒锁")
	if not mgr.is_reactor_online():
		_fail("全修复后反应堆应在线")
	var cond: Dictionary = mgr.is_observatory_unlockable()
	if cond.get("ok", true) or (cond.get("reasons", []) as Array).is_empty():
		_fail("观星台条件在缺碎片/通关时应返回原因列表")
	else:
		_ok("观星台条件：全房修复后仍按碎片/通关门槛拦（%d 条原因）" % (cond.get("reasons", []) as Array).size())

# ════════ Phase C：全亮切片对位（每房 AtlasTexture.region == 房间矩形） ════════

func _phase_c_slice_align() -> void:
	var packed: PackedScene = load("res://scenes/bunker/bunker_main.tscn")
	var inst: Control = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var mgr2: Node = inst.get("_manager")
	var rects: Dictionary = inst.get("_room_rects")
	var nodes: Dictionary = inst.get("_room_nodes")
	var ambient: Node2D = inst.get("_ambient")
	if ambient == null or (ambient.get("_room_rects") as Dictionary).size() != 14:
		_fail("氛围层未注入 14 房矩形")
	var aligned := 0
	for rid in rects:
		var ov: Control = nodes[rid]
		var lit: TextureRect = ov.get("_lit_rect")
		if lit == null:
			_fail("%s 全亮切片缺失（LIT_TEX 加载失败？）" % rid)
			continue
		var is_active: bool = mgr2.get_room_state(rid) == BunkerRoomDefs.STATE_ACTIVE
		if is_active and not lit.visible:
			_fail("%s 可用状态下切片应可见" % rid)
			continue
		if not is_active and lit.visible:
			_fail("%s 锁定状态下切片应隐藏" % rid)
			continue
		if not is_active:
			continue  # 锁定房只验隐藏语义，无 region 可比对（slice 不可见）
		var expect: Rect2 = rects[rid]
		var region: Rect2 = (lit.texture as AtlasTexture).region
		if absf(region.position.x - expect.position.x) < 0.5 \
				and absf(region.position.y - expect.position.y) < 0.5 \
				and absf(region.size.x - expect.size.x) < 0.5 \
				and absf(region.size.y - expect.size.y) < 0.5:
			aligned += 1
		else:
			_fail("%s 切片区域错位: %s != %s" % [rid, region, expect])
	var expect_active := 0
	for rid2 in rects:
		if mgr2.get_room_state(rid2) == BunkerRoomDefs.STATE_ACTIVE:
			expect_active += 1
	if aligned == expect_active:
		_ok("切片对位：%d/%d 可用房 region 与房间矩形逐像素一致；锁定房切片正确隐藏" % [aligned, expect_active])
	else:
		_fail("切片对位 %d/%d 未对齐" % [aligned, expect_active])
	inst.queue_free()
