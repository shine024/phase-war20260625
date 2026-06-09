# Phase War 平衡性调整记录

本文档记录所有游戏平衡性调整，包括原因和效果。

## v6.1 平衡性调整 (2026-06-08)

### 时代系数调整

**问题**: 近未来（时代4）伤害倍率1.90导致后期单位火力过溢

**调整**:
- 文件: `data/battle_card_v3.gd`
- 近未来伤害倍率: 1.90 → 1.80
- 时代系数曲线: 1.00 / 1.20 / 1.40 / 1.65 / 1.80

**影响**: 
- 后期单位攻击性略微降低，避免战斗过快结束
- 保持HP倍率不变（1.60），提升后期单位生存时间

### 单位属性调整

**问题**: 冷战时代T-72 HP高于M1，但历史定位M1应更强

**调整**:
- 文件: `data/default_cards.gd`
- T-72 HP: 850 → 800
- M1 HP: 800 → 850

**影响**: 更符合历史定位，M1作为主战坦克应有更高生存能力

### MOD强度调整

**问题**: 部分MOD攻速提升过高，导致战斗节奏过快

**调整**:
1. **aa_04_quad_mount** (防空-四联装)
   - 文件: `data/modification_modules/anti_air_mods.gd`
   - attack_interval: -35% → -30%
   - 原因: 稀有度攻速降低幅度高于平均值

2. **aa_11_auto_fc** (防空-自动化火控)
   - 文件: `data/modification_modules/anti_air_mods.gd`
   - attack_interval: -50% → -40%
   - 原因:史诗MOD攻速降低幅度极高

3. **air_05_helmet_sight** (空军-头盔瞄准具)
   - 文件: `data/modification_modules/air_mods.gd`
   - attack_interval: -50% → -40%
   - 原因:史诗MOD攻速降低幅度极高

**已完成于v6.0的调整**:
1. aa_01_radar: attack_interval -50% → -30%
2. art_06_fire_computer: attack_interval -40% → -30%
3. art_09_rapid_fire: attack_interval -30% → -20%
4. arm_06_apfsds: attack_armor +35% → +30%

**影响**: 
- 战斗节奏更合理，避免射速过快导致的一边倒
- 保持MOD稀有度power_mult分层（uncommon 1.0, rare 1.3, epic 1.6, legendary 2.0）

## v6.0 平衡性调整 (记录补充)

### MOD系统整体平衡
- 统一稀有度power_mult分布
- 避免同稀有度MOD效果强度差异过大
- 保持攻击间隔降低在-20%到-40%之间

## 平衡性设计原则

1. **时代递增**: 每个时代相比前一代应有明显提升，但保持可玩性
2. **稀有度分层**: power_mult严格按稀有度分层，同稀有度MOD效果强度相近
3. **战斗节奏**: 攻速降低幅度控制在-20%到-40%，避免战斗过快或过慢
4. **历史定位**: 单位属性应基本符合历史定位和战场角色

## 后续平衡性监控点

1. 观察v6.1调整后的战斗数据
2. 监控近时代单位的胜率
3. 检查MOD使用频率分布
4. 评估战斗平均时长变化
