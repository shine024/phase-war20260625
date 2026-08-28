extends Node
## 探针：嵌入面板包装层几何诊断（纪念墙/英雄档案）

func _ready() -> void:
	ManagerLazyLoader.ensure_loaded("bunker")
	var mgr: Node = ManagerLazyLoader.get_manager("bunker")
	mgr.reset_to_defaults()
	for mid in ["enemy_master_001", "enemy_master_002"]:
		mgr.record_hero_fragment(mid)
	var inst: Control = load("res://scenes/bunker/bunker_main.tscn").instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var stage: Control = inst.get("_ui_stage")
	print("[probe] stage=", stage.get_global_rect() if stage else "null")
	for pid in ["memorial", "hero_archive"]:
		inst._open_embedded_panel(pid)
		await get_tree().create_timer(0.4).timeout
		var w: Control = (inst.get("_embed_wrappers") as Dictionary).get(pid, {}).get("wrapper")
		if w == null:
			print("[probe] ", pid, " wrapper=null"); continue
		print("[probe] ", pid, " wrapper=", w.get_global_rect())
		for c in w.get_children():
			print("[probe]   ", c.name, "(", c.get_class(), ")=", c.get_global_rect())
			if c is CenterContainer and c.get_child_count() > 0:
				var p: Control = c.get_child(0)
				print("[probe]     panel=", p.get_global_rect(), " min=", p.custom_minimum_size)
		# 关掉继续下一个
		if w.get_child_count() > 2 and (w.get_child(2) as CenterContainer).get_child_count() > 0:
			var pc: Control = (w.get_child(2) as CenterContainer).get_child(0)
			if pc.has_signal("closed"):
				pc.emit_signal("closed")
	get_tree().quit(0)
