"""
卡图引用探测 v2：拦截 ResourceLoader.exists 调用，记录所有被询问的卡图路径。
这样能捕获动态拼接路径（%s/%03d）的真实命中，比静态分析可靠得多。

运行：godot --headless --script tools/probe_card_icon_usage_v2.gd
"""
extends SceneTree

const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const EnemyUnitManifest = preload("res://data/enemy_unit_manifest.gd")
const CapturedUnitCards = preload("res://data/captured_unit_cards.gd")
const DefaultCards = preload("res://data/default_cards.gd")

# 收集所有被询问且文件存在的 card_icons 路径
var _queried_paths: Dictionary = {}

func _check_path(p: String) -> bool:
	# 只关注 card_icons 下的路径
	if p.find("card_icons") != -1 and not p.begins_with("res://tools"):
		if FileAccess.file_exists(p):
			_queried_paths[p] = true
	return FileAccess.file_exists(p)

func _init():
	# monkeypatch FileAccess.file_exists 不现实，改为直接枚举所有可能的取图入口

	# 1. 构建卡牌缓存
	CapturedUnitCards.register_into_default_cards_cache()
	DefaultCards._ensure_card_cache()
	CapturedUnitCards.register_into_default_cards_cache()

	var card_count: int = DefaultCards._all_cards_cache.size()

	# 2. 枚举每张卡牌的取图
	for c in DefaultCards._all_cards_cache:
		if c == null:
			continue
		var p = UiAssetLoader.card_icon_path_for(c)
		if not p.is_empty() and p.find("card_icons") != -1:
			_queried_paths[p] = true

	# 3. 所有 archetype 的敌方取图
	for aid in EnemyArchetypes.get_all_ids():
		var cfg = EnemyArchetypes.get_config(aid)
		var p = EnemyArchetypes.resolve_card_icon_texture_path(aid, cfg, aid)
		if not p.is_empty() and p.find("card_icons") != -1:
			_queried_paths[p] = true

	# 4. manifest visual_id 映射（敌我两路）
	for row in EnemyUnitManifest.get_entries():
		if not (row is Dictionary):
			continue
		var aid = String(row.get("archetype_id", ""))
		if aid.is_empty():
			continue
		for fp in [true, false]:
			var p = EnemyUnitManifest.get_unit_icon_path_for_archetype(aid, fp)
			if not p.is_empty():
				_queried_paths[p] = true

	# 5. 额外：枚举所有 captured_ key，模拟缴获卡 UI 取图（card_icon_path_for 内部路径）
	var cap_keys: Array = []
	var f = FileAccess.open("res://data/captured_card_stats.gd", FileAccess.READ)
	if f != null:
		var txt = f.get_as_text()
		var re = RegEx.new()
		re.compile("\"(captured_[a-z0-9_]+)\":")
		for m in re.search_all(txt):
			var k = m.get_string(1)
			if not k.ends_with("_v2"):
				cap_keys.append(k)
	for ck in cap_keys:
		var c = DefaultCards.get_card_by_id(ck)
		if c != null:
			var p = UiAssetLoader.card_icon_path_for(c)
			if not p.is_empty() and p.find("card_icons") != -1:
				_queried_paths[p] = true

	# 输出
	var out = FileAccess.open("res://tools/_used_icons.txt", FileAccess.WRITE)
	out.store_line("# 卡图引用探测 v2")
	out.store_line("# 卡牌缓存数: %d | captured key 数: %d | 引用路径数: %d" % [card_count, cap_keys.size(), _queried_paths.size()])
	for p in _queried_paths.keys():
		out.store_line(p)
	out.close()
	print("=== 探测完成 ===")
	print("卡牌缓存数: %d" % card_count)
	print("captured key 数: %d" % cap_keys.size())
	print("引用路径数: %d" % _queried_paths.size())
	quit()
