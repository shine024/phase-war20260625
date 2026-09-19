extends SceneTree
## 临时加载冒烟：ground_loot_layer / vfx_impact_factory 本轮修改可编译（口径同 _tmp_v37_smoke）

func _initialize() -> void:
	var errs: Array[String] = []
	for p: String in [
		"res://scripts/battle/ground_loot_layer.gd",
		"res://scripts/battle/vfx_impact_factory.gd",
	]:
		var s: GDScript = load(p)
		if s == null:
			errs.append("load fail: " + p)
	# loot：改后的三个函数签名/常量仍在
	var gll: GDScript = load("res://scripts/battle/ground_loot_layer.gd")
	if gll == null or not gll.can_instantiate():
		errs.append("ground_loot_layer compile fail")
	var vfx: GDScript = load("res://scripts/battle/vfx_impact_factory.gd")
	if vfx == null:
		errs.append("vfx compile fail")
	if errs.is_empty():
		print("LOADCHECK_OK")
	else:
		for e in errs:
			printerr("LOADCHECK_ERR: " + e)
	quit(0 if errs.is_empty() else 1)
