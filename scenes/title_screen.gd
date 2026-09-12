extends Control
## 开始界面：Sci-Fi 风格的新游戏 / 继续 / 设置 / 退出

## 播放音效（Autoload AudioManager；get_node_or_null 兜底）
func _play_sfx(name: String) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(name)

const PanelStyles = preload("res://scripts/ui/panel_styles.gd")

# 颜色常量
const COLOR_CYAN := Color(0, 0.941, 1)
const COLOR_PURPLE := Color(0.545, 0.361, 0.965)
# 与 DT.COLOR_BG 保持一致（v25 UI 统一底色；本常量当前无消费方，保留防外部引用）
const COLOR_BG := DesignTokens.COLOR_BG

var _tween: Tween
var _scan_line_y: float = 0.0
var _stars: Array = []
var _redraw_acc: float = 0.0  # v27.12: 星空重绘节流累加器（~20fps）
@onready var _title_label: Label = get_node_or_null("CenterContainer/MainVBox/TitleContainer/TitleLabel")


func _ready() -> void:
	# P1-9: 中文字体显式 fallback 链（标题画面也有大量中文文本）
	DesignTokens.ensure_cjk_fallback()
	# v26.11(A2.4): 大字号 UI 缩放启动应用（标题场景面板实例的 _ready 也会应用，
	# 此处兜底覆盖面板懒加载/移除的未来变化）
	var _settings_script := load("res://scenes/ui/settings_panel.gd")
	if _settings_script:
		_settings_script.apply_ui_scale_at_boot()
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
	var cc_btn: Button = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/CombatCheckButton")
	if cc_btn:
		cc_btn.pressed.connect(_on_combat_check)
	# v26.12: 3v3 群战演练入口已从首页移除（场景文件 scenes/tools/combat_arena_3v3.tscn 保留）
	# v26.9: 开发调试按钮仅 debug 构建显示（上架版标题页不应出现开发入口）
	# 覆盖三个：切换存档/战斗效果检查/重看开场(开发,见 _add_replay_intro_button)
	if not OS.is_debug_build():
		for dbn in ["SwitchSlotButton", "CombatCheckButton", "ReplayIntroButton"]:
			var dev_btn: Button = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/" + dbn)
			if dev_btn != null:
				dev_btn.visible = false
	# v21 余烬要塞：基地主枢纽入口（程序化创建，样式复刻继续按钮，插在其下方）
	_add_bunker_button()
	# v26.9: 按钮层级（主操作实心/次操作描边/开发按钮弱化）——统一走 PanelStyles 工厂
	_apply_button_tiers()
	_update_version_label()
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

## v26.9: 标题按钮三层视觉层级——主操作 solid 高亮 / 次操作 ghost / 开发按钮灰弱化
## （颜色走 DT token，样式走 PanelStyles 工厂，圆角档位 6）
func _apply_button_tiers() -> void:
	var vbox := get_node_or_null("CenterContainer/MainVBox/ButtonsVBox")
	if vbox == null:
		return
	var accent: Color = DesignTokens.COLOR_ACCENT_CYAN
	var solid := PanelStyles.make_button_styles(accent, "solid")
	var ghost := PanelStyles.make_button_styles(accent, "ghost")
	var dev_ghost := PanelStyles.make_button_styles(Color(0.55, 0.58, 0.66), "ghost")
	# 主操作：accent 实心 + 深色文字（对比可读）
	for bn in ["NewGameButton", "ContinueButton", "EnterBunkerButton", "EnterTruckBaseButton"]:
		_style_tier_btn(vbox, bn, solid, 20, Color(0.03, 0.10, 0.14), Color(0.03, 0.10, 0.14))
	# 次操作：描边 ghost + 白字/青悬停
	for bn in ["SettingsButton", "QuitButton"]:
		_style_tier_btn(vbox, bn, ghost, 18, Color(1, 1, 1, 0.92), accent)
	# 开发按钮：灰 ghost 弱化（debug 构建才可见）
	for bn in ["SwitchSlotButton", "CombatCheckButton", "ReplayIntroButton"]:
		_style_tier_btn(vbox, bn, dev_ghost, 13, Color(0.62, 0.65, 0.72), Color(0.8, 0.84, 0.9))


func _style_tier_btn(vbox: Node, btn_name: String, styles: Dictionary, font_size: int,
		font_col: Color, hover_col: Color) -> void:
	var b := vbox.get_node_or_null(btn_name) as Button
	if b == null:
		return
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		if styles.has(key):
			b.add_theme_stylebox_override(key, styles[key])
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", font_col)
	b.add_theme_color_override("font_hover_color", hover_col)
	b.add_theme_color_override("font_pressed_color", font_col)
	b.add_theme_color_override("font_focus_color", hover_col)


## v26.9: 版本号统一从工程设置读（project.godot application/config/version）
func _update_version_label() -> void:
	var version_label: Label = get_node_or_null("CenterContainer/MainVBox/VersionLabel")
	if version_label:
		var ver: String = str(ProjectSettings.get_setting("application/config/version", "26.9"))
		version_label.text = "v%s · Construct Era" % ver


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
	# 标题呼吸效果（v26.9: 亮度脉冲——原 scale 脉冲以左上为轴心会左右漂移）
	if _title_label:
		var pulse = 0.92 + 0.08 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0018))
		_title_label.self_modulate = Color(pulse, pulse, pulse, 1.0)

	# 扫描线向下移动
	var vp_h = get_viewport_rect().size.y
	if vp_h > 0:
		_scan_line_y = fmod(_scan_line_y + delta * 80.0, vp_h)

	# 星星闪烁：隔帧重绘，减轻标题界面 GPU/CPU
	# v27.12: 重绘节流到 ~20fps——原每 2 帧 queue_redraw 全量重绘 120 星 + 扫描线；
	# _draw 的星星闪烁/扫描线均按 Time/连续量计算，降频不破坏动画连续性；
	# 上方脉冲与扫描线位移仍每帧更新（连续性变量保留）
	_redraw_acc += delta
	if _redraw_acc >= 0.05:
		_redraw_acc = 0.0
		queue_redraw()

func _update_continue_button(btn: Button) -> void:
	if btn and SaveManager:
		btn.disabled = not SaveManager.has_save_slot(SaveManager.get_slot())

func _on_new_game() -> void:
	_play_sfx("button")
	if SaveManager:
		SaveManager.start_new_game()
	SceneTransition.change(get_tree(), "res://scenes/main.tscn")

func _on_continue() -> void:
	_play_sfx("button")
	if SaveManager:
		# v9.x（P1-4 批次5）：ONE_SHOT 接线——load_game 内若发生备份恢复，信号同步
		# 发出并由 _on_save_restored_from_backup 弹 toast（ToastManager 为懒加载管理器）
		if SignalBus and SignalBus.has_signal("save_restored_from_backup") 				and not SignalBus.save_restored_from_backup.is_connected(_on_save_restored_from_backup):
			SignalBus.save_restored_from_backup.connect(_on_save_restored_from_backup, CONNECT_ONE_SHOT)
		var load_success = SaveManager.load_game()
		if load_success:
			SceneTransition.change(get_tree(), "res://scenes/main.tscn")
		else:
			var toast_mgr = get_node_or_null("/root/ToastManager")
			if toast_mgr and toast_mgr.has_method("show_error"):
				toast_mgr.show_error("存档加载失败，请尝试新建游戏")

## v9.x（P1-4 批次5）：主档损坏经备份恢复——ToastManager 是懒加载管理器，先 ensure 再弹
func _on_save_restored_from_backup(_slot: int) -> void:
	ManagerLazyLoader.ensure_loaded("toast")
	var toast_mgr = get_node_or_null("/root/ToastManager")
	if toast_mgr and toast_mgr.has_method("show_warning"):
		toast_mgr.show_warning("检测到存档损坏，已自动从备份恢复")

func _on_settings() -> void:
	_play_sfx("button")
	var overlay := get_node_or_null("SettingsOverlay") as CanvasLayer
	var cc := overlay.get_node_or_null("CenterContainer") as Control if overlay else null
	if overlay and cc:
		# 批次1：收口统一开合（原 visible 硬切无声，与主场景面板行为不一）。
		# SettingsOverlay 是 CanvasLayer——走 layer 适配（内容淡入弹出 + Dim 同步）。
		PanelAnim.open_layer(overlay, cc, overlay.get_node_or_null("Dim"))
		_play_sfx("panel_open")

## v21 余烬要塞：程序化添加"进入基地"按钮（复刻继续按钮样式，插在其下方第一位）
func _add_bunker_button() -> void:
	var vbox = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox")
	if vbox == null:
		return
	if vbox.has_node("EnterBunkerButton"):
		return
	var continue_btn: Button = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox/ContinueButton")
	var btn := Button.new()
	btn.name = "EnterBunkerButton"
	btn.text = "进入基地"
	# v26.12d：固定主基地停用（移动基地接管，入口保留随时可恢复=删掉下面一行）
	btn.visible = false
	if continue_btn:
		# 样式全盘复刻继续按钮（tscn 内嵌 StyleBoxFlat 三态）
		for style_key in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb: StyleBox = continue_btn.get_theme_stylebox(style_key)
			if sb:
				btn.add_theme_stylebox_override(style_key, sb)
		btn.add_theme_font_size_override("font_size",
			continue_btn.get_theme_font_size("font_size"))
		btn.custom_minimum_size = continue_btn.custom_minimum_size
	btn.pressed.connect(_on_enter_bunker)
	vbox.add_child(btn)
	var insert_idx := 0
	if continue_btn:
		insert_idx = continue_btn.get_index() + 1
	vbox.move_child(btn, insert_idx)
	_add_mobile_base_button(btn)


## v26.12：程序化添加"移动基地"按钮（插在进入基地下方，样式同源）——卡车剖面驻地入口
func _add_mobile_base_button(style_source: Button) -> void:
	var vbox = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox")
	if vbox == null or vbox.has_node("EnterTruckBaseButton"):
		return
	var btn := Button.new()
	btn.name = "EnterTruckBaseButton"
	btn.text = "移动基地"
	for style_key in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = style_source.get_theme_stylebox(style_key)
		if sb:
			btn.add_theme_stylebox_override(style_key, sb)
	btn.add_theme_font_size_override("font_size",
		style_source.get_theme_font_size("font_size"))
	btn.custom_minimum_size = style_source.custom_minimum_size
	btn.pressed.connect(_on_enter_truck_base)
	vbox.add_child(btn)
	vbox.move_child(btn, style_source.get_index() + 1)
	_add_replay_intro_button(btn)


## v26.12：进入移动基地（卡车剖面驻地视觉壳 MVP）
## v27.13：与旧 bunker 链同构的档位保障——无档开新档先播开场漫画（12 格 + 雪原醒来
## 演出在 truck_base 内播）；有档读档，comic_seen 未落档的老档自动补播一次。
func _on_enter_truck_base() -> void:
	_play_sfx("button")
	if SaveManager:
		if SaveManager.has_save_slot(SaveManager.get_slot()):
			SaveManager.load_game()
			SaveManager.flush_deferred_manager_loads()
			var bunker: Node = get_node_or_null("/root/BunkerManager")
			if bunker == null or not bunker.is_comic_seen():
				Engine.set_meta("bunker_intro_comic_pending", true)
				SceneTransition.change(get_tree(), "res://scenes/intro/comic_intro.tscn")
				return
		else:
			SaveManager.start_new_game()
			Engine.set_meta("bunker_intro_comic_pending", true)
			SceneTransition.change(get_tree(), "res://scenes/intro/comic_intro.tscn")
			return
	SceneTransition.change(get_tree(), "res://scenes/bunker/truck_base.tscn")

## v24.5：开发预览"重看开场"——带 comic pending 直播开场，不改存档进度
## v26.9: 仅 debug 构建创建（上架版不出现该按钮）
func _add_replay_intro_button(style_source: Button) -> void:
	if not OS.is_debug_build():
		return
	var vbox = get_node_or_null("CenterContainer/MainVBox/ButtonsVBox")
	if vbox == null or vbox.has_node("ReplayIntroButton"):
		return
	var btn := Button.new()
	btn.name = "ReplayIntroButton"
	btn.text = "重看开场（开发）"
	for style_key in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBox = style_source.get_theme_stylebox(style_key)
		if sb:
			btn.add_theme_stylebox_override(style_key, sb)
	btn.add_theme_font_size_override("font_size",
		style_source.get_theme_font_size("font_size"))
	btn.custom_minimum_size = style_source.custom_minimum_size
	btn.pressed.connect(_on_replay_intro)
	vbox.add_child(btn)

func _on_replay_intro() -> void:
	_play_sfx("button")
	if SaveManager:
		if SaveManager.has_save_slot(SaveManager.get_slot()):
			SaveManager.load_game()
		else:
			SaveManager.start_new_game()
	Engine.set_meta("bunker_intro_comic_pending", true)
	SceneTransition.change(get_tree(), "res://scenes/intro/comic_intro.tscn")

## v21 余烬要塞：进入基地主枢纽（BunkerManager 懒加载后常驻 root，状态跨场景保留）
func _on_enter_bunker() -> void:
	_play_sfx("button")
	# v22.1 修复（用户 2026-08-28 报告"进基地相位仪空/卡空/无法进战斗"）：
	# 此前直接切场景——不读档也不开新档，重启游戏后点此按钮内存里什么都没初始化，
	# 基地呈全空状态（绿槽 0 卡/实例 0/符文 0/作战室锁死）。
	# 现在与"继续"对齐：有档读档（基地状态随 SK_BUNKER 段恢复）；
	# 无档自动开新档（starter 三角卡预装备/符文/起步资源全走 start_new_game 正规链）。
	if SaveManager:
		if SaveManager.has_save_slot(SaveManager.get_slot()):
			SaveManager.load_game()
			# v24.5 修复（用户报告"有旧存档看不到开始剧情"）：开场门控从"有无存档"
			# 改为 BunkerManager.comic_seen 落档标志——v24 之前的老档没有该标志，
			# 下次进基地自动补播一次开场（看完由 bunker 醒来演出落档，不重复）。
			# v24.5 修复二：BunkerManager 非 autoload（ManagerLazyLoader 懒加载常驻
			# /root/BunkerManager），不能当全局标识符裸用；且其存档恢复在 SaveManager
			# 延迟批次（call_deferred），按钮回调栈内尚未执行——必须先同步排空，
			# 否则 comic_seen 恒为默认 false，开场漫画每次进基地都重播。
			SaveManager.flush_deferred_manager_loads()
			var bunker: Node = get_node_or_null("/root/BunkerManager")
			if bunker == null or not bunker.is_comic_seen():
				Engine.set_meta("bunker_intro_comic_pending", true)
				SceneTransition.change(get_tree(), "res://scenes/intro/comic_intro.tscn")
				return
		else:
			# v24（开场剧情）：新档先播漫画序章（B1–B7 分格，docs/开场剧情_10方案.md 方案1），
			# 播完携 wakeup 标记切 bunker_main 播醒来演出（B8，方案9）；有档直进不重播。
			SaveManager.start_new_game()
			Engine.set_meta("bunker_intro_comic_pending", true)
			SceneTransition.change(get_tree(), "res://scenes/intro/comic_intro.tscn")
			return
	# v6.14：入口对齐现役移动基地（按钮 v26.12d 起隐藏，此处为可达性兜底/随时可恢复的
	# 路径真身——旧固定基地 bunker_main 已停用，勿再指回）
	SceneTransition.change(get_tree(), "res://scenes/bunker/truck_base.tscn")


func _on_settings_closed() -> void:
	var overlay := get_node_or_null("SettingsOverlay") as CanvasLayer
	var cc := overlay.get_node_or_null("CenterContainer") as Control if overlay else null
	if overlay and cc:
		PanelAnim.close_layer(overlay, cc, overlay.get_node_or_null("Dim"))
		_play_sfx("panel_close")

## 切换存档位
func _on_switch_slot() -> void:
	if not SaveManager:
		return
	var current: int = SaveManager.get_slot()
	var next_slot: int = current + 1
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


## 进入战斗效果检查场（独立测试场景，复用项目真实战斗效果）
func _on_combat_check() -> void:
	SceneTransition.change(get_tree(), "res://scenes/tools/combat_check.tscn")


func _on_quit() -> void:
	_play_sfx("button")
	# v26.11(A2.3): 退出确认（原直接 quit——存档虽有自动保存双保险，加一道确认防误点）
	# v6.14 勘误：Godot 4.5.1 的 SceneTree 无 about_to_quit 信号（实测信号表无此项），
	# save_manager/debug_log_manager 的 about_to_quit 连接从未生效——程序化退出路径
	# 在此显式收尾存档（此刻全部 manager 仍在树上，晚于退树钩子的安全窗口）。
	var dialog := ConfirmationDialog.new()
	dialog.title = "退出游戏"
	dialog.dialog_text = "确认退出 相位战争？"
	dialog.ok_button_text = "退出"
	dialog.cancel_button_text = "取消"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var sm := get_node_or_null("/root/SaveManager")
		if sm != null and sm.has_method("save_game"):
			sm.call("save_game")
		get_tree().quit())
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

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
