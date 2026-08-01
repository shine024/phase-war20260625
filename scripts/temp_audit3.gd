extends SceneTree

func _init():
	var UL = load("res://scripts/ui_asset_loader.gd")
	var EA = load("res://data/enemy_archetypes.gd")
	var CardRes = load("res://resources/card_resource.gd")
	# vis_enemy_NNN -> [display_name, tags]
	var all = EA.get_all_ids()
	var vis_to_info: Dictionary = {}
	for a in all:
		var s: String = String(a)
		var cfg: Dictionary = EA.get_config(s)
		if cfg.is_empty():
			continue
		var icon: String = EA.resolve_card_icon_texture_path(s, cfg, s)
		if icon.is_empty():
			continue
		var fn: String = icon.get_file().get_basename()
		var dn: String = String(cfg.get("display_name", ""))
		var tags: Array = cfg.get("tags", [])
		if not vis_to_info.has(fn):
			vis_to_info[fn] = [dn, tags]
	# 读卡元数据
	var card_meta: Dictionary = {}
	var f = FileAccess.open("res://card_meta.tmp", FileAccess.READ)
	if f != null:
		while not f.eof_reached():
			var line: String = f.get_line()
			if line.is_empty():
				continue
			var parts: PackedStringArray = line.split("\t")
			if parts.size() >= 4:
				card_meta[String(parts[0])] = [String(parts[1]), int(parts[2]), int(parts[3])]
		f.close()
	var CK := {0: "步兵", 1: "装甲", 2: "支援", 3: "空中", 4: "堡垒"}
	var problems: Array = []
	var checked: int = 0
	var no_tag: int = 0
	var cids = card_meta.keys()
	cids.sort()
	for cid in cids:
		var meta: Array = card_meta[cid]
		var my_dn: String = String(meta[0])
		var era_v: int = int(meta[1])
		var my_ck: int = int(meta[2])
		var card = CardRes.new()
		card.card_id = String(cid)
		card.card_type = 0  # COMBAT_UNIT
		card.combat_kind = my_ck
		card.era = era_v
		checked += 1
		var path: String = UL.card_icon_path_for(card)
		var img_fn: String = "NOIMG"
		if not path.is_empty():
			img_fn = path.get_file().get_basename()
		var lookup_fn: String = img_fn
		if lookup_fn.begins_with("vis_player_"):
			lookup_fn = lookup_fn.replace("vis_player_", "vis_enemy_")
		var info: Array = vis_to_info.get(lookup_fn, ["?", []])
		var img_dn: String = String(info[0])
		var tags: Array = info[1]
		if tags.is_empty():
			no_tag += 1
			continue
		var img_kind: String = "?"
		if tags.has("infantry") or tags.has("antitank"):
			img_kind = "步兵"
		elif tags.has("tank") or tags.has("armored") or tags.has("vehicle"):
			img_kind = "装甲"
		elif tags.has("aircraft"):
			img_kind = "空中"
		elif tags.has("turret") or tags.has("sustained"):
			img_kind = "固定支援"
		elif tags.has("artillery"):
			img_kind = "火炮"
		elif tags.has("fortress") or tags.has("immobile"):
			img_kind = "堡垒"
		elif tags.has("boss") or tags.has("ultimate"):
			img_kind = "boss"
		var ok: bool = false
		if my_ck == 0 and img_kind == "步兵":
			ok = true
		elif my_ck == 1 and img_kind == "装甲":
			ok = true
		elif my_ck == 2 and (img_kind == "固定支援" or img_kind == "火炮"):
			ok = true
		elif my_ck == 3 and img_kind == "空中":
			ok = true
		elif my_ck == 4 and img_kind == "堡垒":
			ok = true
		if not ok and img_kind != "?":
			problems.append(cid + "|" + my_dn + "(" + String(CK.get(my_ck, "?")) + ")|" + img_dn + "(" + img_kind + "," + img_fn + ")")
	var fout = FileAccess.open("user://audit3.txt", FileAccess.WRITE)
	fout.store_line("已检查 " + str(checked) + " 无tag跳过 " + str(no_tag) + " 疑点 " + str(problems.size()))
	for p in problems:
		fout.store_line(p)
	fout.close()
	quit()
