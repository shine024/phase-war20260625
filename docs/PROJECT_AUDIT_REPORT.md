# 项目全面检查报告

> 日期：2026-05-30
> 范围：全部 .gd 源文件（data/, managers/, resources/, scripts/, scenes/）
> 重点：引用完整性、存档一致性、信号连接、势力系统集成

---

## 🔴 严重问题（3个，会导致运行时错误）

### BUG-1: FactionSystemManager 从未监听 battle_ended 信号

**文件**: `managers/faction_system_manager.gd`
**级别**: 🔴 严重

**现象**: `FactionSystemManager.on_battle_ended_for_events()` 方法存在但从未被调用。该管理器没有连接 `SignalBus.battle_ended` 信号，也没有在任何地方被外部调用此方法。

**影响**: 势力战争事件系统完全不会触发——`FactionEventManager.on_battle_ended()` 永远不会执行，`battle_count_since_last` 永远不会递增，事件永远不会生成。

**修复**:
```gdscript
# 在 faction_system_manager.gd 的 _ready() 中添加：
func _ready() -> void:
    if Engine.is_editor_hint():
        return
    level_info = LevelInformation.new()
    _init_faction_data()
    # ↓ 新增：监听战斗结束信号
    if SignalBus and not SignalBus.battle_ended.is_connected(_on_battle_ended):
        SignalBus.battle_ended.connect(_on_battle_ended)

# 新增信号处理函数：
func _on_battle_ended(player_won: bool) -> void:
    on_battle_ended_for_events()
```

---

### BUG-2: FactionEventManager 调用不存在的方法 `get_completed_count()`

**文件**: `managers/faction/faction_event_manager.gd` L52, L104
**级别**: 🔴 严重

**现象**:
```gdscript
L49: var level_info: Node = get_node_or_null("/root/LevelInformation")
L52: if level_info.get_completed_count() < int(conditions["min_level"]):
```

`LevelInformation` 是 `data/level_information.gd` 中定义的 `class_name`，但该类没有 `get_completed_count()` 方法。搜索整个项目也没有找到此方法的定义。

**影响**: 当事件模板包含 `min_level` 条件时，`_check_conditions()` 会崩溃（`call to non-existent method`）。6个事件模板中 `resource`（min_level=10）和 `expansion`（min_level=20）会受影响。

**修复**: 改用 `LevelProgressManager`（autoload）查询已通关关卡数：
```gdscript
func _check_conditions(template: Dictionary) -> bool:
    var conditions: Dictionary = template.get("conditions", {})
    if conditions.has("min_level"):
        var lpm: Node = get_node_or_null("/root/LevelProgressManager")
        if lpm == null or not lpm.has_method("get_cleared_levels"):
            return false
        var cleared: Array = lpm.get_cleared_levels()
        if cleared.size() < int(conditions["min_level"]):
            return false
    # ... 其余不变
```

---

### BUG-3: FactionEventManager 引用 `/root/LevelInformation` 但该节点不存在

**文件**: `managers/faction/faction_event_manager.gd` L49, L102
**级别**: 🔴 严重

**现象**: `get_node_or_null("/root/LevelInformation")` 永远返回 `null`，因为项目 autoload 中没有 `LevelInformation`。在 `FactionSystemManager` 中它是通过 `preload + .new()` 作为内部实例使用的，不是 autoload。

**影响**: `_check_conditions()` 中涉及 `min_level` 的检查会直接跳过（返回 false）；`_instantiate_event()` 中 `level_num` 始终为 1。

**修复**: 同 BUG-2，改用 `LevelProgressManager` autoload。

---

## 🟡 中等问题（4个，功能异常但不崩溃）

### BUG-4: SynthesisManager 调用不存在的方法 `get_blueprint_faction_branch()`

**文件**: `managers/synthesis/synthesis_manager.gd` L54-55
**级别**: 🟡 中等

**现象**:
```gdscript
if bpm != null and bpm.has_method("get_blueprint_faction_branch"):
    var faction: String = bpm.get_blueprint_faction_branch(card_id)
```

`BlueprintManager` 中没有 `get_blueprint_faction_branch()` 方法。搜索整个项目确认该方法不存在。

**影响**: 合成台无法正确识别势力变体卡的势力归属，`_get_faction_id()` 总是返回空字符串，导致合成台对于非专属卡的势力变体无法工作。

**修复**: 在 `BlueprintManager` 中添加该方法，或者改用 `FactionCardGenerator` 提供的解析方法。

---

### BUG-5: SynthesisManager 调用不存在的方法 `get_faction_variant_base_id()`

**文件**: `managers/synthesis/synthesis_manager.gd` L42-43
**级别**: 🟡 中等

**现象**: 同 BUG-4，`FactionSystemManager` 没有 `get_faction_variant_base_id()` 方法。

**影响**: 合成台无法正确识别势力变体卡的基础卡ID。

**修复**: 在 `FactionSystemManager` 中添加，或改用 `card.base_card_id` 字段（从势力变体生成时已设置）。

---

### BUG-6: FactionSystemManager 信号未添加到 SignalBus

**文件**: `managers/faction_system_manager.gd` L115-120
**级别**: 🟡 中等

**现象**: `FactionSystemManager` 定义了6个自定义信号：
- `faction_reputation_changed`
- `faction_level_up`
- `faction_store_updated`
- `active_faction_changed`
- `faction_skill_unlocked`
- `faction_event_generated`

但这些信号**不在 SignalBus 中**，UI 层无法通过 `SignalBus.xxx.connect()` 监听。

**影响**: 势力相关的 UI 更新无法通过信号驱动，需要 UI 主动轮询或直接引用 FactionSystemManager。

**修复建议**: 两种方案：
1. 将势力信号添加到 `signal_bus.gd`（统一风格）
2. UI 直接 connect 到 `/root/FactionSystemManager`（更合理，因为势力是独立子系统）

---

### BUG-7: BlueprintManager.can_manufacture() 对非专属卡的逻辑路径

**文件**: `managers/blueprint_manager.gd` L595-600
**级别**: 🟡 中等

**现象**:
```gdscript
func can_manufacture(card_id: String) -> bool:
    var lookup_id: String = _normalize_blueprint_id(card_id)
    if not is_blueprint_unlocked(lookup_id):
        return false
    if _is_exclusive_card_available(lookup_id):
        return true
    return false
```

当 `is_blueprint_unlocked()` 为 `true` 但 `_is_exclusive_card_available()` 返回 `false` 时，非专属卡也会返回 `false`。但实际上 `_is_exclusive_card_available()` 对非专属卡返回 `true`（设计意图是"可用"），所以碰巧没有问题。逻辑可读性极差。

**影响**: 目前功能正确但逻辑容易误导未来开发者。

**修复**: 见上次审计报告中的建议。

---

## 🟢 轻微问题（5个，不影响功能）

### BUG-8: SynthesisRecipes.parse_hybrid_id() 字符串解析脆弱

**文件**: `data/synthesis_recipes.gd` L75-96
**级别**: 🟢 轻微

**现象**: 使用字符串匹配解析 hybrid_id（如 `hybrid_ww2_tiger_iron_wall_corp_nova_arms`），但 `base_card_id` 本身包含下划线（如 `ww2_tiger`），容易产生歧义匹配。

**影响**: 当 `base_card_id` 中包含与势力 ID 相同的子串时，解析会返回错误结果。

**修复**: 使用双下划线分隔符，或在生成时将 base_card_id 编码。

---

### BUG-9: battle_spawn_system.gd 缓存 key 格式不一致

**文件**: `managers/battle/battle_spawn_system.gd` L734-738
**级别**: 🟢 轻微

**现象**: 已在上次审计中提到。缓存 key 现在包含 `active_faction_cache_key`，格式正确。✅ 已修复。

---

### BUG-10: FactionCardGenerator._variant_cache 未使用

**文件**: `managers/faction/faction_card_generator.gd`
**级别**: 🟢 轻微

**现象**: 声明了实例缓存但 `generate_faction_variant()` 是 `static func`，无法访问。缓存无效。

**影响**: 每次部署都会 clone 卡牌，有轻微性能开销。

**修复**: 改为 `static var` 或移除。

---

### BUG-11: 存档中 synthesis_state 不在 SaveConstants 中

**文件**: `managers/save_manager.gd` + `scripts/systems/save_constants.gd`
**级别**: 🟢 轻微

**现象**: `FactionSystemManager.save_state()` 保存了 `synthesis_state`，`SaveConstants` 中没有对应的 `SK_SYNTHESIS` 常量。这不是 bug（SaveManager 按 key 读取而非常量名），但不符合编码规范。

**修复**: 在 `save_constants.gd` 中添加 `const SK_SYNTHESIS: String = "synthesis_state"`。

---

### BUG-12: SignalBus 中无 synthesis 相关信号

**文件**: `scripts/signal_bus.gd`
**级别**: 🟢 轻微

**现象**: `SynthesisManager` 定义了 `synthesis_completed` 和 `synthesis_failed` 信号，但未添加到 SignalBus。UI 层需要直接引用 SynthesisManager 实例。

**影响**: 不影响功能（可通过 `FactionSystemManager.get_synthesis_manager()` 获取实例），但风格不统一。

---

## 📊 检查统计

| 类别 | 🔴 严重 | 🟡 中等 | 🟢 轻微 | 合计 |
|------|---------|---------|---------|------|
| 势力事件系统 | 3 (BUG-1,2,3) | 0 | 0 | 3 |
| 合成系统 | 0 | 2 (BUG-4,5) | 2 (BUG-8,12) | 4 |
| 信号系统 | 0 | 1 (BUG-6) | 0 | 1 |
| BlueprintManager | 0 | 1 (BUG-7) | 0 | 1 |
| 编码规范 | 0 | 0 | 2 (BUG-10,11) | 2 |
| **合计** | **3** | **4** | **5** | **12** |

## ✅ 已验证正常的部分

| 检查项 | 状态 |
|--------|------|
| preload 路径（排除 addons） | ✅ 全部有效 |
| class_name 声明与使用 | ✅ 全部匹配 |
| SaveConstants keys vs SaveManager loads | ✅ 全部对应 |
| save_state/load_state 向后兼容 | ✅ 全部使用 .get() |
| battle_spawn_system 部署管线 | ✅ 势力注入正确 |
| default_cards 14张专属卡集成 | ✅ create_all() 末尾追加 |
| CardResource 新字段 + clone() | ✅ 正确复制 |
| FactionSkillManager 分支互斥 | ✅ 正确检查 |
| 存档 faction_skill_states | ✅ save/load 完整 |
| 存档 faction_event_state | ✅ save/load 完整 |
| 存档 synthesis_state | ✅ save/load 完整 |

---

## 🔧 修复优先级建议

### 立即修复（阻塞性）
1. **BUG-1**: FactionSystemManager 连接 battle_ended 信号
2. **BUG-2/3**: FactionEventManager 的 LevelInformation 引用改为 LevelProgressManager

### 短期修复（功能缺失）
3. **BUG-4/5**: 为 BlueprintManager / FactionSystemManager 添加合成所需方法
4. **BUG-6**: 统一势力信号连接方式

### 后续优化
5. BUG-7~12: 代码质量和规范改进
