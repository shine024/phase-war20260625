extends PanelContainer
## 设置面板：主音量、全屏，设置持久化到 user://settings.cfg

signal closed()

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

@onready var _master_slider: HSlider = get_node_or_null("Margin/VBox/MasterVolumeRow/MasterSlider")
@onready var _fullscreen_check: CheckButton = get_node_or_null("Margin/VBox/FullscreenRow/FullscreenCheck")
@onready var _close_btn: Button = get_node_or_null("Margin/VBox/CloseButton")

func _ready() -> void:
	_load_and_apply()
	if _master_slider:
		_master_slider.value_changed.connect(_on_master_changed)
	if _fullscreen_check:
		_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if _close_btn:
		_close_btn.pressed.connect(_on_close)

func _load_and_apply() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		_apply_volume(1.0)
		_apply_fullscreen(false)
		return
	var vol: float = cfg.get_value(SECTION, "master_volume", 1.0)
	var fs: bool = cfg.get_value(SECTION, "fullscreen", false)
	if _master_slider != null:
		_master_slider.value = vol
	if _fullscreen_check != null:
		_fullscreen_check.button_pressed = fs
	_apply_volume(vol)
	_apply_fullscreen(fs)

func _apply_volume(linear: float) -> void:
	# 0..1 -> -40 dB (mute) .. 0 dB
	var db: float = linear * linear
	db = db * 40.0 - 40.0
	if db < -40.0:
		db = -80.0
	AudioServer.set_bus_volume_db(0, db)

func _apply_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_master_changed(value: float) -> void:
	_apply_volume(value)
	_save()

func _on_fullscreen_toggled(enabled: bool) -> void:
	_apply_fullscreen(enabled)
	_save()

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", _master_slider.value if _master_slider else 1.0)
	cfg.set_value(SECTION, "fullscreen", _fullscreen_check.button_pressed if _fullscreen_check else false)
	cfg.save(SETTINGS_PATH)

func _on_close() -> void:
	visible = false
	closed.emit()
