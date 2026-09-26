extends SceneTree
const Reg = preload("res://scripts/systems/modification_registry.gd")
func _init() -> void:
	var all: Array = Reg.get_all_ids()
	var counts := {}
	var mythic: Array[String] = []
	for k in all:
		var d: Dictionary = Reg.get_data(String(k))
		var r := String(d.get("rarity","?"))
		counts[r] = int(counts.get(r, 0)) + 1
		if r.to_lower() == "mythic":
			mythic.append(String(k) + " | " + String(d.get("name","?")))
	print("COUNTS=", counts)
	for m in mythic:
		print("MYTHIC ", m)
	quit(0)
