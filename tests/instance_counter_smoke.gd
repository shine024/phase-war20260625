extends SceneTree
## Smoke test：验证 InstanceRegistry _counter 重建 + 防撞号修复
##
## 模拟存档缺 _counter 字段时加载实例，再 create_instance 是否撞号。
## 运行：
##   Godot --headless --script tests/instance_counter_smoke.gd

var _pass_count := 0
var _fail_count := 0

func _init():
	print("=== InstanceRegistry counter reconcile smoke ===")

	_test_reconcile_from_instances_no_counter_field()
	_test_reconcile_max_merge_with_existing_counter()
	_test_allocate_no_collision_after_load()
	_test_allocate_defensive_increment()
	_test_idempotent_reconcile()

	print("\n=== Results: %d PASS, %d FAIL ===" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)


## 场景1：存档完全缺 _counter 字段，load_state 后 _counter 应从实例重建
func _test_reconcile_from_instances_no_counter_field() -> void:
	var ir = _new_registry()
	# 模拟存档：有实例但无 _counter 键（早期/迁移期存档的典型状态）
	var save_data := {
		"fake_card#1": {"card_id": "fake_card", "enhance_level": 5},
		"fake_card#2": {"card_id": "fake_card", "enhance_level": 0},
		"other_card#3": {"card_id": "other_card", "enhance_level": 0},
	}
	# load_state 会调 DefaultCards.clone_for_instance，模板找不到则跳过 + push_error。
	# 这里不依赖真实模板，直接手工填 _instances 模拟加载结果，再调 reconcile。
	ir._instances = {
		"fake_card#1": _dummy_card("fake_card#1"),
		"fake_card#2": _dummy_card("fake_card#2"),
		"other_card#3": _dummy_card("other_card#3"),
	}
	ir._counter.clear()  # 模拟缺 _counter 字段
	ir._reconcile_counter_from_instances()

	_check(ir._counter.get("fake_card", 0) == 2, "reconcile: fake_card counter should be 2, got %d" % ir._counter.get("fake_card", 0))
	_check(ir._counter.get("other_card", 0) == 3, "reconcile: other_card counter should be 3, got %d" % ir._counter.get("other_card", 0))


## 场景2：存档有 _counter 但落后于实例表（手工写入过实例），max 合并应抬升计数器
func _test_reconcile_max_merge_with_existing_counter() -> void:
	var ir = _new_registry()
	ir._instances = {
		"card_x#5": _dummy_card("card_x#5"),
	}
	ir._counter = {"card_x": 2}  # 计数器落后于实例（实例已到 #5）
	ir._reconcile_counter_from_instances()

	_check(ir._counter.get("card_x", 0) == 5, "max merge: card_x counter should be 5, got %d" % ir._counter.get("card_x", 0))


## 场景3：load_state 后 create_instance 不应撞号（核心 bug 场景）
func _test_allocate_no_collision_after_load() -> void:
	var ir = _new_registry()
	ir._instances = {
		"heavymech#1": _dummy_card("heavymech#1"),
	}
	ir._counter.clear()
	ir._reconcile_counter_from_instances()
	# 现在 _counter[heavymech]=1，分配下一个应该是 #2 而非 #1
	var new_id: String = ir._allocate_instance_id("heavymech")
	_check(new_id == "heavymech#2", "no collision: next id should be heavymech#2, got %s" % new_id)


## 场景4：防御层——_counter 丢失但 reconcile 没跑（极端），allocate 仍不覆盖已有实例
func _test_allocate_defensive_increment() -> void:
	var ir = _new_registry()
	ir._instances = {
		"defcard#1": _dummy_card("defcard#1"),
	}
	ir._counter.clear()  # 故意不 reconcile，模拟最坏情况
	# _allocate_instance_id 应递增跳过已存在的 #1
	var new_id: String = ir._allocate_instance_id("defcard")
	_check(new_id == "defcard#2", "defensive: should skip #1 to %s" % new_id)
	_check(not ir._instances.has(new_id), "defensive: new id %s must not already exist" % new_id)


## 场景5：reconcile 幂等（重复调用无副作用，计数器只升不降）
func _test_idempotent_reconcile() -> void:
	var ir = _new_registry()
	ir._instances = {
		"idem#7": _dummy_card("idem#7"),
	}
	ir._reconcile_counter_from_instances()
	var c1 := int(ir._counter.get("idem", 0))
	ir._reconcile_counter_from_instances()
	var c2 := int(ir._counter.get("idem", 0))
	_check(c1 == 7 and c2 == 7, "idempotent: counter stable at 7 (got %d then %d)" % [c1, c2])


# ─────────────────────────────────────────────
#  辅助
# ─────────────────────────────────────────────

func _new_registry():
	var script = load("res://managers/instance_registry.gd")
	var ir = script.new()
	# 跳过 Node 树挂载，直接操作内部状态做单元验证
	return ir

func _dummy_card(instance_id: String):
	# 用 Dictionary 模拟实例表条目——reconcile/allocate 只读 instance_id 字符串做
	# has/解析判定，不依赖条目对象的类型，用 dict 规避 CardResource 加载时序问题
	var entry := {"_id": instance_id}
	return entry

func _check(cond: bool, msg: String) -> void:
	if cond:
		_pass_count += 1
		print("  PASS: %s" % msg)
	else:
		_fail_count += 1
		print("  >>>>FAIL: %s" % msg)
