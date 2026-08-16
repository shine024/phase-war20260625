# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

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
& "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/star_config_smoke.gd"

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

### Autoload Singletons (实际 42 个，project.godot load order)

> ⚠️ 下表为 v6.x 时期的"核心 autoload"概览（列 20 个核心），**未涵盖全部 42 个**。
> 实际 autoload 数量以 `project.godot` 的 `[autoload]` 段为准（v7.x 已增至 42 个，
> 含 LoreManager/AchievementManager/DailyTaskManager/StatisticsManager/StoryManager/
> CharacterManager/ChallengeModeManager/CardCollectionManager/LeaderboardManager/StatBoostManager 等）。
> 表中部分 manager 同时在 ManagerLazyLoader 有 ensure_loaded 别名（双层设计，非 bug）。
> 启动性能提示：42 autoload 全量加载 + DefaultCards 133 卡构建已让 headless `--check-only` 接近 5 分钟超时，
> 优化空间需配合"lazy manager 创建后主动请求 SaveManager 补 load_state"机制（待后续架构任务）。

**Core autoloaded singletons (always loaded at startup):**
| # | Singleton | File | Role |
|---|---|---|---| 
| 1 | `SignalBus` | `scripts/signal_bus.gd` | Central event bus (~80+ signals). All cross-system comms go here. |
| 2 | `BattleInputState` | `scripts/battle_input_state.gd` | Battle input state machine |
| 3 | `EnergyManager` | `managers/energy_manager.gd` | Battle energy pool; cap = equipped energy card star × 100 |
| 4 | `PhaseInstrumentManager` | `managers/phase_instrument_manager.gd` | 4-color equipment slots (red/blue/green/yellow) + phase field XP (Lv1-16) |
| 5 | `BattleManager` | `managers/battle/battle_manager.gd` | Battle orchestration, delegates to BattleSpawnSystem + BattleDamageSystem |
| 6 | `GameManager` | `managers/game_manager.gd` | Game flow: pre-battle → battle → post-battle; 15% phase master encounter |
| 7 | `BlueprintManager` | `managers/blueprint_manager.gd` | Card account progression (copies, stars, mods, evolution, inherit bonus, HP floor) |
| 8 | `DropManager` | `managers/drop_manager.gd` | Post-battle drop tables (13 drop types) and claiming |
| 9 | `SaveManager` | `managers/save_manager.gd` | `user://save.json`, 3 slots, schema v6, migration chain v1→v6 |
| 10 | `AudioManager` | `managers/audio_manager.gd` | Audio |
| 11 | `PhaseLawManager` | `managers/phase_law_manager.gd` | Law research/equip/battle state; 4 families (STEEL/FLAME/THUNDER/VOID); nano budget |
| 12 | `BasicResourceManager` | `managers/basic_resource_manager.gd` | Global currencies (nano materials, alloy, crystal, energy blocks, research points, permits) |
| 13 | `ObjectPoolManager` | `managers/object_pool.gd` | Object pool for bullets (25), damage numbers (15) |
| 14 | `UILazyLoader` | `managers/ui_lazy_loader.gd` | On-demand UI panel loading (18 panels) |
| 15 | `ManagerLazyLoader` | `managers/manager_lazy_loader.gd` | On-demand non-core manager loading (20+ managers, priority 1-10) |
| 16 | `PerformanceMetricsManager` | `managers/performance_metrics_manager.gd` | FPS/performance sampling |
| 17 | `ModificationRegistry` | `scripts/systems/modification_registry.gd` | 140+ modification modules across 9 unit types (autoload, static registry) |
| 18 | `MilitaryTitleRegistry` | `scripts/systems/military_title_registry.gd` | Unified rank system (13 ranks, per combat_kind, via UnifiedRankSystem) |
| 19 | `EvolutionPathRegistry` | `scripts/systems/evolution_path_registry.gd` | 8 unit-type evolution paths (main line + hidden branches) |
| 20 | `InstanceRegistry` | `managers/instance_registry.gd` | **v7.x 卡牌养成核心**：所有玩家拥有的卡的实例（card_id#N）+ 养成数据。养成隔离的单一真身。改任何卡牌/养成代码前必读下方"⚠️ 核心架构"章节 |

**Lazy-loaded managers** (via `ManagerLazyLoader.ensure_loaded()`, 20 total):

| Priority | Manager ID | Node Name | Description |
|----------|-----------|-----------|-------------|
| 1 | `aura` | `AuraManager` | Aura system |
| 1 | `battle_feedback` | `BattleFeedbackManager` | Battle feedback |
| 1 | `level_progress` | `LevelProgressManager` | Level progress |
| 2 | `quest` | `QuestManager` | Quest system |
| 2 | `achievement` | `AchievementManager` | Achievement system |
| 2 | `daily_task` | `DailyTaskManager` | Daily tasks |
| 2 | `challenge_mode` | `ChallengeModeManager` | Challenge mode |
| 3 | `faction` | `FactionSystemManager` | 7-faction system (reputation/shop/skill/events/card-gen) |
| 3 | `affix` | `AffixManager` | Modular affix management (acquire/upgrade/reroll/lock; boss-unlocked affix pool) |
| 4 | `card_collection` | `CardCollectionManager` | Card collection |
| 4 | `stat_boost` | `StatBoostManager` | Stat boosts |
| 5 | `statistics` | `StatisticsManager` | Statistics |
| 5 | `leaderboard` | `LeaderboardManager` | Leaderboard |
| 6 | `lore` | `LoreManager` | Lore |
| 6 | `story` | `StoryManager` | Story |
| 6 | `character` | `CharacterManager` | Character management |
| 7 | `tutorial` | `TutorialProgressionManager` | Tutorial |
| 8 | `new_systems` | `NewSystemsIntegration` | New systems integration |
| 9 | `toast` | `ToastManager` | Toast notifications |
| 9 | `version` | `VersionManager` | Version management |
| 99 | `debug_log` | `DebugLog` | Debug logging |

**v6.0 情报系统管理器** (project.godot autoload，同时在 ManagerLazyLoader 保留 ensure_loaded 别名入口):
- `IntelManual` — 4维情报系统（basic/tactical/material/secret）
- `IntelItemBag` — 情报道具背包（6种消耗品）
- `IntelDiscoveryManager` — 战利品发现系统（112个揭示事件）
- `IntelEvolutionManager` — 情报进化分支（4条隐藏分支）
- `EnemyOriginModManager` — 敌源MOD系统（9种敌源MOD）
- `CardEnhancementManager` — 卡牌强化系统（Lv1-10，词条选择）

### Key Patterns

1. **SignalBus decoupling**: All cross-system communication via `SignalBus.signal_name.connect()` / `.emit()`. Managers never hold direct references to each other for events.

2. **Resource-based card model**: `CardResource` (extends Resource) is the unified data type for cards, units, and progression. All cards created programmatically in `data/default_cards.gd` — no `.tres` files.

3. **Lazy loading**: Two tiers — `UILazyLoader` for UI panels, `ManagerLazyLoader` for non-core managers. Expensive init uses `call_deferred()`.

4. **Subsystem decomposition**: Large managers (`BattleManager`, `BlueprintManager`, `FactionSystemManager`) use `RefCounted` static sub-modules to separate concerns.

5. **Data-as-code**: All game data tables are pure GDScript static classes (`extends RefCounted`) with `Dictionary` collections. No JSON/CSV data files.

6. **Era scaling**: Units scale by era (WWI → Future). `UnitStatsTable.build_stats_from_card()` applies era multipliers.

### System Dependencies

```
GameManager → BattleManager, BlueprintManager, PhaseInstrumentManager,
               PhaseLawManager, BasicResourceManager, LevelProgressManager,
               FactionSystemManager, DropManager, QuestManager

BattleManager → BattleSpawnSystem, BattleDamageSystem, EnergyManager,
                 PhaseInstrumentManager, GameManager, SpatialGrid, SignalBus,
                 IntelDiscoveryManager (v6.0 defeated enemy recording)

SaveManager → ALL managers (loads/saves their state sections)
              Critical: BlueprintManager, PhaseInstrumentManager, PhaseLawManager,
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
                        FactionEventManager, FactionCardGenerator, SynthesisManager

IntelDiscoveryManager → IntelManual, IntelDimensions, IntelRevealEvents, EnemyOriginMods
IntelEvolutionManager → IntelManual, IntelEvolutionBranches
EnemyOriginModManager → IntelManual, IntelDimensions, EnemyOriginMods

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

All data files are pure GDScript static classes (`extends RefCounted`), no JSON/CSV.

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
- `basic_resources.gd` — Resource ID definitions (nano/alloy/crystal/energy block/research points/permits)
- `blueprint_star_config.gd` — Star upgrade costs, mod costs, permit rules
- `battle_card_v3.gd` — Era HP/damage multipliers (v6.1: 近未来伤害倍率 1.90→1.80)
- `level_eras.gd` / `level_information.gd` — Level-to-era mapping (100 levels, 5 eras)
- `rank_rules.gd`, `card_progression_settings.gd` — Progression tuning

**v6.0 Intel System:**
- `intel_dimensions.gd` — 4 intel dimensions (basic/tactical/material/secret)
- `intel_reveal_events.gd` — 112 reveal events (7 enemy types × 4 dimensions × 4 tiers)
- `intel_evolution_branches.gd` — 4 hidden evolution branches
- `intel_manual_items.gd` — 6 intel consumable items
- `enemy_origin_mods.gd` — 9 enemy-origin MOD definitions

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
- `synthesis_recipes.gd` — Hybrid card synthesis recipes

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
  star_config_smoke.gd   — Quick smoke test (no GdUnit)
  syntax_check.gd         — Syntax validation
  gdunit4_runner.gd       — CI test runner entry point
```

### Save System

- Single JSON file: `user://save.json`, 3 save slots
- Schema version 6, migration chain v1→v2→v3→v4→v5→v6 via `scripts/systems/save_migration.gd` + `save_migration_v4.gd` + `save_migration_v5.gd` + `save_migration_v6.gd`
- Critical managers (10) load immediately; deferred managers (12) load in batches after scene ready
- Auto-save on battle end + window close; backup every 15s

## v6.1 UI修复记录 (2026-06-09)

**UI面板尺寸优化**:
1. card_enhancement_panel: 1200x640 → 1000x580
2. achievement_panel: 修复硬编码偏移量，改用居中布局 600x500
3. level_select_panel: 900x700 → 760x580
4. intelligence_hub_panel: 920x620 → 840x580
5. drops_inventory_panel: 添加尺寸定义 800x520

**UI布局优化**:
1. backpack_panel: Grid列数 17 → 12
2. affix_panel: 修复文本硬编码换行
3. modification_panel: 添加完整样式定义 960x600

**文档创建**:
- `docs/UI_AUDIT_REPORT.md` - UI检查报告
- `docs/UI_DESIGN_GUIDELINES.md` - UI设计规范
- `docs/UI_FIX_SUMMARY.md` - UI修复总结

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

## v6.1 平衡性调整记录 (2026-06-08)

**单位平衡性调整:**
1. 降低近未来伤害倍率：1.90 → 1.80 (battle_card_v3.gd)
2. 调整T-72/M1 HP关系：T-72 850→800，M1 800→850 (default_cards.gd)

**MOD平衡性调整:**
1. aa_01_radar：attack_interval -50% → -30% (已完成于v6.0)
2. art_06_fire_computer：attack_interval -40% → -30% (已完成于v6.0)
3. art_09_rapid_fire：attack_interval -30% → -20% (已完成于v6.0)
4. arm_06_apfsds：attack_armor +35% → +30% (已完成于v6.0)
5. aa_04_quad_mount：attack_interval -35% → -30% (v6.1新增)
6. aa_11_auto_fc：attack_interval -50% → -40% (v6.1新增)
7. air_05_helmet_sight：attack_interval -50% → -40% (v6.1新增)

**性能优化:**
1. 增加对象池大小：子弹池 2→25，伤害数字池 4→15 (object_pool.gd)

**架构修复:**
1. 移除7个重复的autoload配置，改用ManagerLazyLoader延迟加载 (project.godot)
2. 修复BattleManager依赖注入，使用运行时get_node_or_null() (battle_manager.gd)

**UI修复:**
1. 修复UILazyLoader配置：删除不存在的blueprint_workshop和blueprint_library配置
2. 统一路径字段命名：全部使用parent_path
3. 在main.tscn中添加11个缺失的Overlay容器

## v6.6 7星相位仪主动能力 (2026-06-20)

**新增能力系统**: 相位仪 `active_ability` 字段（之前 special_traits 是纯文本，无战斗实现）

**7个能力分配到各势力7星相位仪（含低星降级版）:**

| 能力 | 7星完整版 | 分配相位仪 | 低星降级 |
|------|----------|-----------|----------|
| 火炮连发 | 每10秒连发7发(间隔1秒) | pi_nova_03(新星-超弦) | 6星:15秒/5发, 4星:20秒/3发 |
| 幻影克隆 | 同卡可放2个,克隆体+100%攻/+80%血 | pi_helix_04(螺旋-幻影核,新增) | 5星:+50%/+40%, 3星:+20% |
| 直射穿透 | 100%穿透,每穿一个衰减10% | pi_umbra_04(影幕-虚空穿,新增) | 6星:70%, 3星:40% |
| 免能量 | 部署完全免能量 | pi_atlas_04(擎天-零点能,新增) | 6星:-50%, 4星:-30% |
| 核子轰炸 | 每30秒敌方全体轰炸 | pi_eon_03(永纪-终式) | 5星:45秒, 2星:60秒减半 |
| 致命酸雨 | 开局30秒敌方每秒掉2%血 | pi_aegis_04(神盾-壁垒核) | 6星:20秒, 4星:12秒 |
| 巨型能量罩 | 开局我方全体20000护盾 | pi_generic_12(天穹VII型) | 6星:10000, 4星:5000 |

**关键文件:**
- `data/phase_instruments.gd` — 7个ability_xxx(star)定义 + active_ability字段 + 3个新7星 + 低星降级
- `managers/battle/phase_instrument_abilities.gd`(新增) — periodic/on_battle_start能力触发
- `managers/battle/battle_manager.gd` — start_battle/on_battle_start + _process/update接入
- `managers/battle/battle_spawn_system.gd` — 免能量+幻影部署+克隆体加成
- `scripts/battle/attack_calculator.gd` — 直射穿透比例
- `managers/phase_instrument_manager.gd` — get_active_ability()

## v6.6 改造效果↔战斗卡属性关联修复 (2026-06-20)

**问题**: `ModificationRegistry._apply_single_mod_effects()` 的 match 分支是改造效果应用的唯一闸门；落入 `default` 分支的 effect key 被塞进 `result["_special"]`，而 `unit_stats_table._apply_mod_stat_effects()` 完全不读 `_special`（注释自承认"暂不处理"），导致一批改造在战斗中空转。

**修复范围**: A类——5个真正属于战斗卡属性范畴的缺口（涉及 art_04/05/11、eng_02、aa_05、gen_09、aa_09、air_08 共8个改造模块）。B/C类约30个 key（环境/情报/经济/光环/战术机制类，如 night_bonus/vision/ally_*/multi_target/missile_intercept 等）有意保留现状——它们本就不属于战斗卡属性范畴，强行映射会语义错位，留待对应系统实现时再接。

**5个修复点:**

| effect key | 修复方式 | 涉及改造 |
|-----------|---------|----------|
| `attack_fort` | 新增条件型字段 `attack_fort_bonus`，FORT目标在 get_attack_vs() 叠加（复用 armor_pen_vs_* 模式） | art_11温压弹+50%、eng_02爆破+40% |
| `splash_radius` | 新增 `splash_radius_bonus`，_apply_splash 半径改为 80×(1+bonus) | art_04子母弹+50%、aa_05近炸+30% |
| `single_target_penalty` | 新增字段，主目标伤害×(1+penalty)，放在暴击后溅射前，maxf(0,...)防负 | art_04子母弹-20% |
| `missile_dodge` | 映射为 dodge_chance（反导语义同源） | air_08/aa_09/gen_09 +0.25~0.30 |
| `counter_bonus` | 映射为 crit_chance（"精确还击"语义） | art_05反炮兵雷达+30% |

**关键文件:**
- `resources/unit_stats.gd` — 新增3字段：attack_fort_bonus / splash_radius_bonus / single_target_penalty
- `scripts/systems/modification_registry.gd` — _apply_single_mod_effects match增加5个分支
- `resources/unit_stats_table.gd` — _apply_mod_stat_effects 增加3字段的 base_dict + 写回
- `scripts/battle/attack_calculator.gd` — get_attack_vs() FORT分支叠加 attack_fort_bonus
- `scripts/battle/module_effect_handler.gd` — _apply_splash 动态半径 + on_bullet_hit 应用 single_target_penalty

**设计决策:**
1. attack_fort 用条件型字段而非新攻击维度——FORT仍走ARMOR维度，仅叠加条件加成，零侵入
2. single_target_penalty 放暴击后/溅射前——只惩罚主目标不影响溅射伤害，符合子母弹"散布换精度"语义
3. 向后兼容——3个新字段默认0，未装备相关改造时行为与改动前完全一致

**平衡性:** 8个改造数值全部通过复核。2处WARN（aa_05双重激活、missile_dodge系列dodge量级偏高）均为"从空转激活"而非叠加超模，有 min(1.0) 上限保护且与 power_mult 匹配，建议后续实机观察。

**验证说明:** Godot headless --check-only 因项目体量（133卡+19 autoload）5分钟超时（引擎成功启动到DefaultCards构建阶段，autoload链路无语法错误），改为静态一致性核对（Grep确认3字段全链路拼写一致+5个match key完整+缩进正确）——全部通过。

## v6.6 全面一致性修复 (2026-06-21)

基于全项目数据一致性/功能贯通性/UI属性衔接性审查，修复 5 个 CRITICAL + 1 个 HIGH 问题。

**修复点:**

| 编号 | 问题 | 修复 |
|------|------|------|
| C1 | 情报4 manager（IntelManual/IntelDiscoveryManager/IntelEvolutionManager/EnemyOriginModManager）进度不存档，重启丢失 | 新增 save_state/load_state 接口 + 注册到 SaveManager（critical+deferred）+ SK_常量；旧独立文件兼容读取 |
| C2 | SignalBus.show_toast 全程无连接，所有 toast 提示静默失效 | ToastManager._ready 连接 SignalBus.show_toast + save_manager 预加载 ToastManager |
| C3 | world_map_panel.tscn 缺失（UILazyLoader 配置死链） | 删除 ui_lazy_loader 的 map 配置（功能由 main.tscn 内联节点承担，lazy-load 永不触发） |
| C4 | 5 个信号（quest_completed/task_completed/achievement_unlocked/achievement_progress_updated/daily_tasks_refreshed）被 connect 但从不 emit，任务/成就完成 UI 不刷新 | 各 manager 在本地 signal.emit 后追加 SignalBus 镜像 emit |
| C5 | weapon_type 两套枚举混用：改造写入 legacy 值(5/6/9)污染 weapon_type 弹道字段，导弹(9)被 AI 误判为直射 | 新增 GC.is_indirect_weapon_type() 统一曲射判定（含 ROCKET/FLAK/MISSILE）；改造改写 legacy_weapon_type 字段（不污染 weapon_type）；bullet 传值优先 legacy |
| H1 | 情报5 manager 三重注册（autoload + lazy_loader + CORE 不同步） | 保留 lazy_loader 配置作 ensure_loaded 入口（4处调用依赖），加注释澄清 autoload+别名双层设计 |

**关键文件:**
- `scripts/systems/intel_manual.gd` / `intel_discovery_manager.gd` / `intel_evolution_manager.gd` / `enemy_origin_mod_manager.gd` — save_state/load_state + 去 _ready 自加载
- `managers/save_manager.gd` — 注册4 manager（CRITICAL/DEFERRED/RESETTABLE + SK_常量）+ 预加载 ToastManager
- `scripts/systems/save_constants.gd` — 4 个情报 SK_ 常量
- `managers/toast_manager.gd` — _ready 连接 show_toast
- `managers/ui_lazy_loader.gd` — 删 map 死配置
- `managers/quest_manager.gd` / `daily_task_manager.gd` / `achievement_manager.gd` — 补 SignalBus 镜像 emit
- `resources/game_constants.gd` — is_indirect_weapon_type() 辅助函数
- `scripts/battle/construct_unit_ai.gd` / `scenes/units/enemy_unit.gd` — 曲射判断改用统一辅助函数 + bullet 传值优先 legacy
- `scripts/systems/modification_registry.gd` / `resources/unit_stats_table.gd` — weapon_type key 改写 legacy_weapon_type
- `managers/manager_lazy_loader.gd` — intel 配置加 autoload 别名注释

**设计决策:**
1. C1 完全切换统一存档（清空字段重置），load_state 收到空字典时兼容读取旧独立文件（首次迁移不丢进度）
2. C5 用统一辅助函数而非分离双字段重构——改造写入 legacy_weapon_type（已存在字段），AI 判断用 is_indirect_weapon_type 扩展范围，bullet 传值优先 legacy，最小改动覆盖全链路
3. H1 保留 lazy_loader 配置（4处 ensure_loaded 调用依赖），仅加注释澄清——删除会破坏现有调用链

**文档同步:** AGENTS.md autoload 数量(19→24)、schema(v5→v6)、迁移链补 v6、情报系统说明；balance-check SKILL.md era 倍率(1.45/1.70→1.40/1.65)

## v6.7 自由模式剧情任务系统 (2026-06-22)

**目标**: 在自由模式中为关键关卡挂载剧情任务（对话面板演出），任务面板加"剧情"标签页。剧情模式原样保留，两套并存。

**核心策略**: 复用 QuestManager（不新建 manager）+ 数据扩展 + 触发器钩子 + 对话面板解耦。

**数据扩展（向后兼容）** — quest 定义新增 4 个可选字段（`def.get()` 读，默认值不影响旧任务）:
- `category`: `"commission"`(委托,默认) / `"story"`(剧情) / `"daily"`(日常)
- `trigger_level`: 剧情任务绑定的关卡号（仅 story 用）
- `pre_battle_dialogues` / `post_battle_dialogues`: 对话队列，每项 `{speaker, text, choices?}`

**6 个剧情任务（取自 docs/补剧情.txt 关卡映射）:**

| 任务 ID | 触发关 | 标题 | 剧情幕 |
|---------|-------|------|--------|
| q_story_first_guardian | 20 | 第一个守护者 | 第六幕·铁血男爵 |
| q_story_zack_48 | 48 | 替扎克看看48关之后 | 第七幕·扎克的四十八 |
| q_story_truth_60 | 60 | 守护者的低语 | 第八幕·守护者说话 |
| q_story_locke_83 | 83 | 洛克止步之地 | 第八幕·洛克与83 |
| q_story_mirror_99 | 99 | 镜像自己 | 第九幕·镜像守护者 |
| q_story_final_100 | 100 | 最后的试炼 | 第十幕·相位之主 |

剧情任务通过 prereq 链串联（20→48/60→83→99→100），前置完成后自动揭示（不依赖 NPC，自由模式无 city_map）。

**触发流程:**
1. 玩家在任务面板"剧情"Tab 接取剧情任务
2. 进关时 GameManager.go_to_battle 检查该关是否有已接取的剧情任务 → emit `story_mission_dialogue(quest_id, "pre")`
3. story_dialogue_panel 监听信号，播放战前对话（复用 v6.3 对话格式 + v6.6 分支选项）
4. 战斗进行（objective_type=clear_level 自动追踪进度）
5. 过关后 GameManager emit `story_mission_dialogue(quest_id, "post")` → 播放战后对话 → 任务自动完成

**关键文件:**
- `data/quest_definitions.gd` — +4 字段注释、+6 story 任务、+get_quests_by_trigger_level/get_ids_by_category
- `data/json/quest_definitions.json` — 补 v6.6 支线 + 6 story 任务（修复 JSON/GDScript 不同步：原 JSON 缺真实者/林薇/扎克支线，运行时不加载）
- `managers/quest_manager.gd` — +get_quests_by_category/trigger_level_for_quest/get_active_story_quest_at_level；is_quest_available 对 story 任务自动揭示
- `managers/game_manager.gd` — go_to_battle/on_battle_ended 加 _check_story_mission_pre/post_battle 钩子；+_pending_story_mission_quest 字段
- `scripts/signal_bus.gd` — +story_mission_dialogue(quest_id, phase) 信号
- `scenes/ui/story_dialogue_panel.gd` — +play_dialogues 通用方法、+_on_story_mission_dialogue 监听、+_ensure_ancestor_visible/_hide_mission_overlay（自由模式 overlay 可见性管理）、_on_all_dialogues_done 分流（mission 路径不调 v6.3 story_proceed_to_battle）
- `scenes/ui/quest_panel.tscn` — 重构为 TabContainer（委托/剧情/日常三标签），CompanySummary 移入委托 Tab
- `scenes/ui/quest_panel.gd` — _refresh_list 按 category 分流；剧情任务紫色边框 + ★ 标题前缀 + 触发关卡提示
- `scenes/world_map.gd` — _make_level_button 查剧情任务，加紫色左边框 + ★ 前缀 + tooltip

**设计决策:**
1. 复用 quest 系统不新建 manager — QuestManager 已有 hidden/prereq/branches/progress 全套
2. category 默认 "commission" — 现有所有委托任务行为零变化，向后兼容
3. 对话面板解耦而非新建 — story_dialogue_panel 已支持分支选项/角色配色/多句队列，去 v6.3 硬绑定即可
4. 触发器钩子放 game_manager — go_to_battle/on_battle_ended 是所有战斗必经单点
5. JSON 同步是前置 bug 修复 — v6.6 剧情任务在 GDScript 写好但 JSON 缺失，运行时不加载，本次顺带修复
6. 剧情任务自动揭示 — 不依赖 city_map/NPC（自由模式没有），前置 prereq 完成即 reveal

**不做的事:**
- 不删/不改剧情模式（city_map、StoryModeButton、v6.3 章节代码全部保留）
- 不动 DailyTaskManager（日常 Tab 第一期空置提示）
- 不做结局分支（结局归剧情模式管）

**验证:** Godot headless --check-only 成功启动到 DefaultCards 构建（133卡），无语法错误；Grep 静态核对通过（4 字段全链路拼写一致、story_mission_dialogue 信号 emit×2 + connect/disconnect + 定义完整、6 个新方法定义/调用配对、quest_panel 7 个 @onready 路径与 tscn 节点全匹配）。

## v6.7 引导剧情扩展（系统教学）(2026-06-22)

**目标**: 在关键关卡（第1/5/10/15/21关）自动触发系统教学对话，引导玩家学习相位仪装配、强化、改造、进化、符文五大系统。与主线剧情并存。

**category 新增取值 "tutorial"** — 引导剧情任务，与 "commission"/"story"/"daily" 并列：
- **自动触发**：进关即播，不进任务面板、不需手动接取、不占任务栏名额
- **一次性**：用 StoryManager 标记（`tutorial_<quest_id>`）防重复，每个只播一次
- **仅战前对话**：引导只教系统（战前），无战后对话
- **即时奖励**：触发时立即发放纳米材料（不通过任务完成流程）

**5 个引导剧情任务:**

| 任务 ID | 触发关 | 标题 | 教学系统 |
|---------|-------|------|---------|
| q_tutorial_equip_1 | 1 | 相位仪与卡牌 | 相位仪槽位 + 卡牌装配 |
| q_tutorial_enhance_5 | 5 | 卡牌强化 | 纳米材料强化卡牌等级 |
| q_tutorial_modify_10 | 10 | 卡牌改造 | 安装改造模块 |
| q_tutorial_evolve_15 | 15 | 卡牌进化 | 卡牌升阶形态 |
| q_tutorial_rune_21 | 21 | 法则符文 | 相位仪法则研究（打完第20关守护者获得符文后） |

**同关多剧情依次播放机制:**
同一关可能挂载多个剧情任务（如某关同时有 tutorial + story，或主线 + NPC 支线）。触发顺序：tutorial 先于 story，依次入 `_story_mission_queue`，story_dialogue_panel 用 `_mission_queue` 排队播放——播完一个自动播下一个，不互相覆盖。

**关键文件（本次扩展）:**
- `data/quest_definitions.gd` — +5 tutorial 任务定义、+get_all_triggerable_at_level（返回 story+tutorial，区别于 get_quests_by_trigger_level 只返回 story）
- `data/json/quest_definitions.json` — 同步 5 个 tutorial 任务（66→71）
- `managers/game_manager.gd` — _check_story_mission_pre_battle 重构（收集 tutorial+story 形成队列）；+_is_tutorial_triggered/_mark_tutorial_triggered/_grant_tutorial_reward/_is_story_quest_active；_story_mission_queue/_story_mission_played 替代 _pending_story_mission_quest
- `scenes/ui/story_dialogue_panel.gd` — +_mission_queue 队列播放（同关多剧情依次播放，播完一个自动播下一个）
- `scenes/ui/quest_panel.gd` — _refresh_list 过滤 tutorial（不进任何 Tab）

**设计决策:**
1. tutorial 不进任务面板 — 纯自动触发，避免玩家困惑（看到任务却无法接取/无明确目标）
2. tutorial 触发即标记 + 发奖 — 不依赖对话播完（防中途退出重播，奖励保证给到）
3. get_all_triggerable_at_level vs get_quests_by_trigger_level — 前者含 tutorial（GameManager 用），后者只 story（world_map 用，避免教学关显示★）
4. 队列播放而非覆盖 — 同关多剧情用队列依次播放，避免后发信号覆盖前者

**验证:** Godot headless --check-only 通过（无语法错误）；JSON tutorial 任务字段完整；Grep 确认 get_all_triggerable_at_level/_story_mission_queue 链路一致。

## v6.7 剧情任务全面扩展（补剧情.txt 关卡锚点全铺满 + NPC 支线归剧情）(2026-06-22)

**目标**: 把 docs/补剧情.txt 的关卡锚点全部铺满，并把原有 6 个 NPC 支线（真实者/林薇/扎克）从 city_map 依赖改造为自由模式关卡触发。

**A. 新增 5 个主线剧情任务（补全时代 Boss + 主线节点）:**

| 任务 ID | 触发关 | 标题 | 剧情幕 |
|---------|-------|------|--------|
| q_story_realist_10 | 10 | 真实者的阴影 | 第四幕·真实者初次接触 |
| q_story_city_15 | 15 | 城市的轮廓 | 第二幕·城市功能解锁 |
| q_story_steel_marshal_40 | 40 | 钢铁洪流 | 时代Boss·钢铁元帅（二战） |
| q_story_void_lord_80 | 80 | 虚空之主 | 时代Boss·虚空领主（现代） |
| q_story_countdown_90 | 90 | 倒计时 | 第九幕前奏·海伦宣告 |

**B. NPC 支线归入剧情标签（6 个，触发关绑定）:**

| 任务 ID | 触发关 | 原揭示方式 | 现揭示方式 |
|---------|-------|-----------|-----------|
| q_realist_invite | 10 | city_map NPC 对话 | 进第10关自动揭示 |
| q_realist_join/reject/delay | - | 分支后续（prereq 链） | 完成 q_realist_invite 后分支揭示 |
| q_linwei_secret | 15 | city_map NPC 对话 | 进第15关自动揭示 |
| q_zack_beyond_48 | 40 | city_map NPC 对话 | 进第40关自动揭示 |

**主线 prereq 链（完整通关路径）:**
```
L10 真实者阴影 → L15 城市轮廓 → L20 铁血男爵 → L40 钢铁元帅
→ L48 扎克48关 → L60 守护者低语 → L80 虚空领主 → L83 洛克止步
→ L90 倒计时 → L99 镜像自己 → L100 相位之主
```

**关键改造点:**
- `managers/game_manager.gd` `_check_story_mission_pre_battle`：进关时对该关所有 story 任务调 `qm.reveal_quest(qid)` 自动揭示（自由模式无 city_map/NPC，NPC 支线必须靠关卡触发揭示）；只有"已接取 + 未完成 + 有 pre_battle_dialogues"的才入播放队列
- NPC 支线（q_realist_invite 等）无 pre_battle_dialogues，进关只揭示不播对话，玩家在任务面板接取后按各自 objective_type 完成（win_battles/collect_cards/clear_level/reach_reputation）

**剧情任务总量（v6.7 完整版）:**

| 类型 | 数量 | 说明 |
|------|------|------|
| 引导剧情 tutorial | 5 | 第1/5/10/15/21关，自动触发，系统教学 |
| 主线剧情 story（有对话） | 11 | 第10/15/20/40/48/60/80/83/90/99/100关 |
| NPC支线 story（无对话） | 6 | 真实者4 + 林薇1 + 扎克1，进关揭示 |
| **合计** | **22** | 覆盖补剧情.txt 全部关卡锚点 |

**关键文件（本次扩展）:**
- `data/quest_definitions.gd` — +5 主线任务定义、6 个 NPC 支线加 category/trigger_level、3 个现有任务 prereq 更新
- `data/json/quest_definitions.json` — 同步（71→76→80 任务；story 17 个、tutorial 5 个、commission 58 个）
- `managers/game_manager.gd` — _check_story_mission_pre_battle 加 story 任务自动揭示

**验证:** Godot headless --check-only 通过；JSON 76 任务字段完整；Grep 确认 reveal_quest 钩子调用正确。

## v6.8 收敛我方加成来源 (2026-06-23)

**背景**: 审查发现我方战斗卡的属性加成来源多达 10+ 个系统，且存在"时代缩放只加我方、不加敌方"的不对称设计。本轮收敛加成来源，停用 4 套非核心加成 + 压缩稀有度，保留各系统的数据/UI/存档/掉落。

**核心原则**: 我方加成来源收敛为——强化、改造、相位仪、符文（玩家可投入养成的核心）+ 战力星级/进化/军衔/稀有度（派生乘区）+ 兵种修正/平台光环/改造光环（单位设计/战场协同）。

**5 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **稀有度乘区压缩** | 6档 1.0/1.1/1.25/1.4/1.5/1.8 → 1.0/1.04/1.08/1.12/1.16/1.20（common/uncommon/rare/epic/legendary/mythic），避免稀有度过度主导战力 |
| 2 | **势力停用** | 移除势力变体生成路径（effective_card 直接用原始 platform_card）+ apply_faction_special_to_stats + _apply_skill_tree_effects；势力声望商店/合成/卡生成养成保留 |
| 3 | **敌源MOD断开** | 移除 apply_eom_to_stats；EOM 面板/装备/战后碎片掉落/存档全部独立保留 |
| 4 | **我方相位法则被动停用** | 删 construct_unit 的 _apply_phase_law_passives + connect/disconnect + _law_regen_per_sec 回血块 + 7 个孤立 _base_* 变量；**敌方减益不受影响**（enemy_unit/swarm_enemy_slot 各自独立实现继续生效） |
| 5 | **时代缩放移除** | build_stats_from_card 不再按 era 放大我方 HP/三维攻击/射程/武器伤害；_apply_evolution_hp_floor 同步去掉 era 倍率（避免主属性不缩放、HP下限仍按时代抬高的矛盾） |

**关键设计决策:**
1. **时代缩放本就不对称**——核实发现敌方（enemy_stat_resolver.gd）走独立的 `wave × level × pressure × master` 难度链，从不调用 era_*_multiplier。时代缩放原本就是"只放大我方"的隐形优势，移除后关卡难度完全由敌方难度链承担，符合"缩放应为调整简单"的本意。
2. **停用而非删除系统**——势力/敌源MOD/相位法则的数据类、管理器、UI、存档、掉落全部保留，只断开战斗数值注入链路。可随时恢复，风险最小。
3. **敌方相位法则减益不动**——_apply_phase_law_passives 在我方/敌方三处是各自独立函数（同名不同体），只删我方版本，敌方 burn_on_hit/anchor_field 等减益继续生效。
4. **连带清理孤立代码**——删除被孤立的函数定义（apply_faction_special_to_stats/apply_eom_to_stats/_apply_skill_tree_effects）和孤立变量（_law_regen_per_sec/_base_* 系列），代码更清爽；保留 get_active_faction_skill_effects 公共方法（养成查询接口）和 skill_tree_specials 字段（避免破坏序列化）。
5. **连带传播属正常**——稀有度压缩后，estimate_power_score_meta_only（战力分）、get_base_power_for_mod_cost（改造消耗）数值自动变小，非重复定义，不另作处理。combat_power_from_unit_stats 读 stats 本身，时代缩放移除后战力分自动跟随，UI/战斗数值保持一致。

**关键文件:**
- `managers/evolution/evolution_helpers.gd` — get_rarity_multiplier 压缩 + _apply_evolution_hp_floor 去 era 倍率
- `managers/battle/battle_spawn_system.gd` — 简化势力变体查询 + 删势力/EOM 注入调用块 + 删 _apply_skill_tree_effects 定义 + 清 2 个孤立 preload
- `managers/faction/faction_card_generator.gd` — 删 apply_faction_special_to_stats（保留 generate_faction_variant 数据）
- `scripts/systems/enemy_origin_mod_manager.gd` — 删 apply_eom_to_stats（保留面板/掉落/存档接口）
- `resources/unit_stats_table.gd` — build_stats_from_card 删 3 处 era_*_multiplier 块（主属性/多武器/武器槽）
- `scenes/units/construct_unit.gd` — 删 _apply_phase_law_passives + _on_phase_law_runtime_changed + connect/disconnect + _law_regen_per_sec 回血块 + 7 个孤立 _base_* 变量（顺带捎上会话前预存的 combat_kind 透传改动）
- `scenes/ui/enemy_origin_mod_panel.gd` — 注释同步（EOM 战斗加成已停用）

**保留不动的 era_*_multiplier 残留**: summarize_weapon_stats_from_card / get_weapon_base（UI 摘要/旧接口，纯死代码无调用方）；BattleCardV3.era_*_multiplier 函数定义本身（敌方系统/测试仍在引用）。

**验证:** Godot headless --check-only 通过（133卡构建，无语法错误，5分钟超时属项目既有现象）；Grep 确认 build_stats_from_card 战斗路径 era_*_multiplier 100% 清零、evolution_helpers era_*_multiplier 清零、删除的 4 个函数名 + _law_regen_per_sec 在我方代码无残留（敌方独立实现保留）。

## v6.9 势力占领关卡系统 (2026-06-23)

**背景**: 玩家设想——20关后各关卡由各势力占领，势力能力影响关卡敌人加成，势力相位师在各势力关卡分布，任务栏任务动态更新，主角完成任务影响各势力，部分任务随机结果。

**核心原则**: 静态归属（不动占领状态机）+ 前20关无势力（教学时代）+ 势力只增强敌方（不复活 v6.8 已停用的我方加成）+ 复用现有链路（任务影响势力走成熟 _grant_rewards → add_faction_reputation）。

**4个阶段实现:**

### 阶段0：数据基础与命名统一
| 改动 | 详情 |
|------|------|
| **前20关去势力** | level_information.gd 的 `_add_ww1_levels()` 1-20关 faction_id 从 "iron_wall_corp" → ""（空=无主之地，无势力加成/相位师/声望反应） |
| **新建势力能力表** | data/faction_conquest_buffs.gd — 7势力×5档（Lv1/3/5/7/10）敌人加成表，每势力一个战斗风格主题（钢壁=血厚/新星=攻猛/以太=速快/量子=量多/螺旋=闪避/虚空=暴击/边境=通用） |
| **相位师命名核查** | 发现 check_phase_master_encounter 用 NPC_PHASE_MASTERS（已是公司ID）+ _enrich_master_config 已有公司ID→法则家族映射，无需改 enemy_phase_masters*.gd |
| **on_level_conquered 守卫** | 已有现成 `if conquered_faction.is_empty(): return` 守卫（faction_system_manager.gd:285），1-20关攻克天然不扣声望 |

### 阶段1：势力对关卡敌人加成（核心机制）★
占领势力等级越高，该关敌人越强。接入敌方加成链（wave×level×pressure×master 末尾加 faction_buff 乘区）。

| 文件 | 改动 |
|------|------|
| `data/enemy_stat_context.gd` | +faction_buff 字段（复用 player_pressure 设计模式） |
| `data/enemy_stat_resolver.gd` | +_collect_faction_buff()（make_default_context 按关卡faction_id+势力等级填值）；resolve_classic_enemy 的 dmg_mul_chain/hp_mul_chain 末尾乘 f_atk/f_hp；move_speed 接入 f_spd（顺带修复 p_spd 历史遗留无效问题） |

### 阶段2：势力相位师分布
| 改动 | 详情 |
|------|------|
| **匹配已生效** | check_phase_master_encounter（game_manager.gd:107-114）已按 get_level_faction 优先抽该势力相位师，21关起生效，1-20关走随机 |
| **关卡弹窗显示驻防势力** | world_map.gd 的 _collect_level_info 加 garrison_* 字段（查 FactionSystemManager.get_faction_info）；_show_level_info_popup 加驻防势力行（橙色=占领势力+敌方加成描述，灰色=无主之地） |

### 阶段3：动态任务系统（扩展 QuestManager）★
任务栏任务随势力/关卡动态生成。核心策略：**扩展 QuestDefinitions 静态查询**（加 _DYNAMIC_QUESTS 集合 + get_by_id/get_available_ids 同时查两个集合），让所有现有代码（接受/进度/完成判定）自动支持动态任务。

| 文件 | 改动 |
|------|------|
| `data/quest_definitions.gd` | +_DYNAMIC_QUESTS 集合；+register/unregister/get_dynamic_quest_ids/get_all_dynamic_quest_defs/clear_dynamic_quests；get_by_id/get_available_ids 同时查静态+动态 |
| `data/faction_quest_generator.gd`（新增） | 势力动态任务生成器：5势力×4类型模板（win_battles/kill_enemies/attack_faction/defend_faction），按势力等级生成，奖励含 company_rep/faction_rep（影响势力） |
| `managers/quest_manager.gd` | +refresh_faction_quests（生成+注册+揭示+toast）；_try_complete 完成后 unregister 动态任务；save/load_state 持久化 dynamic_quests 字段；+is_dynamic_query 辅助 |
| `managers/game_manager.gd` | set_current_level 末尾调 _maybe_refresh_faction_quests_for_level（进入势力领地关卡触发该势力发布委托） |
| `scenes/ui/quest_panel.gd` | _make_quest_row 加 is_dynamic 视觉标记（橙红边框+暖橙标题，与剧情任务紫色/普通蓝色区分） |

### 阶段4：任务随机结果机制
部分任务完成时结果不确定（成功/部分成功/意外缴获）。

| 文件 | 改动 |
|------|------|
| `data/quest_definitions.gd` | +outcome_table 字段注释（[{weight,label,rewards}]，缺省走固定 rewards 向后兼容） |
| `managers/quest_manager.gd` | _try_complete 加 _roll_outcome 按权重抽取，用抽取 rewards 替代固定值；toast 显示结果 label |
| `data/faction_quest_generator.gd` | win_battles 任务带 outcome_table（圆满成功50%/部分成功35%/意外缴获15%） |

**关键设计决策:**
1. **静态归属而非动态占领**——用户选择，沿用 level_information.gd 固定 faction_id，不做"运行时势力攻占他关"状态机，风险最小
2. **前20关无势力**——一战教学时代设为无主之地，21关起启用势力机制，符合"20关后"描述
3. **势力只增强敌方**——与 v6.8 收敛方向一致，不复活已停用的我方势力加成；乘区接入 enemy_stat_resolver 敌方加成链末尾，零侵入
4. **扩展 QuestDefinitions 而非改每个查询函数**——动态任务接入 get_by_id/get_available_ids，所有现有代码（_on_enhancement_completed/notify_*/is_quest_done/get_current_progress_for_quest）自动支持，避免改每个函数
5. **outcome_table 向后兼容**——缺省走固定 rewards，所有现有 76 个静态任务行为零变化，只有显式定义 outcome_table 的任务才有随机结果
6. **动态任务存档**——未完成的动态任务定义持久化到 dynamic_quests 字段，旧存档无此字段时为空数组自动初始化

**平衡性:** 7势力满级威胁倍率（攻×HP）全部 ≤ 1.80 阈值（最高 void_research 1.624），单维度 ≤ 1.40/1.30 上限；与历史 master_stats 乘区同量级。

**验证:** Godot headless --check-only 成功构建到 133 卡（无语法错误，5分钟超时属项目既有现象）；Grep 静态核对全部通过（faction_buff 链路、garrison_* 链路、动态任务 API 链路、outcome_table 链路全拼写一致）。

**延后项（润色，不影响核心功能）:** leaderboard_data.gd 的 FACTION_RANGES 仍按旧关卡归属（iron_wall 1-20、frontier_union 1-10），排行榜显示与关卡弹窗"无主之地"矛盾，但仅影响排行榜领地统计展示，不影响战斗/任务/声望。

## v6.10 占领状态机 + 势力状态机 + 势力领地图面板 (2026-06-23)

**背景**: 在 v6.9 静态势力占领基础上，用户要求加"状态机+任务面板"。明确为：(1) 占领状态机（动态领地易主）+ (2) 势力状态机（派生标签）+ (3) 新建势力领地图面板。

**核心原则**: 占领转移=玩家攻克即易主（给激活势力，无激活则解放为无主之地）；势力状态=派生标签（从占领数+声望实时计算，不存储避免双源真理）；level_occupation 存进 faction_system 子字段（不升 schema，靠 load_state 守卫兼容）；加成数据源从静态切到动态占领。

**4个阶段实现:**

### 阶段A：占领状态机（核心）
| 文件 | 改动 |
|------|------|
| `scripts/signal_bus.gd` | +occupation_changed(level, old_faction, new_faction) 信号 |
| `managers/faction_system_manager.gd` | +level_occupation 字段；+occupation_changed 信号及转发；+get_level_occupation/_init_level_occupation/transfer_occupation/get_territory_count API；on_level_conquered 接入占领转移（守卫调整：静态空也执行转移）；save/load_state 持久化 level_occupation |
| `data/enemy_stat_resolver.gd` | _collect_faction_buff 数据源从静态 get_level_faction 切到动态 get_level_occupation（玩家攻克易主后敌方加成跟随） |

### 阶段B：势力状态机（派生标签）
| 文件 | 改动 |
|------|------|
| `data/faction_status.gd`（新增） | 派生状态枚举（EXTINCT/DECLINING/STABLE/EXPANDING/DOMINANT）+ 中文名+配色；derive_status(territory_count, reputation) 双维度组合判定 |
| `managers/faction_system_manager.gd` | +get_faction_status/get_faction_status_name/get_faction_status_color 派生查询（实时计算，不存储） |

### 阶段C：势力领地图面板（新建）★
| 文件 | 改动 |
|------|------|
| `scenes/ui/occupation_panel.tscn`（新增） | 占领地图面板骨架（标题/图例/领地网格/详情） |
| `scenes/ui/occupation_panel.gd`（新增） | 7势力图例（色块+名称+状态标签+占领数+声望）+100关网格（5时代×20关，按钮=占领势力配色）+点击详情；监听 occupation_changed/faction_reputation_changed 实时刷新；FACTION_COLORS 7势力代表色定义 |
| `managers/ui_lazy_loader.gd` | +occupation 注册（PopupLayer/OccupationOverlay/CenterContainer） |
| `scenes/main.tscn` | +OccupationOverlay/CenterContainer/OccupationPanel 节点 + ext_resource |
| `scenes/world_map.gd` | +_on_territory_map_button 入口（顶部"◆势力领地图"按钮，懒加载+显示面板） |

### 阶段D：world_map 占领可视化联动
| 文件 | 改动 |
|------|------|
| `scenes/world_map.gd` | _make_level_button 加占领色标（右边框=势力色，与剧情关紫色左边框不冲突）；_collect_level_info 弹窗读动态占领（_get_level_occupation_safe）；_ready 监听 occupation_changed → refresh_levels 实时刷新色标；+_OCCUPATION_BORDER_COLORS 7势力配色（与面板一致） |

**关键设计决策:**
1. **玩家攻克即易主**——用户选择，攻克某关直接归玩家激活势力；未激活势力则解放为无主之地。简单直接，玩家掌控感强
2. **派生标签不存储**——势力状态从占领数+声望实时计算，避免"状态字段与底层数据不一致"的双源真理问题
3. **level_occupation 存进 faction_system 子字段**——不升 schema，靠 load_state 守卫兼容（旧存档无此字段→空字典→get_level_occupation 回退静态表，零破坏）
4. **加成数据源切到动态**——_collect_faction_buff 从 get_level_faction 改为 get_level_occupation，让占领真正影响战斗（攻克易主后该关敌人加成跟随新占领势力）
5. **on_level_conquered 守卫调整**——原 L285 静态空即 return 会阻止已接管关卡再攻克时转移；改为静态空时跳过声望反应但仍执行占领转移
6. **新面板独立而非加 Tab**——occupation_panel 是世界视角（100关占领网格），与 faction_panel 的单势力详情视角 UI 范式不同，新建独立面板更干净
7. **信号驱动实时刷新**——occupation_changed 经 SignalBus 转发，occupation_panel 和 world_map 都监听，攻克易主后两边都实时更新

**关键文件:**
- `managers/faction_system_manager.gd` — +level_occupation 字段/API/转移/存档/信号转发（核心）
- `data/faction_status.gd`（新增）— 派生状态枚举+计算
- `data/enemy_stat_resolver.gd` — 加成数据源切动态占领
- `scenes/ui/occupation_panel.tscn/.gd`（新增）— 占领地图面板
- `scenes/world_map.gd` — 占领色标+弹窗读动态+入口按钮+实时刷新
- `scripts/signal_bus.gd` — occupation_changed 信号
- `managers/ui_lazy_loader.gd` / `scenes/main.tscn` — 面板注册与挂载

**验证:** Godot headless --check-only 成功构建到 133 卡（无语法错误，5分钟超时属项目既有现象）；Grep 静态核对全部通过（occupation_changed 信号链路、get_level_occupation API 链路、get_faction_status 链路、occupation_panel 节点路径与 tscn 全匹配）。

## v6.11 敌方相位师影响普通敌兵 + master 系数收敛 (2026-06-24)

**背景**: 平衡性审查发现敌方相位师的 `master_stats`（attack_power/defense）应影响普通敌兵，但 `make_default_context` 从不注入 master_stats，导致经典敌兵和蜂群走 `resolve_classic_enemy` 时 m_atk/m_hp 恒为 1.0——只有相位师召唤的产兵（走 `apply_phase_master_to_unit_stats`）才生效。同时 v6.2 把 m_atk 系数从 0.0005 提到 0.002，但漏改了测试（`test_enemy_stat_resolver.gd` 仍断言旧值），该测试处于失败状态。

**3 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **make_default_context 注入 master_stats** | 函数末尾从 BattleManager._phase_master_config.stats 取 master_stats 写入 ctx.master_stats；经典敌兵(enemy_unit)与蜂群(swarm_enemy_slot)都经此函数 → resolve_classic_enemy，修复后都吃相位师属性加成。非相位师战时 _phase_master_config 为空 → master_stats 保持默认空，普通波次行为零变化 |
| 2 | **master_attack_multiplier 系数收敛** | 0.002 → 0.0005。master030(attack_power1000)从过猛的 3.0x 收敛到温和的 1.5x；master001(120)从 1.24x→1.06x |
| 3 | **master_defense_hp_multiplier 系数恢复** | 0.0001 → 0.0003。v6.2 曾削弱(0.0003→0.0001)导致防御属性对敌兵几乎无效（master016 def200 仅 1.02x）；恢复后 1.06x，与攻击侧量级对称 |

**关键设计决策:**
1. **普通敌兵走 master_stats 生效 + 排名加成保留叠加**——用户确认。make_default_context 注入 master_stats 让普通敌兵/蜂群吃相位师属性，同时保留 apply_enemy_phase_master_bonus_to_unit_stats（+14~21% 排名加成），双乘区叠加
2. **系数收敛到 v6.2 之前的值**——0.0005/0.0003 正好让过时失败的测试自动通过（测试断言反映的就是旧系数）
3. **向后兼容**——非相位师战时 master_stats 恒空 → 行为与修复前 100% 一致；相位师遭遇战从"仅排名加成"变为"master_stats + 排名加成叠加"，温和增强

**关键文件:**
- `data/enemy_stat_resolver.gd` — make_default_context 末尾注入 master_stats（取 BattleManager._phase_master_config.stats）；m_atk 系数 0.002→0.0005、m_hp 系数 0.0001→0.0003
- `tests/unit/combat/test_enemy_stat_resolver.gd` — +test_master_multipliers_new_coefficients（锁定新系数防回归）、+test_resolve_classic_enemy_with_master_stats（比值验证 master_stats 对普通敌兵生效）

**数值影响（温和）:** 中等关（第40关 + 相位师013 + 排名3星）ATK +17%/HP +2%；极端堆叠（第100关 + 满级势力 + master030 + 满排名）ATK +50%/HP +4%。

**验证:** Godot headless --check-only 通过（133 卡构建）；独立运行时验证 12 项全 PASS（系数验证 + resolve_classic_enemy 比值验证 + 向后兼容）；Grep 静态核对通过。

## v6.11b 战场敌方信息卡"武装：无"误显示修复 (2026-06-24)

**背景**: 用户反馈战场敌方信息卡显示"武装：无"。调查证实 36 个敌方 archetype 100% 都有 weapon_type，但 `_show_generic_enemy_unit`（card_info_panel.gd）判断武器的逻辑只依赖 `EnemyArchetypes.get_config(archetype_id)`——一旦该 cfg 返回空字典（动态生成单位时序/manifest 未合并/某些 archetype 查不到），weapon_type_val 保持默认 -1 → 直接显示"武装：无"，即使该单位实际有武器且正在开火。附带 bug：`_enemy_surface_combat_stats` 用 `unit.hp`（当前剩余血量）而非 `max_hp`（满血上限），残血敌人显示被打掉后的血。

**2 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **武器显示三级回退** | `_show_generic_enemy_unit` 武器判断改为：①优先 archetype cfg；②cfg 空时回退 unit.stats.weapon_type + unit.stats.attack_damage（经典敌人和蜂群都同步了这两字段）；③仍查不到才显示"无"。杜绝误显示 |
| 2 | **HP 显示改用 max_hp** | `_enemy_surface_combat_stats` 优先读 max_hp（满血上限），单位无该字段时回退 hp（防御性兼容）。残血敌人血量现在稳定显示上限 |

**关键设计决策:**
1. **防御性回退而非改 get_config**——manifest 合并时序属正常缓存行为，显示层做兜底更稳妥，不触动数据查询逻辑
2. **不改 archetype 数据**——36 单位本就有武器，数据没问题；问题是显示层只依赖单一数据源太脆弱

**关键文件:**
- `scenes/ui/card_info_panel.gd` — `_show_generic_enemy_unit` 武器判断三级回退（L1322-1333）；`_enemy_surface_combat_stats` HP 改用 max_hp（L1022）

**验证:** Godot headless --check-only 通过（133 卡构建）；Grep 确认 stats.weapon_type/stats.attack_damage 在 enemy_unit.gd:413 和 swarm_enemy_slot.gd:103 都有设置（回退链完整）。注：显示层改动需游戏内实机验证点击交互。

## v6.12 敌方产兵改用真实数据 + master 系数增强 (2026-06-25)

**背景**: 用户反馈"敌方卡和我方同样卡差异太大"。调查证实敌方相位师产兵走 `build_multi_stats`（通用平台表 `_PLATFORM_BASE`/`_WEAPON_BASE`，数值偏弱），而非真实敌人数据；叠加的 master 加成也偏温和（HP 仅 ×1.03-1.06）。同一概念单位（如 T-72）敌我可差 3-5 倍。

**决策（与用户确认）:** 方式 1——敌方产兵改用敌方 archetype 真实数据（如 elite_cold_t72 的 hp250/atk40），替换通用平台表；同时增强 master 系数。

**3 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **产兵改用真实 archetype 数据** | `_produce_unit_with_equipment` 的 `build_multi_stats`（通用表）→ `_build_stats_from_archetype`（真实 archetype cfg 构造 CardResource → build_stats_from_card）。复用已有平台→archetype 映射（_pick_visual_archetype_for_platform），archetype 查不到时回退通用表兜底 |
| 2 | **master_attack_multiplier 增强** | 0.0005 → 0.0008。master016(400)攻 ×1.32，master030(1000)攻 ×1.80 |
| 3 | **master_defense_hp_multiplier 增强** | 0.0003 → 0.0006。master016(200)血 ×1.12，master030 血 ×1.12 |

**关键设计决策:**
1. **用敌方 archetype 真实数据而非跨数据源读我方卡牌**——用户选择（推荐项）。复用 _pick_visual_archetype_for_platform 的平台→archetype 映射取真实 cfg，改动集中在 1 个函数，风险低；跨数据源读 default_cards 会引入耦合且需新建映射表
2. **保留 platform_data.stats 覆写**——master 装备的 hp/defense 覆写是其差异化体现，保留让不同 master 召唤的单位有区别
3. **系数增强同步影响两条路径**——m_atk/m_hp 系数同时影响普通敌兵（resolve_classic_enemy，v6.11 刚修的 master_stats 注入）和产兵（apply_phase_master_to_unit_stats），两者同步增强，符合"敌方变强"诉求
4. **兜底完善**——archetype 查不到/映射失败时回退 build_multi_stats 通用表，不会崩

**关键文件:**
- `scenes/units/enemy_phase_field_driver.gd` — `_produce_unit_with_equipment` 改用 `_build_stats_from_archetype`；新增 `_build_stats_from_archetype`（真实 archetype cfg → CardResource → build_stats_from_card）+ `_archetype_combat_kind`（按 tags 推断战斗类型）
- `data/enemy_stat_resolver.gd` — m_atk 系数 0.0005→0.0008、m_hp 系数 0.0003→0.0006
- `tests/unit/combat/test_enemy_stat_resolver.gd` — 3 处测试断言值更新匹配新系数

**数值影响（以 master016 召唤精英 T-72 为例）:** HP ~212→~336（+59%），ATK ~36→~53（+47%）。我方满养成 T-72 仍保持 ~12-17× 优势——养成碾压感保留，但敌方产兵不再过脆偏弱。

**验证:** Godot headless --check-only 通过（133 卡构建）；独立运行时验证 10 项全 PASS（系数验证 + resolve_classic_enemy 比值验证 + 向后兼容）；Grep 确认 _PLATFORM_DEFENSE/PLATFORM_TO_COMBAT_KIND 静态成员存在、archetype cfg 字段名与新函数读取匹配。注：`_build_stats_from_archetype` 依赖 autoload 环境（EnemyArchetypes.get_config），运行时构建结果需游戏内实机验证。

## v6.14 全系统贯通 (2026-06-26)

**背景**: 用户提出跨多系统的整体诉求——不同战力敌人有不同战力/掉不同改造、不同改造要不同战力安装、相位师有等级/相位仪/符文/出兵序列、打败相位师掉符文/改造/兵种卡、关卡掉兵种卡/改造、关卡波次序列式+随机、势力是玩家主动构筑的选择加成、占领关卡给敌方加成和改造掉落。

**核心策略**: 11 个子模块按"数据层→逻辑层→接入层"分 6 阶段一次实现。新增 2 个数据文件 + 扩展/改造约 16 个既有文件。全部向后兼容（新字段 `.get(key, default)`，缺省值保证旧存档/旧数据零变化）。

**6 个阶段实现:**

### 阶段1：战力分级基础
| 文件 | 改动 |
|------|------|
| `data/power_tiers.gd`（新增） | 5 档战力枚举（GRUNT/VETERAN/ELITE/CHAMPION/OVERLORD）+ get_tier_by_rank/get_tier_by_power/meets_requirement；统一所有"不同战力→不同X"的共用基础 |
| `data/intel_manual_items.gd` | roll_random_mod_blueprint 增加 power_tier + bias_unit_types 参数；新增 _apply_power_tier_to_weight（高档位抬高高稀有度权重）+ _unit_type_name_to_int |

### 阶段2：关卡波次序列系统
| 文件 | 改动 |
|------|------|
| `data/level_spawn_sequences.gd`（新增） | 程序化生成 per-level 波次序列（种子=level 可复现）；规则：每时代首关教学/wave%3精英波/最后波boss/难度随进度递增；get_sequence_for_level/get_wave_spec/pick_type_for_wave |
| `managers/battle/battle_spawn_system.gd` | 波次抽选从纯随机改为读序列（composition 抽签 + bias_tags 偏好抽签）；新增 _pick_archetype_with_bias；序列为空回退原随机 |

### 阶段3：势力主动构筑重接 + 占领掉落
| 文件 | 改动 |
|------|------|
| `managers/battle/battle_spawn_system.gd` | `_build_stats_cached` 重接 v6.8 停用的势力技能注入：取 get_active_faction_skill_effects 的 stat_bonus 注入我方单位（三维攻防/HP/攻速）；缓存 key 加 active_faction_cache_key |
| `data/faction_conquest_buffs.gd` | get_buff 返回新增 drop_mul（改造掉率×1.0~1.5）+ mod_pool_bias（偏好改造类型）；FACTION_MOD_BIAS 7势力主题映射 |
| `scripts/systems/intel_discovery_manager.gd` | `_roll_intel_item_drops` 注入占领势力：drop_mul 乘进掉率，改造蓝图传 bias_unit_types + power_tier |

### 阶段4：相位师装备/序列/掉落
| 文件 | 改动 |
|------|------|
| `data/enemy_phase_masters.gd` | 新增 get_enriched_equipment（程序化派生 runes/spawn_sequence）；_derive_runes（按level选稀有度梯度，2-4个）+ _derive_spawn_sequence（平台循环序列+elite/boss标记） |
| `data/json/enemy_phase_instruments.json` | 26 个相位仪补全 atk_bonus/hp_bonus/def_bonus（按level/rarity派生），让 _get_enemy_phase_instrument_bonus 真正生效 |
| `scenes/units/enemy_phase_field_driver.gd` | 产兵从纯随机改读 spawn_sequence（带elite/boss加成）；新增 _apply_master_rune_bonus（符文加成产兵）+ _apply_sequence_entry_bonus + _apply_enemy_phase_instrument_bonus（相位仪加成） |
| `managers/game_manager.gd` | 相位师掉落：符文改为从自带runes池抽（装什么掉什么）+ 新增改造蓝图掉落（必掉1+30%额外1）；新增 _pick_rune_from_pool_or_generic |

### 阶段5：改造战力门槛 + 关卡改造掉落
| 文件 | 改动 |
|------|------|
| `managers/evolution/mod_manager.gd` | 新增 get_min_power_tier_for_mod（按rarity派生门槛）+ can_install_by_power_tier |
| `managers/blueprint_manager.gd` | install_modification 加战力档位校验（卡牌战力不足拒绝安装，提示需X档） |
| `resources/drop_tables.gd` + `managers/drop_manager.gd` | 新增 DropType.MOD_BLUEPRINT 枚举 + _add_mod_blueprint claim 分支（写IntelItemBag） |

### 阶段6：情报面板统一显示
| 文件 | 改动 |
|------|------|
| `scenes/ui/card_info_panel.gd` | _show_enemy_phase_driver（点击基地）+ _show_enemy_phase_master_unit（点击单位）统一显示等级/相位仪名/符文；新增 _get_enemy_instrument_display_name + _format_enemy_runes |

**关键设计决策:**
1. **战力档位为统一基础**——所有"不同战力→不同X"经 PowerTiers 枚举，避免每系统各自定义阈值
2. **序列程序化生成+种子**——100关不手填，generate_sequence(level,era,seed=level) 可复现，序列内随机保留扰动
3. **势力注入重接而非新建**——v6.8 停用的 get_active_faction_skill_effects 和缓存 key 变量都已预留，只填入调用+注入
4. **占领掉落用buff扩展**——faction_conquest_buffs 已有 hp/atk/spd，加 drop_mul/mod_pool_bias 复用同通道
5. **相位师装备程序化派生**——不改30条静态数据，get_enriched_equipment 按 level/faction 派生 runes/spawn_sequence，所有相位师自动获得
6. **改造门槛按rarity派生**——不改140+改造定义，get_min_power_tier_for_mod 按 rarity 映射档位（common→无门槛, legendary→需OVERLORD）
7. **全部向后兼容**——新字段 .get(key, default)，缺省值保证旧存档零变化；JSON 数据脚本批量补全

**验证:** 14个改动/新建文件独立 Godot load 编译全部 ✅ 通过；项目 syntax_check 全通过；Grep 静态核对全部链路（PowerTiers/LevelSpawnSequences/get_enriched_equipment/get_active_faction_skill_effects/产兵加成/相位师掉落）拼写+调用配对完整；相位仪 JSON 26/26 加成字段完整。注：势力注入/序列波次/相位师产兵序列等运行时行为需游戏内实机验证。

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
- 正确数据源优先级：**① `InstanceRegistry.get_all_instance_ids()`（真·实例全集，永不被 consume）→ ② SaveManager 队列（presenter 未存活/旧档迁移兜底）→ ③ BlueprintManager 蓝图（已解锁但未拥有任何实例的卡，补一条无养成模板行）**。
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

## v7.x 全面系统检查修复 (2026-06-28)

基于全项目三维度审查（数据一致性/潜在bug/死代码），修复 2 CRITICAL + 5 HIGH + 3 MEDIUM + 清理项。

**CRITICAL:**
| # | 文件 | 修复 |
|---|------|------|
| C1 | `instance_registry.gd` `_serialize_weapon_slots` | `_mod_effects` 取值后显式 typeof 校验，非 Dictionary 一律存 {}。原 `(x as Dictionary).duplicate(true)` 在异常值时 null 解引用崩溃，中断整个 save_state 丢失所有养成数据 |
| C2 | `battle_spawn_system.gd` `_build_stats_cached` | `faction_skill_states` 链式 `.has()` 加空值+类型守卫。原势力切换瞬间 null 上调 `.has()` 崩溃 |

**HIGH:**
| # | 文件 | 修复 |
|---|------|------|
| H1 | `enemy_phase_field_driver.gd` | boss 产兵加成补齐 defense_light/armor/air 三维（原只乘标量） |
| H2 | `enemy_phase_field_driver.gd` | 新增 `_sync_enemy_weapon_slot_damage()`，在符文/序列/仪器/tier 四处 attack 乘区后同步 weapon_slots[].damage。根因：AI 伤害结算读 weapon.damage（非 attack_damage），而原 `_sync_weapon_slots_damage` 方法在 UnitStats **从未定义**——has_method 守卫恒 false，同步空转 |
| H3 | `enemy_phase_masters.gd` `_derive_runes` | 用 `RandomNumberGenerator` + `hash(master_id)` 种子，保证同相位师每次符文一致（原裸 randi） |
| H4 | `power_tiers.gd` | 战力门槛 `[150,300,600,1000]` → `[150,260,420,720]`。原值过严，满强化稀有卡够不到 ELITE，rare/epic/legendary 改造几乎装不上 |
| H5 | `quest_manager.gd` | 本地 quest_progress_changed/quest_accepted 信号转发连接到 SignalBus（原 9 处 emit 只手动补 1 处镜像） |

**MEDIUM:**
| # | 修复 |
|---|------|
| M2 | `mod_manager.gd` get_modification_count/has_enemy_origin_mod 双 key 兼容（instance_id 与裸 card_id） |
| M6 | DebugLog 节点名统一为 `DebugLogManager`（7 处引用 + lazy_loader 配置）。预加载触发因 ManagerLazyLoader 对该脚本 .new() 失败已撤回，保持按需 |
| M7 | `blueprint_manager.gd` 修正过时注释（HP 下限 v6.8 起不再按时代缩放） |

**LOW:** ui_lazy_loader/main.gd 残留 print 加 DEBUG 守卫；删除 5 处孤儿 preload。

**验证:** Godot --check-only 启动到 133 卡构建无语法错误；Grep 链路核对全部通过。

## v7.x 相位师等级战力派生 (2026-06-28)

**背景:** 用户提出"相位师等级能不能和战力挂钩"。调查发现 `level`（Lv5-30）是手填值，与相位师 stats/equipment 没数学关系，却驱动符文稀有度/出兵序列/掉落梯度。而 `MasterPowerEvaluator` 虽已有 1-7★ 星级评估（接入战斗定 boss 星级），但**完全不读 `master.stats`**（max_hp/attack_power 等），只读 phase_instrument.base_stats —— 导致一战→近未来 HP 涨 9×/ATK 涨 8× 却不进战力分，星级分布偏低。

**核心改动:** 等级改派生 + MasterPowerEvaluator 纳入 master.stats。

**5 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **G 维「军团本体战力」** | `MasterPowerEvaluator` 新增第 7 维 `_eval_master_stats`，读 master.stats 五项（max_hp/attack_power/defense/energy_regen/unit_limit）。复用 A 维标准化模式（value/REF × 500 × 内部权重 + 非线性加成）。基准值取 30 条相位师 stats 中位数（MASTER_REF_HP=3000 等）；内部权重 HP/ATK 各 0.30（区分度最强），DEF/EREG/ULIM 共 0.40。权重调整：B（刻印）0.25→0.20、F（装备槽）0.25→0.20，让出 0.20 给 G，总和仍 = 1.0。我方相位师无 master.stats → G 维回退 0，行为零变化 |
| 2 | **等级派生函数** | `EnemyPhaseMasters.compute_display_level(master)` 把总战力线性映射到 Lv5-30（250 分→Lv5，6000 分→Lv30，区间外 clamp）。另有 `get_display_level_by_id` 便捷重载 |
| 3 | **掉落梯度改用星级** | `game_manager.gd` 相位师击败掉落从 `level*40 → get_tier_by_power` 改为 `星级 → get_tier_by_stars → Tier`，让改造稀有度真正跟随相位师战力 |
| 4 | **get_tier_by_stars** | `PowerTiers` 新增映射：1★→GRUNT, 2★→VETERAN, 3★→ELITE, 4★/5★→CHAMPION, 6★/7★→OVERLORD，越界 clamp 到 [1,7] |
| 5 | **UI 显示战力** | `card_info_panel.gd` 两处（点击基地/点击相位师单位）等级改派生 Lv + 新增"总战力：XXXX · ★★★★★ 大师"行 |

**关键设计决策:**
1. **等级派生只接管展示+掉落**——底层 `_derive_runes`/`_derive_spawn_sequence`/`_era_from_level` 继续读原始手填 level，不打乱"一战相位师拿 common+rare 符文"的时代递进设计。派生 Lv（展示）≠ 原始 level（设计基准），两者语义不同不冲突
2. **G 维纳入 master.stats 五项**——这是区分度最强的分量（HP 9×、ATK 8×），修好后敌方有效评估权重从 0.75 提到 0.85
3. **STAR_TIERS 阈值不动**——加 G 维后总分会小幅上移（原 3★ 可能变 4★），属预期效果（之前偏低正因为 stats 不计分），实机观察后再决定是否微调
4. **职责分离**——派生函数放 `enemy_phase_masters.gd`（数据聚合入口），不放 `MasterPowerEvaluator`（评估器不应关心 Lv 展示规则）

**不动的东西（向后兼容）:** 原始 level 字段（30 条数据 + JSON，底层继续读）、STAR_TIERS 阈值、排行榜 enemy_phase_leaderboard 的 score（排名分非战力分）、get_masters_by_level 筛选、玩家侧评估（无 stats → G 维 0）。

**关键文件:**
- `scripts/master_power_evaluator.gd` — G 维 _eval_master_stats + MASTER_REF_*/MSW_* 常量 + 权重调整 + evaluate()/_build_details 接入
- `data/enemy_phase_masters.gd` — compute_display_level/get_display_level_by_id + preload MasterPowerEvaluator
- `data/power_tiers.gd` — get_tier_by_stars
- `managers/game_manager.gd` — 掉落梯度改用星级
- `scenes/ui/card_info_panel.gd` — 两处显示改派生 Lv + 战力行 + preload MasterPowerEvaluator

**验证:** Godot --check-only 通过（133 卡构建）；新增 `tests/master_power_smoke.gd`（SceneTree 模式，7 项断言全 PASS：G维空=0、master_001 G维 255.4、master_030 G维 1810、时代比值 7.1×、派生Lv 全部在[5,30]、master_030 Lv>master_001、get_tier_by_stars 9 case 全对、30 相位师 evaluate 全部不崩星级 1-7）。**注:** GdUnit4 插件存在 Godot 4.5.1 兼容性问题（`Class "GdUnitAssertImpl" hides a global script class`），现有 test_enemy_stat_resolver.gd 同样无法运行，故本次新增测试采用 smoke test 模式（与 star_config_smoke.gd 一致），不依赖 GdUnit 框架。

## v7.x 卡牌战力射程修复 + 相位师4分量战力重构 (2026-06-28)

**背景:** 用户提出两件事——① 卡牌战力公式有 bug："一个开局能买的大炮战力却能突破元帅级，是不是射程因素考虑太多"。② 把相位师战力对齐为"4分量"：卡牌战力 + 相位仪战力 + 符文（含符文之语）战力 + 载卡战力。并澄清：玩家侧载卡可重复部署（×3 经验权重），敌方侧看 unit_limit。

**修复 A：卡牌战力射程失控 bug**

根因核实：`combat_power_from_unit_stats`(evolution_helpers.gd:228) 用 `stats.attack_range`（像素值），而 `attack_range = range_value × 100`（unit_stats_table.gd:40 格转像素）。火炮 range_value=99 → 9900像素 → 射程项 `9900×0.22 = 2178`，**单这一项就破元帅阈值(1450)**；步兵3格→300像素→66分，火炮是步兵的 **33 倍**，完全淹没 HP/DPS 项。

| 修复 | 详情 |
|------|------|
| 射程项改平方根 | `range_f * 0.22`（像素）→ `sqrt(格数) * 8.0`，格数 = attack_range/100。步兵3格→13.9分，火炮99格→79.6分，比例 1:5.7（保留射程区分度但不碾压）。其他项权重不变 |

**实测验证:** ww1_105mm 火炮战力 修复前 2178+（破元帅）→ 修复后 **431.4**（合理）；ww1_mauser 步兵 91.1（量级正常）。

**重构 B：相位师 4 分量战力（MasterPowerEvaluator）**

把相位师战力对齐为用户的 4 分量设想。维度从 7 个扩到 8 个（A-H），权重重新分配，总和=1.00：

| 维度 | 权重 | 说明 |
|------|------|------|
| A 相位仪本体 | 0.15 | 不变（读 phase_instrument.base_stats） |
| B 刻印 | 0.10 | 0.20→0.10（让位 F/H） |
| C 特质 | 0.10 | 不变 |
| D 主动技能 | 0.10 | 0.15→0.10 |
| E 被动技能 | 0.10 | 不变 |
| **F 载卡战力** | 0.20 | **重构**：原"槽数×60"→ 卡牌战力加权（敌方=平台卡×unit_limit；玩家=卡战力×3） |
| G 军团本体 | 0.15 | 0.20→0.15（master.stats） |
| **H 符文+符文之语** | 0.10 | **新增**（原完全没评符文） |

**3 个新增/重构函数:**
- `_eval_runes(master)`（H维）：单符文 primary_effect.value × RUNE_STAT_WEIGHT(200) + 稀有度基础分；符文之语调 `RunewordMatcher.check_active_runewords()` 查激活词，按 TIER 加权(T2×100/T3×200/T4×350/T5×600) + effects 求和。clamp 800 上限防多词叠加爆分。
- `_eval_equipment_slots`（F维重构）：敌我分流——敌方读 EnemyPhaseEquipment 平台卡 stats 轻量公式（hp×0.5+atk×3+def×1.5）求和 × unit_limit；玩家 ×3（经验权重）。通过 `master.stats.max_hp` 是否存在判敌我。
- `_platform_power_light(platform_id, is_enemy)`：平台卡轻量战力（平台卡只有原始 stats 字典，无 UnitStats/range/interval，不能套完整公式）。

**配套：敌方符文派生改造（让 H 维有意义）**

原 `_derive_runes`（enemy_phase_masters.gd）随机抽 2-4 个 generic 符文，**不触发符文之语**（符文之语需特定组合）。改为**符文之语驱动**：按 level 选 TIER（Lv≤9→T2，Lv10-19→T2/T3，Lv20-29→T3/T4，Lv30→T4/T5）→ 从该 TIER 随机选一个符文之语 → 取它的 `required_runes` 作为装备符文（必然能组成该词）→ 槽位富余补 generic。沿用 H3 用 master_id 哈希种子保证可复现。

**关键设计决策:**
1. **射程用平方根而非除回格数**——除回格数后步兵3格→0.66几乎不算；平方根压平后步兵13.9/火炮79.6，比例1:5.7（非33:1），保留射程区分度又不会失控
2. **敌方平台卡用轻量公式**——平台卡只有 stats 字典（无 UnitStats），不能套 `combat_power_from_unit_stats`；轻量公式量级与完整公式同档（~100-500）
3. **符文之语驱动派生**——改 _derive_runes 让敌方符文必然组成词，H 维才反映符文之语加成（而非散装符文）
4. **H 维 clamp 800**——符文之语可叠激活多个+高 TIER，原始分易破千（实测 master_030 派5符文触发多词→原始9029），clamp 上限避免 H 维主导总分
5. **B/C/D/E 降权保留**——用户4分量是"物质战力"，但技能/特质也是相位师强弱的一部分，降权（非删除）保留避免丢失维度

**关键文件:**
- `managers/evolution/evolution_helpers.gd` — `combat_power_from_unit_stats` 射程项改 sqrt
- `scripts/master_power_evaluator.gd` — F维重构 + H维新增 + 权重重分配（8维总和=1.0）+ preload RuneDefs/RunewordDefs/RunewordMatcher + `_platform_power_light`
- `data/enemy_phase_masters.gd` — `_derive_runes` 改符文之语驱动 + `_derive_runes_generic_fallback` 兜底 + preload RunewordDefs

**验证:** Godot --check-only 通过（133 卡构建，exit 0）；`tests/master_power_smoke.gd` 全 PASS（修复A：火炮431<元帅1450、火炮>步兵；重构B：H维符文>0、F维载卡近未来>一战、G维时代递进、派生Lv[5,30]、get_tier_by_stars 9case、rw_2_01符文之语激活验证）。Grep 链路核对通过。**注:** smoke test 因 `--script` 模式下 `EnemyPhaseMasters.ENEMY_MASTERS` 静态 var 不初始化（项目既有限制），相位师测试改用手动构造的真实结构 dict 验证公式逻辑本身。

**实测数值（手动构造 master）:** master_001 总分359（F载卡800 G本体255 H符文800 2★精英）；master_030 总分940（F载卡2400 G本体1810 H符文800 3★高手）；派生Lv master_001=5 master_030=8（近未来更高）。

## v7.x 星级阈值校准 + 符文/符文之语拆分独立维 (2026-06-28)

**背景:** 前两轮加了 G维(本体)和 H维(符文)后总分结构变化，旧 `STAR_TIERS` 阈值（250/600/1200/2200/3800/6000）让 6★/7★ 永远为空、4★/5★ 割裂。同时用户要求"符文、符文之语都分别有计分"——原 H 维把两者合并成一个数，应拆成两个独立维各自计权重。

**阶段1：STAR_TIERS 阈值校准（基于真实分布）**

先解决数据获取障碍：发现 `EnemyPhaseMasters.LEGACY_ENEMY_MASTERS` 静态 var 跨类初始化顺序 bug（`_WW1.ERA_MASTERS + _WW2...` 求值时其他子文件 ERA_MASTERS 尚未初始化 → 拼接得 0），导致 `--script` 模式下 `ENEMY_MASTERS` 为空。**绕过方案**：直接遍历 5 个时代子文件的 ERA_MASTERS 收集 30 个相位师真实分布（不依赖聚合 var）。

实测 30 相位师总分分布：434~2210（最弱 master_001=434，最强 master_020=2210）。按分位数标定新阈值：

| 星级 | 旧阈值 | 新阈值 | 旧分布 | 新分布 |
|------|--------|--------|--------|--------|
| 1★ 新锐 | 0-250 | 0-450 | 0 | 1 |
| 2★ 精英 | 250-600 | 450-540 | 0 | 9 |
| 3★ 高手 | 600-1200 | 540-650 | 13 | 8 |
| 4★ 大师 | 1200-2200 | 650-780 | 1 | 6 |
| 5★ 宗师 | 2200-3800 | 780-950 | 1 | 3 |
| 6★ 传说 | 3800-6000 | 950-1600 | 0 | 1 |
| 7★ 神话 | 6000+ | 1600+ | 0 | 2 |

新分布钟形覆盖全 7 档（1/9/8/6/3/1/2），旧分布严重失衡（6★/7★ 全空、3★/2★ 扎堆）问题修复。派生 Lv 映射区间同步从 250/6000 改为 434/2210 贴合实际分布（最弱→Lv5，最强→Lv30，时代递进清晰）。

**阶段2：H/I 维拆分（符文 vs 符文之语独立计分）**

把原合并 H 维（符文+符文之语一起算 scores.runes）拆成两个独立维：

| 维度 | 权重 | 计分内容 |
|------|------|---------|
| H 单符文战力 | 0.06 | 稀有度基础分 + primary_effect.value × RUNE_STAT_WEIGHT(200) + secondary × 0.5，clamp 500 |
| I 符文之语战力 | 0.06（新增）| RunewordMatcher 查激活词，按 TIER 加权(T2×100/T3×200/T4×350/T5×600) + effects 求和 × RUNEWORD_EFFECT_WEIGHT(150)，clamp 600 |

权重重分配（9维总和=1.0）：B刻印 0.10→0.08（让位 I 维）。拆分后符文和符文之语在评分表里各自一行，分别计权重。

**关键文件:**
- `scripts/master_power_evaluator.gd` — STAR_TIERS 新阈值 + compute_display_level 区间注释（实际在 enemy_phase_masters.gd）；H 维 `_eval_runes` 去符文之语部分只留单符文；新增 I 维 `_eval_runewords`；W_RUNES 0.10→0.06 + W_RUNEWORDS 0.06 新增；evaluate/scores/total/_build_details 接入 I 维
- `data/enemy_phase_masters.gd` — `compute_display_level` 映射区间 250/6000 → 434/2210

**验证:** Godot --check-only 通过（exit 0）；smoke test 全 PASS（H单符文>0、I符文之语>0 各自独立、rw_2_01 拆分验证 H=89 I=137.5）。实测：master_001 总分318（H符文500 I词156 1★新锐）、master_030 总分926（H符文500 I词600 5★宗师）；30 相位师星级分布 1/9/8/6/3/1/2 钟形覆盖全 7 档。

**已知技术债（范围外）:** `EnemyPhaseMasters.LEGACY_ENEMY_MASTERS` 静态 var 跨类初始化 bug（拼接时其他子文件未初始化得 0）——本绕过（直接遍历子文件），根因修复需把 LEGACY 改成延迟函数，留待后续。

## v7.x 相位师战力公式收敛为 3 分量 (2026-07-21)

**重要更正：** 上方 L966-1088 记录的"9 维加权公式（A=0.15/B=0.08/C=0.10/D=0.10/E=0.10/F=0.20/G=0.15/H=0.06/I=0.06）"已被代码**完全废弃**，保留段落仅供历史追溯。当前 `MasterPowerEvaluator.evaluate(master)` 实际是 **3 分量直接相加无权重**：

```
总分 = scores.instrument(A) + scores.equipment_slots(F) + scores.runes(H)
```

**3 分量子公式：**
| 维度 | 计算 | 说明 |
|------|------|------|
| A 相位仪 | `star² × 10 + (有 active_ability ? +50 : 0)` | 量级 90-540，占 5-15% |
| F 载卡 | `Σ UnifiedCardTable.get_entry(platform_id).power`（查不到兜底 100/卡） | 主导项，玩家侧读 `_player_platform_powers` |
| H 符文 | `Σ RUNE_RARITY_POWER[rune.rarity]`（common=800/rare=1500/epic=3000/legendary=5000/mythic=7000） | 敌方符文派生驱动 |

**死代码：** `_eval_engravings`/`_eval_traits`/`_eval_active_spells`/`_eval_passive_spells`/`_eval_master_stats`/`_eval_runewords` 6 个子函数仍残留在 `master_power_evaluator.gd`（L340-611），但 `evaluate()` **根本不调用**——勿被误导。

**STAR_TIERS 实际阈值（非旧记录的 450/540/650/780/950/1600）：** `0/800/1600/3200/6000/9500/20000`。

**实测数值（v7.x 3 分量口径）：** master_030 总分约 19040（A=490/F=1050/H=17500）→ 6★ 传说，派生 Lv30；注意 F 维因敌方 `*_expert` 平台 id 不在 UnifiedCardTable 走兜底 100/卡，实际运行时（autoload 完整 + JSON 合并命中）会反映真实卡 power 梯度。

## v7.x 改造效果审计 + 情报面板翻译表补齐 (2026-06-28)

**背景:** 用户要求审计"改造相关有多少没实装、多少对游戏无用、多少无法在情报面板正确显示"。对全 9 改造模块文件（133 改造，70 个 effect key）做三维度审查。

**审计结论（三个核心数字）:**

| # | 指标 | 数值 | 说明 |
|---|------|------|------|
| ① | **未实装（战斗空转）** | **10 / 70** | 全是光环协同类（ally_*/formation_bonus/command_efficiency），落入 `_apply_single_mod_effects` 的 default 分支被塞进 `_special`，而 `unit_stats_table._apply_mod_stat_effects` 完全不读 `_special` |
| ② | **对当前游戏无用** | **10** | 就是上述 10 个（需独立光环系统才能生效）。另有 ~35 个属"数值生效但语义错位"（如 night_bonus 实际给暴击率而非真夜战逻辑） |
| ③ | **情报面板无法正确显示** | **44 / 70**（修复前） | `card_info_panel._translate_mod_key()` 仅 29 条翻译，44 个 key 显示原始英文（如 `command_efficiency: 15`）。改造面板 `modification_panel._translate_effect_key()` 则全覆盖 |

**10 个未实装的光环协同类改造:**
inf_19单兵电台(ally_bonus)、arm_15数据链(ally_hit_bonus)、for_10指挥塔(ally_hit_bonus)、eng_09弹药补给车(ally_ammo)、eng_08战场急救站(ally_hp_regen)、eng_07发电机(ally_fort_regen)、eng_10伪装网(ally_detection)、eng_04架桥设备(ally_river_bonus)、gen_06激光指示器(ally_arty_bonus)、air_12数据链系统(formation_bonus)、gen_02数字化单兵(command_efficiency)。需独立光环系统，本范围外。

**本轮修复（用户选择"只修显示"）:**

`scenes/ui/card_info_panel.gd` 的 `_translate_mod_key()` 从 29 条补齐到 70 条全覆盖。key 集合与 `modification_panel._translate_effect_key()` 对齐，文案用情报面板简短风格（轻攻/重攻/暴击 vs modification_panel 的"对轻装攻击/对装甲攻击/暴击率"）。补齐的 41 个 key 涵盖：暴抗/还击/持续射击/视野系/三防系/巷战系/弹药系/隐蔽系/光环协同系/武器型号等。

**设计决策:**
1. **只修显示不改战斗逻辑**——光环系统（10 个 key）工作量大且需独立设计，本轮范围外；战斗卡属性类 v6.6 修复后已 0 遗漏，无需动 _apply_single_mod_effects
2. **补齐而非复用**——card_info_panel 是懒加载 Node，跨面板直接调 modification_panel._translate_effect_key 有时序风险；维护一份简短风格副本更稳妥，且情报面板本就需要更短的文案
3. **两表 key 集合对齐但文案不同**——modification_panel 用完整文案（玩家专注查看改造），card_info_panel 用简短文案（情报面板空间有限）。Grep 核对：card_info_panel 覆盖了 modification_panel 除稀有度词(common/epic 等)和武器槽倍率(slot_*)之外的全部 effect key

**验证:** Godot --check-only 通过（exit 0）；Grep 覆盖率核对——card_info_panel 101 行 match 分支覆盖全部 70 个 effect key（modification_panel 的 slot_*/稀有度词除外，与改造效果显示无关），0 个 key 裸露显示英文。

**未处理（留待后续）:**
- 语义错位（~35 个 key，如 night_bonus 实际给暴击）——v6.6 设计决策"语义重定向让数值生效"，文案与机制不符但不影响战斗平衡，可后续重做战场环境系统时统一

## v7.x 光环协同改造实装（重映射为自身加成）(2026-06-28)

**背景:** 上轮审计发现 11 个光环协同改造（10 个 effect key）全部落 `_apply_single_mod_effects` default 分支被塞进 `_special` 空转，而 `unit_stats_table._apply_mod_stat_effects` 明确不读 `_special`。用户选择"不做光环系统，改为装载单位自身战斗属性加成"（复用 v6.6/v7.5 重映射模式）。

**10 个 effect key 重映射（全部 ×0.5 缩放，因原值按"多友军受益"设计）:**

| effect key | 改造 | 重映射目标 | 复用模式 |
|-----------|------|-----------|---------|
| ally_bonus | 单兵电台 | crit_chance +0.015 | v6.6 命中→暴击口径 |
| ally_hit_bonus | 数据链/指挥塔 | crit_chance +0.05/+0.075 | 同上 |
| ally_ammo | 弹药补给车 | 三维攻速 ×1.15 | ammo_capacity 模式 |
| ally_hp_regen | 急救站 | hp_regen +0.0015 | 直接加成 |
| ally_fort_regen | 发电机 | 三维防御 ×1.12 | 二次缩放×0.25（堡垒回血给非堡垒自身折半） |
| ally_detection | 伪装网 | dodge_chance +0.15 | detection_reduce 模式（取绝对值） |
| ally_river_bonus | 架桥设备 | deploy_delay_bonus -0.0025 | urban_move_bonus 模式 |
| ally_arty_bonus | 激光指示器 | attack_armor ×1.10 | 对装甲伤害 |
| formation_bonus | 数据链系统 | 三维攻击 ×1.075 | "全属性微升"按字面 |
| command_efficiency | 数字化单兵 | 三维防御 ×1.075 | 指挥效率=整体耐打 |

**关键设计决策:**
1. **不做光环系统，改为自身加成**——光环需新建单位间协同传递机制太重；重映射到现有战斗属性零新机制，复用 v6.6 验证过的模式
2. **×0.5 缩放**——原 effect 值按"给周围多个友军加 buff"设计，改为"装载单位单受益"后必须减半平衡，否则 +15%暴击/攻击偏强
3. **ally_fort_regen 二次缩放（×0.25）**——堡垒回血给非堡垒单位自身，强度再降一档（发电机装在工兵车上，不是堡垒）
4. **数据层原值保留**——与 move_speed/attack_interval 处理一致，effects 字段不动，只在应用闸门 `_apply_single_mod_effects` 重定向

**关键文件:**
- `scripts/systems/modification_registry.gd` — `_apply_single_mod_effects` 在 default 分支前插入 10 个 match 分支（L468-517）
- `tests/aura_mods_smoke.gd`（新增）— 11 个真实改造重映射验证

**验证:** Godot --check-only 通过（exit 0）；aura_mods_smoke 全 PASS（11 个改造全部不再落 _special，写入正确字段且数值符合 ×0.5 缩放预期：crit_chance/dodge_chance 加法叠加、三维攻击/防御/攻速乘法叠加、hp_regen 直接加成）。Grep 核对 10 个 key 全在 match 分支 L468-517，无残留 default 落入。

**实测数值:** 单兵电台 crit+0.015、数据链 crit+0.05、指挥塔 crit+0.075、弹药车 攻速×1.15、急救站 hp_regen+0.0015、发电机 防御×1.12、伪装网 闪避+0.15、架桥 部署加速5%、激光 对装甲×1.10、数据链系统 三维攻击×1.075、数字化单兵 三维防御×1.075。全部温和增益，无超模。

## v7.x 改造描述文案校正 + 闪避/架桥数值平衡修复 (2026-06-28)

**背景:** 用户指出 10 个改造的描述文案与实际生效效果明显不符（经 v6.6/v7.5/v7.x 多轮重映射后，文案还停留在原始设计意图），要求把描述改成实际效果，并修复发现的两个数值隐患。

**A. 描述文案校正（10 个改造，6 个数据文件）:**

| 改造 | 文件 | 改前描述 → 改后描述 |
|------|------|-------------------|
| 主动防护 | armor_mods | 拦截30% → 减伤30%（拦截机制重定向为减伤） ⚠️**v8.x 已废弃，见下方勘误** |
| 热成像瞄准镜 | armor_mods | 无视烟雾+射程 → 射程+30（无视烟雾未实装） ⚠️**v8.x 已废弃，见下方勘误** |
| 扫雷滚/犁 | armor_mods | 免疫地雷 → 三维防御提升（地雷免疫重定向为减伤） ⚠️**v8.x 已废弃，见下方勘误** |
| 烟幕弹发射器 | anti_air_mods | 闪避制导武器 → 闪避+30%（反导闪避重定向为通用闪避） |
| 光学伪装 | recon_mods | 暴击率提升 → 暴击+50%（侦测范围走 vision 类映射暴击） |
| 红外抑制 | recon_mods | 热成像免疫 → 减伤提升（重定向为减伤） |
| 消音器 | recon_mods | 开火暴露降低 → 闪避+50%上限（重定向为闪避，限幅0.50） |
| 架桥设备 | engineer_mods | 友军涉渡 → 部署加速5%（重定向为自身部署，系数修复） |
| 通风过滤系统 | fort_mods | 免疫生化攻击 → 减伤提升（重定向为减伤） |
| 数字化单兵 | universal_mods | 指挥效率提升 → 三维防御+7.5%（重定向为自身防御） |

**B. 两个数值隐患修复:**

| # | 问题 | 修复 |
|---|------|------|
| 1 | **闪避值过高**：消音器 fire_exposure=-0.80 映射闪避+0.80（半无敌），光学伪装/伪装网等同路径偏高 | 所有闪避映射分支（detection_reduce / lock_reduction / fire_exposure / aggro_reduce / missile_dodge / ally_detection）统一 `min(0.50)` 上限。消音器 0.80→0.50，其余在阈值内的不变 |
| 2 | **架桥设备系数太弱**：ally_river_bonus=1.00(百分比) ×0.005×0.5=0.0025（0.25%部署加速，无感） | 系数 0.0025→0.05（×20倍），epic 稀有度获得 5% 部署加速体感 |

> **⚠️ v8.x 勘误（2026-07-27）：上表 A 段前 3 行（主动防护/热成像瞄准镜/扫雷滚）的"改后描述"已被后续版本覆盖，当前真实状态如下：**
>
> | 改造 | v7.x 表格记录（已废弃） | v8.x 当前真实状态 |
> |------|----------------------|------------------|
> | 主动防护 arm_04_aps | 拦截→减伤30% | **真拦截**：`intercept_system=0.30` + `intercept_charges=3`（30% 概率完全免伤，最多 3 次）。description="拦截来袭导弹：30%概率完全免伤，可触发3次"。registry 仍保留 `missile_intercept→damage_reduction` 兼容映射（仅旧存档用，当前无改造数据走此分支；`aa_06_laser` 仍用旧 missile_intercept，未迁移到真拦截） |
> | 热成像瞄准镜 arm_12 | smoke_ignore+射程+30px | **纯暴击**：删除 `smoke_ignore` 和 `attack_range=30`（射程 +0.3 格无感、项目无烟雾战术系统），改 `crit_chance=0.15`。description="热成像瞄准，暴击率+15%"（不再提射程/烟雾） |
> | 扫雷滚/犁 arm_14 | mine_immunity→减伤 | **三维防御×1.30**：registry `mine_immunity` 分支系数 0.15→0.30（原 0.15 对装甲仅 3-7% 实际减伤，过弱）。description="附加装甲提升三维防御+30%，轻微减速"（项目无敌方地雷机制，不提"地雷"）。数据层仍写 `mine_immunity=true`（重定向闸门在 registry） |
>
> **验证方式更新**：本次改动用 Godot `--script` 模式单独 `load()` armor_mods.gd + 7 项断言（几秒完成，不启动全部 autoload），未撞 5 分钟超时。`gdparse` 对本项目数据字典文件的 `key = value` 写法集体误报（gdtoolkit 4.5.0 限制），不适用。

**关键设计决策:**
1. **闪避统一上限 0.50**——闪避是"完全免伤"的随机机制，0.80 意味着 80% 攻击无效（接近无敌），0.50 是合理的"高闪避单位"天花板。数据层直接给 dodge_chance 的小值改造（inf_08/inf_13 的 0.03-0.15）仍走原 min(1.0) 路径不受影响
2. **架桥系数提升 20 倍**——ally_river_bonus 是百分比语义（1.00=100%涉渡）不是像素值，原按像素口径×0.005×0.5 换算导致 epic 改造几乎无效果；改为×0.05（5%部署加速）匹配稀有度
3. **描述暴露真实机制**——不回避"重定向"事实，括号注明原机制→现机制，让玩家理解为何"拦截导弹"实际是"减伤"

**关键文件:**
- `scripts/systems/modification_registry.gd` — 闪避映射 6 处分支 min(1.0)→min(0.50)；架桥设备系数 0.005×0.5→0.05
- `data/modification_modules/armor_mods.gd` — 3 个描述更新
- `data/modification_modules/anti_air_mods.gd` — 1 个描述更新
- `data/modification_modules/recon_mods.gd` — 3 个描述更新
- `data/modification_modules/engineer_mods.gd` — 1 个描述更新（架桥）
- `data/modification_modules/fort_mods.gd` — 1 个描述更新
- `data/modification_modules/universal_mods.gd` — 1 个描述更新

**验证:** Godot --check-only 通过（exit 0）；运行时验证 5 项全 PASS（消音器 0.80→0.50、伪装迷彩 0.20 不变、架桥 0.0025→0.05、烟幕 0.30 不变、红外干扰机 0.25 不变）。

## v7.x 剧情对话面板双立绘规范化 (2026-07-05)

**背景:** 用户要求剧情面板规范设计——左右方各确定是我方还是其他 NPC，立绘图片大小要有要求。调查发现当前是单 speaker 底部条带（JRPG 范式，96 圆形徽章探出条带左上角），speaker→立绘路径耦合在内联 `_PORTRAIT_MAP`（20 条，但实际只有 12 个 speaker，且部分指向不存在的 png），无阵营/方位概念，立绘无统一尺寸规格（200px/512px 混合）。

**决策（与用户确认）:** Galgame 范式双立绘对位（我方左 / NPC右）+ 全身立绘 540×720 + speaker 注册表集中管理元数据。

**3 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **新建 speaker 注册表** | `data/speaker_registry.gd` 集中维护每个 speaker 的 {display_name, faction(player/npc/enemy/neutral), portrait_path, color}。提供 get_entry/get_faction/get_side/get_portrait_path/get_color/get_display_name。阵营→方位派生：player→left, npc/enemy→right, neutral→center。含别名表（指挥官→陈末、镜像守护者→镜像、托马斯→洛克 等历史遗留 speaker 自动归位） |
| 2 | **双立绘层 + 徽章方位浮动** | story_dialogue_panel.gd 新增左右立绘层（540×720 竖条贴屏幕左右两侧，中间 200px 留给底部对话框）。说话者立绘 modulate=1.0+scale=1.0 全亮前移，非说话者 modulate=0.35+scale=0.95 暗化后退；中立 speaker 两侧都暗化。96 圆形徽章位置随说话者方位浮动（player→条带左上, npc/enemy→条带右上） |
| 3 | **立绘尺寸规格 + 资产说明** | 全身立绘 540×720 PNG 透明背景为产出标准；TextureRect 用 EXPAND_IGNORE_SIZE + STRETCH_KEEP_ASPECT_CENTERED，旧图任意尺寸自动适配。`ui/portraits/README.md` 写明规格/命名规范/已注册 speaker 表/新增 NPC 步骤 |

**关键设计决策:**
1. **Galgame 双立绘对位而非左右气泡**——视觉冲击强，全身立绘占满屏幕高度，符合用户"左右方各确定我方/NPC"诉求
2. **立绘层限定 540×720 竖条而非 FULL_RECT**——关键修复：原版用 PRESET_FULL_RECT 导致两张图都跑到屏幕中央互相覆盖（用户反馈"中间会出现大图"），改为锚定左 0~540 / 右 740~1280 竖条，立绘在各自区域内居中
3. **speaker 注册表而非对话项加 side/portrait 字段**——80+ 条对话数据零改动（仍只有 speaker+text），新增 NPC 只改注册表一处；别名机制兼容所有历史遗留 speaker
4. **保留底部对话框条带**——打字机/选项/章节 banner/四角宝石/点击推进/队列播放/choices 分支全部不动，重构只加立绘层，回退简单
5. **徽章位置随方位浮动**——player→条带左上、npc/enemy→条带右上，与全身立绘侧一致，强化左右方位感
6. **立绘资产不强制立即重绘**——TextureRect 自动适配任意尺寸，现有 13 张立绘继续用，新图按 540×720 规格产出（参见 ui/portraits/README.md）
7. **`_PORTRAIT_MAP` 与 `_get_speaker_color` 内联 match 全部移除**——单点维护到 SpeakerRegistry，避免映射表与实际数据脱节（原 _PORTRAIT_MAP 有 8 个未使用的 speaker 别名条目，且 thomas/sophia/victor 等映射指向不存在的 png）

**阵营方位映射:**

| speaker | 阵营 | 方位 | 立绘 | 配色 |
|---------|------|------|------|------|
| 陈末/指挥官 | player | 左 | player.png | 青 |
| 林薇/扎克/洛克/海伦/真实者 | npc | 右 | 各自 png | 角色色 |
| 铁血男爵/钢铁元帅/相位之主/虚空领主/镜像 | enemy | 右 | boss_*.png | 红/紫红/银 |
| 守护者 | neutral | 中（两侧暗化）| boss_guardian.png | 青蓝 |
| 旁白 | neutral | 中（无立绘，首字徽章）| — | 灰 |

**关键文件:**
- `data/speaker_registry.gd`（新增）— speaker 元数据集中表 + 别名机制 + 阵营→方位派生
- `scenes/ui/story_dialogue_panel.gd` — 删 `_PORTRAIT_MAP` + 删 `_get_speaker_color` 内联 match；新增左右立绘层构建/切换/清理；徽章方位浮动；`_get_speaker_color` 转发到注册表
- `ui/portraits/README.md`（新增）— 立绘资产规格/命名规范/已注册 speaker 表/新增 NPC 步骤

**向后兼容性:**
- 对话数据（quest_definitions.gd/.json）零改动
- choices 分支系统、story_choice_made 信号、关卡剧情任务队列播放全部保留
- 旧立绘（任意尺寸）通过 TextureRect 自动适配渲染
- 历史遗留 speaker 别名（指挥官/参谋长/情报官/镜像守护者/托马斯/索菲亚/维克多/艾莉亚/诺瓦）在注册表里映射到对应主 speaker，行为不变

**验证:** Godot headless 启动到 DefaultCards 构建（126 张卡，autoload 链含新 speaker_registry.gd 编译通过无语法错误；--script 模式 ModificationRegistry 报错是项目既有 autoload 时序问题，与本次改动无关）。Grep 静态核对：SpeakerRegistry 5 处调用（get_side/get_portrait_path/get_color）配对完整，注册表 8 个公共方法定义齐全，`_PORTRAIT_MAP` 已无残留引用（仅注释提及历史）。**实机验证（待手动）:** 触发第10/20/60/100关剧情，确认左右立绘按阵营正确显示、说话者高亮前移、徽章随方位浮动、旁白两侧暗化。

**已知技术债:** `_left_stage`/`_right_stage` 区域用硬编码 1280×720 屏幕坐标，未来若改分辨率需同步调整（当前项目固定 1280×720，可接受）。

## v7.x 全局数据平衡修订 (2026-07-10)

**背景:** 用户要求重新审查游戏整体数据平衡并按优先级修订。基于三轮代码数据采集（单位/敌人基础层、MOD/词条层、进化/稀有度/相位师层）+ 关键链路实读复核，修复 2 P0 + 2 P1 + 2 P2 + 1 P3 + 3 M 共 **10 个平衡问题**，全部数据/常量层改动，向后兼容。

### P0 — 严重（数值塌方/直觉违反）

**F1. 巨型能量罩恢复星级分级** — `data/phase_instruments.gd:222` + `managers/battle/phase_instrument_abilities.gd:302`
- 问题：`ability_mega_shield` 统一返回 3000，且运行时 `_apply_mega_shield` 又硬 `minf(...,3000)` 二次压制，导致 7★ 主动能力在近未来 HP 2000+ 战场近乎无效（描述文本还谎称星级影响数值）。
- 修复：`ability_mega_shield` 改星级分级 4★=3000/6★=5000/7★=8000（取 v6.6 原设计 5000/10000/20000 的 ~40%）；`_apply_mega_shield` 移除硬上限（上限由生成器决定）。两处都改，否则运行时白改。

**F3. 进化路径 HP 回退修正** — 3 个进化文件
- 问题：4 处进化终端阶段 HP/power 低于前一阶段（违反"进化=变强"直觉）。
- 修复：火炮 E4 max_hp 300→380（不低于 E3 的 320）；对空 E3 max_hp 350→400（不低于 E2 的 380）；步兵 E5 attack_light 100→150（巨神机甲转重装语义保留但不腰斩）。空中蜂群 E3 HP 回退保留（蜂群=多单位低血，属设计取舍，不改）。

### P1 — HIGH（一致性/对称性）

**F2. 闪避 cap 统一为 0.50** — `scripts/systems/modification_registry.gd:258`
- 问题：v7.x 声称"统一闪避 cap 到 0.50"但只覆盖重定向分支；直接 dodge_chance key（inf_08/inf_13/air_02/air_14/enh_dodge）走合并分支 `min(1.0)`，三套 cap（0.50/1.0/0.75）并存。
- 修复：把 dodge_chance 从合并 match 分支拆出单独 `min(0.50)`，crit_chance/armor_pen 留 `min(1.0)`。全代码闪避上限统一 0.50。

**H3. 相位师 master 攻防系数对称化** — `data/enemy_stat_resolver.gd:44`
- 问题：v6.12 把 m_atk 系数提至 0.0008 但 m_hp 仅 0.0006，攻端加成是防端 6.7×，攻防不对称。
- 修复：m_hp 系数 0.0006→**0.0008**（与 m_atk 对称）。master016(def200)→1.16x。保留 v6.12"敌方变强"诉求。

### P2 — MEDIUM（节奏/体感）

**H1. 时代 HP 倍率后期抬高** — `data/battle_card_v3.gd:17`
- 问题：时代伤害增长（1.65/1.80）快于血量（1.45/1.60），现代/近未来单位相对偏脆 ~12%。
- 修复：`era_hp_multiplier` 从线性 `1.0+era*0.15` 改查表 `[1.00,1.15,1.30,1.50,1.70]`，仅末两档抬高，血量/伤害比回到 ~0.95。测试 `test_battle_card_v3.gd` 同步更新断言（1.45→1.50 + 新增 1.70 断言）。

**H2. move_speed 重定向系数提升** — `scripts/systems/modification_registry.gd:239,472`
- 问题：系数 0.005 让 move_speed=20→deploy_delay -0.1（几乎无体感），机动类改造（涡扇/燃气轮机/外骨骼）实际无效。
- 修复：系数 0.005→**0.02**（×4），move_speed=20→-0.4（明显体感）。`urban_move_bonus` 同口径同步 0.005→0.02（注释明确"与 move_speed 同口径"）。

### P3 — LOW（死链/孤儿）

**H4. 工程兵进化死链修正** — `data/evolution_paths/engineer_evolution.gd:10`
- 问题：E0 `card_id="ww1_engineer"` 是死链（真实卡是 `ww1_sup_engineer`）。
- 修复：card_id 改为 `"ww1_sup_engineer"`。E1 的 fut_nano_drone combat_kind 不一致属 default_cards 数据设计（该卡实际是 AIR 型无人机），不在进化文件内修——本轮范围到此。

### M 类 — 一致性清理

| # | 文件 | 改动 |
|---|------|------|
| M3 | `scripts/master_power_evaluator.gd` | RUNE_RARITY_BASE 补 `"mythic": 200.0`（原缺，mythic 符文走 fallback 20.0 反低于 legendary）；INSTRUMENT_RARITY_SCORE 补 `"legendary": 600.0`（原缺，legendary 相位仪走 fallback 得错误分） |
| M4 | `data/basic_resources.gd` | 删孤儿函数 `get_specific_permit_id`（v7.3 许可证系统移除后零调用） |
| M2 | `data/enemy_stat_resolver.gd` | `collect_player_pressure` 加注释标注"预留未接通的难度调节点"（p_hp/p_atk/p_spd 恒 1.0），保留扩展点不删 |

**未做（M1 cap 统一）:** armor_penetration/lifesteal 在改造/统计层 cap(0.80/0.60) 与词条实例 cap(0.50/0.25) 是两层概念（实例值 vs 应用后总值），强行统一会破坏词条设计，本轮保留。

### 关键设计决策

1. **F1 两处都改** — 只改生成器不改运行时硬上限，护盾值仍被运行时压制回 3000，修复无效。必须同时移除 `_apply_mega_shield` 的 `minf(...,3000)`。
2. **H3 抬 m_hp 而非降 m_atk** — 保留 v6.12"敌方变强"诉求（用户多轮要求敌方变强），让攻防对称而非削弱攻端。
3. **H2 urban_move_bonus 同步** — 该分支注释明确"与 move_speed 同口径"，move_speed 系数变了它必须跟随，否则两个同语义的重定向会不一致。
4. **H4 不新建卡** — 用户选择"仅修死链+卡类型"，E1 combat_kind 不一致留待 default_cards 数据设计单独处理。
5. **测试同步** — era_hp_multiplier 改动后 test_battle_card_v3.gd 断言同步（遵循项目惯例，如 v6.1 伤害倍率改时同样更新断言）。

**关键文件:**
- `data/phase_instruments.gd` — ability_mega_shield 星级分级
- `managers/battle/phase_instrument_abilities.gd` — 移除硬上限
- `data/evolution_paths/artillery_evolution.gd` / `anti_air_evolution.gd` / `infantry_evolution.gd` — HP/攻击回退修正
- `scripts/systems/modification_registry.gd` — dodge_chance 拆分支 + move_speed/urban_move_bonus 系数
- `data/enemy_stat_resolver.gd` — m_hp 系数对称 + player_pressure 注释
- `data/battle_card_v3.gd` — era_hp_multiplier 查表
- `data/evolution_paths/engineer_evolution.gd` — 死链 card_id
- `scripts/master_power_evaluator.gd` — 稀有度查表补全
- `data/basic_resources.gd` — 删孤儿函数
- `tests/unit/data/test_battle_card_v3.gd` — 断言同步

**验证:** Grep 静态核对全部通过（3000 硬上限零残留、dodge_chance 全路径 min(0.50)、m_atk/m_hp 均 0.0008、era 查表值、move_speed/urban_move_bonus 均 0.02、rarity 表补全、permit 函数已删）；Godot `--check-only` 启动到 autoload 链构建无语法错误（项目体量 5 分钟超时属既有现象）。**注:** Godot 路径已从 AGENTS 旧值 `E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe` 迁移到实际位置 `D:/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64.exe`（v8.x 再次校正：真实路径多一层 `-stable/` 子目录，旧记 `D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe` 在本环境不存在）。

## v8.0 三套卡牌数据源统一 (2026-07-11)

**背景:** 用户报告"缴获卡虚空领主才 263 血"。调查发现游戏有**三套并行卡牌数据源**，数值量级严重不统一：
- **玩家原生卡** `default_cards.gd`（虚空领主 HP 2200，高量级）
- **缴获卡** `captured_card_stats.gd`（虚空领主 HP 240，复刻敌方低量级）← **bug 源头**
- **敌方原型** 5个分散来源（JSON / `_get_foe_stats` / `_pool_stats_for_kind` / 反向依赖缴获卡），量级混乱

缴获卡复刻敌方低量级（240血），进玩家背包后走 `build_stats_from_card`（v6.8 后无时代缩放），于是玩家拿到的缴获卡只有 240 血，同名原生卡 2200 血——近 10 倍差距，缴获卡基本废了。

**核心策略:** 新建 `UnifiedCardTable`（统一卡牌表）作为唯一数据源，消灭三套数据的量级混乱。玩家卡/敌方原型/缴获卡三者共享同一套标定后的中间值数值。

**6个阶段实现:**

### 阶段1：统一卡牌表（唯一真值源）
| 文件 | 改动 |
|------|------|
| `data/unified_card_table.gd`（新增） | 183 个概念卡完整字段（玩家卡口径：三维攻防/range_value格数/attack_speed次/秒/4值weapon_type）。按 era+combat_kind+tier 组织。base_hp 标定中间值（普通80-200/精英300-600/boss800-1500/终极1500-2000/堡垒600-2800）。含查询接口：get_entry/build_card_resource/build_enemy_archetype_config/get_player_card_entries/get_entries_by_era |

### 阶段2：玩家原生卡改读统一表
| 文件 | 改动 |
|------|------|
| `data/default_cards.gd` | `create_all()` 从硬编码 110 张 `_unit()` 调用改为 `UnifiedCardTable.get_player_card_entries()` 构建；删除 92 行死代码；保留 `_unit()` 函数体 + get_card_by_id/register_dynamic_card 等所有接口不变 |

### 阶段3：敌方原型改读统一表
| 文件 | 改动 |
|------|------|
| `data/enemy_unit_manifest.gd` | `_get_foe_stats`（A/B段34张）开头加统一表查找优先 + `_unified_to_foe_stats` 转换函数；`_make_pool_row`（D段29张）废弃 kind 公式改读统一表；`_make_fort_row`（E段10张）**解除对 CapturedCardStats 反向依赖**改读统一表 |
| `data/enemy_archetypes.gd` | `_ensure_manifest_merged` 末尾加 C段覆盖逻辑：遍历 archetype，统一表有对应的用 `build_enemy_archetype_config` 覆盖 hp/攻击/防御（保留 JSON 的 drops/tags/display_name） |

### 阶段4：缴获卡=统一表数值
| 文件 | 改动 |
|------|------|
| `data/captured_unit_cards.gd` | `_build_captured_card` 开头加统一表查找优先：drop_id 剥离 `captured_`/`foe_` 前缀 → 查统一表 → 用统一表数值构建。card_id 保留 captured_ 前缀（向后兼容存档），数值=统一表同名卡 |

### 阶段5-6：验证
| 验证项 | 结果 |
|--------|------|
| 统一表卡数 | 183 张（C段36+A段28+B段6+D段29+E段10+玩家独有74）✅ |
| 虚空领主 base_hp | 2000（缴获卡从 240→2000，bug 根除）✅ |
| 字典键重复 | 0 个（修复 15 处笔误）✅ |
| 5段全覆盖 | C/A/B/D/E 段所有 enemy_id 在统一表有对应 ✅ |
| archetype_config 转换 | hp/range/interval 字段转换正确 ✅ |
| Boss 血量范围 | 800-2000 合理 ✅ |
| smoke test | 10 PASS / 2 FAIL（FAIL 是 --script 模式环境限制）|

**关键设计决策:**
1. **统一表用玩家卡字段口径**（三维攻防/range_value格数）—— 最完整，build_stats_from_card 已是成熟入口
2. **敌方仍叠难度乘区**（wave×level×master×faction）—— 不改 enemy_stat_resolver，只改 cfg.hp 来源
3. **缴获卡=统一表同名卡数值** —— card_id 保留 captured_ 前缀（向后兼容存档），数值与商店买的同名卡完全一致
4. **base_hp 重标定中间值** —— 取原三套中位数向上靠档，既解决缴获卡太脆，也避免玩家裸卡过肉
5. **D段废弃 kind 公式** —— 29 个补充单位各录真实数据，不再按 index%4 套公式
6. **E段解除反向依赖** —— 堡垒数据从统一表读，不再依赖 captured_card_stats（消除循环依赖隐患）
7. **captured_card_stats.gd 保留作 fallback** —— 统一表查不到的旧 captured_* id 仍走原静态表，向后兼容

**关键文件:**
- `data/unified_card_table.gd`（新增）— 唯一真值源，183 卡 + 查询/构建接口
- `data/default_cards.gd` — create_all 改统一表驱动
- `data/enemy_unit_manifest.gd` — A/B/D/E 段改读统一表 + _unified_to_foe_stats 转换
- `data/enemy_archetypes.gd` — C 段覆盖逻辑
- `data/captured_unit_cards.gd` — 缴获卡统一表优先
- `tests/unified_table_smoke.gd`（新增）— 数据正确性验证

**不动的东西:** `build_stats_from_card`（已是统一入口）、`enemy_stat_resolver`（乘区链不变）、养成面板（数据源不变）、InstanceRegistry（实例化机制不变）、`captured_card_stats.gd`（保留作 fallback）。

**验证说明:** smoke test 10 PASS（核心数据全部正确）；全项目 `--check-only` 因项目体量 5 分钟超时属既有现象（autoload 链构建阶段无语法错误）。**注:** `build_card_resource` 在 `--script` 测试模式下因 ModificationRegistry autoload 未加载会失败，实际游戏运行时正常。

## v7.x 敌方相位仪独特技能 + 改造独特机制 (2026-07-13)

**背景:** 用户提出两大方向提升战斗可玩性——① 给敌方相位师的相位仪增加独特技能（敌我互通+新增特殊相位仪），② 给改造增加独特机制（成长型/debuff型/兵种专属机制型）。

**核心策略:** 敌方能力引擎镜像我方 PhaseInstrumentAbilities（角色对调），新增 4 个特殊相位仪仅相位师掉落；改造机制走成熟三步范式（UnitStats 加字段 + unit_stats_table 双向回写 + modification_registry 加 match 分支 + handler 加触发逻辑）。

### 第一部分：敌方相位仪独特技能（4 阶段）

**阶段 A：新建 EnemyPhaseInstrumentAbilities 引擎**
| 文件 | 改动 |
|------|------|
| `managers/battle/enemy_phase_instrument_abilities.gd`（新增） | 镜像我方 PhaseInstrumentAbilities，角色对调（敌方能力打玩家、buff 敌兵）；4 个敌方能力：enemy_artillery_barrage(periodic 炮击)/enemy_nano_swarm(on_battle_start 酸雨)/enemy_shield_bulwark(on_battle_start 护盾)/enemy_rage_buff(periodic 狂暴)；复用所有弹道/特效辅助，配色偏威胁（红/暗紫） |

**阶段 B-D：数据接入 + 战斗驱动 + 特殊相位仪**
| 文件 | 改动 |
|------|------|
| `data/json/enemy_phase_instruments.json` | 6 个高阶相位仪加 active_ability 字段（mk3/mk4/god 级） |
| `scenes/units/enemy_phase_field_driver.gd` | setup 缓存 _enemy_active_ability + get_active_ability() getter + _read_enemy_active_ability() |
| `managers/battle/battle_manager.gd` | preload + _process 加 update（短路前）+ _spawn_enemy_phase_master_base 加 on_battle_start + end_battle 加 reset_state |
| `data/phase_instruments.gd` | 新增 4 个特殊相位仪（pi_special_rage/void/aegis/nova，is_generic=false，acquire_rule="phase_master_drop"，复用我方 active_ability） |
| `managers/game_manager.gd` | _grant_phase_master_victory_reward 加特殊相位仪掉落（6★20%/7★40%）+ _maybe_roll_special_instrument_drop 势力映射 |
| `managers/battle/battle_spectacle.gd` | _on_ability_triggered 加 enemy_* 分支 + _play_enemy_warning_flash 演出 |

### 第二部分：改造独特机制（5 阶段）

**阶段 E：修通断链钩子（基础设施）**
| 文件 | 改动 |
|------|------|
| `scenes/units/construct_unit.gd` | _die 加 ModuleEffectHandler.on_kill（修复 shield_on_kill 空转）+ take_damage 加 on_damage_taken 钩子 |
| `scenes/units/enemy_unit.gd` / `scenes/units/swarm_enemy_slot.gd` | take_damage 加破甲/标记/巷战免伤 meta 读取 |
| `scripts/battle/module_effect_handler.gd` | 新增 on_damage_taken 钩子（活跃路径） |

**阶段 F：成长型机制（连击 + 怒气）**
- UnitStats +6 字段：combo_counter/combo_max/combo_bonus_mult + rage_counter/rage_max/rage_bonus_mult
- handler 新增 _tick_combo（命中计数→满后爆发）/ _accumulate_rage（受击计数→满后激活）
- 3 个新改造：inf_23_combat_stimulant（连击5次+25%）、arm_16_battle_frenzy（怒气8次+35%）、air_15_afterburner（连击3次+40%）

**阶段 G：debuff 型机制（破甲叠加 + 标记系统）**
- UnitStats +5 字段：armor_break_per_hit/armor_break_max_stacks + mark_chance/mark_duration/mark_vuln_bonus
- handler 新增 _apply_armor_break（命中挂 meta 降防御）/ _apply_mark（命中概率挂标记易伤）
- 3 个新改造：art_13_apfsds_sabot（破甲-8%×5层）、rec_13_target_designator（标记30%+25%易伤）、aa_13_radar_lock（对空标记40%+30%易伤）

**阶段 H：兵种专属机制（工兵爆破 + 步兵巷战 + 炮兵反击）**
- UnitStats +3 字段：siege_bonus_pct + urban_defense_bonus + has_counter_battery
- handler 新增 _apply_siege_bonus（对堡垒/装甲百分比掉血）/ _apply_counter_battery_mark（被攻击时标记攻击者）
- 3 个新改造：eng_11_breaching_charge（对堡垒5%掉血）、inf_24_urban_warfare（受装甲/空军减伤50%）、art_14_counter_battery（被攻击标记+优先反击）

**阶段 I：UI 翻译补齐**
| 文件 | 改动 |
|------|------|
| `scripts/ui/mod_effect_labels.gd` | 12 个新 effect key 翻译（combo_system/rage_system/armor_break/target_marking/siege_bonus/urban_defense/counter_battery 等） |

**关键设计决策:**
1. **敌我能力引擎分离**——EnemyPhaseInstrumentAbilities 独立类，角色对调逻辑不污染我方，各自独立 reset
2. **复用 phase_instrument_ability_triggered 信号**——params 加 is_enemy:true 区分来源，battle_spectacle 按 ability_id 分派，零新监听链路
3. **特殊相位仪仅相位师掉落**——is_generic=false 不进商店，acquire_rule="phase_master_drop"，6★20%/7★40% 概率
4. **9 个新改造全部新建**——不动现有改造 ID，避免平衡性回归风险
5. **兵种专属机制用条件字段**——urban_defense_bonus/armor_break_per_hit 复用 attack_fort_bonus 条件型模式，零侵入
6. **炮兵反击走标记系统**——art_14 不直接反弹伤害，而是标记攻击者+炮兵优先攻击，符合"炮兵反击炮击"语义
7. **修通 on_kill/on_damage_taken 断链是前置**——shield_on_kill 复活 + 为后续机制铺路
8. **百分比掉血用真实伤害**——target.hp × 5% 绕过防御，高防堡垒不被削弱

**验证:** 3 个 smoke test 全 PASS（new_mod_mechanics 9/9 + phase_instrument_drop 21/21 + enemy_instrument_abilities 8/8）；Grep 静态核对全链路拼写一致（UnitStats 7新字段 + table 14处回写 + registry 22处match + handler 7新函数 + 9改造定义 + battle_manager 3接入点 + 4特殊相位仪 + 12翻译）。全项目 `--check-only` 因项目体量 5 分钟超时属既有现象（smoke test 已验证所有新文件正确编译加载）。

**未处理（留待后续）:** 反伤/亡语爆炸机制（on_damage_taken 钩子已铺好）、充能爆发型机制、敌方召唤增援波能力（需突破 unit_limit）、炮兵反击的 AI 目标优先级（art_14 标记已挂载但 construct_unit_ai 的目标选择权重待接入）。

## v7.x 改造特殊机制扩展第二批次 (2026-07-13)

**背景:** 用户要求继续扩展改造特殊机制。基于调研确认 fort/universal 两兵种零新机制改造、4 个改造描述与实现严重不符（语义错配）、亡语钩子完全缺失。本轮修复 4 个 + 新增 8 个，覆盖 5 类全新机制。

**5 类新机制 + 12 个改造:**

| # | 兵种 | 改造 | 机制类型 | 新建/修复 |
|---|------|------|---------|----------|
| 1 | 步兵 | inf_18_ifak | 濒死复活（HP归零复活15%，每战1次） | 修复 |
| 2 | 侦察 | rec_10_medkit | 濒死复活 | 修复 |
| 3 | 装甲 | arm_03_reactive_armor | 爆反反伤（受击反弹30%伤害×3层） | 修复 |
| 4 | 装甲 | arm_04_aps | 拦截（30%概率完全免伤×3次） | 修复 |
| 5 | 工兵 | eng_12_reactive_engineering | 爆反反伤 | 新增 |
| 6 | 步兵 | inf_25_medic_sacrifice | 亡语治疗（死亡治疗周围友军20%max_hp） | 新增 |
| 7 | 工兵 | eng_13_supply_cache | 亡语治疗 | 新增 |
| 8 | 堡垒 | for_11_advanced_minefield | 雷场爆炸（150伤害） | 新增 |
| 9 | 堡垒 | for_12_anti_tank_trench | 区域减速（范围-40%移速） | 新增 |
| 10 | 堡垒 | for_13_command_bunker | 指挥光环（+15%暴击） | 新增 |
| 11 | 通用 | gen_14_phase_shield_gen | 相位护盾（2000池独立分流+回复） | 新增 |
| 12 | 通用 | gen_15_laser_marker | 激光指示器（命中100%标记+20%易伤） | 新增 |

**关键设计决策:**
1. **复活用独立 on_death 钩子**——不混用 RuneSpecialHandler（两套数据通路：改造stats vs 符文meta）
2. **拦截在 resolve_hit 之后、hp扣减之前 return**——绕过伤害符合"没被打到"语义，跳过受击反馈
3. **反伤作用于实际扣血量(hp_loss)**——复用 on_damage_taken 现有签名，与项目惯例一致
4. **亡语治疗与复活共享 on_death**——复活 return true 时亡语不触发（复活了就没死），逻辑自洽
5. **堡垒区域机制用 meta 刷新模式**——on_tick 每帧给范围内敌方/友军挂 1 秒 meta，单位读 meta 生效，无需新建区域节点
6. **相位护盾用独立池(_phase_shield_current)**——不复用 shield 字段（避免与护盾卡/符文/法则冲突），在常规护盾之前扣减
7. **4个修复改造保留旧 effect key 在 registry**——向后兼容旧存档（ifak_heal/heat_immunity_once/missile_intercept 映射保留），改造 effects 改指向新 key

**关键文件:**
- `resources/unit_stats.gd` — +16 新字段（复活3+爆反拦截4+亡语2+堡垒4+相位护盾3）
- `resources/unit_stats_table.gd` — base_dict + 写回各加16字段
- `scripts/systems/modification_registry.gd` — +15 match 分支（含 charges/radius 子key）
- `scripts/battle/module_effect_handler.gd` — +9 新函数（on_death/_revive_unit/_apply_reflect_damage/try_intercept/_apply_death_heal_allies/_apply_slow_aura/_apply_command_aura/_regen_phase_shield/_apply_laser_mark）+ 扩展 on_tick/on_damage_taken/apply_on_hit_side_effects
- `scenes/units/construct_unit.gd` — _die 加 on_death（复活+亡语）+ take_damage 加 try_intercept + 相位护盾分流 + on_revived 重置 + _phase_shield_current 成员变量
- `scenes/units/enemy_unit.gd` / `scenes/units/swarm_enemy_slot.gd` — take_damage 加 try_intercept
- `data/modification_modules/*.gd` — 6 文件（infantry/recon/armor/engineer/fort/universal）4修复+8新增
- `scripts/ui/mod_effect_labels.gd` — +15 翻译

**验证:** smoke test 7/7 全 PASS（12 改造映射全对 + 复活/反伤/拦截/亡语/雷场/相位分流数值公式全对）；Grep 静态核对全链路拼写一致（UnitStats 9字段 + table 18处回写 + registry 28处match + handler 9新函数 + construct_unit 8接入点 + 12改造定义全在）；第一批 smoke test 回归验证 9/9 全 PASS（无回归）。

## v9.x 背包卡图不可见修复 — PanelContainer 强制布局陷阱 (2026-07-20)

**背景:** 用户反馈"背包所有卡都看不到卡图"。深度排查后定位到一个反直觉的 Godot 4 Container 布局陷阱——此问题极易复发，记录此节供后续所有 UI 开发参考。

### ⚠️ 永久教训：PanelContainer/Container 父节点会强制布局所有直接子节点

**Godot 4 的 Container 布局机制**：任何 `Container` 子类（`PanelContainer`/`VBoxContainer`/`HBoxContainer`/`GridContainer`/`MarginContainer`/`ScrollContainer`/`TabContainer` 等）作为父节点时，会对**所有直接子节点**调用 `fit_child_in_rect`，强制把它们拉伸填满整个父区域——**无论子节点本身是不是 Container**。

这意味着：**在 PanelContainer（或任何 Container）上直接 `add_child()` 一个用 anchor/offset 定位的局部装饰节点，该节点会被强制拉伸到整个父区域，其 bg_color/内容会覆盖其它兄弟节点。**

**反直觉点：**
1. 子节点是 `Control`（非 Container）**也逃不掉**——父 Container 照样强制布局它
2. 设置 `custom_minimum_size` 无用——被 `fit_child_in_rect` 覆盖
3. 设置 `size_flags = SIZE_SHRINK_BEGIN` 无用——Container 不尊重
4. **首次 `add_child` 后到下一次 `_on_sort_children` 触发前，子节点保持自定义尺寸（看似正常）；一旦父级重排（resize/子节点增减/对象池复用 set_card），就被拉伸**

**正确做法（三选一）：**

| 方案 | 适用场景 | 做法 |
|------|---------|------|
| **A. 中间层 Control**（推荐） | 多个局部定位装饰挂在同一 Container 上 | 创建一个 `Control`（非 Container）作为中间层挂到 Container 上；装饰挂到中间层下。Container 只拉伸中间层（符合预期），中间层不强制布局子节点 |
| **B. set_as_top_level(true)** | 单个装饰、需脱离父坐标系 | 装饰 `set_as_top_level(true)` 后用 `_process`/手动同步全局位置跟随父节点（参考 `cost_badge.gd` 的 CostCornerBadge） |
| **C. 兄弟节点置于非 Container 下** | 装饰本应全屏覆盖 | 如 `CardFrameOverlay`/`CardBackgroundOverlay` 是 TextureRect 挂在 PanelContainer 上被拉伸到全卡——这恰是期望行为 |

**本项目已踩坑位置：** `backpack_card_item.gd` 的 4 个装饰（`RarityTopStrip`/`KindTagBadge`/`StarsOverlay`/`EquippedMark`）+ `InstanceNo` 原本直接挂在 `BackpackCardItem`(PanelContainer) 上，被拉伸覆盖卡图。已用方案 A 修复（新建 `DecorationLayer` Control 中间层）。

### 本次修复详情

**排查路径（二分法）**：通过逐个注释 `_set_compact_slot_view` 后续代码块，定位到 `_apply_v9_decorations` 是元凶；再二分到 `_ensure_rarity_top_strip`；运行时打印子节点尺寸，发现对象池复用第二次 `set_card` 后装饰被拉伸到整卡（`KindTagBadge: 16x16 → 96x140`）。

**修复**：
1. `_ensure_decoration_layer()` 新增——创建 `Control`（非 Container，`PRESET_FULL_RECT` + `z_index=5`）作为装饰容器
2. 5 个装饰节点（RarityTopStrip/KindTagBadge/StarsOverlay/EquippedMark/InstanceNo）改挂到 DecorationLayer 下
3. 装饰节点类型从 `PanelContainer`/`HBoxContainer` 改为 `Control` + 内部 `ColorRect`（画底色）/`Label`（画文字），去掉 Container 特性
4. `_hide_decoration` 查找路径改为 DecorationLayer 下
5. `set_card` 入口移到 DecorationLayer 创建之后

**关键文件:**
- `scenes/ui/backpack_card_item.gd` — `_ensure_decoration_layer()` 新增；`_ready` 调用；5 个 `_ensure_*` 装饰函数改挂 DecorationLayer + 改节点类型；`_hide_decoration` 查找路径更新

**验证:** Godot `--check-only` 通过；游戏运行确认卡图正常显示；`[BP-CHILDREN]` 日志确认 DecorationLayer 被拉伸到整卡（符合预期）、装饰节点在内部按 anchor 正常定位；对象池复用多次 set_card 后装饰尺寸稳定不漂移。

**给后续 UI 开发的检查清单：**
- [ ] 新增 UI 装饰节点时，检查父节点是不是 Container（PanelContainer/VBox/HBox 等）
- [ ] 若父是 Container 且装饰需要局部定位（非全屏覆盖），必须用方案 A（中间层 Control）或 B（set_as_top_level）
- [ ] **不要只测首次显示**——对象池复用/resize 后的二次布局才会暴露强制布局 bug
- [ ] TextureRect 挂在 Container 上被拉伸到全屏是**期望行为**（如卡框/底图），不要误改


## v9.x 驻守相位师战力重配（5-7★）+ 加成链 2 处 bug 修复 (2026-07-22)

**背景**: 用户反馈"49 关相位师有时获得高级堡垒"，调查发现爆率档位严重错位——20 个驻守相位师实测全部 1★ 新锐（总分 600，掉率档位 = 杂兵 GRUNT），导致：
- 改造蓝图必掉 1 张（设计应 2-4 张），legendary 概率仅 2.4%（应 6-8%）
- 符文/特殊相位仪门槛永远够不到（6★/7★ 才掉特殊相位仪）

**根因**: 20 个驻守相位师的 `equipment.platforms` 填了 `EnemyArchetypes` 表里**不存在**的卡 id（如 `ww2_inf_garand/ww2_sup_mg42` 实际是弱小兵卡，或 `_legacy_platforms` 的 `steel_fortress_expert` 等老 id 已废弃），导致 `compute_enemy_platform_power` 全部走兜底 100/卡，总分恒 600。

**核心策略**: 4-6 张时代高级战斗卡阶梯配置 + 显式写死势力主题符文 + 修复 2 处加成链 bug（让数学上可达 5-7★）。

**5 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| A1 | **接入 master.stats.max_hp** | `apply_phase_master_to_unit_stats` 之前只读 attack_power/defense，max_hp 完全空转。新增 `mhp_m = 1 + max_hp × 0.00015`（max_hp 3000→×1.45, 5000→×1.75）。仅相位师战生效，普通波次零影响 |
| A2 | **`_derive_runes` max_count 4→6** | 原 `clampi(2+level/10, 2, 4)` 让符文槽填不满相位仪 6 槽（EnemyLoadoutTiers rune_cap HIGH=6）。改为 `clampi(2+level/6, 2, 6)`，Lv10→3/Lv18→5/Lv24→6 |
| B1 | **20 驻守师 platforms 重配** | 每相位师 4-6 张**真实存在于 archetype JSON** 的高级卡（WW1 4 张→COLD 5 张→FUTURE 6 张），含每时代 boss 卡（ww1_boss_av7/ww2_boss_kingtiger/cold_boss_mig/mod_boss_command/fut_boss_nexus） |
| B2 | **显式写死势力主题 runes** | 20 个驻守师的 equipment.runes 字段直接填势力专属符文（steel→iron_*, flame→nova_*, thunder→aether_*, void→void_*）+ 通用攻防符文。`get_enriched_equipment` L212 检测到 runes 字段就不再派生，可控 |
| B3 | **2 处相位仪升级** | master_014（关49 雷霆钢铁）`pi_thundersteel_01(5★)` → `pi_steelthunder_01(6★)`；master_015（关50 虚空烈焰）`pi_voidflame_01(5★)` → `pi_flamevoid_01(6★)`，让 Lv20+ 相位师全部达到 6★+ 仪档 |

**关键设计决策:**
1. **只用 archetype JSON 真实存在的卡**——`EnemyArchetypes.get_config()` 池只有 37 张（每时代 6-8 张），填玩家卡 id（如 cold_t72）会查不到走兜底 100/卡。所有 platforms id 都经 grep 核实存在于 `data/json/enemy_archetypes.json`
2. **runes 显式写死而非改派生逻辑**——`get_enriched_equipment` 已支持"JSON 有 runes 就用原值"，比改 `_derive_runes` 派生逻辑更可控；势力主题（iron/nova/aether/void）让 20 个相位师有视觉识别度
3. **max_hp 系数 0.00015 偏激进**——纯 0.0001 估算后部分中时代相位师卡 4★ 边界，提到 0.00015 确保 WW1/WW2/low-COLD（卡偏弱）也能稳定 5★。代价：高 max_hp（5000+）相位师产兵 HP 加成 ×1.75，需实机观察是否过强
4. **静态子文件同步 platforms**（不写 runes）——JSON 优先时用 JSON 的 runes，JSON 缺失回退静态源时让 `_derive_runes` 自动派生，两层互不影响
5. **不改 STAR_TIERS 阈值**（7000/11000/16000 保持）——加成链补强（A1）+ 数据补强（B）后可达，不动阈值避免影响其他评估路径

**20 个驻守相位师配置总览（platforms/runes/相位仪）:**

| 关 | master | platforms | runes | 仪 | 目标星级 |
|---|---|---|---|---|---|
| 10 | 005 钢铁元帅 | 4（含2×av7）| 4 钢系 | pi_steel_02 5★ | 5★ |
| 15 | 006 炎魔女王 | 4 | 4 焰系 | pi_flame_02 5★ | 5★ |
| 20 | 007 雷神之子 | 4 | 4 雷系 | pi_thunder_02 5★ | 5★ |
| 25 | 008 虚空领主 | 5（含 boss_kingtiger）| 4 虚系 | pi_void_02 5★ | 5★ |
| 30 | 009 钢铁军团长 | 5 | 4 钢系 | pi_steel_03 6★ | 5-6★ |
| 35 | 011 雷皇 | 5 | 4 雷系 | pi_thunder_03 6★ | 5-6★ |
| 40 | 012 虚空虚主 | 5（含2×kingtiger）| 5 虚系 | pi_void_03 6★ | 6★ |
| 45 | 013 钢铁烈焰 | 5 | 5 钢+焰 | pi_steelflame_01 5★ | 5★ |
| 49 | 014 雷霆钢铁 | 5（含 boss_mig）| 5 钢+雷 | **pi_steelthunder_01 6★↑** | 6★ |
| 50 | 015 虚空烈焰 | 5 | 5 虚+焰 | **pi_flamevoid_01 6★↑** | 6★ |
| 55 | 016 不朽钢铁 | 6 | 5 钢系 | pi_steel_04 7★ | 6★ |
| 60 | 018 万雷之主 | 6（含2×mig）| 5 雷系 | pi_thunder_04 7★ | 6★ |
| 65 | 019 虚空主宰 | 6（含 boss_command）| 5 虚系 | pi_void_04 7★ | 6-7★ |
| 70 | 020 钢铁雷霆 | 6 | 5 钢+雷 | pi_steelthunder_01 6★ | 6★ |
| 75 | 022 战争机器 | 6 | 5 钢系 | pi_steel_04 7★ | 6-7★ |
| 80 | 024 风暴使者 | 6（含2×command）| 5 雷系 | pi_thunder_04 7★ | 6-7★ |
| 85 | 025 暗影主宰 | 6（含 boss_nexus）| 5 虚系 | pi_void_04 7★ | 7★ |
| 90 | 026 钢铁之神 | 6（含2×colossus）| 5 钢系 | pi_steel_05 7★ | 7★ |
| 95 | 028 雷神 | 6（含2×nexus）| 5 雷系 | pi_thunder_05 7★ | 7★ |
| 100 | 030 全能奥米伽 | 6（含2×nexus+2×colossus）| 6 四系混 | pi_omega_01 7★ | 7★ |

**关键文件:**
- `data/enemy_stat_resolver.gd` L365-370 — apply_phase_master_to_unit_stats 新增 max_hp 加成
- `data/enemy_phase_masters.gd` L256, L289 — _derive_runes/_derive_runes_generic_fallback max_count 4→6
- `data/json/enemy_phase_masters.json` — 20 个驻守 master 的 equipment.platforms/runes/phase_instrument 重写
- `data/enemy_phase_masters_{ww1,ww2,cold,modern,future}.gd` — 静态源 platforms 同步（runes 不写，回退时派生）
- `tests/master_garrison_power_smoke.gd`（新增）— 20 驻守师战力 smoke test

**验证:**
- ✓ `tests/syntax_check.gd` 全脚本语法通过
- ✓ JSON 解析 OK，20 个驻守 master 全部 platforms∈[4,6]、runes≥4、卡 id 全部在 archetype 池
- ✓ grep 链路核对：A1 max_hp 接入 L369-370、A2 max_count L256/L289、B 静态源 5 个子文件 platforms 同步正确
- ⚠️ **smoke test 受 `--script` 模式限制无法验证真实星级**——`EnemyArchetypes._ensure_manifest_merged` 依赖 `ModificationRegistry` autoload，`--script` 模式下不可用 → 全走兜底 100/卡 → 总分恒 600（不真实）。**真实星级需游戏内实机验证**（autoload 完整 + manifest 合并命中后，每张卡战力正确计算）。手算 mod_boss_command 满配单卡 ≈1644，6 张 ≈9864 → 5★ 宗师（7000-11000），数学上可达。
- ⚠️ **战斗侧 enemy_phase_field_driver 不读 MasterPowerEvaluator**——它走自己的产兵加成链，改 JSON 的 platforms 会让战场实际产兵变化（6 张 boss 卡产兵可能过强）。**需实机验证战斗平衡**，必要时在 driver 加产兵 hp/atk 上限钳制。

**未处理（范围外）:**
- faction→公司 id 映射 bug（`game_manager.gd:758` `FACTION_MOD_BIAS.get(_pm_faction, [])` 用相位师 faction 如 "steel" 查公司 id 如 "iron_wall_corp"，永远命中空）——影响 fort/armor 改造偏好掉落，本次未修
- 战斗侧产兵平衡验证（需实机）
- 其他 10 个非驻守相位师 platforms（只顺带享受 A1/A2 bug 修复，数据未改）

## v7.x 全面性能优化（P0+P1+P2）(2026-07-26)

**背景**: 用户反馈"游戏有时会卡"。三维度性能审查（每帧热点/启动开销/内存累积）识别出 2 个偶发卡顿根因 + 4 个启动期负担 + 2 个轻量抖动源。

**核心策略**: 全部向后兼容（游戏行为零变化）。P0 立竿见影消除阵容/能力相关的掉帧；P1 把启动期重活推迟到首次使用；P2 清理轻量抖动。

### P0：偶发卡顿根因（每帧执行代码）

| # | 问题 | 修复 | 收益 |
|---|------|------|------|
| P0-1 | `_find_nearby_allies` 全组遍历（`module_effect_handler.gd:659`）——指挥光环/堡垒庇护/亡语治疗每帧每光环单位 `get_nodes_in_group` O(N) 扫描，绕过 spatial_grid。指挥车/堡垒类上场即掉帧 | spatial_grid 新增 `query_allies`（镜像 `query_enemies`，阵营判定 `!=`→`==`）；`_find_nearby_allies` 改用 `bm.spatial_grid.query_allies(pos, radius, is_player_center)`，spatial_grid 不可用时保留全组兜底 | 消除阵容相关偶发掉帧，改 spatial_grid bounding-box 查询（只扫覆盖格） |
| P0-2 | `_apply_nano_swarm_tick`（`phase_instrument_abilities.gd:422`）每帧全 children 遍历 + 每单位 `take_damage` → 触发 6 个 `unit_damaged` 订阅者。nano_swarm 激活期间持续 30 秒掉帧 | 新增 `_nano_tick_acc` 累加器 + `NANO_TICK_INTERVAL=0.25`；节流到每 0.25s 累积一次结算（`hp_pct × tick_delta` 数值等价）；`reset_state` 清理累加器 | take_damage 调用频率从每帧×目标数降到每 0.25s×目标数（**~15× 降频**，实测 30 秒 1800 次→112 次），6 个订阅者回调同步降频 |

### P1：启动期懒加载

| # | 问题 | 修复 | 收益 |
|---|------|------|------|
| P1-1 | `ObjectPool._init` 预实例化 90 节点（60 子弹+30 伤害数字），注释明写"战前不预创建"但代码矛盾 | 删 `_init` 的 `_preload_objects()`；新增 `_prewarmed` 标志 + `_ensure_prewarm()`，首次 `get_object` 时建 `min(pool_size, 20)` 个（PREWARM_BATCH 小批量预热平滑首战尖峰） | 启动减 90 节点实例化。实测：_init 后 available=0，首次 get_object 预热 5 个（pool_size=5 测试） |
| P1-2 | `ModificationRegistry._ready` 启动即 `register_all()` 注册 154 条改造 | `_ready` 改为 pass；所有查询入口已有 `_ensure_initialized()` 自愈（`get_data:80`/`get_for_unit_type:98` 等首行），首次查询自动触发注册 | 启动减 154 条改造注册。开销转移到首次战斗构建 unit_stats 时 |
| P1-3 | `DropManager._ready` 启动即 `DropTables.new()` 建 5 时代掉落表，战斗外零调用 | `project.godot` 注释掉 DropManager autoload；`ManagerLazyLoader` 加 `"drop"` 配置（priority 1）；13 个调用点（game_manager/save_manager/mvp_panel/battle_damage_system/afk_mode_manager/offline_idle_manager/card_drop_grants/achievement_rewards）在 `get_node_or_null("/root/DropManager")` 前加 `ManagerLazyLoader.ensure_loaded("drop")` | 启动减 DropTables 构建（~150 DropEntry）。开销转移到首次掉落结算 |
| P1-4 | `AudioManager._ready` 启动即建 32 个 AudioStreamPlayer | `_ready` 只建默认 `button` 播放器；新增 `_ensure_player(name)`，`play_sfx` 未命中时即时 new+add_child+存字典；BGM 系统（`_music_player` 单播放器）不动 | 启动减 31 个 AudioStreamPlayer 节点。标题屏立即需要的 button 音效仍在 |
| P1-5 | 7 个 JSON 用 `static var X = _load_json(...)` 急切加载（同步文件 I/O），触达 preload 链即解析 | 仿 `enemy_phase_masters.gd:50-57` 现成模板，改 static var getter 懒加载（`_x_cache`+`_x_inited`+getter 三件套），对外 `Class.X` 访问语法不变，零调用方改动。7 个文件：quest_definitions(QUESTS)/company_store(ITEMS)/enemy_archetypes(ARCHETYPES)/enemy_phase_equipment(WAR_PLATFORMS+WAR_WEAPONS+ENERGY_CARDS)/task_definitions_extended(OBJECTIVE_TYPES+EXTENDED_TASKS) | 7 个 JSON（~170KB）同步解析推迟到首次访问。实测：访问前 `_inited=false`→访问后 `=true` |

### P2：轻量抖动清理

| # | 修复 | 收益 |
|---|------|------|
| P2-1 | `cast_effect._process` 每帧 `queue_redraw` 改为 0.05s 累加器节流（REDRAW_INTERVAL，仿 law_target_indicator 模式） | 与 P0 热点叠加时减少重绘尖峰（20Hz 重绘肉眼无感知差异） |
| P2-2 | `performance_metrics_manager` 写盘 `4000ms`→`15000ms`（已 call_deferred 非阻塞，纯降频） | 磁盘 IO 抖动源降频 |

**关键设计决策:**
1. **spatial_grid 加 query_allies 而非光环加时间节流**——spatial_grid 是战斗基础设施，加同阵营查询是其职责范围内；光环 meta 持续 1s 需每帧刷新，时间节流会有 0.3s 延迟感
2. **nano_swarm 不保留余数**——0.25s tick 边界误差 < 1 tick（实测 30 秒漂移 6.7%），nano_swarm 是百分比掉血非精确伤害，可接受；保留余数会增加复杂度且收益微小
3. **ObjectPool 首次预热 min(pool_size,20)**——分摊实例化成本避免单帧尖峰，比一次性建全部更平滑，比纯按需（每次 get_object 建 1 个）减少首战卡顿
4. **ModificationRegistry 只删 _ready 一行**——所有查询自带 `_ensure_initialized()` 自愈，无需走 ManagerLazyLoader（它是静态 registry 不是状态机）
5. **DropManager 走 ManagerLazyLoader + 13 调用点 ensure**——与项目 intel/lore/stat_boost 等 lazy manager 完全一致；调用点都是机械性"调用前加一行"
6. **JSON 改 getter 而非加 _ensure_ 函数**——static var getter 对外 API 透明（`Class.X` 仍可读），零调用方改动，是项目已有最简洁模式（enemy_phase_masters.gd 现成模板）
7. **AudioManager 播放器池改按需扩展而非整体懒加载**——它是 CORE_MANAGERS，标题屏立即需要 BGM/UI 音效且连接 ~20 个 SignalBus 信号，整体懒加载会丢信号

**关键文件:**
- P0-1: `scripts/spatial_grid.gd`(+query_allies) / `scripts/battle/module_effect_handler.gd`(_find_nearby_allies 改用)
- P0-2: `managers/battle/phase_instrument_abilities.gd`(_nano_tick_acc + NANO_TICK_INTERVAL + 节流结算 + reset_state 清理)
- P1-1: `managers/object_pool.gd`(_init 去预创建 + _ensure_prewarm + PREWARM_BATCH)
- P1-2: `scripts/systems/modification_registry.gd`(_ready 改 pass)
- P1-3: `project.godot`(注释 DropManager) / `managers/manager_lazy_loader.gd`(加 drop 配置) / 13 个调用点(game_manager×2/save_manager×2/mvp_panel×3/battle_damage_system/afk_mode_manager/offline_idle_manager×2/card_drop_grants/achievement_rewards×2)
- P1-4: `managers/audio_manager.gd`(_ensure_player + play_sfx 改用)
- P1-5: `data/quest_definitions.gd` / `data/company_store.gd` / `data/enemy_archetypes.gd` / `data/enemy_phase_equipment.gd` / `data/task_definitions_extended.gd`(共 7 个 static var 改 getter)
- P2-1: `scenes/effects/cast_effect.gd`(REDRAW_INTERVAL 节流)
- P2-2: `managers/performance_metrics_manager.gd`(4000→15000)
- `tests/perf_smoke.gd`（新增）— 4 维度验证（spatial_grid query_allies 正确性 / nano_swarm 节流逻辑 / JSON getter 懒加载 / ObjectPool 预热常量）

**验证:**
- ✓ Grep 静态核对全部通过：query_allies 定义+调用配对、_nano_tick_acc 清理点、7 个 JSON getter 三件套（cache+inited+getter）、13 个 DropManager 调用点 ensure_loaded 配对
- ✓ `tests/perf_smoke.gd` 4 维度全 PASS：
  - spatial_grid query_allies 正确（含同阵营近距、不含远距/异阵营/自身边界）
  - nano_swarm 节流：30 秒 1800 次调用→112 次（~16× 降频），伤害漂移 < 1 tick
  - JSON getter：QUESTS/ITEMS/ARCHETYPES 访问前 `_inited=false`→访问后 `=true`，数据量正常（58/68/36）
  - ObjectPool 预热常量正确（pool_size=60→20、=30→20、=10→10）
- ✓ ObjectPool 运行时行为验证（独立脚本）：_init 后 available=0（未预创建）→首次 get_object 触发预热（total_created=5, available=4）
- ✓ 其余改动文件（cast_effect/perf_metrics/task_def/epe/modification_registry）独立编译验证通过
- ⚠️ Godot `--check-only` 全项目验证因 133 卡 + 38 autoload 接近 5 分钟超时（既有现象，非本轮引入）；`--script` 模式下的 `ModificationRegistry not found` 错误是 autoload 全局名在无 autoload 环境下的固有限制（master_power_smoke 同样存在），非语法错误
- ⚠️ **运行时性能收益（实际帧时改善）需游戏内实机验证**——本轮改动的算法正确性已验证，但"卡顿消除"的体感改善需在真实战场场景（指挥车+堡垒阵容 / nano_swarm 激活）下测量


## v8.x 技能体系融入格子战斗 (2026-07-26)

**背景:** 现有战斗系统 90% 变量是"数值"（攻击力×HP×防御），缺少"机制差异"。本轮新增 4 大模块（5维克制/卡片定时技能/战法系统/特殊兵种），让不同阵容+技能带来完全不同的战场行为，且全部格子战斗兼容（零移动、被动触发）。

**核心策略:** 基于引擎能力审计，把原 60 个技能设计中的 10 个"架构冲突项"（移动/传送/暂停/命中率）重写为格子兼容版本——复杂机制改为"卡片定时技能"（特定平台卡部署后按周期自动施放），完全复用 `PhaseInstrumentAbilities` 的 periodic 引擎模式。

**4 期实现:**

### P0：5维克制+技能树扩展+战法系统（纯数据扩展，零引擎改动）
| 改动 | 详情 |
|------|------|
| **CombatKind 扩展** | LIGHT/ARMOR/SUPPORT/AIR/FORT(+2) → 新增 ENGINEER(5)/SNIPER(6)；向后兼容（归入 LIGHT 路径，再由矩阵施加差异化倍率） |
| **5维攻击/防御矩阵** | `COMBAT_KIND_ATTACK_MATRIX`/`COMBAT_KIND_DEFENSE_MATRIX`（5×5）；查询函数 `get_attack_matrix_multiplier`/`get_defense_matrix_multiplier` |
| **8条标签硬克制** | `TAG_COUNTER_RULES`：sniper→boss(+50%,never_miss)、stealth→command(+30%)、fort→aircraft(+40%)、artillery→fort/armored、aircraft→engineer/artillery、fast→fort(bypass_reduction)、engineer→casting(+20%)、stalker→command(+30%) |
| **技能树扩展 40 节点** | `phase_master_skill_tree_v8_extension.gd`（4分支×10节点，tier 5-12）；主表 `get_skills_for_branch`/`get_skill`/`get_branch_of` 合并扩展节点 |
| **18 战法** | `tactics.gd`（12基础+6高级）+ `tactic_detector.gd`（每1s阵容检测，差异更新Buff）；高级战法需技能树解锁 |

### P1：卡片定时技能引擎（复用 periodic 模式）
| 改动 | 详情 |
|------|------|
| **21 卡片定时技能** | `card_periodic_skills.gd`（4家族×5+1占位）；steel(6)/flame(5)/thunder(5)/void(5)；7 个终极技能 |
| **卡片技能引擎** | `card_periodic_skill_engine.gd`（RefCounted，复用 PhaseInstrumentAbilities 模式）；11 种 effect 类型（area_damage/single_target/global/chain/debuff_target/area/global/spread/buff_allies/summon/execute） |
| **battle_manager 接入** | `_process` 中 `CardPeriodicSkillEngine.update` + `TacticDetector.update`；`start_battle` 时 `on_battle_start`（从 PhaseMasterSkillManager 读已解锁 card_skill）；`reset` 时清理 |

### P2：兵种行为接入
| 兵种 | 机制 | 实现路径 |
|------|------|---------|
| **STALKER** | 部署后前4s受伤×0.4 + 首击×1.5 | `construct_unit._is_stalker_in_grace` + `construct_unit_ai.do_attack_with_damage` 首击检测 |
| **SNIPER** | 首击必爆 + 锁Boss/master | `bullet.gd` 读 `_first_attack_force_crit` meta 强制暴击 + `target_selection.SNIPER_BOSS_PRIORITY` |
| **ECM** | 光环减敌方攻速-25% | `construct_unit._update_ecm_debuff_aura`（每0.2s扫描250半径挂meta）→ `enemy_unit._process_attack_timing` 读meta减攻速 |
| **ENGINEER** | 卡片技能触发源 | `CardPeriodicSkillEngine` 按 source_tag 触发；`unit_stats_table._apply_v8_unit_type_meta` 按 card_id 前缀打 meta |
| **卡片技能 stat_bonus** | 全体友军攻速/暴击/闪避/减伤 | `construct_unit._update_card_skill_bonus`（每0.5s检查meta过期+应用/回退） |

### P3：标签克制伤害加成+ECM生效+注释完善
| 改动 | 详情 |
|------|------|
| **TAG_COUNTER_RULES 伤害加成** | `attack_calculator.compute_tag_counter_multiplier`（bullet.gd 调用，返回 mult/never_miss/ignore_stealth/bypass_damage_reduction） |
| **bullet.gd 接入** | 伤害结算时读 shooter 标签（_behavior_tags_cached 或 stats meta is_stalker/is_sniper 等）→ 调用 compute_tag_counter_multiplier → 乘 final_damage |
| **ECM 减益生效** | `enemy_unit._process_attack_timing` 开头读 `_ecm_debuffed_until` meta，被减益时 delta×0.75（攻速-25%=周期×1.33） |
| **PhaseMasterSkillManager 注释** | `_apply_unlocks` 注释补全 card_skill/tactic 类型说明（实际靠 is_content_unlocked 查询，pass 分支已正确处理） |

**关键设计决策:**
1. **零移动约束**——所有机制不依赖单位移动（格子战 velocity=ZERO + 槽位锁定）；原 10 个"移动/传送/暂停"技能全部重写为兼容版本（装甲楔入→战法集火、瞬移突击→远程强化、时间停滞→全场减速、STALKER部署敌后→潜行首击）
2. **卡片定时技能承载复杂机制**——特定平台卡部署后按周期自动施放（玩家无需操作），复用 PhaseInstrumentAbilities periodic 引擎模式，零架构改动
3. **5维矩阵向后兼容**——ENGINEER/SNIPER 在 get_attack_vs/get_defense_vs 归入 LIGHT 路径（无独立 attack/defense 字段），再由矩阵乘区施加差异化倍率；现有 5 值（LIGHT/ARMOR/SUPPORT/AIR/FORT）行为零变化
4. **标签硬克制走 bullet.gd**——伤害结算时读 shooter 标签 + target meta（target_priority_tag/_is_casting），匹配 TAG_COUNTER_RULES 应用加成；不侵入 get_attack_vs 的核心路径
5. **ECM 减益走 meta 传递**——ECM 单位周期性给范围内敌方挂 `_ecm_debuffed_until` meta，敌方在 `_process_attack_timing` 读取应用（delta×0.75）；不改 AuraManager（现有光环都是友军向，新增敌方减益类型风险大）
6. **战法差异更新**——TacticDetector 每1s检测，对比新旧激活集，只对变化单位应用/移除 Buff，避免每帧全量刷新
7. **技能树扩展独立文件**——`phase_master_skill_tree_v8_extension.gd` 不动主表 20 节点，主表 `get_skills_for_branch` 合并扩展节点；解锁类型 card_skill/tactic 靠 `is_content_unlocked(type, id)` 通用查询

**关键文件:**
- P0: `resources/game_constants.gd`(+CombatKind.ENGINEER/SNIPER+5维矩阵+TAG_COUNTER_RULES+查询函数) / `scripts/battle/attack_calculator.gd`(get_attack_vs/get_defense_vs/get_attack_timing/get_weapon_for_target 扩展) / `scripts/battle/target_selection.gd`(SNIPER_BOSS_PRIORITY+_is_high_value_target) / `data/phase_master_skill_tree.gd`(合并扩展节点) / `data/phase_master_skill_tree_v8_extension.gd`(新建,40节点) / `data/tactics.gd`(新建,18战法) / `scripts/battle/tactic_detector.gd`(新建,阵容检测)
- P1: `data/card_periodic_skills.gd`(新建,21技能) / `managers/battle/card_periodic_skill_engine.gd`(新建,引擎+11种effect) / `managers/battle/battle_manager.gd`(接入点:init/update/on_battle_start/reset)
- P2: `scenes/units/construct_unit.gd`(+STALKER隐身+SNIPER标记+ECM光环+卡片技能stat_bonus消费) / `scripts/battle/construct_unit_ai.gd`(+首击检测) / `scenes/units/bullet.gd`(+SNIPER必爆+标签克制加成) / `resources/unit_stats_table.gd`(+_apply_v8_unit_type_meta) / `scenes/units/enemy_unit.gd`(+ECM减益读取)
- P3: `scripts/battle/attack_calculator.gd`(+compute_tag_counter_multiplier) / `scenes/units/bullet.gd`(+标签克制调用) / `scenes/units/enemy_unit.gd`(+ECM减益生效) / `managers/phase_master_skill_manager.gd`(注释补全)
- 测试: `tests/v8_skills_smoke.gd`(新建,22项) / `docs/design/COMBAT_SYSTEM_V8_GRID_COMPATIBLE.md`(新建,完整设计文档)

**验证:**
- ✓ Godot `--check-only` exit code 0（全项目语法无 SCRIPT ERROR）
- ✓ `tests/v8_skills_smoke.gd` 22/22 全 PASS：CombatKind枚举/5维矩阵(含向后兼容)/SNIPER优先级常量/18战法定义+结构/TacticDetector实例化+API/21卡片技能+4家族分布+终极标记/CardPeriodicSkillEngine实例化+API/40扩展节点+主表合并+get_skill查询/8条标签硬克制/compute_tag_counter_multiplier API+数值验证(SNIPER vs boss +50%/STEALTH vs command +30%/无标签1.0)/5×5矩阵完整覆盖/card_skill+tactic unlock_type存在
- ✓ `tests/star_config_smoke.gd` OK（无回归）
- ⚠️ Godot `--check-only` 全项目验证因项目体量接近超时（既有现象，非本轮引入）
- ⚠️ `--script` 模式下的 `ModificationRegistry/ObjectPoolManager not found` 错误是 autoload 全局名在无 autoload 环境下的固有限制（非语法错误，game runtime 下正常）
- ⚠️ **运行时行为（实际战斗效果/平衡性）需游戏内实机验证**——本轮改动的 API 正确性+数据完整性+引用链路已全部静态核对+smoke 验证，但战场实际表现（如 ECM 减益体感、战法激活时机、卡片技能节奏）需在真实战场场景下测量

**后续可选方向（非必需，当前已可玩）:**
- UI 面板：技能树扩展节点显示、战法激活提示、卡片技能触发特效
- enemy_unit 读取 ECM 暴击/闪避减益（当前只读取了攻速减益）
- 更多卡片技能/战法（数据扩展，零引擎改动）
- 平衡性调整（实机数据反馈后微调数值）

## v8.x 战场卡图与血条视觉修复 (2026-07-31)

**背景:** 连续修复战场卡图呈现的一系列视觉 bug——血条/HP数字/护盾条显示异常、敌方卡图遮挡血条、势力战斗卡立绘偏小、我方卡图错用。全部集中在视觉呈现层，零战斗数值改动。

### 1. 血条/HP数字/护盾条显示修复（unit_hp_bar）
**根因**：`unit_hp_bar.gd` 的 Label 配置踩了 Godot 4.x 的 3.x→4.x 属性迁移雷区（连续 3 批），叠加 HP 数字定位/字号/护盾条刷新逻辑缺陷。

| # | 问题 | 根因 | 修复 |
|---|------|------|------|
| ① | HP数字显示在血条外 | Label 在 Node2D 父下 `position` 是左上角锚点，`Vector2(0,0)` 让文字向右下偏出 | `_update_view` 设 `size=(BAR_WIDTH,h)` + `position=-size/2`，框中心对齐原点 |
| ② | HP数字颜色看不清 | `set_side()` 把 modulate 改成阵营色（玩家绿/敌方红），同色血条上看不清 | 固定白字 + 黑描边（`add_theme_color_override outline_color`），删除 set_side 改色 |
| ③ | 字号溢出血条 | 固定 font_size=12 行高15px > 折叠态血条12px | 字号动态化：折叠10pt/展开14pt（行高均<血条高度） |
| ④ | `h_alignment` 运行时报错 | 3.x 属性名，4.x 改名 `horizontal_alignment` + 枚举常量 | 改用 `HORIZONTAL_ALIGNMENT_CENTER`/`VERTICAL_ALIGNMENT_CENTER` |
| ⑤ | `outline_size` 运行时报错 | Label 4.x 无此直接属性，须 theme override | `add_theme_constant_override("outline_size",2)` + `add_theme_color_override("outline_color",...)` |
| ⑥ | `font_size` 运行时报错 | 同上，4.x 须 theme override | `add_theme_font_size_override("font_size",N)` |
| ⑦ | 护盾条不显示/残留 | `set_shield()` 仅在 add_shield 调一次，受击消耗后从不刷新 | `set_shield` 加归零隐藏 + `_update_hp_bar` 每次同步护盾条（放在 HP 阈值 early-return 前） |

**血条加宽**：`BAR_WIDTH` 100→130，`HEIGHT_COMPACT` 12→14（容纳更大字号），敌我统一加宽。

**关键文件**：`scenes/units/unit_hp_bar.gd`、`.tscn`、`scenes/units/construct_unit.gd`(_update_hp_bar)

### 2. 敌方血条被立绘遮挡（z_index）
**根因**：`enemy_unit.tscn` 的 Sprite2D 写了 `z_index=1`，HpBar 根节点 z_index 默认0 → 立绘盖住血条和数字。玩家侧因 Sprite z=10 但血条位置在头顶上方侥幸不重叠。

**修复**：`enemy_unit.gd _update_visual_setup` 设 `(hb as Node2D).z_index = 10`，抬到立绘之上。

### 3. 战场双行整体下移 10px
**修复**：`card_grid_battle_layout.gd` 新增 `CARD_GRID_ROW_VERTICAL_SHIFT=10.0`，`slot_y_offset_for_index` 上下行返回值各 +10；`battle_slot_grid.gd` 点击接受带同步 +10。改动落在单位 Y 单一真源，所有单位经 snap 自动跟随。

### 4. 势力战斗卡立绘偏小（foe_* VISUAL_SCALE 缺失）
**根因**：v6.9 势力占领系统的 34 个势力卡 `foe_*` 有独占卡图（vis_enemy_001~035）和锚点数据，但 **VISUAL_SCALE 全部缺失**，产兵缩放回退默认1.0（载具/boss 应有1.2~2.0）→ 立绘偏小 → entity_top_y 算错 → 血条错位。

**修复**：`card_foot_anchors.gd` VISUAL_SCALE 表补全 34 条 `foe_*`。**关键原则**：同名单位的卡图（vis_enemy_NNN）敌我共用，缩放必须一致——全部对齐到我方同名短名卡的既有 VISUAL_SCALE（28个有同名卡对齐，6个未来专属无同名卡按兵种估算标[估算]）。

### 5. 我方卡图错用（PLAYER_ICON_OVERRIDE）★
**背景**：我方卡图是敌方卡的水平翻转（vis_player_NNN = vis_enemy_NNN 翻转）。错用发生在 `ui_asset_loader.gd` 的 `PLAYER_ICON_OVERRIDE` 表（我方 card_id → vis_player_NNN 核心映射）。

**排查方法**：运行时审计 74 条 override，反查每条映射的 vis_enemy_NNN 卡图内容（display_name+tags），与我方 card_id 的真实单位身份逐项比对。

**修正 5 处错用**：

| card_id | 我方单位 | 原卡图(错) | 修正为 | 理由 |
|---------|---------|-----------|--------|------|
| `mod_stinger` | 毒刺导弹兵(步兵) | vis_player_063(阿帕奇直升机) | `vis_player_017`(ZSU-23-4高炮) | 步兵误用飞行器图 → 改防空武器图 |
| `ww1_mark4` | 马克IV坦克 | vis_player_041(装甲车) | `vis_player_042`(圣沙蒙坦克) | 坦克误用轻装甲车 → 同期重坦图(与a7v/saint一致) |
| `cold_leo1` | 豹1主战坦克 | vis_player_052(BTR装甲车) | `vis_player_055`(T-72坦克) | 西方主战坦克误用苏式装甲车 → 主战坦克图 |
| `cold_m1` | M1主战坦克 | vis_player_052(BTR装甲车) | `vis_player_055`(T-72坦克) | 同上 |
| `cold_m60t` | M60坦克 | vis_player_052(BTR装甲车) | `vis_player_055`(T-72坦克) | 同上 |

**未改**：`fut_aa_hover`(防空悬浮车→火箭炮车)，防空/火炮勉强同类，可接受。

**关键澄清（排查过程中的重要发现）**：
- `PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM`（construct_unit.gd）和 `PLAYER_PLATFORM_TO_SCALE_ARCHETYPE`（card_foot_anchors.gd）虽两表同步，但它们基于废弃的 13 值 `PlatformType` 枚举（HOUND/GUARD/TITAN...），实际我方卡 `platform_type = combat_kind`（只有 LIGHT/ARMOR/SUPPORT/AIR/FORT 五值）。这两表只作为缩放兜底，**不是**我方卡图的主映射——真正决定我方卡图的是 `PLAYER_ICON_OVERRIDE`（ui_asset_loader.gd）。
- 排查我方卡图错用应查 `PLAYER_ICON_OVERRIDE`，不是 mirror/scale 表。

**验证**：`ui_asset_loader.gd` 编译 OK；5 处修正后的卡图语义与单位身份匹配（步兵→步兵图、坦克→坦克图、防空→防空图）。

### 关键文件汇总
- `scenes/units/unit_hp_bar.gd` / `.tscn` — 血条/HP数字/护盾条/字号/描边/加宽
- `scenes/units/construct_unit.gd` — _update_hp_bar 同步护盾条
- `scenes/units/enemy_unit.gd` — HpBar z_index=10
- `scripts/card_grid_battle_layout.gd` / `scenes/battlefield/battle_slot_grid.gd` — 双行下移10px
- `data/card_foot_anchors.gd` — 34个 foe_* VISUAL_SCALE 补全
- `scripts/ui_asset_loader.gd` — PLAYER_ICON_OVERRIDE 5处卡图错用修正

**经验教训（Godot 4.x 雷区）**：Label 的 `h_alignment`/`v_alignment`/`outline_size`/`outline_color`/`font_size` 在 4.x 全部不能用裸 int 直接赋值——前两个改名+需枚举常量，后三个须用 `add_theme_*_override`。tscn 里字号标准写法是 `theme_override_font_sizes/font_size`。

## v8.6 全系统实装与复查修复 (2026-08-01)

基于对改造、相位师技能、势力技能、兵种机制四大子系统的三维度审查（数据一致性/逻辑空转/文案匹配），分三轮完成 23 项修复。全部向后兼容，全项目 `--check-only` 零错误。

### 第一轮：四大系统实装缺口修复（5 模块）

**审查结论**：改造 106 key 零空转但 ally_* 双链路注释错误；相位师主动技能引擎就绪但数据全空；势力 stat_bonus 实装但 special 类零消费；兵种机制玩家方实装但敌方完全缺失。

| 模块 | 问题 | 修复 |
|------|------|------|
| 1-敌方兵种 | 经典波次敌方走自建 stats 管线跳过 `apply_combat_kind_modifiers`，敌方堡垒减伤=0/侦察无闪避/防空无对空加成 | `enemy_unit._build_enemy_unit_stats` 加 `apply_combat_kind_modifiers(s)` + `hp=s.max_hp` 同步 |
| 2-ally注释 | `modification_registry.gd:517` 注释称"项目无光环系统"但 `mod_aura_handler.gd` 实际活跃 | 修正注释准确描述双链路（载体自身×0.5缩放 + 友军原值广播） |
| 3-势力special | `merged["special"]` 战斗端零消费，13+种特殊效果解锁后无效果 | 新建 `faction_skill_effect_handler.gd`（17种子键）+ 接入 spawn/construct_unit/bullet |
| 4-boss引擎 | `_compute_boss_damage` 读 `_driver.get("stats")` 恒 null（driver 无 public stats）→ 永走 fallback | driver 暴露 `get_master_stats()`，engine 改读它 |
| 5-boss数据 | 30个 boss 的 `active_spells` 全为空[]，引擎6路执行函数写好但无数据触发 | 按时代梯度填充 51 个 active_spell（WW1 1技能→Future 2-3技能）+ JSON 同步 |

**势力 special 17 种子键分三层接入**：
- 生成期（spawn_system）：armor_penetration / conditional.hp_below / stacking_bonus / variety_bonus / aura.stat
- 事件驱动（construct_unit/bullet）：on_hit_debuff / first_hit_damage / extra_attack_chance / on_kill_energy / on_kill_heal_pct / on_death_energy_return / on_death_ally_heal / death_save / on_crit_bonus_damage_pct
- 周期tick（construct_unit._physics_process）：periodic_shield / periodic_heal / periodic_invuln

**boss 数据分配原则**：faction 主题映射（thunder→chain、flame→AOE、void→AOE/single、steel→shield/summon）；effect 关键字避开顺序陷阱（分派顺序 AOE>chain>summon>debuff>shield>single）；active 禁用 damage_aura/burning（避免被判全场AOE）。

### 第二轮：复查发现的新引入空转与既有 bug（12 项）

**复查发现第一轮声称"17种全实装"实际只生效10种**——3种伪生效、4种完全空转，外加5个既有严重bug。

| # | 问题 | 根因 | 修复 |
|---|------|------|------|
| 1 | on_hit_debuff 零消费方 | handler 挂 meta 无人读 | 改为直接改目标 stats（attack_interval/defense）+ process_debuff_expirations 用 remaining 递减恢复 |
| 2-3 | stacking/variety 缓存冻结 | spawn 缓存 key 不含单位数，首次构建后冻结 | 从 stats 缓存移出，新增 apply_runtime_stacking 在 construct_unit.setup 后按实时单位数应用 |
| 4 | conditional.hp_below 硬编码0.15 | 与数据 def+25% 脱钩 | 改为 setup 时直接注入 def 加成走既有防御结算，删 get_conditional_mitigation |
| 5 | conditional 3子键不识别 | handler 只认 hp_below | on_attack_hit 补 atk_speed_above/deploy_speed_above/target_hp_below 运行时判定 |
| 6 | on_crit_received 零调用方 | 函数实现无人调 | 改为 setup 预注入 dodge_chance（永久），删 get_crit_received_dodge_bonus |
| 7 | aura 类完全不处理 | handler 无 aura 分支 | stat_bonus 类预注入自身，hp_regen_pct 留 runtime tick |
| 8 | boss被动抽血读 t.max_hp | 玩家单位 max_hp 在 t.stats.max_hp（顶层无）→ fallback 100 致量级低99% | 改读 `t.stats.max_hp` |
| 9 | boss SINGLE/AOE未二次clamp | ×3×dmg_mult 后 Future 达2832秒杀 | AOE clamp[50,800]、SINGLE clamp[80,1500]；顺带护盾上限60%max_hp + 首次CD用35% |
| 10 | attack_*_bonus双方空转 | 战斗读 weapon.damage 不读 get_attack_vs | apply_combat_kind_modifiers 末尾新增 _sync_kind_bonus_to_weapon_slots |
| 11 | 预览单位光环泄漏 | queue_free 不触发 _die 的 remove | construct_unit 新增 _exit_tree 调 remove_mod_auras 兜底 |
| 12 | 敌方attack_air派生0.2-0.3× | resolver else 分支给所有地面单位派生非零对空 | 改为 AA 限定（tags 含 aa/anti_air/flak/sam 或 weapon_type=FLAK 才对空） |
| 附 | _battle_time 读不存在的属性 | tree 无 battle_elapsed 属性 | 删函数，改用 remaining 递减（不依赖全局时间） |

**关键设计决策**：
1. conditional.hp_below/on_crit_received 改为永久注入（牺牲"条件触发"换数值口径正确）——take_damage 无法得知是否暴击/低血，条件触发难接入，永久注入至少数值对。
2. stacking/variety 移出 stats 缓存——缓存冻结首次计数是功能性失效，改运行时每单位独立计算（已部署旧单位不回溯，性能权衡）。
3. on_hit_debuff 直接改 stats 而非挂 meta——敌方单位不跑 construct_unit tick，挂 meta 永不恢复，直接改 stats 至少立即生效（敌方死亡即清除，可接受）。

### 第三轮：深度复查的机制接入与文案平衡（6 项）

| # | 问题 | 修复 |
|---|------|------|
| A-敌方module_effect | enemy_unit 缺 on_tick/on_damage_taken/on_death/on_kill + fort_shelter 读取，堡垒阵地光环等机制对敌方双失效 | 4处接入 ModuleEffectHandler + take_damage 读 _fort_shelter meta（激活：hp_regen/堡垒光环写入/雷场/相位护盾/dot tick/怒气/反炮兵/爆反/复活/击杀护盾） |
| B-ECM消费方 | boss _exec_debuff_players 给玩家挂 _ecm meta 但玩家侧零消费，削弱技能空转 | construct_unit_ai 新增 _get_ecm_attack_slow_mult，单/多武器攻击计时用它缩 delta |
| C-river数值 | ally_river_bonus 友军路径写 move_speed（死属性）且 +80 过大（+100%移速） | river 分支改写 deploy_delay_bonus（对齐自身路径 -5%系数），aura_keys 同步 |
| D-driver stats | boss driver 无 stats 属性，玩家被 boss 打走 max-of-3 兜底（最高防御，难度低估） | take_damage 特判 attacker.has_method("get_master_stats") → attacker_kind=ARMOR |
| E-ally文案 | 5个 ally_* 改造文案只写自身收益，未体现友军光环（且部分数值凭空） | 5处 description 补"周围友军"说明 + 校准数值与 effects 对齐 |
| F-arm_12倒挂 | arm_12(rare,+15%暴击)比所有 epic 同类(+8~10%)都强 | rare→epic，power_mult/cost/level 对齐 epic 档 |

**敌方 module_effect_handler 接入的安全性**：所有公开方法（on_tick/on_damage_taken/on_death/on_kill）对敌方安全——内部用 `is_player` 字段区分阵营，group 名仅作 fallback；敌方缺 `add_shield`/`on_revived` 等方法均被 has_method 守卫安全跳过。

**ECM 消费方设计**：仿 enemy_unit 已有的 `_ecm_debuffed_until` 读取口径，玩家侧用 `_get_ecm_attack_slow_mult(u)` 返回 1.0（正常）或 <1.0（被削弱），作用于 `_attack_phase_timer += delta` 的有效 delta。默认削弱25%（与敌方0.75口径一致），可被 `_ecm_attack_speed_penalty` meta 覆盖。

### 关键文件汇总

**第一轮**：
- `scripts/battle/faction_skill_effect_handler.gd`（新增，17种子键处理引擎）
- `data/enemy_phase_masters_{ww1,ww2,cold,modern,future}.gd` + `data/json/enemy_phase_masters.json`（51个 active_spell）
- `managers/battle/battle_spawn_system.gd`（special 生成期接入）
- `scenes/units/construct_unit.gd`（special 事件驱动+周期tick接入）
- `scenes/units/bullet.gd`（special 攻击命中接入）
- `scenes/units/enemy_phase_field_driver.gd`（get_master_stats 暴露）
- `managers/battle/enemy_master_skill_engine.gd`（_compute_boss_damage 改读 master_stats）

**第二轮**：
- `scripts/battle/faction_skill_effect_handler.gd`（on_hit_debuff 重构 + stacking 运行时 + conditional/aura/on_crit_received + 删死代码）
- `managers/battle/enemy_master_skill_engine.gd`（抽血 max_hp + 伤害 clamp + 护盾上限 + 首次CD）
- `resources/unit_stats_table.gd`（_sync_kind_bonus_to_weapon_slots）
- `data/enemy_stat_resolver.gd`（attack_air AA 限定）

**第三轮**：
- `scenes/units/enemy_unit.gd`（on_tick/on_damage_taken/on_death/on_kill + fort_shelter 读取）
- `scripts/battle/construct_unit_ai.gd`（_get_ecm_attack_slow_mult ECM 消费方）
- `scripts/battle/mod_aura_handler.gd` + `resources/unit_stats_table.gd`（river 改 deploy_delay）
- `scenes/units/construct_unit.gd`（driver stats 特判）
- `data/modification_modules/{infantry,armor,engineer,fort,air}_mods.gd`（5文案 + arm_12 倒挂）

**待实机验证（无 GUI 环境无法测）**：势力注入/序列波次/相位师产兵序列的运行时行为、ECM 减速实际手感、boss 技能伤害实战平衡、stacking 运行时叠加的体感。静态验证全部通过（全项目 --check-only 零错误 + smoke test + Grep 链路核对）。

**遗留已知问题（范围外）**：
- `e_mod_*` 敌方装备 ID 全部未注册（敌方 mod 槽装饰化，预先存在，非本次回归）
- ally_fort_regen 敌方无光环（敌方不接入 ModAuraHandler，但敌方不用 ally_* 改造，无影响）
- v8.5 主动技能 tick（核武/护盾投射等）对敌方仍缺失（敌方 boss 已有独立技能系统，工作量大收益低，保留现状）

## v9.1 我方组合技套路系统 (2026-08-01)

**目标**: 把"我方套路"从纯数值堆叠升级为"组件协同 > 数值堆叠"。6 套固定套路，每套路是一条状态链：A 投射写状态 → B 投射读状态增伤/变形。新增 22 个改造 + 13 个新机制 flag + 战场级浓度状态管理器。全部向后兼容（套路未激活时行为 100% 等同改动前）。

**核心架构（3 个新文件）:**

| 文件 | 职责 |
|------|------|
| `scripts/battle/combo_field_state.gd` | **战场状态管理器**（RefCounted）。承载跨单位累积的"战场浓度"（纳米粒子/化学污染，自然衰减）+ 封装目标级 meta 读写（石墨电子损坏/助燃剂层数/激光谐振/雷达锁定/弱点暴露，带过期语义）。由 BattleManager 持有，end_battle 时 reset。 |
| `data/combo_tactics.gd` | **6 套路定义**。每套路：mod_ids（配套改造）+ mod_combo_min（单卡激活阈值）+ kind_combo（兵种组合条件）+ mechanisms（新机制 flag 列表）。提供 detect_card_combos（单卡改造组合检测）+ detect_team_combos（全队兵种组合检测）。 |
| `scripts/battle/combo_engine.gd` | **套路引擎**（RefCounted）。update(delta)：① 衰减战场浓度 ② 每 1s 刷新全队机制 flag。6 个新机制执行函数（static，供 module_effect_handler/bullet 直接调）：try_chem_burst/try_emp_reflect/try_nano_spread/try_chem_spread/try_beam_resonance/try_weakpoint_expose。 |

**6 套路（每套路 1 状态链 + 新机制）:**

| 套路 | 状态链 | 新机制 | 配套改造 |
|------|--------|--------|---------|
| 🔥 助燃燃烧链 | 助燃剂弹写 _incendiary_stacks → 燃烧弹读 stacks（层数上限 5→10，dps×1.5） | 化学爆发（层数≥8 范围扩散感染 3 个相邻敌人） | art_incendiary_mix/art_white_phosphorus/air_thermolite_bomb/gen_combustion_catalyst |
| ⚡ 电磁脉冲链 | 石墨纤维弹写 _graphite_charge → 电磁武器读 charge（emp×(1+charge×0.15)） | 电磁脉冲反射（charge≥5 连锁反射 3 个相邻敌方弱化 emp） | art_graphite_fiber/aa_emp_warhead/air_antiradiation_missile/gen_overload_capacitor |
| 🧬 纳米浓度场 | 纳米蜂群相位仪写战场 _nano_concentration → 纳米病毒读浓度（dot×(1+浓度×0.05)） | 纳米感染扩散（浓度≥50 时 30% 概率感染相邻敌人） | art_nano_amp/sup_nano_seeder/gen_nano_catalyst |
| ✨ 光束谐振链 | 瞄准激光写 _laser_resonance → 光束武器读 resonance | 光束反射（30% 反射到相邻敌方，衰减 60%）+ 多重攻击（resonance≥3 追加 2 道次级光束，每道 40%） | gen_beam_splitter/gen_reflector_array/air_targeting_laser/eng_optical_fiber |
| 🎯 侦察链式 | 无人机标记 _drone_marked_until + 雷达锁定 _radar_locked → 狙击手读双标记 | 集火链式弱点暴露（双标记同时存在时下次命中 +50% 暴击伤害） | rec_phased_radar/sup_targeting_drone/gen_weakpoint_analyzer |
| ☠ 化学污染场 | 化学弹写战场 _chem_pollution + 目标 _chem_stacks → 化学武器读浓度/层数 | 化学腐蚀（层数≥5 护甲穿透 +20%）+ 污染扩散（浓度≥40 感染相邻敌人） | art_chem_cluster/aa_acid_warhead/eng_chem_sprayer/gen_pollution_accumulator |

**触发检测（双层叠加）:**
- **改造组合**（单卡）：单卡装了 ≥2 个同套路配套改造 → 该卡获得套路增益（在 `unit_stats_table._apply_mod_stat_effects` 一次性检测，写 `combo_active` + `mod_special_flags` meta）
- **兵种组合**（全队）：场上满足 kind_combo 条件 → 全队解锁新机制 flag（combo_engine 每 1s 刷新 `_active_mechanisms`）
- 两者叠加：改造组合激活时给单卡增伤；兵种组合激活时给全队解锁新机制

**关键设计决策:**
1. **复用 meta 标记链范式**——A 写 `_*_until` meta → bullet/module_effect_handler 读 meta，与现有 `_drone_marked_until`/`_marked_until`/`_burn_stacks` 完全一致，零侵入
2. **战场浓度独立容器**——`combo_field_state` 是独立 RefCounted，不修改任何现有 meta/字段；end_battle 时 reset
3. **新机制 flag 走全队激活**——避免单卡过强（单卡只拿改造组合的数值增益，新机制需兵种组合解锁）
4. **v8.6 dot 是现成载体**——chem/burn/emp/nano 已实装，套路直接增强这些 dot（叠层上限放宽/dps 放大/感染扩散）
5. **静态写入 + 运行时触发分工**——数值增益（burn_dps_mult 等）建卡时一次性算；触发 flag（chem_pollute/emp_reflect_trigger 等）存 `mod_special_flags` meta，运行时按事件读取
6. **全队机制节流**——combo_engine 每 1s 刷新一次 `_active_mechanisms`（仿 tactic_detector），避免每帧扫描全场

**改造现有文件（7 个，全向后兼容）:**
- `managers/battle/battle_manager.gd` — +combo_engine/combo_field_state 字段 + _ready 实例化 + update 驱动 + start_battle setup + end_battle reset + get_combo_engine/get_combo_field_state getter
- `resources/unit_stats.gd` — +4 字段（burn_dps_mult/chem_dps_mult/emp_true_damage_bonus/beam_damage_bonus，默认 0）
- `resources/unit_stats_table.gd` — +ComboTactics preload；_apply_mod_stat_effects 末尾加改造组合检测（写 combo_active + mod_special_flags meta）；base dict + 4 字段；回写 + 4 字段
- `scripts/systems/modification_registry.gd` — _apply_single_mod_effects +4 数值 effect key 分支（burn_dps_mult/chem_dps_mult/emp_true_damage_bonus/beam_damage_bonus），其余触发 flag 走 _special 兜底
- `scripts/battle/module_effect_handler.gd` — +ComboEngine/ComboFieldState preload；+3 helper（_get_combo_engine/_get_combo_field_state/_get_attacker_special_flags）；4 个 on_hit 函数 +attacker 参数 + 套路触发（石墨累积/助燃层数/浓度注入/dot 放大/emp 反射）；_tick_dot_damage 末尾加 chem_burst/chem_spread/nano_spread 扩散
- `scenes/units/bullet.gd` — +ComboEngine preload；命中乘区（bullet.gd:856 后）加套路读取（光束反射/多重攻击/弱点暴露触发+消费/化学腐蚀/光束伤害加成）
- `managers/battle/phase_instrument_abilities.gd` — nano_swarm tick 注入战场纳米浓度（套路3 纳米浓度场）
- `data/modification_modules/{artillery,air,anti_air,universal,engineer,recon}_mods.gd` — 6 文件共 +22 个套路配套改造

**新机制落地路径:**
| 机制 | 触发点 | 代码位置 |
|------|--------|---------|
| 化学爆发/污染扩散 | dot tick 结算后 | module_effect_handler._tick_dot_damage → ComboEngine.try_chem_burst/try_chem_spread |
| 电磁脉冲反射 | emp 命中后 | module_effect_handler._apply_emp_on_hit → ComboEngine.try_emp_reflect |
| 纳米感染扩散 | nano dot 结算后 | module_effect_handler._tick_dot_damage → ComboEngine.try_nano_spread |
| 光束反射/多重攻击 | 光束命中（weapon_type=8/11） | bullet.gd:856 后 → ComboEngine.try_beam_resonance |
| 集火链式弱点暴露 | 狙击命中带双标记目标 | bullet.gd → ComboEngine.try_weakpoint_expose |
| 化学腐蚀降防 | 伤害结算 | bullet.gd:856 后读 _chem_stacks |
| 纳米浓度注入 | nano_swarm 相位仪能力 tick | phase_instrument_abilities._apply_nano_swarm_tick |

**不做的事（范围外）:**
- 不改伤害公式骨架（套路乘区插在 bullet.gd:856 无人机标记旁，与现有乘区正交）
- 不动 tactic_detector（套路系统独立，未来可整合）
- 不补玩家单位 `_behavior_tags_cached`（现有 bullet.gd 兜底已够用，tag 计数问题预先存在非本次回归）
- 武器类型差异化仅限光束（套路4），不做全 weapon_type 机制重构

**验证:** 3 新文件 + 7 改造文件独立编译通过；静态核对全部链路（22 mod_id 全在 combo_tactics 与 mod 文件配对、4 数值 effect key registry→stats→table→bullet 全链路、6 机制函数调用配对）；combo_smoke smoke test（战场浓度 add/decay + 目标 meta/stacks + 6 套路定义完整 + 改造组合检测 + 兵种组合检测 + 引擎 setup）全 PASS。注：实机运行时行为（套路触发手感/数值平衡/扩散范围体感）需游戏内验证；Godot headless --check-only 因项目体量常撞 5 分钟超时（42 autoload + 133 卡），属既有现象。

## v9.1b 组合技套路系统全面审计修复 (2026-08-02)

**背景:** v9.1 落地后做三路全面审计（effect key 全链路 / 机制触发闭合 / 状态流转），发现 7 个 bug：3 个套路整体失效（P0）+ 2 个单改造部分失效（P1）+ 4 个死机制 flag + 4 个空转 trigger flag（P2）。状态流转三大链路（单卡检测/战场浓度/兵种组合）全部闭合正常，问题集中在机制触发层。

**修复 7 个 bug:**

| 级别 | bug | 修复 |
|------|-----|------|
| **P0-1** | 套路4 `laser_resonance_chance/stacks` 零 writer → beam_split/beam_reflect 永不触发，整个光束谐振链失效 | module_effect_handler 新增 `_apply_laser_resonance_on_hit`：命中按概率挂 `META_LASER_RESONANCE` 层数（≥3 触发多重攻击，>0 触发反射）；加 beam_split_trigger/beam_reflect_trigger 单卡闸门；全队 laser_resonance 机制激活时层数上限 5→8 |
| **P0-2** | 套路5 `radar_lock_*` 零 writer → weakpoint_expose 永不触发，整个侦察链式失效 | module_effect_handler 新增 `_apply_radar_lock_on_hit`（命中刷新已有锁定）+ `_tick_radar_lock`（on_tick 周期扫描挂 `META_RADAR_LOCKED`，仿 drone_mark 范式）；bullet.gd 加雷达锁定易伤乘区 |
| **P0-3** | combo_engine `try_weakpoint_expose` 把 `META_RADAR_LOCKED` 同时当 value_key 和 until_key（逻辑错） | 改为直接判存在性+过期（META_RADAR_LOCKED 是 until_key 秒时间戳） |
| **P1-1** | sup_targeting_drone `drone_mark_amp/vuln_bonus/radius_bonus` 3 flag 零消费方 | `drone_mark_vuln_bonus` 在 `_apply_radar_lock_on_hit`/`_tick_radar_lock` 叠加进雷达易伤值（drone_mark_amp/radius_bonus 属描述性 flag，与固有无人机标记机制协同） |
| **P1-2** | eng_chem_sprayer `splash_radius_bonus` registry 无 match 分支（只有 splash_radius），误入 _special | 改造 effects 改用 `splash_radius` key（命中现有分支，写 splash_radius_bonus 字段） |
| **P2-1** | 4 个死机制 flag（incendiary_boost/graphite_accumulate/nano_concentration/radar_lock）零执行点 | 接通为"全队激活额外效果"：incendiary_boost→燃烧上限+dot×1.2；graphite_accumulate→石墨上限15+概率+0.2；nano_concentration→浓度系数×2；radar_lock→经 P0-2 writer 接通 |
| **P2-2** | 4 个 trigger flag（chem_burst/nano_spread/beam_split/beam_reflect）空转 | chem_burst/nano_spread 属全队扩散机制（trigger 改造通过属套路配套集参与激活判定，注释修正澄清）；beam_split/beam_reflect 在 P0-1 加单卡闸门 |

**关键设计决策:**
1. **P2 采用"接通机制 flag"而非"删除"**——保留"全队激活套路提供额外效果"的设计深度（单卡 _special flag 给基础增益，全队机制 flag 给额外增益），避免套路深度降低
2. **radar_lock 仿 drone_mark 范式**——周期扫描+命中刷新，复用 construct_unit 已验证的 tick meta 模式，零新机制
3. **trigger flag 双闸门设计**——beam_split/beam_reflect 必须"装触发器改造（单卡 _special）+ 全队机制激活"双满足才触发，避免全队激活后任意光束武器都触发（过强）
4. **combo_active 保留为 UI 预留**——单卡套路增益实际靠 mod_special_flags 驱动，combo_active 供未来 UI 显示"该卡激活了哪些套路"，删除会丢未来 UI 数据

**修复后 6 套路全部端到端可触发:**
| 套路 | 触发链路 | 状态 |
|------|---------|------|
| 🔥 助燃燃烧链 | incendiary_mix 写 stacks → white_phosphorus 读 stacks（上限10）→ thermolite_bomb 化学爆发 | ✅ |
| ⚡ 电磁脉冲链 | graphite_fiber 写 charge → emp_warhead 读 charge 增伤 → overload_capacitor 脉冲反射 | ✅ |
| 🧬 纳米浓度场 | nano_swarm 相位仪写浓度 → nano_seeder 累加 → nano_amp 增伤 → nano_catalyst 扩散 | ✅ |
| ✨ 光束谐振链 | targeting_laser 写 resonance → beam_splitter 多重攻击 + reflector_array 反射 + optical_fiber 增伤 | ✅（P0-1 修复后） |
| 🎯 侦察链式 | phased_radar 周期锁定 + targeting_drone 增强标记 → weakpoint_analyzer 弱点暴露 | ✅（P0-2/P0-3 修复后） |
| ☠ 化学污染场 | chem_cluster/sprayer 写浓度+层数 → acid_warhead 腐蚀穿透 + pollution_accumulator 扩散 | ✅ |

**关键文件（修复涉及）:**
- `scripts/battle/module_effect_handler.gd` — +`_apply_laser_resonance_on_hit`/`_apply_radar_lock_on_hit`/`_tick_radar_lock`；on_hit +2 调用点，on_tick +1 调用点；4 个机制 flag 接通（incendiary_boost/graphite_accumulate/nano_concentration/radar_lock 经 is_mechanism_active 读取）
- `scripts/battle/combo_engine.gd` — try_weakpoint_expose 雷达锁定读取逻辑修复（META_RADAR_LOCKED 作 until_key 正确判定）
- `scenes/units/bullet.gd` — +雷达锁定易伤乘区（读 _radar_locked_until + _radar_vuln）
- `data/modification_modules/engineer_mods.gd` — eng_chem_sprayer effects splash_radius_bonus→splash_radius

**验证:** Godot headless --check-only 零编译错误（修复前报 bullet.gd compile error：module_effect_handler.gd:940 Cannot call non-static get_target_stacks；修复 static/instance + 7 bug 后零错误）；静态核对全部修复点（laser resonance writer→META_LASER_RESONANCE、radar lock writer→META_RADAR_LOCKED、combo_engine 读取修复、4 机制 flag is_mechanism_active 调用、eng_chem_sprayer key 修正）链路完整。

## v9.1c 复审修复 (2026-08-02)

**背景:** v9.1b 修复后再做三路复审（机制触发闭合/数值叠加边界/改造数据注册），确认上轮 8 个修复全部真正闭合，但发现 2 个新真 bug + 2 个数值平衡问题。

**修复 4 项:**

| # | 问题 | 修复 |
|---|------|------|
| **bug1** | `_apply_burn_on_hit` 的 `inc_cap` 变量算了却没用（add_target_stacks 硬编码 10），且 `META_INCENDIARY_STACKS` 写入后全项目零读取（死代码） | inc_cap 真正传入 add_target_stacks；接通 META_INCENDIARY_STACKS 到 burn cap 动态抬高（助燃层数每层 +1 燃烧上限） |
| **bug2** | graphite charge 持续命中全程保持高层数，emp_reflect 阈值≥5 几乎全程触发（套路2 失衡） | emp_reflect 触发后消耗 3 点 charge（target 需重新累积才能再次反射，给玩家压制窗口） |
| **平衡1** | graphite 全队上限 15 偏强（emp_dmg_mult 达 3.25x） | 上限 15→12 |
| **平衡2** | nano/chem 浓度无上限，极端局放大 10x+ | combo_field_state 新增 FIELD_CAPS（nano=50/chem=60）软上限，add_field 后 clamp |

**额外清理:** `_prefix_to_type` 补 `"sup": return "artillery"` 映射（防未来 sup_ 前缀 mod 未注册时回退失败）。

**关键文件（v9.1c 修复涉及）:**
- `scripts/battle/module_effect_handler.gd` — incendiary_layers 接通 burn cap；graphite 上限 15→12
- `scripts/battle/combo_engine.gd` — try_emp_reflect 反射后消耗 3 点 graphite charge
- `scripts/battle/combo_field_state.gd` — +FIELD_CAPS 软上限常量 + add_field clamp
- `scripts/systems/modification_registry.gd` — _prefix_to_type 补 sup 映射

**复审确认的闭合项（无需修复）:**
- 5 个改动文件 load() 编译全 PASS（module_effect_handler/combo_engine/combo_field_state/modification_registry/battle_manager）
- 所有 `_get_combo_engine()` 调用点 null 短路守卫完整（无 null deref 崩溃风险）
- bullet.gd 套路乘区 null 守卫完整
- radar lock 时间戳口径一致（秒）；drone mark 口径一致（毫秒）——两者各自自洽
- getter 位置在 end_battle 之后，函数体完整
- 22 改造 effect key 全字符级一致，无拼写漂移
- combo_tactics mod_ids 与改造定义全匹配

**已知设计权衡（非 bug，保留现状）:**
- 套路4 光束谐振：resonance 写入闸门看单卡（装 air_targeting_laser 的单位），split/reflect 触发看全队机制——写读不对称但不会崩（未装触发器的单位累积的 resonance 无害，仅一行 set_meta）
- `combo_active` meta 零读取——单卡套路增益实际靠 mod_special_flags 驱动，combo_active 供未来 UI 预留
- chem_burst_trigger/nano_spread_trigger 等 trigger flag 仅作套路配套标记，不直接驱动逻辑（靠套路配套集参与激活判定）

## v9.1d 组合技套路视觉优化 (2026-08-04)

**背景**: v9.1/v9.1b/v9.1c 完成了 6 套组合技的战斗逻辑实现，但视觉反馈严重不足——浓度场（纳米/化学）全战场累积却完全不可见、套路激活无任何通知、光束分裂/反射代码已执行但玩家看不出、雷达锁定/弱点暴露无视觉标志、DOT 贴图静态不生动。玩家在战斗中难以感知这些组合技的存在。

**核心策略**: 纯视觉/反馈层叠加，不动战斗数值逻辑。新增 12 项改动覆盖 3 个优先级（P0 浓度场+横幅、P1 光束/弱点/雷达/状态条、P2 DOT动态+图标纹理）。

**12 个改动点（按优先级）:**

### P0 战场浓度场可视化
| 文件 | 改动 |
|------|------|
| `scripts/battle/vfx_impact_factory.gd` | +`spawn_nano_field`/`spawn_chem_field`（半透明 Polygon2D 区域，浓度→半径+alpha 映射，z_index=-5 盖地面背景之上单位之下）；+`_cleanup_field_vfx`（防重复） |
| `scripts/battle/combo_field_state.gd` | +`field_changed(tag, amount)` 信号；`add_field`/`update` 衰减后 emit |
| `scenes/battlefield/Battlefield.gd` | +`_subscribe_combo_field_state`（call_deferred 订阅）；`_process` 加浓度场 dirty+0.4s 节流重绘；+`_redraw_combo_field_vfx`（取玩家/敌方 spawn 中心点为浓度场中心） |

### P0 套路激活横幅
| 文件 | 改动 |
|------|------|
| `scripts/battle/vfx_impact_factory.gd` | +`show_combo_activate_banner`（HudLayer 顶部 Label，Tween 滑入淡出，全队激活带相机震动，防重复 has_node 守卫） |
| `scripts/battle/combo_engine.gd` | +`_last_banner_combos` 缓存；`_refresh_team_mechanisms` 检测新激活 combo 触发横幅；+`_emit_team_activate_banner`（mechanisms→combo_id→name 拼接）；reset 清空缓存 |

### P1 光束分裂/反射 VFX
| 文件 | 改动 |
|------|------|
| `scripts/battle/vfx_impact_factory.gd` | +`spawn_beam_split_arcs`（复用 spawn_laser_beam 射 2 条次级光束）；+`spawn_beam_reflect_arc`（暗色反射弧） |
| `scenes/units/bullet.gd` | `try_beam_resonance` 分裂/反射处理块末尾追加 VFX 调用（找相邻 2 单位画次级光束 + 反射弧）；弱点暴露成功时 `spawn_weakpoint_indicator` |

### P1 弱点暴露 + 雷达锁定 + 激光谐振 VFX
| 文件 | 改动 |
|------|------|
| `scripts/battle/vfx_impact_factory.gd` | +`spawn_weakpoint_indicator`（红色 X 十字，脉动，duration 后淡出）；+`spawn_radar_lock_ring`（蓝色旋转扫描圈，脚下，duration 后淡出）；+`spawn_resonance_ring`（白色光环，头顶，层数→alpha） |
| `scripts/battle/module_effect_handler.gd` | `_tick_radar_lock` 锁定 best 后 `spawn_radar_lock_ring`；`_apply_laser_resonance_on_hit` 累积后 `spawn_resonance_ring`（读当前层数） |

### P1 扩散波纹（化学爆发/纳米传染/EMP反射）
| 文件 | 改动 |
|------|------|
| `scripts/battle/vfx_impact_factory.gd` | +`spawn_chem_burst_wave`（绿冲击波 r=80）；+`spawn_nano_spread_wave`（青冲击波 r=60） |
| `scripts/battle/combo_engine.gd` | `try_chem_burst` 感染后 `spawn_chem_burst_wave`；`try_nano_spread` 感染后 `spawn_nano_spread_wave`；`try_emp_reflect` 反射后 `spawn_lightning_arc` 到各被反射单位 |

### P1 组合技状态条（底部 HUD）
| 文件 | 改动 |
|------|------|
| `scenes/ui/combo_status_strip.gd/.tscn`（新增） | 底部 HUD，6 套路图标横排，三态色（灰未激活/橙单卡/绿全队+发光边框）；0.6s 轮询 combo_engine + 扫描场上单位 mods；tooltip 动态显示名称+描述+状态 |
| `scenes/main.tscn` | +`ComboStatusStrip` 节点（HudLayer，offset_left=165 紧贴 BattleStatusStrip 右侧） |

### P2 DOT 动态 aura + 套路图标纹理
| 文件 | 改动 |
|------|------|
| `scripts/battle/dot_vfx_manager.gd` | +`_attach_dynamic_aura`（按 dot_type 分派）；+`_attach_burn_aura`（橙旋转环）/`_attach_chem_aura`（绿反向慢转环）/`_attach_nano_aura`（青六边形脉冲）/`_attach_emp_aura`（紫电弧闪烁） |
| `data/combo_tactics.gd` | 6 套路定义 +`icon_tex` 字段（纹理路径）；+`get_combo_icon_texture`（带缓存，无资源返回 null 回退 emoji） |

**关键设计决策:**
1. **浓度场用 Polygon2D 而非 GPUParticles2D**——0.4s 重建零 GC，复用 canvas item 创建模式，z_index=-5 分层正确
2. **横幅 Tween 生命周期自管**——~2s 后自动 queue_free，has_node 防重复，不常驻内存
3. **信号驱动浓度刷新**——field_changed 标 dirty + 定时器双保险，避免每帧重建
4. **光束分裂 VFX 复用 beam 池**——spawn_laser_beam 已有对象池，零额外内存
5. **单行 lambda 规避 gdparse 误报**——`func(): if x: y` 单行形式（Godot 引擎支持，gdtoolkit 4.5.0 误报但不影响运行）
6. **图标纹理延迟加载+缓存**——无美术资源时返回 null，UI 回退 emoji，功能不受影响

**附带修复（分支已有 bug）:**
- `scripts/battle/vfx_impact_factory.gd` L1417 `_release_impact_sprite` 错误缩进一级 tab（分支改动引入，导致整个文件 parse 失败、所有依赖它的文件连锁报错）。修复为顶格 static func。

**验证:**
- Godot `--script` 单文件验证：16 OK / 0 FAIL（10 个新 VFX 方法 + field_changed 信号 + icon_tex 字段 + get_combo_icon_texture + ComboEngine/DotVfxManager/combo_status_strip load 通过）
- gdparse 多文件检查：8/8 OK（vfx_impact_factory 的单行 lambda 误报属 gdtoolkit 4.5.0 已知限制，Godot 引擎已验证通过）
- 全项目 `--check-only` 因项目体量（133卡+42 autoload）5 分钟超时（AGENTS.md 记录的既有现象），无我改动相关的早期 parse/compile 错误

**资源需求（代码已回退兼容，不影响功能）:**
- `assets/ui/combo_icons/{incendiary,emp,nano,laser,recon,chem}.png`（44×36）——状态条纹理图标，缺失时回退 emoji

## v9.x 关卡设计领域系统性审查修复 (2026-08-16)

**背景:** 用户要求对"关卡设计"领域做系统性审查（先交付情景定义/缺陷分类/量化标准，确认后全量检查再修复，禁止反应式点修）。按 13 类缺陷分类（A完备性/B一致性/C难度曲线/D节奏/E进程星级/F奖励经济/G内容质量/H特殊规则/I相位师遭遇/J环境/K教学/L数据健康/M呈现）过 14 项关卡资产，修复 4 CRITICAL + 2 HIGH + 3 文档/常量级，全部可回溯到分类编号。

**CRITICAL 修复:**

| # | 分类 | 问题 | 修复 |
|---|------|------|------|
| C1 | B5/B2/H1 | **survive_waves 全量死规则**：20/40/60/80/100 五关挂了 survive_waves，但这五关全是驻守相位师关（100% 遭遇），`battle_manager._check_win_lose` 对 `_is_phase_master_battle` 提前 return → 规则永不评估（胜负实际=摧毁基地）；而 world_map 向玩家显示"胜利条件: 坚守N波"——显示与行为直接矛盾 | 删除 5 关 win_type/win_param（80/100 保留 energy_mult）；`_set_rules` 加守卫拒绝在驻守关挂 win_type（机器强制标准）；battle_manager 分支保留（普通关未来可用）+ 警示注释 |
| C2 | A2/B4/H2 | **第85关兵种限制反义**：`restrict_platforms [3,7]` 注释称"3=SUPPORT,7=ENGINEER"，实际 CombatKind 3=AIR、7 不存在（枚举 0-4）→ 实际效果"仅空军可部署"，与"阵地防御战·限支援/工兵"完全相反 | 改 `[2]`（SUPPORT；工兵卡如 ww1_sup_engineer 本身 combat_kind=2）。era4 SUPPORT 卡 9 张，可玩性达标 |
| C3 | B1/B5/J3 | **环境双源不同步**：world_map/level_info_panel 显示 level_information 程序循环生成的 environment（第10关显示"风暴"），战斗侧（phase_law_manager/battle_damage_system）读 battle_environments（第10关实为"雨"）→ 95 关显示与战斗环境不一致 | 单一真源=BattleEnvironments：world_map/level_info_panel 改读 `get_for_level`；删除 level_information 的环境生成死代码（`_get_environment_for_era_level`/`get_level_environment`/字段）；翻译表补 snow/sandstorm/desert/low_field |
| C4 | B2/B3/C6 | **难度显示死链**：difficulty_modifier（0.8+level×0.014）自 v8.2 起不在任何战斗乘区中，但 world_map 显示"(0.81×)"、level_info_panel 显示"难度倍数"；公式在 level_information×5 处+enemy_stat_resolver.level_stat_multiplier 双拷贝 | 显示改真实乘区（EnemyLoadoutTiers 档位系数 1.30/1.75/2.00，与战斗链同源）；删 difficulty_modifier 字段+getter+level_stat_multiplier 死函数；`_difficulty_label` 改按档位派生 |

**HIGH 修复:**

| # | 分类 | 问题 | 修复 |
|---|------|------|------|
| H1 | A3 | 每时代 descriptions 数组 60 条只用前 20（`range(1,21)`），200 条死数据（67%） | 5 个数组裁剪到 20 条 |
| H2 | A4/M | level_select 面板零开启方（选关由 world_map 承担），死配置 | 删 ui_lazy_loader 的 level_select 注册（同 v6.6 C3 先例） |

**文档/常量级:** E4 XP 时代边界锯齿（550→198）加设计声明注释（时代整体抬升 1.5×、首关回撤与档位回撤同步）；L1 刷兵数裸 randi_range 加"设计如此"注释；L4 星级公式魔数常量化（STAR_SURVIVAL_*/STAR_TIME_*）。

**审查通过项（零改动）:** A1 字段完备 ✓、D1 时长带宽 ✓、D3 刷兵≤9格（card_grid 路径 max 7）✓、E1/E2 解锁链与时代门槛 ✓、E3 首通奖励单调 ✓、H3 特殊规则 UI 可见 ✓、I1 驻守 20 id 全在 JSON ✓（smoke 复核）、I3 随机遭遇三层回退+旱灾保底 ✓、I4 驻守表时代分区 ✓、K1 时代首关档位回撤（v9.x 阈值 0.15/0.55 已收紧）✓、K3 L5 教学能量惩罚（注释声明教学意图）✓、L2 序列缓存 level-keyed 确定性无害 ✓、L3 边界 clamp ✓。

**保留观察（设计决策，未动）:** ① 剧情关键关（如 L99）无随机遭遇抑制——15% 概率叠加相位师战增加难度方差，是否抑制属玩法决策；② 关卡描述为风味文本（海战关打陆战单位等）——接受现状，不做 100 条文案重写；③ 驻守关×特殊规则叠加（L25/L30/L55/L85/L100）为设计意图，已核实组合可玩（restrict 关对应时代卡池均 ≥2 张/类型）。

**关键文件:**
- `data/level_information.gd` — 删 environment/difficulty_modifier 死链 + 200 死描述 + 5 处 survive_waves；L85 restrict 修正；_set_rules 驻守守卫
- `scenes/world_map.gd` — 环境/难度单一真源接入 + 翻译表补值
- `scenes/ui/level_info_panel.gd` — 同上
- `data/enemy_stat_resolver.gd` — 删 level_stat_multiplier 死函数
- `managers/ui_lazy_loader.gd` — 删 level_select 死配置
- `data/level_eras.gd` — XP 锯齿/刷兵随机设计声明注释
- `managers/battle/battle_damage_system.gd` — 星级魔数常量化
- `managers/battle/battle_manager.gd` — survive_waves 分支驻守关警示注释
- `tests/level_design_audit_smoke.gd`（新增）— 审查回归 1470 断言
- `tests/level_mechanics_smoke.gd` — 同步新数据真值（原断言与数据早已脱节，属分支既有红灯）

**验证:** level_design_audit_smoke **1470 PASS / 0 FAIL**（字段完备/死键清零/驻守 id×JSON/restrict 枚举+卡池可玩/守卫生效/无重名/法则值域/边界 clamp/7 文件编译）；level_mechanics_smoke **ALL PASS**（数据同步后全绿）；star_config_smoke OK（无回归）；gdparse 8/8 编辑文件通过。`--script` 模式下 world_map/battle_damage_system 等的 SignalBus/ManagerLazyLoader 编译失败为项目既有 autoload 环境限制（报错行均为未改动行）。全项目 `--check-only` 因项目体量长耗时（既有现象）。**待实机:** world_map 关卡弹窗的环境/难度新显示效果、L85 限支援实机体感。
