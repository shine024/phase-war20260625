
const _OBJECTIVES_JSON_PATH := "res://data/json/task_objective_types.json"
const _TASKS_JSON_PATH := "res://data/json/task_definitions_extended.json"
static var OBJECTIVE_TYPES: Dictionary = _load_json_dict(_OBJECTIVES_JSON_PATH, LEGACY_OBJECTIVE_TYPES)
static var EXTENDED_TASKS: Dictionary = _load_json_dict(_TASKS_JSON_PATH, LEGACY_EXTENDED_TASKS)

static func _load_json_dict(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != 1:
		return fallback
	var data = parsed.get("data", fallback)
	return data if typeof(data) == TYPE_DICTIONARY else fallback

extends Node
## 扩展任务定义：提供更多样化和丰富的任务内容

## 任务目标类型定义
const LEGACY_OBJECTIVE_TYPES = {
	# 战斗相关
	"win_battles": {
		"name": "赢得战斗",
		"description_template": "赢得{target}场战斗",
		"event_type": "battle_completed",
		"check_condition": "victory == true"
	},
	"kill_enemies": {
		"name": "击败敌人",
		"description_template": "击败{target}个敌人",
		"event_type": "enemy_killed"
	},
	"deal_damage": {
		"name": "造成伤害",
		"description_template": "累计造成{target}点伤害",
		"event_type": "damage_dealt"
	},
	"win_battle_no_damage": {
		"name": "无伤胜利",
		"description_template": "无伤赢得{target}场战斗",
		"event_type": "battle_completed",
		"check_condition": "victory == true and damage_taken == 0"
	},
	"win_battle_fast": {
		"name": "快速胜利",
		"description_template": "在{target}秒内赢得战斗",
		"event_type": "battle_completed",
		"check_condition": "victory == true and battle_time <= target"
	},

	# 收集相关
	"collect_equipment": {
		"name": "收集装备",
		"description_template": "收集{target}件装备",
		"event_type": "equipment_collected"
	},
	"collect_cards": {
		"name": "收集卡牌",
		"description_template": "收集{target}张卡牌",
		"event_type": "card_collected"
	},
	"collect_resources": {
		"name": "收集资源",
		"description_template": "收集{target}{resource_type}",
		"event_type": "resource_collected"
	},
	"unlock_blueprints": {
		"name": "解锁蓝图",
		"description_template": "解锁{target}张蓝图",
		"event_type": "blueprint_unlocked"
	},

	# 击败BOSS相关
	"defeat_masters": {
		"name": "击败相位师",
		"description_template": "击败{target}位相位师",
		"event_type": "master_defeated"
	},
	"defeat_specific_master": {
		"name": "击败特定相位师",
		"description_template": "击败{master_name}",
		"event_type": "master_defeated",
		"check_condition": "master_id == target"
	},

	# 强化相关
	"enhance_cards": {
		"name": "强化卡牌",
		"description_template": "强化{target}张卡牌",
		"event_type": "card_enhanced"
	},
	"enhance_to_level": {
		"name": "强化到等级",
		"description_template": "将卡牌强化到{target}级",
		"event_type": "card_enhanced",
		"check_condition": "enhancement_level >= target"
	},
	# 探索相关
	"reach_level": {
		"name": "到达关卡",
		"description_template": "到达第{target}关",
		"event_type": "level_reached",
		"check_condition": "level >= target"
	},
	"complete_level_with_stars": {
		"name": "星级通关",
		"description_template": "以{stars}星通关第{target}关",
		"event_type": "level_completed",
		"check_condition": "level == target and stars >= target"
	},

	# 社交相关
	"add_friends": {
		"name": "添加好友",
		"description_template": "添加{target}个好友",
		"event_type": "friend_added"
	},
	"send_gifts": {
		"name": "发送礼物",
		"description_template": "发送{target}个礼物",
		"event_type": "gift_sent"
	},

	# 成就相关
	"unlock_achievements": {
		"name": "解锁成就",
		"description_template": "解锁{target}个成就",
		"event_type": "achievement_unlocked"
	},

	# 经济相关
	"spend_resources": {
		"name": "花费资源",
		"description_template": "花费{target}{resource_type}",
		"event_type": "resource_spent"
	},
	"earn_resources": {
		"name": "赚取资源",
		"description_template": "赚取{target}{resource_type}",
		"event_type": "resource_earned"
	}
}

## 扩展任务数据库
const LEGACY_EXTENDED_TASKS = {
	# 主线任务系列
	"story_chapter_1": {
		"id": "story_chapter_1",
		"name": "第一章：觉醒",
		"description": "完成第一章的所有任务",
		"type": "main_story",
		"chapter": 1,
		"objectives": [
			{"type": "win_battles", "target": 5},
			{"type": "reach_level", "target": 10},
			{"type": "collect_equipment", "target": 3}
		],
		"rewards": [
			{"type": "experience", "amount": 500},
			{"type": "basic_nano", "amount": 2000},
			{"type": "card", "card_id": "story_reward_1"}
		],
		"sort_order": 1
	},

	"story_chapter_2": {
		"id": "story_chapter_2",
		"name": "第二章：挑战",
		"description": "完成第二章的所有任务",
		"type": "main_story",
		"chapter": 2,
		"prerequisites": ["story_chapter_1"],
		"objectives": [
			{"type": "defeat_masters", "target": 3},
			{"type": "enhance_cards", "target": 5},
			{"type": "reach_level", "target": 20}
		],
		"rewards": [
			{"type": "experience", "amount": 1000},
			{"type": "basic_nano", "amount": 5000},
			{"type": "blueprint_fragment", "fragment_id": "epic_fragment", "amount": 3}
		],
		"sort_order": 2
	},

	# 每日任务扩展
	"daily_battle_master": {
		"id": "daily_battle_master",
		"name": "战斗大师",
		"description": "每天赢得5场战斗",
		"type": "daily",
		"objectives": [
			{"type": "win_battles", "target": 5}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 300},
			{"type": "experience", "amount": 100}
		],
		"difficulty": "normal",
		"sort_order": 102
	},

	"daily_resource_collector": {
		"id": "daily_resource_collector",
		"name": "资源收集者",
		"description": "每天收集10000基础纳米颗粒",
		"type": "daily",
		"objectives": [
			{"type": "collect_resources", "resource_type": "basic_nano", "target": 10000}
		],
		"rewards": [
			{"type": "energy_block", "amount": 200}
		],
		"difficulty": "easy",
		"sort_order": 103
	},

	"daily_enhancer": {
		"id": "daily_enhancer",
		"name": "强化专家",
		"description": "每天强化3张卡牌",
		"type": "daily",
		"objectives": [
			{"type": "enhance_cards", "target": 3}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 250},
			{"type": "blueprint_fragment", "fragment_id": "common_fragment", "amount": 2}
		],
		"difficulty": "normal",
		"sort_order": 104
	},

	"daily_speedrunner": {
		"id": "daily_speedrunner",
		"name": "速度之星",
		"description": "在120秒内赢得一场战斗",
		"type": "daily",
		"objectives": [
			{"type": "win_battle_fast", "target": 120}
		],
		"rewards": [
			{"type": "experience", "amount": 150}
		],
		"difficulty": "hard",
		"sort_order": 105
	},

	"daily_perfect": {
		"id": "daily_perfect",
		"name": "完美主义",
		"description": "无伤赢得一场战斗",
		"type": "daily",
		"objectives": [
			{"type": "win_battle_no_damage", "target": 1}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 500}
		],
		"difficulty": "expert",
		"sort_order": 106
	},

	# 每周任务扩展
	"weekly_battle_veteran": {
		"id": "weekly_battle_veteran",
		"name": "战斗老兵",
		"description": "本周赢得50场战斗",
		"type": "weekly",
		"objectives": [
			{"type": "win_battles", "target": 50}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 5000},
			{"type": "experience", "amount": 1000}
		],
		"difficulty": "normal",
		"sort_order": 201
	},

	"weekly_collector": {
		"id": "weekly_collector",
		"name": "收藏家",
		"description": "本周收集20张不同的卡牌",
		"type": "weekly",
		"objectives": [
			{"type": "collect_cards", "target": 20}
		],
		"rewards": [
			{"type": "card", "card_id": "rare_card_pack"}
		],
		"difficulty": "normal",
		"sort_order": 202
	},

	"weekly_enhancement_master": {
		"id": "weekly_enhancement_master",
		"name": "强化大师",
		"description": "本周强化30张卡牌",
		"type": "weekly",
		"objectives": [
			{"type": "enhance_cards", "target": 30}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 3000},
			{"type": "blueprint_fragment", "fragment_id": "rare_fragment", "amount": 5}
		],
		"difficulty": "hard",
		"sort_order": 203
	},

	# 挑战任务
	"challenge_untouchable": {
		"id": "challenge_untouchable",
		"name": "不可触碰",
		"description": "连续5场战斗不受到伤害",
		"type": "challenge",
		"objectives": [
			{"type": "win_battle_no_damage", "target": 5}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 10000},
			{"type": "card", "card_id": "legendary_card_02"}
		],
		"difficulty": "legendary",
		"sort_order": 301
	},

	"challenge_speed_demon": {
		"id": "challenge_speed_demon",
		"name": "速度恶魔",
		"description": "在60秒内赢得一场战斗",
		"type": "challenge",
		"objectives": [
			{"type": "win_battle_fast", "target": 60}
		],
		"rewards": [
			{"type": "experience", "amount": 500},
			{"type": "basic_nano", "amount": 2000}
		],
		"difficulty": "expert",
		"sort_order": 302
	},

	"challenge_hoarder": {
		"id": "challenge_hoarder",
		"name": "囤积者",
		"description": "同时拥有50000基础纳米颗粒",
		"type": "challenge",
		"objectives": [
			{"type": "collect_resources", "resource_type": "basic_nano", "target": 50000}
		],
		"rewards": [
			{"type": "energy_block", "amount": 1000}
		],
		"difficulty": "normal",
		"sort_order": 303
	},

	# 成就任务
	"achievement_task_master": {
		"id": "achievement_task_master",
		"name": "任务大师",
		"description": "完成100个任务",
		"type": "achievement",
		"objectives": [
			{"type": "complete_tasks", "target": 100}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 50000},
			{"type": "card", "card_id": "achievement_reward_card"}
		],
		"difficulty": "legendary",
		"sort_order": 401
	},

	"achievement_daily_streak": {
		"id": "achievement_daily_streak",
		"name": "坚持不懈",
		"description": "连续7天完成每日任务",
		"type": "achievement",
		"objectives": [
			{"type": "daily_streak", "target": 7}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 10000},
			{"type": "experience", "amount": 2000}
		],
		"difficulty": "hard",
		"sort_order": 402
	},

	# 支线任务
	"side_blacksmith": {
		"id": "side_blacksmith",
		"name": "铁匠的请求",
		"description": "为铁匠收集10份蓝图库储备（解析份，与战备卡同源）",
		"type": "side_quest",
		"objectives": [
			{"type": "collect_resources", "resource_type": "blueprint_fragment", "target": 10}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 1000},
			{"type": "experience", "amount": 200}
		],
		"difficulty": "easy",
		"prerequisites": ["main_002"],
		"sort_order": 51
	},

	"side_merchant": {
		"id": "side_merchant",
		"name": "商人的贸易",
		"description": "与商人交易10次",
		"type": "side_quest",
		"objectives": [
			{"type": "shop_transactions", "target": 10}
		],
		"rewards": [
			{"type": "experience", "amount": 300},
			{"type": "card", "card_id": "merchant_reward"}
		],
		"difficulty": "normal",
		"prerequisites": ["main_002"],
		"sort_order": 52
	},

	# 可重复任务
	"repeatable_battle_practice": {
		"id": "repeatable_battle_practice",
		"name": "战斗练习",
		"description": "完成3场战斗",
		"type": "repeatable",
		"objectives": [
			{"type": "win_battles", "target": 3}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 100},
			{"type": "experience", "amount": 50}
		],
		"difficulty": "easy",
		"cooldown": 3600,  # 1小时冷却
		"sort_order": 500
	}
}

## 获取扩展任务
static func get_extended_tasks() -> Dictionary:
	return EXTENDED_TASKS.duplicate()

## 获取任务目标类型定义
static func get_objective_types() -> Dictionary:
	return OBJECTIVE_TYPES.duplicate()

## 根据关卡生成任务
static func generate_level_task(level: int) -> Dictionary:
	var task_id = "level_task_" + str(level)
	var difficulty = "easy"
	if level > 10:
		difficulty = "normal"
	elif level > 20:
		difficulty = "hard"
	elif level > 30:
		difficulty = "expert"

	return {
		"id": task_id,
		"name": "关卡挑战: 第" + str(level) + "关",
		"description": "完成第" + str(level) + "关",
		"type": "side_quest",
		"difficulty": difficulty,
		"objectives": [
			{"type": "reach_level", "target": level}
		],
		"rewards": [
			{"type": "basic_nano", "amount": level * 100},
			{"type": "experience", "amount": level * 50}
		],
		"sort_order": 1000 + level
	}

## 根据BOSS生成任务
static func generate_boss_task(master_id: String) -> Dictionary:
	var task_id = "boss_task_" + master_id

	return {
		"id": task_id,
		"name": "击败" + master_id,
		"description": "在战斗中击败" + master_id,
		"type": "challenge",
		"difficulty": "hard",
		"objectives": [
			{"type": "defeat_specific_master", "master_id": master_id, "target": 1}
		],
		"rewards": [
			{"type": "basic_nano", "amount": 2000},
			{"type": "experience", "amount": 500}
		],
		"sort_order": 2000
	}

## 生成每日任务（动态生成）
static func generate_daily_task(difficulty: String = "normal") -> Dictionary:
	var task_types = [
		{"type": "win_battles", "target_range": [3, 10]},
		{"type": "collect_resources", "resource_type": "basic_nano", "target_range": [5000, 20000]},
		{"type": "enhance_cards", "target_range": [3, 8]}
	]

	var selected_type = task_types[randi() % task_types.size()]
	var target_min = selected_type["target_range"][0]
	var target_max = selected_type["target_range"][1]
	var target = randi_range(target_min, target_max + 1)

	var task_id = "daily_generated_" + str(Time.get_unix_time_from_system())

	var task_data = {
		"id": task_id,
		"name": "每日挑战",
		"description": "完成今天的挑战任务",
		"type": "daily",
		"difficulty": difficulty,
		"objectives": [
			selected_type
		],
		"rewards": _generate_daily_rewards(difficulty),
		"time_limit": 86400,
		"sort_order": 3000
	}

	// 添加目标描述
	task_data["objectives"][0]["description"] = _generate_objective_description(selected_type)

	return task_data

## 生成每日奖励
static func _generate_daily_rewards(difficulty: String) -> Array:
	var rewards = []

	match difficulty:
		"easy":
			rewards = [
				{"type": "basic_nano", "amount": 200},
				{"type": "experience", "amount": 50}
			]
		"normal":
			rewards = [
				{"type": "basic_nano", "amount": 400},
				{"type": "experience", "amount": 100}
			]
		"hard":
			rewards = [
				{"type": "basic_nano", "amount": 800},
				{"type": "experience", "amount": 200},
				{"type": "blueprint_fragment", "fragment_id": "common_fragment", "amount": 2}
			]
		"expert":
			rewards = [
				{"type": "basic_nano", "amount": 1500},
				{"type": "experience", "amount": 400},
				{"type": "blueprint_fragment", "fragment_id": "rare_fragment", "amount": 1}
			]

	return rewards

## 生成目标描述
static func _generate_objective_description(objective: Dictionary) -> String:
	var obj_type = objective["type"]
	var target = objective.get("target", 0)
	var resource_type = objective.get("resource_type", "")

	match obj_type:
		"win_battles":
			return "赢得" + str(target) + "场战斗"
		"collect_resources":
			return "收集" + str(target) + resource_type
		"enhance_cards":
			return "强化" + str(target) + "张卡牌"
		_:
			return "完成目标"

## 获取任务链（系列任务）
static func get_task_chain(chain_id: String) -> Array:
	var chains = {
		"warrior_path": ["main_001", "story_chapter_1", "story_chapter_2"],
		"collector_path": ["main_002", "side_blacksmith", "side_merchant"],
		"challenge_path": ["daily_win_3", "daily_battle_master", "weekly_battle_veteran", "challenge_speed_demon"]
	}

	if chains.has(chain_id):
		return chains[chain_id]

	return []

## 根据进度推荐任务
static func get_recommended_tasks_for_progress(player_level: int, completed_tasks: Array) -> Array:
	var recommended = []

	// 根据等级推荐主线任务
	if player_level < 10:
		recommended.append("main_001")
	elif player_level < 20:
		recommended.append("story_chapter_1")
	else:
		recommended.append("story_chapter_2")

	// 推荐简单的每日任务
	recommended.append("daily_win_3")
	recommended.append("daily_resource_collector")

	return recommended