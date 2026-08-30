extends RefCounted
class_name ComboFieldState
## v9.1 我方组合技套路系统 — 战场状态管理器
##
## 职责：承载"战场级浓度"（跨单位累积状态）+ 封装"目标级 meta"读写。
## - 战场浓度：纳米粒子浓度 / 电磁损坏度 / 化学污染度 等全局累积量，随时间衰减
## - 目标级状态：石墨纤维标记 / 助燃剂层数 / 激光谐振 / 雷达锁定 等（走 target meta，过期清理）
##
## 生命周期：由 BattleManager 持有一个实例，start_battle 时创建，end_battle 时 reset。
## 消费方：combo_engine（套路检测/衰减）、module_effect_handler（命中读写状态）、
##         bullet.gd（读状态增伤）、phase_instrument_abilities（注入浓度）。
##
## 设计决策：
## 1. 战场浓度独立于现有 meta 标记链（_marked_until 等），不修改任何现有 meta，零侵入。
## 2. 浓度按 tag（字符串）分类，支持任意新套路扩展（add_field("nano", 5.0, 30.0)）。
## 3. 目标级状态封装 get/set，统一过期时间戳语义（秒，基于 Time.get_ticks_msec）。

# ─────────────────────────────────────────────
#  战场级浓度（tag -> {amount, decay_per_sec, expire_at}）
# ─────────────────────────────────────────────
# 预定义 tag 常量（供消费方引用，避免拼写漂移）
const FIELD_NANO := "nano_concentration"       # 纳米粒子浓度（套路3）
const FIELD_CHEM := "chem_pollution"            # 化学污染度（套路6）
# 注：电磁损坏度（套路2）走目标级 meta（_graphite_charge），非战场浓度——电子损坏是按目标累积的
# v9.1b：浓度软上限（防无限累积导致放大失控）。nano_concentration ×0.10 系数下，50 上限 → 6x 放大。
const FIELD_CAPS: Dictionary = {
	FIELD_NANO: 50.0,
	FIELD_CHEM: 60.0,
}

var _fields: Dictionary = {}   # tag -> {amount: float, decay: float, expire_at: float}

## 浓度变化信号（tag, 新值）。供 battlefield 层订阅以驱动浓度场 VFX。
signal field_changed(tag: String, amount: float)

# ─────────────────────────────────────────────
#  目标级 meta key 常量
# ─────────────────────────────────────────────
const META_INCENDIARY_STACKS := "_incendiary_stacks"      # 助燃剂层数（套路1，整数计数）
const META_INCENDIARY_UNTIL  := "_incendiary_until"       # 助燃剂过期时间戳
const META_GRAPHITE_CHARGE   := "_graphite_charge"        # 石墨纤维电子损坏累积（套路2，整数计数）
const META_GRAPHITE_UNTIL    := "_graphite_until"         # 石墨纤维过期时间戳
const META_LASER_RESONANCE   := "_laser_resonance"        # 激光谐振层数（套路4，整数计数）
const META_LASER_UNTIL       := "_laser_until"            # 激光谐振过期时间戳
const META_RADAR_LOCKED      := "_radar_locked_until"     # 雷达锁定（套路5，秒时间戳）
const META_RADAR_VULN        := "_radar_vuln"             # 雷达锁定易伤值
const META_WEAKPOINT_UNTIL   := "_weakpoint_until"        # 弱点暴露（套路5集火链式产物）
const META_WEAKPOINT_BONUS   := "_weakpoint_bonus"        # 弱点暴露暴击伤害加成

func _init() -> void:
	reset()

## 清空所有状态（战斗开始/结束调用）
func reset() -> void:
	_fields.clear()

# ─────────────────────────────────────────────
#  战场浓度 API
# ─────────────────────────────────────────────

## 累加战场浓度（攻击命中/能力触发时调用）。
## amount: 本次增加量；decay_per_sec: 每秒衰减量（浓度自然回落）；duration: 浓度持续总时长（秒，到点强制清零）。
func add_field(tag: String, amount: float, decay_per_sec: float = 1.0, duration: float = 30.0) -> void:
	if amount <= 0.0:
		return
	var now: float = _now()
	if not _fields.has(tag):
		_fields[tag] = {"amount": 0.0, "decay": decay_per_sec, "expire_at": now + duration}
	var f: Dictionary = _fields[tag]
	f["amount"] = float(f["amount"]) + amount
	# v9.1b：浓度软上限（防无限累积导致放大失控）
	if FIELD_CAPS.has(tag):
		f["amount"] = minf(float(f["amount"]), float(FIELD_CAPS[tag]))
	# 衰减率取较小值（多源叠加时衰减放缓，体现浓度累积）
	f["decay"] = minf(float(f.get("decay", decay_per_sec)), decay_per_sec)
	# 过期时间取较远（浓度持续时间刷新）
	f["expire_at"] = maxf(float(f.get("expire_at", now + duration)), now + duration)
	# 通知订阅方（battlefield 浓度场 VFX）
	field_changed.emit(tag, float(f["amount"]))

## 读取战场浓度当前值（已扣除自然衰减）。每帧调用 update() 后读到的就是衰减后的实时值。
func get_field(tag: String) -> float:
	var f: Dictionary = _fields.get(tag, {})
	if f.is_empty():
		return 0.0
	if _now() >= float(f.get("expire_at", 0.0)):
		return 0.0
	return float(f.get("amount", 0.0))

## 浓度是否达到阈值（套路触发判定用）
func field_at_least(tag: String, threshold: float) -> bool:
	return get_field(tag) >= threshold

## 每帧更新：浓度自然衰减 + 过期清理。由 combo_engine.update(delta) 调用。
## v21 P1: 新增 decay_scale（默认 1.0 行为不变）——纳米浓度场满档（nano_decay_half）
## 时引擎传 0.5，浓度自然衰减减半（机制升级"浓度保持"，非数值翻倍）。
func update(delta: float, decay_scale: float = 1.0) -> void:
	var now: float = _now()
	var to_erase: Array = []
	var ds: float = clampf(decay_scale, 0.0, 1.0)
	for tag in _fields.keys():
		var f: Dictionary = _fields[tag]
		if now >= float(f.get("expire_at", 0.0)):
			to_erase.append(tag)
			continue
		var decay: float = float(f.get("decay", 0.0)) * delta * ds
		f["amount"] = maxf(0.0, float(f.get("amount", 0.0)) - decay)
		if float(f["amount"]) <= 0.0:
			to_erase.append(tag)
	for tag in to_erase:
		_fields.erase(tag)
		field_changed.emit(tag, 0.0)
	# 衰减后通知仍在激活的浓度（让 VFX 跟随衰减）
	for tag in _fields.keys():
		var f2: Dictionary = _fields[tag]
		field_changed.emit(tag, float(f2.get("amount", 0.0)))

# ─────────────────────────────────────────────
#  目标级 meta API（封装过期语义）
# ─────────────────────────────────────────────

## 给目标设置带过期时间的 meta（value + until 两个 meta key）。
## static：仅操作 target 节点 meta + 调用 static _now()，不依赖实例状态，可在任意上下文调用。
static func set_target_meta(target: Node, value_key: String, until_key: String, value: float, duration: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.set_meta(value_key, value)
	target.set_meta(until_key, _now() + duration)

## 读取目标的 meta（带过期检查，过期返回 0）。
static func get_target_meta(target: Node, value_key: String, until_key: String) -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	if not target.has_meta(until_key):
		return 0.0
	var expire: float = float(target.get_meta(until_key, 0.0))
	if _now() >= expire:
		return 0.0
	return float(target.get_meta(value_key, 0.0))

## 累加目标整数计数（如层数），并刷新过期时间。返回累加后的值。
static func add_target_stacks(target: Node, value_key: String, until_key: String, add: int, max_stacks: int, duration: float) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	var cur: int = int(get_target_meta(target, value_key, until_key))
	cur = mini(cur + add, max_stacks)
	target.set_meta(value_key, cur)
	target.set_meta(until_key, _now() + duration)
	return cur

## 读取目标整数层数（带过期检查）。
static func get_target_stacks(target: Node, value_key: String, until_key: String) -> int:
	return int(get_target_meta(target, value_key, until_key))

# ─────────────────────────────────────────────
#  辅助
# ─────────────────────────────────────────────

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
