extends SceneTree
## 记录4#5 美术覆盖审计：全卡表逐卡走 UiAssetLoader 真实回退链，分类统计
## 专属图 / 时代兵种兜底 / 形状兜底 / 占位符（缺口）。--script 直跑。

const UiAssetLoader = preload("res://scripts/ui_asset_loader.gd")
const DefaultCardsData = preload("res://data/default_cards.gd")

func _init() -> void:
	var ids: Array = DefaultCardsData.get_all_blueprint_ids()
	print("ART_AUDIT card_ids=", ids.size())
	var dedicated: int = 0
	var era_kind: int = 0
	var shape: int = 0
	var placeholder: int = 0
	var empty: int = 0
	var placeholder_ids: Array = []
	var era_kind_ids: Array = []
	for id in ids:
		var card: CardResource = DefaultCardsData.get_card_by_id(String(id))
		if card == null:
			continue
		var p: String = UiAssetLoader.card_icon_path_for(card)
		if p.is_empty():
			empty += 1
			placeholder_ids.append(String(id))
		elif p.contains("_enemy_placeholder") or p.contains("_placeholder"):
			placeholder += 1
			placeholder_ids.append(String(id))
		elif p.contains("/player/") or p.contains("/enemy/"):
			dedicated += 1
		elif p.contains("_era_kind") or p.contains("era_kind"):
			era_kind += 1
			era_kind_ids.append(String(id))
		else:
			shape += 1
	print("ART_AUDIT dedicated=", dedicated, " era_kind=", era_kind, " shape=", shape, " placeholder=", placeholder, " empty=", empty)
	if not era_kind_ids.is_empty():
		print("ART_AUDIT era_kind_ids=", str(era_kind_ids))
	if not placeholder_ids.is_empty():
		print("ART_AUDIT placeholder_ids=", str(placeholder_ids))
	# 图标家族覆盖抽查：符文/仪器/掉落
	var rune_dir := "res://assets/ui/icons/runes"
	var inst_dir := "res://assets/ui/instruments"
	var drop_dir := "res://assets/resources/drops"
	for d in [rune_dir, inst_dir, drop_dir]:
		var dn: DirAccess = DirAccess.open(d)
		if dn == null:
			print("ART_AUDIT missing_dir=", d)
		else:
			var n: int = 0
			dn.list_dir_begin()
			var f := dn.get_next()
			while f != "":
				if not dn.current_is_dir() and f.ends_with(".png"):
					n += 1
				f = dn.get_next()
			print("ART_AUDIT dir=", d, " png=", n)
	quit(0)
