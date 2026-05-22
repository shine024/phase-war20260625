# 敌方相位师系统 - 使用指南

## 🎯 系统概述

30位敌方相位师系统为游戏提供了丰富的BOSS战体验，每位相位师都有独特的技能组合和装备配置。

## 📊 相位师分类

### 按等级分类
- **初级相位师** (1-10级): enemy_master_001 ~ enemy_master_004
- **中级相位师** (11-20级): enemy_master_005 ~ enemy_master_012
- **高级相位师** (16-25级): enemy_master_009 ~ enemy_master_015
- **大师级相位师** (22-30级): enemy_master_016 ~ enemy_master_023
- **传说级相位师** (29-30级): enemy_master_024 ~ enemy_master_027
- **终极相位师** (30级): enemy_master_030

### 按势力分类
- **钢铁势力**: 钢铁先锋、钢铁元帅、不朽钢铁等
- **烈焰势力**: 烈焰使者、炎魔女王、永恒炎魔等
- **雷霆势力**: 雷击者、雷神之子、万雷之主等
- **虚空势力**: 虚空行者、虚空领主、虚空虚主等
- **混合势力**: 钢铁烈焰、雷霆钢铁、虚空烈焰等

### 按难度分类
- **简单**: easy
- **普通**: medium
- **困难**: hard
- **专家**: expert
- **传说**: legendary
- **终极**: ultimate

## 🔥 技能系统

### 主动技能
每位相位师拥有2个主动技能：
- **冷却时间**: 12-120秒不等
- **能量消耗**: 60-1500点
- **效果类型**:
  - 召唤类
  - 伤害类
  - 增益类
  - 控制类
  - 地形类

### 被动技能
每位相位师拥有2个被动技能：
- **光环效果**: 持续影响周围环境
- **触发效果**: 特定条件下触发
- **属性加成**: 永久提升某项属性
- **特殊机制**: 独特的战术效果

## 🎨 技能效果示例

### 钢铁势力技能特点
- 防御强化：护盾、护甲提升
- 单位召唤：召唤钢铁战士
- 阵地防守：要塞模式、防御工事

### 烈焰势力技能特点
- 范围伤害：火焰风暴、流星群
- 持续燃烧：点燃区域、地狱火
- 爆炸伤害：死亡爆炸、连锁爆炸

### 雷霆势力技能特点
- 连锁闪电：弹射伤害
- 控制技能：眩晕、瘫痪
- 速度强化：闪电速度、过载

### 虚空势力技能特点
- 时空操控：时间扭曲、传送
- 生命吸取：熵增、虹吸
- 现实扭曲：维度撕裂、黑洞

## 🎮 使用方法

### 基础用法
```gdscript
# 获取指定等级的相位师
var masters = EnemyPhaseMasters.get_masters_by_level(10, 15)

# 获取指定势力的相位师
var steel_masters = EnemyPhaseMasters.get_masters_by_faction("steel")

# 获取指定难度的相位师
var hard_masters = EnemyPhaseMasters.get_masters_by_difficulty("hard")

# 获取特定相位师
var master = EnemyPhaseMasters.get_master_by_id("enemy_master_001")

# 创建相位师实例
var instance = EnemyPhaseMasters.create_master_instance("enemy_master_001")
```

### 技能系统集成
```gdscript
# 获取主动技能
var active_spells = EnemyPhaseMasters.get_master_active_spells("enemy_master_001")

# 获取被动技能
var passive_spells = EnemyPhaseMasters.get_master_passive_spells("enemy_master_001")

# 获取装备配置
var equipment = EnemyPhaseMasters.get_master_equipment("enemy_master_001")

# 获取属性数据
var stats = EnemyPhaseMasters.get_master_stats("enemy_master_001")
```

### 装备系统
```gdscript
# 获取相位仪
var instrument = EnemyPhaseEquipment.get_phase_instrument("steel_guardian_mk1")

# 获取战争平台
var platform = EnemyPhaseEquipment.get_war_platform("steel_fortress_basic")

# 获取武器
var weapon = EnemyPhaseEquipment.get_war_weapon("steel_machinegun_basic")

# 获取能量卡
var energy_card = EnemyPhaseEquipment.get_energy_card("steel_energy_basic")

# 根据等级获取装备
var equipment = EnemyPhaseEquipment.get_equipment_by_level(10)

# 根据势力获取装备
var faction_equipment = EnemyPhaseEquipment.get_equipment_by_faction("steel")
```

## ⚔️ 战斗集成

### AI行为逻辑
```gdscript
# 敌方相位师AI
func enemy_master_ai(master_instance: Dictionary, battle_state: Dictionary):
    # 检查能量是否足够释放技能
    # 评估战场形势
    # 选择合适的主动技能
    # 管理技能冷却时间
    pass

# 技能释放判断
func should_cast_spell(master_instance: Dictionary, spell_id: String) -> bool:
    var cooldowns = master_instance.skill_cooldowns
    var current_energy = master_instance.current_energy

    # 检查冷却时间
    # 检查能量是否足够
    # 评估释放时机
    return true_or_false
```

### 被动效果处理
```gdscript
# 应用被动技能效果
func apply_passive_effects(master_instance: Dictionary, target_units: Array):
    var passive_effects = master_instance.passive_effects

    for effect in passive_effects:
        match effect.type:
            "armor_boost":
                # 应用护甲加成
                pass
            "damage_aura":
                # 应用伤害光环
                pass
            "summon_bonus":
                # 应用召唤加成
                pass
```

## 📈 平衡性考虑

### 难度曲线
- **简单**: 适合新手，技能威力适中
- **普通**: 标准挑战，需要一定策略
- **困难**: 需要充分准备和合理战术
- **专家**: 高难度，需要完美的策略和执行力
- **传说**: 极高难度，需要顶级装备和操作
- **终极**: 终极挑战，测试所有游戏机制

### 数值平衡
- **生命值**: 1500-10000 (随等级和难度递增)
- **攻击力**: 120-1000 (随等级和难度递增)
- **防御力**: 50-200 (随等级和难度递增)
- **能量恢复**: 2.0-8.0 (随等级递增)
- **单位限制**: 5-15 (随等级和难度变化)

## 🎯 关卡设计建议

### 初级关卡 (1-10关)
- 使用 enemy_master_001 ~ enemy_master_004
- 让玩家学习基础对抗策略
- 介绍不同的势力特色

### 中级关卡 (11-20关)
- 使用 enemy_master_005 ~ enemy_master_012
- 增加技能组合的复杂度
- 要求玩家使用更多战术

### 高级关卡 (21-30关)
- 使用 enemy_master_013 ~ enemy_master_019
- 复杂的技能互动
- 需要专门准备的装备配置

### 大师关卡 (25-30关)
- 使用 enemy_master_020 ~ enemy_master_027
- 极高难度的挑战
- 需要完美的策略和执行力

### 终极挑战
- 使用 enemy_master_028 ~ enemy_master_030
- 游戏的最终挑战
- 测试玩家对所有机制的掌握

## 🔧 扩展和自定义

### 添加新相位师
```gdscript
# 参考现有格式添加新相位师
var new_master = {
    "id": "enemy_master_031",
    "name": "新相位师名称",
    "title": "称号",
    "level": 25,
    "faction": "steel",
    "difficulty": "expert",
    "active_spells": [...],
    "passive_spells": [...],
    "equipment": {...},
    "stats": {...}
}
```

### 创建自定义装备
```gdscript
# 在 enemy_phase_equipment.gd 中添加
var new_instrument = {
    "id": "custom_instrument",
    "name": "自定义相位仪",
    "faction": "custom",
    "level": 20,
    "rarity": "rare",
    "base_stats": {...},
    "special_effects": [...]
}
```

## 📊 数据统计

### 相位师总数
- 总数: 30位
- 钢铁势力: 8位
- 烈焰势力: 7位
- 雷霆势力: 7位
- 虚空势力: 6位
- 混合势力: 2位

### 技能总数
- 主动技能: 60个 (30位 × 2个)
- 被动技能: 60个 (30位 × 2个)
- 总技能数: 120个

### 装备总数
- 相位仪: 20个
- 战争平台: 15个
- 战争武器: 12个
- 能量卡: 15个

## 🎉 总结

30位敌方相位师系统为游戏提供了：
- ✅ 丰富的BOSS战体验
- ✅ 多样化的技能组合
- ✅ 完整的装备体系
- ✅ 平衡的难度曲线
- ✅ 清晰的势力特色

这个系统可以大大增强游戏的可玩性和挑战性！
