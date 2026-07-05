extends RefCounted
## 单位ID迁移配置（旧platform_* → 新时代单位ID）
## 
## 用于存档迁移和旧代码兼容，确保旧存档中的platform_* ID能映射到新的100单位系统
## 
## 映射原则：
## 1. 按时代和类型选择最接近的新单位
## 2. 保留战力级别（轻型→轻型，重型→重型）
## 3. 无法精确映射的用同级通用单位替代

## 旧ID → 新ID映射表
const UNIT_ID_MIGRATION_MAP: Dictionary = {
	# ==================== 一战单位 ====================
	"platform_ww1_light": "ww1_arm_rolls",          # 罗尔斯装甲车（轻型侦察）
	"platform_ww1_medium": "ww1_arm_ft17",          # FT-17轻型坦克（中型坦克）
	"platform_ww1_fort": "ww1_arty_77mm",           # 77mm野战炮（固定炮台）
	"platform_ww1_radar": "ww1_inf_cavalry",        # 骑兵斥候（侦察）
	"platform_ww1_medic": "ww1_sup_engineer",       # 工兵班（支援）

	# ==================== 二战单位 ====================
	"platform_ww2_light": "ww2_inf_hellcat",        # M18地狱猫（轻型装甲车）
	"platform_ww2_medium": "ww2_arm_sherman",       # M4谢尔曼（中型坦克）
	"platform_ww2_heavy": "ww2_arm_tiger",          # 虎式坦克（重型坦克）
	"platform_ww2_raider": "ww2_inf_bazooka",       # 巴祖卡组（轻型突击）
	"platform_ww2_radar": "ww2_inf_panzerschrek",   # 铁拳反坦克组（侦察）
	"platform_ww2_siege": "ww2_arty_m81",           # 81mm迫击炮（攻城）
	"platform_ww2_fortress": "ww1_arty_m81",        # 81mm迫击炮组（固定阵地）

	# ==================== 冷战单位 ====================
	"platform_cold_light": "cold_inf_btr60",        # BTR-60装甲车（轻型侦察）
	"platform_cold_medium": "cold_arm_t55",         # T-55坦克（中型坦克）
	"platform_cold_ifv": "cold_inf_bmp1",           # BMP-1步战车（步战车）
	"platform_cold_scout": "cold_sup_m113",         # M113装甲车（侦察）
	"platform_cold_radar": "cold_sup_zsu23",        # ZSU-23-4（雷达/防空）
	"platform_cold_carrier": "cold_inf_bmp1",       # BMP-1步战车（载具）

	# ==================== 现代单位 ====================
	"platform_modern_light": "mod_inf_technical",   # 武装皮卡（轻型侦察）
	"platform_modern_medium": "mod_arm_m1a1",       # M1A1坦克（中型坦克）
	"platform_modern_radar": "mod_sup_m6",          # 自行高炮M6（雷达）
	"platform_modern_spg": "mod_arty_m270",         # M270火箭炮（自行火炮）
	"platform_modern_stealth": "mod_inf_scout_drone", # 侦察无人机（隐匿）
	"platform_modern_guard_heavy": "mod_arm_m1a2sep", # M1A2 SEP（重型护卫）

	# ==================== 近未来单位 ====================
	"platform_future_light": "fut_inf_scout_mech",  # 侦察机甲（轻型）
	"platform_future_medium": "fut_arm_hovertank",  # 悬浮坦克（中型）
	"platform_future_radar": "fut_arm_prism",       # 光棱坦克（雷达）
	"platform_future_heavy": "fut_arm_heavy_mech",  # 重装机甲（重型）

	# ==================== 终极单位 ====================
	"omega_platform": "fut_arm_omega",              # 全装型机动舱（原 fut_nexus → fut_arm_omega）

	# ==================== v7.x 规范化重命名：上一代ID → 最新ID（40个）====================
	# 卡牌ID按兵种类型加前缀（inf/arm/arty/sup/fort），旧存档/旧引用需迁移
	# 一战
	"ww1_rolls": "ww1_arm_rolls",
	"ww1_ft17": "ww1_arm_ft17",
	"ww1_77mm": "ww1_arty_77mm",
	"ww1_m81": "ww1_arty_m81",
	"ww1_cavalry": "ww1_inf_cavalry",
	"ww1_engineer": "ww1_sup_engineer",
	# 二战
	"ww2_tiger": "ww2_arm_tiger",
	"ww2_sherman": "ww2_arm_sherman",
	"ww2_hellcat": "ww2_inf_hellcat",
	"ww2_bazooka": "ww2_inf_bazooka",
	"ww2_panzerschrek": "ww2_inf_panzerschrek",
	"ww2_m81": "ww2_arty_m81",
	# 冷战
	"cold_btr60": "cold_inf_btr60",
	"cold_bmp1": "cold_inf_bmp1",
	"cold_m113": "cold_sup_m113",
	"cold_t55": "cold_arm_t55",
	"cold_zsu23": "cold_sup_zsu23",
	# 现代
	"mod_technical": "mod_inf_technical",
	"mod_m1a1": "mod_arm_m1a1",
	"mod_m1a2sep": "mod_arm_m1a2sep",
	"mod_m270": "mod_arty_m270",
	"mod_m6": "mod_sup_m6",
	# 近未来
	"fut_scout_drone": "mod_inf_scout_drone",
	"fut_scout_mech": "fut_inf_scout_mech",
	"fut_hovertank": "fut_arm_hovertank",
	"fut_prism": "fut_arm_prism",
	"fut_nexus": "fut_arm_omega",
	"fut_heavy_mech": "fut_arm_heavy_mech",
	# 要塞（fort_前缀 → 时代前缀_fort_）
	"fort_cold_missile": "cold_fort_missile",
	"fort_cold_radar": "cold_fort_radar",
	"fort_future_ion": "fut_fort_ion",
	"fort_future_shield": "fut_fort_shield",
	"fort_modern_citadel": "mod_fort_citadel",
	"fort_modern_phalanx": "mod_fort_phalanx",
	"fort_ww1_artillery": "ww1_fort_artillery",
	"fort_ww1_pillbox": "ww1_fort_pillbox",
	"fort_ww2_bunker": "ww2_fort_bunker",
	"fort_ww2_flak": "ww2_fort_flak",
}

## 新ID → 旧ID反向映射（用于兼容检查）
## 使用静态 getter 实现懒加载初始化
static var _new_to_old_id_map_cached: Dictionary = {}
static var _reverse_map_initialized: bool = false

static func get_reverse_map() -> Dictionary:
	if not _reverse_map_initialized:
		_reverse_map_initialized = true
		for old_id in UNIT_ID_MIGRATION_MAP:
			var new_id = UNIT_ID_MIGRATION_MAP[old_id]
			_new_to_old_id_map_cached[new_id] = old_id
	return _new_to_old_id_map_cached

## 初始化反向映射（已废弃，使用 get_reverse_map()）
static func _static_init():
	get_reverse_map()

## 获取迁移后的新ID
static func get_new_id(old_id: String) -> String:
	if UNIT_ID_MIGRATION_MAP.has(old_id):
		return UNIT_ID_MIGRATION_MAP[old_id] as String
	# 无映射时返回原ID（让上层处理）
	return old_id

## 检查是否需要迁移
## v7.x：除了 platform_* 旧系统ID，还包括 40 个被规范化重命名的上一代ID
static func needs_migration(card_id: String) -> bool:
	return UNIT_ID_MIGRATION_MAP.has(card_id)

## 批量迁移ID列表
static func migrate_id_list(old_ids: Array) -> Array:
	var new_ids: Array = []
	for id in old_ids:
		new_ids.append(get_new_id(id))
	return new_ids

## 获取迁移信息（用于日志）
static func get_migration_info(old_id: String) -> String:
	if UNIT_ID_MIGRATION_MAP.has(old_id):
		var new_id = UNIT_ID_MIGRATION_MAP[old_id]
		return "迁移: %s → %s" % [old_id, new_id]
	return "无需迁移: %s" % old_id
