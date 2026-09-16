extends GdUnitTestSuite
## v6.14.7 部署次数池兑底回归锁：captured_*/foe_* 缴获卡、fe_* 势力卡等
## UCT 直查落空的卡必须入池可部署（修复前跳过=池无键="次数耗尽"硬拒）。
## _resolve_deploy_uses_entry 仅依赖 UnifiedCardTable 与卡字段，无 autoload 依赖。

const SpawnSystem = preload("res://managers/battle/battle_spawn_system.gd")
const UCT = preload("res://data/unified_card_table.gd")
const GC = preload("res://resources/game_constants.gd")


class MockPI extends Node:
	var los: Array = []
	func get_loadouts() -> Array:
		return los


func _make_captured(bare_id: String) -> CardResource:
	# 与 captured_unit_cards._build_captured_card 同口径：数值=统一表真身，
	# card_id 保留 captured_ 前缀（存档兼容），实例卡 instance_id 为空
	var card: CardResource = UCT.build_card_resource(bare_id)
	card.card_id = "captured_" + bare_id
	card.instance_id = ""
	return card


func test_captured_card_resolves_real_entry() -> void:
	var spawn = SpawnSystem.new()
	var card := _make_captured("ww1_inf_storm_e")
	var entry: Dictionary = spawn._resolve_deploy_uses_entry(card)
	assert_dict(entry).is_not_empty()
	assert_dict(entry).is_equal(UCT.get_entry("ww1_inf_storm_e"))


func test_captured_foe_prefix_also_stripped() -> void:
	# drop_id 还有 "captured_foe_<id>" 形态（captured_unit_cards 双重剥前缀）
	var spawn = SpawnSystem.new()
	var card := _make_captured("ww1_inf_storm_e")
	card.card_id = "captured_foe_ww1_inf_storm_e"
	assert_dict(spawn._resolve_deploy_uses_entry(card)).is_equal(UCT.get_entry("ww1_inf_storm_e"))


func test_unknown_id_falls_back_to_combat_kind_baseline() -> void:
	# fe_* 势力卡不在 UCT：兑底条目必须携带卡自身 combat_kind（走兵种基线次数）
	var spawn = SpawnSystem.new()
	var card: CardResource = CardResource.new()
	card.card_id = "fe_iron_wall_bastion"
	card.combat_kind = GC.CombatKind.FORT
	card.instance_id = ""
	var entry: Dictionary = spawn._resolve_deploy_uses_entry(card)
	assert_dict(entry).is_not_empty()
	assert_int(int(entry.get("combat_kind", -1))).is_equal(GC.CombatKind.FORT)


func test_reset_seeds_all_loadout_cards() -> void:
	# 端到端：reset 后任何绿槽卡（含缴获/势力）都应有剩余次数
	var spawn = SpawnSystem.new()
	var cap := _make_captured("ww1_inf_storm_e")
	var fe: CardResource = CardResource.new()
	fe.card_id = "fe_iron_wall_bastion"
	fe.combat_kind = GC.CombatKind.FORT
	fe.instance_id = ""
	var plain: CardResource = UCT.build_card_resource("ww1_inf_rifle")
	plain.instance_id = ""
	var pi := MockPI.new()
	pi.los = [{"platform": cap}, {"platform": fe}, {"platform": plain}]
	spawn._phase_instrument = pi
	spawn._signal_bus = null
	spawn._reset_deploy_uses()
	assert_bool(spawn._has_deploy_uses("captured_ww1_inf_storm_e")).is_true()
	assert_bool(spawn._has_deploy_uses("fe_iron_wall_bastion")).is_true()
	assert_bool(spawn._has_deploy_uses("ww1_inf_rifle")).is_true()
	# 缴获卡次数=真身条目口径（非基线兜底值）
	assert_int(int(spawn._deploy_uses_remaining.get("captured_ww1_inf_storm_e", -1)))\
		.is_equal(UCT.get_deploy_uses(UCT.get_entry("ww1_inf_storm_e"), cap))
	assert_int(spawn._get_deploy_uses_total("captured_ww1_inf_storm_e"))\
		.is_equal(int(spawn._deploy_uses_remaining.get("captured_ww1_inf_storm_e", -1)))
	pi.free()


func test_mid_battle_equipped_card_lazy_seeded() -> void:
	# 战斗中途换装：开战快照池里没有的键，查询时懒建键（不误拒"次数耗尽"）
	var spawn = SpawnSystem.new()
	var plain: CardResource = UCT.build_card_resource("ww1_inf_rifle")
	plain.instance_id = ""
	var pi := MockPI.new()
	pi.los = [{"platform": plain}]
	spawn._phase_instrument = pi
	spawn._signal_bus = null
	spawn._reset_deploy_uses()
	# 此时池里只有 ww1_inf_rifle
	var cap := _make_captured("ww1_inf_storm_e")
	pi.los.append({"platform": cap})  # 中途换装
	assert_bool(spawn._has_deploy_uses("captured_ww1_inf_storm_e")).is_true()
	assert_int(int(spawn._deploy_uses_remaining.get("captured_ww1_inf_storm_e", -1)))\
		.is_equal(UCT.get_deploy_uses(UCT.get_entry("ww1_inf_storm_e"), cap))
	pi.free()


func test_missing_key_without_loadout_still_rejected() -> void:
	# 不在绿槽的键不建键，保持拒绝语义
	var spawn = SpawnSystem.new()
	spawn._phase_instrument = null
	spawn._signal_bus = null
	spawn._reset_deploy_uses()
	assert_bool(spawn._has_deploy_uses("captured_ww1_inf_storm_e")).is_false()
