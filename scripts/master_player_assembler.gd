extends RefCounted
class_name MasterPlayerAssembler
## 玩家相位师星级与等级评估装配器（v7.x 单分量版）
##
## 职责：从 PhaseInstrumentManager 实时装配玩家 master dict，
## 喂给 MasterPowerEvaluator.evaluate() 算出玩家相位师星级（1-7★）与展示等级（Lv5-30）。
##
## v7.x 单分量公式（用户主导设计）：
##   相位师总战力 = Σ 每张装备卡经过完整加成后的实战力
##   - 每张 green 槽战斗卡走完整 7 层加成链路（MasterPlatformPower.compute_player_card_power）
##     → build_stats_from_card + apply_growth + 势力技能 + affix + 相位仪/相位场 + 符文之语
##     → EvolutionHelpers.combat_power_from_unit_stats
##   - 求和注入 _player_platform_powers，evaluator 直接相加
##   - 相位仪/符文/势力/词条的价值已全部体现在卡战力里（不再单独计 A/H 维）

const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const _PlatformPower = preload("res://scripts/master_platform_power.gd")
const RunewordMatcher = preload("res://managers/runeword_matcher.gd")

## 极端兜底分（完全无战斗卡时，保证最小星级不崩）
const PLAYER_BASELINE_SCORE: float = 120.0

# ─────────────────────────────────────────────────────────────
# v7.x 单分量公式：总战力 = Σ 每张装备卡加成后战力。
# Lv 用 log10 映射（与敌方 compute_display_level 同区间）。
# ─────────────────────────────────────────────────────────────

## Lv 映射区间（单分量公式：单卡加成后战力 200-5000，装 2-6 张 = 500-30000）。
## ⚠️ 玩家侧具体分布待实机跑 compute_player_card_power 后精确标定，当前区间为保守预估。
const DISPLAY_LEVEL_LO: int = 5
const DISPLAY_LEVEL_HI: int = 30
const RAW_LO_FOR_LV: float = 300.0
const RAW_HI_FOR_LV: float = 18000.0


# ═══════════════════════════════════════════════════════════════
#  主入口：装配玩家 master dict
# ═══════════════════════════════════════════════════════════════

## 装配玩家 master dict（喂给 MasterPowerEvaluator）
## pm: PhaseInstrumentManager autoload 节点
static func build_player_master_dict(pm: Node) -> Dictionary:
	if pm == null or not is_instance_valid(pm):
		return {}

	# 1. 相位仪 —— 取当前装备相位仪的 id + star（供 UI 展示，不计分）
	var instr_cfg: Dictionary = {}
	if pm.has_method("get_current_instrument"):
		instr_cfg = pm.get_current_instrument()
	var instr_id: String = str(instr_cfg.get("id", ""))
	var instr_star: int = int(instr_cfg.get("star", 1))

	# 2. 战斗卡 —— green 槽的战斗卡，每张走完整 7 层加成链路算实战力
	var platforms: Array = []
	var weapons: Array = []
	var energy_cards: Array = []
	var platform_powers: Array[float] = []  # v7.x: 每张卡加成后战力（7 层全加成）
	var card_breakdown: Array = []          # v7.x: [{name, power}] 供 UI 卡战力分解显示
	var bpm: Node = _get_autoload("BlueprintManager")
	if pm.has_method("get_loadouts"):
		var loadouts: Array = pm.get_loadouts()
		for ld in loadouts:
			if not (ld is Dictionary):
				continue
			var plat = ld.get("platform", null)
			if plat != null and plat is CardResource:
				platforms.append(plat.card_id)
				# v7.x 单分量公式：每张卡走完整 7 层加成链（强化/改造/进化/军衔/词条/相位仪/符文）
				var pwr: float = _PlatformPower.compute_player_card_power(plat, pm, bpm)
				platform_powers.append(pwr)
				# 卡战力分解（UI 用）
				var display_name: String = String(plat.display_name) if "display_name" in plat else plat.card_id
				var enhance: int = int(plat.enhance_level) if "enhance_level" in plat else 0
				card_breakdown.append({
					"name": display_name,
					"enhance": enhance,
					"power": pwr,
					"instance_id": plat.instance_id if "instance_id" in plat else "",
				})
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

	# 4. 相位仪主动能力（供 UI 展示，不计分）
	var active_ability: Dictionary = {}
	if pm.has_method("get_active_ability"):
		active_ability = pm.get_active_ability()

	# 5. v7.x 单分量公式：无战斗卡时注入兜底分（防 0 分 1★ 不直观）
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
		"active_spells": [],
		"passive_spells": baseline_passives,
		"equipment": {
			"platforms": platforms,
			"weapons": weapons,
			"energy_cards": energy_cards,
			"runes": rune_ids_clean,  # UI 展示用（单分量公式不再读此字段计分）
		},
		# 扩展字段（带下划线前缀）
		"_player_instrument_star": instr_star,
		"_player_rune_slots": rune_slots,
		"_player_active_runewords": active_runewords,
		"_player_platform_powers": platform_powers,  # 单分量公式：每张卡 7 层加成后战力之和
		"_player_card_breakdown": card_breakdown,    # UI 卡战力分解（{name,enhance,power}）
		"_player_active_ability": active_ability,    # 供 UI 展示
	}


# ═══════════════════════════════════════════════════════════════
#  评估主函数：真实战力评估 + 派生 Lv（不压缩）
# ═══════════════════════════════════════════════════════════════

## 计算玩家相位师星级（1-7★）+ 展示等级（Lv5-30）
## v7.x 单分量公式：直接调 MasterPowerEvaluator.evaluate()。
## build_player_master_dict 已注入 _player_platform_powers（每张卡 7 层加成后战力），
## evaluator 的 _eval_equipment_slots 会读此字段直接求和。
## 返回：{stars, star_name, total_score, raw_total_score, display_level, scores, card_breakdown}
static func evaluate_player_stars(pm: Node) -> Dictionary:
	var master: Dictionary = build_player_master_dict(pm)
	if master.is_empty():
		# 无法装配——返回基准 3★ Lv15（向后兼容）
		return {
			"stars": 3, "total_score": 0.0, "star_name": "高手",
			"raw_total_score": 0.0,
			"display_level": 15, "scores": {},
			"card_breakdown": [],
		}

	# ── 直接调 evaluate()（单分量：卡战力之和）──
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
		"total_score": total,  # 真实总分（单分量：卡战力之和）
		"raw_total_score": total,  # 兼容字段
		"display_level": display_lvl,  # 展示等级 Lv5-30
		"scores": scores,
		"card_breakdown": full_eval.get("details", {}).get("card_breakdown", []),  # UI 卡战力分解
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


## 安全获取 autoload 节点（与 MasterPlatformPower._get_autoload 同实现）
static func _get_autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root:
		return tree.root.get_node_or_null(autoload_name)
	return null
