extends Node
## v6.41 探针：大地图信息框重叠复现（用户截图：左下动作面板+图例 与 底部燃料/行驶状态行）。
## 复刻用户实机状态：停靠第 13 关（已通关→「再战本关」文案）· 行驶中 →第 23 关 · 燃料 90/100。
## 真实渲染 world_map 独立场景，全屏截图 + 信息框矩形转储（互叠判定）。
## 跑法：GODOT --path . res://tests/_tmp_v642_wm_overlap_probe.tscn --rendering-driver opengl3

const WM_SCENE := "res://scenes/world_map.tscn"

func _ready() -> void:
	print("[WMPROBE] probe start")
	await get_tree().process_frame
	var bm := get_node_or_null("/root/BunkerManager")
	if bm == null:
		# 懒加载 manager：确保落树（ensure_loaded 后等一帧，见 memory godot-script-hang-debug）
		var mll := get_node_or_null("/root/ManagerLazyLoader")
		if mll != null and mll.has_method("ensure_loaded"):
			mll.ensure_loaded("bunker")
			await get_tree().process_frame
		bm = get_node_or_null("/root/BunkerManager")
	print("[WMPROBE] BunkerManager=%s" % str(bm))
	if bm != null:
		bm.set("_parked_level", 13)
		# 行驶中→23：直接置内部态（start_travel 会扣燃料/做门禁，探针走只读语义的直写）
		bm.set("_travel_dest", 23)
		bm.set("_travel_ends_unix", Time.get_unix_time_from_system() + 3600.0 * 12.0)
		bm.set("_fuel", 90.0)

	var wm := (load(WM_SCENE) as PackedScene).instantiate()
	wm.name = "ProbeWorldMap"
	get_tree().root.add_child(wm)
	await get_tree().process_frame
	get_tree().current_scene = wm
	# 建图是 call_deferred：等建完+布局稳
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw

	print("[WMPROBE] parked=%s travel_dest=%s fuel=%s" % [
		str(bm.get_parked_level()) if bm != null else "?",
		str(bm.get_travel_dest()) if bm != null else "?",
		str(bm.get_fuel()) if bm != null else "?"])

	# 信息框矩形转储 + 两两相交判定（屏幕空间 chrome 与底部行）
	var targets := ["MapChromeStack", "MapActions", "MapLegend", "TravelBadge"]
	for nm in targets:
		var n := wm.find_child(nm, true, false)
		if n is Control:
			print("[WMPROBE] %s global_rect=%s visible=%s" % [nm, n.get_global_rect(), n.visible])
		else:
			print("[WMPROBE] %s NOT FOUND" % nm)
	# 燃料 chip（v6.41.1 后应在 chrome 栈尾）
	var chip_node: Control = wm.get("_fuel_chip") if "_fuel_chip" in wm else null
	if chip_node != null:
		print("[WMPROBE] fuel chip parent=%s global_rect=%s visible=%s text=%s" % [
			chip_node.get_parent().name, chip_node.get_global_rect(), chip_node.visible,
			chip_node.text])
	else:
		print("[WMPROBE] fuel chip node NULL")

	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.godot/v642_wm_overlap.png")
	img.save_png(path)
	print("[WMPROBE] shot -> %s" % path)
	print("[WMPROBE] done")
	get_tree().quit()
