extends Node
func _ready() -> void:
	var r := Node.new()
	r.name = "T5FtueRunner"
	r.set_script(load("res://tests/_tmp_b3_t5_ftue_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
