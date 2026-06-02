# Phase War 项目审计报告

**日期**: 2026-06-02
**范围**: 核心玩法逻辑、空指针/越界风险、Update循环性能、游戏重置状态残留、屏幕适配

---

## 一、核心玩法逻辑

### C-01 [中] BattleManager._process 内调用 end_battle 可能引发重入
- **位置**: `managers/battle/battle_manager.gd:121` → `end_battle()` → `SignalBus.battle_ended.emit()` → `GameManager._on_battle_ended()`
- **问题**: `_check_win_lose()` 在 `_process` 中每帧调用。`end_battle(true)` 内发射 `battle_ended` 信号，`GameManager._on_battle_ended` 可能在同帧触发保存、掉落、UI 弹窗等重操作。虽然 `battle_active = false` 守卫阻止二次进入，但信号链在同帧内的副作用顺序不可预测。
- **修复**: 将 `_check_win_lose` 中的 `end_battle(true)` 改为 `call_deferred("end_battle", true)`，或引入 `_pending_end_battle` 标志延迟到帧末执行。

### C-02 [低] GameManager 相位师随机选取有偏
- **位置**: `managers/game_manager.gd:89`
- **问题**: `randi() % min(3, all_masters.size())` 始终偏向前3个相位师。当 `all_masters.size() > 3` 时，后面的相位师永远不会被随机选中。
- **修复**: 改为 `randi() % all_masters.size()` 全池随机，或使用加权随机。

### C-03 [低] EnergyManager._apply_equipped_energy_cards 中 _base_start 重置为 0 后再检查
- **位置**: `managers/energy_manager.gd:67-34`
- **问题**: 第67行 `_base_start = 0.0`，若无能量卡则 _base_start 为 0。第33行有兜底 `if _base_start <= 0.0: _base_start = GC.ENERGY_START`，逻辑正确但可读性差。
- **修复**: 在 `_apply_equipped_energy_cards` 末尾加保底：`if _base_start <= 0.0: _base_start = GC.ENERGY_START`。

### C-04 [中] enemy_unit._do_attack 中 get_parent().get_parent() 链可能断裂
- **位置**: `scenes/units/enemy_unit.gd:569`
- **问题**: `get_parent().get_parent()` 无 null 守卫。若单位在战斗结束清理时被从父节点移除，此处会崩溃。
- **修复**: 改为 `var root_2d = get_parent().get_parent() if get_parent() and get_parent().get_parent() else self`。

### C-05 [低] CardResource.get_rank_progress 除零风险
- **位置**: `resources/card_resource.gd:493`
- **问题**: `float(current_p) / float(base_p) if base_p > 0 else 1.0`，此处已有守卫，但后续 `current_min` 和 `next_min` 计算依赖 `_get_rank_by_ratio` 返回值，若 base_p=0 且 current_p=0，ratio=1.0，`current_min=0, next_min=0`，导致 `(current_p - current_min) / (next_min - current_min)` 除零。
- **修复**: 在 `next_min <= current_min` 判断前加 `if base_p <= 0: return 0.0`。

---

## 二、空指针与越界风险

### N-01 [高] construct_unit.$CollisionShape2D 无 null 检查
- **位置**: `scenes/units/construct_unit.gd:171`
- **问题**: `$CollisionShape2D.disabled = false` 若节点不存在则崩溃。`setup()` 可在 `_ready()` 之前调用（外部 instantiate 后立即 setup），此时 `$CollisionShape2D` 可能未初始化。
- **修复**: 改为 `var cs = get_node_or_null("CollisionShape2D"); if cs: cs.disabled = false`。

### N-02 [高] enemy_unit.$CollisionShape2D 同样无 null 检查
- **位置**: `scenes/units/enemy_unit.gd:109`
- **问题**: 同 N-01。
- **修复**: 同上。

### N-03 [高] enemy_unit 访问 target.get("stats") 未验证 target 类型
- **位置**: `scenes/units/enemy_unit.gd:492-493, 544-545`
- **问题**: `_process_attack_timing` 和 `_do_attack` 中 `target.get("stats") as UnitStats`。若 target 已被 queue_free，`is_instance_valid(target)` 检查通过但 `get("stats")` 返回 null，后续 `target_stats.combat_kind` 崩溃。
- **修复**: 在获取 target_stats 后加 null 检查：`if target_stats == null: return`。

### N-04 [中] construct_unit._shape_points 未覆盖所有 platform_type
- **位置**: `scenes/units/construct_unit.gd:742-779`
- **问题**: match 语句缺少 platform_type 7（迫击炮）的专属分支。虽然末尾有默认方块兜底，但 type 7 与 type 2（装甲）用相同形状不合理。
- **修复**: 为 type 7 添加专属形状，或在注释中标注刻意复用。

### N-05 [中] enemy_unit._do_attack 子弹父节点链未做 null 防护
- **位置**: `scenes/units/enemy_unit.gd:569-574`
- **问题**: `get_parent().get_parent()` 无 null 检查（同 C-04）。
- **修复**: 同 C-04。

### N-06 [中] enemy_unit _attack_weapon_index 越界风险
- **位置**: `scenes/units/enemy_unit.gd:554`
- **问题**: `_attack_weapon_index % multi.size()` 若 `multi` 为空数组，模 0 会崩溃。
- **修复**: 加 `if multi.is_empty(): return` 在 554 行之前。

---

## 三、Update 循环性能问题

### P-01 [高] BattleManager._check_win_lose 每帧全量重算敌方单位数
- **位置**: `managers/battle/battle_manager.gd:335-339`
- **问题**: `get_enemy_unit_count()` 每帧调用 → `recount_enemy_units_on_field()` → 遍历所有子节点。当场上单位多时（50+），每帧 O(n) 遍历。
- **修复**: 使用 SpawnSystem 内部的计数器 + 仅在 unit_died 信号时刷新，避免每帧遍历。

### P-02 [中] enemy_unit._physics_process 无条件更新空间网格
- **位置**: `scenes/units/enemy_unit.gd:413`
- **问题**: `_update_in_spatial_grid()` 每帧调用，而 construct_unit.gd:833 有 `if velocity != Vector2.ZERO` 守卫。格子战术下敌 velocity=ZERO，但仍然每帧更新空间网格。
- **修复**: 添加 `if velocity != Vector2.ZERO: _update_in_spatial_grid()` 守卫。

### P-03 [中] construct_unit._physics_process 多项卡牌能力每帧检查
- **位置**: `scenes/units/construct_unit.gd:839-858`
- **问题**: 即使已用布尔缓存避免字符串 hash，但 `_has_regen_frame || _has_abrams_mk2 || _has_storm_rider || _has_repair_fortress` 每帧评估。当场上 20+ 我方单位时，每帧产生 80+ 次方法调用。
- **修复**: 将特殊能力检查整合到一个 `CardAbilityManager.process_unit_abilities(self, delta)` 调用中，减少跨对象调用开销。

### P-04 [低] enemy_unit._find_target fallback 全树遍历
- **位置**: `scenes/units/enemy_unit.gd:456-480`
- **问题**: 当空间网格不可用时，回退到 `get_nodes_in_group("player_units")` 全树遍历。虽有 `get_cached_nodes_in_group` 节流（0.28s），但缓存刷新时所有单位同帧命中全树遍历。
- **修复**: 在空间网格可用时跳过 fallback（已做到）。可考虑将缓存刷新分散到不同帧。

### P-05 [低] BattleManager._process 中 PerformanceMetricsManager.sample_battle_frame 每帧调用
- **位置**: `managers/battle/battle_manager.gd:122-123`
- **问题**: `has_method` 检查每帧执行。Godot 的 `has_method` 有一定开销。
- **修复**: 在 `_ready` 中缓存方法引用或使用布尔标志。

---

## 四、游戏重置与状态残留

### R-01 [高] GameManager.last_battle_reward_summary 跨战斗未清理
- **位置**: `managers/game_manager.gd:15, 317`
- **问题**: `last_battle_reward_summary` 在 `_on_battle_ended` 被赋值，但在 `return_to_prep()` 或 `start_battle` 路径中未清理。若玩家跳过结算，UI 可能显示上局数据。
- **修复**: 在 `go_to_battle()` 或 `return_to_prep()` 中加 `last_battle_reward_summary = {}`。

### R-02 [中] BattleManager._phase_master_config 战后未清理
- **位置**: `managers/battle/battle_manager.gd:38`
- **问题**: `_phase_master_config` 在 `end_battle` 中未显式清空（仅在 `start_battle` 重新赋值时覆盖）。若逻辑分支跳过赋值，可能残留旧配置。
- **修复**: 在 `end_battle` 末尾加 `_phase_master_config = {}` 和 `_is_phase_master_battle = false`。

### R-03 [中] construct_unit 信号连接累积风险
- **位置**: `scenes/units/construct_unit.gd:131`
- **问题**: `_ready` 中 `SignalBus.unit_move_command.connect(_on_unit_move_command)` 无 `is_connected` 守卫。虽然单位通常只 `_ready` 一次，但若被 ObjectPool 回收重用，会重复连接。
- **修复**: 添加 `if not SignalBus.unit_move_command.is_connected(_on_unit_move_command):` 守卫。

### R-04 [中] BattleManager._cached_nodes_by_group 战后虽清理但引用可能悬空
- **位置**: `managers/battle/battle_manager.gd:541-543`
- **问题**: `_clear_group_target_cache()` 清空字典，但缓存中的 Node 引用在 `queue_free` 后变为无效。若在清空前有回调读取缓存，会访问已释放节点。
- **修复**: 在缓存使用处（`get_cached_nodes_in_group`）对返回的数组做 `is_instance_valid` 过滤。

### R-05 [低] SaveManager._pending_backpack_ids 在 load_game 时被覆盖但不清除旧 pending
- **位置**: `managers/save_manager.gd:896`
- **问题**: `load_game` 直接覆盖 `_pending_backpack_ids = data[SK_BACKPACK_EXTRA_IDS].duplicate()`，若 load 前有 pending 卡牌（如战斗中断），这些卡会丢失。
- **修复**: 在覆盖前合并旧 pending：`_pending_backpack_ids = (old_pending + data[...]).unique()`。

---

## 五、屏幕适配与操作影响

### S-01 [高] 战场边界坐标硬编码 1280x720
- **位置**:
  - `scenes/units/construct_unit.gd:22-27` (BATTLE_MIN_X=40, BATTLE_MAX_X=1240, etc.)
  - `scenes/units/enemy_unit.gd:18-21` (同上)
  - `managers/battle/battle_manager.gd:572` (空间网格 setup 硬编码 40-1240, 280-440)
- **问题**: 所有战场边界坐标硬编码，假设 1280x720 视口。若屏幕比例变化（16:10、4:3、手机竖屏），战斗区域不会自适应。
- **修复**: 从 Battlefield 节点动态获取边界，或在 BattleManager.start_battle 中根据视口尺寸计算。

### S-02 [高] project.godot 缺少 stretch/aspect 配置
- **位置**: `project.godot:50-51`
- **问题**: 只设置了 `window/stretch/mode="canvas_items"`，未设置 `window/stretch/aspect`。Godot 4.5 默认值为 "fit"（保持比例缩放），这本身没问题，但缺少显式声明意味着非 16:9 屏幕上可能出现黑边或裁切。
- **修复**: 显式添加 `window/stretch/aspect="keep"` 或 `"expand"`，根据设计意图选择。

### S-03 [中] construct_unit.PLAYER_MAX_ADVANCE_X 硬编码 1160
- **位置**: `scenes/units/construct_unit.gd:27`
- **问题**: 我方前进上限 1160 假设 1280 宽度。窄屏上可能超出可视区域。
- **修复**: 改为基于 BATTLE_MAX_X 的比例计算：`PLAYER_MAX_ADVANCE_X = BATTLE_MAX_X - 80`。

### S-04 [低] UI 面板锚点未全面审查
- **问题**: 未逐一审查 65 个 UI 面板的 anchor/margin 设置。硬编码的 margin 值在不同分辨率下可能错位。
- **修复**: 使用 Godot 编辑器的 Layout 菜单统一设置为 anchor-based 布局；或对关键面板做 1280x720 和 1920x1080 双分辨率测试。

---

## 修复优先级汇总

| 优先级 | 编号 | 问题 | 影响面 |
|--------|------|------|--------|
| P0 紧急 | N-01 | construct_unit $CollisionShape2D 崩溃 | 每次部署 |
| P0 紧急 | N-02 | enemy_unit $CollisionShape2D 崩溃 | 每次敌方生成 |
| P0 紧急 | N-03 | enemy_unit target.get("stats") 空指针 | 攻击时崩溃 |
| P0 紧急 | C-04 | enemy_unit get_parent 链断裂 | 子弹发射崩溃 |
| P1 高   | N-06 | _attack_weapon_index 模0越界 | 多武器敌人崩溃 |
| P1 高   | P-01 | _check_win_lose 每帧全量重算 | 战斗帧率 |
| P1 高   | R-01 | reward_summary 跨局残留 | 结算数据错乱 |
| P1 高   | S-01 | 战场边界硬编码 | 非标分辨率 |
| P1 高   | S-02 | 缺少 stretch/aspect | 适配不完整 |
| P2 中   | C-01 | end_battle 重入风险 | 信号链顺序 |
| P2 中   | R-02 | phase_master_config 残留 | 下局配置错 |
| P2 中   | R-03 | 信号连接累积 | 对象池复用 |
| P2 中   | R-04 | 缓存悬空引用 | 战斗结束帧 |
| P2 中   | P-02 | enemy 空间网格每帧更新 | 性能浪费 |
| P2 中   | P-03 | 卡牌能力每帧多方法调用 | 性能 |
| P2 中   | S-03 | MAX_ADVANCE_X 硬编码 | 窄屏越界 |
| P3 低   | C-02 | 相位师选取偏差 | 游戏平衡 |
| P3 低   | C-03 | energy _base_start 可读性 | 代码质量 |
| P3 低   | C-05 | rank_progress 除零 | 边界情况 |
| P3 低   | N-04 | shape 缺少 type 7 | 视觉一致性 |
| P3 低   | P-04 | fallback 全树遍历 | 极端情况 |
| P3 低   | P-05 | has_method 每帧调用 | 微优化 |
| P3 低   | R-05 | pending 覆盖丢失 | 读档边缘 |
| P3 低   | S-04 | UI 面板锚点未审查 | 长期适配 |
