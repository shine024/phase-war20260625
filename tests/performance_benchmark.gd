extends Node
## 性能基准测试工具
## 用于测量优化前后的性能差异

## 测试场景
enum TestScenario {
	BATTLE_10_UNITS,      # 10个单位战斗
	BATTLE_50_UNITS,      # 50个单位战斗
	HEAVY_EFFECTS,        # 大量特效
	LONG_SESSION,         # 长时间游戏
	MEMORY_ALLOCATION,    # 内存分配测试
	SCENE_LOADING         # 场景加载测试
}

## 基准数据
var _benchmark_results: Dictionary = {}
var _is_running: bool = false
var _current_scenario: TestScenario = TestScenario.BATTLE_10_UNITS
var _test_start_time: float = 0.0
var _test_frames: int = 0

## 性能监控
var _fps_samples: Array = []
var _memory_samples: Array = []
var _gc_samples: Array = []
var _node_count_samples: Array = []

## 信号
signal benchmark_completed(results: Dictionary)
signal benchmark_progress(progress: float, message: String)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## 开始基准测试
func start_benchmark(scenario: TestScenario) -> void:
	if _is_running:
		push_warning("[Benchmark] 测试已在运行中")
		return

	_current_scenario = scenario
	_is_running = true
	_test_start_time = Time.get_ticks_msec()
	_test_frames = 0

	# 清空之前的数据
	_fps_samples.clear()
	_memory_samples.clear()
	_gc_samples.clear()
	_node_count_samples.clear()

	print("[Benchmark] 开始测试场景: ", TestScenario.keys()[scenario])

	match scenario:
		TestScenario.BATTLE_10_UNITS:
			_run_battle_test(10)
		TestScenario.BATTLE_50_UNITS:
			_run_battle_test(50)
		TestScenario.HEAVY_EFFECTS:
			_run_effects_test()
		TestScenario.LONG_SESSION:
			_run_long_session_test()
		TestScenario.MEMORY_ALLOCATION:
			_run_memory_test()
		TestScenario.SCENE_LOADING:
			_run_scene_loading_test()

## 运行战斗测试
func _run_battle_test(unit_count: int) -> void:
	print("[Benchmark] 战斗测试 - 单位数量: ", unit_count)

	# TODO: 创建测试场景
	# 1. 生成指定数量的单位
	# 2. 记录初始性能数据
	# 3. 运行30秒
	# 4. 记录性能数据

	benchmark_progress.emit(0.0, "准备战斗场景...")

	# 模拟测试
	await get_tree().create_timer(1.0).timeout
	benchmark_progress.emit(0.5, "运行战斗测试...")
	await get_tree().create_timer(1.0).timeout
	benchmark_progress.emit(1.0, "完成战斗测试")

	_complete_test()

## 运行特效测试
func _run_effects_test() -> void:
	print("[Benchmark] 特效测试")

	benchmark_progress.emit(0.0, "准备特效场景...")
	await get_tree().create_timer(0.5).timeout

	benchmark_progress.emit(0.5, "生成大量特效...")
	# TODO: 生成100次爆炸效果

	await get_tree().create_timer(1.0).timeout
	benchmark_progress.emit(1.0, "完成特效测试")

	_complete_test()

## 运行长时间测试
func _run_long_session_test() -> void:
	print("[Benchmark] 长时间测试 (30秒)")

	benchmark_progress.emit(0.0, "开始长时间测试...")

	for i in range(30):
		await get_tree().process_frame
		_capture_performance_sample()
		var progress = float(i) / 30.0
		benchmark_progress.emit(progress, "长时间测试... %d%%" % [progress * 100])

	benchmark_progress.emit(1.0, "完成长时间测试")
	_complete_test()

## 运行内存测试
func _run_memory_test() -> void:
	print("[Benchmark] 内存分配测试")

	benchmark_progress.emit(0.0, "测试内存分配...")
	await get_tree().create_timer(1.0).timeout

	# TODO: 创建和销毁大量对象
	# 测试对象池效率

	benchmark_progress.emit(1.0, "完成内存测试")
	_complete_test()

## 运行场景加载测试
func _run_scene_loading_test() -> void:
	print("[Benchmark] 场景加载测试")

	benchmark_progress.emit(0.0, "测试场景加载...")

	var start_time = Time.get_ticks_msec()
	# TODO: 加载和卸载场景10次
	for i in range(10):
		# 模拟场景加载
		await get_tree().process_frame

	var end_time = Time.get_ticks_msec()
	var load_time = end_time - start_time

	_benchmark_results["scene_load_time"] = load_time
	benchmark_progress.emit(1.0, "完成场景加载测试")

	_complete_test()

## 完成测试
func _complete_test() -> void:
	_is_running = false

	var test_duration = (Time.get_ticks_msec() - _test_start_time) / 1000.0

	# 计算统计结果
	var results = {
		"scenario": TestScenario.keys()[_current_scenario],
		"duration": test_duration,
		"frames": _test_frames,
		"avg_fps": _calculate_average(_fps_samples),
		"min_fps": _calculate_min(_fps_samples),
		"max_fps": _calculate_max(_fps_samples),
		"avg_memory_mb": _calculate_average(_memory_samples) / 1024 / 1024,
		"avg_gc_count": _calculate_average(_gc_samples),
		"avg_node_count": _calculate_average(_node_count_samples),
	}

	_benchmark_results[TestScenario.keys()[_current_scenario]] = results

	print("[Benchmark] 测试完成")
	print("[Benchmark] 平均FPS: ", results.avg_fps)
	print("[Benchmark] 平均内存: ", results.avg_memory_mb, " MB")

	benchmark_completed.emit(results)

## 捕获性能样本
func _capture_performance_sample() -> void:
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var memory = Performance.get_monitor(Performance.MEMORY_STATIC)
	var gc = Performance.get_monitor(Performance.GC_COUNT)
	var node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

	_fps_samples.append(fps)
	_memory_samples.append(memory)
	_gc_samples.append(gc)
	_node_count_samples.append(node_count)

## 计算平均值
func _calculate_average(samples: Array) -> float:
	if samples.is_empty():
		return 0.0

	var total = 0.0
	for s in samples:
		total += float(s)
	return total / samples.size()

## 计算最小值
func _calculate_min(samples: Array) -> float:
	if samples.is_empty():
		return 0.0

	var min_val = float(samples[0])
	for s in samples:
		var val = float(s)
		if val < min_val:
			min_val = val
	return min_val

## 计算最大值
func _calculate_max(samples: Array) -> float:
	if samples.is_empty():
		return 0.0

	var max_val = float(samples[0])
	for s in samples:
		var val = float(s)
		if val > max_val:
			max_val = val
	return max_val

## 获取基准测试结果
func get_results() -> Dictionary:
	return _benchmark_results

## 导出结果为JSON
func export_results_json() -> String:
	return JSON.stringify(_benchmark_results, "\t")

## 显示当前性能
func show_current_performance() -> void:
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var memory = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024 / 1024
	var gc = Performance.get_monitor(Performance.GC_COUNT)
	var node_count = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

	print("=== 当前性能 ===")
	print("FPS: ", fps)
	print("内存: ", memory, " MB")
	print("GC次数: ", gc)
	print("节点数量: ", node_count)
	print("================")

## 在_process中定期采样
func _process(delta: float) -> void:
	if _is_running:
		_test_frames += 1
		# 每10帧采样一次
		if _test_frames % 10 == 0:
			_capture_performance_sample()
