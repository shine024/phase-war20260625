class_name ModAuraHandler
extends RefCounted
## v6.8 改造光环处理器
##
## 复用 AuraManager 的"全体同阵营广播"机制，为装备 ally_* 类改造的单位
## 提供真实的光环 buff（影响全体友军）。
##
## 数据链路：
##   build_stats_from_card → _apply_mod_stat_effects 提取 ally_* 存 stats meta("mod_aura_summary")
##   construct_unit.setup → 复制 stats 的 meta 到节点（仿 rune_specials 模式）
##   construct_unit.setup 末尾 → ModAuraHandler.apply_mod_auras(unit)
##   construct_unit._die → ModAuraHandler.remove_mod_auras(unit)
##
## 与现有平台光环（CardAbilityManager.apply_scout_crit_aura 等）隔离：
##   - 用独立的 meta key "mod_aura_applied" 记录已施加的 buff，便于死亡时精确撤销
##   - 不复用 radar_orig_range / scout_orig_crit 等现有 meta，零冲突

## 在单位 setup 时调用：读取节点的 mod_aura_summary meta，给全体友军加 buff
static func apply_mod_auras(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var summary: Dictionary = _get_aura_summary(unit)
	if summary.is_empty():
		return
	# 广播给全体同阵营友军
	var allies := _get_all_allies(unit)
	for ally in allies:
		_apply_buffs_to_unit(ally, summary, true)

## 在单位 _die 时调用：撤销之前给友军施加的 buff
static func remove_mod_auras(unit: Node) -> void:
	if unit == null:
		return
	# _die 时单位可能已 freed，用 is_instance_valid 守卫
	if not is_instance_valid(unit):
		return
	var summary: Dictionary = _get_aura_summary(unit)
	if summary.is_empty():
		return
	# 广播给全体同阵营友军，反向撤销
	var allies := _get_all_allies(unit)
	for ally in allies:
		_apply_buffs_to_unit(ally, summary, false)

# ─────────────────────────────────────────────
# 内部实现
# ─────────────────────────────────────────────

## 读取节点的 mod_aura_summary meta（由 setup 从 stats 复制）
static func _get_aura_summary(unit: Node) -> Dictionary:
	if unit == null or not is_instance_valid(unit):
		return {}
	if unit.has_meta("mod_aura_summary"):
		var s = unit.get_meta("mod_aura_summary")
		if s is Dictionary:
			return s
	return {}

## 获取单位同阵营的所有友军（不含自身）
## 复用 AuraManager.get_slot_targets 的全体广播逻辑
static func _get_all_allies(unit: Node) -> Array:
	if unit == null or not is_instance_valid(unit):
		return []
	var tree: SceneTree = unit.get_tree()
	if tree == null:
		return []
	var is_player: bool = bool(unit.get("is_player")) if "is_player" in unit else true
	var group_name: String = "player_units" if is_player else "enemy_units"
	# 优先用 BattleManager 缓存
	var bm: Node = tree.root.get_node_or_null("BattleManager")
	var group_nodes: Array = []
	if bm != null and is_instance_valid(bm) and bm.has_method("get_cached_nodes_in_group"):
		var active: bool = bool(bm.get("battle_active")) if "battle_active" in bm else false
		if active:
			group_nodes = bm.get_cached_nodes_in_group(group_name)
	if group_nodes.is_empty():
		group_nodes = tree.get_nodes_in_group(group_name)
	var result: Array = []
	for node in group_nodes:
		if is_instance_valid(node) and node != unit:
			result.append(node)
	return result

## 对单个单位应用/撤销 buff
## summary 格式: {stat_field: {op: String, raw: float}}
## apply=true 时加 buff，apply=false 时减回去
static func _apply_buffs_to_unit(ally: Node, summary: Dictionary, apply: bool) -> void:
	if ally == null or not is_instance_valid(ally):
		return
	if not "stats" in ally or ally.stats == null:
		return
	var stats = ally.stats
	var sign := 1.0 if apply else -1.0
	for stat_field in summary:
		var rule: Dictionary = summary[stat_field]
		var op: String = rule.get("op", "add")
		var raw: float = float(rule.get("raw", 0.0))
		match op:
			"add":
				# 加法叠加（crit_chance/dodge_chance/hp_regen），带上限保护
				var cur: float = float(stats.get(stat_field))
				stats.set(stat_field, clampf(cur + sign * raw, 0.0, 1.0))
			"abs_add":
				# 负值取绝对值后加法（ally_detection -0.30 → +0.30 闪避）
				var cur_abs: float = float(stats.get(stat_field))
				stats.set(stat_field, clampf(cur_abs + sign * absf(raw), 0.0, 1.0))
			"ammo":
				# 弹药/指挥 → 攻速提升（attack_interval 乘法减少）
				var cur_int: float = float(stats.get(stat_field))
				if apply:
					stats.set(stat_field, maxf(0.1, cur_int * (1.0 - raw)))
				else:
					# 撤销时反向除（恢复原始值）
					var divisor: float = (1.0 - raw)
					if divisor > 0.0:
						stats.set(stat_field, cur_int / divisor)
			"mult_int":
				# 乘法伤害加成（attack_armor/attack_all），结果取整
				if stat_field == "attack_all":
					# 综合增益：同时影响三个攻击维度
					for dim in ["attack_light", "attack_armor", "attack_air"]:
						var cur_dim: int = int(stats.get(dim))
						if apply:
							stats.set(dim, int(float(cur_dim) * (1.0 + raw)))
						else:
							var div: float = (1.0 + raw)
							if div > 0.0:
								stats.set(dim, int(float(cur_dim) / div))
				else:
					var cur_m: int = int(stats.get(stat_field))
					if apply:
						stats.set(stat_field, int(float(cur_m) * (1.0 + raw)))
					else:
						var div_m: float = (1.0 + raw)
						if div_m > 0.0:
							stats.set(stat_field, int(float(cur_m) / div_m))
			"river":
				# 架桥 → 移速加法（值较大如 1.0，转为 +80 速度）
				var speed_delta: int = int(raw * 80.0)
				var cur_spd: int = int(stats.get(stat_field))
				stats.set(stat_field, maxi(0, cur_spd + (speed_delta if apply else -speed_delta)))
