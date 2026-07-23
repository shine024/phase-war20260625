## 卡图引用运行时验证：打印每张玩家卡 → 最终图标路径
## 找出"图错"的卡（路径与预期不符）
extends SceneTree

func _init() -> void:
	var UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
	var DefaultCards = preload("res://data/default_cards.gd")

	# 强制构建卡缓存
	var all_cards = DefaultCards.create_all()
	print("玩家卡总数: %d" % all_cards.size())

	# 逐卡解析图标路径
	var by_path: Dictionary = {}  # path → [card_ids]
	var fallback_cards: Array = []  # 走 fallback 的卡
	var results: Array = []
	for card in all_cards:
		if card == null or card.card_type != 0:  # 0 = COMBAT_UNIT
			continue
		var path: String = UiAssetLoader.card_icon_path_for(card)
		results.append({"id": card.card_id, "name": card.display_name, "path": path})
		if path.is_empty():
			fallback_cards.append(card.card_id)
		else:
			var short: String = path.get_file()  # vis_player_NNN.png
			if not by_path.has(short):
				by_path[short] = []
			by_path[short].append(card.card_id)

	# 输出1: 多卡共享同一图的（潜在撞图）
	print("\n=== 多卡共享同一图（≥2张）===")
	var clash_count: int = 0
	for p in by_path.keys():
		var cids: Array = by_path[p]
		if cids.size() >= 2:
			clash_count += cids.size()
			print("  %s (%d张): %s" % [p, cids.size(), ", ".join(cids)])
	print("撞图卡总数: %d / %d" % [clash_count, results.size()])

	# 输出2: 走 fallback（无图）的卡
	print("\n=== 走 fallback/placeholder 的卡（无专属图）===")
	for cid in fallback_cards:
		print("  %s" % cid)
	print("无图卡数: %d" % fallback_cards.size())

	# 输出3: 所有卡 → 图路径（完整明细，供核对）
	print("\n=== 全部卡 → 图路径明细 ===")
	for r in results:
		var p: String = r.path
		var fname: String = p.get_file() if not p.is_empty() else "(无图/placeholder)"
		print("  %-26s %-20s %s" % [r.id, r.name, fname])

	quit(0)
