extends RefCounted
## 战斗伤害与掉落子系统：敌方卡掉落、法则碎片、击杀奖励、星级评定
##
## 设计文档: docs/architecture/project-architecture.md (Sections 4.4, 5, 7)
## 从 BattleManager 中提取，负责所有伤害后处理与奖励结算逻辑。

const GC = preload("res://resources/game_constants.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const BasicResources = preload("res://data/basic_resources.gd")
const CardDropGrants = preload("res://scripts/card_drop_grants.gd")
const PhaseLaws = preload("res://data/phase_laws.gd")
const BattleEnvs = preload("res://data/battle_environments.gd")

# ---- 外部依赖引用（由 BattleManager 注入） ----
var _signal_bus: Node = null
var _player_units_node: Node = null

func setup(deps: Dictionary) -> void:
	_signal_bus = deps.get("signal_bus", null)
	_player_units_node = deps.get("player_units_node", null)

func set_player_units_node(node: Node) -> void:
	_player_units_node = node

# =========================================================================
#  敌方卡/蓝图副本掉落（敌人死亡时调用）
# =========================================================================

func roll_blueprint_drops(unit: Node) -> void:
	if unit.get("archetype_id") == null:
		return
	var archetype_id: String = unit.archetype_id
	var gm: Node = _get_autoload_node("GameManager")
	var drop_mult: float = 1.0
	if gm and gm.has_method("get_drop_rate_multiplier"):
		drop_mult = gm.get_drop_rate_multiplier(gm.current_level)
	var nano_amt: int = EnemyArchetypes.roll_nano_materials_on_kill(archetype_id, drop_mult)
	if nano_amt > 0:
		var brm: Node = _get_autoload_node("BasicResourceManager")
		if brm != null and brm.has_method("add_resource"):
			brm.add_resource(BasicResources.ID_NANO_MATERIALS, nano_amt)
	var drops: Array = EnemyArchetypes.get_drop_definitions(archetype_id)
	var bm: Node = _get_autoload_node("BlueprintManager")
	if bm == null:
		return
	var recon_bonus_mult: float = 1.0 + _get_recon_fragment_bonus_multiplier()
	for drop in drops:
		if not drop is Dictionary:
			continue
		var card_id: String = drop.get("card_id", "")
		var chance: float = float(drop.get("chance", 0.0)) * drop_mult
		if card_id.is_empty():
			continue
		if randf() > chance:
			continue
		# 掉落敌方风格卡（侦查/隐匿单位可提升每次数量）
		var fragment_amount_f: float = 1.0 * recon_bonus_mult
		var fragment_amount: int = int(floor(fragment_amount_f))
		var extra_prob: float = fragment_amount_f - float(fragment_amount)
		if randf() < extra_prob:
			fragment_amount += 1
		fragment_amount = max(1, fragment_amount)
		CardDropGrants.grant_enemy_style_card(bm, card_id, 0, fragment_amount)
		var qm: Node = _get_autoload_node("QuestManager")
		if qm and qm.has_method("notify_fragments_changed"):
			qm.notify_fragments_changed()
	_roll_law_knowledge_drops(unit)

# =========================================================================
#  法则知识值掉落（敌人死亡时调用，v3）
# =========================================================================

func _roll_law_knowledge_drops(unit: Node) -> void:
	if unit.get("archetype_id") == null:
		return
	var plm: Node = _get_autoload_node("PhaseLawManager")
	if plm == null:
		return
	# 知识值基础掉落概率
	var base_chance: float = 0.15
	# 精英/首领敌人掉落概率更高
	var archetype_id: String = unit.archetype_id
	var is_elite: bool = false
	var is_boss: bool = false
	var enemy_data: Dictionary = EnemyArchetypes.get_config(archetype_id)
	if not enemy_data.is_empty():
		var tags: Array = enemy_data.get("tags", [])
		is_elite = tags.has("elite")
		is_boss = tags.has("boss")
	var chance: float = base_chance
	if is_elite:
		chance = 0.30
	if is_boss:
		chance = 0.50
	# 侦查单位提升掉落概率
	var recon_bonus: float = _get_recon_fragment_bonus_multiplier()
	chance *= (1.0 + recon_bonus)
	if randf() > chance:
		return
	var law_id: String = _get_random_law_for_current_env()
	if law_id.is_empty():
		return
	var knowledge_amount: int = 3
	if is_boss:
		knowledge_amount = 8
	elif is_elite:
		knowledge_amount = 5
	if recon_bonus > 0.0:
		knowledge_amount += int(floor(recon_bonus * 2.0))
	knowledge_amount = max(1, knowledge_amount)
	var kind: String = plm.knowledge_key_for_law_id(law_id) if plm.has_method("knowledge_key_for_law_id") else ""
	if not kind.is_empty() and plm.has_method("add_knowledge"):
		plm.add_knowledge(kind, knowledge_amount)

# =========================================================================
#  侦查加成计算
# =========================================================================

func _get_recon_fragment_bonus_multiplier() -> float:
	if _player_units_node == null:
		return 0.0
	var recon_unit_count: int = 0
	for player_unit in _player_units_node.get_children():
		if not is_instance_valid(player_unit):
			continue
		if not player_unit.has_method("get"):
			continue
		var stats: UnitStats = player_unit.get("stats")
		if stats == null:
			continue
		if stats.platform_type == 5 or stats.platform_type == 10:  # SCOUT, STEALTH (旧枚举值，存档兼容)
			# v3: 应使用 stats.combat_kind，但 SCOUT(5)=轻装(0)，STEALTH(10)=轻装(0)
			# 为保持存档兼容，暂时保留 platform_type 检查
			recon_unit_count += 1
	var bonus: float = minf(GC.RECON_FRAGMENT_BONUS_CAP, float(recon_unit_count) * GC.RECON_FRAGMENT_BONUS_PER_UNIT)
	return bonus

# =========================================================================
#  根据当前关卡环境获取随机法则ID
# =========================================================================

func _get_random_law_for_current_env() -> String:
	var plm: Node = _get_autoload_node("PhaseLawManager")
	var current_env: Dictionary = {}
	if plm and plm.has_method("get_current_env"):
		current_env = plm.get_current_env()
	else:
		var gm: Node = _get_autoload_node("GameManager")
		if gm and gm.has_method("get"):
			var gm_level_raw: Variant = gm.current_level if "current_level" in gm else 1
			var level: int = int(gm_level_raw)
			current_env = BattleEnvs.get_for_level(level)
	if current_env.is_empty():
		current_env = {"weather": "clear", "terrain": "plain", "energy_field": "normal", "time_of_day": "day"}
	# 获取环境关联的法则流派
	var families: Array = []
	var weather: String = current_env.get("weather", "")
	var terrain: String = current_env.get("terrain", "")
	var energy_field: String = current_env.get("energy_field", "")
	var time_of_day: String = current_env.get("time_of_day", "")
	# 根据天气关联流派
	if weather == "storm" or weather == "rain":
		families.append("THUNDER")
	# 根据地形关联流派
	if terrain == "mountain" or terrain == "city":
		families.append("STEEL")
	# 根据能量场关联流派
	if energy_field == "high_field" or energy_field == "nano_fog":
		families.append("FLAME")
	if energy_field == "void_rift":
		families.append("VOID")
	# 根据时间关联流派
	if time_of_day == "dusk" or time_of_day == "night":
		families.append("VOID")
	# 如果没有环境关联，随机选择
	if families.is_empty():
		families = ["STEEL", "FLAME", "THUNDER", "VOID"]
	# 从关联流派中随机选择一个
	var chosen_family: String = families[randi() % families.size()]
	# 获取该流派的所有法则ID
	var law_ids: Array = []
	for lid in PhaseLaws.get_all_ids():
		if PhaseLaws.get_family(lid) == chosen_family:
			law_ids.append(lid)
	if law_ids.is_empty():
		return ""
	return law_ids[randi() % law_ids.size()]

# =========================================================================
#  击杀奖励处理（护盾等）
# =========================================================================

func process_kill_rewards(killed_unit: Node) -> void:
	if _player_units_node == null or killed_unit == null:
		return
	if not is_instance_valid(killed_unit):
		return

	# 获取最后造成伤害的玩家单位
	var killer_raw: Variant = null
	if killed_unit.has_method("get"):
		killer_raw = killed_unit.get("last_damage_source")
	var killer_unit: Node = null
	if killer_raw != null and is_instance_valid(killer_raw) and killer_raw is Node:
		killer_unit = killer_raw as Node

	if killer_unit == null:
		return

	# 检查击杀者是否有 shield_on_kill 词条
	if not killer_unit.has_method("get") or killer_unit.get("stats") == null:
		return

	var unit_stats: UnitStats = killer_unit.get("stats")
	if unit_stats == null or unit_stats.shield_on_kill <= 0.0:
		return

	# 应用护盾效果
	const AffixCombatHandler = preload("res://managers/affix_combat_handler.gd")
	var shield_gained: float = AffixCombatHandler.apply_shield_on_kill(killer_unit, unit_stats)

# =========================================================================
#  星级评定（战斗胜利时调用）
# =========================================================================

func calculate_victory_stars(max_deployed: int, units_lost: int, elapsed_time: float, wave_total: int, wave_interval: float) -> int:
	if max_deployed <= 0:
		return 1
	var survival_rate: float = 1.0
	if units_lost > 0:
		var survived: int = max_deployed - units_lost
		survival_rate = float(survived) / float(max_deployed)
	var stars: int = 1
	if survival_rate >= 0.5:
		stars = 2
	if survival_rate >= 0.8:
		var estimated_time: float = float(wave_total) * wave_interval + 15.0
		if estimated_time > 0.0 and elapsed_time <= estimated_time * 0.7:
			stars = 3
	print("[BattleDamageSystem] 星级计算: 部署=%d, 损失=%d, 存活率=%.0f%%, 时间=%.1fs → %d星" % [max_deployed, units_lost, survival_rate * 100.0, elapsed_time, stars])
	return stars

# =========================================================================
#  战斗胜利后为参战卡牌尝试奖励词条
# =========================================================================

func try_grant_battle_affixes(phase_instrument: Node) -> void:
	var am: Node = _get_autoload_node("AffixManager")
	if am == null or not am.has_method("on_battle_won"):
		return
	var pm: Node = phase_instrument
	if pm == null:
		pm = _get_autoload_node("PhaseInstrumentManager")
	if pm == null or not pm.has_method("get_loadouts"):
		return
	# 收集本局参战的所有卡牌 ID
	var card_ids: Array = []
	var loadouts: Array = pm.get_loadouts()
	for loadout in loadouts:
		if loadout is Dictionary:
			var plat: CardResource = loadout.get("platform", null)
			var wpns: Array = loadout.get("weapons", [])
			if plat != null and not plat.card_id.is_empty():
				if not card_ids.has(plat.card_id):
					card_ids.append(plat.card_id)
			for w in wpns:
				if w is CardResource and not (w as CardResource).card_id.is_empty():
					if not card_ids.has((w as CardResource).card_id):
						card_ids.append((w as CardResource).card_id)
	if card_ids.is_empty():
		return
	var gm: Node = _get_autoload_node("GameManager")
	var level: int = 1
	if gm and "current_level" in gm:
		level = int(gm.current_level)
	am.on_battle_won(card_ids, level)

# =========================================================================
#  战斗结算掉落生成
# =========================================================================

func generate_battle_completion_drops(player_won: bool, elapsed_time: float, wave_total: int, wave_interval: float, max_deployed: int, units_lost: int) -> Dictionary:
	var dm: Node = _get_autoload_node("DropManager")
	if dm == null or not dm.has_method("generate_battle_drops"):
		return {"victory_stars": 0, "era": 0, "player_won": player_won}

	var gm: Node = _get_autoload_node("GameManager")
	var level: int = 1
	var era: int = 0
	var victory_stars: int = 0

	if gm:
		if "current_level" in gm:
			level = int(gm.current_level)
		if gm.has_method("get_era"):
			era = gm.get_era(level)

	if not player_won:
		victory_stars = 0
	else:
		victory_stars = calculate_victory_stars(max_deployed, units_lost, elapsed_time, wave_total, wave_interval)

	var battle_result := {
		"victory_stars": victory_stars,
		"era": era,
		"player_won": player_won,
		"phase_instrument_drop": {},
	}

	var drops: Array = dm.generate_battle_drops(era, level, player_won, victory_stars)
	var pim: Node = _get_autoload_node("PhaseInstrumentManager")
	if pim != null and pim.has_method("try_roll_battle_drop_instrument"):
		var inst_drop: Dictionary = pim.try_roll_battle_drop_instrument(0.4, maxi(victory_stars - 1, 0))
		if not inst_drop.is_empty():
			# 防御性拷贝：确保 drops 是可变普通 Array（兼容 TypedArray 场景）
			var safe_drops: Array = []
			safe_drops.assign(drops)
			safe_drops.append(inst_drop)
			drops = safe_drops
			battle_result["phase_instrument_drop"] = inst_drop
	if not drops.is_empty():
		if _signal_bus and _signal_bus.has_signal("drops_ready_to_claim"):
			_signal_bus.drops_ready_to_claim.emit(drops)

	# ═══ v6.0: 情报收获生成 ═══
	var idm: Node = _get_autoload_node("IntelDiscoveryManager")
	if idm != null and idm.has_method("generate_battle_intel_harvest") and player_won:
		var defeated_list: Array = _collect_defeated_enemy_info()
		var current_env: Dictionary = {}
		if gm and gm.has_method("get"):
			var gm_level: Variant = gm.current_level if "current_level" in gm else 1
			var BattleEnvs = preload("res://data/battle_environments.gd")
			current_env = BattleEnvs.get_for_level(int(gm_level))
		var has_recon: bool = _get_recon_fragment_bonus_multiplier() > 0.0
		var intel_harvest: Dictionary = idm.generate_battle_intel_harvest(
			defeated_list, victory_stars, has_recon, current_env
		)
		battle_result["intel_harvest"] = intel_harvest
		# 敌源MOD碎片
		if intel_harvest.get("eom_drops", {}).size() > 0:
			battle_result["eom_fragments"] = intel_harvest["eom_drops"]

	return battle_result

# =========================================================================
#  v6.0: 收集本局击败的敌人信息（供情报系统使用）
# =========================================================================

func _collect_defeated_enemy_info() -> Array:
	## 从BattleManager获取本局击败的敌人列表
	var bm: Node = _get_autoload_node("BattleManager")
	if bm and bm.get("_defeated_enemies") != null:
		var list = bm._defeated_enemies
		if list is Array:
			return list.duplicate(true)
	return []

func _get_autoload_node(name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null(name)
	return null
