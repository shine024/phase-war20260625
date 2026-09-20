extends Node
## 卡图终检 runner：全卡走真实加载器，报缺图/占位图/缩略图缺失三类

const DC = preload("res://data/default_cards.gd")

func _ready() -> void:
	await get_tree().process_frame
	var UAL = load("res://scripts/ui_asset_loader.gd")
	var ids: Array = DC.get_all_blueprint_ids()
	print("[IconAudit] 蓝图总数 %d" % ids.size())
	var placeholder_hits: Array = []
	var missing: Array = []
	var thumb_missing: Array = []
	var checked := 0
	for id in ids:
		var c = DC.get_card_by_id(String(id))
		if c == null:
			continue
		checked += 1
		var path: String = String(UAL.card_icon_path_for(c))
		if path.contains("placeholder"):
			placeholder_hits.append("%s(%s)" % [String(id), path.get_file()])
		elif not ResourceLoader.exists(path):
			missing.append("%s → %s" % [String(id), path])
		else:
			var tp: String = String(UAL.card_icon_path_for_list(c))
			if tp.begins_with("res://assets/card_icons/_thumb") and not ResourceLoader.exists(tp):
				thumb_missing.append(String(id))
	print("[IconAudit] 实检 %d 卡" % checked)
	var ph_sample := ", ".join(placeholder_hits.slice(0, 20))
	var ms_sample := ", ".join(missing.slice(0, 20))
	var th_sample := ", ".join(thumb_missing.slice(0, 25))
	print("[IconAudit] 占位图命中 %d: %s" % [placeholder_hits.size(), ph_sample])
	print("[IconAudit] 路径不存在 %d: %s" % [missing.size(), ms_sample])
	print("[IconAudit] 缩略图缺失(回退全图,性能项) %d: %s" % [thumb_missing.size(), th_sample])
	print("[IconAudit] DONE")
	get_tree().quit(0)
