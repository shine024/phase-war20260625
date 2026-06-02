extends RefCounted
class_name TitleDisplayNames
## 军衔称号显示名称映射
## 每个兵种在不同等级有不同的称号

## ─────────────────────────────────────────────
##  兵种称号映射表
## ─────────────────────────────────────────────

## 步兵/轻装兵称号
const INFANTRY_TITLES: Dictionary = {
	1: {"name": "征召兵", "name_en": "Conscript", "desc": "完成基础训练，配发标准装备"},
	2: {"name": "合格步兵", "name_en": "Qualified Infantry", "desc": "通过战术考核，熟悉班组配合"},
	3: {"name": "老兵", "name_en": "Veteran", "desc": "经历过实战，战场直觉形成"},
	4: {"name": "精锐", "name_en": "Elite", "desc": "连队尖子，可担任火力组长"},
	5: {"name": "士官", "name_en": "Sergeant", "desc": "获得军士军衔，领导一个火力组"},
	6: {"name": "战斗老兵", "name_en": "Combat Veteran", "desc": "多次实战部署，全战术精通"},
	7: {"name": "三级军士长", "name_en": "Sgt. Maj. 3rd Class", "desc": "可训练新兵，担任排士官长"},
	8: {"name": "二级军士长", "name_en": "Sgt. Maj. 2nd Class", "desc": "营级特等射手/战斗教官"},
	9: {"name": "一级军士长", "name_en": "Sgt. Maj. 1st Class", "desc": "\"军士长中的军士长\""},
	10: {"name": "战斗大师", "name_en": "Combat Master", "desc": "超越常规军衔的战场传说"},
}

## 装甲兵称号
const ARMOR_TITLES: Dictionary = {
	1: {"name": "装填手", "name_en": "Loader", "desc": "协助装填，基础训练完成"},
	2: {"name": "驾驶员", "name_en": "Driver", "desc": "掌握机动驾驶，地形适应"},
	3: {"name": "炮手", "name_en": "Gunner", "desc": "精准射击，火力压制"},
	4: {"name": "车长", "name_en": "Commander", "desc": "指挥协调，战术决策"},
	5: {"name": "排长", "name_en": "Platoon Leader", "desc": "领导多车协同作战"},
	6: {"name": "连长", "name_en": "Company Commander", "desc": "指挥装甲连队作战"},
	7: {"name": "营长", "name_en": "Battalion Commander", "desc": "统率装甲营级规模"},
	8: {"name": "装甲兵总监", "name_en": "Armor Director", "desc": "装甲部队战术专家"},
	9: {"name": "装甲兵上将", "name_en": "Armor General", "desc": "装甲兵最高指挥官"},
	10: {"name": "钢铁战神", "name_en": "Steel War God", "desc": "传说中的坦克王牌"},
}

## 炮兵称号
const ARTILLERY_TITLES: Dictionary = {
	1: {"name": "炮手", "name_en": "Gunner", "desc": "基础火炮操作训练"},
	2: {"name": "瞄准手", "name_en": "Sight Adjuster", "desc": "精确瞄准，修正弹道"},
	3: {"name": "炮班长", "name_en": "Squad Leader", "desc": "指挥炮班协同射击"},
	4: {"name": "射击指挥官", "name_en": "Fire Direction Officer", "desc": "协调多个炮班火力"},
	5: {"name": "炮兵排长", "name_en": "Battery Officer", "desc": "指挥炮兵排作战"},
	6: {"name": "炮兵连长", "name_en": "Battery Commander", "desc": "统率炮兵连规模"},
	7: {"name": "炮兵营长", "name_en": "Battalion Commander", "desc": "指挥多连协同射击"},
	8: {"name": "射击大师", "name_en": "Fire Master", "desc": "精准打击，弹无虚发"},
	9: {"name": "炮兵司令", "name_en": "Artillery Commander", "desc": "炮兵部队最高指挥"},
	10: {"name": "钢铁风暴", "name_en": "Steel Storm", "desc": "火力覆盖的化身"},
}

## 防空兵称号
const ANTI_AIR_TITLES: Dictionary = {
	1: {"name": "测距手", "name_en": "Range Finder", "desc": "基础目标测距训练"},
	2: {"name": "跟踪手", "name_en": "Tracker", "desc": "持续跟踪空中目标"},
	3: {"name": "炮手", "name_en": "Gunner", "desc": "防空炮操作训练"},
	4: {"name": "导弹射手", "name_en": "Missile Operator", "desc": "防空导弹系统操作"},
	5: {"name": "防空班长", "name_en": "AA Squad Leader", "desc": "指挥防空班组作战"},
	6: {"name": "防空排长", "name_en": "AA Platoon Leader", "desc": "指挥多防空班组"},
	7: {"name": "防空连长", "name_en": "AA Battery Commander", "desc": "统率防空连规模"},
	8: {"name": "雷达专家", "name_en": "Radar Expert", "desc": "精通雷达防空系统"},
	9: {"name": "防空大师", "name_en": "AA Defense Master", "desc": "防空作战专家"},
	10: {"name": "苍穹之盾", "name_en": "Sky Shield", "desc": "守护领空的铜墙铁壁"},
}

## 空中单位称号
const AIR_TITLES: Dictionary = {
	1: {"name": "飞行学员", "name_en": "Cadet", "desc": "基础飞行训练完成"},
	2: {"name": "飞行员", "name_en": "Pilot", "desc": "获得飞行员资格认证"},
	3: {"name": "三级飞行员", "name_en": "3rd Class Pilot", "desc": "熟练掌握基础战术"},
	4: {"name": "二级飞行员", "name_en": "2nd Class Pilot", "desc": "精通空战机动"},
	5: {"name": "一级飞行员", "name_en": "1st Class Pilot", "desc": "王牌候选人"},
	6: {"name": "王牌飞行员", "name_en": "Ace Pilot", "desc": "击落5架以上敌机"},
	7: {"name": "双料王牌", "name_en": "Double Ace", "desc": "击落10架以上敌机"},
	8: {"name": "飞行教官", "name_en": "Flight Instructor", "desc": "培养下一代飞行员"},
	9: {"name": "王牌中的王牌", "name_en": "Ace of Aces", "desc": "传说中的空战英雄"},
	10: {"name": "天空传奇", "name_en": "Sky Legend", "desc": "领空的绝对主宰"},
}

## 侦察/特种称号
const RECON_TITLES: Dictionary = {
	1: {"name": "侦察兵", "name_en": "Scout", "desc": "基础侦察训练"},
	2: {"name": "巡逻兵", "name_en": "Patroller", "desc": "战场巡逻与警戒"},
	3: {"name": "斥候", "name_en": "Ranger", "desc": "敌后侦察与情报收集"},
	4: {"name": "狙击手", "name_en": "Sniper", "desc": "精确打击与远程侦察"},
	5: {"name": "侦察班长", "name_en": "Recon Squad Leader", "desc": "指挥侦察班组"},
	6: {"name": "侦察排长", "name_en": "Recon Platoon Leader", "desc": "统率多侦察班组"},
	7: {"name": "侦察连长", "name_en": "Recon Company Commander", "desc": "指挥侦察连规模"},
	8: {"name": "特种作战专家", "name_en": "Spec Ops Expert", "desc": "精通特种作战"},
	9: {"name": "侦察大师", "name_en": "Recon Master", "desc": "情报专家，战场之眼"},
	10: {"name": "战场之眼", "name_en": "Eye of Battlefield", "desc": "洞悉一切的侦察之神"},
}

## 工程/支援称号
const ENGINEER_TITLES: Dictionary = {
	1: {"name": "学徒工", "name_en": "Apprentice", "desc": "基础工程训练"},
	2: {"name": "初级工程师", "name_en": "Junior Engineer", "desc": "掌握基础工程技能"},
	3: {"name": "工兵", "name_en": "Combat Engineer", "desc": "战斗工兵，全能支援"},
	4: {"name": "爆破手", "name_en": "Demolition Expert", "desc": "爆破与障碍清除"},
	5: {"name": "工兵班长", "name_en": "Engineer Squad Leader", "desc": "指挥工兵班组"},
	6: {"name": "工程排长", "name_en": "Engineer Platoon Leader", "desc": "统率多工程班组"},
	7: {"name": "工程连长", "name_en": "Engineer Company Commander", "desc": "指挥工程连规模"},
	8: {"name": "高级工程师", "name_en": "Senior Engineer", "desc": "高级工程专家"},
	9: {"name": "工程大师", "name_en": "Engineering Master", "desc": "工程兵种的传奇"},
	10: {"name": "战场建筑师", "name_en": "Battlefield Architect", "desc": "塑造战场的建设者"},
}

## 堡垒/要塞称号
const FORTRESS_TITLES: Dictionary = {
	1: {"name": "要塞兵", "name_en": "Garrison", "desc": "基础要塞守备训练"},
	2: {"name": "炮手", "name_en": "Gunner", "desc": "要塞炮台操作"},
	3: {"name": "观察员", "name_en": "Observer", "desc": "战场监视与预警"},
	4: {"name": "弹药手", "name_en": "Ammo Handler", "desc": "弹药管理与补给"},
	5: {"name": "炮长", "name_en": "Section Commander", "desc": "指挥炮兵分排"},
	6: {"name": "要塞排长", "name_en": "Garrison Platoon Leader", "desc": "统率要塞排"},
	7: {"name": "要塞连长", "name_en": "Garrison Company Commander", "desc": "指挥要塞连"},
	8: {"name": "堡垒专家", "name_en": "Fortress Expert", "desc": "要塞防御专家"},
	9: {"name": "要塞司令", "name_en": "Fortress Commander", "desc": "要塞最高指挥官"},
	10: {"name": "不落要塞", "name_en": "Impregnable Fortress", "desc": "永不陷落的传说"},
}

## ─────────────────────────────────────────────
##  查询接口
## ─────────────────────────────────────────────

## 根据兵种类型获取称号表
static func get_titles_for_unit_type(unit_type: int) -> Dictionary:
	match unit_type:
		0: return INFANTRY_TITLES      # LIGHT
		1: return ARMOR_TITLES         # ARMOR
		2: return ARTILLERY_TITLES    # SUPPORT (炮兵)
		3: return AIR_TITLES           # AIR
		4: return FORTRESS_TITLES      # FORT
		_: return INFANTRY_TITLES      # 默认步兵

## 根据兵种和等级获取称号信息
static func get_title_info(unit_type: int, level: int) -> Dictionary:
	var titles = get_titles_for_unit_type(unit_type)
	return titles.get(level, titles[1]).duplicate(true)

## 获取称号名称
static func get_title_name(unit_type: int, level: int) -> String:
	var info = get_title_info(unit_type, level)
	return info.get("name", "未知")

## 获取称号英文名称
static func get_title_name_en(unit_type: int, level: int) -> String:
	var info = get_title_info(unit_type, level)
	return info.get("name_en", "Unknown")

## 获取称号描述
static func get_title_desc(unit_type: int, level: int) -> String:
	var info = get_title_info(unit_type, level)
	return info.get("desc", "")
