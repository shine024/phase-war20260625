extends Node
## v6.14 探针：truck_base 嵌入面板几何验收（同伴档案/纪念墙越界修复回归）
## 期望：.gd 面板根被包装层给满 1280×720 min-size 后，面板本体居中且完整在视口内。

func _ready() -> void:
	ManagerLazyLoader.ensure_loaded("bunker")
	var inst: Control = load("res://scenes/bunker/truck_base.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var all_ok := true
	print("[probe] viewport=", get_viewport().get_visible_rect(), " inst_size=", inst.size,
		" embed_layer=", (inst.get("_embed_layer") as Control).get_global_rect())
	for pid in ["hero_archive", "memorial"]:
		inst._open_panel(pid)
		await get_tree().create_timer(0.5).timeout
		var wraps: Dictionary = inst.get("_embed_wrappers")
		var w: Control = wraps.get(pid, {}).get("wrapper")
		var p: Control = wraps.get(pid, {}).get("panel")
		if w == null or p == null:
			print("[probe] ", pid, " wrapper/panel=null")
			all_ok = false
			continue
		var r := p.get_global_rect()
		# 按实际视口包含判定（窗口高度随 settings/分辨率变化，勿硬编码 720）
		var ok := get_viewport().get_visible_rect().encloses(r)
		all_ok = all_ok and ok
		print("[probe] ", pid, " rect=", r, " min=", p.custom_minimum_size,
			" IN_VIEWPORT=", ok)
		if p.has_signal("closed"):
			p.emit_signal("closed")
		await get_tree().create_timer(0.3).timeout
	print("[probe] ALL_", "PASS" if all_ok else "FAIL")
	get_tree().quit(0 if all_ok else 1)
