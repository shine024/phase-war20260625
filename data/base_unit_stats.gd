extends RefCounted
class_name BaseUnitStats
## v6.3 统一基础属性表（L0 数据层）
## 玩家卡（default_cards.gd）和敌人卡（enemy_unit_manifest.gd）共享的基础数值。
##
## 设计原则：
##   1. 平衡时先调这里（L0 基础定位），再调各加成层（L1 era/level → L2 养成 → L3 波次 → L4 运行期）
##   2. 字段对齐 UnitStats / CardResource，确保派生无损耗
##   3. 玩家卡和敌人卡用 base_ref 引用原型，可覆盖个别字段实现个体差异
##   4. 防御值由 UnitStatsTable.derive_defense_by_unit_type() 统一派生（v6.2），不在此表定义
##
## 原型命名约定：<era>_<role>，如 ww1_infantry / ww2_heavy_tank / modern_aa

const GC = preload("res://resources/game_constants.gd")

## 基础原型表
## 每个条目字段：
##   display_name: 显示名
##   combat_kind: CombatKind 枚举值
##   hp: 基础生命值
##   move_speed: 移动速度（0=固定）
##   attack_range: 攻击射程（格，99=全图）
##   attack_light/armor/air: 三维攻击力
##   atk_l_speed/a_speed/air_speed: 三维攻速（次/秒）
##   atk_l_windup/a_windup/air_windup: 三维前摇（秒）
##   atk_l_active/a_active/air_active: 三维动作（秒）
##   weapon_type: WeaponType（DIRECT/INDIRECT/AERIAL）
##   deploy_speed: 部署速度（0-7）
##   power: 战力（进化/军衔门槛用）
##   weapon_label: 武器外观标签
const BASE_ENTRIES: Dictionary = {
	# ═══════════════════════════════════════
	# 轻装类（LIGHT = 0）
	# ═══════════════════════════════════════
	"ww1_infantry": {
		"display_name": "步兵班", "combat_kind": GC.CombatKind.LIGHT,
		"hp": 100, "move_speed": 80, "attack_range": 2,
		"attack_light": 35, "attack_armor": 0, "attack_air": 0,
		"atk_l_speed": 1.5, "atk_a_speed": 0.0, "atk_air_speed": 0.0,
		"atk_l_windup": 0.15, "atk_a_windup": 0.0, "atk_air_windup": 0.0,
		"atk_l_active": 0.08, "atk_a_active": 0.0, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 4, "power": 15,
		"weapon_label": "冲锋枪",
	},
	"ww2_infantry": {
		"display_name": "步兵班", "combat_kind": GC.CombatKind.LIGHT,
		"hp": 135, "move_speed": 80, "attack_range": 2,
		"attack_light": 50, "attack_armor": 0, "attack_air": 0,
		"atk_l_speed": 1.5, "atk_a_speed": 0.0, "atk_air_speed": 0.0,
		"atk_l_windup": 0.15, "atk_a_windup": 0.0, "atk_air_windup": 0.0,
		"atk_l_active": 0.08, "atk_a_active": 0.0, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 4, "power": 60,
		"weapon_label": "冲锋枪",
	},
	"cold_infantry": {
		"display_name": "步兵班", "combat_kind": GC.CombatKind.LIGHT,
		"hp": 200, "move_speed": 80, "attack_range": 2,
		"attack_light": 90, "attack_armor": 0, "attack_air": 0,
		"atk_l_speed": 1.5, "atk_a_speed": 0.0, "atk_air_speed": 0.0,
		"atk_l_windup": 0.15, "atk_a_windup": 0.0, "atk_air_windup": 0.0,
		"atk_l_active": 0.08, "atk_a_active": 0.0, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 4, "power": 160,
		"weapon_label": "突击步枪",
	},
	"modern_infantry": {
		"display_name": "步兵班", "combat_kind": GC.CombatKind.LIGHT,
		"hp": 300, "move_speed": 80, "attack_range": 2,
		"attack_light": 140, "attack_armor": 0, "attack_air": 0,
		"atk_l_speed": 1.5, "atk_a_speed": 0.0, "atk_air_speed": 0.0,
		"atk_l_windup": 0.15, "atk_a_windup": 0.0, "atk_air_windup": 0.0,
		"atk_l_active": 0.08, "atk_a_active": 0.0, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 4, "power": 320,
		"weapon_label": "卡宾枪",
	},
	"future_infantry": {
		"display_name": "机械步兵", "combat_kind": GC.CombatKind.LIGHT,
		"hp": 400, "move_speed": 80, "attack_range": 3,
		"attack_light": 200, "attack_armor": 0, "attack_air": 0,
		"atk_l_speed": 1.5, "atk_a_speed": 0.0, "atk_air_speed": 0.0,
		"atk_l_windup": 0.15, "atk_a_windup": 0.0, "atk_air_windup": 0.0,
		"atk_l_active": 0.08, "atk_a_active": 0.0, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 4, "power": 500,
		"weapon_label": "粒子炮",
	},

	# ═══════════════════════════════════════
	# 装甲类（ARMOR = 1）
	# ═══════════════════════════════════════
	"ww1_light_tank": {
		"display_name": "轻型坦克", "combat_kind": GC.CombatKind.ARMOR,
		"hp": 200, "move_speed": 40, "attack_range": 3,
		"attack_light": 28, "attack_armor": 40, "attack_air": 0,
		"atk_l_speed": 0.83, "atk_a_speed": 0.67, "atk_air_speed": 0.0,
		"atk_l_windup": 0.22, "atk_a_windup": 0.25, "atk_air_windup": 0.0,
		"atk_l_active": 0.12, "atk_a_active": 0.12, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 3, "power": 45,
		"weapon_label": "坦克炮",
	},
	"ww2_medium_tank": {
		"display_name": "中型坦克", "combat_kind": GC.CombatKind.ARMOR,
		"hp": 380, "move_speed": 60, "attack_range": 3,
		"attack_light": 45, "attack_armor": 90, "attack_air": 0,
		"atk_l_speed": 0.83, "atk_a_speed": 0.67, "atk_air_speed": 0.0,
		"atk_l_windup": 0.22, "atk_a_windup": 0.25, "atk_air_windup": 0.0,
		"atk_l_active": 0.12, "atk_a_active": 0.12, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 3, "power": 180,
		"weapon_label": "坦克炮",
	},
	"ww2_heavy_tank": {
		"display_name": "重型坦克", "combat_kind": GC.CombatKind.ARMOR,
		"hp": 480, "move_speed": 40, "attack_range": 4,
		"attack_light": 35, "attack_armor": 130, "attack_air": 0,
		"atk_l_speed": 0.67, "atk_a_speed": 0.5, "atk_air_speed": 0.0,
		"atk_l_windup": 0.25, "atk_a_windup": 0.3, "atk_air_windup": 0.0,
		"atk_l_active": 0.12, "atk_a_active": 0.15, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 2, "power": 180,
		"weapon_label": "重型坦克炮",
	},
	"cold_mbt": {
		"display_name": "主战坦克", "combat_kind": GC.CombatKind.ARMOR,
		"hp": 800, "move_speed": 50, "attack_range": 4,
		"attack_light": 55, "attack_armor": 180, "attack_air": 0,
		"atk_l_speed": 0.67, "atk_a_speed": 0.5, "atk_air_speed": 0.0,
		"atk_l_windup": 0.25, "atk_a_windup": 0.3, "atk_air_windup": 0.0,
		"atk_l_active": 0.12, "atk_a_active": 0.15, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 3, "power": 480,
		"weapon_label": "滑膛炮",
	},
	"modern_mbt": {
		"display_name": "主战坦克", "combat_kind": GC.CombatKind.ARMOR,
		"hp": 1200, "move_speed": 50, "attack_range": 4,
		"attack_light": 70, "attack_armor": 300, "attack_air": 0,
		"atk_l_speed": 0.67, "atk_a_speed": 0.5, "atk_air_speed": 0.0,
		"atk_l_windup": 0.25, "atk_a_windup": 0.3, "atk_air_windup": 0.0,
		"atk_l_active": 0.12, "atk_a_active": 0.15, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 3, "power": 960,
		"weapon_label": "主炮",
	},
	"future_heavy_mech": {
		"display_name": "重装机甲", "combat_kind": GC.CombatKind.ARMOR,
		"hp": 1800, "move_speed": 30, "attack_range": 4,
		"attack_light": 80, "attack_armor": 500, "attack_air": 60,
		"atk_l_speed": 0.5, "atk_a_speed": 0.33, "atk_air_speed": 0.5,
		"atk_l_windup": 0.3, "atk_a_windup": 0.4, "atk_air_windup": 0.3,
		"atk_l_active": 0.15, "atk_a_active": 0.2, "atk_air_active": 0.15,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 2, "power": 1580,
		"weapon_label": "等离子加农炮",
	},

	# ═══════════════════════════════════════
	# 空中类（AIR = 3）
	# ═══════════════════════════════════════
	"cold_fighter": {
		"display_name": "战斗机", "combat_kind": GC.CombatKind.AIR,
		"hp": 250, "move_speed": 99, "attack_range": 99,
		"attack_light": 60, "attack_armor": 50, "attack_air": 160,
		"atk_l_speed": 1.0, "atk_a_speed": 1.0, "atk_air_speed": 1.0,
		"atk_l_windup": 0.2, "atk_a_windup": 0.2, "atk_air_windup": 0.2,
		"atk_l_active": 0.1, "atk_a_active": 0.1, "atk_air_active": 0.1,
		"weapon_type": GC.WeaponType.AERIAL, "deploy_speed": 6, "power": 400,
		"weapon_label": "空空导弹",
	},
	"modern_attack_helo": {
		"display_name": "武装直升机", "combat_kind": GC.CombatKind.AIR,
		"hp": 350, "move_speed": 99, "attack_range": 99,
		"attack_light": 160, "attack_armor": 280, "attack_air": 100,
		"atk_l_speed": 0.67, "atk_a_speed": 0.67, "atk_air_speed": 0.67,
		"atk_l_windup": 0.25, "atk_a_windup": 0.25, "atk_air_windup": 0.25,
		"atk_l_active": 0.12, "atk_a_active": 0.12, "atk_air_active": 0.12,
		"weapon_type": GC.WeaponType.AERIAL, "deploy_speed": 5, "power": 800,
		"weapon_label": "地狱火导弹",
	},
	"future_fighter": {
		"display_name": "空天战斗机", "combat_kind": GC.CombatKind.AIR,
		"hp": 450, "move_speed": 99, "attack_range": 99,
		"attack_light": 120, "attack_armor": 100, "attack_air": 350,
		"atk_l_speed": 1.0, "atk_a_speed": 1.0, "atk_air_speed": 1.0,
		"atk_l_windup": 0.2, "atk_a_windup": 0.2, "atk_air_windup": 0.2,
		"atk_l_active": 0.1, "atk_a_active": 0.1, "atk_air_active": 0.1,
		"weapon_type": GC.WeaponType.AERIAL, "deploy_speed": 7, "power": 1325,
		"weapon_label": "轨道炮",
	},

	# ═══════════════════════════════════════
	# 火炮/支援类（SUPPORT = 2，主类归入 LIGHT）
	# ═══════════════════════════════════════
	"ww1_mortar": {
		"display_name": "迫击炮组", "combat_kind": GC.CombatKind.SUPPORT,
		"hp": 70, "move_speed": 30, "attack_range": 99,
		"attack_light": 120, "attack_armor": 60, "attack_air": 0,
		"atk_l_speed": 2.0, "atk_a_speed": 2.0, "atk_air_speed": 0.0,
		"atk_l_windup": 1.2, "atk_a_windup": 1.2, "atk_air_windup": 0.0,
		"atk_l_active": 0.6, "atk_a_active": 0.6, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.INDIRECT, "deploy_speed": 1, "power": 23,
		"weapon_label": "迫击炮",
	},
	"modern_mrl": {
		"display_name": "火箭炮", "combat_kind": GC.CombatKind.SUPPORT,
		"hp": 250, "move_speed": 40, "attack_range": 99,
		"attack_light": 540, "attack_armor": 360, "attack_air": 0,
		"atk_l_speed": 0.8, "atk_a_speed": 0.8, "atk_air_speed": 0.0,
		"atk_l_windup": 2.4, "atk_a_windup": 2.4, "atk_air_windup": 0.0,
		"atk_l_active": 1.2, "atk_a_active": 1.2, "atk_air_active": 0.0,
		"weapon_type": GC.WeaponType.INDIRECT, "deploy_speed": 1, "power": 480,
		"weapon_label": "火箭炮",
	},

	# ═══════════════════════════════════════
	# 防空特化类（SUPPORT = 2，主攻击为对空）
	# ═══════════════════════════════════════
	"ww1_aa_gun": {
		"display_name": "高射炮", "combat_kind": GC.CombatKind.SUPPORT,
		"hp": 70, "move_speed": 0, "attack_range": 5,
		"attack_light": 10, "attack_armor": 24, "attack_air": 150,
		"atk_l_speed": 1.5, "atk_a_speed": 4.0, "atk_air_speed": 8.0,
		"atk_l_windup": 0.15, "atk_a_windup": 0.8, "atk_air_windup": 0.4,
		"atk_l_active": 0.08, "atk_a_active": 0.4, "atk_air_active": 0.2,
		"weapon_type": GC.WeaponType.AERIAL, "deploy_speed": 0, "power": 23,
		"weapon_label": "高射炮",
	},
	"modern_aa": {
		"display_name": "自行防空炮", "combat_kind": GC.CombatKind.SUPPORT,
		"hp": 300, "move_speed": 50, "attack_range": 5,
		"attack_light": 40, "attack_armor": 90, "attack_air": 840,
		"atk_l_speed": 2.0, "atk_a_speed": 6.0, "atk_air_speed": 8.0,
		"atk_l_windup": 0.1, "atk_a_windup": 0.6, "atk_air_windup": 0.4,
		"atk_l_active": 0.05, "atk_a_active": 0.32, "atk_air_active": 0.2,
		"weapon_type": GC.WeaponType.AERIAL, "deploy_speed": 3, "power": 480,
		"weapon_label": "近防炮",
	},

	# ═══════════════════════════════════════
	# 堡垒类（FORT = 4，主类归入 ARMOR）
	# ═══════════════════════════════════════
	"ww1_bunker": {
		"display_name": "机枪碉堡", "combat_kind": GC.CombatKind.FORT,
		"hp": 600, "move_speed": 0, "attack_range": 5,
		"attack_light": 60, "attack_armor": 0, "attack_air": 40,
		"atk_l_speed": 2.0, "atk_a_speed": 0.0, "atk_air_speed": 1.5,
		"atk_l_windup": 0.1, "atk_a_windup": 0.0, "atk_air_windup": 0.15,
		"atk_l_active": 0.05, "atk_a_active": 0.0, "atk_air_active": 0.08,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 0, "power": 80,
		"weapon_label": "要塞炮",
	},
	"modern_citadel": {
		"display_name": "要塞核心", "combat_kind": GC.CombatKind.FORT,
		"hp": 2000, "move_speed": 0, "attack_range": 6,
		"attack_light": 120, "attack_armor": 150, "attack_air": 80,
		"atk_l_speed": 1.0, "atk_a_speed": 0.67, "atk_air_speed": 1.0,
		"atk_l_windup": 0.2, "atk_a_windup": 0.25, "atk_air_windup": 0.2,
		"atk_l_active": 0.1, "atk_a_active": 0.12, "atk_air_active": 0.1,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 0, "power": 800,
		"weapon_label": "要塞炮",
	},
	"future_ion_fort": {
		"display_name": "离子炮台", "combat_kind": GC.CombatKind.FORT,
		"hp": 2500, "move_speed": 0, "attack_range": 7,
		"attack_light": 200, "attack_armor": 300, "attack_air": 150,
		"atk_l_speed": 0.67, "atk_a_speed": 0.5, "atk_air_speed": 0.67,
		"atk_l_windup": 0.25, "atk_a_windup": 0.3, "atk_air_windup": 0.25,
		"atk_l_active": 0.12, "atk_a_active": 0.15, "atk_air_active": 0.12,
		"weapon_type": GC.WeaponType.DIRECT, "deploy_speed": 0, "power": 1200,
		"weapon_label": "离子炮",
	},
}


## 获取基础原型（返回深拷贝，防止误改常量）
static func get_entry(base_ref: String) -> Dictionary:
	if BASE_ENTRIES.has(base_ref):
		return BASE_ENTRIES[base_ref].duplicate(true)
	return {}


## 获取所有原型 ID
static func get_all_refs() -> Array:
	return BASE_ENTRIES.keys()


## 合并原型 + 覆盖字段（用于个体差异）
## base_ref: 原型ID；overrides: 要覆盖的字段字典
static func resolve(base_ref: String, overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = get_entry(base_ref)
	if base.is_empty():
		return overrides.duplicate(true)
	# 覆盖个别字段
	for key in overrides:
		base[key] = overrides[key]
	return base


## 列出某 combat_kind 的所有原型（用于平衡审查）
static func get_refs_by_combat_kind(combat_kind: int) -> Array:
	var result: Array = []
	for ref in BASE_ENTRIES:
		if int(BASE_ENTRIES[ref].get("combat_kind", -1)) == combat_kind:
			result.append(ref)
	return result
