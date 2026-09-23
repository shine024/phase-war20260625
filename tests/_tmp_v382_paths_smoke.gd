extends SceneTree
## v38.2 抽屉 reparent 路径兜底冒烟（--script 模式，无 autoload 依赖）
## 背景：BottomFunctionBar 自 v38.2 起 _ready 末尾被 reparent 到 HudLayer 直下，
## 三处按路径查找的调用点（相位仪栏菜单按钮 / _get_top_controls / battle_manager
## set_start_battle_text）旧路径全部落空。本冒烟复现 reparent 后的层级，断言新路径
## 命中、旧路径确实已死（兜底不是摆设）。

func _initialize() -> void:
	var fails: Array[String] = []

	var hud := CanvasLayer.new()
	hud.name = "HudLayer"
	root.add_child(hud)

	var bbb := VBoxContainer.new()
	bbb.name = "BattleBottomBar"
	hud.add_child(bbb)

	var ib: Control = load("res://scenes/ui/bottom_instrument_bar.gd").new()
	ib.name = "BottomInstrumentBar"
	bbb.add_child(ib)

	var fb: PanelContainer = load("res://scenes/ui/bottom_function_bar.gd").new()
	fb.name = "BottomFunctionBar"
	bbb.add_child(fb)
	# --script 模式 _ready 不派发，手工补 _become_right_side_column 依赖的 Margin/HBox
	var margin := MarginContainer.new()
	margin.name = "Margin"
	fb.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	margin.add_child(hbox)

	var top := Control.new()
	top.name = "TopHudBar"
	hud.add_child(top)

	# 复现 v38.2 reparent（_ready 里是 call_deferred，这里直调）
	fb._become_right_side_column()

	if fb.get_parent() != hud:
		fails.append("reparent 后 BottomFunctionBar 应直挂 HudLayer")
	if ib.get_node_or_null("../../BottomFunctionBar") != fb:
		fails.append("菜单按钮新路径 ../../BottomFunctionBar 解析失败")
	if ib.get_node_or_null("../BottomFunctionBar") != null:
		fails.append("旧兄弟路径 ../BottomFunctionBar 应为 null（兜底前提不成立）")
	if fb._get_top_controls() != top:
		fails.append("_get_top_controls 未解析到 HudLayer/TopHudBar")
	if root.get_node_or_null("HudLayer/BottomFunctionBar") != fb:
		fails.append("battle_manager 绝对路径 HudLayer/BottomFunctionBar 解析失败")

	if fails.is_empty():
		print("V382_PATHS_OK")
	else:
		for f in fails:
			printerr("FAIL: " + f)
	quit(0 if fails.is_empty() else 1)
