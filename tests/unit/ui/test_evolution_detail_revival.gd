class_name EvolutionDetailRevivalTest
extends GdUnitTestSuite
## v6.19.4 回归锁：制造舱右栏死区复活（用户实机反馈"预览不到要制造的战斗卡"）。
## 契约：
## - 无选择态：右栏五分节 + 卡面预览全隐藏（tscn 默认隐藏=初态），NoSelectionLabel 可见
## - 选中配方：五分节全亮 + 卡面预览有贴图 + 卡名非空（制造前看得到要造的卡）
## - 改造图纸模式：亮名/情报/条件/消耗四块；图纸无卡面/无单位属性，预览与统计九格保持隐藏
## 显隐唯一口 = evolution_panel._set_detail_sections_visible；右栏新增分节必须进其列表。

const EvoPanelScene := preload("res://scenes/ui/evolution_panel.tscn")

const ALL_SECTIONS: Array[String] = [
	"TargetNamePanel", "InfoPanel", "RequirementsPanel",
	"StatsPanel", "ResourcePanel", "PreviewPanel",
]


func _make_panel() -> Node:
	var panel: Node = EvoPanelScene.instantiate()
	add_child(panel)
	return panel


func _section(panel: Node, uname: String) -> Control:
	return panel.get_node("%" + uname) as Control


func test_no_selection_hides_all_sections() -> void:
	var panel := _make_panel()
	for uname in ALL_SECTIONS:
		assert_bool(_section(panel, uname).visible).is_false()
	assert_bool(panel.get_node("%NoSelectionLabel").visible).is_true()
	panel.queue_free()


func test_recipe_selection_shows_sections_and_preview() -> void:
	var panel := _make_panel()
	var mgr: Node = panel._mgr()
	if mgr == null:
		print("  ManufactureManager 不可达，跳过")
		return
	await get_tree().process_frame  # 懒加载 manager 落树等一帧
	var recipes: Array = mgr.get_recipe_ids()
	if recipes.is_empty():
		print("  配方目录为空，跳过")
		return
	var rid := ""
	for r in recipes:
		if mgr.is_manufacturable(String(r)):
			rid = String(r)
			break
	if rid.is_empty():
		rid = String(recipes[0])
	panel._on_recipe_selected(rid)
	for uname in ALL_SECTIONS:
		assert_bool(_section(panel, uname).visible).is_true()
	assert_str(String(panel.target_name_label.text)).is_not_empty()
	assert_object(panel.preview_texture.texture).is_not_null()
	panel.queue_free()


func test_mod_mode_hides_preview_and_stats() -> void:
	var panel := _make_panel()
	if panel._mgr() == null:
		print("  ManufactureManager 不可达，跳过")
		return
	await get_tree().process_frame
	panel._set_craft_mode(panel.MODE_MOD)  # 内部自动选中随机补给箱并刷右栏
	assert_str(String(panel._craft_mode)).is_equal(panel.MODE_MOD)
	for uname in ["TargetNamePanel", "InfoPanel", "RequirementsPanel", "ResourcePanel"]:
		assert_bool(_section(panel, uname).visible).is_true()
	assert_bool(_section(panel, "PreviewPanel").visible).is_false()
	assert_bool(_section(panel, "StatsPanel").visible).is_false()
	panel.queue_free()
