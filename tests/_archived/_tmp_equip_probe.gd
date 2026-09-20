extends Node
func _ready() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("load_game"):
		sm.call("load_game")
		if sm.has_method("flush_deferred_manager_loads"):
			sm.call("flush_deferred_manager_loads")
	var reg: Node = get_node_or_null("/root/InstanceRegistry")
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if reg == null or pim == null:
		printerr("[Equip] manager missing"); get_tree().quit(1); return
	var ids: Array = reg.get_all_instance_ids()
	print("[Equip] instances=", ids.size())
	var picked: Array = []
	for id in ids:
		var base := String(id).split("#")[0]
		if base in ["ww1_mauser", "ww1_arty_m81", "ww1_arm_ft17", "ww2_rifle_98k", "ww2_arm_sherman"]:
			picked.append(id)
		if picked.size() >= 3:
			break
	print("[Equip] picked=", picked)
	var equipped := 0
	for i in picked.size():
		var card = reg.call("get_instance", picked[i])
		if card != null:
			pim.call("equip_card", i, card)
			equipped += 1
	print("[Equip] equipped=", equipped)
	if sm and sm.has_method("save_game"):
		sm.call("save_game")
	get_tree().quit(0)
