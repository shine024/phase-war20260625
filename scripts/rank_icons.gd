extends RefCounted
class_name RankIcons
## 军衔图标贴图（assets/ui/ranks/）

const RankRules = preload("res://data/rank_rules.gd")

const DIR := "res://assets/ui/ranks/"

const _ICONS: Dictionary = {
	"private": preload(DIR + "rank_private.png"),
	"corporal": preload(DIR + "rank_corporal.png"),
	"sergeant": preload(DIR + "rank_sergeant.png"),
	"second_lieutenant": preload(DIR + "rank_second_lieutenant.png"),
	"first_lieutenant": preload(DIR + "rank_first_lieutenant.png"),
	"captain": preload(DIR + "rank_captain.png"),
	"major": preload(DIR + "rank_major.png"),
	"lieutenant_colonel": preload(DIR + "rank_lieutenant_colonel.png"),
	"colonel": preload(DIR + "rank_colonel.png"),
	"brigadier": preload(DIR + "rank_brigadier.png"),
	"major_general": preload(DIR + "rank_major_general.png"),
	"general": preload(DIR + "rank_general.png"),
	"marshal": preload(DIR + "rank_marshal.png"),
}


static func get_icon(rank_id: String) -> Texture2D:
	return _ICONS.get(rank_id) as Texture2D


static func get_icon_for_level(rank_level: int) -> Texture2D:
	var idx: int = clampi(rank_level, 1, RankRules.RANK_ORDER.size()) - 1
	return get_icon(RankRules.RANK_ORDER[idx])
