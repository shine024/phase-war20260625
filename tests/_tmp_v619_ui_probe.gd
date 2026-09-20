extends Node
## 临时视觉探针：v6.19 概率可见化三处新 UI 截图（SubViewport 1280×720 免 DPI 缩放）。
## 运行：godot --path . res://tests/_tmp_v619_ui_probe.tscn
## 输出：.godot/agent_tools/v619_*.png（验证完可删）
## 覆盖：①制造面板卡牌详情保底行 ②随机箱详情保底行 ③情报舱相位师分区 ④黑门规则弹窗

const EVOLUTION := preload("res://scenes/ui/evolution_panel.tscn")
const INTEL_HUB := preload("res://scenes/ui/intelligence_hub_panel.tscn")
const WORLD_MAP := preload("res://scenes/world_map.tscn")

var _vp: SubViewport = null


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05)
	bg.size = Vector2(1280, 720)
	_vp.add_child(bg)
	_run()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# ① 制造面板（默认卡牌模式）：选第一张可制造卡 → 详情 info_details 保底行
	#（探针环境无存档情报，命中的将是免情报门的直入卡——同样走 pity 行渲染路径）
	var evo: Node = EVOLUTION.instantiate()
	_vp.add_child(evo)
	for i in 6:
		await get_tree().process_frame
	var picked := ""
	var mgr: Node = evo._mgr()
	if mgr != null and mgr.has_method("get_recipe_ids"):
		for id in mgr.get_recipe_ids():
			if mgr.is_manufacturable(String(id)):
				picked = String(id)
				break
	print("PROBE picked card: ", picked)
	evo._on_recipe_selected(picked if not picked.is_empty() else "ww1_mp18")
	for i in 6:
		await get_tree().process_frame
	print("PROBE state: selected=", evo.get("selected_recipe_id"),
		" craft_mode=", evo.get("_craft_mode"),
		" target_name=", evo.get("target_name_label").text if evo.get("target_name_label") else "N/A",
		" no_sel_visible=", evo.get("no_selection_label").visible if evo.get("no_selection_label") else "N/A")
	var _id_label = evo.get("info_details")
	print("PROBE info_details=", _id_label.text.replace("\n", " | ") if _id_label else "N/A")
	var _dc = evo.get("detail_content")
	if _dc:
		for ch in _dc.get_children():
			print("PROBE vis: ", ch.name, " visible=", ch.visible, " in_tree=", ch.is_visible_in_tree(),
				" gpos=", ch.global_position, " gsize=", ch.size)
	await _shot("v619_evo_card_pity.png")

	# ② 切改造模式 → 默认选中随机补给箱（MOD_BOX_SEL 哨兵）→ 详情保底行
	evo._set_craft_mode(evo.MODE_MOD)
	await get_tree().process_frame
	evo._on_mod_selected(evo.MOD_BOX_SEL)
	for i in 6:
		await get_tree().process_frame
	await _shot("v619_evo_box_pity.png")
	evo.queue_free()
	await get_tree().process_frame

	# ③ 情报舱：敌方情报 Tab（index 2）→ 相位师情报分区 + 动态状态行
	var hub: Node = INTEL_HUB.instantiate()
	_vp.add_child(hub)
	for i in 8:
		await get_tree().process_frame
	hub._tab_container.current_tab = 2
	for i in 8:
		await get_tree().process_frame
	await _shot("v619_intel_phase_master.png")
	hub.queue_free()
	await get_tree().process_frame

	# ④ 黑门弹窗：AcceptDialog 是内嵌 Window 不进 SubViewport 画布——程序化验证文案内容
	#（AcceptDialog 外壳为引擎标准样式，无自定义布局风险；规则行数值读常量为 T1.2 验收点）
	var wm: Node = WORLD_MAP.instantiate()
	_vp.add_child(wm)
	var mll := get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("endless")
	for i in 6:
		await get_tree().process_frame
	wm._show_blackgate_popup()
	for i in 6:
		await get_tree().process_frame
	var popup: Window = wm.get("_level_info_popup")
	if popup != null:
		_walk_labels(popup, "BGATE")
	else:
		print("BGATE popup=null（未创建）")
	await _shot("v619_blackgate_map.png")

	print("V619_UI_PROBE_DONE")
	get_tree().quit()


func _walk_labels(n: Node, tag: String) -> void:
	if n is Label or n is Button:
		var t: String = n.text if "text" in n else ""
		if not t.is_empty():
			print(tag, " [", n.get_class(), "] ", t.replace("\n", " | "))
	for ch in n.get_children():
		_walk_labels(ch, tag)


func _shot(fname: String) -> void:
	for i in 4:
		await get_tree().process_frame
	var img := _vp.get_texture().get_image()
	img.save_png("res://.godot/agent_tools/" + fname)
	print("SAVED ", fname, " ", img.get_width(), "x", img.get_height())
