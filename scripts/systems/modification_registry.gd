extends Node
## 改造模块注册表
## 管理所有140+个改造模块的注册、查询和验证

const InfantryModifications = preload("res://data/modification_modules/infantry_mods.gd")
const ArmorModifications = preload("res://data/modification_modules/armor_mods.gd")
const ArtilleryModifications = preload("res://data/modification_modules/artillery_mods.gd")
const AntiAirModifications = preload("res://data/modification_modules/anti_air_mods.gd")
const AirModifications = preload("res://data/modification_modules/air_mods.gd")
const ReconModifications = preload("res://data/modification_modules/recon_mods.gd")
const EngineerModifications = preload("res://data/modification_modules/engineer_mods.gd")
const FortModifications = preload("res://data/modification_modules/fort_mods.gd")
const UniversalModifications = preload("res://data/modification_modules/universal_mods.gd")
const EnhancementModifications = preload("res://data/modification_modules/enhancement_mods.gd")  # v6.4 强化词条统一

## ─────────────────────────────────────────────
##  缓存
## ─────────────────────────────────────────────

static var _cache: Dictionary = {}
static var _initialized: bool = false
# v7.x 性能：get_for_unit_type 结果缓存。unit_type(CombatKind int) → mod_id 字符串数组。
# 该函数每次 append_array 10 个模块（约154条），掉落生成时每个击败敌人调一次，
# 相位师战胜调5次，单场可达数千次重复 concat。返回值全程只读遍历，缓存安全。
static var _unit_type_cache: Dictionary = {}
# v8.x 性能：扁平反向索引 mod_id → mod_data（直接引用，非深拷贝）。
# 原 get_data 每次 for type_key in _cache.keys() 线性扫描 + duplicate(true) 深拷贝，
# modification_panel 渲染改造列表时每个 mod_id 调一次（M 改造 × N 卡），是首开热点。
# 索引在 register_all 末尾一次性建好，get_data 命中后 O(1) 返回。
# 注意：返回值仍是 .duplicate(true) 以保持调用方"修改不影响缓存"的既有契约。
static var _flat_index: Dictionary = {}

## ─────────────────────────────────────────────
##  v10 改造二分法：机制改造 vs 交换比改造
## ─────────────────────────────────────────────
## 设计原则：改造分两类——
##   机制改造（mechanic）：改变单位"怎么打"（行为规则/触发条件/新能力）。
##     例：爆反反弹、APS拦截、连击爆发、破甲叠层、标记集火、跨维度武器、DOT弹头。
##   交换比改造（ratio）：改变"打得多划算"（数值效率）。
##     例：攻击+15%、防御+20%、攻速-10%、HP+10%。
## 玩家感知差异：机制改造改变战法（可组合出新解法），交换比改造只是变强。
## 分类依据 effect key：effects 命中 MECHANIC_EFFECT_KEYS 任一 key → mechanic。
## 新增机制型 effect 时必须把 key 加进此表，否则面板会把它当数值改造显示。

const MECHANIC_EFFECT_KEYS: Array = [
	# 反伤/拦截（受击规则变化）
	"reactive_armor", "reflect_charges", "intercept_system", "intercept_charges", "missile_intercept",
	# 成长爆发（积累触发规则）
	"combo_system", "combo_bonus", "rage_system", "rage_bonus",
	# 叠层 debuff（持续性规则变化）
	"armor_break", "armor_break_stacks",
	# 标记系统（集火规则）
	"crit_mark_chance", "crit_mark_bonus", "crit_mark_duration",
	"target_marking", "mark_vuln", "mark_duration",
	# 真实伤害/百分比伤害（绕过护甲规则）
	"true_damage", "siege_bonus_pct",
	# DOT 弹头（持续伤害规则）
	"chem_chance", "chem_dps", "chem_duration", "burn_chance", "burn_dps", "burn_duration", "nano_infect",
	# 亡语/濒死（死亡规则变化）
	"death_heal", "death_heal_radius", "ifak_revive",
	# 溅射（范围规则）
	"splash_radius", "splash_damage",
	# 反炮兵（反击规则）
	"counter_battery", "has_counter_battery",
	# 跨维度武器创造（攻击维度解锁）
	"grant_slot",
	# 弹道类型（行为变化：散射/直射/火箭/曲射）
	"weapon_type", "slot_weapon_type",
	# 条件规则（环境/位置条件加成）
	"urban_defense", "night_bonus", "smoke_ignore", "mine_immunity",
	# 击杀修复/回收（资源转换规则——机制型，设定包装待后续迭代）
	"kill_repair",
	# v10 转换型（劣势转优势）
	"salvage_repair", "phase_shift_counter", "hijack_aura_radius", "hijack_aura_duration", "hijack_aura_cd",
]

## 改造分类查询：返回 "mechanic"（机制改造）或 "ratio"（交换比改造）。
## 依据 effects 字典是否含 MECHANIC_EFFECT_KEYS 中的 key。
static func get_mod_class(mod_id: String) -> String:
	var data: Dictionary = get_data(mod_id)
	if data.is_empty():
		return "ratio"
	var effects: Dictionary = data.get("effects", {})
	if not effects.is_empty() and _has_mechanic_key(effects):
		return "mechanic"
	# 强化词条（level_effects 分级）也检查
	var level_effects: Dictionary = data.get("level_effects", {})
	for lv in level_effects.keys():
		var lv_fx: Dictionary = level_effects[lv]
		if lv_fx is Dictionary and not lv_fx.is_empty() and _has_mechanic_key(lv_fx):
			return "mechanic"
	return "ratio"


static func _has_mechanic_key(effects: Dictionary) -> bool:
	for k in effects.keys():
		if MECHANIC_EFFECT_KEYS.has(k):
			return true
	return false


## 改造分类显示信息（改造面板/情报面板用）。
## 返回 {class: String, tag: String, color: String}：
##   mechanic → {tag: "机制", color: "#ff9d4d"}（橙色高亮——改变战法）
##   ratio    → {tag: "数值", color: "#8a94a6"}（灰色——变强）
static func get_mod_class_display(mod_id: String) -> Dictionary:
	if get_mod_class(mod_id) == "mechanic":
		return {"class": "mechanic", "tag": "机制", "color": "#ff9d4d"}
	return {"class": "ratio", "tag": "数值", "color": "#8a94a6"}

## ─────────────────────────────────────────────
##  初始化
## ─────────────────────────────────────────────

func _ready() -> void:
	# v7.x 性能优化：不在 autoload 启动时同步 register_all（注册 154 条改造 + 10 模块类 preload 链）。
	# 所有查询入口（get_data/get_for_unit_type/get_mods_for_card/check_conflict/validate_slot_type/
	# apply_effects/apply_with_level/apply_to_weapon_slot(s)/get_all_ids）首行均调 _ensure_initialized()，
	# 首次查询会自动触发 register_all。开销从启动期转移到首次战斗构建 unit_stats 时。
	pass

## ─────────────────────────────────────────────
##  注册
## ─────────────────────────────────────────────

## 注册所有改造模块
static func register_all() -> void:
	if _initialized:
		return

	_cache.clear()
	_unit_type_cache.clear()  # v7.x 性能：重注册时同步清掉 get_for_unit_type 缓存
	_register_modifications("infantry", InfantryModifications)
	_register_modifications("armor", ArmorModifications)
	_register_modifications("artillery", ArtilleryModifications)
	_register_modifications("anti_air", AntiAirModifications)
	_register_modifications("air", AirModifications)
	_register_modifications("recon", ReconModifications)
	_register_modifications("engineer", EngineerModifications)
	_register_modifications("fort", FortModifications)
	_register_modifications("universal", UniversalModifications)
	_register_modifications("enhancement", EnhancementModifications)  # v6.4 强化词条统一

	# v8.x 性能：建扁平反向索引（mod_id → mod_data），让 get_data 从 O(N) 扫描降到 O(1)。
	_rebuild_flat_index()

	_initialized = true
	# [LOG-v5.1] print("[ModificationRegistry] Registered %d modification modules" % _count_total())

static func _register_modifications(type_key: String, class_ref: RefCounted) -> void:
	var mod_ids = class_ref.get_all_mod_ids()
	var type_cache = {}

	for mod_id in mod_ids:
		type_cache[mod_id] = class_ref.get_mod_data(mod_id)

	_cache[type_key] = type_cache

## v8.x 性能：扁平索引构建。遍历 _cache（按 type_key 分组）平铺成 mod_id → data 字典。
## 同一 mod_id 跨 type_key 重复时取首个（理论上不应发生，duplicate 防御）。
static func _rebuild_flat_index() -> void:
	_flat_index.clear()
	for type_key in _cache.keys():
		var type_cache: Dictionary = _cache[type_key]
		for mod_id in type_cache.keys():
			if not _flat_index.has(mod_id):
				_flat_index[mod_id] = type_cache[mod_id]

static func _count_total() -> int:
	var count = 0
	for type_key in _cache.keys():
		count += _cache[type_key].size()
	return count

## ─────────────────────────────────────────────
##  查询接口
## ─────────────────────────────────────────────

## 获取改造数据
static func get_data(mod_id: String) -> Dictionary:
	_ensure_initialized()

	# v8.x 性能：优先查扁平索引（O(1)），替代原 for type_key 线性扫描（O(N)，10 个 type_key）。
	if _flat_index.has(mod_id):
		return _flat_index[mod_id].duplicate(true)

	# 回退1：解析ID前缀获取类型（保留原逻辑兼容历史 mod_id 命名）
	var prefix = mod_id.split("_")[0]  # "inf", "arm", "art"...
	var type_key = _prefix_to_type(prefix)

	if not type_key.is_empty() and _cache.has(type_key):
		var bucket: Dictionary = _cache[type_key]
		if bucket.has(mod_id):
			# 命中但未进索引（理论不应发生，注册期已建全），补登索引并返回
			_flat_index[mod_id] = bucket[mod_id]
			return bucket[mod_id].duplicate(true)

	return {}

## 获取特定兵种的所有改造
static func get_for_unit_type(unit_type: int) -> Array:
	_ensure_initialized()

	# v7.x 性能：命中缓存直接返回（数组全程只读，安全共享引用）
	if _unit_type_cache.has(unit_type):
		return _unit_type_cache[unit_type]

	var result = []
	result.append_array(InfantryModifications.get_for_unit_type(unit_type))
	result.append_array(ArmorModifications.get_for_unit_type(unit_type))
	result.append_array(ArtilleryModifications.get_for_unit_type(unit_type))
	result.append_array(AntiAirModifications.get_for_unit_type(unit_type))
	result.append_array(AirModifications.get_for_unit_type(unit_type))
	result.append_array(ReconModifications.get_for_unit_type(unit_type))
	result.append_array(EngineerModifications.get_for_unit_type(unit_type))
	result.append_array(FortModifications.get_for_unit_type(unit_type))
	result.append_array(UniversalModifications.get_for_unit_type(unit_type))
	# v6.4: 强化词条适用于所有兵种
	result.append_array(EnhancementModifications.get_for_unit_type(unit_type))
	# v7.x 性能：缓存结果，后续调用 O(1) 命中
	_unit_type_cache[unit_type] = result
	return result

## 按 card_id 精筛改造（比 get_for_unit_type 更精确）
static func get_mods_for_card(card_id: String) -> Array:
	_ensure_initialized()
	var result = []
	result.append_array(InfantryModifications.get_for_card(card_id))
	result.append_array(ArmorModifications.get_for_card(card_id))
	result.append_array(ArtilleryModifications.get_for_card(card_id))
	result.append_array(AntiAirModifications.get_for_card(card_id))
	result.append_array(AirModifications.get_for_card(card_id))
	result.append_array(ReconModifications.get_for_card(card_id))
	result.append_array(EngineerModifications.get_for_card(card_id))
	result.append_array(FortModifications.get_for_card(card_id))
	result.append_array(UniversalModifications.get_for_card(card_id))
	# v6.4: 强化词条适用所有卡
	result.append_array(EnhancementModifications.get_for_card(card_id))
	return result

## 检查改造冲突
static func check_conflict(card: Dictionary, mod_id: String) -> bool:
	_ensure_initialized()

	var mod_data = get_data(mod_id)
	var conflict_group = mod_data.get("conflict_group", "")

	if conflict_group.is_empty():
		return false  # 无冲突

	var installed = card.get("installed_modifications", [])
	for installed_mod in installed:
		var installed_id = installed_mod.get("id", "") if installed_mod is Dictionary else String(installed_mod)
		var installed_data = get_data(installed_id)
		var installed_group = installed_data.get("conflict_group", "")
		if installed_group == conflict_group:
			return true  # 冲突

	return false

## 验证槽位类型
static func validate_slot_type(mod_id: String, slot_type: String) -> bool:
	_ensure_initialized()

	var mod_data = get_data(mod_id)
	var mod_slot_type = mod_data.get("slot_type", "")
	return mod_slot_type == slot_type or mod_slot_type == "universal"

## 计算改造效果（应用到属性）
static func apply_effects(base_stats: Dictionary, modifications: Array) -> Dictionary:
	_ensure_initialized()

	var result = base_stats.duplicate(true)

	for mod_entry in modifications:
		# v6.5: 跳过已禁用的改造
		if mod_entry is Dictionary:
			if mod_entry.has("enabled") and not bool(mod_entry.get("enabled", true)):
				continue
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else String(mod_entry)
		var mod_data = get_data(mod_id)
		var effects = mod_data.get("effects", {})
		if effects.is_empty():
			continue
		# v6.4: 复用统一的单条应用逻辑
		result = _apply_single_mod_effects(result, effects)

	return result


## v6.4: 按等级应用改造效果（统一5套系统的等级概念）
## modifications: Array of {id, level} 或 {id}（默认level=1）或纯String（默认level=1）
## 支持改造条目里的 level_effects（每级不同效果）或 effects（无等级差异时用，所有等级相同）
static func apply_with_level(base_stats: Dictionary, modifications: Array) -> Dictionary:
	_ensure_initialized()

	var result = base_stats.duplicate(true)

	for mod_entry in modifications:
		var mod_id: String = ""
		var mod_level: int = 1
		if mod_entry is Dictionary:
			mod_id = String(mod_entry.get("id", ""))
			mod_level = int(mod_entry.get("level", 1))
			# v6.5: 跳过已禁用的改造（仅武器类改造可禁用，但这里统一检查）
			# 旧存档无 enabled 字段时默认视为启用（true）
			if mod_entry.has("enabled") and not bool(mod_entry.get("enabled", true)):
				continue
		else:
			mod_id = String(mod_entry)
		if mod_id.is_empty():
			continue
		mod_level = clampi(mod_level, 1, 3)  # 等级统一1-3

		var mod_data: Dictionary = get_data(mod_id)
		if mod_data.is_empty():
			continue

		# 优先使用 level_effects（每级不同），否则用 effects（所有等级相同）
		var effects: Dictionary = {}
		var level_effects: Dictionary = mod_data.get("level_effects", {})
		if not level_effects.is_empty() and level_effects.has(mod_level):
			effects = level_effects[mod_level]
		else:
			effects = mod_data.get("effects", {})

		# 应用效果（复用 apply_effects 的单条逻辑）
		result = _apply_single_mod_effects(result, effects)

	return result


## v6.4: 内部辅助——对单个 effects 字典应用到一个 stats 字典（apply_effects 的单条逻辑抽取）
static func _apply_single_mod_effects(result: Dictionary, effects: Dictionary) -> Dictionary:
	for effect_key in effects.keys():
		var effect_value = effects[effect_key]
		match effect_key:
			"attack_light", "attack_armor", "attack_air", \
			"defense_light", "defense_armor", "defense_air", "max_hp":
				if not result.has(effect_key):
					result[effect_key] = 0
				if effect_value is float:
					result[effect_key] = int(float(result[effect_key]) * (1.0 + effect_value))
				elif effect_value is int:
					result[effect_key] += effect_value
			# v6.9→v7.5: move_speed → 重定向为部署延迟百分比（玩家单位格子战术不移动，move_speed 为死属性）
			# v7.x 平衡修订：系数 0.005→0.02（×4）。原 0.005 让 move_speed=20→-0.1 几乎无体感；
			# 现 move_speed=20→-0.4（明显减部署延迟），机动类改造（涡扇/燃气轮机/外骨骼）体感恢复。
			# v7.5 修正符号：原 v6.9 用 += 导致 +speed 反而增加延迟（与注释"减延迟"矛盾），改为 -=
			# 数据层 move_speed 数值保留原样（语义注释为原始设计值），仅在此闸门重定向
			"move_speed":
				if not result.has("deploy_delay_bonus"):
					result["deploy_delay_bonus"] = 0.0
				result["deploy_delay_bonus"] -= float(effect_value) * 0.02
			"attack_range":
				if not result.has(effect_key):
					result[effect_key] = 0
				result[effect_key] += effect_value
			"attack_interval":
				# v7.5: attack_interval 是死字段（v5.0 起战斗读 per-target attack_*_speed）
				# 负 interval bonus（如 -0.30）转成 speed 增益：speed *= (1 - bonus) = 1.30
				# 同时写入三个 per-target speed，覆盖所有攻击目标维度
				var _iv: float = float(effect_value)
				var _speed_mult: float = maxf(0.1, 1.0 - _iv)  # interval↑ → speed↓；下限保护
				for _sk in ["attack_light_speed", "attack_armor_speed", "attack_air_speed"]:
					if not result.has(_sk):
						result[_sk] = 1.0
					result[_sk] = maxf(0.1, float(result[_sk]) * _speed_mult)
			"deploy_speed":
				if not result.has(effect_key):
					result[effect_key] = 0
				result[effect_key] = max(0, int(result[effect_key]) + int(effect_value))
			# v7.x 平衡修订：dodge_chance 单独拆出，cap 统一为 0.50（与重定向类 dodge 来源一致）
			"dodge_chance":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(0.50, float(result[effect_key]) + float(effect_value))
			"crit_chance", "crit_resist", "armor_penetration", \
			"armor_pen_vs_light", "armor_pen_vs_armor", "armor_pen_vs_air":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(1.0, float(result[effect_key]) + float(effect_value))
			# v6.6: attack_fort → 条件型对堡垒伤害加成（温压弹/爆破装置）
			# 加法叠加（值是正小数），仅在 get_attack_vs() 对 FORT 目标时生效
			"attack_fort":
				if not result.has("attack_fort_bonus"):
					result["attack_fort_bonus"] = 0.0
				result["attack_fort_bonus"] += float(effect_value)
			# v6.6: splash_radius → 溅射半径乘数加成（子母弹/近炸引信）
			"splash_radius":
				if not result.has("splash_radius_bonus"):
					result["splash_radius_bonus"] = 0.0
				result["splash_radius_bonus"] += float(effect_value)
			# v6.6: single_target_penalty → 主目标伤害乘数（负值，子母弹平衡项）
			"single_target_penalty":
				if not result.has("single_target_penalty"):
					result["single_target_penalty"] = 0.0
				result["single_target_penalty"] += float(effect_value)
			# v7.5: accuracy_bonus 命中提升 → 暴击伤害加成（"打得更准"=暴击更疼）
			# 原 v6.6 映射为 crit_chance（暴击率）数值偏爆表（0.25~0.50），改 crit_damage_bonus 更温和
			# 涉及 aa_01/aa_02/aa_06/aa_11/art_01/art_09/air_06 等核心火控改造
			"accuracy_bonus":
				if not result.has("crit_damage_bonus"):
					result["crit_damage_bonus"] = 0.0
				result["crit_damage_bonus"] += float(effect_value)
			# v8.x: ifak_heal 分支已移除（孤儿死代码）——inf_18/rec_10 在 v7.x 第二批已改用 ifak_revive（真实濒死复活机制），
			# 此分支再无任何改造数据使用，删除以减少 _apply_single_mod_effects 的无效分支噪声。
			# v7.5: mine_immunity 防地雷 → 三维防御全加（原映射 damage_reduction 空转：take_damage 从不读 damage_reduction）
			# gen_07_mine_resistant 布尔型（true），激活时给三维防御加成。
			# v8.x: 系数 0.15→0.30——原 0.15 对装甲载体仅 3-7% 实际减伤（乘法稀释），与同价位
			# 倾斜装甲(+20%)/复合装甲(+30%) 相比过弱；提升到 0.30 对齐 epic 档位（arm_14_mine_plow 描述已同步）。
			"mine_immunity":
				var _mine_def_val: float = 0.30 if bool(effect_value) else 0.0
				for _dk in ["defense_light", "defense_armor", "defense_air"]:
					if not result.has(_dk):
						result[_dk] = 0
					result[_dk] = int(float(result[_dk]) * (1.0 + _mine_def_val))
			# nbq_immunity：三防免疫 → 减伤（语义保留，防护类）
			# v8.x: bool(true) 经 float()=1.0 会顶到 cap 0.75（for_04/gen_08 装上即 75% 减伤，偏强），
			# bool 值改为固定 0.30（合理减伤），float 值保持原逻辑向后兼容
			"nbq_immunity":
				if not result.has("damage_reduction"):
					result["damage_reduction"] = 0.0
				var _nbq_val: float = 0.30 if bool(effect_value) and typeof(effect_value) == TYPE_BOOL else float(effect_value)
				result["damage_reduction"] = min(0.75, float(result["damage_reduction"]) + _nbq_val)
			# sustained_fire：持续射击 → 攻速提升（v7.5: 转写三个 per-target speed）
			# 正值（如 0.50）→ speed *= (1 + value) = 1.50
			"sustained_fire":
				var _sf_mult: float = maxf(0.1, 1.0 + float(effect_value))
				for _sfk in ["attack_light_speed", "attack_armor_speed", "attack_air_speed"]:
					if not result.has(_sfk):
						result[_sfk] = 1.0
					result[_sfk] = maxf(0.1, float(result[_sfk]) * _sf_mult)
			# v6.6: missile_dodge → 映射为通用闪避（反导主题改造：gen_09/aa_09/air_08）
			# 当前弹道无"导弹 vs 其他"区分维度，干净映射为 dodge_chance
			"missile_dodge":
				if not result.has("dodge_chance"):
					result["dodge_chance"] = 0.0
				# v7.x: 闪避上限 0.50（统一所有闪避映射口径）
				result["dodge_chance"] = min(0.50, float(result["dodge_chance"]) + float(effect_value))
			# v7.5: counter_bonus 精确还击 → 暴击伤害加成（与 accuracy_bonus 同口径，"打得更准"=暴击更疼）
			# 原 v6.6 映射 crit_chance，现统一为 crit_damage_bonus
			"counter_bonus":
				if not result.has("crit_damage_bonus"):
					result["crit_damage_bonus"] = 0.0
				result["crit_damage_bonus"] += float(effect_value)
			"damage_reduction":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(0.75, float(result[effect_key]) + float(effect_value))
			"crit_damage_bonus", "shield_on_kill", "hp_regen":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] += float(effect_value)
			"kill_repair":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(0.6, float(result[effect_key]) + float(effect_value))
			"splash_damage":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(0.8, float(result[effect_key]) + float(effect_value))
			"chain_chance":
				if not result.has(effect_key):
					result[effect_key] = 0.0
				result[effect_key] = min(0.6, float(result[effect_key]) + float(effect_value))
			# v6.5→v6.6: 武器类改造改变武器型号（SHOTGUN/SNIPER/MISSILE 等 legacy 型号）
			# 修复前：直接写入 weapon_type，污染了弹道类型字段（WeaponType 4值枚举），
			# 导致 MISSILE(9) 被 AI 误判为非曲射。现写入独立的 legacy_weapon_type 字段
			# （UnitStats/WeaponResource 均有此字段，bullet 的 VFX/弹道 match 读它）
			"weapon_type", "legacy_weapon_type":
				result["legacy_weapon_type"] = int(effect_value)
			# ── v7.5: 视野/侦察类 → 暴击率（"看得更清"=命中要害概率提升）
			# 原 v6.8 映射为 attack_range（射程延伸），现改为 crit_chance
			# gen_01_comms / gen_06_laser_designator / rec_05_uav / for_06_radar
			# detection_range 是负值（rec_01 -0.50），取绝对值转为正增益
			"vision", "vision_bonus", "stealth_detect", "detection_range":
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				result["crit_chance"] = min(1.0, float(result["crit_chance"]) + absf(float(effect_value)))
			# 夜视/烟雾穿透类 → 暴击率（精确射击语义）
			# inf_20_night_vision / rec_08_nvg / arm_12_thermal_sight / inf_21_thermal
			# v8.x: smoke_ignore 是 bool(true)，经 float()=1.0 会顶到 100% 暴击（inf_21/arm_12 装上即满暴击，偏强），
			# bool 值改为固定 0.15（合理暴击加成），night_bonus(float) 保持原逻辑向后兼容
			"night_bonus", "smoke_ignore":
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				var _nsi_val: float = 0.15 if bool(effect_value) and typeof(effect_value) == TYPE_BOOL else float(effect_value)
				result["crit_chance"] = min(1.0, float(result["crit_chance"]) + _nsi_val)
			# 热防护/三防类 → 减伤（防护语义同源）
			# rec_02_ir_suppression / arm_02_composite_armor
			# v8.x: heat_immunity_once 从条件移除（孤儿死代码）——arm_03 在 v7.x 第二批已改用 reactive_armor（真实爆反），
			# 该 key 再无任何改造数据使用，移除以减少条件列表噪声。
			"thermal_immunity", "heat_resist":
				if not result.has("damage_reduction"):
					result["damage_reduction"] = 0.0
				result["damage_reduction"] = min(0.75, float(result["damage_reduction"]) + float(effect_value))
			# v7.5: mine_damage_reduction 防地雷伤害 → 三维防御全加
			# 原 v6.8 映射 damage_reduction 空转（take_damage 从不读 damage_reduction）
			# universal gen_07 值为 -0.80（负值偏大），取绝对值 ×0.25 缩放（≈0.20，对齐 enh_def_flat Lv2）
			"mine_damage_reduction":
				var _mdr_def_val: float = absf(float(effect_value)) * 0.25
				for _dk2 in ["defense_light", "defense_armor", "defense_air"]:
					if not result.has(_dk2):
						result[_dk2] = 0
					result[_dk2] = int(float(result[_dk2]) * (1.0 + _mdr_def_val))
			# 隐蔽/低可探测类 → 闪避（难被发现=难被命中）
			# gen_03_camouflage / for_07_camouflage
			"detection_reduce":
				if not result.has("dodge_chance"):
					result["dodge_chance"] = 0.0
				# detection_reduce 是负值（-0.20），取绝对值映射为闪避增益
				# v7.x: 闪避上限 0.50（防消音器-0.80 类映射出 0.80 半无敌闪避）
				result["dodge_chance"] = min(0.50, float(result["dodge_chance"]) + absf(float(effect_value)))
			# 巷战加成类 → 对轻装伤害（巷战主要打击步兵/轻装）
			# inf_22_breaching / rec_09_breaching
			"urban_attack_bonus":
				if not result.has("attack_light"):
					result["attack_light"] = 0
				if effect_value is float:
					result["attack_light"] = int(float(result["attack_light"]) * (1.0 + effect_value))
				elif effect_value is int:
					result["attack_light"] += effect_value
			# ── v7.5: 视野/作战半径类 → 暴击率（与第一批视野类同口径）
			# air_10_drop_tank(combat_range) 原 v6.8 映射 attack_range，现改 crit_chance
			"combat_range":
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				result["crit_chance"] = min(1.0, float(result["crit_chance"]) + absf(float(effect_value)))
			# v7.5: close_accuracy 近距精确 → 暴击伤害（与 accuracy_bonus/counter_bonus 同口径）
			# air_07_dogfight_missile，原 v6.8 映射 crit_chance，现统一为 crit_damage_bonus
			"close_accuracy":
				if not result.has("crit_damage_bonus"):
					result["crit_damage_bonus"] = 0.0
				result["crit_damage_bonus"] += float(effect_value)
			"enemy_confusion", "intel_speed":
				# 敌方混乱/情报优势 → 暴击率（精确打击语义，保留原映射）
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				result["crit_chance"] = min(1.0, float(result["crit_chance"]) + float(effect_value))
			# 弹药/持续作战类 → 攻速提升（弹药充足=持续射速，负 attack_interval）
			# air_11_weapon_rack(ammo_capacity) / air_09_air_refuel(sustained_combat)
			# aa_06_laser(infinite_ammo) / aa_12_fire_on_move(mobile_fire)
			"ammo_capacity", "sustained_combat":
				# v7.5: 转写三个 per-target speed（原写 attack_interval 死字段）
				var _ac_mult: float = maxf(0.1, 1.0 + float(effect_value))
				for _ack in ["attack_light_speed", "attack_armor_speed", "attack_air_speed"]:
					if not result.has(_ack):
						result[_ack] = 1.0
					result[_ack] = maxf(0.1, float(result[_ack]) * _ac_mult)
			"infinite_ammo", "mobile_fire":
				# 布尔型：无限弹药/行进间射击 → 攻速小幅提升（true 时 speed ×1.10）
				if bool(effect_value):
					for _iak in ["attack_light_speed", "attack_armor_speed", "attack_air_speed"]:
						if not result.has(_iak):
							result[_iak] = 1.0
						result[_iak] = maxf(0.1, float(result[_iak]) * 1.10)
			"accuracy_penalty":
				# 精度惩罚（负值）→ 暴击率降低（aa_12 行进间射击的平衡项）
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				result["crit_chance"] = max(0.0, float(result["crit_chance"]) + float(effect_value))
			# 反装甲/反轻装类 → 对应维度伤害加成
			# for_08_trench(enemy_armor_slow -0.50) → 对装甲；for_09_minefield(approach_damage) → 对轻装
			"enemy_armor_slow":
				if not result.has("attack_armor"):
					result["attack_armor"] = 0
				result["attack_armor"] = int(float(result["attack_armor"]) * (1.0 + absf(float(effect_value))))
			"approach_damage":
				if not result.has("attack_light"):
					result["attack_light"] = 0
				if effect_value is float:
					result["attack_light"] = int(float(result["attack_light"]) * (1.0 + float(effect_value)))
			# 隐蔽/反锁定类 → 闪避（负值取绝对值转为闪避增益）
			# air_03_stealth_coating(lock_reduction -0.40) / rec_03_suppressor(fire_exposure -0.80)
			# aa_10_camouflage(aggro_reduce -0.30)
			# v7.x: 闪避上限 0.50（防消音器-0.80 映射出 0.80 半无敌闪避）
			"lock_reduction", "fire_exposure", "aggro_reduce":
				if not result.has("dodge_chance"):
					result["dodge_chance"] = 0.0
				result["dodge_chance"] = min(0.50, float(result["dodge_chance"]) + absf(float(effect_value)))
			# 拦截/防护类 → 减伤（向后兼容旧存档）
			# v8.x: arm_04_aps 与 aa_06_laser 均已迁移到真拦截 intercept_system（完全免伤），
			# 当前改造数据不再使用 missile_intercept；此分支仅保留用于加载旧存档的兼容读取。
			"missile_intercept":
				if not result.has("damage_reduction"):
					result["damage_reduction"] = 0.0
				result["damage_reduction"] = min(0.75, float(result["damage_reduction"]) + float(effect_value))
			# v7.5: urban_move_bonus 巷战机动 → 部署延迟百分比（原写 move_speed 死字段）
			# 与 move_speed effect 同口径（系数 0.02），正值→部署更快
			"urban_move_bonus":
					if not result.has("deploy_delay_bonus"):
						result["deploy_delay_bonus"] = 0.0
					result["deploy_delay_bonus"] -= float(effect_value) * 0.02
			# ── v7.x: 光环协同类（ally_*/formation_bonus/command_efficiency）双链路实装 ──
			# 本 match 分支（链路①）：给【装载单位自身】加成，所有值 ×0.5 缩放（原值按多受益设计，
			#   自身单受益需减半平衡）。"命中"类（无独立命中系统）→ 暴击率（复用 v6.6 口径）。
			# 另有 v6.8 光环系统（链路②）：scripts/battle/mod_aura_handler.gd + unit_stats_table.gd
			#   的 _extract_aura_summary_to_meta，把【原始未缩放值】广播给周围同阵营友军（排除自身）。
			# 两链路对象不重叠（自身不进自身光环目标集），故不会对同一单位双重叠加——
			#   载体单位：仅获自身加成（×0.5）；其他友军：仅获光环广播（原值）。
			# 注意：友军端原值未减半，此处的 ×0.5 平衡论证仅对载体自身成立。
			"ally_bonus", "ally_hit_bonus":
				if not result.has("crit_chance"):
					result["crit_chance"] = 0.0
				result["crit_chance"] = min(1.0, float(result["crit_chance"]) + float(effect_value) * 0.5)
			# 弹药补给 → 三维攻速（复用 ammo_capacity 模式）
			"ally_ammo":
				var _aa_mult: float = maxf(0.1, 1.0 + float(effect_value) * 0.5)
				for _aak in ["attack_light_speed", "attack_armor_speed", "attack_air_speed"]:
					if not result.has(_aak):
						result[_aak] = 1.0
					result[_aak] = maxf(0.1, float(result[_aak]) * _aa_mult)
			# 急救站回血 → hp_regen（直接加成）
			"ally_hp_regen":
				if not result.has("hp_regen"):
					result["hp_regen"] = 0.0
				result["hp_regen"] += float(effect_value) * 0.5
			# 发电机（堡垒回血）→ 三维防御（二次缩放×0.25：堡垒回血给非堡垒单位自身再折半）
			"ally_fort_regen":
				var _afr_mult: float = maxf(0.1, 1.0 + float(effect_value) * 0.25)
				for _afrk in ["defense_light", "defense_armor", "defense_air"]:
					if not result.has(_afrk):
						result[_afrk] = 0
					result[_afrk] = int(float(result[_afrk]) * _afr_mult)
			# 伪装网（被发现降低）→ 闪避（复用 detection_reduce 模式，负值取绝对值）
			"ally_detection":
				if not result.has("dodge_chance"):
					result["dodge_chance"] = 0.0
				# v7.x: 闪避上限 0.50
				result["dodge_chance"] = min(0.50, float(result["dodge_chance"]) + absf(float(effect_value)) * 0.5)
			# 架桥设备（涉渡加速）→ 部署延迟
			# v7.x: 系数从 0.005*0.5(=0.0025) 提到 0.05——原值 ally_river_bonus=1.00 是百分比(100%)，
			#        ×0.0025=0.25% 部署加速几乎无用；×0.05=5% 部署加速，匹配 epic 稀有度体感
			"ally_river_bonus":
				if not result.has("deploy_delay_bonus"):
					result["deploy_delay_bonus"] = 0.0
				result["deploy_delay_bonus"] -= float(effect_value) * 0.05
			# 激光指示器（炮火支援）→ 对装甲伤害
			"ally_arty_bonus":
				if not result.has("attack_armor"):
					result["attack_armor"] = 0
				if effect_value is float:
					result["attack_armor"] = int(float(result["attack_armor"]) * (1.0 + float(effect_value) * 0.5))
				elif effect_value is int:
					result["attack_armor"] += int(float(effect_value) * 0.5)
			# 数据链（编队协同，全属性微升）→ 三维攻击全加
			"formation_bonus":
				var _fb_mult: float = maxf(0.1, 1.0 + float(effect_value) * 0.5)
				for _fbk in ["attack_light", "attack_armor", "attack_air"]:
					if not result.has(_fbk):
						result[_fbk] = 0
					result[_fbk] = int(float(result[_fbk]) * _fb_mult)
			# 数字化单兵（指挥效率）→ 三维防御全加
			"command_efficiency":
				var _ce_mult: float = maxf(0.1, 1.0 + float(effect_value) * 0.5)
				for _cek in ["defense_light", "defense_armor", "defense_air"]:
					if not result.has(_cek):
						result[_cek] = 0
					result[_cek] = int(float(result[_cek]) * _ce_mult)
			# ─── v7.x 新机制分支 ───
			# 成长型：连击系统（攻击积累→满后爆发）
			# combo_system 的 value 是触发阈值（命中次数），bonus_mult 通过单独 key 传入
			"combo_system":
				if not result.has("combo_max"):
					result["combo_max"] = 0
				result["combo_max"] = maxi(1, int(float(effect_value)))
			"combo_bonus":
				if not result.has("combo_bonus_mult"):
					result["combo_bonus_mult"] = 0.0
				result["combo_bonus_mult"] = float(result["combo_bonus_mult"]) + float(effect_value)
			# 成长型：怒气系统（受击积累→满后临时增益）
			"rage_system":
				if not result.has("rage_max"):
					result["rage_max"] = 0
				result["rage_max"] = maxi(1, int(float(effect_value)))
			"rage_bonus":
				if not result.has("rage_bonus_mult"):
					result["rage_bonus_mult"] = 0.0
				result["rage_bonus_mult"] = float(result["rage_bonus_mult"]) + float(effect_value)
			# debuff 型：破甲叠加（每次命中降目标防御，可叠加）
			"armor_break":
				if not result.has("armor_break_per_hit"):
					result["armor_break_per_hit"] = 0.0
				result["armor_break_per_hit"] = float(result["armor_break_per_hit"]) + float(effect_value)
				if not result.has("armor_break_max_stacks"):
					result["armor_break_max_stacks"] = 5  # 默认 5 层上限
			"armor_break_stacks":
				result["armor_break_max_stacks"] = maxi(1, int(float(effect_value)))
			# debuff 型：标记系统（命中概率标记，被标记受额外伤害）
			"target_marking":
				if not result.has("mark_chance"):
					result["mark_chance"] = 0.0
				result["mark_chance"] = min(1.0, float(result["mark_chance"]) + float(effect_value))
			"mark_vuln":
				if not result.has("mark_vuln_bonus"):
					result["mark_vuln_bonus"] = 0.0
				result["mark_vuln_bonus"] = float(result["mark_vuln_bonus"]) + float(effect_value)
			"mark_duration":
				result["mark_duration"] = maxf(1.0, float(effect_value))
			# debuff 型：暴击标注系统（命中概率标注，被标注目标受攻击暴击率提升）
			"crit_mark_chance":
				if not result.has("crit_mark_chance"):
					result["crit_mark_chance"] = 0.0
				result["crit_mark_chance"] = min(1.0, float(result["crit_mark_chance"]) + float(effect_value))
			"crit_mark_bonus":
				if not result.has("crit_mark_bonus"):
					result["crit_mark_bonus"] = 0.0
				result["crit_mark_bonus"] = float(result["crit_mark_bonus"]) + float(effect_value)
			"crit_mark_duration":
				result["crit_mark_duration"] = maxf(1.0, float(effect_value))
			# 兵种专属：工兵爆破（对堡垒/装甲百分比掉血）
			"siege_bonus":
				if not result.has("siege_bonus_pct"):
					result["siege_bonus_pct"] = 0.0
				result["siege_bonus_pct"] = float(result["siege_bonus_pct"]) + float(effect_value)
			# 兵种专属：步兵巷战（受装甲/空军攻击减免）
			"urban_defense":
				if not result.has("urban_defense_bonus"):
					result["urban_defense_bonus"] = 0.0
				result["urban_defense_bonus"] = min(0.75, float(result["urban_defense_bonus"]) + float(effect_value))
			# 兵种专属：炮兵反击（被攻击时标记攻击者）
			# v9.x: 炮兵白板已带 has_counter_battery（兵种修正 shots=3），此分支原先只写
			# has=true 对炮兵零增量（装了无变化）。改为叠加 2 次优先反击机会——
			# construct_unit_ai 按次消费 shots，战斗真实生效，战力公式 shots×15 同步捕获。
			"counter_battery":
				result["has_counter_battery"] = true
				if not result.has("counter_battery_shots"):
					result["counter_battery_shots"] = 0
				result["counter_battery_shots"] = int(result["counter_battery_shots"]) + 2
			# ─── v7.x 第二批次新机制分支 ───
			# 濒死复活（IFAK/急救包）
			"ifak_revive":
				result["revive_on_death"] = true
				result["revive_hp_ratio"] = clampf(float(effect_value), 0.05, 0.50)
			# 爆反装甲（受击反伤+消耗层）
			"reactive_armor":
				result["reflect_damage_pct"] = clampf(float(effect_value), 0.0, 1.0)
				if not result.has("reflect_charges"):
					result["reflect_charges"] = 3
			"reflect_charges":
				result["reflect_charges"] = int(effect_value)
			# 拦截（概率伤害归零+次数限制）
			"intercept_system":
				result["intercept_chance"] = clampf(float(effect_value), 0.0, 0.75)
				if not result.has("intercept_charges"):
					result["intercept_charges"] = 3
			"intercept_charges":
				result["intercept_charges"] = int(effect_value)
			# 亡语治疗（死亡时治疗周围友军）
			"death_heal":
				result["death_heal_allies_pct"] = clampf(float(effect_value), 0.0, 1.0)
				if not result.has("death_heal_radius"):
					result["death_heal_radius"] = 180.0
			"death_heal_radius":
				result["death_heal_radius"] = maxf(50.0, float(effect_value))
			# 堡垒区域控制
			"minefield":
				result["minefield_damage"] = maxf(0.0, float(effect_value))
			"slow_aura":
				result["slow_aura_pct"] = clampf(float(effect_value), 0.0, 0.75)
				if not result.has("slow_aura_radius"):
					result["slow_aura_radius"] = 200.0
			"slow_aura_radius":
				result["slow_aura_radius"] = maxf(50.0, float(effect_value))
			"command_aura":
				result["command_aura_bonus"] = clampf(float(effect_value), 0.0, 0.50)
			# 相位护盾（独立池分流）
			"phase_shield":
				result["phase_shield_pool"] = maxf(0.0, float(effect_value))
				if not result.has("phase_shield_regen"):
					result["phase_shield_regen"] = 50.0
			"phase_shield_regen":
				result["phase_shield_regen"] = maxf(0.0, float(effect_value))
			# ─── v10 解题式玩法：转换型改造分支（劣势转优势）───
			# 回收无人机（工兵 eng_14：击杀→按目标最大HP修复自身，吸血的设定合理版）
			"salvage_repair":
				if not result.has("salvage_repair_pct"):
					result["salvage_repair_pct"] = 0.0
				result["salvage_repair_pct"] = min(0.30, float(result["salvage_repair_pct"]) + float(effect_value))
			# 相位偏移（空军 air_16：受暴击→下次必暴，复用 _first_attack_force_crit 充能）
			"phase_shift_counter":
				result["phase_shift_counter"] = true
			# 电子劫持（通用 gen_17：敌方增益光环抵消并转移）
			"hijack_aura_radius":
				result["hijack_aura_radius"] = maxf(0.0, float(effect_value))
			"hijack_aura_duration":
				result["hijack_aura_duration"] = maxf(1.0, float(effect_value))
			"hijack_aura_cd":
				result["hijack_aura_cd"] = maxf(5.0, float(effect_value))
			# 激光指示器（命中100%标记）
			"laser_marker":
				result["laser_mark_on_hit"] = true
			# v8.6 现实/科幻伤害类型
			"true_damage":
				if not result.has("true_damage"): result["true_damage"] = 0.0
				result["true_damage"] += float(effect_value)
			"chem_chance":
				if not result.has("chem_chance"): result["chem_chance"] = 0.0
				result["chem_chance"] += float(effect_value)
			"chem_dps":
				if not result.has("chem_dps"): result["chem_dps"] = 0.0
				result["chem_dps"] += float(effect_value)
			"chem_duration":
				if not result.has("chem_duration"): result["chem_duration"] = 0.0
				result["chem_duration"] += float(effect_value)
			"burn_chance":
				if not result.has("burn_chance"): result["burn_chance"] = 0.0
				result["burn_chance"] += float(effect_value)
			"burn_dps":
				if not result.has("burn_dps"): result["burn_dps"] = 0.0
				result["burn_dps"] += float(effect_value)
			"burn_duration":
				if not result.has("burn_duration"): result["burn_duration"] = 0.0
				result["burn_duration"] += float(effect_value)
			"emp_chance":
				if not result.has("emp_chance"): result["emp_chance"] = 0.0
				result["emp_chance"] += float(effect_value)
			"emp_true_damage":
				if not result.has("emp_true_damage"): result["emp_true_damage"] = 0.0
				result["emp_true_damage"] += float(effect_value)
			"nano_chance":
				if not result.has("nano_chance"): result["nano_chance"] = 0.0
				result["nano_chance"] += float(effect_value)
			"nano_pct":
				if not result.has("nano_pct"): result["nano_pct"] = 0.0
				result["nano_pct"] += float(effect_value)
			"nano_duration":
				if not result.has("nano_duration"): result["nano_duration"] = 0.0
				result["nano_duration"] += float(effect_value)
			# ── v9.1 组合技套路 effect key ──
			# 数值增益类（累加到 stats，建卡时一次性写入）
			"burn_dps_mult":
				if not result.has("burn_dps_mult"): result["burn_dps_mult"] = 0.0
				result["burn_dps_mult"] += float(effect_value)
			"chem_dps_mult":
				if not result.has("chem_dps_mult"): result["chem_dps_mult"] = 0.0
				result["chem_dps_mult"] += float(effect_value)
			"emp_true_damage_bonus":
				if not result.has("emp_true_damage_bonus"): result["emp_true_damage_bonus"] = 0.0
				result["emp_true_damage_bonus"] += float(effect_value)
			"beam_damage_bonus":
				if not result.has("beam_damage_bonus"): result["beam_damage_bonus"] = 0.0
				result["beam_damage_bonus"] += float(effect_value)
			# 套路触发/配置类（写入 _special，运行时由 module_effect_handler 读取）
			_:
				if not result.has("_special"):
					result["_special"] = {}
				result["_special"][effect_key] = effect_value
	return result

## ─────────────────────────────────────────────
##  内部工具
## ─────────────────────────────────────────────

static func _ensure_initialized() -> void:
	if not _initialized:
		register_all()

static func _prefix_to_type(prefix: String) -> String:
	match prefix:
		"inf": return "infantry"
		"arm": return "armor"
		"art": return "artillery"
		"aa": return "anti_air"
		"air": return "air"
		"rec": return "recon"
		"eng": return "engineer"
		"for": return "fort"
		"gen": return "universal"
		"sup": return "artillery"   # v9.1b：sup_ 前缀（支援类改造，放 artillery_mods，复用 SUPPORT 兵种）
		_: return ""

## 获取所有改造ID（用于调试）
static func get_all_ids() -> Array:
	_ensure_initialized()

	var result = []
	for type_key in _cache.keys():
		result.append_array(_cache[type_key].keys())
	return result

## ─── 武器槽位系统支持 ───

## 应用改造效果到武器槽位
## weapon: WeaponResource - 基础武器
## modifications: Array - 改造ID列表
## slot_idx: int - 槽位索引（0=轻装, 1=装甲, 2=对空）
## source_stats: UnitStats - 载体单位属性（v6.13: grant_slot 派生对空基础伤害用，读 attack_armor 等）
## 返回：修改后的 WeaponResource
static func apply_to_weapon_slot(weapon: WeaponResource, modifications: Array, slot_idx: int = -1, source_stats: UnitStats = null) -> WeaponResource:
	_ensure_initialized()
	if weapon == null:
		return weapon

	# v6.13: 先处理 grant_slot——改造可激活空槽位（赋予新攻击维度）
	# 例：炮射导弹(arm_07)激活对空槽，以 attack_armor 为基准派生对空伤害
	# 必须在 enabled 检查之前处理，否则空槽(enabled=false)会被直接 return
	# 语义：grant 仅激活空槽；若槽位已有有效武器(原卡自带)，保留原值不覆盖。
	var result: WeaponResource = weapon
	var slot_granted := false
	for mod_entry in modifications:
		if mod_entry is Dictionary:
			if mod_entry.has("enabled") and not bool(mod_entry.get("enabled", true)):
				continue
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else String(mod_entry)
		var mod_data = get_data(mod_id)
		if mod_data.is_empty():
			continue
		var grant: Dictionary = mod_data.get("grant_slot", {})
		if grant.is_empty():
			continue
		# 仅处理针对当前槽位的 grant
		if slot_idx < 0 or int(grant.get("slot", -1)) != slot_idx:
			continue
		# 槽位已有有效武器（原卡自带，如反坦克组的对装甲槽）：
		# v9.x 修复——原逻辑直接跳过，"换弹升级"类改造（穿甲弹 inf_05）对已有对装甲槽的
		# 单位（多数步兵）完全无效（装了只剩副作用）。改为：派生武器 DPS 更高时升级覆盖
		# （换装语义），更低时保留原武器（不降级）。
		if weapon.enabled and weapon.damage > 0:
			var cur_dps: float = float(weapon.damage) * float(weapon.attack_speed)
			var up_base: float = _read_stat_field(source_stats, String(grant.get("base_damage", "attack_armor")))
			if up_base <= 0.0:
				up_base = _read_stat_field(source_stats, "attack_light")
			var up_dps: float = maxf(1.0, up_base * float(grant.get("damage_ratio", 0.7))) \
				* maxf(0.05, float(grant.get("speed", 0.33)))
			if up_dps <= cur_dps:
				continue
		# 首次 grant：克隆基座（此时 weapon 必为空槽）
		if not slot_granted:
			result = weapon.clone()
			slot_granted = true
		# 激活槽位并填充 grant 参数
		result.enabled = true
		# 基础伤害：从 source_stats 的指定字段派生
		var base_field: String = String(grant.get("base_damage", "attack_armor"))
		var base_val: float = _read_stat_field(source_stats, base_field)
		if base_val <= 0.0:
			# 基准字段为0（如步兵无 attack_armor），回退到 attack_light 避免赋予0伤害
			base_val = _read_stat_field(source_stats, "attack_light")
		var ratio: float = float(grant.get("damage_ratio", 0.7))
		result.damage = maxf(1.0, base_val * ratio)
		result.attack_speed = maxf(0.05, float(grant.get("speed", 0.33)))
		result.windup = maxf(0.05, float(grant.get("windup", 0.6)))
		result.active = maxf(0.05, float(grant.get("active", 0.15)))
		result.weapon_type = int(grant.get("weapon_type", 9))  # 默认 MISSILE
		result.range_value = int(grant.get("range_value", 3))
		var dn: String = String(grant.get("display_name", ""))
		if not dn.is_empty():
			result.display_name = dn

	# 若槽位未被激活且原本未启用，直接返回（保留原 apply_to_weapon_slot 的守卫语义）
	if not slot_granted and not weapon.enabled:
		return weapon

	# 应用其余 slot_* 效果（damage_mult/add/speed_mult/weapon_type 等）
	for mod_entry in modifications:
		# v6.5: 跳过已禁用的改造
		if mod_entry is Dictionary:
			if mod_entry.has("enabled") and not bool(mod_entry.get("enabled", true)):
				continue
		var mod_id = mod_entry.get("id", "") if mod_entry is Dictionary else String(mod_entry)
		var mod_data = get_data(mod_id)
		if mod_data.is_empty():
			continue

		var effects = mod_data.get("effects", {})

		# 检查改造是否适用于特定槽位
		var condition_slot = int(mod_data.get("condition_slot", -1))
		if condition_slot >= 0 and condition_slot != slot_idx:
			continue

		# 应用效果到武器属性
		for effect_key in effects.keys():
			var effect_value = effects[effect_key]

			match effect_key:
				"slot_damage_mult":
					if effect_value is float or effect_value is int:
						result.damage *= float(effect_value)
				"slot_damage_add":
					if effect_value is float or effect_value is int:
						result.damage += float(effect_value)
				"slot_attack_speed_mult":
					if effect_value is float or effect_value is int:
						result.attack_speed *= float(effect_value)
				"slot_range_bonus":
					if effect_value is int:
						result.range_value += effect_value
				"slot_windup_reduce":
					if effect_value is float or effect_value is int:
						result.windup = maxf(0.05, result.windup - float(effect_value))
				"slot_active_reduce":
					if effect_value is float or effect_value is int:
						result.active = maxf(0.05, result.active - float(effect_value))
				# v6.5: 武器类改造改变该槽位的武器类型（影响弹道和命中效果）
				"slot_weapon_type":
					result.weapon_type = int(effect_value)
				# v8.4: 武器类改造的专属视觉变体标识（cluster/thermobaric/proximity/guided/gun_missile）
				# 存入 _mod_effects，开火时由 construct_unit_ai/enemy_unit 读出透传给 bullet/batch。
				# （不加此分支也会被下方 _ 默认分支隐式写入，此处显式声明便于维护。）
				"vfx_variant":
					result._mod_effects["vfx_variant"] = String(effect_value)
				_:
					# 其他特殊效果存储到武器 _mod_effects（已在 WeaponResource 声明，clone 时复制）
					result._mod_effects[effect_key] = effect_value

	return result

## v6.13: 从 UnitStats 读取指定字段（grant_slot 基准伤害用）
## 字段名宽松匹配：attack_light/attack_armor/attack_air 等
static func _read_stat_field(stats: UnitStats, field: String) -> float:
	if stats == null:
		return 0.0
	match field:
		"attack_light": return float(stats.attack_light)
		"attack_armor": return float(stats.attack_armor)
		"attack_air": return float(stats.attack_air)
		"attack_damage": return float(stats.attack_damage)
		"max_hp": return float(stats.max_hp)
		_: return 0.0

## 批量应用改造到所有武器槽位
## weapon_slots: Array[WeaponResource] - 武器槽位数组
## modifications: Array - 改造ID列表
## source_stats: UnitStats - 载体单位属性（v6.13: grant_slot 派生对空基础伤害用）
## 返回：修改后的槽位数组（Array[WeaponResource]，与 unit_stats_table.tmp_slots 类型匹配，
##   避免普通 Array 赋给 typed Array[WeaponResource] 报错）
static func apply_to_weapon_slots(weapon_slots: Array, modifications: Array, source_stats: UnitStats = null) -> Array[WeaponResource]:
	_ensure_initialized()
	var result: Array[WeaponResource] = []

	for i in range(weapon_slots.size()):
		var weapon = weapon_slots[i]
		if weapon is WeaponResource:
			# v6.13: 无论 enabled 与否都走 apply_to_weapon_slot（grant_slot 需要激活空槽）
			result.append(apply_to_weapon_slot(weapon, modifications, i, source_stats))
		else:
			# 非 WeaponResource 占位：用空槽位补齐，保证 typed Array[WeaponResource] 不报错
			result.append(WeaponResource.create_empty_slot(i))

	return result
