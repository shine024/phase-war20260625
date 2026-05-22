extends Node
## 对象池集成快速验证脚本
## 将此脚本添加到任何场景的根节点并运行场景

func _ready() -> void:
	print("=== 对象池集成验证 ===")
	print("等待1秒让所有系统初始化...")
	await get_tree().create_timer(1.0).timeout
	_verify_object_pool()

func _verify_object_pool() -> void:
	var all_passed = true

	# 测试1: 检查对象池管理器
	print("\n[测试1] 检查对象池管理器...")
	if not ObjectPoolManager:
		print("❌ 失败: ObjectPoolManager 未加载")
		print("   请检查 project.godot 中的 autoload 配置")
		all_passed = false
	else:
		print("✅ 通过: ObjectPoolManager 已加载")

	# 测试2: 检查子弹池
	print("\n[测试2] 检查子弹对象池...")
	if ObjectPoolManager:
		var bullet_stats = ObjectPoolManager.get_pool_stats("bullets")
		if bullet_stats.is_empty():
			print("❌ 失败: 子弹池未初始化")
			all_passed = false
		else:
			print("✅ 通过: 子弹池已初始化")
			print("   可用: %d, 预创建: %d, 最大: %d" % [
				bullet_stats.available,
				bullet_stats.pool_size,
				bullet_stats.max_size
			])

	# 测试3: 检查伤害数字池
	print("\n[测试3] 检查伤害数字对象池...")
	if ObjectPoolManager:
		var damage_stats = ObjectPoolManager.get_pool_stats("damage_numbers")
		if damage_stats.is_empty():
			print("❌ 失败: 伤害数字池未初始化")
			all_passed = false
		else:
			print("✅ 通过: 伤害数字池已初始化")
			print("   可用: %d, 预创建: %d, 最大: %d" % [
				damage_stats.available,
				damage_stats.pool_size,
				damage_stats.max_size
			])

	# 测试4: 测试子弹获取和归还
	print("\n[测试4] 测试子弹获取和归还...")
	if ObjectPoolManager:
		var stats_before = ObjectPoolManager.get_pool_stats("bullets")
		var bullet = ObjectPoolManager.get_object("bullets")

		if not bullet:
			print("❌ 失败: 无法获取子弹对象")
			all_passed = false
		else:
			var stats_during = ObjectPoolManager.get_pool_stats("bullets")
			ObjectPoolManager.return_object("bullets", bullet)
			var stats_after = ObjectPoolManager.get_pool_stats("bullets")

			if stats_during.in_use == 1 and stats_after.in_use == stats_before.in_use:
				print("✅ 通过: 子弹获取和归还正常")
			else:
				print("❌ 失败: 子弹获取和归还异常")
				all_passed = false

	# 测试5: 测试伤害数字获取和归还
	print("\n[测试5] 测试伤害数字获取和归还...")
	if ObjectPoolManager:
		var stats_before = ObjectPoolManager.get_pool_stats("damage_numbers")
		var damage = ObjectPoolManager.get_object("damage_numbers")

		if not damage:
			print("❌ 失败: 无法获取伤害数字对象")
			all_passed = false
		else:
			var stats_during = ObjectPoolManager.get_pool_stats("damage_numbers")
			ObjectPoolManager.return_object("damage_numbers", damage)
			var stats_after = ObjectPoolManager.get_pool_stats("damage_numbers")

			if stats_during.in_use == 1 and stats_after.in_use == stats_before.in_use:
				print("✅ 通过: 伤害数字获取和归还正常")
			else:
				print("❌ 失败: 伤害数字获取和归还异常")
				all_passed = false

	# 最终结果
	print("\n" + "=".repeat(50))
	if all_passed:
		print("🎉 所有测试通过！对象池集成成功！")
		print("\n下一步：")
		print("1. 运行战斗场景测试实际效果")
		print("2. 运行性能基准测试对比数据")
		print("3. 查看实时对象池统计")
	else:
		print("⚠️  部分测试失败，请检查配置")
		print("\n常见问题：")
		print("1. 确认 project.godot 中添加了 ObjectPoolManager")
		print("2. 重启编辑器让 autoload 生效")
		print("3. 查看控制台详细错误信息")
	print("=".repeat(50))

	# 显示实时统计
	_show_live_stats()

func _show_live_stats() -> void:
	if not ObjectPoolManager:
		return

	print("\n📊 当前对象池统计:")
	var all_stats = ObjectPoolManager.get_all_stats()
	for pool_name in all_stats:
		var stats = all_stats[pool_name]
		var efficiency = 0.0
		if stats.total_created > 0:
			efficiency = float(stats.in_use) / float(stats.total_created) * 100.0

		print("\n%s 池:" % pool_name)
		print("  可用: %d / %d" % [stats.available, stats.pool_size])
		print("  使用中: %d" % stats.in_use)
		print("  总创建: %d" % stats.total_created)
		print("  利用率: %.1f%%" % efficiency)

## 使用方法：
##
## 1. 创建测试场景：tests/object_pool_test.tscn
## 2. 将此脚本附加到场景根节点
## 3. 运行场景
## 4. 查看控制台输出
##
## 或在任何现有场景的 _ready() 中添加：
## func _ready():
##     var verifier = preload("res://tests/verify_object_pool.gd").new()
##     add_child(verifier)
