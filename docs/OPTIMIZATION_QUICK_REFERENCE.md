# Phase War 性能优化快速参考

**快速上手指南** - 立即开始使用优化工具

---

## 🚀 5分钟快速集成

### 1. 对象池集成（推荐优先）

#### 子弹与伤害数字（统一 `ObjectPoolManager` autoload）

遗留的 `BulletPoolManager` / `DamageNumberPoolManager` 脚本已移除；请始终使用 `ObjectPoolManager`。

```gdscript
# 子弹归还（见 bullet.gd）
ObjectPoolManager.return_object("bullets", self)

# 取子弹
var bullet: Node2D = ObjectPoolManager.get_object("bullets")

# 伤害数字（见 damage_number_display.gd 静态方法）
DamageNumberDisplay.create_damage_number(parent, world_pos, int(amount), is_crit, "normal")
```

### 2. 空间分区集成

#### 在战斗管理器中初始化
```gdscript
# battle_manager.gd
var spatial_grid: SpatialGrid

func _ready():
    spatial_grid = SpatialGrid.new()
    spatial_grid.setup(100.0, 40.0, 1240.0, 280.0, 440.0)
    add_child(spatial_grid)
```

#### 在单位中使用
```gdscript
# construct_unit.gd / enemy_unit.gd

# 单位生成时
func setup(...):
    # ... 现有代码
    if spatial_grid:
        spatial_grid.insert(self)

# 每帧更新位置
func _process(delta):
    # ... 移动代码
    if spatial_grid:
        spatial_grid.update(self)

# 查找目标
func _find_target():
    if spatial_grid:
        return spatial_grid.query_nearest_target(global_position, is_player, attack_range)
    # 旧代码回退...

# 单位死亡时
func _on_death():
    if spatial_grid:
        spatial_grid.remove(self)
    # ... 死亡逻辑
```

---

## 📊 性能监控

### 实时FPS监控
```gdscript
# 在任何 _process() 中
func _process(delta):
    if Engine.get_frames_drawn() % 60 == 0:  # 每秒
        var fps = Performance.get_monitor(Performance.TIME_FPS)
        var mem = Performance.get_monitor(Performance.MEMORY_STATIC) / 1024 / 1024
        print("FPS: %d, MEM: %d MB" % [fps, mem])
```

### 运行基准测试
```gdscript
# 在测试场景中
var benchmark = preload("res://tests/performance_benchmark.gd").new()
add_child(benchmark)

benchmark.benchmark_completed.connect(func(results):
    print("平均FPS: ", results.avg_fps)
    print("平均内存: ", results.avg_memory_mb, " MB")
)

benchmark.start_benchmark(benchmark.TestScenario.BATTLE_50_UNITS)
```

---

## ✅ 验证清单

集成后验证：

- [ ] 战斗中子弹正常飞行
- [ ] 伤害数字正常显示
- [ ] 单位正确索敌和攻击
- [ ] FPS提升明显（对比优化前）
- [ ] 无内存泄漏（长时间测试）
- [ ] 无新增错误或警告

---

## 🐛 常见问题

### Q: 对象池返回的对象状态不对？
A: 确保对象实现了 `reset_pool_object()` 方法

```gdscript
func reset_pool_object():
    hp = max_hp
    velocity = Vector2.ZERO
    visible = true
```

### Q: 空间网格找不到目标？
A: 确保单位移动时调用 `spatial_grid.update(self)`

### Q: 性能没有提升？
A: 运行基准测试对比数据，检查：
1. 对象池是否正确使用
2. 空间网格是否正确初始化
3. 是否有其他性能瓶颈

---

## 📞 获取帮助

- **完整文档**: `docs/OPTIMIZATION_SESSION_COMPLETED.md`
- **优化路线图**: `docs/OPTIMIZATION_ROADMAP.md`
- **对象池源码**: `managers/object_pool.gd`
- **空间网格源码**: `scripts/spatial_grid.gd`

---

**提示**: 建议先在一个测试场景中集成，验证无误后再应用到主游戏。
