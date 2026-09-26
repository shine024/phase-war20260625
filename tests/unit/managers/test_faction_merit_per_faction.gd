class_name FactionMeritPerFactionTest
extends GdUnitTestSuite
## 记录4#3：功勋按势力分账回归锁。
## 契约：贡献镜像只进本势力账；购买查/扣本势力账；成就等无上下文直发均摊（总量守恒）；
## 旧档单值键读档均分迁移。真实 autoload 环境，测完整表回滚 merit_by_faction。

const FactionShop = preload("res://managers/faction/faction_shop.gd")


func _get_fsm() -> Node:
	return get_node_or_null("/root/FactionSystemManager")


func _snapshot(fsm: Node) -> Dictionary:
	return (fsm.merit_by_faction as Dictionary).duplicate(true)


func _restore(fsm: Node, snap: Dictionary) -> void:
	fsm.merit_by_faction = snap.duplicate(true)


func _first_two_factions(fsm: Node) -> Array:
	var ids: Array = (fsm._all_faction_ids as Array).duplicate()
	return [String(ids[0]), String(ids[1])]


func test_mirror_credits_own_faction_only() -> void:
	var fsm := _get_fsm()
	if fsm == null:
		return
	var snap := _snapshot(fsm)
	var fa: String = _first_two_factions(fsm)[0]
	var fb: String = _first_two_factions(fsm)[1]
	var before_a: int = int(fsm.get_merit_points(fa))
	var before_b: int = int(fsm.get_merit_points(fb))
	fsm.add_faction_reputation(fa, 10)
	var after_a: int = int(fsm.get_merit_points(fa))
	var after_b: int = int(fsm.get_merit_points(fb))
	_restore(fsm, snap)
	assert_int(after_a - before_a).is_equal(10)
	assert_int(after_b).is_equal(before_b)


func test_purchase_spends_own_faction_bucket() -> void:
	var fsm := _get_fsm()
	if fsm == null:
		return
	var snap := _snapshot(fsm)
	var ids := _first_two_factions(fsm)
	var fa: String = ids[0]
	var fb: String = ids[1]
	# A 账塞 10000，B 账清 0
	fsm.merit_by_faction[fa] = 10000
	fsm.merit_by_faction[fb] = 0
	var items: Array = fsm.get_faction_store_items(fa)
	var target = null
	for it in items:
		if it != null and int(it.reputation_cost) > 0 and int(it.reputation_cost) <= 10000:
			target = it
			break
	if target == null:
		_restore(fsm, snap)
		print("  该势力无可用商品，跳过")
		return
	var cost: int = int(target.reputation_cost)
	var before_b: int = int(fsm.get_merit_points(fb))
	var can: Dictionary = fsm.can_purchase_item(fa, target)
	assert_bool(bool(can.get("ok", false))).is_true()
	var result: Dictionary = fsm.purchase_item(fa, target)
	var after_a: int = int(fsm.get_merit_points(fa))
	var after_b: int = int(fsm.get_merit_points(fb))
	_restore(fsm, snap)
	# B 账必须分文未动（跨势力不可花）
	assert_int(after_b).is_equal(before_b)
	# 成交扣本势力账；发货失败则全额回退
	if bool(result.get("ok", false)):
		assert_int(after_a).is_equal(10000 - cost)
	else:
		assert_int(after_a).is_equal(10000)


func test_add_merit_without_faction_conserves_total() -> void:
	var fsm := _get_fsm()
	if fsm == null:
		return
	var snap := _snapshot(fsm)
	var before_total: int = int(fsm.get_merit_points())
	fsm.add_merit(7)
	var after_total: int = int(fsm.get_merit_points())
	_restore(fsm, snap)
	assert_int(after_total - before_total).is_equal(7)


func test_legacy_single_value_splits_evenly() -> void:
	var fsm := _get_fsm()
	if fsm == null:
		return
	var snap := _snapshot(fsm)
	# 仅带旧单值键的存档段（旧档迁移路径）
	fsm.load_state({"faction_merit": 500})
	var n: int = maxi(1, (fsm._all_faction_ids as Array).size())
	var total: int = int(fsm.get_merit_points())
	_restore(fsm, snap)
	assert_int(total).is_equal(500)
	# 均分后任意势力账 ≤ share+1（余数只给第一个）
	var max_bucket: int = 0
	for fid in (fsm.merit_by_faction as Dictionary):
		max_bucket = maxi(max_bucket, int(fsm.merit_by_faction[fid]))
	assert_int(max_bucket).is_less_equal(500 / n + 1)
