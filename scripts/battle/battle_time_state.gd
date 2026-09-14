extends RefCounted
## v32.0 B1-1 战斗时间状态（战斗倍速 + 极速推演）——定位转向"战术构筑放置"第一批
##
## Engine.time_scale 是全局作用域：战斗外泄漏会污染基地/结算界面的所有 tween 动画。
## 本类是倍速档位与极速推演旗标的唯一状态真身；应用方是 BattleSpectacle
## （autoload，胜利慢动作/击杀顿帧恢复链的既有持有者），本类只存状态与常量。
##
## 契约：
## 1. 战斗结束（含 end_battle(false) 回标题）必须 restore_neutral()——由
##    BattleSpectacle._on_battle_ended 收口，title_screen._ready 兜底
## 2. 倍速偏好持久化到 user://battle_speed.cfg 独立文件（settings.cfg 是
##    settings_panel/KeyBinds 双写领域，新键须守 load-then-write 纪律，勿并入）
## 3. 极速推演 = 真实模拟至战斗结束（奖励照常结算），期间 SFX/命中 VFX/
##    伤害数字/击杀顿帧各自读 ff_active 短路，物理步进产能加倍
## 4. 静态函数命名避开 reset_state（Godot 4.5.1 静态函数同名静默失效坑）

const SPEED_OPTIONS: Array = [1.0, 2.0, 3.0, 4.0]
const FF_TIME_SCALE: float = 8.0
const FF_MAX_PHYSICS_STEPS: int = 16
const DEFAULT_MAX_PHYSICS_STEPS: int = 8
const PREF_PATH := "user://battle_speed.cfg"

static var user_scale: float = 1.0
static var ff_active: bool = false
static var _pref_loaded: bool = false


## 就近吸附到合法档位（防旧档/手改值越档）
static func snap_scale(v: float) -> float:
	var best: float = SPEED_OPTIONS[0]
	var best_d: float = absf(v - best)
	for s in SPEED_OPTIONS:
		var d := absf(v - s)
		if d < best_d:
			best = s
			best_d = d
	return best


## 惰性读档（每次进程只读一次；读后吸附合法档）
static func load_pref() -> float:
	if _pref_loaded:
		return user_scale
	_pref_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PREF_PATH) == OK:
		user_scale = snap_scale(float(cf.get_value("speed", "user_scale", 1.0)))
	return user_scale


static func save_pref() -> void:
	_pref_loaded = true
	var cf := ConfigFile.new()
	cf.set_value("speed", "user_scale", user_scale)
	cf.save(PREF_PATH)


## 测试隔离用：清惰性读档标记（不删文件）
static func reset_pref_cache() -> void:
	_pref_loaded = false


## 进入极速推演：8x 时间流 + 物理步进产能加倍（默认 8 步/帧 → 16，保 8x 下
## 60fps 机器 480 步/s 的物理产能；低帧率机器自然降速，不会卡死）
static func enter_fast_forward() -> void:
	ff_active = true
	Engine.time_scale = FF_TIME_SCALE
	Engine.max_physics_steps_per_frame = FF_MAX_PHYSICS_STEPS


## 退出极速推演，恢复到战斗内玩家倍速 to_scale
static func exit_fast_forward(to_scale: float) -> void:
	ff_active = false
	Engine.max_physics_steps_per_frame = DEFAULT_MAX_PHYSICS_STEPS
	Engine.time_scale = maxf(to_scale, 0.1)


## 战斗外中性态：1x + 默认物理步进（战斗结束收口/标题屏兜底）
static func restore_neutral() -> void:
	ff_active = false
	Engine.max_physics_steps_per_frame = DEFAULT_MAX_PHYSICS_STEPS
	Engine.time_scale = 1.0
