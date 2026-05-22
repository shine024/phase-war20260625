extends Node
## UI美化系统：提供统一的界面美化、动画效果和视觉增强

## 信号定义
signal animation_started(animation_name: String)
signal animation_completed(animation_name: String)
signal transition_started(from_screen: String, to_screen: String)
signal transition_completed(from_screen: String, to_screen: String)
signal theme_changed(theme_name: String)

## 主题定义
const THEMES: Dictionary = {
	"default": {
		"name": "默认主题",
		"primary_color": Color(0.2, 0.6, 1.0, 1.0),
		"secondary_color": Color(0.6, 0.4, 1.0, 1.0),
		"accent_color": Color(1.0, 0.9, 0.3, 1.0),
		"background_color": Color(0.1, 0.1, 0.15, 1.0),
		"text_color": Color(0.95, 0.95, 0.95, 1.0),
		"panel_color": Color(0.15, 0.15, 0.2, 0.9),
		"border_color": Color(0.3, 0.3, 0.4, 1.0),
		"success_color": Color(0.3, 0.9, 0.5, 1.0),
		"warning_color": Color(1.0, 0.8, 0.2, 1.0),
		"error_color": Color(1.0, 0.3, 0.3, 1.0)
	},
	"dark": {
		"name": "暗色主题",
		"primary_color": Color(0.4, 0.7, 1.0, 1.0),
		"secondary_color": Color(0.7, 0.5, 1.0, 1.0),
		"accent_color": Color(1.0, 0.8, 0.4, 1.0),
		"background_color": Color(0.05, 0.05, 0.08, 1.0),
		"text_color": Color(0.9, 0.9, 0.9, 1.0),
		"panel_color": Color(0.1, 0.1, 0.15, 0.95),
		"border_color": Color(0.2, 0.2, 0.3, 1.0),
		"success_color": Color(0.4, 0.9, 0.5, 1.0),
		"warning_color": Color(1.0, 0.7, 0.2, 1.0),
		"error_color": Color(1.0, 0.3, 0.3, 1.0)
	},
	"light": {
		"name": "亮色主题",
		"primary_color": Color(0.2, 0.5, 0.8, 1.0),
		"secondary_color": Color(0.5, 0.3, 0.7, 1.0),
		"accent_color": Color(0.9, 0.7, 0.2, 1.0),
		"background_color": Color(0.95, 0.95, 0.98, 1.0),
		"text_color": Color(0.1, 0.1, 0.15, 1.0),
		"panel_color": Color(0.98, 0.98, 1.0, 0.95),
		"border_color": Color(0.7, 0.7, 0.8, 1.0),
		"success_color": Color(0.2, 0.7, 0.3, 1.0),
		"warning_color": Color(0.9, 0.6, 0.1, 1.0),
		"error_color": Color(0.9, 0.2, 0.2, 1.0)
	}
}

## 当前主题
var current_theme: String = "default"

## 动画配置
var animation_config: Dictionary = {
	"enable_animations": true,
	"animation_speed": 1.0,
	"easing_type": "ease_in_out",
	"transition_duration": 0.3,
	"enable_particles": true,
	"enable_blur": true
}

## UI根节点
var ui_root: Control = null

## 当前活动动画
var active_animations: Dictionary = {}

func _ready() -> void:
	ui_root = get_tree().root
	_initialize_ui_system()
	_apply_theme(current_theme)

## 初始化UI系统
func _initialize_ui_system() -> void:
	print("[UIBeautifier] UI美化系统已初始化")

	# 设置默认主题样式
	_setup_default_styles()

	# 初始化动画系统
	_initialize_animation_system()

## 设置默认样式
func _setup_default_styles() -> void:
	# 创建主题资源
	var theme = Theme.new()

	# 设置默认样式
	_setup_button_styles(theme)
	_setup_label_styles(theme)
	_setup_panel_styles(theme)
	_setup_progress_bar_styles(theme)

	# 应用主题到根节点
	if ui_root != null:
		ui_root.theme = theme

## 设置按钮样式
func _setup_button_styles(theme: Theme) -> void:
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = THEMES["default"]["primary_color"]
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	button_style.border_width_left = 2
	button_style.border_width_top = 2
	button_style.border_width_right = 2
	button_style.border_width_bottom = 2
	button_style.border_color = THEMES["default"]["border_color"]

	theme.set_stylebox("Button", "normal", button_style)

	# 悬停样式
	var hover_style = button_style.duplicate()
	hover_style.bg_color = THEMES["default"]["primary_color"] + Color(0.2, 0.2, 0.2, 0.0)
	theme.set_stylebox("Button", "hover", hover_style)

	# 按下样式
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = THEMES["default"]["primary_color"] - Color(0.1, 0.1, 0.1, 0.0)
	theme.set_stylebox("Button", "pressed", pressed_style)

## 设置标签样式
func _setup_label_styles(theme: Theme) -> void:
	# 标题样式
	var title_font = FontFile.new()
	# 这里需要加载实际字体文件

	theme.set_font("Label", "font_size", 16)
	theme.set_color("Label", "font_color", THEMES["default"]["text_color"])

## 设置面板样式
func _setup_panel_styles(theme: Theme) -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = THEMES["default"]["panel_color"]
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = THEMES["default"]["border_color"]
	panel_style.shadow_color = Color(0, 0, 0, 0.3)
	panel_style.shadow_size = 5

	theme.set_stylebox("PanelContainer", "panel", panel_style)

## 设置进度条样式
func _setup_progress_bar_styles(theme: Theme) -> void:
	var progress_style = StyleBoxFlat.new()
	progress_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
	progress_style.corner_radius_top_left = 3
	progress_style.corner_radius_top_right = 3
	progress_style.corner_radius_bottom_left = 3
	progress_style.corner_radius_bottom_right = 3

	var fill_style = progress_style.duplicate()
	fill_style.bg_color = THEMES["default"]["accent_color"]

	theme.set_stylebox("ProgressBar", "background", progress_style)
	theme.set_stylebox("ProgressBar", "fill", fill_style)

## 初始化动画系统
func _initialize_animation_system() -> void:
	# 创建动画根节点
	var animation_root = Node.new()
	animation_root.name = "AnimationRoot"
	ui_root.add_child(animation_root)

	print("[UIBeautifier] 动画系统已初始化")

## 应用主题
func apply_theme(theme_name: String) -> void:
	if not THEMES.has(theme_name):
		push_error("[UIBeautifier] 主题不存在: ", theme_name)
		return

	current_theme = theme_name
	var theme_data = THEMES[theme_name]

	# 应用颜色主题
	_apply_color_theme(theme_data)

	# 更新所有面板样式
	_update_all_panels()

	theme_changed.emit(theme_name)

	print("[UIBeautifier] 已应用主题: ", theme_data["name"])

## 应用颜色主题
func _apply_color_theme(theme_data: Dictionary) -> void:
	var root = get_tree().root

	# 更新所有Control节点
	for child in root.find_children("*", false, true):
		if child is Control:
			_update_control_theme(child, theme_data)

## 更新控件主题
func _update_control_theme(control: Control, theme_data: Dictionary) -> void:
	# 更新背景色
	if control is Panel or control is PanelContainer:
		var style = control.get_theme_stylebox("panel", "")
		if style != null:
			style.bg_color = theme_data["panel_color"]
			style.border_color = theme_data["border_color"]

	# 更新标签颜色
	if control.has_method("set_modulate"):
		for child in control.find_children("*", false, true):
			if child is Label:
				child.add_theme_color_override("font_color", theme_data["text_color"])

## 淡入动画
func fade_in(control: Control, duration: float = 0.3) -> void:
	if not animation_config["enable_animations"]:
		control.modulate.a = 1.0
		return

	control.modulate.a = 0.0

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration / animation_config["animation_speed"])

	animation_started.emit("fade_in")
	tween.tween_callback(_on_animation_completed.bind("fade_in"))

## 淡出动画
func fade_out(control: Control, duration: float = 0.3) -> void:
	if not animation_config["enable_animations"]:
		control.modulate.a = 0.0
		return

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(control, "modulate:a", 0.0, duration / animation_config["animation_speed"])

	animation_started.emit("fade_out")
	tween.tween_callback(_on_animation_completed.bind("fade_out"))

## 滑入动画
func slide_in(control: Control, direction: Vector2, duration: float = 0.3) -> void:
	if not animation_config["enable_animations"]:
		return

	var start_pos = control.position
	var end_pos = start_pos + direction

	control.position = start_pos

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", end_pos, duration / animation_config["animation_speed"])

	animation_started.emit("slide_in")
	tween.tween_callback(_on_animation_completed.bind("slide_in"))

## 滑出动画
func slide_out(control: Control, direction: Vector2, duration: float = 0.3) -> void:
	if not animation_config["enable_animations"]:
		return

	var start_pos = control.position
	var end_pos = start_pos + direction

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(control, "position", end_pos, duration / animation_config["animation_speed"])

	animation_started.emit("slide_out")
	tween.tween_callback(_on_animation_completed.bind("slide_out"))

## 缩放动画
func scale_animation(control: Control, target_scale: Vector2, duration: float = 0.3) -> void:
	if not animation_config["enable_animations"]:
		control.scale = target_scale
		return

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "scale", target_scale, duration / animation_config["animation_speed"])

	animation_started.emit("scale")
	tween.tween_callback(_on_animation_completed.bind("scale"))

## 旋转动画
func rotate_animation(control: Control, target_rotation: float, duration: float = 0.3) -> void:
	if not animation_config["enable_animations"]:
		control.rotation = target_rotation
		return

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "rotation", target_rotation, duration / animation_config["animation_speed"])

	animation_started.emit("rotate")
	tween.tween_callback(_on_animation_completed.bind("rotate"))

## 弹跳动画
func bounce_animation(control: Control, duration: float = 0.5) -> void:
	if not animation_config["enable_animations"]:
		return

	var tween = create_tween()
	tween.set_parallel(true)

	# 缩放
	var original_scale = control.scale
	tween.tween_property(control, "scale", original_scale * 1.1, duration * 0.5 / animation_config["animation_speed"])
	tween.tween_property(control, "scale", original_scale, duration * 0.5 / animation_config["animation_speed"])

	# 旋转
	tween.tween_property(control, "rotation", 0.1, duration * 0.25 / animation_config["animation_speed"])
	tween.tween_property(control, "rotation", -0.1, duration * 0.25 / animation_config["animation_speed"])# DELAY: duration * 0.25)
	tween.tween_property(control, "rotation", 0.0, duration * 0.25 / animation_config["animation_speed"])# DELAY: duration * 0.5)

	animation_started.emit("bounce")
	tween.tween_callback(_on_animation_completed.bind("bounce"))

## 抖动动画（有限次循环，可 kill）
func shake_animation(control: Control, intensity: float = 5.0, duration: float = 0.3) -> void:
	if not animation_config["enable_animations"]:
		return

	var original_pos = control.position
	var shake_count = int(duration * 60)  # 60fps

	var tween = create_tween()

	for i in range(shake_count):
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(control, "position", original_pos + offset, 0.016)

	# 恢复位置
	tween.tween_property(control, "position", original_pos, 0.1)

	animation_started.emit("shake")
	tween.tween_callback(_on_animation_completed.bind("shake"))

## 脉冲动画（有限次循环，可 kill）
func pulse_animation(control: Control, duration: float = 1.0) -> void:
	if not animation_config["enable_animations"]:
		return

	var original_scale = control.scale

	var tween = create_tween()
	for _i in range(3):
		tween.tween_property(control, "scale", original_scale * 1.05, duration * 0.5 / animation_config["animation_speed"])
		tween.tween_property(control, "scale", original_scale, duration * 0.5 / animation_config["animation_speed"])

	animation_started.emit("pulse")
	tween.tween_callback(_on_animation_completed.bind("pulse"))

## 过渡动画
func transition_screens(from_screen: Control, to_screen: Control, transition_type: String = "fade") -> void:
	if not animation_config["enable_animations"]:
		from_screen.visible = false
		to_screen.visible = true
		return

	transition_started.emit(from_screen.name, to_screen.name)

	match transition_type:
		"fade":
			_fade_transition(from_screen, to_screen)
		"slide_left":
			_slide_transition(from_screen, to_screen, Vector2(-100, 0))
		"slide_right":
			_slide_transition(from_screen, to_screen, Vector2(100, 0))
		"zoom":
			_zoom_transition(from_screen, to_screen)
		_:
			_fade_transition(from_screen, to_screen)

## 淡入淡出过渡
func _fade_transition(from_screen: Control, to_screen: Control) -> void:
	var duration = animation_config["transition_duration"]

	# 淡出当前屏幕
	fade_out(from_screen, duration / 2)
	await get_tree().create_timer(duration / 2).timeout

	# 隐藏当前屏幕，显示新屏幕
	from_screen.visible = false
	to_screen.visible = true

	# 淡入新屏幕
	fade_in(to_screen, duration / 2)
	await get_tree().create_timer(duration / 2).timeout

	transition_completed.emit(from_screen.name, to_screen.name)

## 滑动过渡
func _slide_transition(from_screen: Control, to_screen: Control, direction: Vector2) -> void:
	var duration = animation_config["transition_duration"]

	# 滑出当前屏幕
	from_screen.z_index = 1
	slide_out(from_screen, direction, duration / 2)
	await get_tree().create_timer(duration / 2).timeout

	# 切换屏幕
	from_screen.visible = false
	to_screen.visible = true
	to_screen.z_index = 0

	# 滑入新屏幕
	slide_in(to_screen, -direction, duration / 2)
	await get_tree().create_timer(duration / 2).timeout

	# 恢复z-index
	from_screen.z_index = 0
	to_screen.z_index = 0

	transition_completed.emit(from_screen.name, to_screen.name)

## 缩放过渡
func _zoom_transition(from_screen: Control, to_screen: Control) -> void:
	var duration = animation_config["transition_duration"]

	# 缩小当前屏幕
	scale_animation(from_screen, Vector2(0.1, 0.1), duration / 2)
	await get_tree().create_timer(duration / 2).timeout

	# 切换屏幕
	from_screen.visible = false
	to_screen.visible = true
	to_screen.scale = Vector2(0.1, 0.1)

	# 放大新屏幕
	scale_animation(to_screen, Vector2(1.0, 1.0), duration / 2)
	await get_tree().create_timer(duration / 2).timeout

	transition_completed.emit(from_screen.name, to_screen.name)

## 添加模糊效果
func apply_blur(control: Control, blur_amount: float = 5.0) -> void:
	if not animation_config["enable_blur"]:
		return

	var blur = BlurRect.new()
	blur.size = control.size
	blur.position = Vector2(0, 0)
	control.add_child(blur)

	var tween = create_tween()
	tween.tween_property(blur, "amount", blur_amount, 0.2)

	# 自动清理
	tween.tween_callback(blur.queue_free)# DELAY: 2.0)

## 移除模糊效果
func remove_blur(control: Control) -> void:
	for child in control.get_children():
		if child is BlurRect:
			child.queue_free()

## 添加粒子效果
func add_particle_effect(control: Control, effect_type: String) -> void:
	if not animation_config["enable_particles"]:
		return

	match effect_type:
		"sparkle":
			_add_sparkle_particles(control)
		"glow":
			_add_glow_effect(control)
		"confetti":
			_add_confetti_particles(control)

## 添加闪烁粒子
func _add_sparkle_particles(control: Control) -> void:
	var particles = GPUParticles2D.new()
	particles.name = "SparkleParticles"
	particles.amount = 20
	particles.process_material = _create_sparkle_material()
	particles.emitting = true

	control.add_child(particles)

	# 自动停止并释放粒子节点（避免泄漏）
	var captured_particles = particles
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(captured_particles):
			captured_particles.emitting = false
			captured_particles.queue_free()
	)

## 创建闪烁材质
func _create_sparkle_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()

	material.gravity = Vector3(0, 98, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(control.size.x, 50.0, 0)
	material.direction = Vector3(0, -1, 0)
	material.spread = 0.3
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 50.0
	material.color = Color(1.0, 1.0, 1.0, 0.8)

	return material

## 添加发光效果
func _add_glow_effect(control: Control) -> void:
	var glow = ColorRect.new()
	glow.size = control.size
	glow.position = Vector2(0, 0)
	glow.color = THEMES[current_theme]["accent_color"]
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(glow)

	# 有限次脉冲（禁止 set_loops，避免 glow 被 queue_free 后 tween 仍引用）
	var glow_tween: Tween = create_tween()
	var base_mod: Color = glow.modulate
	var half: float = 0.28 / maxf(0.05, animation_config["animation_speed"])
	for _i in range(3):
		glow_tween.tween_property(glow, "modulate:a", base_mod.a * 0.45, half)
		glow_tween.tween_property(glow, "modulate:a", base_mod.a, half)

	var captured_glow = glow
	var captured_glow_tween: Tween = glow_tween
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if captured_glow_tween.is_valid():
			captured_glow_tween.kill()
		if is_instance_valid(captured_glow):
			captured_glow.queue_free()
	)

## 添加彩纸粒子
func _add_confetti_particles(control: Control) -> void:
	var particles = GPUParticles2D.new()
	particles.name = "ConfettiParticles"
	particles.amount = 100
	particles.process_material = _create_confetti_material()
	particles.emitting = true

	control.add_child(particles)

	# 自动停止并释放粒子节点（避免泄漏）
	var captured_particles = particles
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(captured_particles):
			captured_particles.emitting = false
			captured_particles.queue_free()
	)

## 创建彩纸材质
func _create_confetti_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()

	material.gravity = Vector3(0, 98, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0, -1, 0)
	material.spread = 0.8
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 200.0

	# 随机颜色
	var colors = [
		Color(1.0, 0.3, 0.3, 1.0),
		Color(0.3, 1.0, 0.3, 1.0),
		Color(0.3, 0.3, 1.0, 1.0),
		Color(1.0, 0.9, 0.3, 1.0)
	]
	material.color = colors[randi() % colors.size()]

	return material

## 更新所有面板
func _update_all_panels() -> void:
	# 更新所有PanelContainer的样式
	var panels = ui_root.find_children("PanelContainer", true, true)
	for panel in panels:
		_update_panel_style(panel)

## 更新面板样式
func _update_panel_style(panel: PanelContainer) -> void:
	var theme_data = THEMES[current_theme]

	# 更新背景样式
	var panel_style = panel.get_theme_stylebox("panel", "")
	if panel_style != null:
		panel_style.bg_color = theme_data["panel_color"]
		panel_style.border_color = theme_data["border_color"]

	# 更新子控件主题
	for child in panel.find_children("*", false, true):
		if child is Control:
			_update_control_theme(child, theme_data)

## 动画完成回调
func _on_animation_completed(animation_name: String) -> void:
	animation_completed.emit(animation_name)

## 设置动画速度
func set_animation_speed(speed: float) -> void:
	animation_config["animation_speed"] = clamp(speed, 0.1, 3.0)

## 设置缓动类型
func set_easing_type(easing: String) -> void:
	match easing:
		"linear":
			animation_config["easing_type"] = "linear"
		"ease_in":
			animation_config["easing_type"] = "ease_in"
		"ease_out":
			animation_config["easing_type"] = "ease_out"
		"ease_in_out":
			animation_config["easing_type"] = "ease_in_out"

## 获取当前主题
func get_current_theme() -> String:
	return current_theme

## 获取所有主题
func get_available_themes() -> Array:
	var themes = []
	for theme_name in THEMES:
		themes.append(THEMES[theme_name]["name"])
	return themes

## 启用/禁用动画
func set_animations_enabled(enabled: bool) -> void:
	animation_config["enable_animations"] = enabled

## 启用/禁用粒子效果
func set_particles_enabled(enabled: bool) -> void:
	animation_config["enable_particles"] = enabled

## 获取美化配置
func get_beautify_config() -> Dictionary:
	return animation_config.duplicate()

## 创建自定义样式
func create_custom_style(style_name: String, style_data: Dictionary) -> StyleBox:
	var style = StyleBoxFlat.new()

	style.bg_color = style_data.get("bg_color", Color(0.2, 0.2, 0.2, 1.0))
	style.corner_radius_top_left = style_data.get("corner_radius", 5)
	style.corner_radius_top_right = style_data.get("corner_radius", 5)
	style.corner_radius_bottom_left = style_data.get("corner_radius", 5)
	style.corner_radius_bottom_right = style_data.get("corner_radius", 5)
	style.border_width_left = style_data.get("border_width", 2)
	style.border_width_top = style_data.get("border_width", 2)
	style.border_width_right = style_data.get("border_width", 2)
	style.border_width_bottom = style_data.get("border_width", 2)
	style.border_color = style_data.get("border_color", Color(0.3, 0.3, 0.3, 1.0))

	return style

## 应用自定义样式到控件
func apply_custom_style(control: Control, style_name: String, style: StyleBox) -> void:
	control.add_theme_stylebox(style_name, "normal", style)

## 创建动画序列
func create_animation_sequence(animations: Array) -> void:
	for anim_data in animations:
		var control = anim_data["control"]
		var animation_type = anim_data["type"]
		var duration = anim_data.get("duration", 0.3)
		var parameters = anim_data.get("parameters", {})

		match animation_type:
		"fade_in":
			fade_in(control, duration)
		"fade_out":
			fade_out(control, duration)
		"slide_in":
			slide_in(control, parameters.get("direction", Vector2.RIGHT), duration)
		"slide_out":
			slide_out(control, parameters.get("direction", Vector2.RIGHT), duration)
		"scale":
			scale_animation(control, parameters.get("scale", Vector2.ONE), duration)
		"rotate":
			rotate_animation(control, parameters.get("rotation", 0.0), duration)
		"bounce":
			bounce_animation(control, duration)
		"shake":
			shake_animation(control, parameters.get("intensity", 5.0), duration)
		"pulse":
			pulse_animation(control, duration)

## 预设动画组合
func play_appear_animation(control: Control) -> void:
	control.scale = Vector2(0.5, 0.5)
	control.modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(control, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_property(control, "modulate:a", 1.0, 0.3)

## 播放消失动画
func play_disappear_animation(control: Control) -> void:
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(control, "scale", Vector2(0.5, 0.5), 0.3)
	tween.tween_property(control, "modulate:a", 0.0, 0.3)

	tween.tween_callback(control.queue_free)# DELAY: 0.3)

## 高亮控件
func highlight_control(control: Control, duration: float = 1.0) -> void:
	var original_style = control.get_theme_stylebox("normal", "normal")

	# 创建高亮样式
	var highlight_style = original_style.duplicate() if original_style != null else StyleBoxFlat.new()
	highlight_style.bg_color = THEMES[current_theme]["accent_color"]
	highlight_style.bg_color.a = 0.3
	highlight_style.border_width_left = 3
	highlight_style.border_color = THEMES[current_theme]["accent_color"]

	control.add_theme_stylebox("normal", "highlight", highlight_style)

	# 添加脉冲动画
	pulse_animation(control, duration)

	# 定时移除高亮（使用 SceneTree.create_timer 无节点泄漏）
	var captured_control = control
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		captured_control.remove_theme_stylebox("normal", "highlight")
	)

## 创建加载动画
func create_loading_animation(parent: Control) -> Control:
	var loading = CenterContainer.new()
	loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox = VBoxContainer.new()
	loading.add_child(vbox)

	# 加载文本
	var label = Label.new()
	label.text = "加载中..."
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", THEMES[current_theme]["text_color"])
	vbox.add_child(label)

	# 加载进度条
	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(200, 20)
	progress_bar.value = 0.0
	vbox.add_child(progress_bar)

	# 有限次循环动画（避免无限 set_loops）
	var tween = create_tween()
	for _i in range(3):
		tween.tween_property(progress_bar, "value", 100.0, 2.0)
		tween.tween_property(progress_bar, "value", 0.0, 2.0)

	parent.add_child(loading)
	return loading

## 移除加载动画
func remove_loading_animation(parent: Control) -> void:
	for child in parent.get_children():
		if child is CenterContainer:
			child.queue_free()
			break

## 获取UI统计
func get_ui_statistics() -> Dictionary:
	return {
		"current_theme": current_theme,
		"animation_config": animation_config,
		"active_animations": active_animations.size(),
		"available_themes": THEMES.size(),
		"effects_enabled": {
			"animations": animation_config["enable_animations"],
			"particles": animation_config["enable_particles"],
			"blur": animation_config["enable_blur"]
		}
	}
