extends SceneTree
## 面板打开回归冒烟（v9.x 商店打不开事故后设立）
## 验证 _prune_preloaded_panels 启动释放的四个面板（quest/store/faction/settings）
## 能通过 UILazyLoader 按需重建且有内容。用法：
##   Godot --headless --rendering-driver opengl3 --path . --script tests/panel_open_smoke.gd
## 退出码 0=通过，1=失败。

var _phase := 0
var _frame := 0
var _waited := 0

const PANEL_CHECKS: Array = [
	["_on_store_pressed", "StoreOverlay", "StorePanel"],
	["_on_quest_pressed", "QuestOverlay", "QuestPanel"],
	["_on_faction_pressed", "FactionOverlay", "FactionPanel"],
	["_on_settings_pressed", "SettingsOverlay", "SettingsPanel"],
	["_on_help_pressed", "HelpOverlay", "HelpPanel"],
]

func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		0:
			change_scene_to_file("res://scenes/main.tscn")
			_phase = 1
			_frame = 0
		1:
			_waited += 1
			var main: Node = root.get_node_or_null("/root/Main")
			var gm: Node = root.get_node_or_null("/root/GameManager")
			if main != null and gm != null and gm.get("battle_scene") != null:
				for entry in PANEL_CHECKS:
					if main.has_method(String(entry[0])):
						main.call(String(entry[0]))
				_phase = 2
				_frame = 0
			elif _waited > 1200:
				printerr("[panel-smoke] FAIL: 主场景 1200 帧未就绪")
				quit(1)
				return true
		2:
			if _frame >= 30:
				return _assert_panels()
	return false

func _assert_panels() -> bool:
	var main: Node = root.get_node_or_null("/root/Main")
	var ok_all := true
	for entry in PANEL_CHECKS:
		var key: String = String(entry[1])
		var pn: String = String(entry[2])
		var panel: Node = main.get_node_or_null("PopupLayer/%s/CenterContainer/%s" % [key, pn])
		var ok: bool = panel != null
		if ok and not panel.visible:
			ok = false  # 面板存在但未显示（help 事故形态：show_panel 未被分发叫醒）
		if ok:
			var items: Node = panel.get_node_or_null("ScrollContainer/ItemList")
			if items != null and items.get_child_count() == 0:
				ok = false  # 有列表却为空视为未填充
		print("[panel-smoke] %s: %s" % [pn, "OK" if ok else "FAIL"])
		if not ok:
			ok_all = false
	if ok_all:
		print("[panel-smoke] OK: 四面板懒加载重建+内容填充通过")
		quit(0)
	else:
		printerr("[panel-smoke] FAIL: 存在空面板")
		quit(1)
	return true
