extends Node
## v32.5b 固定基地删除批复检探针：验证重构后的 mobile_base_facilities 在运行时全链可用——
## ① 通用助手（res_full_id/cost_text）② 房间等级驱动数值（睡眠恢复/每日配给）
## ③ 卡车基地燃料卡实机打开（含引擎升级按钮文本）④ 引擎升级链（BunkerManager+TruckTravel）

func _ready() -> void:
	_run()

func _run() -> void:
	await get_tree().process_frame
	var Defs := load("res://data/mobile_base_facilities.gd")
	# ① 通用助手
	var full: String = Defs.res_full_id("energy")
	var txt: String = Defs.cost_text({"nano": 10, "alloy": 5})
	print("[V325B] res_full_id(energy)=", full, " | cost_text=", txt)
	var ok1 := full == "energy_block" and txt.contains("10")
	# ② 房间等级驱动数值（BunkerManager _init_rooms 读新表 initial）
	ManagerLazyLoader.ensure_loaded("bunker")
	var bm: Node = get_node_or_null("/root/BunkerManager")
	var rec: float = bm.get_sleep_recovery()
	var ration: Dictionary = bm.get_daily_ration()
	print("[V325B] sleep_recovery=", rec, " | ration_entries=", ration.size())
	var ok2 := rec >= 20.0 and not ration.is_empty()
	# ③ 卡车基地燃料卡实机打开
	var inst: Control = load("res://scenes/bunker/truck_base.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	inst.call("_open_fuel_station_card")
	await get_tree().create_timer(0.3).timeout
	var btn_texts: Array[String] = []
	_collect_buttons(inst, btn_texts)
	var has_engine := false
	var has_energy_ui := false
	for t in btn_texts:
		if t.contains("升级引擎") or t.contains("引擎已满级"):
			has_engine = true
		if t.contains("充能补满"):
			has_energy_ui = true
	print("[V325B] 燃料卡按钮：引擎升级=", has_engine, " 能量块充能=", has_energy_ui,
		" | 采样=", btn_texts.slice(0, 3))
	var ok3 := has_engine and has_energy_ui
	# ④ 引擎升级链（资源不足路径也会走 MobileBaseFacilities.cost_text 拼原因文本）
	var res: Dictionary = bm.upgrade_engine()
	print("[V325B] upgrade_engine -> ok=", res.get("ok"), " reason=", res.get("reason", ""))
	var ok4 := res.has("ok")
	print("[V325B] RESULT = ", "PASS" if (ok1 and ok2 and ok3 and ok4) else "FAIL")
	await get_tree().process_frame
	get_tree().quit(0 if (ok1 and ok2 and ok3 and ok4) else 1)

func _collect_buttons(node: Node, out: Array[String]) -> void:
	if node is Button:
		var t := String((node as Button).text)
		if not t.is_empty():
			out.append(t)
	for c in node.get_children():
		_collect_buttons(c, out)
