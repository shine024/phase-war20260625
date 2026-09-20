extends SceneTree
## v6.20 批冒烟（--script 模式，纪律同 v37/v38：_initialize + 零 await）。
## 覆盖：①改动文件全部可编译加载；②苏醒演出三拍教学已删（源码零残留）；
## ③教程步骤数据带聚光键；④truck_base/底栏新公共查询存在；
## ⑤内嵌面板关闭通知接线存在；⑥tutorial_overlay 聚光与 _advance 接线存在。

const MODIFIED := [
	"res://scenes/bunker/truck_base.gd",
	"res://managers/tutorial_progression_manager.gd",
	"res://scenes/ui/tutorial_overlay.gd",
	"res://scenes/ui/bottom_function_bar.gd",
	"res://scripts/ui/tutorial_spotlight.gd",
]

func _initialize() -> void:
	var fails: Array[String] = []

	# 1) 全部改动文件可编译加载
	for p in MODIFIED:
		if load(p) == null:
			fails.append("加载失败: " + p)

	# 2) 苏醒演出三拍教学已删：源码零残留（图/纸条/教学函数）
	var tb_src := FileAccess.get_file_as_string("res://scenes/bunker/truck_base.gd")
	for token in ["_wakeup_teach_beat", "wakeup_wrist.png", "wakeup_backpack.png", "TeachNote"]:
		if tb_src.contains(token):
			fails.append("truck_base 残留三拍教学 token: " + token)
	if not tb_src.contains("装备自检两拍"):
		fails.append("truck_base 缺自检两拍节拍文案")

	# 3) 教程步骤数据带聚光键（第 2/3 步）——tutorial_data 在 _ready 填充，裸实例化手动初始化
	var tpm = load("res://managers/tutorial_progression_manager.gd").new()
	tpm._initialize_tutorial_data()
	var d2: Dictionary = tpm.tutorial_data.get(2, {})
	var d3: Dictionary = tpm.tutorial_data.get(3, {})
	if String(d2.get("spotlight_key", "")) != "backpack":
		fails.append("CARD_COLLECTION 缺 spotlight_key=backpack")
	if not bool(d2.get("spotlight_press_advances", false)):
		fails.append("CARD_COLLECTION 缺 spotlight_press_advances")
	if String(d3.get("spotlight_key", "")) != "backpack":
		fails.append("PHASE_INSTRUMENT 缺 spotlight_key=backpack")
	if String(d2.get("spotlight_tip", "")) == "":
		fails.append("CARD_COLLECTION 缺 spotlight_tip")
	tpm.free()

	# 4) 公共查询存在（脚本方法表，免实例化场景）
	var TBS := load("res://scenes/bunker/truck_base.gd")
	var tb_methods := {}
	for m in TBS.get_script_method_list():
		tb_methods[String(m["name"])] = true
	if not tb_methods.has("get_hotspot_button_for_key"):
		fails.append("truck_base 缺 get_hotspot_button_for_key")
	if not tb_methods.has("_notify_surface_closed"):
		fails.append("truck_base 缺 _notify_surface_closed")
	var BFB := load("res://scenes/ui/bottom_function_bar.gd")
	var bfb_methods := {}
	for m in BFB.get_script_method_list():
		bfb_methods[String(m["name"])] = true
	if not bfb_methods.has("get_button_for_key"):
		fails.append("bottom_function_bar 缺 get_button_for_key")

	# 5) 内嵌面板关闭两路都通知（closed 信号挂点 + ESC 路径）
	if not tb_src.contains("_notify_surface_closed(panel_id))"):
		fails.append("closed 信号挂点缺关闭通知")
	if not tb_src.contains("_notify_surface_closed(top_key)"):
		fails.append("ESC 关闭路径缺关闭通知")

	# 6) tutorial_overlay 接线：聚光三方法 + _advance
	var ov_src := FileAccess.get_file_as_string("res://scenes/ui/tutorial_overlay.gd")
	for token in ["_update_spotlight", "_dismiss_spotlight", "_resolve_spotlight_target",
			"_on_spot_target_pressed", "func _advance(skip_action: bool)"]:
		if not ov_src.contains(token):
			fails.append("tutorial_overlay 缺接线 token: " + token)

	if fails.is_empty():
		print("V620_SMOKE_OK")
	else:
		for f in fails:
			printerr("[FAIL] " + f)
		print("V620_SMOKE_FAIL x%d" % fails.size())
	quit(0 if fails.is_empty() else 1)
