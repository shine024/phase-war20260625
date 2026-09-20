extends Node
## 内嵌地图探针引导

func _ready() -> void:
	var r := Node.new()
	r.name = "EmbedProbeRunner"
	r.set_script(load("res://tests/_tmp_embed_map_probe_runner.gd"))
	get_tree().root.add_child.call_deferred(r)
