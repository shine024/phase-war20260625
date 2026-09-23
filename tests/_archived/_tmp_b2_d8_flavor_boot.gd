extends Node
## 批次② Task 8 boot：卡面文案落地后的 DefaultCards/CardFlavorTexts 域冒烟
## 跑法：godot --headless --path . res://tests/_tmp_b2_d8_flavor_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "B2D8FlavorRunner"
	r.set_script(load("res://tests/_tmp_b2_d8_flavor_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
