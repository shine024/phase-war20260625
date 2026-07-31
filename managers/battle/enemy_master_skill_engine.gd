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
				_timers[sid] = float(spell.get("cooldown", 20.0))  # 首次等满 CD
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
		if _is_aura_effect(effect):
			_tick_aura_damage(params, effect, tick_dt)

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
			var t_max_hp: float = float(t.get("max_hp")) if "max_hp" in t else 100.0
			dmg = t_max_hp * pct * tick_dt
		else:
			# 固定伤害：params.damage 是每秒值
			var dps: float = float(params.get("damage", 30.0))
			dmg = dps * tick_dt
		if dmg > 0.0 and t.has_method("take_damage"):
			t.take_damage(dmg, _driver)

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
func _trigger_spell(spell: Dictionary) -> void:
	var effect: String = String(spell.get("effect", "")).to_lower()
	var params: Dictionary = spell.get("params", {}) if spell is Dictionary else {}
	var name_text: String = String(spell.get("name", effect))
	# 伤害倍率（默认 1.0，可被 params.damage_mult 覆盖）
	var dmg_mult: float = float(params.get("damage_mult", 1.0))
	# 按关键字聚类（顺序敏感：先匹配更具体的）
	if _is_aoe_effect(effect):
		_exec_aoe_damage(dmg_mult, name_text)
	elif _is_chain_effect(effect):
		_exec_chain_lightning(dmg_mult, name_text)
	elif _is_summon_effect(effect):
		_exec_summon(params, name_text)
	elif _is_debuff_effect(effect):
		_exec_debuff_players(params, name_text)
	elif _is_shield_effect(effect):
		_exec_shield_self(params, name_text)
	elif _is_single_target_effect(effect):
		_exec_single_target(dmg_mult, name_text)
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
#  通用执行函数
# ─────────────────────────────────────────────

## AOE 伤害：对所有玩家单位造成 boss atk 派生伤害（标记+延迟+tween 爆炸，仿 nuclear_bombardment）
func _exec_aoe_damage(dmg_mult: float, name_text: String) -> void:
	var targets: Array = _get_player_units()
	if targets.is_empty():
		return
	var base_dmg: float = _compute_boss_damage() * dmg_mult
	var boss_pos: Vector2 = _get_driver_pos()
	# toast 预警
	_show_toast("⚠ %s！我方全体即将受到 %.0f 伤害" % [name_text, base_dmg])
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
		tw.tween_interval(0.4)
		tw.tween_callback(func():
			if _battlefield == null or not is_instance_valid(_battlefield):
				return
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
func _exec_chain_lightning(dmg_mult: float, name_text: String) -> void:
	var targets: Array = _get_player_units()
	if targets.is_empty():
		return
	var base_dmg: float = _compute_boss_damage() * 0.6 * dmg_mult  # 连锁单发伤害较低
	# 取距离 boss 最近的 5 个
	var boss_pos: Vector2 = _get_driver_pos()
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
		# 闪电弧 VFX（蓝白色）
		VfxImpactFactory.spawn_lightning_arc(_battlefield, prev_pos, tpos, Color(0.6, 0.8, 1.0, 1.0))
		# 伤害
		if t.has_method("take_damage"):
			t.take_damage(dmg, _driver)
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
	var now_msec: int = Time.get_ticks_msec()
	var expire_msec: int = now_msec + int(duration * 1000)
	for t in targets:
		if t == null or not is_instance_valid(t):
			continue
		# 复用 ECM 减益 meta 名（construct_unit/attack 路径已读 _ecm_*_penalty）
		t.set_meta("_ecm_debuffed_until", expire_msec)
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
	if _driver.has_method("add_boss_shield"):
		_driver.add_boss_shield(shield_amount)
	# VFX：boss 位置蓝色护盾环
	var boss_pos: Vector2 = _get_driver_pos()
	if _battlefield != null and is_instance_valid(_battlefield):
		VfxImpactFactory.spawn_shockwave(_battlefield, boss_pos, 100.0, Color(0.3, 0.6, 1.0, 0.7))
	_show_toast("🛡 %s！boss 获得 %.0f 护盾" % [name_text, shield_amount])

## 单体高伤：对最高威胁（最高 HP）玩家单位造成大伤害
func _exec_single_target(dmg_mult: float, name_text: String) -> void:
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
	var tpos: Vector2 = (best as Node2D).global_position if best is Node2D else _get_driver_pos()
	# VFX：红色锁定 + 命中冲击波
	if _battlefield != null and is_instance_valid(_battlefield):
		VfxImpactFactory.spawn_shockwave(_battlefield, tpos, 60.0, Color(1.0, 0.3, 0.3, 0.9))
		VfxImpactFactory.spawn_laser_beam(_battlefield, _get_driver_pos(), tpos, Color(1.0, 0.5, 0.3, 1.0))
	if best.has_method("take_damage"):
		best.take_damage(base_dmg, _driver)
	_show_toast("🎯 %s！对我方高威胁单位造成 %.0f 伤害" % [name_text, base_dmg])

# ─────────────────────────────────────────────
#  辅助
# ─────────────────────────────────────────────

## boss 伤害派生：基于 stats.attack_power，保底 50，上限避免秒杀
func _compute_boss_damage() -> float:
	if _driver == null or not is_instance_valid(_driver):
		return 50.0
	var stats = _driver.get("stats") if "stats" in _driver else null
	if stats == null:
		# driver 自身的 max_hp 作为 fallback（boss 越强伤害越高）
		var hp: float = float(_driver.get("max_hp")) if "max_hp" in _driver else 1000.0
		return clampf(hp * 0.05, 50.0, 300.0)
	var atk: float = float(stats.attack_power) if "attack_power" in stats else 100.0
	# boss atk 普遍 120-1000，技能伤害 = atk × 1.5（AOE 威胁感，但单次不致死）
	return clampf(atk * 1.5, 80.0, 500.0)

## 获取玩家单位列表（boss 的目标）
func _get_player_units() -> Array:
	var tree := _driver.get_tree() if _driver != null else null
	if tree == null:
		return []
	return tree.get_nodes_in_group("player_units")

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
