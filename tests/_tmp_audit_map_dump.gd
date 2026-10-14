extends SceneTree
## 2026-10-13 生图资源全面体检：导出 战场id→动画key→兵种/时代/中文名 映射表
## 供 Python 侧全量像素审计分类用（humanoid/platform 阈值分流）。
## 输出：res://.godot/audit_map.json

const UCT = preload("res://data/unified_card_table.gd")
const DC = preload("res://data/default_cards.gd")
const XENO = preload("res://data/xeno_units.gd")
const ARCH = preload("res://data/enemy_archetypes.gd")
const FACTION = preload("res://data/faction_exclusive_cards.gd")
const MANIFEST = preload("res://data/enemy_unit_manifest.gd")
const UFA = preload("res://scripts/battle/unit_frame_anim.gd")

const NON_BATTLE_PREFIXES: Array[String] = ["platform_", "drop_", "cps_", "special_"]


func _initialize() -> void:
	var rows: Array = []
	var ids := {}
	for cid in UCT.get_all_card_ids():
		var s := str(cid)
		for p in NON_BATTLE_PREFIXES:
			if s.begins_with(p):
				continue
		ids[s] = true
	for xid in XENO.get_ids():
		ids[str(xid)] = true
	for row in FACTION.EXCLUSIVE_CARDS:
		var fid := String(row.get("id", ""))
		if not fid.is_empty():
			ids[fid] = true
	for aid in ARCH.get_all_ids():
		ids[str(aid)] = true
	for cap in MANIFEST.CAPTURED_ENEMY_IDS:
		ids[MANIFEST.captured_card_id_for(str(cap))] = true

	var arch_set := {}
	for aid in ARCH.get_all_ids():
		arch_set[str(aid)] = true

	for cid: String in ids.keys():
		var key := UFA._resolve_key(cid)
		var kind := "unknown"
		var era := "unknown"
		var name_cn := cid
		var cfg := {}
		var card = DC.get_card_by_id(cid)
		if card != null:
			cfg = {
				"kind": card.get("combat_kind"), "era": card.get("era"), "name": card.get("display_name"),
			}
		elif XENO.is_xeno(cid):
			cfg = XENO.get_config(cid)
		elif arch_set.has(cid):
			cfg = ARCH.get_config(cid)
		var kind_names := ["light", "armor", "support", "air"]
		var kv = cfg.get("kind")
		if kv == null:
			kv = cfg.get("combat_kind")
		if kv != null and str(kv).is_valid_int():
			var ki := int(str(kv))
			kind = kind_names[ki] if ki >= 0 and ki < kind_names.size() else str(ki)
		elif kv != null:
			kind = String(kv)
		if cfg.get("era") != null:
			era = str(cfg.get("era"))
		if cfg.get("name") != null and not String(cfg.get("name")).is_empty():
			name_cn = String(cfg.get("name"))
		elif cfg.get("display_name") != null:
			name_cn = String(cfg.get("display_name"))
		elif cfg.get("short_name") != null:
			name_cn = String(cfg.get("short_name"))
		rows.append({
			"id": cid, "key": key, "side": "E" if arch_set.has(cid) else "P",
			"kind": kind, "era": era, "name": name_cn,
		})

	var f := FileAccess.open("res://.godot/audit_map.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"rows": rows}, "  "))
		f.close()
		print("[map dump] rows=%d -> res://.godot/audit_map.json" % rows.size())
	else:
		push_error("[map dump] 写文件失败")
	quit(0)
