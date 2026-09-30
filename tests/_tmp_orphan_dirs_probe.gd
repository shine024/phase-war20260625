extends SceneTree
## 孤儿动画目录判定探针（真孤儿 = 解析链五步全 miss，见 AGENTS.md「动画部署 key 纪律」）
## 正向：枚举运行期可能出现的一切 anim_id（玩家卡 id ∪ 敌方 archetype id ∪ 平台/特殊卡 id），
##      逐个走 UnitFrameAnim._resolve_key，收集全部可达目录。
## 反向：unit_anims 下具备 sheet_idle+anim.json 的目录 − 可达集 = 真孤儿。
## 仅含 attack_f0.png 的目录属 AttackPoseAnim 攻击姿态系统，不在候选内。

func _collect_platform_ids(o: Variant, ids: Dictionary) -> void:
	if o is Dictionary:
		for k in o.keys():
			if k in ["id", "platform_id", "archetype_id"] and o[k] is String:
				ids[o[k]] = true
			else:
				_collect_platform_ids(o[k], ids)
	elif o is Array:
		for x in o:
			_collect_platform_ids(x, ids)

func _initialize() -> void:
	var ufa := load("res://scripts/battle/unit_frame_anim.gd")
	var uct := load("res://data/unified_card_table.gd")
	var ecm := load("res://data/enemy_card_mod_map.gd")
	var eum := load("res://data/enemy_unit_manifest.gd")

	# 1. 候选 anim_id 全集（⚠️ 必须含 manifest get_entries 条目——星冥 xeno_* 等
	#    archetype 直连 vis_xeno_* 目录，漏掉会把 19 套已接线动画误判成孤儿）
	var ids := {}
	for row in eum.call("get_entries"):
		var rid := String(row.get("archetype_id", ""))
		if not rid.is_empty():
			ids[rid] = true
	for cid in uct.get_all_card_ids():
		ids[String(cid)] = true
	for aid in ecm.get_all_archetype_ids():
		ids[String(aid)] = true
	for key in ["FOE_PLATFORM_CARD_IDS", "FOE_SPECIAL_CARD_IDS", "CAPTURED_ENEMY_IDS", "FORT_ENEMY_IDS", "FIXED_ENEMY_IDS", "POOL_ENEMY_IDS"]:
		if eum.get(key) is Array:
			for x in eum.get(key):
				ids[String(x)] = true
				ids["captured_" + String(x)] = true
	# 相位师战争平台直以平台 id 出生（enemy_phase_platforms.json），不在 UCT/ECM
	var ptxt := FileAccess.get_file_as_string("res://data/json/enemy_phase_platforms.json")
	var pj = JSON.parse_string(ptxt)
	if pj != null:
		_collect_platform_ids(pj, ids)

	# 2. 正向解析 → 可达目录集
	var reachable := {}
	for id in ids.keys():
		var k := String(ufa.call("_resolve_key", id))
		if not k.is_empty():
			reachable[k] = true

	# 3. 反向：全部 sheet 型目录
	var dirs := []
	var d := DirAccess.open("res://assets/effects/unit_anims")
	if d != null:
		d.list_dir_begin()
		var n := d.get_next()
		while not n.is_empty():
			if d.current_is_dir() and not n.begins_with("."):
				if FileAccess.file_exists("res://assets/effects/unit_anims/" + n + "/sheet_idle.png") \
						and FileAccess.file_exists("res://assets/effects/unit_anims/" + n + "/anim.json"):
					dirs.append(n)
			n = d.get_next()

	var orphans := []
	for k in dirs:
		if not reachable.has(k):
			orphans.append(k)

	print("== orphan dirs probe ==")
	print("sheet 型目录总数: ", dirs.size())
	print("可达目录数: ", reachable.size())
	print("真孤儿数: ", orphans.size())
	for k in orphans:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/unit_anims/" + k + "/anim.json"))
		var cnt: Dictionary = (parsed.get("counts", {}) if parsed is Dictionary else {})
		print("  ORPHAN: ", k, " counts=", cnt)
	print("ORPHAN_PROBE_DONE")
	quit(0)
