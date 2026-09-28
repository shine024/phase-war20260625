extends Control
## _tmp_blackgate_reenter_probe.gd（临时探针——复现"黑门33波退出后再次点黑门没反应"）
## 真实存档（slot1）态下走完整判定链，逐步打印断点。只读存档，不写。
##
## 跑法（headless，autoload 全加载）：
##   GODOT --headless --rendering-driver opengl3 --path . res://tests/_tmp_blackgate_reenter_probe.tscn

const WorldMapScene := preload("res://scenes/world_map.tscn")

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func _check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  [PASS] %s %s" % [name, detail])
	else:
		_fails += 1
		print("  [FAIL] %s %s" % [name, detail])


func _run() -> void:
	print("=== PROBE blackgate re-enter ===")

	# ── 1) 读真实存档（只读） ──
	var sm: Node = get_node_or_null("/root/SaveManager")
	_check("SaveManager 在", sm != null)
	if sm == null:
		_finish()
		return
	var loaded: bool = bool(sm.load_game())
	print("  load_game(slot=%d) -> %s" % [int(sm.get_slot()), loaded])
	await get_tree().process_frame
	await get_tree().process_frame

	# ── 2) 核心状态（模拟 33 波结算后的第二会话/同会话状态） ──
	var gm: Node = get_node_or_null("/root/GameManager")
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	var mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if mll != null:
		mll.ensure_loaded("bunker")
		mll.ensure_loaded("endless")
	await get_tree().process_frame
	var bm: Node = get_node_or_null("/root/BunkerManager")
	var ebm: Node = get_node_or_null("/root/EndlessBlackgateManager")
	_check("BunkerManager 在", bm != null)
	_check("EndlessBlackgateManager 在", ebm != null)

	var stars100: int = int(lpm.get_level_stars(100)) if lpm != null else -1
	var parked: int = int(bm.get_parked_level()) if bm != null else -1
	print("  stars(100)=%d parked=%d current_level=%s" % [stars100, parked, str(gm.get("current_level"))])

	# 模拟 33 波结算后的运行态：已耗 1 次免费、run 已结算、无尽标志已清
	if ebm != null:
		ebm.set("_entries_used_today", 1)
		ebm.set("run_active", false)
	if gm != null:
		gm.set("_is_endless_battle", false)

	# ── 3) 判定链三段（world_map._on_blackgate_gui_input / _enter_blackgate 同口径） ──
	print("-- 判定链 --")
	var unlocked: bool = stars100 > 0
	_check("①解锁判定 stars(100)>0", unlocked)
	var parked_ok: bool = parked == 100
	_check("②停靠门控 parked==100", parked_ok, "parked=%d" % parked)
	var st: Dictionary = ebm.get_entry_status() if ebm != null else {}
	var can_enter: bool = bool(st.get("can_enter", false))
	_check("③软门 can_enter", can_enter, str(st))

	# ── 4) 实例化 world_map，模拟点击黑门 ──
	print("-- world_map 实例化 --")
	var wm: Node = WorldMapScene.instantiate()
	add_child(wm)
	# 等建图帧（_build_level_map 等 deferred）
	for _i in 4:
		await get_tree().process_frame
	var gate: Node = wm.find_child("BlackGateEntry", true, false)
	_check("黑门热区存在", gate != null)
	if gate != null and gate is Control:
		var gc := gate as Control
		print("  gate visible=%s modulate=%s size=%s pos=%s" % [str(gc.visible), str(gc.modulate), str(gc.size), str(gc.global_position)])
	_check("黑门热区可见", gate != null and gate is Control and (gate as Control).visible)

	# 模拟左键按下（world_map._on_blackgate_gui_input 同事件口径）
	if gate != null:
		var ev := InputEventMouseButton.new()
		ev.pressed = true
		ev.button_index = MOUSE_BUTTON_LEFT
		wm.call("_on_blackgate_gui_input", ev)
		await get_tree().process_frame
		var popup: Node = wm.get("_level_info_popup")
		_check("弹窗已创建", popup != null and is_instance_valid(popup))
		if popup != null:
			print("  popup visible=%s title=%s" % [str(popup.get("visible")), str(popup.get("title"))])
			_check("弹窗可见", bool(popup.get("visible")))

			# ── 5) 踏入判定（不真切场景：单独复算 _enter_blackgate 的门控段） ──
			# parked 门控 + can_enter 门控都过的话，_enter_blackgate_confirmed 会走
			# set_current_level(100) + start_endless_battle + SceneTransition.change(main)
			# ——headless 下真切 main.tscn 会拖起整个战场链，此处只验证标志位通路
			print("-- 踏入链判定 --")
			_check("④踏入门控 parked", parked_ok)
			_check("⑤踏入门控 can_enter", can_enter)
			# 复算 confirmed 前半段（不切场景）
			gm.call("set_current_level", 100)
			gm.call("start_endless_battle")
			await get_tree().process_frame
			_check("⑥start_endless_battle 标志置位", bool(gm.get("_is_endless_battle")))
			print("  is_endless_battle=%s current_level=%s" % [str(gm.get("_is_endless_battle")), str(gm.get("current_level"))])
			# 还原（防探针残留影响后续手跑）
			gm.set("_is_endless_battle", false)

	_finish()


func _finish() -> void:
	print("=== PROBE DONE fails=%d ===" % _fails)
	if _fails == 0:
		print("BLACKGATE_REENTER_PROBE_OK")
	get_tree().quit(0 if _fails == 0 else 1)
