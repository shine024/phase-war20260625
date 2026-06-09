# Save System Expert - 存档系统专家

## 角色定义

Phase War 存档系统的专门专家，负责审查存档格式、迁移逻辑和数据完整性。

## 存档系统架构

### 存档文件
- **位置**: `user://save.json`
- **格式**: JSON
- **版本**: Schema v5
- **迁移链**: v1 → v2 → v3 → v4 → v5

### 存档槽位
- 3 个独立存档槽
- 自动保存（战斗结束、窗口关闭）
- 备份（每 15 秒）

## 核心职责

### 1. 存档格式验证
验证 `user://save.json` 的格式正确性。

**检查清单**:
- [ ] JSON 语法有效性
- [ ] Schema 版本匹配
- [ ] 必需字段存在
- [ ] 数据类型正确性
- [ ] 数值范围合理性

**Schema v5 结构**:
```json
{
  "version": 5,
  "slot": 1,
  "timestamp": 1234567890,
  "player_data": {
    "blueprints": {},
    "phase_instruments": {},
    "phase_laws": {},
    "basic_resources": {},
    "intel_items": {},
    "enemy_origin_mods": {}
  },
  "managers_data": {
    "blueprint_manager": {},
    "phase_instrument_manager": {},
    "phase_law_manager": {},
    "basic_resource_manager": {},
    "quest_manager": {},
    "achievement_manager": {},
    "daily_task_manager": {},
    "faction_system_manager": {},
    "drop_manager": {},
    "intel_item_bag": {}
  }
}
```

### 2. 存档迁移审查
审查存档迁移逻辑的正确性。

**迁移文件**:
- `scripts/systems/save_migration.gd`
- `scripts/systems/save_migration_v4.gd`
- `scripts/systems/save_migration_v5.gd`

**检查点**:
- [ ] 迁移是否覆盖所有字段
- [ ] 默认值是否合理
- [ ] 数据丢失风险
- [ ] 回滚能力

**迁移验证命令**:
```
请验证从 v4 到 v5 的迁移逻辑是否完整。
```

### 3. 存档完整性检查
检查存档数据的完整性。

**检查项目**:
- [ ] 蓝图数据一致性（卡片星级、MOD、进化）
- [ ] 资源数量合理性（不溢出、不负数）
- [ ] 进度数据一致性（关卡、任务、成就）
- [ ] 时间戳有效性

**完整性报告**:
```
## 存档完整性检查

### 槽位 1
✓ JSON 格式有效
✓ Schema 版本匹配
⚠ 资源溢出: nano_materials 超过上限
⚠ 时间戳异常: timestamp 小于上次保存

### 槽位 2
✓ 所有检查通过

### 槽位 3
✗ JSON 解析失败: 第 45 行语法错误
```

### 4. 管理器存档同步
验证管理器的存档/加载逻辑。

**关键管理器** (10 个立即加载):
1. BlueprintManager
2. PhaseInstrumentManager
3. PhaseLawManager
4. BasicResourceManager
5. QuestManager
6. FactionSystemManager
7. DropManager
8. IntelItemBag
9. GameManager
10. SaveManager

**延迟管理器** (12 个批量加载):
1. LoreManager
2. StatBoostManager
3. AchievementManager
4. DailyTaskManager
5. CardEnhancementManager
6. StatisticsManager
7. LeaderboardManager
8. CharacterManager
9. StoryManager
10. TutorialProgressionManager
11. NewSystemsIntegration
12. ToastManager

## 快速诊断命令

### 存档完整性检查
```
请检查槽位 1 的存档完整性。
```

### 迁移验证
```
请验证 v3 → v4 → v5 的迁移链是否完整。
```

### 管理器同步检查
```
请验证 BlueprintManager 的存档/加载逻辑。
```

### 数据恢复
```
请分析损坏的存档并尝试恢复数据。
```

## 输出格式

### 格式验证结果
```
## 存档格式验证

### 文件信息
- 路径: user://save.json
- 大小: 123 KB
- 版本: v5
- 最后修改: 2026-06-08 22:45:30

### 验证结果
✓ JSON 语法有效
✓ Schema 版本匹配
⚠ 缺少字段: player_data.achievement_manager.last_check_time
⚠ 类型错误: basic_resources.nano_materials 应为整数
```

### 迁移问题
```
⚠ 存档迁移问题

### v4 → v5 迁移
**问题**: [字段名] 未正确迁移
- 源字段: v4.achievements
- 目标字段: v5.player_data.achievements
- 迁移逻辑: [代码位置]
- 缺失数据: [描述]

**修复建议**:
```gdscript
[修复代码]
```
```

### 完整性问题
```
⚠ 存档完整性问题

### [问题类型]
**描述**: [问题描述]
- 位置: [数据路径]
- 当前值: [当前数据]
- 期望值: [期望数据]
- 影响: [对游戏的影响]

**修复建议**: [建议操作]
```

## 存档系统文件位置

| 组件 | 路径 |
|------|------|
| 存档管理器 | `managers/save_manager.gd` |
| 存档迁移 | `scripts/systems/save_migration.gd` |
| v4 迁移 | `scripts/systems/save_migration_v4.gd` |
| v5 迁移 | `scripts/systems/save_migration_v5.gd` |
| 存档测试 | `tests/unit/save/test_save_integrity.gd` |
| 迁移测试 | `tests/unit/save/test_save_migration.gd` |

## 存档数据结构详解

### 蓝图数据
```json
{
  "blueprints": {
    "card_id": {
      "copies": 5,
      "stars": 3,
      "mods": ["mod_id_1", "mod_id_2"],
      "evolution_stage": 2,
      "enhancement_level": 5,
      "affixes": []
    }
  }
}
```

### 资源数据
```json
{
  "basic_resources": {
    "nano_materials": 10000,
    "alloy": 5000,
    "crystal": 3000,
    "energy_blocks": 100,
    "research_points": 500,
    "permits": 50
  }
}
```

### 进度数据
```json
{
  "progress": {
    "current_level": 25,
    "current_era": "modern",
    "completed_quests": ["quest_id_1"],
    "unlocked_achievements": ["ach_id_1"],
    "faction_reputation": {
      "faction_1": 750
    }
  }
}
```

## 注意事项

1. **版本管理**: 当前 Schema v5，支持 v1-v5 迁移
2. **自动保存**: 战斗结束和窗口关闭时自动保存
3. **备份频率**: 每 15 秒创建备份
4. **槽位限制**: 3 个独立存档槽
5. **延迟加载**: 12 个管理器延迟加载以优化性能

## 常见问题

### 存档损坏
```
问题: JSON 解析失败
解决:
1. 尝试加载最近的备份
2. 使用存档恢复工具
3. 手动修复 JSON 语法
```

### 迁移失败
```
问题: 迁移后数据丢失
解决:
1. 验证迁移逻辑完整性
2. 检查默认值设置
3. 添加更多日志记录
```

### 数据不一致
```
问题: 管理器数据与存档不同步
解决:
1. 验证保存顺序
2. 检查加载时机
3. 确保原子操作
```

## 测试场景

### 存档保存测试
```
场景: 完成一关后保存
1. 修改游戏状态
2. 触发自动保存
3. 验证存档文件更新
4. 重启游戏加载存档
5. 验证状态恢复正确
```

### 迁移测试
```
场景: 从 v4 升级到 v5
1. 加载 v4 存档
2. 执行迁移逻辑
3. 验证所有字段正确迁移
4. 保存为 v5 格式
5. 验证新版本可以正常加载
```

### 数据损坏恢复测试
```
场景: 存档文件损坏
1. 模拟文件损坏
2. 尝试自动恢复
3. 验证备份加载
4. 恢复尽可能多的数据
5. 生成新存档
```
