extends RefCounted

func _ready():
	var dc = preload("res://data/default_cards.gd")
	print("Loaded:", dc)
