
## 显示伤害数字（战斗反馈系统）
## 性能优化：预加载脚本，避免运行时 load()
const DamageNumberDisplay = preload("res://scenes/effects/damage_number_display.gd")
const ScreenShake = preload("res://scenes/effects/screen_shake.gd")

func _show_damage_number(amount: float) -> void:
	# 获取战场父节点
	var battlefield = get_parent()
	if not battlefield or not is_instance_valid(battlefield):
		return

	# 计算是否暴击（简单示例：10%暴击率）
	var is_critical = randf() < 0.1

	# 创建伤害数字显示
	if DamageNumberDisplay:
		DamageNumberDisplay.create_damage_number(
			battlefield,
			global_position,
			int(amount),
			is_critical
		)

	# 如果是暴击，添加屏幕震动
	if is_critical:
		var camera = battlefield.get_node_or_null("Camera2D")
		if camera and ScreenShake:
			ScreenShake.medium_shake(camera)

