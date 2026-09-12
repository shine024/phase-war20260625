extends PanelContainer
## 设置面板 v7.x(A2)：音量分轨 + 难度 + 全屏 + 可访问性（高对比/大字号/减少动效）
## 持久化到 user://settings.cfg。向后兼容旧配置（缺省键自动用默认值）。

signal closed()

const DT = preload("res://resources/design_tokens.gd")
const PanelStyles = preload("res://scripts/ui/panel_styles.gd")
const PanelChrome = preload("res://scenes/ui/components/panel_chrome.gd")

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

# v7.x(A4): 难度档位与 GameConstants.DIFFICULTY_MULTIPLIERS 对齐。
# OptionButton 用 index 0/1/2 → easy/normal/hard。
const _DIFFICULTY_IDS := ["easy", "normal", "hard"]
const _DEFAULT_DIFFICULTY_IDX := 1

@onready var _master_slider: HSlider = get_node_or_null("Margin/VBoxMain/Scroll/VBox/MasterVolumeRow/MasterSlider")
@onready var _sfx_slider: HSlider = get_node_or_null("Margin/VBoxMain/Scroll/VBox/SfxVolumeRow/SfxSlider")
@onready var _bgm_slider: HSlider = get_node_or_null("Margin/VBoxMain/Scroll/VBox/BgmVolumeRow/BgmSlider")
@onready var _difficulty_option: OptionButton = get_node_or_null("Margin/VBoxMain/Scroll/VBox/DifficultyRow/DifficultyOption")
@onready var _fullscreen_check: CheckButton = get_node_or_null("Margin/VBoxMain/Scroll/VBox/FullscreenRow/FullscreenCheck")
@onready var _hc_check: CheckButton = get_node_or_null("Margin/VBoxMain/Scroll/VBox/HighContrastRow/HighContrastCheck")
@onready var _lt_check: CheckButton = get_node_or_null("Margin/VBoxMain/Scroll/VBox/LargeTypeRow/LargeTypeCheck")
@onready var _mr_check: CheckButton = get_node_or_null("Margin/VBoxMain/Scroll/VBox/MotionReduceRow/MotionReduceCheck")
@onready var _reset_tutorial_button: Button = get_node_or_null("Margin/VBoxMain/Scroll/VBox/TutorialRow/ResetTutorialButton")
@onready var _content_vbox: VBoxContainer = get_node_or_null("Margin/VBoxMain")


func _ready() -> void:
	# v7.x 面板统一：中性冷灰蓝签名框架 + PanelChrome 标题栏（右上 ✕ 关闭）
	var accent := DT.get_panel_accent("settings")
	add_theme_stylebox_override("panel", PanelStyles.make_panel_frame_textured(accent))
	if _content_vbox:
		var chrome = PanelChrome.attach_to(_content_vbox, "设置", accent, "系统设置")
		chrome.closed.connect(_on_close)
	_load_and_apply()
	# 音频
	if _master_slider:
		_master_slider.value_changed.connect(_on_master_changed)
	if _sfx_slider:
		_sfx_slider.value_changed.connect(_on_sfx_changed)
	if _bgm_slider:
		_bgm_slider.value_changed.connect(_on_bgm_changed)
	# 难度
	if _difficulty_option:
		_difficulty_option.item_selected.connect(_on_difficulty_changed)
	# 显示
	if _fullscreen_check:
		_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	# 可访问性
	if _hc_check:
		_hc_check.toggled.connect(_on_accessibility_changed)
	if _lt_check:
		_lt_check.toggled.connect(_on_accessibility_changed)
	if _mr_check:
		_mr_check.toggled.connect(_on_accessibility_changed)
	# 游戏：教程重置（v26.9 A1.4，接活 TutorialProgressionManager.reset_tutorial）
	if _reset_tutorial_button:
		_reset_tutorial_button.pressed.connect(_on_reset_tutorial_pressed)


func _load_and_apply() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	# 默认值（旧配置缺这些键时自动回退，零破坏）
	var master: float = 1.0
	var sfx: float = 1.0
	var bgm: float = 0.7
	var fullscreen: bool = false
	var diff_idx: int = _DEFAULT_DIFFICULTY_IDX
	var hc: bool = false
	var lt: bool = false
	var mr: bool = false
	if err == OK:
		master = cfg.get_value(SECTION, "master_volume", master)
		sfx = cfg.get_value(SECTION, "sfx_volume", sfx)
		bgm = cfg.get_value(SECTION, "bgm_volume", bgm)
		fullscreen = cfg.get_value(SECTION, "fullscreen", fullscreen)
		diff_idx = cfg.get_value(SECTION, "difficulty_idx", diff_idx)
		hc = cfg.get_value(SECTION, "high_contrast", hc)
		lt = cfg.get_value(SECTION, "large_type", lt)
		mr = cfg.get_value(SECTION, "motion_reduce", mr)
	diff_idx = clampi(diff_idx, 0, _DIFFICULTY_IDS.size() - 1)
	# 回填控件
	if _master_slider != null:
		_master_slider.value = master
	if _sfx_slider != null:
		_sfx_slider.value = sfx
	if _bgm_slider != null:
		_bgm_slider.value = bgm
	if _difficulty_option != null:
		_difficulty_option.selected = diff_idx
	if _fullscreen_check != null:
		_fullscreen_check.button_pressed = fullscreen
	if _hc_check != null:
		_hc_check.button_pressed = hc
	if _lt_check != null:
		_lt_check.button_pressed = lt
	if _mr_check != null:
		_mr_check.button_pressed = mr
	# 应用
	_apply_master(master)
	_apply_sfx(sfx)
	_apply_bgm(bgm)
	_apply_fullscreen(fullscreen)
	_apply_accessibility(hc, lt, mr)


# ===== 音频 =====
# v7.x(A2): 主音量改走 AudioManager.set_master_volume（统一入口，消除原 _apply_volume
# 直接操 AudioServer 的双路径冲突）。
func _apply_master(linear: float) -> void:
	if AudioManager != null:
		AudioManager.set_master_volume(linear)
	else:
		# AudioManager 尚未就绪时的兜底（标题屏极早期）
		var db: float = linear * linear * 40.0 - 40.0
		if db < -40.0:
			db = -80.0
		AudioServer.set_bus_volume_db(0, db)

func _apply_sfx(linear: float) -> void:
	if AudioManager != null:
		AudioManager.set_sfx_volume(linear)

func _apply_bgm(linear: float) -> void:
	# v26.11(A2.4): 接通 set_music_volume——实时作用于当前播放曲目（原实现只写
	# music_volume 字段，拖滑杆要等下一次切歌才生效；旧注释"当前无 BGM 播放器"
	# 已过时：8 首 BGM 资产在库，AudioManager 启动即播）。
	if AudioManager != null and AudioManager.has_method("set_music_volume"):
		AudioManager.set_music_volume(clamp(linear, 0.0, 1.0))
	elif AudioManager != null and "music_volume" in AudioManager:
		AudioManager.music_volume = clamp(linear, 0.0, 1.0)

func _on_master_changed(value: float) -> void:
	_apply_master(value)
	_save()

func _on_sfx_changed(value: float) -> void:
	_apply_sfx(value)
	_save()

func _on_bgm_changed(value: float) -> void:
	_apply_bgm(value)
	_save()


# ===== 难度 =====
func _on_difficulty_changed(index: int) -> void:
	_save()

# v7.x(A4): 供 GameManager 读取当前难度档位字符串（"easy"/"normal"/"hard"）。
func get_difficulty() -> String:
	var idx := _DEFAULT_DIFFICULTY_IDX
	if _difficulty_option != null:
		idx = _difficulty_option.selected
	return _DIFFICULTY_IDS[clampi(idx, 0, _DIFFICULTY_IDS.size() - 1)]

# 从配置文件读难度（不依赖面板已实例化，供 GameManager 在战斗启动时读取）。
static func load_difficulty() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return "normal"
	var idx: int = cfg.get_value(SECTION, "difficulty_idx", _DEFAULT_DIFFICULTY_IDX)
	idx = clampi(idx, 0, _DIFFICULTY_IDS.size() - 1)
	return _DIFFICULTY_IDS[idx]


# ===== 显示 =====
func _apply_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_fullscreen_toggled(enabled: bool) -> void:
	_apply_fullscreen(enabled)
	_save()


# ===== 可访问性 =====
func _apply_accessibility(hc: bool, lt: bool, mr: bool) -> void:
	# v7.x(A3): 经 DesignTokens 静态 API 切换，并由 SignalBus.accessibility_changed
	# 广播给已打开的血条/能量条等即时重绘。
	DT.set_accessibility(hc, lt, mr)
	_apply_ui_scale(lt)

# v26.11(A2.4): 大字号真实生效——content_scale_factor 全局放大界面（项目为
# canvas_items 拉伸模式，1.25 = UI 整体放大 25%）。此前 is_large_type 全项目零
# 消费方、勾选后游戏内纹丝不动，属"承诺未兑现"开关；本修复后即时生效。
func _apply_ui_scale(large_type: bool) -> void:
	var vp := get_tree().root
	if vp != null:
		vp.content_scale_factor = 1.25 if large_type else 1.0

# v26.11(A2.4): 启动时应用大字号缩放（settings 面板未实例化也要生效）。
# 由 title_screen._ready 调用（入口场景，任何路径都先经过）。
static func apply_ui_scale_at_boot() -> void:
	var lt := false
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		lt = cfg.get_value(SECTION, "large_type", false)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = 1.25 if lt else 1.0

func _on_accessibility_changed(_toggled: bool) -> void:
	var hc: bool = _hc_check.button_pressed if _hc_check else false
	var lt: bool = _lt_check.button_pressed if _lt_check else false
	var mr: bool = _mr_check.button_pressed if _mr_check else false
	_apply_accessibility(hc, lt, mr)
	_save()


# ===== 教程重置（v26.9 A1.4）=====
func _on_reset_tutorial_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "重置新手引导"
	var step_count := 0
	var tm := get_node_or_null("/root/TutorialProgressionManager")
	if tm and "STEP_ORDER" in tm:
		step_count = tm.STEP_ORDER.size()
	dialog.dialog_text = "将清空当前教学进度，重新播放 %d 步新手引导。\n确认重置？" % step_count
	dialog.ok_button_text = "重置"
	dialog.cancel_button_text = "取消"
	add_child(dialog)
	dialog.confirmed.connect(_do_reset_tutorial)
	# 关闭即自清理（confirmed / canceled 两条路径都覆盖）
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _do_reset_tutorial() -> void:
	var tm := get_node_or_null("/root/TutorialProgressionManager")
	if tm == null or not tm.has_method("reset_tutorial"):
		SignalBus.show_toast.emit("⚠ 教程管理器不可用，重置失败")
		return
	tm.reset_tutorial()
	SignalBus.show_toast.emit("🎓 新手引导已重置")
	# 主场景在场则立即拉起教程覆盖层（镜像 _start_tutorial_if_needed 的推进副作用）；
	# 在标题屏重置则等下次进入主界面自然触发（current_step==NONE 守卫放行）。
	var main_scene := get_node_or_null("/root/Main")
	if main_scene and main_scene.has_method("_show_tutorial_overlay"):
		if tm.has_method("get_tutorial_content"):
			tm.get_tutorial_content()  # 副作用：NONE → INTRO_WELCOME
		main_scene._show_tutorial_overlay()


# ===== 持久化 =====
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", _master_slider.value if _master_slider else 1.0)
	cfg.set_value(SECTION, "sfx_volume", _sfx_slider.value if _sfx_slider else 1.0)
	cfg.set_value(SECTION, "bgm_volume", _bgm_slider.value if _bgm_slider else 0.7)
	cfg.set_value(SECTION, "fullscreen", _fullscreen_check.button_pressed if _fullscreen_check else false)
	cfg.set_value(SECTION, "difficulty_idx", _difficulty_option.selected if _difficulty_option else _DEFAULT_DIFFICULTY_IDX)
	cfg.set_value(SECTION, "high_contrast", _hc_check.button_pressed if _hc_check else false)
	cfg.set_value(SECTION, "large_type", _lt_check.button_pressed if _lt_check else false)
	cfg.set_value(SECTION, "motion_reduce", _mr_check.button_pressed if _mr_check else false)
	cfg.save(SETTINGS_PATH)


func _on_close() -> void:
	visible = false
	closed.emit()
