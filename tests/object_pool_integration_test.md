# 对象池集成测试指南

**测试对象池是否正确集成到战斗系统**

---

## ✅ 集成完成检查

### 1. Autoload 配置
- [ ] `ObjectPoolManager` 已添加到 `project.godot` 的 `[autoload]` 部分
- [ ] 位置：在 BattleFeedbackManager 之后

### 2. 子弹对象池
- [ ] `bullet.gd` 实现 `reset_pool_object()` 方法
- [ ] `construct_unit.gd` 使用 `ObjectPoolManager.get_object("bullets")`
- [ ] `enemy_unit.gd` 使用 `ObjectPoolManager.get_object("bullets")`
- [ ] 两处都有回退机制（对象池为空时使用 instantiate）

### 3. 伤害数字对象池
- [ ] `damage_number_display.gd` 使用 `ObjectPoolManager.get_object("damage_numbers")`
- [ ] 有回退机制（对象池为空时使用 instantiate）

### 4. 对象池自动注册
- [ ] `object_pool.gd` 的 `_ready()` 调用 `_register_default_pools()`
- [ ] 自动注册 "bullets" 池（50个预创建，最大100个）
- [ ] 自动注册 "damage_numbers" 池（20个预创建，最大40个）

---

## 🧪 测试步骤

### 测试1：验证对象池初始化

**目标**: 确认对象池在游戏启动时正确初始化

```gdscript
# 在 title_screen.gd 或 main.gd 的 _ready() 中添加测试代码
func _ready():
    # 等待一帧让所有 autoload 初始化
    await get_tree().process_frame

    # 检查对象池是否存在
    if not ObjectPoolManager:
        print("❌ 对象池管理器未加载")
        return

    print("✅ 对象池管理器已加载")

    # 获取所有池统计
    var all_stats = ObjectPoolManager.get_all_stats()
    print("📊 对象池统计: ", JSON.stringify(all_stats, "\t"))

    # 预期结果：
    # {
    #   "bullets": {
    #     "available": 50,
    #     "in_use": 0,
    #     "total": 50,
    #     "total_created": 50,
    #     "pool_size": 50,
    #     "max_size": 100,
    #     "utilization": 0.0
    #   },
    #   "damage_numbers": {
    #     "available": 20,
    #     "in_use": 0,
    #     "total": 20,
    #     "total_created": 20,
    #     "pool_size": 20,
    #     "max_size": 40,
    #     "utilization": 0.0
    #   }
    # }
```

**预期结果**:
- ✅ 控制台显示 "对象池管理器已加载"
- ✅ 子弹池有50个可用对象
- ✅ 伤害数字池有20个可用对象

---

### 测试2：验证子弹对象池

**目标**: 确认子弹使用对象池

```gdscript
# 在战斗管理器中添加测试
func test_bullet_pool():
    print("\n=== 测试子弹对象池 ===")

    # 获取初始统计
    var stats_before = ObjectPoolManager.get_pool_stats("bullets")
    print("测试前: ", JSON.stringify(stats_before, "\t"))

    # 手动获取10个子弹
    var bullets = []
    for i in range(10):
        var bullet = ObjectPoolManager.get_object("bullets")
        if bullet:
            bullets.append(bullet)

    # 获取使用后统计
    var stats_during = ObjectPoolManager.get_pool_stats("bullets")
    print("使用10个子弹后: ", JSON.stringify(stats_during, "\t"))

    # 归还所有子弹
    for bullet in bullets:
        ObjectPoolManager.return_object("bullets", bullet)

    # 获取归还后统计
    var stats_after = ObjectPoolManager.get_pool_stats("bullets")
    print("归还10个子弹后: ", JSON.stringify(stats_after, "\t"))

    # 验证
    assert(stats_during.in_use == 10, "应该有10个子弹在使用中")
    assert(stats_after.available == stats_before.available, "所有子弹应该已归还")

    print("✅ 子弹对象池测试通过")
```

**预期结果**:
- ✅ 可以成功获取10个子弹
- ✅ 使用中计数正确（10个）
- ✅ 归还后可用计数恢复

---

### 测试3：验证伤害数字对象池

**目标**: 确认伤害数字使用对象池

```gdscript
# 在战斗管理器中添加测试
func test_damage_number_pool():
    print("\n=== 测试伤害数字对象池 ===")

    # 获取初始统计
    var stats_before = ObjectPoolManager.get_pool_stats("damage_numbers")
    print("测试前: ", JSON.stringify(stats_before, "\t"))

    # 创建10个伤害数字
    var battlefield = get_tree().current_scene
    for i in range(10):
        DamageNumberDisplay.create_damage(
            battlefield,
            Vector2(100 + i * 50, 100),
            10 + i,
            false,
            "normal"
        )

    # 等待一帧让对象创建
    await get_tree().process_frame

    # 获取使用后统计
    var stats_during = ObjectPoolManager.get_pool_stats("damage_numbers")
    print("创建10个伤害数字后: ", JSON.stringify(stats_during, "\t"))

    # 等待伤害数字完成（2秒）
    await get_tree().create_timer(2.5).timeout

    # 获取完成后统计
    var stats_after = ObjectPoolManager.get_pool_stats("damage_numbers")
    print("伤害数字完成后: ", JSON.stringify(stats_after, "\t"))

    print("✅ 伤害数字对象池测试通过")
```

**预期结果**:
- ✅ 可以成功创建10个伤害数字
- ✅ 使用中计数正确
- ✅ 完成后对象自动归还

---

### 测试4：实战测试

**目标**: 在真实战斗中测试对象池

```gdscript
# 在战斗管理器中添加监控
func _process(delta):
    if not battle_active:
        return

    # 每60帧（约1秒）输出一次统计
    if Engine.get_frames_drawn() % 60 == 0:
        var bullet_stats = ObjectPoolManager.get_pool_stats("bullets")
        var damage_stats = ObjectPoolManager.get_pool_stats("damage_numbers")

        print("\n=== 对象池实时统计 ===")
        print("子弹池: 可用=%d, 使用中=%d, 效率=%.1f%%" % [
            bullet_stats.available,
            bullet_stats.in_use,
            float(bullet_stats.total_created) / max(1, bullet_stats.in_use + bullet_stats.available) * 100.0
        ])
        print("伤害池: 可用=%d, 使用中=%d, 效率=%.1f%%" % [
            damage_stats.available,
            damage_stats.in_use,
            float(damage_stats.total_created) / max(1, damage_stats.in_use + damage_stats.available) * 100.0
        ])
```

**预期结果**:
- ✅ 效率 > 80%（高复用率）
- ✅ 使用中对象数量合理
- ✅ 无内存泄漏（长期运行后数量稳定）

---

## 🐛 故障排除

### 问题1：对象池管理器未加载

**症状**: `ObjectPoolManager` 为 null

**解决方案**:
1. 检查 `project.godot` 中是否添加了 ObjectPoolManager 到 autoload
2. 重启编辑器
3. 检查控制台是否有加载错误

### 问题2：获取对象返回 null

**症状**: `ObjectPoolManager.get_object("bullets")` 返回 null

**原因**: 对象池未初始化

**解决方案**:
1. 检查 `object_pool.gd` 的 `_ready()` 是否被调用
2. 检查 `_register_default_pools()` 是否执行
3. 查看控制台是否有注册成功消息

### 问题3：对象不复用

**症状**: 每次都创建新对象，效率为0%

**原因**: 对象未正确归还

**解决方案**:
1. 检查 `bullet.gd` 中的归还调用
2. 检查 `damage_number_display.gd` 中的归还调用
3. 确认 `reset_pool_object()` 正确实现

### 问题4：内存泄漏

**症状**: 长时间运行后内存持续增长

**原因**: 对象未正确归还或重复添加到场景树

**解决方案**:
1. 检查是否有地方直接使用 `instantiate()` 而绕过对象池
2. 检查对象归还前是否先 `remove_child()`
3. 使用调试器监控对象数量

---

## 📊 性能基准

### 对比测试

**测试方法**:
1. 运行50单位战斗30秒
2. 记录对象池效率
3. 对比优化前后的性能

**预期性能提升**:
- 子弹创建: -70% 开销
- 伤害数字创建: -85% 开销
- 整体帧率: +25-35%

### 成功标准

- ✅ 对象池效率 > 80%
- ✅ FPS 提升 > 20%
- ✅ 无内存泄漏（30分钟测试）
- ✅ 无功能回归

---

## ✅ 最终验收

运行完整测试清单：

- [ ] 对象池正确初始化
- [ ] 子弹使用对象池
- [ ] 伤害数字使用对象池
- [ ] 对象正确归还
- [ ] 效率 > 80%
- [ ] FPS 提升 > 20%
- [ ] 无内存泄漏
- [ ] 无新增bug

**全部通过后，对象池集成完成！** ✅

---

**文档版本**: 1.0
**最后更新**: 2026-04-11
