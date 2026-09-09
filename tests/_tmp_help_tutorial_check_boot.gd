extends Node
## v26.33 引导/帮助重整检查 boot：runner 直挂 /root（复刻 _tmp_travel_check_boot 两层结构）
## 跑法：godot --headless --rendering-driver opengl3 --path . res://tests/_tmp_help_tutorial_check_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "HelpTutorialCheckRunner"
	r.set_script(load("res://tests/_tmp_help_tutorial_check_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
