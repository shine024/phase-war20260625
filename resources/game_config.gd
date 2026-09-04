extends Resource
class_name GameConfig
## 游戏配置：管理可调节的数值，避免硬编码
## v26.4 收敛：15 个零消费字段（first_wave_delay/nano_bonus_*/exp_*/blueprint_drop_*/
## phase_master_encounter_chance/save_notification_duration 等旧经济/UI/性能旋钮）与
## 4 个零调用方法（load_from_file/save_to_file/get_value/set_value）已删，git 历史可查。
## 存活字段必须至少有一个真实消费点（见各注释）；新增字段记得同步 reset_to_defaults()。

## 战斗配置
@export_group("战斗配置")
@export var cross_row_direct_damage_mult: float = 0.70  ## v9.x: 直射武器跨行射击伤害乘区（同行全额；曲射/空射全场全额不受行约束）。消费点 card_grid_battle_layout.gd
## v21 P0: 光环范围化总开关——true=战术光环（医疗/侦查/雷达/堡垒/改造光环）按槽距范围生效，
## 指挥/载具维修恒全场；false=完整回退 v6.2 全场广播行为（判定函数短路 true）。消费点 aura_data.is_in_aura_range
@export var aura_range_enabled: bool = true
## v26.2: 战斗环境效果总开关——true=天气/地形/能量场/时段按 BattleEnvEffects 表生效
## （敌我对称，乘在 stats 构建层）；false=四维回归纯展示标签（v26.1 前行为）。消费点 battle_env_effects.enabled()
@export var env_effects_enabled: bool = true
## v26.2: 每关布局表总开关——true=LevelBattleLayouts 显式配置的关卡用专属棋盘
## （行数/敌我列数/废墟格），其余关默认 3×3；false=全部关卡 3×3（v26.1 前行为）。消费点 card_grid_battle_layout
@export var battle_layouts_enabled: bool = true
## v26.x: 改造模块消耗品化总开关——true=安装改造消耗 1 张对应图纸（blueprint_<mod_id>，
## IntelItemBag 库存）+ 纳米费；false=图纸只验持有不消耗（旧"永久解锁"行为）。
## 消费点 blueprint_manager.install_modification
@export var mod_consumable_enabled: bool = true

## 调试配置
@export_group("调试配置")
## v8.x 测试开关：true = 去掉部署的兵种类/数目限制（无视 restrict_platforms 白名单、
## 同卡存活上限、总数/绿槽数上限），方便测试阶段自由放兵。默认 false（生产零影响）。
## 注意：物理格子上限（6 个可点击位置）不受此开关影响，仍由 BattleSlotGrid 决定。
@export var debug_no_deploy_limits: bool = false
## v26.11(A3): 测试模式蓝图全送开关——true = 新游戏开局发放全部改造+进化蓝图（原 save_manager
## 裸代码块"上线前需改回"的门控化，开发/测试想全开时手动置 true）；false = 正式行为
## （仅 7 张起步图纸，其余靠战斗掉落逐步解锁）。消费点 save_manager 新档初始蓝图发放段
@export var debug_grant_all_blueprints: bool = false

## 默认配置实例
static var _default_config: GameConfig = null

static func get_default() -> GameConfig:
	if _default_config == null:
		# 默认值以 @export 初始值为单一来源（v26.4 起不再在此重复抄写）
		_default_config = GameConfig.new()
	return _default_config

## 重置为默认值
func reset_to_defaults() -> void:
	cross_row_direct_damage_mult = 0.70  # P0-5 修复：v9.x 字段此前漏重置
	# v26.4 修复：v21/v26 三个总开关此前漏重置
	aura_range_enabled = true
	env_effects_enabled = true
	battle_layouts_enabled = true
	mod_consumable_enabled = true
	debug_no_deploy_limits = false  # P0-5 修复：测试开关此前漏重置
	debug_grant_all_blueprints = false
