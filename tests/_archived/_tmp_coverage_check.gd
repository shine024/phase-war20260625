extends SceneTree
## v6.14.3 权威覆盖率：注册表全量 vs 配装表引用集
func _init() -> void:
	var reg = load("res://scripts/systems/modification_registry.gd")
	var lo = load("res://data/enemy_fixed_loadouts.gd")
	var all_ids: Array = []
	for ut in range(5):
		for mid in reg.get_for_unit_type(ut):
			if not all_ids.has(String(mid)):
				all_ids.append(String(mid))
	var referenced: Dictionary = {}
	for aid in lo.LOADOUTS:
		for m in (lo.LOADOUTS[aid]["mods"] as Array):
			referenced[String(m)] = true
	var uncovered: Array = []
	for mid in all_ids:
		if not referenced.has(String(mid)):
			uncovered.append(String(mid))
	print("[cov] 注册表去重全量=%d 被配装引用=%d 未覆盖=%d" % [all_ids.size(), referenced.size(), uncovered.size()])
	print("[cov] 未覆盖清单: ", ", ".join(uncovered))
	quit(0)
