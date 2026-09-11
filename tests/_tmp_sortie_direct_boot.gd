extends Node
## v26.30 出击直达战斗 E2E 引导（boot 场景模式，runner 直挂 /root）
## 跑法：godot --rendering-driver opengl3 --path . res://tests/_tmp_sortie_direct_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "SortieDirectRunner"
	r.set_script(load("res://tests/_tmp_sortie_direct_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
