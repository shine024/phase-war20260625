extends RefCounted
class_name RelicRegistry
## 遗物注册表（v6.71 动态补给网 M1.3）——纯静态表，24 件（每时代 4 + 黑门 4）。
##
## 设计边界（拍板）：效果只做经济/QoL 侧，零战斗数值。
## 五类效果（effect → 数值单位均为百分比点数，聚合取总和）：
##   exchange_discount 关卡兑换价折扣%（ SupplyNetworkManager.exchange_box 消费）
##   fuel_efficiency   燃料消耗减免%（truck_travel 消费）
##   salvage_rate      缴获率加成%（异族战资源结算消费）
##   xeno_bonus        异族战资源加成%（渗透/收复结算消费）
##   threat_slow       区域威胁增速降低点数/日（supply_threat 增速参数化消费——
##                     遗物里少数战略型）
##
## 收集度阶梯（网络级被动，全常量）：
##   5 件 → 兑换价再 −2% / 10 件 → 异族战资源 +5% / 18 件 → 燃料再 −5% / 24 件 → 威胁增速 −5
##
## 存档口径：IntelItemBag「见过集合」（relic_box 开启时 add_item("relic_<id>")）。

## 遗物条目字段：id / name / era / effect / value / desc
## era: "ww1"/"ww2"/"cold"/"modern"/"future"/"gate"
const RELICS: Array = [
	# ── WW1（4）──
	{"id": "relic_ww1_watch",       "name": "军用怀表",     "era": "ww1",    "effect": "exchange_discount", "value": 3,  "desc": "战壕里校准过的怀表，补给官见到它会多让一点价。"},
	{"id": "relic_ww1_binocular",   "name": "黄铜望远镜",   "era": "ww1",    "effect": "salvage_rate",      "value": 3,  "desc": "看得越远，捡得越多。"},
	{"id": "relic_ww1_mask",        "name": "氧气面罩",     "era": "ww1",    "effect": "fuel_efficiency",   "value": 2,  "desc": "滤毒罐改的进气口，发动机喝油省了一点。"},
	{"id": "relic_ww1_prayer",      "name": "战壕祈祷书",   "era": "ww1",    "effect": "threat_slow",       "value": 1,  "desc": "扉页写着：守住今日。区域内异族的推进似乎慢了些。"},
	# ── WW2（4）──
	{"id": "relic_ww2_silk",        "name": "降落伞绸",     "era": "ww2",    "effect": "salvage_rate",      "value": 3,  "desc": "一整幅完好的伞衣，能换不少物资。"},
	{"id": "relic_ww2_enigma",      "name": "恩尼格玛残件", "era": "ww2",    "effect": "exchange_discount", "value": 4,  "desc": "转轮还能转。补给网的对账员看不懂，但敬重它。"},
	{"id": "relic_ww2_aviation",    "name": "航空汽油添加剂", "era": "ww2",  "effect": "fuel_efficiency",   "value": 3,  "desc": "老配方，蓝火焰。"},
	{"id": "relic_ww2_radar",       "name": "雷达残屏",     "era": "ww2",    "effect": "threat_slow",       "value": 1,  "desc": "荧光点比肉眼早几分钟看见渗透的影子。"},
	# ── COLD（4）──
	{"id": "relic_cold_gear",       "name": "铱合金齿轮",   "era": "cold",   "effect": "exchange_discount", "value": 4,  "desc": "精密到不该出现在这个时代。"},
	{"id": "relic_cold_radio",      "name": "加密电台",     "era": "cold",   "effect": "xeno_bonus",        "value": 5,  "desc": "能提前截获异族补给坐标，战斗缴获更丰厚。"},
	{"id": "relic_cold_battery",    "name": "核电池",       "era": "cold",   "effect": "fuel_efficiency",   "value": 3,  "desc": "五十年没充过电，还在输出。"},
	{"id": "relic_cold_array",      "name": "预警雷达阵列", "era": "cold",   "effect": "threat_slow",       "value": 2,  "desc": "北方屏幕上，威胁的爬升慢了半格。"},
	# ── MODERN（4）──
	{"id": "relic_modern_ceramic",  "name": "陶瓷装甲片",   "era": "modern", "effect": "salvage_rate",      "value": 4,  "desc": "轻、硬、值钱。"},
	{"id": "relic_modern_drone",    "name": "无人机核心",   "era": "modern", "effect": "xeno_bonus",        "value": 6,  "desc": "战后自动扫描战场，漏缴的都补回来了。"},
	{"id": "relic_modern_chip",     "name": "量子通信芯片", "era": "modern", "effect": "exchange_discount", "value": 5,  "desc": "补给网各节点实时对账，中间损耗趋近于零。"},
	{"id": "relic_modern_gateway",  "name": "卫星预警网关", "era": "modern", "effect": "threat_slow",       "value": 2,  "desc": "全域监控让渗透无处藏身，推进自然迟滞。"},
	# ── FUTURE（4）──
	{"id": "relic_future_coil",     "name": "曲率线圈",     "era": "future", "effect": "fuel_efficiency",   "value": 4,  "desc": "路变短了，油就省了。"},
	{"id": "relic_future_forge",    "name": "纳米熔炉核心", "era": "future", "effect": "salvage_rate",      "value": 5,  "desc": " battlefield 废铁进去，制式锭材出来。"},
	{"id": "relic_future_crystal",  "name": "相位谐振水晶", "era": "future", "effect": "xeno_bonus",        "value": 8,  "desc": "与相位师信号同频，战斗收益水涨船高。"},
	{"id": "relic_future_anchor",   "name": "时空锚原型",   "era": "future", "effect": "threat_slow",       "value": 3,  "desc": "把区域的一天锚得更稳，异族更难站稳脚跟。"},
	# ── 黑门（4）──
	{"id": "relic_gate_hinge",      "name": "门枢残片",     "era": "gate",   "effect": "exchange_discount", "value": 6,  "desc": "黑门碎裂时崩出的残骸。补给网认得它，愿意让价。"},
	{"id": "relic_gate_eye",        "name": "吞噬者之眼",   "era": "gate",   "effect": "salvage_rate",      "value": 6,  "desc": "它看过的地方，没有东西能被漏掉。"},
	{"id": "relic_gate_inscription", "name": "门语者铭文",  "era": "gate",   "effect": "xeno_bonus",        "value": 10, "desc": "读懂门中低语的人，知道异族的软肋在哪。"},
	{"id": "relic_gate_engine",     "name": "回溯引擎残核", "era": "gate",   "effect": "threat_slow",       "value": 4,  "desc": "时间的逆流在残核里打转，威胁的时钟被拨慢。"},
]

## 收集度阶梯（件数 → 网络级被动效果，全常量 C3）
const COLLECTION_MILESTONES: Dictionary = {
	5:  {"effect": "exchange_discount", "value": 2,  "desc": "补给网信誉：兑换价 −2%"},
	10: {"effect": "xeno_bonus",        "value": 5,  "desc": "战友情报网：异族战资源 +5%"},
	18: {"effect": "fuel_efficiency",   "value": 5,  "desc": "补给线熟路：燃料 −5%"},
	24: {"effect": "threat_slow",       "value": 5,  "desc": "全域镇守：区域威胁增速 −5/日"},
}

# ─────────────────────────────────────────────────────────────
#  查询 API
# ─────────────────────────────────────────────────────────────

static func get_by_id(relic_id: String) -> Dictionary:
	for r in RELICS:
		if String(r.get("id", "")) == relic_id:
			return r.duplicate(true)
	return {}

static func get_all() -> Array:
	return RELICS.duplicate(true)

static func get_ids() -> Array:
	var out: Array = []
	for r in RELICS:
		out.append(String(r.get("id", "")))
	return out

static func total_count() -> int:
	return RELICS.size()

## 聚合：owned_ids（已拥有遗物 id 集合）+ 收集度阶梯 → 指定效果总和。
## SupplyNetworkManager.get_relic_effect_sum(effect) 的纯函数核心。
static func aggregate_effect(effect: String, owned_ids: Array) -> int:
	var owned := {}
	for oid in owned_ids:
		owned[String(oid)] = true
	var total: int = 0
	for r in RELICS:
		if owned.has(String(r.get("id", ""))) and String(r.get("effect", "")) == effect:
			total += int(r.get("value", 0))
	var collected: int = owned.size()
	for threshold in COLLECTION_MILESTONES.keys():
		var ms: Dictionary = COLLECTION_MILESTONES[threshold]
		if collected >= int(threshold) and String(ms.get("effect", "")) == effect:
			total += int(ms.get("value", 0))
	return total

## 收集度阶梯当前应得的被动条目列表（面板展示用）
static func active_milestones(owned_count: int) -> Array:
	var out: Array = []
	for threshold in COLLECTION_MILESTONES.keys():
		if owned_count >= int(threshold):
			out.append(COLLECTION_MILESTONES[threshold].duplicate(true))
	return out

## 下一阶梯（面板展示用）；全收集返回空字典
static func next_milestone(owned_count: int) -> Dictionary:
	var thresholds: Array = COLLECTION_MILESTONES.keys()
	thresholds.sort()
	for threshold in thresholds:
		if owned_count < int(threshold):
			return {"count": int(threshold), "desc": String(COLLECTION_MILESTONES[threshold].get("desc", ""))}
	return {}

## 遗物箱 roll：必得 1 件未拥有（权重表+未拥有优先）；全收集返回空（调用方转资源包）。
## weights 字典 id → 权重（缺省 RELIC_BOX_FALLBACK_WEIGHT）。
const RELIC_BOX_FALLBACK_WEIGHT: float = 10.0

static func roll_unowned(owned_ids: Array) -> String:
	var owned := {}
	for oid in owned_ids:
		owned[String(oid)] = true
	var pool: Array = []
	var total_w: float = 0.0
	for r in RELICS:
		var rid: String = String(r.get("id", ""))
		if owned.has(rid):
			continue
		var w: float = float(r.get("box_weight", RELIC_BOX_FALLBACK_WEIGHT))
		pool.append({"id": rid, "w": w})
		total_w += w
	if pool.is_empty() or total_w <= 0.0:
		return ""
	var roll: float = randf() * total_w
	var acc: float = 0.0
	for entry in pool:
		acc += float(entry["w"])
		if roll <= acc:
			return String(entry["id"])
	return String(pool[pool.size() - 1]["id"])

# ─────────────────────────────────────────────────────────────
#  文案（C3 单一来源）
# ─────────────────────────────────────────────────────────────

static func describe_effect(relic: Dictionary) -> String:
	match String(relic.get("effect", "")):
		"exchange_discount":
			return "兑换价 −%d%%" % int(relic.get("value", 0))
		"fuel_efficiency":
			return "燃料消耗 −%d%%" % int(relic.get("value", 0))
		"salvage_rate":
			return "缴获率 +%d%%" % int(relic.get("value", 0))
		"xeno_bonus":
			return "异族战资源 +%d%%" % int(relic.get("value", 0))
		"threat_slow":
			return "区域威胁增速 −%d/日" % int(relic.get("value", 0))
	return ""

const ERA_LABELS: Dictionary = {
	"ww1": "一战", "ww2": "二战", "cold": "冷战", "modern": "现代", "future": "未来", "gate": "黑门",
}

static func describe_era(era: String) -> String:
	return String(ERA_LABELS.get(era, era))
