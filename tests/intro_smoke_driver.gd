extends Node
## 序章开场冒烟测试 v24
## 运行：godot --headless --rendering-driver opengl3 --path . res://tests/intro_smoke_driver.tscn
## （场景模式跑——autoload 全量初始化；不用 --script 模式因其不加载 autoload）
##
## 覆盖：
##   Phase1 漫画分格数据完整性（11 格 / 字段 / id 唯一 / 文案 / texture 槽）
##   Phase2 comic 场景实例化 + 逐格推进 + dry-run 收尾（meta 落位，不切场景）
##   Phase3 bunker 醒来演出：标记触发 / 演出节点创建 / comic_seen 落档 / 跳过清理 /
##     无标记直进引导卡（旧路径回归）
##   Phase4 comic_seen 存档往返（save_state / load_state / reset_to_defaults）

const PanelsData = preload("res://data/intro_comic_panels.gd")

const META_COMIC_PENDING := "bunker_intro_comic_pending"
const META_WAKEUP := "bunker_intro_wakeup_pending"
const META_DRY_RUN := "bunker_intro_dry_run"
const META_BATTLE_RESUME := "bunker_intro_battle_resume"

var _fail_count := 0

func _ready() -> void:
	print("═════════════════════════════════════════════════")
	print("  序章开场冒烟测试（INTRO SMOKE）")
	print("═════════════════════════════════════════════════")
	await _phase1_data()
	await _phase2_comic()
	await _phase2b_dream_battle()
	await _phase3_wakeup()
	await _phase4_flags()
	_finish()

func _fail(msg: String) -> void:
	_fail_count += 1
	push_error("[FAIL] " + msg)
	print("[FAIL] " + msg)

func _ok(msg: String) -> void:
	print("[ OK ] " + msg)

func _finish() -> void:
	if _fail_count == 0:
		print("═══════════ 全部通过（ALL PASS）═══════════")
		get_tree().quit(0)
	else:
		print("═══════════ 失败 %d 项 ═══════════" % _fail_count)
		get_tree().quit(1)

# ══════════════════ Phase 1：分格数据 ══════════════════

func _phase1_data() -> void:
	var panels: Array = PanelsData.PANELS
	if panels.size() != 11:
		_fail("分格应为 11，实际 %d" % panels.size())
	var seen := {}
	for i in panels.size():
		var p: Dictionary = panels[i]
		for key in ["id", "motif", "accent", "title", "text"]:
			if not p.has(key):
				_fail("第 %d 格缺字段 %s" % [i + 1, key])
		if seen.has(p.get("id")):
			_fail("格 id 重复: %s" % str(p.get("id")))
		seen[p.get("id")] = true
		if str(p.get("text", "")).length() < 10:
			_fail("第 %d 格文案过短" % (i + 1))
		if str(p.get("texture", "")) == "":
			_fail("第 %d 格缺 texture 槽" % (i + 1))
	if PanelsData.count() != panels.size():
		_fail("count() 与 PANELS.size() 不一致")
	_ok("分格数据 11 格：字段齐 / id 唯一 / 文案非空 / texture 槽齐")

# ══════════════════ Phase 2：漫画场景 dry-run ══════════════════

func _phase2_comic() -> void:
	Engine.set_meta(META_DRY_RUN, true)
	Engine.set_meta(META_COMIC_PENDING, true)
	var packed: PackedScene = load("res://scenes/intro/comic_intro.tscn")
	if packed == null:
		_fail("comic_intro.tscn 加载失败")
		return
	var inst := packed.instantiate()
	var finished := {"v": false}
	inst.intro_finished.connect(func(): finished["v"] = true)
	add_child(inst)
	await get_tree().create_timer(0.9).timeout
	if inst.get("_stage") == null:
		_fail("comic 舞台未构建")
	if int(inst.get("_index")) != 0:
		_fail("首格索引应为 0，实际 %d" % int(inst.get("_index")))
	var battle_req := {"v": false}
	inst.dream_battle_requested.connect(func(): battle_req["v"] = true)
	# advance#1：B1→B2；advance#2：B2→B2a——v24.5 摘钩后 B2 是纯讲述格，不得触发战斗
	for i in 2:
		inst.call("advance")
		await get_tree().create_timer(0.55).timeout
	if bool(battle_req["v"]):
		_fail("B2 已摘钩，不应再发出梦境战请求")
	else:
		_ok("B2 纯讲述：梦境战入口已摘钩")
	if int(inst.get("_index")) != 2:
		_fail("两次推进后应停在 B2a（索引 2），实际 %d" % int(inst.get("_index")))
	# 续播至末格 → 收尾（索引 2 → 10 共 8 次）
	for i in 8:
		inst.call("advance")
		await get_tree().create_timer(0.55).timeout
	inst.call("advance")                            # 第 11 格 → 触发收尾
	await get_tree().create_timer(3.4).timeout      # _finish 转黑+点睛句 ~2.9s 后才 _hand_off
	if not bool(finished["v"]):
		_fail("最后一格推进后未触发 intro_finished")
	if not Engine.has_meta(META_WAKEUP):
		_fail("收尾未设置 wakeup meta")
	if Engine.has_meta(META_COMIC_PENDING):
		_fail("收尾未消费 comic_pending meta")
	_ok("comic 逐格推进 → 收尾：intro_finished + meta 落位（dry-run 不切场景）")
	inst.queue_free()
	await get_tree().process_frame
	Engine.remove_meta(META_WAKEUP)
	Engine.remove_meta(META_BATTLE_RESUME)
	Engine.remove_meta(META_DRY_RUN)

# ══════════════════ Phase 2b：梦境战 dry-run（v24.5 开场摘钩，场景保留回归）══════════════════

func _phase2b_dream_battle() -> void:
	Engine.set_meta(META_DRY_RUN, true)
	var packed: PackedScene = load("res://scenes/intro/dream_battle.tscn")
	if packed == null:
		_fail("dream_battle.tscn 加载失败")
		return
	var inst := packed.instantiate()
	var finished := {"v": false}
	inst.battle_finished.connect(func(): finished["v"] = true)
	add_child(inst)
	await get_tree().create_timer(3.5).timeout
	if not bool(finished["v"]):
		_fail("梦境战 dry-run 未按时收尾（应 ~1s 压缩时间线）")
	if int(Engine.get_meta(META_BATTLE_RESUME)) != 2:
		_fail("梦境战收尾未落 resume meta=2")
	else:
		_ok("梦境战场景保留回归：dry-run 真实单位 spawn + 收尾 meta 落位")
	inst.queue_free()
	await get_tree().process_frame
	Engine.remove_meta(META_BATTLE_RESUME)
	Engine.remove_meta(META_DRY_RUN)

# ══════════════════ Phase 3：bunker 醒来演出 ══════════════════

func _phase3_wakeup() -> void:
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	if mgr == null:
		_fail("BunkerManager 不可用")
		return
	var packed: PackedScene = load("res://scenes/bunker/bunker_main.tscn")
	if packed == null:
		_fail("bunker_main.tscn 加载失败")
		return

	# a) 带 wakeup 标记：演出创建 / meta 消费 / comic_seen 落档 / 跳过清理
	mgr.reset_to_defaults()
	mgr.mark_intro_shown()
	Engine.set_meta(META_WAKEUP, true)
	var inst := packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var stage: Control = inst.get("_ui_stage")
	if stage == null:
		_fail("bunker UI 舞台未创建")
		inst.queue_free()
		return
	if stage.get_node_or_null("WakeupCinematic") == null:
		_fail("醒来演出节点未创建")
	else:
		_ok("wakeup 标记 → 醒来演出创建（睁眼/闪回/画外音）")
	if Engine.has_meta(META_WAKEUP):
		_fail("wakeup meta 未被消费")
	if not mgr.is_comic_seen():
		_fail("comic_seen 未随演出落档")
	else:
		_ok("comic_seen 已落档")
	inst.call("_finish_wakeup")
	await get_tree().process_frame
	if stage.get_node_or_null("WakeupCinematic") != null:
		_fail("跳过后演出节点未清理")
	if stage.get_node_or_null("IntroDim") != null:
		_fail("intro_shown=true 时不应弹引导卡")
	else:
		_ok("跳过演出 → 干净进基地（引导卡已看过不重复弹）")
	inst.queue_free()
	await get_tree().process_frame

	# b) 无标记（旧档/直进）：直接弹引导卡
	mgr.reset_to_defaults()
	var inst2 := packed.instantiate()
	add_child(inst2)
	await get_tree().process_frame
	await get_tree().process_frame
	var stage2: Control = inst2.get("_ui_stage")
	if stage2.get_node_or_null("WakeupCinematic") != null:
		_fail("无标记不应创建醒来演出")
	if stage2.get_node_or_null("IntroDim") == null:
		_fail("无标记时引导卡未弹出")
	else:
		_ok("无 wakeup 标记 → 直接弹首次引导卡（旧路径回归）")
	inst2.queue_free()
	await get_tree().process_frame

# ══════════════════ Phase 4：comic_seen 持久化 ══════════════════

func _phase4_flags() -> void:
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	mgr.reset_to_defaults()
	if mgr.is_comic_seen():
		_fail("新档 comic_seen 应为 false")
	mgr.mark_comic_seen()
	var snap: Dictionary = mgr.save_state()
	if not bool(snap.get("comic_seen", false)):
		_fail("save_state 缺 comic_seen 字段")
	mgr.reset_to_defaults()
	if mgr.is_comic_seen():
		_fail("reset_to_defaults 未清 comic_seen")
	mgr.load_state(snap)
	if not mgr.is_comic_seen():
		_fail("load_state 未恢复 comic_seen")
	_ok("comic_seen 存档往返（save/load/reset）")
	mgr.reset_to_defaults()
