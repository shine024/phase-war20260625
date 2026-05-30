## 战斗成就 + 挑战成就数据
## 由 achievement_definitions_extended.gd 拆分而来
extends RefCounted
class_name AchievementsCombat

const DATA: Dictionary = {
	# ==================== 战斗成就 (30个) ====================

	# 基础战斗成就
	"battle_first_win": {
		"id": "battle_first_win",
		"name": "初露锋芒",
		"description": "赢得你的第一场战斗胜利",
		"category": "battle",
		"rarity": "COMMON",
		"requirements": {"type": "wins", "count": 1},
		"reward": {"nano_materials": 50, "xp": 100},
		"icon": "⚔️",
		"hidden": false,
		"flavor_text": "千里之行，始于足下。"
	},
	"battle_wins_10": {
		"id": "battle_wins_10",
		"name": "百战老兵",
		"description": "累计赢得10场战斗",
		"category": "battle",
		"rarity": "COMMON",
		"requirements": {"type": "wins", "count": 10},
		"reward": {"nano_materials": 100, "blueprint_fragments": 2},
		"icon": "🎖️",
		"hidden": false,
		"flavor_text": "胜利会成为习惯。"
	},
	"battle_wins_50": {
		"id": "battle_wins_50",
		"name": "战场传奇",
		"description": "累计赢得50场战斗",
		"category": "battle",
		"rarity": "UNCOMMON",
		"requirements": {"type": "wins", "count": 50},
		"reward": {"nano_materials": 300, "blueprint_fragments": 5},
		"icon": "🏆",
		"hidden": false,
		"flavor_text": "战场是最好的老师。"
	},
	"battle_wins_100": {
		"id": "battle_wins_100",
		"name": "战争大师",
		"description": "累计赢得100场战斗",
		"category": "battle",
		"rarity": "RARE",
		"requirements": {"type": "wins", "count": 100},
		"reward": {"nano_materials": 500, "blueprint_fragments": 10, "rare_card": 1},
		"icon": "👑",
		"hidden": false,
		"flavor_text": "战争已经融入你的血液。"
	},
	"battle_wins_500": {
		"id": "battle_wins_500",
		"name": "不朽战神",
		"description": "累计赢得500场战斗",
		"category": "battle",
		"rarity": "EPIC",
		"requirements": {"type": "wins", "count": 500},
		"reward": {"nano_materials": 2000, "blueprint_fragments": 20, "mythic_card": 1},
		"icon": "🌟",
		"hidden": false,
		"flavor_text": "你的名字将载入史册。"
	},
	"battle_kills_100": {
		"id": "battle_kills_100",
		"name": "收割者",
		"description": "累计击毁100个敌方单位",
		"category": "battle",
		"rarity": "COMMON",
		"requirements": {"type": "kills", "count": 100},
		"reward": {"nano_materials": 150},
		"icon": "💀",
		"hidden": false,
		"flavor_text": "每一次击倒都是胜利的前奏。"
	},
	"battle_kills_500": {
		"id": "battle_kills_500",
		"name": "战场主宰",
		"description": "累计击毁500个敌方单位",
		"category": "battle",
		"rarity": "UNCOMMON",
		"requirements": {"type": "kills", "count": 500},
		"reward": {"nano_materials": 400},
		"icon": "☠️",
		"hidden": false,
		"flavor_text": "战场上无人能挡。"
	},
	"battle_kills_1000": {
		"id": "battle_kills_1000",
		"name": "毁灭者",
		"description": "累计击毁1000个敌方单位",
		"category": "battle",
		"rarity": "RARE",
		"requirements": {"type": "kills", "count": 1000},
		"reward": {"nano_materials": 800, "blueprint_fragments": 5},
		"icon": "💥",
		"hidden": false,
		"flavor_text": "毁灭是你的第二名字。"
	},
	"battle_kills_5000": {
		"id": "battle_kills_5000",
		"name": "末日收割者",
		"description": "累计击毁5000个敌方单位",
		"category": "battle",
		"rarity": "EPIC",
		"requirements": {"type": "kills", "count": 5000},
		"reward": {"nano_materials": 3000, "blueprint_fragments": 15, "mythic_card": 1},
		"icon": "🔱",
		"hidden": false,
		"flavor_text": "你就是行走的末日。"
	},
	"battle_damage_dealt_100k": {
		"id": "battle_damage_dealt_100k",
		"name": "破坏者",
		"description": "累计造成10万点伤害",
		"category": "battle",
		"rarity": "UNCOMMON",
		"requirements": {"type": "total_damage", "count": 100000},
		"reward": {"nano_materials": 200},
		"icon": "🔨",
		"hidden": false,
		"flavor_text": "每一分伤害都算数。"
	},
	"battle_damage_dealt_1m": {
		"id": "battle_damage_dealt_1m",
		"name": "拆迁专家",
		"description": "累计造成100万点伤害",
		"category": "battle",
		"rarity": "RARE",
		"requirements": {"type": "total_damage", "count": 1000000},
		"reward": {"nano_materials": 500, "blueprint_fragments": 8},
		"icon": "💎",
		"hidden": false,
		"flavor_text": "破坏是你的艺术。"
	},
	"battle_no_damage_win": {
		"id": "battle_no_damage_win",
		"name": "完美战役",
		"description": "在一场战斗中不受到任何伤害并获得胜利",
		"category": "challenge",
		"rarity": "RARE",
		"requirements": {"type": "no_damage_win", "count": 1},
		"reward": {"nano_materials": 200, "blueprint_fragments": 3},
		"icon": "🛡️",
		"hidden": false,
		"flavor_text": "完美的胜利，无瑕的战役。"
		},
	"battle_no_damage_wins_10": {
		"id": "battle_no_damage_wins_10",
		"name": "不可触碰",
		"description": "累计10场无伤胜利",
		"category": "challenge",
		"rarity": "EPIC",
		"requirements": {"type": "no_damage_win", "count": 10},
		"reward": {"nano_materials": 1000, "blueprint_fragments": 10, "rare_card": 1},
		"icon": "✨",
		"hidden": false,
		"flavor_text": "你的操作已经超越了凡人。"
		},
	"battle_speed_run_3min": {
		"id": "battle_speed_run_3min",
		"name": "速战速决",
		"description": "在3分钟内赢得一场战斗",
		"category": "challenge",
		"rarity": "UNCOMMON",
		"requirements": {"type": "fast_win", "seconds": 180},
		"reward": {"nano_materials": 150},
		"icon": "⚡",
		"hidden": false,
		"flavor_text": "时间就是生命。"
		},
	"battle_speed_run_1min": {
		"id": "battle_speed_run_1min",
		"name": "闪电战",
		"description": "在1分钟内赢得一场战斗",
		"category": "challenge",
		"rarity": "RARE",
		"requirements": {"type": "fast_win", "seconds": 60},
		"reward": {"nano_materials": 300, "blueprint_fragments": 5},
		"icon": "🌩",
		"hidden": false,
		"flavor_text": "闪电般的速度，雷霆般的打击。"
		},
	"battle_win_streak_5": {
		"id": "battle_win_streak_5",
		"name": "连胜达人",
		"description": "连续赢得5场战斗",
		"category": "battle",
		"rarity": "UNCOMMON",
		"requirements": {"type": "win_streak", "count": 5},
		"reward": {"nano_materials": 180},
		"icon": "🔥",
		"hidden": false,
		"flavor_text": "胜利的势头不可阻挡。"
		},
	"battle_win_streak_20": {
		"id": "battle_win_streak_20",
		"name": "常胜将军",
		"description": "连续赢得20场战斗",
		"category": "battle",
		"rarity": "EPIC",
		"requirements": {"type": "win_streak", "count": 20},
		"reward": {"nano_materials": 800, "blueprint_fragments": 12, "rare_card": 1},
		"icon": "👑",
		"hidden": false,
		"flavor_text": "你已经习惯了胜利的滋味。"
		},
	"battle_kill_master_all": {
		"id": "battle_kill_master_all",
		"name": "相位师终结者",
		"description": "击败所有30位敌方相位师",
		"category": "challenge",
		"rarity": "LEGENDARY",
		"requirements": {"type": "defeat_all_masters", "count": 30},
		"reward": {"nano_materials": 5000, "blueprint_fragments": 50, "mythic_card": 3, "title": "相位师终结者"},
		"icon": "🏅",
		"hidden": false,
		"flavor_text": "没有任何相位师能逃过你的手掌。"
		},

	
	# ==================== 挑战成就 (15个) ====================
	"challenge_survival_20_waves": {
		"id": "challenge_survival_20_waves",
		"name": "生存专家",
		"description": "在生存模式中坚持20波",
		"category": "challenge",
		"rarity": "RARE",
		"requirements": {"type": "survival_waves", "count": 20},
		"reward": {"nano_materials": 400, "blueprint_fragments": 8},
		"icon": "🛡️",
		"hidden": false,
		"flavor_text": "生存是最基本的技能。"
		},
	"challenge_survival_50_waves": {
		"id": "challenge_survival_50_waves",
		"name": "生存大师",
			"description": "在生存模式中坚持50波",
		"category": "challenge",
		"rarity": "EPIC",
		"requirements": {"type": "survival_waves", "count": 50},
		"reward": {"nano_materials": 800, "blueprint_fragments": 16, "rare_card": 1},
		"icon": "🏰",
		"hidden": false,
		"flavor_text": "没有任何波浪能击倒你。"
		},
	"challenge_survival_100_waves": {
		"id": "challenge_survival_100_waves",
		"name": "不朽生存者",
		"description": "在生存模式中坚持100波",
		"category": "challenge",
		"rarity": "LEGENDARY",
		"requirements": {"type": "survival_waves", "count": 100},
		"reward": {"nano_materials": 2000, "blueprint_fragments": 30, "mythic_card": 2, "title": "不朽生存者"},
		"icon": "♾️",
		"hidden": false,
		"flavor_text": "你就是生存的代名词。"
		},
	"challenge_boss_rush_all": {
		"id": "challenge_boss_rush_all",
		"name": "Boss杀手",
		"description": "击败所有Boss连战中的Boss",
		"category": "challenge",
		"rarity": "EPIC",
		"requirements": {"type": "defeat_all_bosses"},
		"reward": {"nano_materials": 1000, "blueprint_fragments": 20, "rare_card": 2},
		"icon": "👹",
		"hidden": false,
		"flavor_text": "没有任何Boss能幸存。"
		},
	"challenge_time_attack_100_kills": {
		"id": "challenge_time_attack_100_kills",
		"name": "速度与激情",
		"description": "在限时挑战中击杀100个敌人",
		"category": "challenge",
		"rarity": "UNCOMMON",
		"requirements": {"type": "time_attack_kills", "count": 100},
		"reward": {"nano_materials": 200},
		"icon": "⏱️",
		"hidden": false,
		"flavor_text": "速度和激情缺一不可。"
		},
	"challenge_no_loss_complete": {
		"id": "challenge_no_loss_complete",
		"name": "完美主义者",
		"description": "在无损挑战中完成10场战斗",
		"category": "challenge",
		"rarity": "EPIC",
		"requirements": {"type": "no_loss_wins", "count": 10},
		"reward": {"nano_materials": 600, "blueprint_fragments": 12, "rare_card": 1},
		"icon": "🎯",
		"hidden": false,
		"flavor_text": "完美就是你的标准。"
		},
	"challenge_max_damage_1m": {
		"id": "challenge_max_damage_1m",
		"name": "伤害极限",
		"description": "在最大伤害挑战中造成100万伤害",
		"category": "challenge",
		"rarity": "RARE",
		"requirements": {"type": "max_damage_challenge", "damage": 1000000},
		"reward": {"nano_materials": 500, "blueprint_fragments": 10},
		"icon": "💪",
		"hidden": false,
		"flavor_text": "伤害没有上限。"
		},
	"challenge_random_deck_win_10": {
		"id": "challenge_random_deck_win_10",
		"name": "随机应变",
		"description": "在随机卡组挑战中连胜10场",
		"category": "challenge",
		"rarity": "UNCOMMON",
		"requirements": {"type": "random_deck_wins", "count": 10},
		"reward": {"nano_materials": 250},
		"icon": "🎲",
		"hidden": false,
		"flavor_text": "任何情况都能应对。"
		},
}
