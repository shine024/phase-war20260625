class_name ModManager
extends RefCounted
## 改装系统 — 从 BlueprintManager 拆分的子模块
## 所有函数为 static，通过 bpm_ref（BlueprintManager 实例）或 mods_dict 访问核心数据

const ModEffects = preload("res://data/mod_effects.gd")
const StarConfig = preload("res://data/blueprint_star_config.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const PowerTiers = preload("res://data/power_tiers.gd")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

## 获取卡牌基础战力（不含改造加成），用于改造消耗公式
## v6.11: 原 star 来自废弃的 get_blueprint_star（恒1），改用固定值1，数值不变
static func get_base_power_for_mod_cost(card_id: String, bpm_ref: Node) -> float:
	var rarity_mul: float = EvolutionHelpers.get_rarity_multiplier(card_id)
	var inherit_bonus: float = float(bpm_ref.blueprint_inherit_bonus.get(card_id, 0.0))
	return (80.0 + 28.0) * rarity_mul * (1.0 + inherit_bonus)

## v6.14: 获取改造模块的最低战力档位要求（按 rarity 派生，无需改 140+ 定义数据）。
## common→GRUNT(无门槛), uncommon→VETERAN, rare→ELITE, epic→CHAMPION, legendary→OVERLORD。
## 未知 rarity 回退 GRUNT（无门槛，向后兼容）。
static func get_min_power_tier_for_mod(mod_id: String) -> int:
	var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
	var rarity: String = String(mod_data.get("rarity", "common"))
	match rarity:
		"common":
			return PowerTiers.Tier.GRUNT
		"uncommon":
			return PowerTiers.Tier.VETERAN
		"rare":
			return PowerTiers.Tier.ELITE
		"epic":
			return PowerTiers.Tier.CHAMPION
		"legendary":
			return PowerTiers.Tier.OVERLORD
		_:
			return PowerTiers.Tier.GRUNT

## v6.14: 检查卡牌当前战力档位是否满足改造安装门槛。
## [param card_power_tier] 卡牌战力档位（PowerTiers.Tier）
## [param mod_id] 改造模块 id
## [return] true = 可安装，false = 战力不足
static func can_install_by_power_tier(card_power_tier: int, mod_id: String) -> bool:
	var min_tier: int = get_min_power_tier_for_mod(mod_id)
	return PowerTiers.meets_requirement(card_power_tier, min_tier)

## 获取当前已装改造数量
static func get_modification_count(card_id: String, mods_dict: Dictionary) -> int:
	var mods: Array = mods_dict.get(card_id, [])
	return mods.size()

## 获取最大改造次数
static func get_max_mod_slots() -> int:
	return ModEffects.MAX_MOD_SLOTS

# v6.6: 以下旧改造系统方法已移除（死代码）：
#   - get_modification_requirements（基于 ModEffects 槽位成本公式，新系统用 install_modification 动态算纳米）
#   - get_mod_options（返回 ModEffects 的 MOD_01~20，与新 140+ 模块系统不兼容）
#   - can_apply_modification（基于旧系统的资源校验）
#   - apply_modification（option_id "offense/defense/utility" 在 ModEffects 查不到，永远失败）
# 改造安装统一走 BlueprintManager.install_modification(card, mod_id)。
# ModEffects.MOD_DATA（MOD_01~20）保留供 save_migration_v6 的老存档迁移映射使用。

## 检查卡片是否已安装敌源改造模块（EOM_前缀）
static func has_enemy_origin_mod(card_id: String, mods_dict: Dictionary) -> bool:
	var mods: Array = mods_dict.get(card_id, [])
	if mods is Array:
		for m in mods:
			var entry_id = m.get("id", "") if m is Dictionary else String(m)
			if entry_id.begins_with("EOM_"):
				return true
	return false
