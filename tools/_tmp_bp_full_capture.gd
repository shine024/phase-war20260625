extends SceneTree
## 临时验证（用后即删）：背包"改造"Tab 全量瓷砖（中文短名 + 宽度回归）。

var _frames := 0
var _stage := 0

const BOOT_FRAMES := 300
const OPEN_FRAMES := 150
const TAB_FRAMES := 250
const GRANT_FRAMES := 250

func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	match _stage:
		0:
			if _frames >= BOOT_FRAMES:
				current_scene.call("_on_backpack_pressed")
				_stage = 1
				_frames = 0
		1:
			if _frames >= OPEN_FRAMES:
				var tc: Node = _find_tab_container()
				tc.current_tab = 1
				_stage = 2
				_frames = 0
		2:
			if _frames >= TAB_FRAMES:
				var bag: Node = root.get_node_or_null("/root/IntelItemBag")
				var reg: Node = root.get_node_or_null("/root/ModificationRegistry")
				var ids := {}
				var granted := 0
				for t in range(9):
					for mid in (reg.call("get_for_unit_type", t) as Array):
						var m: String = String(mid)
						if not ids.has(m):
							ids[m] = true
							bag.call("add_item", "blueprint_" + m, 1)
							granted += 1
				print("[BPF] 注入图纸 ", granted, " 个")
				_find_panel().call("refresh_intel_tab")
				_stage = 3
				_frames = 0
		3:
			if _frames >= GRANT_FRAMES:
				_dump()
				quit(0)
				return true
	return false

func _find_panel() -> Node:
	return current_scene.get_node_or_null("PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/BackpackPanel")

func _find_tab_container() -> Node:
	return _find_panel().get_node_or_null("VBoxOuter/TabContainer")

func _dump() -> void:
	var tc: TabContainer = _find_tab_container() as TabContainer
	var g: GridContainer = tc.get_child(1).find_children("IntelGrid", "GridContainer", true, false).pop_front() as GridContainer
	var sc: ScrollContainer = g.get_parent() as ScrollContainer
	# 效果行文本抽样（前 8 块瓷砖的 AmountLabel）
	var texts: Array = []
	for ch in g.get_children():
		if ch is Control and (ch as Control).has_meta("_tile_rarity"):
			var al: Label = (ch as Control).get_node_or_null("Margin/VBox/AmountLabel")
			if al and not al.text.is_empty():
				texts.append(al.text)
		if texts.size() >= 10:
			break
	print("[BPF] cols=%d tiles=%d grid=%.0f scroll=%.0f hbar=%s" % [g.columns, g.get_child_count(), g.size.x, sc.size.x, sc.get_h_scroll_bar().visible])
	print("[BPF] 瓷砖效果行抽样: ", texts)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("user://bp_full_verify.png")
	print("[BPF] screenshot -> ", ProjectSettings.globalize_path("user://bp_full_verify.png"))
	print("[BPF] ", "PASS" if not sc.get_h_scroll_bar().visible and g.get_combined_minimum_size().x <= sc.size.x + 0.5 else "FAIL")
