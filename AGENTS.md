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

**⚠️ 美术 PNG 全量备份铁律（发行机迁移/换机硬前提）**：`.gitignore` 全局忽略 `*.png`——美术资产**不入 git，删=永久丢失**。两大目录：`assets/card_icons/`（866 张卡面 + 缩略图树）与 `assets/ui/instruments/`（相位仪徽章）。基线备份：项目外 `phase-war-art-backup-YYYY-MM-DD.zip`（2026-08-23 首份 144.1MB/960 文件，sha256 前 16 位 `7c9da35781ffe08c`）。新增/修改图后按同日期惯例重打包，并建议同步一份到网盘/异机。打包：两树 walk（png/svg/txt）→ zipfile ZIP_STORED → 项目外。

**新增卡牌缺卡面图时**，用 AI API 自动生成，完整流程见 `docs/ART_PIPELINE_AI_ICON_GENERATION.md`。

**相位师（30 位 master）美术已定稿（2026-08-24）**：EA 走 C 方案——战场共享底座图+势力染色、产兵复用时代原型卡图、世界地图仅 tooltip 名字，**零美术工作量**；1.0 前升级专属立绘（届时方案 A/B 二选一）。现状核实与升级路径见 `docs/PHASE_MASTER_ART_PLAN.md`。勿在 EA 阶段给 master 加专属立绘挂载点。

**快速要点**：
- 卡面图 `vis_enemy/player_NNN.png`（512×512 RGBA 透明底；敌方原图朝左，我方=水平翻转版）
- 编号体系：A段001-028 / B段030-035 / C段036-071 / D段专属命名 / E段072-081 / F段082-087 / G段110-114
- 生成脚本模板：`tools/generate_missing_card_icons_11.py`（调 agnes-ai API，key 在 `tools/_api_key.txt`）
- 部署脚本模板：`tools/deploy_card_icons_11.py`（白底转透明+缩放512+翻转player版）
- **分配新编号前必须先查 `_FOE_ID_TO_PLATFORM` 和 `PLAYER_ICON_OVERRIDE`** 能否复用已有图
- **相位仪/装备徽章图标**（`assets/ui/instruments/pi_*.png`，1024×1024 不透明深底徽章风）：阵营族图（aegis/helix/nova/iron/umbra/eon）各有专属系列，缺图走 agnes 生成（模板 `tools/generate_umbra_instruments_4.py`，2026-08-23 影幕系列先例）；传奇 r_ 系列为 128×128 小图。生成后需跑 `godot --headless --import` 生成 .import 元数据
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
| 强化①（手动强化轴 enhance_level 0-10） | **已退役** | 2026-08-24 v20.12 等级统一：`card_level`（战斗卡等级 1-30，上阵攒经验自动升）成为唯一玩家卡等级轴。`reinforcement_panel.gd/.tscn` 删除、`BlueprintManager.apply_reinforcement` 删除、card_info_panel 强化 Tab 恒隐藏（TabIdx/节点保留防索引错位）。进化等级门槛改读 card_level（E1=5/E2=10）；进化执行=变成全新卡（等级/经验/改造/词条槽全部重置，仅 inherit_bonus/hp_floor/情报奖励保留）；光环/能力星级 = card_level÷3 映射 1-10；掉落卡星级改发起始经验；教学任务"强化尝试"改升级驱动（`_on_card_level_up` 转发 `enhancement_completed` 信号）。敌方配装档位（enemy_loadout_tiers 的 enhance_level 3/6/10）与攻击公式的 enhance 乘区**不受影响**（内部敌方轴）；旧档存量 enhance_level 保留为惰性数值，无提升入口 |
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

### 已知弹道路由问题（2026-08-25 核对，P1 已修复）

- **P1 敌方曲射/空射单位弹道走直线（已修复 v9.5）**：`enemy_unit.gd:1328-1332` 路由顺序是直射 batch 先判（`wt in [0,4,1,2]`）、曲射 batch 后判。`stats.weapon_type` 经 UCT 层为新枚举值（INDIRECT=1/AERIAL=2），与 legacy 列表 `[0,4,1,2]` 撞值——1/2 被直射 batch 抢走，弧线分支永不触发。**修复**：① `_default_enemy_slot_weapon_type` 引入 `combat_kind` 消歧义（legacy 1/2/3 vs 新枚举 1/2/3）；② `_do_attack` 路由调序——曲射 batch 先于直射 batch（与玩家侧 `construct_unit_ai` 对齐）。改动文件：`enemy_unit.gd` 三处（函数签名+调用点+路由顺序）。
- **P2 边界退化**：双 batch 均不可用时 wt=1/2 行为取决于退化路径，极罕见。
- **P3 死代码**：`swarm_enemy_slot.weapon_types` 数组永远空（data 层无 `weapon_types` 字段），多武器轮换永不触发；`enemy_unit.gd:1340` 敌方霰弹分支死代码（无 wt=5 敌原型）。

### 弹道主路径修复记录 + 遗留问题（2026-08-29 核对，v20.25 修复）

**背景**：曲射弹道双实现脱节——实战 100% 走 `simple_indirect_projectile_batch`（主路径），`bullet.gd` 曲射仅兜底；v19-R25/R33 的弧线可读性修复（wt1/wt9 倍率 1.6/1.0→0.5）只落在兜底路径，主路径无名炮弹弧顶 ~376px 飞出画面上缘。审计工具 `vfx_audit_matrix` 自 v18-R8 起曲射族也采样兜底路径，调优闭环全程失准。

**v20.25 已修复**（改动：`simple_indirect_projectile_batch.gd` / `weapon_projectile_vfx.gd` / `vfx_audit_matrix.gd` / 两直射 batch / `bullet.gd` / smoke 锁）：

1. **弧线基准统一**：batch `_get_indirect_arc_multiplier` wt1 1.6→0.5、wt9 1.0→0.5（对齐 bullet v19 验证值）；WPV `indirect_apex_mul` 亚类系数按新基准重标（迫击炮 1.6→终值 0.8 / 榴弹 1.0→0.5 标准弧 / 火箭 0.7→0.35 / 导弹 1.2→0.6，保 v20.17 层级锚进可读包络，两路径共用）。
2. **审计矩阵曲射族（f1/2/3/7/9）改走 indirect batch 采样**——后续弹道调优闭环对准主路径（vfx-tuning 第 3 步教训）。
3. **batch 弹道音效接通**：曲射 batch 补开火音（rocket_launch/flak_fire/missile_hum 按槽位）+ 落地爆炸音（70ms 节流）；两直射 batch 补节流开火音（110ms 窗口、低音量 0.18-0.3、敌方降调）。此前武器音效全链路只挂 bullet 兜底路径，主路径无声。
4. **敌方曲射弹体 tint 粉红→亮橙红**（batch `_ENEMY_TINT` + `bullet.gd` 贴图弹 tint，统一为直射 batch 的 `(1.0,0.55,0.25)`）。
5. **bullet 对象池卫生**：`reset_pool_object` 补 `_blitz_applied`/`_pierce_from_ability` 复位（残留会吞新射手闪电穿插加成/误播 enhanced 穿甲光线）。

**遗留问题（P2/P3，按需处理）**：

- **P2 曲射 batch 无烟迹拖尾**：bullet 兜底路径有 36 粒/1.0s 烟迹画弧线（v19-R30 调优），batch 主路径只有弹体本体+落点预警圈，弧线中段仅靠弹体标注（2026-08-29 审计截图 AI 确认可读但中偏弱）。补齐需在 batch 加池化粒子层，属独立 VFX 轮。
- **P2 目标中途死亡弹道表现**：曲射/直射弹在目标死亡后飞完直接回收，无落地爆炸特效、无 MISS 提示——"落地无声蒸发"与"被拦截"观感混淆。
- **P3 溅射公式两路径不同**：batch 固定 50% 伤害且上限 4 目标（`MAX_AOE_TARGETS_PER_HIT`）；bullet 用 `shooter_stats.splash_damage` 且无上限。改造溅射词条对两路径玩家意义不同。
- **P3 蜂群路由裸值**：`swarm_enemy_controller._should_use_projectile_batch` 仍用 `GC.BATCH_FIRE_WEAPON_TYPES=[0,4,1,2]` 裸值判路由，v9.5 敌方双枚举消歧义未同步到蜂群（当前蜂群全 legacy 轻步兵未触发）。
- **P3 死配置**：indirect batch `_WEAPON_CONFIG` 的 speed 字段零消费（时长走固定公式），且 wt1/2 值与 bullet 路径不一致，纯误导；`proj_quad_size` 表多档与实图不符（2026-08-29 PIL 实测：legacy MG 1349×110 写成 1127×251 等，活路径 wt1/2/3/7/9 全部正确，谁给直射族建 quad 层谁踩）。
- **P3 死代码**：indirect batch `_physics_process` 的 `raw_tgt == null: pass` 空块、`_impact_spawned` 字段无人读；`bullet.gd` `_beam_visual_phase`/`FLAME_STAR_TEX` 保留兼容未消费。

### 命中效果检查记录 + 修复（2026-08-29，v20.26）

检查范围：`vfx_impact_factory.gd`（3904 行全读）+ WPV 分派 + bullet/三 batch 命中调用点 + 24 张审计命中格像素/目视。结论：分层命中结构、池化上限（spark 320/debris 140/ring 80/sprite 160/beam 60）、四签名分派、轻武器减层规格全部健康；爆炸帧动画 PNG 有真实内容（WPV"占位透明 PNG"旧注释失实）。

**v20.26 已修复**（改动：`vfx_impact_factory.gd` / `weapon_projectile_vfx.gd` / `simple_indirect_projectile_batch.gd`）：

1. **P2 曲射/空射命中火花退出轻动能档**（双枚举漏网第三例）：`_spawn_sparks` 寿命帽 `[0,1,2,4]→[0,4]`、动能提速排除表补 1/2（与 3/7/9 爆炸族同组）——此前 wt1 配方"慢速大粒扬尘 0.6s"被覆盖成"快小粒 0.34s"，现在配方语义落地（审计复核：f02 两侧中亮度带 +59%/+117%，扬尘驻留可读）。
2. **P2 `_apply_tier_scale` 注释链勘误**：docstring"×1.4 放大"/行注释"1.2"与实际值 0.85 三方矛盾——注释对齐实际行为（0.85 是 v18-v20 审计实测基线，行为不动），并注明与 WPV 贴图层 HEAVY ×1.3 的"粒子收/贴图放"分工，勿改成同向。
3. **P3 WPV 死粒子池三件套删除**：`_impact_particles`/`_active_impacts`/`MAX_ACTIVE_IMPACTS`/`_get_impact_ramp`/`_acquire/_release_impact_particle` 零调用方（v8.1 迁厂遗留，计数器只减不增），连带删除曲射 batch 恒不触发的 `>=200` 死守卫。特效上限由工厂活跃封顶承担。
4. **P3 `spawn_animated_nuclear` SpriteFrames 静态缓存**：原注释假设"核爆 CD 45s 低频"，实际每次火箭/高炮/导弹/曲射命中都调——每发 new SpriteFrames+6 贴图引用是稳定堆分配源。按首帧资源路径键缓存（调用方仅 WPV 两组 const 帧序列），构建一次永久复用。

**v20.27 遗留项修复**（改动：`vfx_impact_factory.gd` / `bullet.gd`；删除 `scripts/card_grid_fx.gd`）：

1. **命中分派统一，CardGridFx 退役**：bullet._on_hit 六处 `_rotates_with_direction` 分叉收敛到 `_spawn_tex_impact_at` 单链路——非旋转弹（光束 wt8）命中自此吃 spawn_laser_burn 烧灼签名而非旧三角闪光；CardGridFx 零引用后连文件删除（git 可找回）。
2. **窄锥命中火花读来弹方向**：`_spawn_sparks` 的 spark_dir 窄锥配方（步枪/狙击/激光）轴向从恒朝上改为沿入射线反弹回溅（opts.direction 取反）；360° 广播配方与无方向来源的 batch 路径保持原轴（观感零漂移）。
3. **敌方命中基色粉染→橙红**（`_impact_color` 25% lerp 改 `(1.0,0.55,0.25)`）——与弹体/环阵营橙统一（审计实测 f01_enemy 暖橙 6751px/粉紫 0px）。
4. **命中烟层 ADD→MIX**（`_spawn_debris` 烟分支 + `_spawn_smoke_puff_layer`，shrapnel v18-R9 同款理由：ADD 洗掉灰烟暗部读成白雾）——爆炸族"白团 300px 吞火球"的主病根，审计复核：有烟 debris 的族（f01/f03/f07）白雾退场、橙红火芯清晰可读；金属碎片族（f02/f09）不受影响做对照。**注意**：命中格"白色亮核"历史 AI 分数有相当部分是 ADD 烟贡献的，此后轮次解读分数变化先想到本条。烟云尺寸（~300px 暗烟）如需收紧是下一个单变量轮。

**v20.27 验证**：smoke 119/119；审计矩阵 72 格重跑，目视 f01（暗烟+橙芯）/f06（弹着环+回溅火花）达标，f02/f09 对照组不变，敌方命中区粉紫像素归零。

**v20.28 火花重力修复**（2026-08-29，改动：`vfx_impact_factory.gd`）：全厂 24 处 gravity 语义核对（侧视角）——烟上飘/碎片下坠/血溅下落/尘土回落全部正确，唯一违背认知的是 `_spawn_sparks` 主命中火花层零重力（池默认 0,0）：曲射/爆炸族 0.6-0.75s 慢速火花直线悬漂成"悬空萤火虫"。修复：`p.gravity = (0, 380)`——慢粒下坠 65-105px 出下坠弧（审计目视 f01/f03：火星沿烟球边缘坠向地面线），快粒（0.2-0.34s）仅 9-22px 轻微下垂观感不变；只影响命中主火花层（枪口火/闪光/血溅/暴击是独立函数各自设置）。顺手：磁轨穿透扬尘 (0,-20) 持续上飘→(0,40) 回落，与曲射扬尘同语言。**不要"顺手统一"其余向上层**：烟/热火花向上是正确语义。

### 相位仪/相位师技能树/敌方大招视觉检查 + 修复（2026-08-29，v20.29）

检查范围：`phase_instrument_abilities.gd`（1096 行）、`phase_master_skill_manager.gd`（纯状态无视觉，七类 unit_mechanism 视觉经 SignalBus 全部真实接线到 battle_spectacle，无一死链）、`enemy_master_skill_engine.gd`（1183 行六类演出）、工厂大招渲染三函数、`boss_spell_audit` 实拍 12 帧。**16 张 ult/spell 贴图全实存，内容宽表 PIL 实测零漂移；v20.15 战斗结束守卫/motion_reduce 分支全覆盖。**

**v20.29 已修复**（改动：`boss_spell_audit.gd` / `phase_instrument_abilities.gd` / `vfx_impact_factory.gd`）：

1. **P3-1 审计工具 mock boss 在原点**：`boss_spell_audit` driver=self 且从未设 position → `_get_driver_pos()` 恒回 (0,0)，主弹落点/传送门/闪电爆发等 boss 位效果全部炸在左上角——历史 boss 位截图与 AI 评分都是错位样本（目标侧效果正确故未察觉）。修复：独立 Node2D 摆到 BOSS_POS 作 driver（不能挪根节点，会带参考框/假目标一起移；plain Node2D 无 _flash_body_on_buff，has_method 守卫安全跳过）。重拍验证：主陨石落点爆炸/召唤传送门均正确落在右侧 boss 基地。
2. **P3-2 死守卫删除**：`_fire_nuclear_bombardment` 的 `fired_impact`/`captured_fired`——GDScript lambda 按值捕获 bool，守卫对外层无效且单回调本就只发一次。
3. **P3-3 巨盾呼吸罩缩放口径**：改用内容实宽（工厂新增公开查询 `spell_content_width()`），原用画布宽 1024 而内容 916，罩子比标称 300px 小 ~10%。

**记录级（不修）**：`spawn_spell_burst` 第 4 层烟是烟层最后一个 ADD（大招偏亮语义可接受，嫌发白可同 v20.27 切 MIX）；敌方护盾类演出偏薄（单环+闪光）vs 玩家巨盾——防御类低演出疑似有意；boss_spell_audit 启动日志两条 `_ready` 期间 add_child 报错（工具侧 cosmetic）。

**v20.29 补：boss 大招 AI 评分新基线**（新增 `tools/review_boss_spell_audit.py` + 修复 `review_vfx_realism._regex_verdict` 中文乱码）。mock boss 修复后首份有效基线：**平均 4.8/10**（24 帧 ×3 取中位，`docs/boss_spell_report.md` / `boss_spell_scores.json`；修复前 `ai_scores.json` 为错位样本仅作对照——如 meteor_land 旧 3→新 5）。最差项：**连锁闪电落地/余波 2/10**（审计 land 时刻 0.85s 偏晚，环/电弧/爆图全淡出；实战该时刻有 `_exec_chain_lightning` 跳弧补位，但 boss 爆发 0.7s 后到跳弧之间的空窗是真实观感问题）、**精准打击 after 3/10**（光矛 50px 规模感不足、金白配色与"神罚"语义脱节）。两者是下轮 VFX 调优的首选目标（按 vfx-tuning 五步走）。

**v20.30 最差项调优轮**（改动：`vfx_impact_factory.gd` / `enemy_master_skill_engine.gd` / `boss_spell_audit.gd`）：

1. **真 bug 修复：`spawn_smoke_column` 从未设贴图**——粒子用引擎默认白方块 ×scale 5-11 = 纯色方块流（战术核武/核爆核心/地狱烈焰的"烟柱"实为方块点阵；chain_land 帧的"红色方块"即上一案 inferno 烟柱串味）。修复：挂 SMOKE_GENERIC（128 画布/内容 106，PIL 实测），scale 0.30-0.62 → 32-66px 软烟团。
2. **审计时序校准**（skill 第 3 步）：chain land 0.85→0.68——环/电弧/爆图 ~0.85s 全淡出，旧 land 帧拍的是空场（2/10 主因）；settle 1.2→2.6s（烟柱 2.4s 发射期 > 旧 settle，上一案烟柱串进下一案）。
3. **神罚光矛 80→115px**——旧弹体比 96px boss 参考框还小（AI 批"体积极小/规模感不足"）。

**调优前后对比**（同帧降噪重评，注意单帧噪声 ±1-2 属正常，感知验收见截图）：chain land **2→5**、warn 5→6、flight 7→6（噪声带）；inferno after 6→7（烟柱修复）；single flight/land 4→5（光矛增体）。目视：chain_land 从空场变为完整雷暴（爆图+8 向电弧+冲击波环），inferno 烟柱为软烟团（红方块绝迹），光矛体量清晰。剩余弱项：single_after 3/10（余波帧只剩焦痕+激光残影，规模弱）、chain_after 3/10（审计构成先天限制——1.03s 处链式自身已散场；实战该窗口由 exec 跳弧填充）。基线存档：`boss_spell_*_baseline_v20.29.*`。

### 教程系统检查 + 修复（2026-08-30，v20.31）

检查范围：`tutorial_progression_manager.gd`（13 步 A 系统）、`tutorial_overlay.gd`、main.gd 教程 handler、`quest_definitions.gd` 教学任务（C 系统）。内容健康项：初始三卡（ww1_mauser/ww1_arty_m81/ww1_arm_ft17，v21.6 预装）、词条里程碑 Lv5/10/15/20/25/30（card_growth_config 每 5 级）、符文入口 `_open_backpack_runes_tab`、9 个 toggle 信号 handler、存档 v1→v2 门控全部核验无误。

**v20.31 已修复**（改动：`scenes/main.gd` / `data/quest_definitions.gd` / `managers/card_enhancement_manager.gd`）：

1. **P1 教程第 7 步"开始首战"按钮无效**：`SignalBus.start_level` 自创建以来零消费方——点击后无任何反应，教程跳到第 8 步而首战从未开始（新手关键路径断裂，战斗结束续播 8-13 步的设计也永不触发）。修复：main.gd 连接 `start_level` → `_on_start_level_from_tutorial`（设 `GameManager.set_current_level(level)` + `_battle_setup.on_start_battle()`，与"开始战斗"按钮同链路）。
2. **P2 `q_tutorial_law`"法则初探"不可完成**：objective_type=research_law 的唯一进度入口 `notify_law_researched()` 随法则系统 P2-7 退役后零调用方，任务接取后永不可完成。已删除定义；旧存档 accepted 残留 id 由 QuestManager 的 def.is_empty() 守卫安全跳过。
3. **P3 过时文案**：`q_collect_fragments_50`（"蓝图碎片"→拥有卡种数，title 改"收藏大家"）、`q_frag_smg`（"解锁卡牌蓝图"→收集战斗卡）——objective 早已适配、描述未同步；`card_enhancement_manager.gd` 头注从已退役的强化① v6.0 设计校正为 v20.12 现状（僵尸文件说明 + 勿新增功能警示）。

**验证**：`tests/_tmp_batch6_audio_tutorial_check.gd` ALL PASS（13 步数据/禁用词/存档门控/action 分支）；smoke 119/119；q_tutorial_law 零残留引用。

### 平衡性审查 + spetsnaz 补强（2026-08-30，v20.32）

全量数值审查（脚本 `tools/balance_audit_cards.py` / `balance_audit_mods_evo.py`，扫 223 卡条目 + 10 MOD 文件 + 8 进化文件；明细 `docs/_balance_dump_cards.json`）：时代/tier 递进、装甲-步兵 HP 关系、MOD 上限（attack_interval -0.40 恰在 v6.1 帽）、level_effects 单调、进化增长、敌我成长对称（双方共用 CardGrowthConfig 曲线，敌方配装 3/6/10 档乘区 1.14/1.28/1.63 为难度旋钮）——**全部 PASS，无硬伤**。已知非问题：fut_colossus/fut_arm_omega 同数值为弹道分流有意设计；DPS 离散警告均为对空/反坦克/守护者职能特化；battle_card_v3 的 era/star 倍率为死代码（唯一存活 enhance_stat_multiplier 供敌方配装轴）。

**修复**：cold_spetsnaz（阿尔法特种部队，ELITE）此前 hp238/atk60 全面劣于同 era VETERAN 步枪（324-346/86-92）且无机制补偿。补强至 hp300 / atk_l 96（对轻装全族最高）/ atk_a 45 / def 对齐 22/28/8——ELITE 身份=最快部署移速+最高对轻装 ATK+脆身板（hp 仍低于线列步兵为有意设计，**审查脚本对 era2 kind0 的 tier1>tier2 HP 倒挂告警属该设计预期，勿再当 bug 修**）。power 216 与实战强度自此一致。评分器降噪模式（--deterministic）为基线/对比必用。

### 关卡敌兵/相位师审计 + 战术主题失配修复（2026-08-30，v23.2~v23.3）

全链审计各关卡敌兵构成与敌方相位师配置（工具 `tools/audit_level_enemy_fun.gd`，报告落 `user://audit_level_enemy_fun.txt`，**改主题/tag/兵种相关数据前必重跑**）。相位师侧健康：20 驻守关套路全覆盖（手填 MASTER_PATTERN_MAP 是权威，`detect_pattern` 只是兜底——审计脚本误走兜底曾把 005/009/022 误报"无套路"）、平台时代一致、15% 随机遇敌链健壮。

**核心问题**：v10 战术主题（LevelTacticalThemes）bias tag 与敌池 tag 严重失配——artillery tag 原全游戏仅 2 单位持有、era0/1 fast 各 1 且在精英池、era1 零飞行单位 era2 唯一飞行单位在 boss 池 → 炮兵阵地/空中压制/斩首渗透三主题在多数时代退化为随机出兵（题面失实），全 100 关约 80 波 bias 落空。

**v23.2 修复三件套**（不动 boss/elite 分池、掉率、词缀）：
1. `enemy_archetypes.gd` 新增 `TAG_PATCH`（22 条 artillery/fast/stealth）+ 统一表 kind0 自动补 infantry；应用循环**必须独立于 v8.1 覆盖循环并剥 foe_ 前缀查统一表**（首版放覆盖循环内致 A 段补丁全部静默失效的踩坑已记录在 CHANGELOG）。
2. `level_tactical_themes.gd`：era1/2 移除 AIR_SUPREMACY（基础池无飞行单位，题面必真原则；空中主题只剩 era3/4）。
3. `battle_spawn_system.gd`：波次预警 `_bias_tags_match_era_pool` 校验，零匹配降级显示"混合"。

**v23.3 空中兵种误映射修复**：`_manifest_kind_to_combat_kind` 已删除——它是旧 manifest kind 语义（3=支援）的转换层，v8.1 后唯一效果是把统一表空中(3)误折叠为支援，侦察无人机/重装母舰/再生骨架三个真飞行单位被地面化。`_make_foe_row` 现直通 `s.kind`（统一表口径=CombatKind），`_tags_for_kind(3)` 改返 `["aircraft"]`。修后 aircraft 覆盖 era3/4 各 3 个（基础池有真题面）；**era3 普通关随机池自此可刷飞行单位、era4 新增 1400 血飞行重装母舰，玩家防空配置压力上升，建议实测体感**。

**v23.4 末波 boss 池扩充 + 波型时代感知过滤**：①TAG_PATCH 追加 6 条 boss 提拔——每时代末波从恒 1 只变 2 只（era4 三只：+重装机甲/虚空领主），提拔单位为"次级 boss"（血量 48%~89% 对标 + boss 词缀，掉落维持 8% 不开 55% 卡泉）；3158 血终极单位虚空领主此前混基础波当杂兵，提拔同时修正。②`roll_wave_bias` 增 era 参数做时代感知过滤——tag 零匹配的波型槽剔除，死 bias 波 21→**0**（v23.2 前为 80）。敌池查询走延迟 load。

修后死 bias 波 80→0；boss 池 2/2/2/2/3；GdUnit 145/145。

**记录级遗留（勿当已修）**：驻守 master 跨时代 HP ×1.8 跳变与档位回撤反向（有意威慑，L40→45 首战体感待实测）；Lv85 限支援/工兵上场，玩家支援卡储备量待实战验证；era3/4 防空压力上升待实测（见 v23.3 注）。

### 飞行单位战场表现升级（2026-08-30，v23.5）

飞行单位此前唯一空中感是 ±3px 浮动（脚踩地面线、无投影、死亡原地淡出）。v23.5 悬空化三件套——**核心决策：只抬 sprite 不抬 host**（射程是 2D 距离，抬 host 会注入 ~35px 系统漂移；抬 sprite 零玩法影响）：

1. **悬空**：`apply_battle_unit_presentation` 对 AIR 卡设 `unit_spr.position.y = -lift`（实体高×0.34，clamp 22-46px），写入 host meta `air_lift_y`；浮动 ±4px/1.7s。
2. **投影**：新增 `scripts/battle/air_unit_shadow.gd`（三层同心椭圆纯 _draw，零贴图），钉槽位地面线、随浮动呼吸、坠落时隐藏——**影子钉地 + 机身悬空 = 高度感**。
3. **坠落死亡**：`play_air_death_fall`（停浮动/杀 boss 摇摆/藏投影→翻转加速落地→爆散淡出），敌我 `_play_death_fadeout` 同构接入。

**配套对齐五个消费点**（改任何其一前先读 CHANGELOG v23.5 全表）：`aim_pos_for`（bullet 6 处 + 直射双 batch 方向/命中圈 + 曲射弧线终点——空中目标打空中爆炸不穿帮）、枪口出膛叠 `unit_spr.position.y`、`entity_top_y_for_sprite` 叠 sprite 位移（头顶 UI 随机身）。**顺手修**：枪口无标注回退点符号反转 bug（Vector2.UP×负值=落地面下方，两处）。

验证：gdparse 10/10、视觉锁 119/119、smoke 8/8、GdUnit 145/145；实机目视待游玩确认。遗留：伤害数字仍在槽位地面（HUD 信号传位，独立轮）；坠落无烟迹（可另开 VFX 轮）。

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

**铁律 1：养成操作（改造/进化）必须落在实例卡上，严禁直接改模板。**
- 实例判定：`card.instance_id` 非空（如 `cold_t72#1`）才是实例；为空则是共享模板。
- 改造面板 `_install_modification` 有 `instance_id.is_empty()` 守卫，拒绝操作模板。**新增任何养成操作必须加同款守卫。**（强化①面板及 `apply_reinforcement` 已随 v20.12 等级统一退役，见停用清单）
- 数据层 `BlueprintManager.install_modification(card, ...)` 写入传入 card 对象的养成字段——调用方必须保证传入的是实例，不是 `DefaultCards.get_card_by_id` 模板。

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
       _has_deploy_uses(部署身份键)  # v21.4 次数池按实例分池（键=instance_id，旧卡裸id）
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
- `managers/blueprint_manager.gd` — `install_modification`（写入传入实例的养成字段）/`get_all_blueprint_ids`（`apply_reinforcement` 已随强化①退役删除）
- `managers/phase_instrument_manager.gd` — `equip_card`（存实例对象）/`get_loadout_by_platform_card_id`（instance_id 精确匹配 + card_id 回退）/`_restore_loadout`
- `managers/battle/battle_spawn_system.gd` — `request_player_deploy`（上限用 base_card_id，loadout 用原 id）
- `scenes/ui/bottom_instrument_bar.gd` — `_on_slot_gui_input`（部署传 instance_id）
- `scenes/ui/growth_panel.gd` — `_load_unlocked_cards`（Registry 全集数据源 + 完整 instance_id 去重）
- `scenes/ui/modification_panel.gd` — `_refresh_card_list`（参考实现：分组+每实例一行）/`_install_modification`（守卫）
- `scenes/ui/card_info_panel.gd` — `_resolve_source_instance_card`（战场单位按 meta 取实例）

## ⚠️ 改任何 VFX（粒子/贴图/弹道视觉）前必读

**`.agents/skills/vfx-tuning/SKILL.md`** — v17 全轮踩坑复盘沉淀的强制五步铁律：
①先读历史评分报告（正确值就躺在 v12/v17 报告里）→ ②量贴图实寸（PIL 三行，禁按注释假设）→
③改特效前先校准测量（采样帧与寿命联动）→ ④单轮单变量 + AI 三次取中位 → ⑤感知验收优先于物理正确。
附参数参考表（本轮验证值）、弯路黑名单五条、工具链速查。2026-08-18 v17e 轮沉淀。
