class_name GateCoreStructureTest
extends GdUnitTestSuite
## v6.35 黑门 2.0 回归锁:随机本体深度/本体波构成/通关态/补给节点/首通 flag/布局池/渗透节点。
## 契约见 CHANGELOG v6.35 + AGENTS.md 对应段。EBM = EndlessBlackgateManager(autoload 懒加载)。

const EBMPath := "/root/EndlessBlackgateManager"


func _ebm() -> Node:
	var mll: Node = get_node_or_null("/root/ManagerLazyLoader")
	if mll != null and mll.has_method("ensure_loaded"):
		mll.ensure_loaded("endless")
	return get_node_or_null(EBMPath)


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


func _ebm_snapshot() -> Dictionary:
	var e := _ebm()
	return {
		"run_active": e.run_active, "gate_core_wave": e.gate_core_wave,
		"gate_cleared": e.gate_cleared, "gate_choice_pending": e.gate_choice_pending,
		"supplies_granted": e.supplies_granted, "gate_cleared_once": e.gate_cleared_once,
		"incursions": e.incursions.duplicate(true), "layout_variant": e.layout_variant,
		"current_rift_env": e.current_rift_env,
		# 2026-10-08 分段推进字段(防跨用例泄漏)
		"cp_wave": e.cp_wave, "cp_core_wave": e.cp_core_wave, "cp_rift_env": e.cp_rift_env,
		"cp_marrow_paid": e.cp_marrow_paid, "cp_supply_granted": e.cp_supply_granted,
	}


func _ebm_restore(s: Dictionary) -> void:
	var e := _ebm()
	e.run_active = s["run_active"]
	e.gate_core_wave = s["gate_core_wave"]
	e.gate_cleared = s["gate_cleared"]
	e.gate_choice_pending = s["gate_choice_pending"]
	e.supplies_granted = s["supplies_granted"]
	e.gate_cleared_once = s["gate_cleared_once"]
	e.incursions = s["incursions"]
	e.layout_variant = s["layout_variant"]
	e.cp_wave = s["cp_wave"]
	e.cp_core_wave = s["cp_core_wave"]
	e.cp_rift_env = s["cp_rift_env"]
	e.cp_marrow_paid = s["cp_marrow_paid"]
	e.cp_supply_granted = s["cp_supply_granted"]
	e.current_rift_env = s["current_rift_env"]


func before_test() -> void:
	pass


func after_test() -> void:
	pass


## v6.42 黑门结构改版：首场（未通关过）=固定第 FIRST_GATE_CORE_WAVE 波的有限试炼；
## 通关（gate_cleared_once=true）后才 roll 200-320 无限档。两种档都为 10 的倍数。
func test_begin_run_rolls_gate_core_wave_in_range() -> void:
	var e := _ebm()
	assert_object(e).is_not_null()
	var bak := _ebm_snapshot()
	# 首场试炼：恒 FIRST_GATE_CORE_WAVE
	e.gate_cleared_once = false
	for _i in range(5):
		e.begin_run()
		e.run_active = false  # 防止下一次 begin_run 双扣入场次数
		assert_int(e.gate_core_wave).is_equal(e.FIRST_GATE_CORE_WAVE)
		assert_bool(e.gate_cleared).is_false()
	# 通关后的无限模式：恢复 200-320 随机档
	e.gate_cleared_once = true
	for _i in range(30):
		e.begin_run()
		e.run_active = false
		assert_int(e.gate_core_wave).is_between(200, 320)
		assert_int(e.gate_core_wave % 10).is_equal(0)
		assert_bool(e.gate_cleared).is_false()
	_ebm_restore(bak)


## v6.42: get_run_wave_limit——首场 run 返回有限波上限，无限 run/非运行态返回 0
func test_run_wave_limit_first_gate_finite() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.gate_cleared_once = false
	e.begin_run()
	assert_int(e.get_run_wave_limit()).is_equal(e.FIRST_GATE_CORE_WAVE)
	e.run_active = false
	assert_int(e.get_run_wave_limit()).is_equal(0)
	e.gate_cleared_once = true
	e.begin_run()
	# 2026-10-08 分段推进:无限 run 返回锁定的本体深度(玩家按它规划分段)
	assert_int(e.get_run_wave_limit()).is_equal(e.gate_core_wave)
	assert_int(e.get_run_wave_limit()).is_between(200, 320)
	e.run_active = false
	_ebm_restore(bak)


## 2026-10-08 分段推进：段结算落进度、星髓差价不重复、续打恢复断点且免入场
func test_checkpoint_segment_settle_and_resume() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.gate_cleared_once = true
	e.begin_run()
	var core_wave: int = e.gate_core_wave
	assert_int(e.cp_core_wave).is_equal(core_wave)  # 新 run 即锁定深度
	# ── 第一段：推进到 80 波撤退 ──
	var paid0: int = int(e._weekly_marrow_gained)
	var s1: Dictionary = e.settle_run(80, 30)
	assert_bool(s1["checkpoint_saved"]).is_true()
	assert_int(e.cp_wave).is_equal(80)
	assert_int(int(s1["checkpoint_core_wave"])).is_equal(core_wave)
	var marrow_seg1: int = int(s1["marrow"])
	assert_int(marrow_seg1).is_equal(e.marrow_for_waves(80))  # 首段=里程碑全额(20+30+40+60+80=230)
	assert_int(e.cp_marrow_paid).is_equal(marrow_seg1)
	# ── 续打：恢复锁定深度/补给起点，且不扣入场次数 ──
	var entries_before: int = int(e._entries_used_today)
	e.begin_run()
	assert_bool(e.run_active).is_true()
	assert_int(e.gate_core_wave).is_equal(core_wave)  # 不重摇深度
	assert_int(e.supplies_granted).is_equal(e.cp_supply_granted)
	assert_int(int(e._entries_used_today)).is_equal(entries_before)  # 续打免入场
	# ── 第二段：推进到 160 波撤退——星髓只补差价(160 档总额 − 已付) ──
	var s2: Dictionary = e.settle_run(160, 60)
	var expect_delta: int = e.marrow_for_waves(160) - marrow_seg1
	assert_int(int(s2["marrow"])).is_equal(expect_delta)
	assert_int(e.cp_marrow_paid).is_equal(marrow_seg1 + expect_delta)
	assert_int(e.cp_wave).is_equal(160)
	# ── 通关段：进度清空 ──
	e.gate_cleared = true
	var s3: Dictionary = e.settle_run(core_wave, 100)
	assert_bool(s3["checkpoint_saved"]).is_false()
	assert_bool(e.has_checkpoint()).is_false()  # 通关清进度
	assert_int(e.cp_marrow_paid).is_equal(0)
	_ebm_restore(bak)


## 分段推进：存档 roundtrip——cp 五键跨存档保留
func test_checkpoint_survives_save_load_roundtrip() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.gate_cleared_once = true
	e.begin_run()
	var saved: Dictionary = e.settle_run(120, 40)
	assert_bool(bool(saved["checkpoint_saved"])).is_true()
	var snap: Dictionary = e.save_state()
	# 模拟重进游戏：新建字段再 load
	e.cp_wave = 0; e.cp_core_wave = 0; e.cp_rift_env = ""; e.cp_marrow_paid = 0; e.cp_supply_granted = 0
	e.load_state(snap)
	assert_bool(e.has_checkpoint()).is_true()
	assert_int(e.cp_wave).is_equal(120)
	assert_int(e.cp_core_wave).is_equal(int(snap["cp_core_wave"]))
	_ebm_restore(bak)


## 2026-10-09 分段推进：放弃进度——清档、下次进场走新 run(重摇深度+扣入场)
func test_abandon_checkpoint_resets_to_fresh_run() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	# entries 是跨用例存活的 autoload 态——本用例重置额度,保证"放弃后新 run 扣次"可断言
	var orig_entries: int = int(e._entries_used_today)
	e._entries_used_today = 0
	e.gate_cleared_once = true
	e.begin_run()
	e.settle_run(150, 50)
	assert_bool(e.has_checkpoint()).is_true()
	var entries_after_settle: int = int(e._entries_used_today)
	# 放弃进度
	e.abandon_checkpoint()
	assert_bool(e.has_checkpoint()).is_false()
	assert_int(e.cp_wave).is_equal(0)
	assert_int(e.cp_core_wave).is_equal(0)
	assert_int(e.cp_marrow_paid).is_equal(0)
	# 下次进场=新 run:重摇深度、扣入场次数、里程碑从头累计
	e.begin_run()
	assert_bool(e.run_active).is_true()
	assert_int(e.gate_core_wave).is_between(200, 320)
	assert_int(int(e._entries_used_today)).is_equal(entries_after_settle + 1)
	assert_int(e.cp_wave).is_equal(0)
	_ebm_restore(bak)
	e._entries_used_today = orig_entries


## 分段推进：中途退出 waves=0 不产生假进度；进度号只前进不回退
func test_checkpoint_never_regresses() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.gate_cleared_once = true
	e.begin_run()
	e.settle_run(100, 30)
	e.begin_run()
	e.settle_run(40, 10)  # 比断点更小的波次(进场即退)
	assert_int(e.cp_wave).is_equal(100)  # 不回退
	_ebm_restore(bak)


## 本体波构成:is_core_wave 分支只在本体深度波触发;cleared 后不再刷
## (经由 spawn 系统私有逻辑不可直测——这里锁 EBM 侧语义:mark_gate_cleared 幂等+信号)
func test_mark_gate_cleared_sets_state_once_and_clears_incursions() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.run_active = true
	e.incursions = [{"host_level": 90, "seed": 7, "spawned_day": 1}]
	var fired: Array = []
	e.gate_core_destroyed.connect(func() -> void: fired.append(1))
	e.mark_gate_cleared()
	assert_bool(e.gate_cleared).is_true()
	assert_bool(e.gate_choice_pending).is_true()
	assert_int(fired.size()).is_equal(1)
	# 幂等:第二次 mark 不重复发信号
	e.mark_gate_cleared()
	assert_int(fired.size()).is_equal(1)
	# 黑门关闭世界状态:渗透节点清空
	assert_array(e.incursions).is_empty()
	# 选择收口
	e.resolve_gate_choice()
	assert_bool(e.gate_choice_pending).is_false()
	_ebm_restore(bak)


## 补给节点:25 的倍数波入账、重复触发守卫、非节点波拒绝
func test_supply_node_grants_once_per_interval() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.run_active = true
	e.supplies_granted = 0
	assert_dict(e.grant_supply_node(10)).is_empty()   # 非节点波
	assert_dict(e.grant_supply_node(25)).is_not_empty()  # 节点波入账
	assert_int(e.supplies_granted).is_equal(1)
	assert_dict(e.grant_supply_node(25)).is_empty()   # 同节点重入守卫
	assert_dict(e.grant_supply_node(50)).is_not_empty()  # 下一节点
	assert_int(e.supplies_granted).is_equal(2)
	e.gate_cleared = true
	assert_dict(e.grant_supply_node(75)).is_empty()   # 通关后不再发
	_ebm_restore(bak)


## 首通大奖:settle_run 消费 gate_cleared 一次性发 flag,二刷不再发
func test_settle_run_first_clear_flag() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.run_active = true
	e.gate_cleared_once = false
	e.gate_cleared = true
	var s1: Dictionary = e.settle_run(210, 100)
	assert_bool(s1.get("gate_cleared", false)).is_true()
	assert_bool(s1.get("gate_first_clear", false)).is_true()
	assert_bool(e.gate_cleared_once).is_true()
	# 二次通关 run:有 gate_cleared 但非首通
	e.run_active = true
	e.gate_cleared = true
	var s2: Dictionary = e.settle_run(220, 100)
	assert_bool(s2.get("gate_cleared", false)).is_true()
	assert_bool(s2.get("gate_first_clear", false)).is_false()
	_ebm_restore(bak)


## 渗透节点:日刷上限/过期/erase 匹配/编队确定性
func test_incursion_lifecycle() -> void:
	var e := _ebm()
	var bak := _ebm_snapshot()
	e.incursions = []
	e.gate_cleared_once = false
	# erase 按 host+seed 匹配
	e.incursions = [{"host_level": 90, "seed": 7, "spawned_day": 1}, {"host_level": 80, "seed": 9, "spawned_day": 1}]
	e.erase_incursion({"host_level": 90, "seed": 7})
	assert_array(e.incursions).has_size(1)
	assert_int(int(e.incursions[0].get("seed", 0))).is_equal(9)
	# 编队确定性:同 seed 同编队
	var inc := {"host_level": 88, "seed": 12345, "spawned_day": 1}
	var l1: Dictionary = e.get_incursion_loadout(inc)
	var l2: Dictionary = e.get_incursion_loadout(inc)
	assert_array(l1.get("ids", [])).is_not_empty()
	assert_array(l1.get("ids", [])).is_equal(l2.get("ids", []))
	# 编队规模 4-6 只(3-5 基础 + 1 精英位)
	assert_int(int(l1.get("ids", []).size())).is_between(4, 6)
	# 通关停刷语义(世界状态在 mark_gate_cleared 清场;此处锁 loadout 对空表安全)
	e.incursions = []
	assert_array(e.get_incursion_loadout(inc).get("ids", [])).is_not_empty()  # 推导不依赖在场表
	_ebm_restore(bak)


## 布局池:变体表驱动/越界回退默认/应用与复位
func test_endless_layout_variants() -> void:
	var layouts := load("res://data/level_battle_layouts.gd")
	var cgl := load("res://scripts/card_grid_battle_layout.gd")
	var count: int = layouts.get_endless_variant_count()
	assert_int(count).is_between(2, 8)
	for i in range(count):
		assert_dict(layouts.get_endless_variant(i)).is_not_empty()
	assert_dict(layouts.get_endless_variant(-1)).is_empty()
	assert_dict(layouts.get_endless_variant(999)).is_empty()
	# 应用变体 1(4 列×3 行) → 槽位变化;复位 → 默认 3x3
	assert_bool(cgl.apply_for_endless(1)).is_true()
	assert_int(cgl.player_slots_total()).is_equal(12)
	assert_bool(cgl.apply_for_endless(0)).is_true()
	cgl.reset_to_default()
	assert_int(cgl.player_slots_total()).is_equal(9)
	# 收尾恢复(不确定前值就复位默认,与 end_battle 同律)
	cgl.reset_to_default()


## 敌成长分段收敛:普通关小波次零变化、高波收敛(数值定案断言)
func test_enemy_stat_resolver_segmented_growth() -> void:
	var r := load("res://data/enemy_stat_resolver.gd")
	# 第一段(≤60 波)与旧线性完全一致:wave 1 = 1.0, wave 10 = 1.72
	assert_float(r.wave_hp_multiplier(1)).is_equal_approx(1.0, 0.0001)
	assert_float(r.wave_hp_multiplier(10)).is_equal_approx(1.72, 0.0001)
	# 收敛段:wave 300 = 1+0.08×59+0.015×240 = 9.32(定案值)
	assert_float(r.wave_hp_multiplier(300)).is_equal_approx(9.32, 0.0001)
	assert_float(r.wave_damage_multiplier(300)).is_equal_approx(7.42, 0.0001)
	# 攻防一致地:wave 1 恒 1.0
	assert_float(r.wave_damage_multiplier(1)).is_equal_approx(1.0, 0.0001)
	assert_float(r.wave_def_multiplier(1)).is_equal_approx(1.0, 0.0001)


## 出兵 gate:通关弹窗待选择期间波间隔事实暂停
func test_wave_interval_holds_on_gate_choice() -> void:
	var e := _ebm()
	var gm := _gm()
	var bak := _ebm_snapshot()
	var bak_endless: bool = gm._is_endless_battle
	e.run_active = true
	e.gate_choice_pending = true
	gm._is_endless_battle = true
	assert_float(gm.get_enemy_wave_interval_for_level(100)).is_equal_approx(3600.0, 0.001)
	e.gate_choice_pending = false
	assert_float(gm.get_enemy_wave_interval_for_level(100)).is_equal_approx(7.0, 0.001)
	gm._is_endless_battle = bak_endless
	_ebm_restore(bak)


## 渗透轻结算口径常量存在(收益很小定案,C3 数值单一真身)
func test_incursion_and_supply_constants() -> void:
	var e := _ebm()
	assert_int(e.GATE_CORE_WAVE_MIN).is_equal(200)
	assert_int(e.GATE_CORE_WAVE_MAX).is_equal(320)
	assert_int(e.FIRST_GATE_CORE_WAVE).is_equal(30)  # v6.42: 首场试炼有限波
	assert_int(e.SUPPLY_INTERVAL).is_equal(25)
	assert_int(e.INCURSION_MAX).is_equal(3)
	assert_int(e.GATE_FIRST_CLEAR_MARROW).is_equal(300)  # 2026-10-08 收益感批：200→300
	# xeno 本体条目存在且不在常规轮换池
	var xu := load("res://data/xeno_units.gd")
	assert_bool(xu.UNITS.has("xeno_gate_core")).is_true()
	assert_str(String(xu.UNITS["xeno_gate_core"].get("role", ""))).is_equal("core")
	assert_array(xu.get_ids_for_role("boss")).not_contains(["xeno_gate_core"])
	# 缴获本体卡必须可部署:power 不得超 power_cap 上限(2400=无垠档)
	assert_int(int(xu.UNITS["xeno_gate_core"].get("power", 0))).is_less_equal(2400)


## v6.35 复查锁:渗透战备态不直接开打——start_incursion_battle 只置 pending/关卡对齐,
## go_to_battle 由 main 标准管线(show_battle)触发。回退旧直接开打代码此用例必红。
func test_start_incursion_battle_preps_only() -> void:
	var e := _ebm()
	var gm := _gm()
	var bak := _ebm_snapshot()
	var bak_level: int = int(gm.current_level)
	var bak_phase: int = int(gm.current_phase)
	e.incursions = [{"host_level": 88, "seed": 42, "spawned_day": 1}]
	gm.start_incursion_battle(e.incursions[0])
	assert_array(gm.pending_incursion_loadout).is_not_empty()
	assert_bool(bool(gm.is_incursion_battle())).is_true()
	assert_int(int(gm.current_level)).is_equal(88)
	# 未直接开打:战斗相位不进 BATTLE(留给 main 管线)
	assert_int(int(gm.current_phase)).is_equal(bak_phase)
	# 清理渗透态
	gm.pending_incursion_loadout = []
	gm.set("_is_incursion_battle", false)
	gm.set("_pending_incursion", {})
	gm.set_current_level(bak_level)
	_ebm_restore(bak)


# ═════════════════════════════════════════════════════════════
#  v6.71 动态补给网：渗透宿主区域威胁加权 + 迷失相位师波数据侧
# ═════════════════════════════════════════════════════════════

func _snm() -> Node:
	return get_node_or_null("/root/SupplyNetworkManager")


## v6.71 M1.1：_spawn_incursion 宿主抽关改按区域威胁加权——高威胁区显著更密。
## 统计断言（2000 次抽样）：region1 威胁 100 vs region2 威胁 0 时，
## region1 命中数占比 > 80%（基线 20/20+120+20 → 理论 ~75%+，留容差）。
func test_spawn_incursion_host_threat_weighted() -> void:
	var e := _ebm()
	var snm := _snm()
	assert_bool(snm != null).is_true()
	var threat_bak: Dictionary = snm.region_threat.duplicate()
	snm.region_threat = {1: 100, 2: 0}
	var r1_hits: int = 0
	var n: int = 2000
	for _i in range(n):
		var lv: int = e.call("_pick_threat_weighted_level", 1, 20)
		if lv <= 10:
			r1_hits += 1
	snm.region_threat = threat_bak
	# 加权后 region1（威胁100）应压倒 region2（威胁0）
	assert_int(r1_hits).is_greater(int(n * 0.8))

## 全零威胁退化均匀：两区命中量级相当（±15% 容差，防写死权重后忘退化分支）
func test_spawn_incursion_zero_threat_uniform_fallback() -> void:
	var e := _ebm()
	var snm := _snm()
	var threat_bak: Dictionary = snm.region_threat.duplicate()
	snm.region_threat = {}
	var r1_hits: int = 0
	var n: int = 2000
	for _i in range(n):
		if e.call("_pick_threat_weighted_level", 1, 20) <= 10:
			r1_hits += 1
	snm.region_threat = threat_bak
	assert_int(r1_hits).is_greater(int(n * 0.35))
	assert_int(r1_hits).is_less(int(n * 0.65))


## v6.71 M4：迷失变体波常量与池联动（spawn 侧波次逻辑需战场，此处锁数据侧契约）
func test_lost_master_pool_feeds_blackgate_variant() -> void:
	var snm := _snm()
	assert_bool(snm != null).is_true()
	var lost_bak: Array = snm.lost_masters.duplicate(true)
	var garrison_bak: Dictionary = snm.garrison_lost.duplicate()
	snm.lost_masters = [{"master_id": "量子幽灵", "origin": "roam", "lost_day": 3}]
	var pool: Array = snm.blackgate_variant_pool()
	assert_array(pool).contains("量子幽灵")
	snm.lost_masters = lost_bak
	snm.garrison_lost = garrison_bak
