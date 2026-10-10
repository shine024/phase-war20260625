extends Node
## 黑门无限模式管理器（v27）
##
## 设计文档：docs/无限模式_异族设定（草案）.md（v0.2 定案版）§5
## 职责：
##   - 黑门解锁判定（通关 100 关）
##   - 单场无限 run 的开局/结算（波次、击杀 → 分数、星髓、排行榜提交）
##   - 裂隙环境轮换（每场随机 1 条，经 BattleEnvEffects.rift_override 生效）
##   - 星髓每周封顶（呼应 game-pillars「NOT Infinite Grind」：评分挑战，非无限刷）
##
## 实例化：ManagerLazyLoader.ensure_loaded("endless")（懒加载，非战斗实时）
## 存档：SaveManager DEFERRED_MANAGER_LOADS ["/root/EndlessBlackgateManager", "endless_blackgate"]
##
## 战斗内行为不在本文件：
##   - 无尽波次推进/构成 → battle_spawn_system（_endless 分支）
##   - 永不判胜 → battle_manager._check_win_lose（endless 早退）
##   - 护盾/折跃/共感 → enemy_unit（xeno 扩展键）

const LevelEras = preload("res://data/level_eras.gd")
const XenoUnits = preload("res://data/xeno_units.gd")
const BasicResourcesData = preload("res://data/basic_resources.gd")
const LevelBattleLayoutsRef = preload("res://data/level_battle_layouts.gd")

signal run_ended(summary: Dictionary)

## v6.35 黑门 2.0:本体被击碎(通关时刻)。battle_spawn_system 击杀链转发,
## main(通关弹窗)/battle_spectacle(演出)/game_manager(出兵 gate)消费。
signal gate_core_destroyed()

## v6.35 异族渗透节点变化(大地图热区重建消费)
signal incursions_changed()

## 计分权重（设计 §5.4：score = 波次×100 + 击杀×2 + 总伤害/1000；
## v27 首发砍掉伤害项——伤害总量结算链跨帧，取波次+击杀已足够区分度，避免双结算依赖）
const SCORE_PER_WAVE: int = 100
const SCORE_PER_KILL: int = 2

## ── v6.35 黑门 2.0 数值定案（占位可微调,依据见 docs/无限模式_异族设定（草案）.md 黑门2.0节）──
## 本体深度随机区间(步进 DEPTH_STEP 取档):200-320 波,13 档。7s/波 ×~260 波 ≈ 30 分钟
## 纯刷兵 + 战斗时长,×4 倍速下一局 1-2 小时可完成。
const GATE_CORE_WAVE_MIN: int = 200
const GATE_CORE_WAVE_MAX: int = 320
const GATE_CORE_DEPTH_STEP: int = 10
## v6.42（记录6，用户拍板）：黑门不是无限模式——首场是有限波试炼：第 FIRST_GATE_CORE_WAVE 波
## 本体现身，击碎即通关黑门；通关（gate_cleared_once）后才开放无限模式（本体每场随机 200-320 波）。
const FIRST_GATE_CORE_WAVE: int = 30
## 击碎本体的首通大奖(一次性;星髓,受周封顶约束)。
## 2026-10-08 收益感批：200→300——旧值+里程碑 90 折算不足 1 小时后期流水，首通无收益感。
const GATE_FIRST_CLEAR_MARROW: int = 300
## 中途补给节点:每 25 波自动入账(不打断战斗)。
## 2026-10-08 收益感批：改为随深度递增（第 N 档 = 基准 × N）——无限深层此前与第 1 波
## 掉落完全相同（败局收场跳过整条掉落链），深层推进零梯度。
const SUPPLY_INTERVAL: int = 25
const SUPPLY_NANO: int = 1500
const SUPPLY_ENERGY: int = 200
## 异族渗透(大地图小战斗,收益很小口径)
const INCURSION_MAX: int = 3
const INCURSION_EXPIRE_DAYS: int = 3
## v6.55 记录6#16：渗透提前露脸——原实时心跳/行军遭遇双门槛=黑门解锁（通关 L100），
## 唯一无门槛入口是睡眠日刷；不常睡觉的玩家 40+ 关零星冥接触（实机主诉"没见异族关卡"）。
## 渗透编队强度锚定宿主关（make_default_context），低关宿主自动缩放，提前安全。
const INCURSION_UNLOCK_CLEARED_LEVEL: int = 25
const INCURSION_NANO: int = 800
const INCURSION_ENERGY: int = 120
const INCURSION_CAPTURE_CHANCE: float = 0.30
# v6.56 记录1#18：区域化生成口径——近锚计数半径对齐 world_map.MAP_WINDOW_RADIUS
# （±10 视野窗，窗外红点本就不可见）；锚点远后方 15 关外的陈旧点提前过期
# （玩家追不上它们，却占着 INCURSION_MAX 名额挤掉新区域红点）。
const INCURSION_NEAR_RADIUS: int = 10
const INCURSION_STALE_BEHIND: int = 15

## 渗度里程碑 → 星髓（设计 §7：按里程碑发放；每 run 累计可达里程碑之和）
const MARROW_MILESTONES: Array = [
	{"waves": 10, "marrow": 20},
	{"waves": 20, "marrow": 30},
	{"waves": 30, "marrow": 40},
	{"waves": 50, "marrow": 60},
	{"waves": 75, "marrow": 80},
	{"waves": 100, "marrow": 120},
]

## 星髓每周获取封顶（NOT Infinite Grind 支柱的落地闸门）。
## 2026-10-08 收益感批：400→500——黑门首通 300+L100 铺底 150+里程碑 90 首日可达 540，
## 封顶跟涨让首通大奖不被钳成"没感觉"（大地图"本周还可获取"文案读本常量自动跟随）。
const WEEKLY_MARROW_CAP: int = 500

## 裂隙环境键（BattleEnvEffects.RIFT_ENV_EFFECTS 同键；每场开局随机 1 条）
const RIFT_ENV_KEYS: Array[String] = ["psi_storm", "low_gravity", "rift_tide", "crystal_vein"]

## ── 存档态 ──
var best_score: int = 0
var best_waves: int = 0
var total_runs: int = 0
var _weekly_week_key: String = ""
var _weekly_marrow_gained: int = 0
## 2026-10-08 分段推进（用户拍板"一次打四五百关不太可能,一定的关数可以储存"）：
## run 进度跨场存档——中途退出/战败不丢进度,下次进场从断点波继续,免入场次数。
## 波次号全局连续（spawn 从 cp_wave+1 起）,本体波/补给节点/里程碑差价全部天然对齐。
var cp_wave: int = 0            ## 已推进到的全局波次（0=无存档进度）
var cp_core_wave: int = 0       ## 本 run 锁定的本体深度（roll 一次,续打不重摇）
var cp_rift_env: String = ""    ## 裂隙环境（跨段延续）
var cp_marrow_paid: int = 0     ## 本 run 已发星髓（段结算只补差价,防里程碑重复）
var cp_supply_granted: int = 0  ## 已发补给档数（恢复 supplies_granted 起点,防重发）
## v6.35: 黑门本体已击碎(世界状态,跨 run 持久)——通关后异族渗透停刷+清场
var gate_cleared_once: bool = false

## ── 本 run 运行态 ──
var run_active: bool = false
var current_rift_env: String = ""
## v6.35 黑门 2.0 run 态:本体深度(每 run 随机,不入档)、通关态、通关弹窗待选择、补给累计次数
var gate_core_wave: int = 0
var gate_cleared: bool = false
var gate_choice_pending: bool = false
var supplies_granted: int = 0
## 2026-10-08 收益感批：本 run 沿途补给累计（结算战报"沿途补给"行消费；begin_run 清零）
var _run_supply_nano: int = 0
var _run_supply_energy: int = 0
## v6.35: 本 run 布局池变体(LevelBattleLayouts.ENDLESS_LAYOUTS 索引;battle_manager 开战激活)
var layout_variant: int = 0

## v6.35 异族渗透节点(大地图小战斗;{host_level, seed, spawned_day})——存档段
var incursions: Array = []


func _ready() -> void:
	# v6.35: 游戏日推进 → 异族渗透刷新/过期(黑门域统一管理)
	var sb: Node = get_node_or_null("/root/SignalBus")
	if sb != null and sb.has_signal("bunker_day_ended") and not sb.bunker_day_ended.is_connected(_on_day_ended):
		sb.bunker_day_ended.connect(_on_day_ended)
	# v6.42（记录6）：渗透据点隔真实时间刷新——此前唯一驱动是 sleep() 的 bunker_day_ended，
	# 醒着多久都不刷（实机主诉"地图也应该隔时间刷新星冥敌人据点"）。懒加载管理器常驻后
	# 挂 5 分钟周期钟；黑门未通关才补刷（通关后停刷口径与 _on_day_ended 一致）。
	var tick := Timer.new()
	tick.name = "IncursionRealtimeTick"
	tick.wait_time = 300.0
	tick.autostart = true
	tick.timeout.connect(_realtime_refresh_tick)
	add_child(tick)


## v6.42: 渗透实时心跳（5 分钟/拍）——过期清理 + 未满则 50% 概率补 1 个（上限/停刷同日刷口径）
## v6.56 记录1#18：上限判据加近锚口径——可见窗内已满就不刷，身后陈旧点不再挤占预算。
func _realtime_refresh_tick() -> void:
	_expire_incursions()
	if gate_cleared_once or not incursions_unlocked():
		return
	if incursions.size() >= INCURSION_MAX or _count_incursions_near_anchor() >= INCURSION_MAX:
		return
	if randf() < 0.5:
		return
	_spawn_incursion()
	incursions_changed.emit()


## v6.55 记录6#16：渗透是否解锁——通关 INCURSION_UNLOCK_CLEARED_LEVEL（星级 > 0；
## LPM 未加载时按 GameManager 进度兜底，口径同 is_blackgate_unlocked）。
func incursions_unlocked() -> bool:
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	if lpm != null and lpm.has_method("get_level_stars"):
		return int(lpm.get_level_stars(INCURSION_UNLOCK_CLEARED_LEVEL)) > 0
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		return int(gm.get("current_level")) > INCURSION_UNLOCK_CLEARED_LEVEL
	return false


## 黑门是否解锁：第 100 关已通关（星级 > 0；LPM 未加载时按 GameManager 进度兜底）
func is_blackgate_unlocked() -> bool:
	var lpm: Node = get_node_or_null("/root/LevelProgressManager")
	if lpm != null and lpm.has_method("get_level_stars"):
		return int(lpm.get_level_stars(LevelEras.LEVEL_COUNT)) > 0
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		return int(gm.get("current_level")) > LevelEras.LEVEL_COUNT
	return false


## 开局：roll 裂隙环境、置运行态（由 GameManager.start_endless_battle 调用）。
## 2026-10-08 分段推进：有存档进度（cp_wave>0）时走续打分支——恢复锁定的本体深度/
## 裂隙环境/补给起点，**不消耗入场次数**（进度只前进，分段不产生额外收益，无滥用面）。
func begin_run() -> void:
	_run_supply_nano = 0
	_run_supply_energy = 0
	gate_cleared = false
	gate_choice_pending = false
	if cp_wave > 0 and cp_core_wave > 0:
		# ── 续打：从断点波继续 ──
		run_active = true
		gate_core_wave = cp_core_wave
		current_rift_env = cp_rift_env
		supplies_granted = cp_supply_granted
		layout_variant = randi() % maxi(1, LevelBattleLayoutsRef.get_endless_variant_count())
		return
	# ── 新 run ──
	# v32.0 B3-S3: 开局消耗一次入场次数（门禁在 GameManager.start_endless_battle）
	consume_entry_for_begin()
	run_active = true
	current_rift_env = RIFT_ENV_KEYS[randi() % RIFT_ENV_KEYS.size()]
	# v6.35 黑门 2.0: roll 本体深度(步进取档)+复位通关态+布局池变体
	# v6.42（记录6）：首场（未通关过）=固定第 FIRST_GATE_CORE_WAVE 波的本体试炼；
	# 通关后才是无限模式（每场随机 200-320 波）。
	if gate_cleared_once:
		var span: int = int((GATE_CORE_WAVE_MAX - GATE_CORE_WAVE_MIN) / float(GATE_CORE_DEPTH_STEP)) + 1
		gate_core_wave = GATE_CORE_WAVE_MIN + (randi() % span) * GATE_CORE_DEPTH_STEP
	else:
		gate_core_wave = FIRST_GATE_CORE_WAVE
	supplies_granted = 0
	layout_variant = randi() % maxi(1, LevelBattleLayoutsRef.get_endless_variant_count())
	# 深度/环境锁定进存档进度（settle_run 落账 cp_wave）
	cp_wave = 0
	cp_core_wave = gate_core_wave
	cp_rift_env = current_rift_env
	cp_marrow_paid = 0
	cp_supply_granted = 0


## 2026-10-08 分段推进：是否存在可续打的存档进度
func has_checkpoint() -> bool:
	return cp_wave > 0 and cp_core_wave > 0


## 2026-10-09 分段推进：主动放弃进度（大地图"放弃进度"按钮唯一消费口）——
## 下次 begin_run 走新 run 分支（重摇深度/环境，扣入场次数）。已入袋的星髓不追回，
## 未结算的本 run 里程碑差价随进度作废（确认框已说明）。
func abandon_checkpoint() -> void:
	_clear_checkpoint()


## 击碎本体（通关）时清进度；reset_state 同步清
func _clear_checkpoint() -> void:
	cp_wave = 0
	cp_core_wave = 0
	cp_rift_env = ""
	cp_marrow_paid = 0
	cp_supply_granted = 0


## v6.42: 当前 run 的波数上限（HUD 波次显示用；0=无限）。
## 首场试炼=FIRST_GATE_CORE_WAVE。
## 2026-10-08 分段推进：无限 run 也返回锁定的本体深度——玩家要按"打到第几波存档"
## 规划分段，无上限口径（旧拍板）在分段制下失去意义；首通前该值=30 不受影响。
func get_run_wave_limit() -> int:
	if not run_active:
		return 0
	if gate_cleared_once:
		return gate_core_wave if gate_core_wave > 0 else 0
	return FIRST_GATE_CORE_WAVE


## v6.35: 本体被击碎(battle_spawn_system 击杀链调用)。通关优先于判负——
## 驱动器被毁与本体重亡同帧时,game_manager 侧先查 gate_cleared 再走判负。
func mark_gate_cleared() -> void:
	if gate_cleared:
		return
	gate_cleared = true
	gate_choice_pending = true  # 弹窗选择前暂停出兵(game_manager 波间隔 gate)
	# 世界状态:黑门关闭——异族渗透清场+停刷
	if not incursions.is_empty():
		incursions.clear()
		incursions_changed.emit()
	gate_core_destroyed.emit()


## 通关选择收口(弹窗两键共用):继续深入=false / 携带奖励离开后由 end_battle 结算
func resolve_gate_choice() -> void:
	gate_choice_pending = false


## v6.35: 中途补给节点(每 SUPPLY_INTERVAL 波,由 battle_spawn_system 波次链调用)。
## 返回空字典=非节点波;非空=已入账 {nano, energy, count}。基础资源直入 BasicResourceManager。
## 2026-10-08 收益感批：数值随深度档递增（第 N 档 = 基准 × N）——无限深层此前与
## 第 1 波掉落完全相同，深层推进零梯度；现在第 100 波补给 = 4×基准。
func grant_supply_node(wave_index: int) -> Dictionary:
	if not run_active or gate_cleared:
		return {}
	if wave_index <= 0 or wave_index % SUPPLY_INTERVAL != 0:
		return {}
	var expected: int = int(wave_index / float(SUPPLY_INTERVAL))
	if expected <= supplies_granted:
		return {}  # 同节点波重复触发守卫(波次重试/信号重入)
	supplies_granted = expected
	var tier_mult: float = float(expected)
	var nano: int = int(SUPPLY_NANO * tier_mult)
	var energy: int = int(SUPPLY_ENERGY * tier_mult)
	_run_supply_nano += nano
	_run_supply_energy += energy
	var brm: Node = get_node_or_null("/root/BasicResourceManager")
	if brm != null and brm.has_method("add_resource"):
		brm.add_resource("basic_nano", nano)
		brm.add_resource("energy_block", energy)
	return {"nano": nano, "energy": energy, "count": supplies_granted}


## v6.35: 异族渗透——每游戏日刷新/过期(bunker_day_ended)。通关后停刷。
func _on_day_ended(_day: int = -1) -> void:
	_expire_incursions()
	if gate_cleared_once or not incursions_unlocked():
		return  # v6.55 记录6#16：与实时心跳/行军遭遇同门槛（原日刷无门槛属口径漂移）
	var spawned: int = 0
	while incursions.size() < INCURSION_MAX and _count_incursions_near_anchor() < INCURSION_MAX \
			and spawned < 2:
		if randf() < 0.5:
			break  # 每日 0-2 个(50% 概率提前收手)
		_spawn_incursion()
		spawned += 1
	if spawned > 0:
		incursions_changed.emit()


## v6.56 记录1#18：渗透生成锚——行军中锚定目的地。地图视野窗本就锚目的地
## （world_map._truck_anchor_level），生成却锚停靠关且后偏（parked−15..+5）：
## 长途行军后红点全留在身后（实机主诉"90 关不见异族红点"）。口径与地图窗对齐。
func _incursion_anchor_level() -> int:
	var bm: Node = get_node_or_null("/root/BunkerManager")
	if bm != null:
		if bm.has_method("is_traveling") and bool(bm.call("is_traveling")) \
				and bm.has_method("get_travel_dest"):
			return clampi(int(bm.call("get_travel_dest")), 1, LevelEras.LEVEL_COUNT)
		if bm.has_method("get_parked_level"):
			return clampi(int(bm.call("get_parked_level")), 1, LevelEras.LEVEL_COUNT)
	return 1


## 锚点 ±INCURSION_NEAR_RADIUS（可见窗）内的据点数——刷新预算按可见口径计。
func _count_incursions_near_anchor() -> int:
	var anchor := _incursion_anchor_level()
	var n := 0
	for inc in incursions:
		if absi(int(inc.get("host_level", 0)) - anchor) <= INCURSION_NEAR_RADIUS:
			n += 1
	return n


## 指定关卡 ±INCURSION_NEAR_RADIUS 内是否已有据点（长途到站保底判据）。
func has_incursion_near(level: int) -> bool:
	for inc in incursions:
		if absi(int(inc.get("host_level", 0)) - level) <= INCURSION_NEAR_RADIUS:
			return true
	return false


## v6.42: 追加一个渗透节点（宿主关=生成锚前偏窗 −5~+15；日刷/实时心跳共用）
func _spawn_incursion() -> void:
	# 宿主候选:锚点（行军中=目的地）前偏窗——新区域先有红点等玩家到达
	var anchor := _incursion_anchor_level()
	var lo: int = maxi(1, anchor - 5)
	var hi: int = mini(LevelEras.LEVEL_COUNT, anchor + 15)
	if hi < lo:
		return
	incursions.append({
		"host_level": randi_range(lo, hi),
		"seed": randi(),
		"spawned_day": _current_day(),
	})


## v6.42: 渗透剩余过期天数（大地图 tooltip 消费；宪法 C3 口径随 INCURSION_EXPIRE_DAYS 常量走）
func get_incursion_days_left(inc: Dictionary) -> int:
	return maxi(0, INCURSION_EXPIRE_DAYS - (_current_day() - int(inc.get("spawned_day", 0))))


## v6.42: 行军遭遇——在指定关追加一个渗透节点（宿主=到站关；BunkerManager 到站掷点消费）。
## 条件不满足（已通关/未解锁/已达上限/非法关卡）返回 false，调用方静默跳过。
func spawn_incursion_at(host_level: int) -> bool:
	if gate_cleared_once or not incursions_unlocked():
		return false
	if incursions.size() >= INCURSION_MAX:
		return false
	if host_level < 1 or host_level > LevelEras.LEVEL_COUNT:
		return false
	incursions.append({
		"host_level": host_level,
		"seed": randi(),
		"spawned_day": _current_day(),
	})
	incursions_changed.emit()
	return true


func _current_day() -> int:
	var bm: Node = get_node_or_null("/root/BunkerManager")
	if bm != null and bm.has_method("get_day"):
		return int(bm.get_day())
	return 0


func _expire_incursions() -> void:
	var today: int = _current_day()
	var anchor := _incursion_anchor_level()
	var kept: Array = []
	var changed: bool = false
	for inc in incursions:
		var day_ok: bool = today - int(inc.get("spawned_day", 0)) < INCURSION_EXPIRE_DAYS
		# v6.56 记录1#18：锚点远后方（>INCURSION_STALE_BEHIND）的陈旧点提前过期——
		# 已在视野窗外且玩家只向前推进，留着只占名额
		var far_behind: bool = int(inc.get("host_level", 0)) < anchor - INCURSION_STALE_BEHIND
		if day_ok and not far_behind:
			kept.append(inc)
		else:
			changed = true
	if changed:
		incursions = kept
		incursions_changed.emit()


## 渗透编队推导(seed 确定性):3-5 只基础 + 1 精英。
func get_incursion_loadout(inc: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(inc.get("seed", 0))
	var basic: Array[String] = get_role_pool("basic")
	var elite: Array[String] = get_role_pool("elite") + get_role_pool("ace")
	var ids: Array[String] = []
	var count: int = 3 + rng.randi() % 3
	for _i in range(count):
		ids.append(basic[rng.randi() % basic.size()])
	if not elite.is_empty():
		ids.append(elite[rng.randi() % elite.size()])
	return {"ids": ids, "host_level": int(inc.get("host_level", 1))}


func get_role_pool(role: String) -> Array[String]:
	var out: Array[String] = []
	for id in XenoUnits.get_ids():
		if String(XenoUnits.UNITS[id].get("role", "")) == role:
			out.append(id)
	return out


## v6.35: 移除一个渗透节点(战斗结算胜/败都移除;按 host_level+seed 匹配)
func erase_incursion(inc: Dictionary) -> void:
	var before: int = incursions.size()
	incursions = incursions.filter(func(e: Dictionary) -> bool:
		return int(e.get("host_level", -1)) != int(inc.get("host_level", -2)) \
			or int(e.get("seed", -1)) != int(inc.get("seed", -2)))
	if incursions.size() != before:
		incursions_changed.emit()


## 结算：分数/星髓/排行榜。返回摘要字典（面板/Toast 消费）。
## waves = 存活波次（驱动器被毁时已推进的波数），kills = 本场击杀数。
func settle_run(waves: int, kills: int) -> Dictionary:
	run_active = false
	var env: String = current_rift_env
	current_rift_env = ""
	total_runs += 1

	var score: int = waves * SCORE_PER_WAVE + kills * SCORE_PER_KILL
	# 2026-10-08 分段推进：星髓按"本 run 累计应得 − 已付"补差价——
	# 里程碑表按全局波次算，分段多次结算不会重复发同档（cp_marrow_paid 随存档持久化）。
	var marrow_full: int = maxi(0, marrow_for_waves(waves) - cp_marrow_paid)
	# v6.35: 击碎本体首通大奖(一次性;与里程碑星髓同吃周封顶)
	var gate_first_clear: bool = gate_cleared and not gate_cleared_once
	if gate_first_clear:
		marrow_full += GATE_FIRST_CLEAR_MARROW
		gate_cleared_once = true
	var marrow: int = mini(marrow_full, weekly_marrow_remaining())
	var capped: bool = marrow < marrow_full
	if marrow > 0:
		_add_marrow(marrow)
	if not gate_cleared:
		# 只把实发数记入已付——被周封顶钳掉的差额保留,后续段/周内补领
		cp_marrow_paid += marrow

	var is_best: bool = score > best_score
	if is_best:
		best_score = score
	if waves > best_waves:
		best_waves = waves

	# 排行榜（survival_highscore = 挑战类·周重置，零改动复用）
	var lb: Node = get_node_or_null("/root/LeaderboardManager")
	if lb != null and lb.has_method("submit_score"):
		lb.submit_score("survival_highscore", float(score), {
			"waves": waves, "kills": kills, "rift_env": env,
		})
		if lb.has_method("update_battle_stats"):
			# survival_best 玩家统计同链推进（update_level_progress 不适用无尽模式）
			lb.call("update_battle_stats", false, 0, 0.0)

	var summary: Dictionary = {
		"waves": waves,
		"kills": kills,
		"score": score,
		"marrow": marrow,
		"marrow_capped": capped,
		"is_best": is_best,
		"best_score": best_score,
		"best_waves": best_waves,
		"rift_env": env,
		# v6.35 黑门 2.0 战报字段(结算面板消费)
		"gate_cleared": gate_cleared,
		"gate_core_wave": gate_core_wave,
		"gate_first_clear": gate_first_clear,
		"supplies_granted": supplies_granted,
		"supply_nano": _run_supply_nano,
		"supply_energy": _run_supply_energy,
	}
	# 2026-10-08 分段推进：未通关=进度落账(下次进场续打,免入场)；通关=清进度
	if gate_cleared:
		_clear_checkpoint()
		summary["checkpoint_saved"] = false
	else:
		if waves > cp_wave:
			cp_wave = waves
		cp_core_wave = gate_core_wave
		cp_rift_env = env
		cp_supply_granted = supplies_granted
		summary["checkpoint_saved"] = cp_wave > 0
		summary["checkpoint_wave"] = cp_wave
		summary["checkpoint_core_wave"] = cp_core_wave
	gate_cleared = false
	gate_choice_pending = false
	run_ended.emit(summary)
	return summary


## 渗度（每 10 波 +1，设计 §5.3）
static func depth_for_waves(waves: int) -> int:
	return clampi(int(waves / 10.0), 0, 5)


## 里程碑星髓（累计可达里程碑之和）
static func marrow_for_waves(waves: int) -> int:
	var total: int = 0
	for m in MARROW_MILESTONES:
		if waves >= int(m["waves"]):
			total += int(m["marrow"])
	return total


## 本周剩余可获取星髓
func weekly_marrow_remaining() -> int:
	_rollover_week_if_needed()
	return maxi(0, WEEKLY_MARROW_CAP - _weekly_marrow_gained)


## 周键（周一为界的单调周序；封顶窗口只需"每周变一次"，不要求 ISO 年-周严格对应）
func _week_key() -> String:
	var days: int = int(Time.get_unix_time_from_system() / 86400.0)
	# 1970-01-01 是周四；+3 后整除 7 → 周一为界的周序（跨年单调递增，周界正确）
	var week_index: int = (days + 3) / 7
	return "W%d" % week_index


func _rollover_week_if_needed() -> void:
	var wk: String = _week_key()
	if wk != _weekly_week_key:
		_weekly_week_key = wk
		_weekly_marrow_gained = 0


func _add_marrow(amount: int) -> void:
	if amount <= 0:
		return
	_rollover_week_if_needed()
	_weekly_marrow_gained += amount
	var brm: Node = get_node_or_null("/root/BasicResourceManager")
	if brm != null and brm.has_method("add_resource"):
		brm.add_resource(BasicResourcesData.ID_STAR_MARROW, amount)


# ── v32.0 B3-S3: 黑门入场软门（免费 3 次/日 + 能量块购额外次数；用户拍板 2026-09-14）──
## 占位价：能量块 60/次——TODO(B3数值轮) 校准。日界=真实日期（与周星髓 _week_key 同口径）。
## 语义：仅开局计数，进行中的 run 不受影响；购买次数永久有效直到使用。
const FREE_ENTRIES_PER_DAY := 3
const ENERGY_PER_EXTRA_ENTRY := 60
var _entries_used_day_key: String = ""
var _entries_used_today: int = 0
var _extra_entries: int = 0

func _day_key() -> String:
	return "D%d" % int(Time.get_unix_time_from_system() / 86400.0)

func _rollover_day_if_needed() -> void:
	var dk: String = _day_key()
	if dk != _entries_used_day_key:
		_entries_used_day_key = dk
		_entries_used_today = 0

func get_entry_status() -> Dictionary:
	_rollover_day_if_needed()
	var free_left := maxi(0, FREE_ENTRIES_PER_DAY - _entries_used_today)
	return {free_left = free_left, extra_left = _extra_entries,
		can_enter = free_left > 0 or _extra_entries > 0}

func can_begin_run() -> bool:
	return bool(get_entry_status()["can_enter"])

func consume_entry_for_begin() -> bool:
	_rollover_day_if_needed()
	if _entries_used_today < FREE_ENTRIES_PER_DAY:
		_entries_used_today += 1
		return true
	if _extra_entries > 0:
		_extra_entries -= 1
		return true
	return false

func buy_extra_entry_with_energy(times: int = 1) -> Dictionary:
	var n := clampi(times, 1, 3)
	var price := n * ENERGY_PER_EXTRA_ENTRY
	var brm: Node = get_node_or_null("/root/BasicResourceManager")
	if brm == null:
		return {ok = false, reason = "资源管理器未就绪"}
	if not brm.can_afford(BasicResourcesData.ID_ENERGY_BLOCK, price):
		return {ok = false, reason = "能量块不足（需 %d）" % price}
	# 2026-09-19：spend_resource 方法不存在（原靠 has_method 兜底），统一走 consume
	brm.consume(BasicResourcesData.ID_ENERGY_BLOCK, price)
	_extra_entries += n
	return {ok = true, bought = n, energy_spent = price, extra_left = _extra_entries}

# ───────────────────── 存档（SaveManager deferred） ─────────────────────


func save_state() -> Dictionary:
	return {
		"best_score": best_score,
		"best_waves": best_waves,
		"total_runs": total_runs,
		"weekly_week_key": _weekly_week_key,
		"weekly_marrow_gained": _weekly_marrow_gained,
		"entries_used_day_key": _entries_used_day_key,
		"entries_used_today": _entries_used_today,
		"extra_entries": _extra_entries,
		# v6.35 黑门 2.0
		"gate_cleared_once": gate_cleared_once,
		"incursions": incursions.duplicate(true),
		# 2026-10-08 分段推进:run 进度存档(旧档缺键=无进度,免迁移)
		"cp_wave": cp_wave,
		"cp_core_wave": cp_core_wave,
		"cp_rift_env": cp_rift_env,
		"cp_marrow_paid": cp_marrow_paid,
		"cp_supply_granted": cp_supply_granted,
	}


func load_state(data: Dictionary) -> void:
	if data == null or data.is_empty():
		return
	best_score = int(data.get("best_score", 0))
	best_waves = int(data.get("best_waves", 0))
	total_runs = int(data.get("total_runs", 0))
	_weekly_week_key = String(data.get("weekly_week_key", ""))
	_weekly_marrow_gained = int(data.get("weekly_marrow_gained", 0))
	# v32.0 B3-S3: 日次限惰性键（旧档缺键=当日未用+无购次，免迁移）
	_entries_used_day_key = String(data.get("entries_used_day_key", ""))
	_entries_used_today = int(data.get("entries_used_today", 0))
	_extra_entries = int(data.get("extra_entries", 0))
	# v6.35 黑门 2.0(旧档缺键=未通关+无渗透,免迁移)
	gate_cleared_once = bool(data.get("gate_cleared_once", false))
	var inc_var: Variant = data.get("incursions", [])
	incursions = (inc_var as Array).duplicate(true) if inc_var is Array else []
	# 2026-10-08 分段推进(旧档缺键=无进度,免迁移)
	cp_wave = int(data.get("cp_wave", 0))
	cp_core_wave = int(data.get("cp_core_wave", 0))
	cp_rift_env = String(data.get("cp_rift_env", ""))
	cp_marrow_paid = int(data.get("cp_marrow_paid", 0))
	cp_supply_granted = int(data.get("cp_supply_granted", 0))


func reset_state() -> void:
	best_score = 0
	best_waves = 0
	total_runs = 0
	_weekly_week_key = ""
	_weekly_marrow_gained = 0
	_entries_used_day_key = ""
	_entries_used_today = 0
	_extra_entries = 0
	run_active = false
	current_rift_env = ""
	gate_cleared_once = false
	gate_core_wave = 0
	gate_cleared = false
	gate_choice_pending = false
	supplies_granted = 0
	incursions = []
	_clear_checkpoint()
