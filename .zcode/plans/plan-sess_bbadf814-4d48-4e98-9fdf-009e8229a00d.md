## 修复：新游戏开局 ww1_ft17 重复实例（相位仪#1 + 背包#1）

### 根因回顾
`start_new_game()` 中两个 starter 函数各自独立 `create_instance("ww1_ft17")`，中间 `ir.clear_all()` 重置计数器导致都分配到 `#1`：
1. PIM 被 reset（`load_state({})`）→ `_equip_starter_cards_for_new_game()` → create `#1` 装绿槽
2. `ir.clear_all()` 计数器归零（绿槽那张脱钩成孤儿）
3. `_enqueue_starter_backpack_cards()` → create `#1` 入背包

### 修复方向（用户确认："只入背包"）
初始卡**只创建 1 张入背包**，相位仪绿槽开局为空，玩家手动拖到相位仪装备。

### 改动点（2 个文件）

**1. `managers/phase_instrument_manager.gd`**

- **`load_state()` L1071-1075 else 分支**：删除 `_equip_starter_cards_for_new_game()` 调用。新游戏（`load_state({})`）时绿槽保持空（由 `_rebuild_slots` 建空槽），不再自动装备。
- **`_equip_starter_cards_for_new_game()` L1002-1023**：函数体改为 no-op（仅保留注释说明），移除 `ir.create_instance("ww1_ft17")` 创建逻辑。

**2. `managers/save_manager.gd` `start_new_game()`**

- **`ir.clear_all()` L1083-1085 提前到 CRITICAL manager reset（L1062）之前**。防御性调整：确保实例表先于任何 manager reset 干净。本方案下 PIM 不再建实例，此调整是双保险。

### 不动的部分
- `_enqueue_starter_backpack_cards()`（save_manager.gd:826）保持不变——修复后**唯一**的初始卡创建点，创建 `ww1_ft17#1` 入背包。
- `clear_slots_for_new_game()`（PIM:985 死代码）保留不动。
- 正常读档路径不受影响（`load_state(real_data)` 走 `slot_card_ids` 分支）。

### 行为后果（需知悉）
修复后新游戏开局：背包 1 张 `ww1_ft17#1`，相位仪绿槽为空。**玩家第一次进战斗前需手动把卡从背包拖到相位仪绿槽**，否则无单位可部署。

### 验证
- Godot `--check-only` 语法通过
- 逻辑核对：start_new_game 后 InstanceRegistry 仅 1 个 `ww1_ft17#1`，存档中 `backpack_extra_ids=["ww1_ft17#1"]`、`slot_card_ids` 绿槽为空字符串