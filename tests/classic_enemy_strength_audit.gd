# 经典敌兵（非相位师）强度审计：敌兵战力 vs 我方同档卡战力（同一把尺子）
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_classic_enemy_strength_audit.gd
extends SceneTree

const LevelEras := preload("res://data/level_eras.gd")
const EnemyLoadoutTiers := preload("res://data/enemy_loadout_tiers.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const EnemyStatResolver := preload("res://data/enemy_stat_resolver.gd")
const DefaultCards := preload("res://data/default_cards.gd")
const UnitStatsTable := preload("res://resources/unit_stats_table.gd")
const EvolutionHelpers := preload("res://managers/evolution/evolution_helpers.gd")
const UnitStatsScript := preload("res://resources/unit_stats.gd")
const EnemyStatContext := preload("res://data/enemy_stat_context.gd")
const BattleExperienceConfig := preload("res://data/battle_experience_config.gd")
const CardGrowthConfig := preload("res://data/card_growth_config.gd")

const AUDIT_LEVELS := [1, 5, 10, 15, 20, 25, 40, 45, 60, 65, 80, 85, 100]
# 档位 → 我方镜像强化等级（TIER_BONUS 注释：低=enh3 中=enh6 高=enh10）


func _power_from_resolved(r: Dictionary) -> float:
	var s := UnitStatsScript.new()
	s.max_hp = maxf(1.0, float(r.get("hp", 1.0)))
	s.attack_light = float(r.get("attack_light", 0.0))
	s.attack_armor = float(r.get("attack_armor", 0.0))
	s.attack_air = float(r.get("attack_air", 0.0))
	s.attack_light_speed = 1.0 / maxf(0.2, float(r.get("attack_interval", 1.0)))
	s.attack_armor_speed = s.attack_light_speed
	s.attack_air_speed = s.attack_light_speed
	var d: float = float(r.get("defense", 0.0))
	s.defense_light = float(r.get("defense_light", d))
	s.defense_armor = float(r.get("defense_armor", d))
	s.defense_air = float(r.get("defense_air", d))
	s.move_speed = 80.0
	return EvolutionHelpers.combat_power_from_unit_stats(s)


func _player_cards_for_era(era: int, count: int) -> Array:
	var out: Array = []
	for cid in DefaultCards.get_all_blueprint_ids_lightweight():
		var card = DefaultCards.get_card_by_id(cid)
		if card == null or int(card.card_type) != 0:
			continue
		if int(card.era) != era:
			continue
		out.append(card)
		if out.size() >= count * 3:  # 多取一些做中位筛选
			break
	return out


## v18.c 等级镜像：玩家卡经验按校准口径 ~60 exp/关/卡（胜50基数+击杀分成中位），
## 换算到卡等级（BattleExperienceConfig 30级曲线）→ CardGrowthConfig flat。
## 敌方侧等级由 resolve_classic_enemy 内部关卡映射（ceil(关卡×0.3)）自动包含。
func _player_card_level_for_stage(stage: int) -> int:
	return BattleExperienceConfig.get_card_level_for_exp(60 * maxi(1, stage))


func _player_power(cards: Array, enhance: int, card_lv: int = 1) -> float:
	var powers: Array = []
	for card in cards:
		var c = card.clone()  # 模板只读铁律——clone 后改强化档
		c.enhance_level = enhance
		var st = UnitStatsTable.build_stats_from_card(c, 0)
		if st != null:
			CardGrowthConfig.apply_to_stats(st, CardGrowthConfig.total_growth(c, card_lv))
			powers.append(EvolutionHelpers.combat_power_from_unit_stats(st))
	if powers.is_empty():
		return 0.0
	powers.sort()
	return float(powers[powers.size() / 2])  # 中位卡战力


func _initialize() -> void:
	print("==========================================================================")
	print("经典敌兵强度审计（战力尺：combat_power_from_unit_stats，敌我同尺）")
	print("档位镜像：低配=我方enh3 / 中配=enh6 / 高配=enh10（TIER_BONUS 设计口径）")
	print("等级镜像：敌=关卡映射(ceil(关×0.3))；我=经验口径 60/关/卡 → Lv（v18.c flat 同表）")
	print("==========================================================================")
	print("关卡 时代  档 波数 | 敌兵hp(w1至末波)   | 敌兵战力(w1至末波)  | 我方中位(Lv) | 敌/我")
	print("-".repeat(104))

	var era_names := ["一战", "二战", "冷战", "现代", "近未来"]
	var era_archetypes: Dictionary = {}
	# 每时代取中位 hp 的 archetype 做代表（确定性排序）
	var all_ids: Array = EnemyArchetypes.get_all_ids()
	var per_era: Dictionary = {}
	for aid in all_ids:
		var cfg: Dictionary = EnemyArchetypes.get_config(aid)
		var e: int = int(cfg.get("era", -1))
		if e < 0:
			continue
		if not per_era.has(e):
			per_era[e] = []
		(per_era[e] as Array).append({"id": aid, "hp": float(cfg.get("hp", 0.0))})
	for e in per_era.keys():
		var arr: Array = per_era[e]
		arr.sort_custom(func(a, b): return float(a.hp) < float(b.hp))
		era_archetypes[e] = String(arr[arr.size() / 2].id)

	for lv in AUDIT_LEVELS:
		var era: int = LevelEras.get_era(lv)
		var in_era: int = ((lv - 1) % 20) + 1
		var prog: float = float(in_era - 1) / 19.0
		var tier: int = EnemyLoadoutTiers.get_tier_for_level_progress(prog)
		var waves: int = LevelEras.get_wave_total_for_level(lv)
		var tier_bonus: Dictionary = EnemyLoadoutTiers.get_bonus_for_tier(tier)
		var mirror_enh: int = int(tier_bonus.get("enhance_level", 3))

		var aid: String = era_archetypes.get(era, "")
		if aid.is_empty():
			print("%-4d %s  无 archetype，跳过" % [lv, era_names[era]])
			continue
		# 波1 与 末波解析（直接构造 ctx：headless 无 GameManager autoload；
		# faction_buff 留空 = 无主之地基线，难度 normal 1.0）
		var ctx1 = EnemyStatContext.new(lv, 1)
		ctx1.tier = tier
		var r1: Dictionary = EnemyStatResolver.resolve_classic_enemy(aid, ctx1)
		var ctxL = EnemyStatContext.new(lv, waves)
		ctxL.tier = tier
		var rL: Dictionary = EnemyStatResolver.resolve_classic_enemy(aid, ctxL)
		var p1: float = _power_from_resolved(r1)
		var pL: float = _power_from_resolved(rL)

		# 我方同时代卡（中位）按镜像强化档 + v18.c 卡等级 flat 镜像
		var cards: Array = _player_cards_for_era(era, 9)
		var plv: int = _player_card_level_for_stage(lv)
		var pp: float = _player_power(cards, mirror_enh, plv)
		var ratio: float = pL / pp if pp > 0.0 else 0.0

		print("%-4d %-4s %-3s %-4d | hp %.0f→%.0f 势力%+4.0f%% | %-12s 战力 %6.1f→%6.1f | %6.1f(Lv%d) | %.2f" % [
			lv, era_names[era], ["低", "中", "高"][tier - 1], waves,
			float(r1.get("hp", 0)), float(rL.get("hp", 0)),
			(float(ctxL.faction_buff.get("hp_mul", 1.0)) - 1.0) * 100.0,
			aid, p1, pL, pp, plv, ratio])
	quit(0)
