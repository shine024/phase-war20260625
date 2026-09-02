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

# v25.3 产能结算已退役：产能点（production_points）唯一 sink 无 UI 调用方，整链随
# v25.3 系统收敛移除（见 modification_registry.gd 尾部退役注）。DayClock 回归纯时间系统。

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
		_emit_day_started(current_day)
	day_phase_changed.emit(current_day, current_phase)
	phase_advanced.emit(current_day, current_phase)

## 重置为新周目（保留 total_loops）
func reset_for_new_loop() -> void:
	current_day = 1
	current_phase = PHASE_MORNING
	year_completed = false
	total_loops += 1

## 统一的 day_started 发射器
## v6.8: city_map 删除后不再镜像转发到 SignalBus（原 city_day_started 信号已移除）
func _emit_day_started(day: int) -> void:
	day_started.emit(day)

## 完全重置（新游戏）
func full_reset() -> void:
	current_day = 1
	current_phase = PHASE_MORNING
	year_completed = false
	total_loops = 0

# v25.3 产能结算段已删（_accrue_production_for_days / get_daily_production_rate /
# production_resource_override / PRODUCTION_* 常量）——见文件头退役注。

# ── 查询方法 ───────────────────────────────────────────────────────

# ── 存档 ───────────────────────────────────────────────────────────

func save_state() -> Dictionary:
	return {
		"current_day": current_day,
		"current_phase": current_phase,
		"total_loops": total_loops,
		"year_completed": year_completed,
	}

func load_state(data: Dictionary) -> void:
	# v26.6 修复：空字典 = 无存档数据（新游戏/存档缺段），必须复位到默认。
	# 此前早退导致 _reset_manager_by_name 的 load_state({}) 候选对本管理器恒空转——
	# 开新档后天数/周目数从上一档残留并写入新档。
	if data.is_empty():
		full_reset()
		return
	# 缺省键回退默认 + 基本值域钳制（手改档/截断档容错）
	current_day = clampi(int(data.get("current_day", 1)), 1, MAX_DAYS)
	current_phase = clampi(int(data.get("current_phase", 0)), 0, PHASES_PER_DAY - 1)
	total_loops = maxi(int(data.get("total_loops", 0)), 0)
	year_completed = bool(data.get("year_completed", false))
	if year_completed:
		# 已通关周目的天数必须停在最终日，避免 day<365 却 year_completed 的矛盾态
		current_day = MAX_DAYS
		current_phase = PHASES_PER_DAY - 1
