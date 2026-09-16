extends SceneTree
func _init() -> void:
	var uct = load("res://data/unified_card_table.gd")
	var entries: Array = uct.get_player_card_entries()
	var all_p: Array[int] = []
	var by_era: Dictionary = {}
	for e in entries:
		var p: int = int(e.get("power", 0))
		if p <= 0:
			continue
		all_p.append(p)
		var era: int = int(e.get("era", -1))
		if not by_era.has(era):
			by_era[era] = []
		by_era[era].append(p)
	all_p.sort()
	all_p.sort()
	print("[audit] player entries with power>0: ", all_p.size())
	if all_p.size() > 0:
		print("[audit] min=%d p10=%d p25=%d p50=%d p75=%d p90=%d max=%d" % [
			all_p[0], all_p[int(0.10*(all_p.size()-1))], all_p[int(0.25*(all_p.size()-1))],
			all_p[int(0.50*(all_p.size()-1))], all_p[int(0.75*(all_p.size()-1))],
			all_p[int(0.90*(all_p.size()-1))], all_p[all_p.size()-1]])
	for era in by_era:
		var arr: Array = by_era[era]
		arr.sort()
		print("[audit] era=%d n=%d min=%d p50=%d max=%d" % [era, arr.size(), arr[0], arr[arr.size()/2], arr[arr.size()-1]])
	quit()
