# Phase War 项目全面检查报告

**生成时间**: 2026-06-08
**项目**: Phase War (Godot 4.5)
**分析范围**: 架构、测试、战斗、MOD、存档、性能、数据一致性

---

## 执行摘要

### 总体评估

| 类别 | 状态 | 严重问题数 | 中等问题数 | 低优先级问题数 |
|------|------|-----------|-----------|-------------|
| 架构合规性 | ⚠️ 需改进 | 3 | 2 | 2 |
| 测试覆盖率 | ❌ 不足 | 8 | 17 | 20 |
| 战斗系统 | ⚠️ 需调整 | 2 | 3 | 1 |
| MOD 系统 | ✅ 良好 | 0 | 4 | 1 |
| 存档系统 | ✅ 良好 | 0 | 2 | 1 |
| 性能优化 | ⚠️ 需改进 | 1 | 4 | 3 |
| 数据一致性 | 🔄 分析中 | - | - | - |

**总计**: 🔴 14 严重问题 | 🟡 32 中等问题 | 🟢 28 低优先级问题

---

## 1. 架构合规性分析

### 评分: ⚠️ 60/100

| 原则 | 合规性 | 评分 |
|------|--------|------|
| SignalBus 解耦 | ✅ 95% | 优秀 |
| Resource 模式 | ✅ 90% | 良好 |
| Data-as-Code | ✅ 95% | 优秀 |
| Lazy Loading | ⚠️ 60% | 需改进 |
| 管理器隔离 | ⚠️ 50% | 需改进 |
| 依赖注入 | ❌ 30% | 不足 |

### 🔴 严重问题

#### 1. BattleManager 直接 Autoload 引用
**文件**: `managers/battle/battle_manager.gd:13-14`
```gdscript
@onready var energy_manager: Node = EnergyManager
@onready var phase_instrument: Node = PhaseInstrumentManager
```
**问题**: 违反依赖注入模式
**修复**: 使用 `setup()` 方法注入依赖

#### 2. 延迟加载管理器仍被 Autoload
**文件**: `project.godot` [autoload] 部分
**受影响管理器**:
- CardEnhancementManager
- AffixManager
- IntelManual
- IntelItemBag
- IntelDiscoveryManager
- IntelEvolutionManager
- EnemyOriginModManager

**问题**: 既被 Autoload 又配置延迟加载， defeating 架构目的

#### 3. get_node_or_null("/root/XXX") 直接耦合
**影响范围**: 100+ 处
**示例**:
- `managers/game_manager.gd:118`
- `managers/quest_manager.gd:52`
- `managers/blueprint_manager.gd:53`

### 修复优先级

**HIGH**:
1. 移除 BattleManager 中的 @onready 单例引用
2. 从 project.godot 移除重复的 autoload 条目
3. 审计所有 get_node_or_null 调用，包装 ManagerLazyLoader.ensure_loaded()

**MEDIUM**:
4. 标准化管理器访问模式
5. 添加架构验证测试

---

## 2. 测试覆盖率分析

### 评分: ❌ 25/100

### 当前测试覆盖 (23 个测试文件)

**已测试管理器**:
- ✅ EnergyManager (16 tests)
- ✅ BasicResourceManager (22 tests)
- ✅ DailyTaskManager (27 tests)

**已测试战斗系统**:
- ✅ 伤害计算
- ✅ Affix 缩放
- ✅ 敌人状态解析

**已测试数据层**:
- ✅ Battle card v3
- ✅ Level information
- ✅ Blueprint star config
- ✅ Military titles

### 🔴 严重问题 - 无测试的关键文件

**核心管理器 (0% 覆盖)**:
1. `BlueprintManager` - 核心进度系统
2. `GameManager` - 主游戏流程
3. `BattleManager` - 战斗编排
4. `PhaseInstrumentManager` - 装备系统
5. `PhaseLawManager` - 法则系统
6. `SaveManager` - 存档协调
7. `DropManager` - 奖励系统

**v6.0 Intel 系统 (0% 覆盖)**:
8. `IntelManual` - 4 维情报系统
9. `IntelDiscoveryManager` - 112 个揭示事件
10. `EnemyOriginModManager` - 敌方起源 MOD
11. `IntelEvolutionManager` - 4 条隐藏进化

**进化/MOD 系统 (0% 覆盖)**:
12. `CardEvolutionManager` - 进化路径逻辑
13. `ModManager` - MOD 应用和冲突

**派系系统 (0% 覆盖)**:
14. `FactionSystemManager` - 7 派系声望
15. `FactionCardGenerator` - 派系卡片生成
16. `SynthesisManager` - 混合卡片合成

**关键数据文件 (0% 覆盖)**:
17. `default_cards.gd` - 110+ 单位定义
18. `phase_laws.gd` - 4 家族法则
19. `intel_dimensions.gd` - 4 情报维度
20. `intel_reveal_events.gd` - 112 揭示事件
21. `intel_evolution_branches.gd` - 4 隐藏进化分支
22. `enemy_origin_mods.gd` - 9 敌方起源 MOD
23. `evolution_paths/*` - 8 条进化路径
24. `modification_modules/*` - 7 类别 MOD 模块
25. `faction_skill_tree.gd` - 派系技能树

### 修复优先级

**Tier 1 - 关键** (游戏破坏性):
- BlueprintManager
- SaveManager
- BattleManager
- GameManager

**Tier 2 - 高** (主要功能):
- PhaseInstrumentManager
- PhaseLawManager
- v6.0 Intel 系统 (4 个文件)
- Evolution/Mod 管理器 (2 个文件)

**Tier 3 - 中** (重要但可隔离):
- 派系系统 (5 个文件)
- 任务/成就管理器
- CardEnhancementManager

---

## 3. 战斗系统分析

### 评分: ⚠️ 65/100

### 🔴 严重问题

#### 1. 伤害计算 Bug
**文件**: `scripts/battle/attack_calculator.gd:51`
```gdscript
var max_range = distance  # BUG: 应使用武器的 max_range
```
**问题**: 衰减计算总是将目标视为在最大射程
**影响**: 伤害衰减计算不正确
**修复**: 使用 `weapon.max_range` 而不是 `distance`

#### 2. 重复函数问题
**文件**: `scripts/battle/attack_calculator.gd`
- `calculate_damage()` - 有 bug
- `calculate_damage_with_range()` - 正确

**建议**: 废弃第一个函数以防止混淆

### 🟡 中等问题

#### 3. 年代缩放不平衡
| 年代 | 伤害 | HP | 范围 |
|-----|------|-----|------|
| WWI | 1.00× | 1.00× | 1.00× |
| WWII | 1.20× | 1.15× | 1.10× |
| Cold War | 1.40× | 1.30× | 1.20× |
| Modern | 1.65× | 1.45× | 1.30× |
| Near Future | 1.90× | 1.60× | 1.40× |

**问题**:
- 伤害增长递减 (20%, 20%, 25%, 25%)
- 现代到未来仅 +15% 伤害
- 基础属性增加 4-6× 与年代乘数叠加，极端幂增

#### 4. 无年代防御缩放
**问题**: 防御值仅通过基础属性增加，不使用年代乘数
**影响**: 高年代单位相对防御过强

#### 5. 基础属性曲线
- WWI 步兵: 35 攻击
- Modern 步兵: 140 攻击
- Future 步兵: 200 攻击
- **问题**: 4-6× 增加与 1.9× 年代乘数叠加

### 修复优先级

**HIGH**:
1. 修复 attack_calculator.gd:51 的 max_range bug
2. 废弃 calculate_damage() 函数

**MEDIUM**:
3. 重新平衡年代乘数以保持一致的相对力量差距
4. 添加年代防御缩放
5. 审查 default_cards.gd 中的基础属性曲线

---

## 4. MOD 系统分析

### 评分: ✅ 80/100

### MOD 统计
- **总计**: 117 MOD (文档声称 140+)
- **分布**: 步兵(22), 装甲(15), 火炮(12), 防空(12), 空军(14), 侦察(12), 工兵(10), 堡垒(10), 通用(10)

### 稀有度分布
| 稀有度 | 数量 | 百分比 |
|--------|-----|--------|
| 普通 | 2 | 1.7% |
| 罕见 | 18 | 15.4% |
| 稀有 | 33 | 28.2% |
| 史诗 | 38 | 32.5% |
| 传说 | 14 | 12.0% |

### 🟡 中等问题

#### 1. 过强稀有 MOD
**aa_01_radar** (防空, 稀有)
- 效果: attack_interval -50%, accuracy_bonus +30%
- 问题: -50% 攻击间隔对稀有来说过强
- 建议: 降至 -30% 或提升至史诗

**art_09_rapid_fire** (火炮, 稀有)
- 效果: attack_interval -30%
- 问题: 对稀有来说过强
- 建议: 降至 -20% 或提升至史诗

#### 2. 过强史诗 MOD
**art_06_fire_computer** (火炮, 史诗)
- 效果: attack_interval -40%
- 问题: 对史诗来说极强
- 建议: 降至 -30%

**arm_06_apfsds** (装甲, 史诗)
- 效果: attack_armor +35%, attack_light -15%
- 问题: +35% 单 MOD 加成过高
- 建议: 降至 +30%

#### 3. 稀有度分布失衡
**问题**: 普通层级严重不足 (仅 2 MOD)
**建议**: 添加 5-8 个更多普通层级选项

### 修复优先级

**HIGH**:
1. 削弱 aa_01_radar: -50% → -30%
2. 削弱 art_09_rapid_fire: -30% → -20%

**MEDIUM**:
3. 削弱 art_06_fire_computer: -40% → -30%
4. 添加普通层级 MOD (目标 8-10 个)

---

## 5. 存档系统分析

### 评分: ✅ 85/100

### Schema v5 状态: ✅ 通过

**迁移链**: v1 → v2 → v3 → v4 → v5 ✅ 完整

### 管理器存档覆盖
| 管理器 | save_state | load_state | 状态 |
|--------|-----------|------------|------|
| BlueprintManager | ✅ | ✅ | Schema v5 兼容 |
| BasicResourceManager | ✅ | ✅ | 向后兼容 |
| PhaseLawManager | ✅ | ✅ | |
| QuestManager | ✅ | ✅ | |
| FactionSystemManager | ✅ | ✅ | |
| AffixManager | ✅ | ✅ | |
| LevelProgressManager | ✅ | ✅ | |
| DropManager | ✅ | ✅ | |
| IntelItemBag | ✅ | ✅ | v6.0 新增 |

### 🟡 中等问题

#### 1. IntelItemBag 双序列化
**问题**: 使用 SaveUtils 独立序列化 AND save_state()
**影响**: 可能数据分歧

#### 2. 测试覆盖稀疏
**问题**: 仅 2 个基本测试
**建议**: 添加迁移测试、数据完整性测试

### 修复优先级

**MEDIUM**:
1. 统一 IntelItemBag 序列化方式
2. 添加存档系统测试覆盖

**LOW**:
3. 启用调试日志 (DEBUG_SAVE_LOG, ENABLE_DETAILED_LOAD_VALIDATION)

---

## 6. 性能分析

### 评分: ⚠️ 60/100

### 🔴 严重问题

#### 1. 对象池初始大小不足
**当前设置**:
- 子弹: 2 初始 / 100 最大
- 伤害数字: 4 初始 / 40 最大

**问题**: 低初始大小导致战斗期间频繁扩展
**建议**:
- 子弹: 2 → 20-30
- 伤害数字: 4 → 15-20

### 🟡 中等问题

#### 2. UI 更新无节流
**受影响**:
- 血条 (health_bar.gd)
- 能量条 (energy_bar.gd)

**建议**: 每 100-200ms 更新一次

#### 3. Tween 生命周期管理
**问题**:
- animation_utils 创建 tweens 无清理跟踪
- pulse_animation 使用 set_loops() 无清理机制
- 战斗特效 shake tween 处理全局存储引用

**建议**: 实现 tween 生命周期跟踪和清理

#### 4. 目标查找频率
**问题**: 单位使用 300ms 间隔但仍执行周期性扫描
**建议**: 缓存空间网格查询，实现增量更新

### 🟢 低优先级问题

#### 5. 粒子材质缓存扩展
**建议**: 为不同武器类型添加更多预烘焙材质

#### 6. LOD 系统实现
**建议**: 基于 FPS 降低效果质量

### 修复优先级

**HIGH**:
1. 增加对象池初始大小
2. 实现 UI 更新节流
3. 添加 Tween 生命周期管理

**MEDIUM**:
4. 优化目标查找
5. 扩展粒子材质缓存

**LOW**:
6. 实现 LOD 系统
7. 添加异步资源预加载

### 性能目标
- TTI: < 2500ms
- 背包首次打开: < 450ms
- 战斗帧时间 P50: < 16.7ms (60 FPS)
- 战斗帧时间 P95: < 25ms

---

## 7. 数据一致性分析

### 评分: ✅ 85/100

### 验证结果

| 验证类型 | 状态 | 详情 |
|----------|------|------|
| 跨文件引用 | ✅ 通过 | default_cards.gd 中所有进化目标有效 |
| 数据范围 | ✅ 通过 | 所有 era/combat_kind/power 值在有效范围内 |
| 数据完整性 | ✅ 通过 | 所有 115 个单位具有必需字段 |
| 本地化 | ⚠️ 部分 | 仅中文；军衔有英文 |

### 🟡 中等问题

#### 1. 本地化不完整
**问题**: 卡片单位缺乏英文本地化
**位置**: `data/default_cards.gd`
**影响**: 无英文支持

#### 2. 调试日志已禁用
**问题**: 存档系统调试日志已禁用
**位置**: `scripts/systems/save_migration.gd`
**影响**: 生产环境中难以诊断问题

#### 3. 特殊 MOD 效果需要验证
**问题**: 部分 MOD 特效可能未完全实现
**位置**: `scripts/battle/module_effect_handler.gd`
**需验证效果**:
- smoke_ignore
- night_bonus
- missile_intercept
- multi_target

### 修复优先级

**MEDIUM**:
1. 添加卡片单位英文本地化
2. 验证特殊 MOD 效果实现

**LOW**:
3. 启用存档系统调试日志（仅开发环境）

---

## 修复优先级总结

### 🔴 立即修复 (严重)

| # | 问题 | 文件 | 预计工时 |
|---|------|------|----------|
| 1 | max_range bug | scripts/battle/attack_calculator.gd:51 | 1h |
| 2 | 对象池初始大小 | managers/object_pool.gd | 0.5h |
| 3 | Autoload 重复加载 | project.godot | 0.5h |
| 4 | BattleManager 依赖注入 | managers/battle/battle_manager.gd | 2h |
| 5 | MOD 平衡性调整 | data/modification_modules/*.gd | 2h |
| 6 | 核心管理器测试 | tests/unit/* | 16h |
| 7 | v6.0 系统测试 | tests/unit/* | 8h |
| 8 | 数据文件测试 | tests/unit/data/* | 12h |

**总计**: ~42 小时

### 🟡 短期修复 (中等)

| # | 问题类别 | 预计工时 |
|---|----------|----------|
| 1 | 年代缩放平衡 | 4h |
| 2 | UI 更新节流 | 3h |
| 3 | Tween 生命周期管理 | 4h |
| 4 | 管理器访问模式标准化 | 6h |
| 5 | 存档系统测试 | 4h |
| 6 | IntelItemBag 双序列化修复 | 2h |

**总计**: ~23 小时

### 🟢 长期优化 (低优先级)

| # | 优化项 | 预计工时 |
|---|--------|----------|
| 1 | LOD 系统实现 | 8h |
| 2 | 异步资源预加载 | 6h |
| 3 | 粒子材质缓存扩展 | 4h |
| 4 | 架构文档更新 | 4h |
| 5 | 普通层级 MOD 添加 | 4h |

**总计**: ~26 小时

---

## 建议修复路线图

### Week 1: 关键 Bug 和架构
1. 修复 max_range bug (1h)
2. 修复对象池大小 (0.5h)
3. 移除 Autoload 重复加载 (0.5h)
4. 重构 BattleManager 依赖注入 (2h)

### Week 2-3: 平衡性和测试
1. MOD 平衡性调整 (2h)
2. 核心管理器测试 (16h)
3. v6.0 系统测试 (8h)

### Week 4: 性能优化
1. UI 更新节流 (3h)
2. Tween 生命周期管理 (4h)
3. 目标查找优化 (4h)

### Week 5+: 长期优化
1. LOD 系统实现
2. 年代缩放重平衡
3. 数据一致性验证系统

---

## 附录

### A. 文件变更清单

**需要修改的文件**:
1. `scripts/battle/attack_calculator.gd`
2. `managers/battle/battle_manager.gd`
3. `managers/object_pool.gd`
4. `project.godot`
5. `data/modification_modules/aa_01_radar` (假设存在)
6. `data/modification_modules/art_09_rapid_fire`
7. `scenes/ui/health_bar.gd`
8. `scenes/ui/energy_bar.gd`
9. `scripts/animation_utils.gd`

### B. 新增测试文件建议

1. `tests/unit/managers/test_blueprint_manager.gd`
2. `tests/unit/managers/test_game_manager.gd`
3. `tests/unit/managers/test_battle_manager.gd`
4. `tests/unit/managers/test_save_manager.gd`
5. `tests/unit/intel/test_intel_discovery_manager.gd`
6. `tests/unit/intel/test_intevolution_manager.gd`
7. `tests/unit/data/test_default_cards.gd`
8. `tests/unit/data/test_phase_laws.gd`
9. `tests/unit/data/test_intel_reveal_events.gd`
10. `tests/unit/faction/test_faction_system_manager.gd`

---

**报告生成**: 2026-06-08
**下次审查建议**: 修复完成后 2 周
