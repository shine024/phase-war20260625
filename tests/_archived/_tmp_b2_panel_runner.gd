extends Node
## 批次② Task 3 面板外壳层 runner（LANGUAGE_BIBLE 第三章 21 行映射的显示层断言）
## 断言：
##   A) 10 个 PanelChrome 面板实例化后 chrome 标题 = 定案新名（quest/store/faction/
##      achievement/help/collection/intelligence/leaderboard/afk）+ hero_archive 标题 Label
##   B) 4 个 tscn 标题面板（backpack/modification/evolution/growth）标题 Label = 新名
##   C) bottom_function_bar BTN_CONFIGS / SHORTCUT_TOOLTIPS 联动（背包→卡仓、成长→整备、
##      afk 按钮保留「挂机」而 tooltip 随面板名「自动哨戒」）
##   D) truck_base PANEL_LABELS 兜底 + HOTSPOTS hint 收敛（无「背包·卡仓」「制造中心」「情报中心」「商店·势力」残留）
## 只读显示层；panel_id/信号名/节点名零触碰。

var _fails: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame  # 等 deferred 挂载完成、autoload 稳定
	await _check_chrome_panels()
	await _check_tscn_title_panels()
	_check_function_bar()
	_check_truck_base()
	for f in _fails:
		printerr("[B2Panel] FAIL: " + f)
	print("[B2Panel] " + ("ALL PASS" if _fails.is_empty() else "HAS FAILURES"))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _fail(msg: String) -> void:
	_fails.append(msg)


# ─── A) PanelChrome 面板标题 ───
func _check_chrome_panels() -> void:
	# [场景路径, 期望标题]
	var cases: Array = [
		["res://scenes/ui/quest_panel.tscn", "委托台"],
		["res://scenes/ui/store_panel.tscn", "补给舱"],
		["res://scenes/ui/faction_panel.tscn", "联络台"],
		["res://scenes/ui/achievement_panel.tscn", "战功簿"],
		["res://scenes/ui/help_panel.tscn", "车长手册"],
		["res://scenes/ui/collection_panel.tscn", "生灵图鉴"],
		["res://scenes/ui/intelligence_hub_panel.tscn", "情报舱"],
		["res://scenes/ui/leaderboard_panel.tscn", "战功榜"],
		["res://scenes/ui/afk_panel.tscn", "自动哨戒"],
	]
	for c in cases:
		print("[B2Panel] chrome case: %s" % c[0])
		var packed: PackedScene = load(c[0])
		if packed == null:
			_fail("场景加载失败: %s" % c[0])
			continue
		var panel: Control = packed.instantiate()
		add_child(panel)
		await get_tree().process_frame
		var title := _find_chrome_title(panel)
		print("[B2Panel] chrome case done: %s -> %s" % [c[0], title])
		if title.is_empty():
			_fail("%s 未找到 PanelChrome 标题" % c[0])
		elif title != c[1]:
			_fail("%s 标题应为「%s」，实际「%s」" % [c[0], c[1], title])
		panel.queue_free()
		await get_tree().process_frame

	# hero_archive：纯代码面板（EMBEDDED_PANELS 直挂 .gd），标题为自建 Label
	var ha_script: GDScript = load("res://scenes/bunker/ui/hero_archive_panel.gd")
	if ha_script == null:
		_fail("hero_archive_panel.gd 加载失败")
		return
	var ha: Control = ha_script.new()
	add_child(ha)
	await get_tree().process_frame
	var found := false
	for lbl in ha.find_children("*", "Label", true, false):
		if (lbl as Label).text == "同伴档案":
			found = true
			break
	if not found:
		_fail("hero_archive 面板应含标题「同伴档案」")
	ha.queue_free()
	await get_tree().process_frame


func _find_chrome_title(root: Node) -> String:
	for chrome in root.find_children("*", "PanelChrome", true, false):
		var pc := chrome as PanelChrome
		if pc.title_label != null:
			return pc.title_label.text
	return ""


# ─── B) tscn 标题面板 ───
func _check_tscn_title_panels() -> void:
	# [场景路径, Label 节点路径, 期望文本]
	var cases: Array = [
		["res://scenes/ui/backpack_panel.tscn", "VBoxOuter/TitleRow/TitleLabel", "卡仓 · COMBAT ROSTER"],
		["res://scenes/ui/modification_panel.tscn", "VBoxContainer/TitleRow/TitleHBox/TitleLabel", "改造舱"],
		["res://scenes/ui/evolution_panel.tscn", "VBoxContainer/TitleRow/TitleHBox/TitleLabel", "制造舱"],
		["res://scenes/ui/growth_panel.tscn", "RootVBox/TitleBar/TitleHBox/TitleText", "整备舱"],
	]
	for c in cases:
		print("[B2Panel] tscn case: %s" % c[0])
		var packed: PackedScene = load(c[0])
		if packed == null:
			_fail("场景加载失败: %s" % c[0])
			continue
		var panel: Control = packed.instantiate()
		add_child(panel)
		await get_tree().process_frame
		var lbl := panel.get_node_or_null(c[1]) as Label
		print("[B2Panel] tscn case done: %s -> %s" % [c[0], lbl.text if lbl else "<null>"])
		if lbl == null:
			_fail("%s 无标题节点 %s" % [c[0], c[1]])
		elif lbl.text != c[2]:
			_fail("%s 标题应为「%s」，实际「%s」" % [c[0], c[2], lbl.text])
		panel.queue_free()
		await get_tree().process_frame


# ─── C) 底部功能栏按钮联动 ───
func _check_function_bar() -> void:
	var bf: GDScript = load("res://scenes/ui/bottom_function_bar.gd")
	if bf == null:
		_fail("bottom_function_bar.gd 加载失败")
		return
	var by_key := {}
	for row in bf.BTN_CONFIGS:
		by_key[row[0]] = row[1]
	if String(by_key.get("backpack", "")) != "卡仓":
		_fail("背包按钮应为「卡仓」，实际「%s」" % str(by_key.get("backpack")))
	if String(by_key.get("progression", "")) != "整备":
		_fail("成长按钮应为「整备」，实际「%s」" % str(by_key.get("progression")))
	if String(by_key.get("afk", "")) != "挂机":
		_fail("afk 按钮应保留「挂机」，实际「%s」" % str(by_key.get("afk")))
	var tips: Dictionary = bf.SHORTCUT_TOOLTIPS
	if not String(tips.get("backpack", "")).begins_with("卡仓："):
		_fail("backpack tooltip 应以「卡仓：」开头，实际「%s」" % str(tips.get("backpack")))
	if not String(tips.get("progression", "")).begins_with("整备舱："):
		_fail("progression tooltip 应以「整备舱：」开头，实际「%s」" % str(tips.get("progression")))
	if not String(tips.get("afk", "")).begins_with("自动哨戒："):
		_fail("afk tooltip 应以「自动哨戒：」开头，实际「%s」" % str(tips.get("afk")))


# ─── D) 移动基地兜底文案与热区 hint ───
func _check_truck_base() -> void:
	var tb: GDScript = load("res://scenes/bunker/truck_base.gd")
	if tb == null:
		_fail("truck_base.gd 加载失败")
		return
	var expect_labels := {
		"store": "补给舱", "modification": "改造舱", "evolution": "制造舱",
		"backpack": "卡仓", "intelligence": "情报舱",
	}
	var labels: Dictionary = tb.PANEL_LABELS
	for key in expect_labels:
		var got := String(labels.get(key, ""))
		if not got.begins_with(String(expect_labels[key])):
			_fail("PANEL_LABELS[%s] 应以「%s」开头，实际「%s」" % [key, expect_labels[key], got])
	var banned_hints := ["背包·卡仓", "制造中心", "情报中心", "商店·势力"]
	var expect_hints := ["卡仓", "制造舱·卡仓", "情报舱", "补给舱·联络台"]
	for era in tb.HOTSPOTS.keys():
		for h in tb.HOTSPOTS[era]:
			var hint := String(h.get("hint", ""))
			for b in banned_hints:
				if hint.contains(b):
					_fail("HOTSPOTS[%s]「%s」hint 残留旧名「%s」" % [era, String(h.get("name", "")), b])
			if hint in expect_hints or hint in ["卡仓"]:
				pass  # 新名命中即合法
	var era5: Array = tb.HOTSPOTS.get("era5", [])
	var has_new := false
	for h in era5:
		if String(h.get("hint", "")) == "卡仓":
			has_new = true
	if not has_new:
		_fail("era5 热区应存在收敛后 hint「卡仓」")
