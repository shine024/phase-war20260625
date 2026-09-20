# v26.21 bunker_manager 行军重构残留引用修复 smoke
# 症状：v26.21 实时行军重构删了 _travel_days_left 整型成员（改 unix 时间戳 + getter），
#       但 plan_travel/start_travel 两处返回表达式漏改 → 全文件 Parse Error，
#       bunker_manager（SaveManager deferred 段）加载失败。
# 验证：1) 脚本可编译加载；2) 在途 plan_travel 拒绝文案带剩余天数（195 行修复点）；
#       3) start_travel 成功且返回 days == _travel_days_total（224 行修复点）。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_bunker_travel_parse_check.gd
extends SceneTree

const TruckTravel = preload("res://data/truck_travel.gd")


func _initialize() -> void:
	var fails: Array[String] = []
	var scr: GDScript = load("res://managers/bunker_manager.gd")
	if scr == null or not scr.can_instantiate():
		fails.append("bunker_manager.gd 编译失败（Parse Error 复现）")
	else:
		var bm: Node = scr.new()
		# 195 行分支：在途状态 → plan_travel 拒绝且文案由 getter 换算剩余天数
		bm._travel_dest = 3
		bm._travel_days_total = 4
		bm._travel_started_unix = Time.get_unix_time_from_system() - 10.0
		bm._travel_ends_unix = bm._travel_started_unix + 4.0 * TruckTravel.SECONDS_PER_DAY
		var p: Dictionary = bm.plan_travel(7)
		if bool(p.get("ok", true)):
			fails.append("在途时 plan_travel 应拒绝: %s" % str(p))
		elif String(p.get("reason", "")).find("剩") < 0:
			fails.append("在途拒绝文案缺少剩余天数: %s" % str(p.get("reason", "")))
		# 224 行分支：启程成功 → 返回 days 与 _travel_days_total 一致
		bm._travel_dest = 0
		bm._travel_ends_unix = 0.0
		bm._parked_level = 2
		var st: Dictionary = bm.start_travel(1)
		if not bool(st.get("ok", false)):
			fails.append("start_travel 应成功: %s" % str(st))
		elif int(st.get("days", 0)) != int(bm._travel_days_total):
			fails.append("start_travel 返回 days(%s) 与 _travel_days_total(%d) 不一致"
				% [str(st.get("days")), int(bm._travel_days_total)])
		elif not bm.is_traveling():
			fails.append("start_travel 后应处于在途状态")
		bm.free()
	for f in fails:
		printerr("[TravelParseCheck] FAIL: " + f)
	print("[TravelParseCheck] " + ("ALL PASS" if fails.is_empty() else "HAS FAILURES"))
	quit(0 if fails.is_empty() else 1)
