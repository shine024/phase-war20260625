extends RefCounted
class_name PhaseMasterGarrison
## 敌方相位师固定驻守关卡映射表（v7.x）
##
## 把"15%随机遭遇"改为"20个关卡100%遭遇固定相位师"。
## 每个驻守相位师带重新设计的机配卡(platforms)+相位仪(phase_instrument)。
## 非驻守关保留原15%随机机制。
##
## 驻守点设计：从第10关开始（新手保护期1-10关），每5关1个，覆盖5个时代。
## 难度随关卡递进（Lv10→Lv30），每时代3-4个驻守点。

# ─────────────────────────────────────────────────────────────
#  关卡 → 相位师ID 映射（20个驻守点）
# ─────────────────────────────────────────────────────────────

const GARRISON_LEVEL_TO_MASTER: Dictionary = {
	# ── WW1 时代（关卡 1-20）──
	10: "enemy_master_005",  # 阿奇博尔德·格雷 Lv10 steel
	15: "enemy_master_006",  # 塞尔焦·费拉里 Lv12 flame
	20: "enemy_master_007",  # 穆斯塔法·德米拉 Lv13 thunder（WW1 Boss）

	# ── WW2 时代（关卡 21-40）──
	25: "enemy_master_008",  # 叶莲娜·索科洛娃 Lv14 void
	30: "enemy_master_009",  # 奥托·施泰因贝格 Lv16 steel
	35: "enemy_master_011",  # 弗兰克·莫里森 Lv18 thunder
	40: "enemy_master_012",  # 亚瑟·惠特克 Lv19 void（WW2 Boss）

	# ── COLD 时代（关卡 41-60）──
	45: "enemy_master_013",  # 沃尔夫冈·布伦纳 Lv18 steel_flame
	49: "enemy_master_014",  # 德米特里·杜宾 Lv19 thunder_steel（原第49关硬编码，驻守化）
	50: "enemy_master_015",  # 薇拉·科瓦奇 Lv20 void_flame
	55: "enemy_master_016",  # 罗伊·斯坦顿 Lv22 steel
	60: "enemy_master_018",  # 谢尔盖·沃洛宁 Lv24 thunder（COLD Boss）

	# ── MODERN 时代（关卡 61-80）──
	65: "enemy_master_019",  # 拉斐尔·埃斯皮诺萨 Lv25 void
	70: "enemy_master_020",  # 阿米娜·奥科耶 Lv24 steel_thunder
	75: "enemy_master_022",  # 朴成宰 Lv26 steel
	80: "enemy_master_024",  # 英格里德·索尔海姆 Lv27 thunder（MODERN Boss）

	# ── FUTURE 时代（关卡 81-100）──
	85: "enemy_master_025",  # 维克多·内维斯 Lv28 void
	90: "enemy_master_026",  # 阿列克谢·莫罗佐夫 Lv28 steel
	95: "enemy_master_028",  # 玛雅·奥杜亚 Lv29 thunder
	100: "enemy_master_030", # 贺同舟 Lv30 all（终极Boss）
}

# ─────────────────────────────────────────────────────────────
#  查询 API
# ─────────────────────────────────────────────────────────────

## 查询关卡是否有固定驻守相位师，返回 master_id（非驻守关返回空字符串）
static func get_garrison_master_id(level: int) -> String:
	return String(GARRISON_LEVEL_TO_MASTER.get(level, ""))

## 判断关卡是否为驻守关
static func is_garrison_level(level: int) -> bool:
	return GARRISON_LEVEL_TO_MASTER.has(level)

## 获取所有驻守关卡号（升序）
static func get_all_garrison_levels() -> Array:
	var levels: Array = GARRISON_LEVEL_TO_MASTER.keys()
	levels.sort()
	return levels

## 获取所有驻守相位师ID
static func get_all_garrison_master_ids() -> Array:
	return GARRISON_LEVEL_TO_MASTER.values()

## 查询指定相位师ID驻守在哪个关卡（反向查询，返回关卡号，未驻守返回-1）
static func get_garrison_level_for_master(master_id: String) -> int:
	for level in GARRISON_LEVEL_TO_MASTER.keys():
		if String(GARRISON_LEVEL_TO_MASTER[level]) == master_id:
			return int(level)
	return -1
