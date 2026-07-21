# 同一张卡三种情境战力对比 — 实跑真实公式
#
# 目标：回答"同一张卡在最后广场（第100关）三种情境下的战力数值"
#   ① 我方满配战力（fut_colossus 满强化+满改造+满进化+元帅）
#   ② 敌方非相位师满配（fut_arm_colossus_e，第100关普通敌兵，wave×level×faction_buff 满链）
#   ③ 敌方相位师满配（master_030，第100关 boss，3 分量总分 + 产兵属性）
#
# 基准卡：巨神机甲（近未来 era=4，与第100关同时代）
#   我方卡：fut_colossus（power=1590，ULTIMATE）
#   敌方对应 archetype：fut_arm_colossus_e（hp=600/atk=55，CHAMPION）
#
# 运行：
#   godot --headless --rendering-driver opengl3 --path . --script tests/combat_power_comparison_smoke.gd
extends SceneTree

const EvolutionHelpers = preload("res://managers/evolution/evolution_helpers.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const RankRules = preload("res://data/rank_rules.gd")
const BattleCardV3 = preload("res://data/battle_card_v3.gd")
const EnemyStatResolver = preload("res://data/enemy_stat_resolver.gd")
const EnemyStatContext = preload("res://data/enemy_stat_context.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const _ArchFuture = preload("res://data/enemy_archetypes_future.gd")
const FactionConquestBuffs = preload("res://data/faction_conquest_buffs.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")
const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const PowerTiers = preload("res://data/power_tiers.gd")


func _initialize() -> void:
	print("")
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║   同一张卡 · 三种情境战力对比（基准卡：巨神机甲 era=4）       ║")
	print("║   场景：第100关（最后广场·近未来·void_research 满级占领）    ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	print("")

	_section1_player_full_build()
	print("")
	_section2_enemy_non_master()
	print("")
	_section3_enemy_master()
	print("")
	_summary()

	quit(0)


# ═══════════════════════════════════════════════════════════
#  段1：我方满配 fut_colossus 战力
# ═══════════════════════════════════════════════════════════
func _section1_player_full_build() -> void:
	print("┌────────────────────────────────────────────────────────────┐")
	print("│ ① 我方满配 fut_colossus（巨神机甲）                       │")
	print("│    满强化 Lv10 + 满改造 + 满进化 E3 +稀有度 mythic + 元帅 │")
	print("└────────────────────────────────────────────────────────────┘")

	var card = DefaultCards.get_card_by_id("fut_colossus")
	if card == null:
		push_error("[FAIL] fut_colossus 模板未找到")
		return

	# clone 出独立实例（避免污染共享模板——三大铁律之一）
	var inst = card.clone()
	inst.instance_id = "fut_colossus#TEST"
	inst.rarity = "mythic"
	inst.enhance_level = 10
	# 满改造：取一组代表性装甲 legendary 改造（满配示意，非精确最优组合）
	# 选取标准：覆盖 HP/三维攻/三维防/暴击/穿甲/攻速 全维度
	inst.mods = [
		"arm_06_apfsds",      # 对装甲 +30%（v6.1 校准）
		"arm_07_reactive_armor", # HP/防御提升
		"arm_09_auto_loader", # 攻速提升
		"gen_03_targeting_computer", # 暴击+穿甲
		"gen_05_reinforced_chassis", # HP 大幅提升
	]

	# build_stats_from_card：应用 mod 效果 + 强化加成 + Lv4/7/10 能力解锁 + 兵种修正
	# v6.8 已移除时代缩放（我方不按 era 放大）
	var stats = UnitStatsTable.build_stats_from_card(inst, 4)
	if stats == null:
		push_error("[FAIL] build_stats_from_card 返回 null")
		return

	# 养成乘区（手动叠加，复用 evolution_helpers 的纯函数）
	# 公式：rarity_mul × enhance_mul（get_effective_power_multiplier）
	var rarity_mul := EvolutionHelpers.get_rarity_multiplier(inst.card_id)  # mythic → 1.20
	# 但 inst.rarity 已设 mythic，get_rarity_multiplier 走 get_card_base_rarity 查模板（common）
	# 这里手动覆盖：直接算 mythic 满强化的 effective 倍率
	var enhance_mul := BattleCardV3.enhance_stat_multiplier(10, "mythic")
	# enhance_stat_multiplier(10, mythic) = 1 + 9*0.07 + 9*0.04 = 1 + 0.63 + 0.36 = 1.99
	var power_mul := 1.20 * enhance_mul  # rarity × enhance

	# inherit_bonus（满进化 E3，取最大 0.40）
	var inherit_bonus := 0.40
	var inherit_mul := 1.0 + inherit_bonus

	# 军衔（满配元帅）
	var rank_bonus := RankRules.get_rank_bonus("marshal")  # hp_mul=dmg_mul=1.07

	# 应用乘区到 stats（HP 和三维攻击各乘）
	stats.max_hp *= power_mul
	stats.max_hp *= inherit_mul
	stats.max_hp *= float(rank_bonus.get("hp_mul", 1.0))
	# 兵种倾斜（装甲 hp_bias 0.06/级 × 10 级 = 0.60）
	var growth_bias := UnitStatsTable.get_combat_kind_growth_bias(stats.combat_kind)
	var hp_bias := float(growth_bias.get("hp_bias", 0.04))
	var dmg_bias := float(growth_bias.get("dmg_bias", 0.04))
	stats.max_hp *= 1.0 + 10.0 * hp_bias

	# 三维攻击各乘（含 weapon_slots 同步——_multiply_attack_damage_and_weapon_slots 已封装）
	_mul_attack(stats, power_mul)
	_mul_attack(stats, inherit_mul)
	_mul_attack(stats, float(rank_bonus.get("dmg_mul", 1.0)))
	_mul_attack(stats, 1.0 + 10.0 * dmg_bias)

	# 进化 HP 下限（满进化 E3，设一个高 floor，避免被上面的乘区拉低）
	# 注：实际满进化 floor 由 InstanceRegistry.get_evolution_hp_floor 存储，这里手动设
	# 满进化 fut_colossus HP 下限约 12000（v6.8 不再乘时代倍率）
	var evolution_hp_floor := 12000.0
	stats.max_hp = maxf(stats.max_hp, evolution_hp_floor)

	# 最终战力
	var power := EvolutionHelpers.combat_power_from_unit_stats(stats)

	# 输出
	print("  [满配养成参数]")
	print("    稀有度乘区（mythic）       : ×%.2f" % 1.20)
	print("    强化倍率（Lv10 + mythic）  : ×%.2f  (= 1 + 9×0.07 + 9×0.04)" % enhance_mul)
	print("    effective power_mul        : ×%.2f" % power_mul)
	print("    进化继承（满 E3）          : ×%.2f  (+40%%)" % inherit_mul)
	print("    军衔（元帅 marshal）       : hp×%.2f dmg×%.2f" % [float(rank_bonus.get("hp_mul", 1.0)), float(rank_bonus.get("dmg_mul", 1.0))])
	print("    兵种倾斜（装甲×10级）      : hp×%.2f dmg×%.2f" % [1.0 + 10.0 * hp_bias, 1.0 + 10.0 * dmg_bias])
	print("    进化 HP 下限               : ≥ %.0f" % evolution_hp_floor)
	print("")
	print("  [满配属性]")
	print("    HP        : %.0f" % stats.max_hp)
	print("    对轻装攻击: %.0f × %.2f/s" % [stats.attack_light, stats.attack_light_speed])
	print("    对装甲攻击: %.0f × %.2f/s" % [stats.attack_armor, stats.attack_armor_speed])
	print("    对空攻击  : %.0f × %.2f/s" % [stats.attack_air, stats.attack_air_speed])
	print("    三维防御  : 轻 %.0f / 装甲 %.0f / 空 %.0f" % [stats.defense_light, stats.defense_armor, stats.defense_air])
	print("    暴击率    : %.0f%%" % (stats.crit_chance * 100.0))
	print("    穿甲      : %.0f" % stats.armor_penetration)
	print("    移速      : %.0f" % stats.move_speed)
	print("")
	print("  ══════════════════════════════════════════")
	print("  ★ 我方满配 fut_colossus 战力 = %.0f" % power)
	print("  ══════════════════════════════════════════")
	# 缓存到 root 供汇总读取
	Engine.get_main_loop().root.set_meta("s1_player_power", power)
	Engine.get_main_loop().root.set_meta("s1_player_hp", stats.max_hp)


# 内部：同时乘 attack_damage / weapons[] / weapon_slots[]
func _mul_attack(stats, factor: float) -> void:
	if stats == null or factor == 1.0:
		return
	stats.attack_damage *= factor
	for i in range(stats.weapons.size()):
		var w: Dictionary = stats.weapons[i] as Dictionary
		if w == null:
			continue
		if w.has("damage"):
			w["damage"] = float(w["damage"]) * factor
			stats.weapons[i] = w
	if stats.has_method("_sync_weapon_slots_damage"):
		stats._sync_weapon_slots_damage(factor)


# ═══════════════════════════════════════════════════════════
#  段2：敌方非相位师 fut_arm_colossus_e（第100关普通敌兵）
# ═══════════════════════════════════════════════════════════
func _section2_enemy_non_master() -> void:
	print("┌────────────────────────────────────────────────────────────┐")
	print("│ ② 敌方非相位师 fut_arm_colossus_e（普通敌兵，第100关满配） │")
	print("│    走 resolve_classic_enemy（wave×level×faction_buff 链）  │")
	print("└────────────────────────────────────────────────────────────┘")

	# 手动构造 EnemyStatContext（不依赖 autoload，纯函数）
	# 第100关：era=4（近未来），faction=void_research（虚空相位）满级 Lv10
	# 坚守 15 波，取末波 wave=15（最难的最后一波）
	var ctx := EnemyStatContext.new(100, 15)
	ctx.master_stats = {}  # 非相位师战，master_stats 空 → m_atk/m_hp = 1.0
	ctx.faction_buff = FactionConquestBuffs.get_buff("void_research", 10)
	ctx.difficulty_multiplier = 1.0  # 普通难度
	ctx.faction_id = "void_research"
	ctx.faction_level = 10

	# 调真实公式（注：--script 模式下 EnemyArchetypes.get_config 走 JSON 合并路径可能返回空，
	# 此时 resolve_classic_enemy 走 fallback 公式 (60+wave×15) 而非真实 archetype 数据。
	# 为了拿到真实数字，下面同时提供"手动复现真实公式"的对照计算。）
	var resolved: Dictionary = EnemyStatResolver.resolve_classic_enemy("fut_arm_colossus_e", ctx)

	# archetype 原始字段
	# 注：--script 模式下 EnemyArchetypes.get_config 可能走 JSON 合并路径返回空，
	# 直接 preload _ArchFuture.DATA 拿真实数据（const Dictionary，不受初始化顺序影响）
	var cfg: Dictionary = _ArchFuture.DATA.get("fut_arm_colossus_e", {})
	if cfg.is_empty():
		# 兜底：尝试走 get_config（autoload 完整时能命中）
		cfg = EnemyArchetypes.get_config("fut_arm_colossus_e")
	var base_hp := float(cfg.get("hp", 0.0))
	var base_atk := float(cfg.get("attack_damage", 0.0))

	# 乘区拆解
	var w_hp := 1.0 + 0.12 * (15 - 1)    # = 2.68
	var w_dmg := 1.0 + 0.08 * (15 - 1)   # = 2.12
	var lvl := 0.8 + 100 * 0.014         # = 2.2
	var f_hp := float(ctx.faction_buff.get("hp_mul", 1.0))   # void_research Lv10 = 1.16
	var f_atk := float(ctx.faction_buff.get("attack_mul", 1.0))  # = 1.40
	var f_spd := float(ctx.faction_buff.get("speed_mul", 1.0))   # = 1.08

	# 手动复现真实公式（cfg 有真实数据时为准；resolve_classic_enemy 走 fallback 时用此结果）
	var hp_mul_chain := w_hp * lvl * f_hp  # ×1.0（master/difficulty 都为 1）
	var dmg_mul_chain := w_dmg * lvl * f_atk
	var real_hp := base_hp * hp_mul_chain
	# fut_arm_colossus_e combat_kind 未在 cfg 显式标注，tags=[elite,tank,armored] → 视为 ARMOR（装甲）
	# 装甲三维攻击派生：对装甲=base, 对轻装=base×0.7, 对空=base×0.3
	var real_atk_base := base_atk * dmg_mul_chain
	var real_atk_l := real_atk_base * 0.7
	var real_atk_a := real_atk_base
	var real_atk_air := real_atk_base * 0.3
	# 移速：cfg.speed=-60（向左），乘 f_spd
	var real_move := -absf(float(cfg.get("speed", -60.0))) * f_spd

	# v7.x 修复后：spawn 后追加的 tier 加成（之前漏算导致用户看到"HP 比理论值高/低飘忽"）
	# 第100关 era_local=20 → era_progress=1.0 → TIER_HIGH（hp_pct=0.30, atk_pct=0.35）
	# 修复前：tier 只改 stats 不同步裸字段 → 血条显示未加成 HP（实际脆 30%）
	#         只有 elite 词缀 roll 到 max_hp 时才"意外"同步（飘忽不定）
	# 修复后：_sync_bare_fields_from_stats() 统一同步，tier 加成稳定生效
	var tier_hp_mul := 1.30  # TIER_HIGH hp_pct=0.30
	var tier_atk_mul := 1.35  # TIER_HIGH atk_pct=0.35
	var visible_hp := real_hp * tier_hp_mul
	var visible_atk_a := real_atk_a * tier_atk_mul

	# 敌方没有正式 combat_power 概念，但为对比硬套一下我方公式（量级参照）
	var pseudo_power := _enemy_pseudo_power({
		"hp": visible_hp, "attack_light": real_atk_l * tier_atk_mul, "attack_armor": visible_atk_a,
		"attack_air": real_atk_air * tier_atk_mul, "attack_interval": float(cfg.get("attack_interval", 1.0)),
		"defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0,
		"move_speed": real_move,
	})

	print("  [第100关乘区链]")
	print("    archetype 原始              : HP=%.0f  ATK=%.0f  range=%.0f  spd=%.0f" %
		[base_hp, base_atk, float(cfg.get("attack_range", 0.0)), absf(float(cfg.get("speed", 0.0)))])
	print("    wave 末波(15) HP×ATK        : ×%.2f / ×%.2f" % [w_hp, w_dmg])
	print("    level(100)                  : ×%.2f" % lvl)
	print("    void_research Lv10 HP×ATK   : ×%.2f / ×%.2f（spd ×%.2f）" % [f_hp, f_atk, f_spd])
	print("    difficulty(普通)            : ×1.00")
	print("    master_stats（非相位师战）  : ×1.00 / ×1.00（空，无加成）")
	print("    综合 HP×ATK 乘区链(resolver): ×%.2f / ×%.2f" % [hp_mul_chain, dmg_mul_chain])
	print("    + loadout tier TIER_HIGH    : HP ×%.2f / ATK ×%.2f（spawn 后追加，v7.x 修复后稳定同步）" % [tier_hp_mul, tier_atk_mul])
	print("")
	print("  [第100关满配属性（末波·修复后实际可见）]")
	print("    HP        : %.0f   (= %.0f × %.2f × %.2f × %.2f × %.2f)" %
		[visible_hp, base_hp, w_hp, lvl, f_hp, tier_hp_mul])
	print("    对轻装攻击: %.0f   (base×0.7×tier)" % (real_atk_l * tier_atk_mul))
	print("    对装甲攻击: %.0f   (base×1.0×tier，装甲单位主攻维度)" % visible_atk_a)
	print("    对空攻击  : %.0f   (base×0.3×tier)" % (real_atk_air * tier_atk_mul))
	print("    射程/攻速 : range=%.0f  interval=%.2f/s" %
		[float(cfg.get("attack_range", 0.0)), float(cfg.get("attack_interval", 1.0))])
	print("    移速      : %.0f" % absf(real_move))
	print("    [对照] 修复前（tier 未同步）HP = %.0f（血条显示这个，实际脆 30%%）" % real_hp)
	print("    [对照] resolve_classic_enemy 返回 HP=%.0f（resolver 原始输出，不含 tier）" %
		float(resolved.get("hp", 0.0)))
	print("")
	print("  ══════════════════════════════════════════")
	print("  ★ 敌方非相位师无正式战力概念（combat_power_from_unit_stats 敌方零调用）")
	print("    仅供量级参照（硬套我方公式）: %.0f（修复后）/ %.0f（修复前）" % [pseudo_power, _enemy_pseudo_power({"hp": real_hp, "attack_light": real_atk_l, "attack_armor": real_atk_a, "attack_air": real_atk_air, "attack_interval": float(cfg.get("attack_interval", 1.0)), "defense_light": 0.0, "defense_armor": 0.0, "defense_air": 0.0, "move_speed": real_move})])
	print("  ══════════════════════════════════════════")

	Engine.get_main_loop().root.set_meta("s2_enemy_hp", visible_hp)
	Engine.get_main_loop().root.set_meta("s2_enemy_pseudo_power", pseudo_power)


# 敌方属性硬套我方战力公式（量级参照，非真实游戏数值）
func _enemy_pseudo_power(r: Dictionary) -> float:
	var hp := float(r.get("hp", 0.0))
	var atk_l := float(r.get("attack_light", 0.0))
	var atk_a := float(r.get("attack_armor", 0.0))
	var atk_air := float(r.get("attack_air", 0.0))
	var itv := float(r.get("attack_interval", 1.0))
	var spd := 1.0 / itv if itv > 0.0 else 1.0
	# 敌方 archetype 只有一维攻击数据（attack_damage），三维派生后 atk_l 通常占大头
	var dps_raw := atk_l * spd + atk_a * spd + atk_air * spd
	var def_sum := float(r.get("defense_light", 0.0)) + float(r.get("defense_armor", 0.0)) + float(r.get("defense_air", 0.0))
	var move := absf(float(r.get("move_speed", 0.0)))
	var out := hp * 0.35 + dps_raw * 0.75 + spd * 25.0 + def_sum * 2.1 + move * 0.25
	return maxf(out, 1.0)


# ═══════════════════════════════════════════════════════════
#  段3：敌方相位师 master_030（第100关 boss 满配）
# ═══════════════════════════════════════════════════════════
func _section3_enemy_master() -> void:
	print("┌────────────────────────────────────────────────────────────┐")
	print("│ ③ 敌方相位师 master_030（全能相位师·奥米伽，第100关 boss） │")
	print("│    走 MasterPowerEvaluator.evaluate（3 分量 A+F+H）        │")
	print("└────────────────────────────────────────────────────────────┘")

	# 直接读真数据（避开 LEGACY_ENEMY_MASTERS 静态初始化 bug）
	var master: Dictionary = EnemyPhaseMasters.get_master_by_id("enemy_master_030")
	if master.is_empty():
		push_error("[FAIL] master_030 未找到")
		return

	# 派生符文/序列（v7.x 符文之语驱动，hash(master_id) 可复现）
	var enriched: Dictionary = EnemyPhaseMasters.get_enriched_equipment("enemy_master_030")
	master["equipment"] = enriched

	# 调真实公式
	var result: Dictionary = MasterPowerEvaluator.evaluate(master)
	var total: float = float(result.get("total_score", 0.0))
	var stars: int = int(result.get("stars", 0))
	var star_name: String = String(result.get("star_name", ""))
	var scores: Dictionary = result.get("scores", {})
	var lvl: int = EnemyPhaseMasters.compute_display_level(master)
	var tier := PowerTiers.get_tier_by_stars(stars)

	# 原始 master.stats
	var mstats: Dictionary = master.get("stats", {})

	print("  [master_030 原始属性]")
	print("    max_hp        : %.0f" % float(mstats.get("max_hp", 0)))
	print("    attack_power  : %.0f" % float(mstats.get("attack_power", 0)))
	print("    defense       : %.0f" % float(mstats.get("defense", 0)))
	print("    energy_regen  : %.1f/s" % float(mstats.get("energy_regen", 0)))
	print("    unit_limit    : %.0f" % float(mstats.get("unit_limit", 0)))
	print("    level(派生 Lv): %d" % lvl)
	print("    装备相位仪    : %s" % String(master.get("equipment", {}).get("phase_instrument", "")))
	print("    装备平台      : %s" % str(master.get("equipment", {}).get("platforms", [])))
	print("    派生符文      : %s" % str(master.get("equipment", {}).get("runes", [])))
	print("")
	print("  [3 分量战力拆解（v7.x 终版公式）]")
	print("    A 相位仪战力  : %.0f   (star²×10 + 主动能力+50)" % float(scores.get("instrument", 0)))
	print("    F 装备卡战力  : %.0f   (注：敌方 *_expert 平台 id 不在 UCT，走兜底100/卡)" % float(scores.get("equipment_slots", 0)))
	print("    H 符文战力    : %.0f   (按符文稀有度固定值求和)" % float(scores.get("runes", 0)))
	print("")
	print("  ══════════════════════════════════════════")
	print("  ★ 敌方相位师 master_030 总战力 = %.0f" % total)
	print("    星级：%d★ %s  |  派生 Lv：%d  |  战力档位：%s" %
		[stars, star_name, lvl, _tier_name(tier)])
	print("  ══════════════════════════════════════════")
	print("")
	print("  [参照] master_030 召唤的产兵（fut_arm_colossus_e 为基础）")
	print("    产兵走独立加成链（不进 master 总分）：")
	print("      archetype HP600/ATK55 × master×1.80(ATK) × sequence elite×1.25/boss×1.50")
	print("      × 符文 × 相位仪 × 强化等级 × 波次难度")
	print("    产兵 HP 单只量级约 3000-6000+（精英/Boss 加成后更高）")

	Engine.get_main_loop().root.set_meta("s3_master_power", total)
	Engine.get_main_loop().root.set_meta("s3_master_stars", stars)


func _tier_name(tier: int) -> String:
	match tier:
		PowerTiers.Tier.GRUNT: return "GRUNT 杂兵"
		PowerTiers.Tier.VETERAN: return "VETERAN 老兵"
		PowerTiers.Tier.ELITE: return "ELITE 精英"
		PowerTiers.Tier.CHAMPION: return "CHAMPION 冠军"
		PowerTiers.Tier.OVERLORD: return "OVERLORD 霸主"
		_: return "未知(%d)" % tier


# ═══════════════════════════════════════════════════════════
#  汇总
# ═══════════════════════════════════════════════════════════
func _summary() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Node = tree.root
	var s1 := float(root.get_meta("s1_player_power", 0.0))
	var s1_hp := float(root.get_meta("s1_player_hp", 0.0))
	var s2_hp := float(root.get_meta("s2_enemy_hp", 0.0))
	var s2_pseudo := float(root.get_meta("s2_enemy_pseudo_power", 0.0))
	var s3 := float(root.get_meta("s3_master_power", 0.0))
	var s3_stars := int(root.get_meta("s3_master_stars", 0))

	print("╔══════════════════════════════════════════════════════════════╗")
	print("║                        ★ 汇总对照表 ★                      ║")
	print("╠══════════════════════════════════════════════════════════════╣")
	print("║ 情境             │ 战力/分数      │ HP          │ 说明      ║")
	print("╠══════════════════╪════════════════╪═════════════╪═══════════╣")
	print("║ ① 我方满配       │ %-13.0f  │ %-10.0f  │ fut_colossus 满╳" % [s1, s1_hp])
	print("║                  │                │             │ 强化+改造+进化║")
	print("║ ② 敌方非相位师   │ N/A(无战力)    │ %-10.0f  │ 普通敌兵    ║" % s2_hp)
	print("║    （硬套公式）   │ %-13.0f  │             │ 仅量级参照  ║" % s2_pseudo)
	print("║ ③ 敌方相位师     │ %-13.0f  │ master本体 │ master_030 ║" % s3)
	print("║                  │                │ HP=10000    │ %d★ 满╳" % s3_stars)
	print("╚══════════════════╧════════════════╧═════════════╧═══════════╝")
	print("")
	print("说明：")
	print("  • 我方/敌方卡牌走两套完全不同的属性管线，'战力' 数值不可直接横比")
	print("  • 我方'战力'是单一数字（combat_power_from_unit_stats，用于军衔/改造门槛）")
	print("  • 敌方非相位师没有正式战力概念，只有 HP/三维攻击/防御等原始属性")
	print("  • 敌方相位师战力是 3 分量总分（A相位仪+F载卡+H符文），用于星级评估")
	print("  • 基准卡选巨神机甲（近未来 era=4），我方卡=fut_colossus，敌方对应=fut_arm_colossus_e")
