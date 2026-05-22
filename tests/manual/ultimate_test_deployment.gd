extends Node
## 终极部署测试：完全绕过UI和检查，直接创建单位

func _ready() -> void:
	print("[UltimateTest] 终极部署测试已加载")
	call_deferred("_test_direct_unit_creation")

func _test_direct_unit_creation() -> void:
	await get_tree().create_timer(5.0).timeout
	print("[UltimateTest] 开始直接创建单位测试...")

	# 检查战斗管理器
	if not BattleManager:
		print("[UltimateTest] ❌ BattleManager不存在")
		return

	if not BattleManager.battle_active:
		print("[UltimateTest] ❌ 战斗未激活")
		return

	# 获取战场
	var battlefield = BattleManager.get("battlefield")
	if not battlefield:
		print("[UltimateTest] ❌ 战场不存在")
		return

	print("[UltimateTest] 战场存在，尝试直接创建单位...")

	# 直接创建单位，绕过所有检查
	var unit_scene = preload("res://scenes/units/construct_unit.tscn")
	var unit = unit_scene.instantiate()

	# 设置基本属性
	var stats = UnitStats.new()
	stats.max_hp = 100
	stats.hp = 100
	stats.attack_damage = 10
	stats.attack_interval = 1.0
	stats.move_speed = 50.0
	stats.attack_range = 150.0
	stats.platform_type = 0  # HOUND
	stats.weapon_type = 0

	unit.setup(true, stats)

	# 添加到战场
	var player_units = battlefield.get_node_or_null("PlayerUnits")
	if not player_units:
		player_units = battlefield

	player_units.add_child(unit)
	unit.global_position = Vector2(200, 300)

	print("[UltimateTest] ✅ 单位创建成功！")
	print("[UltimateTest] 如果你在战场左侧看到单位，说明创建功能正常")

	# 10秒后清理
	await get_tree().create_timer(10.0).timeout
	if is_instance_valid(unit):
		unit.queue_free()
	print("[UltimateTest] 测试单位已清理")
	queue_free()