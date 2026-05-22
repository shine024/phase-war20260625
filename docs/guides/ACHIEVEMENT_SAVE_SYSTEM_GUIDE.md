# 成就系统和存档系统 - 使用指南

## 🎯 系统概述

增强的成就系统和存档系统为游戏提供了更丰富的玩家体验和更灵活的存档管理。

## 📊 成就系统

### 系统架构

```
成就系统
├── 成就管理器 (AchievementManager)
├── 扩展成就定义 (AchievementDefinitionsExtended)
├── 成就UI面板 (AchievementPanel)
└── 成就统计追踪
```

### 成就分类

#### 1. 战斗成就 (30个)
- **胜利里程碑**: 初战告捷、小有成就、百战老兵等
- **击杀统计**: 击杀大师、灭绝师太等
- **伤害输出**: 伤害输出者、破坏之王等
- **特殊胜利**: 无伤胜利、速战速决、连胜大师等
- **BOSS击败**: 击败各种敌方相位师

#### 2. 收藏成就 (25个)
- **蓝图收集**: 收藏家起步、蓝图大师等
- **卡牌收集**: 卡牌收藏家、全图鉴等
- **稀有度收集**: 传说猎人、史诗收藏家等

#### 3. 进度成就 (20个)
- **关卡进度**: 前哨站、战线推进、战场主宰等
- **完美评价**: 完美主义者、全星级玩家等
- **时代完成**: 各个时代完成成就
- **游戏时长**: 长期玩家、资深玩家等

#### 4. 挑战成就 (15个)
- **生存模式**: 生存专家、生存大师等
- **BOSS连战**: BOSS挑战者、BOSS大师等
- **限时挑战**: 速度之星、时间主宰等
- **无伤挑战**: 无伤挑战、完美无瑕等
- **最大伤害**: 破坏极限、一击必杀等

#### 5. 系统成就 (10个)
- **存档相关**: 初次存档、存档大师等
- **合成强化**: 合成大师、强化专家等
- **商店交易**: 购物狂、商店常客等

#### 6. 特殊成就 (10个)
- **隐藏成就**: 探索者、秘密发现等
- **财富目标**: 百万富翁、资源大亨等
- **终极挑战**: 终极BOSS击败者、传奇成就等

### 成就奖励系统

#### 奖励类型
- **基础纳米颗粒**: 游戏基础货币
- **能量块**: 能量货币
- **相位经验**: 相位仪经验值
- **特殊卡牌**: 稀有卡牌奖励
- **蓝图碎片**: 用于解锁蓝图

#### 领取机制
```gdscript
# 单个领取
AchievementManager.claim_achievement_reward("achievement_id")

# 批量领取
var claimable = AchievementManager.get_claimable_rewards()
for ach_id in claimable:
    AchievementManager.claim_achievement_reward(ach_id)
```

### 统计追踪系统

#### 战斗统计
- 总胜利次数
- 总战斗次数
- 总击杀数
- 总伤害输出
- 无伤胜利次数
- 快速胜利次数（180秒内）
- 连胜统计
- 击败的BOSS列表

#### 收藏统计
- 唯一蓝图数量
- 唯一卡牌数量
- 各稀有度卡牌数量

#### 进度统计
- 最高关卡等级
- 完美通关关卡数
- 时代完成情况
- 总游戏时长

#### 挑战统计
- 生存模式完成次数
- BOSS连战完成次数
- 限时挑战完成次数
- 无伤挑战完成次数
- 单场最大伤害

#### 系统统计
- 总存档次数
- 手动存档次数
- 自动存档次数
- 合成操作次数
- 强化操作次数
- 商店购买次数

### 成就API使用

#### 记录游戏事件
```gdscript
var achievement_mgr = get_node_or_null("/root/AchievementManager")

# 记录战斗胜利
var battle_data = {
    "no_damage": true,
    "battle_time": 120,
    "kills": 50,
    "damage_dealt": 10000,
    "defeated_master": "enemy_master_001"
}
achievement_mgr.record_battle_victory(battle_data)

# 记录收集品
achievement_mgr.record_collection("card_id", "legendary")

# 记录关卡进度
achievement_mgr.record_level_progress(25, 3)  # 关卡25，3星

# 记录挑战完成
var challenge_data = {"damage_dealt": 50000}
achievement_mgr.record_challenge_completion("boss_rush", challenge_data)

# 记录系统操作
achievement_mgr.record_system_operation("manual_save")
```

#### 查询成就状态
```gdscript
# 检查成就是否解锁
var is_unlocked = achievement_mgr.is_achievement_unlocked("ach_first_win")

# 获取成就进度
var progress = achievement_mgr.get_achievement_progress("ach_wins_100")
# 返回: {"current": 50, "max": 100, "percentage": 50.0, "unlocked": false}

# 获取解锁进度
var unlock_progress = achievement_mgr.get_unlock_progress()
# 返回: {"total": 100, "unlocked": 25, "percentage": 25.0, "category_progress": {...}}

# 获取统计信息
var stats = achievement_mgr.get_achievement_statistics()
```

## 💾 存档系统

### 系统架构

```
存档系统
├── 基础存档管理器 (SaveManager)
├── 增强存档管理器 (SaveManager)
├── 存档槽管理器UI (SaveSlotManager)
└── 自动存档系统
```

### 存档槽配置

#### 标准存档槽
- **slot_1**: 存档槽 1
- **slot_2**: 存档槽 2
- **slot_3**: 存档槽 3

#### 特殊存档槽
- **auto_save**: 自动存档（系统自动管理）
- **quick_save**: 快速存档（玩家手动快速保存）

### 存档功能

#### 基础存档操作
```gdscript
var save_mgr = get_node_or_null("/root/SaveManager")

# 保存到当前槽
save_mgr.save_game()

# 保存到指定槽
save_mgr.save_game_to_slot("slot_2")

# 加载当前槽
save_mgr.load_game()

# 从指定槽加载
save_mgr.load_game_from_slot("slot_1")

# 删除存档
save_mgr.delete_save("slot_3")
```

#### 快速存档/读档
```gdscript
# 快速存档（F5快捷键）
save_mgr.quick_save()

# 快速读档（F9快捷键）
save_mgr.quick_load()
```

#### 存档槽管理
```gdscript
# 获取所有存档槽信息
var all_slots = save_mgr.get_all_save_slots()

# 获取指定槽位信息
var slot_info = save_mgr.get_save_slot_info("slot_1")

# 复制存档
save_mgr.copy_save("slot_1", "slot_2")

# 设置当前槽位
save_mgr.set_current_slot("slot_3")

# 获取当前槽位
var current = save_mgr.get_current_slot()
```

### 自动存档系统

#### 自动存档配置
```gdscript
# 启用自动存档，间隔5分钟
save_mgr.configure_auto_save(true, 5)

# 禁用自动存档
save_mgr.configure_auto_save(false, 0)
```

#### 自动存档触发事件
- 战斗完成
- 关卡完成
- 重要游戏事件
- 定时触发（可配置间隔）

### 存档导入/导出

#### 导出存档
```gdscript
# 导出存档到指定路径
var success = save_mgr.export_save("slot_1", "user://backup_save.json")
```

#### 导入存档
```gdscript
# 从文件导入存档
var success = save_mgr.import_save("user://backup_save.json", "slot_2")
```

### 存档验证和维护

#### 验证存档完整性
```gdscript
# 验证存档文件
var is_valid = save_mgr.validate_save_file("slot_1")
```

#### 获取存档信息
```gdscript
# 获取存档文件大小
var file_size = save_mgr.get_save_file_size("slot_1")

# 获取存档统计
var stats = save_mgr.get_save_statistics()
# 返回: {"total_saves": 100, "manual_saves": 80, "auto_saves": 20, ...}
```

#### 清理旧存档
```gdscript
# 清理30天前的存档
save_mgr.cleanup_old_saves(30)
```

### 存档数据结构

#### 元数据
```json
{
  "metadata": {
    "slot_id": "slot_1",
    "save_time": 1234567890,
    "save_version": "1.0",
    "is_auto_save": false,
    "game_version": "1.0.0"
  }
}
```

#### 预览数据
```json
{
  "preview": {
    "max_level": 25,
    "playtime_minutes": 1200,
    "basic_nano": 50000,
    "achievements_unlocked": 30
  }
}
```

#### 游戏数据
- 蓝图数据
- 基础资源
- 相位法则
- 任务状态
- 势力系统
- 卡牌强化
- 词缀数据
- 法则碎片
- 关卡进度
- 成就进度
- 相位仪数据
- 背包数据

## 🎮 UI界面使用

### 成就面板

#### 打开成就面板
```gdscript
var achievement_panel = preload("res://scenes/ui/achievement_panel.tscn").instantiate()
get_node("/root/Main").add_child(achievement_panel)
```

#### 功能特性
- **分类浏览**: 按成就分类查看
- **进度显示**: 实时显示完成进度
- **奖励领取**: 一键领取或批量领取奖励
- **搜索功能**: 搜索特定成就
- **推荐系统**: 显示即将完成的成就

#### 使用方法
1. 点击分类标签切换成就类别
2. 查看成就详情和进度
3. 点击"领取奖励"按钮获得奖励
4. 使用"批量领取"一次性领取所有奖励

### 存档槽管理器

#### 打开存档管理器
```gdscript
var slot_manager = preload("res://scenes/ui/save_slot_manager.tscn").instantiate()
get_node("/root/Main").add_child(slot_manager)
```

#### 功能特性
- **槽位显示**: 显示所有存档槽状态
- **存档信息**: 显示保存时间、游戏进度等
- **槽位操作**: 加载、保存、删除存档
- **导入导出**: 支持存档备份和恢复
- **自动清理**: 清理过期存档

#### 使用方法
1. 查看所有存档槽的状态和信息
2. 点击"加载"按钮加载指定槽位
3. 点击"保存"按钮保存到指定槽位
4. 点击"删除"按钮删除存档
5. 使用导入/导出功能备份存档

## 🔧 开发者集成

### 在游戏代码中集成成就系统

#### 战斗结束
```gdscript
func on_battle_completed(result: Dictionary):
    var achievement_mgr = get_node_or_null("/root/AchievementManager")
    if achievement_mgr == null:
        return

    if result.get("victory", false):
        var battle_data = {
            "no_damage": result.get("player_damage", 0) == 0,
            "battle_time": result.get("battle_time", 0),
            "kills": result.get("enemy_kills", 0),
            "damage_dealt": result.get("total_damage", 0),
            "defeated_master": result.get("boss_id", "")
        }
        achievement_mgr.record_battle_victory(battle_data)
    else:
        achievement_mgr.record_battle_defeat()

    # 自动存档
    var save_mgr = get_node_or_null("/root/SaveManager")
    if save_mgr != null:
        save_mgr.perform_auto_save()
```

#### 卡牌获取
```gdscript
func on_card_obtained(card_id: String, rarity: String):
    var achievement_mgr = get_node_or_null("/root/AchievementManager")
    if achievement_mgr != null:
        achievement_mgr.record_collection(card_id, rarity)
```

#### 关卡完成
```gdscript
func on_level_completed(level: int, stars: int):
    var achievement_mgr = get_node_or_null("/root/AchievementManager")
    if achievement_mgr != null:
        achievement_mgr.record_level_progress(level, stars)

    # 保存游戏
    var save_mgr = get_node_or_null("/root/SaveManager")
    if save_mgr != null:
        save_mgr.perform_auto_save()
```

### 数据持久化

#### 成就数据自动保存
成就数据会通过SaveManager自动保存和加载，无需额外处理。

#### 存档兼容性
- 支持旧版本存档升级
- 自动数据迁移
- 错误恢复机制

## 📈 性能优化

### 成就系统优化
- 延迟加载：只加载需要的成就数据
- 缓存机制：缓存常用查询结果
- 批量处理：批量更新多个成就

### 存档系统优化
- 增量保存：只保存变化的数据
- 压缩存储：使用JSON压缩减少文件大小
- 异步操作：避免存档时卡顿

## 🐛 故障排除

### 成就解锁问题
1. 检查成就管理器是否正确加载
2. 确认统计事件是否正确记录
3. 查看控制台错误信息

### 存档加载失败
1. 检查存档文件完整性
2. 验证存档版本兼容性
3. 尝试导入备份存档

### UI显示问题
1. 确认场景文件正确加载
2. 检查节点路径是否正确
3. 验证信号连接是否建立

## 🎉 总结

增强的成就系统和存档系统为《Phase War》提供了：

### 成就系统特色
- ✅ 100+ 个精心设计的成就
- ✅ 6 大成就分类
- ✅ 实时进度追踪
- ✅ 丰富的奖励系统
- ✅ 详细的统计信息
- ✅ 智能推荐系统

### 存档系统特色
- ✅ 多存档槽管理
- ✅ 自动存档功能
- ✅ 快速存档/读档
- ✅ 存档导入/导出
- ✅ 数据完整性验证
- ✅ 旧存档清理

这些系统将大大增强游戏的可玩性和用户体验！
