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

# --- 节流时间戳（毫秒，同类特效冷却）---
const _THROTTLE_KILL_MS: int = 1000        # 击杀定帧 1s 冷却
const _THROTTLE_LAW_MS: int = 800          # 法则施放 0.8s 冷却
const _THROTTLE_BOSS_MS: int = 2000        # BOSS 登场 2s 冷却

# --- 连杀追踪 ---
const _COMBO_WINDOW_SEC: float = 3.0       # 连杀计数窗口
const _COMBO_THRESHOLD: int = 3            # 触发连杀提示的最少击杀数
var _kill_timestamps: Array[float] = []    # 最近击杀的时间戳（秒，来自 Time.get_ticks_msec）
var _last_combo_count: int = 0             # 上次播报的连杀数（避免重复播报同档）

# --- 节流状态 ---
var _last_kill_fx_ms: int = -999999
var _last_law_fx_ms: int = -999999
var _last_boss_fx_ms: int = -999999

# --- 慢动作状态守卫 ---
var _slowmo_active: bool = false

# --- 临时节点引用（按需创建，战斗结束清理）---
var _overlay: ColorRect = null             # 全屏覆盖层（暗化/闪光）
var _title_label: Label = null             # 中央大字标签（VICTORY/BOSS名）
var _combo_label: Label = null             # 右上角连杀标签


func _ready() -> void:
	# 监听核心战斗事件。process_mode 默认 ALWAYS，但慢动作期间 Engine.time_scale 不影响
	# autoload 节点的 _process（autoload 走 PROCESS_MODE_ALWAYS 链路），await 用 ignore_time_scale。
	if SignalBus:
		SignalBus.unit_killed.connect(_on_unit_killed)
		SignalBus.boss_wave_started.connect(_on_boss_wave_started)
		SignalBus.phase_master_appeared.connect(_on_phase_master_appeared)
		SignalBus.phase_law_cast.connect(_on_phase_law_cast)
		SignalBus.battle_ended.connect(_on_battle_ended)


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


func _on_phase_law_cast(law_id: String, _position: Vector2, family: String) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_law_fx_ms < _THROTTLE_LAW_MS:
		return
	_last_law_fx_ms = now_ms
	_play_law_cast(law_id, family)


func _on_battle_ended(player_won: bool) -> void:
	if player_won:
		_play_victory()
	else:
		_play_defeat()


# =========================================================================
#  特效实现（全部克制版）
# =========================================================================

## 击杀定帧：屏幕边缘 0.1s 青色微闪 + 击杀单位 0.1s 金框高亮
func _play_kill_flash(killer: Node) -> void:
	if DT.is_motion_reduce():
		return
	_ensure_overlay()
	# 边缘微闪：覆盖层快速青色 alpha 0→0.15→0
	_overlay.color = Color(DT.COLOR_ACCENT_CYAN.r, DT.COLOR_ACCENT_CYAN.g, DT.COLOR_ACCENT_CYAN.b, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_overlay, "color:a", 0.15, 0.05)
	tw.tween_property(_overlay, "color:a", 0.0, 0.05)
	tw.tween_callback(func(): _overlay.visible = false)
	# 击杀者金框高亮（克制：仅 modulate 闪一下，不缩放不震动）
	if killer != null and is_instance_valid(killer):
		var orig_mod: Color = killer.get("modulate") if "modulate" in killer else Color.WHITE
		var kt: Tween = create_tween()
		kt.tween_property(killer, "modulate", Color(1.3, 1.15, 0.7, 1.0), 0.05)
		kt.tween_property(killer, "modulate", orig_mod, 0.10)
	# 轻微屏幕震动（克制：light 档）
	_request_shake(2.0, 0.10)


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
	tw2.tween_property(_title_label, "position:y", 110, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(_title_label, "modulate:a", 1.0, 0.15)
	tw2.tween_interval(1.5)
	tw2.tween_property(_title_label, "modulate:a", 0.0, 0.35)
	tw2.tween_callback(func(): _title_label.visible = false)
	# 屏幕震动（medium 档）
	_request_shake(5.0, 0.3)


## 相位法则施放：顶部横幅 + family 配色 + light_shake
func _play_law_cast(law_id: String, family: String) -> void:
	_ensure_title_label()
	var fam_color: Color = _family_color(family)
	_title_label.text = "⚡ %s" % _law_display_name(law_id)
	_title_label.label_settings = _make_label_settings(fam_color, DT.FONT_SIZE_LARGE)
	_title_label.visible = true
	_title_label.modulate.a = 0.0
	_title_label.position.x = (get_viewport().get_visible_rect().size.x - _title_label.size.x) / 2.0
	_title_label.position.y = 80
	var tw: Tween = create_tween()
	tw.tween_property(_title_label, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.3)
	tw.tween_property(_title_label, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): _title_label.visible = false)
	_request_shake(2.0, 0.15)


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
		Engine.time_scale = 1.0
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


## 相位法则家族配色（STEEL青/FLAME橙/THUNDER紫/VOID粉）
func _family_color(family: String) -> Color:
	match family.to_upper():
		"STEEL":
			return DT.COLOR_ACCENT_CYAN
		"FLAME":
			return DT.COLOR_ENERGY
		"THUNDER":
			return DT.COLOR_ACCENT_PURPLE
		"VOID":
			return Color(1.0, 0.42, 0.62, 1.0)  # mythic 粉
		_:
			return DT.COLOR_ACCENT_CYAN


## 法则显示名（简单美化，从 law_id 推断中文名；未知则原样返回）
func _law_display_name(law_id: String) -> String:
	# law_id 形如 "law_steel_xxx"，做最简美化：去掉前缀，按 _ 拆分取有意义部分
	if law_id.is_empty():
		return "相位法则"
	# 若是中文键名直接返回；否则去前缀
	if law_id.find("·") >= 0:
		return law_id
	var cleaned: String = law_id.replace("law_", "").replace("_", " ")
	return cleaned.capitalize()


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
	if _slowmo_active:
		Engine.time_scale = 1.0
		_slowmo_active = false
