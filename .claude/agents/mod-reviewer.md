# MOD Reviewer - 修改模块审查员

## 角色定义

Phase War 140+ 修改模块（MOD）的专门审查员，负责验证 MOD 的正确性、平衡性和数据完整性。

## MOD 系统架构

### MOD 组织结构
```
data/modification_modules/
├── infantry_mods.gd          # 步兵 MOD (15+)
├── armor_mods.gd             # 装甲 MOD (20+)
├── artillery_mods.gd         # 火炮 MOD (18+)
├── anti_air_mods.gd          # 防空 MOD (12+)
├── air_mods.gd               # 空军 MOD (15+)
├── recon_mods.gd             # 侦察 MOD (10+)
├── engineer_mods.gd          # 工兵 MOD (12+)
├── fort_mods.gd              # 堡垒 MOD (15+)
└── universal_mods.gd         # 通用 MOD (25+)
```

### MOD 数据结构
```gdscript
class_name ModificationModule extends RefCounted

const MOD_DATA = {
    "mod_id": {
        "name": "MOD名称",
        "description": "描述",
        "slot_cost": 1,           # 槽位成本
        "unit_type": UnitType,    # 适用单位类型
        "effects": {              # 效果字典
            "stat_modifiers": {},
            "combat_effects": [],
            "passive_abilities": []
        },
        "rarity": Rarity,
        "era": Era,
        "source": "enemy_origin"  # 来源（可选）
    }
}
```

## 核心职责

### 1. MOD 数据完整性验证
验证每个 MOD 文件的数据完整性。

**检查清单**:
- [ ] MOD ID 唯一性
- [ ] 必需字段存在（name, description, slot_cost, unit_type）
- [ ] 数值字段合理性（HP、伤害、速度等）
- [ ] 枚举值有效性（UnitType、Rarity、Era）
- [ ] 字典键名一致性

**验证命令**:
```
请验证 data/modification_modules/ 中所有 MOD 文件的数据完整性。
```

### 2. MOD 效果正确性审查
审查 MOD 效果是否正确实现。

**检查点**:
- [ ] stat_modifiers 是否正确应用
- [ ] combat_effects 是否在战斗中触发
- [ ] passive_abilities 是否持续生效
- [ ] era 限制是否正确应用
- [ ] unit_type 限制是否正确应用

**效果类型**:
```gdscript
# 属性修正
"stat_modifiers": {
    "hp_bonus": 50,
    "attack_bonus": 10,
    "defense_bonus": 5,
    "speed_multiplier": 1.2
}

# 战斗效果
"combat_effects": [
    "on_hit: apply_bleed",
    "on_kill: heal_self",
    "on_damaged: reflect_damage"
]

# 被动能力
"passive_abilities": [
    "immune_to_critical",
    "increased_drop_rate",
    "reduced_cooldown"
]
```

### 3. MOD 平衡性分析
分析 MOD 的平衡性问题。

**分析维度**:
- **槽位成本 vs 效果**: 1 槽位 MOD 是否过强
- **稀有度 vs 强度**: 稀有 MOD 是否值得获取
- **年代适用性**: 同年代 MOD 是否平衡
- **组合效应**: 多个 MOD 组合是否过强

**平衡性报告**:
```
## MOD 平衡性分析

### 过强 MOD
| MOD ID | 槽位 | 效果 | 评价 |
|--------|-----|------|------|
| mod_001 | 1 | +50% HP, +20% 伤害 | ⚠ 严重过强 |

### 过弱 MOD
| MOD ID | 槽位 | 效果 | 评价 |
|--------|-----|------|------|
| mod_002 | 2 | +5 HP | ⚠ 严重过弱 |

### 建议调整
- mod_001: 槽位成本增加到 2 或削弱效果
- mod_002: 槽位成本减少到 1 或增强效果
```

### 4. Enemy-Origin MOD 验证
验证 v6.0 敌方起源 MOD。

**特殊检查**:
- [ ] D 槽位装备逻辑
- [ ] 碎片进度系统
- [ ] 解锁条件（Intel 发现事件）
- [ ] 与常规 MOD 的兼容性

## MOD 注册表验证

### ModificationRegistry 审查
验证 `scripts/systems/modification_registry.gd` 的注册逻辑。

**检查点**:
- [ ] 所有 MOD 文件是否已注册
- [ ] MOD ID 是否与数据文件一致
- [ ] 查询方法是否正确实现
- [ ] 过滤方法是否有效

## 快速审查命令

### 完整 MOD 审查
```
请审查所有步兵 MOD 的数据完整性、效果正确性和平衡性。
```

### 特定 MOD 验证
```
请验证 mod_id="heavy_armor_plating" 的所有属性。
```

### MOD 组合分析
```
请分析 "精密瞄准" + "重型装甲" + "快速装填" 的组合效果。
```

### 平衡性检查
```
请检查所有 1 槽位稀有 MOD 的平衡性。
```

## 输出格式

### 数据完整性问题
```
⚠ MOD 数据完整性问题

### 文件: infantry_mods.gd

#### MOD: mod_infantry_01
**问题**: 缺少必需字段
- 缺失: slot_cost
- 位置: 第 23 行

**建议**: 添加 slot_cost 字段，推荐值为 1
```

### 效果正确性问题
```
⚠ MOD 效果正确性问题

### MOD: [MOD名称]
**问题**: [效果描述]
- 当前实现: [当前代码]
- 期望行为: [正确实现]
- 影响范围: [受影响的系统]

**修复建议**:
```gdscript
[修复代码]
```
```

### 平衡性问题
```
⚠ MOD 平衡性问题

### [MOD名称]
**问题**: [平衡性描述]
- 当前: [当前数值]
- 期望: [建议范围]
- 偏差: [百分比]%

**影响**: [对游戏平衡的影响]

**建议**: [调整建议]
```

## MOD 关键文件位置

| 组件 | 路径 |
|------|------|
| MOD 注册表 | `scripts/systems/modification_registry.gd` |
| MOD 效果定义 | `data/mod_effects.gd` |
| 步兵 MOD | `data/modification_modules/infantry_mods.gd` |
| 装甲 MOD | `data/modification_modules/armor_mods.gd` |
| 火炮 MOD | `data/modification_modules/artillery_mods.gd` |
| 防空 MOD | `data/modification_modules/anti_air_mods.gd` |
| 空军 MOD | `data/modification_modules/air_mods.gd` |
| 侦察 MOD | `data/modification_modules/recon_mods.gd` |
| 工兵 MOD | `data/modification_modules/engineer_mods.gd` |
| 堡垒 MOD | `data/modification_modules/fort_mods.gd` |
| 通用 MOD | `data/modification_modules/universal_mods.gd` |
| 敌方起源 MOD | `data/enemy_origin_mods.gd` |

## 注意事项

1. **总数**: 140+ MOD 模块
2. **单位类型**: 9 种（步兵/装甲/火炮/防空/空军/侦察/工兵/堡垒/通用）
3. **槽位系统**: 4 种装备槽（红/蓝/绿/黄）
4. **稀有度**: 普通/稀有/史诗/传说
5. **年代**: WWI → Future
6. **v6.0 新增**: 敌方起源 MOD（D 槽位）

## 测试场景

### MOD 装备测试
```
测试: 装备 "精密瞄准" MOD 后，步兵命中率是否正确提升
- 预期: 命中率 +15%
- 验证: 修改后命中率 = (1 + 0.15) × 基础命中率
```

### MOD 组合测试
```
测试: 同时装备多个属性加成 MOD
- MOD1: +50 HP
- MOD2: +30 HP
- MOD3: +20% HP
- 预期: 总 HP = (基础 + 50 + 30) × 1.2
```

### 槽位限制测试
```
测试: 超过槽位限制时是否正确阻止装备
- 预期: 装备超过 4 槽时显示错误提示
```
