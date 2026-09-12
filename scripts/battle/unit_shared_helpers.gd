extends RefCounted
class_name UnitSharedHelpers
## v26.6 批4: 敌我单位共享静态助手（漂移收敛·零风险组）
##
## construct_unit.gd 与 enemy_unit.gd 的同名函数中「逐字/近逐行重复」部分收敛到此处，
## 消除双份维护漂移（v26.6 量化：34 个同名函数中 14 个高度相似）。
## 收敛原则：
## 1. 只抽逻辑单一真身；阵营/模式差异全部参数化（preview_guard / is_player_side / 节点名）。
## 2. 两侧保留同名薄委托方法（1 行调 helper）——调用点零改动，热路径仅多一层调用。
## 3. 宿主成员用 duck-typed 属性访问（两侧成员名一致：_res_cache/_hpbar_ref/_hit_shake_t 等）。
## 不抽项（有意保留两侧独立实现）：take_damage 结算内核、索敌/攻击链、setup/_update_shape
## 等管线根不同的函数——见 AGENTS.md「收敛评估结论」。

const DT = preload("res://resources/design_tokens.gd")
const CardGridUnitVisuals = preload("res://scripts/card_grid_unit_visuals.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")
const UnitOutline = preload("res://scripts/battle/unit_outline.gd")  # v26.9: 描边 uniform 契约

const HIT_SHAKE_DURATION: float = 0.14  # v8.3: 0.12→0.14（4×0.035s）
# v27.12: 受击抖动关键帧常量（原每次受击在 update_hit_animations 内分配同值数组）
const HIT_SHAKE_KEYS: Array[float] = [0.78, 1.12, 0.92, 1.0]

# ─────────────────────────────────────────────
#  资源/节点引用缓存
# ─────────────────────────────────────────────

## 缓存 load()：同一资源路径只加载一次，后续从内存字典取（宿主持有 _res_cache 成员）
static func cached_load(res_cache: Dictionary, path: String, type_hint: int = -1) -> Resource:
	if path.is_empty():
		return null
	if res_cache.has(path):
		var cached = res_cache[path]
		if is_instance_valid(cached):
			return cached
		res_cache.erase(path)
	if not ResourceLoader.exists(path):
		return null
	var res: Resource
	if type_hint >= 0:
		# Godot 4.5: ResourceLoader.load 最多 3 个参数
		res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	else:
		res = load(path)
	if res != null:
		res_cache[path] = res
	return res

## HpBar 引用缓存（宿主持有 _hpbar_ref 成员）——命中免字符串路径查找；
## 未挂载时保持重查（与原行为一致），被释放后自动失效重查。
static func hpbar_cached(unit: Node) -> Node:
	if unit._hpbar_ref == null or not is_instance_valid(unit._hpbar_ref):
		unit._hpbar_ref = unit.get_node_or_null("HpBar")
	return unit._hpbar_ref

# ─────────────────────────────────────────────
#  受击视觉反馈三件套
# ─────────────────────────────────────────────

## 受击缩放抖动触发（手写分段计时，不再 create_tween）。preview_guard：部署虚影跳过（仅我方）。
static func hit_shake(unit: Node2D, preview_guard: bool) -> void:
	if preview_guard:
		return
	unit.scale = Vector2.ONE  # 关键：每次重置基准（防 scale 累积漂移）
	unit._hit_shake_t = 0.0   # 0.0=开始计时

## 受击击退位移——沿弹道反方向微位移（直射 3 / 爆炸 6 / 暴击 10）。motion_reduce 短路。
static func hit_knockback(unit: Node2D, direction: Vector2, strength: float, preview_guard: bool) -> void:
	if preview_guard or DT.is_motion_reduce():
		return
	if direction == Vector2.ZERO or strength <= 0.0:
		return
	if unit._knockback_tween != null and unit._knockback_tween.is_valid():
		unit._knockback_tween.kill()  # 连续受击时重置（取最新击退方向）
	var base_pos: Vector2 = unit.position
	var off: Vector2 = direction.normalized() * strength
	unit._knockback_tween = unit.create_tween()
	unit._knockback_tween.tween_property(unit, "position", base_pos + off, 0.04)
	unit._knockback_tween.tween_property(unit, "position", base_pos, 0.08)

## 受击动画推进（每 physics 帧调用）：shake 4 段关键帧 0.78→1.12→0.92→1.0，每段 0.035s。
## enable_flash：敌方 true（受击闪白复用 _hit_shake_t 计时，零新 tween 零 GC）；我方 false（闪白走 _play_hit_flash tween）。
static func update_hit_animations(unit: Node2D, delta: float, enable_flash: bool) -> void:
	if unit._hit_shake_t >= 0.0:
		unit._hit_shake_t += delta
		if unit._hit_shake_t >= HIT_SHAKE_DURATION:
			unit.scale = Vector2.ONE
			unit._hit_shake_t = -1.0  # 停用
			if enable_flash:
				unit.modulate = Color.WHITE  # v10: 闪白结束复位(敌方正常态 modulate=WHITE)
		else:
			var seg: int = int(unit._hit_shake_t / 0.035)
			if seg > 3:
				seg = 3
			var local_t: float = (unit._hit_shake_t - seg * 0.035) / 0.035
			var s_start: float = 1.0 if seg == 0 else HIT_SHAKE_KEYS[seg - 1]
			var s_end: float = HIT_SHAKE_KEYS[seg]
			var s: float = lerpf(s_start, s_end, local_t)
			unit.scale = Vector2(s, s)
			if enable_flash and not DT.is_motion_reduce():
				# v10: 受击闪白——前 0.08s 把 modulate 推亮再回白
				var ft: float = clampf(unit._hit_shake_t / 0.08, 0.0, 1.0)
				var fb: float = 0.8 * (1.0 - ft)  # 0.8 → 0
				unit.modulate = Color(1.0 + fb, 1.0 + fb, 1.0 + fb, 1.0)

# ─────────────────────────────────────────────
#  死亡视觉
# ─────────────────────────────────────────────

## 死亡视觉淡出：空中单位先坠落（翻转加速到地面线）再爆散淡出；地面单位直接爆散。
## 爆散 = 阵营色冲击波 + 碎片 + 缩放淡出销毁（逻辑结算已完成，不依赖 _process）。
static func death_fadeout(unit: Node2D, is_player_side: bool) -> void:
	if CardGridUnitVisuals.play_air_death_fall(unit,
		func() -> void: death_burst_and_fade(unit, is_player_side)):
		return
	death_burst_and_fade(unit, is_player_side)

static func death_burst_and_fade(unit: Node2D, is_player_side: bool) -> void:
	# v8.x: 死亡爆散反馈（阵营色冲击波 + 碎片），让死亡与受击产生明确视觉差
	VfxImpactFactory.spawn_death_burst(unit.get_parent(), unit.global_position, is_player_side)
	if unit._death_fade_tween != null and unit._death_fade_tween.is_valid():
		unit._death_fade_tween.kill()
	var start_scale := unit.scale
	unit._death_fade_tween = unit.create_tween()
	unit._death_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	unit._death_fade_tween.tween_property(unit, "scale", start_scale * 1.15, 0.08)
	unit._death_fade_tween.parallel().tween_property(unit, "modulate:a", 0.0, 0.25)
	unit._death_fade_tween.tween_property(unit, "scale", Vector2.ZERO, 0.17)
	unit._death_fade_tween.tween_callback(unit.queue_free)

# ─────────────────────────────────────────────
#  空间分区网格
# ─────────────────────────────────────────────

## 入格（preview_guard：部署虚影跳过注册——仅我方；敌方虚影需入格供我方索敌）
static func register_spatial_grid(unit: Node2D, preview_guard: bool) -> void:
	if not BattleManager or not BattleManager.spatial_grid:
		return
	if preview_guard:
		return
	BattleManager.spatial_grid.insert(unit)

## 出格
static func unregister_spatial_grid(unit: Node2D) -> void:
	if not BattleManager or not BattleManager.spatial_grid:
		return
	BattleManager.spatial_grid.remove(unit)

## 更新格内位置（preview_guard 同 register）
static func update_spatial_grid(unit: Node2D, preview_guard: bool) -> void:
	if not BattleManager or not BattleManager.spatial_grid:
		return
	if preview_guard:
		return
	BattleManager.spatial_grid.update(unit)

# ─────────────────────────────────────────────
#  战场边界
# ─────────────────────────────────────────────

## Y 轴钳制范围：格子战读部署 Y 界，否则战场常量（BATTLE_MIN_Y/BATTLE_MAX_Y 由宿主常量传入）
static func battlefield_y_clamp_range(unit: Node2D, y_min: float, y_max: float) -> Vector2:
	if unit._cached_is_card_grid:
		if BattleManager and BattleManager.battlefield and BattleManager.battlefield.has_method("get_deploy_y_bounds"):
			return BattleManager.battlefield.get_deploy_y_bounds()
	return Vector2(y_min, y_max)

## 战场边界钳制（max_x 由调用侧按阵营算好：我方 PLAYER_MAX_ADVANCE_X / 敌方 BATTLE_MAX_X）。
## 收尾调宿主 _enforce_card_grid_lane_alignment()（两侧各自实现，格吸附语义不同）。
static func clamp_inside_battlefield(unit: Node2D, x_min: float, max_x: float, y_min: float, y_max: float) -> void:
	var gx := unit.global_position
	var clamped_x := clampf(gx.x, x_min, max_x)
	var yb: Vector2 = battlefield_y_clamp_range(unit, y_min, y_max)
	var clamped_y := clampf(gx.y, yb.x, yb.y)
	if clamped_x != gx.x:
		unit.global_position.x = clamped_x
	if clamped_y != gx.y:
		unit.global_position.y = clamped_y
	unit._enforce_card_grid_lane_alignment()

# ─────────────────────────────────────────────
#  开火演出
# ─────────────────────────────────────────────

## 开火缩放脉冲 + 方向冲撞（前倾→后坐→归位，本体参与开火演出）。
## sprite_node_name：我方 "Sprite" / 敌方 "Sprite2D"；lunge_forward：我方 true / 敌方 false（朝左）。
static func fire_scale_pulse(unit: Node2D, sprite_node_name: String, lunge_forward: bool) -> void:
	# v27.12 perf: sprite 引用 meta 缓存（原每次开火字符串路径查找；失效自动重查）
	# v6.14: 必须 has_meta 守卫——get_meta(key, null) 传 null 默认值在缺 key 时
	# 仍打 ERROR 日志（每单位首火一条，L3 短局刷 6-7 条，实测踩坑）
	var spr: Sprite2D = null
	if unit.has_meta("_fire_pulse_sprite"):
		spr = unit.get_meta("_fire_pulse_sprite")
	if spr == null or not is_instance_valid(spr) or spr.get_parent() != unit:
		spr = unit.get_node_or_null(sprite_node_name)
		if spr == null:
			return
		unit.set_meta("_fire_pulse_sprite", spr)
	if unit._fire_pulse_tween != null and unit._fire_pulse_tween.is_valid():
		unit._fire_pulse_tween.kill()
	# 记录当前 scale 作回归点（可能被 faction_glow 等改过，不硬编码）
	var base_s: Vector2 = spr.scale
	unit._fire_pulse_tween = unit.create_tween()
	unit._fire_pulse_tween.tween_property(spr, "scale", base_s * 1.10, 0.04)
	unit._fire_pulse_tween.tween_property(spr, "scale", base_s, 0.07)
	# v26.x: 契约收口（全项目唯一漏接的 scale 直写点）——动画回归后刷描边 uniform
	# （edge_texels=OUTLINE_PX/scale.x，见 unit_outline.gd 头注）
	# v27.12: lambda 闭包改 Callable.bind（免每次开火分配捕获环境）
	unit._fire_pulse_tween.tween_callback(UnitOutline.refresh.bind(spr))
	# v14: 方向冲撞——前倾→后坐→归位(预备-发力-跟随)
	var wt: int = unit.stats.weapon_type if unit.stats != null else 0
	CardGridUnitVisuals.fire_lunge_sprite(spr, lunge_forward, wt in [1, 2, 3, 7, 9, 10, 11])

# ─────────────────────────────────────────────
#  卡面 buff/改造条同步
# ─────────────────────────────────────────────

## 卡面 buff/改造图标条同步（signature 去重免重建）。preview_guard：部署虚影跳过（仅我方）。
## sprite_node_name：我方 "Sprite" / 敌方 "Sprite2D"。
static func update_card_grid_buff_strip(unit: Node2D, force: bool, preview_guard: bool, sprite_node_name: String) -> void:
	if not unit._presentation_card_grid or preview_guard:
		return
	var sig: String = CardGridBuffStrip.buff_signature(unit)
	if not force and sig == unit._buff_strip_signature:
		return
	unit._buff_strip_signature = sig
	var spr: Sprite2D = unit.get_node_or_null(sprite_node_name) as Sprite2D
	# v7.x 战场视觉反馈：改造图标条（与 buff_strip 错位，放在更下方）
	CardGridUnitVisuals.sync_buff_strip(unit, unit, spr)
	CardGridUnitVisuals.sync_mod_strip(unit, unit, spr)
