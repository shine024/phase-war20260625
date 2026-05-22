extends Camera2D
## 屏幕震动效果：为战斗提供视觉冲击

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var original_offset: Vector2
var shake_decay: bool = true  # 是否随时间衰减

var _noise: FastNoiseLite = null
var _noise_seed: float = 0.0

func _ready() -> void:
	original_offset = offset

	# 初始化噪声生成器
	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.frequency = 1.0
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_seed = 0.0

func _process(delta: float) -> void:
	if shake_timer < shake_duration:
		shake_timer += delta

		# 使用噪声生成更自然的随机偏移
		_noise_seed += delta * 10.0
		var noise_x = _noise.get_noise_2d(_noise_seed, 0.0)
		var noise_y = _noise.get_noise_2d(0.0, _noise_seed)

		var shake_offset = Vector2(noise_x, noise_y) * shake_intensity

		# 应用衰减
		if shake_decay:
			var decay_factor = 1.0 - (shake_timer / shake_duration)
			shake_offset *= decay_factor

		offset = original_offset + shake_offset
	else:
		offset = original_offset

## 开始震动
func start_shake(intensity: float, duration: float, decay: bool = true) -> void:
	shake_intensity = intensity
	shake_duration = duration
	shake_decay = decay
	shake_timer = 0.0

	# 重新生成噪声种子
	_noise.seed = randi()

## 停止震动
func stop_shake() -> void:
	shake_duration = 0.0
	shake_timer = 0.0
	offset = original_offset

## 静态方法：震动指定相机
static func shake_camera(camera: Camera2D, intensity: float, duration: float, decay: bool = true) -> void:
	if camera and is_instance_valid(camera):
		if camera.has_method("start_shake"):
			camera.start_shake(intensity, duration, decay)

## 轻微震动（击中反馈）
static func light_shake(camera: Camera2D) -> void:
	shake_camera(camera, 2.0, 0.15)

## 中等震动（爆炸反馈）
static func medium_shake(camera: Camera2D) -> void:
	shake_camera(camera, 5.0, 0.3)

## 强烈震动（大爆炸反馈）
static func heavy_shake(camera: Camera2D) -> void:
	shake_camera(camera, 10.0, 0.5)

## 极限震动（Boss死亡等）
static func extreme_shake(camera: Camera2D) -> void:
	shake_camera(camera, 20.0, 0.8)
