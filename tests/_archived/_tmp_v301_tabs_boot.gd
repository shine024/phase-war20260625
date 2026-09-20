extends Node
## v30.1 R3 结算三页签冒烟——boot 场景（runner 直挂 /root，autoload 全量可用）
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_v301_tabs_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "T31TabsRunner"
	r.set_script(load("res://tests/_tmp_v301_tabs_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
