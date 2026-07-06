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

	# 显示环境信息
	if environment_label:
		var environment = info.get("environment", {})
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

	# 显示难度倍数
	if difficulty_label:
		var difficulty = info.get("difficulty_modifier", 1.0)
		difficulty_label.text = "难度倍数：%.2fx" % difficulty

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
		},
		"terrain": {
			"plain": "平原",
			"city": "城市",
			"mountain": "山地",
			"forest": "森林",
		},
		"energy_field": {
			"normal": "常规",
			"high_field": "高能",
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
