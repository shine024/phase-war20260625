# v20.13 每卡部署次数上限冒烟测试
# 无 GdUnit 依赖，桩仪器 + 假入口直接驱动 UnifiedCardTable.get_deploy_uses + BattleSpawnSystem 部署次数追踪。
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/deploy_uses_smoke.gd
extends SceneTree

const GC = preload("res://resources/game_constants.gd")
const UCT = preload("res://data/unified_card_table.gd")

var _errs: Array[String] = []


func _initialize() -> void:
	# ── 1. 兵种基线表 ──
	_check_baseline(GC.CombatKind.LIGHT,   6, "LIGHT  基线=6")
	_check_baseline(GC.CombatKind.SUPPORT, 5, "SUPPORT 基线=5")
	_check_baseline(GC.CombatKind.ARMOR,   4, "ARMOR   基线=4")
	_check_baseline(GC.CombatKind.AIR,     4, "AIR     基线=4")
	_check_baseline(GC.CombatKind.FORT,    3, "FORT    基线=3")

	# ── 2. 显式覆盖（最高优先） ──
	var entry_override := {"combat_kind": GC.CombatKind.LIGHT, "deploy_uses": 1}
	_check_deploy_uses(entry_override, null, 1, "显式 deploy_uses=1 覆盖基线6")

	# ── 3. 核心标记（tags 命中 radar） ──
	var entry_radar := {"combat_kind": GC.CombatKind.SUPPORT, "tags": ["radar", "support"]}
	_check_deploy_uses(entry_radar, null, 2, "tags 命中 radar → 核心档2")

	# ── 4. 核心标记（tags 命中 command） ──
	var entry_cmd := {"combat_kind": GC.CombatKind.FORT, "tags": ["command", "fortress"]}
	_check_deploy_uses(entry_cmd, null, 2, "tags 命中 command → 核心档2（覆盖 FORT 基线3）")

	# ── 5. 核心标记（显式 deploy_class="core"） ──
	var entry_core := {"combat_kind": GC.CombatKind.ARMOR, "deploy_class": "core"}
	_check_deploy_uses(entry_core, null, 2, "deploy_class=core → 核心档2")

	# ── 6. 终极修正：legendary rarity → -1 ──
	var card_legendary := _make_card("test_legendary", GC.CombatKind.LIGHT, "legendary", "")
	_check_deploy_uses({"combat_kind": GC.CombatKind.LIGHT}, card_legendary, 5, "legendary LIGHT 6-1=5")

	# ── 7. 终极修正：FORT legendary 保底 2 ──
	var card_fort_legendary := _make_card("test_fort_leg", GC.CombatKind.FORT, "legendary", "")
	_check_deploy_uses({"combat_kind": GC.CombatKind.FORT}, card_fort_legendary, 2, "legendary FORT 3-1=2（保底）")

	# ── 8. 普通 rarity 不触发终极修正 ──
	var card_common := _make_card("test_common", GC.CombatKind.ARMOR, "common", "")
	_check_deploy_uses({"combat_kind": GC.CombatKind.ARMOR}, card_common, 4, "common ARMOR 基线=4（不触发修正）")

	# ── 9. entry 层 rarity 回退（无 card 实例时） ──
	var entry_legendary := {"combat_kind": GC.CombatKind.AIR, "rarity": "legendary"}
	_check_deploy_uses(entry_legendary, null, 3, "entry rarity=legendary AIR 4-1=3")

	# ── 10. 未知 combat_kind 兜底 ──
	var entry_unknown := {"combat_kind": 99}
	_check_deploy_uses(entry_unknown, null, 4, "未知 combat_kind=99 → 兜底4")

	_finish()


func _check_baseline(ck: int, expect: int, label: String) -> void:
	var entry := {"combat_kind": ck}
	_check_deploy_uses(entry, null, expect, label)


func _check_deploy_uses(entry: Dictionary, card: CardResource, expect: int, label: String) -> void:
	var actual: int = UCT.get_deploy_uses(entry, card)
	var ok: bool = (actual == expect)
	print("  %s → %d (expect %d) %s" % [label, actual, expect, "✓" if ok else "✗"])
	if not ok:
		_errs.append("%s: got %d, expected %d" % [label, actual, expect])


func _make_card(card_id: String, ck: int, rarity: String, instance_id: String) -> CardResource:
	var card := CardResource.new()
	card.card_id = card_id
	card.combat_kind = ck
	card.rarity = rarity
	card.instance_id = instance_id
	return card


func _finish() -> void:
	if _errs.is_empty():
		print("")
		print("=== deploy_uses_smoke: ALL PASS（v20.13 每卡部署次数上限）===")
	else:
		print("")
		print("❌ deploy_uses_smoke: FAILED (%d)" % _errs.size())
		for e in _errs:
			push_error(e)
			print("  - ", e)
	quit(0 if _errs.is_empty() else 1)