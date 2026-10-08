extends GdUnitTestSuite
## v6.52（记录1#37）回归锁：攻防同维度配对——三维攻防的维度判定唯一口与受击侧配对。
##
## 根因复盘（实机"自行火炮对轻攻击 20 多、对装甲攻击 200 多"复查）：攻击侧
## AttackCalculator.get_attack_vs 按**目标类型**选攻击维度（打装甲=attack_armor），
## 受击侧（construct_unit/enemy_unit/swarm_enemy_slot 三份内联 match +
## get_defense_vs）却按**攻击者兵种**选防御维度——SUPPORT 火炮恒被 defense_light 挡：
## 重炮打坦克只被坦克的对轻防御（d_l=60）抵消，比它的对甲防御（d_a=90）还少 30，
## 软兵种反比硬目标抗重炮。数据表语义（unit_stats_table "防轻装/防装甲/防空中"）
## 本就是"对攻击类型的抵御"。
##
## 契约（scripts/battle/attack_calculator.gd）：
## ① attack_dim_for_target = 攻击维度判定唯一口（LIGHT/SUPPORT 目标→LIGHT 轴、
##   ARMOR/FORT→ARMOR 轴、AIR→AIR 轴、未知→LIGHT）；
## ② 弹道重赋（converted_munitions）把对轻轴转 ARMOR 轴（v21 语义保持）；
## ③ get_defense_vs 有 attacker_stats 时按①配对；attacker_stats=null 兵种口径兜底
##   （旧调用方/诊断锁行为不变）；
## ④ get_attack_vs 与 ① 同轴（两函数对全目标类型取同一维度）；
## ⑤ era0 数据表语义：装甲目标 defense_armor > defense_light（配对修正方向=硬目标
##   对重火力更抗，轻装目标不变）。

const AttackCalc = preload("res://scripts/battle/attack_calculator.gd")
const GC = preload("res://resources/game_constants.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")


func _mk_stats(kind: int, atk_l: float = 50.0, atk_a: float = 50.0, atk_air: float = 50.0) -> UnitStats:
	var s := UnitStats.new()
	s.combat_kind = kind
	s.attack_light = atk_l
	s.attack_armor = atk_a
	s.attack_air = atk_air
	s.defense_light = 10.0
	s.defense_armor = 20.0
	s.defense_air = 30.0
	return s


## ① 维度判定矩阵（全目标类型）
func test_attack_dim_matrix() -> void:
	var shooter := _mk_stats(GC.CombatKind.SUPPORT)
	assert_int(AttackCalc.attack_dim_for_target(shooter, GC.CombatKind.LIGHT)).is_equal(GC.CombatKind.LIGHT)
	assert_int(AttackCalc.attack_dim_for_target(shooter, GC.CombatKind.SUPPORT)).is_equal(GC.CombatKind.LIGHT)
	assert_int(AttackCalc.attack_dim_for_target(shooter, GC.CombatKind.ARMOR)).is_equal(GC.CombatKind.ARMOR)
	assert_int(AttackCalc.attack_dim_for_target(shooter, GC.CombatKind.FORT)).is_equal(GC.CombatKind.ARMOR)
	assert_int(AttackCalc.attack_dim_for_target(shooter, GC.CombatKind.AIR)).is_equal(GC.CombatKind.AIR)
	# 未知目标类型兜底 LIGHT 轴
	assert_int(AttackCalc.attack_dim_for_target(shooter, 99)).is_equal(GC.CombatKind.LIGHT)


## ② 弹道重赋：对轻轴转对甲轴（v21 语义，唯一口承接）
func test_converted_munitions_flips_light_axis() -> void:
	var shooter := _mk_stats(GC.CombatKind.LIGHT)
	shooter.set_meta("mod_special_flags", {"converted_munitions": true})
	assert_int(AttackCalc.attack_dim_for_target(shooter, GC.CombatKind.LIGHT)).is_equal(GC.CombatKind.ARMOR)
	assert_int(AttackCalc.attack_dim_for_target(shooter, GC.CombatKind.SUPPORT)).is_equal(GC.CombatKind.ARMOR)
	# 对甲/对空轴不受影响
	assert_int(AttackCalc.attack_dim_for_target(shooter, GC.CombatKind.ARMOR)).is_equal(GC.CombatKind.ARMOR)
	assert_int(AttackCalc.attack_dim_for_target(shooter, GC.CombatKind.AIR)).is_equal(GC.CombatKind.AIR)


## ③ 新口径配对：防御维度跟随攻击维度（火炮打坦克=对甲防御，不再被对轻防御挡）
func test_defense_pairs_with_attack_dim() -> void:
	var shooter_support := _mk_stats(GC.CombatKind.SUPPORT)
	var tank := _mk_stats(GC.CombatKind.ARMOR)
	tank.defense_light = 60.0
	tank.defense_armor = 90.0
	# SUPPORT 攻击者打 ARMOR 目标 → 目标的 defense_armor（旧口径错给 defense_light=60）
	assert_float(AttackCalc.get_defense_vs(tank, GC.CombatKind.SUPPORT, shooter_support)).is_equal(90.0)
	# SUPPORT 攻击者打 LIGHT 目标 → defense_light（与旧行为一致）
	var inf := _mk_stats(GC.CombatKind.LIGHT)
	inf.defense_light = 30.0
	assert_float(AttackCalc.get_defense_vs(inf, GC.CombatKind.SUPPORT, shooter_support)).is_equal(30.0)
	# ARMOR 攻击者打 LIGHT 目标 → defense_light（同轴：打轻装=轻轴）
	assert_float(AttackCalc.get_defense_vs(inf, GC.CombatKind.ARMOR, _mk_stats(GC.CombatKind.ARMOR))).is_equal(30.0)
	# 空中目标 → defense_air
	var heli := _mk_stats(GC.CombatKind.AIR)
	heli.defense_air = 36.0
	assert_float(AttackCalc.get_defense_vs(heli, GC.CombatKind.ARMOR, _mk_stats(GC.CombatKind.ARMOR))).is_equal(36.0)
	# 重赋单位打 LIGHT 目标 → ARMOR 轴（目标对甲防御）
	shooter_support.set_meta("mod_special_flags", {"converted_munitions": true})
	assert_float(AttackCalc.get_defense_vs(inf, GC.CombatKind.SUPPORT, shooter_support)).is_equal(inf.defense_armor)


## ③b 兜底：attacker_stats=null 维持兵种口径（旧调用方/诊断锁行为不变）
func test_null_attacker_stats_fallback_unchanged() -> void:
	var inf := _mk_stats(GC.CombatKind.LIGHT)
	inf.defense_light = 30.0
	inf.defense_armor = 14.0
	assert_float(AttackCalc.get_defense_vs(inf, GC.CombatKind.SUPPORT)).is_equal(30.0)
	assert_float(AttackCalc.get_defense_vs(inf, GC.CombatKind.ARMOR)).is_equal(14.0)
	# 重赋判定对 null stats 安全（不报错、不转换）
	assert_bool(AttackCalc.get_defense_vs(inf, GC.CombatKind.SUPPORT, null) > 0.0).is_true()


## ④ 同轴性：get_attack_vs 取值轴与 attack_dim_for_target 判定轴一致
func test_attack_vs_and_dim_same_axis() -> void:
	# 攻击值可分辨：对轻 100 / 对甲 7 / 对空 100——打某类目标 get_attack_vs 返回哪一维，
	# attack_dim_for_target 必须给同一维
	var shooter := _mk_stats(GC.CombatKind.LIGHT, 100.0, 7.0, 100.0)
	var targets := [GC.CombatKind.LIGHT, GC.CombatKind.SUPPORT, GC.CombatKind.ARMOR,
		GC.CombatKind.FORT, GC.CombatKind.AIR]
	for tk_v in targets:
		var tk: int = int(tk_v)
		var dim: int = AttackCalc.attack_dim_for_target(shooter, tk)
		var atk: float = AttackCalc.get_attack_vs(shooter, tk)
		match dim:
			GC.CombatKind.ARMOR:
				assert_float(atk).is_equal_approx(7.0, 0.001)
			GC.CombatKind.AIR:
				assert_float(atk).is_equal_approx(100.0, 0.001)
			_:
				assert_float(atk).is_equal_approx(100.0, 0.001)


## ⑤ era0 数据表语义：装甲目标对甲防御 > 对轻防御（配对修正方向=硬目标对重火力更抗）
func test_table_semantics_armor_target() -> void:
	var row: Dictionary = UnitStatsTable.derive_defense_by_unit_type(GC.CombatKind.ARMOR, 0, 0)
	assert_float(float(row.get("defense_armor", 0.0))).is_greater(float(row.get("defense_light", 0.0)))
	# 轻装步兵目标：对轻防御 > 对甲防御（打轻装=轻轴，配对不变）
	var inf_row: Dictionary = UnitStatsTable.derive_defense_by_unit_type(GC.CombatKind.LIGHT, 0, 0)
	assert_float(float(inf_row.get("defense_light", 0.0))).is_greater(float(inf_row.get("defense_armor", 0.0)))
