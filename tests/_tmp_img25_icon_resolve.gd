# -*- coding: utf-8 -*-
extends SceneTree
## img25 重做清单专用：按情报面板同链（card_icon_path_for）解析 88 单位的真实卡图路径。
## 输出 .godot/unit_review/img25_icon_map.json {key: icon_res_path}

func _init() -> void:
	var loader := load("res://scripts/ui_asset_loader.gd")
	var dc := load("res://data/default_cards.gd")
	var wl_path := "res://.godot/unit_review/img25_worklist.json"
	var wl: Dictionary = {}
	var f := FileAccess.open(wl_path, FileAccess.READ)
	if f:
		wl = JSON.parse_string(f.get_as_text())
	var out := {}
	for key in wl.keys():
		var icon := ""
		var card = dc.get_card_by_id(key) if dc else null
		if card != null:
			icon = str(loader.card_icon_path_for(card))
		else:
			# 无卡的动画 key（如平台/敌形）：试 manifest 直查 archetype
			var manifest := load("res://data/enemy_unit_manifest.gd")
			if manifest:
				var p := str(manifest.get_unit_icon_path_for_archetype(key))
				icon = p
		out[key] = icon
	var wf := FileAccess.open("res://.godot/unit_review/img25_icon_map.json", FileAccess.WRITE)
	wf.store_string(JSON.stringify(out, "  "))
	wf.close()
	var miss := 0
	for k in out.keys():
		if str(out[k]).is_empty():
			miss += 1
			print("MISS ", k)
	print("RESOLVED %d, missing %d" % [out.size(), miss])
	quit()
