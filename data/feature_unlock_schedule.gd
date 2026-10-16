extends RefCounted
class_name FeatureUnlockSchedule

## v34 渐进解锁节奏表（早期体验重构批·用户拍板"温和"档）
##
## 「关卡进度 → 系统解锁」唯一真身。开局只留核心入口（出击/卡仓/地图/成长/设置/
## 存档/帮助），其余系统随通关逐步解锁——解决"新档第一屏 31 个入口零门控"的选择过载。
##
## 当前节奏（v6.38.4 记录5追加：旁路六件 L15→L4，用户主诉"任务及相关太晚"）：
## L2 制造+情报 / L4 旁路六件（委托/成就/图鉴/战功榜/同伴档案/纪念墙）/
## L5 挂机 / L6 改造 / L10 势力+补给 / L12 词条工坊。
##
## ⚠️ 契约：
## - 键名与三个入口层对齐——truck_base HOTSPOTS 的 panel key / bottom_function_bar
##   的 8 键+抽屉 / main._open_overlay 的 overlay key。加新系统入口时先在此注册，
##   否则视为常开。
## - 解锁态从关卡进度推导（is_feature_unlocked 在 LevelProgressManager），
##   教程已完成的存档全开兜底；存档 schema 零改动。
## - 解锁仪式：LevelProgressManager 跨级时经 SignalBus.feature_unlocked 广播，
##   消费方（truck_base/底栏/教程）弹 FeatureUnlockPopup（key 前缀 feature_gate_ 去重）。
## - 总开关 GameConfig.feature_gates_enabled（false=一键回退全开）。
## - L1 常开集不进本表：sortie/march/backpack/growth/map/settings/save/help/
##   terminal/sleep/info 类工位。

const SCHEDULE := {
	# ── 养成主链（灰显+锁标，锁定本身是期待感来源）──
	# v37 实机验收轮（用户拍板）：制造+情报提前到 L2、改造推后到 L6——
	# 首战掉的新卡先走"制造补战力"回路（新档已附起始卡同族 25% 情报地板），
	# 改造的图纸消耗体系等玩家熟悉制造后再开。
	"modification": {
		"level": 6,
		"title": "改造舱",
		# v5 教程整合批：教程 MODIFICATION 步退役，图纸三路补给教学并入解锁仪式
		"desc": "用缴获的图纸给战斗卡安装改造模块：缴获 1 张图纸 + 纳米材料即可安装，战力立涨。图纸三路补给：战斗掉落 / 制造舱制造 / 补给舱采购。",
	},
	"evolution": {
		"level": 2,
		"title": "制造中心",
		"desc": "消耗纳米材料制造新兵种。情报 25% 解锁对应配方，品质随档提升——新档已附赠起始卡同族情报，首战通关即可开工。",
	},
	"afk": {
		"level": 5,
		"title": "挂机作战",
		"desc": "自动反复出击已通关的关卡，材料持续入账——离线期间也在积累。",
	},
	"intelligence": {
		"level": 2,
		"title": "情报舱",
		"desc": "敌方情报阶梯：25% 解锁制造配方，50%/75% 扩品质池，100% 含神话品质。",
	},
	"faction": {
		"level": 10,
		"title": "势力联络台",
		# v5 教程整合批：教程 FACTION_REP 步退役，贡献解锁内容教学并入解锁仪式
		"desc": "七大势力的声望与外交在战场上等待着你——击败首位驻守相位师后开放。完成委托与事件提升贡献，贡献等级解锁势力专属卡牌、相位仪与技能。",
	},
	"store": {
		"level": 10,
		"title": "补给舱",
		# v5 教程整合批：教程 SHOP 步退役，符文可购/售货机同源教学并入解锁仪式
		"desc": "消耗声望购买卡牌、资源与符文。声望来自作战与势力任务；各公司上架物资不同，移动基地的「补给售货机」工位是同一个补给舱。",
	},
	"affix": {
		"level": 12,
		"title": "词条工坊",
		"desc": "对卡牌词条洗练/锁定/批量重随——普通卡耗纳米+晶体，星冥卡耗星髓。",
	},
	# ── 旁路系统（v6.38.4 提前到 L4——任务/成就前期给方向感与额外奖励；
	# 六件一次性开闸保持单次解锁仪式，同伴档案/纪念墙的"内容"仍由击败驻守相位师驱动）──
	"quest": {
		"level": 4,
		"title": "委托台",
		"desc": "接取委托与日常任务——日常每天刷新 7 个，奖励需在\"日常\"页签手动领取。",
	},
	"achievement": {
		"level": 4,
		"title": "成就",
		"desc": "生涯里程碑自动累计：达成即领纳米/稀有卡/称号。",
	},
	"collection": {
		"level": 4,
		"title": "收藏图鉴",
		"desc": "按时代检阅收藏过的卡种；缴获与制造都会录入。",
	},
	"leaderboard": {
		"level": 4,
		"title": "战功榜",
		"desc": "三大战绩档案：公司势力排名、相位师排名、敌方相位师图鉴。",
	},
	"hero_archive": {
		"level": 4,
		"title": "同伴档案",
		"desc": "30 位牺牲相位师的生平与遗言——击败驻守相位师带回遗物解锁。",
	},
	"memorial": {
		"level": 4,
		"title": "纪念墙",
		"desc": "30 盏灯对应 30 位牺牲相位师；灯亮可点击读名。",
	},
	# v6.71 动态补给网：补给中枢 L25 解锁（威胁系统首个渗透约在玩家推进到 L20+ 时显现）。
	"supply_network": {
		"level": 25,
		"title": "补给中枢",
		"desc": "动态补给网态势：十区域威胁、陷落与收复、遗物收集，以及迷失在黑门里的战友名册。",
	},
}

## 键是否在节奏表内（不在 = 常开，不设防）
static func has_key(key: String) -> bool:
	return SCHEDULE.has(key)

## 解锁关卡（未知键返回 0 = 常开）
static func unlock_level_for(key: String) -> int:
	if not SCHEDULE.has(key):
		return 0
	return int(SCHEDULE[key]["level"])

## 全部键（按解锁关卡升序，测试/审计用）
static func keys_by_level() -> Array:
	var out: Array = SCHEDULE.keys()
	out.sort_custom(func(a, b) -> bool:
		return int(SCHEDULE[a]["level"]) < int(SCHEDULE[b]["level"]))
	return out

## 指定关卡新解锁的键列表（LevelProgressManager 跨级广播用）
static func keys_unlocked_at(level: int) -> Array:
	var out: Array = []
	for key in SCHEDULE:
		if int(SCHEDULE[key]["level"]) == level:
			out.append(key)
	return out

## 给定"最高已解锁关卡"推导开放键集合（测试锁用）
static func unlocked_keys_at_max_level(max_level: int) -> Array:
	var out: Array = []
	for key in SCHEDULE:
		if int(SCHEDULE[key]["level"]) <= max_level:
			out.append(key)
	return out
