extends Control
## 开始界面：Sci-Fi 风格的新游戏 / 继续 / 设置 / 退出

## 播放音效（Autoload AudioManager；get_node_or_null 兜底）
func _play_sfx(name: String) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(name)

# 颜色常量
const COLOR_CYAN := Color(0, 0.941, 1)
const COLOR_PURPLE := Color(0.545, 0.361, 0.965)
const COLOR_BG := Color(0.039, 0.055, 0.09)

var _tween: Tween
var _scan_line_y: float = 0.0
var _stars: Array = []
@onready var _title_label: Label = get_node_or_null("CenterContainer/MainVBox/TitleContainer/TitleLabel")


func _ready() -> void:
	# 获取按钮节点
	var new_btn: Button = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/NewGameButton")
	var continue_btn: Button = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/ContinueButton")
	var settings_btn: Button = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/SettingsButton")
	var quit_btn: Button = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/QuitButton")
	# 连接信号
	if new_btn:
		new_btn.pressed.connect(_on_new_game)
	if continue_btn:
		continue_btn.pressed.connect(_on_continue)
		_update_continue_button(continue_btn)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit)
	var slot_btn: Button = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/SwitchSlotButton")
	if slot_btn:
		slot_btn.pressed.connect(_on_switch_slot)
	var settings_panel = get_node_or_null("SettingsOverlay/CenterContainer/SettingsPanel")
	if settings_panel and settings_panel.has_signal("closed"):
		settings_panel.closed.connect(_on_settings_closed)

	# 生成星星数据
	_generate_stars()
	# 更新存档位显示
	_update_slot_display()

	# 播放入场动画
	_play_intro_animation()
	# 保险起见：下一帧强制启用按钮，避免动画异常导致一直不可点击
	call_deferred("_force_enable_buttons")

func _generate_stars() -> void:
	_stars.clear()
	var vp_size = get_viewport_rect().size
	var w = vp_size.x if vp_size.x > 0 else 1280.0
	var h = vp_size.y if vp_size.y > 0 else 720.0
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in range(120):
		_stars.append({
			"x": rng.randf_range(0, w),
			"y": rng.randf_range(0, h),
			"size": rng.randf_range(0.5, 2.5),
			"speed": rng.randf_range(0.1, 0.5),
			"alpha": rng.randf_range(0.2, 0.9),
			"phase": rng.randf_range(0.0, TAU),
		})

func _play_intro_animation() -> void:
	_tween = create_tween()
	_tween.set_parallel(true)

	# 动画开始前禁用按钮交互，避免透明时误触
	_set_buttons_enabled(false)

	# 标题淡入上移
	var title_label = get_node_or_null("CenterContainer/MainVBox/TitleContainer/TitleLabel")
	var subtitle = get_node_or_null("CenterContainer/MainVBox/TitleContainer/Subtitle")
	var buttons_vbox = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox")
	var version_label = get_node_or_null("CenterContainer/MainVBox/VersionLabel")

	if title_label:
		title_label.modulate.a = 0
		title_label.position.y = -50
		_tween.tween_property(title_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_property(title_label, "position:y", 0.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	if subtitle:
		subtitle.modulate.a = 0
		_tween.tween_property(subtitle, "modulate:a", 1.0, 0.6)# DELAY: 0.3).set_ease(Tween.EASE_OUT)

	if buttons_vbox:
		buttons_vbox.modulate.a = 0
		buttons_vbox.modulate.r = 1
		buttons_vbox.modulate.g = 1
		buttons_vbox.modulate.b = 1
		_tween.tween_property(buttons_vbox, "modulate:a", 1.0, 0.5)# DELAY: 0.5).set_ease(Tween.EASE_OUT)

	if version_label:
		version_label.modulate.a = 0
		_tween.tween_property(version_label, "modulate:a", 1.0, 0.4)# DELAY: 0.8).set_ease(Tween.EASE_OUT)

	# 动画完成后启用按钮（0.5s 延迟 + 0.5s 动画 = 1s 后）
	_tween.chain().tween_callback(_on_intro_animation_finished)

func _on_intro_animation_finished() -> void:
	_set_buttons_enabled(true)

func _force_enable_buttons() -> void:
	_set_buttons_enabled(true)

func _set_buttons_enabled(enabled: bool) -> void:
	var buttons_vbox = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox")
	if buttons_vbox:
		for child in buttons_vbox.get_children():
			if child is Button:
				child.disabled = not enabled

func _process(delta: float) -> void:
	# 标题呼吸效果
	if _title_label:
		var pulse = sin(Time.get_ticks_msec() * 0.002) * 0.05 + 1.0
		_title_label.scale.x = pulse
		_title_label.scale.y = pulse

	# 扫描线向下移动
	var vp_h = get_viewport_rect().size.y
	if vp_h > 0:
		_scan_line_y = fmod(_scan_line_y + delta * 80.0, vp_h)

	# 星星闪烁：隔帧重绘，减轻标题界面 GPU/CPU
	if Engine.get_process_frames() % 2 == 0:
		queue_redraw()

func _update_continue_button(btn: Button) -> void:
	if btn and SaveManager:
		btn.disabled = not SaveManager.has_save_slot(SaveManager.get_slot())

func _on_new_game() -> void:
	_play_sfx("button")
	if SaveManager:
		SaveManager.start_new_game()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_continue() -> void:
	_play_sfx("button")
	if SaveManager:
		var load_success = SaveManager.load_game()
		if load_success:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		else:
			var toast_mgr = get_node_or_null("/root/ToastManager")
			if toast_mgr and toast_mgr.has_method("show_error"):
				toast_mgr.show_error("存档加载失败，请尝试新建游戏")

func _on_settings() -> void:
	_play_sfx("button")
	var overlay = get_node_or_null("SettingsOverlay")
	if overlay:
		overlay.visible = true

func _on_settings_closed() -> void:
	var overlay = get_node_or_null("SettingsOverlay")
	if overlay:
		overlay.visible = false

## 切换存档位
func _on_switch_slot() -> void:
	if not SaveManager:
		return
	var current := SaveManager.get_slot()
	var next_slot := current + 1
	if next_slot > SaveManager.MAX_SLOTS:
		next_slot = 1
	SaveManager.set_slot(next_slot)
	var continue_btn: Button = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/ContinueButton")
	if continue_btn:
		_update_continue_button(continue_btn)
	_update_slot_display()


## 更新存档位显示
func _update_slot_display() -> void:
	var slot_label: Label = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/SlotLabel")
	if slot_label:
		var info: Array = SaveManager.get_slot_info() if SaveManager else []
		var parts: Array = []
		for s in info:
			var marker := "▸ " if int(s.get("slot", 0)) == SaveManager.get_slot() else "  "
			var level_str := "第 %d 关" % int(s.get("level", 0)) if int(s.get("level", 0)) > 0 else "空"
			parts.append("%s%d: %s" % [marker, int(s.get("slot", 0)), level_str])
		slot_label.text = "\n".join(parts)


func _on_quit() -> void:
	_play_sfx("button")
	get_tree().quit()

func _draw() -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	var vp_size = get_viewport_rect().size

	# 绘制闪烁星星
	for s in _stars:
		var a: float = s["alpha"] * (0.5 + 0.5 * sin(t * s["speed"] + s["phase"]))
		draw_circle(Vector2(s["x"], s["y"]), s["size"], Color(0.7, 0.9, 1.0, a))

	# 绘制水平扫描线（半透明细线）
	var scan_color := Color(0, 0.941, 1, 0.04)
	var scan_step := 40.0
	var offset := fmod(_scan_line_y, scan_step)
	var y := offset
	while y < vp_size.y:
		draw_line(Vector2(0, y), Vector2(vp_size.x, y), scan_color, 1.0)
		y += scan_step

	# 绘制底部渐变线（装饰用）
	draw_line(Vector2(0, vp_size.y - 2), Vector2(vp_size.x, vp_size.y - 2),
		Color(0, 0.941, 1, 0.3), 2.0)
