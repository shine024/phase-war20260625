class_name EvolutionHelpers
## 战力估算与属性增长 — 从 BlueprintManager 拆分的子模块
## 所有函数为 static，通过 bpm_ref（BlueprintManager 实例）访问核心数据

const GC = preload("res://resources/game_constants.gd")
const DefaultCards = preload("res://data/default_cards.gd")
const RankRules = preload("res://data/rank_rules.gd")
const UnitStatsTable = preload("res://resources/unit_stats_table.gd")

const _LAW_BLUEPRINT_PREFIX: String = "law:"

static func _is_law_blueprint_id(card_id: String) -> bool:
	return not card_id.is_empty() and card_id.begins_with(_LAW_BLUEPRINT_PREFIX)

## ─────────── 稀有度 ───────────

static func get_card_base_rarity(card_id: String) -> String:
	if _is_law_blueprint_id(card_id):
		return "rare"
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card:
		return card.rarity
	return "common"

static func get_card_rarity(card_id: String) -> String:
	return get_card_base_rarity(card_id)

static func get_rarity_multiplier(card_id: String) -> float:
	# v6.8: 稀有度乘区压缩（6档），避免稀有度过度主导战力
	var r: String = get_card_rarity(card_id)
	match r:
		"uncommon":  return 1.04
		"rare":      return 1.08
		"epic":      return 1.12
		"legendary": return 1.16
		"mythic":    return 1.20
		_:           return 1.0

static func get_effective_power_multiplier(card_id: String, bpm_ref: Node) -> float:
	if _is_law_blueprint_id(card_id):
		var enhance: int = _get_card_enhance_level(card_id)
		return 1.0 + float(maxi(0, enhance - 1)) * 0.07
	var rarity_mul: float = get_rarity_multiplier(card_id)
	var enhance: int = _get_card_enhance_level(card_id)
	var enhance_mul: float = BattleCardV3.enhance_stat_multiplier(enhance, get_card_rarity(card_id))
	return rarity_mul * enhance_mul

## ─────────── 内部辅助 ───────────

## 单武器：`stats.weapons[0]` 与 `attack_damage` 保持一致
static func _sync_single_weapon_damage_from_attack(stats: UnitStats) -> void:
	if stats == null or stats.weapons.size() != 1:
		return
	var w: Dictionary = stats.weapons[0] as Dictionary
	if w == null:
		return
	w["damage"] = stats.attack_damage
	stats.weapons[0] = w

static func _multiply_attack_damage_and_weapon_slots(stats: UnitStats, factor: float) -> void:
	if stats == null or factor == 1.0:
		return
	stats.attack_damage *= factor
	for i in range(stats.weapons.size()):
		var w: Dictionary = stats.weapons[i] as Dictionary
		if w == null: continue
		if w.has("damage"):
			w["damage"] = float(w["damage"]) * factor
			stats.weapons[i] = w
	# v7.x 修复: 同步 weapon_slots[].damage（战斗 AI 读的是这里，非 weapons[]/attack_damage）
	# 此前函数名虽带 "weapon_slots" 但只改 weapons[]（Dictionary），漏了 weapon_slots（WeaponResource），
	# 导致强化/稀有度/inherit/军衔 4 个乘区对实际开火伤害失效。
	if stats.has_method("_sync_weapon_slots_damage"):
		stats._sync_weapon_slots_damage(factor)

static func _preview_battle_era() -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 0
	var gm: Node = tree.root.get_node_or_null("GameManager")
	if gm != null and "current_level" in gm:
		return GC.get_era_for_level(int(gm.current_level))
	return 0

## ─────────── 强化成长倾斜 / 进化 HP 下限 ───────────

static func _apply_platform_enhance_growth_bias(stats: UnitStats, platform_card_id: String, bpm_ref: Node) -> void:
	if stats == null or platform_card_id.is_empty():
		return
	var enhance: int = _get_card_enhance_level(platform_card_id)
	var tiers: float = float(enhance)
	if tiers <= 0.0:
		return
	var bias: Dictionary = UnitStatsTable.get_combat_kind_growth_bias(stats.combat_kind)
	var hp_bias: float = float(bias.get("hp_bias", 0.04))
	var dmg_bias: float = float(bias.get("dmg_bias", 0.04))
	stats.max_hp *= 1.0 + tiers * hp_bias
	_multiply_attack_damage_and_weapon_slots(stats, 1.0 + tiers * dmg_bias)
	if bias.has("range_bias"):
		var range_mul: float = 1.0 + tiers * float(bias["range_bias"])
		stats.attack_range *= range_mul
		for i in range(stats.weapons.size()):
			var w: Dictionary = stats.weapons[i] as Dictionary
			if w == null:
				continue
			if w.has("range"):
				w["range"] = float(w["range"]) * range_mul
				stats.weapons[i] = w
	if bias.has("def_bias"):
		stats.defense += tiers * float(bias["def_bias"]) * 2.0

## v7.3 修复 B3: 签名改为接收 CardResource，优先从 InstanceRegistry（按 instance_id）读 hp_floor。
## 原 signature 接收 card_id 字符串，按 card_id 查 BlueprintManager 字典，实例化进化数据读不到。
static func _apply_evolution_hp_floor(stats: UnitStats, platform_card: CardResource, era: int, bpm_ref: Node) -> void:
	if stats == null or platform_card == null or platform_card.card_id.is_empty():
		return
	var floor_base: float = 0.0
	var inst_id_str: String = String(platform_card.instance_id) if ("instance_id" in platform_card) else ""
	var ir_ref: Node = _get_instance_registry()
	# 优先从实例读（实例化进化数据存这里）
	if ir_ref != null and not inst_id_str.is_empty() and ir_ref.has_method("get_evolution_hp_floor"):
		floor_base = ir_ref.get_evolution_hp_floor(inst_id_str)
	# 回退 BlueprintManager 字典（兼容未实例化卡/旧数据）
	if floor_base <= 0.0:
		floor_base = float(bpm_ref.blueprint_evolution_hp_floor.get(platform_card.card_id, 0.0))
	if floor_base <= 0.0:
		return
	# v6.8: 时代缩放已移除，进化 HP 下限直接用 floor_base（不再乘时代倍率）
	stats.max_hp = maxf(stats.max_hp, floor_base)

## ─────────── 军衔 ───────────

static func get_rank_info(card_id: String, bpm_ref: Node) -> Dictionary:
	if card_id.is_empty():
		return {}
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return {}
	var base_rank: String = RankRules.get_base_rank_by_combat_kind(card.combat_kind)
	var power_score: float = estimate_power_score(card_id, bpm_ref)
	var rank_id: String = RankRules.get_rank_by_power(base_rank, power_score)
	var out: Dictionary = {
		"rank_id": rank_id,
		"rank_name": RankRules.get_rank_display_name(rank_id),
		"power_score": power_score,
	}
	bpm_ref.blueprint_rank_cache[card_id] = out.duplicate(true)
	return out

## ─────────── 战力估算 ───────────

## 平台/武器/合成卡用 UnitStats 推导；能量/法则用养成向公式
## v7.0: card_id 支持 instance_id（实例化养成，实战力估算读到实例养成数据）
static func estimate_power_score(card_id_or_instance: String, bpm_ref: Node) -> float:
	# v7.0: 解析 card_id（instance_id → card_id）
	var card_id: String = card_id_or_instance
	var ir: Node = _get_instance_registry()
	if ir != null and ir.has_method("get_card_id_of"):
		var resolved: String = ir.get_card_id_of(card_id_or_instance)
		if not resolved.is_empty():
			card_id = resolved
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null:
		return estimate_power_score_meta_only(card_id_or_instance, bpm_ref)
	if card.card_type == GC.CardType.ENERGY or card.card_type == GC.CardType.LAW:
		return estimate_power_score_meta_only(card_id_or_instance, bpm_ref)
	# v7.3 修复 B2: 优先用实例对象（含养成）build stats，而非模板（enhance_level=0/mods=[]）。
	# 原代码传模板给 build_unit_stats_for_power_preview，实例化卡的强化/改造/进化加成全部丢失，
	# 导致战力评分恒偏低、军衔永不晋升、改造门槛误判。
	var card_for_preview: CardResource = card
	var ir_ref2: Node = _get_instance_registry()
	if ir_ref2 != null and ir_ref2.has_method("get_instance"):
		var inst_card: CardResource = ir_ref2.get_instance(card_id_or_instance)
		if inst_card != null:
			card_for_preview = inst_card
	var stats: UnitStats = build_unit_stats_for_power_preview(card_for_preview, bpm_ref)
	if stats == null:
		return estimate_power_score_meta_only(card_id_or_instance, bpm_ref)
	return combat_power_from_unit_stats(stats)

## v7.0: 支持 instance_id——从实例对象读 enhance/mods，从 blueprint 读 inherit_bonus
static func estimate_power_score_meta_only(card_id_or_instance: String, bpm_ref: Node) -> float:
	var enhance: int = 0
	var mod_count: int = 0
	var inherit_bonus: float = 0.0
	var rarity_mul: float = 1.0
	var card_id: String = card_id_or_instance

	var ir: Node = _get_instance_registry()
	if ir != null and ir.has_method("get_instance"):
		var inst: CardResource = ir.get_instance(card_id_or_instance)
		if inst != null:
			# 实例存在：从实例读养成
			enhance = maxi(inst.enhance_level, 0)
			mod_count = inst.mods.size()
			inherit_bonus = ir.get_inherit_bonus(card_id_or_instance)
			card_id = inst.card_id
		else:
			# 非实例：按 card_id 查 blueprint_* 字典
			enhance = _get_card_enhance_level(card_id_or_instance)
			mod_count = ModManager.get_modification_count(card_id_or_instance, bpm_ref.blueprint_mods)
			inherit_bonus = float(bpm_ref.blueprint_inherit_bonus.get(card_id_or_instance, 0.0))
			if ir != null and ir.has_method("get_card_id_of"):
				var resolved: String = ir.get_card_id_of(card_id_or_instance)
				if not resolved.is_empty():
					card_id = resolved
	else:
		# 没有 InstanceRegistry：旧路径
		enhance = _get_card_enhance_level(card_id_or_instance)
		mod_count = ModManager.get_modification_count(card_id_or_instance, bpm_ref.blueprint_mods)
		inherit_bonus = float(bpm_ref.blueprint_inherit_bonus.get(card_id_or_instance, 0.0))

	rarity_mul = get_rarity_multiplier(card_id)
	return (80.0 + float(enhance) * 28.0 + float(mod_count) * 22.0) * rarity_mul * (1.0 + inherit_bonus)

## v7.0: 安全获取 InstanceRegistry 节点
static func _get_instance_registry() -> Node:
	var tree = Engine.get_main_loop()
	if tree and tree.root:
		return tree.root.get_node_or_null("InstanceRegistry")
	return null

## v9.x 重设：目标卡白板战斗战力（模板口径，不吃任何养成——进化战力门槛与面板显示用）。
## 旧口径 UnitLineageConfig.get_target_base_power 读卡表 power 字段，与判定左侧
## estimate_power_score（战斗公式）不同标尺，战力条件形同虚设。
static var _target_white_combat_cache: Dictionary = {}

static func get_target_white_combat(card_id: String) -> int:
	# 与判定左侧 build_unit_stats_for_power_preview 同用 _preview_battle_era()——防御派生带
	# era 乘区（1+era×0.15），两侧时代基准必须一致，否则对比漂移（实测 pz3：era0=715 vs era1=771）
	var era: int = _preview_battle_era()
	var cache_key: String = "%s|%d" % [card_id, era]
	if _target_white_combat_cache.has(cache_key):
		return int(_target_white_combat_cache[cache_key])
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	var pw: int = 0
	if card != null and card.card_type == GC.CardType.COMBAT_UNIT:
		var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
		if stats != null:
			pw = int(combat_power_from_unit_stats(stats))
	_target_white_combat_cache[cache_key] = pw
	return pw

## v9.x 重设：进化战力门槛 = 目标白板战斗战力 × 0.70（判定两侧同标尺）。
## 实测定标（tests/power_calibration_probe.gd）：战斗公式下投入养成仅抬 ~10% 战力，
## 装甲线白板即过线（投入门槛由强化/改造数条件承担）；步兵首进化恰在 E1 数值门槛
## （强化5+2改 ≈ 白板×1.05）附近过线；各时代满投入对下一时代目标均留 3%+ 余量，无锁死。
static func get_target_power_bar(card_id: String) -> int:
	return int(float(get_target_white_combat(card_id)) * 0.70)

static func build_unit_stats_for_power_preview(card: CardResource, bpm_ref: Node) -> UnitStats:
	if card == null:
		return null
	var era: int = _preview_battle_era()
	if card.card_type == GC.CardType.COMBAT_UNIT:
		var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
		if stats == null:
			return null
		apply_growth_to_stats(stats, card, [], bpm_ref, false)
		_apply_mod_weapon_dps_gain(stats, card, era, bpm_ref)
		# v6.0: 词条效果已由 UnitStatsTable.build_stats_from_card 内部处理
		# 不再需要额外调用 AffixManager
		return stats
	return null

## v9.x 武器槽改造增益差分：grant_slot（激活新武器槽）/ slot_damage_mult 等
## 只改 WeaponResource，不回写 stats.attack_* → 战力公式读不到。
## 此处双 build（原卡 vs 去 mods 白板 clone，同口径走 growth）取 weapon_slots 的
## DPS 差值，写入 stats meta "mod_weapon_dps_gain"（combat_power_from_unit_stats
## 按 DPS 同权 0.75 折算）。白板差恒 0，白板战力零漂移。
## deploy_speed 同理：有真实战斗消费（部署延迟公式）不能重定向，差分记
## "mod_deploy_speed_gain"（白板差=0）。
static func _apply_mod_weapon_dps_gain(stats: UnitStats, card: CardResource, era: int, bpm_ref: Node) -> void:
	if stats == null or card.mods == null or card.mods.is_empty():
		return
	var w_dps_modded := _weapon_dps_of(stats.weapon_slots)
	var bare: CardResource = card.duplicate(true)
	if bare == null:
		return
	bare.mods = []
	var bare_stats: UnitStats = UnitStatsTable.build_stats_from_card(bare, era)
	if bare_stats == null:
		return
	apply_growth_to_stats(bare_stats, bare, [], bpm_ref, false)
	var gain: float = w_dps_modded - _weapon_dps_of(bare_stats.weapon_slots)
	if gain > 0.5:
		stats.set_meta("mod_weapon_dps_gain", gain)
	var d_gain: float = float(stats.deploy_speed) - float(bare_stats.deploy_speed)
	if d_gain > 0.0:
		stats.set_meta("mod_deploy_speed_gain", d_gain)
	# 射程增量（远程卡基数 9900px 线性计权失真，只计 mod 增量；白板差=0）
	var r_gain: float = float(stats.attack_range) - float(bare_stats.attack_range)
	if r_gain > 1.0:
		stats.set_meta("mod_range_gain", r_gain)

static func _weapon_dps_of(slots: Array) -> float:
	var v: float = 0.0
	for w in slots:
		if w is WeaponResource and w.enabled and float(w.damage) > 0.0:
			v += float(w.damage) * float(w.attack_speed)
	return v

## v7.x 战力公式全修（用户主导设计最终版）：
##   战力 = HP × 0.35
##        + (atk_l×spd_l + atk_a×spd_a + atk_air×spd_air) × 0.75 × (1 + 暴击 × 0.5)
##        + avg_speed × 25
##        + (def_l + def_a + def_air) × 2.1
##        + armor_pen × 5
##        + move_speed × 0.25
##
## v9.x 机制属性折算扩展（标准档，用户拍板：机制属性满载可达总分 25~35%）：
##   改造能写入约 60 个机制字段（闪避/减伤/吸血/溅射/燃烧/拦截/...），旧公式权重全 0
##   → 功能性改造装了战力不涨。扩展三段折算（详见 _mechanic_survival_mul /
##   _mechanic_output_mul / _mechanic_flat_score），白板卡这些字段≈0 → 白板战力零漂移，
##   进化门槛（白板×0.70）稳定。验收：tests/mod_power_gain_coverage.gd 全改造必涨。
static func combat_power_from_unit_stats(stats: UnitStats) -> float:
	if stats == null:
		return 0.0
	var hp: float = maxf(float(stats.max_hp), 0.0)
	# DPS 三维各自配对（每维用自己的攻速）
	var spd_l: float = maxf(float(stats.attack_light_speed), 0.0)
	var spd_a: float = maxf(float(stats.attack_armor_speed), 0.0)
	var spd_air: float = maxf(float(stats.attack_air_speed), 0.0)
	var dps_raw: float = (
		maxf(float(stats.attack_light), 0.0) * spd_l
		+ maxf(float(stats.attack_armor), 0.0) * spd_a
		+ maxf(float(stats.attack_air), 0.0) * spd_air
	)
	# 暴击率进 DPS 乘区（暴击 50% → DPS ×1.25）；v9.x 暴伤扩展（暴伤只在暴击时生效）
	var crit_mul: float = (1.0 + maxf(float(stats.crit_chance), 0.0) * 0.5) \
		* (1.0 + maxf(float(stats.crit_chance), 0.0) * maxf(float(stats.crit_damage_bonus), 0.0) * 0.5)
	# v9.x 功能输出乘区（溅射/连锁/DoT 系对 DPS 的期望增益）
	var out_mul: float = _mechanic_output_mul(stats, hp)
	var dps_score: float = dps_raw * 0.75 * crit_mul * out_mul
	# 攻速独立项（三维平均攻速，反映出手快慢本身的价值）
	var avg_speed: float = (spd_l + spd_a + spd_air) / 3.0
	# 三维防御求和（奖励全面型单位，后期卡三维均衡发展自然分高）
	var def_sum: float = (
		maxf(float(stats.defense_light), 0.0)
		+ maxf(float(stats.defense_armor), 0.0)
		+ maxf(float(stats.defense_air), 0.0)
	)
	var spd: float = maxf(float(stats.move_speed), 0.0)
	# v9.x 穿甲乘区化（_mechanic_output_mul 内按比率折算 DPS 增益），不再线性计分
	# v9.x 武器槽改造增益（grant_slot/slot_damage 类不回写 stats.attack_*，由
	# build_unit_stats_for_power_preview 双 build 差分写入 meta；白板差=0）
	var w_gain: float = 0.0
	if stats.has_meta("mod_weapon_dps_gain"):
		w_gain = maxf(float(stats.get_meta("mod_weapon_dps_gain")), 0.0)
	var out: float = (
		hp * 0.35 * _mechanic_survival_mul(stats)
		+ dps_score
		+ w_gain * 0.75
		+ avg_speed * 25.0
		+ def_sum * 2.1
		+ spd * 0.25
		+ _mechanic_flat_score(stats, hp, dps_raw, dps_score)
	)
	return maxf(out, 1.0)


## v9.x 机制折算·等效生存乘区：防护比率类属性折算进等效 HP（闪避 x% ≈ 有效血量 +x%）。
## 白板全 0 → 乘 1.0，零漂移。乘区各项取保守上限（与 registry 的 cap 一致或更紧）。
## 注：hp_regen/shield_on_kill 数据层是比率语义（0.005=0.5%HP/秒），按战斗窗口折算等效血量。
static func _mechanic_survival_mul(stats: UnitStats) -> float:
	var m: float = 1.0
	m += minf(maxf(float(stats.dodge_chance), 0.0), 0.5)            # 闪避=免伤概率
	m += minf(maxf(float(stats.damage_reduction), 0.0), 0.75)        # 直接减伤
	m += minf(maxf(float(stats.crit_resist), 0.0), 1.0) * 0.5        # 暴抗（受暴伤减免，折半）
	m += minf(maxf(float(stats.lifesteal), 0.0), 0.6) * 0.5          # 吸血续航≈有效血量，折半
	if bool(stats.revive_on_death) and stats.revive_hp_ratio > 0.0:
		m += minf(stats.revive_hp_ratio, 1.0) * 0.6                  # 复活=按比例二条命
	# 拦截（完全免伤但受次数限制）：按 3 次封顶折算覆盖率
	if stats.intercept_chance > 0.0 and stats.intercept_charges > 0:
		m += minf(float(stats.intercept_chance), 1.0) \
			* (minf(float(stats.intercept_charges), 3.0) / 3.0) * 0.5
	# 回血/击杀护盾：比率语义，按 12 秒战斗窗口 / 2 击杀期望折算等效血量
	m += minf(maxf(float(stats.hp_regen), 0.0) * 12.0, 0.3)
	m += minf(maxf(float(stats.shield_on_kill), 0.0) * 2.0, 0.3)
	# 相位护盾池按等效血量折算（比率封顶防极端）
	m += minf(maxf(float(stats.phase_shield_pool), 0.0), 2000.0) * 0.001
	# 巷战防御（条件型防御加成，白板步兵自带 0.15——统一计权，门槛同比上涨）
	m += minf(maxf(float(stats.urban_defense_bonus), 0.0), 1.0) * 0.2
	return m


## v9.x 机制折算·等效输出乘区：功能输出类属性对 DPS 的期望增益。
## 溅射/连锁对多目标场景的期望增伤、DoT 系（燃烧/化学/EMP/纳米）的期望每秒附加输出。
## 穿甲比率乘区化：0.2 穿甲 ≈ +8% DPS（旧线性 ×5 对比率值只给 1 分，形同虚设）。
static func _mechanic_output_mul(stats: UnitStats, hp: float) -> float:
	var m: float = 1.0
	m += minf(maxf(float(stats.splash_damage), 0.0), 0.8) * 0.35     # 溅射（AOE 增伤，对群才生效→折 0.35）
	m += minf(maxf(float(stats.chain_chance), 0.0), 0.6) * 0.3       # 连锁弹
	m += minf(maxf(float(stats.armor_penetration), 0.0), 1.0) * 0.4  # 穿甲（无视护甲=期望增伤）
	m += (minf(maxf(float(stats.armor_pen_vs_light), 0.0), 1.0)
		+ minf(maxf(float(stats.armor_pen_vs_armor), 0.0), 1.0)
		+ minf(maxf(float(stats.armor_pen_vs_air), 0.0), 1.0)) * 0.1  # 定向穿甲（半权×半权）
	# DoT 系：chance × dps × 有效时长（上限 5 秒，×0.5 折算为期望增伤比）
	var dot_sum: float = 0.0
	dot_sum += minf(maxf(float(stats.burn_chance), 0.0), 1.0) \
		* maxf(float(stats.burn_dps), 0.0) * minf(maxf(float(stats.burn_duration), 0.0), 5.0)
	dot_sum += minf(maxf(float(stats.chem_chance), 0.0), 1.0) \
		* maxf(float(stats.chem_dps), 0.0) * minf(maxf(float(stats.chem_duration), 0.0), 5.0)
	dot_sum += minf(maxf(float(stats.emp_chance), 0.0), 1.0) \
		* maxf(float(stats.emp_true_damage), 0.0) * 3.0
	if dot_sum > 0.0:
		# dot_sum 是"每次命中的期望附加总伤"，粗略按 4 次命中窗口折算成增伤比
		m += minf(dot_sum * 4.0 * 0.1, 0.5)
	return m


## v9.x 机制折算·线性机制分：数值型字段/条件型机制的直接加分。
## 白板全 0 → 加 0。权重集中此处便于调参（标准档：单项典型值 5~50 分）。
static func _mechanic_flat_score(stats: UnitStats, hp: float, dps_raw: float, dps_score: float) -> float:
	var s: float = 0.0
	# ── 输出数值型/条件型 ──
	s += maxf(float(stats.true_damage), 0.0) * 1.2                    # 真伤（无视护甲附加，10 真伤=12 分）
	s += maxf(float(stats.crit_damage_bonus), 0.0) * dps_score * 0.15  # 暴伤保底分（乘区已按暴击率计期望，此为零暴击卡保底）
	# 射程：差分法（_apply_mod_weapon_dps_gain 记 meta），白板基数不计权（v7.x 设计⑤：
	# 索敌半径已覆盖战场，射程基数无价值），只计改造增量——白板零漂移，纯射程改造必涨
	if stats.has_meta("mod_range_gain"):
		s += minf(maxf(float(stats.get_meta("mod_range_gain")), 0.0), 300.0) * 0.5
	s += maxf(float(stats.splash_radius_bonus), 0.0) * dps_score * 0.15  # 溅射半径（AOE 覆盖期望）
	s += maxf(float(stats.attack_fort_bonus), 0.0) * dps_score * 0.15  # 对堡垒条件加成
	s += maxf(float(stats.attack_light_bonus), 0.0) * dps_score * 0.15
	s += maxf(float(stats.attack_air_bonus), 0.0) * dps_score * 0.15
	s += maxf(float(stats.siege_bonus_pct), 0.0) * dps_score * 0.1     # 攻城加成
	s += maxf(float(stats.single_target_penalty), 0.0) * dps_score * 0.2  # 平衡负项（子母弹主目标减伤）
	# 组合技乘区（v9.1/10：burn/chem/emp/beam 增益）
	s += maxf(float(stats.burn_dps_mult), 0.0) * dps_score * 0.3
	s += maxf(float(stats.chem_dps_mult), 0.0) * dps_score * 0.3
	s += maxf(float(stats.emp_true_damage_bonus), 0.0) * 1.2
	s += maxf(float(stats.beam_damage_bonus), 0.0) * dps_score * 0.3
	# 成长型：连击/怒气（需前置系统激活，爆发乘数按 0.1 折算期望）
	if int(stats.combo_max) > 0:
		s += maxf(float(stats.combo_bonus_mult), 0.0) * dps_score * 0.1
	if int(stats.rage_max) > 0:
		s += maxf(float(stats.rage_bonus_mult), 0.0) * dps_score * 0.1
	# 标记系：标记易伤（chance×vuln×DPS 期望）
	if float(stats.mark_chance) > 0.0:
		s += minf(float(stats.mark_chance), 1.0) * maxf(float(stats.mark_vuln_bonus), 0.0) * dps_score * 0.5
	if float(stats.crit_mark_chance) > 0.0:
		s += minf(float(stats.crit_mark_chance), 1.0) * maxf(float(stats.crit_mark_bonus), 0.0) * dps_score * 0.3
	if bool(stats.laser_mark_on_hit):
		s += dps_score * 0.05
	# 纳米（百分比削血）：按 HP 期望折算
	s += minf(maxf(float(stats.nano_chance), 0.0), 1.0) \
		* minf(maxf(float(stats.nano_pct), 0.0), 0.5) * hp * 2.2
	# 破甲叠层（每击削护甲，期望按满层折算）
	if float(stats.armor_break_per_hit) > 0.0:
		s += float(stats.armor_break_per_hit) * float(maxi(int(stats.armor_break_max_stacks), 1)) \
			* dps_score * 0.12
	# 相位转移（v10 转换型：受击相位闪避计数）
	if bool(stats.phase_shift_counter) or float(stats.phase_shift_counter) > 0.0:
		s += 12.0
	# ── 反制/领域型 ──
	s += maxf(float(stats.reflect_damage_pct), 0.0) * dps_raw * 0.5   # 反伤（受击才有，×0.5 折算）
	s += float(maxi(int(stats.counter_battery_shots), 0)) * 15.0      # 反炮兵射击次数
	if bool(stats.has_counter_battery):
		s += 20.0                                                      # 反炮兵标记（bool 型改造保底分）
	s += maxf(float(stats.death_heal_allies_pct), 0.0) * hp * 0.15    # 亡语治疗
	s += maxf(float(stats.minefield_damage), 0.0) * 0.4               # 布雷伤害
	s += maxf(float(stats.slow_aura_pct), 0.0) * maxf(float(stats.slow_aura_radius), 0.0) * 20.0  # 减速领域
	s += maxf(float(stats.command_aura_bonus), 0.0) * 25.0            # 指挥光环
	s += maxf(float(stats.fort_shelter_aura), 0.0) * 10.0             # 堡垒掩体光环
	s += maxf(float(stats.salvage_repair_pct), 0.0) * hp * 0.2        # 残骸回收维修
	# 电子劫持（v10 转换型）：按领域半径×占空比折算
	if float(stats.hijack_aura_radius) > 0.0 and float(stats.hijack_aura_cd) > 0.0:
		var hj_duty: float = float(stats.hijack_aura_duration) / float(stats.hijack_aura_cd)
		s += float(stats.hijack_aura_radius) * 0.01 * clampf(hj_duty, 0.0, 1.0) * 15.0
	# ── 部署价值（部署快=更早参战输出）──
	s += maxf(-float(stats.deploy_delay_bonus), 0.0) * 80.0           # move_speed 类改造落点（重定向减部署延迟）
	# deploy_speed 差分增益（build_unit_stats_for_power_preview 写入 meta，白板差=0）
	if stats.has_meta("mod_deploy_speed_gain"):
		s += maxf(float(stats.get_meta("mod_deploy_speed_gain")), 0.0) * 8.0
	return s


## 预览：给卡牌额外装一个改造后的战力（不真正写入养成数据）。
## 改造面板效果抽屉"装上后"用。实现=深拷贝实例卡 + 把候选 mod 追加进 clone.mods，
## 再走与真实安装完全相同的 build_stats_from_card → combat_power_from_unit_stats 路径，
## 保证预览值与实际安装后（右栏/intel 面板）显示的战力一致。
## 原 modification_panel 用 before × power_mult 严重虚高（power_mult 是稀有度/成本权重，
## 非战力增益倍率，1.35 会对 3000 战力卡显示 +1050）。
static func estimate_power_with_extra_mod(card: CardResource, mod_id: String, bpm_ref: Node) -> float:
	if card == null or mod_id.is_empty() or bpm_ref == null:
		return 0.0
	var clone: CardResource = card.duplicate(true)
	if clone == null:
		return 0.0
	# 追加候选改造（与真实 install_modification 写入的 entry 结构一致：{id, enabled}）
	if clone.mods == null:
		clone.mods = []
	clone.mods.append({"id": mod_id, "enabled": true})
	var stats: UnitStats = build_unit_stats_for_power_preview(clone, bpm_ref)
	if stats == null:
		return 0.0
	return combat_power_from_unit_stats(stats)


## ─────────── 属性增长 ───────────

static func apply_growth_to_stats(stats: UnitStats, platform_card: CardResource, weapon_cards: Array, bpm_ref: Node, apply_rank_bonus: bool = true) -> void:
	if stats == null:
		return
	var cards_to_check: Array = []
	if platform_card != null:
		cards_to_check.append(platform_card)
	for wc_raw in weapon_cards:
		if wc_raw is CardResource:
			cards_to_check.append(wc_raw)
	if cards_to_check.is_empty():
		return
	var hp_mul: float = 1.0
	var dmg_mul: float = 1.0
	var n: int = cards_to_check.size()
	for c_raw in cards_to_check:
		var c: CardResource = c_raw
		if c.card_id.is_empty():
			continue
		var m: float = get_effective_power_multiplier(c.card_id, bpm_ref)
		hp_mul += (m - 1.0) / float(n)
		dmg_mul += (m - 1.0) / float(n)
	stats.max_hp *= hp_mul
	_multiply_attack_damage_and_weapon_slots(stats, dmg_mul)
	if platform_card != null and not platform_card.card_id.is_empty():
		# v7.3 修复 B3/B4: 实例化养成读取——优先从 InstanceRegistry（按 instance_id）读 inherit_bonus/hp_floor，
		# 而非从 BlueprintManager 字典（按 card_id）。实例化进化后养成数据存在 InstanceRegistry，
		# 原代码按 card_id 查 BlueprintManager 字典读不到 → inherit_bonus/hp_floor 对进化过的实例化卡失效。
		var inst_id_str: String = String(platform_card.instance_id) if ("instance_id" in platform_card) else ""
		var ir_ref: Node = _get_instance_registry()
		var inherit_bonus: float = 0.0
		if ir_ref != null and not inst_id_str.is_empty() and ir_ref.has_method("get_inherit_bonus"):
			inherit_bonus = ir_ref.get_inherit_bonus(inst_id_str)
		if inherit_bonus <= 0.0:
			# 回退 BlueprintManager 字典（兼容未实例化卡/旧数据）
			inherit_bonus = float(bpm_ref.blueprint_inherit_bonus.get(platform_card.card_id, 0.0))
		if inherit_bonus > 0.0:
			var inh_mul: float = 1.0 + inherit_bonus
			stats.max_hp *= inh_mul
			_multiply_attack_damage_and_weapon_slots(stats, inh_mul)
		if apply_rank_bonus:
			# v7.3 修复 B2/B4: get_rank_info 用 instance_id（有实例时），让战力估算读到实例养成
			var rank_key: String = inst_id_str if not inst_id_str.is_empty() else platform_card.card_id
			var rank_info: Dictionary = get_rank_info(rank_key, bpm_ref)
			var rank_id: String = String(rank_info.get("rank_id", ""))
			var rank_bonus: Dictionary = RankRules.get_rank_bonus(rank_id)
			stats.max_hp *= float(rank_bonus.get("hp_mul", 1.0))
			var rank_dmg: float = float(rank_bonus.get("dmg_mul", 1.0))
			_multiply_attack_damage_and_weapon_slots(stats, rank_dmg)
		_apply_platform_enhance_growth_bias(stats, platform_card.card_id, bpm_ref)
		_apply_evolution_hp_floor(stats, platform_card, _preview_battle_era(), bpm_ref)
	_sync_single_weapon_damage_from_attack(stats)

## 计算 era0 预览 HP
static func compute_platform_preview_hp(card_id: String, era: int, bpm_ref: Node) -> float:
	var card: CardResource = DefaultCards.get_card_by_id(card_id)
	if card == null or card.card_type != GC.CardType.COMBAT_UNIT:
		return 0.0
	var stats: UnitStats = UnitStatsTable.build_stats_from_card(card, era)
	if stats == null:
		return 0.0
	apply_growth_to_stats(stats, card, [], bpm_ref, false)
	return stats.max_hp

## 获取卡片强化等级（通过 CardEnhancementManager Autoload）
static func _get_card_enhance_level(card_id: String) -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var cem: Node = tree.root.get_node_or_null("CardEnhancementManager")
		if cem != null and cem.has_method("get_card_enhancement_level"):
			return cem.get_card_enhancement_level(card_id)
	return 1
