extends GdUnitTestSuite
## v33 击杀地面战利品 + 情报图纸主腿前移回归锁
## 契约（掷骰拆两腿，分布与旧版单掷精确等价）：
## 1) 数学锁：p1 + (1−p1)×p2 == base(stars)×rank_mult×occ，全档位网格精确成立；
##    1 星及以下 p2=0（星级加成只在 2/3 星存在）
## 2) 主腿命中：enemy_info 打 intel_main_hit 标记 + 掉落进 pending（一次）
## 3) 战后收编：pending 原样并入 drops 且只消费一次
## 4) disable（相位师战防双爆口径）：pending 清空不发（与旧版零掉落一致）
## 5) 全标记敌人列表：星级腿零掷（确定性空）
## 6) battle_started 清空 pending（败北未消费不带到下一场）

const IdmScript = preload("res://scripts/systems/intel_discovery_manager.gd")

var _idm: Node


func before_test() -> void:
	_idm = IdmScript.new()
	add_child(_idm)


func after_test() -> void:
	if _idm != null and is_instance_valid(_idm):
		_idm.queue_free()
	_idm = null


# ── 1) 分布等价数学锁 ─────────────────────────────────────────────

func test_two_leg_distribution_exact_across_grid() -> void:
	for stars in [0, 1, 2, 3]:
		for rank in ["normal", "elite", "boss"]:
			for occ in [1.0, 1.25, 1.5]:
				var p1: float = IdmScript.intel_main_leg_chance(rank, occ)
				var p2: float = IdmScript.intel_star_leg_chance(stars, rank, occ)
				var combined: float = p1 + (1.0 - p1) * p2
				var target: float = IdmScript.intel_star_base_chance(stars) \
					* IdmScript.intel_rank_mult(rank) * occ
				assert_bool(absf(combined - target) < 1e-9).is_true()
				assert_bool(p2 >= 0.0 and p2 <= 1.0).is_true()


func test_star_leg_zero_below_two_stars() -> void:
	for stars in [0, 1]:
		for rank in ["normal", "elite", "boss"]:
			assert_bool(IdmScript.intel_star_leg_chance(stars, rank, 1.5) < 1e-9).is_true()


# ── 2) 主腿标记与 pending ─────────────────────────────────────────

func test_main_leg_hit_marks_info_and_pends() -> void:
	var hit := false
	for i in 500:
		var info := {"archetype_id": "foe_preroll_probe", "rank": "normal", "enemy_type": "infantry"}
		var drop: Dictionary = _idm.roll_kill_intel_drop(info)
		if drop.is_empty():
			assert_bool(info.has("intel_main_hit")).is_false()
			continue
		hit = true
		# 主腿命中必须打标记（战后星级腿跳过依据）
		assert_bool(bool(info.get("intel_main_hit", false))).is_true()
		# 掉落字典必须带 item_type/rarity（地面战利品展示契约）
		assert_bool(drop.has("item_type") and drop.has("rarity")).is_true()
		break
	assert_bool(hit).is_true()


# ── 3/4/5) 战后收编与口径 ─────────────────────────────────────────

func test_harvest_consumes_pending_exactly_once() -> void:
	_idm._kill_prerolled_drops.append({
		"item_type": "blueprint_preroll_probe", "name": "测试图纸",
		"rarity": "rare", "mod_id": "preroll_probe",
	})
	var enemies := [{"archetype_id": "foe_a", "rank": "normal", "enemy_type": "infantry"}]
	# victory_stars=1 → 星级腿 p2 精确为 0（base 与主腿同 0.12），结果确定性只含 pending
	var drops: Array = _idm._roll_intel_item_drops(enemies, 1, null)
	assert_int(drops.size()).is_equal(1)
	assert_str(str(drops[0].get("item_type", ""))).is_equal("blueprint_preroll_probe")
	assert_int(_idm._kill_prerolled_drops.size()).is_equal(0)
	# 第二次调用：pending 已消费，不得重复发放
	var drops2: Array = _idm._roll_intel_item_drops(enemies, 1, null)
	assert_int(drops2.size()).is_equal(0)


func test_disable_mod_blueprint_clears_pending() -> void:
	_idm._kill_prerolled_drops.append({
		"item_type": "blueprint_preroll_probe2", "name": "测试图纸2",
		"rarity": "epic", "mod_id": "preroll_probe2",
	})
	var drops: Array = _idm._roll_intel_item_drops([], 3, null, true)
	assert_int(drops.size()).is_equal(0)
	assert_int(_idm._kill_prerolled_drops.size()).is_equal(0)


func test_fully_marked_list_rolls_nothing() -> void:
	_idm._kill_prerolled_drops.clear()
	var marked := {
		"archetype_id": "foe_b", "rank": "boss",
		"enemy_type": "armor", "intel_main_hit": true,
	}
	var drops: Array = _idm._roll_intel_item_drops([marked], 3, null)
	assert_int(drops.size()).is_equal(0)


# ── 6) 按场清空 ───────────────────────────────────────────────────

func test_battle_started_clears_prerolls() -> void:
	_idm._kill_prerolled_drops.append({"item_type": "blueprint_stale", "name": "陈旧", "rarity": "common"})
	_idm._on_battle_started_clear_prerolls()
	assert_int(_idm._kill_prerolled_drops.size()).is_equal(0)
