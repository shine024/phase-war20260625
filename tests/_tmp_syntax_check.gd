extends SceneTree
## 临时语法校验：编译修改过的脚本
const BM = preload("res://managers/battle/battle_manager.gd")
const CIP = preload("res://scenes/ui/card_info_panel.gd")

func _init():
	print("OK battle_manager=", BM != null)
	print("OK card_info_panel=", CIP != null)
	quit()
