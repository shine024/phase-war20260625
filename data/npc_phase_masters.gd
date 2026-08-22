extends RefCounted
## NPC 相位师战斗配置 —— 全项目单一真理源
## 用于相位师遭遇战的卡牌选择（game_manager 抽取遭遇相位师）与排行榜 NPC 显示
## （leaderboard_panel / leaderboard_data）。此前三处各持一份发散副本（7/7/9 条目），
## v9.x 统一到本文件。
## 字段：name 相位师名 / faction 势力ID / era 时代 / platform 平台卡ID。
## 注：旧副本中的 "weapons" 字段从未被任何消费方读取，统一时已删除。

const NPC_PHASE_MASTERS: Array = [
	{"name": "终焉之镰",   "faction": "void_research",     "era": "future", "platform": "platform_future_heavy"},
	{"name": "炽焰星痕",   "faction": "nova_arms",         "era": "future", "platform": "platform_future_medium"},
	{"name": "雷霆判官",   "faction": "aether_dynamics",   "era": "cold",   "platform": "platform_cold_medium"},
	{"name": "寒霜壁垒",   "faction": "iron_wall_corp",    "era": "ww2",    "platform": "platform_ww2_heavy"},
	{"name": "量子幽灵",   "faction": "quantum_logistics", "era": "modern", "platform": "platform_modern_medium"},
	{"name": "虚空低语",   "faction": "helix_recon",       "era": "future", "platform": "platform_future_light"},
	{"name": "边境开拓者", "faction": "frontier_union",    "era": "ww2",    "platform": "platform_ww2_light"},
	# v7.x 时代筛选修复补录：一战 NPC（低级关需要同代池，避免一战关抽到跨时代相位师）
	{"name": "铁壁先锋",   "faction": "iron_wall_corp",    "era": "ww1",    "platform": "platform_ww1_heavy"},
	{"name": "旧日雷霆",   "faction": "frontier_union",    "era": "ww1",    "platform": "platform_ww1_medium"},
]

static func get_all() -> Array:
	return NPC_PHASE_MASTERS.duplicate()

static func get_by_name(p_name: String) -> Dictionary:
	for config in NPC_PHASE_MASTERS:
		if config.get("name") == p_name:
			return config.duplicate(true)
	return {}
