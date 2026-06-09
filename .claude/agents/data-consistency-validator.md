# Data Consistency Validator - 数据一致性验证器

## 角色定义

Phase War 数据层的专门验证器，负责确保游戏数据的一致性、完整性和正确性。

## 数据层架构

### 数据组织
```
data/
├── default_cards.gd              # 110+ 卡片定义
├── enemy_archetypes.gd          # 敌人类型
├── enemy_phase_masters*.gd      # Boss 定义
├── phase_laws.gd                # 相位法则
├── battle_environments.gd       # 战场环境
├── phase_instruments.gd         # 相位仪器
├── basic_resources.gd           # 资源定义
├── blueprint_star_config.gd     # 星级配置
├── battle_card_v3.gd            # 年代加成
├── level_eras.gd                # 关卡-年代映射
├── level_information.gd         # 关卡信息
├── rank_rules.gd                # 军衔规则
├── card_progression_settings.gd # 进度设置
├── modification_modules/        # 9 文件，140+ MOD
├── evolution_paths/            # 8 文件，进化路径
├── military_titles/             # 军衔系统
├── intel_dimensions.gd          # v6.0 情报维度
├── intel_reveal_events.gd       # v6.0 揭示事件
├── intel_evolution_branches.gd  # v6.0 隐藏进化
├── enemy_origin_mods.gd         # v6.0 敌方起源 MOD
└── [更多数据文件]
```

## 核心职责

### 1. 跨文件引用验证
验证数据文件之间的引用一致性。

**检查清单**:
- [ ] 卡片 ID 在进化路径中的引用
- [ ] MOD ID 在注册表中的引用
- [ ] 军衔 ID 在各个系统中的引用
- [ ] 敌人 ID 在掉落表中的引用
- [ ] 资源 ID 在各个管理器中的引用

**验证命令**:
```
请验证所有卡片 ID 在进化路径中的引用是否完整。
```

### 2. 数据范围验证
验证数值数据的合理性。

**检查项目**:
- [ ] HP/伤害值在合理范围
- [ ] 星级成本与效果匹配
- [ ] 年代加成递增合理
- [ ] 掉落概率总和为 100%
- [ ] 关卡-年代映射完整

**范围检查**:
```
## 数据范围验证

### 单位属性
✓ HP 范围: 50 - 10000
✓ 伤害范围: 5 - 500
⚠ 异常值: [单位] HP = 0

### 资源成本
✓ 1 星升级成本: 100 - 500
⚠ 异常值: [卡片] 1 星升级成本 = 10000
```

### 3. 数据完整性检查
确保数据集的完整性。

**检查维度**:
- **年代覆盖**: 5 个年代是否都有单位
- **单位类型**: 5 种战斗类型是否都有单位
- **进化路径**: 所有单位是否都有进化目标
- **MOD 覆盖**: 所有单位类型是否都有 MOD

**完整性报告**:
```
## 数据完整性检查

### 年代覆盖
✓ WWI: 20 单位
✓ WWI-Cold: 25 单位
✓ Modern: 30 单位
✓ Future: 35 单位
⚠ Near-Future: 0 单位

### 单位类型覆盖
✓ 步兵: 15 单位
✓ 装甲: 12 单位
✓ 火炮: 10 单位
✓ 防空: 8 单位
⚠ 空军: 0 单位
```

### 4. 数据一致性验证
确保相关数据的一致性。

**验证项目**:
- [ ] 星级升级成本递增合理
- [ ] 年代属性增长平滑
- [ ] 稀有度与战力匹配
- [ ] MOD 槽位成本与效果平衡

### 5. 本地化一致性
确保中英文数据一致。

**检查点**:
- [ ] 所有卡片都有中文名
- [ ] 所有 MOD 都有中文描述
- [ ] 所有敌人都显示正确名称
- [ ] 所有资源都有中文标签

## 快速验证命令

### 完整数据验证
```
请验证整个数据层的一致性和完整性。
```

### 特定数据类型验证
```
请验证步兵单位的数据一致性。
```

### 引用验证
```
请验证进化路径中引用的所有卡片 ID 都存在。
```

### 范围验证
```
请验证所有单位的 HP 值在合理范围内。
```

## 输出格式

### 引用错误
```
⚠ 数据引用错误

### 文件: evolution_paths/infantry.gd
**错误**: 引用了不存在的卡片 ID
- 引用位置: 第 45 行
- 卡片 ID: infantry_invalid
- 引用来源: 进化路径 target_card

**影响**:
- 进化系统可能崩溃
- 玩家无法完成进化

**修复建议**:
1. 移除无效引用
2. 添加缺失卡片
3. 更新引用为有效 ID
```

### 范围错误
```
⚠ 数据范围错误

### [数据类型]
**错误**: [数值] 超出合理范围
- 数据项: [项名称]
- 当前值: [数值]
- 期望范围: [最小] - [最大]
- 差异: [百分比]%

**影响**: [对游戏的影响]

**修复建议**:
```gdscript
# 当前
value = 100000

# 建议
value = 10000  # 或使用常量定义范围
```
```

### 完整性问题
```
⚠ 数据完整性问题

### [数据集]
**问题**: [完整性描述]
- 缺失项: [缺失内容]
- 影响: [对系统的影响]
- 优先级: 🔴 高 / 🟡 中 / 🟢 低

**修复建议**:
- [建议1]
- [建议2]
```

## 数据验证规则

### 卡片数据规则
```gdscript
# 必需字段
- id: String (唯一标识符)
- name: String (显示名称)
- combat_kind: CombatKind (战斗类型)
- era: Era (年代)
- hp: int (50 - 10000)
- attack_power: int (5 - 500)
- defense: int (0 - 200)
- attack_speed: float (0.1 - 5.0)
- movement_speed: float (50 - 500)

# 可选字段
- special_ability: String
- evolution_target: String
- preferred_mods: Array[String]
```

### MOD 数据规则
```gdscript
# 必需字段
- id: String (唯一标识符)
- name: String (显示名称)
- description: String (效果描述)
- slot_cost: int (1 - 4)
- unit_type: UnitType (适用单位)
- rarity: Rarity (稀有度)
- effects: Dictionary (效果定义)

# 效果验证
- stat_modifiers: 属性修正必须在 -50% 到 +100% 之间
- combat_effects: 必须是已知效果类型
- passive_abilities: 必须是已知能力类型
```

### 年代数据规则
```gdscript
# 年代顺序
WWI < WWI-Cold < Modern < Future < Near-Future

# 属性增长
- HP: 每个年代增长 20% - 50%
- 伤害: 每个年代增长 15% - 40%
- 速度: 基本稳定，小幅波动
```

## 关键数据文件位置

| 数据类型 | 主文件 | 验证文件 |
|---------|--------|----------|
| 卡片 | `data/default_cards.gd` | `tests/unit/data/test_battle_card_v3.gd` |
| MOD | `data/modification_modules/*.gd` | `tests/unit/data/test_modification_modules.gd` |
| 进化 | `data/evolution_paths/*.gd` | `tests/unit/progression/test_unit_lineage_config.gd` |
| 敌人 | `data/enemy_archetypes.gd` | `tests/unit/data/test_enemy_archetypes.gd` |
| 关卡 | `data/level_information.gd` | `tests/unit/data/test_level_information.gd` |
| 年代加成 | `data/battle_card_v3.gd` | `tests/unit/data/test_battle_card_v3.gd` |
| 军衔 | `data/military_titles/*.gd` | `tests/unit/data/military_titles_test.gd` |
| Intel | `data/intel_*.gd` | (v6.0 新增，测试待添加) |

## 数据验证工具

### 内置测试
```bash
# 运行数据验证测试
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/unit/data/test_battle_card_v3.gd"
```

### 自定义验证脚本
```gdscript
# 验证卡片 ID 唯一性
func validate_card_id_uniqueness() -> bool:
    var card_ids = []
    for card in DefaultCards.all_cards():
        if card.id in card_ids:
            push_error("Duplicate card ID: " + card.id)
            return false
        card_ids.append(card.id)
    return true

# 验证引用完整性
func validate_references() -> bool:
    var all_card_ids = DefaultCards.all_card_ids()
    for evolution_path in EvolutionPathRegistry.all_paths():
        if evolution_path.target_id not in all_card_ids:
            push_error("Invalid reference: " + evolution_path.target_id)
            return false
    return true
```

## 注意事项

1. **数据规模**:
   - 110+ 卡片
   - 140+ MOD
   - 8 条进化路径
   - 13 个军衔
   - 100 个关卡
   - 112 个揭示事件

2. **v6.0 新数据**:
   - 情报维度 (4 维)
   - 揭示事件 (112 个)
   - 隐藏进化分支 (4 条)
   - 敌方起源 MOD (9 个)

3. **更新频率**:
   - 卡片数据: 较少更新
   - MOD 数据: 定期更新
   - 平衡性调整: 每次更新
   - 新内容: 每个大版本

## 常见数据问题

### 引用错误
```
问题: 进化路径引用不存在的卡片
解决:
1. 验证所有引用的卡片 ID 存在
2. 更新进化路径数据
3. 添加缺失的卡片
```

### 数值异常
```
问题: 卡片属性超出合理范围
解决:
1. 定义数值范围常量
2. 添加数据验证脚本
3. 在编辑器中显示警告
```

### 一致性问题
```
问题: 不同文件中同一数据不一致
解决:
1. 使用单一数据源
2. 避免数据重复
3. 添加一致性检查
```

### 本地化问题
```
问题: 中文显示乱码或缺失
解决:
1. 确保所有文本使用 UTF-8
2. 验证所有显示项都有中文
3. 添加本地化验证工具
```
