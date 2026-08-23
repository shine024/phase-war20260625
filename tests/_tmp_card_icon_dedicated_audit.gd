extends SceneTree
## tests/_tmp_card_icon_dedicated_audit.gd — 2026-08-23
## 目的：用 UiAssetLoader.card_icon_path_for() 的真实七级解析链审计全卡取图，
## 澄清"192 张无PNG"（该数字来自 05-22 工作清单的文件名核对，非运行时真相）。
## 分类（按解析顺序语义归并）：
##   DEDICATED    专属图（解析结果文件名 == card_id，含根目录与 player/{card_id}.png）
##   OVERRIDE     PLAYER_ICON_OVERRIDE 指定的共享 vis 图（语义精选，非专属）
##   MANIFEST     manifest foe_*/archetype/drop 反查映射到的 vis 图
##   LAW_GENERIC  法则卡通用图（law.png 缺失 → icon_law.svg）
##   ERA_FALLBACK 时代+兵种撞图（七级回退第 6 级）
##   SHAPE        聚合图回退
##   MISSING      空/引擎占位图
## 运行：Godot --headless --rendering-driver opengl3 --path . -s res://tests/_tmp_card_icon_dedicated_audit.gd

const UiAssetLoader := preload("res://scripts/ui_asset_loader.gd")
const DefaultCards := preload("res://data/default_cards.gd")
const EnemyBlueprints := preload("res://data/enemy_blueprints.gd")
const EnemyUnitManifest := preload("res://data/enemy_unit_manifest.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const GC := preload("res://resources/game_constants.gd")

func _classify(c, path: String) -> String:
	var cid: String = c.card_id
	if path.is_empty():
		return "MISSING"
	var stem: String = path.get_file().get_basename()
	if stem == "_enemy_placeholder":
		return "MISSING"
	# 专属图：解析结果文件名与 card_id 一致（根目录 card_icons/{id}.png 或 player/{id}.png）
	if stem == cid:
		return "DEDICATED"
	# override 指定（共享 vis 图，语义精选）
	if String(UiAssetLoader.PLAYER_ICON_OVERRIDE.get(cid, "")) == stem:
		return "OVERRIDE"
	# manifest 三条链（platform foe_ / archetype / drop 反查）
	var aid: String = UiAssetLoader.archetype_id_for_card_icon(c)
	if not aid.is_empty() and not EnemyUnitManifest.get_unit_icon_path_for_archetype(aid).is_empty():
		return "MANIFEST"
	if not EnemyUnitManifest.get_unit_icon_path_for_archetype(
			EnemyUnitManifest.archetype_id_for_platform_card(cid)).is_empty():
		return "MANIFEST"
	if not EnemyArchetypes.get_visual_archetype_id_for_card(cid).is_empty():
		return "MANIFEST"
	# 法则通用
	if path.ends_with("icon_law.svg") or stem == "law":
		return "LAW_GENERIC"
	# 时代兵种撞图 / 聚合图
	if UiAssetLoader.ERA_KIND_FALLBACK_ICON.values().has(stem):
		return "ERA_FALLBACK"
	if UiAssetLoader.SHAPE_KEY_UNIT_ICON.values().has(stem):
		return "SHAPE"
	return "OTHER:%s" % stem

func _audit_group(cards: Array, group_name: String, tally: Dictionary, detail: Dictionary) -> void:
	for c in cards:
		if c == null:
			continue
		var p: String = UiAssetLoader.card_icon_path_for(c)
		var cat: String = _classify(c, p)
		tally[cat] = int(tally.get(cat, 0)) + 1
		detail[cat] = detail.get(cat, [])
		detail[cat].append("%s→%s" % [c.card_id, p.get_file()])

func _initialize() -> void:
	var tally: Dictionary = {}
	var detail: Dictionary = {}

	# 1) 玩家战斗卡 + 势力专属卡（create_all = 统一表玩家卡 + EC 14 张）
	var player_cards: Array = DefaultCards.create_all()
	_audit_group(player_cards, "PLAYER", tally, detail)

	# 2) 法则卡审计组已随法则系统退役移除（v9.x P2-7 批次2；法则卡不再存在于任何获取链路）

	# 3) 敌人掉落高级蓝图 id（bp_* 系；用 DefaultCards 真卡对象——含真实 era/combat_kind，
	#    避免最小 CardResource 的 era=0 默认值把时代撞图算错）
	var bp_cards: Array = []
	for bpid in EnemyBlueprints.get_all_enemy_blueprint_ids():
		var bc = EnemyBlueprints.get_card_by_id(String(bpid))
		if bc == null:
			bc = CardResource.new()
			bc.card_id = String(bpid)
			bc.card_type = GC.CardType.COMBAT_UNIT
			push_warning("[audit] bp 无真卡: %s" % bpid)
		bp_cards.append(bc)
	_audit_group(bp_cards, "ENEMY_BP", tally, detail)

	# 4) 缴获成品卡（captured_*，击杀敌人掉落；从 manifest 的 drop_card_id 枚举）
	var cap_cards: Array = []
	for row in EnemyUnitManifest.get_entries():
		var drop_id: String = String(row.get("drop_card_id", ""))
		if drop_id.is_empty():
			continue
		var cap = DefaultCards.get_card_by_id(drop_id)
		if cap == null:
			var c2 = CardResource.new()
			c2.card_id = drop_id
			c2.card_type = GC.CardType.COMBAT_UNIT
			c2.era = int(row.get("archetype_config", {}).get("era", 0))
			cap = c2
		cap_cards.append(cap)
	_audit_group(cap_cards, "CAPTURED", tally, detail)
	print("缴获卡: %d" % cap_cards.size())

	# ── 汇总输出 ──
	print("==== 卡图运行时解析审计（真实七级链）====")
	print("玩家卡+势力卡: %d | 敌蓝图: %d | 合计: %d" % [
		player_cards.size(), bp_cards.size(),
		player_cards.size() + bp_cards.size()])
	var keys: Array = tally.keys()
	keys.sort()
	for k in keys:
		print("[%s] %d" % [k, tally[k]])
	# 明细只打"非专属"类别，专属/映射数量级太大不打全
	for k in ["MISSING", "ERA_FALLBACK", "SHAPE", "LAW_GENERIC", "OTHER"]:
		if detail.has(k):
			print("---- %s 明细 (%d) ----" % [k, detail[k].size()])
			for line in detail[k]:
				print("  " + line)
	# OVERRIDE 明细打前 10 条示意
	if detail.has("OVERRIDE"):
		print("---- OVERRIDE 明细样例 (共 %d，打 10) ----" % detail["OVERRIDE"].size())
		for i in range(mini(10, detail["OVERRIDE"].size())):
			print("  " + String(detail["OVERRIDE"][i]))
	quit(0)
