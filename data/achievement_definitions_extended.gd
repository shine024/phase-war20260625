extends RefCounted
class_name AchievementDefinitions
## 扩展成就系统定义：包含100+成就，覆盖所有游戏内容

## 成就状态枚举
enum Status {
	LOCKED,     # 未解锁
	UNLOCKED,   # 已解锁但未完成
	PROGRESS,   # 进行中
	COMPLETED   # 已完成
}

## 成就稀有度
enum Rarity {
	COMMON,     # 普通 (绿色)
	UNCOMMON,   # 稀有 (蓝色)
	RARE,       # 罕见 (紫色)
	EPIC,       # 史诗 (橙色)
	LEGENDARY    # 传说 (红色)
}

## 成就定义表
const ACHIEVEMENTS: Dictionary = {
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

	# ==================== 收集成就 (25个) ====================
	"collect_blueprints_10": {
		"id": "collect_blueprints_10",
		"name": "收藏家起步",
		"description": "解锁10种不同的蓝图",
		"category": "collection",
		"rarity": "COMMON",
		"requirements": {"type": "unique_blueprints", "count": 10},
		"reward": {"nano_materials": 100},
		"icon": "📚",
		"hidden": false,
		"flavor_text": "知识的积累始于好奇心。"
	},
	"collect_blueprints_30": {
		"id": "collect_blueprints_30",
		"name": "蓝图收集者",
		"description": "解锁30种不同的蓝图",
		"category": "collection",
		"rarity": "UNCOMMON",
		"requirements": {"type": "unique_blueprints", "count": 30},
		"reward": {"nano_materials": 200, "blueprint_fragments": 5},
		"icon": "📐",
		"hidden": false,
		"flavor_text": "蓝图在手，天下我有。"
		},
	"collect_blueprints_50": {
		"id": "collect_blueprints_50",
		"name": "蓝图大师",
		"description": "解锁50种不同的蓝图",
		"category": "collection",
		"rarity": "RARE",
		"requirements": {"type": "unique_blueprints", "count": 50},
		"reward": {"nano_materials": 400, "blueprint_fragments": 10, "rare_card": 1},
		"icon": "🗺️",
		"hidden": false,
		"flavor_text": "你已经掌握了大部分蓝图奥秘。"
		},
	"collect_blueprints_80": {
		"id": "collect_blueprints_80",
		"name": "蓝图百科全书",
		"description": "解锁80种不同的蓝图",
		"category": "collection",
		"rarity": "EPIC",
		"requirements": {"type": "unique_blueprints", "count": 80},
		"reward": {"nano_materials": 800, "blueprint_fragments": 20, "mythic_card": 1},
		"icon": "📖",
		"hidden": false,
		"flavor_text": "你就是行走的蓝图百科全书。"
		},
	"collect_all_blueprints": {
		"id": "collect_all_blueprints",
		"name": "终极收藏家",
		"description": "解锁所有蓝图",
		"category": "collection",
		"rarity": "LEGENDARY",
		"requirements": {"type": "unique_blueprints", "count": 999},
		"reward": {"nano_materials": 10000, "blueprint_fragments": 100, "mythic_card": 5, "title": "终极收藏家"},
		"icon": "🏆",
		"hidden": false,
		"flavor_text": "没有任何蓝图能逃过你的收藏。"
		},
	"collect_common_complete": {
		"id": "collect_common_complete",
		"name": "普通大师",
		"description": "收集所有普通品质的蓝图",
		"category": "collection",
		"rarity": "RARE",
		"requirements": {"type": "all_common_blueprints"},
		"reward": {"nano_materials": 300, "blueprint_fragments": 8},
		"icon": "🟩",
		"hidden": false,
		"flavor_text": "普通并不平凡。"
		},
	"collect_rare_complete": {
		"id": "collect_rare_complete",
		"name": "稀有猎人",
		"description": "收集所有稀有品质的蓝图",
		"category": "collection",
		"rarity": "EPIC",
		"requirements": {"type": "all_rare_blueprints"},
		"reward": {"nano_materials": 600, "blueprint_fragments": 15, "rare_card": 1},
		"icon": "🟦",
		"hidden": false,
		"flavor_text": "稀有中的稀有。"
		},
	"collect_mythic_complete": {
		"id": "collect_mythic_complete",
		"name": "神话征服者",
		"description": "收集所有神话品质的蓝图",
		"category": "collection",
		"rarity": "LEGENDARY",
		"requirements": {"type": "all_mythic_blueprints"},
		"reward": {"nano_materials": 2000, "blueprint_fragments": 30, "mythic_card": 3, "title": "神话征服者"},
		"icon": "🟪",
		"hidden": false,
		"flavor_text": "神话在向你低头。"
		},
	"collect_cards_100": {
		"id": "collect_cards_100",
		"name": "卡牌收藏家",
		"description": "拥有100张卡牌（包括重复）",
		"category": "collection",
		"rarity": "COMMON",
		"requirements": {"type": "total_cards", "count": 100},
		"reward": {"nano_materials": 150},
		"icon": "🃏",
		"hidden": false,
		"flavor_text": "卡牌就是力量。"
		},
	"collect_cards_500": {
		"id": "collect_cards_500",
		"name": "卡牌大亨",
		"description": "拥有500张卡牌（包括重复）",
		"category": "collection",
		"rarity": "UNCOMMON",
		"requirements": {"type": "total_cards", "count": 500},
		"reward": {"nano_materials": 300, "blueprint_fragments": 6},
		"icon": "🎴",
		"hidden": false,
		"flavor_text": "你的卡牌收藏令人印象深刻。"
		},
	"collect_max_rarity": {
		"id": "collect_max_rarity",
		"name": "品质追求",
		"description": "拥有一张最高品质的卡牌",
		"category": "collection",
		"rarity": "UNCOMMON",
		"requirements": {"type": "max_rarity_card"},
		"reward": {"nano_materials": 120},
		"icon": "💎",
		"hidden": false,
		"flavor_text": "品质就是一切。"
		},

	# ==================== 关卡成就 (20个) ====================
	"progress_level_10": {
		"id": "progress_level_10",
		"name": "初次征程",
		"description": "到达第10关",
		"category": "progress",
		"rarity": "COMMON",
		"requirements": {"type": "max_level", "count": 10},
		"reward": {"nano_materials": 80},
		"icon": "🚩",
		"hidden": false,
		"flavor_text": "战争刚刚开始。"
		},
	"progress_level_25": {
		"id": "progress_level_25",
		"name": "战线推进",
		"description": "到达第25关",
		"category": "progress",
		"rarity": "UNCOMMON",
		"requirements": {"type": "max_level", "count": 25},
		"reward": {"nano_materials": 200},
		"icon": "⛺",
		"hidden": false,
		"flavor_text": "战线正在推进。"
		},
	"progress_level_50": {
		"id": "progress_level_50",
		"name": "战场老将",
		"description": "到达第50关",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "max_level", "count": 50},
		"reward": {"nano_materials": 400, "blueprint_fragments": 8},
		"icon": "🏰",
		"hidden": false,
		"flavor_text": "你已经是一名经验丰富的指挥官。"
		},
	"progress_level_75": {
		"id": "progress_level_75",
		"name": "战争专家",
		"description": "到达第75关",
		"category": "progress",
		"rarity": "EPIC",
		"requirements": {"type": "max_level", "count": 75},
		"reward": {"nano_materials": 800, "blueprint_fragments": 16, "rare_card": 1},
		"icon": "🎖️",
		"hidden": false,
		"flavor_text": "战争的每一个细节你都了如指掌。"
		},
	"progress_level_100": {
		"id": "progress_level_100",
		"name": "战争之王",
		"description": "到达第100关（最终关卡）",
		"category": "progress",
		"rarity": "LEGENDARY",
		"requirements": {"type": "max_level", "count": 100},
		"reward": {"nano_materials": 5000, "blueprint_fragments": 50, "mythic_card": 5, "title": "战争之王"},
		"icon": "👑",
		"hidden": false,
		"flavor_text": "你已经成为战争的主宰。"
		},
	"progress_all_ww1_levels": {
		"id": "progress_all_ww1_levels",
		"name": "一战老兵",
		"description": "完成所有一战时代关卡",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "complete_era", "era": "ww1"},
		"reward": {"nano_materials": 300, "blueprint_fragments": 6},
		"icon": "🪖",
		"hidden": false,
		"flavor_text": "一战的历史你已经完全掌握。"
		},
	"progress_all_ww2_levels": {
		"id": "progress_all_ww2_levels",
		"name": "二战英雄",
		"description": "完成所有二战时代关卡",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "complete_era", "era": "ww2"},
		"reward": {"nano_materials": 300, "blueprint_fragments": 6},
		"icon": "✈️",
		"hidden": false,
		"flavor_text": "二战的荣耀属于你。"
		},
	"progress_all_cold_levels": {
		"id": "progress_all_cold_levels",
		"name": "冷战战士",
		"description": "完成所有冷战时代关卡",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "complete_era", "era": "cold"},
		"reward": {"nano_materials": 300, "blueprint_fragments": 6},
		"icon": "☢",
		"hidden": false,
		"flavor_text": "冷战的硝烟你已经散去。"
		},
	"progress_all_modern_levels": {
		"id": "progress_all_modern_levels",
		"name": "现代指挥官",
		"description": "完成所有现代时代关卡",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "complete_era", "era": "modern"},
		"reward": {"nano_materials": 300, "blueprint_fragments": 6},
		"icon": "🚀",
		"hidden": false,
		"flavor_text": "现代战争你已经游刃有余。"
		},
	"progress_all_future_levels": {
		"id": "progress_all_future_levels",
		"name": "未来先锋",
		"description": "完成所有近未来时代关卡",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "complete_era", "era": "future"},
		"reward": {"nano_materials": 300, "blueprint_fragments": 6},
		"icon": "⚡",
		"hidden": false,
		"flavor_text": "未来的战争你也已征服。"
		},
	"progress_perfect_all_levels": {
		"id": "progress_perfect_all_levels",
		"name": "完美征服者",
		"description": "以3星评价通过所有关卡",
		"category": "progress",
		"rarity": "LEGENDARY",
		"requirements": {"type": "all_3_stars"},
		"reward": {"nano_materials": 10000, "blueprint_fragments": 100, "mythic_card": 10, "title": "完美征服者"},
		"icon": "⭐",
		"hidden": false,
		"flavor_text": "完美的征服，完美的荣耀。"
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

	# ==================== 系统成就 (10个) ====================
	"system_first_save": {
		"id": "system_first_save",
		"name": "谨慎的开始",
		"description": "第一次保存游戏",
		"category": "system",
		"rarity": "COMMON",
		"requirements": {"type": "save_count", "count": 1},
		"reward": {"nano_materials": 50},
		"icon": "💾",
		"hidden": false,
		"flavor_text": "好的开始是成功的一半。"
		},
	"system_save_100": {
		"id": "system_save_100",
		"name": "存档达人",
		"description": "累计保存游戏100次",
		"category": "system",
		"rarity": "UNCOMMON",
		"requirements": {"type": "save_count", "count": 100},
		"reward": {"nano_materials": 200},
		"icon": "📁",
		"hidden": false,
		"flavor_text": "你总是记得保存进度。"
		},
	"system_play_time_10h": {
		"id": "system_play_time_10h",
		"name": "战争狂热",
		"description": "累计游戏时间达到10小时",
		"category": "system",
		"rarity": "COMMON",
		"requirements": {"type": "play_time_hours", "count": 10},
		"reward": {"nano_materials": 150},
		"icon": "⏰",
		"hidden": false,
		"flavor_text": "你对战争的热情令人敬佩。"
		},
	"system_play_time_100h": {
		"id": "system_play_time_100h",
		"name": "战争终身",
		"description": "累计游戏时间达到100小时",
		"category": "system",
		"rarity": "RARE",
		"requirements": {"type": "play_time_hours", "count": 100},
		"reward": {"nano_materials": 800, "blueprint_fragments": 15},
		"icon": "⌛",
		"hidden": false,
		"flavor_text": "战争已经成为你生活的一部分。"
	},
	"system_enhancement_50": {
		"id": "system_enhancement_50",
		"name": "强化专家",
		"description": "累计进行50次卡牌强化",
		"category": "system",
		"rarity": "UNCOMMON",
		"requirements": {"type": "enhancement_count", "count": 50},
		"reward": {"nano_materials": 200},
		"icon": "🔧",
		"hidden": false,
		"flavor_text": "强化让你的卡牌更加强大。"
		},
	"system_shop_purchase_100": {
		"id": "system_shop_purchase_100",
		"name": "购物狂",
		"description": "在商店累计购买100次物品",
		"category": "system",
		"rarity": "COMMON",
		"requirements": {"type": "shop_purchases", "count": 100},
		"reward": {"nano_materials": 180},
		"icon": "🛒",
		"hidden": false,
		"flavor_text": "购物也是战争的一部分。"
		},

	# ==================== 特殊成就 (10个) ====================
	"special_hidden_1": {
		"id": "special_hidden_1",
		"name": "秘密发现者",
		"description": "发现一个隐藏的彩蛋",
		"category": "special",
		"rarity": "RARE",
		"requirements": {"type": "find_easter_egg", "id": "secret_1"},
		"reward": {"nano_materials": 500, "blueprint_fragments": 5},
		"icon": "🥚",
		"hidden": true,
		"flavor_text": "你发现了开发者埋藏的秘密。"
		},
	"special_nano_millionaire": {
		"id": "special_nano_millionaire",
		"name": "纳米百万富翁",
		"description": "拥有100万纳米材料",
		"category": "special",
		"rarity": "EPIC",
		"requirements": {"type": "nano_materials", "amount": 1000000},
		"reward": {"blueprint_fragments": 20, "mythic_card": 1, "title": "纳米大亨"},
		"icon": "💰",
		"hidden": false,
		"flavor_text": "财富已经不再是问题。"
		},
	"special_defeat_ultimate_boss": {
		"id": "special_defeat_ultimate_boss",
		"name": "终极胜利",
		"description": "击败奥米伽相位师",
		"category": "special",
		"rarity": "LEGENDARY",
		"requirements": {"type": "defeat_boss", "boss_id": "enemy_master_030"},
		"reward": {"nano_materials": 10000, "blueprint_fragments": 100, "mythic_card": 10, "title": "世界拯救者"},
		"icon": "🌟",
		"hidden": false,
		"flavor_text": "你拯救了世界，成为真正的传奇。"
		},
	"special_perfect_collection": {
		"id": "special_perfect_collection",
		"name": "完美收藏",
		"description": "拥有所有传说级卡牌的满强化版本",
			"category": "special",
		"rarity": "LEGENDARY",
		"requirements": {"type": "perfect_mythic_collection"},
		"reward": {"nano_materials": 15000, "blueprint_fragments": 200, "mythic_card": 15, "title": "完美收藏家"},
		"icon": "👑",
		"hidden": false,
		"flavor_text": "你已经达到了收集的终极境界。"
		},
	"special_speed_demon": {
		"id": "special_speed_demon",
		"name": "速度恶魔",
		"description": "在30秒内赢得一场战斗",
		"category": "special",
		"rarity": "EPIC",
		"requirements": {"type": "ultra_fast_win", "seconds": 30},
		reward": {"nano_materials": 700, "blueprint_fragments": 14},
		"icon": "💨",
		"hidden": false,
		"flavor_text": "你的速度快得不可思议。"
		},
	"special_pacifist": {
		"id": "special_pacifist",
		"name": "和平主义者",
		"description": "在一场战斗中不击杀任何敌方单位获得胜利",
		"category": "special",
		"rarity": "EPIC",
		"requirements": {"type": "pacifist_win"},
		"reward": {"nano_materials": 600, "blueprint_fragments": 12},
		"icon": "☮️",
		"hidden": false,
		"flavor_text": "和平是最强的武器。"
		},
	"special_all_factions_max": {
		"id": "special_all_factions_max",
		"name": "势力领袖",
		"description": "与所有7个势力都达到最高声望等级",
		"category": "special",
		"rarity": "LEGENDARY",
		"requirements": {"type": "all_factions_max_reputation"},
		"reward": {"nano_materials": 8000, "blueprint_fragments": 80, "mythic_card": 8, "title": "势力领袖"},
		"icon": "🎖️",
		"hidden": false,
		"flavor_text": "所有势力都对你心悦诚服。"
		}
}

## 获取成就定义
static func get_achievement(achievement_id: String) -> Dictionary:
	if ACHIEVEMENTS.has(achievement_id):
		return ACHIEVEMENTS[achievement_id]
	return {}

## 获取分类成就
static func get_achievements_by_category(category: String) -> Array:
	var result = []
	for achievement_id in ACHIEVEMENTS:
		var achievement = ACHIEVEMENTS[achievement_id]
		if achievement.get("category", "") == category:
			result.append(achievement)
	return result

## 获取稀有度成就
static func get_achievements_by_rarity(rarity: String) -> Array:
	var	result = []
	for achievement_id in ACHIEVEMENTS:
		var achievement = ACHIEVEMENTS[achievement_id]
		if achievement.get("rarity", "") == rarity:
			result.append(achievement)
	return result

## 获取隐藏成就
static func get_hidden_achievements() -> Array:
	var result = []
	for achievement_id in ACHIEVEMENTS:
		var achievement = ACHIEVEMENTS[achievement_id]
		if achievement.get("hidden", false):
			result.append(achievement)
	return result

## 获取可见成就
static func get_visible_achievements() -> Array:
	var result = []
	for achievement_id in ACHIEVEMENTS:
		var achievement = ACHIEVEMENTS[achievement_id]
		if not achievement.get("hidden", false):
			result.append(achievement)
	return result

## 检查成就完成条件
static func check_achievement_requirements(achievement_id: String, player_data: Dictionary) -> Dictionary:
	var achievement = get_achievement(achievement_id)
	if achievement.is_empty():
		return {"completed": false, "progress": 0, "total": 0}

	var requirements = achievement.get("requirements", {})
	var requirement_type = requirements.get("type", "")
	var requirement_count = requirements.get("count", 1)
	var current_progress = 0
	var completed = false

	match requirement_type:
		"wins":
			current_progress = player_data.get("total_wins", 0)
			completed = current_progress >= requirement_count
		"kills":
			current_progress = player_data.get("total_kills", 0)
			completed = current_progress >= requirement_count
		"total_damage":
			current_progress = player_data.get("total_damage_dealt", 0)
			completed = current_progress >= requirement_count
		"no_damage_win":
			current_progress = player_data.get("no_damage_wins", 0)
			completed = current_progress >= requirement_count
		"fast_win":
			# 需要具体实现检查
			completed = false
		"win_streak":
			current_progress = player_data.get("current_win_streak", 0)
			completed = current_progress >= requirement_count
		"unique_blueprints":
			current_progress = player_data.get("unique_blueprints", []).size()
			completed = current_progress >= requirement_count
		"max_level":
			current_progress = player_data.get("max_level_reached", 1)
			completed = current_progress >= requirement_count
		"complete_era":
			var era = requirements.get("era", "")
			current_progress = player_data.get("completed_eras", {}).get(era, 0)
			completed = current_progress > 0
		"all_3_stars":
			# 需要检查所有关卡是否都是3星
			completed = false
		"survival_waves":
			current_progress = player_data.get("max_survival_waves", 0)
			completed = current_progress >= requirement_count
		"defeat_all_masters":
			current_progress = player_data.get("defeated_masters", []).size()
			completed = current_progress >= requirement_count
		_:
			completed = false
			current_progress = 0

	return {
		"completed": completed,
		"progress": current_progress,
		"total": requirement_count,
		"percentage": float(current_progress) / float(requirement_count) if requirement_count > 0 else 1.0
	}

## 获取成就奖励
static func get_achievement_rewards(achievement_id: String) -> Dictionary:
	var achievement = get_achievement(achievement_id)
	if achievement.is_empty():
		return {}
	return achievement.get("reward", {})

## 格式化成就进度
static func format_achievement_progress(achievement_id: String, current: int, total: int) -> String:
	var achievement = get_achievement(achievement_id)
	if achievement.is_empty():
		return ""

	var name = achievement.get("name", "")
	var requirement_type = achievement.get("requirements", {}).get("type", "")

	match requirement_type:
		"wins":
			return "%s: %d/%d 场胜利" % [name, current, total]
		"kills":
			return "%s: %d/%d 击杀" % [name, current, total]
		"total_damage":
			var damage_str = str(current) if current < 1000 else str(current / 1000) + "k"
			return "%s: %s/%s 伤害" % [name, damage_str, str(total / 1000) + "k"]
		"unique_blueprints":
			return "%s: %d/%d 蓝图" % [name, current, total]
		"max_level":
			return "%s: 第%d/%d 关" % [name, current, total]
		"survival_waves":
			return "%s: %d/%d 波" % [name, current, total]
		_:
			return "%s: %d/%d" % [name, current, total]