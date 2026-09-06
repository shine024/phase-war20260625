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
		"requirements": {
			"type": "wins", "count": 1
		},
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
		"requirements": {
			"type": "wins", "count": 10
		},
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
		"requirements": {
			"type": "wins", "count": 50
		},
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
		"requirements": {
			"type": "kills", "count": 100
		},
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
		"requirements": {
			"type": "kills", "count": 500
		},
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
		"requirements": {
			"type": "no_damage_wins", "count": 1
		},
		"reward": {
			"nano_materials": 150
		},
		"icon": "🛡️",
		"hidden": false
	},

	"battle_speed_run": {
		"id": "battle_speed_run",
		"name": "闪电战",
		"description": "在 180 秒内完成任意关卡",
		"category": "challenge",
		"requirements": {
			"type": "fast_wins", "count": 1
		},
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
		"requirements": {
			"type": "unique_cards", "count": 20
		},
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
		"requirements": {
			"type": "unique_cards", "count": 50
		},
		"reward": {
			"nano_materials": 300
		},
		"icon": "📖",
		"hidden": false
	},

	"collection_blueprints_10": {
		"id": "collection_blueprints_10",
		"name": "卡牌收集者",
		"description": "收集10种不同的卡牌",
		"category": "collection",
		"requirements": {
			"type": "unique_blueprints", "count": 10
		},
		"reward": {
			"nano_materials": 150
		},
		"icon": "📋",
		"hidden": false
	},

	"collection_rare_card": {
		"id": "collection_rare_card",
		"name": "稀世珍宝",
		"description": "获得一张稀有品质卡牌",
		"category": "collection",
		"requirements": {
			"type": "rarity_collection", "target": "rare", "rarity_count": 1
		},
		"reward": {
			"nano_materials": 200
		},
		"icon": "💎",
		"hidden": false
	},

	"collection_legendary": {
		"id": "collection_legendary",
		"name": "传说猎手",
		"description": "获得一张传说品质卡牌",
		"category": "collection",
		"requirements": {
			"type": "rarity_collection", "target": "legendary", "rarity_count": 1
		},
		"reward": {
			"nano_materials": 400
		},
		"icon": "👑",
		"hidden": false
	},

	"collection_affix_10": {
		"id": "collection_affix_10",
		"name": "改造入门",
		"description": "为卡牌累计安装 5 条改造模块",
		"category": "collection",
		"requirements": {
			"type": "enhancement_operations", "count": 5
		},
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
		"requirements": {
			"type": "max_level", "count": 20
		},
		"reward": {
			"nano_materials": 100,
			"type": "card", "card_id": "guardian_ww1_ironclad", "amount": 1
		},
		"icon": "🌟",
		"hidden": false
	},

	"progress_level_40": {
		"id": "progress_level_40",
		"name": "二战英雄",
		"description": "通关第40关（二战时代）",
		"category": "progress",
		"requirements": {
			"type": "max_level", "count": 40
		},
		"reward": {
			"nano_materials": 150,
			"type": "card", "card_id": "guardian_ww2_blitzkrieg", "amount": 1
		},
		"icon": "🌟🌟",
		"hidden": false
	},

	"progress_level_60": {
		"id": "progress_level_60",
		"name": "冷战胜利",
		"description": "通关第60关（冷战时代）",
		"category": "progress",
		"requirements": {
			"type": "max_level", "count": 60
		},
		"reward": {
			"nano_materials": 200,
			"type": "card", "card_id": "guardian_cold_thunder", "amount": 1
		},
		"icon": "🌟🌟🌟",
		"hidden": false
	},

	"progress_level_80": {
		"id": "progress_level_80",
		"name": "现代主宰",
		"description": "通关第80关（现代时代）",
		"category": "progress",
		"requirements": {
			"type": "max_level", "count": 80
		},
		"reward": {
			"nano_materials": 250,
			"type": "card", "card_id": "guardian_modern_stealth", "amount": 1
		},
		"icon": "🌟🌟🌟🌟",
		"hidden": false
	},

	"progress_level_100": {
		"id": "progress_level_100",
		"name": "终极征服",
		"description": "通关第100关（近未来时代）",
		"category": "progress",
		"requirements": {
			"type": "max_level", "count": 100
		},
		"reward": {
			"nano_materials": 1000,
			"type": "card", "card_id": "guardian_future_omega", "amount": 1
		},
		"icon": "🌟🌟🌟🌟🌟",
		"hidden": false
	},

	"progress_all_boss": {
		"id": "progress_all_boss",
		"name": "相位师克星",
		"description": "击败任意驻守相位师",
		"category": "challenge",
		"requirements": {
			"type": "defeat_master", "target": "enemy_master_005", "count": 1
		},
		"reward": {
			"nano_materials": 500,
			"type": "mod_blueprint", "mod_blueprint_id": "gen_11_phase_resonance", "amount": 1
		},
		"icon": "👹",
		"hidden": false
	},

	"progress_all_era": {
		"id": "progress_all_era",
		"name": "时空穿越者",
		"description": "通关第 100 关（相位界终点）",
		"category": "progress",
		"requirements": {
			"type": "complete_era", "target": "era4"
		},
		"reward": {
			"nano_materials": 300
		},
		"icon": "🌀",
		"hidden": false
	},

	# ==================== 势力成就 ====================

	"faction_max_rep": {
		"id": "faction_max_rep",
		"name": "后勤大师",
		"description": "在商店累计购买 10 次",
		"category": "progress",
		"requirements": {
			"type": "shop_purchases", "count": 10
		},
		"reward": {
			"nano_materials": 200
		},
		"icon": "🤝",
		"hidden": false
	},

	"faction_all_20": {
		"id": "faction_all_20",
		"name": "连战连捷",
		"description": "累计获胜 20 场",
		"category": "challenge",
		"requirements": {
			"type": "wins", "count": 20
		},
		"reward": {
			"nano_materials": 400
		},
		"icon": "🌐",
		"hidden": false
	},

	# ==================== 强化成就 ====================

	"enhance_card_10": {
		"id": "enhance_card_10",
		"name": "改造熟练",
		"description": "为卡牌累计安装 10 条改造模块",
		"category": "progress",
		"requirements": {
			"type": "enhancement_operations", "count": 105
		},
		"reward": {
			"nano_materials": 150,
			"company_rep": {"void_research": 30}
		},
		"icon": "📈",
		"hidden": false
	},

	"enhance_card_20": {
		"id": "enhance_card_20",
		"name": "改造大师",
		"description": "为卡牌累计安装 15 条改造模块",
		"category": "challenge",
		"requirements": {
			"type": "enhancement_operations", "count": 15
		},
		"reward": {
			"nano_materials": 300
		},
		"icon": "📊",
		"hidden": false
	},

	"enhance_breakthrough": {
		"id": "enhance_breakthrough",
		"name": "史诗战力",
		"description": "获得一张史诗品质卡牌",
		"category": "challenge",
		"requirements": {
			"type": "rarity_collection", "target": "epic", "rarity_count": 1
		},
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
		"requirements": {
			"type": "perfect_levels", "count": 1
		},
		"reward": {
			"nano_materials": 200
		},
		"icon": "⭐",
		"hidden": false
	},

	"special_speed_clear": {
		"id": "special_speed_clear",
		"name": "速通大师",
		"description": "累计 5 次快速取胜（180 秒内）",
		"category": "challenge",
		"requirements": {
			"type": "fast_wins", "count": 5
		},
		"reward": {
			"nano_materials": 180,
			"company_rep": {"nova_arms": 35}
		},
		"icon": "⏱️",
		"hidden": false
	},

	"special_survival": {
		"id": "special_survival",
		"name": "五连胜",
		"description": "取得 5 连胜",
		"category": "challenge",
		"requirements": {
			"type": "max_win_streak", "count": 5
		},
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
