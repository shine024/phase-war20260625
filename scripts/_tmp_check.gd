extends SceneTree
func _init():
	var f = FileAccess.open("user://fsz.txt", FileAccess.WRITE)
	var a = load("res://scenes/units/unit_hp_bar.gd")
	f.store_line("gd " + ("OK" if a != null else "FAIL"))
	var b = load("res://scenes/units/unit_hp_bar.tscn")
	f.store_line("tscn " + ("OK" if b != null else "FAIL"))
	f.close()
	quit()
