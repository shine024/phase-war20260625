extends SceneTree
func _init() -> void:
	var s = load("res://scenes/ui/card_info_panel.gd")
	if s == null:
		print("❌ 编译失败")
		quit(1)
	else:
		print("✅ card_info_panel.gd 编译通过")
		quit(0)
