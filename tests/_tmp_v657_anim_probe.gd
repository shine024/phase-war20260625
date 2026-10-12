extends SceneTree
const ARCH = preload("res://data/enemy_archetypes.gd")
const XENO = preload("res://data/xeno_units.gd")
func _initialize() -> void:
	print("arch_of xeno_swarmling = ", ARCH.get_visual_archetype_id_for_card("xeno_swarmling"))
	print("arch_of ww1_inf_rifle = ", ARCH.get_visual_archetype_id_for_card("ww1_inf_rifle"))
	var ids := ARCH.get_all_ids()
	var has_vis := 0
	var has_foe := 0
	var has_short := 0
	for i in ids:
		var s := str(i)
		if s.begins_with("vis_xeno"): has_vis += 1
		elif s.begins_with("foe_"): has_foe += 1
		elif not s.contains("_e") and not s.begins_with("boss"): has_short += 1
	print("ARCH ids total=%d vis_xeno=%d foe=%d" % [ids.size(), has_vis, has_foe])
	print("xeno ids sample: ", str(XENO.get_ids().slice(0, 3)))
	quit(0)
