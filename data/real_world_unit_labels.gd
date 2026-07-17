extends RefCounted
class_name RealWorldUnitLabels
## 单位信息 UI：武器 / 底盘 的「现实向」展示名（与 GameConstants 枚举序号一致，勿改序）。

## ── 当前 WeaponType（4值攻击方式）显示名（v6.5：修正枚举错位）──
## 注意：当前 WeaponType 只有 DIRECT/INDIRECT/AERIAL/SUPPORT 四值，
## 不再是旧的 12 值 WeaponTypeLegacy。这里返回的是「战斗方式」描述，
## 具体武器型号应由 CardResource.weapon_names[] 提供。
static func weapon_mode_name(weapon_type: int) -> String:
	match weapon_type:
		0:  # DIRECT
			return "直射武器"
		1:  # INDIRECT
			return "曲射武器"
		2:  # AERIAL
			return "空射武器"
		3:  # SUPPORT
			return "支援设备"
		_:
			return "未知"

## 简短战斗方式名
static func weapon_mode_short(weapon_type: int) -> String:
	match weapon_type:
		0: return "直射"
		1: return "曲射"
		2: return "空射"
		3: return "支援"
		_: return "未知"

## ── 旧 WeaponTypeLegacy（12值具体武器型号）显示名 ──
## 仅用于 legacy_weapon_type 字段（存档迁移），请勿对当前 WeaponType 传值。
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


## v7.x 修复：原按 GameConstants.PlatformType（13值 0=HOUND…12=COMMAND）返回底盘描述，
## 但所有调用方（default_cards:107 `c.platform_type = combat_kind`、card_info_panel、
## store_panel 等）实际传入的是 CombatKind（5值 0=轻装/1=装甲/2=支援/3=空中/4=堡垒），
## 导致 AH-64阿帕奇(空中=3) 显示成"永备工事"、导弹发射井(堡垒=4) 显示成"雷达指挥车"。
## 现统一为 CombatKind 5 值口径，与 card.combat_kind / stats.platform_type 对齐。
static func platform_chassis_long(platform_type: int) -> String:
	match platform_type:
		0:
			return "轻装步兵 / 侦察单位"
		1:
			return "装甲战斗车辆"
		2:
			return "支援 / 火力单位"
		3:
			return "空中单位"
		4:
			return "堡垒 / 固定工事"
		_:
			return "未知单位"


static func platform_chassis_short(platform_type: int) -> String:
	match platform_type:
		0: return "轻装"
		1: return "装甲"
		2: return "支援"
		3: return "空中"
		4: return "堡垒"
		_: return "未知"
