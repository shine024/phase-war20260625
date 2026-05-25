# Phase War: 构装纪元 - 游戏概念

> **Status**: Designed
> **Source**: Implementation + system GDDs
> **Last Updated**: 2026-04-24

## Overview

Phase War（构装纪元）是一款 Godot 4.5 / GDScript 开发的自动战斗卡牌构筑游戏。玩家扮演相位指挥官，通过装配平台卡和武器卡构建作战单位，搭配相位法则和环境策略，在 100 个关卡中击败敌人。核心循环围绕"战前装配构筑，战中部署操作"展开，蓝图数据（研究点）永久积累驱动长期成长。游戏覆盖 5 个时代（一战→近未来），7 个势力，300+ 卡牌组合，12 种相位法则。

## Player Fantasy

**The Phase Commander**: 你是掌控相位技术的指挥官，通过装配构装单位、选择相位法则来指挥战斗。你的每一个选择——平台、武器、法则、能量——都会影响战场。

**核心体验**：
- **构筑深度**：战前装配决定可用兵种 — 搭配平台与武器，选择法则与能量配置
- **战术操作**：战中部署时机和法则施放 — 观察战场，在正确时机投入正确单位
- **环境策略**：根据战场环境选择法则 — 法则与环境的匹配影响威力（50%~100%）
- **收集成长**：蓝图数据（研究点）永久积累，持续变强 — 蓝图 1-9 星渐进，知识值解锁新能力

## Detailed Rules

### 三层循环

#### 30 秒循环（战斗中）
- **部署**: 点击战场位置，消耗能量，生成单位（部署时间 = 能量消耗 / 能量输出速率）
- **战斗**: 单位自动移动、攻击、死亡
- **施法**: 消耗能量 + 纳米材料，施放主动法则（受 max_cast_per_battle 限制）
- **观察**: 观察战场形势，调整部署时机

#### 5 分钟循环（单场战斗）
- **准备**: 装配相位仪（绿色槽=平台+武器，黄色槽=能量，红色槽=主动法则，蓝色槽=被动法则）
- **战斗**: 完成敌人波次，保护相位场驱动器
- **结算**: 获得蓝图数据（研究点）、纳米材料、星级评价（1-3 星）

#### 会话循环（长期进程）
- **收集**: 战斗获得蓝图数据（研究点）、知识值（永久不消耗）
- **成长**: 蓝图星级提升（1-9★），解锁新法则
- **推进**: 解锁 100 关，5 个时代（一战→近未来）
- **优化**: 强化卡牌，消耗纳米材料提升等级，调整构筑

### 核心系统概览

| 系统 | 职责 | 关键约束 |
|------|------|---------|
| 战斗系统 | 部署、自动战斗、波次、胜负 | 单位上限 5，无重复平台 |
| 蓝图系统 | 蓝图数据（研究点）收集、星级、制造 | 研究点不消耗，9 星上限 |
| 强化系统 | 卡牌升级等级、消耗纳米材料 | 消耗纳米材料提升等级 |
| 法则系统 | 主动/被动法则、环境匹配 | 4 家族：STEEL/FLAME/THUNDER/VOID |
| 能量系统 | 战前配置、战斗回复 | 净回复 = 基础 + 卡牌 - 消耗 |
| 单位属性系统 | 平台+武器+词缀组合 | 8 词缀修饰，6 突变标记 |
| 掉落系统 | 战后掉落、待领取队列 | 10 种掉落类型，权重随机 |

## Formulas

### 部署能量消耗

```
deploy_energy_cost = max(1, platform_energy_cost + sum(weapon_energy_costs))
deploy_time = deploy_energy_cost / energy_output_rate
```

### 法则环境匹配

```
power_multiplier = 0.5 + (match_count / total_dims) * 0.5
范围: 50% (无匹配) → 100% (完全匹配)
```

### 蓝图星级属性加成

```
stat_multiplier = rarity_multiplier * (1.0 + (star - 1) * 0.06)  // 卡牌
stat_multiplier = rarity_multiplier * (1.0 + (star - 1) * 0.08)  // 法则
```

### 伤害计算

```
final_damage = base_damage * crit_multiplier(2x if crit)
reduced_damage = final_damage * (1 - armor * (1 - penetration))
splash_damage = reduced_damage * splash_percentage
```





## Edge Cases

- **能量不足部署**: 部署失败，发出 `energy_insufficient` 信号，不扣除能量
- **单位上限 5**: 达到上限后无法继续部署，必须等待单位被摧毁
- **重复平台**: 同一平台类型只能部署一次（例如不能有两个相同的坦克平台）
- **强化失败**: 不存在失败，消耗纳米材料必定成功
- **知识值类型**: 知识值使用 `law:` 前缀区分于普通蓝图数据（研究点）
- **9 星溢出转换**: 蓝图 9 星后多余研究点转换为纳米材料（50 纳米/研究点，每日上限 1000）
- **存档版本不匹配**: SaveManager 检测 schema 版本，不兼容的存档提示无法加载
- **延迟初始化失败**: ManagerLazyLoader 帧分散加载，任何单帧不超过 16.6ms

## Dependencies

### 核心系统依赖链

```
Foundation (no dependencies):
  Signal Bus System → Configuration System → Energy System
  Nano Material System → Data Persistence → Resource Loading

Core (depends on foundation):
  Unit Stats → Damage Calculation → Deployment → Wave System
  Environment → Fragment Drop → Backpack → Affix → Success Rate

Feature (depends on core):
  Battle → Blueprint → Energy Regen/Consumption → Phase Law
  Enhancement → Star Rating → Card Manufacturing

Presentation (depends on features):
  Combat UI → Blueprint Library UI → Law Library UI → Enhancement UI

Polish (depends on everything):
  Era System → Level Unlock → Quest/Achievement
```

### 外部依赖

- **Godot 4.5 Engine** — 渲染、物理、输入、场景管理
- **GdUnit4** — 单元/集成测试框架
- **Steam/Epic** — 目标发行平台（PC）

## Tuning Knobs

| 参数 | 当前值 | 位置 | 影响 |
|------|-------|------|------|
| 单位上限 | 5 | battle-system | 同时在场最大单位数 |
| 蓝图星级上限 | 9 | blueprint-system | 每张蓝图的最高星级 |
| 蓝图溢出转换率 | 50 纳米/研究点 | blueprint-system | 9 星后研究点转化价值 |
| 蓝图溢出每日上限 | 1000 纳米 | blueprint-system | 每日研究点转化纳米上限 |
| 强化纳米消耗 | 50/150/500 | enhancement-system | 各稀有度升级费用 |
| 法则环境匹配范围 | 50%-100% | phase-law-system | 匹配维度对威力的影响 |
| 被动法则缩放 | 1.0x-1.18x | phase-law-system | 法则等级对被动效果的影响 |
| 帧预算 | 16.6ms | 技术规范 | 每帧最大计算时间 |
| 内存上限 | 512MB | 技术规范 | 游戏最大内存占用 |
| 目标帧率 | 60 FPS | 技术规范 | 渲染帧率目标 |
| 最大绘制调用 | 200/帧 | 技术规范 | 每帧最大 draw call 数量 |

## Acceptance Criteria

- [ ] 玩家能完成首次战斗（教程引导）
- [ ] 蓝图数据（研究点）在战斗后正确获得，累计不消耗
- [ ] 蓝图达到研究点阈值时自动解锁新卡牌
- [ ] 蓝图星级 1-9 正确计算属性加成
- [ ] 相位仪 4 色槽位正确接受对应卡牌类型
- [ ] 法则卡自动路由到正确颜色（红/蓝交换，深度≤2）
- [ ] 战斗中部署单位消耗正确能量，时间 = 消耗/输出
- [ ] 3 星评价：1 星胜利，2 星生存 ≥50%，3 星生存 ≥80% + 时间效率
- [ ] 强化卡牌消耗纳米材料后等级正确提升
- [ ] 法则环境匹配正确计算威力倍率（50%-100%）
- [ ] 存档在 schema v3 下正确保存和加载
- [ ] 游戏在 60 FPS 下稳定运行，内存 < 512MB
- [ ] 全部 13 个系统 GDD 完成且符合 8 节格式
