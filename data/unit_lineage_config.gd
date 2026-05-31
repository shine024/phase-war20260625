extends RefCounted
class_name UnitLineageConfig

## 卡牌进化链配置（v5.0：9条主线进化路线）
## 路线结构：
## - evolution_1: 下一阶段进化目标（同体系直线）
## - faction_branches: 势力特化进化（备选路线）
## - inherit_ratio: 进化仅继承属性比例（不继承改造）
##
## v6.0 进化条件:
## 1. 战力达标: 培养满后战力 >= 目标基础战力
## 2. 情报100%: 目标单位情报满（Phase 5实现，此处预留接口）
## 3. 不跨类型: combat_kind 相同
## 4. 强化门槛: E1≥Lv5, E2≥Lv8
## 5. 改造门槛: E1≥2个MOD, E2≥5个MOD
## 6. 敌源门槛: E2需1个敌源改造模块
##
## 进化执行规则: 改造完全继承(mods复制)、强化重置(enhance_level=0)、品质保留、情报保留

const DefaultCards = preload("res://data/default_cards.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")

const DEFAULT_INHERIT_RATIO: float = 0.30

## v6.0 进化门槛（替代旧的星级/研究点/许可证）
const E1_MIN_ENHANCE_LEVEL: int = 5       ## 基础进化：强化至少Lv5
const E1_MIN_MOD_COUNT: int = 2            ## 基础进化：至少装2个MOD
const E2_MIN_ENHANCE_LEVEL: int = 8        ## 势力分支：强化至少Lv8
const E2_MIN_MOD_COUNT: int = 5             ## 势力分支：至少装5个MOD
const E2_REQUIRE_ENEMY_ORIGIN_MOD: bool = true  ## 势力分支：必须有1个敌源MOD

const EVOLVE_REASON_ZH: Dictionary = {
	"ok": "可进化",
	"invalid": "条件无效",
	"card_locked": "蓝图未解锁",
	"invalid_target": "进化目标不存在",
	"target_not_in_path": "目标不在该卡进化路线中",
	"enhance_not_enough": "强化等级不足（基础进化需Lv5，势力分支需Lv8）",
	"mod_not_enough": "改造模块不足（基础进化需2个，势力分支需5个）",
	"enemy_mod_not_enough": "未安装敌源改造模块（势力分支进化要求）",
	"power_not_enough": "培养战力未达标",
	"cross_class": "不能跨类型进化",
	"intel_not_full": "目标情报未满100%（Phase 5启用）",
}

## ═══════════════════════════════════════════════════════════
## v5.0 进化路线（9条主线，共37个节点）
## ═══════════════════════════════════════════════════════════
##
## 轻装线（combat_kind=0）:
##   普通步兵: ww1_mp18(15) → ww2_thompson(60) → cold_ak47(160) → mod_marine(320) → fut_cyborg(500)
##   反坦克:   ww2_panzerschrek(65) → cold_rpg(170) → mod_javelin(330) → fut_cyborg(500)
##   特种:     ww1_storm(20) → cold_spetsnaz(180) → mod_ranger(340) → fut_spectre(530)
##
## 装甲线（combat_kind=1）:
##   主战坦克: ww1_ft17(45) → ww2_pz3(180) → cold_t55(480) → mod_m1a1(950) → fut_hovertank(1500)
##   重型坦克: ww1_saint(50) → ww2_tiger(180) → cold_t72(480) → mod_m1a2sep(960) → fut_heavy_mech(1580)
##
## 空中线（combat_kind=3）:
##   战斗机:   cold_mig21(400) → mod_ah64(800) → fut_space_fighter(1325)
##   攻击机:   mod_ah1(780) → fut_attack_drone(1300)
##
## 支援线（combat_kind=2）:
##   火炮:     ww1_m81(23) → ww2_m81(90) → cold_m113(240) → mod_m270(480) → fut_howitzer(795)
##   防空:     ww1_37mm(23) → cold_zsu23(240) → mod_m6(480) → fut_aa_hover(780)

const LINEAGES: Dictionary = {
	# ─── 轻装线：普通步兵（5节） ───
	"ww1_mp18": {
		"evolution_1": "ww2_thompson",
		"faction_branches": {
			"aether_dynamics": "mod_marine",
			"frontier_union": "cold_ak47",
			"helix_recon": "mod_ranger",
			"void_research": "fut_spectre",
		},
	},
	"ww2_thompson": {
		"evolution_1": "cold_ak47",
		"faction_branches": {
			"aether_dynamics": "cold_spetsnaz",
			"frontier_union": "cold_ak47",
			"helix_recon": "mod_ranger",
			"iron_wall_corp": "mod_ranger",
			"nova_arms": "mod_marine",
			"quantum_logistics": "mod_marine",
			"void_research": "fut_spectre",
		},
	},
	"cold_ak47": {
		"evolution_1": "mod_marine",
		"faction_branches": {
			"aether_dynamics": "mod_ranger",
			"frontier_union": "mod_marine",
			"helix_recon": "fut_spectre",
			"iron_wall_corp": "mod_ranger",
			"nova_arms": "fut_cyborg",
			"quantum_logistics": "mod_marine",
			"void_research": "fut_cyborg",
		},
	},
	"mod_marine": {
		"evolution_1": "fut_cyborg",
		"faction_branches": {
			"aether_dynamics": "fut_scout_mech",
			"frontier_union": "fut_cyborg",
			"helix_recon": "fut_spectre",
			"iron_wall_corp": "fut_heavy_trooper",
			"nova_arms": "fut_cyborg",
			"quantum_logistics": "fut_cyborg",
			"void_research": "fut_nexus",
		},
	},

	# ─── 轻装线：反坦克（4节） ───
	"ww2_panzerschrek": {
		"evolution_1": "cold_rpg",
		"faction_branches": {
			"aether_dynamics": "mod_javelin",
			"frontier_union": "cold_rpg",
			"nova_arms": "mod_javelin",
		},
	},
	"cold_rpg": {
		"evolution_1": "mod_javelin",
		"faction_branches": {
			"aether_dynamics": "mod_javelin",
			"frontier_union": "mod_javelin",
			"nova_arms": "mod_javelin",
		},
	},
	"mod_javelin": {
		"evolution_1": "fut_cyborg",
		"faction_branches": {
			"aether_dynamics": "fut_scout_mech",
			"frontier_union": "fut_cyborg",
			"helix_recon": "fut_spectre",
			"iron_wall_corp": "fut_heavy_trooper",
			"nova_arms": "fut_assault_mech",
			"quantum_logistics": "fut_cyborg",
			"void_research": "fut_nexus",
		},
	},

	# ─── 轻装线：特种（4节） ───
	"ww1_storm": {
		"evolution_1": "cold_spetsnaz",
		"faction_branches": {
			"aether_dynamics": "mod_ranger",
			"frontier_union": "cold_spetsnaz",
			"helix_recon": "mod_ranger",
			"iron_wall_corp": "mod_ranger",
			"nova_arms": "mod_ranger",
			"quantum_logistics": "mod_ranger",
			"void_research": "fut_spectre",
		},
	},
	"cold_spetsnaz": {
		"evolution_1": "mod_ranger",
		"faction_branches": {
			"aether_dynamics": "mod_ranger",
			"frontier_union": "mod_ranger",
			"helix_recon": "mod_ranger",
			"iron_wall_corp": "mod_ranger",
			"nova_arms": "mod_ranger",
			"quantum_logistics": "mod_ranger",
			"void_research": "fut_spectre",
		},
	},
	"mod_ranger": {
		"evolution_1": "fut_spectre",
		"faction_branches": {},
	},

	# ─── 装甲线：主战坦克（5节） ───
	"ww1_ft17": {
		"evolution_1": "ww2_pz3",
		"faction_branches": {
			"aether_dynamics": "cold_t55",
			"frontier_union": "cold_t55",
			"helix_recon": "cold_t62",
			"iron_wall_corp": "ww2_tiger",
			"nova_arms": "ww2_panther",
			"quantum_logistics": "ww2_t34_85",
			"void_research": "fut_hovertank",
		},
	},
	"ww2_pz3": {
		"evolution_1": "cold_t55",
		"faction_branches": {
			"aether_dynamics": "cold_t55",
			"frontier_union": "cold_t72",
			"helix_recon": "cold_chieftain",
			"iron_wall_corp": "cold_t72",
			"nova_arms": "cold_leo1",
			"void_research": "fut_hovertank",
		},
	},
	"cold_t55": {
		"evolution_1": "mod_m1a1",
		"faction_branches": {
			"iron_wall_corp": "mod_m1a2sep",
			"nova_arms": "mod_m1a2sep",
			"aether_dynamics": "mod_m1a1",
			"quantum_logistics": "mod_m1a1",
			"helix_recon": "mod_leo2a6",
			"void_research": "fut_hovertank",
			"frontier_union": "mod_m1a1",
		},
	},
	"mod_m1a1": {
		"evolution_1": "fut_hovertank",
		"faction_branches": {
			"iron_wall_corp": "fut_heavy_mech",
			"nova_arms": "fut_assault_mech",
			"aether_dynamics": "fut_hovertank",
			"quantum_logistics": "fut_hovertank",
			"helix_recon": "fut_prism",
			"void_research": "fut_colossus",
			"frontier_union": "fut_hovertank",
		},
	},

	# ─── 装甲线：重型坦克（5节） ───
	"ww1_saint": {
		"evolution_1": "ww2_tiger",
		"faction_branches": {
			"iron_wall_corp": "ww2_kingtiger",
			"nova_arms": "ww2_panther",
			"aether_dynamics": "ww2_tiger",
			"quantum_logistics": "cold_t72",
			"helix_recon": "cold_chieftain",
			"void_research": "fut_heavy_mech",
			"frontier_union": "cold_t72",
		},
	},
	"ww2_tiger": {
		"evolution_1": "cold_t72",
		"faction_branches": {
			"iron_wall_corp": "cold_t72",
			"nova_arms": "mod_m1a2sep",
			"aether_dynamics": "cold_t72",
			"quantum_logistics": "mod_m1a2sep",
			"helix_recon": "mod_leo2a6",
			"void_research": "fut_heavy_mech",
			"frontier_union": "mod_m1a2sep",
		},
	},
	"cold_t72": {
		"evolution_1": "mod_m1a2sep",
		"faction_branches": {
			"iron_wall_corp": "mod_m1a2sep",
			"nova_arms": "mod_m1a2sep",
			"aether_dynamics": "mod_m1a1",
			"quantum_logistics": "mod_m1a1",
			"helix_recon": "mod_leo2a6",
			"void_research": "fut_heavy_mech",
			"frontier_union": "mod_m1a2sep",
		},
	},
	"mod_m1a2sep": {
		"evolution_1": "fut_heavy_mech",
		"faction_branches": {
			"iron_wall_corp": "fut_colossus",
			"nova_arms": "fut_assault_mech",
			"aether_dynamics": "fut_hovertank",
			"quantum_logistics": "fut_heavy_mech",
			"helix_recon": "fut_prism",
			"void_research": "fut_nexus",
			"frontier_union": "fut_heavy_mech",
		},
	},

	# ─── 空中线：战斗机（3节） ───
	"cold_mig21": {
		"evolution_1": "mod_ah64",
		"faction_branches": {
			"nova_arms": "mod_ah64",
			"aether_dynamics": "fut_space_fighter",
			"quantum_logistics": "mod_uh60",
			"helix_recon": "fut_space_fighter",
			"void_research": "fut_space_fighter",
			"frontier_union": "mod_ah64",
		},
	},
	"mod_ah64": {
		"evolution_1": "fut_space_fighter",
		"faction_branches": {
			"iron_wall_corp": "fut_space_fighter",
			"nova_arms": "fut_stealth_bomber",
			"aether_dynamics": "fut_space_fighter",
			"quantum_logistics": "fut_attack_drone",
			"helix_recon": "fut_space_fighter",
			"void_research": "fut_stealth_bomber",
			"frontier_union": "fut_space_fighter",
		},
	},

	# ─── 空中线：攻击机（2节） ───
	"mod_ah1": {
		"evolution_1": "fut_attack_drone",
		"faction_branches": {
			"iron_wall_corp": "fut_attack_drone",
			"nova_arms": "fut_attack_drone",
			"aether_dynamics": "fut_space_fighter",
			"quantum_logistics": "fut_scout_drone",
			"helix_recon": "fut_attack_drone",
			"void_research": "fut_stealth_bomber",
			"frontier_union": "fut_attack_drone",
		},
	},

	# ─── 支援线：火炮（5节） ───
	"ww1_m81": {
		"evolution_1": "ww2_m81",
		"faction_branches": {
			"iron_wall_corp": "ww2_m120",
			"quantum_logistics": "ww2_m120",
			"void_research": "ww2_m120",
			"frontier_union": "ww2_m81",
		},
	},
	"ww2_m81": {
		"evolution_1": "cold_m113",
		"faction_branches": {
			"nova_arms": "cold_bmp1",
			"aether_dynamics": "cold_bmp1",
			"quantum_logistics": "cold_m113",
			"helix_recon": "cold_bmp1",
			"void_research": "cold_m113",
			"frontier_union": "cold_m113",
		},
	},
	"cold_m113": {
		"evolution_1": "mod_m270",
		"faction_branches": {
			"nova_arms": "mod_m270",
			"aether_dynamics": "mod_m270",
			"quantum_logistics": "mod_m270",
			"helix_recon": "mod_m270",
			"void_research": "mod_m270",
			"frontier_union": "mod_m270",
		},
	},
	"mod_m270": {
		"evolution_1": "fut_howitzer",
		"faction_branches": {
			"iron_wall_corp": "fut_ion",
			"aether_dynamics": "fut_howitzer",
			"quantum_logistics": "fut_howitzer",
			"helix_recon": "fut_howitzer",
			"void_research": "fut_ion",
			"frontier_union": "fut_howitzer",
		},
	},

	# ─── 支援线：防空（4节） ───
	"ww1_37mm": {
		"evolution_1": "cold_zsu23",
		"faction_branches": {
			"aether_dynamics": "cold_zsu23",
			"frontier_union": "cold_zsu23",
			"helix_recon": "mod_m6",
			"nova_arms": "cold_zsu23",
			"quantum_logistics": "cold_zsu23",
			"void_research": "mod_m6",
		},
	},
	"cold_zsu23": {
		"evolution_1": "mod_m6",
		"faction_branches": {
			"aether_dynamics": "mod_m6",
			"frontier_union": "mod_m6",
			"helix_recon": "mod_m6",
			"iron_wall_corp": "mod_m6",
			"nova_arms": "mod_m6",
			"quantum_logistics": "mod_m6",
			"void_research": "mod_m6",
		},
	},
	"mod_m6": {
		"evolution_1": "fut_aa_hover",
		"faction_branches": {
			"aether_dynamics": "fut_aa_hover",
			"frontier_union": "fut_aa_hover",
			"helix_recon": "fut_aa_hover",
			"iron_wall_corp": "fut_aa_hover",
			"nova_arms": "fut_aa_hover",
			"quantum_logistics": "fut_aa_hover",
			"void_research": "fut_shield",
		},
	},

	# ─── 终端节点（无后续进化） ───
	# fut_cyborg, fut_spectre, fut_hovertank, fut_heavy_mech,
	# fut_space_fighter, fut_attack_drone, fut_howitzer, fut_aa_hover
	# 均无 LINEAGES 条目，表示进化链末端
}

## ═══════════════════════════════════════════════════════════
## v5.0 进化条件检查
## ═══════════════════════════════════════════════════════════

## 检查是否可以进化（纯数据层条件，不含资源检查）
## 参数:
##   from_card_id: 当前单位 blueprint ID
##   target_card_id: 进化目标 blueprint ID
##   current_power: 当前培养后的实际战力（由 BlueprintManager 传入）
##   from_combat_kind: 当前单位 combat_kind（由 BlueprintManager 传入）
##   target_intel: 目标单位当前情报进度（0.0~1.0，Phase 5 传入）
## 返回: Dictionary { "ok": bool, "reason": String }
static func can_evolve(
	from_card_id: String,
	target_card_id: String,
	current_power: float = 0.0,
	from_combat_kind: int = -1,
	target_intel: float = 1.0
) -> Dictionary:
	# 1. 基本有效性
	if from_card_id.is_empty() or target_card_id.is_empty():
		return {"ok": false, "reason": "invalid"}

	# 2. 检查进化路线中存在此目标
	if not has_lineage(from_card_id):
		return {"ok": false, "reason": "target_not_in_path"}
	var evo_target: String = get_evolution_1_target(from_card_id)
	if evo_target != target_card_id:
		# 也检查势力分支
		var branches: Dictionary = get_all_faction_targets(from_card_id)
		var found_in_branches: bool = false
		for _k in branches.keys():
			if String(branches[_k]) == target_card_id:
				found_in_branches = true
				break
		if not found_in_branches:
			return {"ok": false, "reason": "target_not_in_path"}

	# 3. 不跨类型（combat_kind 必须相同）
	if from_combat_kind >= 0:
		var target_card: CardResource = DefaultCards.get_card_by_id(target_card_id)
		if target_card != null:
			var target_kind: int = target_card.combat_kind if target_card.combat_kind >= 0 else 0
			if from_combat_kind != target_kind:
				return {"ok": false, "reason": "cross_class"}

	# 4. 战力达标：培养后战力 >= 目标基础战力
	var target_card: CardResource = DefaultCards.get_card_by_id(target_card_id)
	if target_card != null and current_power > 0.0:
		if current_power < float(target_card.power):
			return {"ok": false, "reason": "power_not_enough"}

	# 5. 情报100%
	if target_intel < 1.0:
		return {"ok": false, "reason": "intel_not_full"}

	return {"ok": true, "reason": "ok"}

## 获取进化链中两个单位之间的 combat_kind 一致性
## 返回 true 表示同类型（允许进化），false 表示跨类型（不允许）
static func check_same_combat_kind(from_card_id: String, to_card_id: String) -> bool:
	var from_card: CardResource = DefaultCards.get_card_by_id(from_card_id)
	var to_card: CardResource = DefaultCards.get_card_by_id(to_card_id)
	if from_card == null or to_card == null:
		return true  # 无法判断时放行
	return from_card.combat_kind == to_card.combat_kind

## 获取目标单位的基础战力（用于战力达标检查）
static func get_target_base_power(target_card_id: String) -> int:
	var card: CardResource = DefaultCards.get_card_by_id(target_card_id)
	if card == null:
		return 0
	return card.power

## ═══════════════════════════════════════════════════════════
## 工具函数
## ═══════════════════════════════════════════════════════════

static func localize_evolve_reason(reason: String) -> String:
	var key: String = String(reason).strip_edges()
	if EVOLVE_REASON_ZH.has(key):
		return String(EVOLVE_REASON_ZH[key])
	return key if not key.is_empty() else String(EVOLVE_REASON_ZH.get("invalid", "条件无效"))

static func is_valid_evolution_target(target_id: String) -> bool:
	if target_id.is_empty():
		return false
	if DefaultCards.get_card_by_id(target_id) != null:
		return true
	return not PhaseLaws.get_by_id(target_id).is_empty()

static func validate_lineage_targets() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for source_id in LINEAGES.keys():
		var cfg: Dictionary = LINEAGES[source_id]
		var e1: String = String(cfg.get("evolution_1", ""))
		if not e1.is_empty() and not is_valid_evolution_target(e1):
			errors.append("%s → 无效目标: %s (evolution_1)" % [source_id, e1])
		var branches: Dictionary = cfg.get("faction_branches", {})
		for faction_id in branches.keys():
			var target: String = String(branches[faction_id])
			if not is_valid_evolution_target(target):
				errors.append("%s → 无效目标: %s (faction %s)" % [source_id, target, faction_id])
	return errors

static func has_lineage(card_id: String) -> bool:
	return LINEAGES.has(card_id)

static func get_inherit_ratio(_from_card_id: String, _to_card_id: String) -> float:
	return DEFAULT_INHERIT_RATIO

static func get_evolution_1_target(card_id: String) -> String:
	var cfg: Dictionary = LINEAGES.get(card_id, {})
	return String(cfg.get("evolution_1", ""))

static func get_faction_target(card_id: String, faction_id: String) -> String:
	var cfg: Dictionary = LINEAGES.get(card_id, {})
	var branches: Dictionary = cfg.get("faction_branches", {})
	return String(branches.get(faction_id, ""))

static func get_all_faction_targets(card_id: String) -> Dictionary:
	var cfg: Dictionary = LINEAGES.get(card_id, {})
	return (cfg.get("faction_branches", {}) as Dictionary).duplicate(true)

static func get_progression_step(card_id: String) -> int:
	if not has_lineage(card_id):
		return 0
	var evo1: String = get_evolution_1_target(card_id)
	if evo1.is_empty():
		return 0
	if has_lineage(evo1):
		return 1
	return 1

static func get_stage(from_card_id: String, to_card_id: String) -> String:
	if to_card_id == get_evolution_1_target(from_card_id):
		return "e1"
	return "e2"

static func get_enhance_requirement(stage: String) -> int:
	return E2_MIN_ENHANCE_LEVEL if stage == "e2" else E1_MIN_ENHANCE_LEVEL

static func get_mod_requirement(stage: String) -> int:
	return E2_MIN_MOD_COUNT if stage == "e2" else E1_MIN_MOD_COUNT

static func get_enemy_mod_required(stage: String) -> bool:
	return E2_REQUIRE_ENEMY_ORIGIN_MOD if stage == "e2" else false
