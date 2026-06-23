extends RefCounted
class_name MasterPlayerAssembler
## 玩家相位师星级评估装配器（v6.7）
##
## 职责：从 PhaseInstrumentManager 实时装配玩家 master dict，
## 喂给 MasterPowerEvaluator.evaluate() 算出玩家相位师星级（1-7★）。
##
## 星级来源（与用户确认）：
##   A维(相位仪15%) — 玩家当前装备的相位仪（star/属性）
##   F维(装备槽25%) — 相位仪 green 槽里的战斗卡（platforms/weapons/energy_cards）
##   B维(刻印25%)   — 符文槽 + 激活的符文之语（每符文一个分值 + 每符文之语一个分值）
##   兜底分         — 玩家无 traits/spells，注入一条固定被动保证不低于 2★（与用户确认）
##
## C/D/E 维（特质/主动/被动技能）玩家没有，留空（evaluator 返回 0 分，不影响档位判定）。

const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const RunewordMatcher = preload("res://managers/runeword_matcher.gd")
const RuneDefs = preload("res://data/runes.gd")
const RunewordDefs = preload("res://data/runewords.gd")

## 玩家基础兜底分（注入一条虚拟被动，保证玩家不会低于 2★）
## 选择 ~320 分的依据：2★ 下限 250 分，玩家 A/F/B 维即使较弱也能靠此分跨过 2★ 门槛
const PLAYER_BASELINE_SCORE: float = 320.0

## 符文稀有度 → 分值（每符文一个分值）
const RUNE_RARITY_POWER: Dictionary = {
	"common": 40.0,
	"rare": 75.0,
	"epic": 120.0,
	"legendary": 180.0,
}

## 符文之语 tier → 分值（每符文之语一个分值）
const RUNEWORD_TIER_POWER: Dictionary = {
	"tier_2": 90.0,   # 2符文之语
	"tier_3": 150.0,  # 3符文之语
	"tier_4": 230.0,  # 4符文之语
	"tier_5": 320.0,  # 5符文之语（最强）
}


## 装配玩家 master dict（喂给 MasterPowerEvaluator）
## pm: PhaseInstrumentManager autoload 节点
static func build_player_master_dict(pm: Node) -> Dictionary:
	if pm == null or not is_instance_valid(pm):
		return {}

	# 1. 相位仪 —— 取当前装备相位仪的 id（evaluator 会用 EnemyPhaseEquipment 查属性；
	#    若查不到，A维返回0，但有兜底分托底，不会崩溃）
	var instr_cfg: Dictionary = {}
	if pm.has_method("get_current_instrument"):
		instr_cfg = pm.get_current_instrument()
	var instr_id: String = str(instr_cfg.get("id", ""))
	var instr_star: int = int(instr_cfg.get("star", 1))

	# 2. 战斗卡 —— green 槽的战斗卡映射到 equipment.platforms/weapons/energy_cards
	var platforms: Array = []
	var weapons: Array = []
	var energy_cards: Array = []
	if pm.has_method("get_loadouts"):
		var loadouts: Array = pm.get_loadouts()
		for ld in loadouts:
			if not (ld is Dictionary):
				continue
			var plat = ld.get("platform", null)
			if plat != null and plat is CardResource:
				platforms.append(plat.card_id)
			var ws = ld.get("weapons", [])
			if ws is Array:
				for w in ws:
					if w != null and w is CardResource and not w.card_id.is_empty():
						weapons.append(w.card_id)
	# yellow 槽的能量卡（get_loadouts 只返回 green 槽，能量卡需单独读）
	# 通过 get_slot_card_ids 拿全部槽位 id，但难以区分颜色——改用直接读 instrument_slots
	# 这里用兼容方式：若 pm 暴露了 instrument_slots 则直接读，否则跳过能量卡
	if "instrument_slots" in pm:
		var slots: Dictionary = pm.get("instrument_slots")
		var yellow_arr: Array = slots.get("yellow", [])
		for c_raw in yellow_arr:
			if c_raw != null and c_raw is CardResource:
				energy_cards.append(c_raw.card_id)

	# 3. 符文 + 符文之语 —— 转成 engraved_affixes（每符文一条 + 每符文之语一条）
	var rune_slots: Array = []
	if pm.has_method("get_rune_slots"):
		rune_slots = pm.get_rune_slots()
	var slot_count: int = 0
	if pm.has_method("get_rune_slot_count"):
		slot_count = pm.get_rune_slot_count()
	else:
		slot_count = rune_slots.size()

	var engraved_affixes: Array = []
	# 3a. 每个装备的符文 → 一条刻印
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
	# 3b. 每个激活的符文之语 → 一条刻印（分值更高，见 _eval_engravings_player）
	var active_runewords: Array = []
	if pm.has_method("get_active_runewords"):
		active_runewords = pm.get_active_runewords()
	else:
		# 兜底：直接用 RunewordMatcher 匹配
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

	# 4. 玩家兜底分 —— 注入一条虚拟被动，保证不低于 2★
	#    用一个 evaluator 认可的 effect key + 高 value，使其 PASSIVE_EFFECT_WEIGHTS 命中
	var baseline_passives: Array = [{
		"id": "player_baseline",
		"name": "玩家基底",
		"effect": "automation",  # PASSIVE_EFFECT_WEIGHTS 里存在，权重 100.0
		"params": {"value": PLAYER_BASELINE_SCORE / 5.0},  # ×5.0 系数后≈320
	}]

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
		},
		# 扩展字段：供 _eval_instrument 兜底（当 EnemyPhaseEquipment 查不到玩家仪器时用）
		"_player_instrument_star": instr_star,
		"_player_rune_slots": rune_slots,
		"_player_active_runewords": active_runewords,
	}


## 计算玩家相位师星级（1-7★）
## 调用 MasterPowerEvaluator.evaluate()，但重写 B维（刻印）分值计算，
## 用"每符文一个分值 + 每符文之语一个分值"规则（与用户确认）。
static func evaluate_player_stars(pm: Node) -> Dictionary:
	var master: Dictionary = build_player_master_dict(pm)
	if master.is_empty():
		# 无法装配——返回基准 3★（等于现状，向后兼容）
		return {"stars": 3, "total_score": 0.0, "star_name": "高手"}

	var scores: Dictionary = {}
	scores.instrument = _eval_instrument_player(master)
	scores.engravings = _eval_engravings_player(master)
	scores.traits = MasterPowerEvaluator._eval_traits(master)
	scores.active_spells = MasterPowerEvaluator._eval_active_spells(master)
	scores.passive_spells = MasterPowerEvaluator._eval_passive_spells(master)
	scores.equipment_slots = MasterPowerEvaluator._eval_equipment_slots(master)

	var total: float = (
		scores.instrument * MasterPowerEvaluator.W_INSTRUMENT
		+ scores.engravings * MasterPowerEvaluator.W_ENGRAVINGS
		+ scores.traits * MasterPowerEvaluator.W_TRAITS
		+ scores.active_spells * MasterPowerEvaluator.W_ACTIVE_SPELLS
		+ scores.passive_spells * MasterPowerEvaluator.W_PASSIVE_SPELLS
		+ scores.equipment_slots * MasterPowerEvaluator.W_EQUIPMENT_SLOTS
	)

	var star_info: Dictionary = MasterPowerEvaluator._score_to_stars(total)
	return {
		"stars": int(star_info.get("stars", 1)),
		"total_score": total,
		"star_name": str(star_info.get("name", "")),
		"scores": scores,
	}


# ═════════════════════════════════════════════
#  玩家专用维度评估（A维/B维重写，其余复用 evaluator）
# ═════════════════════════════════════════════

## A维：玩家相位仪评估
## evaluator 原版用 EnemyPhaseEquipment.get_phase_instrument(id) 查数据，
## 玩家的仪器 id 在 EnemyPhaseEquipment 里查不到。此处用相位仪 star 做简化估算：
## star 越高分数越高，与 NPC 相位师的仪器分值量级对齐。
static func _eval_instrument_player(master: Dictionary) -> float:
	var star: int = int(master.get("_player_instrument_star", 1))
	star = clampi(star, 1, 7)
	# 7星相位仪在 evaluator 里稀有度 epic≈450 + 属性分≈500，约 950；
	# 1星 common≈50 + 属性分≈150，约 200。线性插值近似。
	return 200.0 + float(star - 1) * 125.0  # 1星=200, 7星=950


## B维：玩家刻印（符文+符文之语）评估
## 用户确认规则：每个符文一个分值 + 每个符文之语一个分值，累加。
## 原版 evaluator 调 EnergyFieldEngravings.calc_engraving_power 查刻印表，
## 玩家的 engraved_affixes 是符文/符文之语映射的虚拟 id，查表返回 0。
## 此处用 rune_id/runeword_id 直接查 RuneDefs/RunewordDefs 的稀有度/tier。
static func _eval_engravings_player(master: Dictionary) -> float:
	var rune_slots: Array = master.get("_player_rune_slots", [])
	var active_runewords: Array = master.get("_player_active_runewords", [])

	var total: float = 0.0
	# 每个装备的符文一个分值（按稀有度）
	var active_rune_count: int = 0
	for slot_v in rune_slots:
		if slot_v == null:
			continue
		var rune_id: String = str(slot_v)
		if rune_id.is_empty():
			continue
		active_rune_count += 1
		var rune_def: Dictionary = RuneDefs.get_rune(rune_id)
		if rune_def.is_empty():
			total += 30.0  # 查不到也给个保底分
			continue
		var rarity: String = str(rune_def.get("rarity", "common"))
		total += float(RUNE_RARITY_POWER.get(rarity, 40.0))
	# 符文数量加成（每符文 +25，与 evaluator 原版递减逻辑对齐）
	total += active_rune_count * 25.0

	# 每个激活的符文之语一个分值（按 tier）
	for rw in active_runewords:
		# v6.7 修复：tier 是 int（TIER_2..TIER_5），原代码用 String(Variant) 转换
		# 在 Godot 4.5 当 Variant 持有 int 时运行时崩溃（String 构造函数不支持 int）。
		# 改用 str() 安全转换，并兼容 tier 为 "tier_N" 字符串的旧格式。
		var tier_raw: Variant = rw.get("tier", 2)
		var tier_key: String = "tier_" + str(tier_raw) if typeof(tier_raw) == TYPE_INT else str(tier_raw)
		total += float(RUNEWORD_TIER_POWER.get(tier_key, 90.0))

	return total
