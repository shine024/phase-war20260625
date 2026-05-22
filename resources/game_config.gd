extends Resource
class_name GameConfig
## 游戏配置：管理可调节的数值，避免硬编码

## 战斗配置
@export_group("战斗配置")
@export var first_wave_delay: float = 3.0  ## 第一波敌人出现延迟（秒）
@export var default_enemy_wave_interval: float = 12.0  ## 默认敌人生成间隔
@export var player_deploy_cooldown: float = 1.0  ## 玩家部署冷却时间

## 数值平衡
@export_group("数值平衡")
@export var nano_bonus_base: int = 5  ## 纳米基础奖励
@export var nano_bonus_per_level: int = 2  ## 每级额外纳米奖励
@export var blueprint_drop_chance_base: float = 0.15  ## 蓝图基础掉落率
@export var exp_base_amount: int = 10  ## 基础经验值
@export var exp_per_level: int = 5  ## 每级额外经验值

## 相位师配置
@export_group("相位师配置")
@export var phase_master_encounter_chance: float = 0.15  ## 相位师遭遇概率
@export var phase_master_boss_level: int = 49  ## 相位师BOSS关卡

## UI配置
@export_group("UI配置")
@export var save_notification_duration: float = 2.0  ## 存档提示显示时长
@export var error_notification_duration: float = 3.0  ## 错误提示显示时长
@export var animation_default_duration: float = 0.3  ## 默认动画时长

## 性能配置
@export_group("性能配置")
@export var object_pool_size: int = 9  ## 对象池大小
@export var max_particle_effects: int = 50  ## 最大粒子效果数量
@export var target_find_interval: float = 0.3  ## 目标查找间隔（秒）

## 调试配置
@export_group("调试配置")
@export var enable_debug_logs: bool = true  ## 启用调试日志
@export var enable_performance_stats: bool = false  ## 启用性能统计

## 默认配置实例
static var _default_config: GameConfig = null

static func get_default() -> GameConfig:
	if _default_config == null:
		_default_config = GameConfig.new()
		# 设置默认值
		_default_config.first_wave_delay = 3.0
		_default_config.default_enemy_wave_interval = 12.0
		_default_config.player_deploy_cooldown = 1.0
		_default_config.nano_bonus_base = 5
		_default_config.nano_bonus_per_level = 2
		_default_config.blueprint_drop_chance_base = 0.15
		_default_config.exp_base_amount = 10
		_default_config.exp_per_level = 5
		_default_config.phase_master_encounter_chance = 0.15
		_default_config.phase_master_boss_level = 49
		_default_config.save_notification_duration = 2.0
		_default_config.error_notification_duration = 3.0
		_default_config.animation_default_duration = 0.3
		_default_config.object_pool_size = 9
		_default_config.max_particle_effects = 50
		_default_config.target_find_interval = 0.3
		_default_config.enable_debug_logs = true
		_default_config.enable_performance_stats = false

	return _default_config

## 从文件加载配置
static func load_from_file(path: String) -> GameConfig:
	if not FileAccess.file_exists(path):
		push_warning("[GameConfig] 配置文件不存在: %s，使用默认配置" % path)
		return get_default()

	var config = load(path) as GameConfig
	if config == null:
		push_error("[GameConfig] 无法加载配置文件: %s" % path)
		return get_default()

	return config

## 保存配置到文件
func save_to_file(path: String) -> bool:
	var result = ResourceSaver.save(self, path)
	if result != OK:
		push_error("[GameConfig] 无法保存配置到文件: %s，错误代码: %d" % [path, result])
		return false
	return true

## 获取配置值（带默认值）
func get_value(key: String, default_value: Variant = null) -> Variant:
	if not has_method("get"):
		return default_value

	var value = get(key)
	if value == null:
		return default_value

	return value

## 设置配置值
func set_value(key: String, value: Variant) -> void:
	if has_method("set"):
		set(key, value)
	else:
		push_warning("[GameConfig] 无法设置配置值: %s" % key)

## 重置为默认值
func reset_to_defaults() -> void:
	first_wave_delay = 3.0
	default_enemy_wave_interval = 12.0
	player_deploy_cooldown = 1.0
	nano_bonus_base = 5
	nano_bonus_per_level = 2
	blueprint_drop_chance_base = 0.15
	exp_base_amount = 10
	exp_per_level = 5
	phase_master_encounter_chance = 0.15
	phase_master_boss_level = 49
	save_notification_duration = 2.0
	error_notification_duration = 3.0
	animation_default_duration = 0.3
	object_pool_size = 9
	max_particle_effects = 50
	target_find_interval = 0.3
	enable_debug_logs = true
	enable_performance_stats = false
