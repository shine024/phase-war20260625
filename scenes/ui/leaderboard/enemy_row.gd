extends PanelContainer
## 敌方相位师排行行模板
## 节点结构: PanelContainer > MarginContainer > Button > InnerHBox
##   InnerHBox > RankLabel, NameLabel, LevelLabel, FactionLabel, DiffLabel, WinrateLabel

signal row_pressed(master_id: String)

@onready var _button: Button = %RowButton
@onready var _rank_label: Label = %RankLabel
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _faction_label: Label = %FactionLabel
@onready var _diff_label: Label = %DiffLabel
@onready var _winrate_label: Label = %WinrateLabel

const EnemyPhaseLeaderboard = preload("res://data/enemy_phase_leaderboard.gd")

var _master_id: String = ""

func _ready() -> void:
	_button.pressed.connect(func(): row_pressed.emit(_master_id))

func setup(entry: LeaderboardEntry) -> void:
	_master_id = entry.master_id

	# 排名
	_rank_label.text = LeaderboardPresenter._rank_text(entry.rank)
	_rank_label.add_theme_color_override("font_color",
		Color(1.0, 0.843, 0.0, 1) if entry.rank <= 3 else Color(0.65, 0.65, 0.65, 1))

	# 名称
	var faction_info = EnemyPhaseLeaderboard.get_faction_display_info(entry.faction)
	_name_label.text = entry.name
	_name_label.add_theme_color_override("font_color", faction_info.color)

	# 等级
	_level_label.text = "Lv.%d" % entry.level
	_level_label.add_theme_color_override("font_color",
		LeaderboardPresenter._enemy_level_color(entry.level))

	# 势力
	_faction_label.text = faction_info.name
	_faction_label.add_theme_color_override("font_color",
		faction_info.color.lightened(0.3))

	# 难度星级
	var difficulty_info = EnemyPhaseLeaderboard.get_difficulty_display_info(entry.difficulty)
	var stars_text = ""
	for i in range(difficulty_info.stars):
		stars_text += "*"
	_diff_label.text = stars_text
	_diff_label.add_theme_color_override("font_color", difficulty_info.color)

	# 胜率
	_winrate_label.text = EnemyPhaseLeaderboard.format_win_rate(entry.win_rate)
