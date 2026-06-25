extends SceneTree
## v6.13 独立运行时验证：grant_slot 赋予新攻击维度
## 覆盖：arm_07_gun_missile（炮射导弹→对空）、inf_05_ap_ammo（穿甲弹→对装甲）
## 用法：
##   & Godot --headless --rendering-driver opengl3 --path "." --script "tests/v613_grant_slot_check.gd"

const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
const ArmorModifications = preload("res://data/modification_modules/armor_mods.gd")

func _initialize() -> void:
	var code: int = 0

	# 确保 ModificationRegistry 已初始化（SceneTree 脚本模式 autoload _ready 不跑）
	ModificationRegistry.register_all()

	print("════════════════════════════════════════")
	print("  v6.13 grant_slot 对空攻击维度验证")
	print("════════════════════════════════════════")

	var passed := 0
	var failed := 0

	# ── 测试0: arm_07 grant_slot 数据完整性 ──
	var arm07_data := ModificationRegistry.get_data("arm_07_gun_missile")
	if arm07_data.is_empty():
		print("✗ FAIL [T0] arm_07 数据查不到")
		failed += 1
		code = 1
	else:
		var grant: Dictionary = arm07_data.get("grant_slot", {})
		if grant.is_empty():
			print("✗ FAIL [T0] arm_07 缺 grant_slot 字段")
			failed += 1
			code = 1
		else:
			print("✓ PASS [T0] arm_07 grant_slot 完整: slot=%d ratio=%.1f" % [int(grant.get("slot", -1)), float(grant.get("damage_ratio", 0))])
			passed += 1

	# ── 测试1: cold_t72 装炮射导弹 ──
	var t72_card: CardResource = DefaultCards.get_card_by_id("cold_t72") as CardResource
	if t72_card == null:
		print("✗ FAIL: 找不到 cold_t72 卡牌")
		failed += 1
		code = 1
	else:
		var card_with_mod: CardResource = t72_card.clone()
		card_with_mod.mods = [{"id": "arm_07_gun_missile", "level": 1}]
		var stats: UnitStats = UnitStatsTable.build_stats_from_card(card_with_mod)

		# 对空槽（index 2）
		if stats.weapon_slots.size() < 3:
			print("✗ FAIL [T1.1] weapon_slots 数量不足 3，实际 %d" % stats.weapon_slots.size())
			failed += 1
			code = 1
		else:
			var air_slot: WeaponResource = stats.weapon_slots[2] as WeaponResource
			if air_slot.enabled and air_slot.damage > 0:
				print("✓ PASS [T1.1] 对空槽已激活: enabled=%s damage=%.1f" % [air_slot.enabled, air_slot.damage])
				passed += 1
			else:
				print("✗ FAIL [T1.1] 对空槽未激活: enabled=%s damage=%.1f" % [air_slot.enabled, air_slot.damage])
				failed += 1
				code = 1

			# 对空伤害 ≈ attack_armor(加成后) × 0.8
			# arm_07 effects: attack_armor=0.20 → 加成后 stats.attack_armor = base × 1.20
			var expected_air: float = stats.attack_armor * 0.8
			var diff: float = absf(air_slot.damage - expected_air)
			if diff < 1.0:
				print("✓ PASS [T1.2] 对空伤害派生正确: %.1f ≈ attack_armor(%.1f)×0.8=%.1f" % [air_slot.damage, stats.attack_armor, expected_air])
				passed += 1
			else:
				print("✗ FAIL [T1.2] 对空伤害偏差过大: %.1f vs 期望 %.1f (attack_armor=%.1f)" % [air_slot.damage, expected_air, stats.attack_armor])
				failed += 1
				code = 1

			# 武器参数检查
			if air_slot.attack_speed > 0 and air_slot.attack_speed < 1.0:
				print("✓ PASS [T1.3] 导弹攻速(慢): speed=%.2f" % air_slot.attack_speed)
				passed += 1
			else:
				print("✗ FAIL [T1.3] 攻速异常: speed=%.2f" % air_slot.attack_speed)
				failed += 1
				code = 1

			if air_slot.weapon_type == 9:  # MISSILE
				print("✓ PASS [T1.4] 弹道类型=MISSILE(9)")
				passed += 1
			else:
				print("✗ FAIL [T1.4] 弹道类型异常: weapon_type=%d" % air_slot.weapon_type)
				failed += 1
				code = 1

			if air_slot.display_name == "炮射导弹":
				print("✓ PASS [T1.5] 武器名称: %s" % air_slot.display_name)
				passed += 1
			else:
				print("✗ FAIL [T1.5] 武器名称异常: %s" % air_slot.display_name)
				failed += 1
				code = 1

	# ── 测试2: 未装改造的 cold_t72 对空槽仍为空（向后兼容）──
	if t72_card != null:
		var bare_stats: UnitStats = UnitStatsTable.build_stats_from_card(t72_card)
		if bare_stats.weapon_slots.size() >= 3:
			var bare_air: WeaponResource = bare_stats.weapon_slots[2] as WeaponResource
			if not bare_air.enabled or bare_air.damage <= 0:
				print("✓ PASS [T2] 未装改造的对空槽保持空: enabled=%s damage=%.1f" % [bare_air.enabled, bare_air.damage])
				passed += 1
			else:
				print("✗ FAIL [T2] 未装改造却激活了对空槽: enabled=%s damage=%.1f" % [bare_air.enabled, bare_air.damage])
				failed += 1
				code = 1

	# ── 测试3: 防空兵(已有对空能力)对空槽不受影响 ──
	var aa_card: CardResource = DefaultCards.get_card_by_id("mod_m6") as CardResource
	if aa_card != null:
		var aa_stats: UnitStats = UnitStatsTable.build_stats_from_card(aa_card)
		if aa_stats.weapon_slots.size() >= 3:
			var aa_air: WeaponResource = aa_stats.weapon_slots[2] as WeaponResource
			if aa_air.enabled and aa_air.damage > 100:  # M6 本身 attack_air=840
				print("✓ PASS [T3] 防空兵对空槽未受影响: damage=%.1f" % aa_air.damage)
				passed += 1
			else:
				print("✗ FAIL [T3] 防空兵对空槽异常: enabled=%s damage=%.1f" % [aa_air.enabled, aa_air.damage])
				failed += 1
				code = 1

	# ── 测试5: 纯步枪兵(mod_marine)装穿甲弹(inf_05_ap_ammo)激活对装甲槽 ──
	# mod_marine 是纯步枪班：attack_light=140, attack_armor=0 → 原穿甲弹失效
	var marine_card: CardResource = DefaultCards.get_card_by_id("mod_marine") as CardResource
	if marine_card != null:
		var ap_card: CardResource = marine_card.clone()
		ap_card.mods = [{"id": "inf_05_ap_ammo", "level": 1}]
		var ap_stats: UnitStats = UnitStatsTable.build_stats_from_card(ap_card)
		if ap_stats.weapon_slots.size() >= 3:
			var armor_slot: WeaponResource = ap_stats.weapon_slots[1] as WeaponResource
			# 对装甲伤害 ≈ attack_light(加成后) × 0.5
			# inf_05 effects: attack_light=-0.10 → 加成后 attack_light = 140 × 0.9 = 126
			# 对装甲 = 126 × 0.5 = 63
			if armor_slot.enabled and armor_slot.damage > 0:
				var expected_armor: float = ap_stats.attack_light * 0.5
				var diff5: float = absf(armor_slot.damage - expected_armor)
				if diff5 < 1.0:
					print("✓ PASS [T5.1] 步枪兵装穿甲弹激活对装甲槽: damage=%.1f ≈ attack_light(%.1f)×0.5" % [armor_slot.damage, ap_stats.attack_light])
					passed += 1
				else:
					print("✗ FAIL [T5.1] 对装甲伤害偏差: %.1f vs 期望 %.1f" % [armor_slot.damage, expected_armor])
					failed += 1
					code = 1
			else:
				print("✗ FAIL [T5.1] 对装甲槽未激活: enabled=%s damage=%.1f" % [armor_slot.enabled, armor_slot.damage])
				failed += 1
				code = 1
			# 副作用：attack_light 应下降约10%
			var bare_marine_stats: UnitStats = UnitStatsTable.build_stats_from_card(marine_card)
			if ap_stats.attack_light < bare_marine_stats.attack_light:
				print("✓ PASS [T5.2] 穿甲弹副作用生效: attack_light %.1f→%.1f" % [bare_marine_stats.attack_light, ap_stats.attack_light])
				passed += 1
			else:
				print("✗ FAIL [T5.2] 副作用未生效: attack_light %.1f→%.1f" % [bare_marine_stats.attack_light, ap_stats.attack_light])
				failed += 1
				code = 1

	# ── 测试6: 反坦克组(已有对装甲能力)装穿甲弹不影响现有槽（向后兼容）──
	# mod_javelin: attack_light=25, attack_armor=250 → 原有对装甲槽，装穿甲弹应保持（不应被grant覆盖成低值）
	var javelin_card: CardResource = DefaultCards.get_card_by_id("mod_javelin") as CardResource
	if javelin_card != null:
		var jav_ap_card: CardResource = javelin_card.clone()
		jav_ap_card.mods = [{"id": "inf_05_ap_ammo", "level": 1}]
		var jav_ap_stats: UnitStats = UnitStatsTable.build_stats_from_card(jav_ap_card)
		if jav_ap_stats.weapon_slots.size() >= 3:
			var jav_armor_slot: WeaponResource = jav_ap_stats.weapon_slots[1] as WeaponResource
			# javelin 原本 attack_armor=250，对装甲槽应保持高伤害（不被 grant 的 0.5× 覆盖）
			# grant_slot 在已有武器时不覆盖，只激活空槽
			if jav_armor_slot.enabled and jav_armor_slot.damage > 100:
				print("✓ PASS [T6] 反坦克组装穿甲弹保留原对装甲槽: damage=%.1f（不被grant覆盖）" % jav_armor_slot.damage)
				passed += 1
			else:
				print("✗ FAIL [T6] 反坦克组对装甲槽异常: damage=%.1f（应保留原值）" % jav_armor_slot.damage)
				failed += 1
				code = 1

	# ── 测试4: 战斗路径能取到对空武器 ──
	# 模拟 AttackCalculator.get_weapon_for_target(AIR) 的行为
	if t72_card != null:
		var mod_card: CardResource = t72_card.clone()
		mod_card.mods = [{"id": "arm_07_gun_missile", "level": 1}]
		var mod_stats: UnitStats = UnitStatsTable.build_stats_from_card(mod_card)
		var air_weapon: WeaponResource = mod_stats.get_weapon_for_target(GC.CombatKind.AIR)
		if air_weapon != null and air_weapon.enabled and air_weapon.damage > 0:
			print("✓ PASS [T4] get_weapon_for_target(AIR) 返回有效武器: damage=%.1f" % air_weapon.damage)
			passed += 1
		else:
			print("✗ FAIL [T4] get_weapon_for_target(AIR) 返回空或无效: %s" % str(air_weapon))
			failed += 1
			code = 1

	# ── 汇总 ──
	print("────────────────────────────────────────")
	print("  结果: %d 通过 / %d 失败" % [passed, failed])
	if failed == 0:
		print("  ★ 全部通过 — grant_slot 对空攻击维度生效")
	else:
		print("  ✗ 存在失败项")
	print("════════════════════════════════════════")

	quit(code)
