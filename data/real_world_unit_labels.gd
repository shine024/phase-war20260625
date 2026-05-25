extends RefCounted
class_name RealWorldUnitLabels
## 单位信息 UI：武器 / 底盘 的「现实向」展示名（与 GameConstants 枚举序号一致，勿改序）。

## 与 GameConstants.WeaponType 一致：0=SMG … 11=RAIL_CANNON
static func weapon_kind_long(weapon_type: int) -> String:
	match weapon_type:
		0:
			return "冲锋枪（冲锋枪族，如 MP5、P90）"
		1:
			return "突击步枪 / 步枪（中口径自动武器）"
		2:
			return "车载机枪（7.62mm 通用机枪类，如 M240、PKM）"
		3:
			return "火箭筒 / 无后坐力炮（如 RPG、AT4）"
		4:
			return "手枪（自卫武器）"
		5:
			return "霰弹枪（近战破门与压制）"
		6:
			return "狙击步枪 / 精确射手步枪"
		7:
			return "高射炮 / 自行防空炮（中小口径）"
		8:
			return "定向能武器（高能激光，架空）"
		9:
			return "导弹发射器（制导武器）"
		10:
			return "重粒子束炮（科幻设定）"
		11:
			return "电磁轨道炮"
		_:
			return "未知武装"


## 简短名：列表、紧凑 UI
static func weapon_kind_short(weapon_type: int) -> String:
	match weapon_type:
		0: return "冲锋枪"
		1: return "步枪"
		2: return "车载机枪"
		3: return "火箭筒"
		4: return "手枪"
		5: return "霰弹枪"
		6: return "狙击枪"
		7: return "高射炮"
		8: return "激光"
		9: return "导弹"
		10: return "粒子炮"
		11: return "轨道炮"
		_: return "未知"


## 与 GameConstants.PlatformType 一致：0=HOUND … 12=COMMAND
static func platform_chassis_long(platform_type: int) -> String:
	match platform_type:
		0:
			return "轻型装甲侦察车（轮式）"
		1:
			return "主战坦克 / 护卫战车（中型装甲）"
		2:
			return "重型主战坦克"
		3:
			return "永备工事 / 固定炮位"
		4:
			return "雷达指挥车 / 电子对抗站"
		5:
			return "轻型侦察车"
		6:
			return "突击装甲车辆"
		7:
			return "自行火炮 / 曲射支援"
		8:
			return "步兵战车 / 装甲输送车"
		9:
			return "战场救护车 / 维修工程车"
		10:
			return "隐身侦察平台（架空）"
		11:
			return "全装重型机动平台（架空）"
		12:
			return "指挥战车 / 联合作业指挥站"
		_:
			return "未知底盘"


static func platform_chassis_short(platform_type: int) -> String:
	match platform_type:
		0: return "轻侦装甲"
		1: return "主战/护卫"
		2: return "重型坦克"
		3: return "固定工事"
		4: return "雷达/电抗"
		5: return "侦察车"
		6: return "突击车"
		7: return "自行火炮"
		8: return "步战车"
		9: return "救护/维修"
		10: return "隐身侦"
		11: return "全装机甲"
		12: return "指挥车"
		_: return "未知"
