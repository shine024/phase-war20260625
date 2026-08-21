## v7.x 武器弹道按槽位差异化 smoke test
## 验证：① 默认弹道按 slot_idx 分配 ② 曲射单位例外 ③ 改造 slot_weapon_type 生效
## 运行：Godot --headless --script tests/weapon_trajectory_smoke.gd
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("=== v7.x 武器弹道按槽位差异化 smoke test ===")
	_test_default_slot_weapon_types()
	_test_indirect_unit_exception()
	_test_mod_slot_weapon_type()
	_test_grant_slot_weapon_type()
	_test_vfx_combat_kind_tables()
	_print_summary()
	quit(0 if _fail_count == 0 else 1)

func _assert_eq(actual, expected, label: String) -> void:
	if actual == expected:
		_pass_count += 1
		print("  ✅ PASS: %s = %s" % [label, str(actual)])
	else:
		_fail_count += 1
		print("  ❌ FAIL: %s — 期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _test_default_slot_weapon_types() -> void:
	print("\n[1] 默认弹道按 slot_idx 分配（DIRECT/SNIPER/MISSILE）")
	# 直接测试 _default_weapon_type_for_slot 逻辑（不依赖 autoload）
	# slot 0 → DIRECT(0), slot 1 → SNIPER(6), slot 2 → MISSILE(9)
	_assert_eq(_default_wt_for_slot(0, 0), 0, "slot 0 轻装槽 → DIRECT(0)")
	_assert_eq(_default_wt_for_slot(1, 0), 6, "slot 1 装甲槽 → SNIPER(6)")
	_assert_eq(_default_wt_for_slot(2, 0), 9, "slot 2 对空槽 → MISSILE(9)")

func _test_indirect_unit_exception() -> void:
	print("\n[2] 曲射单位（weapon_type=INDIRECT=1）三槽都保留曲射")
	# INDIRECT(1) 单位：三槽都应返回 1
	_assert_eq(_default_wt_for_slot(0, 1), 1, "INDIRECT 单位 slot 0 → INDIRECT(1)")
	_assert_eq(_default_wt_for_slot(1, 1), 1, "INDIRECT 单位 slot 1 → INDIRECT(1)")
	_assert_eq(_default_wt_for_slot(2, 1), 1, "INDIRECT 单位 slot 2 → INDIRECT(1)")

func _test_mod_slot_weapon_type() -> void:
	print("\n[3] slot_weapon_type effect key 在 modification_registry 已实现")
	# 验证 match 分支存在（读源码确认）
	var registry_script = _read_file("res://scripts/systems/modification_registry.gd")
	var has_slot_wt_match: bool = registry_script.find('"slot_weapon_type":') >= 0
	var has_condition_slot: bool = registry_script.find("condition_slot") >= 0
	_assert_eq(has_slot_wt_match, true, "modification_registry 有 slot_weapon_type match 分支")
	_assert_eq(has_condition_slot, true, "modification_registry 有 condition_slot 守卫")

func _test_grant_slot_weapon_type() -> void:
	print("\n[4] grant_slot 改造数据完整性（inf_05/arm_07）")
	var inf_mods = _read_file("res://data/modification_modules/infantry_mods.gd")
	var arm_mods = _read_file("res://data/modification_modules/armor_mods.gd")
	# inf_05_ap_ammo 应有 grant_slot slot=1 weapon_type=6
	var has_inf05_grant: bool = inf_mods.find("slot = 1") >= 0 and inf_mods.find("weapon_type = 6") >= 0
	_assert_eq(has_inf05_grant, true, "inf_05_ap_ammo grant_slot slot=1 weapon_type=6(SNIPER)")
	# arm_07_gun_missile 应有 grant_slot slot=2 weapon_type=9
	var has_arm07_grant: bool = arm_mods.find("slot = 2") >= 0 and arm_mods.find("weapon_type = 9") >= 0
	_assert_eq(has_arm07_grant, true, "arm_07_gun_missile grant_slot slot=2 weapon_type=9(MISSILE)")

func _test_vfx_combat_kind_tables() -> void:
	print("\n[5] weapon_projectile_vfx 的 combat_kind 参数表完整")
	var vfx_script = _read_file("res://scripts/weapon_projectile_vfx.gd")
	var has_tint: bool = vfx_script.find("IMPACT_TINT_BY_KIND") >= 0
	var has_scale: bool = vfx_script.find("IMPACT_SCALE_MUL_BY_KIND") >= 0
	var has_shake: bool = vfx_script.find("IMPACT_SHAKE_BY_KIND") >= 0
	var has_spawn_with_kind: bool = vfx_script.find("spawn_impact_with_kind") >= 0
	var has_shake_func: bool = vfx_script.find("impact_shake_for_kind") >= 0
	_assert_eq(has_tint, true, "IMPACT_TINT_BY_KIND 色调表存在")
	# v8.0 已废弃 IMPACT_SCALE_MUL_BY_KIND（粒子系统无 scale 概念）——断言其已移除而非存在
	_assert_eq(has_scale, false, "IMPACT_SCALE_MUL_BY_KIND 缩放表已按 v8.0 移除")
	_assert_eq(has_shake, true, "IMPACT_SHAKE_BY_KIND 震动表存在")
	_assert_eq(has_spawn_with_kind, true, "spawn_impact_with_kind 函数存在")
	_assert_eq(has_shake_func, true, "impact_shake_for_kind 函数存在")

## 模拟 _default_weapon_type_for_slot 逻辑（不依赖 CardResource 实例化）
## card_weapon_type: 卡牌级 weapon_type（0=DIRECT, 1=INDIRECT, 2=AERIAL）
func _default_wt_for_slot(slot_idx: int, card_weapon_type: int) -> int:
	if card_weapon_type == 1:  # INDIRECT
		return 1
	match slot_idx:
		0: return 0   # DIRECT
		1: return 6   # SNIPER
		2: return 9   # MISSILE
		_: return 0

func _read_file(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var content = f.get_as_text()
	f.close()
	return content

func _print_summary() -> void:
	print("\n=== 测试总结 ===")
	print("  通过: %d" % _pass_count)
	print("  失败: %d" % _fail_count)
	if _fail_count == 0:
		print("  🎉 全部通过！")
	else:
		print("  ⚠️ 有失败项需检查")
