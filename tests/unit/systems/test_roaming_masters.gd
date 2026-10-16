extends GdUnitTestSuite
## v6.71 游猎相位师回归锁（计划 §九）：解锁单调、池校验、迷失吸收幂等、
## 遭遇优先级数据侧、黑门变体波常量、模拟战败无后果语义。
##
## 边界：本套件 new() 独立实例（不触碰真 autoload）；涉 /root 查询的函数
## （activate_roaming_if_due 等）只测纯数据侧与常量结构。

const SupplyThreatT = preload("res://data/supply_threat.gd")
const NpcPhaseMastersT = preload("res://data/npc_phase_masters.gd")
const SupplyNetworkManagerScript = preload("res://managers/supply_network_manager.gd")
const SpawnSystemScript = preload("res://managers/battle/battle_spawn_system.gd")

func _make_manager() -> Object:
	return auto_free(SupplyNetworkManagerScript.new())

# ─────────────────────────────────────────────────────────────
#  常量与池结构
# ─────────────────────────────────────────────────────────────

func test_roaming_unlock_levels_monotonic_and_named() -> void:
	var lv: Array = SupplyNetworkManagerScript.ROAMING_UNLOCK_LEVELS
	assert_int(lv.size()).is_equal(3)
	assert_int(lv[0]).is_less(lv[1])
	assert_int(lv[1]).is_less(lv[2])
	# 三位游猎者都必须在 NPC 池有名字（防拼写漂移——_roaming_name_for_slot 池校验同律）
	for i in range(SupplyNetworkManagerScript.ROAMING_MASTER_NAMES.size()):
		var found: bool = false
		for cfg in NpcPhaseMastersT.get_all():
			if String(cfg.get("name", "")) == String(SupplyNetworkManagerScript.ROAMING_MASTER_NAMES[i]):
				found = true
				break
		assert_bool(found).is_true()

func test_roaming_constants_shape() -> void:
	assert_int(SupplyNetworkManagerScript.ROAMING_FINAL_LEVEL).is_equal(100)
	assert_int(SupplyNetworkManagerScript.ROAMING_DAILY_CAP).is_greater_equal(1)
	assert_int(SupplyNetworkManagerScript.ROAMING_DAILY_CAP).is_less_equal(3)
	assert_int(SupplyNetworkManagerScript.ROAMING_SPAWN_OFFSET).is_greater(0)

func test_blackgate_wave_interval_constant() -> void:
	# 迷失变体波间隔=40（battle_spawn_system 锁定，波动会破坏波次节律预期）
	assert_int(SpawnSystemScript.LOST_MASTER_WAVE_INTERVAL).is_equal(40)

# ─────────────────────────────────────────────────────────────
#  迷失池吸收（roam/garrison 共用，幂等）
# ─────────────────────────────────────────────────────────────

func test_add_lost_master_idempotent_and_tagged() -> void:
	var snm: Object = _make_manager()
	snm.add_lost_master("旧日雷霆", "roam", 5)
	snm.add_lost_master("旧日雷霆", "roam", 9)  # 幂等：重复登记吸收
	var pool: Array = snm.get_lost_overview()
	assert_int(pool.size()).is_equal(1)
	assert_str(String((pool[0] as Dictionary).get("origin"))).is_equal("roam")
	assert_int(int((pool[0] as Dictionary).get("lost_day"))).is_equal(5)
	# 同名 garrison 来路被吸收（先到先得）
	snm.add_lost_master("旧日雷霆", "garrison", 12)
	assert_int(snm.get_lost_overview().size()).is_equal(1)

func test_garrison_origin_marks_lost_filter() -> void:
	# garrison 迷失 → is_garrison_encounter_available=false（重打只剩卡）
	var snm: Object = _make_manager()
	assert_bool(bool(snm.call("is_garrison_encounter_available", 30))).is_true()
	snm.add_lost_master("enemy_master_009", "garrison", 3)
	assert_bool(bool(snm.call("is_garrison_encounter_available", 30))).is_false()
	# 非迷失：其它驻守关不受影响
	assert_bool(bool(snm.call("is_garrison_encounter_available", 35))).is_true()

func test_blackgate_variant_pool_matches_lost_roster() -> void:
	var snm: Object = _make_manager()
	assert_array(snm.call("blackgate_variant_pool")).is_empty()
	snm.add_lost_master("量子幽灵", "roam", 7)
	snm.add_lost_master("enemy_master_020", "garrison", 11)
	var pool: Array = snm.call("blackgate_variant_pool")
	assert_array(pool).contains("量子幽灵")
	assert_array(pool).contains("enemy_master_020")
	assert_int(pool.size()).is_equal(2)

# ─────────────────────────────────────────────────────────────
#  遭遇优先级数据侧（game_manager 消费口径）
# ─────────────────────────────────────────────────────────────

func test_get_roaming_master_at_exact_level_only() -> void:
	var snm: Object = _make_manager()
	snm.roaming_masters.append({"master_id": "量子幽灵", "level": 42, "active": true})
	assert_dict(snm.call("get_roaming_master_at", 42)).is_not_empty()
	assert_dict(snm.call("get_roaming_master_at", 41)).is_empty()
	assert_dict(snm.call("get_roaming_master_at", 43)).is_empty()
	# 已迷失（active=false）不再遭遇
	snm.roaming_masters[0]["active"] = false
	assert_dict(snm.call("get_roaming_master_at", 42)).is_empty()

func test_garrison_filter_wins_over_any_roaming_data() -> void:
	# 优先级链：garrison_lost 过滤独立于游猎数据——同关双态时驻守过滤仍成立
	var snm: Object = _make_manager()
	snm.add_lost_master("enemy_master_009", "garrison", 2)
	snm.roaming_masters.append({"master_id": "量子幽灵", "level": 30, "active": true})
	assert_bool(bool(snm.call("is_garrison_encounter_available", 30))).is_false()
	assert_dict(snm.call("get_roaming_master_at", 30)).is_not_empty()  # 游猎线不误伤

# ─────────────────────────────────────────────────────────────
#  模拟战语义（game_manager 消费口径的常量侧锁定）
# ─────────────────────────────────────────────────────────────

func test_roaming_move_never_backward_via_state_shape() -> void:
	# _roaming_daily_move 依赖 /root（不直测）；此处锁「迷失只增不减」的池语义：
	# lose_roaming_master 走 add_lost_master 幂等路径，重复迷失不重复播报登记
	var snm: Object = _make_manager()
	snm.lose_roaming_master("终焉之镰", "roam", 20)
	snm.lose_roaming_master("终焉之镰", "roam", 25)
	assert_int(snm.get_lost_overview().size()).is_equal(1)
	assert_bool(bool(snm.call("is_master_lost", "终焉之镰"))).is_true()
