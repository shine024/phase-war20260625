extends Node
## v7.x 战场高光管理器（autoload /root/BattleSpectacle）
##
## 聚合"战斗高光时刻"的视觉编排：击杀定帧、连杀提示、BOSS 登场、相位法则施放、
## 胜利瞬间慢动作。克制风格——特效短促（0.15~1.4s），不喧宾夺主，保持军事战术感。
##
## 设计要点：
## 1. 纯 Node，无 _ready 重逻辑，启动零负担（不加重 autoload 超时）
## 2. 同类特效节流（1s 内只触发 1 次），避免密集交火刷屏
## 3. 所有动效读 DT.is_motion_reduce()，开启则短路（仅保留文字播报）
## 4. 慢动作仅胜利瞬间用一次 Engine.time_scale，await 用 ignore_time_scale 保证恢复
## 5. 全屏覆盖层（_overlay）按需创建/销毁，非战斗时不占资源
##
## 信号来源（阶段1 已接通）：
##   SignalBus.unit_killed(victim, killer, is_player_victim)
##   SignalBus.boss_wave_started(boss_archetype_ids)
##   SignalBus.phase_master_appeared(master_config)
##   SignalBus.phase_law_cast(law_id, position, family)
##   SignalBus.battle_ended(player_won)

const DT = preload("res://resources/design_tokens.gd")
const VfxImpactFactory = preload("res://scripts/battle/vfx_impact_factory.gd")

# --- 节流时间戳（毫秒，同类特效冷却）---
const _THROTTLE_KILL_MS: int = 1000        # 击杀定帧 1s 冷却
const _THROTTLE_BOSS_MS: int = 2000        # BOSS 登场 2s 冷却

# --- 连杀追踪 ---
const _COMBO_WINDOW_SEC: float = 3.0       # 连杀计数窗口
const _COMBO_THRESHOLD: int = 3            # 触发连杀提示的最少击杀数
var _kill_timestamps: Array[float] = []    # 最近击杀的时间戳（秒，来自 Time.get_ticks_msec）
var _last_combo_count: int = 0             # 上次播报的连杀数（避免重复播报同档）

# --- 节流状态 ---
var _last_kill_fx_ms: int = -999999
var _last_boss_fx_ms: int = -999999

# --- 慢动作状态守卫 ---
var _slowmo_active: bool = false

# v7.x: 玩家设定的倍速（1.0 或 2.0）。胜利慢动作恢复时用此值，不覆盖玩家选择。
var _user_time_scale: float = 1.0

## 外部设置玩家倍速（top_battle_controls 调用）。立即应用到 Engine.time_scale。
func set_user_time_scale(scale: float) -> void:
	_user_time_scale = scale
	# 慢动作进行中不立即覆盖（等慢动作结束自然恢复到 _user_time_scale）
	if not _slowmo_active:
		Engine.time_scale = scale

## 获取当前玩家倍速
func get_user_time_scale() -> float:
	return _user_time_scale

# --- 临时节点引用（按需创建，战斗结束清理）---
var _overlay: ColorRect = null             # 全屏覆盖层（暗化/闪光）
var _title_label: Label = null             # 中央大字标签（VICTORY/BOSS名）
var _combo_label: Label = null             # 右上角连杀标签
var _nano_rain_layer: CPUParticles2D = null  # v8.1: 纳米虫群全屏降雨粒子层

func _ready() -> void:
	# 监听核心战斗事件。process_mode 默认 ALWAYS，但慢动作期间 Engine.time_scale 不影响
	# autoload 节点的 _process（autoload 走 PROCESS_MODE_ALWAYS 链路），await 用 ignore_time_scale。
	if SignalBus:
		SignalBus.unit_killed.connect(_on_unit_killed)
		SignalBus.boss_wave_started.connect(_on_boss_wave_started)
		SignalBus.phase_master_appeared.connect(_on_phase_master_appeared)
		SignalBus.battle_ended.connect(_on_battle_ended)
		# v8.1: 相位仪主动能力全屏演出
		if SignalBus.has_signal("phase_instrument_ability_triggered"):
			SignalBus.phase_instrument_ability_triggered.connect(_on_ability_triggered)
		# v8.5: 兵种机制技能 VFX（8 个信号，has_signal 守卫兼容旧存档）
		if SignalBus.has_signal("mechanism_demolition_fired"):
			SignalBus.mechanism_demolition_fired.connect(_on_mechanism_demolition_fired)
		if SignalBus.has_signal("mechanism_sniper_aim_locked"):
			SignalBus.mechanism_sniper_aim_locked.connect(_on_mechanism_sniper_aim_locked)
		if SignalBus.has_signal("mechanism_sniper_fired"):
			SignalBus.mechanism_sniper_fired.connect(_on_mechanism_sniper_fired)
		if SignalBus.has_signal("mechanism_blitz_fired"):
			SignalBus.mechanism_blitz_fired.connect(_on_mechanism_blitz_fired)
		if SignalBus.has_signal("mechanism_jamming_field_activated"):
			SignalBus.mechanism_jamming_field_activated.connect(_on_mechanism_jamming_field_activated)
		if SignalBus.has_signal("mechanism_nuclear_launched"):
			SignalBus.mechanism_nuclear_launched.connect(_on_mechanism_nuclear_launched)
		if SignalBus.has_signal("mechanism_shield_projected"):
			SignalBus.mechanism_shield_projected.connect(_on_mechanism_shield_projected)
		if SignalBus.has_signal("mechanism_drone_marked"):
			SignalBus.mechanism_drone_marked.connect(_on_mechanism_drone_marked)

# =========================================================================
#  信号处理
# =========================================================================

func _on_unit_killed(victim: Node, killer: Node, is_player_victim: bool) -> void:
	# 仅"我方击杀敌方"做高光（避免玩家死亡也闪屏，增加挫败感）
	if is_player_victim:
		return
	# 节流：1s 内只触发一次击杀定帧
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_kill_fx_ms < _THROTTLE_KILL_MS:
		_kill_timestamps.append(float(now_ms) / 1000.0)
		_trim_kill_window(now_ms)
		return
	_last_kill_fx_ms = now_ms
	_kill_timestamps.append(float(now_ms) / 1000.0)
	_trim_kill_window(now_ms)
	# 击杀定帧特效（克制：仅边缘微闪 + 击杀者金框）
	_play_kill_flash(killer)
	# 连杀检测
	_check_combo(now_ms)

func _on_boss_wave_started(boss_archetype_ids: Array) -> void:
	if boss_archetype_ids.is_empty():
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_boss_fx_ms < _THROTTLE_BOSS_MS:
		return
	_last_boss_fx_ms = now_ms
	_play_boss_appear("精英波次来袭")

func _on_phase_master_appeared(master_config: Dictionary) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_boss_fx_ms < _THROTTLE_BOSS_MS:
		return
	_last_boss_fx_ms = now_ms
	var display_name: String = master_config.get("display_name", master_config.get("name", "相位师"))
	_play_boss_appear("⚔ %s 降临" % display_name)

# v9.x（P2-7范围B）：_on_phase_law_cast 法则施放演出已随法则系统退役移除

func _on_battle_ended(player_won: bool) -> void:
	_cleanup_ability_fx()  # v8.1: 清理技能演出残留（如纳米降雨层）
	if player_won:
		_play_victory()
	else:
		_play_defeat()

# =========================================================================
#  v8.1 相位仪能力全屏演出
#  =========================================================================

## 相位仪能力触发 → 按 ability_id + stage 分派演出
func _on_ability_triggered(ability_id: String, stage: String, params: Dictionary) -> void:
	if DT.is_motion_reduce():
		return
	match ability_id:
		"nuclear_bombardment":
			if stage == "warning":
				_play_nuclear_warning(params)
			elif stage == "impact":
				_play_nuclear_impact(params)
		"nano_swarm":
			if stage == "start":
				_play_nano_swarm_start(params)
		"mega_shield":
			if stage == "start":
				_play_mega_shield_start(params)
		# v7.x: 敌方相位仪能力演出（配色偏威胁——红/暗紫）
		"enemy_nano_swarm":
			if stage == "start":
				_play_enemy_warning_flash(Color(0.5, 0.1, 0.2, 0.35), "☠ 敌方纳米虫群")
		"enemy_shield_bulwark":
			if stage == "start":
				_play_enemy_warning_flash(Color(0.7, 0.2, 0.2, 0.3), "🛡 敌方能量壁垒")
		"enemy_rage_buff":
			if stage == "start":
				_play_enemy_warning_flash(Color(1.0, 0.15, 0.1, 0.4), "🔥 敌方狂暴激活")
		# v9.3: 敌方相位师 active_spells 差异化大招演出（6 类，按 effect 语义分）
		# 由 EnemyMasterSkillEngine._play_spell_cinematic emit 触发
		"enemy_spell_apocalypse":
			if stage == "warning":
				_play_enemy_warning_flash(Color(0.4, 0.05, 0.5, 0.45),
					"☄ " + String(params.get("title", "虚空灾变")))
			elif stage == "impact":
				_play_spell_impact(Color(0.5, 0.1, 0.8))  # v9.3c: 紫白定帧闪
		"enemy_spell_inferno":
			if stage == "warning":
				_play_enemy_warning_flash(Color(0.7, 0.25, 0.05, 0.4),
					"🔥 " + String(params.get("title", "地狱烈焰")))
			elif stage == "impact":
				_play_spell_impact(Color(1.0, 0.5, 0.2))  # 橙白定帧闪
		"enemy_spell_chain":
			if stage == "warning":
				_play_enemy_warning_flash(Color(0.4, 0.55, 1.0, 0.45),
					"⚡ " + String(params.get("title", "连锁闪电")))
			elif stage == "impact":
				_play_spell_impact(Color(0.6, 0.8, 1.0))  # 蓝白定帧闪
		"enemy_spell_single":
			if stage == "warning":
				_play_enemy_warning_flash(Color(0.9, 0.2, 0.5, 0.45),
					"🎯 " + String(params.get("title", "精准打击")))
			elif stage == "impact":
				_play_spell_impact(Color(1.0, 0.4, 0.7))  # 红紫定帧闪
		"enemy_spell_summon":
			if stage == "warning":
				_play_enemy_warning_flash(Color(0.35, 0.1, 0.6, 0.4),
					"⚙ " + String(params.get("title", "敌方召唤援军")))
		"enemy_spell_debuff":
			if stage == "warning":
				# v9.3b: 升级为带标题全屏预警，按类别配色调：黑暗=深紫、EMP=青、虚弱=灰
				var kind: String = String(params.get("debuff_kind", "weakness"))
				var db_title: String = String(params.get("title", "敌方削弱"))
				match kind:
					"darkness":
						_play_enemy_warning_flash(Color(0.3, 0.05, 0.45, 0.5), "🌑 " + db_title)
					"emp":
						_play_enemy_warning_flash(Color(0.15, 0.5, 0.55, 0.45), "📵 " + db_title)
					_:
						_play_enemy_warning_flash(Color(0.4, 0.4, 0.4, 0.4), "💫 " + db_title)

## 核子轰炸预警：全屏红色暗化 + 标题
func _play_nuclear_warning(_params: Dictionary) -> void:
	_ensure_overlay()
	_ensure_title_label()
	# 全屏红色暗化 0→0.5→0.3（0.3s 预警脉冲）
	_overlay.color = Color(1.0, 0.1, 0.05, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", 0.5, 0.12)
	tw.tween_property(_overlay, "color:a", 0.3, 0.18)
	# 标题
	_title_label.text = "☢ 核子轰炸"
	_title_label.label_settings = _make_label_settings(Color(1.0, 0.3, 0.2), DT.FONT_SIZE_TITLE)
	_title_label.visible = true
	_title_label.modulate.a = 0.0
	_title_label.position.x = (get_viewport().get_visible_rect().size.x - _title_label.size.x) / 2.0
	_title_label.position.y = _title_banner_y()
	var tw2: Tween = create_tween()
	tw2.tween_property(_title_label, "modulate:a", 1.0, 0.15)
	tw2.tween_interval(0.4)

## 核子轰炸命中：白闪定帧 + extreme shake（v8.1a：白闪延长到0.2s，更震撼）
func _play_nuclear_impact(params: Dictionary) -> void:
	_ensure_overlay()
	# 白闪定帧（v8.1a：0.04+0.16=0.2s，比原0.12s更持久震撼）
	_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_overlay.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", 0.95, 0.05)
	tw.tween_property(_overlay, "color:a", 0.0, 0.15)
	tw.tween_callback(func(): _overlay.visible = false)
	# extreme shake（v8.1a：延长到1.0s，余震感）
	_request_shake(16.0, 1.0)
	# 屏幕边缘绿光衰减（overlay 绿色 0.35→0，1.2s，v8.1a：延长+加亮）
	var tw3: Tween = create_tween()
	tw3.tween_interval(0.12)
	_ensure_overlay()
	_overlay.color = Color(0.2, 1.0, 0.3, 0.0)
	_overlay.visible = true
	tw3.tween_property(_overlay, "color:a", 0.35, 0.06)
	tw3.tween_property(_overlay, "color:a", 0.0, 1.1)
	tw3.tween_callback(func(): _overlay.visible = false)

## v9.3c: 大招命中定帧闪（敌我通用，对齐核子轰炸的白闪定帧效果）。
## 比 _play_nuclear_impact 轻量（单层闪 + 震屏），用于敌方 boss 大招 + 我方非核爆能力的命中瞬间。
## tint: 配色（lerp 到白闪，让闪屏带技能色调）。
func _play_spell_impact(tint: Color = Color.WHITE) -> void:
	_ensure_overlay()
	# 染色白闪定帧（0.04+0.16=0.2s，与核子轰炸同款时长）
	var flash_c: Color = Color(1.0, 1.0, 1.0, 0.0).lerp(tint, 0.4) if tint != Color.WHITE else Color(1.0, 1.0, 1.0, 0.0)
	_overlay.color = flash_c
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", 0.85, 0.04)
	tw.tween_property(_overlay, "color:a", 0.0, 0.16)
	tw.tween_callback(func(): _overlay.visible = false)
	# extreme shake（略低于核子轰炸 16.0，大招级用 12.0）
	_request_shake(12.0, 0.6)

## 纳米虫群开始：全屏紫色降雨粒子层（持续整个周期）
func _play_nano_swarm_start(params: Dictionary) -> void:
	var duration: float = float(params.get("duration", 30.0))
	_create_nano_rain_layer(duration)
	# 初始紫光脉冲
	_ensure_overlay()
	_overlay.color = Color(0.6, 0.2, 0.9, 0.0)
	_overlay.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", 0.2, 0.15)
	tw.tween_property(_overlay, "color:a", 0.0, 0.5)
	tw.tween_callback(func(): _overlay.visible = false)
	_request_shake(5.0, 0.4)

## 创建全屏紫色降雨粒子层
func _create_nano_rain_layer(duration: float) -> void:
	if _nano_rain_layer != null and is_instance_valid(_nano_rain_layer):
		_nano_rain_layer.queue_free()
	# v9.x：改挂 Battlefield Node2D（战场坐标系），原挂 get_tree().root（窗口坐标系）会导致
	# 粒子穿过战场 SubViewport（1280×580）下落到 HUD 区（580→720），污染 HUD 可读性，
	# 且与同能力的浓度场（spawn_nano_field 挂 Battlefield）坐标系不一致。
	# 拿不到 battlefield 时回退 root（保持原行为，不崩）。
	# 注：parent 类型用 Node 而非 Node2D——_get_vfx_parent 返回 Node2D（battlefield），
	# 但兜底 get_tree().root 是 Window（Node 子类，非 Node2D），CPUParticles2D 挂载只需 Node parent。
	var parent: Node = _get_vfx_parent()
	var use_root: bool = false
	if parent == null:
		parent = get_tree().root  # Window（Node 子类），能 add_child，坐标走窗口视口
		use_root = true
	# 发射区横向覆盖：战场坐标用 parent 的视口宽度，root 回退用窗口视口
	var vp_size: Vector2
	if use_root:
		vp_size = get_viewport().get_visible_rect().size
	else:
		# Battlefield 在 SubViewport 里，用其所在 SubViewport 的尺寸（战场实际宽高）
		var sv: Viewport = parent.get_viewport()
		vp_size = sv.get_visible_rect().size if sv != null else Vector2(1280.0, 580.0)
	var rain := CPUParticles2D.new()
	rain.name = "NanoSwarmRainLayer"
	rain.amount = 120  # v8.1a：80→120，更密集的虫群雨
	rain.lifetime = 2.2  # v8.1a：2.0→2.2
	rain.one_shot = false
	rain.emitting = true
	rain.explosiveness = 0.0
	rain.direction = Vector2(0, 1)  # 向下
	rain.spread = 18.0
	rain.initial_velocity_min = 180.0  # v8.1a：提速，下落更急
	rain.initial_velocity_max = 320.0
	rain.gravity = Vector2(0, 50.0)
	rain.scale_amount_min = 2.0
	rain.scale_amount_max = 4.5  # v8.1a：4→4.5
	rain.color = Color(0.7, 0.28, 1.0, 0.85)  # v8.1a：更亮的紫
	# 全屏发射区域（矩形发射，横向覆盖屏幕宽度）
	# 注：emission_rect_extents 是半宽半高，所以实际区域 = 2×extents
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2((vp_size.x + 200) * 0.5, 10.0)
	rain.position = Vector2(vp_size.x / 2.0, -40)  # 战场顶部上方（粒子从这里开始下落）
	rain.z_index = 150
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	rain.material = mat
	parent.add_child(rain)
	_nano_rain_layer = rain
	# 持续 duration 秒后淡出移除
	var tw: Tween = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(rain, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func():
		if is_instance_valid(rain):
			rain.queue_free()
		_nano_rain_layer = null
	)

## 巨型能量罩开始：全屏蓝色闪光脉冲
func _play_mega_shield_start(_params: Dictionary) -> void:
	_ensure_overlay()
	# 蓝色闪光 0→0.35→0
	_overlay.color = Color(0.3, 0.7, 1.0, 0.0)
	_overlay.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", 0.35, 0.15)
	tw.tween_property(_overlay, "color:a", 0.0, 0.6)
	tw.tween_callback(func(): _overlay.visible = false)
	_request_shake(6.0, 0.4)

## v7.x: 敌方相位仪能力警告闪光（全屏暗红/暗紫闪光 + 标题警告）
## [param flash_color] 闪光颜色（含 alpha 作为峰值透明度）
## [param title_text] 警告标题文本
func _play_enemy_warning_flash(flash_color: Color, title_text: String) -> void:
	_ensure_overlay()
	_ensure_title_label()
	# 全屏威胁色闪光：0→峰值→0
	_overlay.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", flash_color.a, 0.18)
	tw.tween_property(_overlay, "color:a", 0.0, 0.7)
	tw.tween_callback(func(): _overlay.visible = false)
	# 警告标题
	_title_label.text = title_text
	_title_label.label_settings = _make_label_settings(Color(1.0, 0.4, 0.3), DT.FONT_SIZE_TITLE)
	_title_label.visible = true
	_title_label.modulate.a = 0.0
	_title_label.position.x = (get_viewport().get_visible_rect().size.x - _title_label.size.x) / 2.0
	_title_label.position.y = _title_banner_y()
	var tw2: Tween = create_tween()
	tw2.tween_property(_title_label, "modulate:a", 1.0, 0.2)
	tw2.tween_interval(0.5)
	tw2.tween_property(_title_label, "modulate:a", 0.0, 0.3)
	_request_shake(8.0, 0.5)

## 清理技能演出残留节点（战斗结束时调用）
func _cleanup_ability_fx() -> void:
	if _nano_rain_layer != null and is_instance_valid(_nano_rain_layer):
		_nano_rain_layer.queue_free()
		_nano_rain_layer = null

# =========================================================================
#  特效实现（全部克制版）
# =========================================================================

## 击杀定帧：屏幕边缘 0.1s 青色微闪 + 击杀单位 0.1s 金框高亮
func _play_kill_flash(killer: Node) -> void:
	if DT.is_motion_reduce():
		return
	_ensure_overlay()
	# 边缘微闪：覆盖层快速青色 alpha 0→0.15→0（v8.2：0.05+0.05→0.12+0.18，原一闪即逝看不到）
	_overlay.color = Color(DT.COLOR_ACCENT_CYAN.r, DT.COLOR_ACCENT_CYAN.g, DT.COLOR_ACCENT_CYAN.b, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", 0.15, 0.12)
	tw.tween_property(_overlay, "color:a", 0.0, 0.18)
	tw.tween_callback(func(): _overlay.visible = false)
	# 击杀者金框高亮（克制：仅 modulate 闪一下，不缩放不震动；v8.2：0.05+0.10→0.12+0.22）
	if killer != null and is_instance_valid(killer):
		var orig_mod: Color = killer.get("modulate") if "modulate" in killer else Color.WHITE
		var kt: Tween = create_tween()
		kt.tween_property(killer, "modulate", Color(1.3, 1.15, 0.7, 1.0), 0.12)
		kt.tween_property(killer, "modulate", orig_mod, 0.22)
	# 轻微屏幕震动（克制：light 档）
	_request_shake(2.0, 0.10)

## v9.2: 大型常规爆炸的全屏微闪——下放核武闪白范式给 OMEGA/RAIL/MISSILE 等大爆炸。
## intensity 0.0~1.0 控制峰值透明度（0.25=微弱白闪，区别于核武的 0.95 强闪）。
## 让大爆炸有"砰"的视觉冲击，而非仅震动+粒子。受 motion_reduce 开关控制（无障碍）。
func play_explosion_flash(intensity: float = 0.25) -> void:
	if DT.is_motion_reduce():
		return
	_ensure_overlay()
	_overlay.color = Color(1.0, 0.95, 0.85, 0.0)  # 暖白（爆炸火光感，非纯白）
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = true
	var peak: float = clampf(intensity, 0.0, 0.5)  # 上限 0.5，避免常规爆炸闪瞎
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", peak, 0.04)   # 快速达到峰值（爆炸瞬间）
	tw.tween_property(_overlay, "color:a", 0.0, 0.12)   # 快速消退
	tw.tween_callback(func(): _overlay.visible = false)

## 连杀提示：右上角滑入"3 连击！"小标签
func _check_combo(now_ms: int) -> void:
	if _kill_timestamps.size() < _COMBO_THRESHOLD:
		return
	var count: int = _kill_timestamps.size()
	# 按 3/5/7 档分级播报，避免每次击杀都弹
	var tier: int = 3 if count < 5 else (5 if count < 7 else 7)
	if tier == _last_combo_count:
		return
	_last_combo_count = tier
	var label_text: String = "%d 连击！" % count
	_show_combo_label(label_text)

func _show_combo_label(text: String) -> void:
	if _combo_label == null:
		_combo_label = Label.new()
		_combo_label.name = "BattleSpectacleCombo"
		_combo_label.z_index = 200
		_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		# 挂到 root viewport 的 canvas，确保不被 SubViewport 裁剪
		get_tree().root.add_child(_combo_label)
	_combo_label.text = text
	_combo_label.label_settings = _make_label_settings(DT.COLOR_GOLD, DT.FONT_SIZE_LARGE)
	_combo_label.visible = true
	# 右上角偏下（避开 EnemySpawnHUD）
	_combo_label.size = Vector2(200, 40)
	_combo_label.position = Vector2(get_viewport().get_visible_rect().size.x - 220, 180)
	# 滑入 + 停留 + 淡出
	_combo_label.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(_combo_label, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(_combo_label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): _combo_label.visible = false)

## BU-10（战斗界面美化）：标题横幅垂直槽位——播报条（y96~146）显示中时
## 下移至 y152 避让（垂直序：波次胶囊 y1~49 → 播报 y96~146 → 横幅 y110/152）。
func _title_banner_y() -> float:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return 110.0
	var announcer: Control = tree.root.get_node_or_null("Main/HudLayer/TopCenterAnnouncer") as Control
	if announcer != null and announcer.visible:
		return 152.0
	return 110.0

## BOSS 登场：0.2s 全屏暗化 + 顶部标题横幅 + medium_shake
func _play_boss_appear(title_text: String) -> void:
	_ensure_overlay()
	_ensure_title_label()
	# 全屏暗化（alpha 0→0.4→0，克制：暗化 0.4 而非全黑）
	_overlay.color = Color(0, 0, 0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", 0.4, 0.1)
	tw.tween_property(_overlay, "color:a", 0.0, 0.4)
	tw.tween_callback(func(): _overlay.visible = false)
	# 顶部标题横幅（红色，大字），从上滑入
	_title_label.text = title_text
	_title_label.label_settings = _make_label_settings(DT.COLOR_DANGER, DT.FONT_SIZE_TITLE)
	_title_label.visible = true
	_title_label.modulate.a = 0.0
	_title_label.position.x = (get_viewport().get_visible_rect().size.x - _title_label.size.x) / 2.0
	_title_label.position.y = -60
	var tw2: Tween = create_tween()
	tw2.tween_property(_title_label, "position:y", _title_banner_y(), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(_title_label, "modulate:a", 1.0, 0.15)
	tw2.tween_interval(1.5)
	tw2.tween_property(_title_label, "modulate:a", 0.0, 0.35)
	tw2.tween_callback(func(): _title_label.visible = false)
	# 屏幕震动（medium 档）
	_request_shake(5.0, 0.3)

# v9.x（P2-7范围B）：_play_law_cast/_law_display_name/_family_color（法则施放演出）已随法则系统退役移除

## 胜利瞬间：Engine.time_scale=0.3 持续 0.6s + VICTORY 金字 + extreme_shake
func _play_victory() -> void:
	_ensure_overlay()
	_ensure_title_label()
	# 慢动作（仅一次，motion_reduce 短路）
	if not DT.is_motion_reduce() and not _slowmo_active:
		_slowmo_active = true
		Engine.time_scale = 0.3
		# ignore_time_scale=true 保证即使 time_scale<1 也能准时恢复
		await get_tree().create_timer(0.6, true, false, true).timeout
		# v7.x: 恢复到玩家设定的倍速（而非硬编码 1.0），避免覆盖玩家的 ×2 选择
		Engine.time_scale = _user_time_scale
		_slowmo_active = false
	# VICTORY 金字弹出
	_title_label.text = "VICTORY"
	_title_label.label_settings = _make_label_settings(DT.COLOR_GOLD, DT.FONT_SIZE_HUGE)
	_title_label.visible = true
	_title_label.modulate.a = 0.0
	_title_label.scale = Vector2(0.6, 0.6)
	_title_label.position.x = (get_viewport().get_visible_rect().size.x - _title_label.size.x * 0.6) / 2.0
	_title_label.position.y = (get_viewport().get_visible_rect().size.y - _title_label.size.y * 0.6) / 2.0 - 40
	var tw: Tween = create_tween()
	tw.tween_property(_title_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_title_label, "modulate:a", 1.0, 0.2)
	tw.tween_property(_title_label, "position:x", (get_viewport().get_visible_rect().size.x - _title_label.size.x) / 2.0, 0.3)
	tw.tween_interval(0.8)
	tw.tween_property(_title_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _title_label.visible = false)
	# 极限震动（克制：用 heavy 而非 extreme，避免眩晕）
	_request_shake(10.0, 0.5)

## 失败瞬间：红色边缘脉动 + DEFEAT 灰字（不慢动作，避免挫败感拉长）
func _play_defeat() -> void:
	_ensure_overlay()
	_ensure_title_label()
	_overlay.color = Color(DT.COLOR_DANGER.r, DT.COLOR_DANGER.g, DT.COLOR_DANGER.b, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", 0.3, 0.15)
	tw.tween_property(_overlay, "color:a", 0.0, 0.25)
	tw.tween_callback(func(): _overlay.visible = false)
	_title_label.text = "DEFEAT"
	_title_label.label_settings = _make_label_settings(DT.COLOR_TEXT_DIM, DT.FONT_SIZE_TITLE)
	_title_label.visible = true
	_title_label.modulate.a = 0.0
	_title_label.position.x = (get_viewport().get_visible_rect().size.x - _title_label.size.x) / 2.0
	_title_label.position.y = (get_viewport().get_visible_rect().size.y - _title_label.size.y) / 2.0 - 30
	var tw2: Tween = create_tween()
	tw2.tween_property(_title_label, "modulate:a", 1.0, 0.3)
	tw2.tween_interval(1.0)
	tw2.tween_property(_title_label, "modulate:a", 0.0, 0.5)
	tw2.tween_callback(func(): _title_label.visible = false)

# =========================================================================
#  辅助
# =========================================================================

## 确保全屏覆盖层存在（首次按需创建，挂 root viewport 不被 SubViewport 裁剪）
func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = ColorRect.new()
	_overlay.name = "BattleSpectacleOverlay"
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.z_index = 200
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_overlay)

## 确保中央大字标签存在
func _ensure_title_label() -> void:
	if _title_label != null and is_instance_valid(_title_label):
		return
	_title_label = Label.new()
	_title_label.name = "BattleSpectacleTitle"
	_title_label.z_index = 201
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(_title_label)

## 构造 LabelSettings（缓存 outline 提升可读性）
func _make_label_settings(color: Color, size: int) -> LabelSettings:
	var ls: LabelSettings = LabelSettings.new()
	ls.font_color = color
	ls.font_size = size
	ls.outline_color = Color(0, 0, 0, 0.85)
	ls.outline_size = 4
	return ls


## 触发屏幕震动（通过 BattleManager 转发，与现有命中震动同通道）
func _request_shake(intensity: float, duration: float) -> void:
	if DT.is_motion_reduce():
		return
	var bm: Node = get_node_or_null("/root/BattleManager")
	if bm != null and bm.has_method("request_screen_shake"):
		bm.request_screen_shake(intensity, duration)

## 清理连杀窗口外的旧时间戳
func _trim_kill_window(now_ms: int) -> void:
	var now_sec: float = float(now_ms) / 1000.0
	var cutoff: float = now_sec - _COMBO_WINDOW_SEC
	while _kill_timestamps.size() > 0 and _kill_timestamps[0] < cutoff:
		_kill_timestamps.pop_front()
	# 窗口清空后重置连杀档位，下次从 3 杀重新计
	if _kill_timestamps.is_empty():
		_last_combo_count = 0

func _exit_tree() -> void:
	# 守卫：节点销毁时确保 time_scale 恢复（防 autoload 被卸载时慢动作卡死）
	# 用 _user_time_scale 恢复，尊重玩家设定的倍速
	if _slowmo_active:
		Engine.time_scale = _user_time_scale
		_slowmo_active = false

# =========================================================================
#  v8.5 兵种机制技能 VFX 回调
#  局部特效用 VfxImpactFactory（需战场 Node2D parent）；全屏效果用 _overlay/shake
# =========================================================================

## 获取战场层 Node2D（用于 spawn 局部 VFX），找不到返回 null
func _get_vfx_parent() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	# 优先按 group 查（battlefield/battle_layer）
	var by_group: Node = tree.get_first_node_in_group("battlefield_layer")
	if by_group == null:
		by_group = tree.get_first_node_in_group("battlefield")
	if by_group != null and by_group is Node2D:
		return by_group
	# 回退1：从 BattleManager 拿显式持有的 battlefield（Battlefield 嵌在 SubViewport 里，
	# 不在 root 直接子节点，也没加 group——group 查找和 root 遍历都找不到它。
	# BattleManager.start_battle 时显式持有 battlefield 成员，这是最可靠的来源）
	var bm: Node = get_node_or_null("/root/BattleManager")
	if bm != null:
		var bf: Variant = bm.get("battlefield")
		if bf is Node2D and is_instance_valid(bf):
			return bf
	# 回退2：遍历 root 子节点找第一个 Node2D（main 场景根）
	if tree.root != null:
		for c in tree.root.get_children():
			if c is Node2D:
				return c
	return null

## 定向爆破：从 from→to 播抛物线弹（简化为激光束+爆炸冲击波）
func _on_mechanism_demolition_fired(from_pos: Vector2, to_pos: Vector2) -> void:
	var parent: Node2D = _get_vfx_parent()
	if parent == null:
		return
	# 橙红色抛物线轨迹（用 laser_beam 简化，方向 from→to）
	VfxImpactFactory.spawn_laser_beam(parent, from_pos, to_pos, Color(1.0, 0.5, 0.2, 0.9))
	# 目标点爆炸冲击波（橙）
	VfxImpactFactory.spawn_shockwave(parent, to_pos, 80.0, Color(1.0, 0.6, 0.2, 0.9))
	_request_shake(4.0, 0.3)

## 瞄准狙击锁定：在狙击单位位置播瞄准镜十字线（紫色短闪光）
func _on_mechanism_sniper_aim_locked(pos: Vector2) -> void:
	var parent: Node2D = _get_vfx_parent()
	if parent == null:
		return
	VfxImpactFactory.spawn_shockwave(parent, pos, 40.0, Color(0.8, 0.5, 1.0, 0.7))

## 瞄准狙击开火：from→to 红色锁定框+射击线
func _on_mechanism_sniper_fired(from_pos: Vector2, to_pos: Vector2) -> void:
	var parent: Node2D = _get_vfx_parent()
	if parent == null:
		return
	VfxImpactFactory.spawn_laser_beam(parent, from_pos, to_pos, Color(1.0, 0.3, 0.3, 1.0))
	VfxImpactFactory.spawn_crit_aura(parent, to_pos)

## 闪电穿插开火：from→to 贯穿光线（青色，体现穿透）
func _on_mechanism_blitz_fired(from_pos: Vector2, to_pos: Vector2) -> void:
	var parent: Node2D = _get_vfx_parent()
	if parent == null:
		return
	var dir: Vector2 = (to_pos - from_pos).normalized()
	VfxImpactFactory.spawn_pierce_beam(parent, from_pos, dir)

## 电子屏蔽：center 位置播紫色扩散波纹（半径 radius）
func _on_mechanism_jamming_field_activated(center: Vector2, radius: float) -> void:
	var parent: Node2D = _get_vfx_parent()
	if parent == null:
		return
	VfxImpactFactory.spawn_shockwave(parent, center, radius, Color(0.6, 0.3, 0.9, 0.6))

## 战术核武（导弹发射井）：弹道飞行 → 落点预警 → 多层核爆（闪光/火球/双冲击波/蘑菇云/焦痕）→ 延迟伤害结算
## v8.5+: 从原「瞬时闪白+冲击波」升级为完整演出。
##   owner_str: "player"/"enemy" 用于敌我配色（当前仅玩家）
##   victims: [{"target": Node, "damage": float, "attacker": Node}, ...] 发射时锁定，爆炸回调结算
## 伤害延后到爆炸 tween_callback 结算（参考 phase_instrument_abilities._fire_nuclear_bombardment 范式），
## 避免「敌人 0.35s 前就死、导弹还在飞」的视觉伤害脱节。
func _on_mechanism_nuclear_launched(from_pos: Vector2, target_pos: Vector2, owner_str: String, victims: Array) -> void:
	var parent: Node2D = _get_vfx_parent()
	# 写实橙白核爆配色（白热闪光→橙红火球→黑灰蘑菇云→焦黑地面）
	# 与核子轰炸（科幻绿紫能量调）彻底拉开：玩家一眼识别橙红+蘑菇云=导弹井
	var fireball_tint: Color = Color(1.0, 0.6, 0.2, 0.95)  # 橙红火球（写实核爆火光）
	var shock_color: Color = Color(1.0, 0.85, 0.5, 0.9)   # 淡金/白热冲击波（非绿）
	var aftershock_color: Color = Color(0.9, 0.5, 0.2, 0.5) # 暗橙余波
	var smoke_tint: Color = Color(0.35, 0.32, 0.30, 0.6)   # 黑灰蘑菇云（写实烟尘色，非绿）
	var flash_overlay_color: Color = Color(1.0, 0.98, 0.92) # 纯白偏暖热闪光
	var ember_color: Color = Color(1.0, 0.5, 0.15)         # 橙红余烬

	# ── 阶段1：弹道飞行（0.35s，贝塞尔短弧，适配俯视网格战场）──
	# 减动效模式：跳过弹道，直接进入爆炸（保留核心反馈）
	if parent != null and not DT.is_motion_reduce():
		_spawn_nuclear_missile(parent, from_pos, target_pos)

	# 文字提示（发射瞬间）：toast 告知战术核武触发
	if SignalBus.has_signal("show_toast"):
		SignalBus.show_toast.emit("☢ 战术核弹发射！")

	# ── 阶段2：预警（弹道飞行中段，落点红圈标记）──
	if parent != null:
		var warn_tween := create_tween()
		warn_tween.tween_interval(0.15)  # 弹道飞行 0.15s 后出现预警
		warn_tween.tween_callback(func():
			if is_instance_valid(parent):
				# 收缩预警环（橙红→警示）
				VfxImpactFactory.spawn_shockwave(parent, target_pos, 220.0, Color(1.0, 0.2, 0.1, 0.45)))

	# ── 阶段3：落地核爆（弹道飞行 0.5s 后，与 _spawn_nuclear_missile 的飞行时间一致）
	var detonate_tween := create_tween()
	detonate_tween.tween_interval(0.5)
	detonate_tween.tween_callback(func():
		# 伤害结算（延迟回调内逐个 take_damage，victims 在发射时已锁定）
		_settle_nuclear_victims(victims, target_pos)
		# ①全屏闪白（overlay 0→0.95→0，0.15s）
		_ensure_overlay()
		_overlay.color = Color(flash_overlay_color.r, flash_overlay_color.g, flash_overlay_color.b, 0.0)
		_overlay.visible = true
		var flash_tw: Tween = create_tween()
		# v9.x：战术核武闪白峰值 0.95→0.75 降温（CD 45s 比 _play_nuclear_impact 终极能力频繁，
		# 叠加 extreme shake 1s 对前庭敏感用户偏强；0.75 保留震撼感。对比 play_explosion_flash 已 clamp 0.5）
		flash_tw.tween_property(_overlay, "color:a", 0.75, 0.05)
		flash_tw.tween_property(_overlay, "color:a", 0.0, 0.15)
		flash_tw.tween_callback(func(): _overlay.visible = false)
		# 核爆标题（红字「☢ 核爆」闪现 0.4s，与闪白同步冲击，复用核子轰炸 _title_label 范式）
		_ensure_title_label()
		_title_label.text = "☢ 核打击"
		_title_label.label_settings = _make_label_settings(Color(1.0, 0.3, 0.15), DT.FONT_SIZE_TITLE)
		_title_label.visible = true
		_title_label.modulate.a = 0.0
		_title_label.position.x = (get_viewport().get_visible_rect().size.x - _title_label.size.x) / 2.0
		_title_label.position.y = 110
		var title_tw: Tween = create_tween()
		title_tw.tween_property(_title_label, "modulate:a", 1.0, 0.08)
		title_tw.tween_interval(0.25)
		title_tw.tween_property(_title_label, "modulate:a", 0.0, 0.25)
		title_tw.tween_callback(func(): _title_label.visible = false)
		# ②火球贴图（scale 0→大，0.4s）
		# ③主冲击波（半径 200，实际伤害半径）
		# ④余波环（半径 320，延迟 0.08s，更淡）
		# ⑤蘑菇云（ADD 混合，2.5s 上飘淡出）
		# ⑥地面焦痕（永久）
		if is_instance_valid(parent):
			# ②火球贴图（1024px贴图×0.35≈360px，醒目不溢屏）
			var fireball_tex: Texture2D = _load_nuclear_texture("nuke_fireball")
			if fireball_tex != null:
				VfxImpactFactory.spawn_impact_sprite(parent, target_pos, fireball_tex, 0.35, 0.4)
			# ③主冲击波：贴图（形状感）+ 程序化环（扩散动感）叠加
			var shockwave_tex: Texture2D = _load_nuclear_texture("nuke_shockwave")
			if shockwave_tex != null:
				VfxImpactFactory.spawn_impact_sprite(parent, target_pos, shockwave_tex, 0.30, 0.45)
			VfxImpactFactory.spawn_shockwave(parent, target_pos, 200.0, shock_color)
			# ④余波环（延迟 0.08s，参考 spawn_crit_aura 双层范式）
			var after_tw := create_tween()
			after_tw.tween_interval(0.08)
			after_tw.tween_callback(func():
				if is_instance_valid(parent):
					# v19-R32 超屏修复：320→240（aspect2.0 椭圆纵向原达781px超580视口高）
					VfxImpactFactory.spawn_shockwave(parent, target_pos, 240.0, aftershock_color))
			# ⑤蘑菇云：优先帧动画（AI精灵表切割的多帧），失败回退单 sprite + tween
			var mushroom_frames: Array = _load_nuclear_frames("nuke_mushroom_f", 9)
			var mushroom_played: bool = false
			if not mushroom_frames.is_empty():
				mushroom_played = VfxImpactFactory.spawn_animated_nuclear(parent, target_pos, mushroom_frames, 320.0, 120.0, 8.0)
			if not mushroom_played:
				# 回退：单 sprite + tween（帧贴图缺失或减动效模式）
				var mushroom_tex: Texture2D = _load_nuclear_texture("nuke_mushroom")
				if mushroom_tex != null:
					VfxImpactFactory.spawn_rising_sprite(parent, target_pos, mushroom_tex, 320.0, 120.0, 1.4)
			VfxImpactFactory.spawn_smoke_column(parent, target_pos, smoke_tint)
			# ⑥地面焦痕（贴图版，更逼真；贴图加载失败回退纯色多边形）
			var burn_tex: Texture2D = _load_nuclear_texture("nuke_burn")
			VfxImpactFactory.spawn_ground_burn(parent, target_pos, 90.0, 0.3, burn_tex)
		# ⑦屏幕震动（extreme 档）
		_request_shake(16.0, 1.0)
		# ⑧橙红余烬（overlay 0.35→0，1.0s；战术核武写实橙调，区别于核子轰炸的科幻绿）
		var ember_tw: Tween = create_tween()
		ember_tw.tween_interval(0.05)
		_ensure_overlay()
		_overlay.color = Color(ember_color.r, ember_color.g, ember_color.b, 0.0)
		_overlay.visible = true
		ember_tw.tween_property(_overlay, "color:a", 0.35, 0.06)
		ember_tw.tween_property(_overlay, "color:a", 0.0, 1.0)
		ember_tw.tween_callback(func(): _overlay.visible = false)
	)

## 核爆伤害结算（在爆炸 tween_callback 内调用，对 victims 逐个 take_damage）
## victims: [{"target": Node, "damage": float, "attacker": Node}, ...]
## 结算时复查目标有效性（延迟期间目标可能已死亡/移除），位置用爆心（伤害范围已在发射时锁定）
func _settle_nuclear_victims(victims: Array, center: Vector2) -> void:
	for v in victims:
		var target: Variant = v.get("target", null)
		if target == null or not is_instance_valid(target):
			continue
		var dmg: float = float(v.get("damage", 0.0))
		var attacker: Variant = v.get("attacker", null)
		# 伤害数字（用目标当前位置，复用 CombatFeedback 的 critical 样式突出核爆）
		var cur_pos: Vector2 = center
		if target is Node2D:
			cur_pos = (target as Node2D).global_position
		if target.has_method("take_damage"):
			target.take_damage(dmg, attacker if attacker is Node else null)

## 核爆弹道：导弹 Sprite2D 沿贝塞尔短弧飞行 0.5s + 橙白拖尾激光
func _spawn_nuclear_missile(parent: Node2D, from_pos: Vector2, target_pos: Vector2) -> void:
	var missile_tex: Texture2D = _load_nuclear_texture("nuke_missile")
	# 无导弹贴图时用激光线代替弹体（保证弹道可见）
	if missile_tex == null:
		VfxImpactFactory.spawn_laser_beam(parent, from_pos, target_pos, Color(1.0, 0.9, 0.4, 1.0))
		return
	var missile := Sprite2D.new()
	missile.texture = missile_tex
	# 1024px 贴图缩放到约 56px 宽（导弹应有的大小，像坦克炮弹而非巨物）
	var tex_w: float = float(missile_tex.get_width())
	var missile_scale: float = 56.0 / tex_w if tex_w > 0.0 else 0.06
	missile.scale = Vector2(missile_scale, missile_scale)
	missile.modulate = Color(1.0, 0.92, 0.75, 1.0)
	missile.global_position = from_pos
	# 导弹放单位层之上（z_index 高），确保飞行时盖在单位上方可见
	missile.z_index = 50
	parent.add_child(missile)
	# 贝塞尔短弧：起点 → 弧顶（中点上方抬升）→ 目标
	var apex := Vector2((from_pos.x + target_pos.x) / 2.0, min(from_pos.y, target_pos.y) - 160.0)
	var prev_pt := from_pos
	var trail_tw := create_tween()
	# tween_method 沿二次贝塞尔曲线移动 + 朝向飞行方向旋转（0.5s 飞行，足够看清导弹）
	trail_tw.tween_method(func(progress: float):
		if not is_instance_valid(missile):
			return
		var t: float = progress
		var q0 := from_pos.lerp(apex, t)
		var q1 := apex.lerp(target_pos, t)
		var pt := q0.lerp(q1, t)
		missile.global_position = pt
		# 朝向飞行方向
		var dir := pt - prev_pt
		if dir.length() > 0.5:
			missile.rotation = dir.angle()
		prev_pt = pt
	, 0.0, 1.0, 0.5)
	# 落地时移除导弹（爆炸特效接管）
	trail_tw.tween_callback(func():
		if is_instance_valid(missile):
			missile.queue_free())

## 加载核爆专用纹理（带资源守卫，缺失返回 null 由调用方回退）
## name_id: "nuke_fireball" / "nuke_missile" / "nuke_mushroom" 等
func _load_nuclear_texture(name_id: String) -> Texture2D:
	var path := "res://assets/effects/nuclear/" + name_id + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	# 回退：火球用通用爆炸贴图，导弹/其他返回 null
	if name_id == "nuke_fireball":
		var fallback := "res://assets/effects/projectiles/weapons_realistic/weapon_artillery_impact.png"
		if ResourceLoader.exists(fallback):
			return load(fallback)
	return null

## 加载核爆帧动画序列（蘑菇云精灵表切割的多帧）。
## prefix: 帧文件名前缀（如 "nuke_mushroom_f"），实际文件 = prefix + i + ".png"（i=0..count-1）
## 任一帧缺失返回空数组（调用方回退单 sprite）。全部存在返回 Texture2D 数组。
func _load_nuclear_frames(prefix: String, count: int) -> Array:
	var frames: Array = []
	for i in count:
		var path := "res://assets/effects/nuclear/" + prefix + str(i) + ".png"
		if not ResourceLoader.exists(path):
			return []  # 任一帧缺失，整体回退
		var tex: Texture2D = load(path)
		if tex == null:
			return []
		frames.append(tex)
	return frames

## 护盾投射：from 施放者 + 多个友军位置播蓝色护盾展开
func _on_mechanism_shield_projected(_from_pos: Vector2, target_positions: Array) -> void:
	var parent: Node2D = _get_vfx_parent()
	if parent == null:
		return
	for tp in target_positions:
		if tp is Vector2:
			VfxImpactFactory.spawn_shockwave(parent, tp, 50.0, Color(0.3, 0.7, 1.0, 0.8))

## 无人机定时标记：from 无人机 + 多个敌方位置播红色锁定框+扫描波纹
func _on_mechanism_drone_marked(_from_pos: Vector2, target_positions: Array) -> void:
	var parent: Node2D = _get_vfx_parent()
	if parent == null:
		return
	for tp in target_positions:
		if tp is Vector2:
			VfxImpactFactory.spawn_shockwave(parent, tp, 45.0, Color(1.0, 0.3, 0.3, 0.85))
