extends Node
## 批次③ Task 2 结算叙事冒烟——boot 场景（runner 直挂 /root）
## 跑法：godot --headless --path . res://tests/_tmp_b3_t2_narrative_boot.tscn

func _ready() -> void:
	var r := Node.new()
	r.name = "T2NarrativeRunner"
	r.set_script(load("res://tests/_tmp_b3_t2_narrative_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
