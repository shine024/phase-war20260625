extends Node

func _ready():
	# Try to load the unit_hp_bar.tscn
	var scene = load("res://scenes/units/unit_hp_bar.tscn")
	if scene != null:
		print("unit_hp_bar.tscn loaded successfully!")
	else:
		print("ERROR: Failed to load unit_hp_bar.tscn")
	
	# Try to load unit_hp_bar.gd
	var script = load("res://scenes/units/unit_hp_bar.gd")
	if script != null:
		print("unit_hp_bar.gd loaded successfully!")
	else:
		print("ERROR: Failed to load unit_hp_bar.gd")