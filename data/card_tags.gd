extends RefCounted
class_name CardTags
## 卡片标签配置
## 为不同类型的卡片提供默认标签

## 根据卡片ID获取推荐标签
static func get_tags_for_card(card_id: String) -> Array[String]:
	var tags: Array[String] = []

	# 解析卡片ID前缀确定时代
	var era = _get_era_from_id(card_id)
	if era != "":
		tags.append(era)

	# 解析卡片类型
	var combat_type = _get_combat_type_from_id(card_id)
	if combat_type != "":
		tags.append(combat_type)

	# 特殊单位标签
	tags.append_array(_get_special_tags(card_id))

	return tags

## 从卡片ID提取时代
static func _get_era_from_id(card_id: String) -> String:
	if card_id.begins_with("ww1_"):
		return "一战"
	elif card_id.begins_with("ww2_"):
		return "二战"
	elif card_id.begins_with("cold_"):
		return "冷战"
	elif card_id.begins_with("mod_"):
		return "现代"
	elif card_id.begins_with("fut_"):
		return "未来"
	elif card_id.begins_with("fort_"):
		return "堡垒"
	return ""

## 从卡片ID提取战斗类型
static func _get_combat_type_from_id(card_id: String) -> String:
	# 步兵单位
	if card_id.contains("mp18") or card_id.contains("thompson") or card_id.contains("ak47") or card_id.contains("mauser") or card_id.contains("garand") or card_id.contains("m14") or card_id.contains("marine") or card_id.contains("ranger") or card_id.contains("spetsnaz") or card_id.contains("spectre"):
		return "步兵"

	# 机枪单位
	if card_id.contains("mg08") or card_id.contains("vickers") or card_id.contains("browning") or card_id.contains("mg42") or card_id.contains("m60"):
		return "机枪"

	# 反坦克单位
	if card_id.contains("panzerschrek") or card_id.contains("bazooka") or card_id.contains("rpg") or card_id.contains("javelin"):
		return "反坦克"

	# 坦克单位
	if card_id.contains("ft17") or card_id.contains("pz3") or card_id.contains("pz4") or card_id.contains("tiger") or card_id.contains("t34") or card_id.contains("t55") or card_id.contains("t72") or card_id.contains("m1") or card_id.contains("leo") or card_id.contains("challenger"):
		return "坦克"

	# 装甲车
	if card_id.contains("rolls") or card_id.contains("lanchest") or card_id.contains("btr") or card_id.contains("bradley") or card_id.contains("stryker") or card_id.contains("hummer"):
		return "装甲车"

	# 火炮单位
	if card_id.contains("m81") or card_id.contains("m120") or card_id.contains("m270") or card_id.contains("howitzer") or card_id.contains("mortar"):
		return "火炮"

	# 防空单位
	if card_id.contains("37mm") or card_id.contains("zsu") or card_id.contains("m6") or card_id.contains("stinger") or card_id.contains("aa_hover") or card_id.contains("phalanx") or card_id.contains("flak"):
		return "防空"

	# 空中单位
	if card_id.contains("mig") or card_id.contains("ah64") or card_id.contains("ah1") or card_id.contains("f4") or card_id.contains("uh60") or card_id.contains("space_fighter") or card_id.contains("attack_drone") or card_id.contains("stealth_bomber"):
		return "空中"

	# 特种单位
	if card_id.contains("storm") or card_id.contains("engineer") or card_id.contains("flame"):
		return "特种"

	# 堡垒单位
	if card_id.contains("fort_"):
		return "防御"

	return ""

## 获取特殊标签
static func _get_special_tags(card_id: String) -> Array[String]:
	var special_tags: Array[String] = []

	# 终极单位
	if card_id.contains("colossus") or card_id.contains("nexus") or card_id.contains("omega_platform"):
		special_tags.append("终极")

	# 高科技单位
	if card_id.contains("cyborg") or card_id.contains("mech") or card_id.contains("drone"):
		special_tags.append("高科技")

	# 重型单位
	if card_id.contains("heavy") or card_id.contains("colossus") or card_id.contains("tiger") or card_id.contains("kingtiger"):
		special_tags.append("重型")

	# 快速单位
	if card_id.contains("scout") or card_id.contains("hover") or card_id.contains("ranger"):
		special_tags.append("快速")

	return special_tags

## 为情报ID生成标签
static func get_tags_for_lore(lore_id: String, category: String = "", era: int = -1) -> Array[String]:
	var tags: Array[String] = []

	# 添加时代标签
	if era >= 0:
		match era:
			0: tags.append("一战")
			1: tags.append("二战")
			2: tags.append("冷战")
			3: tags.append("现代")
			4: tags.append("未来")

	# 添加分类标签
	if not category.is_empty():
		match category:
			"tactics": tags.append("战术")
			"technology": tags.append("技术")
			"history": tags.append("历史")
			"intelligence": tags.append("情报")

	# 根据ID添加特殊标签
	if lore_id.contains("gas") or lore_id.contains("chemical"):
		tags.append("化学")
	if lore_id.contains("tank") or lore_id.contains("armor"):
		tags.append("装甲")
	if lore_id.contains("cipher") or lore_id.contains("enigma"):
		tags.append("密码")
	if lore_id.contains("nuclear") or lore_id.contains("manhattan"):
		tags.append("核能")
	if lore_id.contains("drone") or lore_id.contains("uav"):
		tags.append("无人机")
	if lore_id.contains("cyber") or lore_id.contains("network"):
		tags.append("网络")

	return tags
