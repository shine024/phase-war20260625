extends SceneTree
## tests/_tmp_art_audit_task11.gd — 2026-09-22 美术资产质检计划 Task 1.1
## 目的：对统一卡表逐卡走 UiAssetLoader.card_icon_path_for() 真实七级解析链，
##       按"最终落盘图标路径"分组，输出同一图标被 ≥2 张卡共用的撞脸分组表。
## 分组类别（按组内成员解析类别归并）：
##   A_MANIFEST_DESIGN  组内全部为 OVERRIDE/MANIFEST（设计内语义复用）
##   B_ERA_GENERIC      组内含 ERA_FALLBACK/SHAPE（时代/兵种通用兜底兜出来的同脸）
##   C_UNEXPECTED       其余（意外撞脸）
##   MISSING            解析为空/_enemy_placeholder（占位图共享，单列最高优先级）
## 证据落盘：tests/evidence/art_audit_2026-09-22/task11_icon_collision_groups.json / .md
## 运行：Godot --headless --rendering-driver opengl3 --path . -s res://tests/_tmp_art_audit_task11.gd

const UiAssetLoader := preload("res://scripts/ui_asset_loader.gd")
const DefaultCards := preload("res://data/default_cards.gd")
const EnemyBlueprints := preload("res://data/enemy_blueprints.gd")
const EnemyUnitManifest := preload("res://data/enemy_unit_manifest.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const ModEraBands := preload("res://data/mod_era_bands.gd")
const GC := preload("res://resources/game_constants.gd")

const OUT_DIR := "res://tests/evidence/art_audit_2026-09-22"

func _classify(c, path: String) -> String:
	var cid: String = c.card_id
	if path.is_empty():
		return "MISSING"
	var stem: String = path.get_file().get_basename()
	if stem == "_enemy_placeholder":
		return "MISSING"
	if stem == cid:
		return "DEDICATED"
	if String(UiAssetLoader.PLAYER_ICON_OVERRIDE.get(cid, "")) == stem:
		return "OVERRIDE"
	var aid: String = UiAssetLoader.archetype_id_for_card_icon(c)
	if not aid.is_empty() and not EnemyUnitManifest.get_unit_icon_path_for_archetype(aid).is_empty():
		return "MANIFEST"
	if not EnemyUnitManifest.get_unit_icon_path_for_archetype(
			EnemyUnitManifest.archetype_id_for_platform_card(cid)).is_empty():
		return "MANIFEST"
	if not EnemyArchetypes.get_visual_archetype_id_for_card(cid).is_empty():
		return "MANIFEST"
	if path.ends_with("icon_law.svg") or stem == "law":
		return "LAW_GENERIC"
	if UiAssetLoader.ERA_KIND_FALLBACK_ICON.values().has(stem):
		return "ERA_FALLBACK"
	if UiAssetLoader.SHAPE_KEY_UNIT_ICON.values().has(stem):
		return "SHAPE"
	return "OTHER:%s" % stem

func _initialize() -> void:
	# 全量口径（同归档脚本）：玩家统一表 create_all + 敌蓝图 bp_* + 缴获 captured_*/drop
	# ——task13 的"统一卡表 233 张"含后两侧（82 张冷门变体多在敌侧），只跑 create_all 会漏。
	var cards: Array = []
	var seen_ids: Dictionary = {}
	for c in DefaultCards.create_all():
		if c == null or seen_ids.has(String(c.card_id)):
			continue
		seen_ids[String(c.card_id)] = true
		cards.append(c)
	var player_count := cards.size()

	var bp_cards: Array = []
	for bpid in EnemyBlueprints.get_all_enemy_blueprint_ids():
		var bc = EnemyBlueprints.get_card_by_id(String(bpid))
		if bc == null:
			bc = CardResource.new()
			bc.card_id = String(bpid)
			bc.card_type = GC.CardType.COMBAT_UNIT
			push_warning("[audit] bp 无真卡: %s" % bpid)
		if seen_ids.has(String(bc.card_id)):
			continue
		seen_ids[String(bc.card_id)] = true
		bp_cards.append(bc)
		cards.append(bc)

	var cap_count := 0
	for row in EnemyUnitManifest.get_entries():
		var drop_id: String = String(row.get("drop_card_id", ""))
		if drop_id.is_empty() or seen_ids.has(drop_id):
			continue
		var cap = DefaultCards.get_card_by_id(drop_id)
		if cap == null:
			var c2 = CardResource.new()
			c2.card_id = drop_id
			c2.card_type = GC.CardType.COMBAT_UNIT
			c2.era = int(row.get("archetype_config", {}).get("era", 0))
			cap = c2
		seen_ids[drop_id] = true
		cards.append(cap)
		cap_count += 1

	print("统一卡表卡数: %d（玩家 %d + 敌蓝图 %d + 缴获/掉落 %d）" % [
		cards.size(), player_count, bp_cards.size(), cap_count])

	# 逐卡解析
	var by_icon: Dictionary = {}   # icon_key -> Array[member]
	var cat_tally: Dictionary = {}
	for c in cards:
		if c == null:
			continue
		var p: String = UiAssetLoader.card_icon_path_for(c)
		var cls := _classify(c, p)
		cat_tally[cls] = int(cat_tally.get(cls, 0)) + 1
		var key := p if not p.is_empty() else "<EMPTY_PATH>"
		if not by_icon.has(key):
			by_icon[key] = []
		by_icon[key].append({
			"id": String(c.card_id),
			"name": String(c.display_name),
			"rarity": String(c.rarity),
			"era": int(c.era),
			"era_name": ModEraBands.era_name(int(c.era)) if ModEraBands.ERA_NAMES.size() > int(c.era) and int(c.era) >= 0 else str(c.era),
			"cls": cls,
		})

	# 分组（≥2 卡共用）
	var groups: Array = []
	for icon_path in by_icon.keys():
		var members: Array = by_icon[icon_path]
		if members.size() < 2:
			continue
		var classes: Array = []
		var has_missing := false
		var has_era_generic := false
		var all_manifest := true
		for m in members:
			var mc: String = String(m["cls"])
			if not classes.has(mc):
				classes.append(mc)
			if mc == "MISSING":
				has_missing = true
				all_manifest = false
			elif mc == "ERA_FALLBACK" or mc.begins_with("SHAPE"):
				has_era_generic = true
				all_manifest = false
			elif mc != "OVERRIDE" and mc != "MANIFEST":
				all_manifest = false
		var gcls := "C_UNEXPECTED"
		if has_missing:
			gcls = "MISSING"
		elif has_era_generic:
			gcls = "B_ERA_GENERIC"
		elif all_manifest:
			gcls = "A_MANIFEST_DESIGN"
		# 组内按稀有度+时代排序便于阅读
		members.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
		groups.append({
			"icon": String(icon_path),
			"icon_file": String(icon_path).get_file(),
			"group_class": gcls,
			"member_classes": classes,
			"count": members.size(),
			"members": members,
		})
	var order := {"MISSING": 0, "C_UNEXPECTED": 1, "B_ERA_GENERIC": 2, "A_MANIFEST_DESIGN": 3}
	groups.sort_custom(func(a, b):
		var oa: int = int(order.get(String(a["group_class"]), 9))
		var ob: int = int(order.get(String(b["group_class"]), 9))
		if oa != ob:
			return oa < ob
		return int(a["count"]) > int(b["count"]))

	# ── 写 JSON ──
	var payload := {
		"date": "2026-09-22",
		"unified_table_cards": cards.size(),
		"category_tally": cat_tally,
		"collision_group_count": groups.size(),
		"groups": groups,
	}
	var jf := FileAccess.open(OUT_DIR + "/task11_icon_collision_groups.json", FileAccess.WRITE)
	jf.store_string(JSON.stringify(payload, "  ", false))
	jf.close()

	# ── 写 MD ──
	var cls_name := {
		"MISSING": "占位图共享（最高优先级）",
		"C_UNEXPECTED": "c) 意外撞脸",
		"B_ERA_GENERIC": "b) 时代/兵种通用兜底",
		"A_MANIFEST_DESIGN": "a) manifest 有意映射（设计内复用）",
	}
	var md := "# Task 1.1 卡图标撞脸分组（%d 卡全量解析）\n\n" % cards.size()
	md += "解析类别分布：%s\n\n" % str(cat_tally)
	md += "撞脸组总数：%d\n\n" % groups.size()
	var gi := 0
	for g in groups:
		gi += 1
		md += "## 组 %d [%s] %d 卡共用 `%s`\n\n" % [gi, cls_name.get(String(g["group_class"]), "?"), int(g["count"]), String(g["icon_file"])]
		md += "完整路径：`%s`\n\n" % String(g["icon"])
		md += "| 卡 id | 显示名 | 稀有度 | 时代 | 解析类别 |\n|---|---|---|---|---|\n"
		for m in g["members"]:
			md += "| %s | %s | %s | %s | %s |\n" % [m["id"], m["name"], m["rarity"], m["era_name"], m["cls"]]
		md += "\n"
	var mf := FileAccess.open(OUT_DIR + "/task11_icon_collision_groups.md", FileAccess.WRITE)
	mf.store_string(md)
	mf.close()

	# ── 控制台摘要 ──
	print("解析类别分布: %s" % str(cat_tally))
	print("撞脸组总数: %d" % groups.size())
	var by_cls: Dictionary = {}
	for g in groups:
		var k: String = String(g["group_class"])
		by_cls[k] = int(by_cls.get(k, 0)) + 1
	print("分组类别统计: %s" % str(by_cls))
	for g in groups:
		if String(g["group_class"]) == "MISSING" or String(g["group_class"]) == "C_UNEXPECTED":
			print("  [%s] %d 卡 -> %s" % [g["group_class"], g["count"], g["icon_file"]])
	print("TASK11_OK")
	quit(0)
