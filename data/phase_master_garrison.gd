extends RefCounted
class_name PhaseMasterGarrison
## 敌方相位师固定驻守关卡映射表（v7.x）
##
## 把"15%随机遭遇"改为"19个关卡100%遭遇固定相位师"。
## 每个驻守相位师带重新设计的机配卡(platforms)+相位仪(phase_instrument)。
## 非驻守关保留原15%随机机制。
##
## 驻守点设计：从第10关开始（新手保护期1-10关），每5关1个，覆盖5个时代。
## 难度随关卡递进（Lv10→Lv30），每时代3-4个驻守点。

# ─────────────────────────────────────────────────────────────
#  关卡 → 相位师ID 映射（19个驻守点）
# ─────────────────────────────────────────────────────────────

const GARRISON_LEVEL_TO_MASTER: Dictionary = {
	# ── WW1 时代（关卡 1-20）──
	10: "enemy_master_005",  # 钢铁元帅·克劳斯 Lv10 steel
	15: "enemy_master_006",  # 炎魔女王·赫卡特 Lv12 flame
	20: "enemy_master_007",  # 雷神之子·索尔 Lv13 thunder（WW1 Boss）

	# ── WW2 时代（关卡 21-40）──
	25: "enemy_master_008",  # 虚空领主·萨洛斯 Lv14 void
	30: "enemy_master_009",  # 钢铁军团长·费米 Lv16 steel
	35: "enemy_master_011",  # 雷皇·宙斯 Lv18 thunder
	40: "enemy_master_012",  # 虚空虚主·阿扎托斯 Lv19 void（WW2 Boss）

	# ── COLD 时代（关卡 41-60）──
	45: "enemy_master_013",  # 钢铁烈焰·卡尔 Lv18 steel_flame
	50: "enemy_master_015",  # 虚空烈焰·塞拉菲娜 Lv20 void_flame
	55: "enemy_master_016",  # 不朽钢铁·阿特拉斯 Lv22 steel
	60: "enemy_master_018",  # 万雷之主·雷神 Lv24 thunder（COLD Boss）

	# ── MODERN 时代（关卡 61-80）──
	65: "enemy_master_019",  # 虚空主宰·尼德霍格 Lv25 void
	70: "enemy_master_020",  # 钢铁雷霆·泰尔 Lv24 steel_thunder
	75: "enemy_master_022",  # 战争机器·铁骑 Lv26 steel
	80: "enemy_master_024",  # 风暴使者·赛勒斯 Lv27 thunder（MODERN Boss）

	# ── FUTURE 时代（关卡 81-100）──
	85: "enemy_master_025",  # 暗影主宰·深渊 Lv28 void
	90: "enemy_master_026",  # 钢铁之神·赫淮斯托斯 Lv28 steel
	95: "enemy_master_028",  # 雷神·托尔 Lv29 thunder
	100: "enemy_master_030", # 全能相位师·奥米伽 Lv30 all（终极Boss）
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
