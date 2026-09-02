extends Node
func _ready() -> void:
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	mgr.reset_to_defaults()
	var inst: Control = (load("res://scenes/bunker/bunker_main.tscn") as PackedScene).instantiate()
	add_child(inst)
	await get_tree().create_timer(0.3).timeout
	var root: Node = inst
	print("[probe] root children order:")
	var idx := 0
	for c in root.get_children():
		var rect := ""
		if c is Control:
			rect = "pos=%s size=%s vis=%s" % [c.position, c.size, c.visible]
		elif c is Node2D:
			rect = "z=%s" % c.z_index
		print("[probe]   %02d %-22s %s %s" % [idx, c.name, c.get_class(), rect])
		idx += 1
	var bg := root.get_node_or_null("BG")
	if bg:
		print("[probe] BG tex=", bg.get("texture") if bg.get("texture") != null else "NULL",
			" pos=", bg.position, " size=", bg.size, " visible=", bg.visible)
	get_tree().quit(0)
