## Project Overview

**Phase War** (相位战争) — tactical card strategy game. Players deploy historical military units (WWI to future eras) on a grid-based battlefield, manage card evolution, faction diplomacy, and intel-driven progression.

- **Engine**: Godot 4.5 (config_version=5)
- **Language**: GDScript
- **Resolution**: 1280x720, 60fps cap, `gl_compatibility` renderer
- **Entry scene**: `res://scenes/title_screen.tscn`
- **Main game scene**: `res://scenes/main.tscn`

## Godot CLI Commands

Godot not on PATH. **本项目跨两台机器开发，Godot 可执行文件位置不同——按下表选当前机器可用的那个**
（两台机器均为 v4.5.1 stable，`--version` 验证通过）。

| 机器 | 主路径（实测可用） | 布局说明 |
|------|--------------------|----------|
| 机器 A | `D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe` | 顶层、无子目录（旧文档记载，该机器子目录布局不存在） |
| 机器 B（2026-08-06 实测） | `D:/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64.exe` | 多一层 `-stable/` 子目录。同机顶层另有别名 `Godot_v4.5.1.exe`（163MB，等价主 exe）与 `Godot_v4.5.1-stable_win64_console.exe`（console launcher，stderr 直打终端，**排错/抓崩溃日志首选**） |

> **自动探测（bash，复制即用，跨机器无需改路径）**——优先 console 版（排错友好）→ 子目录正身 → 顶层各候选，命中第一个即用：
> ```bash
> GODOT=""
> for c in \
>   "/d/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64_console.exe" \
>   "/d/Downloads/Godot/Godot_v4.5.1-stable_win64_console.exe" \
>   "/d/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64.exe" \
>   "/d/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" \
>   "/d/Downloads/Godot/Godot_v4.5.1.exe"; do
>   [ -x "$c" ] && GODOT="$c" && break
> done
> echo "GODOT=$GODOT"; "$GODOT" --version
> ```

> ⚠️ **历史踩坑**：旧文档只记机器 A 的顶层路径，在机器 B 上不存在 → bash 报
> `No such file or directory`（上一轮 vfx_impact_factory 排错时即踩此坑）。
> 两台机器都记下 + 自动探测后此问题不再复现。

Add `--rendering-driver opengl3` if Vulkan issues (applies to `--headless` / `--check-only` too).

> **验证方式分层建议（避免撞 5 分钟超时）**：
> - **纯逻辑文件**（无 `key = value` 字典写法）→ `gdparse <file>`（秒级，但 gdtoolkit 4.5.0 不支持 GDScript `key = value` 字典语法，对数据字典文件集体误报）
> - **单文件改动**（数据字典等）→ `--script` 模式单独 `load()` 改动文件 + 断言（几秒出结果，不启动全部 autoload）
> - **全项目兜底** → `--check-only`（启动 42 autoload + 构建 133 卡，常撞 5 分钟超时，仅大改动用）

```powershell
# Version check
& "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --path "." --version

# Project validation (no UI, recommended) — 全项目兜底，小改动别用
& "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --check-only

# Smoke test (no GdUnit dependency)
& "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/master_power_smoke.gd"

# Full GdUnit test suite
& "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/gdunit4_runner.gd"
```

## agent_tools 编辑器插件（已启用，可用）

**`addons/agent_tools`** 是 Godot 编辑器插件（`@tool` + `EditorPlugin`），在编辑器进程里跑一个 **line-delimited JSON-RPC over TCP** 服务，对外暴露 70+ 工具 / 12 命名空间，全走编辑器真实 API（比手改 `.tscn`/`.tres` 安全）。**2026-08-03 实测可用。**

### 运行前提（重要）
- **只在带 GUI 的编辑器进程里加载**（`plugin.gd` 是 `EditorPlugin`）。`--headless` / `--check-only` / `--script` 模式**不会**加载此插件 → 无 9920 端口。
- 用前先确认编辑器在跑：`tasklist | grep -i godot` 且 `netstat -ano | grep 9920` 有 LISTENING。
- 端口：默认 `9920`；被占用自动顺延到 `9921..9929`（`project.godot` 设 `agent_tools/port` 可强制端口）。多编辑器实例靠此共存。

### 调用方式（无需 MCP 客户端，Bash+Python 直连）
```python
import socket, json
def call(method, params=None, port=9920, timeout=8.0):
    req = {'id': 1, 'method': method}
    if params is not None: req['params'] = params
    s = socket.socket(); s.settimeout(timeout)
    s.connect(('127.0.0.1', port)); s.sendall((json.dumps(req)+'\n').encode())
    buf=b''
    while b'\n' not in buf:
        c=s.recv(8192);  # 每行一条响应（\n 分隔）
        if not c: break
        buf+=c
    s.close(); return json.loads(buf.decode().strip())
print(call('editor.state'))                       # 读编辑器状态（连通性探针首选）
print(call('project.get_setting', {'key':'application/config/name'}))  # 参数名是 key 不是 setting
print(call('autoload.list'))
print(call('logs.read'))                          # 读 Output 面板日志（查报错，比跑 headless 快）
```

### 工具命名空间速查（`registry.gd` 全量）
| 命名空间 | 代表方法 | 用途 |
|---------|---------|------|
| `scene.*` | new/add_node/set_property/get_property/call_method/build_tree/open/save/current/inspect/capture_screenshot | 场景节点增删改/属性/调用/打包存盘 |
| `signal.*` | connect/disconnect/list | 信号接线（走编辑器 API，自动写 `.tscn`） |
| `script.*` | create/attach/patch | 建脚本/挂载/补丁 |
| `resource.*` | create/set_property/call_method | 建/改 `.tres` 资源 |
| `refs.*` | validate_project/find_usages/rename/rename_class | **引用校验/重命名**（大项目慢，注意超时） |
| `project.*` / `autoload.*` | get_setting/set_setting/autoload_add/list | 项目设置/autoload 管理 |
| `editor.*` / `logs.*` | state/selection_get/game_screenshot/logs_read/logs_clear | 编辑器状态/选择/运行中游戏截图/日志 |
| `run.*` | scene_headless | 通过编辑器跑 headless 场景 |
| `fs.*` / `user_fs.*` | list/read_text/write_text | 读写文件（走编辑器 FS） |
| `test.*` / `input_map.*` / `animation.*` / `theme.*` / `physics.*` / `client.*` / `performance.*` / `docs.*` | — | 测试/输入映射/动画/主题/碰撞形状/客户端配置/性能监视器/类参考 |

### 实测要点 / 踩坑
1. **`project.get_setting` 参数名是 `key`** 不是 `setting`（报 `-32602 missing 'key'`）。
2. **响应 `id` 返回浮点数**（`1.0`）—— JSON-RPC 客户端如按 int 匹配 id 会失败，需容忍。
3. **空响应=工具模块解析错误**：`registry.dispatch` 对 preload 失败的工具返回空，server 会发 `-32000 tool returned empty response — likely a parse error`，此时看编辑器 Output 面板的真错误。
4. **大项目慢工具**：`refs.validate_project`/`fs.list res://`（本项目 2043 文件）可能数秒到超时，按需缩小范围或分批。
5. **方法不存在** → `-32601 method not found: <method>`（去 `registry.gd` 核对全名）。
6. **会话注册表**：插件按 PID 在 `~/.godot-agent-tools/sessions/<pid>.json` 写端口/项目路径，供 MCP shim 的 `session.list` 发现多个编辑器实例。

## 崩溃/错误日志诊断速查（2026-08-05 踩坑沉淀）

> 游戏崩溃（signal 11 / 0xc0000005 段错误）后，"日志在哪"反复找不准。下面是**每个日志源的确切位置 + 局限**，按优先级排查。

### 日志源清单（按可用性排序）

| # | 日志源 | 路径 | 能抓什么 | 局限 |
|---|--------|------|---------|------|
| 1 | **agent_tools `logs.read`** | 编辑器进程内存缓冲（socket `logs.read` 方法）| 运行中游戏的 print/push_error，含 **GDScript backtrace** | ⚠️ **游戏崩溃退出后缓冲随进程消失**，必须"游戏还活着"时读。嵌入式窗口游戏崩溃通常进程已退 → 抓不到 |
| 2 | **Godot 全局游戏日志** | `%APPDATA%/Godot/app_userdata/Phase War/logs/godot.log`（+ 时间戳轮转 `godot2026-XX-XX...log`）| 游戏运行期全部 stdout/stderr | ⚠️ **嵌入式窗口子进程**（编辑器 F5）的日志常不落盘（被父编辑器捕获到 Output 面板而非写文件）；只有**独立进程**（双击 exe / `--script` 模式）才稳定落盘。本项目该目录历史日志多是 2026-02 旧原型残留，看**文件修改时间**别被误导 |
| 3 | **Windows 事件查看器（WER）** | 事件查看器 → Windows 日志 → 应用程序， ProviderName=`Application Error`；或 PowerShell：`Get-WinEvent -FilterHashtable @{LogName='Application';ProviderName='Application Error';StartTime=(Get-Date).AddHours(-2)} \| Where-Object {$_.Message -match 'Godot'}` | 崩溃的 C++ 层信息：异常代码（`0xc0000005`=访问违例/段错误，`0xc000041d`=未处理异常）、故障模块（`ntdll.dll`/`msvcrt.dll`=堆破坏，`Godot.exe`=引擎内部）、进程 ID、时间戳 | ⚠️ **只有 C++ 堆栈地址，无 debug info**（`PE/COFF executable`），**没有 GDScript backtrace**。只够判断"崩了 + 大概类型"，定位不到具体 GDScript 行 |
| 4 | **编辑器 Output 面板** | 编辑器 GUI（无文件落盘）| F5 嵌入式游戏的 stdout/stderr，含 GDScript backtrace | ⚠️ agent_tools 的 `logs.read` **读不到**（它读的是游戏进程的 `_MCPGameBridge` autoload 缓冲，不是编辑器 Output）。只能人眼看；崩溃后 Output 内容**保留**（不随游戏子进程消失） |
| 5 | **磁盘 `.godot/` 下** | `.godot/` 无崩溃日志 | — | Godot 不在项目目录写崩溃转储 |

### 各崩溃场景该读哪个

| 场景 | 推荐日志源 | 备注 |
|------|-----------|------|
| **编辑器 F5 跑游戏崩溃退出** | ①人眼看编辑器 Output 面板（GDScript backtrace 在那）②Windows 事件查看器（确认崩溃类型/时间）| agent_tools `logs.read` **抓不到**（游戏进程已退）。这是最常见的坑 |
| **headless `--script` 模式崩溃** | 命令行 stdout 直接打印（含完整 GDScript backtrace） | `run_scene_headless` 工具会捕获并结构化返回 `errors[]` |
| **独立进程（双击 exe）崩溃** | `%APPDATA%/.../logs/godot.log`（落盘）| 嵌入式窗口模式不落盘，这是与独立的区别 |
| **游戏运行中（未崩）报错** | agent_tools `logs.read`（socket 直读，最快）| 游戏必须**正在运行**；`playing_scene` 非 false |

### 关键鉴别点（别被误导）

1. **`%APPDATA%/.../Phase War/logs/` 里的旧日志**：本项目该目录有大量 `2026-02-25` 的日志，内容是 `[Battlefield] ERROR: Key N already exists!` / `RealtimeBattleLayer` / `BattleGameManager` / `battle_unit` 字典等前缀——**这些在当前代码里零出现**（`grep -r "RealtimeBattleLayer" --include=*.gd .` 无结果），是某个旧原型残留，**对当前 Phase War 代码无诊断价值**。看日志务必先看文件**修改时间**。

2. **GDScript backtrace 是定位崩溃的金标准**：形如
   ```
   GDScript backtrace (most recent call first):
       [0] _apply_card_icon_to_clip (res://scenes/ui/backpack_card_item.gd:856)
       [1] _set_compact_slot_view (res://scenes/ui/backpack_card_item.gd:895)
       ...
   ```
   它在**游戏 stdout**。嵌入式 F5 崩溃后只能从编辑器 Output 面板人眼看到；headless 模式直接打到终端。

3. **C++ backtrace（`[1] error(-1): no debug info in PE/COFF executable`）**：发行版 Godot 无调试符号，几十行地址全部 `no debug info`，**无法定位**。别花时间解析这些地址。

4. **异常代码速查**：`0xc0000005`=访问违例（空指针/野指针/堆破坏）；`signal 11`=同前（Linux/跨平台叫法）；`0xc000041d`=未处理异常；`mem is null`（`alloc_static`）=**堆耗尽**（OOM）。

### 当所有日志源都抓不到时的兜底：给游戏加 stdout 落盘

嵌入式 F5 崩溃 + 编辑器 Output 滚太快看不清时，在 `scenes/main.gd:_ready()` 开头加全局 print 重定向：

```gdscript
func _redirect_stdout_to_file() -> void:
    var path := "user://game_stdout.log"
    var f := FileAccess.open(path, FileAccess.WRITE)  # WRITE=每次覆盖；想追加用 READ_WRITE + seek_end
    if f == null:
        push_warning("[Main] 无法打开日志文件: %s" % path)
        return
    # 把全局 print 输出重定向到文件（OS.execute 不受影响）
    # Godot 4.x：用 LoggerServer 或直接 hook print；最简方式是设 ProjectSettings 的 logging
    # 这里用一个轻量 trick：重定向 _print_handler
    _log_file = f
    # 注：实际实现需注册 print handler（见 OS.add_logger），下方简化版仅做示意
    print("[Main] stdout 重定向到 ", path)
```

> ⚠️ Godot 4.5 没有 `OS.add_logger` 公开 API，完整重定向需用 `Logger` 类的 `add_logger`（编辑器构建可用）。**实战更稳的做法**：在崩溃点前后手动 `f.store_string(...)` + `f.flush()`，或临时把关键路径的 `print` 改成写文件。本项目 main.gd 曾临时加 `_redirect_stdout_to_file()`，复现稳定后应移除。

## Architecture

### Autoload Singletons（project.godot 实际 31 个，2026-08-23 核对——PhaseLawManager 已随 P2-7 法则退役删除）

> 双层设计说明：部分 manager **同时**存在于 project.godot [autoload] 与 ManagerLazyLoader 配置——
> 后者仅作 `ensure_loaded("<id>")` 的统一访问入口，命中 `/root/NodeName` 即复用，不会重复实例化。

| # | Singleton | File | Role |
|---|---|---|---|
| 1 | `SignalBus` | `scripts/signal_bus.gd` | 中央事件总线（~76 活跃信号；同名死信号已清理） |
| 2 | `BattleInputState` | `scripts/battle_input_state.gd` | 战斗输入状态机 |
| 3 | `EnergyManager` | `managers/energy_manager.gd` | 战斗能量池 |
| 4 | `PhaseInstrumentManager` | `managers/phase_instrument_manager.gd` | 4色装备槽 + 符文槽 + 相位场等级(Lv1-30)/属性点分配 |
| 5 | `BattleManager` | `managers/battle/battle_manager.gd` | 战斗编排（委托 BattleSpawnSystem/BattleDamageSystem） |
| 6 | `GameManager` | `managers/game_manager.gd` | 游戏流程；15% 相位师遭遇 |
| 7 | `BlueprintManager` | `managers/blueprint_manager.gd` | 卡牌账号级养成（副本/星级/改造/进化/继承/HP下限） |
| 8 | `DropManager` | `managers/drop_manager.gd` | 战后掉落表与领取 |
| 9 | `SaveManager` | `managers/save_manager.gd` | `user://save.json`，schema v8，迁移链 v1→v8 |
| 10 | `AudioManager` | `managers/audio_manager.gd` | 音频 |
| 11 | `BasicResourceManager` | `managers/basic_resource_manager.gd` | 全局货币（纳米/合金/水晶/能量块/许可；科研点已随 P2-7 退役） |
| 12 | `ObjectPoolManager` | `managers/object_pool.gd` | 子弹/伤害数字对象池 |
| 13 | `UILazyLoader` | `managers/ui_lazy_loader.gd` | UI 面板按需加载 |
| 14 | `ManagerLazyLoader` | `managers/manager_lazy_loader.gd` | 非 core manager 按需加载 |
| 15 | `PerformanceMetricsManager` | `managers/performance_metrics_manager.gd` | FPS/性能采样 |
| 16 | `ModificationRegistry` | `scripts/systems/modification_registry.gd` | 9 兵种 140+ 改造模块（静态注册表） |
| 17 | `EvolutionPathRegistry` | `scripts/systems/evolution_path_registry.gd` | 8 兵种进化路径 |
| 18 | `DayClock` | `managers/day_clock.gd` | 游戏内日时钟 |
| 19 | `AuraManager` | `managers/aura_manager.gd` | 平台光环 |
| 20 | `IntelItemBag` | `managers/intel_item_bag.gd` | 情报道具背包 |
| 21 | `IntelManual` | `scripts/systems/intel_manual.gd` | 4维情报手册 |
| 22 | `QuestManager` | `managers/quest_manager.gd` | 任务（委托/剧情/引导/动态） |
| 23 | `FactionSystemManager` | `managers/faction_system_manager.gd` | 7 势力（声望/商店/技能/事件/占领状态机） |
| 24 | `AffixManager` | `managers/affix_manager.gd` | 模块化词条 |
| 25 | `LevelProgressManager` | `managers/level_progress_manager.gd` | 关卡进度 |
| 26 | `CardEnhancementManager` | `managers/card_enhancement_manager.gd` | 卡牌强化（词条节点按等级驱动） |
| 27 | `InstanceRegistry` | `managers/instance_registry.gd` | **卡牌实例+养成数据唯一真身**（见下方铁律章节） |
| 28 | `PhaseMasterSkillManager` | `managers/phase_master_skill_manager.gd` | 相位师技能树 |
| 29 | `TutorialProgressionManager` | `managers/tutorial_progression_manager.gd` | 引导 |
| 30 | `BattleSpectacle` | `managers/battle/battle_spectacle.gd` | 战斗演出/大招编排 |
| 31 | `_MCPGameBridge` | `addons/agent_tools/runtime/game_bridge.gd` | agent_tools 编辑器插件运行时桥 |

**Lazy-loaded managers**（`ManagerLazyLoader.ensure_loaded()`，21 个配置项；v9.x 2026-08-22 清理：battle_feedback/character/challenge_mode/version 四项已删，见停用清单）：
aura, level_progress, drop, quest, achievement, daily_task,
faction, affix, intel_item_bag, intel_manual, intel_discovery,
intel_evolution, card_collection, card_enhancement, stat_boost, leaderboard,
lore, tutorial, new_systems, toast, debug_log

> 注：与 autoload 重叠的条目（drop/quest/faction/affix/level_progress/card_enhancement/
> tutorial/intel_item_bag/intel_manual/aura）是别名入口（复用 /root 节点），非双实例。

### Key Patterns

1. **SignalBus decoupling**: All cross-system communication via `SignalBus.signal_name.connect()` / `.emit()`. Managers never hold direct references to each other for events.

2. **Resource-based card model**: `CardResource` (extends Resource) is the unified data type for cards, units, and progression. All cards created programmatically in `data/default_cards.gd` — no `.tres` files.

3. **Lazy loading**: Two tiers — `UILazyLoader` for UI panels, `ManagerLazyLoader` for non-core managers. Expensive init uses `call_deferred()`.

4. **Subsystem decomposition**: Large managers (`BattleManager`, `BlueprintManager`, `FactionSystemManager`) use `RefCounted` static sub-modules to separate concerns.

5. **Data-as-code（主体）**: 游戏数据表主体是纯 GDScript 静态类（`extends RefCounted` + `Dictionary`）。**例外（v9.x 核对修正）**：`data/json/`（8 文件）是活的 JSON 懒加载数据层——`company_store` / `enemy_phase_masters` / `enemy_archetypes` / `quest_definitions` / `enemy_phase_equipment`（platforms/weapons/energy 三表）等模块 getter 懒加载 JSON + LEGACY 兜底；`tools/audit_*` 与部分测试也读它。

6. **Era scaling**: Units scale by era (WWI → Future). `UnitStatsTable.build_stats_from_card()` applies era multipliers.

### System Dependencies

```
GameManager → BattleManager, BlueprintManager, PhaseInstrumentManager,
               BasicResourceManager, LevelProgressManager,
               FactionSystemManager, DropManager, QuestManager

BattleManager → BattleSpawnSystem, BattleDamageSystem, EnergyManager,
                 PhaseInstrumentManager, GameManager, SpatialGrid, SignalBus,
                 IntelDiscoveryManager (v6.0 defeated enemy recording)

SaveManager → ALL managers (loads/saves their state sections)
              Critical: BlueprintManager, PhaseInstrumentManager,
              QuestManager, BasicResourceManager, FactionSystemManager, AffixManager,
              LevelProgressManager, DropManager, IntelItemBag
              Deferred: LoreManager, StatBoostManager, AchievementManager,
              DailyTaskManager, StatisticsManager, CardEnhancementManager, etc.

BlueprintManager → CardEvolutionManager, ModManager, EvolutionHelpers,
                    DefaultCards, PhaseLaws, UnitStatsTable, RankRules

CardEnhancementManager → DefaultCards, UnifiedRankSystem (military titles)

ModificationRegistry → 9 unit-type mod modules (infantry/armor/artillery/anti_air/air/recon/engineer/fort/universal)

EvolutionPathRegistry → 8 unit-type evolution modules (infantry/armor/air/artillery/fort/recon/engineer/anti_air)

FactionSystemManager → FactionReputation, FactionShop, FactionSkillManager,
                        FactionEventManager, FactionCardGenerator

IntelDiscoveryManager → IntelManual, IntelDimensions, IntelRevealEvents
IntelEvolutionManager → IntelManual, IntelEvolutionBranches

★ InstanceRegistry (v7.x 核心，autoload) → 所有"卡牌实例 + 养成数据"的唯一真身
  └─ 被 BlueprintManager/CardEnhancementManager/store_panel/drop_manager/
     phase_instrument_manager/battle_spawn_system/所有养成面板 依赖
  └─ 详见下方"⚠️ 核心架构：卡牌实例化与养成隔离"——改任何卡牌/养成代码前必读
```

### ⚠️ 改卡牌/养成代码前必读

**`InstanceRegistry` 是 v7.x 卡牌养成隔离的核心（autoload `/root/InstanceRegistry`）。** 它持有所有"玩家拥有的卡"的实例（`card_id#N` 带独立养成数据）。`DefaultCards.get_card_by_id()` 返回的是**只读共享模板**，**严禁**直接改其 enhance_level/mods 等养成字段（会导致所有同名卡被污染）。养成操作必须通过实例卡。详见下方"⚠️ 核心架构：卡牌实例化与养成隔离"章节的三大铁律。

### Battle Flow

1. `GameManager.go_to_battle()` → `BattleManager.start_battle(scene)`
2. Per-frame: wave spawning + win/lose check
3. `SignalBus.battle_ended.emit(player_won)` → `GameManager._on_battle_ended()` handles rewards, progression, save

### Scene Structure

- `scenes/main.tscn` — `BattleContainer` + `HudLayer` (CanvasLayer 40) + `PopupLayer` (CanvasLayer 100)
- `scenes/battlefield/battlefield.tscn` — Battlefield rendering + battle slot grid
- `scenes/ui/` — ~65+ UI panel scripts (backpack, store, faction, quest, achievement, evolution, enhancement, modification, affix, intel hub, leaderboard, daily task, etc.)
- `scenes/units/` — `construct_unit` (player), `enemy_unit`, `phase_field_driver` (base), `enemy_phase_field_driver`, `bullet`, `swarm_enemy_controller`, `unit_hp_bar`
- `scenes/effects/` — Damage numbers, screen shake, cast effects, law target indicator, battle audio/effects systems
- `scripts/battle/` — `attack_calculator`, `construct_unit_ai`, `construct_unit_deploy`, `damage_attenuation`, `target_selection`

### Data Layer (`data/`)

数据主体为纯 GDScript 静态类（`extends RefCounted`）；`data/json/` 子目录是例外——8 个 JSON 文件作为懒加载真身（getter 懒读 + LEGACY 兜底），消费方见 Key Patterns #5。

**Core Cards & Enemies:**
- `default_cards.gd` — ~110 battle unit definitions (WWI to near-future, 5 eras × 20 levels)
- `enemy_archetypes.gd` (+ era-split variants: `_ww.gd`, `_cold_modern.gd`, `_future.gd`) — Enemy types, drops
- `enemy_phase_masters*.gd` (5 era files + combined) — Phase master (boss) definitions
- `enemy_equipment_*.gd` — Enemy weapons, armor modules, specials
- `enemy_blueprints.gd`, `enemy_unit_manifest.gd`, `enemy_stat_context.gd`, `enemy_stat_resolver.gd`

**Law & Environment:**
- `phase_laws.gd` — Law definitions (4 families: STEEL/FLAME/THUNDER/VOID, passive + active)
- `battle_environments.gd` — Battlefield environment modifiers
- `phase_instruments.gd` — Phase instrument definitions (4-color slot configs)

**Economy & Progression:**
- `basic_resources.gd` — Resource ID definitions (nano/alloy/crystal/energy block/permits；科研点已随 P2-7 退役)
- `battle_card_v3.gd` — Era HP/damage multipliers (v6.1: 近未来伤害倍率 1.90→1.80)
- `level_eras.gd` / `level_information.gd` — Level-to-era mapping (100 levels, 5 eras)
- `rank_rules.gd`, `card_progression_settings.gd` — Progression tuning

**v6.0 Intel System:**
- `intel_dimensions.gd` — 4 intel dimensions (basic/tactical/material/secret)
- `intel_reveal_events.gd` — 112 reveal events (7 enemy types × 4 dimensions × 4 tiers)
- `intel_evolution_branches.gd` — 4 hidden evolution branches
- `intel_manual_items.gd` — 6 intel consumable items

**Evolution:**
- `data/evolution_paths/` — 8 files: infantry/armor/air/artillery/fort/recon/engineer/anti_air evolution paths
- `unit_lineage_config.gd` — Unit lineage and evolution target mapping
- `evolution_paths_supplement.gd` — Supplementary evolution data

**Modification:**
- `data/modification_modules/` — 9 files: infantry/armor/artillery/anti_air/air/recon/engineer/fort/universal mods (140+ total)
- `mod_effects.gd` — Mod effect definitions and slot cost formulas

**Military Titles:**
- `data/military_titles/unified_rank_system.gd` — Unified rank system (13 ranks, power multipliers)
- `data/military_titles/title_display_names.gd` — Rank display names per combat_kind

**Faction:**
- `company_definitions.gd` — 7 faction definitions
- `faction_card_bonuses.gd`, `faction_exclusive_cards.gd`, `faction_skill_tree.gd`, `faction_war_events.gd`

**Quest/Achievement/Challenge:**
- `quest_definitions.gd`, `achievement_definitions*.gd` (4 files), `challenge_definitions.gd`, `task_definitions_extended.gd`, `daily_task_definitions.gd`

### Resource Types (`resources/`)

- `CardResource` — Unified card model (combat_unit/energy/law), evolution, affix slots, mods, per-target attack speeds (v5.0)
- `AffixResource` — Modular affix with rarity, level scaling, stat caps
- `UnitStats` / `UnitStatsTable` — Derived combat stats from CardResource with era scaling
- `GameConstants` — All enums: CardType(3), WeaponType(4), CombatKind(5), Era(5), PlatformType(13, deprecated), WeaponTypeLegacy(12, deprecated)
- `DropTables` — Weighted drop entries (13 drop types), tables, guarantee drops
- `DesignTokens` — UI theming constants (neon palette, typography, spacing, glow, accessibility)
- `GameConfig` — Tunable game config (battle/economy/UI/performance/debug)

### Test Structure

Framework: GdUnit4 (`addons/gdunit4/`)

```
tests/
  unit/
    blueprint/    — blueprint star config
    combat/       — affix scaling, card grid damage, damage calc, enemy stat resolver
    data/         — battle card v3, enemy archetypes, level info
    economy/      — drop tables, energy economy
    energy/       — energy manager
    managers/     — core managers (BlueprintManager, SaveManager, BattleManager, GameManager)
    progression/  — evolution HP floor, unit lineage
    resources/    — basic resource manager
    save/         — save integrity, save migration
  master_power_smoke.gd  — Quick smoke test (no GdUnit)
  syntax_check.gd         — Syntax validation
  gdunit4_runner.gd       — CI test runner entry point
```

### Save System

- Single JSON file: `user://save.json`, 3 save slots
- Schema version 6, migration chain v1→v2→v3→v4→v5→v6 via `scripts/systems/save_migration.gd` + `save_migration_v4.gd` + `save_migration_v5.gd` + `save_migration_v6.gd`
- Critical managers (10) load immediately; deferred managers (12) load in batches after scene ready
- Auto-save on battle end + window close; backup every 15s

## 美术资源工作流（卡图自动生成）

**新增卡牌缺卡面图时**，用 AI API 自动生成，完整流程见 `docs/ART_PIPELINE_AI_ICON_GENERATION.md`。

**快速要点**：
- 卡面图 `vis_enemy/player_NNN.png`（512×512 RGBA 透明底；敌方原图朝左，我方=水平翻转版）
- 编号体系：A段001-028 / B段030-035 / C段036-071 / D段专属命名 / E段072-081 / F段082-087 / G段110-114
- 生成脚本模板：`tools/generate_missing_card_icons_11.py`（调 agnes-ai API，key 在 `tools/_api_key.txt`）
- 部署脚本模板：`tools/deploy_card_icons_11.py`（白底转透明+缩放512+翻转player版）
- **分配新编号前必须先查 `_FOE_ID_TO_PLATFORM` 和 `PLAYER_ICON_OVERRIDE`** 能否复用已有图
- 修改 `enemy/` 原图后，必须对 `player/` 重做 `FLIP_LEFT_RIGHT`
- 审查清单：`tools/enemy_card_review.html`（浏览器查看全部卡面）

## ★ 战场卡图视觉数据单一真理源

**改任何"卡图大小/脚踩地/头部位置/缩放比例"问题，先查 `data/card_foot_anchors.gd`。**

该文件是战场卡图视觉数据的唯一真身，涵盖三类数据：

| 数据 | 字段 | 说明 |
|------|------|------|
| 脚部锚点 | `FOOT_FRAC` | 脚（最低非透明像素）距纹理底部比例；立绘 offset 据此对齐地面线 |
| 头部锚点 | `HEAD_FRAC` | 头（最高非透明像素）距纹理顶部比例；头顶 UI 据此锚定实体顶部 |
| 缩放比例 | `VISUAL_SCALE` | 战场缩放（CSV 原值 0.62~2.0，步兵~0.7/载具~1.4/boss~2.0）；查询时自动剥 `captured_` 前缀 |

**配套**：
- `PLAYER_PLATFORM_TO_SCALE_ARCHETYPE`（我方 platform_type → archetype 兜底映射，同文件内）
- `get_visual_scale(card)` / `get_visual_scale_by_id(id)` / `entity_top_y_for_sprite(spr)` 查询方法
- 脚部/头部数据由 `tools/generate_card_foot_anchors.py` 扫描卡图 alpha 通道生成（**新增卡图后必须重跑**：`python tools/generate_card_foot_anchors.py`）
- 缩放比例来自用户 CSV 表（手填，非扫描生成）

**消费方**（无需改，数据源统一指向本文件）：
- `scripts/card_grid_unit_visuals.gd`（战场单位呈现：缩放/脚部 offset/头顶 UI 锚定）
- `data/enemy_archetypes.gd` 的 `get_visual_scale_for_archetype`（转发到本文件，供 construct_unit/enemy_phase_field_driver 调用）

## Engine Version Notes

LLM training data covers Godot up to ~4.3. This project uses Godot 4.5.
Check `docs/engine-reference/godot/VERSION.md` before suggesting API calls.

## Collaboration Protocol

User-driven collaboration. Every task follows: **Question → Options → Decision → Draft → Approval**

- Ask before writing to any filepath
- Show drafts before requesting approval
- Multi-file changes need explicit approval for the full changeset
- No commits without user instruction

## 已知停用/移除系统清单（2026-08-23 更新）

改代码/排查 bug 前先对照本表，避免给停用系统"修 bug"或误以为功能缺失：

| 系统 | 状态 | 说明 |
|------|------|------|
| 合成系统（SynthesisManager + synthesis_recipes） | **已整体删除** | 2026-08-23 P2-7（批次2c）：无 UI 的僵尸系统，科研点唯一 sink。managers/synthesis/ 与 data/synthesis_recipes.gd 删除；fsm 的 preload/实例/初始化/getter/存档段移除；signal_bus 双信号与 audio 消费删除；旧档 synthesis_state key 静默跳过 |
| 科研点（research_points） | **已退役** | 2026-08-23 P2-7（批次2c）：ID_RESEARCH_POINTS 常量/定义/关卡产出、BasicResourceManager 收支臂、BlueprintManager 四函数、能量掉落降级补偿、faction_war 事件奖励、四处 UI 展示全部移除；旧档 total_research_points key 静默跳过 |
| 相位法则系统（PhaseLawManager + active_law_effects） | **已整体删除** | 2026-08-23 P2-7（批次2a+2b）：法则卡获取/展示链路、红蓝槽法则装配、主动法则施放链（battle_click_overlay 选点/ActiveLawEffects 效果/演出/播报）、敌方法则减益（enemy_unit/swarm_enemy_slot）、知识值掉落与战斗快照全部移除。starter 符文发放迁至 PhaseInstrumentManager.clear_slots_for_new_game。autoload 32→31；SignalBus 三条法则信号（active_law_cast_at/phase_law_runtime_changed/phase_law_cast）删除；旧档 phase_law 存档段 key 级静默跳过；buff 折叠卡 BUFF 段改显已装备符文 |
| 卡牌蓝图体系（解锁/副本/制造/拆解/星级） | **已整体删除** | 2026-08-22：制造面板（早已无入口）、副本记账、重复副本→研究点、背包拆解、研究点升星全部移除。收集口径改"拥有过的卡种"（card_added_to_backpack 驱动，InstanceRegistry 计数）。法则掉落解锁与开局 4 法则后随 P2-7 法则退役一并移除（2026-08-23） |
| 敌源MOD（EOM） | **已整体删除** | 面板/管理器/数据/掉落/存档字段全部移除（2026-08-21）。旧存档 eom 字段被静默忽略。情报揭示事件的 eom_unlock 奖励已改为 stat_visibility |
| 我方相位法则被动（ALLY 目标） | **已整体删除** | 随 P2-7 法则系统退役（2026-08-23）：蓝槽 ENEMY/BOTH 被动的 enemy_unit 减益消费链同批移除。开局 starter 符文发放迁至 PhaseInstrumentManager |
| 相位场属性点 | **已接通** | phase_instrument_selector 有分配/回收/洗点按钮，battle_spawn_system/master_platform_power 消费加成，存档字段齐全 |
| 时代缩放（我方） | 停用 | v6.8 移除 build_stats_from_card 的 era_*_multiplier；关卡难度完全由敌方难度链承担 |
| 能量卡系统 | 移除 | yellow 槽不接受任何卡 |
| 爬塔模式 | 移除 | v6.0 |
| LawShard | 废弃 | 常量仅作新游戏知识值倍率的兼容来源 |
| 强化②面板（card_enhancement_panel） | 移除 | 养成改为自动经验升星 + 技能树（v8.x）；no-op 函数与死场景已删 |
| StatisticsManager | 移除 | 配置与文件均不存在 |
| 相位师名册（phase_master_roster*） | 删除 | 4132 行死系统，零引用；活系统是 data/enemy_phase_masters*.gd（30 位） |
| BattleFeedbackManager | **已删除** | 2026-08-22：暴击震屏路径从未生效（get_node_or_null 恒 null），battle_manager/new_systems_integration 的 bfm 分支删除、兜底转正。将来恢复震屏直调 `scripts/screen_shake.gd`（8 个活文件先例） |
| CharacterManager / ChallengeModeManager(+challenge_definitions) | **已删除** | 2026-08-22：零玩法/UI 消费的僵尸管理器，仅存档管道被动实例化。旧档 characters/challenge_records key 静默跳过；save_constants/save_migration 映射保留。将来做剧情/挑战模式从 git 历史找回 |
| VersionManager | **已删除** | 2026-08-22：零调用方，永不实例化 |
| UILazyLoader 死配置 5 项 | 已清理 | 2026-08-22：occupation/leaderboard/intelligence（面板静态实例化且不在 prune 释放名单）/phase_master_skill（parent 节点不存在）/reinforcement（活于 card_info_panel 嵌入实例化）。**⚠️ 教训：quest/store/faction/settings 曾被同批误删当晚会回滚**——main.`_prune_preloaded_panels` 启动时会释放这四个面板的静态实例"转按需加载"，UILazyLoader 配置是其唯一重建路径，删=面板永远空壳（商店打不开事故）。真懒加载全集：backpack/growth/quest/store/faction/settings/achievement/help/modification/evolution/collection（10 项） |
| LevelSelectOverlay 空壳 | 已删除 | 2026-08-22：main.tscn 空节点，level_select 配置 v9.x 已先删（选关由 world_map 承担） |
| docs/tech-debt-register.md | 已删除 | 2026-04-09 停更全过时；活债务改记本清单 + CHANGELOG |

### 已知断链资产（不修只记录，2026-08-22 核对）

- `data/combo_tactics.gd`：combo_icons/ 下 chem/emp/incendiary/laser/nano/recon 6 张 PNG 缺失
- `scripts/ui_asset_loader.gd`：`assets/card_icons/law.png` 缺失
- `data/phase_instruments.gd`：pi_r_free_deploy、pi_umbra_01~03 图标缺失（pi_umbra_04 在）

## 版本历史

版本变更记录（v6.1 → v20 + 2026-08-16~22 补录节，2026-06 至 2026-08）见 **`docs/CHANGELOG.md`**。
本文件只保留活文档：架构、工作流、铁律、协作协议。

## ⚠️ 核心架构：卡牌实例化与养成隔离（永久约束，改任何卡牌/养成相关代码前必读）

**这是 v7.x 的核心架构，所有"卡牌强化/改造/进化/部署/显示"相关改动都必须遵守。违反会导致"强化一张卡所有同名卡都变"等严重污染 bug。**

### 单一事实来源

| 概念 | 真身 | 说明 |
|------|------|------|
| **卡牌模板** | `DefaultCards.get_card_by_id(card_id)` 返回的 `CardResource` | **共享单例**，每个 card_id 全局唯一，`_id_lookup_cache` 缓存。**只读，永不直接改其养成字段**（enhance_level/mods/module_slots）。 |
| **卡牌实例** | `InstanceRegistry` 里的独立 `CardResource` 对象 | 通过 `create_instance(card_id)` → `template.clone()`（深拷贝）创建，带 `instance_id`（`card_id#N`，N 由计数器递增）。**养成数据（enhance_level/mods/module_slots/inherit_bonus）只挂在实例上，不挂模板**。 |

### 三大铁律

**铁律 1：养成操作（强化/改造/进化）必须落在实例卡上，严禁直接改模板。**
- 实例判定：`card.instance_id` 非空（如 `cold_t72#1`）才是实例；为空则是共享模板。
- 强化面板 `_on_reinforce_pressed`、改造面板 `_install_modification` 都有 `instance_id.is_empty()` 守卫，拒绝操作模板。**新增任何养成操作必须加同款守卫。**
- 数据层 `BlueprintManager.apply_reinforcement(card, ...)` / `install_modification(card, ...)` 写入传入 card 对象的养成字段——调用方必须保证传入的是实例，不是 `DefaultCards.get_card_by_id` 模板。

**铁律 2：卡牌列表（成长/强化/改造/进化面板）数据源必须是 InstanceRegistry 实例全集，不是 SaveManager 队列。**
- `SaveManager._pending_backpack_ids` / `_last_known_extra_ids` 队列在 `backpack_presenter` 存活时会被 `consume_pending_backpack_card_id` 掏空（买卡信号双监听：SaveManager 入队 + presenter 立即 consume），读这个队列会看到"空"。
- 正确数据源优先级：**① `InstanceRegistry.get_all_instance_ids()`（真·实例全集，永不被 consume）→ ② SaveManager 队列（presenter 未存活/旧档迁移兜底）。蓝图解锁行已随蓝图体系移除（2026-08-22）**。
- 去重：完整 instance_id 去重（`cold_t72#1` ≠ `cold_t72#2`，各自保留一行）；蓝图裸 card_id 仅在该 card_id **没有任何实例**时补一条。
- `modification_panel` 是参考实现：按 base card_id 分组，每个实例渲染一行（带 `#N` 序号后缀）。

**铁律 3：同名卡部署到战场必须按 instance_id 精确匹配各自的实例，严禁按裸 card_id 取"首个匹配"。**
- 部署入口 `bottom_instrument_bar._on_slot_gui_input`：`BattleInputState.pending_deploy_platform_card_id` 必须传 `instance_id`（非空时），不是裸 card_id。
- `get_loadout_by_platform_card_id(id)` 同时支持 instance_id 精确匹配（优先）和 card_id 回退（兼容旧卡）。
- `_reach_alive_limit_for_card` 的"同卡上限"检查用裸 base card_id（按卡种统计），**不是** instance_id——两者语义不同，不可混用。

### 关键链路速查

```
买卡  store_panel → InstanceRegistry.create_instance(card_id) → 注册实例 + emit card_added_to_backpack
                                                                    ├─ backpack_presenter._on_card_added → _data.add_extra_card
                                                                    └─ SaveManager fallback → 入队（presenter存活时立即被consume）

装备  phase_instrument_manager.equip_card(slot, card) → 槽位存 card 对象（实例）；存档存 instance_id

读档  _restore_loadout → 按 instance_id 从 Registry 取实例（get_instance）；裸 card_id 回退取首个同名实例（push_warning）

部署  bottom_instrument_bar → 传 instance_id → request_player_deploy →
       _reach_alive_limit_for_card(base_card_id)  # 上限按卡种
       get_loadout_by_platform_card_id(instance_id)  # 精确取该实例
       → _build_stats_cached(platform_card实例)  # stats 已含该实例养成

显示  card_info_panel._show_player_unit → _resolve_source_instance_card(unit) → 按 unit.source_instance_id meta 取实例卡
```

### 已踩过的坑（勿重复）

| 坑 | 现象 | 根因 | 修复 |
|----|------|------|------|
| 强化/改造面板列表按裸 card_id 去重 | 同名卡只显示一条 | `cold_t72#1`/`#2` 被折叠 | 按完整 instance_id 去重 |
| 面板列表读 SaveManager 队列 | 买卡后列表看不到新卡 | presenter 存活时队列被 consume 掏空 | 改读 InstanceRegistry 全集 |
| 强化面板选模板强化 | 强化一张卡→所有同名卡都变 | 选中 `DefaultCards.get_card_by_id` 共享模板并改其 enhance_level | 选中实例卡 + instance_id 守卫拒模板 |
| 部署传裸 card_id | 同名卡战场属性都相同 | loadout 按 card_id 回退取"首个匹配" | 部署传 instance_id 精确匹配 |
| 上限检查传 instance_id | 同名卡上限统计错位 | 按 instance_id 统计而非卡种 | 剥离 #序号 得 base_card_id 再统计 |

### 涉及的关键文件

- `managers/instance_registry.gd` — `create_instance`/`get_instance`/`get_all_instance_ids`/`get_instances_by_card_id`/`get_card_id_of`/`clone_for_instance`
- `managers/save_manager.gd` — `_pending_backpack_ids`/`_last_known_extra_ids`/`consume_pending_backpack_card_id`/`get_pending_backpack_ids`/`get_last_known_backpack_ids`/`_set_last_known_extra_ids_direct`
- `data/default_cards.gd` — `get_card_by_id`（**共享模板，只读**）/`clone_for_instance`
- `resources/card_resource.gd` — `clone()`（深拷贝，养成隔离的基础）/`instance_id`/`enhance_level`/`mods`/`module_slots`
- `managers/blueprint_manager.gd` — `apply_reinforcement`/`install_modification`（写入传入实例的养成字段）/`get_all_blueprint_ids`
- `managers/phase_instrument_manager.gd` — `equip_card`（存实例对象）/`get_loadout_by_platform_card_id`（instance_id 精确匹配 + card_id 回退）/`_restore_loadout`
- `managers/battle/battle_spawn_system.gd` — `request_player_deploy`（上限用 base_card_id，loadout 用原 id）
- `scenes/ui/bottom_instrument_bar.gd` — `_on_slot_gui_input`（部署传 instance_id）
- `scenes/ui/growth_panel.gd` — `_load_unlocked_cards`（Registry 全集数据源 + 完整 instance_id 去重）
- `scenes/ui/reinforcement_panel.gd` — `_refresh_card_list`（实例感知）/`_on_reinforce_pressed`（instance_id 守卫）
- `scenes/ui/modification_panel.gd` — `_refresh_card_list`（参考实现：分组+每实例一行）/`_install_modification`（守卫）
- `scenes/ui/card_info_panel.gd` — `_resolve_source_instance_card`（战场单位按 meta 取实例）

## ⚠️ 改任何 VFX（粒子/贴图/弹道视觉）前必读

**`.agents/skills/vfx-tuning/SKILL.md`** — v17 全轮踩坑复盘沉淀的强制五步铁律：
①先读历史评分报告（正确值就躺在 v12/v17 报告里）→ ②量贴图实寸（PIL 三行，禁按注释假设）→
③改特效前先校准测量（采样帧与寿命联动）→ ④单轮单变量 + AI 三次取中位 → ⑤感知验收优先于物理正确。
附参数参考表（本轮验证值）、弯路黑名单五条、工具链速查。2026-08-18 v17e 轮沉淀。
