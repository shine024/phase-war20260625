# 📊 《相位战争》项目全面检查报告

> **检查日期**：2026-05-31（星期日）
> **检查范围**：全量代码 + 全部设计/审计文档 + 项目配置
> **引擎版本**：Godot 4.5.1
> **检查工具**：DeepV Code Agent（文件扫描 + 代码分析 + 文档交叉验证）

---

## 第一部分：游戏设定总览

### 1.1 基本信息

| 项目 | 内容 |
|------|------|
| **游戏名** | 相位战争：构装纪元 (Phase War: Assembly Era) |
| **引擎** | Godot 4.5 / GDScript |
| **类型** | 横版自动对战卡牌构筑策略游戏 |
| **规模** | 100关卡 / 5时代 / 7阵营 / 110战斗单位 + 7能量卡 / 24法则 |
| **目标平台** | PC (60FPS / 1280×720 / 内存<512MB) |

### 1.2 核心设计原则

| 原则 | 说明 |
|------|------|
| **自动对战** | 玩家布阵，系统自动战斗，战中无操作 |
| **策略在战前** | 所有决策在编队界面完成 |
| **克制决定胜负** | 攻击/防御的多维克制是核心 |
| **成长有方向** | 进化分支让玩家选择"转职"方向 |
| **改造可继承** | 进化后改造完全保留，可替换 |

### 1.3 世界观

- **时代跨度**：一战 → 二战 → 冷战 → 现代 → 近未来的架空战争史
- **叙事基调**：硬核军事装备感与科幻元素并存
- **玩家角色**：掌控"相位仪"的指挥官，远程投射构装单位作战
- **四大法则家族**：钢铁 / 烈焰 / 雷霆 / 虚空

### 1.4 三大卡牌类型

| 编号 | 卡牌类型 | 说明 |
|------|---------|------|
| 0 | 战斗单位卡 (Combat Unit) | 平台+武器组合，部署到战场自动战斗 |
| 1 | 能量卡 (Energy) | 提供能量池/回复/即时补充 |
| 2 | 法则卡 (Law) | 主动/被动战斗技能，4大法则家族 |

### 1.5 战斗系统核心

| 维度 | 设计 |
|------|------|
| **战场布局** | 横向单排 6v6 |
| **胜负条件** | 消灭所有敌方波次=胜利 / 己方核心被摧毁=失败 |
| **三维攻击** | attack_light / attack_armor / attack_air（对不同CombatKind） |
| **三维防御** | defense_light / defense_armor / defense_air |
| **武器类型** | DIRECT(直射/有衰减) / INDIRECT(曲射/全图) / AERIAL(空射/全图/可拦截) |
| **CombatKind** | LIGHT(0) / ARMOR(1) / AIR(2) / SUPPORT(3) / FORT(4) |
| **伤害公式** | 击穿检查 + 100/(100+def)，射程衰减仅DIRECT |
| **选敌逻辑** | DIRECT→最近 / INDIRECT→优先克制 / AERIAL→优先空中 |
| **部署速度** | 公式：delay = max(0, (8 - deploy_speed) × 1.5)，已实现 |

### 1.6 成长系统

| 系统 | 说明 | 玩家操作 |
|------|------|---------|
| **进化 (E0→E1→E2→E3)** | 卡牌转职/进阶 | 消耗资源，需情报100%+战力达标 |
| **强化 (Lv1-10)** | 提升卡牌基础属性 | 消耗纳米材料，100%成功 |
| **改造 (最多9次)** | 改变卡牌特性/定位 | 消耗研究点，可替换 |
| **模块化词条** | 战斗内被动效果（暴击/吸血/溅射/护盾） | 装配词条模块 |
| **能量系统** | 部署单位消耗 | 自动回复，战前配置 |
| **法则系统** | 主动/被动技能 | 装配到相位仪 |
| **军衔 (13级)** | 整体战力标识 | 总战力达到门槛 |

### 1.7 情报手册系统

| 行为 | 情报获取量 |
|------|-----------|
| 首次遭遇 | +20% |
| 击败普通 | +5%~10% |
| 击败精英/BOSS | +15%~25% |
| 侦察单位/法则 | +5%~15% |
| 重复卡分解 | +10% |

### 1.8 情报道具系统（v6.0）

6种一次性消耗品：强化手册、升星指南、改装指南(基础/进阶/高级)、进化图纸。
来源：战斗掉落(12%-22%) + 商店购买。

### 1.9 资源经济

| 资源 | 用途 |
|------|------|
| 纳米材料 | 强化卡牌 |
| 研究点 | 升星、改造 |
| 知识值 | 解锁法则 |
| 情报道具 | 替代部分资源消耗（强化/升星/改装/进化） |

---

## 第二部分：项目代码结构

### 2.1 项目规模

| 指标 | 数值 |
|------|------|
| GDScript 文件总数 | ~331个 |
| 场景文件(.tscn) | 75个 |
| Autoload 单例 | 21个 |
| Manager 层代码量 | ~18,245行 (58个.gd文件) |
| Data 层定义文件 | 67个.gd + 4个JSON |
| 测试文件 | ~15个 |

### 2.2 Autoload 单例 (21个)

| 名称 | 脚本 | 用途 |
|------|------|------|
| SignalBus | scripts/signal_bus.gd | 全局信号总线 |
| BattleInputState | scripts/battle_input_state.gd | 战斗输入状态机 |
| EnergyManager | managers/energy_manager.gd | 能量/资源管理 |
| PhaseInstrumentManager | managers/phase_instrument_manager.gd | 相位仪器装备管理 |
| BattleManager | managers/battle/battle_manager.gd | 战斗流程编排 |
| GameManager | managers/game_manager.gd | 全局状态与流程控制 |
| BlueprintManager | managers/blueprint_manager.gd | 蓝图/卡牌数据管理 |
| DropManager | managers/drop_manager.gd | 掉落物与奖励 |
| SaveManager | managers/save_manager.gd | 存档/读档/迁移 |
| AudioManager | managers/audio_manager.gd | 音频管理 |
| PhaseLawManager | managers/phase_law_manager.gd | 相位法则系统 |
| BasicResourceManager | managers/basic_resource_manager.gd | 基础资源(货币/材料) |
| ObjectPoolManager | managers/object_pool.gd | 对象池 |
| UILazyLoader | managers/ui_lazy_loader.gd | UI延迟加载 |
| ManagerLazyLoader | managers/manager_lazy_loader.gd | Manager延迟初始化 |
| PerformanceMetricsManager | managers/performance_metrics_manager.gd | 性能指标监控 |
| IntelManual | scripts/systems/intel_manual.gd | 情报手册 |
| IntelItemBag | managers/intel_item_bag.gd | 情报物品背包 |
| IntelDiscoveryManager | scripts/systems/intel_discovery_manager.gd | 情报发现管理 |
| EnemyOriginModManager | scripts/systems/enemy_origin_mod_manager.gd | 敌人起源修正 |
| IntelEvolutionManager | scripts/systems/intel_evolution_manager.gd | 情报进化管理 |

### 2.3 Manager 大文件排行

| 文件 | 行数 | 状态 |
|------|------|------|
| phase_instrument_manager.gd | **1,097** | ⚠️ 超过1000行阈值 |
| save_manager.gd | 984 | 需关注 |
| blueprint_manager.gd | 875 | 职责膨胀(已标记拆分) |
| battle_spawn_system.gd | 810 | 已从battle_manager拆分 |
| faction_system_manager.gd | 699 | 已拆分为reputation+shop |
| phase_law_manager.gd | 667 | — |
| affix_manager.gd | 643 | 待决策(保留/删除) |
| battle_manager.gd | 623 | 已从969行拆分 |
| game_manager.gd | 597 | — |
| achievement_manager.gd | 573 | 已拆分为checker+rewards |

### 2.4 技术债务登记 (tech-debt-register)

| 状态 | 数量 | 完成率 |
|------|------|--------|
| ✅ Done | 8/8 (TD-001~006, 008) | 87.5% |
| 🟡 Partial | 1 (TD-007: JSON数据外置未完成加载端迁移) | — |

---

## 第三部分：审计修复进度追踪

### 3.1 v5.0 审计 → v5.1 审计 → 当前状态

#### ✅ 已确认修复的问题 (9项)

| ID | 问题 | 修复确认 |
|----|------|---------|
| BUG-01 | `card_enhancement_manager.gd` 中 `base_damage` 不存在→强化消耗=0 | ✅ 已改为 `card.power` |
| BUG-02 | `attack_calculator.gd` 改造伤害倍率被注释 | ✅ 已实现 `get_mod_damage_multiplier()` |
| BUG-03 | 全局 autoload 不安全引用 | ✅ PhaseLawManager直接引用已清零 |
| BUG-1(v5.1) | `enhance_level >= 9` 在 `>= 10` 之前(死代码) | ✅ 已修正顺序 |
| BUG-2(v5.1) | 硬编码绝对路径 `F:/godot fair duel/...` | ✅ 已清零 |
| DIFF-01a | 缺失 `cold_rpg` 单位 | ✅ 已补充 |
| MISSING-02 | 情报100%检查被注释 | ✅ 已启用 |
| MISSING-01 | deploy_speed 未在战斗中生效 | ✅ construct_unit_deploy.gd 已完整实现 |
| A-01(v5.1) | bullet.gd 词缀伤害调用 | ✅ 已移除 AffixCombatHandler.calculate_damage() |

#### ✅ 已确认修复的设计差异 (4项)

| ID | 问题 | 修复确认 |
|----|------|---------|
| D-01 | 文档标题编号不一致(100→110) | ✅ 已修正 |
| D-02 | 空中线F-22 vs AH-64 | ✅ 文档已标注AH-64替代 |
| D-03 | 堡垒类无进化路线 | ✅ 已添加防御线5节点+防空线3节点 |
| D-04 | 纯辅助单位武器类型推断错误 | ✅ 已新增SUPPORT枚举+推断逻辑 |

#### ✅ 已完成的代码质量 (2项)

| ID | 问题 | 修复确认 |
|----|------|---------|
| P2-1 | `_agent_log` 清理 | ✅ 46处→0处 |
| P2-2 | `DEFAULT_MOD_OPTIONS` 清理 | ✅ 2处→0处 |

#### ⚠️ 已部分完成 (2项)

| ID | 问题 | 状态 |
|----|------|------|
| A-02 | star_level 写入清理 | ⚠️ 外部写入已全部切断(10处已注释)，但 affix_manager.gd 仍活跃调用 blueprint_stars |
| A-03 | blueprint_fragments 奖励 | ⚠️ quest/tutorial/achievement/UI中已注释，135处→23处(全部注释) |

#### ❌ 未完成 (4项)

| ID | 问题 | 状态 |
|----|------|------|
| P2-3 | print() 残留清理 | ❌ 反增至214处（修复中新增调试print） |
| P2-4 | BlueprintManager 拆分 | ❌ 未执行（875行，管理蓝图+星级+改造+进化+存档） |
| blueprint_stars/copies | 内部逻辑仍在运转 | ⚠️ 64+20处引用，存档仍序列化 |
| omega_platform | 遗留ID仍在活跃引用 | ⚠️ ~20处引用，作为存档兼容shim未隔离 |

---

## 第四部分：当前存在的关键问题

### 🔴 P0 — 高优先级（影响核心玩法）

#### 问题1：词缀系统(Affix)——552处引用仍在非伤害维度活跃

**严重度**：高
**现状**：
- 核心**伤害调用**已在bullet.gd中切断 ✅
- 但 AffixCombatHandler 仍在被引用于：击杀护盾(battle_damage_system)、平台变异(construct_unit)、HP回复(enemy_unit/AI)
- AffixManager(643行) 仍被 aura_manager、card_ability_manager 调用
- AffixResource(149行) 完整定义仍在
- CardResource 中 affix_slot_ids/affix_slot_count 仍作为 @export 字段
- 设计文档已将词缀重命名为"模块化词条"，但代码中两套术语混用

**影响**：词缀的暴击/吸血/溅射效果仍在战斗中生效（通过非bullet路径），与"模块化词条"设计不一致

**需决策**：
- 方案A：保留词缀为模块化词条底层实现，统一术语
- 方案B：彻底删除词缀系统（预估16h，需全面回归）
- 方案C(当前)：仅切断伤害调用，非伤害功能暂保留

#### 问题2：BlueprintManager 内部 blueprint_stars/copies 仍在运转

**严重度**：中
**现状**：
- 外部star_level写入已全部注释 ✅
- 但 BlueprintManager 内部 blueprint_stars 字典(64处引用)仍在管理
- blueprint_copies 字典(20处引用)仍在序列化/反序列化
- get_blueprint_star() 仍被 affix_manager.gd 调用
- 存档中仍包含stars+copies数据

**影响**：存档兼容性风险；BlueprintManager职责不清（875行管理5种功能）

#### 问题3：print() 调用泛滥

**严重度**：中
**现状**：365处 print() 调用分布在65个文件中（修复过程中新增了56处）

---

### 🟠 P1 — 中优先级（影响数据一致性/质量）

#### 问题4：omega_platform 遗留ID仍在活跃引用

**严重度**：中
**现状**：~20处引用分布在 blueprints、achievements、quests、drops、shops 等系统。与 fut_nexus 的迁移映射已定义但未全面执行。

#### 问题5：phase_instrument_manager.gd 1,097行

**严重度**：中
**现状**：唯一超过1000行阈值的活跃manager，需拆分。

#### 问题6：TD-007 JSON数据外置未完成

**严重度**：低
**现状**：JSON已创建(5018行)，GDScript加载端迁移未完成。

#### 问题7：文档与代码的术语不一致

**严重度**：低
**现状**：设计文档用"模块化词条"但代码用"affix"；关键设计决策汇总.md中仍有"已删除：词缀/附魔"的旧描述

---

### 🟡 P2 — 低优先级（技术债务/长期）

#### 问题8：0个 assert() 调用

**现状**：生产代码中完全没有防御性断言，关键路径缺少校验。

#### 问题9：21个 Autoload 可能影响启动时间

**现状**：虽有 ManagerLazyLoader 缓解，但21个单例仍有初始化开销。

#### 问题10：势力和势力分支进化内容

**现状**：faction_branches 数据结构已有（非空字典），势力系统声望+商店已实现，但分支进化目标可能与设计意图不完全一致。

---

## 第五部分：详细修复与优化计划

### Phase 1：P0 关键修复（预估3-4天）

#### 任务 1.1：词缀系统决策与清理 ⏱️ 0.5天

**目标**：统一"词缀"与"模块化词条"的设计定位

**步骤**：
1. **决策确认**：确认方案A(保留并重命名)或方案B(彻底删除)
2. 如选方案A：
   - 将 `affix_slot_ids` 重命名为 `module_slot_ids`（别名兼容）
   - 更新 AffixManager → ModuleSlotManager
   - 更新设计文档，说明"模块化词条"= 词缀系统v2
3. 如选方案B：
   - 移除 AffixCombatHandler 全部引用(7处非伤害)
   - 移除 aura_manager/card_ability_manager 中的词缀逻辑
   - 替换为新的模块化词条实现
4. 如选方案C(维持现状)：
   - 在代码中添加注释说明词缀非伤害功能待迁移
   - 更新设计文档标注

**涉及文件**：
- `managers/affix_manager.gd` (643行)
- `managers/affix_combat_handler.gd` (340行)
- `resources/affix_resource.gd` (149行)
- `resources/card_resource.gd` (affix字段)
- `managers/drop_manager.gd` (词缀掉落)
- `resources/unit_stats.gd` (词缀属性)

---

#### 任务 1.2：BlueprintManager 内部清理 ⏱️ 1天

**目标**：移除 BlueprintManager 内部废弃的 stars/copies 管理逻辑

**步骤**：
1. 注释 BlueprintManager 中的 blueprint_stars Dictionary 初始化和管理函数
2. 注释 blueprint_copies Dictionary 初始化和管理函数
3. 注释 get_blueprint_star() 函数体（保留空壳+push_warning）
4. 注释存档序列化中的 stars/copies 读取（保留字段但标记 DEPRECATED）
5. 修复 affix_manager.gd L479-480 的 blueprint_stars 调用
6. 冒烟测试：启动游戏 → 进入战斗 → 强化 → 进化 → 存档/读档

**涉及文件**：
- `managers/blueprint_manager.gd` (~64处 blueprint_stars + ~20处 blueprint_copies)
- `managers/affix_manager.gd` L479-480

---

#### 任务 1.3：print() 批量清理 ⏱️ 0.5天

**目标**：将365处 print() 调用缩减到合理范围

**步骤**：
1. 批量搜索所有 print() 调用
2. 分类处理：
   - 调试print（修复过程中新增）：直接删除
   - 有意义的print：替换为 DEBUG_XXX_LOG 模式
   - 关键路径print：保留（如初始化日志）
3. 目标：print() 总数 < 50处

**涉及文件**：65个文件中365处

---

### Phase 2：P1 质量提升（预估3-4天）

#### 任务 2.1：BlueprintManager 拆分 ⏱️ 2天

**目标**：将875行 BlueprintManager 拆分为4个独立 Manager

**拆分方案**：
| 新Manager | 职责 | 预估行数 |
|-----------|------|---------|
| CardDataManager | 蓝图解锁、卡片查询、存档 | ~200行 |
| CardEnhancementManager | 强化管理（已独立，需完全脱离） | ~150行 |
| CardEvolutionManager | 进化检查与执行 | ~200行 |
| ModManager | 改造槽位管理 | ~150行 |
| BlueprintManager | Facade门面（API兼容层） | ~100行 |

**步骤**：
1. 创建4个新 Manager 文件
2. 将 BlueprintManager 中对应代码迁移
3. BlueprintManager 保留为 facade，转发调用
4. 更新所有外部引用（逐步迁移到新 Manager API）
5. 冒烟测试：全流程

---

#### 任务 2.2：omega_platform 存档兼容隔离 ⏱️ 0.5天

**步骤**：
1. 在 enemy_unit_manifest.gd 中添加 omega_platform → fut_nexus 迁移逻辑
2. 在 blueprints_manager/drop_manager/shop 中添加兼容shim
3. 确保新流程不生成 omega_platform
4. 更新 achievement_definitions / quest_definitions 中的 omega_platform 引用

---

#### 任务 2.3：phase_instrument_manager.gd 拆分 ⏱️ 1天

**拆分方案**：
| 新文件 | 职责 |
|--------|------|
| phase_instrument_manager.gd | 主入口/facade (~200行) |
| phase_instrument_config.gd | 配置数据、常量 |
| phase_instrument_equipment.gd | 装备/卸载逻辑 |

---

#### 任务 2.4：文档术语统一 ⏱️ 0.5天

**步骤**：
1. 更新关键设计决策汇总.md
2. 统一"词缀"→"模块化词条"命名（如选方案A）
3. 更新 ARCH_DECISIONS.md
4. 更新设计文档 v5.0

---

### Phase 3：P2 技术债务清理（预估4-5天）

#### 任务 3.1：生产代码添加 assert ⏱️ 1天

**目标**：在关键路径添加防御性断言

**优先级**：
1. 存档加载后数据完整性（card_id存在、数值范围合法）
2. 战斗伤害计算（attack值非负、defense值非负）
3. 进化条件检查（目标card_id存在、不跨类型）
4. 资源消费（余额>=消耗）

#### 任务 3.2：TD-007 JSON数据外置完成 ⏱️ 1-2天

**步骤**：
1. 创建 GDScript JSON 加载器
2. 迁移 default_cards.gd 中110个单位数据到 data/json/units.json
3. 启动时从JSON加载，保留GDScript作为fallback
4. 回归测试

#### 任务 3.3：势力分支进化内容审查 ⏱️ 1天

**步骤**：
1. 审查7个 faction_branches 数据
2. 确认每个分支目标单位与设计意图一致
3. 如有偏差，修正或记录设计决策

#### 任务 3.4：视觉资源审计 ⏱️ 1天

**步骤**：
1. 检查 assets/unit_sprites/ 是否117个单位都有精灵图
2. 检查 assets/card_icons/ 是否117个单位都有卡面图标
3. 列出缺失资源清单
4. 为缺失资源创建 AI 生成提示词

---

### Phase 4：长期提升（预估1-2月）

#### 任务 4.1：堡垒单位特殊行为实现
- 雷达站：光环提升周围友军精度+15%
- 护盾发生器：为周围友军提供HP护盾
- 要塞核心：光环增加周围防御
- 通过 aura_manager.gd 实现

#### 任务 4.2：战斗回放与日志系统
- 简易战斗日志（每次攻击/击杀记录）
- 可选慢速回放模式

#### 任务 4.3：平衡性测试框架
- GdUnit测试套件：每时代DPS范围、克制关系、进化链战力递增

#### 任务 4.4：性能基准测试自动化
- CI集成 headless 性能测试
- 60fps 稳定性阈值

#### 任务 4.5：数据驱动设计迁移
- 110个单位迁移到 JSON
- 支持 Google Sheets → Python → JSON → 游戏 工作流

---

## 第六部分：优先级总结

```
紧急程度:  ████████████████████░░░░░░  Phase 1（3项：词缀决策+BM清理+print清理）
重要性:    ████████████████████░░░░░░  Phase 2（4项：BM拆分+omega隔离+PIM拆分+文档）
代码质量:  ████████████████░░░░░░░░░░  Phase 3（4项：assert+JSON外置+势力审查+资源审计）
战略价值:  ████████████░░░░░░░░░░░░░░  Phase 4（5项：堡垒行为+回放+平衡+性能+数据驱动）
```

### 如果只能做3件事：
1. **任务1.1** 词缀系统决策（统一代码与设计的一致性）
2. **任务1.2** BlueprintManager 内部清理（移除废弃的stars/copies逻辑）
3. **任务2.1** BlueprintManager 拆分（架构清洁度，解决875行大文件）

### 总工作量估算

| Phase | 工作量 | 前置条件 |
|-------|--------|---------|
| Phase 1 | ~2天 | 无 |
| Phase 2 | ~4天 | Phase 1 完成 |
| Phase 3 | ~4-5天 | Phase 2 完成 |
| Phase 4 | ~80h | Phase 3 完成 |
| **合计** | **~15天(Phase 1-3) + 80h(Phase 4)** | |

---

## 第七部分：附录

### A. 各遗留系统引用统计

| 系统 | 引用数 | 活跃影响 | 风险 |
|------|--------|---------|------|
| affix/词缀(非伤害) | 552处 | 🟡 影响护盾/回复/平台变异 | 中 |
| blueprint_stars | 64处 | 🟡 BM内部逻辑仍在运转 | 低 |
| blueprint_copies | 20处 | 🟡 存档数据残留 | 低 |
| omega_platform | ~20处 | 🟡 存档兼容+多系统引用 | 低 |
| print() | 365处 | 🟢 调试残留，65个文件 | 低 |
| star_level字段 | 3处 | 🟢 良性残留(无写入) | 极低 |
| _agent_log | 0处 | ✅ 已清理 | 无 |
| DEFAULT_MOD_OPTIONS | 0处 | ✅ 已清理 | 无 |

### B. 已正确实现的核心系统清单

| 系统 | 验证点 | 状态 |
|------|--------|------|
| WeaponType 枚举 | DIRECT=0, INDIRECT=1, AERIAL=2, SUPPORT=3 | ✅ |
| CombatKind 枚举 | 含 FORT=4 | ✅ |
| 三维攻击/防御 | 9字段完整 | ✅ |
| 伤害公式 | 击穿检查 + 100/(100+def) | ✅ |
| 射程衰减 | 仅DIRECT武器，6种系数 | ✅ |
| 三种选敌逻辑 | 完整实现 | ✅ |
| 110个战斗单位 | default_cards.gd 数据完整 | ✅ |
| 7张能量卡 | default_cards.gd 数据完整 | ✅ |
| 强化100%成功 | 无随机判定 | ✅ |
| 强化倍率 | Lv1-10 线性+跳变 | ✅ |
| 强化消耗 | base_power × 等级系数 | ✅ |
| 20种改造效果 | MOD_01-MOD_20 含 attack_multiplier | ✅ |
| 改造伤害接入 | get_mod_damage_multiplier() 第6步 | ✅ |
| 情报门控 | unit_lineage_config 已启用 | ✅ |
| 部署速度 | construct_unit_deploy.gd 完整实现 | ✅ |
| 情报手册 | IntelManual 49处引用 | ✅ |
| 情报道具 | IntelItemBag + IntelManualItems | ✅ |
| 改造进化继承 | mods复制到目标 | ✅ |
| 堡垒进化路线 | 防御线5节点+防空线3节点 | ✅ |
| RPG组单位 | cold_rpg + 反坦克链 | ✅ |
| 势力分支 | 7个势力分支数据 | ✅ |
| 对象池 | ObjectPool | ✅ |
| 空间网格 | BattleManager | ✅ |
| 攻击3阶段状态机 | WINDUP→ACTIVE→COOLDOWN | ✅ |
| 军衔13级 | RankRules | ✅ |

### C. 关键文件索引

| 文件 | 行数 | 职责 |
|------|------|------|
| docs/《相位战争》完整设计文档 v5.0 - 最终版20260529.md | 939行 | 设计主文档 |
| docs/相位战争_完整设定与数据平衡总览.md | 1073行 | AI逆向工程设定 |
| docs/相位战争 - 关键设计决策汇总.md | 1472行 | 对话决策记录 |
| docs/相位战争_重设计参考资料汇编.md | 925行 | 重设计参考资料 |
| docs/ARCH_DECISIONS.md | 12个ADR | 架构决策 |
| docs/tech-debt-register.md | 8项 | 技术债务登记 |
| docs/AUDIT_REPORT_v5.0_20260530.md | 审计报告v5.0 | |
| docs/FULL_SYSTEM_AUDIT_FIX_PLAN_v5.1_20260531.md | 修复计划v5.1 | |
| docs/FIX_VERIFICATION_REPORT_v5.1_20260531.md | 验证报告v5.1 | |

---

> **报告生成时间**：2026-05-31 22:17 (UTC+8)
> **下次全面检查建议**：Phase 1 修复完成后（预计 2026-06-07）
> **检查覆盖率**：全量扫描 scripts/, managers/, data/, resources/, scenes/ 共 ~331 个 .gd 文件
