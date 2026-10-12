extends SceneTree
## v6.57 记录3#7：敌我双方待机/进攻动画布置全量审计 v4（--script 直跑）
## v4 关键修正：不再自拟映射——直接调用运行时同款 UnitFrameAnim._resolve_key
## （四级回退：id 直查→foe_ 剥前缀→EnemyCardModMap→visual_id→ANIM_ALIAS 别名表），
## 对解析结果分类。解析失败（""）=战场纯静态回退=真实布置缺口。
## 输出：控制台摘要 + .godot/v657_anim_audit.txt 明细。

const UCT = preload("res://data/unified_card_table.gd")
const XENO = preload("res://data/xeno_units.gd")
const ARCH = preload("res://data/enemy_archetypes.gd")
const FACTION = preload("res://data/faction_exclusive_cards.gd")
const MANIFEST = preload("res://data/enemy_unit_manifest.gd")
const UFA = preload("res://scripts/battle/unit_frame_anim.gd")
const ANIM_ROOT := "res://assets/effects/unit_anims/"
const NON_BATTLE_PREFIXES: Array[String] = ["platform_", "drop_", "cps_", "special_"]


func _is_battlefield_id(cid: String) -> bool:
	for p in NON_BATTLE_PREFIXES:
		if cid.begins_with(p):
			return false
	return true


func _classify_dir(dir: String) -> String:
	if not DirAccess.dir_exists_absolute(dir):
		return "missing_dir"
	var has_si := FileAccess.file_exists(dir + "sheet_idle.png")
	var has_sa := FileAccess.file_exists(dir + "sheet_attack.png")
	var has_la := FileAccess.file_exists(dir + "attack_f0.png")
	var has_li := FileAccess.file_exists(dir + "idle_f0.png")
	if has_si and has_sa:
		return "sheet"
	if has_li and has_la:
		return "legacy_both"
	if has_li:
		return "legacy_idle_only"
	if has_la:
		return "legacy_attack_only"
	if has_si or has_sa:
		return "sheet_partial"
	return "empty_dir"


func _initialize() -> void:
	var ids := {}
	for cid in UCT.get_all_card_ids():
		if _is_battlefield_id(str(cid)):
			ids[str(cid)] = true
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

	var counts := {"sheet": 0, "legacy_both": 0, "legacy_idle_only": 0, "legacy_attack_only": 0, "sheet_partial": 0, "empty_dir": 0, "no_key": 0}
	var lists := {"legacy_both": [], "legacy_idle_only": [], "legacy_attack_only": [], "sheet_partial": [], "empty_dir": [], "no_key": [], "stale_json": []}
	for cid: String in ids.keys():
		var side := "E" if arch_set.has(cid) else "P"
		var key: String = UFA._resolve_key(cid)
		if key.is_empty():
			counts["no_key"] = int(counts["no_key"]) + 1
			lists["no_key"].append(side + " " + cid)
			continue
		var form := _classify_dir(ANIM_ROOT + key + "/")
		counts[form] = int(counts[form]) + 1
		if form != "sheet":
			lists[form].append("%s %s → %s" % [side, cid, key])
		var jf := FileAccess.open(ANIM_ROOT + key + "/anim.json", FileAccess.READ)
		if jf != null:
			var j = JSON.parse_string(jf.get_as_text())
			if j is Dictionary and (not (j as Dictionary).has("subject") or not (j as Dictionary).has("foot_frac")):
				lists["stale_json"].append("%s %s → %s" % [side, cid, key])

	var total := ids.size()
	print("=== v6.57 动画布置审计 v4（运行时 _resolve_key 同链）===")
	print("战场 id 总数: %d" % total)
	print("  sheet 全动画（idle+attack）: %d" % counts["sheet"])
	print("  旧单帧回退: both=%d idle_only=%d attack_only=%d" % [counts["legacy_both"], counts["legacy_idle_only"], counts["legacy_attack_only"]])
	print("  sheet 半残缺: %d  空目录: %d" % [counts["sheet_partial"], counts["empty_dir"]])
	print("  ★无任何动画解析（战场纯静态）: %d" % counts["no_key"])
	print("  anim.json 过期（缺 subject/foot_frac）: %d" % lists["stale_json"].size())

	var lines: Array[String] = []
	lines.append("=== v6.57 动画布置审计 v4 %s ===" % Time.get_datetime_string_from_system())
	lines.append("战场 id 总数: %d｜sheet: %d｜旧单帧 both/idle/attack: %d/%d/%d｜半残缺: %d｜空目录: %d｜无解析: %d｜json过期: %d" % [
		total, counts["sheet"], counts["legacy_both"], counts["legacy_idle_only"],
		counts["legacy_attack_only"], counts["sheet_partial"], counts["empty_dir"],
		counts["no_key"], lists["stale_json"].size()])
	for label in [["★无动画解析（战场纯静态）", lists["no_key"]],
			["sheet 半残缺", lists["sheet_partial"]], ["空目录", lists["empty_dir"]],
			["旧单帧-仅idle", lists["legacy_idle_only"]], ["旧单帧-仅attack", lists["legacy_attack_only"]],
			["旧单帧-双全", lists["legacy_both"]], ["anim.json 过期", lists["stale_json"]]]:
		var arr: Array = label[1]
		if arr.is_empty():
			continue
		lines.append("")
		lines.append("── %s (%d) ──" % [label[0], arr.size()])
		for x in arr:
			lines.append("  " + str(x))

	var of := FileAccess.open("res://.godot/v657_anim_audit.txt", FileAccess.WRITE)
	if of != null:
		of.store_string("\n".join(lines))
		of.close()
		print("明细 → res://.godot/v657_anim_audit.txt")
	quit(0)
