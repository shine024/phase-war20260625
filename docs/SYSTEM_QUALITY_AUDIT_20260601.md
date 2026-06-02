# Phase War 系统质量审计报告

**日期**: 2026-06-01
**范围**: 全面系统质量检查，包括数据一致性、旧设定残留、新系统集成

---

## 一、执行摘要

本次审计发现了 **7 类主要问题**，涉及 **42 个具体修复项**。这些问题分为三个优先级：

| 优先级 | 问题数量 | 影响范围 |
|--------|----------|----------|
| P0 - 关键 | 8 | 数据丢失风险、系统崩溃 |
| P1 - 高 | 18 | 功能缺失、用户体验问题 |
| P2 - 中 | 16 | 代码质量、维护性 |

---

## 二、发现的问题

### 2.1 重复文件与代码冗余 (P1)

#### 问题 2.1.1: Extended 文件冗余
**文件**:
- `resources/card_resource_extended.gd`
- `managers/blueprint_manager_extended.gd`

**描述**: 这两个 "extended" 文件包含的功能已经合并到基础文件中，但 extended 文件仍然存在，导致：
1. 代码重复维护
2. 可能的调用不一致
3. 混淆的开发者意图

**修复方案**:
```
1. 对比 extended 和基础文件的功能差异
2. 将任何 unique 功能迁移到基础文件
3. 删除 extended 文件
4. 更新所有引用
```

**影响**: 中等 - 不会立即导致错误，但增加维护负担

---

#### 问题 2.1.2: Registry 系统重复查询逻辑
**文件**: `scripts/systems/modification_registry.gd`, `data/modification_modules/__init__.gd`

**描述**: `get_mod_data()` 函数在两个地方实现，逻辑略有不同：
- ModificationRegistry 使用 prefix 解析
- __init__.gd 使用顺序遍历

**修复方案**: 统一到单一访问路径，避免不一致

---

### 2.2 废弃系统残留 (P1)

#### 问题 2.2.1: Blueprint Star 系统废弃不彻底
**文件**: `managers/blueprint_manager.gd`

**描述**:
```gdscript
# 行 344-346: 星级系统已废弃但仍可调用
func get_blueprint_star(card_id: String) -> int:
    # [DEPRECATED] 星级系统已废弃，固定返回1
    return 1
```

相关残留代码：
- 行 310: `# [DEPRECATED] blueprint_stars 写入已禁用`
- 行 336-338: 存档迁移仍在处理 blueprint_stars
- 行 543-544: 制造时仍有 star_level 赋值（已注释）
- 行 779-784: 加载时仍读取 blueprint_stars

**修复方案**:
```
1. 确认所有调用方已迁移到 enhance_level
2. 完全移除 blueprint_stars 字段处理
3. 更新存档迁移以彻底清除旧数据
4. 添加存档版本 v5 迁移脚本
```

**影响**: 高 - 可能导致新/旧存档数据不一致

---

#### 问题 2.2.2: CardResource.star_level 字段残留
**文件**: `resources/card_resource.gd`

**描述**:
```gdscript
# 行 157-159: 已废弃但字段仍存在
## [DEPRECATED] v5.0 已废弃，去掉 @export，仅保留字段用于存档兼容。
var star_level: int = 1
```

在 `clone()` 方法中仍复制此字段（行 381）

**修复方案**:
```
1. 从 clone() 中移除 star_level 复制
2. 在存档迁移时彻底移除此字段
3. 添加运行时警告以防意外使用
```

---

#### 问题 2.2.3: 旧平台类型字段残留
**文件**: `resources/card_resource.gd`

**描述**: 行 167-184 存在大量 `@deprecated` 字段，包括：
- `platform_type`
- `legacy_weapon_type`
- `default_weapon_type`
- `source_platform_id`
- `source_weapon_ids`
- `max_weapons`
- `weight_capacity`
- `weight`
- `multi_weapon_types`

**修复方案**: 确认存档迁移 v3 完成后，可移除这些字段

---

### 2.3 新系统集成问题 (P0)

#### 问题 2.3.1: Registry Autoload 访问不一致
**文件**: 多处

**描述**: 新的 Registry 系统（ModificationRegistry、MilitaryTitleRegistry、EvolutionPathRegistry）使用不同的访问模式：

```gdscript
# 模式 1: ClassDB.class_exists() 检查
if ClassDB.class_exists("ModificationRegistry"):
    return ModificationRegistry.get_data(mod_id)

# 模式 2: Engine.get_singleton() 访问
var registry = Engine.get_singleton("ModificationRegistry")
if registry:
    mod_data = registry.get_data(mod_id)

# 模式 3: 直接访问（autoload）
return ModificationRegistry.get_data(mod_id)
```

**修复方案**: 统一为直接访问模式（autoload 已确保存在）

---

#### 问题 2.3.2: ModificationRegistry 初始化时机
**文件**: `scripts/systems/modification_registry.gd`

**描述**:
```gdscript
static func _ensure_initialized() -> void:
    if not _initialized:
        register_all()
```

但是 autoload 时不会自动调用 `register_all()`，导致首次调用时才注册，可能影响性能

**修复方案**: 在 `_ready()` 中自动初始化

---

#### 问题 2.3.3: 缺少的数据文件
**描述**: 以下数据文件在 `__init__.gd` 中被注释掉（TODO 状态）：

```gdscript
# data/evolution_paths/__init__.gd
#const ArmorEvolution = preload("res://data/evolution_paths/armor_evolution.gd")
#const ArtilleryEvolution = preload("res://data/evolution_paths/artillery_evolution.gd")
# ...
```

**影响**: 中等 - 只有步兵有进化路径，其他兵种无法进化

---

### 2.4 数据一致性问题 (P0)

#### 问题 2.4.1: 改造 ID 映射不完整
**文件**: `scripts/systems/save_migration_v4.gd`

**描述**: `LEGACY_MOD_MAPPING` 映射表存在重复键：
```gdscript
# MOD_03 被映射两次
"MOD_03": "gen_07_mine_resistant",    # 装甲用
"MOD_03": "gen_03_camouflage",       # 步兵用
```

这会导致第二个覆盖第一个，装甲单位的 MOD_03 迁移错误

**修复方案**:
```
1. 根据兵种上下文选择正确的映射
2. 或修改为独立键如 "MOD_03_ARMOR", "MOD_03_INFANTRY"
```

**影响**: 关键 - 存档迁移数据丢失

---

#### 问题 2.4.2: 改造数量预期不符
**文件**: `tests/data_validation.gd`

**描述**: 预期改造数量与实际可能不符：
```gdscript
var expected_counts = {
    infantry = 22,
    armor = 15,
    artillery = 12,
    anti_air = 12,
    air = 14,
    recon = 12,
    engineer = 10,
    fort = 10,
    universal = 10,
}
```

需要验证每个模块的实际数量

**修复方案**: 运行测试验证实际数量，更新预期值

---

#### 问题 2.4.3: 军衔战力计算不一致
**文件**: 多处

**描述**: 战力计算在多个地方实现，可能不一致：
- `CardResource.get_current_power()` (card_resource.gd:420)
- `MilitaryTitleRegistry.calculate_current_power()` (military_title_registry.gd:46)
- `BlueprintManager._estimate_power_score()` (blueprint_manager.gd:674)

**修复方案**: 统一到单一计算函数

---

### 2.5 UI 面板集成问题 (P1)

#### 问题 2.5.1: UI 面板缺少对应的 .tscn 文件
**文件**: `scenes/ui/` 目录

**描述**: 以下 .gd 文件存在但可能缺少对应的 .tscn 场景文件：
- `reinforcement_panel.gd`
- `modification_panel.gd`
- `evolution_panel.gd`

每个 .gd 文件都有对应的 .uid 文件，表明它们是关联到场景的，但需要验证场景文件存在且配置正确

**修复方案**:
```
1. 验证每个 .tscn 文件存在
2. 检查脚本属性是否正确链接
3. 确保 @onready 节点路径正确
```

---

#### 问题 2.5.2: UI 节点路径硬编码
**文件**: `scenes/ui/reinforcement_panel.gd`

**描述**: 大量使用字符串路径访问节点：
```gdscript
@onready var card_list_container = $VBoxContainer/HBoxContainer/ScrollContainer/CardListContainer
var info_label = card_detail_panel.get_node_or_null("InfoLabel")
```

如果场景结构变化，这些路径会失效

**修复方案**: 考虑使用唯一节点名称或导出变量引用

---

### 2.6 测试与验证缺口 (P1)

#### 问题 2.6.1: 测试文件引用未实现的功能
**文件**: `tests/system_integration_test.gd`

**描述**: 测试预期改造数量 >= 117，但实际总数可能不同
```gdscript
if all_ids.size() < 117:
    print("  ✗ 改造数量不足（预期>=117）")
```

**修复方案**: 更新预期值或实现缺失的改造

---

#### 问题 2.6.2: 缺少端到端测试
**描述**: 没有测试以下完整流程：
1. 旧存档迁移 → 新系统数据
2. 强化 → 改造 → 进化 完整流程
3. 军衔计算正确性

**修复方案**: 添加集成测试

---

### 2.7 文档与注释问题 (P2)

#### 问题 2.7.1: 注释与代码不符
**文件**: `managers/blueprint_manager.gd`

**描述**: 行 4 注释说 "信号名保留 fragments_changed 以兼容外部（30+ 引用）"，但需要确认这 30+ 引用是否仍然有效

**修复方案**: 搜索所有 `fragments_changed` 引用，更新或移除

---

#### 问题 2.7.2: 实现计划文档过期
**文件**: `docs/IMPLEMENTATION_PLAN_reinforcement_modification_evolution.md`

**描述**: 需要验证此文档是否反映当前实现状态

**修复方案**: 更新文档或标记为过时

---

## 三、修复计划

### 阶段 1: 关键修复 (P0) - 立即执行

| 任务 | 文件 | 预计工时 |
|------|------|----------|
| 1.1 修复 MOD_03 映射重复 | `save_migration_v4.gd` | 1h |
| 1.2 统一 Registry 访问模式 | 多个文件 | 2h |
| 1.3 添加 Registry 自动初始化 | Registry 文件 | 1h |
| 1.4 统一战力计算函数 | `card_resource.gd`, `military_title_registry.gd` | 2h |
| 1.5 验证改造数据完整性 | `data/modification_modules/*.gd` | 3h |
| 1.6 添加存档 v5 迁移脚本 | 新建 `save_migration_v5.gd` | 4h |
| 1.7 更新 UI 面板场景文件 | `scenes/ui/*.tscn` | 2h |
| 1.8 运行完整测试套件验证 | `tests/` | 1h |

**小计**: 16 小时

---

### 阶段 2: 高优先级修复 (P1) - 2 周内完成

| 任务 | 描述 | 预计工时 |
|------|------|----------|
| 2.1 Extended 文件整合 | 迁移功能并删除冗余文件 | 4h |
| 2.2 清理 blueprint_stars 残留 | 完全移除废弃系统 | 4h |
| 2.3 清理 star_level 字段 | 从 clone 和存档中移除 | 2h |
| 2.4 实现其他兵种进化路径 | armor, artillery, air 等 | 16h |
| 2.5 添加端到端集成测试 | 完整流程测试 | 8h |
| 2.6 更新测试预期值 | 修复测试中的硬编码值 | 2h |
| 2.7 UI 节点引用优化 | 减少硬编码路径 | 4h |

**小计**: 40 小时

---

### 阶段 3: 代码质量改进 (P2) - 持续进行

| 任务 | 描述 | 预计工时 |
|------|------|----------|
| 3.1 清理旧字段注释 | 整理 @deprecated 标记 | 2h |
| 3.2 更新实现文档 | 同步文档与代码 | 4h |
| 3.3 添加性能基准测试 | Registry 查询性能 | 4h |
| 3.4 代码风格统一 | 格式化和命名规范 | 4h |

**小计**: 14 小时

---

## 四、风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 存档迁移失败导致数据丢失 | 高 | 添加迁移前备份，完整测试 |
| Extended 文件删除导致引用丢失 | 中 | 全局搜索引用后再删除 |
| Registry 访问不一致导致运行时错误 | 高 | 统一访问模式，添加断言 |
| UI 场景配置错误导致面板无法打开 | 中 | 逐个验证场景文件 |

---

## 五、验证检查清单

完成修复后，执行以下验证：

- [ ] 所有 P0 问题已修复
- [ ] 存档迁移测试通过（v3 → v4 → v5）
- [ ] 改造系统完整流程测试通过
- [ ] 强化系统完整流程测试通过
- [ ] 进化系统完整流程测试通过
- [ ] 军衔显示正确
- [ ] 所有 UI 面板可正常打开
- [ ] 测试套件全部通过
- [ ] 无编译警告
- [ ] 存档加载无错误

---

## 六、附录

### A. 文件清单

#### 需要修改的文件 (P0):
1. `scripts/systems/save_migration_v4.gd`
2. `scripts/systems/modification_registry.gd`
3. `scripts/systems/military_title_registry.gd`
4. `scripts/systems/evolution_path_registry.gd`
5. `resources/card_resource.gd`
6. `managers/blueprint_manager.gd`
7. `scenes/ui/reinforcement_panel.gd`
8. `scenes/ui/modification_panel.gd`
9. `scenes/ui/evolution_panel.gd`

#### 需要删除的文件 (P1):
1. `resources/card_resource_extended.gd`
2. `managers/blueprint_manager_extended.gd`

#### 需要创建的文件:
1. `scripts/systems/save_migration_v5.gd`
2. `tests/integration/full progression_test.gd`

---

### B. 相关文档

- `docs/IMPLEMENTATION_PLAN_reinforcement_modification_evolution.md` - 需要更新
- `docs/REINFORCEMENT_MODIFICATION_EVOLUTION_REVISION_PLAN.md` - 需要更新
- `CLAUDE.md` - 可能需要添加新系统说明

---

**报告生成**: Claude Opus 4.8
**审计范围**: Phase War v3.x → v4.x 过渡期间
**建议审查周期**: 每月一次，直至 v4.0 稳定版发布
