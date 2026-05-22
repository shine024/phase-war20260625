# Phase War 性能优化检查清单

**使用本清单验证所有优化是否正确实施**

---

## 📋 优化实施检查清单

### ✅ 阶段1：快速胜利优化

#### 1.1 清理调试日志
- [ ] `battle_manager.gd` 中的 print 调用已移除
- [ ] 核心战斗代码无调试日志输出
- [ ] 使用信号系统代替调试日志

**验证方法**:
```gdscript
# 运行战斗，检查控制台无过多日志输出
# 战斗正常进行，无功能异常
```

---

#### 1.2 预加载战斗资源
- [ ] `construct_unit_addons.gd` 使用 preload
- [ ] `world_map_panel.gd` 使用 preload
- [ ] `tower_climb_manager.gd` 使用 preload
- [ ] `drop_manager.gd` 使用 preload
- [ ] 无运行时 load() 调用（动态资源除外）

**验证方法**:
```gdscript
# 搜索代码中的 load() 调用
# 确认都是必要的动态加载
# 场景切换无卡顿
```

---

#### 1.3 SubViewport渲染优化
- [ ] 战斗开始时设置 UPDATE_ALWAYS
- [ ] 战斗结束时设置 UPDATE_ONCE
- [ ] 主场景 main.gd 正确配置

**验证方法**:
```gdscript
# 启动战斗，检查 SubViewport 渲染
# 结束战斗，检查渲染停止
# FPS 在非战斗时提升
```

---

### ✅ 阶段2：对象池优化

#### 2.1 子弹与伤害数字（`ObjectPoolManager`）

> 旧版 `bullet_pool_manager.gd` / `damage_number_pool_manager.gd` 已删除，统一使用 autoload `ObjectPoolManager`。

- [ ] `project.godot` 已注册 `ObjectPoolManager`
- [ ] 子弹使用 `ObjectPoolManager.get_object("bullets")` / `return_object("bullets", ...)`
- [ ] 伤害数字使用 `DamageNumberDisplay.create_damage_number(...)` 或等价池 API
- [ ] 对象正确重置（`reset_pool_object` 等）

**验证方法**:
```gdscript
var stats = ObjectPoolManager.get_pool_stats("bullets")
print(stats)
```

**代码检查**:
```gdscript
ObjectPoolManager.return_object("bullets", self)
DamageNumberDisplay.create_damage_number(parent, world_pos, damage, is_crit, "normal")
```

---

#### 2.2（已合并至 2.1）

旧独立伤害数字池文档段落已废弃；见 2.1。

---

#### 2.3 通用对象池增强
- [ ] `object_pool.gd` 已更新
- [ ] 自动注册默认池
- [ ] 预加载场景常量
- [ ] 统计信息正确

**验证方法**:
```gdscript
# 检查自动注册
var all_stats = ObjectPoolManager.get_all_stats()
print("子弹池: ", all_stats.bullets)
print("伤害池: ", all_stats.damage_numbers)
```

---

### ✅ 阶段3：架构优化

#### 3.1 空间分区系统
- [ ] `spatial_grid.gd` 已创建
- [ ] 战斗管理器初始化网格
- [ ] 单位生成时插入网格
- [ ] 单位移动时更新网格
- [ ] 单位死亡时移除网格
- [ ] 索敌使用网格查询

**验证方法**:
```gdscript
# 检查网格统计
var stats = spatial_grid.get_stats()
print("单元格: ", stats.total_cells)
print("单位数: ", stats.total_units)
print("查询数: ", stats.query_count)

# 50个单位战斗，FPS应稳定
```

**代码检查**:
```gdscript
# construct_unit.gd / enemy_unit.gd
func setup(...):
    if spatial_grid:
        spatial_grid.insert(self)  # 必须

func _process(delta):
    if spatial_grid:
        spatial_grid.update(self)  # 必须

func _find_target():
    if spatial_grid:
        return spatial_grid.query_nearest_target(...)  # 必须
```

---

#### 3.2 性能基准测试工具
- [ ] `performance_benchmark.gd` 已创建
- [ ] 可以运行所有测试场景
- [ ] 结果正确导出
- [ ] 进度信号正常

**验证方法**:
```gdscript
# 运行基准测试
var benchmark = preload("res://tests/performance_benchmark.gd").new()
benchmark.start_benchmark(benchmark.TestScenario.BATTLE_50_UNITS)
# 等待完成，检查结果
```

---

## 🎯 性能验证清单

### 基准测试
- [ ] 运行10单位战斗测试
- [ ] 运行50单位战斗测试
- [ ] 运行大量特效测试
- [ ] 运行30分钟长时间测试
- [ ] 记录所有测试结果

### 性能指标
- [ ] 平均FPS > 50（50单位战斗）
- [ ] 最小FPS > 30（密集场景）
- [ ] 内存无泄漏（30分钟测试）
- [ ] 场景加载 < 2秒
- [ ] GC频率 < 10次/秒

### 对比分析
- [ ] 记录优化前基准数据
- [ ] 记录优化后数据
- [ ] 计算提升幅度
- [ ] 确认达到预期收益

---

## 🔍 代码质量检查

### 对象池使用
- [ ] 无混用 instantiate() 和对象池
- [ ] 所有对象正确归还
- [ ] 无内存泄漏
- [ ] 无野指针访问

### 空间网格使用
- [ ] 所有单位正确插入/更新/移除
- [ ] 网格查询结果正确
- [ ] 无遗漏单位
- [ ] 无重复查询

### 错误处理
- [ ] 对象池满时正确处理
- [ ] 网格边界检查
- [ ] 空值检查
- [ ] 异常情况恢复

---

## 📊 性能报告模板

完成优化后，填写此报告：

```
## 性能优化报告

### 测试环境
- Godot版本: 4.5
- 测试设备: [填写]
- 测试日期: 2026-04-11

### 优化前基准
| 指标 | 数值 |
|------|------|
| 平均FPS | |
| 内存(MB) | |
| GC次数/秒 | |
| 场景加载(秒) | |

### 优化后结果
| 指标 | 数值 | 提升 |
|------|------|------|
| 平均FPS | | +% |
| 内存(MB) | | -% |
| GC次数/秒 | | -% |
| 场景加载(秒) | | -% |

### 对象池统计
- 子弹池效率: %
- 伤害池效率: %
- 复用次数: 次

### 空间网格统计
- 单元格数量:
- 查询次数:
- 平均查询单位数:

### 遗留问题
- [如有，请列出]

### 后续优化建议
- [如有，请列出]
```

---

## ✅ 最终验收标准

### 必须满足（P0）
- ✅ 所有功能正常工作
- ✅ 无新增崩溃或严重bug
- ✅ FPS提升 > 30%
- ✅ 内存无泄漏

### 应该满足（P1）
- ✅ FPS提升 > 50%
- ✅ GC频率降低 > 50%
- ✅ 代码质量良好

### 可以满足（P2）
- ✅ UI延迟加载完成
- ✅ Autoload精简完成
- ✅ 特效优化完成

---

## 🚀 上线前检查

- [ ] 所有优化项已完成
- [ ] 性能测试全部通过
- [ ] 代码审查完成
- [ ] 文档更新完整
- [ ] 回滚方案准备
- [ ] 团队培训完成

---

**检查清单版本**: 1.0
**最后更新**: 2026-04-11
**维护者**: Claude
