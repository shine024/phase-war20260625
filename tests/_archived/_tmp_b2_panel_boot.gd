extends Node
## 批次② Task 3 面板外壳层检查 boot（复刻 _tmp_help_tutorial_check_boot 两层结构）
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_b2_panel_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "B2PanelCheckRunner"
	r.set_script(load("res://tests/_tmp_b2_panel_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
