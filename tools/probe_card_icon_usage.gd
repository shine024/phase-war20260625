"""
卡图引用探测工具：枚举所有卡牌 + archetype，调用真实取图函数，
收集真正被引用的 png 文件路径。用于识别孤儿图。

运行：godot --headless --script tools/probe_card_icon_usage.gd
"""
extends SceneTree

const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")
const DefaultCards = preload("res://data/default_cards.gd")

func _init():
	var used_paths: Dictionary = {}
	var card_count: int = 0

	# 1. 所有 DefaultCards 卡牌（含缴获卡）
	# 强制构建：先注册缴获卡，再确保缓存（register 可能依赖缓存已构建）
	CapturedUnitCards.register_into_default_cards_cache()
	DefaultCards._ensure_card_cache()
	# 二次注册（缴获卡依赖 _id_lookup_cache 已建）
	CapturedUnitCards.register_into_default_cards_cache()
	for c in DefaultCards._all_cards_cache:
		if c == null:
			continue
		card_count += 1
		var p = UiAssetLoader.card_icon_path_for(c)
		if not p.is_empty():
			used_paths[p] = true

	# 2. 所有 archetype（敌方单位取图，for_player=false）
	for aid in EnemyArchetypes.get_all_ids():
		var cfg = EnemyArchetypes.get_config(aid)
		var p = EnemyArchetypes.resolve_card_icon_texture_path(aid, cfg, aid)
		if not p.is_empty():
			used_paths[p] = true

	# 3. manifest entries（平台卡/特殊/池子/堡垒的 visual_id 映射）
	for row in EnemyUnitManifest.get_entries():
		if not (row is Dictionary):
			continue
		var aid = String(row.get("archetype_id", ""))
		if aid.is_empty():
			continue
		# 我方路径
		var pp = EnemyUnitManifest.get_unit_icon_path_for_archetype(aid, true)
		if not pp.is_empty():
			used_paths[pp] = true
		# 敌方路径
		var pe = EnemyUnitManifest.get_unit_icon_path_for_archetype(aid, false)
		if not pe.is_empty():
			used_paths[pe] = true

	# 输出到文件
	var f = FileAccess.open("res://tools/_used_icons.txt", FileAccess.WRITE)
	f.store_line("# 卡图引用探测结果（自动生成）")
	f.store_line("# 卡牌数: %d | 引用路径数: %d" % [card_count, used_paths.size()])
	for p in used_paths.keys():
		f.store_line(p)
	f.close()
	print("=== 探测完成 ===")
	print("卡牌数: %d" % card_count)
	print("引用路径数: %d" % used_paths.size())
	print("结果写入: tools/_used_icons.txt")
	quit()
