extends Control
class_name LevelInfoPanel
## 关卡信息UI面板
##
## 功能：
## - 显示关卡详细信息（名称、描述、背景故事）
## - 显示环境信息（天气、地形、能量场、时间）
## - 显示势力控制信息
## - 显示难度倍数和敌人预设
# 法则系统已废弃(v6.2)，改用符文系统，不再显示战争魔法列表
const GC = preload("res://resources/game_constants.gd")
const BattleEnvironments = preload("res://data/battle_environments.gd")  # 2026-08-16: 环境单一真源
const EnemyLoadoutTiers = preload("res://data/enemy_loadout_tiers.gd")  # 2026-08-16: 难度显示单一真源

# UI 组件引用
@onready var level_name_label = $VBoxContainer/LevelNameLabel
@onready var description_label = $VBoxContainer/DescriptionLabel
@onready var environment_label = $VBoxContainer/EnvironmentLabel
@onready var faction_label = $VBoxContainer/FactionLabel
@onready var difficulty_label = $VBoxContainer/DifficultyLabel
@onready var enter_button = $VBoxContainer/EnterButton

# 数据
var current_level: int = 0
var lid = preload("res://data/level_information.gd")

func _ready() -> void:
	if enter_button:
		enter_button.pressed.connect(_on_enter_button_pressed)

	# 如果从外部设置了当前关卡，初始化显示
	if current_level > 0:
		_update_level_info()

func set_level(level_num: int) -> void:
	"""设置要显示的关卡"""
	current_level = level_num
	_update_level_info()

func _update_level_info() -> void:
	"""更新关卡信息显示"""
	if current_level <= 0:
		return

	var level_info = lid.new()
	var info = level_info.get_level_info(current_level)

	if info.is_empty():
		return

	# 显示关卡名称
	if level_name_label:
		level_name_label.text = info.get("display_name", "")

	# 显示描述
	if description_label:
		description_label.text = info.get("description", "")
		description_label.custom_minimum_size = Vector2(0, 0)
		# 移除固定高度限制，让描述自适应内容
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# 显示环境信息（2026-08-16: 改读 BattleEnvironments 单一真源，与战斗侧同源；
	# 原读 info["environment"] 是 level_information 程序循环生成的死数据，与战斗环境不同步）
	if environment_label:
		var environment: Dictionary = BattleEnvironments.get_for_level(current_level)
		var env_text = "环境信息:\n"
		env_text += "天气：%s\n" % _env_value_label("weather", String(environment.get("weather", "未知")))
		env_text += "地形：%s\n" % _env_value_label("terrain", String(environment.get("terrain", "未知")))
		env_text += "能量场：%s\n" % _env_value_label("energy_field", String(environment.get("energy_field", "未知")))
		env_text += "时间：%s" % _env_value_label("time_of_day", String(environment.get("time_of_day", "未知")))
		environment_label.text = env_text

	# 显示势力信息
	if faction_label:
		ManagerLazyLoader.ensure_loaded("faction")
		var fsm = get_node_or_null("/root/FactionSystemManager")
		if fsm:
			var faction_id = info.get("faction_id", "")
			var faction_info = fsm.get_faction_info(faction_id)
			var faction_name = faction_info.get("name", "未知势力")
			faction_label.text = "势力控制：%s" % faction_name

	# 显示难度（2026-08-16: 改用敌方配置档位系数——战斗链真实乘区；
	# 原 difficulty_modifier 线性公式 v8.2 起不在任何战斗乘区中，显示为误导）
	if difficulty_label:
		var in_era_pos: int = ((current_level - 1) % 20) + 1
		var era_progress: float = float(in_era_pos - 1) / 19.0
		var tier: int = EnemyLoadoutTiers.get_tier_for_level_progress(era_progress)
		var tier_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(tier)
		difficulty_label.text = "敌方配置：×%.2f" % (1.0 + float(tier_bonus.get("hp_pct", 0.0)))

func _on_enter_button_pressed() -> void:
	"""进入关卡按钮被按下"""
	if current_level > 0:
		# 隐藏或关闭此面板
		hide()

func _env_value_label(env_key: String, raw: String) -> String:
	var maps: Dictionary = {
		"weather": {
			"clear": "晴朗",
			"rain": "降雨",
			"storm": "风暴",
			"fog": "迷雾",
			"snow": "降雪",
			"sandstorm": "沙暴",
		},
		"terrain": {
			"plain": "平原",
			"city": "城市",
			"mountain": "山地",
			"forest": "森林",
			"desert": "荒漠",
		},
		"energy_field": {
			"normal": "常规",
			"high_field": "高能",
			"low_field": "低能",
			"nano_fog": "纳米雾",
			"void_rift": "虚空裂隙",
		},
		"time_of_day": {
			"day": "白天",
			"dusk": "黄昏",
			"night": "夜晚",
		},
	}
	var group: Dictionary = maps.get(env_key, {})
	if group.has(raw):
		return String(group[raw])
	return raw
