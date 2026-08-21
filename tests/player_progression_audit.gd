# 玩家养成分层审计：各时代典型养成进度下的真实敌/我战力比
# Usage: godot --headless --rendering-driver opengl3 --path . --script tests/_tmp_progression_audit.gd
extends SceneTree

const DefaultCards := preload("res://data/default_cards.gd")
const UnitStatsTable := preload("res://resources/unit_stats_table.gd")
const EvolutionHelpers := preload("res://managers/evolution/evolution_helpers.gd")
const ModificationRegistry := preload("res://scripts/systems/modification_registry.gd")
const PhaseInstruments := preload("res://data/phase_instruments.gd")
const RunewordDefs := preload("res://data/runewords.gd")
const SkillTree := preload("res://data/phase_master_skill_tree.gd")
const FactionTree := preload("res://data/faction_skill_tree.gd")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")
const EnemyStatResolver := preload("res://data/enemy_stat_resolver.gd")
const EnemyStatContext := preload("res://data/enemy_stat_context.gd")
const CardGrowthConfig := preload("res://data/card_growth_config.gd")

## 各时代典型养成进度（进度推进假设：玩家在该时代后段的养成状态）
## v18.c 新增 card_lv：卡等级（经验口径 60/关/卡 → 该时代后段 ≈ 关20/40/60/80/100 的等级）
const STAGES := [
	{"era": 0, "enh": 4, "mods": 3, "star": 3, "field": 0.2, "rw_tier": 2, "tree": 0.2, "fac": 0.0, "card_lv": 7},
	{"era": 1, "enh": 6, "mods": 6, "star": 4, "field": 0.4, "rw_tier": 2, "tree": 0.4, "fac": 0.3, "card_lv": 9},
	{"era": 2, "enh": 8, "mods": 9, "star": 5, "field": 0.6, "rw_tier": 3, "tree": 0.6, "fac": 0.6, "card_lv": 10},
	{"era": 3, "enh": 10, "mods": 9, "star": 6, "field": 0.8, "rw_tier": 4, "tree": 0.8, "fac": 0.8, "card_lv": 12},
	{"era": 4, "enh": 10, "mods": 9, "star": 7, "field": 1.0, "rw_tier": 5, "tree": 1.0, "fac": 1.0, "card_lv": 13},
]

## 敌方等级镜像用代表关卡（该时代后段）：ctx.level 供 resolver 关卡→等级映射（ceil(关×0.3)）
const ERA_STAGE := [17, 37, 57, 77, 97]

var _power_cache: Dictionary = {}


func _power(st) -> float:
	return EvolutionHelpers.combat_power_from_unit_stats(st)


func _pct_scale(st, atk_p: float, def_p: float, hp_p: float) -> void:
	if atk_p != 0.0:
		st.attack_light *= (1.0 + atk_p)
		st.attack_armor *= (1.0 + atk_p)
		st.attack_air *= (1.0 + atk_p)
	if def_p != 0.0:
		st.defense_light *= (1.0 + def_p)
		st.defense_armor *= (1.0 + def_p)
		st.defense_air *= (1.0 + def_p)
	if hp_p != 0.0:
		st.max_hp *= (1.0 + hp_p)


func _era_cards(e: int) -> Array:
	var out: Array = []
	for cid in DefaultCards.get_all_blueprint_ids_lightweight():
		var card = DefaultCards.get_card_by_id(cid)
		if card == null or int(card.card_type) != 0 or int(card.era) != e:
			continue
		var c0 = card.clone()
		c0.enhance_level = 10
		var st0 = UnitStatsTable.build_stats_from_card(c0, 0)
		if st0 != null:
			out.append({"card": card, "p": _power(st0)})
	out.sort_custom(func(a, b): return float(a.p) < float(b.p))
	return out


func _stage_mods(card, count: int) -> Array:
	# get_mods_for_card 按 card_id 精筛；只取"数值类"改造（effects 命中属性键）——
	# 池前几个常是 command_efficiency/vision 等非数值改造，装了对战力零贡献
	var pool: Array = ModificationRegistry.get_mods_for_card(String(card.card_id))
	var stat_keys: Array = ["attack_interval", "attack_speed", "attack_all", "attack_light",
		"attack_armor", "attack_air", "hp", "max_hp", "defense", "def_all",
		"defense_light", "defense_armor", "defense_air", "crit_chance", "dodge_chance"]
	var out: Array = []
	for m in pool:
		if out.size() >= count:
			break
		# 池元素是 mod id 字符串（非 dict）——经 get_data 取定义再筛数值类
		var mid: String = String((m as Dictionary).get("id", "")) if m is Dictionary else str(m)
		if mid.is_empty():
			continue
		var data: Dictionary = ModificationRegistry.get_data(mid)
		var fx: Dictionary = data.get("effects", {})
		var hit: bool = false
		for k in stat_keys:
			if fx.has(k):
				hit = true
				break
		if hit:
			out.append({"id": mid, "level": 1})
	return out


func _instrument_pct(star: int) -> Dictionary:
	# 同星级 generic 仪器取 pi_atk/pi_def/pi_hp 中位值
	var atks: Array = []
	var defs: Array = []
	var hps: Array = []
	for inst in PhaseInstruments.get_all():
		if int(inst.get("star", 0)) != star or not bool(inst.get("is_generic", false)):
			continue
		for p in inst.get("properties", []):
			match String(p.get("id", "")):
				"pi_atk": atks.append(float(p.get("value", 0.0)))
				"pi_def": defs.append(float(p.get("value", 0.0)))
				"pi_hp": hps.append(float(p.get("value", 0.0)))
	var med := func(arr: Array) -> float:
		if arr.is_empty():
			return 0.0
		arr.sort()
		return float(arr[arr.size() / 2])
	return {"atk": med.call(atks), "def": med.call(defs), "hp": med.call(hps)}


func _runeword_pct(tier: int) -> Dictionary:
	var words: Array = RunewordDefs.get_runewords_by_tier(tier)
	if words.is_empty():
		return {"atk": 0.0, "def": 0.0, "hp": 0.0}
	var w: Dictionary = words[words.size() / 2]  # 该档中位词
	var atk: float = 0.0
	var defv: float = 0.0
	var hp: float = 0.0
	for s in w.get("effects", []):  # runeword 定义键是 effects（非 stats）
		match String(s.get("stat", "")):
			"attack": atk += float(s.get("value", 0.0))
			"defense": defv += float(s.get("value", 0.0))
			"hp", "max_hp": hp += float(s.get("value", 0.0))
	return {"atk": atk, "def": defv, "hp": hp}


func _tree_pct(frac: float) -> Dictionary:
	# 相位师技能树全部数值节点求和 × 进度比例
	var sums: Dictionary = {"atk": 0.0, "def": 0.0, "hp": 0.0}
	for br in SkillTree.get_all_branches():
		for n in SkillTree.get_skills_for_branch(br):
			for k in (n.get("effects", {}) as Dictionary).get("stat_bonus", {}):
				var v: float = float((n.get("effects", {}) as Dictionary)["stat_bonus"][k])
				if k.begins_with("atk"):
					sums.atk += v
				elif k.begins_with("def"):
					sums.def += v
				elif k == "hp" or k == "max_hp":
					sums.hp += v
	return {"atk": sums.atk * frac, "def": sums.def * frac, "hp": sums.hp * frac}


func _faction_pct(frac: float) -> Dictionary:
	var sums: Dictionary = {"atk": 0.0, "def": 0.0, "hp": 0.0}
	var counted: int = 0
	for fid in FactionTree.get_all_faction_ids():
		for n in FactionTree.get_skills_for_faction(fid):
			var sb: Dictionary = (n.get("effects", {}) as Dictionary).get("stat_bonus", {})
			for k in sb:
				var v: float = float(sb[k])
				if k.begins_with("atk"):
					sums.atk += v
				elif k.begins_with("def"):
					sums.def += v
				elif k == "hp" or k == "max_hp":
					sums.hp += v
			counted += 1
	# 7 势力取中位势力的数值（不是全部加总——玩家只激活一个势力）
	var avg: Dictionary = {"atk": sums.atk / maxf(1.0, counted / 7.0), "def": sums.def / maxf(1.0, counted / 7.0), "hp": sums.hp / maxf(1.0, counted / 7.0)}
	return {"atk": avg.atk * frac, "def": avg.def * frac, "hp": avg.hp * frac}


func _field_pct(frac: float) -> Dictionary:
	# 相位场属性点：满级点数按 40%攻/25%防/35%血 分配
	var pts_total: int = SkillTree.max_skill_points_at_phase_field_level(16)
	var pts: float = float(pts_total) * frac
	return {"atk": pts * 0.40 * 0.02, "def": pts * 0.25 * 0.02, "hp": pts * 0.35 * 0.03}


func _enemy_median_power(e: int, tier: int) -> float:
	var powers: Array = []
	for aid in EnemyArchetypes.get_all_ids():
		var cfg: Dictionary = EnemyArchetypes.get_config(aid)
		if int(cfg.get("era", -1)) != e:
			continue
		powers.append(String(aid))
	# v18.c: ctx.level 用时代后段代表关卡——resolver 内关卡→等级映射(ceil(关×0.3))给敌方 flat
	var ctx = EnemyStatContext.new(int(ERA_STAGE[clampi(e, 0, 4)]), 1)
	ctx.tier = tier
	var vals: Array = []
	for aid in powers:
		var r: Dictionary = EnemyStatResolver.resolve_classic_enemy(aid, ctx)
		var hp: float = float(r.get("hp", 1.0))
		var atk: float = float(r.get("attack_light", 0.0)) + float(r.get("attack_armor", 0.0)) + float(r.get("attack_air", 0.0))
		var d: float = float(r.get("defense", 0.0))
		vals.append(hp * 0.35 + atk * 0.75 + d * 6.3)
	vals.sort()
	return float(vals[vals.size() / 2]) if not vals.is_empty() else 0.0


func _initialize() -> void:
	ModificationRegistry.register_all()
	var era_names := ["一战", "二战", "冷战", "现代", "近未来"]
	print("====================================================================================================")
	print("玩家养成分层审计（上场卡=p75 强卡；敌方=同代战力中位·高配档×2.0·时代后段关卡等级flat）")
	print("进度假设: 强化/改造数/仪器星/符文词/技能树/势力树/卡等级 随时代递进（见 STAGES）")
	print("====================================================================================================")
	print("时代  | 卡基准(enh) | ×改造 | ×仪器+场点 | ×符文词 | ×技能/势力树 | ×卡Lvflat | 满养成战力 | 敌兵中位 | 敌/我")
	print("-".repeat(112))
	for stage in STAGES:
		var e: int = stage.era
		var cards: Array = _era_cards(e)
		if cards.is_empty():
			continue
		var card = cards[int(cards.size() * 0.75)].card  # p75 上场卡

		# 层0：基准（该时代典型强化档，无改造）
		var c0 = card.clone()
		c0.enhance_level = int(stage.enh)
		var st0 = UnitStatsTable.build_stats_from_card(c0, 0)
		var p0: float = _power(st0)

		# 层1：+改造（真身管线：card.mods → build_stats）
		var c1 = card.clone()
		c1.enhance_level = int(stage.enh)
		c1.mods = _stage_mods(card, int(stage.mods))
		var st1 = UnitStatsTable.build_stats_from_card(c1, 0)
		var p1: float = _power(st1)

		# 层2：+相位仪+相位场点
		var inst: Dictionary = _instrument_pct(int(stage.star))
		var fld: Dictionary = _field_pct(float(stage.field))
		_pct_scale(st1, inst.atk + fld.atk, inst.def + fld.def, inst.hp + fld.hp)
		var p2: float = _power(st1)

		# 层3：+符文之语
		var rw: Dictionary = _runeword_pct(int(stage.rw_tier))
		_pct_scale(st1, rw.atk, rw.def, rw.hp)
		var p3: float = _power(st1)

		# 层4：+技能树+势力树
		var tr: Dictionary = _tree_pct(float(stage.tree))
		var fa: Dictionary = _faction_pct(float(stage.fac))
		_pct_scale(st1, tr.atk + fa.atk, tr.def + fa.def, tr.hp + fa.hp)
		var p4: float = _power(st1)

		# 层5：+卡等级 flat（v18.c 纯加法，链尾——不进上方任何乘区）
		CardGrowthConfig.apply_to_stats(st1, CardGrowthConfig.total_growth(c1, int(stage.card_lv)))
		var p5: float = _power(st1)

		var enemy: float = _enemy_median_power(e, 3)
		print("%-4s | %6.0f(e%02d) | %5.2f | %5.2f(+%2.0f%%) | %5.2f | %5.2f | %5.2f(L%02d) | %8.0f | %7.0f | %.2f" % [
			era_names[e], p0, int(stage.enh),
			p1 / p0, p2 / p1, (inst.atk + fld.atk) * 100.0,
			p3 / p2, p4 / p3, p5 / p4, int(stage.card_lv), p5, enemy, enemy / p5])
	quit(0)
