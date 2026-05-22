extends Node
## 战斗反馈管理器：统一处理战斗中的视觉和音效反馈

const _LawDefs = preload("res://data/phase_laws.gd")
const _DamageNumberDisplay = preload("res://scenes/effects/damage_number_display.gd")
const _ScreenShake = preload("res://scenes/effects/screen_shake.gd")
const _PhaseLawCastEffect = preload("res://scenes/effects/phase_law_cast_effect.gd")

## 数据里 family 为 STEEL/FLAME…，施放特效 match 使用中文键
func _family_key_for_phase_law_fx(fam_raw: String) -> String:
	match String(fam_raw).to_upper():
		"STEEL":
			return "钢铁"
		"FLAME":
			return "烈焰"
		"THUNDER":
			return "雷霆"
		"VOID":
			return "虚空"
		_:
			return fam_raw

## 显示伤害数字
func show_damage_number(parent_node: Node, world_pos: Vector2, damage: int, is_critical: bool = false, damage_type: String = "normal") -> void:
	if not parent_node or not is_instance_valid(parent_node):
		return

	# 加载伤害数字显示脚本
	if _DamageNumberDisplay:
		_DamageNumberDisplay.create_damage_number(parent_node, world_pos, damage, is_critical, damage_type)

## 屏幕震动
func shake_screen(camera: Camera2D, intensity: float, duration: float) -> void:
	if not camera or not is_instance_valid(camera):
		return

	if _ScreenShake:
		_ScreenShake.shake_camera(camera, intensity, duration)

## 显示相位法则施放特效
func show_phase_law_effect(parent_node: Node, world_pos: Vector2, family: String) -> void:
	if not parent_node or not is_instance_valid(parent_node):
		return

	if _PhaseLawCastEffect:
		match family:
			"钢铁": _PhaseLawCastEffect.create_steel_effect(parent_node, world_pos)
			"烈焰": _PhaseLawCastEffect.create_flame_effect(parent_node, world_pos)
			"雷霆": _PhaseLawCastEffect.create_thunder_effect(parent_node, world_pos)
			"虚空": _PhaseLawCastEffect.create_void_effect(parent_node, world_pos)
			_: _PhaseLawCastEffect.create_phase_law_effect(parent_node, world_pos, Color.CYAN)

## 处理单位受伤反馈
func on_unit_damaged(unit: Node, damage: float, is_critical: bool = false) -> void:
	if not unit or not is_instance_valid(unit):
		return

	var battlefield = unit.get_parent()
	if not battlefield:
		return

	# 显示伤害数字
	show_damage_number(battlefield, unit.global_position, int(damage), is_critical)

	# 如果是暴击，添加屏幕震动
	if is_critical:
		var camera = battlefield.get_node_or_null("Camera2D")
		if camera:
			shake_screen(camera, 5.0, 0.3)

## 处理治疗反馈
func on_unit_healed(unit: Node, heal_amount: float) -> void:
	if not unit or not is_instance_valid(unit):
		return

	var battlefield = unit.get_parent()
	if not battlefield:
		return

	# 显示治疗数字
	if _DamageNumberDisplay:
		_DamageNumberDisplay.create_heal_number(battlefield, unit.global_position, int(heal_amount))

## 处理相位法则施放反馈
func on_phase_law_cast(law_id: String, position: Vector2, battlefield: Node) -> void:
	if not battlefield or not is_instance_valid(battlefield):
		return
	# NewSystemsIntegration 用 load().new() 创建的临时 Node 不在场景树内，不能用 get_node("/root/…")。
	var law_data: Dictionary = _LawDefs.get_by_id(law_id)
	if law_data.is_empty():
		return
	var family_fx := _family_key_for_phase_law_fx(String(law_data.get("family", "")))
	show_phase_law_effect(battlefield, position, family_fx)

## 处理单位死亡反馈
func on_unit_death(unit: Node) -> void:
	# 可以添加死亡特效等
	pass
