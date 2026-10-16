extends RefCounted
class_name BattleEvaluation
## 战斗考评评分（v6.71 动态补给网 M2.2）——纯函数，无副作用。
##
## 口径（拍板决策 3/4）：考评=玩家亲自打的真实对战考核；评分=兑换权限——
## 每关记最近一次评分（覆盖式，非历史最高），不打就凭上次评分随时兑换。
## 输入字段来自 battle_manager.get_battle_result()（v6.71 起补 max_deployed/
## units_lost/elapsed_time/wave_total/wave_interval 五字段，见 battle_damage_system）。
##
## 分项：星级 40 + 存活率 30 + 时长比 30 → S≥85 / A≥70 / B≥50 / C。
## 文案单一源（C3）：describe_grade_breakdown 结算页直接展示，数值全读常量。

const STAR_WEIGHT: float = 40.0
const SURVIVAL_WEIGHT: float = 30.0
const TIME_WEIGHT: float = 30.0

const GRADE_S: int = 85
const GRADE_A: int = 70
const GRADE_B: int = 50
## C 无下限（<GRADE_B 即 C）

const GRADE_ORDER: Dictionary = {
	"S": 4, "A": 3, "B": 2, "C": 1,
}

## 旧档迁移折算：level_stars 3★→S / 2★→A / 1★→B / 0★→无评分
const STARS_TO_GRADE: Dictionary = {
	3: "S", 2: "A", 1: "B",
}

# ─────────────────────────────────────────────────────────────
#  评分主函数
# ─────────────────────────────────────────────────────────────

## 计算考评分。result 需含：victory_stars / max_deployed / units_lost /
## elapsed_time / wave_total / wave_interval。
## 返回 {grade: String, total: int, star_pts, survive_pts, time_pts: float}
static func calculate_evaluation_grade(result: Dictionary) -> Dictionary:
	var stars: int = clampi(int(result.get("victory_stars", 0)), 0, 3)
	var star_pts: float = stars / 3.0 * STAR_WEIGHT

	var deployed: int = int(result.get("max_deployed", 0))
	var lost: int = clampi(int(result.get("units_lost", 0)), 0, 999999)
	var survive_ratio: float = 1.0
	if deployed > 0:
		survive_ratio = clampf(1.0 - float(lost) / float(deployed), 0.0, 1.0)
	var survive_pts: float = survive_ratio * SURVIVAL_WEIGHT

	var elapsed: float = float(result.get("elapsed_time", 0.0))
	var wave_total: int = int(result.get("wave_total", 0))
	var wave_interval: float = float(result.get("wave_interval", 0.0))
	var time_ref: float = wave_total * wave_interval
	var time_ratio: float = 1.0
	if time_ref > 0.0 and elapsed > time_ref:
		# 参考时长内满分；超时线性衰减，2 倍参考时长归零
		time_ratio = clampf(1.0 - (elapsed / time_ref - 1.0), 0.0, 1.0)
	var time_pts: float = time_ratio * TIME_WEIGHT

	var total: int = roundi(star_pts + survive_pts + time_pts)
	var grade: String = "C"
	if total >= GRADE_S:
		grade = "S"
	elif total >= GRADE_A:
		grade = "A"
	elif total >= GRADE_B:
		grade = "B"
	return {
		"grade": grade,
		"total": total,
		"star_pts": star_pts,
		"survive_pts": survive_pts,
		"time_pts": time_pts,
	}

## 旧档折算（读档时按 level_stars 生成初始评分）
static func grade_from_stars(stars: int) -> String:
	return String(STARS_TO_GRADE.get(clampi(stars, 0, 3), ""))

## 评分档位是否解锁某箱子档（supply_exchange 消费）
static func grade_rank(grade: String) -> int:
	return int(GRADE_ORDER.get(grade, 0))

# ─────────────────────────────────────────────────────────────
#  文案（C3 单一来源）
# ─────────────────────────────────────────────────────────────

## 分项明细（结算页展示）——唯一文案源，数值全从常量/入参读。
static func describe_grade_breakdown(ev: Dictionary) -> String:
	return "考评 %s（%d 分）\n星级 %d/%d\n存活 %d/%d\n用时 %d/%d" % [
		String(ev.get("grade", "C")),
		int(ev.get("total", 0)),
		roundi(float(ev.get("star_pts", 0.0))),
		roundi(STAR_WEIGHT),
		roundi(float(ev.get("survive_pts", 0.0))),
		roundi(SURVIVAL_WEIGHT),
		roundi(float(ev.get("time_pts", 0.0))),
		roundi(TIME_WEIGHT),
	]

## 评分覆盖提示（覆盖式口径：结算页醒目提示「评分 A→B」）
static func describe_grade_change(old_grade: String, new_grade: String) -> String:
	if old_grade.is_empty():
		return "本关评级：%s" % new_grade
	if old_grade == new_grade:
		return "评级保持 %s" % new_grade
	return "评级 %s→%s（记最近一次评分）" % [old_grade, new_grade]
