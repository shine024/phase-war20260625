# v6.6 改造系统统一：战斗落地 + 存档迁移 校验（无 GdUnit 依赖）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/v66_mod_landing_smoke.gd
extends SceneTree

const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
const SaveMigrationV6 = preload("res://scripts/systems/save_migration_v6.gd")
const CardResource = preload("res://resources/card_resource.gd")


func _initialize() -> void:
	var code: int = 0
	# 确保 ModificationRegistry 已初始化（autoload 在 SceneTree 脚本模式下可能未跑 _ready）
	ModificationRegistry.register_all()

	# ── 测试1：装 gen_04_vest 后 max_hp / defense_light 应被修正 ──
	print("[v6.6] 测试1：改造模块战斗落地（gen_04_vest）")
	var card := _make_test_card()
	var base_hp: float = 0.0
	var base_def_light: float = 0.0
	{
		var st_base: UnitStats = UnitStatsTable.build_stats_from_card(card, 0)
		base_hp = st_base.max_hp
		base_def_light = st_base.defense_light
	}
	# 装上 gen_04_vest（effects = {max_hp=0.10, defense_light=0.05}）
	card.mods.append({id = "gen_04_vest", enabled = true})
	var st_modded: UnitStats = UnitStatsTable.build_stats_from_card(card, 0)
	# max_hp 应增加约 10%（int 截断）
	if st_modded.max_hp <= base_hp:
		push_error("[v6.6] 改造落地失败：max_hp 未增加（base=%.1f, modded=%.1f）" % [base_hp, st_modded.max_hp])
		code = 1
	else:
		print("  ✓ max_hp: %.1f → %.1f（+%.1f）" % [base_hp, st_modded.max_hp, st_modded.max_hp - base_hp])
	# defense_light 应增加约 5%
	if st_modded.defense_light <= base_def_light:
		push_error("[v6.6] 改造落地失败：defense_light 未增加（base=%.1f, modded=%.1f）" % [base_def_light, st_modded.defense_light])
		code = 1
	else:
		print("  ✓ defense_light: %.1f → %.1f（+%.1f）" % [base_def_light, st_modded.defense_light, st_modded.defense_light - base_def_light])

	# ── 测试2：MOD_01 在新系统查不到（应返回空）—— 证明旧系统失效 ──
	print("[v6.6] 测试2：旧 MOD_01 在 ModificationRegistry 查不到（断链证据）")
	var mod01_data: Dictionary = ModificationRegistry.get_data("MOD_01")
	if not mod01_data.is_empty():
		push_error("[v6.6] 意外：MOD_01 不应存在于 ModificationRegistry（说明旧系统残留）")
		code = 1
	else:
		print("  ✓ MOD_01 在 ModificationRegistry 中查不到（确认旧系统断链）")

	# ── 测试3：140+ 模块可查到（证明新系统健康） ──
	print("[v6.6] 测试3：140+ 模块在 ModificationRegistry 可查到")
	var gen04_data: Dictionary = ModificationRegistry.get_data("gen_04_vest")
	if gen04_data.is_empty():
		push_error("[v6.6] gen_04_vest 应可查到")
		code = 1
	else:
		print("  ✓ gen_04_vest 可查到，name=%s" % String(gen04_data.get("name", "")))

	# ── 测试4：存档迁移 MOD_01 → 140+ 模块 ──
	print("[v6.6] 测试4：存档迁移 v5→v6（MOD_01 → 140+ 模块）")
	var fake_save: Dictionary = {
		"schema_version": 5,
		"blueprint": {
			"blueprint_mods": {
				# 用一个已注册的卡 ID（omega_platform 是初始卡）
				"omega_platform": [
					{id = "MOD_01"},        # 火力改造 → 应迁移到 inf_02_assault_rifle（轻装）
					{id = "MOD_02"},        # 装甲改造 → 应迁移到 inf_11_armor_insert
					{id = "gen_04_vest"},   # 已是新系统，应保持不变
				]
			}
		}
	}
	SaveMigrationV6.migrate_v5_to_v6(fake_save, true)
	var migrated_mods: Array = fake_save["blueprint"]["blueprint_mods"]["omega_platform"]
	var has_mod01: bool = false
	var has_new_id: bool = false
	for entry in migrated_mods:
		var eid: String = String(entry.get("id", "")) if entry is Dictionary else String(entry)
		if eid == "MOD_01":
			has_mod01 = true
		if not eid.begins_with("MOD_"):
			has_new_id = true
	if has_mod01:
		push_error("[v6.6] 迁移失败：仍存在 MOD_01")
		code = 1
	else:
		print("  ✓ MOD_01 已迁移，新 ID 列表：%s" % str(_extract_ids(migrated_mods)))
	if not has_new_id:
		push_error("[v6.6] 迁移失败：无新系统 ID")
		code = 1

	# ── 测试5：needs_migration 检测 ──
	print("[v6.6] 测试5：needs_migration 检测")
	var needs: bool = SaveMigrationV6.needs_migration({
		"blueprint": {"blueprint_mods": {"x": [{id = "MOD_05"}]}}
	})
	if not needs:
		push_error("[v6.6] needs_migration 应返回 true（含 MOD_）")
		code = 1
	else:
		print("  ✓ needs_migration 正确检测到 MOD_ 前缀")
	var needs_clean: bool = SaveMigrationV6.needs_migration({
		"blueprint": {"blueprint_mods": {"x": [{id = "gen_04_vest"}]}}
	})
	if needs_clean:
		push_error("[v6.6] needs_migration 应返回 false（无 MOD_）")
		code = 1
	else:
		print("  ✓ needs_migration 正确返回 false（仅含新系统 ID）")

	# ── 测试6：accuracy_bonus 软特性补全（映射到 crit_chance） ──
	print("[v6.6] 测试6：accuracy_bonus 软特性补全")
	var result: Dictionary = ModificationRegistry.apply_with_level(
		{crit_chance = 0.0},
		[{id = "aa_01_radar", level = 1}]  # aa_01_radar 的 effects 含 accuracy_bonus
	)
	var crit_after: float = float(result.get("crit_chance", 0.0))
	# aa_01_radar.effects = {accuracy_bonus = ..., attack_interval = -0.3}
	# accuracy_bonus 应被映射到 crit_chance
	if crit_after <= 0.0:
		push_error("[v6.6] accuracy_bonus 未补全：crit_chance 仍为 0（应 > 0）")
		code = 1
	else:
		print("  ✓ accuracy_bonus 映射到 crit_chance = %.3f" % crit_after)

	# ── 结论 ──
	if code == 0:
		print("\n[v6.6] ✅ 全部测试通过")
	else:
		print("\n[v6.6] ❌ 有测试失败（见上方错误）")
	quit(code)


func _make_test_card() -> CardResource:
	# 用 DefaultCards 的一个已注册卡（omega_platform 是初始卡）
	var card := DefaultCards.get_card_by_id("omega_platform")
	if card != null:
		return card
	# 兜底：构造一个最小卡
	var c := CardResource.new()
	c.card_id = "test_mod_card"
	c.combat_kind = 0  # LIGHT
	c.max_hp = 100.0
	c.attack_light = 10.0
	c.attack_armor = 5.0
	c.attack_air = 0.0
	c.defense_light = 20.0
	c.defense_armor = 10.0
	c.defense_air = 5.0
	c.attack_range = 120.0
	c.attack_interval = 1.0
	c.move_speed = 80.0
	return c


func _extract_ids(mods: Array) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for entry in mods:
		var eid: String = String(entry.get("id", "")) if entry is Dictionary else String(entry)
		ids.append(eid)
	return ids
