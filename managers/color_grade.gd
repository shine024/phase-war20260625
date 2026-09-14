extends CanvasLayer
## ColorGrade 全局调色后期层（v28 质感轮 T1）
## 全屏 ColorRect + shaders/color_grade.gdshader，把"统一摄影层"罩在所有画面之上：
## 饱和度 / S 曲线对比 / 时代色温（阴影-高光分离色调）/ 暗角 / 抑带颗粒。
## 切换链路：SignalBus.battle_started → 按关卡时代选预设；battle_ended → 2s 后回 neutral
## （结算面板期间保持时代色，进地图/标题即中性）。layer=1000 罩住含 Popup 在内的一切，
## 参数调得足够轻，不伤文字可读性；不拦鼠标。
## 总开关 GameConfig.color_grade_enabled；A/B 截图对比用环境变量 PW_GRADE_OFF=1 整层旁路。

const SHADER := preload("res://shaders/color_grade.gdshader")
const GameConfigScript = preload("res://resources/game_config.gd")
const LevelErasData = preload("res://data/level_eras.gd")

## 预设表：键=shader uniform 名。era1-5 对应五时代色温方向：
## 一战泥黄做旧 / 二战冷灰钢蓝 / 冷战青蓝 / 现代中性偏净 / 近未来靛紫霓虹。
const PRESETS: Dictionary = {
	"neutral": {
		"saturation": 1.06, "contrast": 1.04, "brightness": 1.0,
		"shadow_tint": Vector3(1.0, 0.99, 0.97), "highlight_tint": Vector3(1.0, 1.0, 1.0),
		"tint_balance": 0.25, "vignette_strength": 0.10, "grain_amount": 0.010,
	},
	"era1": {
		"saturation": 1.02, "contrast": 1.08, "brightness": 1.0,
		"shadow_tint": Vector3(0.72, 0.62, 0.50), "highlight_tint": Vector3(1.05, 0.99, 0.88),
		"tint_balance": 0.50, "vignette_strength": 0.20, "grain_amount": 0.012,
	},
	"era2": {
		"saturation": 0.99, "contrast": 1.08, "brightness": 1.0,
		"shadow_tint": Vector3(0.80, 0.82, 0.88), "highlight_tint": Vector3(1.0, 0.99, 0.94),
		"tint_balance": 0.45, "vignette_strength": 0.18, "grain_amount": 0.011,
	},
	"era3": {
		"saturation": 1.06, "contrast": 1.07, "brightness": 1.0,
		"shadow_tint": Vector3(0.72, 0.82, 0.92), "highlight_tint": Vector3(0.98, 1.02, 1.05),
		"tint_balance": 0.45, "vignette_strength": 0.17, "grain_amount": 0.010,
	},
	"era4": {
		"saturation": 1.07, "contrast": 1.06, "brightness": 1.0,
		"shadow_tint": Vector3(0.88, 0.90, 0.95), "highlight_tint": Vector3(1.0, 1.0, 1.02),
		"tint_balance": 0.35, "vignette_strength": 0.14, "grain_amount": 0.008,
	},
	"era5": {
		"saturation": 1.12, "contrast": 1.07, "brightness": 1.0,
		"shadow_tint": Vector3(0.78, 0.80, 1.00), "highlight_tint": Vector3(1.02, 0.98, 1.06),
		"tint_balance": 0.45, "vignette_strength": 0.15, "grain_amount": 0.008,
	},
}

var _rect: ColorRect
var _mat: ShaderMaterial
var _tween: Tween
var _apply_gen := 0  ## 每次应用自增；battle_ended 的延迟回调按代号失效，防止新开局被旧回退踩掉
var _cb_mode := 0  ## R6-1 色盲辅助档（0关/1protan/2deutan/3tritan）——独立于调色预设，_apply 不触碰


func _ready() -> void:
	layer = 1000
	_rect = ColorRect.new()
	_rect.name = "GradeRect"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	# R6-1：色盲辅助档从设置读（settings.cfg 与设置面板同源；面板运行时改走 set_color_blind_mode）
	_cb_mode = _load_cb_mode_from_settings()
	_mat.set_shader_parameter("color_blind_mode", float(_cb_mode))
	if not _grade_on():
		_mat.set_shader_parameter("enabled", 0.0)
	else:
		_apply("neutral", 0.0)
	SignalBus.battle_started.connect(_on_battle_started)
	SignalBus.battle_ended.connect(_on_battle_ended)


## R6-1（F-18 可及性）：色盲辅助档切换（0关/1protan/2deutan/3tritan）
func set_color_blind_mode(mode: int) -> void:
	_cb_mode = clampi(mode, 0, 3)
	_mat.set_shader_parameter("color_blind_mode", float(_cb_mode))

func get_color_blind_mode() -> int:
	return _cb_mode

static func _load_cb_mode_from_settings() -> int:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return 0
	return clampi(int(cfg.get_value("settings", "color_blind_mode", 0)), 0, 3)


## 对外显式切换入口（菜单/特殊场景将来要钉死色温时用；当前链路全走信号自动切换）
func set_preset(preset: String, duration := 0.9) -> void:
	if not PRESETS.has(preset):
		push_warning("[ColorGrade] 未知预设: %s" % preset)
		return
	if not _grade_on():
		return
	_apply(preset, duration)


func _grade_on() -> bool:
	if OS.get_environment("PW_GRADE_OFF") == "1":
		return false
	return bool(GameConfigScript.get_default().color_grade_enabled)


func _apply(key: String, duration: float) -> void:
	_apply_gen += 1
	var p: Dictionary = PRESETS[key]
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0:
		for k in p:
			_mat.set_shader_parameter(k, p[k])
		return
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_SINE)
	for k in p:
		_tween.tween_property(_mat, "shader_parameter/" + k, p[k], duration)


func _on_battle_started() -> void:
	if not _grade_on():
		return
	var lvl := 1
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		lvl = int(gm.get("current_level"))
	var era := clampi((lvl - 1) / LevelErasData.ERA_LEVELS, 0, 4)
	_apply("era%d" % (era + 1), 1.2)


func _on_battle_ended(_player_won: bool) -> void:
	if not _grade_on():
		return
	var gen := _apply_gen
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if gen == _apply_gen:
			_apply("neutral", 1.4))
