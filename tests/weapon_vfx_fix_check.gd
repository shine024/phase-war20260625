## v15 武器弹道/命中特效配置修复验证
## 修复内容：UCT 特殊 weapon_type（RAIL=11 / OMEGA=10 / SNIPER=6）在槽位层被降级，
## 签名命中特效（磁轨穿透/欧米茄放电）丢失。修复方式：
##   1. CardResource._WEAPON_NAME_TRAJECTORY_OVERRIDE 精确表补签名武器条目；
##   2. 解析器改 static（trajectory_override_for_weapon_name），敌方槽位构建复用同一解析器；
##   3. UCT/敌方 stats 对 >3 的 legacy 弹道值同步记录 legacy_weapon_type（VFX 回退链）。
## 运行：Godot --headless --script tests/weapon_vfx_fix_check.gd
## 注：必须用 _initialize()（autoload 就绪后）而非 _init()——依赖 autoload 的脚本
## （card_resource→ModificationRegistry / enemy_unit→BattleManager）在 _init() 时编译失败。
extends SceneTree

var _pass: int = 0
var _fail: int = 0

func _initialize() -> void:
	print("=== v15 武器弹道/VFX 配置修复验证 ===")
	_test_resolver_exact_table()
	_test_resolver_regressions()
	_test_player_card_slots()
	_test_enemy_slots()
	_test_legacy_weapon_type()
	_summary()
	quit(0 if _fail == 0 else 1)

func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ✅ PASS: " + label)
	else:
		_fail += 1
		print("  ❌ FAIL: " + label)

## [1] 精确表：签名武器 → 专属弹道
func _test_resolver_exact_table() -> void:
	print("\n[1] trajectory_override_for_weapon_name 精确表")
	var CardRes: GDScript = load("res://resources/card_resource.gd")
	_ok(CardRes != null and CardRes.has_method("trajectory_override_for_weapon_name"),
		"card_resource.gd 编译加载成功（static 解析器存在）")
	if CardRes == null or not CardRes.has_method("trajectory_override_for_weapon_name"):
		return
	_ok(CardRes.trajectory_override_for_weapon_name("攻城电磁炮", 0) == 11,
		"攻城电磁炮 → RAIL(11) 磁轨穿透")
	_ok(CardRes.trajectory_override_for_weapon_name("重型等离子加农炮", 0) == 10,
		"重型等离子加农炮 → OMEGA(10) 径向放电")
	_ok(CardRes.trajectory_override_for_weapon_name("磁轨狙击炮", 0) == 6,
		"磁轨狙击炮 → SNIPER(6) 光束")

## [2] 回归：既有映射不被破坏
func _test_resolver_regressions() -> void:
	print("\n[2] 既有映射回归")
	var CardRes: GDScript = load("res://resources/card_resource.gd")
	_ok(CardRes.trajectory_override_for_weapon_name("霰弹枪", 0) == 5, "霰弹枪 → SHOTGUN(5)")
	_ok(CardRes.trajectory_override_for_weapon_name("全装型导弹巢", 0) == 9, "全装型导弹巢 → MISSILE(9)")
	_ok(CardRes.trajectory_override_for_weapon_name("无人机导弹", 0) == -1, "无人机导弹 → 不覆盖（保持 DIRECT）")
	_ok(CardRes.trajectory_override_for_weapon_name("125mm滑膛炮", 0) == -1,
		"125mm滑膛炮 → 不覆盖（坦克炮风味由 DirectWeaponFlavor 处理）")
	_ok(CardRes.trajectory_override_for_weapon_name("粒子束步枪", 0) == 6, "粒子束步枪 → SNIPER(6) 光束关键词")
	_ok(CardRes.trajectory_override_for_weapon_name("227mm火箭炮", 1) == 3, "曲射单位 227mm火箭炮 → ROCKET(3)")
	_ok(CardRes.trajectory_override_for_weapon_name("防空导弹", 1) == 9, "曲射单位 防空导弹 → MISSILE(9)")
	_ok(CardRes.trajectory_override_for_weapon_name("无人机导弹", 1) == 9, "曲射单位 无人机导弹 → MISSILE(9)")

## [3] 玩家卡槽位（UCT 构建链）
func _test_player_card_slots() -> void:
	print("\n[3] 玩家卡槽位弹道")
	var UCT: GDScript = load("res://data/unified_card_table.gd")
	if UCT == null:
		_ok(false, "unified_card_table.gd 编译加载成功")
		return
	_ok(true, "unified_card_table.gd 编译加载成功")
	var omega = UCT.build_card_resource("fut_arm_omega")
	omega._ensure_weapon_slots_initialized()
	_ok(int(omega.weapon_slots[0].weapon_type) == 9, "fut_arm_omega 轻装槽(全装型导弹巢) → MISSILE(9)")
	_ok(int(omega.weapon_slots[1].weapon_type) == 11, "fut_arm_omega 装甲槽(攻城电磁炮) → RAIL(11)")
	var colossus = UCT.build_card_resource("fut_colossus")
	colossus._ensure_weapon_slots_initialized()
	_ok(int(colossus.weapon_slots[1].weapon_type) == 11, "fut_colossus 装甲槽(攻城电磁炮) → RAIL(11)")
	var nexus = UCT.build_card_resource("fut_arm_nexus")
	nexus._ensure_weapon_slots_initialized()
	_ok(int(nexus.weapon_slots[0].weapon_type) == 0, "fut_arm_nexus 轻装槽(125mm滑膛炮) → DIRECT(0)")
	_ok(int(nexus.weapon_slots[1].weapon_type) == 10, "fut_arm_nexus 装甲槽(重型等离子加农炮) → OMEGA(10)")

## [4] 敌方槽位（_ensure_enemy_weapon_slots 真实链路；纯数据构建，不进节点树）
func _test_enemy_slots() -> void:
	print("\n[4] 敌方槽位弹道")
	var eu_script: GDScript = load("res://scenes/units/enemy_unit.gd")
	if eu_script == null:
		_ok(false, "enemy_unit.gd 编译加载成功")
		return
	_ok(true, "enemy_unit.gd 编译加载成功")
	var eu = eu_script.new()
	# v9.x 已把 UCT weapon_type 归一为 4 值新枚举（colossus_e wt=0）——
	# RAIL/OMEGA 弹道完全由武器名精确表在槽位层恢复（v15 修复真身）
	var colossus_e: UnitStats = _make_enemy_stats(0, "攻城电磁炮", 280.0, 1260.0, 0.0)
	eu._ensure_enemy_weapon_slots(colossus_e)
	_ok(int(colossus_e.weapon_slots[0].weapon_type) == 11, "fut_arm_colossus_e 轻装槽 → RAIL(11)")
	_ok(int(colossus_e.weapon_slots[1].weapon_type) == 11, "fut_arm_colossus_e 装甲槽 → RAIL(11)")
	_ok(not colossus_e.weapon_slots[2].enabled, "fut_arm_colossus_e 对空槽 disabled(atk_air=0)")

	var boss: UnitStats = _make_enemy_stats(1, "重型等离子加农炮", 504.0, 2250.0, 76.0)
	eu._ensure_enemy_weapon_slots(boss)
	_ok(int(boss.weapon_slots[0].weapon_type) == 10, "fut_boss_nexus 轻装槽 → OMEGA(10)")
	_ok(int(boss.weapon_slots[1].weapon_type) == 10, "fut_boss_nexus 装甲槽 → OMEGA(10)")
	_ok(int(boss.weapon_slots[2].weapon_type) == 10, "fut_boss_nexus 对空槽 → OMEGA(10)（精确表统一）")

	var rider: UnitStats = _make_enemy_stats(0, "磁轨狙击炮", 280.0, 84.0, 0.0)
	eu._ensure_enemy_weapon_slots(rider)
	_ok(int(rider.weapon_slots[0].weapon_type) == 6, "fut_inf_storm_rider 轻装槽 → SNIPER(6)")
	_ok(int(rider.weapon_slots[1].weapon_type) == 6, "fut_inf_storm_rider 装甲槽 → SNIPER(6)")

	var himars: UnitStats = _make_enemy_stats(1, "227mm火箭炮", 125.0, 625.0, 25.0)
	eu._ensure_enemy_weapon_slots(himars)
	_ok(int(himars.weapon_slots[0].weapon_type) == 3, "HIMARS 曲射槽(227mm火箭炮) → ROCKET(3)（回归）")

	var drone: UnitStats = _make_enemy_stats(0, "无人机导弹", 135.0, 115.0, 0.0)
	eu._ensure_enemy_weapon_slots(drone)
	_ok(int(drone.weapon_slots[0].weapon_type) == 0, "无人机群 直射单位(无人机导弹) → DIRECT(0)（回归）")

	var beam_arty: UnitStats = _make_enemy_stats(1, "HEL-30激光阵列", 200.0, 300.0, 0.0)
	eu._ensure_enemy_weapon_slots(beam_arty)
	_ok(int(beam_arty.weapon_slots[0].weapon_type) == 6, "HEL-30 曲射单位光束武器 → SNIPER(6)（v9.x 回归）")
	eu.free()

## [5] legacy_weapon_type 记录（VFX 回退链 / 信息面板）
func _test_legacy_weapon_type() -> void:
	print("\n[5] legacy_weapon_type 同步记录")
	var UCT: GDScript = load("res://data/unified_card_table.gd")
	# v9.x 已归一 UCT weapon_type 为 4 值枚举——用合成条目验证 v15 的 >3 记录逻辑
	var synth = UCT._entry_to_card({"card_id": "_synth_rail", "weapon_type": 11})
	_ok(int(synth.legacy_weapon_type) == 11, "合成条目 weapon_type=11 → legacy_weapon_type=11")
	var synth2 = UCT._entry_to_card({"card_id": "_synth_omega", "weapon_type": 10})
	_ok(int(synth2.legacy_weapon_type) == 10, "合成条目 weapon_type=10 → legacy_weapon_type=10")
	var mp18 = UCT.build_card_resource("ww1_mp18")
	_ok(int(mp18.legacy_weapon_type) == -1, "普通卡(新枚举 wt=0) legacy_weapon_type 保持 -1（不误设）")
	var ce = UCT.build_card_resource("fut_arm_colossus_e")
	_ok(int(ce.legacy_weapon_type) == -1, "v9.x 归一后的 colossus_e(wt=0) legacy=-1（RAIL 由武器名精确表提供）")

func _make_enemy_stats(wt: int, label: String, atk_l: float, atk_a: float, atk_air: float) -> UnitStats:
	var s: UnitStats = UnitStats.new()
	s.weapon_type = wt
	s.weapon_label = label
	s.attack_light = atk_l
	s.attack_armor = atk_a
	s.attack_air = atk_air
	s.attack_light_speed = 1.0
	s.attack_armor_speed = 1.0
	s.attack_air_speed = 1.0
	s.attack_range = 400.0
	return s

func _summary() -> void:
	print("\n=== 测试总结 ===")
	print("  通过: %d" % _pass)
	print("  失败: %d" % _fail)
	if _fail == 0:
		print("  🎉 全部通过！")
	else:
		print("  ⚠️ 有失败项需检查")
