extends RefCounted
class_name AchievementDefinitions
## 成就系统定义：记录玩家的里程碑和挑战
##
## 成就分类：
## - battle: 战斗成就（击杀数、胜场等）
## - collection: 收集成就（卡片、蓝图等）
## - challenge: 挑战成就（困难任务等）
## - progress: 进度成就（通关、等级等）
## - special: 特殊成就（隐藏成就等）

## 成就状态枚举
enum Status {
	LOCKED,     # 未解锁
	UNLOCKED,   # 已解锁
	COMPLETED   # 已完成（需要额外步骤）
}

## 成就定义表
const ACHIEVEMENTS: Dictionary = {
	# ==================== 战斗成就 ====================

	"battle_first_win": {
		"id": "battle_first_win",
		"name": "初露锋芒",
		"description": "赢得你的第一场战斗胜利",
		"category": "battle",
		"reward": {
			"nano_materials": 50,
			"company_rep": {"iron_wall_corp": 20}
		},
		"icon": "⚔️",
		"hidden": false
	},

	"battle_wins_10": {
		"id": "battle_wins_10",
		"name": "百战老兵",
		"description": "累计赢得10场战斗",
		"category": "battle",
		"reward": {
			"nano_materials": 100
		},
		"icon": "🎖️",
		"hidden": false
	},

	"battle_wins_50": {
		"id": "battle_wins_50",
		"name": "战场传奇",
		"description": "累计赢得50场战斗",
		"category": "battle",
		"reward": {
			"nano_materials": 300
		},
		"icon": "🏆",
		"hidden": false
	},

	"battle_kills_100": {
		"id": "battle_kills_100",
		"name": "收割者",
		"description": "累计击毁100个敌方单位",
		"category": "battle",
		"reward": {
			"nano_materials": 200
		},
		"icon": "💀",
		"hidden": false
	},

	"battle_kills_500": {
		"id": "battle_kills_500",
		"name": "战场主宰",
		"description": "累计击毁500个敌方单位",
		"category": "battle",
		"reward": {
			"nano_materials": 500
		},
		"icon": "☠️",
		"hidden": false
	},

	"battle_no_damage": {
		"id": "battle_no_damage",
		"name": "完美战役",
		"description": "在一场战斗中不受到任何伤害",
		"category": "challenge",
		"reward": {
			"nano_materials": 150
		},
		"icon": "🛡️",
		"hidden": false
	},

	"battle_speed_run": {
		"id": "battle_speed_run",
		"name": "闪电战",
		"description": "在30秒内完成一场战斗",
		"category": "challenge",
		"reward": {
			"nano_materials": 120,
			"company_rep": {"aether_dynamics": 30}
		},
		"icon": "⚡",
		"hidden": false
	},

	# ==================== 收集成就 ====================

	"collection_cards_20": {
		"id": "collection_cards_20",
		"name": "收藏家",
		"description": "拥有20张不同的卡片",
		"category": "collection",
		"reward": {
			"nano_materials": 100
		},
		"icon": "📚",
		"hidden": false
	},

	"collection_cards_50": {
		"id": "collection_cards_50",
		"name": "卡片大师",
		"description": "拥有50张不同的卡片",
		"category": "collection",
		"reward": {
			"nano_materials": 300
		},
		"icon": "📖",
		"hidden": false
	},

	"collection_blueprints_10": {
		"id": "collection_blueprints_10",
		"name": "蓝图收集者",
		"description": "解锁10个不同的蓝图",
		"category": "collection",
		"reward": {
			"nano_materials": 150
		},
		"icon": "📋",
		"hidden": false
	},

	"collection_rare_card": {
		"id": "collection_rare_card",
		"name": "稀世珍宝",
		"description": "拥有5张稀有度以上的卡片",
		"category": "collection",
		"reward": {
			"nano_materials": 200
		},
		"icon": "💎",
		"hidden": false
	},

	"collection_legendary": {
		"id": "collection_legendary",
		"name": "传说猎手",
		"description": "拥有1张传说稀有度的卡片",
		"category": "collection",
		"reward": {
			"nano_materials": 400
		},
		"icon": "👑",
		"hidden": false
	},

	"collection_affix_10": {
		"id": "collection_affix_10",
		"name": "词条大师",
		"description": "为卡片添加总共10个词条",
		"category": "collection",
		"reward": {
			"nano_materials": 180,
			"company_rep": {"void_research": 40}
		},
		"icon": "✨",
		"hidden": false
	},

	# ==================== 进度成就 ====================

	"progress_level_20": {
		"id": "progress_level_20",
		"name": "突破中期",
		"description": "通关第20关（一战时代）",
		"category": "progress",
		"reward": {
			"nano_materials": 100
		},
		"icon": "🌟",
		"hidden": false
	},

	"progress_level_40": {
		"id": "progress_level_40",
		"name": "二战英雄",
		"description": "通关第40关（二战时代）",
		"category": "progress",
		"reward": {
			"nano_materials": 150
		},
		"icon": "🌟🌟",
		"hidden": false
	},

	"progress_level_60": {
		"id": "progress_level_60",
		"name": "冷战胜利",
		"description": "通关第60关（冷战时代）",
		"category": "progress",
		"reward": {
			"nano_materials": 200
		},
		"icon": "🌟🌟🌟",
		"hidden": false
	},

	"progress_level_80": {
		"id": "progress_level_80",
		"name": "现代主宰",
		"description": "通关第80关（现代时代）",
		"category": "progress",
		"reward": {
			"nano_materials": 250
		},
		"icon": "🌟🌟🌟🌟",
		"hidden": false
	},

	"progress_level_100": {
		"id": "progress_level_100",
		"name": "终极征服",
		"description": "通关第100关（未来时代）",
		"category": "progress",
		"reward": {
			"nano_materials": 1000
		},
		"icon": "🌟🌟🌟🌟🌟",
		"hidden": false
	},

	"progress_all_boss": {
		"id": "progress_all_boss",
		"name": "Boss征服者",
		"description": "击败所有5个时代的Boss关卡",
		"category": "challenge",
		"reward": {
			"nano_materials": 500
		},
		"icon": "👹",
		"hidden": false
	},

	"progress_all_era": {
		"id": "progress_all_era",
		"name": "时空穿越者",
		"description": "在所有5个时代都取得过胜利",
		"category": "progress",
		"reward": {
			"nano_materials": 300
		},
		"icon": "🌀",
		"hidden": false
	},

	# ==================== 势力成就 ====================

	"faction_max_rep": {
		"id": "faction_max_rep",
		"name": "势力领袖",
		"description": "与任意一个势力的声望达到50",
		"category": "progress",
		"reward": {
			"nano_materials": 200
		},
		"icon": "🤝",
		"hidden": false
	},

	"faction_all_20": {
		"id": "faction_all_20",
		"name": "各方势力",
		"description": "与所有7个势力的声望都达到20",
		"category": "challenge",
		"reward": {
			"nano_materials": 400
		},
		"icon": "🌐",
		"hidden": false
	},

	# ==================== 强化成就 ====================

	"enhance_card_10": {
		"id": "enhance_card_10",
		"name": "强化新手",
		"description": "将任意卡片强化到等级10",
		"category": "progress",
		"reward": {
			"nano_materials": 150,
			"company_rep": {"void_research": 30}
		},
		"icon": "📈",
		"hidden": false
	},

	"enhance_card_20": {
		"id": "enhance_card_20",
		"name": "强化大师",
		"description": "将任意卡片强化到等级20",
		"category": "challenge",
		"reward": {
			"nano_materials": 300
		},
		"icon": "📊",
		"hidden": false
	},

	"enhance_breakthrough": {
		"id": "enhance_breakthrough",
		"name": "突破极限",
		"description": "完成一次卡片突破（提升稀有度）",
		"category": "challenge",
		"reward": {
			"nano_materials": 250
		},
		"icon": "💥",
		"hidden": false
	},

	# ==================== 特殊成就 ====================

	"special_perfect_game": {
		"id": "special_perfect_game",
		"name": "完美游戏",
		"description": "在一场战斗中获得三星评价",
		"category": "challenge",
		"reward": {
			"nano_materials": 200
		},
		"icon": "⭐",
		"hidden": false
	},

	"special_speed_clear": {
		"id": "special_speed_clear",
		"name": "速通专家",
		"description": "在60秒内完成任意关卡",
		"category": "challenge",
		"reward": {
			"nano_materials": 180,
			"company_rep": {"nova_arms": 35}
		},
		"icon": "⏱️",
		"hidden": false
	},

	"special_survival": {
		"id": "special_survival",
		"name": "生存大师",
		"description": "在一场战斗中存活15个波次",
		"category": "challenge",
		"reward": {
			"nano_materials": 220
		},
		"icon": "❤️",
		"hidden": false
	}
}

## 获取所有成就
static func get_all_achievements() -> Array:
	return ACHIEVEMENTS.values()

## 根据ID获取成就
static func get_achievement(achievement_id: String) -> Dictionary:
	if ACHIEVEMENTS.has(achievement_id):
		return ACHIEVEMENTS[achievement_id]
	return {}

## 根据分类获取成就
static func get_achievements_by_category(category: String) -> Array:
	var result: Array = []
	for achievement in ACHIEVEMENTS.values():
		if achievement.get("category", "") == category:
			result.append(achievement)
	return result

## 获取成就总数
static func get_total_count() -> int:
	return ACHIEVEMENTS.size()

## 获取隐藏成就
static func get_hidden_achievements() -> Array:
	var result: Array = []
	for achievement in ACHIEVEMENTS.values():
		if achievement.get("hidden", false):
			result.append(achievement)
	return result
