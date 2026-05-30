## 关卡 + 系统 + 特殊成就数据
## 由 achievement_definitions_extended.gd 拆分而来
extends RefCounted
class_name AchievementsSpecial

const DATA: Dictionary = {
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

