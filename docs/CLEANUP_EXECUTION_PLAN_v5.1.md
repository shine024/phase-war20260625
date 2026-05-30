# 🧹 《相位战争》v5.1 清理与修复执行计划

> **生成日期**：2026-05-30
> **基于**：全量代码审计（大文件扫描 + 废弃代码搜索 + 数据一致性交叉验证）
> **前提**：v5.0 后续执行计划全部完成（POST_AUDIT_EXECUTION_PLAN 已清零）
> **目标**：消除技术债务、修复数据不一致、提升代码质量

---

## 一、审计问题总览

| 类别 | 问题数 | 🔴严重 | 🟠高 | 🟡中 |
|------|--------|--------|-----|-----|
| 大文件未拆分 | 18 | 4 | 4 | 10 |
| 废弃代码未清理 | 7 | 2 | 3 | 2 |
| 数据不一致 | 6 | 1 | 3 | 2 |
| 存档隐患 | 3 | 1 | 1 | 1 |
| 代码质量 | 4 | 2 | 1 | 1 |
| **合计** | **38** | **10** | **12** | **16** |

---

## 二、🔴 P0：必须立即修复（安全/崩溃风险）

### P0-1：硬编码绝对路径（3个文件，约0.5h）

**问题**：3个文件中 `_agent_log()` 硬编码了 `F:/godot fair duel/phase-war/debug-585b52.log`，其他用户运行必静默失败。

**改动文件**：

| 文件 | 行号 | 改动 |
|------|------|------|
| `managers/save_manager.gd` | L105-106 | 删除 `_agent_log` 函数体（或改为 `push_warning`） |
| `managers/active_law_effects.gd` | L16 | 同上 |
| `managers/energy_manager.gd` | L14 | 同上 |
| `managers/phase_instrument_manager.gd` | L57-58 | 同上 |
| `managers/phase_law_manager.gd` | L49 | 同上（注意此文件参数顺序与其他4个不一致） |

**统一方案**：
```gdscript
# 方案A（推荐）：全部替换为 Godot 内置日志
func _agent_log(hypothesis_id: String, message: String, data: Dictionary = {}) -> void:
    push_warning("[agent] %s: %s" % [hypothesis_id, message])

# 方案B：提取为共享工具函数
# 在 scripts/systems/debug_logger.gd 中统一实现
```

---

### P0-2：`star_level` 仍在被写入（1处，约0.5h）

**问题**：`card_resource.gd` L140 已标记 `star_level` 为 `@deprecated`，但 `blueprint_manager.gd` L610 仍在**写入**它：
```gdscript
out_card.star_level = star  # ← 违反 @deprecated 声明
```

**改动文件**：

| 文件 | 行号 | 改动 |
|------|------|------|
| `managers/blueprint_manager.gd` | L610 | 删除 `out_card.star_level = star` 行 |

**注意**：需确认是否有读取方依赖此字段。搜索结果显示无活跃读取（仅在 `clone()` 中被动复制），可安全删除写入。

---

## 三、🟠 P1：尽快修复（数据一致性 / 性能）

### P1-1：`enhance_level` 初始化不一致（约1h）

**问题**：`CardResource.enhance_level` 默认值 = 0，但 `CardEnhancementManager` 初始化等级 = 1，默认返回 = 1。语义混乱。

| 位置 | 值 | 说明 |
|------|---|------|
| `card_resource.gd` L111 | `var enhance_level: int = 0` | 数据模型 |
| `default_cards.gd` `_unit()` | `c.enhance_level = 0` | 数据层 |
| `card_enhancement_manager.gd` L60 | `card_enhancement_level[card_id] = 1` | 运行时管理器 |
| `card_enhancement_manager.gd` L178 | `return .get(card_id, 1)` | 默认返回 1 |

**统一方案**：管理器层表示"已强化到第N级"（1=首次强化），CardResource 层表示"额外加成等级"（0=未强化）。两者语义不同但合理，需要**添加注释明确说明**。

**改动文件**：

| 文件 | 行号 | 改动 |
|------|------|------|
| `managers/card_enhancement_manager.gd` | L18-22 | 增加注释说明 0 vs 1 的语义差异 |
| `managers/card_enhancement_manager.gd` | L58-60 | 增加注释说明初始化为1的含义 |
| `resources/card_resource.gd` | L110-111 | 增加注释说明运行时由 CardEnhancementManager 管理 |

---

### P1-2：`cold_rpg` 数据放在二战区块（约0.5h）

**问题**：`cold_rpg`（era=2, 冷战）出现在二战单位区块的注释下。

**改动文件**：

| 文件 | 行号 | 改动 |
|------|------|------|
| `data/default_cards.gd` | L57 | 将 `cold_rpg` 行从二战区块移到冷战区块（`cold_ak47` 之前） |

**具体操作**：
1. 删除 L57 的 `cold_rpg` 行
2. 在 `# ==================== 冷战单位（20个）====================` 注释后、`cold_ak47` 之前插入

---

### P1-3：`omega_platform` 与 `fut_colossus` 属性完全相同（约1h）

**问题**：两个不同 ID 的单位拥有完全相同属性（power=1590, hp=2000, 全部攻防数值相同）。

**方案**：由用户确认是保留还是删除。

- **如果保留**：在 `default_cards.gd` 的 `omega_platform` 行增加注释说明设计意图（如"全装型机动舱与巨神机甲数据相同，作为替代皮肤/早期单位"）
- **如果删除**：删除 `default_cards.gd` L137-138 的 `omega_platform` 行，并在存档迁移中处理已有存档引用

---

### P1-4：调试 `print()` 大量残留（~117处，约2h）

**问题**：`scenes/` 目录中约 117 处 `print()` 语句残留，部分在高频路径上。

**重点清理文件**（print >10处）：

| 文件 | print数量 | 清理策略 |
|------|----------|---------|
| `scenes/ui/global_save_button.gd` | 25 | 全部删除或改为 DEBUG guard |
| `scenes/game_launcher.gd` | 20 | 保留启动流程关键日志，删除其余 |
| `scenes/ui/custom_drag_card_item.gd` | 14 | 删除拖拽调试日志 |
| `scenes/world_map.gd` | 14 | 保留关卡切换日志，删除坐标打印 |
| `scenes/ui/backpack_card_item.gd` | 11 | 删除状态打印 |
| `scenes/main.gd` | 10 | 保留关键流程日志，删除调试日志 |
| `scripts/master_power_evaluator.gd` | 20 | 改为返回 String 而非直接 print |
| `scripts/save_utils.gd` | 7 | 保留（存档工具日志有诊断价值） |

**清理模板**：
```gdscript
# 删除前
print("[BackpackItem] card_id=%s state=%s" % [card_id, state])

# 删除后（如需保留调试能力）
# if OS.is_debug_build():
#     print("[BackpackItem] card_id=%s state=%s" % [card_id, state])
```

---

### P1-5：存档键名常量化（约1h）

**问题**：`save_manager.gd` 中所有管理器数据键名为硬编码字符串，拼写错误风险高。

**改动文件**：

| 文件 | 行号 | 改动 |
|------|------|------|
| `managers/save_manager.gd` | 文件顶部 | 新增存档键名常量块 |

```gdscript
## 存档数据键名常量（避免拼写错误）
const SAVE_KEY_BLUEPRINT: String = "blueprint"
const SAVE_KEY_BASIC_RESOURCES: String = "basic_resources"
const SAVE_KEY_PHASE_LAW: String = "phase_law"
const SAVE_KEY_QUEST: String = "quest"
const SAVE_KEY_FACTION_SYSTEM: String = "faction_system"
const SAVE_KEY_AFFIX_DATA: String = "affix_data"
const SAVE_KEY_LEVEL_PROGRESS: String = "level_progress"
const SAVE_KEY_DROP_MANAGER: String = "drop_manager"
const SAVE_KEY_GAME: String = "game"
const SAVE_KEY_CURRENT_LEVEL: String = "current_level"
const SAVE_KEY_PHASE_SLOTS: String = "phase_slots"
const SAVE_KEY_PHASE_SLOTS_ORDER: String = "phase_slots_order"
const SAVE_KEY_PHASE_INSTRUMENT: String = "phase_instrument"
```

然后将 `save_manager.gd` 中所有硬编码键名替换为常量引用。

---

## 四、🟡 P2：技术债务（中长期）

### P2-1：大文件拆分（约3-5天）

#### 优先级1：数据文件（纯定义，低风险）

| 文件 | 行数 | 拆分方案 |
|------|------|---------|
| `data/phase_master_roster.gd` | 4085 | 按时代拆分为 `phase_master_roster_ww1.gd` ~ `phase_master_roster_future.gd`，主文件做聚合 |
| `data/enemy_phase_masters.gd` | 2195 | 按时代拆分为 5 个文件 |
| `data/enemy_phase_equipment.gd` | 1501 | 按装备槽位拆分为 `weapon_equipment.gd` / `armor_equipment.gd` / `special_equipment.gd` |
| `data/enemy_archetypes.gd` | 1149 | 按时代拆分 |
| `data/achievement_definitions_extended.gd` | 904 | 按类别拆分（战斗/收集/养成/特殊） |

#### 优先级2：逻辑文件（需保持API兼容）

| 文件 | 行数 | 拆分方案 |
|------|------|---------|
| `scenes/units/construct_unit.gd` | 1548 | 提取：`construct_unit_ai.gd`（AI/攻击逻辑 ~400行）、`construct_unit_deploy.gd`（部署幽灵 ~200行） |
| `scenes/ui/backpack_card_item.gd` | 1505 | 提取：`backpack_card_drag.gd`（拖拽相关 ~300行）、`backpack_card_actions.gd`（操作按钮 ~200行） |
| `scenes/ui/leaderboard_panel.gd` | 1209 | 提取：`leaderboard_data_provider.gd`（数据获取/排序 ~300行） |
| `managers/save_manager.gd` | 1191 | 提取：`save_migration.gd`（迁移逻辑 ~300行）、`save_constants.gd`（常量定义） |
| `managers/phase_instrument_manager.gd` | 1121 | 已有 facade，可进一步提取装备/卸下逻辑 |
| `scenes/main.gd` | 966 | 提取：`main_battle_setup.gd`（战前准备 ~200行）、`main_reward.gd`（战后结算 ~150行） |
| `scenes/effects/battle_effects_system.gd` | 928 | 提取：`battle_vfx_manager.gd`（视觉特效）、`battle_audio_manager.gd`（音效） |

#### 优先级3：UI面板（中等风险）

| 文件 | 行数 | 拆分方案 |
|------|------|---------|
| `scenes/ui/backpack_panel.gd` | 927 | 提取筛选/排序逻辑 |
| `scenes/ui/bottom_instrument_bar.gd` | 907 | 提取槽位拖放处理 |
| `scenes/ui/card_enhancement_panel.gd` | 802 | 提取强化动画/确认弹窗 |
| `scenes/ui/leaderboard/leaderboard_panel.gd` | 847 | 与主 leaderboard_panel 合并或统一 |
| `managers/blueprint_manager.gd` | 865 | 进一步提取 facade：稀有度查询、属性成长计算 |

---

### P2-2：`platform_card_id` 迁移计划（约2天）

**问题**：`platform_card_id` 标记为 `@deprecated` 但仍有 107 处活跃引用，是事实上的核心身份字段。

**建议**：暂时保留，不做迁移。理由：
1. 重命名影响面太大（107处），收益仅是代码整洁度
2. 当前无功能 bug
3. 新代码应使用 `card_id`，旧代码逐步自然替换

**行动**：在 `card_resource.gd` 的 `@deprecated` 注释中增加说明：
```gdscript
## @deprecated v5.0: 新代码使用 card_id；此字段保留用于存档兼容和旧系统桥接
## 迁移计划：随新功能开发逐步替换，不做批量重命名
```

---

### P2-3：`_agent_log` 去重（约0.5h）

**问题**：5个文件各自定义 `_agent_log`，且 `phase_law_manager.gd` 参数顺序不同。

**方案**：P0-1 已删除硬编码路径。如果保留调试日志功能：

1. 在 `scripts/systems/debug_logger.gd` 新建统一工具：
```gdscript
class_name DebugLogger

static func agent_log(hypothesis_id: String, message: String, data: Dictionary = {}) -> void:
    if OS.is_debug_build():
        var timestamp: String = Time.get_datetime_string_from_system()
        print("[%s] [agent:%s] %s | data=%s" % [timestamp, hypothesis_id, message, str(data)])
```

2. 5个文件中的 `_agent_log` 改为调用 `DebugLogger.agent_log()`

---

### P2-4：TODO 闭环跟踪（约1h）

| TODO | 文件 | 行号 | 行动 |
|------|------|------|------|
| BlueprintManager 待重命名为 CardDataManager | `blueprint_manager.gd` | L4 | 记录到 tech-debt-register.md，不做重命名（影响面太大） |
| affix_panel 引用方迁移后删除 DEFAULT_MOD_OPTIONS | `blueprint_manager.gd` | L36 | 检查引用方是否已迁移，是则删除 |
| 步兵/载具区分 | `active_law_effects.gd` | L170 | 记录到设计文档，作为 v5.2 功能需求 |
| 空测试占位 | `performance_benchmark.gd` | 多处 | 补充实际测试或删除空占位 |

---

## 五、执行顺序与依赖关系

```
P0-1 (硬编码路径) ─────────→ 立即
P0-2 (star_level写入) ─────→ 立即（可与P0-1并行）
    ↓
P1-1 (enhance_level注释) ─→ P0完成后
P1-2 (cold_rpg位置) ──────→ 可与P1-1并行
P1-3 (omega_platform确认) ─→ 需用户决策
P1-4 (print清理) ─────────→ 可独立
P1-5 (存档常量化) ────────→ 可独立
    ↓
P2-1 (大文件拆分) ─────────→ P1全部完成后
P2-2 (platform_card_id) ───→ 长期跟踪
P2-3 (_agent_log去重) ─────→ P0-1完成后
P2-4 (TODO闭环) ──────────→ 持续
```

---

## 六、工作量估算

| 优先级 | 任务数 | 预估工时 | 风险 |
|--------|--------|---------|------|
| P0（必须立即） | 2 | 1h | 🟢 低 |
| P1（尽快） | 5 | 5h | 🟢 低 |
| P2-1 数据文件拆分 | 5 | 8h | 🟢 低 |
| P2-1 逻辑文件拆分 | 8 | 16h | 🟡 中 |
| P2-1 UI文件拆分 | 5 | 8h | 🟡 中 |
| P2-2~P2-4 | 3 | 3.5h | 🟢 低 |
| **合计** | **28** | **~41.5h** | — |

---

## 七、里程碑

| 里程碑 | 完成标志 | 预计日期 |
|--------|---------|---------|
| **M1**：安全清零 | 硬编码路径删除、deprecated 写入停止 | 2026-06-01 |
| **M2**：数据一致 | enhance_level 注释统一、cold_rpg 归位、omega_platform 确认 | 2026-06-03 |
| **M3**：代码整洁 | 117处 print 清理、存档键名常量化 | 2026-06-05 |
| **M4**：数据文件瘦身 | 5个数据大文件拆分完成 | 2026-06-12 |
| **M5**：逻辑文件瘦身 | 8个逻辑大文件拆分完成，API 兼容 | 2026-06-20 |
| **M6**：UI瘦身 + 债务闭环 | UI大文件拆分、TODO闭环 | 2026-06-27 |

---

> **文档版本**：v1.0
> **生成工具**：DeepV Code Agent
> **状态**：待执行
