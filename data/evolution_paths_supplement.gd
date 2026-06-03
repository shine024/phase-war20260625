extends RefCounted
class_name EvolutionPathsSupplement
## 进化路径补充配置（v6.0）
## 为78个缺少进化路径的战斗卡补充进化配置
## 设计原则：同一代同类兵种，只要战力够都可以进化

const DefaultCards = preload("res://data/default_cards.gd")

## ═══════════════════════════════════════════════════════════
## 进化路径补充配置
## ═══════════════════════════════════════════════════════════

## 补充的进化路径配置
## 这些配置将被合并到 unit_lineage_config.gd 的 LINEAGES 字典中
const SUPPLEMENTARY_LINEAGES: Dictionary = {
	# ═══════════════════════════════════════════════════════════
	# WWI 步兵类型补充
	# ═══════════════════════════════════════════════════════════

	# 步枪线：毛瑟 → 加兰德 → M14 → 游骑兵 → 幽灵特工
	"ww1_mauser": {
		"evolution_1": "ww2_garand",
		"faction_branches": {
			"frontier_union": "ww2_browning",
			"helix_recon": "cold_m14",
		},
	},
	"ww2_garand": {
		"evolution_1": "cold_m14",
		"faction_branches": {
			"aether_dynamics": "mod_ranger",
			"frontier_union": "cold_m14",
		},
	},
	"cold_m14": {
		"evolution_1": "mod_ranger",
		"faction_branches": {
			"iron_wall_corp": "mod_marine",
			"void_research": "fut_spectre",
		},
	},

	# 机枪线：维克斯 → MG42 → M60 → UH-60 → 攻击无人机
	"ww1_vickers": {
		"evolution_1": "ww2_mg42",
		"faction_branches": {
			"frontier_union": "ww2_browning",
		},
	},
	"ww1_mg08": {
		"evolution_1": "ww2_mg42",
		"faction_branches": {
			"aether_dynamics": "ww2_browning",
		},
	},
	"ww2_mg42": {
		"evolution_1": "cold_m60",
		"faction_branches": {
			"nova_arms": "cold_m60t",
		},
	},
	"cold_m60": {
		"evolution_1": "mod_uh60",
		"faction_branches": {
			"aether_dynamics": "mod_uh60",
			"frontier_union": "mod_ah64",
		},
	},
	"cold_m60t": {
		"evolution_1": "mod_uh60",
		"faction_branches": {},
	},

	# 反坦克步枪线：李恩菲尔德 → 巴祖卡 → RPG → 标枪 → 重型突击兵
	"ww1_enfield": {
		"evolution_1": "ww2_bazooka",
		"faction_branches": {
			"iron_wall_corp": "ww2_panzerschrek",
		},
	},
	"ww2_bazooka": {
		"evolution_1": "cold_rpg",
		"faction_branches": {
			"frontier_union": "cold_rpg",
		},
	},

	# 工兵线：工兵 → 先锋 → 工兵 → 战斗工兵 → 蜂群机甲
	"ww1_engineer": {
		"evolution_1": "ww2_mp40",  # 临时连接到火焰线
		"faction_branches": {
			"aether_dynamics": "ww2_bazooka",
		},
	},

	# 火焰线：火焰喷射器 → 火焰喷射器 → 火焰 → 火焰 → 风暴核心
	"ww1_flame": {
		"evolution_1": "ww2_mp40",  # 临时连接到冲锋枪线
		"faction_branches": {
			"void_research": "cold_sam7",
		},
	},

	# 冲锋枪线：MP40 → PPSh → AK47（已有）
	"ww2_mp40": {
		"evolution_1": "cold_ak47",
		"faction_branches": {
			"frontier_union": "cold_spetsnaz",
		},
	},
	"ww2_ppsh": {
		"evolution_1": "cold_ak47",
		"faction_branches": {
			"iron_wall_corp": "cold_spetsnaz",
		},
	},
	"ww2_browning": {
		"evolution_1": "cold_m60",
		"faction_branches": {},
	},

	# ═══════════════════════════════════════════════════════════
	# WWI 装甲类型补充
	# ═══════════════════════════════════════════════════════════

	# A7V线：A7V → 四号坦克 → T-62 → T-90 → 棱镜机甲
	"ww1_a7v": {
		"evolution_1": "ww2_pz4",
		"faction_branches": {
			"iron_wall_corp": "ww2_tiger",
			"nova_arms": "ww2_panther",
		},
	},
	"ww2_pz4": {
		"evolution_1": "cold_t62",
		"faction_branches": {
			"frontier_union": "cold_t55",
			"iron_wall_corp": "cold_t72",
		},
	},
	"ww2_panther": {
		"evolution_1": "cold_t62",
		"faction_branches": {
			"aether_dynamics": "cold_leo1",
			"frontier_union": "cold_t55",
		},
	},

	# 谢尔曼线：Mark IV → 谢尔曼 → M1 → M1A2 → 突击机甲
	"ww1_mark4": {
		"evolution_1": "ww2_sherman",
		"faction_branches": {
			"frontier_union": "ww2_t34_76",
		},
	},
	"ww2_sherman": {
		"evolution_1": "cold_m1",
		"faction_branches": {
			"aether_dynamics": "cold_leo1",
			"iron_wall_corp": "cold_t72",
		},
	},
	"cold_m1": {
		"evolution_1": "mod_m1a2",
		"faction_branches": {
			"nova_arms": "mod_m1a2sep",
		},
	},

	# T-34线：A7V → T-34/76 → T-62 → 豹2A6 → 棱镜机甲
	"ww2_t34_76": {
		"evolution_1": "cold_t62",
		"faction_branches": {
			"iron_wall_corp": "cold_t72",
		},
	},
	"ww2_t34_85": {
		"evolution_1": "cold_t62",
		"faction_branches": {
			"frontier_union": "cold_t55",
		},
	},

	# 虎王线：圣沙蒙（已有）→ 虎王 → 酋长 → 挑战者2 → 巨神机甲
	"ww2_kingtiger": {
		"evolution_1": "cold_chieftain",
		"faction_branches": {
			"iron_wall_corp": "cold_t72",
		},
	},
	"cold_chieftain": {
		"evolution_1": "mod_challenger2",
		"faction_branches": {
			"nova_arms": "mod_leo2a6",
			"void_research": "fut_colossus",
		},
	},

	# 装甲车线：罗尔斯 → 半履带车 → BTR-60 → 布雷德利 → 侦察机甲
	"ww1_rolls": {
		"evolution_1": "ww2_sherman",  # 需要添加半履带车
		"faction_branches": {
			"frontier_union": "ww2_sherman",
		},
	},
	"ww1_lanchest": {
		"evolution_1": "ww2_sherman",  # 需要添加半履带车
		"faction_branches": {},
	},

	# ═══════════════════════════════════════════════════════════
	# 冷战装甲类型补充
	# ═══════════════════════════════════════════════════════════

	"cold_leo1": {
		"evolution_1": "mod_leo2a6",
		"faction_branches": {
			"aether_dynamics": "mod_m1a2",
			"frontier_union": "mod_challenger2",
		},
	},
	"cold_btr60": {
		"evolution_1": "mod_stryker_m2",
		"faction_branches": {
			"aether_dynamics": "cold_bradley",
		},
	},
	"cold_bradley": {
		"evolution_1": "mod_stryker_m2",
		"faction_branches": {
			"nova_arms": "fut_scout_mech",
		},
	},
	"cold_rpk": {
		"evolution_1": "mod_stinger",
		"faction_branches": {},
	},
	"cold_sam7": {
		"evolution_1": "mod_stinger",
		"faction_branches": {
			"frontier_union": "mod_m6",
		},
	},
	"cold_f4": {
		"evolution_1": "mod_ah1",
		"faction_branches": {
			"nova_arms": "mod_ah64",
		},
	},

	# ═══════════════════════════════════════════════════════════
	# 现代装甲类型补充
	# ═══════════════════════════════════════════════════════════

	"mod_leo2a6": {
		"evolution_1": "fut_prism",
		"faction_branches": {
			"iron_wall_corp": "fut_heavy_mech",
			"nova_arms": "fut_assault_mech",
		},
	},
	"mod_t90": {
		"evolution_1": "fut_prism",
		"faction_branches": {
			"void_research": "fut_nexus",
		},
	},
	"mod_challenger2": {
		"evolution_1": "fut_colossus",
		"faction_branches": {
			"aether_dynamics": "fut_heavy_mech",
		},
	},
	"mod_m1a2": {
		"evolution_1": "fut_assault_mech",
		"faction_branches": {
			"nova_arms": "fut_hovertank",
		},
	},
	"mod_uh60": {
		"evolution_1": "fut_attack_drone",
		"faction_branches": {
			"aether_dynamics": "fut_space_fighter",
		},
	},
	"mod_stinger": {
		"evolution_1": "fut_aa_hover",
		"faction_branches": {},
	},

	# 轻型车辆线
	"mod_hummer_m2": {
		"evolution_1": "mod_stryker_m2",
		"faction_branches": {},
	},
	"mod_hummer_tow": {
		"evolution_1": "mod_stryker_mgs",
		"faction_branches": {},
	},
	"mod_stryker_m2": {
		"evolution_1": "fut_scout_mech",
		"faction_branches": {
			"helix_recon": "fut_nano_drone",
		},
	},
	"mod_stryker_mgs": {
		"evolution_1": "fut_scout_mech",
		"faction_branches": {
			"nova_arms": "fut_assault_mech",
		},
	},

	# ═══════════════════════════════════════════════════════════
	# 支援类型补充
	# ═══════════════════════════════════════════════════════════

	# 迫击炮线：76mm → 120mm → 迫击炮（需要添加）→ 迫击炮（需要添加）→ 纳米无人机
	"ww1_m76": {
		"evolution_1": "ww2_m120",
		"faction_branches": {},
	},
	"ww2_m120": {
		"evolution_1": "cold_m113",  # 需要添加冷战迫击炮
		"faction_branches": {
			"frontier_union": "cold_m113",
		},
	},

	# 火炮线：105mm → 155mm（需要添加）→ M109（需要添加）→ MLRS（已有）→ 未来火炮
	"ww1_105mm": {
		"evolution_1": "ww2_m120",  # 需要添加二战105mm
		"faction_branches": {
			"frontier_union": "ww2_m120",
		},
	},
	"ww1_77mm": {
		"evolution_1": "ww2_m81",  # 需要添加二战88mm
		"faction_branches": {},
	},

	# ═══════════════════════════════════════════════════════════
	# 堡垒类型补充（终端节点标记）
	# ═══════════════════════════════════════════════════════════

	# 辅助功能单位（不需要进化）
	"fort_ww1_artillery": {
		"is_utility": true,  # 标记为辅助单位
	},
	"fort_cold_radar": {
		"is_utility": true,  # 标记为辅助单位
	},

	# 终端节点（进化链末端）
	"fort_future_ion": {
		"is_terminal": true,  # 标记为终端节点
	},
	"fort_future_shield": {
		"is_terminal": true,  # 标记为终端节点
	},
	"omega_platform": {
		"is_terminal": true,  # 标记为终端节点
	},

	# 未来单位作为进化目标（不需要再进化，或已有进化路径）
	"fut_cyborg": {
		"evolution_1": "",  # 可以进一步进化，但留空表示可选择性
		"is_terminal": false,
	},
	"fut_spectre": {
		"is_terminal": true,  # 幽灵特工为终端
	},
	"fut_heavy_mech": {
		"is_terminal": true,  # 重型机甲为终端
	},
	"fut_hovertank": {
		"is_terminal": true,  # 悬浮坦克为终端
	},
	"fut_howitzer": {
		"is_terminal": true,  # 未来火炮为终端
	},
	"fut_attack_drone": {
		"is_terminal": true,  # 攻击无人机为终端
	},
	"fut_space_fighter": {
		"is_terminal": true,  # 太空战斗机为终端
	},
	"fut_stealth_bomber": {
		"is_terminal": true,  # 隐形轰炸机为终端
	},
	"fut_aa_hover": {
		"is_terminal": true,  # 悬浮防空为终端
	},
	"fut_colossus": {
		"is_terminal": true,  # 巨神机甲为终端
	},

	# 未来单位可继续进化的
	"fut_heavy_trooper": {
		"evolution_1": "fut_colossus",
		"faction_branches": {
			"void_research": "fut_nexus",
		},
	},
	"fut_assault_mech": {
		"evolution_1": "fut_colossus",
		"faction_branches": {
			"nova_arms": "fut_heavy_mech",
		},
	},
	"fut_scout_mech": {
		"evolution_1": "fut_prism",
		"faction_branches": {
			"helix_recon": "fut_nano_drone",
		},
	},
	"fut_nano_drone": {
		"evolution_1": "fut_swarm",
		"faction_branches": {},
	},
	"fut_nexus": {
		"is_terminal": true,  # 联结核心为终端
	},
	"fut_prism": {
		"is_terminal": true,  # 棱镜机甲为终端
	},
	"fut_swarm": {
		"is_terminal": true,  # 蜂群机甲为终端
	},
	"fut_shield": {
		"is_terminal": true,  # 能量护盾为终端
	},
	"fut_stormcore": {
		"is_terminal": true,  # 风暴核心为终端
	},

	# 骑兵线
	"ww1_cavalry": {
		"evolution_1": "ww2_sherman",  # 需要添加半履带车
		"faction_branches": {
			"frontier_union": "ww2_sherman",
		},
	},

	# IS-2线
	"ww2_is2": {
		"evolution_1": "cold_t72",
		"faction_branches": {
			"iron_wall_corp": "cold_t72",
		},
	},

	# 地狱猫线
	"ww2_hellcat": {
		"evolution_1": "cold_m60t",
		"faction_branches": {
			"nova_arms": "mod_ah1",
		},
	},
}

## ═══════════════════════════════════════════════════════════
## 公共接口
## ═══════════════════════════════════════════════════════════

## 获取补充配置
static func get_supplementary_lineages() -> Dictionary:
	return SUPPLEMENTARY_LINEAGES.duplicate(true)

## 检查是否为终端节点
static func is_terminal_unit(card_id: String) -> bool:
	var cfg = SUPPLEMENTARY_LINEAGES.get(card_id, {})
	return bool(cfg.get("is_terminal", false))

## 检查是否为辅助单位
static func is_utility_unit(card_id: String) -> bool:
	var cfg = SUPPLEMENTARY_LINEAGES.get(card_id, {})
	return bool(cfg.get("is_utility", false))
