# 词条战斗效果实现指南

## 概览

词条战斗效果系统已完成实现，包含以下核心模块：

| 模块 | 文件 | 职责 |
|------|------|------|
| 词条定义 | `data/affix_definitions.gd` | 词条类型、基础数值、稀有度 |
| 词条资源 | `resources/affix_resource.gd` | 单个词条实例数据 |
| 词条管理 | `managers/affix_manager.gd` | 词条获取、升级、存档 |
| **战斗效果处理** | **`managers/affix_combat_handler.gd`** | **词条效果计算与应用** |

---

## 1. 词条效果分类

### 1.1 基础属性修正（已部分实现）

这类词条通过修改 `UnitStats` 的基础属性，在单位创建时自动应用：

| 词条 ID | 名称 | 效果 | 数值（Lv1） |
|---------|------|------|-----------|
| `platform_hp_up` | 铁甲强化 | 最大 HP +12% | +12% |
| `platform_speed_up` | 疾行引擎 | 移动速度 +10% | +10% |
| `platform_armor` | 纳米装甲 | 伤害减免 +8% | +8% |
| `weapon_dmg_up` | 穿透弹芯 | 攻击伤害 +15% | +15% |
| `weapon_range_up` | 延伸枪管 | 攻击射程 +12% | +12% |
| `weapon_atkspd_up` | 速射改装 | 攻击间隔 ×0.88 | -12% |

**应用时机**：`BattleManager._try_spawn_player_unit()` 调用 `AffixManager.apply_affixes_to_stats()`

**实现位置**：`managers/affix_manager.gd` 第 268-335 行

---

### 1.2 战斗特性词条（新实现）

这类词条在**伤害计算和处理阶段**应用，通过子弹命中时的特殊逻辑实现：

#### 1.2.1 暴击（Crit Chance）

```gd
# 效果
- 8% 暴击率（Lv1）
- 暴击伤害：×1.5 倍

# 实现位置
AffixCombatHandler.calculate_damage()

# 触发时机
子弹命中目标时，根据 shooter_stats.crit_chance 判断是否暴击
```

**代码示例**：
```gd
var damage_calc = AffixCombatHandler.calculate_damage(
    damage,
    shooter_stats,
    target.hp,
    target.max_hp,
    target.damage_reduction
)
var is_crit = damage_calc["is_crit"]
```

#### 1.2.2 吸血（Lifesteal）

```gd
# 效果
- 5% 吸血率（Lv1）
- 攻击伤害的 5% 回复为 HP

# 实现位置
AffixCombatHandler.apply_lifesteal()

# 触发时机
每次造成伤害后，吸血量 = 伤害 × lifesteal_rate
```

**代码示例**：
```gd
var lifesteal_heal = AffixCombatHandler.apply_lifesteal(
    final_damage,
    shooter_stats,
    shooter  # 射手单位引用
)
```

#### 1.2.3 溅射伤害（Splash Damage）

```gd
# 效果
- 20% 溅射伤害（Lv1）
- 在目标周围 80px 范围内造成范围伤害

# 实现位置
AffixCombatHandler.apply_splash_damage()

# 触发时机
每次直击后，在目标周围范围内寻找额外目标
```

**代码示例**：
```gd
var splash_targets = AffixCombatHandler.apply_splash_damage(
    primary_target,
    final_damage,
    shooter_stats,
    shooter_is_player
)
```

#### 1.2.4 穿甲（Armor Penetration）

```gd
# 效果
- 15% 穿甲率（Lv1）
- 忽视目标 15% 的伤害减免

# 实现位置
AffixCombatHandler.calculate_damage() 内的防御计算

# 计算公式
effective_reduction = target_reduction × (1.0 - armor_penetration)
final_damage = base_damage × (1.0 - effective_reduction)
```

---

### 1.3 特殊机制词条（新实现）

#### 1.3.1 链式放电（Chain Lightning）

```gd
# 效果
- 12% 连锁触发率（Lv1）
- 每次触发后跳至附近 5 个敌人，造成 75% 的伤害

# 实现位置
AffixCombatHandler.apply_chain_lightning()

# 触发时机
每次造成伤害后，根据 chain_chance 判断是否触发连锁
```

**代码示例**：
```gd
var chain_targets = AffixCombatHandler.apply_chain_lightning(
    primary_target,
    final_damage,
    shooter_stats,
    shooter_is_player,
    5  # 最多连锁目标数
)
```

#### 1.3.2 击杀护盾（Shield on Kill）

```gd
# 效果
- 5% 最大 HP 的护盾值（Lv1）
- 每次击杀获得一层护盾

# 实现位置
AffixCombatHandler.apply_shield_on_kill()

# 触发时机
单位死亡时，杀手获得护盾
需要在 SignalBus.unit_died 信号中调用
```

**集成示例**（需在战斗逻辑中添加）：
```gd
# 在 construct_unit.gd 或战斗管理器中
func _on_enemy_died(unit: Node, is_player: bool) -> void:
    if is_player:
        # 查找杀手，调用护盾效果
        var shield = AffixCombatHandler.apply_shield_on_kill(killer, killer_stats)
```

#### 1.3.3 纳米自愈（Nano Regen）

```gd
# 效果
- 每秒回复 0.5% 最大 HP（Lv1）
- 在战斗中缓慢恢复生命

# 实现位置
AffixCombatHandler.apply_hp_regen()

# 触发时机
每帧调用（在 _physics_process 中）
```

**代码示例**：
```gd
# construct_unit.gd 的 _apply_continuous_effects()
if stats.hp_regen > 0.0:
    AffixCombatHandler.apply_hp_regen(self, stats, delta)
```

---

## 2. 词条变异效果

当词条升到 **Lv5** 时，有 25% 概率触发变异，获得额外效果：

| 词条 | 变异效果 |
|------|---------|
| `weapon_dmg_up` | 攻击时 15% 概率造成双倍伤害 |
| `weapon_atkspd_up` | 连续 3 次攻击后，下次攻击伤害 +50% |
| `crit_chance` | 暴击时额外恢复 5% 最大生命值 |
| `lifesteal` | 生命值 <30% 时，吸血效果翻倍 |
| `splash_dmg` | 溅射击杀时触发额外一次溅射 |
| `chain_lightning` | 连锁最多延伸至 5 个目标（已配置） |
| `shield_on_kill` | 护盾层数上限 +2 |
| `nano_regen` | 生命值 <50% 时，回复速度翻倍 |
| `platform_hp_up` | 血量 >80% 时，受伤害额外减少 10% |

**实现位置**：`managers/affix_combat_handler.gd` 的 mutation 系列函数

---

## 3. 集成流程

### 3.1 战斗单位创建流程

```
1. BattleManager._try_spawn_player_unit()
   ↓
2. UnitStatsTable.build_multi_stats()          [基础数值]
   ↓
3. BlueprintManager.apply_growth_to_stats()    [成长加成]
   ↓
4. AffixManager.apply_affixes_to_stats()       [词条属性修正]
   ↓
5. construct_unit.setup(stats)                 [创建单位]
```

### 3.2 伤害计算流程

```
construct_unit._do_attack_with_damage(damage)
   ↓
bullet.setup(..., shooter, shooter_stats)
   ↓
bullet._on_hit(target)
   ↓
AffixCombatHandler.calculate_damage()          [暴击+穿甲]
   ↓
target.take_damage(final_damage)
   ↓
AffixCombatHandler.apply_lifesteal()           [吸血]
   ↓
AffixCombatHandler.apply_splash_damage()       [溅射]
   ↓
AffixCombatHandler.apply_chain_lightning()     [连锁]
```

### 3.3 持续效果流程

```
construct_unit._physics_process(delta)
   ↓
_apply_continuous_effects(delta)
   ↓
AffixCombatHandler.apply_hp_regen()            [回血]
```

---

## 4. 文件修改清单

### 新增文件
- `managers/affix_combat_handler.gd` - 词条战斗效果处理器

### 修改文件

#### `scenes/units/bullet.gd`
- 添加 `shooter` 和 `shooter_stats` 参数
- 修改 `setup()` 方法签名
- 重写 `_on_hit()` 方法以应用词条效果
- 添加 `_on_hit_basic()` 作为后备方案

#### `scenes/units/construct_unit.gd`
- 添加 `shield` 属性
- 添加 `heal()` 方法（词条吸血）
- 添加 `add_shield()` 方法（词条护盾）
- 添加 `take_damage_with_shield()` 方法
- 添加 `_apply_continuous_effects()` 方法
- 修改 `_do_attack_with_damage()` 以传递射手信息
- 修改 `_physics_process()` 调用持续效果处理

#### `scenes/units/enemy_unit.gd`
- 添加 `stats` 属性用于词条计算
- 添加 `heal()` 方法
- 修改 `_do_attack()` 以传递射手信息

---

## 5. 配置参数

所有词条效果的参数均在 `data/affix_definitions.gd` 中定义：

### 基础参数
```gd
const MAX_AFFIX_SLOTS: int = 4              # 每卡最多词条数
const MAX_AFFIX_LEVEL: int = 5              # 词条等级上限
const MUTATION_CHANCE: float = 0.25         # 变异触发概率
```

### 词条数值
```gd
AFFIX_TABLE = {
    "weapon_dmg_up": {
        "base_value": 0.15,                 # Lv1 数值
        "rarity_pool": ["common", ...],     # 可获得的稀有度
    },
    ...
}
```

### 稀有度倍率（`affix_resource.gd`）
```gd
static func get_rarity_multiplier(rar: String) -> float:
    "common": 1.0, "rare": 1.3, "epic": 1.7, "legendary": 2.2
```

### 等级倍率（`affix_resource.gd`）
```gd
static func get_level_factor(lv: int) -> float:
    1: 1.0, 2: 1.25, 3: 1.55, 4: 1.95, 5: 2.5
```

---

## 6. 测试建议

### 6.1 单元测试
- [ ] 测试暴击概率准确性
- [ ] 测试穿甲减免计算
- [ ] 测试吸血数值
- [ ] 测试溅射范围和伤害
- [ ] 测试连锁跳跃距离和次数
- [ ] 测试护盾值上限
- [ ] 测试回血速率

### 6.2 集成测试
- [ ] 战斗中验证多个词条同时生效
- [ ] 验证变异效果的触发
- [ ] 验证词条升级后的数值变化
- [ ] 测试敌方单位是否正确应用词条（如果敌方有词条）

### 6.3 UI 反馈
- [ ] 暴击时显示特效（可选）
- [ ] 吸血时显示治疗数字（可选）
- [ ] 溅射击中显示范围标记（可选）
- [ ] 连锁链接视效（可选）

---

## 7. 已知限制

1. **敌方词条**：当前仅支持我方单位应用词条效果。敌方单位需要单独配置 `stats` 才能使用词条系统。

2. **护盾上限**：护盾上限设为双倍 HP，可根据游戏设计调整。

3. **范围判定**：溅射和连锁使用欧氏距离计算，暂无优化。

4. **变异效果**：部分变异效果（如双倍伤害）需要在单位端维护计数器，可能需要额外 UI 反馈。

---

## 8. 后续扩展建议

1. **护盾系统完善**：
   - 护盾独立 UI 显示（蓝色覆盖层）
   - 护盾破裂特效

2. **特殊效果动画**：
   - 暴击闪光
   - 连锁闪电链
   - 溅射爆炸效果

3. **词条组合加成**：
   - 同类型词条的额外加成
   - 词条之间的相性系统

4. **敌方词条支持**：
   - 为 Boss 怪物配置词条
   - 难度随词条变化

5. **性能优化**：
   - 范围判定的空间分割
   - 伤害计算的缓存

---

## 参考资源

- 词条定义表：`data/affix_definitions.gd`
- 词条资源类：`resources/affix_resource.gd`
- 词条管理器：`managers/affix_manager.gd`
- **词条战斗处理器**：`managers/affix_combat_handler.gd`
- 战斗管理器：`managers/battle_manager.gd`
- 单位数值类：`resources/unit_stats.gd`
- 我方单位脚本：`scenes/units/construct_unit.gd`
- 敌方单位脚本：`scenes/units/enemy_unit.gd`
- 子弹脚本：`scenes/units/bullet.gd`
