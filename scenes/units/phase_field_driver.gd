extends Node2D
## 相位场驱动器：我方基地，200 HP，被摧毁则战败

@export var max_hp: float = 200.0
@export var rotate_speed_deg: float = 36.0
var hp: float = 200.0
@onready var _body: Node2D = $Body

func _ready() -> void:
	hp = max_hp
	# 让敌人可以识别为特殊目标
	add_to_group("phase_driver")
	if SignalBus:
		SignalBus.phase_driver_hp_changed.emit(hp, max_hp)

func _process(delta: float) -> void:
	if _body == null:
		return
	_body.rotation += deg_to_rad(rotate_speed_deg) * delta

func take_damage(amount: float, attacker: Variant = null) -> void:
	hp -= amount
	if SignalBus:
		SignalBus.phase_driver_hp_changed.emit(maxf(hp, 0.0), max_hp)
		SignalBus.unit_damaged.emit(self, true, amount, global_position)
	if hp <= 0:
		_on_destroyed()

func _on_destroyed() -> void:
	if SignalBus:
		SignalBus.phase_driver_destroyed.emit()
	queue_free()

