extends Node
## v6.35.2 探针：实机主诉"100 关退回移动基地→进大地图全黑"修复验证。
## 根因：v6.35 把 func _on_incursions_changed 插进 _ready 中段，
## 原构建链（call_deferred("_build_level_map")/返回键接线/浮层 chrome）成孤儿代码，
## _build_level_map 在任何路径都不可达 → 地图场景只有深色底，零报错。
## 三证：结构断言（画布/底图纹理/关卡按钮/黑门入口）+ 锚点 100 + 真实渲染截图
## （截图由 run.scene_headless 的 screenshots 参数落到 res://.godot/agent_tools/）。

func _ready() -> void:
	# 模拟用户实机态：停靠关 100（黑门解锁边缘）
	var mll := get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("bunker")
	await get_tree().process_frame
	var bm := get_node_or_null("/root/BunkerManager")
	print("[probe] bm_ready=", bm != null,
		" parked_before=", bm.get_parked_level() if bm != null else -1)
	if bm != null:
		bm._parked_level = 100
	print("[probe] parked_after=", bm.get_parked_level() if bm != null else -1)
	GameManager.set_current_level(100)

	var wm: Control = (load("res://scenes/world_map.tscn") as PackedScene).instantiate()
	add_child(wm)
	# _build_level_map 走 call_deferred，fit/居中再各吃一帧——给足 4 帧
	for i in range(4):
		await get_tree().process_frame

	var scroll := wm.get_node_or_null("Margin/VBox/ScrollContainer") as ScrollContainer
	var canvas: Control = scroll.get_node_or_null("MapCanvas") if scroll != null else null
	var bg: TextureRect = canvas.get_node_or_null("VoidBase") if canvas != null else null
	var buttons := 0
	if canvas != null:
		for c in canvas.get_children():
			if c is Button:
				buttons += 1
	var gate_entry: Button = canvas.get_node_or_null("BlackGateEntry") if canvas != null else null
	var back_btn: Button = wm.find_child("BackToTitleButton", true, false)

	print("[probe] _map_built=", wm.get("_map_built"))
	print("[probe] anchor_built=", wm.get("_built_window_anchor"))
	print("[probe] canvas=", canvas != null,
		" children=", canvas.get_child_count() if canvas != null else -1)
	print("[probe] bg_tex_set=", bg != null and bg.texture != null)
	print("[probe] canvas_buttons=", buttons, " gate_entry=", gate_entry != null,
		" back_btn_wired=", back_btn != null and back_btn.pressed.get_connections().size() > 0)
	var ok: bool = wm.get("_map_built") == true \
		and canvas != null and bg != null and bg.texture != null \
		and buttons > 0 and gate_entry != null \
		and int(wm.get("_built_window_anchor")) == 100
	print("[probe] VERDICT=", "PASS" if ok else "FAIL")
	# 真实渲染三证：等一帧绘制完成后抓视口存 PNG（目检用）
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.godot/agent_tools/worldmap_rebuild_probe.png")
	print("[probe] shot -> res://.godot/agent_tools/worldmap_rebuild_probe.png")
	print("[probe] DONE")
	get_tree().quit(0 if ok else 1)
