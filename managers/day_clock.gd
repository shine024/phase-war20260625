extends Node
## v6.4 天时钟管理器 — 365天循环剧情模式的核心时间系统
##
## 时间结构：
##   1年 = 365天
##   1天 = 5个时段（上午/下午/晚上/午夜/早晨）
##   时段推进方式：行动驱动（玩家每执行一个行动，时段+1）
##
## 信号流：
##   advance_phase() → day_phase_changed → (满5时段) → day_started
##   day 365 结束 → year_completed → 触发最终Boss/结局

# ── 常量 ───────────────────────────────────────────────────────────

const PHASES_PER_DAY: int = 5
const MAX_DAYS: int = 365

const PHASE_MORNING: int = 0     ## 上午
const PHASE_AFTERNOON: int = 1   ## 下午
const PHASE_EVENING: int = 2     ## 晚上
const PHASE_MIDNIGHT: int = 3    ## 午夜
const PHASE_DAWN: int = 4        ## 早晨

const PHASE_NAMES: Array[String] = ["上午", "下午", "晚上", "午夜", "早晨"]

## 时段蒙板颜色（用于城市地图氛围表现）
const PHASE_OVERLAY_COLORS: Array[Color] = [
	Color(1.0, 0.98, 0.9, 0.0),    # 上午：明亮无蒙板
	Color(1.0, 0.85, 0.6, 0.08),   # 下午：暖色
	Color(0.3, 0.2, 0.5, 0.25),    # 晚上：蓝紫
	Color(0.05, 0.05, 0.1, 0.5),   # 午夜：深黑
	Color(1.0, 0.9, 0.7, 0.05),    # 早晨：淡金
]

# ── 状态 ───────────────────────────────────────────────────────────

var current_day: int = 1         ## 当前天数（1-365）
var current_phase: int = 0       ## 当前时段（0-4）
var total_loops: int = 0         ## 周目数（0=一周目，1=二周目...）
var year_completed: bool = false ## 本周目是否已通关（第365天Boss战结束）

signal day_phase_changed(day: int, phase: int)
signal day_started(day: int)
signal phase_advanced(day: int, phase: int)
signal year_end_reached()

# ── 核心方法 ───────────────────────────────────────────────────────

func _ready() -> void:
	# SaveManager 会自动调用 load_state
	pass

## 推进一个时段（行动驱动：玩家执行行动后调用）
func advance_phase() -> void:
	if year_completed:
		return
	current_phase += 1
	if current_phase >= PHASES_PER_DAY:
		current_phase = 0
		current_day += 1
		if current_day > MAX_DAYS:
			current_day = MAX_DAYS
			current_phase = PHASES_PER_DAY - 1
			year_completed = true
			year_end_reached.emit()
			return
		day_started.emit(current_day)
	day_phase_changed.emit(current_day, current_phase)
	phase_advanced.emit(current_day, current_phase)

## 快进到指定天数（用于跳过空闲期，如"休息到第30天"）
func advance_to_day(target_day: int) -> void:
	target_day = clampi(target_day, current_day, MAX_DAYS)
	if target_day <= current_day:
		return
	current_day = target_day
	current_phase = PHASE_MORNING
	day_started.emit(current_day)
	day_phase_changed.emit(current_day, current_phase)

## 休息到第二天早晨（消耗剩余时段）
func rest_until_dawn() -> void:
	if year_completed:
		return
	current_day += 1
	current_phase = PHASE_MORNING
	if current_day > MAX_DAYS:
		current_day = MAX_DAYS
		year_completed = true
		year_end_reached.emit()
		return
	day_started.emit(current_day)
	day_phase_changed.emit(current_day, current_phase)

## 重置为新周目（保留 total_loops）
func reset_for_new_loop() -> void:
	current_day = 1
	current_phase = PHASE_MORNING
	year_completed = false
	total_loops += 1

## 完全重置（新游戏）
func full_reset() -> void:
	current_day = 1
	current_phase = PHASE_MORNING
	year_completed = false
	total_loops = 0

# ── 查询方法 ───────────────────────────────────────────────────────

## 获取当前时段名称
func get_current_phase_name() -> String:
	if current_phase >= 0 and current_phase < PHASE_NAMES.size():
		return PHASE_NAMES[current_phase]
	return "未知"

## 获取当前时段蒙板颜色
func get_current_phase_overlay() -> Color:
	if current_phase >= 0 and current_phase < PHASE_OVERLAY_COLORS.size():
		return PHASE_OVERLAY_COLORS[current_phase]
	return Color(1, 1, 1, 0)

## 获取时间显示字符串（如"第30天 · 下午"）
func get_time_display() -> String:
	return "第%d天 · %s" % [current_day, get_current_phase_name()]

## 获取完整时间显示（含周目）
func get_full_time_display() -> String:
	var loop_str: String = ""
	if total_loops > 0:
		loop_str = "（第%d周目）" % (total_loops + 1)
	return "第%d天 · %s%s" % [current_day, get_current_phase_name(), loop_str]

## 本周目进度（0.0-1.0）
func get_year_progress() -> float:
	return float(current_day) / float(MAX_DAYS)

## 是否为最终日
func is_final_day() -> bool:
	return current_day >= MAX_DAYS

## 今天是否是指定天数（用于主线节点检查）
func is_day(target_day: int) -> bool:
	return current_day == target_day

## 当前时段是否在指定列表中
func is_phase_in(phases: Array) -> bool:
	return phases.has(current_phase)

# ── 存档 ───────────────────────────────────────────────────────────

func save_state() -> Dictionary:
	return {
		"current_day": current_day,
		"current_phase": current_phase,
		"total_loops": total_loops,
		"year_completed": year_completed,
	}

func load_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	current_day = int(data.get("current_day", 1))
	current_phase = int(data.get("current_phase", 0))
	total_loops = int(data.get("total_loops", 0))
	year_completed = bool(data.get("year_completed", false))
