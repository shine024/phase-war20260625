extends Node
## v26.19 卡车行军 E2E 执行体（直挂 /root 存活换场景）
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_travel_check_boot.tscn
## 流程：满罐起步 → 回程一关 start_travel（地图开着看动画/徽标）→ 在途拒绝再规划 →
##       睡觉推进到站（停靠点/current_level 同步断言）→ 低储备拒出车 → 引擎升级 →
##       地图门控 UI（停靠关=情报弹窗 / 非停靠=行军规划 / 直呼出击被守卫拦）
## 截图 .godot/agent_tools/travel_*.png；退出码非 0 = 有断言失败
## ⚠️ sleep 推进天数 + 引擎/资源入账会随退出存档——跑前备份、跑后由外部恢复存档。

const TruckTravel = preload("res://data/truck_travel.gd")
var _fails: Array[String] = []


func _ready() -> void:
	await _run()
	for f in _fails:
		printerr("[Travel] FAIL: " + f)
	print("[Travel] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES"))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _cur_path() -> String:
	var cs := get_tree().current_scene
	return str(cs.scene_file_path)


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(ProjectSettings.globalize_path("res://.godot/agent_tools/travel_%s.png" % tag))
		print("[Travel] shot %s" % tag)


func _run() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm != null and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")
	if ManagerLazyLoader != null and ManagerLazyLoader.has_method("ensure_loaded"):
		ManagerLazyLoader.ensure_loaded("bunker")
	var bm: Node = get_node_or_null("/root/BunkerManager")
	if bm == null:
		_fails.append("BunkerManager 未创建")
		return

	# ── A. 状态热身：新档复现（可选 FRESH=1 跳过状态注入）──
	var fresh := OS.get_environment("TRAVEL_FRESH") == "1"
	var park := int(bm.get_parked_level())
	if park < 1:
		_fails.append("停靠点解析失败")
		return
	if not fresh and park == 1:
		bm.set("_parked_level", 2)
		park = 2
	if not fresh:
		bm.set("_fuel", float(bm.get_fuel_cap()))
	print("[Travel] fresh=%s park=%d" % [fresh, park])
	print("[Travel] park=%d dest=1（回程半价）" % park)

	# ── A2. 新档路径探测：解锁线 == 停靠点时，其他节点全部锁定 ──
	if fresh:
		var lp := get_node_or_null("/root/LevelProgressManager")
		var mu := -1
		if lp != null and lp.has_method("get_max_unlocked_level"):
			mu = int(lp.get_max_unlocked_level())
		print("[Travel] 新档解锁线 max_unlocked=%d, parked=%d" % [mu, park])
		if mu > park:
			if lp != null and lp.has_method("set_max_unlocked_level"):
				lp.call("set_max_unlocked_level", mu)
	SceneTransition.change(get_tree(), "res://scenes/world_map.tscn")
	print("[Travel] B1: 切地图前")
	SceneTransition.change(get_tree(), "res://scenes/world_map.tscn")
	print("[Travel] B2: change 已调用")
	await _wait(70)
	print("[Travel] B3: 等待完成 cur=%s" % [_cur_path()])
	if not _cur_path().contains("world_map"):
		_fails.append("未进入 world_map: " + _cur_path())
		return
	var map: Node = get_tree().current_scene
	if map == null or map.get_script() == null:
		_fails.append("world_map 脚本未挂载（编译失败）")
		return
	print("[Travel] B4: 地图节点到手")
	await _shot("fresh_map")
	if OS.get_environment("TRAVEL_FRESH") == "1":
		# 新档全流程：自由行军到未解锁关5 → 到站 → 关卡情报（战前准备）→ 进入该关直接开打
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.connect(func(m: String) -> void: print("[Travel][toast] ", m))
		var map2: Node = get_tree().current_scene
		map2.call("_on_level_selected", 5)
		await _wait(6)
		var p5: Window = map2.get("_level_info_popup")
		print("[Travel] 点未解锁关5 → 弹窗标题: ", (p5.title if p5 != null else "无"))
		if p5 != null:
			map2.call("_close_popup_safe", p5)
			await _wait(4)
		var res5: Dictionary = bm.start_travel(5)
		if not bool(res5.get("ok", false)):
			_fails.append("新档 start_travel(5) 失败: " + str(res5.get("reason", "")))
			get_tree().quit(1)
			return
		print("[Travel] 出发→关5 OK：", res5)
		bm.set("_travel_ends_unix", Time.get_unix_time_from_system() - 1.0)
		bm.call("_check_travel_arrival")
		if int(bm.get_parked_level()) != 5:
			_fails.append("未停靠到关5: %d" % int(bm.get_parked_level()))
		map2.call("_on_level_selected", 5)
		await _wait(6)
		var p5b: Window = map2.get("_level_info_popup")
		print("[Travel] 停靠关5 → 弹窗标题: ", (p5b.title if p5b != null else "无"))
		var has_enter := false
		if p5b != null:
			for btn in p5b.find_children("*", "Button", true, false):
				if String(btn.text).contains("进入该关"):
					has_enter = true
		if not has_enter:
			_fails.append("停靠未解锁关的情报弹窗缺「进入该关」按钮")
		else:
			print("[Travel] 停靠未解锁关 → 「进入该关」按钮在位")
		if p5b != null:
			map2.call("_enter_level_from_popup", 5, p5b)
			await _wait(6)
			if int(GameManager.get("current_level")) != 5:
				_fails.append("停靠未解锁关出击被拦 current=%d" % int(GameManager.get("current_level")))
			else:
				print("[Travel] 停靠即战 OK：current_level=5")
		print("[Travel] 新档探测完成")
		get_tree().quit(0 if _fails.is_empty() else 1)
		return
	var plan: Dictionary = bm.plan_travel(1)
	if not bool(plan.get("ok", false)):
		_fails.append("plan_travel 失败: " + str(plan.get("reason", "")))
		return
	print("[Travel] B5: plan OK %s" % [plan])
	var res: Dictionary = bm.start_travel(1)
	print("[Travel] B6: start_travel → %s" % [res])
	if not bool(res.get("ok", false)):
		_fails.append("start_travel 失败: " + str(res.get("reason", "")))
		return
	if not bool(bm.is_traveling()):
		_fails.append("start_travel 后不在途")
	if int(bm.get_travel_days_left()) < 1:
		_fails.append("days_left 异常")
	if float(bm.get_fuel()) >= float(bm.get_fuel_cap()):
		_fails.append("启程后燃料未扣减")
	print("[Travel] 启程 OK：-燃料" + str(int(res.get("cost", 0))) + " · " + str(int(res.get("days", 0))) + " 天")
	# 在途再规划必须被拒
	if bool(bm.plan_travel(park).get("ok", false)):
		_fails.append("行驶中仍可规划新行程（应拒绝）")
	await _wait(140)
	# 诊断：光点/路线节点状态
	var mk: Control = map.get("_truck_marker")
	var rt: Control = map.get("_travel_route")
	print("[Travel] marker=", mk,
		" in_tree=", (mk != null and mk.is_inside_tree()),
		" visible=", (mk != null and mk.is_visible_in_tree()),
		" pos=", (mk.position if mk != null else Vector2()),
		" size=", (mk.size if mk != null else Vector2()),
		" parent=", (mk.get_parent().name if mk != null and mk.get_parent() != null else "null"))
	print("[Travel] route=", rt,
		" in_tree=", (rt != null and rt.is_inside_tree()),
		" size=", (rt.size if rt != null else Vector2()),
		" parent=", (rt.get_parent().name if rt != null and rt.get_parent() != null else "null"))
	var canvas_node: Node = mk.get_parent() if mk != null else null
	if canvas_node != null:
		print("[Travel] canvas=", canvas_node, " canvas_pos=", (canvas_node as Control).position,
			" canvas_size=", (canvas_node as Control).size)
	await _shot("en_route")

	# ── C. 实时行军：睡觉只回充不推进；ETA 换算；强制到期结算 ──
	await get_tree().create_timer(15.0).timeout
	if not bool(bm.is_traveling()):
		_fails.append("15 秒后应仍在途（60 秒/天）")
	bm.sleep()
	if not bool(bm.is_traveling()):
		_fails.append("睡觉不应推进实时行军（应仍在途）")
	if float(bm.get_fuel()) <= 0.0:
		_fails.append("睡觉未回充燃料")
	var ends: float = float(bm.get("_travel_ends_unix"))
	var remaining: float = ends - Time.get_unix_time_from_system()
	var expect_days: int = maxi(1, int(ceil(remaining / TruckTravel.SECONDS_PER_DAY)))
	if int(bm.get_travel_days_left()) != expect_days:
		_fails.append("剩余天数与 ETA 换算不符: %d != %d" % [int(bm.get_travel_days_left()), expect_days])
	await _shot("en_route_late")
	bm.set("_travel_ends_unix", Time.get_unix_time_from_system() - 1.0)
	bm.call("_check_travel_arrival")
	if bool(bm.is_traveling()):
		_fails.append("到期未到站")
	elif int(bm.get_parked_level()) != 1:
		_fails.append("到站停靠点不符: %d != 1" % int(bm.get_parked_level()))
	if GameManager != null and int(GameManager.get("current_level")) != 1:
		_fails.append("到站后 current_level 未同步: %d" % int(GameManager.get("current_level")))
	print("[Travel] 到站 OK（实时到期结算；睡觉仅回充不推进）")
	await _wait(80)
	await _shot("arrived")

	# ── D. 安全储备门槛：油只剩地板附近时应拒出车（除非路程便宜到不越线）──
	bm.set("_fuel", float(TruckTravel.RESERVE_FLOOR) + 3.0)
	var plan3: Dictionary = bm.plan_travel(park)
	if bool(plan3.get("ok", false)) and int(plan3.get("cost", 0)) > 3:
		_fails.append("低储备仍可出车（应拒绝）")

	# ── E. 引擎升级（资源入账 → Lv2，罐容/速度随动）──
	if BasicResourceManager != null:
		BasicResourceManager.add_resource("nano_materials", 1000)
		BasicResourceManager.add_resource("alloy", 1000)
	var up: Dictionary = bm.upgrade_engine()
	if not bool(up.get("ok", false)):
		_fails.append("引擎升级失败: " + str(up.get("reason", "")))
	elif int(bm.get_engine_level()) != 2:
		_fails.append("引擎等级未 +1")
	elif int(bm.get_fuel_cap()) != TruckTravel.TANK_BASE + TruckTravel.TANK_PER_LV:
		_fails.append("罐容未随引擎升级")
	print("[Travel] 引擎 Lv2 OK，罐容 %d" % int(bm.get_fuel_cap()))

	# ── F. 地图门控 UI：停靠摆回 2（存档前沿=1）
	#        关2=停靠关→关卡情报弹窗；关1=已解锁非停靠→行军规划弹窗；直呼出击被守卫拦 ──
	bm.set("_parked_level", 2)
	map.call("_on_level_selected", 2)
	await _wait(6)
	var pop: Window = map.get("_level_info_popup")
	if pop == null:
		_fails.append("停靠关点击无弹窗")
	elif str(pop.title) != "关卡情报":
		_fails.append("停靠关弹窗标题不符: " + str(pop.title))
	if pop != null:
		map.call("_close_popup_safe", pop)
	await _wait(4)
	map.call("_on_level_selected", 1)
	await _wait(6)
	var pop2: Window = map.get("_level_info_popup")
	if pop2 == null:
		_fails.append("非停靠点点击无弹窗")
	elif not str(pop2.title).contains("行军规划"):
		_fails.append("行军规划弹窗标题不符: " + str(pop2.title))
	if pop2 != null:
		var before_lv := int(GameManager.get("current_level"))
		map.call("_enter_level_from_popup", 1, pop2)
		await _wait(6)
		if int(GameManager.get("current_level")) != before_lv:
			_fails.append("非停靠点出击未被守卫拦截")
		else:
			print("[Travel] 门控守卫 OK")
	# 守卫内部已 deferred 关闭 pop2，此处不得重复 close（freed）
