extends Node2D
## 相位场驱动器：我方基地，200 HP，被摧毁则战败

const DT = preload("res://resources/design_tokens.gd")
const BaseAura = preload("res://scenes/units/base_aura.gd")

@export var max_hp: float = 200.0
@export var rotate_speed_deg: float = 36.0
var hp: float = 200.0
@onready var _body: Node2D = $Body
## BU-2（战斗界面美化）：基地视觉——底座光环/核心血条/受击反馈组件 + 反向外环
var _aura: Node2D = null
var _body_halo: Sprite2D = null

func _ready() -> void:
	hp = max_hp
	# 让敌人可以识别为特殊目标
	add_to_group("phase_driver")
	_setup_base_visuals()
	if SignalBus:
		SignalBus.phase_driver_hp_changed.emit(hp, max_hp)

func _process(delta: float) -> void:
	if _body == null:
		return
	_body.rotation += deg_to_rad(rotate_speed_deg) * delta
	if _body_halo != null and is_instance_valid(_body_halo):
		_body_halo.rotation -= deg_to_rad(18.0) * delta

## BU-2：底座光环（我方青）+ 核心 HP 条 + 双层反向旋转外环（零新美术的待机层次）。
func _setup_base_visuals() -> void:
	if _aura == null or not is_instance_valid(_aura):
		_aura = BaseAura.new()
		_aura.name = "BaseAura"
		add_child(_aura)
	_aura.setup(DT.COLOR_ACCENT_CYAN, 46.0, "核心", 110.0, DT.COLOR_HEALTH)
	_aura.update_hp(hp, max_hp)
	var body_spr := _body as Sprite2D
	if body_spr == null or body_spr.texture == null:
		return
	if _body_halo == null or not is_instance_valid(_body_halo):
		_body_halo = Sprite2D.new()
		_body_halo.name = "BodyHalo"
		_body_halo.z_index = -1
		add_child(_body_halo)
	_body_halo.texture = body_spr.texture
	_body_halo.scale = body_spr.scale * 1.15
	_body_halo.modulate = Color(1, 1, 1, 0.5)

func take_damage(amount: float, attacker: Variant = null) -> void:
	hp -= amount
	if _aura != null and is_instance_valid(_aura):
		_aura.update_hp(maxf(hp, 0.0), max_hp)
		_aura.flash_hit()
	if SignalBus:
		SignalBus.phase_driver_hp_changed.emit(maxf(hp, 0.0), max_hp)
		SignalBus.unit_damaged.emit(self, true, amount, global_position)
	if hp <= 0:
		_on_destroyed()

func _on_destroyed() -> void:
	# BU-9：摧毁演出——命中特效大档 + 强震屏（失败字幕/红闪仍由 BattleSpectacle 承接）
	var host: Node2D = get_parent() as Node2D
	if host != null:
		var Vfx = preload("res://scripts/battle/vfx_impact_factory.gd")
		Vfx.spawn_layered_impact(host, global_position, 0, true)
		if host.has_method("request_screen_shake"):
			host.request_screen_shake(8.0, 0.5)
	if SignalBus:
		SignalBus.phase_driver_destroyed.emit()
	queue_free()

