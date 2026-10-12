extends GdUnitTestSuite
## v6.57 记录3#7：战场单位动画布置覆盖回归锁
## 口径：所有可上战场的 id（玩家战斗卡/势力卡/缴获卡/星冥/敌方 archetype）经
## UnitFrameAnim._resolve_key（运行时同链：直查→foe_剥前缀→EnemyCardModMap→
## visual_id→ANIM_ALIAS→captured_ 剥前缀重走）必须命中完备 sheet 目录
## （sheet_idle+sheet_attack+anim.json），anim.json 含 subject+foot_frac（v6.55 部署门）。
## 新增单位卡/敌方原型漏配动画 = 本锁红。

const UCT = preload("res://data/unified_card_table.gd")
const XENO = preload("res://data/xeno_units.gd")
const ARCH = preload("res://data/enemy_archetypes.gd")
const FACTION = preload("res://data/faction_exclusive_cards.gd")
const MANIFEST = preload("res://data/enemy_unit_manifest.gd")
const UFA = preload("res://scripts/battle/unit_frame_anim.gd")
const ANIM_ROOT := "res://assets/effects/unit_anims/"
const NON_BATTLE_PREFIXES: Array[String] = ["platform_", "drop_", "cps_", "special_"]


func _battlefield_ids() -> Array[String]:
	var ids := {}
	for cid in UCT.get_all_card_ids():
		var s := str(cid)
		var skip := false
		for p in NON_BATTLE_PREFIXES:
			if s.begins_with(p):
				skip = true
				break
		if not skip:
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
	var out: Array[String] = []
	for k in ids.keys():
		out.append(str(k))
	out.sort()
	return out


func test_every_battlefield_id_resolves_to_full_sheet_anim() -> void:
	var unresolved: Array[String] = []
	for cid in _battlefield_ids():
		var key: String = UFA._resolve_key(cid)
		if key.is_empty():
			unresolved.append(cid)
			continue
		assert_bool(ResourceLoader.exists(ANIM_ROOT + key + "/sheet_idle.png")) \
			.override_failure_message("%s → %s 缺 sheet_idle" % [cid, key]).is_true()
		assert_bool(ResourceLoader.exists(ANIM_ROOT + key + "/sheet_attack.png")) \
			.override_failure_message("%s → %s 缺 sheet_attack" % [cid, key]).is_true()
		var jf := FileAccess.open(ANIM_ROOT + key + "/anim.json", FileAccess.READ)
		assert_bool(jf != null).override_failure_message("%s → %s 缺 anim.json" % [cid, key]).is_true()
		if jf != null:
			var j = JSON.parse_string(jf.get_as_text())
			assert_bool(j is Dictionary and (j as Dictionary).has("subject") and (j as Dictionary).has("foot_frac")) \
				.override_failure_message("%s → %s anim.json 过期（缺 subject/foot_frac）" % [cid, key]).is_true()
	assert_array(unresolved).override_failure_message(
		"以下战场 id 动画解析失败（战场纯静态回退）: %s" % [unresolved]).is_empty()


func test_anim_alias_entries_all_exist() -> void:
	# 别名表指向的目录必须为完备 sheet（防表内错名静默失效）
	for anim_id in UFA.ANIM_ALIAS.keys():
		var alias: String = String(UFA.ANIM_ALIAS[anim_id])
		assert_bool(ResourceLoader.exists(ANIM_ROOT + alias + "/sheet_idle.png")) \
			.override_failure_message("ANIM_ALIAS %s → %s 缺 sheet_idle" % [anim_id, alias]).is_true()
		assert_bool(ResourceLoader.exists(ANIM_ROOT + alias + "/anim.json")) \
			.override_failure_message("ANIM_ALIAS %s → %s 缺 anim.json" % [anim_id, alias]).is_true()
