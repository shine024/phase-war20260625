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

# ══ v21 P3-B（计划 C1）：离线产能积累 ══
## 每跨 1 天结算一次产能点，汇入 BasicResourceManager（改造打造的消耗货币之一）。
## 数值公式（v21 P3-B 定版）：
##   每日产能 = PRODUCTION_PER_DAY_BASE × (1 + 0.25 × (档位 - 1))
##   档位 = EnemyLoadoutTiers.get_tier_for_level_progress(时代内进度)（与 P3-A 敌方配装同源）
##   → 低配档(×1.30) 30 点/天；中配档(×1.75) 38 点/天；高配档(×2.00) 45 点/天。
##   设计意图：玩家推进越深（时代内后期），产能越高，打造高档改造的等待天数越短；
##   与敌方难度台阶共用同一档位轴，难度与收益同源不脱节。
## 累积上限 PRODUCTION_POINTS_CAP：防挂机无限屯点（约 22~33 天的自然上限）。
const PRODUCTION_PER_DAY_BASE: int = 30
const PRODUCTION_POINTS_CAP: int = 999

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
		_accrue_production_for_days(1)  # v21 P3-B: 每跨 1 天结算产能
		_emit_day_started(current_day)
	day_phase_changed.emit(current_day, current_phase)
	phase_advanced.emit(current_day, current_phase)

## 快进到指定天数（用于跳过空闲期，如"休息到第30天"）
func advance_to_day(target_day: int) -> void:
	target_day = clampi(target_day, current_day, MAX_DAYS)
	if target_day <= current_day:
		return
	var crossed_days: int = target_day - current_day
	current_day = target_day
	current_phase = PHASE_MORNING
	_accrue_production_for_days(crossed_days)  # v21 P3-B: 快进 N 天补 N 天产能
	_emit_day_started(current_day)
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
	_accrue_production_for_days(1)  # v21 P3-B: 每跨 1 天结算产能
	_emit_day_started(current_day)
	day_phase_changed.emit(current_day, current_phase)

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

# ── v21 P3-B（计划 C1）：产能结算 ──────────────────────────────────

## v21 P3-B: 资源管理器注入点（可选）——smoke/测试等 --script 模式下 autoload 未注册，
## 由调用方传入持有 add_production_points 的节点；游戏内保持 null 走 get_node_or_null 常规路径。
var production_resource_override: Node = null

## 按"每日产能"公式为跨过的天数结算产能点，汇入 BasicResourceManager。
## 关卡 id 取 GameManager.current_level（拿不到时按 1 = 低配档 30 点/天，headless/标题屏安全）。
## 走 get_node_or_null 而非裸 autoload 标识：--script 模式（smoke 测试）下 autoload 未注册也不崩。
func _accrue_production_for_days(days: int) -> void:
	if days <= 0:
		return
	var brm: Node = production_resource_override
	if brm == null and is_inside_tree():
		# is_inside_tree 守卫：--script 模式 _initialize 阶段节点在活跃场景树外，
		# 绝对路径 get_node 会刷 ERROR（返回 null 等价，但污染 headless 日志）
		brm = get_node_or_null("/root/BasicResourceManager")
	if brm == null or not brm.has_method("add_production_points"):
		return
	var level: int = 1
	if is_inside_tree():
		# 同上：活跃场景树外跳过路径解析，按低配档默认结算
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and "current_level" in gm:
			level = maxi(1, int(gm.get("current_level")))
	var era_local_level: int = ((level - 1) % 20) + 1
	var era_progress: float = float(era_local_level - 1) / 19.0
	# 档位与 P3-A 敌方配装同源（低配/中配/高配）
	var _ELT = load("res://data/enemy_loadout_tiers.gd")
	var tier: int = 1
	if _ELT != null:
		tier = int(_ELT.get_tier_for_level_progress(era_progress, false))
	var per_day: float = float(PRODUCTION_PER_DAY_BASE) * (1.0 + 0.25 * float(tier - 1))
	brm.add_production_points(int(round(per_day * float(days))))

## v21 P3-B: 查询当前每日产能（UI 展示用；同公式）
func get_daily_production_rate() -> int:
	var level: int = 1
	if is_inside_tree():
		# 同上：活跃场景树外的 --script 模式跳过路径解析（拿不到 GameManager 按低配档 30）
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm != null and "current_level" in gm:
			level = maxi(1, int(gm.get("current_level")))
	var era_local_level: int = ((level - 1) % 20) + 1
	var era_progress: float = float(era_local_level - 1) / 19.0
	var _ELT = load("res://data/enemy_loadout_tiers.gd")
	var tier: int = 1
	if _ELT != null:
		tier = int(_ELT.get_tier_for_level_progress(era_progress, false))
	return int(round(float(PRODUCTION_PER_DAY_BASE) * (1.0 + 0.25 * float(tier - 1))))

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
