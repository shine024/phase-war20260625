extends Control
## 余烬要塞 · 房间覆盖层 v21 动效批次
## 配合双版本背景图（bunker_bg.png 初始态 / bunker_bg_lit.png 全亮态）：
##   废弃/锁定 → 轻暗遮罩 + 🔒（背景图本身已是深剪影，轻遮即可）
##   修复中    → 橙色遮罩 + 底部进度条 + 🔧
##   可用      → 显示全亮图对应房间区域（AtlasTexture region 切换），
##               状态跃迁至可用时播"灯管启动闪烁→稳定"点亮演出
## 文字（房名/角标）由本层承载，随状态变色。

signal room_clicked(room_id: String)
signal relit(room_id: String)   # 点亮演出触发（bunker_main 接震屏等反馈）

const BunkerRoomDefs = preload("res://data/bunker_room_defs.gd")
const DT = preload("res://resources/design_tokens.gd")
const LIT_TEX_PATH := "res://assets/bunker/v3/bunker_bg_v3_lit.png"
const UPG_TEX_PATH := "res://assets/bunker/v3/bunker_bg_v3_upg.png"

## v3 烘焙已把锁定房"涂黑"（只留胶囊轮廓），遮罩只需极轻一层
const COL_LOCK_TINT := Color(0.02, 0.02, 0.04, 0.14)
const COL_FIX_TINT := Color(0.30, 0.18, 0.05, 0.55)
const COL_HOVER := Color(1.0, 0.95, 0.85, 0.10)

var _room_id := ""
var _lit_rect: TextureRect
var _upg_rect: TextureRect          # v26 批次4：时代升级态图层（Lv2/Lv3 换新观感）
var _upg_border: Panel              # Lv3 金色描边框
var _relight_tween: Tween
var _prev_state := -1
var _prev_level := -1
var _tint: ColorRect
var _hover: ColorRect
var _name_label: Label
var _tag_label: Label
var _upgrade_hint: Label     # v26.12：可升级角标（运转中未满级时底部提示）
var _progress_bg: ColorRect
var _progress_fill: ColorRect
var _is_hover := false

func setup(room_id: String, x: float, y: float, w: float, h: float) -> void:
	_room_id = room_id
	position = Vector2(x, y)
	size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# v23.6.1：房间可点击（非 Button 不吃全局手型钩子），手动设光标
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build()

func _build() -> void:
	# 点亮层：全亮背景图的本房间区域（置底，tint/hover/文字都画在其上）
	var lit_tex := load(LIT_TEX_PATH) as Texture2D
	if lit_tex != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = lit_tex
		atlas.region = Rect2(position, size)
		_lit_rect = TextureRect.new()
		_lit_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_lit_rect.texture = atlas
		_lit_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_lit_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_lit_rect.modulate.a = 0.0
		_lit_rect.visible = false
		_lit_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_lit_rect)
	else:
		push_warning("[BunkerOverlay] 全亮背景图缺失: %s（点亮演出不可用）" % LIT_TEX_PATH)

	# v26 批次4：时代升级态图层——与 lit 同 region 裁切，Lv2/Lv3 时叠加显示
	var upg_tex := load(UPG_TEX_PATH) as Texture2D
	if upg_tex != null and lit_tex != null:
		var upg_atlas := AtlasTexture.new()
		upg_atlas.atlas = upg_tex
		upg_atlas.region = Rect2(position, size)
		_upg_rect = TextureRect.new()
		_upg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_upg_rect.texture = upg_atlas
		_upg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_upg_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_upg_rect.modulate.a = 0.0
		_upg_rect.visible = false
		_upg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_upg_rect)
		# Lv3 金色描边（draw_center=false 只画框）
		var border_sb := StyleBoxFlat.new()
		border_sb.draw_center = false
		border_sb.set_border_width_all(2)
		border_sb.border_color = Color(0.98, 0.82, 0.42, 0.85)
		border_sb.set_corner_radius_all(10)
		_upg_border = Panel.new()
		_upg_border.set_anchors_preset(Control.PRESET_FULL_RECT)
		_upg_border.add_theme_stylebox_override("panel", border_sb)
		_upg_border.visible = false
		_upg_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_upg_border)

	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)

	_hover = ColorRect.new()
	_hover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hover.color = COL_HOVER
	_hover.visible = false
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover)

	_name_label = Label.new()
	_name_label.anchor_left = 0.04
	_name_label.anchor_right = 0.70
	_name_label.anchor_top = 0.05
	_name_label.anchor_bottom = 0.32
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_MEDIUM)
	_name_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_tag_label = Label.new()
	_tag_label.anchor_left = 0.58
	_tag_label.anchor_right = 0.96
	_tag_label.anchor_top = 0.05
	_tag_label.anchor_bottom = 0.32
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# v23.6.1：角标有中文（废弃/修复中），11px 禁用档 → 12px
	_tag_label.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag_label)

	# v26.12：可升级角标——运转中且未满级时亮出（与修复进度条同属底部状态带）
	_upgrade_hint = Label.new()
	_upgrade_hint.anchor_left = 0.50
	_upgrade_hint.anchor_right = 0.95
	_upgrade_hint.anchor_top = 0.82
	_upgrade_hint.anchor_bottom = 0.99
	_upgrade_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_upgrade_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_upgrade_hint.add_theme_font_size_override("font_size", DT.FONT_SIZE_SMALL)
	_upgrade_hint.add_theme_color_override("font_color", DT.COLOR_AMBER_SOFT)
	_upgrade_hint.text = "▲ 可升级"
	_upgrade_hint.visible = false
	_upgrade_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_upgrade_hint)

	_progress_bg = ColorRect.new()
	_progress_bg.anchor_left = 0.05
	_progress_bg.anchor_right = 0.95
	_progress_bg.anchor_top = 0.90
	_progress_bg.anchor_bottom = 0.96
	_progress_bg.color = Color(0, 0, 0, 0.65)
	_progress_bg.visible = false
	_progress_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.anchor_left = 0.05
	_progress_fill.anchor_top = 0.90
	_progress_fill.anchor_bottom = 0.96
	_progress_fill.color = Color(0.95, 0.62, 0.15)
	_progress_fill.visible = false
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress_fill)

	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))

## 悬停就地解释：按状态给"修复条件/进度/功能/升级线"完整情报
## （文本真身在 BunkerRoomDefs.hover_tooltip_text，与房间面板共用数据源）
func _refresh_tooltip(_def: Dictionary, state: int, progress: float, frozen: bool,
		level: int, upgrade_tag: String) -> void:
	tooltip_text = BunkerRoomDefs.hover_tooltip_text(
		_room_id, state, level, frozen, upgrade_tag, progress)

func _set_hover(on: bool) -> void:
	_is_hover = on
	_hover.visible = on

func refresh(state: int, level: int, progress: float, frozen: bool, upgrade_tag := "") -> void:
	var def := BunkerRoomDefs.get_room(_room_id)
	_name_label.text = str(def.get("name", ""))
	# v23.6.1：悬停就地解释——修复条件/进度/功能说明按状态给（ui-review 检查单）
	_refresh_tooltip(def, state, progress, frozen, level, upgrade_tag)
	# v26.12：可升级角标默认隐藏，仅运转中未满级时在下方分支点亮
	_upgrade_hint.visible = false
	var is_transition := _prev_state != -1 and state != _prev_state
	# v26 批次4：等级提升（1→2→3）也播一次点亮演出——升级可感知
	var level_up := _prev_level != -1 and level > _prev_level \
			and state == BunkerRoomDefs.STATE_ACTIVE
	_prev_state = state
	_prev_level = level
	match state:
		BunkerRoomDefs.STATE_LOCKED:
			_hide_lit()
			_hide_upg()
			_tint.visible = true
			_tint.color = COL_LOCK_TINT
			_name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.58))
			_tag_label.text = "🔒 废弃"
			_tag_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.44))
			_progress_bg.visible = false
			_progress_fill.visible = false
		BunkerRoomDefs.STATE_REPAIRING:
			_hide_lit()
			_hide_upg()
			_tint.visible = true
			_tint.color = COL_FIX_TINT
			_name_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.55))
			_tag_label.text = ("进度冻结·待电力" if frozen
				else "🔧 %d%%" % int(round(progress * 100.0)))
			_tag_label.add_theme_color_override("font_color", Color(0.95, 0.66, 0.18))
			_progress_bg.visible = true
			_progress_fill.visible = true
			_layout_progress(progress)
		_:
			_tint.visible = false
			_name_label.add_theme_color_override("font_color", DT.COLOR_TEXT_BRIGHT)
			# v26：升级中的房间角标切橙色升级态；否则功能角标 + 等级（Lv2+ 标级+星）
			if not upgrade_tag.is_empty():
				_tag_label.text = upgrade_tag
				_tag_label.add_theme_color_override("font_color", Color(0.95, 0.66, 0.18))
			else:
				var tag := str(def.get("tag", ""))
				var stars := ""
				if level >= 2:
					stars = " " + "★".repeat(mini(level - 1, 2))
				_tag_label.text = ("%s · Lv%d%s" % [tag, level, stars]) if level >= 2 else tag
				_tag_label.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0, 0.9))
				# v26.12：可升级（资源未扣、进度未开跑）→ 底部琥珀提示引导玩家点进面板
				_upgrade_hint.visible = level < BunkerRoomDefs.get_max_level(_room_id)
			_progress_bg.visible = false
			_progress_fill.visible = false
			# v26 批次4：时代升级态——Lv2 半透明叠加（焕新感）/ Lv3 全量+金描边（完全体）
			_show_upg(level)
			if _lit_rect == null:
				pass  # 全亮图缺失：退回"揭遮罩露初始烘焙"旧观感
			elif _relight_tween and _relight_tween.is_valid():
				pass  # 点亮演出进行中：同状态重复刷新不打断
			elif (is_transition or level_up) and not DT.is_motion_reduce():
				_play_relight()
			else:
				# 首次刷新（读档/初始3亮房）或动效减弱：直接点亮，不闪烁
				_lit_rect.visible = true
				_lit_rect.modulate.a = 1.0

## 灯管启动演出：闪两下→稳定（~0.6s）
func _play_relight() -> void:
	_stop_relight_tween()
	_lit_rect.visible = true
	_lit_rect.modulate.a = 0.0
	_relight_tween = create_tween()
	_relight_tween.tween_property(_lit_rect, "modulate:a", 0.75, 0.10)
	_relight_tween.tween_property(_lit_rect, "modulate:a", 0.12, 0.08)
	_relight_tween.tween_property(_lit_rect, "modulate:a", 0.9, 0.12)
	_relight_tween.tween_property(_lit_rect, "modulate:a", 0.35, 0.09)
	_relight_tween.tween_property(_lit_rect, "modulate:a", 1.0, 0.25)
	relit.emit(_room_id)

func _hide_lit() -> void:
	_stop_relight_tween()
	if _lit_rect:
		_lit_rect.visible = false
		_lit_rect.modulate.a = 0.0

## v26.1：时代升级层——Lv2/Lv3 都全量切换（半透明叠加会与 lit 重影发糊，用户实测否决）；
## 档位区分靠 Lv3 金描边 + 角标星。其余状态隐藏。
func _show_upg(level: int) -> void:
	if _upg_rect == null:
		return
	var show := level >= 2
	_upg_rect.visible = show
	_upg_rect.modulate.a = 1.0 if show else 0.0
	if _upg_border != null:
		_upg_border.visible = show and level >= 3

func _hide_upg() -> void:
	if _upg_rect:
		_upg_rect.visible = false
		_upg_rect.modulate.a = 0.0
	if _upg_border:
		_upg_border.visible = false

func _stop_relight_tween() -> void:
	if _relight_tween and _relight_tween.is_valid():
		_relight_tween.kill()
	_relight_tween = null

func _layout_progress(progress: float) -> void:
	var frac := clampf(progress, 0.0, 1.0)
	_progress_fill.anchor_left = 0.05
	_progress_fill.anchor_right = 0.05 + frac * 0.90

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		room_clicked.emit(_room_id)
