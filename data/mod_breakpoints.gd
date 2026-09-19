extends RefCounted
class_name ModBreakpoints
## v6.16 断点阶梯（Diablo 2 式门槛跳变）——攻速聚合增益 → 离散档位。
##
## 设计目标：连续乘区改不出"跨过门槛"的瞬间；把攻速堆叠改成阶梯后，
## 每跨一档有一次肉眼可见的跳变（额外提速 + 首弹蓄力削减），
## 玩家会像 D2 凑 FCR 断点一样"刚好够到就停"。
##
## 口径契约：
## - 增益 g = 该武器槽维度"改造后攻速 / 改造前攻速 - 1"（构筑期一次性计算，
##   包含 attack_interval / sustained_fire 等全部改造速度来源；
##   战斗期光环类速度加成不参与——避免运行态档位抖动）。
## - 档位只升不叠：resolve 取满足阈值的最高档。
## - 消费点唯一：UnitStatsTable._sync_mod_speed_ratio_to_weapon_slots
##   （玩家 build_stats_from_card 与经典敌兵 setup 同调它，敌我同构）。
## - 总开关 GameConfig.mod_breakpoints_enabled（false = 回退连续乘区旧行为）。

## 档位表（threshold=增益门槛；speed_mult=档位额外速度乘区；
## windup_mult=首弹蓄力乘区；tag=UI 档位名）
const TIERS: Array = [
	{"threshold": 0.20, "speed_mult": 1.05, "windup_mult": 0.75, "tag": "I 先手"},
	{"threshold": 0.40, "speed_mult": 1.12, "windup_mult": 0.50, "tag": "II 连射"},
	{"threshold": 0.70, "speed_mult": 1.20, "windup_mult": 0.25, "tag": "III 风暴"},
	{"threshold": 1.10, "speed_mult": 1.35, "windup_mult": 0.10, "tag": "IV 超频"},
]


## 增益 → 档位信息。
## 返回 {tier:int(0-4), speed_mult:float, windup_mult:float, tag:String,
##       next_threshold:float(-1=已满档), to_next:float(距下一档还差多少增益)}
static func resolve(gain: float) -> Dictionary:
	var out: Dictionary = {
		"tier": 0, "speed_mult": 1.0, "windup_mult": 1.0, "tag": "",
		"next_threshold": float(TIERS[0].get("threshold")), "to_next": 0.0,
	}
	for i in range(TIERS.size()):
		if gain >= float(TIERS[i]["threshold"]):
			out["tier"] = i + 1
			out["speed_mult"] = float(TIERS[i]["speed_mult"])
			out["windup_mult"] = float(TIERS[i]["windup_mult"])
			out["tag"] = String(TIERS[i]["tag"])
			out["next_threshold"] = float(TIERS[i + 1]["threshold"]) if i + 1 < TIERS.size() else -1.0
			out["to_next"] = maxf(0.0, out["next_threshold"] - gain) if out["next_threshold"] > 0.0 else 0.0
		else:
			# 尚未到本档：下一档门槛与差值以本档为准
			out["next_threshold"] = float(TIERS[i]["threshold"])
			out["to_next"] = maxf(0.0, float(TIERS[i]["threshold"]) - gain)
			break
	return out


## UI 一行文案（改造面板卡详情用）。
## 示例："II 连射（+41%）· 下一档 III 还差 29%" / "未达断点（+15%，还差 5%）"
static func describe_for_ui(gain: float) -> String:
	var bp := resolve(gain)
	var pct := int(round(gain * 100.0))
	if int(bp["tier"]) <= 0:
		var need := int(ceil(float(bp["to_next"]) * 100.0))
		return "未达断点（攻速改造 +%d%%，还差 %d%% 到 I 先手）" % [pct, need]
	var line := "%s（攻速改造 +%d%%）" % [String(bp["tag"]), pct]
	if float(bp["next_threshold"]) > 0.0:
		line += " · 下一档还差 %d%%" % int(ceil(float(bp["to_next"]) * 100.0))
	return line


## 卡牌对象（CardResource 鸭子类型）→ 三维中最大改造攻速增益。
## 供 UI 展示用（与战斗侧 _sync_mod_speed_ratio_to_weapon_slots 同口径：
## get_modified_stats 的 attack_*_speed 键从 1.0 起步、只累计改造乘区，
## 故增益 = 键值 - 1，勿再除以卡基础轴速）。
static func max_speed_gain_for_card(card) -> float:
	if card == null or not card.has_method("get_modified_stats"):
		return 0.0
	var stats: Dictionary = card.get_modified_stats()
	if stats.is_empty():
		return 0.0
	var best: float = 0.0
	for key in ["attack_light_speed", "attack_armor_speed", "attack_air_speed"]:
		best = maxf(best, float(stats.get(key, 1.0)) - 1.0)
	return best
