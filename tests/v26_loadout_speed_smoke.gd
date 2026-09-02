## v26.2 敌方配装频率轴 smoke：attack_interval 白名单 + 攻速武器槽落地链
## 验证四件事：
##   1. 白名单含 attack_interval（敌方配装可带攻速键）
##   2. 玩家构建链：card.mods 的 attack_interval 改造 → weapon_slots[].attack_speed 实际提升
##      （timing 主路径读武器槽速度——此前只写 stats 侧实战空转，敌我同构存量 P1）
##   3. 敌方挂载链：_apply_mod_stat_effects + 速度比值同步 → 武器槽速度提升
##   4. 配装表确有条目使用攻速件（机制非死代码）
extends SceneTree

const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const EnemyFixedLoadouts = preload("res://data/enemy_fixed_loadouts.gd")
const CardResource = preload("res://resources/card_resource.gd")
const GC = preload("res://resources/game_constants.gd")

func _initialize() -> void:
	var fails: Array = []
	var fail := func(msg: String) -> void:
		fails.append(msg)
		push_error("[FAIL] " + msg)
		print("  ❌ " + msg)

	print("=== 1. 白名单含 attack_interval ===")
	if EnemyFixedLoadouts.LOADOUT_MOD_SUPPORTED_KEYS.has("attack_interval"):
		print("  ✓ LOADOUT_MOD_SUPPORTED_KEYS 已含 attack_interval")
	else:
		fail.call("白名单缺 attack_interval（敌方配装频率轴未开）")

	print("")
	print("=== 2. 玩家构建链：攻速改造 → 武器槽速度 ===")
	var mk_card := func() -> CardResource:
		var c := CardResource.new()
		c.card_type = GC.CardType.COMBAT_UNIT
		c.era = 1
		c.combat_kind = 0
		c.attack_light = 40.0
		c.attack_armor = 10.0
		c.attack_air = 0.0
		c.attack_light_speed = 1.0
		c.attack_armor_speed = 1.0
		c.attack_air_speed = 1.0
		return c
	var base_card: CardResource = mk_card.call()
	var base_stats = UnitStatsTable.build_stats_from_card(base_card)
	var base_slot_speed: float = float(base_stats.weapon_slots[0].attack_speed)
	var mod_card: CardResource = mk_card.call()
	mod_card.mods = [{"id": "enh_atkspd_up", "level": 3, "enabled": true}]
	var mod_stats = UnitStatsTable.build_stats_from_card(mod_card)
	var mod_slot_speed: float = float(mod_stats.weapon_slots[0].attack_speed)
	var ratio: float = mod_slot_speed / base_slot_speed if base_slot_speed > 0.0 else 0.0
	print("  基础槽速=%.3f 装后槽速=%.3f 比值=%.3f（enh_atkspd_up Lv3 期望 ≈1.17）" % [
		base_slot_speed, mod_slot_speed, ratio])
	if ratio < 1.10 or ratio > 1.25:
		fail.call("玩家构建链攻速未落地武器槽：比值 %.3f（期望≈1.17）" % ratio)
	if absf(float(mod_stats.attack_light_speed) / 1.0 - 1.17) > 0.02:
		fail.call("stats 轴攻速异常：attack_light_speed=%.3f（期望≈1.17）" % mod_stats.attack_light_speed)

	print("")
	print("=== 3. 敌方挂载链：apply + 同步 → 武器槽速度 ===")
	var enemy_card: CardResource = mk_card.call()
	enemy_card.combat_kind = 4
	var estats = UnitStatsTable.build_stats_from_card(enemy_card)
	var pre_spd: Array = [estats.attack_light_speed, estats.attack_armor_speed, estats.attack_air_speed]
	var pre_slot: float = float(estats.weapon_slots[0].attack_speed)
	UnitStatsTable._apply_mod_stat_effects(estats, [{"id": "aa_04_quad_mount", "level": 3, "enabled": true}], 1)
	UnitStatsTable._sync_mod_speed_ratio_to_weapon_slots(estats, estats.weapon_slots, pre_spd)
	var post_slot: float = float(estats.weapon_slots[0].attack_speed)
	var eratio: float = post_slot / pre_slot if pre_slot > 0.0 else 0.0
	print("  挂载前槽速=%.3f 挂载后槽速=%.3f 比值=%.3f（aa_04 四联装 -0.30 期望 ≈1.30（speed ×(1-(-0.30))））" % [
		pre_slot, post_slot, eratio])
	if eratio < 1.25 or eratio > 1.35:
		fail.call("敌方挂载链攻速未落地武器槽：比值 %.3f（期望≈1.30）" % eratio)

	print("")
	print("=== 4. 配装表攻速件使用面 ===")
	var spd_ids: Array = ["aa_04_quad_mount", "aa_11_auto_fc", "enh_atkspd_up"]
	var used: int = 0
	for aid in EnemyFixedLoadouts.LOADOUTS.keys():
		var entry: Dictionary = EnemyFixedLoadouts.LOADOUTS[aid]
		for mid in entry.get("mods", []):
			if spd_ids.has(String(mid)):
				used += 1
				break
	print("  含攻速件的配装条目：%d / %d" % [used, EnemyFixedLoadouts.LOADOUTS.size()])
	if used < 5:
		fail.call("配装表攻速件覆盖过少（%d 条，机制形同虚设）" % used)

	print("")
	print("════════════════════════════════════════")
	if fails.is_empty():
		print("✅ 全部 PASS（4 项验证）")
	else:
		print("❌ %d 项 FAIL" % fails.size())
	print("════════════════════════════════════════")
	quit(0 if fails.is_empty() else 1)
