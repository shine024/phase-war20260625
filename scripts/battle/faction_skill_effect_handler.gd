extends RefCounted
class_name FactionSkillEffectHandler

## v8.6: 势力技能 special 类效果战斗端处理引擎
##
## 背景：faction_skill_manager.get_active_effects() 把 effect_type=="special" 的技能
## 收集进 merged["special"] 数组，但战斗端此前零消费——解锁后无战斗效果。
## 本 handler 集中收口全部 17 种 special 子键的战斗实现。
##
## 设计范式：仿 RuneSpecialHandler / ModuleEffectHandler——独立静态类 + 节点 meta 传递配置。
## 配置在 construct_unit.setup() 时一次性 snapshot 存到节点 meta "faction_skill_effects"
## （含 stat_bonus + special 数组），避免每帧反射查 FactionSystemManager。
##
## 接入点分布：
##   - 生成期（spawn_system._build_stats_cached）：armor_penetration / conditional.stat 部分 / stacking / variety
##   - 事件驱动（construct_unit/bullet）：on_hit / on_kill / on_death / death_save / on_crit
##   - 周期 tick（construct_unit._physics_process）：periodic_shield / periodic_heal / periodic_invuln
##
## 注意：所有特殊效果仅对 is_player==true 的单位生效（势力技能是玩家养成系统，敌方不享有）。

const GC = preload("res://resources/game_constants.gd")


# ══════════════════════════════════════════════════════════════════
#  生成期：spawn_system._build_stats_cached 调用（setup 时一次性应用）
# ══════════════════════════════════════════════════════════════════

## 生成期总入口：处理可在 stats 构建时确定的部分。
## 由 battle_spawn_system._build_stats_cached 在 stat_bonus 注入后调用。
## 同时把需要运行时判定的 special 配置快照存到 stats meta，供后续事件/tick handler 读取。
static func apply_setup_effects(stats, special_list: Array) -> void:
	if stats == null or special_list.is_empty():
		return
	var runtime_specials: Array = []  # 需要运行时判定的，存 meta 留给事件/tick handler
	for fx in special_list:
		if not (fx is Dictionary):
			continue
		# armor_penetration：直接并入 stat（无运行时判定，对全目标生效）
		if fx.has("armor_penetration"):
			var pen: float = float(fx["armor_penetration"])
			if pen > 0.0:
				stats.armor_penetration = maxf(0.0, float(stats.armor_penetration) + pen)
			continue
		# conditional：hp_below 类预注入 def 加成（永久，牺牲"低血才触发"换数值口径正确，
		#   原 take_damage 硬编码 0.15 与数据 def+25% 脱钩）。
		#   on_crit_received 类预注入 dodge（永久，因 take_damage 无法得知是否暴击，条件触发难接入）。
		#   其它 conditional（atk_speed_above/deploy_speed_above/target_hp_below）留运行时事件判定。
		if fx.has("conditional"):
			var cfg: Dictionary = fx["conditional"]
			if cfg.has("hp_below") and cfg.has("stat_bonus"):
				_apply_stat_bonus_scaled(stats, cfg["stat_bonus"], 1.0)
				continue
			if cfg.get("on_crit_received", false) and cfg.has("dodge_chance"):
				stats.dodge_chance = minf(0.75, float(stats.dodge_chance) + float(cfg["dodge_chance"]))
				continue
			# 其它 conditional 留 runtime（atk_speed_above/deploy_speed_above/target_hp_below）
			runtime_specials.append(fx)
			continue
		# stacking_bonus / variety_bonus：依赖实时场上单位数，不进 stats 缓存（缓存会冻结首次计数）。
		# 改为运行时在 construct_unit.setup 后由 apply_runtime_stacking 即时应用（见下方）。
		# 这里只存进 runtime_specials，不预注入。
		if fx.has("stacking_bonus") or fx.has("variety_bonus"):
			runtime_specials.append(fx)
			continue
		# aura：v8.6 setup 时把 stat_bonus 预注入自身（简化：原设计是给范围友军，但广播实现复杂。
		#   至少技能不再空转——载体自身获得光环 stat 加成）。hp_regen_pct 走 runtime tick。
		if fx.has("aura"):
			var aura_cfg: Dictionary = fx["aura"]
			if aura_cfg.has("stat_bonus"):
				_apply_stat_bonus_scaled(stats, aura_cfg["stat_bonus"], 1.0)
			# hp_regen_pct 类留 runtime（需 tick 持续回血）
			if aura_cfg.has("hp_regen_pct"):
				runtime_specials.append(fx)
			continue
		# 其余全部留运行时（事件/tick）
		runtime_specials.append(fx)
	# 把运行时 special 快照存到 stats meta（供事件/tick handler 读取，仿 rune_specials 范式）
	if not runtime_specials.is_empty():
		stats.set_meta("faction_runtime_specials", runtime_specials)


## v8.6 运行时叠加：部署后即时应用 stacking_bonus / variety_bonus（不进 stats 缓存）。
## 由 construct_unit.setup 在加入 group 后调用，此时能拿到实时场上单位数。
## 注意：此方法直接改 unit.stats（每单位独立），不会冻结。已部署的旧单位不会回溯更新
## （设计权衡：避免每次部署都遍历刷新全场单位的性能开销）。
static func apply_runtime_stacking(unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not bool(unit.get("is_player")):
		return
	var stats = unit.get("stats") if "stats" in unit else null
	if stats == null:
		return
	var specials: Array = stats.get_meta("faction_runtime_specials", [])
	if specials.is_empty():
		return
	for fx in specials:
		if not (fx is Dictionary):
			continue
		if fx.has("stacking_bonus"):
			_apply_stacking_to_unit(stats, fx["stacking_bonus"])
		elif fx.has("variety_bonus"):
			_apply_variety_to_unit(stats, fx["variety_bonus"])


## stacking_bonus 运行时应用：按当前场上同阵营单位数算 stacks
static func _apply_stacking_to_unit(stats, cfg) -> void:
	if not (cfg is Dictionary):
		return
	var per_unit: int = int(cfg.get("per_unit", 1))
	var max_stacks: int = int(cfg.get("max", 5))
	var sb: Dictionary = cfg.get("stat_bonus", {})
	if per_unit <= 0 or max_stacks <= 0 or sb.is_empty():
		return
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or not (tree.root is Node):
		return
	var count: int = (tree.root as Node).get_nodes_in_group("player_units").size()
	var stacks: int = clampi(count / per_unit, 0, max_stacks)
	if stacks <= 0:
		return
	_apply_stat_bonus_scaled(stats, sb, float(stacks))


## variety_bonus 运行时应用：按场上不同 combat_kind 数算 stacks
static func _apply_variety_to_unit(stats, cfg) -> void:
	if not (cfg is Dictionary):
		return
	var per_type: int = int(cfg.get("per_type", 1))
	var max_stacks: int = int(cfg.get("max", 5))
	var sb: Dictionary = cfg.get("stat_bonus", {})
	if per_type <= 0 or max_stacks <= 0 or sb.is_empty():
		return
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or not (tree.root is Node):
		return
	var kinds_seen: Dictionary = {}
	for u in (tree.root as Node).get_nodes_in_group("player_units"):
		if u == null or not is_instance_valid(u):
			continue
		var ck: int = int(u.get("combat_kind")) if "combat_kind" in u else -1
		if ck >= 0:
			kinds_seen[ck] = true
	var stacks: int = clampi(kinds_seen.size() / per_type, 0, max_stacks)
	if stacks <= 0:
		return
	_apply_stat_bonus_scaled(stats, sb, float(stacks))


## 把 stat_bonus 字典按 scale 倍率注入 stats（复用势力 stat_bonus 注入口径）
static func _apply_stat_bonus_scaled(stats, sb: Dictionary, scale: float) -> void:
	if scale == 0.0:
		return
	# HP
	if sb.has("hp"):
		stats.max_hp = maxf(1.0, float(stats.max_hp) * (1.0 + float(sb["hp"]) * scale))
	# 三维攻击
	for key in ["atk_light", "atk_armor", "atk_air"]:
		if sb.has(key):
			var field: String = key.replace("atk_", "attack_")
			stats.set(field, maxf(0.1, float(stats.get(field)) * (1.0 + float(sb[key]) * scale)))
	# 三维防御
	for key in ["def_light", "def_armor", "def_air"]:
		if sb.has(key):
			var field: String = key.replace("def_", "defense_")
			stats.set(field, maxf(0, int(float(stats.get(field)) * (1.0 + float(sb[key]) * scale))))
	# 攻速
	if sb.has("attack_speed"):
		var aspd: float = float(sb["attack_speed"]) * scale
		for sk in ["attack_light_speed", "attack_armor_speed", "attack_air_speed"]:
			stats.set(sk, maxf(0.1, float(stats.get(sk)) * (1.0 + aspd)))
	# 暴击/闪避/回血
	if sb.has("crit_chance"):
		stats.crit_chance = min(1.0, float(stats.crit_chance) + float(sb["crit_chance"]) * scale)
	if sb.has("dodge_chance"):
		stats.dodge_chance = min(1.0, float(stats.dodge_chance) + float(sb["dodge_chance"]) * scale)
	if sb.has("hp_regen"):
		stats.hp_regen = float(stats.hp_regen) + float(sb["hp_regen"]) * scale


# ══════════════════════════════════════════════════════════════════
#  事件驱动：受击侧（construct_unit.take_damage 调用）
# ══════════════════════════════════════════════════════════════════

## death_save 判定：单位 hp 归零时，若有此技能则恢复 pct 血量（每单位一次）。
## 在 construct_unit.take_damage 的 if hp<=0: _die() 前调用。
## 返回 true 表示已救活（调用方应恢复 hp 并跳过 _die）。
static func try_death_save(unit) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if not bool(unit.get("is_player")):
		return false
	var stats = unit.get("stats") if "stats" in unit else null
	if stats == null:
		return false
	var specials: Array = stats.get_meta("faction_runtime_specials", [])
	for fx in specials:
		if not (fx is Dictionary) or not fx.has("death_save"):
			continue
		var cfg: Dictionary = fx["death_save"]
		var pct: float = float(cfg.get("pct", 0.30))
		var once: bool = bool(cfg.get("once", true))
		if once and unit.has_meta("_faction_death_save_used"):
			continue  # 已用过一次性免死
		var max_hp: float = float(stats.max_hp)
		unit.hp = maxf(1.0, max_hp * pct)
		if "max_hp" in unit:
			unit.max_hp = max_hp
		if once:
			unit.set_meta("_faction_death_save_used", true)
		_show_faction_vfx(unit, "免死护盾", "✦")
		return true
	return false


# ══════════════════════════════════════════════════════════════════
#  事件驱动：攻击侧（bullet._on_hit 调用）
# ══════════════════════════════════════════════════════════════════

## 攻击命中时：on_hit_debuff（给目标挂攻速/防御 debuff）+ first_hit_damage（首次命中加成）。
## 返回额外伤害乘数（first_hit_damage 触发时 >0，调用方乘到本次伤害上）。
static func on_attack_hit(shooter, target, is_crit: bool) -> float:
	if shooter == null or not is_instance_valid(shooter):
		return 0.0
	if not bool(shooter.get("is_player")):
		return 0.0
	var stats = shooter.get("stats") if "stats" in shooter else null
	if stats == null:
		return 0.0
	var specials: Array = stats.get_meta("faction_runtime_specials", [])
	if specials.is_empty():
		return 0.0
	var extra_mult: float = 0.0
	for fx in specials:
		if not (fx is Dictionary):
			continue
		# on_hit_debuff：给目标挂 debuff meta
		if fx.has("on_hit_debuff"):
			_apply_on_hit_debuff(target, fx["on_hit_debuff"])
		# first_hit_damage：首次命中加成（每单位一次）
		if fx.has("first_hit_damage"):
			var used_key: String = "_faction_first_hit_used"
			if not shooter.has_meta(used_key):
				extra_mult += float(fx["first_hit_damage"])
				shooter.set_meta(used_key, true)
		# on_crit_bonus_damage_pct：暴击时额外最大HP伤害
		if is_crit and fx.has("on_crit_bonus_damage_pct"):
			var bonus_pct: float = float(fx["on_crit_bonus_damage_pct"])
			if bonus_pct > 0.0 and target != null and is_instance_valid(target):
				var t_stats = target.get("stats") if "stats" in target else null
				if t_stats != null:
					var bonus_dmg: float = float(t_stats.max_hp) * bonus_pct
					if target.has_method("take_damage"):
						target.take_damage(bonus_dmg, shooter)
		# v8.6: conditional 运行时判定（atk_speed_above / deploy_speed_above / target_hp_below）
		if fx.has("conditional"):
			var cfg_c: Dictionary = fx["conditional"]
			# 攻速 > 阈值 → +暴击（近似为额外伤害，因暴击在 bullet 侧已结算）
			if cfg_c.has("atk_speed_above") and cfg_c.has("crit_bonus"):
				var atk_spd: float = float(stats.attack_light_speed)
				if atk_spd >= float(cfg_c["atk_speed_above"]):
					extra_mult += float(cfg_c.get("crit_bonus", 0.0)) * 0.5  # 暴击加成近似转为伤害
			# 部署速度 > 阈值 → +伤害（deploy_speed 是 construct_unit 属性，非 stats 字段）
			if cfg_c.has("deploy_speed_above") and cfg_c.has("damage_bonus"):
				var dep_spd: float = float(shooter.get("deploy_speed")) if "deploy_speed" in shooter else 0.0
				if dep_spd >= float(cfg_c["deploy_speed_above"]):
					extra_mult += float(cfg_c.get("damage_bonus", 0.0))
			# 目标 HP < 阈值 → +伤害（处决）
			if cfg_c.has("target_hp_below") and cfg_c.has("damage_bonus"):
				if target != null and is_instance_valid(target):
					var t_stats2 = target.get("stats") if "stats" in target else null
					var t_hp = target.get("hp") if "hp" in target else 0.0
					var t_max = float(t_stats2.max_hp) if t_stats2 != null else 1.0
					if t_max > 0.0 and float(t_hp) / t_max <= float(cfg_c["target_hp_below"]):
						extra_mult += float(cfg_c.get("damage_bonus", 0.0))
	return extra_mult


## extra_attack_chance：攻击后概率触发额外一次攻击。
## 返回 true 表示触发额外攻击（调用方应再结算一次伤害）。
static func roll_extra_attack(shooter) -> bool:
	if shooter == null or not is_instance_valid(shooter):
		return false
	if not bool(shooter.get("is_player")):
		return false
	var stats = shooter.get("stats") if "stats" in shooter else null
	if stats == null:
		return false
	var specials: Array = stats.get_meta("faction_runtime_specials", [])
	for fx in specials:
		if not (fx is Dictionary) or not fx.has("extra_attack_chance"):
			continue
		var chance: float = float(fx["extra_attack_chance"])
		if chance > 0.0 and randf() < chance:
			return true
	return false


## on_hit_debuff 应用：直接修改目标 stats（立即生效），记录 meta 供过期恢复。
## v8.6 修复：原实现只挂 meta 无消费方→空转。改为直接改 stats.attack_interval（攻速降）
## 和 stats.defense_*（防御降），过期由 process_debuff_expirations 用 delta 递减恢复。
static func _apply_on_hit_debuff(target, cfg) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not (cfg is Dictionary):
		return
	var duration: float = float(cfg.get("duration", 3.0))
	var t_stats = target.get("stats") if "stats" in target else null
	if t_stats == null:
		return
	# 攻速降低：attack_interval 增大（攻速 = 1/interval，interval 大=攻速慢）
	var aspd_red: float = float(cfg.get("attack_speed_reduction", 0.0))
	if aspd_red > 0.0 and not target.has_meta("_faction_aspd_debuff"):
		# 记录原始 interval（仅首次，防止重复叠加），过期恢复。remaining 每帧递减。
		var base_ivl: float = float(t_stats.attack_interval)
		t_stats.attack_interval = base_ivl / maxf(0.1, 1.0 - aspd_red)
		target.set_meta("_faction_aspd_debuff", {"base_interval": base_ivl, "remaining": duration})
	# 防御降低：三维防御按比例降低
	var def_red: float = float(cfg.get("defense_reduction", 0.0))
	if def_red > 0.0 and not target.has_meta("_faction_def_debuff"):
		var base_dl: float = float(t_stats.defense_light)
		var base_da: float = float(t_stats.defense_armor)
		var base_dai: float = float(t_stats.defense_air)
		t_stats.defense_light = maxf(0, base_dl * (1.0 - def_red))
		t_stats.defense_armor = maxf(0, base_da * (1.0 - def_red))
		t_stats.defense_air = maxf(0, base_dai * (1.0 - def_red))
		target.set_meta("_faction_def_debuff", {
			"base_def_light": base_dl, "base_def_armor": base_da, "base_def_air": base_dai,
			"remaining": duration,
		})


## 过期检查：恢复被 on_hit_debuff 修改的 stats。由 construct_unit._physics_process 调用。
## 用 delta 递减 remaining，不依赖全局战斗时间（BattleManager 无公开时间字段）。
static func process_debuff_expirations(unit, delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var t_stats = unit.get("stats") if "stats" in unit else null
	if t_stats == null:
		return
	# 攻速 debuff 过期
	if unit.has_meta("_faction_aspd_debuff"):
		var d: Dictionary = unit.get_meta("_faction_aspd_debuff")
		var rem: float = float(d.get("remaining", 0.0)) - delta
		if rem <= 0.0:
			t_stats.attack_interval = float(d.get("base_interval"))
			unit.remove_meta("_faction_aspd_debuff")
		else:
			d["remaining"] = rem
			unit.set_meta("_faction_aspd_debuff", d)
	# 防御 debuff 过期
	if unit.has_meta("_faction_def_debuff"):
		var d: Dictionary = unit.get_meta("_faction_def_debuff")
		var rem: float = float(d.get("remaining", 0.0)) - delta
		if rem <= 0.0:
			t_stats.defense_light = float(d.get("base_def_light"))
			t_stats.defense_armor = float(d.get("base_def_armor"))
			t_stats.defense_air = float(d.get("base_def_air"))
			unit.remove_meta("_faction_def_debuff")
		else:
			d["remaining"] = rem
			unit.set_meta("_faction_def_debuff", d)


# ══════════════════════════════════════════════════════════════════
#  事件驱动：击杀/死亡（construct_unit._die 调用）
# ══════════════════════════════════════════════════════════════════

## 击杀敌人时：on_kill_energy（击杀者回能量）+ on_kill_heal_pct（击杀者回血）。
## 由 construct_unit._die 通知击杀者时，在击杀者单位上调用。
static func on_unit_kill(killer, victim) -> void:
	if killer == null or not is_instance_valid(killer):
		return
	# 击杀者不一定是我方单位（boss AOE 攻击源是 enemy_phase_field_driver，
	# 无 is_player 属性；Object 走 bool() 会触发 "Nonexistent 'bool' constructor"）。
	# 用 in 操作符守卫属性存在性，并对取值做类型校验后再判定。
	if not ("is_player" in killer):
		return
	var killer_ip = killer.get("is_player")
	if not (killer_ip is bool) or not killer_ip:
		return
	var stats = killer.get("stats") if "stats" in killer else null
	if stats == null:
		return
	var specials: Array = stats.get_meta("faction_runtime_specials", [])
	if specials.is_empty():
		return
	for fx in specials:
		if not (fx is Dictionary):
			continue
		# on_kill_energy：回能量（按最大能量百分比）
		if fx.has("on_kill_energy"):
			var pct: float = float(fx["on_kill_energy"])
			if pct > 0.0:
				_add_energy_pct(pct)
		# on_kill_heal_pct：击杀者按自身最大HP回血
		if fx.has("on_kill_heal_pct"):
			var heal_pct: float = float(fx["on_kill_heal_pct"])
			if heal_pct > 0.0 and killer.has("hp"):
				var healed: float = float(stats.max_hp) * heal_pct
				killer.hp = minf(float(stats.max_hp), float(killer.hp) + healed)
				if killer.has_method("_update_hp_bar"):
					killer._update_hp_bar()


## 单位自身死亡时：on_death_energy_return（返还部署能量）+ on_death_ally_heal（范围友军回血）。
## 由 construct_unit._die 在确认真正死亡后（复活检查全过）、queue_free 前调用。
static func on_unit_death(unit) -> void:
	if unit == null:
		return
	if not bool(unit.get("is_player")):
		return
	var stats = unit.get("stats") if "stats" in unit else null
	if stats == null:
		return
	var specials: Array = stats.get_meta("faction_runtime_specials", [])
	if specials.is_empty():
		return
	for fx in specials:
		if not (fx is Dictionary):
			continue
		# on_death_energy_return：返还部署能量
		if fx.has("on_death_energy_return"):
			var pct: float = float(fx["on_death_energy_return"])
			if pct > 0.0:
				_add_energy_pct(pct)
		# on_death_ally_heal：范围友军回血
		if fx.has("on_death_ally_heal"):
			_death_ally_heal(unit, fx["on_death_ally_heal"])


# ══════════════════════════════════════════════════════════════════
#  周期 tick：construct_unit._physics_process 调用
# ══════════════════════════════════════════════════════════════════

## 周期 tick 总入口：处理 periodic_shield / periodic_heal / periodic_invuln。
## 由 construct_unit._physics_process 在 v8.5 兵种机制 tick 块后调用。
static func process_periodic_ticks(unit, delta: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not bool(unit.get("is_player")):
		return
	# 预览/部署幽灵不触发（Object.get 不支持默认值参数，用 in 守卫）
	var _is_ghost: bool = bool(unit.get("is_deploy_ghost")) if "is_deploy_ghost" in unit else false
	var _is_preview: bool = bool(unit.get("is_preview_mode")) if "is_preview_mode" in unit else false
	if _is_ghost or _is_preview:
		return
	var stats = unit.get("stats") if "stats" in unit else null
	if stats == null:
		return
	var specials: Array = stats.get_meta("faction_runtime_specials", [])
	if specials.is_empty():
		return
	for fx in specials:
		if not (fx is Dictionary):
			continue
		if fx.has("periodic_shield"):
			_tick_periodic_shield(unit, stats, fx["periodic_shield"], delta)
		if fx.has("periodic_heal"):
			_tick_periodic_heal(unit, stats, fx["periodic_heal"], delta)
		if fx.has("periodic_invuln"):
			_tick_periodic_invuln(unit, stats, fx["periodic_invuln"], delta)


## periodic_shield：每 interval 秒给自己加 pct×max_hp 护盾
static func _tick_periodic_shield(unit, stats, cfg, delta: float) -> void:
	if not (cfg is Dictionary):
		return
	var interval: float = float(cfg.get("interval", 60.0))
	var pct: float = float(cfg.get("pct", 0.10))
	if interval <= 0.0 or pct <= 0.0:
		return
	var cd: float = float(unit.get_meta("_faction_pshield_cd", interval))
	cd -= delta
	if cd > 0.0:
		unit.set_meta("_faction_pshield_cd", cd)
		return
	unit.set_meta("_faction_pshield_cd", interval)
	if unit.has_method("add_shield"):
		unit.add_shield(float(stats.max_hp) * pct)


## periodic_heal：每 interval 秒回 pct×max_hp 血（全体友军或自己）
static func _tick_periodic_heal(unit, stats, cfg, delta: float) -> void:
	if not (cfg is Dictionary):
		return
	var interval: float = float(cfg.get("interval", 30.0))
	var pct: float = float(cfg.get("pct", 0.05))
	if interval <= 0.0 or pct <= 0.0:
		return
	var cd: float = float(unit.get_meta("_faction_pheal_cd", interval))
	cd -= delta
	if cd > 0.0:
		unit.set_meta("_faction_pheal_cd", cd)
		return
	unit.set_meta("_faction_pheal_cd", interval)
	# 回血给自己（全体友军版本由 aura 处理，这里单位自身）
	if unit.has("hp"):
		unit.hp = minf(float(stats.max_hp), float(unit.hp) + float(stats.max_hp) * pct)
		if unit.has_method("_update_hp_bar"):
			unit._update_hp_bar()


## periodic_invuln：每 interval 秒进入 duration 秒无敌
static func _tick_periodic_invuln(unit, stats, cfg, delta: float) -> void:
	if not (cfg is Dictionary):
		return
	var interval: float = float(cfg.get("interval", 45.0))
	var duration: float = float(cfg.get("duration", 2.0))
	if interval <= 0.0 or duration <= 0.0:
		return
	# 处于无敌中：递减剩余时间
	var active_remaining: float = float(unit.get_meta("_faction_invuln_remaining", 0.0))
	if active_remaining > 0.0:
		active_remaining -= delta
		unit.set_meta("_faction_invuln_remaining", maxf(0.0, active_remaining))
		if active_remaining <= 0.0:
			unit.set_meta("_faction_invuln_active", false)
		return
	# CD 计时
	var cd: float = float(unit.get_meta("_faction_invuln_cd", interval))
	cd -= delta
	if cd > 0.0:
		unit.set_meta("_faction_invuln_cd", cd)
		return
	unit.set_meta("_faction_invuln_cd", interval)
	unit.set_meta("_faction_invuln_active", true)
	unit.set_meta("_faction_invuln_remaining", duration)


## 查询单位是否处于 periodic_invuln 无敌状态（take_damage 调用）
static func is_invulnerable(unit) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	return bool(unit.get_meta("_faction_invuln_active", false))


# ══════════════════════════════════════════════════════════════════
#  辅助函数
# ══════════════════════════════════════════════════════════════════

## 按最大能量百分比回能量（on_kill_energy / on_death_energy_return 共用）
static func _add_energy_pct(pct: float) -> void:
	var em = _get_autoload("EnergyManager")
	if em == null:
		return
	var max_e: float = float(em.get_max()) if em.has_method("get_max") else 100.0
	em.add_energy(max_e * pct)


## on_death_ally_heal：死亡时范围内友军回血
static func _death_ally_heal(unit, cfg) -> void:
	if not (cfg is Dictionary):
		return
	var radius_cells: float = float(cfg.get("radius", 2.0))
	var pct: float = float(cfg.get("pct", 0.10))
	var radius_px: float = radius_cells * 100.0  # 每格约100px
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or not (tree.root is Node):
		return
	var my_pos = unit.global_position if "global_position" in unit else Vector2.ZERO
	var stats = unit.get("stats") if "stats" in unit else null
	var heal_base: float = float(stats.max_hp) if stats != null else 100.0
	for ally in (tree.root as Node).get_nodes_in_group("player_units"):
		if ally == null or not is_instance_valid(ally) or ally == unit:
			continue
		if not ("global_position" in ally):
			continue
		var dist: float = ally.global_position.distance_to(my_pos)
		if dist <= radius_px:
			if ally.has("hp") and ally.has("stats"):
				var ally_stats = ally.get("stats")
				var healed: float = float(ally_stats.max_hp) * pct
				ally.hp = minf(float(ally_stats.max_hp), float(ally.hp) + healed)
				if ally.has_method("_update_hp_bar"):
					ally._update_hp_bar()


## 获取 autoload 节点
static func _get_autoload(name_str: String) -> Node:
	var tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(name_str)


## 显示势力技能 VFX 提示（复用 toast）
static func _show_faction_vfx(unit, msg: String, emoji: String) -> void:
	var sb = _get_autoload("SignalBus")
	if sb == null or not sb.has_signal("show_toast"):
		return
	sb.show_toast.emit("%s %s" % [emoji, msg])
