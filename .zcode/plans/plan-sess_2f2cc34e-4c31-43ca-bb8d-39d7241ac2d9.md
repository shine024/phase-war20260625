# Phase War 性能优化方案（P0+P1+P2 全套）

## 目标
消除"有时会卡"的两个偶发卡顿根因（P0）+ 减轻启动期同步负担（P1）+ 清理轻量抖动源（P2）。全部向后兼容，游戏行为零变化。

## 背景（已通过源码核实）

**偶发卡顿根因**：
1. `module_effect_handler.gd:659 _find_nearby_allies` 全组遍历——`_apply_command_aura`/`_apply_fort_shelter_aura` 每帧每单位调，绕过 spatial_grid（已有 query_enemies 但无同阵营查询）。指挥车/堡垒类上场就掉帧。
2. `phase_instrument_abilities.gd:422 _apply_nano_swarm_tick` 每帧全 children 遍历 + 每单位 `take_damage` → 每单位触发 6 个 `unit_damaged` 订阅者。nano_swarm 激活期间持续 30 秒掉帧。

**启动期负担**：
3. `object_pool.gd:45 _preload_objects()` 在 `_init()` 直接实例化 90 个节点（注释明写"战前不预创建"但代码矛盾）。
4. `modification_registry.gd:31 _ready` 启动即 `register_all()` 注册 154 个改造，但所有查询入口已有 `_ensure_initialized()` 自愈。
5. `drop_manager.gd:23 _ready` 启动即 `DropTables.new()` 建 5 时代掉落表，战斗外零调用。
6. `audio_manager.gd:65-70` 启动即建 32 个 AudioStreamPlayer。
7. 7 个 JSON 文件用 `static var X = _load_json(...)` 急切加载（同步文件 I/O），触达 preload 链即解析。

**轻量抖动**：
8. `cast_effect.gd:9` 每帧 `queue_redraw()` 寿命 1 秒。
9. `performance_metrics_manager.gd:59` 写盘 4 秒一次，可降频。

---

## P0-1：spatial_grid 加 query_allies + _find_nearby_allies 复用

**改动文件 2 个：**

**`scripts/spatial_grid.gd`**（在 `query_enemies` 后 L132 附近新增）
镜像 `query_enemies`（L107-132），唯一区别阵营判定 `!=` → `==`，返回同阵营单位。

**`scripts/battle/module_effect_handler.gd:659-681`** `_find_nearby_allies` 改用 spatial_grid（仿 `_find_nearby_enemies:343-358` 模式）：优先 `bm.spatial_grid.query_allies(pos, radius, is_player_center)`，spatial_grid 不可用时保留原全组遍历兜底。

**收益**：消除指挥光环/堡垒庇护/亡语治疗的 O(N) 全组遍历，改 spatial_grid bounding-box 查询（只扫覆盖格）。

---

## P0-2：nano_swarm 节流到 0.25s + 累加伤害

**改动文件 1 个：`managers/battle/phase_instrument_abilities.gd`**

新增模块级 `_nano_tick_acc` 累加器 + `NANO_TICK_INTERVAL = 0.25` 常量。`_apply_nano_swarm_tick`（L422-447）改为：累加 delta，未满 0.25s 跳过本帧；满 0.25s 消费一个 tick，按 `hp_pct × 0.25` 一次性结算伤害（数值等价）。nano_swarm 结束时（`_nano_remaining` 归零分支）和 `stop()`/`reset` 时清理累加器。

**收益**：take_damage 调用频率从每帧×目标数降到每 0.25s×目标数（**4 倍降频**），`unit_damaged` 信号 emit 同降 4 倍，6 个订阅者回调同降。伤害数值完全等价。

---

## P1-1：ObjectPool 去掉 _init 预实例化

**改动文件 1 个：`managers/object_pool.gd`**

`ObjectPool._init`（L33-51）删 `_preload_objects()` 调用（L45）。`get_object`（L69）开头加 `_ensure_prewarm()`：首次调用时批量建 `min(pool_size, 20)` 个（小批量预热平滑首战尖峰），用 `_prewarmed: bool` 标志守卫。保留 `auto_expand` 到 `max_size` 的逻辑不变。

**收益**：启动减 90 个节点实例化（60 子弹 + 30 伤害数字）。首战首次取对象时小批量预热。

---

## P1-2：ModificationRegistry 删 _ready 的 register_all()

**改动文件 1 个：`scripts/systems/modification_registry.gd`**

`_ready`（L31-33）删 `register_all()` 调用。所有查询入口（`get_data:80`/`get_for_unit_type:98`/`get_mods_for_card:122` 等）首行已有 `_ensure_initialized()`（L672-674：`if not _initialized: register_all()`），首次查询自动触发注册。

**收益**：启动减 154 条改造注册。开销转移到首次战斗构建 unit_stats 时（玩家已进入战斗界面，可接受）。

---

## P1-3：DropManager 走 ManagerLazyLoader

**改动文件 ~12 个：**

- **`project.godot:28`**：注释掉 DropManager autoload 行（仿 L37 `#IntelDiscoveryManager` 格式）
- **`managers/manager_lazy_loader.gd`**：L31 `CORE_MANAGERS` 移除 `"DropManager"`；`_manager_configs` 新增 `"drop": {node_name:"DropManager", script_path:"res://managers/drop_manager.gd", priority:1, description:"掉落系统"}`
- **10 个调用点**在 `get_node_or_null("/root/DropManager")` 前加 `ManagerLazyLoader.ensure_loaded("drop")`：
  - `managers/battle/battle_damage_system.gd:368`
  - `managers/battle/battle_manager.gd:371`
  - `managers/game_manager.gd:586,613`
  - `scripts/systems/offline_idle_manager.gd:154`
  - `scripts/systems/afk_mode_manager.gd:431`
  - `scripts/card_drop_grants.gd:55`
  - `managers/achievement/achievement_rewards.gd:115,171`
  - `scenes/ui/mvp_panel.gd:288,327,629`
  - `managers/save_manager.gd:687`（`_collect_manager_state` 前）
- **`drop_manager.gd` 自身不动**（`_ready` 里 `drop_tables = DropTables.new()` 保留）

**收益**：启动减 DropTables 构建（5 时代 ~150 DropEntry）。开销转移到首次掉落结算时。

---

## P1-4：AudioManager 播放器池改按需扩展

**改动文件 1 个：`managers/audio_manager.gd`**

- `_ready`（L65-70）`for name in SFX_NAMES` 循环改为只建默认 `"button"` 播放器
- `play_sfx`（L136-162）：`_players.get(name)` 未命中时即时 `new() + add_child + 存入 _players`
- BGM 系统（`_music_player` 单播放器）不动

**收益**：启动减 31 个 AudioStreamPlayer 节点。标题屏立即需要的 button 音效仍在。

---

## P1-5：7 个 JSON static var 改 getter 懒加载

**改动文件 6 个**（仿 `data/enemy_phase_masters.gd:50-57` 现成模板）：

把 `static var X = _load_json(...)` 改写为 getter（对外 `Class.X` 访问语法不变，**零调用方改动**）：
```gdscript
static var _x_cache: Dictionary = {}
static var _x_inited: bool = false
static var X: Dictionary:
    get:
        if not _x_inited:
            _x_inited = true
            _x_cache = _load_json_dict(_X_JSON_PATH, FALLBACK)
        return _x_cache
```

**改动点**：
- `data/quest_definitions.gd:5` `QUESTS`
- `data/company_store.gd:5` `ITEMS`
- `data/enemy_archetypes.gd:56` `ARCHETYPES`
- `data/enemy_phase_equipment.gd:15,16,17` `WAR_PLATFORMS`/`WAR_WEAPONS`/`ENERGY_CARDS`（3 个）
- `data/task_definitions_extended.gd:445,446` `OBJECTIVE_TYPES`/`EXTENDED_TASKS`（2 个）

`enemy_phase_masters.gd` 已是此模式无需改。

**收益**：7 个 JSON 文件（~170KB）的同步解析推迟到首次访问。preload 链触达这些类时不再立即读盘。

---

## P2-1：cast_effect 加节流

**改动文件 1 个：`scenes/effects/cast_effect.gd`**

`_process`（L9-14）加 0.05s 累加器节流 `queue_redraw`（仿 `law_target_indicator.gd:17` 模式）。寿命 1 秒不变。

**收益**：与 P0 热点叠加时减少重绘尖峰。

## P2-2：performance_metrics 写盘 4s→15s

**改动文件 1 个：`managers/performance_metrics_manager.gd:59`**

`now_ms - _battle_last_flush_ms >= 4000` → `>= 15000`。

**收益**：磁盘 IO 抖动源降频。

---

## 验证

1. **Godot headless `--check-only`**：确认无语法错误（5 分钟超时属项目既有现象，启动到 DefaultCards 构建即可）。
2. **静态 Grep 核对**（沿用项目 v6.x~v7.x 标准）：
   - `query_allies` 定义+调用配对
   - `_nano_tick_acc` 清理点完整（_update_owner 归零分支 + stop/reset）
   - 10 个 DropManager 调用点 ensure_loaded 配对
   - 7 个 JSON getter 的 `_inited`/`_cache` 拼写一致
3. **性能 smoke test**（新建 `tests/perf_smoke.gd`，仿 `tests/master_power_smoke.gd` SceneTree 模式）：
   - 构造伪 spatial_grid + N 个伪单位，对比 `query_allies` vs `get_nodes_in_group` 全组遍历耗时
   - 模拟 nano_swarm 30 秒：旧逻辑（每帧 take_damage×N）vs 新逻辑（0.25s 累加）的调用次数
   - ObjectPool 首次 get_object 预热行为验证
   - JSON getter 首次访问触发加载、二次访问不重复加载

## 实施顺序

1. **P0**（两个偶发卡顿根因，立竿见影）
2. **P1**（启动减负，~15 文件）
3. **P2**（轻量清理，2 文件）
4. **验证**（check-only + Grep + smoke test）
5. **更新 AGENTS.md** 记录本轮性能优化

全部向后兼容，游戏行为零变化。