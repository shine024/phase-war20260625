extends SceneTree
## 临时 dump v4：单位 id → (玩家卡图权威路径, 敌版卡图路径, 动画键) 全量映射。
## 玩家卡图直接调 UiAssetLoader.card_icon_path_for(真 CardResource)——覆盖专属图/
## manifest 平台链/PLAYER_ICON_OVERRIDE/era_kind 回退全链；敌版优先 vis_player→vis_enemy
## 换算，缺则 manifest for_player=false / drop 反查。目录名不进 id 集（防孤儿判定污染）。
## 跑法：godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_dump_icon_map.gd

func _initialize() -> void:
	var m := load("res://data/enemy_unit_manifest.gd")
	var uf := load("res://scripts/battle/unit_frame_anim.gd")
	var uct := load("res://data/unified_card_table.gd")
	var dc := load("res://data/default_cards.gd")
	var ual := load("res://scripts/ui_asset_loader.gd")
	var ea := load("res://data/enemy_archetypes.gd")
	var mi: Object = m.new()
	var ids := {}
	for row in mi.call("get_entries"):
		var id := String(row.get("archetype_id", ""))
		if not id.is_empty():
			ids[id] = true
	for cid in uct.call("get_all_card_ids"):
		ids[String(cid)] = true
	# 相位师战争平台直以平台 id 出生（enemy_phase_platforms.json），不在 manifest/UCT
	# ——漏掉会把 ww1_storm/ww1_av7/vis_xeno_adept 等别名合法落点误判成孤儿（2026-09-28）
	_collect_ids(JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/json/enemy_phase_platforms.json")), ids)
	var out := {}
	for id in ids.keys():
		var p := ""
		var card: CardResource = dc.call("get_card_by_id", id)
		if card != null:
			p = String(ual.call("card_icon_path_for", card))
		var e := ""
		if p.contains("vis_player_"):
			var cand: String = p.replace("vis_player_", "vis_enemy_")
			if FileAccess.file_exists(cand.replace("res://", "")):
				e = cand
		if e.is_empty():
			e = String(mi.call("get_unit_icon_path_for_archetype", id, false))
		if e.is_empty():
			var arch := String(ea.call("get_visual_archetype_id_for_card", id))
			if not arch.is_empty():
				e = String(mi.call("get_unit_icon_path_for_archetype", arch, false))
		var k := String(uf.call("_resolve_key", id))
		out[id] = {"anim": k, "e": e, "p": p}
	DirAccess.make_dir_recursive_absolute("res://.godot/unit_review")
	var f := FileAccess.open("res://.godot/unit_review/gd_icon_map.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	var with_anim := 0
	var with_e := 0
	var with_p := 0
	for id in out:
		if String(out[id]["anim"]) != "":
			with_anim += 1
		if String(out[id]["e"]) != "":
			with_e += 1
		if String(out[id]["p"]) != "":
			with_p += 1
	print("DUMP_DONE ids=%d with_anim=%d with_enemy_icon=%d with_player_icon=%d" % [out.size(), with_anim, with_e, with_p])
	quit(0)

func _collect_ids(o: Variant, ids: Dictionary) -> void:
	if o is Dictionary:
		for k in o.keys():
			if k in ["id", "platform_id", "archetype_id"] and o[k] is String:
				ids[o[k]] = true
			else:
				_collect_ids(o[k], ids)
	elif o is Array:
		for x in o:
			_collect_ids(x, ids)
