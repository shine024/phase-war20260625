extends SceneTree
## ═══════════════════════════════════════════════════════════
##  v9 性能批次 smoke test
##  1. SpatialGrid.query_nearest_target 环形扩张重写 vs 暴力扫描对拍（含提前退出正确性）
##  2. sanitize_save_variant 条件重建（干净数据原样返回 / 污染数据正确清洗）
##  运行：Godot --headless --script tests/v9_perf_smoke.gd
## ═══════════════════════════════════════════════════════════

const SpatialGrid = preload("res://scripts/spatial_grid.gd")
const SaveMigration = preload("res://scripts/systems/save_migration.gd")

## 对拍用假单位（query_nearest_target 检查 "is_player" 属性）
const FakeUnit = preload("res://tests/v9_perf_fake_unit.gd")

var _pass: int = 0
var _fail: int = 0

func _init() -> void:
	print("=== v9 perf smoke（环形索敌对拍 + 存档清洗）===")
	_test_ring_query_vs_bruteforce()
	_test_ring_query_edges()
	_test_sanitize_conditional()
	print("\n=== 结果: %d PASS / %d FAIL ===" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)

## 随机布局对拍：环形扩张查询结果必须与暴力扫描一致（距离平方相等或同为 null）
func _test_ring_query_vs_bruteforce() -> void:
	print("\n[1] 环形索敌 vs 暴力扫描（200 次随机布局 × 5 查询点）")
	var grid: Node = SpatialGrid.new()
	root.add_child(grid)
	grid.setup(100.0, 0.0, 4000.0, 0.0, 4000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260816
	var mismatches: int = 0
	for trial in range(200):
		# 清场重插（模拟不同战场）
		for child in grid.get_children():
			child.queue_free()
		grid.clear()
		var units: Array = []
		var n: int = rng.randi_range(0, 30)
		for i in range(n):
			var u: Node2D = FakeUnit.new()
			u.is_player = rng.randf() < 0.5
			u.position = Vector2(rng.randf_range(0.0, 4000.0), rng.randf_range(0.0, 4000.0))
			units.append(u)
			root.add_child(u)
			grid.insert(u)
		for q in range(5):
			var qpos := Vector2(rng.randf_range(0.0, 4000.0), rng.randf_range(0.0, 4000.0))
			var want_player: bool = rng.randf() < 0.5
			var radius: float = [1600.0, 250.0, 700.0, 1089.0][rng.randi_range(0, 3)]
			var got: Node2D = grid.query_nearest_target(qpos, want_player, radius)
			var want: Node2D = _brute_nearest(units, qpos, want_player, radius)
			var got_d: float = (got.global_position.distance_squared_to(qpos)) if got != null else -1.0
			var want_d: float = (want.global_position.distance_squared_to(qpos)) if want != null else -1.0
			# 距离相等即通过（同距离不同单位可接受）
			if absf(got_d - want_d) > 0.001:
				mismatches += 1
		for u in units:
			u.queue_free()
	_ok(mismatches == 0, "1000 次随机查询全部与暴力扫描一致" if mismatches == 0 else "不一致 %d 次" % mismatches)

## 边界用例：空场 / 只有同阵营 / 恰好在半径边缘
func _test_ring_query_edges() -> void:
	print("\n[2] 环形索敌边界用例")
	var grid: Node = SpatialGrid.new()
	root.add_child(grid)
	grid.setup(100.0, 0.0, 4000.0, 0.0, 4000.0)
	# 空场
	var r0: Node2D = grid.query_nearest_target(Vector2(500, 500), false, 1600.0)
	_ok(r0 == null, "空场返回 null")
	# 只有同阵营（查敌方视角 is_player=false 时只返回玩家单位）
	var same: Node2D = FakeUnit.new()
	same.is_player = false
	same.position = Vector2(500, 500)
	root.add_child(same)
	grid.insert(same)
	var r1: Node2D = grid.query_nearest_target(Vector2(520, 520), false, 1600.0)
	_ok(r1 == null, "只有同阵营单位时返回 null")
	# 恰好在半径边缘（r=300：一个 299.9 命中，一个 300.1 不命中）
	var near: Node2D = FakeUnit.new()
	near.is_player = true
	near.position = Vector2(800 - 0.1, 0)  # 距原点 299.9... 用一维布局
	near.position = Vector2(299.9, 0.0)
	var far: Node2D = FakeUnit.new()
	far.is_player = true
	far.position = Vector2(300.1, 0.0)
	root.add_child(near)
	root.add_child(far)
	grid.insert(near)
	grid.insert(far)
	var r2: Node2D = grid.query_nearest_target(Vector2.ZERO, false, 300.0)
	_ok(r2 == near, "半径边缘：299.9 命中、300.1 排除")
	# 远距目标：1600 半径，目标在 1500 处（先移除近处单位，专测多环扩张无早退路径）
	grid.remove(near)
	grid.remove(far)
	var far_target: Node2D = FakeUnit.new()
	far_target.is_player = true
	far_target.position = Vector2(1500.0, 0.0)
	root.add_child(far_target)
	grid.insert(far_target)
	var r3: Node2D = grid.query_nearest_target(Vector2.ZERO, false, 1600.0)
	_ok(r3 == far_target, "1600 半径命中 1500 处目标（15 环扩张）")
	for u in [same, far_target]:
		u.queue_free()

## sanitize 条件重建：干净原样 / 污染清洗
func _test_sanitize_conditional() -> void:
	print("\n[3] sanitize_save_variant 条件重建")
	var clean: Dictionary = {"a": 1, "b": [1.5, 2.5, {"c": "txt"}], "d": {"e": [true, null, 3]}}
	var out_clean: Variant = SaveMigration.sanitize_save_variant(clean)
	_ok(out_clean == clean, "干净数据清洗后等值")
	var dirty: Dictionary = {"a": 1.0, "b": [1.5, INF, {"c": NAN}]}
	var out_dirty: Variant = SaveMigration.sanitize_save_variant(dirty)
	var od: Dictionary = out_dirty
	_ok(out_dirty is Dictionary and is_finite(float(od["a"])) and float((od["b"] as Array)[1]) == 0.0
			and is_finite(float((od["b"] as Array)[2]["c"])), "污染数据 inf/nan 清洗为 0")
	# 检测函数本身
	_ok(!SaveMigration._has_invalid_float(clean), "_has_invalid_float 干净=false")
	_ok(SaveMigration._has_invalid_float(dirty), "_has_invalid_float 污染=true")

# ─────────────────────────────────────────────
func _brute_nearest(units: Array, qpos: Vector2, want_player: bool, radius: float) -> Node2D:
	var best: Node2D = null
	var best_d2: float = radius * radius
	for u in units:
		if u == null or not is_instance_valid(u):
			continue
		# 网格语义：返回与参数阵营【相反】的最近单位（is_player 参数是"中心方是否玩家"）
		if bool(u.is_player) == want_player:
			continue
		var d2: float = (u as Node2D).global_position.distance_squared_to(qpos)
		if d2 < best_d2:
			best_d2 = d2
			best = u
	return best

func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("  ✓ %s" % msg)
	else:
		_fail += 1
		print("  ✗ %s" % msg)

func _bad(msg: String) -> void:
	_fail += 1
	print("  ✗ %s" % msg)
