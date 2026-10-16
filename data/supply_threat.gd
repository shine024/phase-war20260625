extends RefCounted
class_name SupplyThreat
## 区域威胁模型（v6.71 动态补给网 M1.1）——纯静态表与纯函数，无副作用。
## 有状态执行在 managers/supply_network_manager.gd。
##
## 心智模型（拍板决策 5）：威胁值是区域级的——每 10 关一区共 10 区，
## 与 world_map MAP_WINDOW_RADIUS=10 视野窗同宽（玩家视野≈一个区域的动态）。
## 区域威胁超阈值 → 区域内已通关关按防御值升序陷落 1 关（薄弱点先破）。
## 唯一主动降压口 = 与区域内异族战斗（清渗透 −15 / 收复战 −20；模拟战不减——战友不是异族）。
##
## 教程期休眠：L25 通关（EBM.INCURSION_UNLOCK_CLEARED_LEVEL）前整个威胁系统不动；
## gate_cleared_once（黑门本体已碎）后威胁停增（世界和平态）。

# ─────────────────────────────────────────────────────────────
#  常量（C3：全部数值口径单一来源，UI 文案从这里读）
# ─────────────────────────────────────────────────────────────

const REGION_SIZE: int = 10                 # 每 10 关一区
const REGION_COUNT: int = 10                # 100 关 → 10 区
const FALL_THRESHOLD: int = 100             # 陷落阈值
const FALL_RELIEF: int = 30                 # 陷落时区域威胁回吐（异族占地释放压力，给玩家反应窗口）
const NO_INCURSION_DECAY: int = 4           # 区域内无渗透时的自然微衰减/日
## 渗透加压：区域内每个活跃渗透点/日推高的威胁
const INCURSION_PRESSURE: int = 8
## 战斗降压：清渗透战胜 / 收复战胜（模拟战不减）
const CLEAR_INCURSION_RELIEF: int = 15
const RECONQUEST_RELIEF: int = 20

## 时代基础增速/日（一战 5 → 未来 12，按 LevelEras 5 时代；
## 区域增速 = 其所属时代的增速。时代→区域映射：区 1-2=WW1、3-4=WW2、5-6=COLD、7-8=MODERN、9-10=FUTURE）
const ERA_GROWTH: Dictionary = {
	1: 5,   # WW1（区 1-2）
	2: 7,   # WW2（区 3-4）
	3: 9,   # COLD（区 5-6）
	4: 10,  # MODERN（区 7-8）
	5: 12,  # FUTURE（区 9-10）
}

## 扰动幅度（±30% 确定性扰动，按存档 seed 逐区固定——同一存档同一区每天增速恒定）
const PERTURB_RANGE: float = 0.3

## 陷落候选防御值：enemy_loadout_tiers 四档 ×100（时代内位置推导，薄弱点先破）
const DEFENSE_BY_TIER: Dictionary = {
	1: 140,  # 新兵（时代内 1-5 关）
	2: 165,  # 老兵（6-11 关）
	3: 195,  # 精英（12-17 关）
	4: 225,  # 传奇（18-20 关含末关 boss）
}

# ─────────────────────────────────────────────────────────────
#  区域划分
# ─────────────────────────────────────────────────────────────

## 关卡 → 区域（1-based）。((level-1)/10)+1
static func region_for_level(level: int) -> int:
	return clampi((level - 1) / REGION_SIZE + 1, 1, REGION_COUNT)

## 区域 → 关卡范围（含首尾）。区 1 → [1,10]。
static func level_range_for_region(region: int) -> Vector2i:
	var r: int = clampi(region, 1, REGION_COUNT)
	return Vector2i((r - 1) * REGION_SIZE + 1, r * REGION_SIZE)

## 区域 → 所属时代（1-based，与 LevelEras.get_era 同轴：每 20 关一时代）
static func era_for_region(region: int) -> int:
	return clampi((region - 1) / 2 + 1, 1, 5)

# ─────────────────────────────────────────────────────────────
#  增速推导（纯函数）
# ─────────────────────────────────────────────────────────────

## 确定性扰动系数 [1-PERTURB_RANGE, 1+PERTURB_RANGE]，同一 (seed, region) 恒定。
## 用整数哈希而非 RNG——日结重放不打乱次序。
static func perturb_factor(region_seed: int, region: int) -> float:
	var h: int = hash("%d_%d" % [region_seed, region])
	var norm: float = float(absi(h) % 1001) / 1000.0  # [0,1]
	return (1.0 - PERTURB_RANGE) + norm * (PERTURB_RANGE * 2.0)

## 区域当日威胁增量（正=加压，负=衰减）。incursion_count=区域内活跃渗透点数。
## gate_cleared / threat_dormant 时调用方直接返回 0（休眠判定不放本函数）。
static func daily_delta(region: int, region_seed: int, incursion_count: int) -> int:
	var base: float = float(ERA_GROWTH.get(era_for_region(region), 5))
	base *= perturb_factor(region_seed, region)
	var delta: int = roundi(base)
	if incursion_count > 0:
		delta += incursion_count * INCURSION_PRESSURE
	else:
		delta -= NO_INCURSION_DECAY
	return delta

# ─────────────────────────────────────────────────────────────
#  防御值与陷落候选
# ─────────────────────────────────────────────────────────────

## 关卡防御值：时代内位置 → enemy_loadout_tiers 档位 → ×100。
## 时代内 1-5 关=新兵 140 / 6-11=老兵 165 / 12-17=精英 195 / 18-20=传奇 225
##（与 data/enemy_loadout_tiers.gd TIER 注释的档位区间同轴）。
static func defense_for_level(level: int) -> int:
	var pos_in_era: int = (level - 1) % 20 + 1  # 时代内 1..20
	var tier: int = 1
	if pos_in_era >= 18:
		tier = 4
	elif pos_in_era >= 12:
		tier = 3
	elif pos_in_era >= 6:
		tier = 2
	return int(DEFENSE_BY_TIER.get(tier, 140))

## 陷落候选排序：防御值升序（薄弱点先破）；同防御值按关卡号升序。
## held_levels: 当前 held 态的已通关关卡数组。
static func pick_fall_candidate(held_levels: Array) -> int:
	var candidates: Array = []
	for lv in held_levels:
		candidates.append({"lv": int(lv), "def": defense_for_level(int(lv))})
	if candidates.is_empty():
		return 0
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["def"] != b["def"]:
			return int(a["def"]) < int(b["def"])
		return int(a["lv"]) < int(b["lv"]))
	return int(candidates[0]["lv"])

# ─────────────────────────────────────────────────────────────
#  文案（C3 单一来源）
# ─────────────────────────────────────────────────────────────

static func describe_region_threat(region: int, threat: int) -> String:
	return "第%d区域威胁 %d/%d" % [region, clampi(threat, 0, 999), FALL_THRESHOLD]

static func describe_fall_forecast(region: int, threat: int, days_to_peak: int) -> String:
	if threat >= FALL_THRESHOLD:
		return "第%d区域已失控" % region
	if days_to_peak <= 0:
		return "第%d区域威胁 %d/%d，濒临失守" % [region, threat, FALL_THRESHOLD]
	return "第%d区域威胁 %d/%d，预计 %d 日后濒临失守" % [region, threat, FALL_THRESHOLD, days_to_peak]
