## 存档迁移 v5 → v6
## 改造系统统一：把老存档里的 MOD_01~MOD_20（旧改造系统，战斗中已失效）
## 迁移到 140+ 模块系统（modification_modules/*.gd 的 gen_01_comms/inf_01_xxx 等）。
##
## 背景：
##   - 旧系统 mod_effects.gd 的 MOD_01~20 在 ModificationRegistry 中查不到（ID 命名空间不同）
##   - 战斗构建 unit_stats_table.gd 调用 ModificationRegistry.get_data(mod_id) 时返回空 → 静默失效
##   - 新系统 modification_modules/*.gd 的 140+ 模块已通过 modification_panel UI 装备，战斗中生效
##   - 本迁移把老玩家的 MOD_01~20 按语义映射到最接近的 140+ 模块，保留玩家改造投入

class_name SaveMigrationV6
extends RefCounted

const ModEffects = preload("res://data/mod_effects.gd")
const DefaultCards = preload("res://data/default_cards.gd")

## MOD_01~20 → 140+ 模块的语义映射表。
## 按 combat_kind 提供候选（LIGHT=0/ARMOR=1/SUPPORT=2/AIR=3/FORT=4），兜底用 enh_* 通用词条。
## 映射原则：优先选该兵种专用模块（effects 最接近），否则用 enhancement 通用词条。
const MOD_MIGRATION_MAP: Dictionary = {
	# MOD_01 火力改造（攻击力+15%）→ 攻击强化模块
	"MOD_01": {
		0: "inf_02_assault_rifle",   # 轻装/步兵：突击步枪（attack_light+）
		1: "arm_05_smoothbore",       # 装甲：滑膛炮（attack_armor+）
		2: "art_01_rifling",          # 支援/炮兵：膛线（attack_light+）
		3: "air_06_bvr_missile",      # 空中：超视距导弹（attack_range+）
		4: "for_05_ammo_dump",        # 堡垒：弹药库（attack_light+）
		"_fallback": "enh_dmg_up",    # 兜底：强化攻击词条
	},
	# MOD_02 装甲改造（防御力+20%）→ 防御强化模块
	"MOD_02": {
		0: "inf_11_armor_insert",     # 轻装：装甲插板（defense_light+ max_hp+）
		1: "arm_01_sloped_armor",     # 装甲：倾斜装甲（defense_armor+）
		2: "inf_12_body_armor",       # 支援：防弹衣（defense_armor+ defense_light+）
		3: "air_14_swing_wing",       # 空中：变后掠翼（dodge+，最接近防御）
		4: "for_01_concrete",         # 堡垒：混凝土（defense_light+ max_hp+）
		"_fallback": "enh_def_up",
	},
	# MOD_03 机动改造（部署速度+2）→ 速度/部署模块
	"MOD_03": {
		0: "inf_16_exoskeleton",      # 轻装：外骨骼（move_speed+ deploy_speed+）
		1: "arm_09_turbine",           # 装甲：燃气轮机（move_speed+）
		2: "art_10_auto_nav",          # 支援：自动导航（deploy_speed+）
		3: "air_01_turbofan",          # 空中：涡扇（move_speed+）
		4: "inf_14_knee_pads",         # 堡垒：护膝（move_speed+）
		"_fallback": "enh_speed_up",
	},
	# MOD_04 射程改造（射程+1）→ 射程模块
	"MOD_04": {
		0: "inf_07_optical_scope",    # 轻装：光学瞄具（attack_range+ crit+）
		1: "arm_05_smoothbore",        # 装甲：滑膛炮（attack_range+）
		2: "art_02_extended_range",    # 支援：增程炮（attack_range+）
		3: "air_06_bvr_missile",       # 空中：超视距导弹（attack_range+）
		4: "enh_range_up",             # 堡垒：无专用，用词条
		"_fallback": "enh_range_up",
	},
	# MOD_05 穿甲专精（对装甲+30%）→ 穿甲模块
	"MOD_05": {
		0: "inf_05_ap_ammo",          # 轻装：穿甲弹（attack_armor+）
		1: "arm_06_apfsds",            # 装甲：尾翼稳定脱壳穿甲弹（attack_armor+）
		2: "inf_05_ap_ammo",           # 支援：穿甲弹
		3: "air_06_bvr_missile",       # 空中：导弹（最接近穿甲）
		4: "arm_06_apfsds",            # 堡垒：脱壳穿甲弹
		"_fallback": "enh_penetration",
	},
	# MOD_06 高爆专精（直射+30%）→ 直射强化
	"MOD_06": {
		0: "inf_02_assault_rifle",
		1: "arm_05_smoothbore",
		2: "art_01_rifling",
		3: "air_06_bvr_missile",
		4: "for_05_ammo_dump",
		"_fallback": "enh_dmg_up",
	},
	# MOD_07 防空专精（对空+40%）→ 防空模块
	"MOD_07": {
		0: "aa_03_missile_rail",      # 轻装：防空导弹（attack_air+）
		1: "arm_07_gun_missile",       # 装甲：炮射导弹（attack_air+）
		2: "aa_03_missile_rail",
		3: "air_06_bvr_missile",
		4: "aa_03_missile_rail",
		"_fallback": "enh_dmg_up",
	},
	# MOD_08 快速装填（攻击间隔-20%）→ 攻速模块
	"MOD_08": {
		0: "inf_09_dual_mag",         # 轻装：双弹匣（attack_interval-）
		1: "arm_08_autoloader",        # 装甲：自动装弹机（attack_interval-）
		2: "art_06_fire_computer",     # 支援：射击计算机（attack_interval-）
		3: "air_05_helmet_sight",      # 空中：头盔瞄准具（attack_interval-）
		4: "for_03_auto_turret",       # 堡垒：自动炮塔（attack_interval-）
		"_fallback": "enh_atkspd_up",
	},
	# MOD_09 精确瞄准（命中+20%）→ 暴击（命中系统简化为暴击）
	"MOD_09": {
		"_fallback": "enh_crit",
	},
	# MOD_10 战场维修（每秒回1%血）→ 回血模块
	"MOD_10": {
		0: "inf_17_tourniquet",       # 轻装：止血带（hp_regen+）
		1: "eng_03_welding",           # 装甲：焊接（hp_regen+）
		2: "inf_17_tourniquet",
		3: "inf_17_tourniquet",
		4: "eng_03_welding",
		"_fallback": "enh_regen",
	},
	# MOD_11 能量效率（部署能量-20%）→ 无直接对应，映射到速度
	"MOD_11": {
		"_fallback": "enh_speed_up",
	},
	# MOD_12 纳米装甲（减伤+10%）→ 减伤
	"MOD_12": {
		0: "inf_11_armor_insert",
		1: "arm_01_sloped_armor",
		2: "inf_12_body_armor",
		3: "air_14_swing_wing",
		4: "for_01_concrete",
		"_fallback": "enh_def_up",
	},
	# MOD_13 过载射击（暴击+15%）→ 暴击
	"MOD_13": {
		0: "inf_07_optical_scope",    # 轻装：光学瞄具（crit+）
		1: "arm_11_fire_control",      # 装甲：火控（crit+）
		2: "art_03_guided_shell",      # 支援：制导炮弹（crit+）
		3: "rec_04_high_power_scope",  # 空中：高倍瞄准镜（crit+）
		4: "enh_crit",
		"_fallback": "enh_crit",
	},
	# MOD_14 范围溅射（20%范围伤害）→ 溅射
	"MOD_14": {
		"_fallback": "enh_splash",
	},
	# MOD_15 护盾生成（部署时20%HP护盾）→ 击杀护盾
	"MOD_15": {
		"_fallback": "enh_shield_kill",
	},
	# MOD_16 死亡自爆 → 无直接对应，映射到攻击
	"MOD_16": {
		"_fallback": "enh_dmg_up",
	},
	# MOD_17 回收利用 → 无直接对应，映射到速度
	"MOD_17": {
		"_fallback": "enh_speed_up",
	},
	# MOD_18 双倍供弹（10%双倍伤害）→ 暴击伤害
	"MOD_18": {
		"_fallback": "enh_crit_dmg",
	},
	# MOD_19 硬化装甲（对穿甲抗性+25%）→ 防御
	"MOD_19": {
		0: "inf_11_armor_insert",
		1: "arm_01_sloped_armor",
		2: "inf_12_body_armor",
		3: "air_14_swing_wing",
		4: "for_01_concrete",
		"_fallback": "enh_def_up",
	},
	# MOD_20 电磁脉冲（20%瘫痪）→ 无直接对应，映射到暴击
	"MOD_20": {
		"_fallback": "enh_crit",
	},
}


## 执行 v5 → v6 迁移：把老存档的 MOD_01~20 改造映射到 140+ 模块系统
static func migrate_v5_to_v6(data: Dictionary, debug_log: bool = false) -> void:
	_migrate_blueprint_mods(data, debug_log)


## 迁移 blueprint_mods：把 MOD_01~20 替换为 140+ 模块 ID
static func _migrate_blueprint_mods(data: Dictionary, debug_log: bool) -> void:
	if not data.has("blueprint") or not data["blueprint"] is Dictionary:
		return
	var bp: Dictionary = data["blueprint"]
	if not bp.has("blueprint_mods") or not bp["blueprint_mods"] is Dictionary:
		return
	var mods_dict: Dictionary = bp["blueprint_mods"]
	if mods_dict.is_empty():
		return

	var migrated_count: int = 0
	var skipped_count: int = 0
	for card_id in mods_dict.keys():
		var mods_array: Array = mods_dict[card_id]
		if not mods_array is Array:
			continue
		var combat_kind: int = _get_card_combat_kind(String(card_id))
		var new_array: Array = []
		for entry in mods_array:
			var old_id: String = ""
			var entry_level: int = 1
			var entry_enabled: bool = true
			if entry is Dictionary:
				old_id = String(entry.get("id", ""))
				entry_level = int(entry.get("level", 1))
				entry_enabled = bool(entry.get("enabled", true))
			else:
				old_id = String(entry)
			# 仅迁移 MOD_01~20 前缀的旧改造；新系统 ID（inf_*/gen_*/enh_*/EOM_*）保持不变
			if not old_id.begins_with("MOD_"):
				new_array.append(entry)
				continue
			var new_id: String = _resolve_migration_target(old_id, combat_kind)
			if new_id.is_empty():
				skipped_count += 1
				continue
			new_array.append({
				"id": new_id,
				"level": entry_level,
				"enabled": entry_enabled,
				"migrated": true,  # 标记为迁移而来
			})
			migrated_count += 1
		mods_dict[card_id] = new_array

	if debug_log and migrated_count > 0:
		push_warning("[SaveMigrationV6] 改造迁移：%d 个 MOD_01~20 → 140+模块（跳过 %d 个无法映射）" % [migrated_count, skipped_count])


## 查询卡的 combat_kind（0=LIGHT 1=ARMOR 2=SUPPORT 3=AIR 4=FORT）
## 迁移时用不到 DefaultCards 时回退到 0（轻装，映射最通用）
static func _get_card_combat_kind(card_id: String) -> int:
	var card = DefaultCards.get_card_by_id(card_id)
	if card != null and "combat_kind" in card:
		return int(card.combat_kind)
	return 0


## 根据老 MOD ID 和卡的 combat_kind 解析迁移目标
static func _resolve_migration_target(old_mod_id: String, combat_kind: int) -> String:
	if not MOD_MIGRATION_MAP.has(old_mod_id):
		return ""
	var mapping: Dictionary = MOD_MIGRATION_MAP[old_mod_id]
	# 优先按 combat_kind 精确匹配
	if mapping.has(combat_kind):
		return String(mapping[combat_kind])
	# 兜底
	return String(mapping.get("_fallback", ""))


## 迁移前的检测：判断存档是否需要 v5→v6 迁移（含 MOD_ 前缀改造）
static func needs_migration(data: Dictionary) -> bool:
	if not data.has("blueprint") or not data["blueprint"] is Dictionary:
		return false
	var bp: Dictionary = data["blueprint"]
	if not bp.has("blueprint_mods") or not bp["blueprint_mods"] is Dictionary:
		return false
	var mods_dict: Dictionary = bp["blueprint_mods"]
	for card_id in mods_dict.keys():
		var mods_array = mods_dict[card_id]
		if not mods_array is Array:
			continue
		for entry in mods_array:
			var mod_id: String = ""
			if entry is Dictionary:
				mod_id = String(entry.get("id", ""))
			else:
				mod_id = String(entry)
			if mod_id.begins_with("MOD_"):
				return true
	return false
