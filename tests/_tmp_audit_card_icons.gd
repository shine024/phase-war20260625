extends SceneTree
## 资源清点批（2026-10-13）一次性探针：全卡表走 UiAssetLoader.card_icon_path_for
## 真实六级链，统计占位/空路径/时代兵种通用回退分布 + 解析结果磁盘存在性。

const UCT = preload("res://data/unified_card_table.gd")
const DC = preload("res://data/default_cards.gd")
const UAL = preload("res://scripts/ui_asset_loader.gd")


func _initialize() -> void:
	var n_total := 0
	var n_placeholder := 0
	var n_empty := 0
	var n_generic := 0
	var n_missing_disk := 0
	var generic_vis := {}
	for v in UAL.ERA_KIND_FALLBACK_ICON.values():
		generic_vis[String(v)] = true
	var details: Array = []
	for cid in UCT.get_all_card_ids():
		var card = DC.get_card_by_id(str(cid))
		if card == null:
			continue
		n_total += 1
		var p: String = UAL.card_icon_path_for(card)
		if p.is_empty():
			n_empty += 1
			details.append("EMPTY      %s" % cid)
			continue
		if p.contains("_enemy_placeholder"):
			n_placeholder += 1
			details.append("PLACEHOLDER %s" % cid)
			continue
		if not FileAccess.file_exists(p.replace("res://", "")):
			n_missing_disk += 1
			details.append("NO_DISK    %s -> %s" % [cid, p])
			continue
		var fname: String = p.get_file().replace(".png", "")
		if generic_vis.has(fname):
			n_generic += 1
			details.append("GENERIC    %s -> %s" % [cid, p])
	print("[card-icon audit] total=%d placeholder=%d empty=%d generic_era_kind=%d missing_on_disk=%d" % [n_total, n_placeholder, n_empty, n_generic, n_missing_disk])
	for d in details:
		print(d)
	quit(0)
