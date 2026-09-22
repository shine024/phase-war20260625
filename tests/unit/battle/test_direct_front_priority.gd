class_name DirectFrontPriorityTest
extends GdUnitTestSuite
## v38.x 直射前排优先回归锁：select_target_direct 三键排序
## （① 前向 x 跨排优先 → ② 同前进带内同排 tiebreak → ③ 距离/HP）。
## 修复场景：直射坦克无视更前方的异排敌人，粘死同排后排目标
## （用户实机"前面有两个敌人直射不应该先打前面的么"）。
##
## 几何口径（与 CardGridBattleLayout 站位一致）：我方带在左（x 小），敌方带在右
## （x 大）。forward_sign：我方攻击者 -1（目标 x 越小=敌阵列朝我方的前排）、
## 敌方攻击者 +1（目标 x 越大=我方阵列朝敌方的前排）。

## 测试假单位：带 hp/is_player 字段的最小 Node2D
class DummyUnit extends Node2D:
	var hp: float = 100.0
	var is_player: bool = false


func _mk_unit(pos: Vector2, slot: int, is_enemy: bool) -> DummyUnit:
	var u := DummyUnit.new()
	u.position = pos
	u.is_player = not is_enemy
	if slot >= 0:
		u.set_meta("card_grid_enemy_slot" if is_enemy else "card_grid_slot", slot)
	add_child(u)
	return u


func after_test() -> void:
	for c in get_children():
		c.queue_free()


func test_front_row_other_beats_same_row_rear() -> void:
	# 玩家攻击者 (200,300) row2；敌前排异排 (320,100) row0；敌后排同排 (520,300) row2。
	# 前向值：前排 -320 > 后排 -520 → 选前排（旧逻辑同排优先+距离最近会选后排同排敌）。
	var attacker := _mk_unit(Vector2(200, 300), 6, false)
	var front_other_row := _mk_unit(Vector2(320, 100), 2, true)
	var rear_same_row := _mk_unit(Vector2(520, 300), 8, true)
	var picked: Node2D = TargetSelection.select_target_direct(
		attacker, [rear_same_row, front_other_row])
	assert_that(picked).is_same(front_other_row)


func test_front_priority_beats_distance() -> void:
	# 前向与距离冲突：同排敌 (480,300) 更近（280px）但更靠后（前向 -480）；
	# 异排敌 (460,60) 更远（~354px）但更靠前（前向 -460）→ 应选异排前排。
	var attacker := _mk_unit(Vector2(200, 300), 6, false)
	var near_rear := _mk_unit(Vector2(480, 300), 8, true)
	var far_front := _mk_unit(Vector2(460, 60), 2, true)
	var picked: Node2D = TargetSelection.select_target_direct(
		attacker, [near_rear, far_front])
	assert_that(picked).is_same(far_front)


func test_same_front_band_prefers_same_row() -> void:
	# 同前进带（x 差 ≤ 12px 容差）内：同排 tiebreak 生效
	var attacker := _mk_unit(Vector2(600, 300), 6, false)
	var band_same_row := _mk_unit(Vector2(900, 300), 8, true)    # 前向 -900，同排
	var band_other_row := _mk_unit(Vector2(905, 100), 2, true)   # 前向 -905（带内），异排
	var picked: Node2D = TargetSelection.select_target_direct(
		attacker, [band_other_row, band_same_row])
	assert_that(picked).is_same(band_same_row)


func test_equal_front_band_distance_tiebreaks_by_hp() -> void:
	# 同带同排同距：低 HP 优先
	var attacker := _mk_unit(Vector2(600, 300), 6, false)
	var low_hp := _mk_unit(Vector2(900, 300), 8, true)
	low_hp.hp = 30.0
	var high_hp := _mk_unit(Vector2(900, 300), 7, true)
	high_hp.hp = 80.0
	var picked: Node2D = TargetSelection.select_target_direct(
		attacker, [high_hp, low_hp])
	assert_that(picked).is_same(low_hp)


func test_enemy_side_symmetry() -> void:
	# 敌方攻击者 (600,100) row0 对称口径（前向 = +x）：我方前排 (500,300) row1
	# 前向 500 > 我方后排 (300,100) row0 前向 300 → 选前排（旧逻辑同行覆盖选后排）。
	var attacker := _mk_unit(Vector2(600, 100), 2, true)
	var front_player := _mk_unit(Vector2(500, 300), 5, false)
	var rear_player := _mk_unit(Vector2(300, 100), 0, false)
	var picked: Node2D = TargetSelection.select_target_direct(
		attacker, [rear_player, front_player])
	assert_that(picked).is_same(front_player)


func test_dead_and_untargetable_filtered() -> void:
	var attacker := _mk_unit(Vector2(200, 300), 6, false)
	var alive := _mk_unit(Vector2(400, 300), 8, true)
	var dead := _mk_unit(Vector2(100, 300), 2, true)
	dead.hp = 0.0
	var picked: Node2D = TargetSelection.select_target_direct(
		attacker, [dead, alive])
	assert_that(picked).is_same(alive)
