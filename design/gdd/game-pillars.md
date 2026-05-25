# Game Pillars — 构装纪元 (Phase War)

> **Status**: Designed
> **Created**: 2026-04-24
> **Source**: Derived from game-concept.md and 7 core GDD implicit pillar references

---

## Pillar 1: Tactical Build & Deploy

**One-line**: 战前装配决定可用兵种，战中部署时机决定胜负。

**Design Test**: 当在特性 X（更多兵种选择）和特性 Y（自动优化部署）之间争论时，此 Pillar 说选择 **X** — 玩家的构筑和部署决策必须有意义。

**System Ownership**: battle-system, unit-stats-system, energy-system

**What this means**:
- 每张卡牌的选择都应改变战斗体验
- 部署时机（何时、何地投入单位）是核心技能
- 相同单位在不同时机部署应有不同结果
- 能量限制让每次部署都有代价

**GDD References**:
- "Tactical Combat & Strategic Planning" (battle-system.md)
- "Combat Mechanics & Unit Customization" (unit-stats-system.md)
- "Core Constraints & Rhythm Control" (energy-system.md)

---

## Pillar 2: Environmental Adaptation

**One-line**: 法则与战场环境的匹配度直接影响战斗力（50%~100%威力）。

**Design Test**: 当在特性 X（通用强力法则）和特性 Y（环境特定法则）之间争论时，此 Pillar 说选择 **Y** — 玩家应因环境不同而改变策略。

**System Ownership**: phase-law-system

**What this means**:
- 不同关卡/环境需要不同的法则搭配
- "正确"的法则搭配应比"错误"的搭配效果显著更好
- 环境信息应清晰可见，让玩家能做出明智选择
- 法则收集创造"工具箱扩展"的成长感

**GDD References**:
- "Active Skills & Environmental Strategy" (phase-law-system.md)

---

## Pillar 3: Permanent Growth

**One-line**: 碎片永久积累，每次战斗都让下一次更强。

**Design Test**: 当在特性 X（每关重置进度）和特性 Y（碎片永久保留）之间争论时，此 Pillar 说选择 **Y** — 长期积累是核心驱动力。

**System Ownership**: blueprint-system, drop-system

**What this means**:
- 每场战斗产出的资源都有长期价值
- 蓝图 1→9 星升级提供清晰的进度感知
- 新玩家和老玩家应在能力上有可感知的差距
- "再打一把"的驱动力来自"离下一星/下一解锁更近了"

**GDD References**:
- "Growth & Collection" (blueprint-system.md)
- "Resource Economy & Progression" (drop-system.md)

---

## Pillar 4: 组合与词缀多样性

**One-line**: 13 种平台 × 10+ 种武器的组合 + 词缀系统创造丰富的构筑多样性。

**Design Test**: 当在特性 X（减少组合种类提高平衡性）和特性 Y（更多组合创造意外发现）之间争论时，此 Pillar 说选择 **Y** — 多样性和意外发现比完美平衡更有趣。

**System Ownership**: blueprint-system, unit-stats-system, affix-system

**What this means**:
- 平台 × 武器的自由组合应鼓励玩家尝试不寻常的搭配
- 词缀随机性创造意外发现，每次掉落都可能带来惊喜
- 发现强力组合应创造 "aha moment"
- 不同玩家应有截然不同的最优构筑

**GDD References**:
- "Growth & Collection" (blueprint-system.md)
- "Combat Mechanics & Unit Customization" (unit-stats-system.md)
- "Affix & Modifier System" (affix-system.md)

---

## Anti-Pillars (What This Game Is NOT)

| Anti-Pillar | Description |
|-------------|-------------|
| **NOT Action-Reflex** | 战斗是自动的，玩家不操控单位移动或攻击。操作速度不是技能。 |
| **NOT Pay-to-Win** | 所有内容通过游戏内获取，无内购影响战斗平衡。 |
| **NOT Infinite Grind** | 蓝图有上限（9星），收集有完成感，不是无尽刷。 |
| **NOT PvP Competitive** | 当前为单人体验，排行榜是自我比较工具。 |
| **NOT Story-Driven** | 叙事提供背景（5 个时代），但不是核心驱动力。 |

---

## Pillar Tension Map

| Tension | Pillars | Resolution |
|---------|---------|------------|
| Build depth vs. Accessibility | #1 vs. #3 | 新手用简单构筑即可通关，高手用复杂构筑追求优化 |
| Environmental adaptation vs. Build consistency | #2 vs. #1 | 通用构筑可行但非最优，环境特定构筑有显著奖励 |
| Permanent growth vs. Affix randomness | #3 vs. #4 | 蓝图升级提供稳定成长，词缀随机性带来意外惊喜与构筑变化 |
| Collection completion vs. Build variety | #3 vs. #4 | 9星上限提供目标，平台×武器组合+词缀提供持续新鲜感 |

---

## Priority Ranking

当资源有限必须裁剪时，按此优先级保护 Pillar：

1. **Tactical Build & Deploy** — 核心，没有它就没有游戏
2. **Permanent Growth** — 留存驱动力，没有它就没有长期目标
3. **Environmental Adaptation** — 差异化特色，没有它法则系统变得平庸
4. **组合与词缀多样性** — 深度，没有它游戏变浅但仍然可玩
