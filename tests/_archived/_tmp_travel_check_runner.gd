extends Node
## v26.19 卡车行军 E2E 执行体（直挂 /root 存活换场景）
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_travel_check_boot.tscn
## 流程：满罐起步 → 回程一关 start_travel（地图开着看动画/徽标）→ 在途拒绝再规划 →
##       实时到期结算（停靠点/current_level 同步断言）→ 低储备拒出车 → 引擎升级 →
##       自动回复/能量块充能 → 地图门控（停靠关=情报弹窗 / 非停靠=一点即发直接启程 /
##       非停靠出击被守卫拦）
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
		# 新档全流程：点未解锁关5=一点即发直接启程 → 到站 → 关卡情报（战前准备）→ 进入该关直接开打
		if SignalBus.has_signal("show_toast"):
			SignalBus.show_toast.connect(func(m: String) -> void: print("[Travel][toast] ", m))
		var map2: Node = get_tree().current_scene
		map2.call("_on_level_selected", 5)
		await _wait(6)
		if not bool(bm.is_traveling()) or int(bm.get_travel_dest()) != 5:
			_fails.append("点关5未直接启程（一点即发）: traveling=%s dest=%d" % [
				bool(bm.is_traveling()), int(bm.get_travel_dest())])
			get_tree().quit(1)
			return
		print("[Travel] 点未解锁关5 → 直接启程 OK（连线+光点即走）")
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
	# 诊断+硬断言：光点/路线节点必须在位（runner 双切场景=模板复用路径，曾整段漏建——
	# 表现为二次进图无连线无光点，v26.26 修复）
	var mk: Control = map.get("_truck_marker")
	var rt: Control = map.get("_travel_route")
	if mk == null or not is_instance_valid(mk):
		_fails.append("卡车光点缺失（模板复用路径漏建 TruckMarker）")
	if rt == null or not is_instance_valid(rt):
		_fails.append("行驶路线层缺失（模板复用路径漏建 TravelRoute）")
	# v26.27：光点中心必须钉在路线插值点上（不得保留停靠位避让偏移）
	if mk != null and is_instance_valid(mk) and bm.is_traveling():
		var from_p: Vector2 = map.call("_level_point", int(bm.get_parked_level()))
		var to_p: Vector2 = map.call("_level_point", int(bm.get_travel_dest()))
		var expect_c: Vector2 = from_p.lerp(to_p, float(bm.get_travel_progress()))
		var actual_c: Vector2 = mk.position + mk.size * 0.5
		if actual_c.distance_to(expect_c) > 2.0:
			_fails.append("光点中心偏离路线插值点: %s != %s（差 %.1fpx）" % [
				actual_c, expect_c, actual_c.distance_to(expect_c)])
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
	# v26.29 提速 5 倍（12 秒/天，本行程 1 天）——等待窗改 5 秒，须仍在途
	await get_tree().create_timer(5.0).timeout
	if not bool(bm.is_traveling()):
		_fails.append("5 秒后应仍在途（12 秒/天 × 1 天）")
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
	# v26.28：停靠位=节点中心（走到哪停到哪）——到站/再出发不得跳位
	var mk_arr: Control = map.get("_truck_marker")
	if mk_arr != null and is_instance_valid(mk_arr):
		var park_c: Vector2 = mk_arr.position + mk_arr.size * 0.5
		var node_c: Vector2 = map.call("_level_point", 1)
		if park_c.distance_to(node_c) > 2.0:
			_fails.append("停靠位不在节点中心（到站跳位回归）: %s != %s" % [park_c, node_c])
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

	# ── E2. v26.25 燃料自动回复（读侧累计/封顶）+ 能量块 1:1 充能 + 拒绝理由带指引 ──
	bm.set("_fuel", 10.0)
	bm.set("_fuel_regen_unix", Time.get_unix_time_from_system() - 600.0)  # 10 分钟前（Lv2=4/分钟）
	var regen_fuel: float = float(bm.get_fuel())
	if regen_fuel < 48.0 or regen_fuel > 52.0:
		_fails.append("自动回复数值不符: %.2f（期望 ~50 = 10 + 10min × 4/min）" % regen_fuel)
	bm.set("_fuel", 5.0)
	bm.set("_fuel_regen_unix", Time.get_unix_time_from_system() - 100000.0)  # 离线超长 → 封顶
	var capped_fuel: float = float(bm.get_fuel())
	if absf(capped_fuel - float(bm.get_fuel_cap())) > 0.5:
		_fails.append("离线长时回复未封顶罐容: %.1f/%d" % [capped_fuel, int(bm.get_fuel_cap())])
	var energy_before := 0
	if BasicResourceManager != null:
		energy_before = int(BasicResourceManager.get_total("energy_block"))
		BasicResourceManager.add_resource("energy_block", 500)
	bm.set("_fuel", 20.0)
	var fuel_cap_e2: int = int(bm.get_fuel_cap())
	var ch: Dictionary = bm.charge_fuel_to_full()
	if not bool(ch.get("ok", false)):
		_fails.append("充能失败: " + str(ch.get("reason", "")))
	elif absf(float(bm.get_fuel()) - float(fuel_cap_e2)) > 0.5:
		_fails.append("充能未补满: %.1f/%d" % [float(bm.get_fuel()), fuel_cap_e2])
	if BasicResourceManager != null:
		var energy_left := int(BasicResourceManager.get_total("energy_block"))
		if energy_left != energy_before + 500 - (fuel_cap_e2 - 20):
			_fails.append("能量块扣减不符 1:1: 剩 %d（期望 %d）" % [energy_left, energy_before + 500 - (fuel_cap_e2 - 20)])
	var ch2: Dictionary = bm.charge_fuel_to_full()
	if bool(ch2.get("ok", false)):
		_fails.append("已满仍充能成功（应拒绝）")
	bm.set("_fuel", 5.0)
	var rej: Dictionary = bm.plan_travel(60)
	if bool(rej.get("ok", false)) or not str(rej.get("reason", "")).contains("充能"):
		_fails.append("燃料拒绝理由未带充能指引: " + str(rej.get("reason", "")))
	print("[Travel] E2 自动回复/充能 OK（回复 ~%.0f、封顶 %.0f、补满 %d）" % [regen_fuel, capped_fuel, int(ch.get("charged", 0))])

	# ── F. 地图门控 UI（v26.26 一点即发）：停靠摆回 2（存档前沿=1）
	#        关2=停靠关→关卡情报弹窗；关1=非停靠→点即直接启程；非停靠出击守卫仍拦 ──
	bm.set("_fuel", float(bm.get_fuel_cap()))  # E2 后燃料≈5，补满保证点关1能出发
	bm.set("_fuel_regen_unix", Time.get_unix_time_from_system())
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
	if not bool(bm.is_traveling()) or int(bm.get_travel_dest()) != 1:
		_fails.append("点非停靠关1未直接启程: traveling=%s dest=%d" % [
			bool(bm.is_traveling()), int(bm.get_travel_dest())])
	else:
		print("[Travel] 一点即发 OK：点关1 → 在途 → 关1")
	if bool(bm.is_traveling()):
		bm.set("_travel_ends_unix", Time.get_unix_time_from_system() - 1.0)
		bm.call("_check_travel_arrival")
	await _wait(4)
	# 到站停靠1后：借停靠关情报弹窗直呼"进入第2关"必须被守卫拦（防旁路）
	map.call("_on_level_selected", 1)
	await _wait(6)
	var pop2: Window = map.get("_level_info_popup")
	if pop2 != null:
		var before_lv := int(GameManager.get("current_level"))
		map.call("_enter_level_from_popup", 2, pop2)
		await _wait(6)
		if int(GameManager.get("current_level")) == 2:
			_fails.append("非停靠点出击未被守卫拦截")
		else:
			print("[Travel] 门控守卫 OK")
		map.call("_close_popup_safe", pop2)
