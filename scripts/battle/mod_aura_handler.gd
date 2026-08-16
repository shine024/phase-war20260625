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
##
## 视觉反馈：
##   - 接收光环 buff 的友军会在自身 meta 中记录 "mod_aura_applied"
##   - CardGridBuffStrip 读取该 meta 显示光环图标
##   - card_info_panel._build_aura_text() 读取该 meta 显示详细效果

## 在单位 setup 时调用：读取节点的 mod_aura_summary meta，给全体友军加 buff
## 受影响的友军会在自身 meta 中记录 mod_aura_applied，供 buff_strip 和情报面板显示
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
		# 记录该友军接收了来自 unit 的光环 buff（供 buff_strip 和情报面板显示）
		_record_aura_receiver(ally, unit)

## 在单位 _die 时调用：撤销之前给友军施加的 buff，清除光环接收记录
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
		# 清除该友军接收的来自 unit 的光环记录
		_remove_aura_receiver(ally, unit)

## v10(H9): 后部署单位的补偿接收——光环源的 setup 广播只覆盖"当时在场"友军，
## 之后部署的单位原先永久吃不到光环。新单位 setup 时反向扫描场上光环源并接收其 buff。
## 由 construct_unit.setup 在 apply_mod_auras(self) 之后调用。
static func receive_mod_auras_from_field(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var is_player: bool = bool(unit.get("is_player")) if "is_player" in unit else true
	var group_name: String = "player_units" if is_player else "enemy_units"
	var allies: Array = []
	var bm: Node = tree.root.get_node_or_null("BattleManager")
	if bm != null and is_instance_valid(bm) and bm.has_method("get_cached_nodes_in_group"):
		allies = bm.get_cached_nodes_in_group(group_name)
	if allies.is_empty():
		allies = tree.get_nodes_in_group(group_name)
	for src in allies:
		if src == null or not is_instance_valid(src) or src == unit:
			continue
		var summary: Dictionary = _get_aura_summary(src)
		if summary.is_empty():
			continue
		# 已接收过该源的光环（含死亡撤销后重挂场景）则跳过，防止重复施加
		if _has_receiver_record(unit, src):
			continue
		_apply_buffs_to_unit(unit, summary, true)
		_record_aura_receiver(unit, src)

## 单位是否已记录接收过 src 的光环
static func _has_receiver_record(unit: Node, src: Node) -> bool:
	if not unit.has_meta("mod_aura_applied"):
		return false
	var src_id: String = ""
	if src.has_meta("source_instance_id"):
		src_id = String(src.get_meta("source_instance_id"))
	elif is_instance_valid(src):
		src_id = str(src.get_instance_id())
	if src_id.is_empty():
		return false
	var rec: Variant = unit.get_meta("mod_aura_applied")
	if rec is Array:
		for entry in rec:
			if entry is Dictionary and String(entry.get("source", "")) == src_id:
				return true
	return false

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
## 注意：apply_mod_auras 在 construct_unit.setup() 中被调用，此时单位可能尚未 add_child
## 入树（_create_player_unit 先 setup 后 add_child）。unit.get_tree() 在节点未入树时会
## 在 C++ 层打印 "Parameter is null" 错误（即使本函数有 null 守卫也来不及，因为错误
## 在 get_tree() 内部已触发）。改用 Engine.get_main_loop() 取全局 SceneTree，与
## FactionSkillEffectHandler._apply_stacking_to_unit 同款模式，避免触发出树 get_tree 错误。
static func _get_all_allies(unit: Node) -> Array:
	if unit == null or not is_instance_valid(unit):
		return []
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
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
	for stat_field in summary:
		var rule: Dictionary = summary[stat_field]
		var op: String = rule.get("op", "add")
		var raw: float = float(rule.get("raw", 0.0))
		match op:
			"add":
				# 加法叠加（crit_chance/dodge_chance/hp_regen），带上限保护。
				# v10(H11): 按"实际施加量"记录并回退——原撤销按 raw 回退，施加被 clamp
				# 截断时（如 0.9+0.3→1.0）撤销后变 0.7，友军属性被永久削低。
				# 注：两个光环源写同一 stat 时记录为最近一次的施加量（优于 raw，非完美）
				if apply:
					var cur: float = float(stats.get(stat_field))
					var applied_add: float = clampf(cur + raw, 0.0, 1.0) - cur
					stats.set(stat_field, cur + applied_add)
					_record_applied_delta(ally, stat_field, applied_add)
				else:
					var cur_u: float = float(stats.get(stat_field))
					var prev_add: float = _pop_applied_delta(ally, stat_field, raw)
					stats.set(stat_field, clampf(cur_u - prev_add, 0.0, 1.0))
			"abs_add":
				# 负值取绝对值后加法（ally_detection -0.30 → +0.30 闪避）。v10(H11) 同上
				if apply:
					var cur_abs: float = float(stats.get(stat_field))
					var applied_abs: float = clampf(cur_abs + absf(raw), 0.0, 1.0) - cur_abs
					stats.set(stat_field, cur_abs + applied_abs)
					_record_applied_delta(ally, stat_field, applied_abs)
				else:
					var cur_abs_u: float = float(stats.get(stat_field))
					var prev_abs: float = _pop_applied_delta(ally, stat_field, absf(raw))
					stats.set(stat_field, clampf(cur_abs_u - prev_abs, 0.0, 1.0))
			"ammo":
				# 弹药/指挥 → 攻速提升。v10(H1) 修复：原只改 attack_interval，对有武器槽的单位
				# （timing 走 weapon.attack_speed）无效。改走统一入口同步全部 timing 来源。
				# raw 语义：interval 减少比例（interval ×(1-raw) ⇔ 攻速率 ×1/(1-raw)）
				var rate_mult: float = 1.0 / maxf(0.1, 1.0 - raw)
				AttackCalculator.scale_attack_speeds(stats, rate_mult if apply else 1.0 / rate_mult)
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
				# v8.6: 架桥 → 友军部署延迟减少（与自身路径 ally_river_bonus 同口径，系数 0.05）。
				# 原 raw*80 写 move_speed 是死属性（玩家单位格子战不移动）且数值过大（+100%移速）。
				var cur_dd: float = float(stats.get("deploy_delay_bonus"))
				stats.set("deploy_delay_bonus", cur_dd + (-raw * 0.05 if apply else raw * 0.05))


# ─────────────────────────────────────────────
# ── v10(H11): clamp 施加量记账——撤销按实际施加量回退，防属性漂移 ──

static func _record_applied_delta(ally: Node, stat_field: String, delta: float) -> void:
	var d: Dictionary = {}
	if ally.has_meta("_mod_aura_applied_delta"):
		var ex: Variant = ally.get_meta("_mod_aura_applied_delta")
		if ex is Dictionary:
			d = ex
	d[stat_field] = delta
	ally.set_meta("_mod_aura_applied_delta", d)


static func _pop_applied_delta(ally: Node, stat_field: String, fallback: float) -> float:
	if ally.has_meta("_mod_aura_applied_delta"):
		var d: Variant = ally.get_meta("_mod_aura_applied_delta")
		if d is Dictionary and d.has(stat_field):
			var v: float = float(d[stat_field])
			d.erase(stat_field)
			if d.is_empty():
				ally.remove_meta("_mod_aura_applied_delta")
			else:
				ally.set_meta("_mod_aura_applied_delta", d)
			return v
	return fallback


#  mod_aura 接收者追踪（供 buff_strip / 情报面板显示）
# ─────────────────────────────────────────────

## 记录 ally 接收了来自 source_unit 的光环 buff
## meta key: "mod_aura_applied" → Array[{source: source_instance_id, summary: {stat_field: {op, raw}}} ]
static func _record_aura_receiver(ally: Node, source_unit: Node) -> void:
	if ally == null or not is_instance_valid(ally):
		return
	var source_id: String = ""
	if source_unit.has_meta("source_instance_id"):
		source_id = String(source_unit.get_meta("source_instance_id"))
	elif is_instance_valid(source_unit):
		source_id = str(source_unit.get_instance_id())
	if source_id.is_empty():
		return
	var summary: Dictionary = _get_aura_summary(source_unit)
	if summary.is_empty():
		return
	# 读取现有记录或创建新数组
	var applied: Array = []
	if ally.has_meta("mod_aura_applied"):
		var existing = ally.get_meta("mod_aura_applied")
		if existing is Array:
			applied = existing
	# 检查是否已存在同一 source 的记录
	var found := false
	for entry in applied:
		if entry is Dictionary and entry.get("source") == source_id:
			# 已有记录，更新 summary
			entry["summary"] = summary
			found = true
			break
	# 未找到匹配记录，新增一条
	if not found:
		applied.append({"source": source_id, "summary": summary})
	ally.set_meta("mod_aura_applied", applied)

## 清除 ally 接收的来自 source_unit 的光环 buff 记录
static func _remove_aura_receiver(ally: Node, source_unit: Node) -> void:
	if ally == null or not is_instance_valid(ally):
		return
	var source_id: String = ""
	if source_unit.has_meta("source_instance_id"):
		source_id = String(source_unit.get_meta("source_instance_id"))
	elif is_instance_valid(source_unit):
		source_id = str(source_unit.get_instance_id())
	if source_id.is_empty():
		return
	if not ally.has_meta("mod_aura_applied"):
		return
	var applied: Array = ally.get_meta("mod_aura_applied")
	if applied is Array:
		var filtered: Array = []
		for entry in applied:
			if entry is Dictionary and entry.get("source") == source_id:
				continue  # 移除该条记录
			filtered.append(entry)
		if filtered.is_empty():
			ally.remove_meta("mod_aura_applied")
		else:
			ally.set_meta("mod_aura_applied", filtered)
