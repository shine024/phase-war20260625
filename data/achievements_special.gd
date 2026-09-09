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
		"reward": {"nano_materials": 400},
		"icon": "🏰",
		"hidden": false,
		"flavor_text": "你已经是一名经验丰富的相位师。"
		},
	"progress_level_75": {
		"id": "progress_level_75",
		"name": "战争专家",
		"description": "到达第75关",
		"category": "progress",
		"rarity": "EPIC",
		"requirements": {"type": "max_level", "count": 75},
		"reward": {"nano_materials": 800, "rare_card": 1},
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
		"reward": {"nano_materials": 5000, "mythic_card": 5, "title": "战争之王"},
		"icon": "👑",
		"hidden": false,
		"flavor_text": "第 100 关已在身后。黑门，近了。"
		},
	"progress_all_ww1_levels": {
		"id": "progress_all_ww1_levels",
		"name": "一战老兵",
		"description": "完成所有一战时代关卡",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "complete_era", "era": "ww1"},
		"reward": {"nano_materials": 300},
		"icon": "🪖",
		"hidden": false,
		"flavor_text": "一战的战线，你已经走完。"
		},
	"progress_all_ww2_levels": {
		"id": "progress_all_ww2_levels",
		"name": "二战英雄",
		"description": "完成所有二战时代关卡",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "complete_era", "era": "ww2"},
		"reward": {"nano_materials": 300},
		"icon": "✈️",
		"hidden": false,
		"flavor_text": "二战的战线，你已经走完。"
		},
	"progress_all_cold_levels": {
		"id": "progress_all_cold_levels",
		"name": "冷战战士",
		"description": "完成所有冷战时代关卡",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "complete_era", "era": "cold"},
		"reward": {"nano_materials": 300},
		"icon": "☢",
		"hidden": false,
		"flavor_text": "冷战的战线，你已经走完。"
		},
	"progress_all_modern_levels": {
		"id": "progress_all_modern_levels",
		"name": "现代尖兵",
		"description": "完成所有现代时代关卡",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "complete_era", "era": "modern"},
		"reward": {"nano_materials": 300},
		"icon": "🚀",
		"hidden": false,
		"flavor_text": "现代的战线，你已经走完。"
		},
	"progress_all_future_levels": {
		"id": "progress_all_future_levels",
		"name": "未来先锋",
		"description": "完成所有近未来时代关卡",
		"category": "progress",
		"rarity": "RARE",
		"requirements": {"type": "complete_era", "era": "future"},
		"reward": {"nano_materials": 300},
		"icon": "⚡",
		"hidden": false,
		"flavor_text": "近未来的战线，你已经走完。"
		},
	"progress_perfect_all_levels": {
		"id": "progress_perfect_all_levels",
		"name": "完美征服者",
		"description": "以3星评价通过所有关卡",
		"category": "progress",
		"rarity": "LEGENDARY",
		"requirements": {"type": "all_3_stars"},
		"reward": {"nano_materials": 10000, "mythic_card": 10, "title": "完美征服者"},
		"icon": "⭐",
		"hidden": false,
		"flavor_text": "每一关，都以三星收场。"
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
		"flavor_text": "档案开始记录你的战线。"
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
		"flavor_text": "你始终记得让档案保持最新。"
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
		"flavor_text": "累计 10 小时。战线仍在延伸。"
		},
	"system_play_time_100h": {
		"id": "system_play_time_100h",
		"name": "战争终身",
		"description": "累计游戏时间达到100小时",
		"category": "system",
		"rarity": "RARE",
		"requirements": {"type": "play_time_hours", "count": 100},
		"reward": {"nano_materials": 800},
		"icon": "⌛",
		"hidden": false,
		"flavor_text": "累计 100 小时。你与车队同行已久。"
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
		"flavor_text": "第 50 条安装记录，在案。"
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
		"flavor_text": "补给舱的第 100 笔军需。"
		},

	
	# ==================== 特殊成就 (10个) ====================
	"special_hidden_1": {
		"id": "special_hidden_1",
		"name": "秘密发现者",
		"description": "发现一个隐藏的彩蛋",
		"category": "special",
		"rarity": "RARE",
		"requirements": {"type": "find_easter_egg", "id": "secret_1"},
		"reward": {"nano_materials": 500},
		"icon": "🥚",
		"hidden": true,
		"flavor_text": "有些角落，不在任何地图上。"
		},
	"special_nano_millionaire": {
		"id": "special_nano_millionaire",
		"name": "纳米百万富翁",
		"description": "拥有100万纳米材料",
		"category": "special",
		"rarity": "EPIC",
		"requirements": {"type": "nano_materials", "amount": 1000000},
		"reward": {"nano_materials": 1000, "mythic_card": 1, "title": "纳米大亨"},
		"icon": "💰",
		"hidden": false,
		"flavor_text": "纳米材料库存，七位数。"
		},
	"special_defeat_ultimate_boss": {
		"id": "special_defeat_ultimate_boss",
		"name": "终极胜利",
		"description": "击败奥米伽相位师",
		"category": "special",
		"rarity": "LEGENDARY",
		"requirements": {"type": "defeat_boss", "boss_id": "enemy_master_030"},
		"reward": {"nano_materials": 10000, "mythic_card": 10, "title": "世界拯救者"},
		"icon": "🌟",
		"hidden": false,
		"flavor_text": "驻守终局的相位师，力量随你同行。"
		},
	"special_perfect_collection": {
		"id": "special_perfect_collection",
		"name": "完美收藏",
		"description": "拥有所有传说级卡牌的满强化版本",
		"category": "special",
		"rarity": "LEGENDARY",
		"requirements": {"type": "perfect_mythic_collection"},
		"reward": {"nano_materials": 15000, "mythic_card": 15, "title": "完美收藏家"},
		"icon": "👑",
		"hidden": false,
		"flavor_text": "全部传说档案，等级封顶。"
		},
	"special_speed_demon": {
		"id": "special_speed_demon",
		"name": "速度恶魔",
		"description": "在30秒内赢得一场战斗",
		"category": "special",
		"rarity": "EPIC",
		"requirements": {"type": "ultra_fast_win", "seconds": 30},
		"reward": {"nano_materials": 700},
		"icon": "💨",
		"hidden": false,
		"flavor_text": "30 秒，战斗结束。"
		},
	"special_pacifist": {
		"id": "special_pacifist",
		"name": "和平主义者",
		"description": "在一场战斗中不击杀任何敌方单位获得胜利",
		"category": "special",
		"rarity": "EPIC",
		"requirements": {"type": "pacifist_win"},
		"reward": {"nano_materials": 600},
		"icon": "☮️",
		"hidden": false,
		"flavor_text": "未击杀一名敌人，阵地照样易手。"
		},
	"special_all_factions_max": {
		"id": "special_all_factions_max",
		"name": "势力领袖",
		"description": "与所有7个势力都达到最高声望等级",
		"category": "special",
		"rarity": "LEGENDARY",
		"requirements": {"type": "all_factions_max_reputation"},
		"reward": {"nano_materials": 8000, "mythic_card": 8, "title": "势力领袖"},
		"icon": "🎖️",
		"hidden": false,
		"flavor_text": "七家公司的联络线，全部为你亮起。"
		}
}

