extends RefCounted
class_name MasterPlayerAssembler
## 玩家相位师星级与等级评估装配器（v6.7 / v7.x 对称化重构）
##
## 职责：从 PhaseInstrumentManager 实时装配玩家 master dict，
## 喂给 MasterPowerEvaluator.evaluate() 算出玩家相位师星级（1-7★）与展示等级（Lv5-30）。
##
## v7.x 对称化重构（推翻"相位师无等级"原始设计）：
##   - 玩家走完整 9 维评估（A-I），与敌方口径对称
##   - F 维改用真实卡牌战力（含相位仪加成后的 stats），不再写死 100.0
##   - D 维把相位仪 active_ability 映射成 active_spells 计分
##   - H/I 维把符文塞进 equipment.runes，让符文之语计分对称生效
##   - 总分做 log10 压缩到敌方 434-2210 同尺，使敌我 Lv 可直接横向对比
##
## 等级链路（与用户确认）：
##   满相位仪 + 战斗卡（加相位仪加成后）+ 技能(active_ability) + 满相位仪卡位符文
##   → 9维军团战力 → log10压缩 → 派生Lv5-30 + 星级(1-7★)

const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const RunewordMatcher = preload("res://managers/runeword_matcher.gd")
const RuneDefs = preload("res://data/runes.gd")
const RunewordDefs = preload("res://data/runewords.gd")
const EvolutionHelpers = preload("res://managers/evolution/evolution_helpers.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")

## 极端兜底分（完全无战斗卡时，保证最小星级不崩）
const PLAYER_BASELINE_SCORE: float = 120.0

# ─────────────────────────────────────────────────────────────
# v7.x 对称化最终版：不做压缩，用真实战力值。
# 总战力 = F维(卡真实战力×系数) + A维(相位仪加成战力) + H维(符文固定值) + 其他维
# Lv 用 log10 映射（跨度大：新手~200 / 终极~18万），与敌方 compute_display_level 同区间。
# ─────────────────────────────────────────────────────────────

## Lv 映射区间（与敌方一致：200→Lv5，180000→Lv30）
const DISPLAY_LEVEL_LO: int = 5
const DISPLAY_LEVEL_HI: int = 30
const RAW_LO_FOR_LV: float = 200.0
const RAW_HI_FOR_LV: float = 180000.0

# ─────────────────────────────────────────────────────────────
# v7.x 对称化最终版：删 D维(技能)单独计分——相位仪技能价值体现在 A维(相位仪加成战力)内。
# active_ability 映射表已移除。


# ═══════════════════════════════════════════════════════════════
#  主入口：装配玩家 master dict
# ═══════════════════════════════════════════════════════════════

## 装配玩家 master dict（喂给 MasterPowerEvaluator）
## pm: PhaseInstrumentManager autoload 节点
static func build_player_master_dict(pm: Node) -> Dictionary:
	if pm == null or not is_instance_valid(pm):
		return {}

	# 1. 相位仪 —— 取当前装备相位仪的 id + star
	var instr_cfg: Dictionary = {}
	if pm.has_method("get_current_instrument"):
		instr_cfg = pm.get_current_instrument()
	var instr_id: String = str(instr_cfg.get("id", ""))
	var instr_star: int = int(instr_cfg.get("star", 1))

	# 2. 战斗卡 —— green 槽的战斗卡，同时预算每张卡的"相位仪加成后真实战力"
	var platforms: Array = []
	var weapons: Array = []
	var energy_cards: Array = []
	var platform_powers: Array[float] = []  # v7.x: 每张战斗卡的真实战力（含相位仪加成）
	var loadout_cards: Array = []  # 保留 CardResource 引用以供电台取养成
	if pm.has_method("get_loadouts"):
		var loadouts: Array = pm.get_loadouts()
		for ld in loadouts:
			if not (ld is Dictionary):
				continue
			var plat = ld.get("platform", null)
			if plat != null and plat is CardResource:
				platforms.append(plat.card_id)
				loadout_cards.append(plat)
				# v7.x: 预算真实战力（含养成 + 相位仪加成）
				platform_powers.append(_compute_player_card_power(plat, pm))
			var ws = ld.get("weapons", [])
			if ws is Array:
				for w in ws:
					if w != null and w is CardResource and not w.card_id.is_empty():
						weapons.append(w.card_id)

	# 3. 符文 + 符文之语 —— 转成 engraved_affixes（B维重写用）+ equipment.runes（H/I维用）
	var rune_slots: Array = []
	if pm.has_method("get_rune_slots"):
		rune_slots = pm.get_rune_slots()
	var slot_count: int = 0
	if pm.has_method("get_rune_slot_count"):
		slot_count = pm.get_rune_slot_count()
	else:
		slot_count = rune_slots.size()

	var engraved_affixes: Array = []
	# 3a. 每个装备的符文 → 一条刻印（B维）
	for slot_v in rune_slots:
		if slot_v == null:
			continue
		var rune_id: String = str(slot_v)
		if rune_id.is_empty():
			continue
		engraved_affixes.append({
			"engraving_id": "rune_%s" % rune_id,
			"progress": 1.0,
			"active": true,
		})
	# 3b. 每个激活的符文之语 → 一条刻印（B维）
	var active_runewords: Array = []
	if pm.has_method("get_active_runewords"):
		active_runewords = pm.get_active_runewords()
	else:
		active_runewords = RunewordMatcher.check_active_runewords(rune_slots, slot_count)
	for rw in active_runewords:
		var rw_id: String = str(rw.get("id", ""))
		if rw_id.is_empty():
			continue
		engraved_affixes.append({
			"engraving_id": "runeword_%s" % rw_id,
			"progress": 1.0,
			"active": true,
		})

	# v7.x: 把符文 ID 列表塞进 equipment.runes，让 evaluator 的 H/I 维对称生效
	var rune_ids_clean: Array = []
	for slot_v in rune_slots:
		if slot_v == null:
			continue
		var rid: String = str(slot_v)
		if not rid.is_empty():
			rune_ids_clean.append(rid)

	# 4. v7.x 对称化最终版：D维(技能)已删，相位仪技能价值在 A维(加成战力)内
	var active_ability: Dictionary = {}
	if pm.has_method("get_active_ability"):
		active_ability = pm.get_active_ability()

	# 5. v7.x: A维相位仪加成战力 = 加成后战力 - 加成前战力（全部战斗卡汇总）
	#    平台卡战力已含加成（_compute_player_card_power 内部调 apply_phase_field_bonus）
	#    再单独算一次"无加成"版本，差值即相位仪贡献
	var platform_powers_no_bonus: Array[float] = []
	for card in loadout_cards:
		platform_powers_no_bonus.append(_compute_player_card_power_no_bonus(card))
	var inst_bonus_total: float = 0.0
	for i in range(platform_powers.size()):
		var with_bonus: float = platform_powers[i] if i < platform_powers.size() else 0.0
		var no_bonus: float = platform_powers_no_bonus[i] if i < platform_powers_no_bonus.size() else 0.0
		inst_bonus_total += maxf(0.0, with_bonus - no_bonus)

	# 6. 极端兜底分 —— 仅当无战斗卡时注入虚拟被动
	var baseline_passives: Array = []
	if platforms.is_empty():
		baseline_passives.append({
			"id": "player_baseline",
			"name": "玩家基底",
			"effect": "automation",
			"params": {"value": PLAYER_BASELINE_SCORE / 5.0},
		})

	return {
		"id": "player_runtime",
		"name": "玩家",
		"faction": "",
		"phase_instrument": instr_id,
		"engraved_affixes": engraved_affixes,
		"traits": [],
		"active_spells": [],  # v7.x: D维已删
		"passive_spells": baseline_passives,
		"equipment": {
			"platforms": platforms,
			"weapons": weapons,
			"energy_cards": energy_cards,
			"runes": rune_ids_clean,  # H维读这里
		},
		# 扩展字段（带下划线前缀，evaluator 原版不读）
		"_player_instrument_star": instr_star,
		"_player_rune_slots": rune_slots,
		"_player_active_runewords": active_runewords,
		"_player_platform_powers": platform_powers,  # F维用（含相位仪加成）
		"_player_inst_bonus_total": inst_bonus_total,  # A维用（相位仪加成战力）
		"_player_active_ability": active_ability,  # 供 UI 展示
	}


# ═══════════════════════════════════════════════════════════════
#  F 维：单张战斗卡真实战力（含养成 + 相位仪加成）
# ═══════════════════════════════════════════════════════════════

## v7.x: 计算单张玩家战斗卡的"加相位仪加成后"真实战力
## 链路：CardResource(实例) → build_stats(含养成) → apply_phase_field_bonus → combat_power
## card: 平台卡 CardResource（可能是实例，含养成数据）
## pm: PhaseInstrumentManager（调 apply_phase_field_bonus_to_unit_stats）
static func _compute_player_card_power(card: CardResource, pm: Node) -> float:
	if card == null:
		return 0.0
	# 取 BlueprintManager autoload（apply_growth_to_stats 需要）
	var bpm: Node = Engine.get_main_loop().root.get_node_or_null("BlueprintManager")
	if bpm == null:
		return 100.0  # bpm 不可用时回退基础分（不崩）
	# 1. build stats（含养成：强化/改造/稀有度/inherit/军衔）
	var stats = EvolutionHelpers.build_unit_stats_for_power_preview(card, bpm)
	if stats == null:
		return 100.0
	# 2. 叠加相位仪加成（相位场属性点 + 相位仪固有属性 + 星级系数）
	#    注意：apply_phase_field_bonus_to_unit_stats 是实例方法，读 pm._cached_player_rank_stars
	#    首次评估时默认 3★=1.0，不会死循环（评估完才 set 高星）
	if pm != null and is_instance_valid(pm) and pm.has_method("apply_phase_field_bonus_to_unit_stats"):
		pm.apply_phase_field_bonus_to_unit_stats(stats)
	# 3. 算战力
	return EvolutionHelpers.combat_power_from_unit_stats(stats)


## v7.x: 计算单张玩家战斗卡的"无相位仪加成"战力（用于 A 维差值计算）
## 链路：CardResource(实例) → build_stats(含养成) → combat_power（不调 apply_phase_field_bonus）
static func _compute_player_card_power_no_bonus(card: CardResource) -> float:
	if card == null:
		return 0.0
	var bpm: Node = Engine.get_main_loop().root.get_node_or_null("BlueprintManager")
	if bpm == null:
		return 100.0
	var stats = EvolutionHelpers.build_unit_stats_for_power_preview(card, bpm)
	if stats == null:
		return 100.0
	return EvolutionHelpers.combat_power_from_unit_stats(stats)


# ═══════════════════════════════════════════════════════════════
#  评估主函数：真实战力评估 + 派生 Lv（不压缩）
# ═══════════════════════════════════════════════════════════════

## 计算玩家相位师星级（1-7★）+ 展示等级（Lv5-30）
## 调用 MasterPowerEvaluator 拿 G/H 维，A/B/F 维用玩家专用重写覆盖。
## 返回：{stars, star_name, total_score, raw_total_score, display_level, scores}
static func evaluate_player_stars(pm: Node) -> Dictionary:
	var master: Dictionary = build_player_master_dict(pm)
	if master.is_empty():
		# 无法装配——返回基准 3★ Lv15（向后兼容）
		return {
			"stars": 3, "total_score": 0.0, "star_name": "高手",
			"raw_total_score": 0.0,
			"display_level": 15, "scores": {},
		}

	# ── 先用 evaluator 跑完整 9 维（G/H 维靠这一步拿到值）──
	var full_eval: Dictionary = MasterPowerEvaluator.evaluate(master)
	var scores: Dictionary = full_eval.get("scores", {}).duplicate()

	# ── A 维重写：玩家相位仪加成战力（=给卡的加成战力，evaluator 原版查不到玩家仪器）──
	scores.instrument = _eval_instrument_player(master)
	# ── B 维重写：玩家刻印（符文，evaluator 原版查刻印表查不到）──
	scores.engravings = _eval_engravings_player(master)
	# ── F 维重写：玩家载卡战力（用 _player_platform_powers 真实值）──
	scores.equipment_slots = _eval_equipment_slots_player(master)

	# ── 重算总分（真实值，不压缩）──
	var total: float = (
		scores.instrument * MasterPowerEvaluator.W_INSTRUMENT
		+ scores.engravings * MasterPowerEvaluator.W_ENGRAVINGS
		+ scores.traits * MasterPowerEvaluator.W_TRAITS
		+ scores.active_spells * MasterPowerEvaluator.W_ACTIVE_SPELLS
		+ scores.passive_spells * MasterPowerEvaluator.W_PASSIVE_SPELLS
		+ scores.equipment_slots * MasterPowerEvaluator.W_EQUIPMENT_SLOTS
		+ scores.master_stats * MasterPowerEvaluator.W_MASTER_STATS
		+ scores.runes * MasterPowerEvaluator.W_RUNES
		+ scores.runewords * MasterPowerEvaluator.W_RUNEWORDS
	)

	# ── 星级判定（基于真实总分）──
	var star_info: Dictionary = MasterPowerEvaluator._score_to_stars(total)
	# ── 派生展示等级（log10 映射，与敌方同区间）──
	var display_lvl: int = _raw_to_display_level(total)

	return {
		"stars": int(star_info.get("stars", 1)),
		"star_name": str(star_info.get("name", "")),
		"star_color": str(star_info.get("color", "")),
		"total_score": total,  # 真实总分（不压缩）
		"raw_total_score": total,  # 兼容字段
		"display_level": display_lvl,  # 展示等级 Lv5-30
		"scores": scores,
	}


# ═══════════════════════════════════════════════════════════════
#  派生等级（log10 映射，与敌方 compute_display_level 同区间）
# ═══════════════════════════════════════════════════════════════

## v7.x: 真实总分 → 展示等级 Lv5-30（log10 映射，跨度大）
## 200→Lv5，180000→Lv30，与敌方 compute_display_level 同区间
static func _raw_to_display_level(total: float) -> int:
	if total <= 0.0:
		return DISPLAY_LEVEL_LO
	var log_lo: float = log(RAW_LO_FOR_LV) / log(10.0)
	var log_hi: float = log(RAW_HI_FOR_LV) / log(10.0)
	var log_t: float = log(maxf(total, 1.0)) / log(10.0)
	var t: float = clampf((log_t - log_lo) / maxf(log_hi - log_lo, 0.001), 0.0, 1.0)
	var lvl: int = roundi(float(DISPLAY_LEVEL_LO) + t * float(DISPLAY_LEVEL_HI - DISPLAY_LEVEL_LO))
	return clampi(lvl, DISPLAY_LEVEL_LO, DISPLAY_LEVEL_HI)


## v7.x: 便捷重载——直接传 pm 算展示等级（供 UI 调用）
static func get_player_display_level(pm: Node) -> int:
	var r: Dictionary = evaluate_player_stars(pm)
	return int(r.get("display_level", 15))


## v7.x: 便捷查询——返回完整展示文本 "Lv.20 4★ 大师"（供 UI 调用）
static func get_player_display_text(pm: Node) -> String:
	var r: Dictionary = evaluate_player_stars(pm)
	return "Lv.%d %d★ %s" % [
		int(r.get("display_level", 15)),
		int(r.get("stars", 3)),
		str(r.get("star_name", "")),
	]


# ═══════════════════════════════════════════════════════════════
#  玩家专用维度评估（A维/B维/F维重写，G/H/I/C/D/E 复用 evaluator）
# ═══════════════════════════════════════════════════════════════

## A维：玩家相位仪加成战力 = 相位仪给战斗卡的加成战力（加成后 - 加成前）
## v7.x 对称化最终版：用户要求"相位仪战力 = 它给卡的加成战力"。
## build_player_master_dict 已预算 _player_inst_bonus_total（全部卡加成后-加成前之和）。
static func _eval_instrument_player(master: Dictionary) -> float:
	var bonus: float = float(master.get("_player_inst_bonus_total", 0.0))
	if bonus > 0.0:
		return bonus
	# 无战斗卡时，用 star 做基础兜底（避免 A 维归零）
	var star: int = clampi(int(master.get("_player_instrument_star", 1)), 1, 7)
	return 200.0 + float(star - 1) * 125.0


## B维：玩家符文战力（v7.x 对称化最终版：按稀有度固定值，与 evaluator H 维一致）
## 符文之语不单独计分（I 维已删），其价值已体现在符文战力内。
static func _eval_engravings_player(master: Dictionary) -> float:
	var rune_slots: Array = master.get("_player_rune_slots", [])
	# 用 evaluator 的固定值表（与 H 维同口径）
	var rune_power: Dictionary = MasterPowerEvaluator.RUNE_RARITY_POWER
	var total: float = 0.0
	for slot_v in rune_slots:
		if slot_v == null:
			continue
		var rune_id: String = str(slot_v)
		if rune_id.is_empty():
			continue
		var rune_def: Dictionary = RuneDefs.get_rune(rune_id)
		if rune_def.is_empty():
			total += 800.0  # 查不到按 common 兜底
			continue
		var rarity: String = str(rune_def.get("rarity", "common"))
		total += float(rune_power.get(rarity, 800.0))
	return total


## F维：玩家载卡战力（v7.x 重构核心）
## 不走 evaluator 的 _platform_power_light（那个对玩家写死 100.0），
## 改用 _player_platform_powers 预计算的真实战力（含相位仪加成）求和 ×3。
## ×3 = 一张卡整场约上阵 3 次（可重复部署的经验权重，与 evaluator 原版玩家分支一致）
static func _eval_equipment_slots_player(master: Dictionary) -> float:
	var powers: Array = master.get("_player_platform_powers", [])
	if powers.is_empty():
		# 无战斗卡时回退旧"槽数×固定值"逻辑（与 evaluator 原版空槽回退一致）
		var equip: Dictionary = master.get("equipment", {})
		var weapons_arr: Array = equip.get("weapons", [])
		var energy_arr: Array = equip.get("energy_cards", [])
		return (
			weapons_arr.size() * MasterPowerEvaluator.WEAPON_COUNT_BONUS
			+ energy_arr.size() * MasterPowerEvaluator.ENERGY_CARD_BONUS
		)
	var card_power_sum: float = 0.0
	for p in powers:
		card_power_sum += float(p)
	# 玩家：一张卡整场约上阵 3 次（可重复部署的经验权重）
	return card_power_sum * 3.0
