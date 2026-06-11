---
name: balance-check
description: 审查单位/MOD 平衡性数据，检查倍率和数值一致性
---

# 平衡性审查技能

## 功能

系统化审查 Phase War 的单位数据、MOD 效果和伤害倍率，检测数值不一致和平衡性问题。

## 审查维度

### 1. 时代倍率一致性
检查 `data/battle_card_v3.gd` 中的 HP/伤害倍率：
- WWI → WWII → Cold War → Modern → Near Future
- 倍率应单调递增
- 当前值：1.00 / 1.20 / 1.45 / 1.70 / 1.80

### 2. 同级别单位 HP 关系
检查 `data/default_cards.gd` 中同级别单位：
- 同级别不同类型（infantry/armor/artillery/air）HP 应符合设计定位
- 装甲单位 HP > 步兵 HP > 其他
- 关注 v6.1 T-72(800) vs M1(850) 调整

### 3. MOD 效果合理性
检查 `data/modification_modules/*.gd`：
- 同类型 MOD 效果不应叠加超过合理范围
- 攻击间隔减少上限检查（v6.1 多项调整为 -30%/-40%）
- 攻击力加成上限检查

### 4. 进化路径数值增长
检查 `data/evolution_paths/*.gd`：
- 进化后属性增长应合理（不低于基础值）
- 隐藏分支应有代价补偿

## 输出格式

```
[CHECK] 检查项名称
  PASS: 通过原因
  WARN: 警告信息（数值接近阈值）
  FAIL: 失败原因（数值明显异常）
  DATA: 当前值 → 预期范围
```

## 关键数据文件

| 文件 | 用途 |
|------|------|
| `data/battle_card_v3.gd` | 时代倍率 |
| `data/default_cards.gd` | 单位基础数据 |
| `data/modification_modules/*.gd` | MOD 效果 |
| `data/evolution_paths/*.gd` | 进化路径 |
| `data/mod_effects.gd` | MOD 效果公式 |
| `resources/game_constants.gd` | 枚举和常量 |

## 相关 Agent

- `combat-analyst` — 战斗系统深度分析
- `mod-reviewer` — MOD 模块审查
