## 存档迁移 v3 → v4
## 新增内容：
## 1. 军衔系统（动态计算，无需迁移）
## 2. 改造ID映射（旧MOD_XX → 新inf_XX/arm_XX等）
## 3. 进化历史记录

## ─────────────────────────────────────────────
##  旧改造ID映射表
## ─────────────────────────────────────────────
## 上下文相关映射：某些旧 MOD 根据兵种映射到不同新改造
## 格式：{default: "默认新ID", by_unit_type: {兵种: "特定新ID"}}

const LEGACY_MOD_MAPPING: Dictionary = {
	# 旧火力改造 → 步兵改造
	"MOD_01": {default = "inf_02_assault_rifle"},      # 火力改造 → 突击步枪化
	"MOD_05": {default = "inf_05_ap_ammo"},            # 穿甲专精 → 穿甲弹
	"MOD_06": {default = "inf_06_hp_ammo"},            # 高爆专精 → 空尖弹
	"MOD_08": {default = "inf_01_submachine_gun"},     # 快速装填 → 冲锋枪改装
	"MOD_13": {default = "inf_10_saw"},                # 过载射击 → 班用机枪化
	"MOD_14": {default = "inf_04_bullpup"},            # 范围溅射 → 无托结构（近似）

	# 旧装甲改造 → 装甲改造
	"MOD_02": {default = "arm_02_composite_armor"},    # 装甲改造 → 复合装甲
	"MOD_12": {default = "arm_01_sloped_armor"},       # 纳米装甲 → 倾斜装甲
	"MOD_19": {default = "arm_03_reactive_armor"},     # 硬化装甲 → 爆反装甲

	# 旧机动改造 → 通用改造（根据兵种不同映射）
	"MOD_03": {
		default = "gen_03_camouflage",       # 默认：伪装迷彩
		by_unit_type = {
			0: "gen_03_camouflage",       # 步兵 → 伪装迷彩
			1: "gen_07_mine_resistant",    # 装甲 → 防雷座椅
		}
	},

	# 旧射程改造 → 瞄准设备
	"MOD_04": {default = "inf_07_optical_scope"},     # 射程改造 → 光学瞄准镜
	"MOD_09": {default = "inf_08_holographic"},       # 精确瞄准 → 全息瞄准镜

	# 旧生存改造 → 医疗设备
	"MOD_10": {default = "inf_18_ifak"},             # 战场维修 → 急救包
	"MOD_15": {default = "inf_15_riot_shield"},      # 护盾生成 → 防弹盾牌

	# 旧特殊改造
	"MOD_07": {default = "aa_05_proximity_fuze"},     # 防空专精 → 近炸引信
	"MOD_11": {default = "gen_10_ammo_rack"},         # 能量效率 → 备用弹药架
	"MOD_16": {default = "for_09_minefield"},         # 死亡自爆 → 雷场
	"MOD_17": {default = "gen_10_ammo_rack"},         # 回收利用 → 备用弹药架
	"MOD_18": {default = "inf_02_assault_rifle"},     # 双倍供弹 → 突击步枪化（近似）
	"MOD_20": {default = "aa_11_auto_fc"},            # 电磁脉冲 → 自动化火控（近似）
}

## ─────────────────────────────────────────────
##  迁移接口
## ─────────────────────────────────────────────

## 迁移单个卡牌的改造记录
## @param old_mods: 旧改造数组
## @param unit_type: 兵种类型（0=轻装/步兵, 1=装甲, 2=支援, 3=空中, 4=堡垒）
static func migrate_modifications(old_mods: Array, unit_type: int = 0) -> Array:
	var new_mods = []

	for old_mod in old_mods:
		var old_id = old_mod.get("id", "") if old_mod is Dictionary else ""
		var new_id = _get_mapped_mod_id(old_id, unit_type)

		if new_id.is_empty():
			# 无法映射，使用默认
			push_warning("[SaveMigration] 无法映射改造ID：%s（兵种%d），跳过" % [old_id, unit_type])
			continue

		# 创建新改造记录
		new_mods.append({
			id = new_id,
			installed_at = old_mod.get("installed_at", Time.get_unix_time_from_system()),
		})

	return new_mods

## 获取映射后的新改造ID（考虑兵种上下文）
static func _get_mapped_mod_id(old_id: String, unit_type: int) -> String:
	var mapping = LEGACY_MOD_MAPPING.get(old_id, {})
	if mapping.is_empty():
		return ""

	# 如果映射是字符串，直接返回（兼容旧格式）
	if mapping is String:
		return mapping

	# 新格式：带上下文的字典
	if mapping is Dictionary:
		var by_unit_type = mapping.get("by_unit_type", {})
		if by_unit_type.has(unit_type):
			return by_unit_type[unit_type]
		return mapping.get("default", "")

	return ""

## 迁移蓝图数据
static func migrate_blueprint_data(old_blueprint: Dictionary) -> Dictionary:
	var new_blueprint = old_blueprint.duplicate(true)

	# 迁移改造（传递兵种类型用于上下文映射）
	if new_blueprint.has("mods"):
		var unit_type = new_blueprint.get("combat_kind", 0)
		new_blueprint.mods = migrate_modifications(new_blueprint.mods, unit_type)

	# 计算军衔（仅用于显示，不存储）
	if new_blueprint.has("card_id"):
		var card_id = new_blueprint.card_id
		var level = new_blueprint.get("enhance_level", 1)
		var power = new_blueprint.get("power", 0)

		# 军衔是动态计算的，这里仅用于验证
		var current_power = power * (1.0 + (level - 1) * 0.05)
		var unit_type = new_blueprint.get("combat_kind", 0)
		var title_info = MilitaryTitleRegistry.get_military_title(power, int(current_power), unit_type)
		new_blueprint.military_title = title_info.name

	return new_blueprint

## 验证迁移结果
static func validate_migration(old_data: Dictionary, new_data: Dictionary) -> Dictionary:
	var result = {valid = true, issues = []}

	# 检查改造数量
	var old_mod_count = old_data.get("mods", []).size()
	var new_mod_count = new_data.get("mods", []).size()

	if new_mod_count < old_mod_count:
		result.issues.append("改造数量减少：%d → %d（部分改造无法映射）" % [old_mod_count, new_mod_count])

	# 检查强化等级
	var old_level = old_data.get("enhance_level", 1)
	var new_level = new_data.get("enhance_level", 1)

	if old_level != new_level:
		result.issues.append("强化等级变化：%d → %d" % [old_level, new_level])

	result.valid = result.issues.is_empty()
	return result
