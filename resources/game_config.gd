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
## v27.x: 星冥武器专属 VFX 总开关——true=星冥 20 武器名（xeno_weapon_flavor 精确表）
## 走紫青专属开火/弹道/命中视觉（近战刃光/灵能放电/能量爆炸帧）；false=全部消费方
## （bullet/三 batch/命中分派/枪口反馈）短路回人类通用视觉（星冥武器蹭既有 wt 族）。
## 消费点 weapon_visual_profiles 之外的全部 XenoWeaponFlavor 分支（解析层无开关，纯数据）
@export var xeno_vfx_enabled: bool = true
## v28 质感轮 T1: 全局调色后期层总开关——true=ColorGrade 预设（时代色温/对比/暗角）全屏生效；
## false=整层旁路（shader enabled=0，零后处理）。消费点 managers/color_grade.gd
@export var color_grade_enabled: bool = true
## v28 质感轮 T3: 战场地面 dressing 总开关——true=弹坑/碎石/履带印/枯草撒点（纯视觉）；
## false=不撒（回退干净地板）。消费点 scripts/battle/ground_dressing.gd
@export var ground_dressing_enabled: bool = true
## v34 渐进解锁门控总开关——true=系统入口按 data/feature_unlock_schedule.gd 节奏表
## 随通关解锁（开局只留核心入口）；false=全量敞开（v34 前行为，一键回退）。
## 消费点 level_progress_manager.is_feature_unlocked 及其三个入口层消费方
@export var feature_gates_enabled: bool = true
## v36 精神同调战力门总开关——true=部署链按相位师可运用战力上限拦卡（技能树
## 精神同调链提升上限）；false=不设上限（v36 前行为，一键回退）。
## 消费点 battle_spawn_system.request_player_deploy
@export var power_cap_enabled: bool = true
## v6.16 攻速断点阶梯总开关——true=攻速改造聚合增益跨档（20/40/70/110%）时按
## 档位跳变（额外提速 + 首弹蓄力削减，data/mod_breakpoints.gd）；false=连续乘区
## （v6.16 前行为）。消费点 unit_stats_table._sync_mod_speed_ratio_to_weapon_slots
@export var mod_breakpoints_enabled: bool = true
## v6.16 改造槽位预算总开关——true=槽位=品质基础槽（common5~mythic10）+兵种专属
## 槽（+1，堡垒+2），通用件只占基础槽（ModManager.get_max_mod_slots_for_card）；
## false=全卡恒 9 槽（v6.16 前行为，一键回退）。消费点 card_resource.can_install_modification
@export var mod_slot_budget_enabled: bool = true
## v6.17 命中光学层批：战场泛光总开关——true=battlefield 挂 WorldEnvironment glow
## （配 project.godot viewport/hdr_2d，VFX 发光体 modulate>1 过 bloom 阈值，弹道/爆炸
## 带光晕）；false=不建 env（v6.17 前无泛光渲染，一键回退）。
## A/B 环境变量 PW_GLOW_OFF=1 同效。消费点 battle_optics.ensure_glow
@export var vfx_glow_enabled: bool = true
## v6.17 命中光学层批：动态光闪总开关——true=枪口/爆炸 PointLight2D 闪光滑池点亮
## 战场（无投影、并发上限、限世界层）；false=零动态光（v6.17 前行为）。
## A/B 环境变量 PW_LIGHTS_OFF=1 同效。消费点 battle_optics.flash
@export var vfx_dynamic_lights_enabled: bool = true

## 经济配置（v29 R2a 离线收益再平衡，设计审查 F-05）
@export_group("经济配置")
## v29 R2a: 离线收益效率系数——离线折算战斗次数整体乘数。原 1.0 无衰减（离线 8h≈376 场，
## 一晚挂机=数百场主动游玩，主动玩法被支配）。0.5 = 减半。消费点 offline_idle_manager
@export var offline_idle_efficiency: float = 0.5
## v29 R2a: 离线边际递减开关——true=前 2h 全额、2-8h 半额（有效时长 = min(t,2h) +
## max(0, min(t,8h)-2h)×0.5）；false=全程全额。与效率系数叠乘。消费点 offline_idle_manager
@export var offline_idle_decay_enabled: bool = true
## v29 R2a: 离线推关冻结——true=离线期间每场推一关+全胜假设结算（旧行为，睡觉白拿进度
## 与首通奖励）；false=离线只产资源不推关（在线挂机 PUSH 不受影响，推图仍需玩家在场）。
## 消费点 offline_idle_manager._compute_offline_level_progress 调用侧
@export var offline_push_levels_enabled: bool = false
## v30 R2b: 普通卡词条洗练附加晶体分量——true=洗练同时消耗晶体（纳米费用×2% 向上取整，
## 星冥卡星髓计费不变）；false=纯纳米（旧行为）。晶体此前仅改造升级/era4 制造两处薄 sink。
## 消费点 affix_manager.can_pay_reroll/_pay_reroll
@export var affix_reroll_crystal_enabled: bool = true
## v30 R2b 黑门 50 能量块/次硬门票已随 2026-09-19 双轨修复退役（blackgate_energy_cost 删除）：
## 门票统一走 endless_blackgate_manager 软门（3 免费/日 + 60 能量块购次，v32.0 B3-S3 用户拍板）。
## 消费点 world_map._enter_blackgate / endless_blackgate_manager.ENERGY_PER_EXTRA_ENTRY

## v29 R2a: 离线边际递减分段参数（offline_reward_factor 用）
const DECAY_FULL_RATE_HOURS: float = 2.0
const DECAY_REDUCED_RATE: float = 0.5

## v29 R2a: 离线收益总乘数 = 效率系数 × 边际递减系数（静态可测，无 autoload 依赖）。
## 递减模型：前 DECAY_FULL_RATE_HOURS 小时全额，其后（8h 封顶内）半额；
## capped_sec 由调用方 clamp。消费点 offline_idle_manager.compute_offline_rewards
static func offline_reward_factor(capped_sec: int) -> float:
	var factor: float = clampf(get_default().offline_idle_efficiency, 0.0, 1.0)
	if get_default().offline_idle_decay_enabled and float(capped_sec) > DECAY_FULL_RATE_HOURS * 3600.0:
		var full_sec: float = DECAY_FULL_RATE_HOURS * 3600.0
		var reduced_sec: float = float(capped_sec) - full_sec
		factor *= (full_sec + reduced_sec * DECAY_REDUCED_RATE) / float(capped_sec)
	return factor

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
		# 试玩/测试构建（export custom_features="pw_playtest"）运行时全解锁档：
		# 功能门全开 + 免战力门/部署限制 + 开局补齐全蓝图全符文 + 蓝图只验不消耗。
		# 正式 release（无该 feature）与编辑器调试跑均零影响。
		if OS.has_feature("pw_playtest"):
			_default_config.feature_gates_enabled = false
			_default_config.power_cap_enabled = false
			_default_config.debug_no_deploy_limits = true
			_default_config.debug_grant_all_blueprints = true
			_default_config.mod_consumable_enabled = false
	return _default_config

## 重置为默认值
func reset_to_defaults() -> void:
	cross_row_direct_damage_mult = 0.70  # P0-5 修复：v9.x 字段此前漏重置
	# v26.4 修复：v21/v26 三个总开关此前漏重置
	aura_range_enabled = true
	env_effects_enabled = true
	battle_layouts_enabled = true
	mod_consumable_enabled = true
	xeno_vfx_enabled = true
	color_grade_enabled = true
	ground_dressing_enabled = true
	feature_gates_enabled = true
	power_cap_enabled = true
	mod_breakpoints_enabled = true  # v6.16 断点阶梯
	mod_slot_budget_enabled = true  # v6.16 槽位预算
	vfx_glow_enabled = true  # v6.17 光学层泛光
	vfx_dynamic_lights_enabled = true  # v6.17 光学层动态光闪
	# v29 R2a: 离线收益三参数（经济批，设计审查 F-05）
	offline_idle_efficiency = 0.5
	offline_idle_decay_enabled = true
	offline_push_levels_enabled = false
	affix_reroll_crystal_enabled = true
	debug_no_deploy_limits = false  # P0-5 修复：测试开关此前漏重置
	debug_grant_all_blueprints = false
