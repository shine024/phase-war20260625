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

## 极端兜底分（完全无战斗卡时，保证最小星级不崩）
const PLAYER_BASELINE_SCORE: float = 120.0

# ─────────────────────────────────────────────────────────────
# v7.x 对称化最终版：不做压缩，用真实战力值。
# 总战力 = F维(卡真实战力×系数) + A维(相位仪加成战力) + H维(符文固定值) + 其他维
# Lv 用 log10 映射（跨度大：新手~200 / 终极~18万），与敌方 compute_display_level 同区间。
# ─────────────────────────────────────────────────────────────

## Lv 映射区间（3 分量公式：新手~50 → Lv5，满配~55000 → Lv30）
const DISPLAY_LEVEL_LO: int = 5
const DISPLAY_LEVEL_HI: int = 30
const RAW_LO_FOR_LV: float = 50.0
const RAW_HI_FOR_LV: float = 55000.0

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

	# 2. 战斗卡 —— green 槽的战斗卡，取每张卡的 get_current_power()（与 UI 显示口径一致）
	var platforms: Array = []
	var weapons: Array = []
	var energy_cards: Array = []
	var platform_powers: Array[float] = []  # v7.x: 每张卡的 get_current_power()（power字段×强化倍率+改造加成）
	var loadout_cards: Array = []  # 保留 CardResource 引用以供 A 维差值计算
	if pm.has_method("get_loadouts"):
		var loadouts: Array = pm.get_loadouts()
		for ld in loadouts:
			if not (ld is Dictionary):
				continue
			var plat = ld.get("platform", null)
			if plat != null and plat is CardResource:
				platforms.append(plat.card_id)
				loadout_cards.append(plat)
				# v7.x: 统一用 get_current_power()——与强化面板/卡牌信息显示的战力完全一致
				platform_powers.append(float(plat.get_current_power()))
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

	# 5. v7.x: A维相位仪战力 = 相位仪给所有装备卡的加成战力。
	#    get_current_power() 是 power字段×强化倍率（不含相位仪加成）。
	#    相位仪加成 = get_current_power() × 相位场总加成%（hp_pct+atk_pct+def_pct）。
	#    这与"相位仪给单位加了多少战力"语义一致。
	var pf_bonus: Dictionary = {}
	if pm.has_method("get_phase_field_total_bonus"):
		pf_bonus = pm.get_phase_field_total_bonus()
	var hp_pct: float = float(pf_bonus.get("hp_pct", 0.0))
	var atk_pct: float = float(pf_bonus.get("atk_pct", 0.0))
	var def_pct: float = float(pf_bonus.get("def_pct", 0.0))
	var total_bonus_pct: float = hp_pct + atk_pct + def_pct
	var inst_bonus_total: float = 0.0
	if total_bonus_pct > 0.0:
		for p in platform_powers:
			inst_bonus_total += float(p) * total_bonus_pct

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
#  评估主函数：真实战力评估 + 派生 Lv（不压缩）
# ═══════════════════════════════════════════════════════════════

## 计算玩家相位师星级（1-7★）+ 展示等级（Lv5-30）
## v7.x 统一公式：直接调 MasterPowerEvaluator.evaluate()（3 分量相加，敌我同口径）。
## build_player_master_dict 已注入 _player_platform_powers(get_current_power) 和
## _player_inst_bonus_total(相位仪加成战力)，evaluator 的 _eval_instrument/_eval_equipment_slots
## 会优先读这些字段，无需再重写维度。
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

	# ── 直接调统一 evaluate()（3 分量：相位仪 + 卡战力 + 符文）──
	var full_eval: Dictionary = MasterPowerEvaluator.evaluate(master)
	var total: float = float(full_eval.get("total_score", 0.0))
	var scores: Dictionary = full_eval.get("scores", {}).duplicate()

	# ── 星级判定（基于真实总分）──
	var star_info: Dictionary = MasterPowerEvaluator._score_to_stars(total)
	# ── 派生展示等级（log10 映射，与敌方同区间）──
	var display_lvl: int = _raw_to_display_level(total)

	return {
		"stars": int(star_info.get("stars", 1)),
		"star_name": str(star_info.get("name", "")),
		"star_color": str(star_info.get("color", "")),
		"total_score": total,  # 真实总分（3 分量直接相加）
		"raw_total_score": total,  # 兼容字段
		"display_level": display_lvl,  # 展示等级 Lv5-30
		"scores": scores,
	}


# ═══════════════════════════════════════════════════════════════
#  派生等级（log10 映射，与敌方 compute_display_level 同区间）
# ═══════════════════════════════════════════════════════════════

## v7.x: 真实总分 → 展示等级 Lv5-30（log10 映射，跨度大）
## 3 分量公式：50→Lv5，55000→Lv30（与敌方 compute_display_level 同区间）
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
