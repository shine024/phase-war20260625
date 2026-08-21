# v18.d 效果实验面板新增两区数据链 smoke test
# 验证（不实例化面板 UI，只测两个新区枚举的数据完整性）：
#   1. 奇点（capstone）节点全量分类——每个节点都落在面板处理的四个桶之一，
#      机制类 id 全部在 _MECH_UNIT_FIELDS 映射表内，卡片技能 id 全部在 CPS 表中
#   2. 敌方相位师大招——30 master 51 个大招 shape 完整（id/effect/cooldown），
#      引擎聚类判定全部命中六类之一（无静默跳过的空转大招）
#
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/effect_lab_new_sections_smoke.gd
extends SceneTree

const PMSkillTree := preload("res://data/phase_master_skill_tree.gd")
const CPS := preload("res://data/card_periodic_skills.gd")
const EnemyMasterInstruments := preload("res://data/enemy_master_instruments.gd")
const EnemyPhaseMasters := preload("res://data/enemy_phase_masters.gd")
const EnemyMasterSkillEngine := preload("res://managers/battle/enemy_master_skill_engine.gd")

## 与 effect_lab_panel._MECH_UNIT_FIELDS 同源（面板映射表的键集）
const MECH_KEYS := ["nuclear_strike", "shield_projector", "drone_mark",
	"demolition", "sniper_aim", "blitz_pierce", "jamming_field"]


func _initialize() -> void:
	var code := [0]
	var fail := func(msg: String) -> void:
		push_error("[FAIL] " + msg)
		code[0] = 1

	print("═══════════════════════════════════════════════════════════")
	print("  效果实验面板新两区数据链验证（奇点大招 + 敌方相位师大招）")
	print("═══════════════════════════════════════════════════════════")

	# ══════════ 1. 奇点节点分类覆盖 ══════════
	print("\n[1] 奇点（capstone）节点全量分类")
	var mech_count: int = 0
	var cps_count: int = 0
	var stat_count: int = 0
	var evo_count: int = 0
	var other: Array = []
	for branch in ["command", "intelligence", "firepower"]:
		for node in PMSkillTree.get_skills_for_branch(branch):
			if not (node is Dictionary) or not bool((node as Dictionary).get("capstone", false)):
				continue
			var n: Dictionary = node as Dictionary
			var mech_id: String = ""
			var cps_id: String = ""
			var has_evolution: bool = false
			for u in n.get("unlocks", []) as Array:
				if u is Dictionary:
					match String(u.get("type", "")):
						"unit_mechanism":
							mech_id = String(u.get("id", ""))
						"card_skill":
							cps_id = String(u.get("id", ""))
						"evolution":
							has_evolution = true
			if not mech_id.is_empty():
				mech_count += 1
				if not (mech_id in MECH_KEYS):
					fail.call("机制 %s 不在面板映射表内（面板会落灰行）: %s" % [mech_id, String(n.get("id"))])
			elif not cps_id.is_empty():
				cps_count += 1
				if CPS.get_skill(cps_id).is_empty():
					fail.call("奇点解锁的卡片技能 %s 不在 CPS 表: %s" % [cps_id, String(n.get("id"))])
			elif not ((n.get("effects", {}) as Dictionary).get("stat_bonus", {}) as Dictionary).is_empty():
				stat_count += 1
			elif has_evolution:
				evo_count += 1
			else:
				other.append(String(n.get("id")))
	var total_capstone: int = mech_count + cps_count + stat_count + evo_count + other.size()
	if total_capstone < 10:
		fail.call("奇点节点应 ≥10 个（实测 %d）——枚举链路可能断了" % total_capstone)
	if not other.is_empty():
		fail.call("有奇点节点落入未处理桶: %s" % str(other))
	print("  分类覆盖 OK（机制%d 卡片技能%d 数值%d 养成%d 未处理%d = 共%d）" % [
		mech_count, cps_count, stat_count, evo_count, other.size(), total_capstone])

	# ══════════ 2. 敌方相位师大招 shape + 引擎聚类覆盖 ══════════
	print("\n[2] 敌方相位师大招（30 master）shape 与聚类覆盖")
	var masters: Array = EnemyPhaseMasters.ENEMY_MASTERS
	if masters.size() != 30:
		fail.call("ENEMY_MASTERS 应 30 个（实测 %d）" % masters.size())
	var total_spells: int = 0
	var shape_bad: int = 0
	var unrouted: Array = []
	var eng: RefCounted = EnemyMasterSkillEngine.new()
	for m in masters:
		var mid: String = String((m as Dictionary).get("id", ""))
		var spells: Array = EnemyMasterInstruments.get_master_ultimate_spells(mid)
		total_spells += spells.size()
		for sp in spells:
			var sd: Dictionary = sp as Dictionary
			if String(sd.get("id", "")).is_empty() or String(sd.get("effect", "")).is_empty() or float(sd.get("cooldown", 0.0)) <= 0.0:
				shape_bad += 1
			# 引擎聚类：六个判定至少命中一个（未命中 = 触发后静默跳过的空转大招）
			var eff: String = String(sd.get("effect", "")).to_lower()
			if not (eng._is_aoe_effect(eff) or eng._is_chain_effect(eff) or eng._is_summon_effect(eff)
					or eng._is_debuff_effect(eff) or eng._is_shield_effect(eff) or eng._is_single_target_effect(eff)):
				unrouted.append("%s:%s" % [mid, eff])
	if total_spells != 51:
		fail.call("大招总数应为 51（实测 %d）" % total_spells)
	if shape_bad > 0:
		fail.call("%d 个大招 shape 不完整（id/effect/cooldown）" % shape_bad)
	if not unrouted.is_empty():
		fail.call("有 %d 个大招不命中引擎任何聚类（触发后静默空转）: %s" % [unrouted.size(), str(unrouted.slice(0, 5))])
	print("  大招链路 OK（%d master / %d 大招 / shape 完整 / 聚类全覆盖）" % [masters.size(), total_spells])

	print("\n═══════════════════════════════════════════════════════════")
	if code[0] == 0:
		print("  ✅ 全部通过")
	else:
		print("  ❌ 存在失败项")
	print("═══════════════════════════════════════════════════════════")
	quit(code[0])
