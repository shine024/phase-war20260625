extends PanelContainer
## NPC相位师排行行模板
## 节点结构: PanelContainer > MarginContainer > HBox
##   HBox > RankLabel, NameLabel, LevelLabel, FactionLabel, WinsLabel

@onready var _rank_label: Label = %RankLabel
@onready var _name_label: Label = %NameLabel
@onready var _lv_label: Label = %LevelLabel
@onready var _fac_label: Label = %FactionLabel
@onready var _wins_label: Label = %WinsLabel

func setup(data: Dictionary) -> void:
	var rank: int = data.get("rank", 0)

	# 排名
	match rank:
		1: _rank_label.text = "\u2460"  # ①
		2: _rank_label.text = "\u2461"  # ②
		3: _rank_label.text = "\u2462"  # ③
		_: _rank_label.text = str(rank)
	_rank_label.add_theme_color_override("font_color",
		Color(1.0, 0.843, 0.0, 1) if rank <= 3 else Color(0.65, 0.65, 0.65, 1))

	# 相位师名称
	var fid: String = data.get("preferred_faction", "")
	_name_label.text = data.get("name", "未知玩家")
	_name_label.add_theme_color_override("font_color",
		LeaderboardPresenter.FACTION_COLORS.get(fid, Color.WHITE))

	# 当前关卡
	var cur_lv: int = data.get("current_level", 0)
	_lv_label.text = "Lv.%d" % cur_lv
	# 按关卡区间着色
	var era_color: Color
	if cur_lv >= 81:
		era_color = Color(0.85, 0.5, 1.0, 1)
	elif cur_lv >= 61:
		era_color = Color(0.0, 0.85, 0.95, 1)
	elif cur_lv >= 41:
		era_color = Color(0.45, 0.7, 1.0, 1)
	elif cur_lv >= 21:
		era_color = Color(0.4, 0.95, 0.35, 1)
	else:
		era_color = Color(0.95, 0.78, 0.45, 1)
	_lv_label.add_theme_color_override("font_color", era_color)

	# 所属势力
	_fac_label.text = data.get("faction_name", fid)
	_fac_label.add_theme_color_override("font_color",
		LeaderboardPresenter.FACTION_COLORS.get(fid, Color.GRAY).lightened(0.3))

	# 胜场
	_wins_label.text = str(data.get("wins", 0))
