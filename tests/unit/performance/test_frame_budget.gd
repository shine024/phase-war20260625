class_name FrameBudgetTest
extends GdUnitTestSuite
## v26.11(D3): 战斗逻辑帧预算门禁——headless 跑真实战斗场景（3v3 演练场自驱），
## 逐帧采样 wall delta，断言 P95 在预算内。CI（tests.yml 跑 tests/unit 全量）自动纳入。
##
## 口径说明：headless dummy 渲染器下帧耗时 ≈ 纯逻辑成本（process+physics+脚本），
## 不含真实渲染——本门禁防的是"逻辑热路径退化"级别的回归（如批次9 F6 快速重试
## 竞态空转 CPU 120% 那类），不是渲染帧率。阈值取本机基线的 3 倍余量：
## 预算常量在 _P95_BUDGET_MS / _HARD_MS，调整前先看 print 出的实测分布。

const ARENA_SCENE := "res://scenes/tools/combat_arena_3v3.tscn"
const SAMPLE_FRAMES := 600  # 600 帧 ≈ 3v3 全程战斗的中间密度段
const WARMUP_FRAMES := 60   # 预热（首帧加载/缓存构建不计）
## P95 预算：本机实测 headless P95 约 2-5ms；40ms ≈ 25fps 逻辑预算，容忍 CI 弱机噪声
const _P95_BUDGET_MS := 40.0
## 硬上限：单帧超此值说明存在空转/死循环级退化（F6 事故家族），任何环境都该拦
const _HARD_MS := 200.0


func test_battle_logic_frame_p95_within_budget() -> void:
	var packed: PackedScene = load(ARENA_SCENE)
	if packed == null:
		print("  演练场场景缺失，跳过")
		return
	var arena: Node = packed.instantiate()
	add_child(arena)
	# 预热
	for i in range(WARMUP_FRAMES):
		await get_tree().process_frame
	# v26.11(D4): 池化评估基线——预热后（战斗已展开）采样，战斗清理后再采样对比
	var obj_peak: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var mem_peak: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	print("  [池化评估] 战斗中：objects=%d mem=%.1fMB" % [obj_peak, float(mem_peak) / 1048576.0])
	# 采样：帧间 wall delta（headless 下即逻辑成本）
	var deltas: Array[float] = []
	var worst: float = 0.0
	for i in range(SAMPLE_FRAMES):
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		var dt_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		# await process_frame 的唤醒时机含引擎空转等待，取本轮真实耗时近似帧成本
		deltas.append(dt_ms)
		worst = maxf(worst, dt_ms)
	arena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame  # 队列释放落地（queue_free 在帧末执行）
	# v26.11(D4): 池化评估采样——战斗中 vs 清理后。若清理后回落到战斗中量级
	# （对象数大幅回落），说明单位生命周期由战斗作用域管理、无跨场累积，
	# "单位池化"暂无必要（结论锚：CHANGELOG v26.12 D 节）。
	var obj_after: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var mem_after: int = Performance.get_monitor(Performance.MEMORY_STATIC)
	print("  [池化评估] 清理后：objects=%d mem=%.1fMB" % [obj_after, float(mem_after) / 1048576.0])
	# 复位本测试借用的全局战斗态——arena._setup_battle_manager 置了
	# battle_active=true 并把 battlefield 指向已释放节点；组缓存里的 freed 单位会
	# 污染后续套件的组扫描（test_drone_mark_uniform 曾因此 "freed instance" 踩空）。
	if BattleManager != null:
		BattleManager.battle_active = false
		BattleManager.battlefield = null
		if BattleManager.has_method("_clear_group_target_cache"):
			BattleManager._clear_group_target_cache()

	deltas.sort()
	var p50: float = deltas[int(deltas.size() * 0.5)]
	var p95: float = deltas[int(deltas.size() * 0.95)]
	var avg: float = 0.0
	for d in deltas:
		avg += d
	avg /= deltas.size()
	print("  帧耗时 ms：avg=%.2f p50=%.2f p95=%.2f worst=%.2f（n=%d）" % [avg, p50, p95, worst, deltas.size()])
	assert_float(p95).is_less(_P95_BUDGET_MS)
	assert_float(worst).is_less(_HARD_MS)
