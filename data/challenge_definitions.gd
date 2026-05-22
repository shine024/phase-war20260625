extends RefCounted
class_name ChallengeDefinitions
## 挑战模式定义：各种挑战模式的配置和奖励

## 挑战模式定义
const CHALLENGES: Dictionary = {
	# ==================== 生存模式 ====================
	"survival_normal": {
		"id": "survival_normal",
		"name": "生存挑战 - 普通",
		"description": "在连续的敌人波次中生存下来，波次会越来越强。",
		"type": "survival",
		"difficulty": "normal",
		"rules": {
			"wave_interval": 15.0,
			"enemy_multiplier": 1.0,
			"max_waves": 20,
			"start_energy": 100,
			"healing_between_waves": false,
			"card_restriction": []
		},
		"rewards": {
			"completion": {"nano_materials": 200, "blueprint_fragments": 10},
			"per_wave": {"nano_materials": 10},
			"bonus_objectives": {
				"no_loss": {"nano_materials": 100, "blueprint_fragments": 5},
				"under_10_minutes": {"nano_materials": 50}
			}
		},
		"unlock_requirements": {"level": 5}
	},

	"survival_hard": {
		"id": "survival_hard",
		"name": "生存挑战 - 困难",
		"description": "更强的敌人，更快的波次，真正的考验！",
		"type": "survival",
		"difficulty": "hard",
		"rules": {
			"wave_interval": 12.0,
			"enemy_multiplier": 1.3,
			"max_waves": 30,
			"start_energy": 80,
			"healing_between_waves": false,
			"card_restriction": ["mythic"]
		},
		"rewards": {
			"completion": {"nano_materials": 500, "blueprint_fragments": 25, "rare_cards": 1},
			"per_wave": {"nano_materials": 20},
			"bonus_objectives": {
				"no_loss": {"nano_materials": 300, "blueprint_fragments": 15},
				"under_15_minutes": {"nano_materials": 100}
			}
		},
		"unlock_requirements": {"level": 10, "completed_survival_normal": true}
	},

	# ==================== Boss连战 ====================
	"boss_rush": {
		"id": "boss_rush",
		"name": "Boss连战",
		"description": "连续挑战强大的Boss敌人，中间不能休息！",
		"type": "boss_rush",
		"difficulty": "hard",
		"rules": {
			"boss_count": 5,
			"healing_between_bosses": false,
			"energy_refill": false,
			"start_energy": 120
		},
		"rewards": {
			"completion": {"nano_materials": 800, "blueprint_fragments": 40, "legendary_card": 1},
			"per_boss": {"nano_materials": 100},
			"bonus_objectives": {
				"no_loss": {"nano_materials": 500, "blueprint_fragments": 20}
			}
		},
		"unlock_requirements": {"level": 15, "completed_survival_hard": true}
	},

	# ==================== 限时挑战 ====================
	"time_attack_3min": {
		"id": "time_attack_3min",
		"name": "限时挑战 - 3分钟",
		"description": "在3分钟内击败尽可能多的敌人！",
		"type": "time_attack",
		"difficulty": "normal",
		"rules": {
			"time_limit": 180.0,
			"enemy_spawn_rate": 2.0,
			"start_energy": 150
		},
		"rewards": {
			"base": {"nano_materials": 100},
			"per_kill": {"nano_materials": 5},
			"milestones": {
				"20_kills": {"nano_materials": 100},
				"40_kills": {"nano_materials": 200},
				"60_kills": {"nano_materials": 300, "rare_card": 1}
			}
		},
		"unlock_requirements": {"level": 3}
	},

	"time_attack_1min": {
		"id": "time_attack_1min",
		"name": "限时挑战 - 1分钟极速",
		"description": "1分钟内尽可能多地击败敌人，考验反应速度！",
		"type": "time_attack",
		"difficulty": "expert",
		"rules": {
			"time_limit": 60.0,
			"enemy_spawn_rate": 1.0,
			"start_energy": 200,
			"card_restriction": ["uncommon", "common"]
		},
		"rewards": {
			"base": {"nano_materials": 150},
			"per_kill": {"nano_materials": 10},
			"milestones": {
				"15_kills": {"nano_materials": 150},
				"30_kills": {"nano_materials": 300, "rare_card": 1}
			}
		},
		"unlock_requirements": {"level": 20, "completed_time_attack_3min": true}
	},

	# ==================== 无损挑战 ====================
	"no_loss_normal": {
		"id": "no_loss_normal",
		"name": "无损挑战 - 普通",
		"description": "在不损失任何单位的情况下完成关卡！",
		"type": "no_loss",
		"difficulty": "normal",
		"rules": {
			"allowed_losses": 0,
			"level_select": "any",
			"start_energy": 120
		},
		"rewards": {
			"completion": {"nano_materials": 300, "blueprint_fragments": 15},
			"bonus_per_level": {"nano_materials": 50}
		},
		"unlock_requirements": {"level": 8}
	},

	"no_loss_hard": {
		"id": "no_loss_hard",
		"name": "无损挑战 - 困难",
		"description": "在困难关卡中无损获胜，只有真正的高手才能做到！",
		"type": "no_loss",
		"difficulty": "hard",
		"rules": {
			"allowed_losses": 0,
			"level_select": "hard_only",
			"start_energy": 100
		},
		"rewards": {
			"completion": {"nano_materials": 600, "blueprint_fragments": 30, "mythic_card": 1},
			"bonus_per_level": {"nano_materials": 100}
		},
		"unlock_requirements": {"level": 25, "completed_no_loss_normal": true}
	},

	# ==================== 随机卡组挑战 ====================
	"random_deck": {
		"id": "random_deck",
		"name": "随机卡组挑战",
		"description": "使用随机生成的卡组进行战斗，考验适应能力！",
		"type": "random_deck",
		"difficulty": "normal",
		"rules": {
			"deck_size": 8,
			"platform_count": 3,
			"weapon_count": 4,
			"energy_card_count": 1,
			"rarity_limit": "rare"
		},
		"rewards": {
			"completion": {"nano_materials": 250, "blueprint_fragments": 12},
			"wins_streak": {
				"3_wins": {"nano_materials": 100},
				"5_wins": {"nano_materials": 200, "rare_card": 1},
				"10_wins": {"nano_materials": 500, "mythic_card": 1}
			}
		},
		"unlock_requirements": {"level": 12}
	},

	# ==================== 最大伤害挑战 ====================
	"max_damage_single": {
		"id": "max_damage_single",
		"name": "最大伤害挑战 - 单次",
		"description": "在单次攻击中造成尽可能高的伤害！",
		"type": "max_damage",
		"difficulty": "normal",
		"rules": {
			"attack_type": "single",
			"time_limit": 30.0,
			"target_dummy": true
		},
		"rewards": {
			"base": {"nano_materials": 100},
			"milestones": {
				"1000_damage": {"nano_materials": 100},
				"5000_damage": {"nano_materials": 300},
				"10000_damage": {"nano_materials": 600, "blueprint_fragments": 20}
			}
		},
		"unlock_requirements": {"level": 18}
	},

	"max_damage_total": {
		"id": "max_damage_total",
		"name": "最大伤害挑战 - 总计",
		"description": "在限定时间内造成尽可能高的总伤害！",
		"type": "max_damage",
		"difficulty": "hard",
		"rules": {
			"attack_type": "total",
			"time_limit": 60.0,
			"enemy_spawn_rate": 3.0
		},
		"rewards": {
			"base": {"nano_materials": 150},
			"milestones": {
				"10000_damage": {"nano_materials": 200},
				"50000_damage": {"nano_materials": 500},
				"100000_damage": {"nano_materials": 1000, "mythic_card": 1}
			}
		},
		"unlock_requirements": {"level": 22, "completed_max_damage_single": true}
	}
}

## 挑战模式分类
const CHALLENGE_CATEGORIES: Dictionary = {
	"survival": {
		"name": "生存模式",
		"description": "在连续的敌人波次中生存下来",
		"icon": "⚔",
		"challenges": ["survival_normal", "survival_hard"]
	},
	"boss_rush": {
		"name": "Boss连战",
		"description": "连续挑战强大的Boss敌人",
		"icon": "👹",
		"challenges": ["boss_rush"]
	},
	"time_attack": {
		"name": "限时挑战",
		"description": "在限定时间内达成目标",
		"icon": "⏱",
		"challenges": ["time_attack_3min", "time_attack_1min"]
	},
	"no_loss": {
		"name": "无损挑战",
		"description": "在不损失单位的情况下获胜",
		"icon": "🛡",
		"challenges": ["no_loss_normal", "no_loss_hard"]
	},
	"special": {
		"name": "特殊挑战",
		"description": "各种特殊的游戏模式",
		"icon": "⭐",
		"challenges": ["random_deck", "max_damage_single", "max_damage_total"]
	}
}

## 获取挑战定义
static func get_challenge(challenge_id: String) -> Dictionary:
	if CHALLENGES.has(challenge_id):
		return CHALLENGES[challenge_id]
	return {}

## 获取分类下的所有挑战
static func get_challenges_by_category(category: String) -> Array:
	if CHALLENGE_CATEGORIES.has(category):
		var category_data = CHALLENGE_CATEGORIES[category]
		var challenges = []
		for challenge_id in category_data.challenges:
			challenges.append(get_challenge(challenge_id))
		return challenges
	return []

## 检查挑战解锁条件
static func check_unlock_requirements(challenge_id: String, player_data: Dictionary) -> bool:
	var challenge = get_challenge(challenge_id)
	if challenge.is_empty():
		return false

	var requirements = challenge.get("unlock_requirements", {})
	var player_level = player_data.get("level", 0)

	# 检查等级要求
	if requirements.has("level") and player_level < requirements.level:
		return false

	# 检查完成其他挑战的要求
	if requirements.has("completed_survival_normal"):
		var completed = player_data.get("completed_challenges", {})
		if not completed.has("survival_normal"):
			return false

	# 类似检查其他要求...
	return true

## 获取挑战奖励预览
static func get_challenge_rewards_preview(challenge_id: String) -> Dictionary:
	var challenge = get_challenge(challenge_id)
	if challenge.is_empty():
		return {}

	return challenge.get("rewards", {})
