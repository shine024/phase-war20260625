extends PanelContainer
## 公司势力排行行模板
## 节点结构: PanelContainer > MarginContainer > HBox
##   HBox > RankLabel, NameLabel, TerritoryLabel, ReputationLabel

@onready var _rank_label: Label = %RankLabel
@onready var _name_label: Label = %NameLabel
@onready var _ter_label: Label = %TerritoryLabel
@onready var _rep_label: Label = %ReputationLabel

func setup(rank: int, data: Dictionary) -> void:
	# 排名
	match rank:
		1: _rank_label.text = "\u2460"  # ①
		2: _rank_label.text = "\u2461"  # ②
		3: _rank_label.text = "\u2462"  # ③
		_: _rank_label.text = str(rank)
	_rank_label.add_theme_color_override("font_color",
		Color(1.0, 0.843, 0.0, 1) if rank <= 3 else Color(0.65, 0.65, 0.65, 1))

	# 公司名称
	var fid: String = data.get("faction_id", "")
	_name_label.text = data.get("name", "未知")
	_name_label.add_theme_color_override("font_color",
		LeaderboardPresenter.FACTION_COLORS.get(fid, Color.WHITE))

	# 已攻克/总关卡
	var cleared: int = data.get("score", 0)
	var total: int = data.get("territories_total", 0)
	if total > 0:
		_ter_label.text = "%d / %d" % [cleared, total]
		var ratio: float = float(cleared) / float(total)
		_ter_label.add_theme_color_override("font_color",
			Color(1.0, 0.843, 0.0, 1) if cleared == total else
			Color(0.4 + ratio * 0.5, 0.7 + ratio * 0.25, 0.5, 1))
	else:
		_ter_label.text = "- / -"
		_ter_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))

	# 声望
	_rep_label.text = str(data.get("reputation", 0))
