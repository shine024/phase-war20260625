# 项目优化建议报告

> 日期：2026-05-30
> 基于：全面代码审计 + 架构分析 + 游戏设计分析
> 范围：性能、架构、代码质量、游戏设计、终局内容

---

## 一、🔴 高优先级 — 运行时性能与体验关键

### 1.1 战斗热路径 preload 应提升为 const

**文件**: `scripts/battle/attack_calculator.gd` L47, L79, L119

**问题**: 战斗中每次子弹命中都会调用 `calculate_damage()`，函数内部用 `var` 声明 preload。虽然 Godot 引擎级只加载一次，但每帧创建局部变量是不必要的开销。

**修复**:
```gdscript
# 从：
func calculate_damage(...):
    var DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
# 改为（class 顶部）：
const DamageAttenuation = preload("res://scripts/battle/damage_attenuation.gd")
const ModEffects = preload("res://data/mod_effects.gd")
```

同样适用于 `scripts/master_power_evaluator.gd` L340, L476。

---

### 1.2 信号泄漏：219次 connect vs 11次 disconnect

**范围**: `scenes/ui/` 全部场景脚本

**问题**: 大量 UI 面板在 `_ready()` 中连接 SignalBus/Manager 信号，但只有 3 个文件实现了 `_exit_tree()` 清理。如果 UI 面板是重复创建/销毁的（如战斗 HUD），每次战斗都会泄漏连接。

**最严重的文件**:

| 文件 | connect 数 | disconnect 数 | 有 _exit_tree |
|------|-----------|---------------|-------------|
| `battle_hud.gd` | 11 | 0 | ❌ |
| `resource_bar.gd` | 5 | 0 | ❌ |
| `battle_info_display.gd` | 4 | 0 | ❌ |
| `enemy_spawn_hud.gd` | 2 | 0 | ❌ |
| `player_spawn_hud.gd` | 2 | 0 | ❌ |

**修复方案A（快速）**:
```gdscript
# 统一在 UI 基类或每个面板中添加：
func _exit_tree() -> void:
    _disconnect_all_signals()

func _disconnect_all_signals() -> void:
    for sig_list in [
        [SignalBus.battle_ended, _on_battle_ended],
        [SignalBus.unit_spawned, _on_unit_spawned],
        # ... 列出所有连接
    ]:
        if sig_list[0].is_connected(sig_list[1]):
            sig_list[0].disconnect(sig_list[1])
```

**修复方案B（推荐）**：创建 `UIPanelBase` 基类，统一管理信号生命周期。

---

### 1.3 基础资源缺乏消耗 Sink

**范围**: 经济系统整体

**问题**: 纳米材料、合金、晶体、能量块 4 种基础资源的主要用途不明确。商店中只能用能量块购买相位仪，纳米材料仅作为成就奖励。后期玩家会囤积大量资源导致经济通胀。

**建议新增消耗途径**:

| 资源 | 新增消耗 |
|------|---------|
| 纳米材料 | 势力专属卡蓝图购买（每张 500-2000） |
| 合金 | 卡牌 MOD 改造（替代纯研究点消耗） |
| 晶体 | 相位法则加速研究（跳过知识门槛） |
| 能量块 | 战前临时增益购买（战斗一次性 buff） |

---

## 二、🟡 中优先级 — 架构质量与可维护性

### 2.1 冗余委托层：rarity_helpers.gd / attribute_growth.gd

**文件**: `scripts/systems/rarity_helpers.gd`, `scripts/systems/attribute_growth.gd`

**问题**: 这两个文件的所有方法都是一行转发到 `EvolutionHelpers`，增加了不必要的调用层级：

```
UI → rarity_helpers.gd → EvolutionHelpers → DefaultCards
     （多余层）
```

**建议**: 移除中间层，调用方直接使用 `EvolutionHelpers`。如果需要 `ClassDB.class_exists()` 保护，可以在 `EvolutionHelpers` 内部处理。

---

### 2.2 save_state/load_state 样板代码重复（30个管理器）

**范围**: 全部 `managers/*.gd`

**问题**: 30 个管理器都实现了完全相同模式的 `save_state() -> Dictionary` 和 `load_state(data)`。每个都手动序列化字段。

**建议**: 提取基类 `SaveableManager`：

```gdscript
class_name SaveableManager
extends Node

## 标记需要序列化的属性（子类重写）
func _get_save_fields() -> Array:
    return []

func save_state() -> Dictionary:
    var d := {}
    for field in _get_save_fields():
        var val = get(field)
        if val is Dictionary:
            d[field] = val.duplicate(true)
        elif val is Array:
            d[field] = val.duplicate()
        else:
            d[field] = val
    return d

func load_state(data: Dictionary) -> void:
    for field in _get_save_fields():
        if data.has(field):
            set(field, data[field])
```

---

### 2.3 技能树缺少重置功能

**文件**: `data/faction_skill_tree.gd`, `managers/faction/faction_skill_manager.gd`

**问题**: A/B 分支互斥选择不可逆。玩家选错分支后永久受损，没有任何纠正机会。

**建议**: 添加重置功能：
- 消耗资源（研究点 + 纳米材料）重置单个分支
- 或消耗更多资源重置整个技能树
- 在 `FactionSystemManager` 中添加 `reset_faction_skill_branch(faction_id, tier, branch)` 方法

---

### 2.4 相位法则环境限制过严 → 25条法则中仅~10条常用

**文件**: `data/phase_laws.gd`

**问题**: 每条法则需要匹配特定的天气/地形/能量场/时间组合。很多法则的组合极为罕见（如 `void_time_ripple` 需要 void_rift + dusk/night），大部分关卡无法激活。

**建议**:
- **方案A**: 放宽环境条件（每个法则从需要2个环境匹配降为1个）
- **方案B**: 添加"相位环境修改器"消耗品，战前主动设定环境
- **方案C**: 高声望解锁"全环境激活"被动能力

---

## 三、🟢 低优先级 — 代码规范与长期演进

### 3.1 Static 函数访问 autoload 的架构不一致

**文件**: `managers/faction/faction_shop.gd`, `managers/achievement/achievement_rewards.gd`, `managers/card_ability_manager.gd`

**问题**: 多处 static 函数通过 `get_node("/root/SomeManager")` 访问 autoload 单例，违反了 static 函数无副作用的预期。

**建议**: 将这些函数改为实例方法，或在调用处传入依赖。

---

### 3.2 PhaseInstrumentManager 缓存无显式失效

**文件**: `managers/phase_instrument_manager.gd` L54 `_loadouts_cache`

**问题**: 缓存只在完全覆盖时更新，没有显式失效机制。如果外部修改了 loadout 数据，缓存可能过期。

**建议**: 添加 `invalidate_loadout_cache()` 方法，或在修改 loadout 时自动失效。

---

### 3.3 高星研究点倍率截断

**文件**: `data/blueprint_star_config.gd`

**问题**: `BATTLE_RESEARCH_STAR_MULTIPLIER` 只有 3 档（1★:1.0, 2★:1.2, 3★:1.5），3★ 以后没有额外加成。削弱了"越养越强"的正向循环。

**建议**: 扩展到 9 档：
```gdscript
# 从：
{1: 1.0, 2: 1.2, 3: 1.5}
# 改为：
{1: 1.0, 2: 1.2, 3: 1.4, 4: 1.6, 5: 1.8, 6: 2.0, 7: 2.3, 8: 2.6, 9: 3.0}
```

---

### 3.4 难度曲线时代切换倒退

**文件**: `data/level_information.gd`

**问题**: Lv20（二战结束）难度 1.18 → Lv21（冷战开始）难度 1.00，难度**下降了18%**。每个时代重新计算起始倍率导致不连续。

**建议**: 将难度倍率改为全局连续公式：
```gdscript
# 从：每时代重新计算起始值
# 改为：全局公式
static func get_difficulty(level: int) -> float:
    return 0.80 + level * 0.014  # Lv1=0.814, Lv20=1.08, Lv100=2.2
```
或至少确保时代衔接处不倒退。

---

## 四、🎮 游戏设计优化建议

### 4.1 终局内容：New Game+ / 噩梦模式

**现状**: 100关通关后，核心战斗循环结束。挑战模式在中期就解锁完毕。

**建议**:
- **噩梦模式**: 全部100关但难度 ×2.5，敌人获得新能力，掉落增强
- **无限塔爬模式**: 已有 `tower_run` 信号基础设施，可扩展为无限模式
- **势力征服模式**: 100关 + 势力领土控制，每关归属一个势力

### 4.2 周期性活动系统

**现状**: 日常任务（24h刷新）是唯一的周期性内容。

**建议**:
- **周常任务**: 3个高难度目标，奖励稀有资源
- **势力轮换活动**: 每周一个势力声望翻倍
- **赛季系统**: 每30天一个赛季，赛季排行 + 独占奖励

### 4.3 改造许可函来源明确化

**现状**: 许可函是 MOD 改造的前置条件，但来源不明确（成就/任务奖励不够稳定）。

**建议**:
- 势力商店出售对应类型的许可函
- 挑战模式高难度通关奖励
- 势力事件奖励

### 4.4 卡组保存与分享

**现状**: 玩家每次进入战斗需要重新配置卡组，无法保存多种配置。

**建议**:
- 保存 3-5 套预设卡组（按势力/关卡类型分类）
- 快速切换卡组（主界面一键切换）

---

## 五、📊 优化优先级矩阵

| # | 建议 | 影响 | 工时 | 优先级 |
|---|------|------|------|--------|
| 1.1 | 战斗热路径 preload → const | 性能+0.5-2% | 10分钟 | 🔴 |
| 1.2 | 信号泄漏修复（UI基类） | 内存稳定性 | 2小时 | 🔴 |
| 1.3 | 基础资源消耗 Sink | 经济平衡 | 3-4小时 | 🔴 |
| 2.1 | 移除冗余委托层 | 代码简洁 | 30分钟 | 🟡 |
| 2.2 | SaveableManager 基类 | 可维护性 | 2小时 | 🟡 |
| 2.3 | 技能树重置功能 | 玩家体验 | 1小时 | 🟡 |
| 2.4 | 法则环境限制放宽 | 内容利用率 | 1小时 | 🟡 |
| 4.1 | New Game+ / 噩梦模式 | 终局留存 | 4-6小时 | 🟡 |
| 4.2 | 周期性活动系统 | 长期留存 | 3-4小时 | 🟡 |
| 3.1 | Static → Instance 重构 | 架构一致 | 2小时 | 🟢 |
| 3.2 | PhaseInstrument 缓存失效 | 数据一致性 | 30分钟 | 🟢 |
| 3.3 | 高星研究点倍率扩展 | 正向反馈 | 30分钟 | 🟢 |
| 3.4 | 难度曲线平滑化 | 体验流畅 | 1小时 | 🟢 |
| 4.3 | 许可函来源明确 | 进度流畅 | 1小时 | 🟢 |
| 4.4 | 卡组预设保存 | 便利性 | 2小时 | 🟢 |

---

## 六、快速见效的"Low Hanging Fruit"

以下改动可以在 **30分钟内完成**，立即产生正面效果：

1. ✅ `attack_calculator.gd` — 2个 `var preload` 改为 `const`（10分钟）
2. ✅ `master_power_evaluator.gd` — 2个 `var preload` 改为 `const`（5分钟）
3. ✅ `blueprint_star_config.gd` — 扩展星倍率到9档（15分钟）
4. ✅ 移除 `rarity_helpers.gd` 和 `attribute_growth.gd`，调用方直接引用 `EvolutionHelpers`（15分钟）
