class_name EnemyMasterSkillEngine
extends RefCounted
## v8.5: 敌方相位师（boss）主动技能执行引擎
##
## 背景：30 个 boss 的 active_spells/passive_spells 数据完整（约 120 个 effect 名），
## 但战斗侧零消费（仅 UI 展示）。本引擎让 boss 在战斗中真实触发主动技能。
##
## 设计决策：
## 1. 不逐一实装 120 个 effect 名（不可维护），按语义聚类归并到 3 个通用执行函数：
##    - AOE伤害类（explosion/meteor/aoe/global_damage/nuke/...）→ _exec_aoe_damage
##    - 连锁闪电类（chain/lightning/...）→ _exec_chain_lightning
##    - 召唤类（summon/deploy/portal/...）→ _exec_summon
##    其余 effect 名未映射的，跳过（不崩溃），后续可扩展。
## 2. 伤害按 boss stats.attack_power 派生（与现有敌方难度链一致），避免秒杀。
## 3. 由 battle_manager 实例化并 update(delta) 驱动（仿 card_periodic_skill_engine 范式）。
## 4. VFX 复用 VfxImpactFactory + BattleSpectacle 信号（与 PhaseInstrumentAbilities 同款）。
##
## 范围（v8.5 首批）：仅 active_spells（定时触发）。passive_spells（事件触发型）留待后续。

const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const DT = preload("res://resources/design_tokens.gd")

## v9.3: 敌方相位师大招差异化演出
## 背景：原 6 个 _exec_* 全部走通用程序化 VFX（同质化冲击波环），玩家无法区分
## void_apocalypse / hell_inferno / tesla_chain 等不同大招。
## v9.3c: 每类大招接入 AI 生成的专属贴图（spawn_spell_burst），对齐核子轰炸表现力。
##   核爆贴图只用给核爆类技能，不滥用到其他语义大招。
## 全屏演出经 SignalBus.phase_instrument_ability_triggered 委托 BattleSpectacle（职责分离）。
##
## 贴图懒加载缓存（首次需要时加载，后续命中复用）。ResourceLoader.exists 守卫缺失贴图。
var _nuke_texture_cache: Dictionary = {}
## v9.3c: 大招专属贴图缓存（assets/effects/spell_burst/，AI 生成 + 抠图）
var _spell_texture_cache: Dictionary = {}
## v9.5: 大招飞行弹体贴图缓存（assets/effects/ultimate_projectiles/，AI 生成 + 抠图）
var _projectile_texture_cache: Dictionary = {}

## boss driver 引用（取 active_spells + stats + 全局位置）
var _driver: Node = null
## 战场节点（spawn VFX 用）
var _battlefield: Node = null
## 各技能的计时器  key: spell_id -> elapsed
var _timers: Dictionary = {}
## 是否已激活
var _active: bool = false
## v8.5: 被动技能 tick 累加器（光环类每 0.5s 结算一次，避免每帧扫描）
var _passive_tick_acc: float = 0.0
const PASSIVE_TICK_INTERVAL: float = 0.5
## v8.5: buff 类是否已应用（一次性，避免重复加 buff meta）
var _passive_buff_applied: bool = false

## 战斗开始时调用：缓存 driver/battlefield，初始化计时器
func setup(driver: Node, battlefield: Node) -> void:
	_driver = driver
	_battlefield = battlefield
	_timers.clear()
	# 初始化每个 active_spell 的计时器（首次触发等一个完整 cooldown）
	if _driver != null and _driver.has_method("get_boss_active_spells"):
		for spell in _driver.get_boss_active_spells():
			var sid: String = String(spell.get("id", ""))
			if not sid.is_empty():
				# v8.6: 首次触发用完整 CD 的 35%（开场首秀，避免 WW1 boss 等 28s 才第一次放技能）
				var full_cd: float = float(spell.get("cooldown", 20.0))
				_timers[sid] = full_cd * 0.35
	_active = true

## 停止（战斗结束/boss 死亡时调用）
func stop() -> void:
	_active = false

## 每帧驱动（由 battle_manager._process 调用）
func update(delta: float) -> void:
	if not _active or _driver == null or not is_instance_valid(_driver):
		return
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	if not _driver.has_method("get_boss_active_spells"):
		return
	var spells: Array = _driver.get_boss_active_spells()
	for spell in spells:
		if not (spell is Dictionary):
			continue
		var sid: String = String(spell.get("id", ""))
		if sid.is_empty():
			continue
		var cd: float = float(spell.get("cooldown", 20.0))
		if cd <= 0.0:
			continue
		var elapsed: float = float(_timers.get(sid, cd))
		elapsed += delta
		if elapsed >= cd:
			elapsed = 0.0
			_trigger_spell(spell)
		_timers[sid] = elapsed
	# v8.5: 被动技能 tick（光环/buff/debuff 类，每 PASSIVE_TICK_INTERVAL 结算）
	update_passives(delta)

## v8.5: 被动技能 tick（光环持续伤害/抽血 + buff 一次性应用）
func update_passives(delta: float) -> void:
	if not _active or _driver == null or not is_instance_valid(_driver):
		return
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	if not _driver.has_method("get_boss_passive_spells"):
		return
	var passives: Array = _driver.get_boss_passive_spells()
	if passives.is_empty():
		return
	# buff 类一次性应用（首次调用时）
	if not _passive_buff_applied:
		_passive_buff_applied = true
		_apply_passive_buffs(passives)
	# 光环类节流 tick（每 0.5s 结算一次范围内伤害/抽血）
	_passive_tick_acc += delta
	if _passive_tick_acc < PASSIVE_TICK_INTERVAL:
		return
	var tick_dt: float = _passive_tick_acc
	_passive_tick_acc = 0.0
	for spell in passives:
		if not (spell is Dictionary):
			continue
		var effect: String = String(spell.get("effect", "")).to_lower()
		var params: Dictionary = spell.get("params", {})
		# v18 四源重构·批次3: 节点 kind 优先精确分发（数据来自 EnemyMasterSkillTree 机制节点）。
		# 修复旧误路由：massive_heal_aura 含 'aura' 被 _is_aura_effect 抢先命中 → 治疗光环
		# 实际走伤害 tick 打玩家。kind 显式标注后不再依赖关键字优先级。
		var kind: String = String(spell.get("kind", ""))
		if kind == "aura_damage":
			_tick_aura_damage(params, effect, tick_dt)
		elif kind == "aura_heal":
			# v9.1: 治疗光环类 → 持续治疗范围内友军
			_tick_aura_heal(params, tick_dt)
		elif kind.is_empty():
			# 兼容路径：无 kind 的旧配置沿用关键字判定
			if _is_aura_effect(effect):
				_tick_aura_damage(params, effect, tick_dt)
			elif _is_heal_aura_effect(effect):
				_tick_aura_heal(params, tick_dt)

## v8.5: 一次性应用 buff 类被动（armor_boost/formation_bonus 等直接改敌方单位 stats）
## 直接修改 stats（每单位独立实例，安全），立即生效不依赖 meta 读取
func _apply_passive_buffs(passives: Array) -> void:
	var allies: Array = _get_enemy_units()
	if allies.is_empty():
		return
	for spell in passives:
		if not (spell is Dictionary):
			continue
		var effect: String = String(spell.get("effect", "")).to_lower()
		var params: Dictionary = spell.get("params", {})
		var name_text: String = String(spell.get("name", effect))
		# armor_boost / *_defense → 三维防御 ×(1+bonus)
		if effect.find("armor") >= 0 or effect.find("defence") >= 0 or effect.find("defense") >= 0:
			var bonus: float = float(params.get("bonus", 0.15))
			for a in allies:
				if a != null and is_instance_valid(a) and "stats" in a and a.stats != null:
					a.stats.defense_light *= (1.0 + bonus)
					a.stats.defense_armor *= (1.0 + bonus)
					a.stats.defense_air *= (1.0 + bonus)
			_show_toast("🛡 %s：敌方全体防御 +%d%%" % [name_text, int(bonus * 100)])
		# damage_boost / *_mastery / formation_bonus → 三维攻击 ×(1+boost)
		elif effect.find("damage") >= 0 or effect.find("boost") >= 0 or effect.find("mastery") >= 0 \
		     or effect.find("formation") >= 0:
			var boost: float = float(params.get("damage_boost", params.get("bonus", 0.20)))
			for a in allies:
				if a != null and is_instance_valid(a) and "stats" in a and a.stats != null:
					a.stats.attack_light *= (1.0 + boost)
					a.stats.attack_armor *= (1.0 + boost)
					a.stats.attack_air *= (1.0 + boost)
			_show_toast("⚔ %s：敌方全体攻击 +%d%%" % [name_text, int(boost * 100)])
		# thorn/spike 类被动 → boss 反伤（一次性设置 _boss_thorn_pct）
		elif effect.find("thorn") >= 0 or effect.find("spike") >= 0 or effect.find("reflect") >= 0:
			var thorn_pct: float = float(params.get("reflect_pct", params.get("bonus", 0.25)))
			if _driver != null and is_instance_valid(_driver) and _driver.has_method("set_boss_thorn"):
				_driver.set_boss_thorn(thorn_pct)
			_show_toast("🌵 %s：boss 反伤 %d%%" % [name_text, int(thorn_pct * 100)])
		# v9.1: 能量护盾类（energy_shield/shield_base）→ boss 自身获得护盾（一次性开局施加）
		# 注：active_spell 的 energy_shield 由 _trigger_spell 的 _exec_shield_self 定时处理，
		# 此处仅处理 passive_spells 中的同名 effect（开局即生效，非定时）。
		elif effect.find("energy_shield") >= 0 or effect == "shield_base":
			var shield_pct: float = float(params.get("shield_pct", params.get("bonus", 0.20)))
			if _driver != null and is_instance_valid(_driver) and _driver.has_method("add_boss_shield"):
				var boss_max_hp: float = float(_driver.get("max_hp")) if "max_hp" in _driver else 1000.0
				var shield_amt: float = boss_max_hp * shield_pct
				shield_amt = minf(shield_amt, boss_max_hp * 0.60)
				_driver.add_boss_shield(shield_amt)
				_show_toast("🛡 %s：boss 获得 %.0f 护盾" % [name_text, shield_amt])
				_flash_driver_on_buff()
		# v9.1: 高能量增益类（high_energy_bonus/overcharge）→ 记录阈值与加成到 driver meta，
		# 由 driver._process 自行检查能量状态并应用攻速加成（engine 不持有能量状态）。
		elif effect.find("high_energy") >= 0 or effect.find("overcharge") >= 0:
			var threshold: float = float(params.get("threshold", 0.8))
			var boost_val: float = float(params.get("attack_speed_boost", params.get("boost", 0.4)))
			if _driver != null and is_instance_valid(_driver):
				_driver.set_meta("high_energy_threshold", threshold)
				_driver.set_meta("high_energy_boost", boost_val)
			_show_toast("⚡ %s：能量超 %d%% 时攻速+%d%%" % [name_text, int(threshold * 100), int(boost_val * 100)])
			_flash_driver_on_buff()
		# v9.1: 大规模治疗光环类（massive_heal_aura/healing_aura）→ 记录到 driver meta，
		# 由 engine.update_passives 的 tick 路径调 _tick_aura_heal 持续治疗友军。
		elif effect.find("heal") >= 0 or effect.find("healing") >= 0 or effect.find("massive_heal") >= 0:
			var heal_pct: float = float(params.get("heal_percent", params.get("bonus", 0.04)))
			var heal_radius: float = float(params.get("radius", 250.0))
			if _driver != null and is_instance_valid(_driver):
				_driver.set_meta("heal_aura_percent", heal_pct)
				_driver.set_meta("heal_aura_radius", heal_radius)
			_show_toast("✨ %s：范围内友军每秒恢复 %d%% HP" % [name_text, int(heal_pct * 100)])
			_flash_driver_on_buff()
		# v9.1: death_shield 类（友军死亡回盾）→ 标记到 driver，由 _on_any_unit_died 触发
		# （不在此处应用，仅 set_meta 占位；实际触发在 enemy_phase_field_driver._try_trigger_death_shield）
		elif effect.find("death_shield") >= 0:
			# 占位 meta（driver._try_trigger_death_shield 直接读 passive_spells，不依赖此 meta，
			# 但保留 set_meta 供其他系统查询 boss 是否有此被动）
			if _driver != null and is_instance_valid(_driver):
				var ds_pct: float = float(params.get("shield_percent", params.get("shield_pct", 0.05)))
				_driver.set_meta("death_shield_pct", ds_pct)
			_show_toast("💚 %s：友军阵亡时 boss 回护盾" % name_text)

## v8.5: 光环类被动 tick（damage_aura/max_hp_drain/entropy_drain 等范围内持续伤害）
func _tick_aura_damage(params: Dictionary, effect: String, tick_dt: float) -> void:
	var radius: float = float(params.get("radius", 150.0))
	var boss_pos: Vector2 = _get_driver_pos()
	var targets: Array = _get_player_units()
	for t in targets:
		if t == null or not is_instance_valid(t) or not (t is Node2D):
			continue
		if boss_pos.distance_to((t as Node2D).global_position) > radius:
			continue
		# damage_aura：固定点数伤害（按 tick_dt 缩放，参数是每秒值）
		var dmg: float = 0.0
		if effect.find("max_hp") >= 0 or effect.find("drain") >= 0 or effect.find("entropy") >= 0:
			# 百分比抽血：按目标 max_hp 的百分比/秒
			var pct: float = float(params.get("drain_percent", params.get("bonus", 0.01)))
			# 修复：玩家单位 max_hp 在 t.stats.max_hp（顶层无 max_hp，旧 fallback 100 致抽血量级低 99%）
			var t_stats = t.get("stats") if "stats" in t else null
			var t_max_hp: float = float(t_stats.max_hp) if t_stats != null and "max_hp" in t_stats else (float(t.get("max_hp")) if "max_hp" in t else 100.0)
			dmg = t_max_hp * pct * tick_dt
		else:
			# 固定伤害：params.damage 是每秒值
			var dps: float = float(params.get("damage", 30.0))
			dmg = dps * tick_dt
		if dmg > 0.0 and t.has_method("take_damage"):
			t.take_damage(dmg, _driver)

## v9.1: 治疗光环 tick（massive_heal_aura/healing_aura 类，正向治疗范围内友军）。
## 治疗量 = 友军 max_hp × heal_percent × tick_dt（每秒值，按 tick_dt 缩放）。
## 半径优先读 spell.params.radius，回退 driver meta heal_aura_radius（_apply_passive_buffs 写入）。
func _tick_aura_heal(params: Dictionary, tick_dt: float) -> void:
	if _driver == null or not is_instance_valid(_driver):
		return
	# heal_percent 优先读 params，回退 driver meta（_apply_passive_buffs 标记）
	var heal_pct: float = float(params.get("heal_percent", params.get("bonus", 0.04)))
	if _driver.has_meta("heal_aura_percent"):
		heal_pct = float(_driver.get_meta("heal_aura_percent", heal_pct))
	var radius: float = float(params.get("radius", 250.0))
	if _driver.has_meta("heal_aura_radius"):
		radius = float(_driver.get_meta("heal_aura_radius", radius))
	var boss_pos: Vector2 = _get_driver_pos()
	var allies: Array = _get_enemy_units()
	for a in allies:
		if a == null or not is_instance_valid(a) or not (a is Node2D):
			continue
		if boss_pos.distance_to((a as Node2D).global_position) > radius:
			continue
		# 友军 max_hp：优先 stats.max_hp，回退顶层 max_hp，再回退 100
		var a_max_hp: float = 100.0
		if "stats" in a and a.stats != null and "max_hp" in a.stats:
			a_max_hp = float(a.stats.max_hp)
		elif "max_hp" in a:
			a_max_hp = float(a.max_hp)
		var heal_amt: float = a_max_hp * heal_pct * tick_dt
		if heal_amt > 0.0:
			# 优先 heal 方法（ConstructUnit 有），回退 heal_hp（EnemyUnit 风格），再回退直接改 hp
			if a.has_method("heal"):
				a.heal(heal_amt)
			elif a.has_method("heal_hp"):
				a.heal_hp(heal_amt)
			elif "hp" in a:
				a.hp = minf(float(a.hp) + heal_amt, a_max_hp)

## v9.1: 治疗光环 effect 判定（区别于伤害类 _is_aura_effect）
func _is_heal_aura_effect(effect: String) -> bool:
	return effect.find("heal") >= 0 or effect.find("healing") >= 0 or effect.find("massive_heal") >= 0

## v8.5: boss 死亡时触发死亡类被动（death_explosion/cheat_death 等）
## 在 driver._on_destroyed 调 queue_free 之前调用（此时 driver 仍有效）
func on_boss_destroyed() -> void:
	if _driver == null or not is_instance_valid(_driver):
		return
	if not _driver.has_method("get_boss_passive_spells"):
		return
	var passives: Array = _driver.get_boss_passive_spells()
	var boss_pos: Vector2 = _get_driver_pos()
	for spell in passives:
		if not (spell is Dictionary):
			continue
		var effect: String = String(spell.get("effect", "")).to_lower()
		var params: Dictionary = spell.get("params", {})
		var name_text: String = String(spell.get("name", effect))
		# death_explosion：死亡时对全场玩家造成一次大伤害 + 爆炸 VFX
		if effect.find("death") >= 0 and (effect.find("explosion") >= 0 or effect.find("blast") >= 0):
			var dmg_mult: float = float(params.get("damage_mult", 2.0))
			# [NUKE-DIAG] BOSS 死亡爆炸——这是"敌方死→玩家伤"的唯一活跃路径，
			# VFX(橙红冲击波)与玩家核爆高度重合，是"核爆波及我方"的最可能根因
			if OS.is_debug_build():
				var _diag_targets: Array = _get_player_units()
				print("[NUKE-DIAG] BOSS死亡爆炸触发！effect=%s dmg_mult=%.1f 将对%d个玩家单位造成AOE伤害" % [effect, dmg_mult, _diag_targets.size()])
			_exec_aoe_damage(dmg_mult, name_text)
			# 中心大爆炸 VFX
			if _battlefield != null and is_instance_valid(_battlefield):
				VfxImpactFactory.spawn_shockwave(_battlefield, boss_pos, 200.0, Color(1.0, 0.4, 0.2, 1.0))
			_trigger_screen_shake(12.0, 0.8)
			_show_toast("💥 %s！boss 死亡爆炸" % name_text)
	# 停止引擎
	_active = false

## 光环类 effect 判定（持续 tick 型，区别于 active 的定时 AOE）
func _is_aura_effect(effect: String) -> bool:
	var keywords: Array = ["aura", "drain", "entropy", "damage_aura", "burning_aura",
		"self_damage", "time_based", "life_energy"]
	for k in keywords:
		if effect.find(k) >= 0:
			return true
	return false

## 获取敌方单位列表（boss 的友军，用于 buff 类被动）
func _get_enemy_units() -> Array:
	var tree := _driver.get_tree() if _driver != null else null
	if tree == null:
		return []
	return tree.get_nodes_in_group("enemy_units")

## 触发单个技能：按 effect 名聚类映射到通用执行函数
## v17f: 时序对齐——_play_spell_cinematic 返回主弹体飞行时长，
## 伤害侧以该时长为延迟基准结算（旧版伤害 0.4s 固定延迟 vs 演出 0.55s 飞行
## → 单位先掉血陨石才落地，"果先于因"倒置）。
func _trigger_spell(spell: Dictionary) -> void:
	var effect: String = String(spell.get("effect", "")).to_lower()
	var params: Dictionary = spell.get("params", {}) if spell is Dictionary else {}
	var name_text: String = String(spell.get("name", effect))
	# 伤害倍率（默认 1.0，可被 params.damage_mult 覆盖）
	var dmg_mult: float = float(params.get("damage_mult", 1.0))
	# v9.3: 差异化演出（在伤害结算前触发，给玩家预警反应时间）
	# v17f: 返回演出主时长（无飞行弹体的类别返回默认延迟），供伤害侧对齐
	var cinematic_delay: float = _play_spell_cinematic(effect, name_text, params)
	# 按关键字聚类（顺序敏感：先匹配更具体的）
	if _is_aoe_effect(effect):
		_exec_aoe_damage(dmg_mult, name_text, cinematic_delay)
	elif _is_chain_effect(effect):
		_exec_chain_lightning(dmg_mult, name_text, cinematic_delay)
	elif _is_summon_effect(effect):
		_exec_summon(params, name_text)
	elif _is_debuff_effect(effect):
		_exec_debuff_players(params, name_text)
	elif _is_shield_effect(effect):
		_exec_shield_self(params, name_text)
	elif _is_single_target_effect(effect):
		_exec_single_target(dmg_mult, name_text, cinematic_delay)
	# 未匹配的 effect 静默跳过（不崩溃；后续可扩展更多聚类）

# ─────────────────────────────────────────────
#  effect 聚类判定（关键字匹配）
# ─────────────────────────────────────────────
func _is_aoe_effect(effect: String) -> bool:
	# 范围/全图伤害类：explosion/meteor/aoe/global_damage/nuke/bombard/quake/void/hell/solar/flame_wave
	var keywords: Array = ["explosion", "meteor", "aoe", "global_damage", "global_dot",
		"nuke", "bombard", "quake", "void_apocalypse", "hell", "solar", "flame_wave",
		"pyroblast", "black_hole", "hammer_smash", "massive", "instant_kill_zone",
		"damage_aura", "burning", "chaos", "apocalypse"]
	for k in keywords:
		if effect.find(k) >= 0:
			return true
	return false

func _is_chain_effect(effect: String) -> bool:
	# 连锁/闪电类：chain/lightning/tesla
	var keywords: Array = ["chain", "lightning", "tesla", "thunder"]
	for k in keywords:
		if effect.find(k) >= 0:
			return true
	return false

func _is_summon_effect(effect: String) -> bool:
	# 召唤类：summon/deploy/portal/clones
	var keywords: Array = ["summon", "deploy", "portal", "clones", "mech", "forge"]
	for k in keywords:
		if effect.find(k) >= 0:
			return true
	return false

func _is_debuff_effect(effect: String) -> bool:
	# debuff 类：slow/stun/darkness/emp/weakness（减玩家攻速/暴击/闪避）
	var keywords: Array = ["slow", "stun", "darkness", "emp", "weakness", "debuff", "wind_push"]
	for k in keywords:
		if effect.find(k) >= 0:
			return true
	return false

func _is_shield_effect(effect: String) -> bool:
	# 护盾类：shield/dome/barrier/ward（给 boss 自身加护盾）
	var keywords: Array = ["shield", "dome", "barrier", "ward", "bulwark"]
	for k in keywords:
		if effect.find(k) >= 0:
			return true
	return false

func _is_single_target_effect(effect: String) -> bool:
	# 单体高伤类：single/snipe/pierce/god_weapon（对单个高威胁玩家单位高伤）
	var keywords: Array = ["single", "snipe", "god_weapon", "piercing_shot", "devour"]
	for k in keywords:
		if effect.find(k) >= 0:
			return true
	return false

# ─────────────────────────────────────────────
#  v9.3: 差异化演出分流（在伤害结算前触发）
# ─────────────────────────────────────────────

## 按 effect 语义判定演出类别，触发对应的局部 VFX + 全屏演出。
## 局部 VFX 直接调 VfxImpactFactory；全屏演出经 SignalBus 委托 BattleSpectacle。
## 性能：每次大招只 emit 一次全屏信号；局部 VFX 复用对象池；尊重 motion_reduce。
## v17f: 返回演出主时长（秒）——伤害侧以此延迟结算，保证"弹体落地→爆炸→掉血"因果同帧。
## 无飞行弹体的类别返回各自默认延迟（chain 0.3 预警窗口 / debuff·summon·shield 0 即时）。
func _play_spell_cinematic(effect: String, name_text: String, _params: Dictionary) -> float:
	if DT.is_motion_reduce():
		return 0.0  # 减动效：跳过全部演出，伤害即时结算（时序无从对齐，保持数值节奏）
	if _battlefield == null or not is_instance_valid(_battlefield):
		return 0.0
	# 天降毁灭类（void_apocalypse / meteor_apocalypse / orbital_bombard / abyss / bombard_explosion）
	if _is_cinematic_apocalypse(effect):
		return _play_apocalypse_cinematic(effect, name_text)
	# 地狱火焰类（hell_inferno / napalm / meteor_flame / hellfire_explosion）
	elif _is_cinematic_inferno(effect):
		return _play_inferno_cinematic(effect, name_text)
	# 连锁闪电类（tesla_chain / chain_lightning / thunderstorm / thunder / lightning_chain）
	elif _is_cinematic_chain(effect):
		return _play_chain_cinematic(effect, name_text)
	# 单体打击类（god_weapon_single / devour_single）
	elif _is_single_target_effect(effect):
		return _play_single_target_cinematic(effect, name_text)
	# 召唤/传送类（mech_deploy / forge_summon / deploy_legion / summon）
	elif _is_summon_effect(effect):
		_play_summon_cinematic(effect, name_text)
		return 0.0
	# debuff 类（darkness / emp / weakness）
	elif _is_debuff_effect(effect):
		_play_debuff_cinematic(effect, name_text)
		return 0.0
	# 护盾类（energy_shield / dome_barrier / plate_shield / ward_bulwark）
	elif _is_shield_effect(effect):
		_play_shield_cinematic(effect, name_text)
		return 0.0
	return 0.0

# ── 演出类别判定 ──

func _is_cinematic_apocalypse(effect: String) -> bool:
	# 注：用 "meteor_apocalypse" 而非裸 "meteor"，避免误命中 meteor_flame（归 inferno 类）
	for k in ["apocalypse", "orbital_bombard", "bombard_explosion", "void_explosion", "meteor_apocalypse"]:
		if effect.find(k) >= 0:
			return true
	return false

func _is_cinematic_inferno(effect: String) -> bool:
	for k in ["inferno", "napalm", "meteor_flame", "hellfire"]:
		if effect.find(k) >= 0:
			return true
	return false

func _is_cinematic_chain(effect: String) -> bool:
	for k in ["chain", "tesla", "thunder", "lightning"]:
		if effect.find(k) >= 0:
			return true
	return false

# ── 各类演出实现 ──

## A. 天降毁灭：全屏暗红预警 + 飞行弹体从天而降（不同 effect 不同弹体/配色）+ 落地爆炸。
## v9.5: 从"原地能量光柱"升级为"有飞行弹道"——陨石/轨道弹/虚空球从屏幕外飞到目标点再爆炸，更写实。
## 覆盖 void_apocalypse(×6)/meteor_apocalypse(×3)/orbital_bombard/abyss/bombard 等 11 个 boss 大招。
func _play_apocalypse_cinematic(effect: String, name_text: String) -> float:
	# v17f: 返回主弹体飞行时长 0.55s（伤害侧以此延迟，落地→爆炸→掉血同帧）
	# v20.15: 快照战斗状态——错峰发射/延迟 impact 在战斗结束后全部作废（贴图残留根因）
	var was_live: bool = _battle_active_now()
	var title: String = "陨石雨"
	if effect.find("void") >= 0:
		title = "虚空灾变"
	elif effect.find("orbital") >= 0 or effect.find("bombard") >= 0:
		title = "轨道轰炸"
	elif effect.find("abyss") >= 0:
		title = "深渊降临"
	# 按 effect 类型选飞行弹体 + 配色 + 拖尾色（针对性区分）
	var proj_id: String = "ult_meteor"  # 默认陨石
	var proj_tint: Color = Color(1.0, 0.5, 0.2)  # 橙红
	var trail_color: Color = Color(1.0, 0.6, 0.2, 0.9)
	var burst_id: String = "apocalypse_meteor"
	var burst_tint: Color = Color(1.0, 0.5, 0.2)
	if effect.find("void") >= 0 or effect.find("abyss") >= 0:
		proj_id = "ult_void_orb"
		proj_tint = Color(0.82, 0.45, 1.0)   # v17g 减染：tint 饱和度降（旧 0.25 重着色盖掉贴图细节，AI 2/10"占位级椭圆"）
		trail_color = Color(0.78, 0.4, 1.0, 0.9)
		burst_id = "apocalypse_void"
		burst_tint = Color(0.82, 0.45, 1.0)
	elif effect.find("orbital") >= 0 or effect.find("bombard") >= 0:
		proj_id = "ult_orbital"
		proj_tint = Color(0.5, 0.85, 1.0)
		trail_color = Color(0.5, 0.85, 1.0, 0.9)
		# v9.6 (P3-a): 落地爆炸贴图沿用 apocalypse_meteor，但色调改蓝青——
		# 原橙红爆炸与蓝青弹体/拖尾/冲击波配色断裂（void 分支有专属 burst 覆盖，orbital 漏了）
		burst_tint = Color(0.5, 0.85, 1.0)
	# 全屏预警（委托 BattleSpectacle）
	_emit_cinematic("enemy_spell_apocalypse", "warning", {"title": "%s·%s" % [name_text, title]})
	_flash_driver_on_cast(0.7)  # boss 本体施法闪光（紫红调，大招峰值）
	_spawn_target_warning_marks()  # v17i: 目标脚下红色脉冲（AI 批"预警帧等于空白"）
	var boss_pos: Vector2 = _get_driver_pos()
	var proj_tex: Texture2D = _load_projectile_texture(proj_id)
	var burst_tex: Texture2D = _load_spell_texture(burst_id)
	# boss 位置：一发大弹体从正上方高空垂直落下 → 落地大爆炸（on_arrival 回调触发）
	var sky_height: float = 500.0  # 起点在目标上方 500px（屏幕外高空）
	var boss_from: Vector2 = Vector2(boss_pos.x, boss_pos.y - sky_height)
	VfxImpactFactory.spawn_ultimate_projectile(_battlefield, boss_from, boss_pos, proj_tex, "vertical", 80.0, proj_tint, trail_color, 0.55,
		func(land_pos: Vector2):
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
			# 落地：冲击波 + 大爆炸贴图（替代原能量光柱）
			VfxImpactFactory.spawn_shockwave(_battlefield, land_pos, 200.0, Color(proj_tint.r, proj_tint.g, proj_tint.b, 0.7))
			# v17j: 双冲击环（AI 批"冲击波亮度/对比度偏低，内外层落差不足"）——
			# 快环（上，200px）收束动量 + 慢环（280px 低 alpha）拉开扩散层次
			VfxImpactFactory.spawn_shockwave(_battlefield, land_pos, 280.0, Color(proj_tint.r, proj_tint.g, proj_tint.b, 0.4))
			# v17g 放大(v17g 脚本中断丢盘补) + v17h 补层(AI 批缺碎屑/crater/层次)
			VfxImpactFactory.spawn_layered_impact(_battlefield, land_pos, 3, false, -1, {"power_tier": 2})
			VfxImpactFactory.spawn_ground_burn(_battlefield, land_pos, 90.0, 0.25, VfxImpactFactory.PARTICLE_TEX_IMPACT_SCORCH)
			if burst_tex != null:
				VfxImpactFactory.spawn_spell_burst(_battlefield, land_pos, burst_tex, burst_tint, 480.0, 0.9)
	)
	# 各玩家单位位置：小弹体从高空垂直落下（节流：最多 9 个目标，适配三行布局）
	var spawned: int = 0
	for t in _get_player_units():
		if spawned >= 9:  # v9.3: 适配三行9格布局（原6）
			break
		if t == null or not is_instance_valid(t) or not (t is Node2D):
			continue
		var tpos: Vector2 = (t as Node2D).global_position
		var t_from: Vector2 = Vector2(tpos.x, tpos.y - sky_height)
		# 错开 0.08s 让弹体依次落下（地毯轰炸感），而非同时
		var delay: float = float(spawned) * 0.08
		var captured_tpos: Vector2 = tpos
		var captured_delay: float = delay
		var tw_d := _battlefield.create_tween()
		tw_d.tween_interval(captured_delay)
		tw_d.tween_callback(func():
			# v20.15: 战斗在错峰窗口内结束 → 后续小弹体不再发射（残留在结算背景的漏网链）
			if was_live and not _battle_active_now():
				return
			VfxImpactFactory.spawn_ultimate_projectile(_battlefield, Vector2(captured_tpos.x, captured_tpos.y - sky_height), captured_tpos, proj_tex, "vertical", 52.0, proj_tint, trail_color, 0.45,
				func(lp: Vector2):
					if _battlefield == null or not is_instance_valid(_battlefield):
						return
					VfxImpactFactory.spawn_shockwave(_battlefield, lp, 110.0, Color(proj_tint.r * 0.8, proj_tint.g * 0.8, proj_tint.b * 0.8, 0.8))
			)
		)
		spawned += 1
	# impact 信号延迟到主弹体落地后（0.55s），与爆炸同步
	var tw_impact := _battlefield.create_tween()
	tw_impact.tween_interval(0.55)
	tw_impact.tween_callback(func():
		if was_live and not _battle_active_now():
			return  # v20.15: 战斗已结束——不再对结算画面打全屏定帧闪/震屏
		_emit_cinematic("enemy_spell_apocalypse", "impact", {})
		_trigger_screen_shake(9.0, 0.55)
	)
	return 0.55

## B. 地狱火焰：燃烧弹从侧方低空俯冲飞入 → 落地火焰爆炸 + 橙红烟柱。
## v9.5: 从"原地火球"升级为"空投燃烧弹弹道"，体现"从天投下火海"的写实感。
## 覆盖 hell_inferno(×2)/napalm/meteor_flame/hellfire_explosion 5 个 boss 大招。
func _play_inferno_cinematic(_effect: String, name_text: String) -> float:
	# v17f: 返回燃烧弹飞行时长 0.5s
	# v20.15: 快照战斗状态——错峰发射/延迟 impact 在战斗结束后全部作废（贴图残留根因）
	var was_live: bool = _battle_active_now()
	_emit_cinematic("enemy_spell_inferno", "warning", {"title": "%s·地狱烈焰" % name_text})
	_flash_driver_on_cast(0.65, Color(1.0, 0.4, 0.15))  # boss 本体施法闪光（橙红调）
	_spawn_target_warning_marks()  # v17i: 燃烧弹落点预警（AI 批"缺直接威胁提示"）
	var boss_pos: Vector2 = _get_driver_pos()
	var hell_tex: Texture2D = _load_spell_texture("inferno_hell")
	var bomb_tex: Texture2D = _load_projectile_texture("ult_inferno_bomb")
	var bomb_tint: Color = Color(1.0, 0.4, 0.15)
	var trail_color: Color = Color(1.0, 0.35, 0.1, 0.95)  # 火焰拖尾
	# boss 位置：大燃烧弹从侧方高空俯冲 → 落地大火球 + 烟柱
	# 起点在 boss 左上方屏幕外（dive 轨迹=低空俯冲，体现"空投"）
	var bomb_from: Vector2 = Vector2(boss_pos.x - 350.0, boss_pos.y - 400.0)
	VfxImpactFactory.spawn_ultimate_projectile(_battlefield, bomb_from, boss_pos, bomb_tex, "dive", 72.0, bomb_tint, trail_color, 0.5,
		func(land_pos: Vector2):
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
			# 落地：大火球爆炸 + 冲击波 + 烟柱 + 完整层次（火焰蔓延感）
			# v17h 补层：HEAVY 火箭级 layered + 焦痕（AI 批"层次为零/烟柱冲击波缺失"）
			if hell_tex != null:
				VfxImpactFactory.spawn_spell_burst(_battlefield, land_pos, hell_tex, Color(1.0, 0.3, 0.1), 460.0, 0.9)
			VfxImpactFactory.spawn_shockwave(_battlefield, land_pos, 160.0, Color(1.0, 0.35, 0.1, 0.9))
			VfxImpactFactory.spawn_shockwave(_battlefield, land_pos, 230.0, Color(1.0, 0.35, 0.1, 0.45))  # v17j: 慢环层次
			VfxImpactFactory.spawn_layered_impact(_battlefield, land_pos, 3, false, -1, {"power_tier": 2})
			VfxImpactFactory.spawn_ground_burn(_battlefield, land_pos, 80.0, 0.25, VfxImpactFactory.PARTICLE_TEX_IMPACT_SCORCH)
			VfxImpactFactory.spawn_smoke_column(_battlefield, land_pos, Color(0.85, 0.30, 0.10, 0.7))
	)
	# 各玩家位置：小燃烧弹依次俯冲（节流：最多 9 个，适配三行布局）
	var spawned: int = 0
	for t in _get_player_units():
		if spawned >= 9:  # v9.3: 适配三行9格布局（原6）
			break
		if t == null or not is_instance_valid(t) or not (t is Node2D):
			continue
		var tpos: Vector2 = (t as Node2D).global_position
		var t_from: Vector2 = Vector2(tpos.x - 200.0, tpos.y - 300.0)
		var delay: float = 0.15 + float(spawned) * 0.1  # boss 落地后 0.15s 开始，每个间隔 0.1s
		var captured_tpos: Vector2 = tpos
		var captured_from: Vector2 = t_from
		var captured_delay: float = delay
		var tw_d := _battlefield.create_tween()
		tw_d.tween_interval(captured_delay)
		tw_d.tween_callback(func():
			# v20.15: 战斗在错峰窗口内结束 → 后续小燃烧弹不再发射
			if was_live and not _battle_active_now():
				return
			VfxImpactFactory.spawn_ultimate_projectile(_battlefield, captured_from, captured_tpos, bomb_tex, "dive", 46.0, bomb_tint, trail_color, 0.4,
				func(lp: Vector2):
					if _battlefield == null or not is_instance_valid(_battlefield):
						return
					if hell_tex != null:
						VfxImpactFactory.spawn_spell_burst(_battlefield, lp, hell_tex, Color(1.0, 0.35, 0.12), 200.0, 0.6)
					else:
						VfxImpactFactory.spawn_shockwave(_battlefield, lp, 85.0, Color(1.0, 0.4, 0.12, 0.9))
			)
		)
		spawned += 1
	# impact 信号延迟到 boss 燃烧弹落地后（0.5s）
	var tw_impact := _battlefield.create_tween()
	tw_impact.tween_interval(0.5)
	tw_impact.tween_callback(func():
		if was_live and not _battle_active_now():
			return  # v20.15: 战斗已结束——不再对结算画面打全屏定帧闪/震屏
		_emit_cinematic("enemy_spell_inferno", "impact", {})
		_trigger_screen_shake(8.0, 0.5)
	)
	return 0.5

## C. 连锁闪电：boss 起手蓝白能量爆发 + 全屏蓝紫微闪。
## 覆盖 tesla_chain(×5)/chain_lightning(×3)/thunderstorm/thunder/lightning_chain 11 个 boss 大招。
func _play_chain_cinematic(_effect: String, name_text: String) -> float:
	# v17f: 无飞行弹体，返回 0.3 预警窗口（boss 爆发→电弧跳出→伤害，预警标题可读）
	# v9.3b: 升级为带标题的全屏预警（原 quick_flash 太短促无标题，玩家不知道发生了什么）
	# v20.15: 快照战斗状态——延迟环/预电弧在战斗结束后作废
	var was_live: bool = _battle_active_now()
	_emit_cinematic("enemy_spell_chain", "warning", {"title": "%s·连锁闪电" % name_text})
	_flash_driver_on_cast(0.65)  # boss 本体施法闪光（蓝白调）
	var boss_pos: Vector2 = _get_driver_pos()
	# boss 起手蓝白能量爆发环（三层递进，强化"蓄力→释放"感）
	# v17i: 三层环改时序蓄力（0/0.15/0.3s 依次激活）——AI 批"同时静态平铺无蓄力节奏"
	for ring_i in range(3):
		var radii: Array = [70.0, 120.0, 180.0]
		var alphas: Array = [1.0, 0.8, 0.5]
		var captured_i: int = ring_i
		var tw_r := _battlefield.create_tween()
		tw_r.tween_interval(ring_i * 0.15)
		tw_r.tween_callback(func():
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
			if was_live and not _battle_active_now():
				return  # v20.15: 战斗已结束——蓄力环不再生成
			VfxImpactFactory.spawn_shockwave(_battlefield, boss_pos,
				radii[captured_i], Color(0.6 - 0.15 * captured_i, 0.85 - 0.15 * captured_i, 1.0, alphas[captured_i])))
	# v17i: boss→最近3目标预电弧（低 alpha 预告）——AI 批"闪电从天上落下方向叙事错位，
	# 应从 boss 射向玩家"。预电弧确立方向语义，正式电弧在 _exec_chain_lightning 逐跳
	var arc_n: int = 0
	for t in _get_player_units():
		if arc_n >= 3:
			break
		if t == null or not is_instance_valid(t) or not (t is Node2D):
			continue
		var tpos: Vector2 = (t as Node2D).global_position
		var tw_a := _battlefield.create_tween()
		tw_a.tween_interval(0.25 + arc_n * 0.08)
		tw_a.tween_callback(func():
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
			if was_live and not _battle_active_now():
				return  # v20.15: 战斗已结束——预电弧不再生成
			VfxImpactFactory.spawn_lightning_arc(_battlefield, boss_pos, tpos, Color(0.55, 0.75, 1.0, 0.55)))
		arc_n += 1
	# v9.3c: boss 位置专属闪电贴图爆炸（蓝白调）
	var chain_tex: Texture2D = _load_spell_texture("chain_lightning")
	if chain_tex != null:
		VfxImpactFactory.spawn_spell_burst(_battlefield, boss_pos, chain_tex, Color(0.5, 0.75, 1.0), 400.0, 0.7)
	_emit_cinematic("enemy_spell_chain", "impact", {})
	_trigger_screen_shake(7.0, 0.45)
	return 0.3

## D. 单体打击：神罚光矛从天垂直劈下 → 命中激光+穿甲光线 + 全屏红色锁定闪。
## v9.5: 加垂直下劈弹道（ult_divine_spear 从目标正上方落下），强化"神罚降临"的写实飞行过程。
##   原来的 boss→目标激光线保留作为"命中瞬间的能量贯穿"，与光矛弹道形成"下劈→贯穿"层次。
## 覆盖 god_weapon_single(×4)/devour_single(×4) 8 个 boss 大招。
func _play_single_target_cinematic(_effect: String, name_text: String) -> float:
	# v17f: 返回光矛飞行时长 0.4s（旧版伤害即时结算 → 先掉血光效后到）
	_emit_cinematic("enemy_spell_single", "warning", {"title": "%s·精准打击" % name_text})
	_flash_driver_on_cast(0.7)  # boss 本体施法闪光（红紫调）
	# 找 HP 最高目标（与 _exec_single_target 同款选法），预打激光
	var best: Node = null
	var best_hp: float = -1.0
	for t in _get_player_units():
		if t == null or not is_instance_valid(t):
			continue
		var t_hp: float = float(t.get("hp")) if "hp" in t else 0.0
		if t_hp > best_hp:
			best_hp = t_hp
			best = t
	if best == null or not (best is Node2D):
		return 0.0  # v17f: 无有效目标，演出未启动（伤害侧 0 延迟即时结算兜底）
	var boss_pos: Vector2 = _get_driver_pos()
	var tpos: Vector2 = (best as Node2D).global_position
	# 目标锁定双层环（预警，立即出现）
	# v17j: 锁定环加大（AI 批"预警太弱"）——80/120→110/160，boss 级锁定要有包裹感
	VfxImpactFactory.spawn_shockwave(_battlefield, tpos, 110.0, Color(1.0, 0.3, 0.7, 0.95))
	VfxImpactFactory.spawn_shockwave(_battlefield, tpos, 160.0, Color(0.9, 0.2, 0.6, 0.5))
	# v17i: 天空光点预告——锁定环正上方 450px 打一发金白能量闪（光矛来向预告），
	# AI 批"光矛在屏幕顶部与锁定环空间脱节，无法建立冲向目标的因果"
	VfxImpactFactory.spawn_shockwave(_battlefield, Vector2(tpos.x, tpos.y - 450.0), 50.0, Color(1.0, 0.9, 0.6, 0.9))
	# v9.5: 神罚光矛从目标正上方垂直劈下（0.4s 飞行），到达时触发激光+穿甲+震屏
	# v20.30: 弹体 80→115px——AI 基线（v20.29）批"光矛体积极小/规模感不足"（旧 80px
	# 比 96px boss 参考框还小，读不出"神罚"体量）。内容宽 317px，115px = 0.36 缩放。
	var spear_tex: Texture2D = _load_projectile_texture("ult_divine_spear")
	var spear_from: Vector2 = Vector2(tpos.x, tpos.y - 450.0)  # 正上方高空
	var captured_boss_pos: Vector2 = boss_pos
	var captured_tpos: Vector2 = tpos
	VfxImpactFactory.spawn_ultimate_projectile(_battlefield, spear_from, tpos, spear_tex, "vertical", 115.0, Color(1.0, 0.85, 0.5), Color(1.0, 0.85, 0.4, 0.95), 0.4,
		func(land_pos: Vector2):
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
			# 光矛落地：主激光（boss→命中点，红紫能量贯穿）+ 命中点穿甲光线（垂直下劈）
			# v17h 补层：SNIPER 级层次 + 焦痕（AI 批"仅单色线条，缺冲击波穿甲熔蚀碎片"）
			VfxImpactFactory.spawn_layered_impact(_battlefield, land_pos, 6, false, -1, {"power_tier": 2, "direction": Vector2.DOWN})
			VfxImpactFactory.spawn_ground_burn(_battlefield, land_pos, 60.0, 0.2, VfxImpactFactory.PARTICLE_TEX_IMPACT_SCORCH)
			VfxImpactFactory.spawn_laser_beam(_battlefield, captured_boss_pos, land_pos, Color(1.0, 0.3, 0.85, 1.0))
			# v17i: 穿甲方向改 Vector2.DOWN——与光矛垂直下落一致。AI 批"激光斜线贯穿 vs 光矛
			# 垂直下落的方向断裂，观众无法建立因果"。boss→目标激光保留（发射源语义），
			# 穿甲效果（命中后果）方向跟弹体走。
			VfxImpactFactory.spawn_pierce_beam(_battlefield, land_pos, Vector2.DOWN, Color(1.0, 0.3, 0.8, 1.0), true, 1.4)
			_emit_cinematic("enemy_spell_single", "impact", {})
			_trigger_screen_shake(8.0, 0.4)
	)
	return 0.4

## E. 召唤/传送：boss 基地紫色螺旋传送门 + 全屏紫雾微闪。
## 覆盖 mech_deploy(×2)/forge_summon(×2)/deploy_legion 5 个 boss 大招。
func _play_summon_cinematic(_effect: String, name_text: String) -> void:
	# v20.15: 快照战斗状态——传送门脉动/能量柱/威胁环等延迟链在战斗结束后作废
	# （威胁环持续 3.5s，是结算背景里最显眼的残留贴图之一）
	var was_live: bool = _battle_active_now()
	_emit_cinematic("enemy_spell_summon", "warning", {"title": "%s·召唤援军" % name_text})
	_flash_driver_on_cast(0.6, Color(0.7, 0.3, 1.0))  # boss 本体施法闪光（紫调）
	var boss_pos: Vector2 = _get_driver_pos()
	# v9.3c: 专属传送门贴图（紫绿调，叠加在程序化螺旋环上）
	var portal_tex: Texture2D = _load_spell_texture("summon_portal")
	if portal_tex != null:
		VfxImpactFactory.spawn_spell_burst(_battlefield, boss_pos, portal_tex, Color(0.7, 0.35, 1.0), 460.0, 1.0)  # v17i-R2: 380→460（AI 批画面占比过小）
	VfxImpactFactory.spawn_summon_portal(_battlefield, boss_pos, Color(0.7, 0.3, 1.0, 0.9), 0.9)
	# v17i-R2: portal 脉动——AI 批"portal 全程静止零反馈"。门展开后 3 次递进小爆闪
	#（0.2/0.45/0.7s，尺寸递增），能量不稳定感 + 持续视觉反馈
	for pulse_i in range(3):
		var captured_pi: int = pulse_i
		var tw_p := _battlefield.create_tween()
		tw_p.tween_interval(0.2 + pulse_i * 0.25)
		tw_p.tween_callback(func():
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
			if was_live and not _battle_active_now():
				return  # v20.15: 战斗已结束——门脉动环不再生成
			VfxImpactFactory.spawn_shockwave(_battlefield, boss_pos,
				60.0 + captured_pi * 30.0, Color(0.75, 0.4, 1.0, 0.7 - captured_pi * 0.15)))
	# v17i: 叙事补全——AI 批"传送门后三阶段严重脱节，无内容无威胁"。
	# ① 门上方紫色能量柱（召唤能量注入的证据）② 我方头顶红色警报（援军=威胁提升）
	var tw_e := _battlefield.create_tween()
	tw_e.tween_interval(0.35)
	tw_e.tween_callback(func():
		if _battlefield == null or not is_instance_valid(_battlefield):
			return
		if was_live and not _battle_active_now():
			return  # v20.15: 战斗已结束——能量柱/爆闪不再生成
		VfxImpactFactory.spawn_laser_beam(_battlefield, boss_pos,
			boss_pos + Vector2(0, -220.0), Color(0.75, 0.4, 1.0, 0.95))
		# v17j: 门内能量团爆闪（AI 批"portal 静止零反馈"——脉动 + 能量上升的中间证据）
		VfxImpactFactory.spawn_shockwave(_battlefield, boss_pos + Vector2(0, -30.0), 46.0, Color(0.85, 0.55, 1.0, 0.85)))
	var warn_n: int = 0
	for t in _get_player_units():
		if warn_n >= 3:
			break
		if t == null or not is_instance_valid(t) or not (t is Node2D):
			continue
		var tpos: Vector2 = (t as Node2D).global_position
		var tw_w := _battlefield.create_tween()
		tw_w.tween_interval(0.5)
		tw_w.tween_callback(func():
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
			if was_live and not _battle_active_now():
				return  # v20.15: 战斗已结束——持续威胁环（3.5s）不再生成
			# v17j: 警报换持续威胁环（4s 红环脉动）——AI 批单次 shockwave"读作命中框"，
			# 持续环 + 脉动 = "威胁标记挂身"语义（复用 v14 darkness 的 lingering 范式）
			VfxImpactFactory.spawn_lingering_debuff_ring(_battlefield, tpos, Color(1.0, 0.3, 0.2), 3.5))
		warn_n += 1

## F. debuff：全屏对应色调暗化 + 目标头顶紫色减益标记。
## 覆盖 darkness_debuff/emp_pulse/emp_debuff/weakness_debuff 7 个 boss 大招。
func _play_debuff_cinematic(effect: String, name_text: String) -> void:
	var debuff_kind: String = "weakness"
	var title_suffix: String = "虚弱"
	if effect.find("dark") >= 0:
		debuff_kind = "darkness"
		title_suffix = "黑暗降临"
	elif effect.find("emp") >= 0:
		debuff_kind = "emp"
		title_suffix = "电磁干扰"
	# v9.3b: 升级为带标题全屏预警 + boss 本体施法闪光
	_emit_cinematic("enemy_spell_debuff", "warning", {"debuff_kind": debuff_kind, "title": "%s·%s" % [name_text, title_suffix]})
	_flash_driver_on_cast(0.55)  # boss 本体施法闪光（按 debuff 类别调色）
	# v9.3c: darkness 类 debuff 叠加专属黑暗笼罩贴图（boss 位置）
	if debuff_kind == "darkness":
		var dark_tex: Texture2D = _load_spell_texture("debuff_dark")
		if dark_tex != null:
			VfxImpactFactory.spawn_spell_burst(_battlefield, _get_driver_pos(), dark_tex, Color(0.4, 0.15, 0.6), 380.0, 1.2)
			# v14: 读图 6/10"读作一次性爆炸"——叠加 4s 持续暗蚀环,"削弱挂身"语义成立
			VfxImpactFactory.spawn_lingering_debuff_ring(_battlefield, _get_driver_pos(), Color(0.45, 0.18, 0.65), 4.0)

## G. 护盾：boss 本体蓝白施法闪光 + boss 位置蓝白大环 + 全屏蓝色预警标题。
## v9.6(P3-b): 此前护盾类大招无全屏预警、无施法闪光（仅执行侧 _exec_shield_self
## 一个 100px 小环），与其他 5 类大招表现力断层——补齐对齐（护盾无伤害延迟，纯视觉预警）。
## 覆盖 energy_shield(001)/dome_barrier(011)/plate_shield(014)/ward_bulwark(016/026) 5 处大招。
func _play_shield_cinematic(effect: String, name_text: String) -> void:
	var title: String = "能量护盾"
	if effect.find("dome") >= 0:
		title = "穹顶屏障"
	elif effect.find("plate") >= 0:
		title = "钢板护盾"
	elif effect.find("ward") >= 0 or effect.find("bulwark") >= 0:
		title = "壁垒守护"
	_emit_cinematic("enemy_spell_shield", "warning", {"title": "%s·%s" % [name_text, title]})
	_flash_driver_on_cast(0.55, Color(0.45, 0.7, 1.0))  # boss 本体施法闪光（蓝白调）
	var boss_pos: Vector2 = _get_driver_pos()
	if _battlefield != null and is_instance_valid(_battlefield):
		# 蓝白大环（150px，与执行侧 100px 护盾环层次互补）
		VfxImpactFactory.spawn_shockwave(_battlefield, boss_pos, 150.0, Color(0.4, 0.65, 1.0, 0.55))

# ── 演出辅助 ──

## v17i: 目标脚下红色脉动预警圈——AI 高频批评"预警帧等于空白/无威胁提示"的根治。
## 对即将被 AOE 波及的玩家单位提前 0.6s 打出红色脉冲标记（3 次递进扩散），
## 建立"即将被标记"的压迫预期（Metal Slug 式 boss 攻击预警）。
func _spawn_target_warning_marks(max_marks: int = 9) -> void:
	if _battlefield == null or not is_instance_valid(_battlefield):
		return
	var spawned: int = 0
	for t in _get_player_units():
		if spawned >= max_marks:
			break
		if t == null or not is_instance_valid(t) or not (t is Node2D):
			continue
		var tpos: Vector2 = (t as Node2D).global_position
		# 3 次递进脉冲（0/0.2/0.4s 错开，半径 26→34→42 递增——倒计时加速感）
		for pulse in range(3):
			var captured_tpos: Vector2 = tpos
			var r: float = 26.0 + pulse * 8.0
			var alpha: float = 0.45 + pulse * 0.18
			var delay: float = pulse * 0.2
			var tw := _battlefield.create_tween()
			tw.tween_interval(delay)
			tw.tween_callback(func():
				if _battlefield == null or not is_instance_valid(_battlefield):
					return
				VfxImpactFactory.spawn_shockwave(_battlefield, captured_tpos, r,
					Color(1.0, 0.25, 0.2, alpha)))
		spawned += 1

## v9.3b: boss 放大招时本体施法闪光（让玩家感知"是 boss 在放技能"）。
## 调 driver 的 _flash_body_on_buff（加 intensity 参数控制峰值亮度）。
## intensity: 闪光峰值 0-1（默认 0.65，大招级；被动 buff 原 0.3）。
## tint: 可选闪光色调（默认白色=纯变亮；传橙/紫等让闪光带技能配色）。
func _flash_driver_on_cast(intensity: float = 0.65, tint: Color = Color.WHITE) -> void:
	if _driver == null or not is_instance_valid(_driver):
		return
	if _driver.has_method("_flash_body_on_buff"):
		_driver._flash_body_on_buff(intensity, tint)

## emit 全屏演出信号（委托 BattleSpectacle）。每次大招只调用一次。
func _emit_cinematic(ability_id: String, stage: String, params: Dictionary) -> void:
	if Engine.get_main_loop() != null:
		SignalBus.phase_instrument_ability_triggered.emit(ability_id, stage, params)

## 懒加载核爆贴图（缓存，缺失返回 null）。
func _load_nuke_texture(name_id: String) -> Texture2D:
	if _nuke_texture_cache.has(name_id):
		return _nuke_texture_cache[name_id]
	var path := "res://assets/effects/nuclear/" + name_id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_nuke_texture_cache[name_id] = tex  # null 也缓存（缺失贴图不重复 load）
	return tex

## v9.3c: 懒加载大招专属贴图（assets/effects/spell_burst/，AI 生成 + 抠图）。
## 缺失返回 null（调用方有 null 守卫，缺失时回退纯程序化 VFX，向后兼容）。
func _load_spell_texture(name_id: String) -> Texture2D:
	if _spell_texture_cache.has(name_id):
		return _spell_texture_cache[name_id]
	var path := "res://assets/effects/spell_burst/" + name_id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_spell_texture_cache[name_id] = tex
	return tex

## v9.5: 懒加载大招飞行弹体贴图（assets/effects/ultimate_projectiles/，AI 生成 + 抠图）。
## 缺失返回 null（spawn_ultimate_projectile 有 null 守卫，回退激光线段，向后兼容）。
func _load_projectile_texture(name_id: String) -> Texture2D:
	if _projectile_texture_cache.has(name_id):
		return _projectile_texture_cache[name_id]
	var path := "res://assets/effects/ultimate_projectiles/" + name_id + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_projectile_texture_cache[name_id] = tex
	return tex

# ─────────────────────────────────────────────
#  通用执行函数
# ─────────────────────────────────────────────

## AOE 伤害：对所有玩家单位造成 boss atk 派生伤害（标记+延迟+tween 爆炸，仿 nuclear_bombardment）
## v17f: delay 与演出主弹体 flight_time 对齐（默认 0.4 保持死亡爆炸路径旧行为）——
## 旧版固定 0.4s vs 天降毁灭主弹体 0.55s 飞行，单位先掉血陨石才落地。
func _exec_aoe_damage(dmg_mult: float, name_text: String, delay: float = 0.4) -> void:
	var targets: Array = _get_player_units()
	if targets.is_empty():
		return
	var base_dmg: float = _compute_boss_damage() * dmg_mult
	# v8.6: 二次 clamp 防 AOE 清场（_compute_boss_damage 已 clamp[80,500]，但 ×dmg_mult 后 modern+ 偏高）
	base_dmg = clampf(base_dmg, 50.0, 800.0)
	var boss_pos: Vector2 = _get_driver_pos()
	# toast 预警
	_show_toast("⚠ %s！我方全体即将受到 %.0f 伤害" % [name_text, base_dmg])
	# v20.15: 快照战斗状态——延迟爆炸窗口内战斗结束则作废（防结算后贴图残留+补刀已结算单位）
	var was_live: bool = _battle_active_now()
	# 对每个目标：标记 + 延迟爆炸 + 伤害结算
	for e in targets:
		if e == null or not is_instance_valid(e) or not (e is Node2D):
			continue
		var epos: Vector2 = (e as Node2D).global_position
		# 标记（红圈预警）
		VfxImpactFactory.spawn_shockwave(_battlefield, epos, 50.0, Color(1.0, 0.3, 0.3, 0.6))
		# 延迟爆炸 + 伤害（tween，仿 nuclear_bombardment）
		var captured_enemy = e
		var captured_pos = epos
		var tw := _battlefield.create_tween()
		tw.tween_interval(maxf(delay, 0.1))  # v17f: 对齐演出（下限 0.1 防零延迟直接结算）
		tw.tween_callback(func():
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
			if was_live and not _battle_active_now():
				return  # v20.15: 战斗已结束——落地爆炸与伤害全部作废
			var cur_pos: Vector2 = captured_pos
			if is_instance_valid(captured_enemy) and captured_enemy is Node2D:
				cur_pos = (captured_enemy as Node2D).global_position
			VfxImpactFactory.spawn_shockwave(_battlefield, cur_pos, 80.0, Color(1.0, 0.5, 0.2, 0.9))
			if is_instance_valid(captured_enemy):
				if captured_enemy.has_method("take_damage"):
					captured_enemy.take_damage(base_dmg, _driver)
		)
	# 全屏震动
	_trigger_screen_shake(6.0, 0.4)

## 连锁闪电：对最多 5 个玩家单位跳闪电（每跳衰减 80%），VFX 用 lightning_arc
## v17f: delay 预警窗口（默认 0.3）——电弧 VFX 立即铺开给玩家看，伤害延迟结算，
## 预警标题至少可见一瞬（旧版演出与伤害同帧，预警形同虚设）。
func _exec_chain_lightning(dmg_mult: float, name_text: String, delay: float = 0.3) -> void:
	var targets: Array = _get_player_units()
	if targets.is_empty():
		return
	var base_dmg: float = _compute_boss_damage() * 0.6 * dmg_mult  # 连锁单发伤害较低
	# 取距离 boss 最近的 5 个
	var boss_pos: Vector2 = _get_driver_pos()
	# v20.15: 快照战斗状态——延迟结算窗口内战斗结束则作废
	var was_live: bool = _battle_active_now()
	targets.sort_custom(func(a, b):
		var da: float = boss_pos.distance_to((a as Node2D).global_position) if a is Node2D else 9999.0
		var db: float = boss_pos.distance_to((b as Node2D).global_position) if b is Node2D else 9999.0
		return da < db
	)
	var max_jumps: int = min(5, targets.size())
	var prev_pos: Vector2 = boss_pos
	var dmg: float = base_dmg
	for i in range(max_jumps):
		var t = targets[i]
		if t == null or not is_instance_valid(t) or not (t is Node2D):
			continue
		var tpos: Vector2 = (t as Node2D).global_position
		# 闪电弧 VFX（蓝白色，立即——玩家先看到电弧铺开）
		VfxImpactFactory.spawn_lightning_arc(_battlefield, prev_pos, tpos, Color(0.6, 0.8, 1.0, 1.0))
		# v17i-R2: 分叉电弧——每跳主电弧外再放 1 条短分叉（目标附近随机偏移），
		# 传达"链式电网"而非"单道闪电"（AI 批"连锁感缺失"）
		var fork_end: Vector2 = tpos + Vector2(randf_range(-90.0, 90.0), randf_range(-70.0, 50.0))
		VfxImpactFactory.spawn_lightning_arc(_battlefield, tpos, fork_end, Color(0.5, 0.75, 1.0, 0.7))
		# 伤害（v17f 延迟 delay 秒，与预警窗口对齐；VFX 已铺开所以跳序仍可读）
		var captured_t = t
		var captured_dmg = dmg
		var tw_h := _battlefield.create_tween()
		tw_h.tween_interval(maxf(delay, 0.05))
		tw_h.tween_callback(func():
			if was_live and not _battle_active_now():
				return  # v20.15: 战斗已结束——延迟电伤不再结算
			if is_instance_valid(captured_t) and captured_t.has_method("take_damage"):
				captured_t.take_damage(captured_dmg, _driver)
		)
		prev_pos = tpos
		dmg *= 0.8  # 每跳衰减
	_show_toast("⚡ %s！连锁闪电跳跃 %d 次" % [name_text, max_jumps])

## 召唤：立即补满产兵到 unit_limit（格子战简化——不真正 spawn 新单位类型，
## 而是触发 driver 的产兵流程补满场上单位）
func _exec_summon(_params: Dictionary, name_text: String) -> void:
	if _driver == null or not is_instance_valid(_driver):
		return
	# 触发 driver 的紧急产兵（如果有该方法）；格子战敌方槽位有限，补满即止
	if _driver.has_method("force_produce_once"):
		_driver.force_produce_once()
	_show_toast("⚔ %s！敌方召唤援军" % name_text)

## debuff：对所有玩家单位挂减益 meta（攻速/暴击/闪避降低，持续数秒）
func _exec_debuff_players(params: Dictionary, name_text: String) -> void:
	var targets: Array = _get_player_units()
	if targets.is_empty():
		return
	# debuff 强度（默认攻速-30%/暴击-20%/闪避-15%），可被 params 覆盖
	var atk_penalty: float = float(params.get("attack_speed_penalty", 0.30))
	var crit_penalty: float = float(params.get("crit_penalty", 0.20))
	var dodge_penalty: float = float(params.get("dodge_penalty", 0.15))
	var duration: float = float(params.get("duration", 5.0))
	# v10(C4) 统一：时间戳秒制
	var expire_sec: float = Time.get_ticks_msec() / 1000.0 + duration
	for t in targets:
		if t == null or not is_instance_valid(t):
			continue
		# 复用 ECM 减益 meta 名（construct_unit/attack 路径已读 _ecm_*_penalty）
		t.set_meta("_ecm_debuffed_until", expire_sec)
		t.set_meta("_ecm_attack_speed_penalty", atk_penalty)
		t.set_meta("_ecm_crit_penalty", crit_penalty)
		t.set_meta("_ecm_dodge_penalty", dodge_penalty)
	_show_toast("✦ %s！我方全体被削弱 %ds" % [name_text, int(duration)])

## shield：给 boss 自身加护盾（吸收量基于 boss max_hp 百分比）
func _exec_shield_self(params: Dictionary, name_text: String) -> void:
	if _driver == null or not is_instance_valid(_driver):
		return
	# 护盾量：boss max_hp × pct（默认 20%），可被 params.shield_pct 覆盖
	var shield_pct: float = float(params.get("shield_pct", params.get("bonus", 0.20)))
	var boss_max_hp: float = float(_driver.get("max_hp")) if "max_hp" in _driver else 1000.0
	var shield_amount: float = boss_max_hp * shield_pct
	# v8.6: 护盾上限 boss max_hp 的 60%（防多次施法堆叠到数万近似无敌）
	shield_amount = minf(shield_amount, boss_max_hp * 0.60)
	if _driver.has_method("add_boss_shield"):
		_driver.add_boss_shield(shield_amount)
	# VFX：boss 位置蓝色护盾环
	var boss_pos: Vector2 = _get_driver_pos()
	if _battlefield != null and is_instance_valid(_battlefield):
		VfxImpactFactory.spawn_shockwave(_battlefield, boss_pos, 100.0, Color(0.3, 0.6, 1.0, 0.7))
	_show_toast("🛡 %s！boss 获得 %.0f 护盾" % [name_text, shield_amount])

## 单体高伤：对最高威胁（最高 HP）玩家单位造成大伤害
## v17f: delay 与光矛 flight_time（0.4s）对齐——旧版伤害即时结算，
## 玩家先看到掉血、0.4s 后光效才劈下来，"果先于因"最严重的一处。
func _exec_single_target(dmg_mult: float, name_text: String, delay: float = 0.4) -> void:
	var targets: Array = _get_player_units()
	if targets.is_empty():
		return
	# 选 HP 最高的玩家单位（最高威胁）
	var best: Node = null
	var best_hp: float = -1.0
	for t in targets:
		if t == null or not is_instance_valid(t):
			continue
		var t_hp: float = float(t.get("hp")) if "hp" in t else 0.0
		if t_hp > best_hp:
			best_hp = t_hp
			best = t
	if best == null:
		return
	var base_dmg: float = _compute_boss_damage() * 3.0 * dmg_mult  # 单体伤害 ×3（聚焦打击）
	# v8.6: 二次 clamp 防单体秒杀（×3×dmg_mult 后 Future boss 可达 2832，过强）
	base_dmg = clampf(base_dmg, 80.0, 1500.0)
	var tpos: Vector2 = (best as Node2D).global_position if best is Node2D else _get_driver_pos()
	# VFX：红色锁定 + 命中冲击波
	if _battlefield != null and is_instance_valid(_battlefield):
		VfxImpactFactory.spawn_shockwave(_battlefield, tpos, 60.0, Color(1.0, 0.3, 0.3, 0.9))
		VfxImpactFactory.spawn_laser_beam(_battlefield, _get_driver_pos(), tpos, Color(1.0, 0.5, 0.3, 1.0))
	# v17f: 延迟结算与光矛落地同帧（锁定环/激光预览立即，伤害随光效到达）
	# v20.15: 快照战斗状态——延迟窗口内战斗结束则作废（防对已结算单位补刀）
	var was_live: bool = _battle_active_now()
	var captured_best = best
	var captured_base_dmg = base_dmg
	var tw_d := _battlefield.create_tween()
	tw_d.tween_interval(maxf(delay, 0.05))
	tw_d.tween_callback(func():
		if was_live and not _battle_active_now():
			return  # v20.15: 战斗已结束——延迟单体伤害不再结算
		if is_instance_valid(captured_best) and captured_best.has_method("take_damage"):
			captured_best.take_damage(captured_base_dmg, _driver)
	)
	_show_toast("🎯 %s！对我方高威胁单位造成 %.0f 伤害" % [name_text, base_dmg])

# ─────────────────────────────────────────────
#  辅助
# ─────────────────────────────────────────────

## boss 伤害派生：基于 stats.attack_power，保底 50，上限避免秒杀
func _compute_boss_damage() -> float:
	if _driver == null or not is_instance_valid(_driver):
		return 50.0
	# v8.5: 优先用 driver 暴露的 get_master_stats()（_master_stats 私有，无 public stats 属性）。
	# 旧代码 _driver.get("stats") 恒 null → 永远走 fallback，attack_power 从不生效。
	var stats: Dictionary = {}
	if _driver.has_method("get_master_stats"):
		stats = _driver.get_master_stats()
	var atk: float = float(stats.get("attack_power", 0.0)) if not stats.is_empty() else 0.0
	if atk <= 0.0:
		# fallback：无 attack_power 时用 max_hp×0.05（boss 越强伤害越高）
		var hp: float = float(stats.get("max_hp", 0.0))
		if hp <= 0.0 and "max_hp" in _driver:
			hp = float(_driver.get("max_hp"))
		if hp <= 0.0:
			hp = 1000.0
		return clampf(hp * 0.05, 50.0, 300.0)
	# boss atk 普遍 120-1000，技能伤害 = atk × 1.5（AOE 威胁感，但单次不致死）
	return clampf(atk * 1.5, 80.0, 500.0)

## 获取玩家单位列表（boss 的目标）
func _get_player_units() -> Array:
	var tree := _driver.get_tree() if _driver != null else null
	if tree == null:
		return []
	return tree.get_nodes_in_group("player_units")

## v20.15: 真实战斗存活查询（延迟链守卫用，快照式判定）。
## effect_lab / boss_spell_audit 工具场无战斗（battle_active 恒 false）——
## 守卫判定必须"触发时在战斗中 && 回调时已结束"才拦截，工具场永不被拦。
func _battle_active_now() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var bm: Node = tree.root.get_node_or_null("BattleManager")
	return bm != null and bool(bm.get("battle_active"))

## 获取 boss 全局位置
func _get_driver_pos() -> Vector2:
	if _driver == null or not is_instance_valid(_driver) or not (_driver is Node2D):
		return Vector2.ZERO
	return (_driver as Node2D).global_position

## 屏幕震动（复用 ScreenShake）
func _trigger_screen_shake(intensity: float, duration: float) -> void:
	var tree := _driver.get_tree() if _driver != null else null
	if tree == null or tree.root == null:
		return
	var shake_node = tree.root.get_node_or_null("/root/ScreenShake")
	if shake_node != null and shake_node.has_method("shake"):
		shake_node.shake(intensity, duration)

## toast 提示
func _show_toast(msg: String) -> void:
	if SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit(msg)

## v9.1: 被动 buff 应用时触发 driver 基地闪光（视觉反馈，让玩家感知"boss 有被动加成"）
func _flash_driver_on_buff() -> void:
	if _driver == null or not is_instance_valid(_driver):
		return
	if not _driver.has_method("_flash_body_on_buff"):
		return
	_driver._flash_body_on_buff()
