class_name ModManager
extends RefCounted
## 改装系统 — 从 BlueprintManager 拆分的子模块
## 所有函数为 static，通过 bpm_ref（BlueprintManager 实例）或 mods_dict 访问核心数据

const ModEffects = preload("res://data/mod_effects.gd")
const PowerTiers = preload("res://data/power_tiers.gd")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")

## 获取卡牌基础战力（不含改造加成），用于改造消耗公式
## v6.11: 原 star 来自废弃的 get_blueprint_star（恒1），改用固定值1，数值不变
static func get_base_power_for_mod_cost(card_id: String, bpm_ref: Node) -> float:
	var rarity_mul: float = EvolutionHelpers.get_rarity_multiplier(card_id)
	var inherit_bonus: float = float(bpm_ref.blueprint_inherit_bonus.get(card_id, 0.0))
	return (80.0 + 28.0) * rarity_mul * (1.0 + inherit_bonus)

## v6.14: 获取改造模块的最低战力档位要求（按 rarity 派生，无需改 140+ 定义数据）。
## common→GRUNT(无门槛), uncommon→VETERAN, rare→ELITE, epic→CHAMPION, legendary/mythic→OVERLORD。
## 未知 rarity 回退 GRUNT（无门槛，向后兼容）。
## v27：mythic 补分支——此前回退 GRUNT 是陷阱（顶级改造反而无门槛）。
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
		"mythic":
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
## v7.x 修复(M2): blueprint_mods 的 key 可能是 instance_id（cold_t72#1，由
## _update_blueprint_mods_cache_for_card 写入）或裸 card_id（cold_t72，旧路径写入）。
## 调用方传的 key 不一定是写入时的同款——传 card_id 查实例 key 会漏。
## 这里查两次：先按传入 key 直查，没命中再按"去掉 #序号后缀"的 base key 查，
## 覆盖 instance→base 与 base→instance 两种错配。
static func get_modification_count(card_id: String, mods_dict: Dictionary) -> int:
	var mods: Array = mods_dict.get(card_id, [])
	if mods.is_empty():
		# v7.x M2: 直查未命中，尝试 base card_id 形式（去掉 #N 后缀）
		var hi: int = card_id.rfind("#")
		if hi > 0:
			mods = mods_dict.get(card_id.substr(0, hi), [])
	return mods.size()

## 获取最大改造次数
static func get_max_mod_slots() -> int:
	return ModEffects.MAX_MOD_SLOTS

## ═══════════════════════════════════════════════════════════
##  v6.16 槽位预算（品质定基础槽 + 兵种专属加成槽）
## ═══════════════════════════════════════════════════════════
## 设计：底盘稀有度管两件事——基础值（卡表）+ 改造成长上限（本表）；
## 兵种专属槽只收兵种件（registry.is_family_mod），通用件（universal/enhancement）
## 只占基础槽。总开关 GameConfig.mod_slot_budget_enabled（false=全卡恒 9 旧口径）。
## 旧档超额（如统一 9 槽时代给 common 卡装满 9 件）不剥离——can_install 只封新装。

## 品质 → 基础槽数（通用件与兵种件共享的上限基准）
const SLOT_BUDGET_BY_RARITY: Dictionary = {
	"common": 5, "uncommon": 6, "rare": 7, "epic": 8, "legendary": 9, "mythic": 10,
}
## 兵种 → 专属加成槽数（CombatKind：0轻装/1装甲/2支援/3空军/4堡垒）
## 堡垒 +2（防御堆叠身份），其余 +1；无 combat_kind 的卡（能量/法则卡）无加成
const FAMILY_SLOT_BONUS_BY_KIND: Dictionary = {4: 2}
const FAMILY_SLOT_BONUS_DEFAULT: int = 1

## 品质基础槽（未知稀有度回退 9 = v6.16 前旧口径，宁松勿紧防误锁）
static func get_base_mod_slots(card) -> int:
	if not GameConfig.get_default().mod_slot_budget_enabled or card == null:
		return ModEffects.MAX_MOD_SLOTS
	return int(SLOT_BUDGET_BY_RARITY.get(String(card.rarity), ModEffects.MAX_MOD_SLOTS))

## 兵种专属加成槽
static func get_family_slot_bonus(card) -> int:
	if not GameConfig.get_default().mod_slot_budget_enabled or card == null:
		return 0
	if not ("combat_kind" in card):
		return 0  # 能量/法则等非战斗卡无兵种概念
	return int(FAMILY_SLOT_BONUS_BY_KIND.get(int(card.combat_kind), FAMILY_SLOT_BONUS_DEFAULT))

## 该卡改造槽总数（UI 砖块数 / 安装容量 / 过滤口径的唯一真身）
static func get_max_mod_slots_for_card(card) -> int:
	if not GameConfig.get_default().mod_slot_budget_enabled or card == null:
		return ModEffects.MAX_MOD_SLOTS
	return get_base_mod_slots(card) + get_family_slot_bonus(card)

# v6.6: 以下旧改造系统方法已移除（死代码）：
#   - get_modification_requirements（基于 ModEffects 槽位成本公式，新系统用 install_modification 动态算纳米）
#   - get_mod_options（返回 ModEffects 的 MOD_01~20，与新 140+ 模块系统不兼容）
#   - can_apply_modification（基于旧系统的资源校验）
#   - apply_modification（option_id "offense/defense/utility" 在 ModEffects 查不到，永远失败）
# 改造安装统一走 BlueprintManager.install_modification(card, mod_id)。
# ModEffects.MOD_DATA（MOD_01~20）保留供 save_migration_v6 的老存档迁移映射使用。
