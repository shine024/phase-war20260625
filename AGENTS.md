## Project Overview

**Phase War** (相位战争) — tactical card strategy game. Players deploy historical military units (WWI to future eras) on a grid-based battlefield, manage card evolution, faction diplomacy, and intel-driven progression.

- **Engine**: Godot 4.5 (config_version=5)
- **Language**: GDScript
- **Resolution**: 1280x720, `gl_compatibility` renderer（无引擎级 fps 上限配置——project.godot 未设 max_fps/low_processor_mode，v26.4 核对勘误）
- **Entry scene**: `res://scenes/title_screen.tscn`
- **Main game scene**: `res://scenes/main.tscn`

## 发行宪法（红线，任何功能设计前先过）

**`docs/发行宪法.md`（2026-09-19 起）四条红线：C1 商业化只买便利/外观、绝不碰内容可及性与概率暗箱；C2 核心玩法 100% 离线可玩、联网只做增量；C3 一切概率/保底口径玩家可见（UI 文案数值从常量读，禁止硬编码）；C4 对外路线图 ≥3 版本 + 发版必打 tag。** 改经济数值/概率/商业化/联网相关代码前先读该文档；冲突即违宪。

## v6.19 竞品反思修订批：概率可见化 + 埋点 + 发行宪法（2026-09-19~20，详见 CHANGELOG）

**改制造面板/情报舱/黑门弹窗/game_manager 遭遇链/埋点消费前必读本节。**

- **保底口径文案唯一源**：`ManufacturePools.describe_card_pity(pity)` / `ModManufacture.describe_box_pity(pity)`（数值读常量自动跟随；软保底 ×2 语义，**严禁"必出"字样**——宪法 C3）。UI 落点=制造舱**中栏"品质概率池"可见区顶**金色行（卡牌 `_rebuild_pool_bars` / 随机箱 `_update_mod_box_detail`）。
- **制造舱右栏已复活（v6.19.4，反转 v6.19.2"维持现状"拍板——用户实机反馈"预览不到要制造的战斗卡"）**：TargetNamePanel/InfoPanel/RequirementsPanel/StatsPanel/ResourcePanel 五分节 + 新增 PreviewPanel 卡面预览（150px，`UiAssetLoader.card_icon_for_list` 全回退链）现按分支显隐，玩家可见。**显隐唯一口=`evolution_panel._set_detail_sections_visible`**；纪律：任何写右栏内容的分支必须显式亮起要展示的分节（无选择态整组隐藏=tscn 默认；不可制造兜底分支只亮名/情报；mod 模式亮四块、预览与统计九格隐藏）。右栏结构：DetailInner→**DetailVBox**→[DetailScroll(滚动内容) + ButtonArea(钉底恒显)]，**制造按钮永远在折叠线以下不可见是红线**；ButtonArea 内是 ButtonHBox（v6.19.4 修掉存量叠盖 bug：PanelContainer 多子控件同矩形互叠，曾把「开一次箱」盖死）。⚠️ evolution_panel.tscn 的 `parent` 属性是场景根起算全路径——挪动 DetailScroll 层级时必须同步全部子孙节点路径（29 处，漏改=%unique 名静默失踪）。回归锁 `tests/unit/ui/test_evolution_detail_revival.gd`（3 用例）+ 视觉探针 `tests/_tmp_evo_detail_probe.tscn`。
- **相位师遭遇规则**：查询口=`GameManager.get_phase_master_encounter_status()`（情报舱敌方情报 Tab「相位师情报」分区消费）；递增参数具名化 `PHASE_MASTER_DROUGHT_TRIGGER/STEP/ENCOUNTER_CAP`（与 check 同源，改一处两边跟随）；UI 分区文案含字面 % 时记得 `%%` 转义（运行期 formatting error 静默吞行）。
- **埋点**：`PerformanceMetricsManager.record_milestone`（**跨会话持久** `user://milestones.cfg`，时间戳 `total_ms`=累计游戏内时长；事件：combo_active_first/combo_full_first/first_mythic_mod/**first_mythic_card**/first_garrison_clear/first_phase_master_encounter，判据见 `docs/试玩验收_长线节点.md`）+ `mark_battle_flag`（场次聚合 battles_total/spedup/skipped/**sped_or_skipped 联合计数**，使用率=sped_or_skipped/total，"倍速+跳过>70% ⇒ 回炉"判据）。**RefCounted/静态上下文取 autoload 必须走 `Engine.get_main_loop() as SceneTree → root.get_node_or_null()`**（combo_engine 教训：直接写 get_node_or_null = 编译错级联、--script 冒烟零输出卡死）。
- **晶体垫封顶（v6.19.1 核验落地）**：`advance_mod_box_pity_with_crystals` 以 `ModManufacture.PITY_THRESHOLD-1` 封顶——已到激活线前拒绝垫付，未到线按剩余额度部分成交（`capped` 键标记）。改随机箱 pity 阈值时封顶自动跟随。
- **黑门购次二次确认（v6.19.1 核验落地）**：`world_map._enter_blackgate` 免费用尽时先弹 `_confirm_blackgate_purchase` 确认框再扣 60 能量块（原为静默扣费）；确认后走 `_enter_blackgate_confirmed` 同一进入链。
- 首遇引导：`FeatureUnlockPopup.show_once("phase_master_intel_guide"/"grace_end_notice")`——前者三步链文案（遭遇→档案区「情报舱」工位→战前建议预配克制），后者经 `GameManager._show_notice_when_popup_free` 错峰（**L10 是驻守关，通关时两弹窗同帧，直接 show_once 会叠层互盖**）；保护期计入递增计数的口径已写进情报舱分区与预告文案（机制红线不动，文案如实）。build_advisor 相位师条目照旧：驻守关必提示 / 野外递增≥1.5×基础提示。
- 黑门弹窗规则数值走 `EndlessBlackgateRef.FREE_ENTRIES_PER_DAY/ENERGY_PER_EXTRA_ENTRY/WEEKLY_MARROW_CAP` 静态常量（勿再硬编码 3/60/400）。

## v6.20 开场设定修正 + 教程聚光指向批（2026-09-20，详见 CHANGELOG）

**改苏醒演出/教程覆盖层/教程步骤数据前必读本节。** 用户拍板：①主角是穿越回来的相位师、本来就认识战斗卡，「发现卡」式叙事违设定；②教程是对玩家的，不能只有文字——指向按钮要有光点，悬停要有介绍。

- **苏醒演出「三拍教学」已删**（truck_base E 段）：`_wakeup_teach_beat` 整删，`wakeup_wrist/backpack.png` 与枕下纸条退出开场链（资产留档）。现为「装备自检两拍」纯字幕（~8.6s）。「卡在哪/怎么装」引导归教程覆盖层，勿再往开场演出里塞系统教学。
- **教程聚光唯一真身 `scripts/ui/tutorial_spotlight.gd`**：`attach(host, target, tip)`=暗幕挖孔+金色脉冲环+悬浮提示条；全 IGNORE 纯视觉、每帧跟随目标。⚠️ 宿主必须是独立覆盖层根——与游戏 UI 同宿主会被 `move_child(0)` 压到底下画不出（探针实踩）。motion_reduce 自动恒亮。
- **教程步骤数据三键**：`spotlight_key`/`spotlight_tip`/`spotlight_press_advances`（现挂第 2/3 步→基地卡牌墙热区）。消费口=tutorial_overlay `_update_spotlight`：chain_paused（点播段面板已开）与 gate_locked（锁定工位）不聚光；`spotlight_press_advances` 步骤**点真实入口按钮=等效点动作键**（`_advance(true)` 跳过动作信号防 toggle 二次关门——`_on_next_pressed` 已重构为 `_advance(skip_action)`）。
- **入口按钮查询**：truck_base `get_hotspot_button_for_key(key)` / bottom_function_bar `get_button_for_key(key)`（growth 在底栏键名=progression，别名换算在 overlay 侧）。加新教程步聚光先确认目标键两条链都能解析。
- **基地 close-wait 断链已根修**（存量 bug）：truck_base 关面板两路（面板 closed 信号/ESC）都通知 `_notify_surface_closed` → TPM——此前只有 main._close_overlay 通知，教程第 2/3 步在基地关卡仓后永停摆。**新嵌入面板的关闭路径必须接 `_notify_surface_closed`**，否则教程挂起链再断。
- 验证件：`tests/_tmp_v620_smoke.gd`（编译+数据）+ `tests/_tmp_v620_flow_smoke.tscn`（真基地端到端 10 断言，跑前备份 user://）+ `tests/_tmp_spotlight_probe.tscn`（视觉像素断言）。

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
> - **全项目兜底** → `--check-only`（启动 30 autoload + 构建 131 卡，常撞 5 分钟超时，仅大改动用）

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
7. **`run.scene_headless` 裸模式陷阱（2026-09-02 Steam 采集实测）**：**不传 `screenshots`/`input_script` 参数时走 `--headless` 裸模式——64×64 假窗口 + dummy 渲染**，游戏逻辑照跑但视口纹理全空（截图/录制全黑）。要画面必须带至少一个截图参数（预热截图即可）。另：`extra_args` 会被插在场景路径**之前**，不能用 `--` 传 user args（会把场景路径吞掉）——参数改走临时文件（如 `.godot/steam_cap_mode.txt`）。
8. **采集编排器（Steam 素材管线范例 `tests/_tmp_steam_cap.gd`）**：挂载场景用 `root.add_child + current_scene 赋值`（**绝不能 `change_scene_to_file`，会连驱动器一起释放导致静默断链**）；match 分支里的协程函数必须 `await`（不 await 则协程链在首个 await 处被孤儿回收，现象是"函数只跑了前半段"）；运行期改 `w.size` 在 ANGLE 环境会杀渲染表面（启动参数给分辨率才安全）；战场 1080p 截图走 SubViewport 超采样（容器 `stretch=false` + 自建第二相机 `make_current` + zoom 1.5 复刻 1280×720 设计取景，实测内容带 world y∈[140,853] 最佳机位 cam.y=495）。

## godot_ai 插件（DSH 游戏创造模式，2026-09-12 安装）

**`addons/godot_ai` v3.1.5** 已安装并通过 `agent_tools` 桥写入 `editor_plugins/enabled`（带 agent_tools/gdunit4/godot-mcp 三插件共存）。配套 **DSH 插件 `dsh-godot-ai@0.6.0`** 已装入 web profile。三者分工：agent_tools（9920 TCP JSON-RPC，自研）、godot-mcp（1.0.0，独立 MCP）、godot_ai（编辑器 Addon + uv Python sidecar，HTTP 8000 / WS 9500 + 编辑器 dock）。

- **版本锁 v3.1.5**：`dsh-godot-ai 0.6.0` 仅测试过 Godot AI 3.1.5（45 工具、attach 协议 v1）；GitHub 最新已是 v4.1.0（协议大版本变更），**不要升级到 v4**，也警惕 addon 自更新（dock 里有更新控件，弹 v4 拒绝）。
- **⚠️ 2026-09-12 实测勘误（已解决）**：当日 `session_manage` 曾报 **plugin/server 3.2.5**（高于版本锁一个 minor，DSH 兼容性未回归；`editor_screenshot` / `game_eval` 会打死 MCP 连接层——"Failed to initialize server session"，sidecar 与 HTTP 8000 仍存活、本会话不可恢复）。**同日晚些 DSH 侧重装回 3.1.5（用户拍板锁定），plugin.cfg 已核**；3.2.5 特有回归是否消失待复测，挂了仍回退 agent_tools（截图走 `editor_game_screenshot`，深流程走 CLI `--script`）。
- **启用尚需编辑器重启**（写设置时编辑器在跑，走 `EditorInterface.set_plugin_enabled` 才能免重启热加载，agent_tools 未暴露该方法）。
- headless 自动禁用（`GODOT_AI_ALLOW_HEADLESS` 可越过）→ 不影响 `--check-only` / gdunit 测试流程；启用时会自动加 autoload `_mcp_game_helper`（禁用插件时自动移除）。
- sidecar 经 `uvx` 拉 `godot-ai` PyPI 包，首次启动需网络。
- 完整启用流程（DSH 侧）：重启 DSH Web → Settings 点"安装游戏创造模式"（创建 `godot-creator` / `godot-creator-adaptive` 两个用户 preset）→ 新会话选 Godot Creator，顶部状态"已连接"即通。

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

### Autoload Singletons（project.godot 实际 31 个，2026-09-12 核对——PhaseLawManager 已随 P2-7 法则退役删除；EvolutionPathRegistry 已随 v26.6 结构收敛删除，autoload 31→30；v28 质感轮 +ColorGrade 30→31，见停用清单）

> 双层设计说明：部分 manager **同时**存在于 project.godot [autoload] 与 ManagerLazyLoader 配置——
> 后者仅作 `ensure_loaded("<id>")` 的统一访问入口，命中 `/root/NodeName` 即复用，不会重复实例化。

| # | Singleton | File | Role |
|---|---|---|---|
| 1 | `SignalBus` | `scripts/signal_bus.gd` | 中央事件总线（79 个 signal 声明；同名死信号已清理） |
| 2 | `BattleInputState` | `scripts/battle_input_state.gd` | 战斗输入状态机 |
| 3 | `EnergyManager` | `managers/energy_manager.gd` | 战斗能量池 |
| 4 | `PhaseInstrumentManager` | `managers/phase_instrument_manager.gd` | 4色装备槽 + 符文槽 + 相位场等级(Lv1-30)/属性点分配 |
| 5 | `BattleManager` | `managers/battle/battle_manager.gd` | 战斗编排（委托 BattleSpawnSystem/BattleDamageSystem） |
| 6 | `GameManager` | `managers/game_manager.gd` | 游戏流程；15% 相位师遭遇 |
| 7 | `BlueprintManager` | `managers/blueprint_manager.gd` | 卡牌账号级养成（副本/星级/改造/进化/继承/HP下限） |
| 8 | `DropManager` | `managers/drop_manager.gd` | 战后掉落表与领取 |
| 9 | `SaveManager` | `managers/save_manager.gd` | `user://save_slot_%d.json`（3 槽；`save.json` 仅旧单档兼容读），schema v9，迁移链 v1→v9（v9 迁移体 no-op，版本号保留） |
| 10 | `AudioManager` | `managers/audio_manager.gd` | 音频 |
| 11 | `BasicResourceManager` | `managers/basic_resource_manager.gd` | 全局货币（纳米材料/合金/晶体/能量块 共 4 种；许可证 v7.3 删、科研点已随 P2-7 退役） |
| 12 | `ObjectPoolManager` | `managers/object_pool.gd` | 子弹/伤害数字对象池 |
| 13 | `UILazyLoader` | `managers/ui_lazy_loader.gd` | UI 面板按需加载 |
| 14 | `ManagerLazyLoader` | `managers/manager_lazy_loader.gd` | 非 core manager 按需加载 |
| 15 | `PerformanceMetricsManager` | `managers/performance_metrics_manager.gd` | FPS/性能采样 |
| 16 | `ModificationRegistry` | `scripts/systems/modification_registry.gd` | 10 模块类 249 改造模块（8 兵种 + 通用 + 强化词条；静态注册表，数量锁在 modification_modules_test） |
| 17 | `DayClock` | `managers/day_clock.gd` | 游戏内日时钟 |
| 18 | `AuraManager` | `managers/aura_manager.gd` | 平台光环 |
| 19 | `IntelItemBag` | `managers/intel_item_bag.gd` | 情报道具背包 |
| 20 | `IntelManual` | `scripts/systems/intel_manual.gd` | 4维情报手册 |
| 21 | `QuestManager` | `managers/quest_manager.gd` | 任务（委托/剧情/引导/动态） |
| 22 | `FactionSystemManager` | `managers/faction_system_manager.gd` | 7 势力（声望/商店/技能/事件/占领状态机） |
| 23 | `AffixManager` | `managers/affix_manager.gd` | 模块化词条 |
| 24 | `LevelProgressManager` | `managers/level_progress_manager.gd` | 关卡进度 |
| 25 | `CardEnhancementManager` | `managers/card_enhancement_manager.gd` | 卡牌强化（词条节点按等级驱动） |
| 26 | `InstanceRegistry` | `managers/instance_registry.gd` | **卡牌实例+养成数据唯一真身**（见下方铁律章节） |
| 27 | `PhaseMasterSkillManager` | `managers/phase_master_skill_manager.gd` | 相位师技能树 |
| 28 | `TutorialProgressionManager` | `managers/tutorial_progression_manager.gd` | 引导 |
| 29 | `BattleSpectacle` | `managers/battle/battle_spectacle.gd` | 战斗演出/大招编排 |
| 30 | `ColorGrade` | `managers/color_grade.gd` | v28 全局调色后期层（时代色温/暗角/抑带；battle_started→时代预设、battle_ended→2s 回 neutral；开关 GameConfig.color_grade_enabled，A/B 环境变量 PW_GRADE_OFF=1） |
| 31 | `_MCPGameBridge` | `addons/agent_tools/runtime/game_bridge.gd` | agent_tools 编辑器插件运行时桥 |

**Lazy-loaded managers**（`ManagerLazyLoader.ensure_loaded()`，23 个配置项；v9.x 2026-08-22 清理：battle_feedback/character/challenge_mode/version 四项已删，见停用清单；v26.4 核对更新）：
aura, level_progress, drop, quest, achievement, daily_task,
faction, affix, intel_item_bag, intel_manual, intel_discovery,
intel_evolution, card_collection, card_enhancement, stat_boost, leaderboard,
lore, tutorial, new_systems, toast, debug_log, bunker, manufacture

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
              Critical（12，立即加载）: InstanceRegistry, BlueprintManager,
              PhaseInstrumentManager, QuestManager, BasicResourceManager,
              FactionSystemManager, AffixManager, LevelProgressManager,
              DropManager, IntelItemBag, IntelManual, PhaseMasterSkillManager
              （ModificationRegistry 解锁集段已随 v25.3 退役移除）
              Deferred（13，分批延迟）: LoreManager, StatBoostManager, AchievementManager,
              DailyTaskManager, CardEnhancementManager, TutorialProgressionManager,
              DayClock, CardCollectionManager, LeaderboardManager, IntelDiscoveryManager,
              IntelEvolutionManager, BunkerManager, ManufactureManager

BlueprintManager → CardEvolutionManager, ModManager, EvolutionHelpers,
                    DefaultCards, PhaseLaws, UnitStatsTable, RankRules

CardEnhancementManager → DefaultCards, UnifiedRankSystem (military titles)

ModificationRegistry → 10 mod module classes (infantry/armor/artillery/anti_air/air/recon/engineer/fort/universal/enhancement)

~~EvolutionPathRegistry → 8 unit-type evolution modules~~（注册表文件+autoload 已随 v26.6 删除，权威迁 unit_lineage_config + BlueprintManager.get_evolution_options；进化整链后随 v26.8 退役，见停用清单）

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

### v26.2 战斗环境效果 + 每关战场布局（2026-09-01，详见 CHANGELOG）

**改战场格子/环境数值/敌方槽位逻辑前必读本节。**

- **环境效果**（`data/battle_env_effects.gd`）：`battle_environments.gd` 四维（天气/地形/
  能量场/时段）的数值真身，分立乘区桶（indirect/direct/all_dmg、direct_range、atk_speed、
  regen）**敌我对称**乘在 stats 构建层三处（玩家 `_build_stats_cached` 尾部——环境签名
  已进缓存 key；经典敌兵 resolve 结果字典；driver 乘区 7）。回能走 `level_regen_mult`
  通道。加新环境值=在四张 EFFECTS 表加一条（带 desc）；调量级改表即可。总开关
  `GameConfig.env_effects_enabled`。UI：world_map 战前摘要 + TopHudBar"环境"chip
  （`describe_level_env` 同源）。留观：MODERN/COLD 时代默认环境四维叠加 ≈ 直射 -15%。
- **每关布局**（`data/level_battle_layouts.gd`，首版 15 关）：rows(2/3)/敌我 cols(2-4)/
  废墟格 excluded。**布局真身是 `CardGridBattleLayout` 的 static 激活态**
  （`apply_for_level`/`reset_to_default` 由 battle_manager start/end 调；缺省=3×3 逐像素
  同旧）。几何函数全部带 `is_enemy` 可选参；`column_width = (X1-X0)/max(7, cols_p+cols_e+1)`
  保 3×3 不变。加棋面=表加一行，零代码。**敌方槽序不得再写死 9 格**——用
  `enemy_slots_total()`/`active_enemy_cols()`/`is_slot_excluded(si,"enemy")`（spawn 系统
  与 driver 的三处旧硬编码序已全部动态化）。L1 教程关必须保持无条目。总开关
  `GameConfig.battle_layouts_enabled`。数据锁 `tests/unit/data/battle_env_layouts_test.gd`。
- aura 槽距坐标走 `aura_data.slot_grid_coords(idx, is_enemy)`（敌我列数可不同；
  单位侧别判定用新 `slot_grid_coords_for_unit`）。

### v26.8 制造系统 + 基地房间时代升级视觉（2026-09-02，详见 CHANGELOG）

**改制造/房间升级/房间美术前必读本节。**

- **制造系统四批次**（配方目录 38 / 制造中心面板 / 进化 UI 退役 / 分析仪 / 缴获品质 /
  仓库打印 / 气象站探索 / 洗点费 / 沙盘 / 敬礼 / 天气预报）：数值与挂钩真身见 CHANGELOG
  v26.8 A/B 节；品质池/成本/保底参数改 `data/manufacture_pools.gd`（balance_audit_mods_evo.py
  MF 段守方向性：common 单调降、epic+ 单调不降、中段驼峰合法）。
- **基地房间升级视觉三图管线（已随 v32.5b 固定基地删除失效，管线文档仅存档）**：`bunker_bg_v3{,_lit,_upg}.png` 三图 + `bunker_room_overlay.gd`
  第四视觉档（Lv2/Lv3 切 upg 图层，Lv3 金描边）。改布局只动 `bunker_room_defs.gd` rect/
  场景占位块再重跑 `generate_bunker_bg_v3.py`；换升级图=往 `docs/基地重设计/generated5/`
  放 `cap_<rid>_upg.jpeg` 再重跑烘焙（agnes 批量生成器 `generate_bunker_caps_upg.py`）。
- **agnes 生图模型特点**（负面词反激活/正面意象锁死/风格词垃圾暗示/屏幕内容限定）：
  ⚠️ 写新生图 prompt 前必读 `tools/_agnes_image_api.md` 行为实测段——v26.8 三轮实测
  （负面词拉黑垃圾无效、正面意象锁死有效）直接推翻直觉写法。
- **FLOW 生图工作流**（`docs/基地重设计/flow_edit_tool.py`，Google Flow 网页 UI 自动化，
  登录态 `%LOCALAPPDATA%\ffroliva\gflow-cli\profile_default`，默认项目
  5bffb93f-5026-4009-872c-cb70d0304f45；v27.11 序章五图全靠它）：
  ① **纯文生图模式**（v27.11 新增）：不传 `--ref` 直接 `--prompt`，语言理解强，
  方向/朝向/谁在动都能听懂；② ⚠️ **prompt 超 ~950 字触发「错误卡片」限流**，
  控制在 900 字内，报错等 60s 重试即好；③ **--ref 是强内容锚**（图里画什么就出什么，
  prompt 只能微调），要换内容级元素必须换参考图或走纯文生图；④ 原生 1376×768，
  PIL aspect-fill 裁 1280×720；⑤ flow-mcp（labs.google API 直调）自 2026-09-05
  站点迁移后已死，别再试。
- **新 png 资产导入**：`--import` 直跑崩（0xC0000005），用 `--headless --editor --quit` 触发。

### v26.9 战场单位可读性：深色描边 + 全单位投影 + 背景压暗（2026-09-02，详见 CHANGELOG）

**改单位贴图/换帧/缩放相关代码前必读本节。** 三件套修复"我方灰褐卡图在沙漠亮底融底"
（实测本体/背景亮度差仅 30-60）：

- **单位深色描边**（`shaders/unit_outline.gdshader` + `scripts/battle/unit_outline.gd`）：
  alpha 膨胀 shader，presentation 链自动挂。⚠️ **契约：凡运行期直写 `unit_spr.texture`
  或 `scale`，必须调 `UnitOutline.refresh(spr)`**——`edge_texels` 依赖 scale（帧动画
  attach 有 scale×2 补偿）、`region_uv` 依赖当前贴图（雪碧图 AtlasTexture 需收敛到当前帧，
  否则膨胀取样越帧采到相邻帧轮廓出鬼影）。已接入：UnitFrameAnim.FrameDriver 三处、
  BossIdleAnim.FrameDriver（兜底）；AttackPoseAnim 攻击帧=同分辨率整图无需刷新。
- **全单位投影**：`air_unit_shadow.gd` 双模式——空中=悬空影（随浮动呼吸），地面=贴地
  接触影（更宽更淡、静止）；由 `_sync_unit_shadow`（原 `_sync_air_shadow`）统一调度。
- **背景压暗**：`battlefield.gd` 的 `BG_DIM`（0.80/0.80/0.87）叠乘时代 tint，
  收口在 `_apply_background_texture`；调背景明暗只动这一个常量。

### v27 改造 2.0：升级系统 + 六新套装 + 触发式 + mythic（2026-09-11，详见 CHANGELOG）

**改改造升级/套装/触发式效果相关代码前必读本节。** 总量 202→**249**（+47），全部玩家侧。

- **改造升级 Lv1→3**（`blueprint_manager.gd`）：费用唯一真身 `preview_upgrade_cost`（图纸 =
  同改造 ×(目标等级−1)；纳米 = `preview_install_cost` 基准 × {2:1.5, 3:2.5}）；资格
  `get_mod_upgrade_info`（**无 level_effects 的改造不可升级**）；执行 `upgrade_modification`。
  引擎零改动——registry `apply_with_level` 按条目 level 读档，旧档缺 level 默认 Lv1 免迁移。
  UI：已装行 `[LvN]` 前缀 + `↑Lv2/3` 按钮；详情面板已装态变升级按钮。
- **level_effects backfill 纪律**：`tools/gen_mod_level_effects.py` 可重跑；**只对未被敌方引用
  的 id 生成**（enemy_fixed_loadouts + enemy_card_mod_map 并集，现 125 id）——敌方 tier 走
  level_effects 消费，给敌方引用 id 补档 = 改敌方强度。pct 帽 0.60（balance test CAP_STAT）、
  负副作用/布尔/语义 int 三代平坦、全平坦条目跳过。
- **新六套装**（`combo_tactics.gd` COMBOS 6→12）：重装方阵/防空火网/野战医疗链/炮兵饱和/
  工兵防线/堡垒固守。basic 与 full 机制 flag 消费点在 `module_effect_handler` 既有函数的
  档位分支（查询助手 `_mech_active()`）+ 曲射 batch `aoe_cap` 分支；新增机制键勿忘
  消费点先查 `_mech_active` 零成本早退。
- **触发式改造**（效果键落 `_special`→`mod_special_flags`）：消费点 = handler 四入口
  （on_hit/on_kill/on_tick/on_damage_taken/on_death）+ battle_manager 波次链转发
  `ModuleEffectHandler.on_wave_spawned`。新触发键必须进 `MECHANIC_EFFECT_KEYS`（面板"机制"分类）。
- **mythic 启用**：`mod_manager` mythic→OVERLORD；掉落权重 1（boss×3）；三条 gen_21~23
  行为改写（全队击杀自回/周期补盾/引力脉冲）。

### v27.16 游戏手感三批次（2026-09-12，详见 CHANGELOG）

**改面板开合/按钮反馈/入战流程前必读。**

- **面板开合动画唯一真身 `scripts/ui/panel_anim.gd`（PanelAnim）**：main 17 个 overlay 与
  全部旁路面板（相位师/技能树/卡车基地内嵌/标题屏弹窗）都经它——**新面板勿再手写
  开合 tween**。Control 宿主走 open/close；CanvasLayer 宿主（无 modulate）走
  open_layer/close_layer（backdrop 同步淡出+收尾 tween 竞态守卫）。组件自身不播音效
  （防群关 15 重奏），开合音归调用点
- **点击音/按压微动效是全局钩子**（AudioManager node_added → BaseButton.pressed）：
  新按钮无需手写反馈；play_sfx("button") 带 50ms 去重，既有手写调用保留不删
- **StageBanner（stage_banner.gd）= 轻节拍横幅**（~1s，全链 mouse IGNORE 不挡点击），
  SortieInterstitial = 重仪式战报（1.5s 可跳过）——两者构成过场体系；挂机/教程链路
  对横幅**全部豁免**。入战揭幕的 dip 用树定时器 await（tw.finished 有挂起协程风险）
- help/growth 面板内层动画已拆（动画归外层 PanelAnim）；growth 的重活分帧语义保留在
  show_panel 的 0.08s interval 链上，勿删
- tab 内容过渡只动 modulate（fade_content_in）——容器子节点的 position/scale 会被
  下次布局排序覆盖，勿加位移动画

### v31 R6 发行工程批（2026-09-13，详见 CHANGELOG）

**改键位/设置/存档配置文件/战功榜/情报舱前必读本节。**

- **键位重绑唯一真身 `scripts/systems/keybinds.gd`（KeyBinds）**：6 个可重绑动作
  （pw_pause / pw_start_battle / pw_open_map / pw_open_backpack / pw_open_growth /
  pw_open_settings）在此注册——InputMap 运行时覆盖层，project.godot [input] 零条目；
  main._input 全走 `is_action`（ESC=ui_cancel 固定、数字 1-9 部署槽位固定不重绑）。
  覆盖持久化在 settings.cfg 的 [keybinds] 段；main._ready 调 `ensure_registered`。
  **捕捉契约**：设置面板捕捉重绑按键期间置静态 `KeyBinds.capture_active=true`，
  main._input 见 true 即整体让路——新增键盘消费点前先想清楚与捕捉流程的互斥。
  **默认键=旧硬编码值；改默认值=改玩家习惯，勿顺手调**。
- **user://settings.cfg 双段契约**：[settings]（音量/难度/窗口模式 window_mode/
  分辨率 resolution_idx/色盲 color_blind_mode/可及性三键/教程重置）由 settings_panel
  读写；[keybinds] 由 KeyBinds 读写。⚠️ **settings_panel._save 必须先 load 再写**——
  v31 修掉的存量 bug 就是新建 ConfigFile 整文件覆写、抹掉 keybinds 段（回归锁
  `tests/unit/systems/test_r6_release_options.gd`，含 settings.cfg 备份还原纪律）。
  新增设置键时两个写入方都遵守该纪律。
- **色盲辅助层**：color_grade.gdshader 的 `color_blind_mode` uniform（0关/1protan/
  2deutan/3tritan，Daltonize 算法）——**独立于 GameConfig.color_grade_enabled 与
  PW_GRADE_OFF**（可及性不受调色开关影响）。入口 `ColorGrade.set_color_blind_mode`；
  启动自读 settings.cfg。
- **分辨率/窗口模式**：window_mode 0窗口/1无边框全屏/2独占全屏（旧 fullscreen=true
  配置自动迁移为 2）；分辨率四档仅窗口模式生效、自动居中。boot 应用器
  `settings_panel.apply_display_at_boot`（title_screen 调用，与 apply_ui_scale_at_boot
  同点）。
- **战功榜（leaderboard）**：显示名以语言宪法为准（宪法 2026-09-08 已批条目：
  战功榜，与战功簿/战功卡同族；计划文档原拟「生涯战绩」与宪法冲突未采用）。
  榜单数据真身 leaderboard_definitions.gd——`survival_highscore` 是黑门无限周榜的
  **活榜**（唯一提交方 endless_blackgate_manager），勿当死榜再删；其余 10 张
  零提交方零 UI 定义留档（将来生涯统计页候选），`time_attack_best` 已删。

### v32.0 定位转向批：战术构筑放置（2026-09-14 起，详见 CHANGELOG 与 docs/定位转向_战术构筑放置_2026-09-14.md）

**改战斗节奏/倍速/结算链相关代码前必读本节。** 定位拍板「战术构筑放置」：自动战斗是特性，
构筑深度是核心技能（game-pillars Pillar 1 已改写 + Anti-Pillar NOT Micro-Management）。

- **战斗时间状态唯一真身 `scripts/battle/battle_time_state.gd`（BattleTimeState，静态类，
  无 class_name）**：倍速档 [1,2,3,4] + 极速推演旗标 + 偏好持久化 `user://battle_speed.cfg`
  （独立 ConfigFile，勿并入 settings.cfg——那是 settings_panel/KeyBinds 双写领域）。
  ⚠️ **`Engine.time_scale` 是全局作用域**：战斗外必须 1x——BattleSpectacle 是应用方与收口点
  （battle_started 应用玩家倍速 / battle_ended 先退推演再回中性 1x / _exit_tree + title_screen
  兜底）。任何新"战斗内时间流速"需求走 BattleTimeState + BattleSpectacle，勿直写 Engine.time_scale
  （工具场景 combat_check/combat_arena_3v3/intro dream_battle 自管除外）。
- **极速推演（TopHudBar「跳过」）**：8x 真实模拟至战斗结束（奖励照常结算，无虚假结算）；
  压制清单=AudioManager battle_sfx_suppressed（UI 白名单外静默）+ VfxImpactFactory 28 个高频
  生成入口 + CombatFeedback.show_damage + 击杀顿帧；`spawn_ultimate_projectile`/`spawn_summon_portal`
  刻意不压（boss 大招 on_arrival 编排链）——给 boss 编排加新 VFX 时想清楚是否该进压制名单。
- 顺手修复的存量泄漏：旧胜利慢动作/败北路径把 time_scale 恢复到玩家倍速，结算/基地界面
  跑在 ×3 上；现在战斗外恒 1x，倍速在下一场 battle_started 重新应用。
- **观战镜头（B1-2，已实装）**：`BattleSpectacle._play_camera_push` 三个挂钩（boss 登场/
  核爆命中/胜利），减动效+极速推演+推近中三重守卫，与震屏正交（zoom vs offset 通道）——
  全项目唯一 zoom 写入方，谁要动战场相机先查此处防互踩。
- **挂机观战入口（B1-4，已实装）**：afk_panel「▶ 观看战场」=隐藏面板不停机（stop_afk
  只由 StopBtn 触发），回来走底部功能栏挂机按钮。
- **战报升级（B1-3，已实装）**：`scripts/battle/battle_unit_record.gd` 静态聚合器——
  挂账点=两单位 take_damage（输出/承伤，**减免前口径**）+ battle_manager 击杀 handler；
  按显示名鸭子链聚合（card.display_name→display_name→archetype_id）；start_battle 重置、
  极速推演照常累积；mvp_panel「本场最佳」三行消费。改 take_damage 语义/伤害衰减口径时
  注意该账本口径随之变化。
- **B2 构筑可见化（部分实装）**：体系可见化=底栏 NameSection 第三行（备战预示，与
  combo_status_strip 战斗实时态分工）；阵容预设=PIM `loadout_presets` 5 槽（save_state
  惰性键 + load_state 复位不变式①，应用按 InstanceRegistry 实例精确恢复）。改绿槽
  equip/unequip 语义时注意预设快照/恢复链。战前克制提示=`data/build_advisor.gd`
  纯静态规则引擎（规则键+环境乘区→≤3 条建议，world_map 简报消费；主题 advice 不归它管）。
  **新增特殊规则键或环境乘区键时同步加建议条目**，否则玩家看不到新机制的应对提示。
- **实机验收埋点（已实装）**：PerformanceMetricsManager `count_event`（speed_x2/x3/x4、
  skip_activated、afk_watch）；试玩构建靠 export custom_features="pw_playtest" 解锁
  P0-4 写盘门控并**额外落 exe 旁 playtest_metrics.json**——正式 release（无该 feature）
  仍静音。godot_ai game_helper 已补 release 自守卫；两个调试桥在发行包内零开销。
- **演出层（侦察后实做一项）**：战场环境音=AudioManager ambient 通道
  （battle_started 起 `ambient_battle_wind` 30s 无缝循环 / battle_ended 淡出；
  `play_ambient`/`stop_ambient` 独立于 BGM/SFX；FF 推演不停）。相位师战前演出/
  遗言触发/世界地图 BGM 均已由 v24/v27/v30 批次覆盖，勿重复建设（详见 CHANGELOG
  演出层轮侦察结论）。
- **B3 结构层（已建，数值占位）**：首通=`data/first_clear_rewards.gd` + GameManager
  `_grant_first_clear_if_eligible`（**必须在 complete_level 前调用**——stars==0 判首通）；
  晶体 sink=ManufactureManager `advance_mod_box_pity_with_crystals`（占位 80/+1）+
  BlueprintManager `exchange_crystals_for_upgrade_blueprint`（占位 40/张补图纸缺口）。
  **数值轮动占位价时必须同步改 test_first_clear_rewards.gd 与两处 const**；sink UI 接线、
  日常缩量随数值轮。黑门软门已实装（用户拍板 3 次/**日**）：门禁在
  `GameManager.start_endless_battle` 头位、消耗在 `begin_run`、日键 `_day_key` 真实日期
  口径、存档三惰性键、占位 60 能量块/次（endless_blackgate_manager 顶部常量）。
- 后续批次：黑门软门 + sink UI + 数值校准（等试玩数据）→ 发行壳（版本号 tag 统一、
  Steamworks、AI 披露/隐私政策）。

## v32.2 实机验收反馈修复批（2026-09-14，详见 CHANGELOG）

**改嵌入面板/归仓气泡/制造中心列表/图纸掉落/动画雪碧图/命中 VFX 前必读本节。**

- **truck_base 嵌入 .gd 面板契约**：脚本面板根是裸 Control（min=0），塞进 CenterContainer
  会被折成 0×0 摆屏幕中心、内容向右下溢出半屏——`_ensure_panel_wrapper` 已对非 .tscn 面板
  统一给 `custom_minimum_size=(1280,720)`（bunker_main:625 同款）。面板内部全屏锚点一律
  `set_anchors_and_offsets_preset`（`set_anchors_preset` 的保偏移语义会把 0×0 陈旧 rect 带
  回布局，memorial_wall v22 教训第二次踩）。回归探针 `tests/_tmp_truck_embed_probe.tscn`。
- **归仓气泡点击契约**：bunker_reward_bubble 根的 `gui_input` 是唯一点击入口——子控件一律
  `mouse_filter=IGNORE`（v23.6 起子 Panel 默认 STOP 吞掉全部点击、"气泡点不了"的存量 bug
  即此）。
- **制造中心列表过滤口径**：有敌形原型但 intel=0（从未交战）的卡种不显示；era0/1 直入卡
  显示"直入目录"而非"情报 0%"。改 `get_recipe_ids`/`is_direct_pool_card` 语义时同步三处 UI
  （列表行/详情/条件行，均在 evolution_panel.gd）。
- **图纸掉落时代通道**：`roll_random_mod_blueprint(..., max_era)` 掉落侧 era_band 过滤
  （对齐安装门；空池回退全量；负值=旧行为）。**v6.14.1 口径（用户拍板）：普通件限当前
  时代；极特殊件（epic/legendary/mythic）按关卡所处时代跨一级（下一时代）前瞻掉落**，
  era_hi 钳 4。**v6.14.2 缴获语义（用户提出）：有配装的敌人只掉它实际携带的模块**
  （`roll_mod_blueprint_from_kit`，档位切片 normal=前5/elite·boss=9，与敌方挂载同源），
  无配装回退全池——**新增掉落调用点注意先查 kit 再回退**。配装引用集 76→85/249
  （v6.14.3 三件套轮收编防空/空军/装甲族冷门件；工兵/侦察无专属敌卡、词条族不入配装，
  长尾仍由制造定向兑换兜底）。调用方两处
  （intel_discovery_manager 普通链 + game_manager 相位师战利品）都传
  `LevelEras.get_era(current_level)`。**v6.14.4 缴获/发现 75/25 分流（用户拍板）**：
  有配装敌人 75% 缴获件、25% 走 `roll_discovery_mod_blueprint`（全注册表按稀有度
  加权+时代口径同上+**优先未见模块**）——保证全图鉴保持战斗可发现（发现→见过→
  随机箱池/定向列表不断链）；无配装敌人直接走发现腿。两腿皆空回退原兵种池 roll。
  **v6.14.5 制造出厂随机改造（用户拍板）**：制造出的卡按品质档附送随机改造
  （`STARTUP_MOD_COUNT` 阶梯：普通 0→神话 5；`pick_startup_mods` 静态选取，安装
  同源口径+稀有度≤品质档+冲突组去重；赠品 paid_cost=0 免图纸）。回归锁
  `tests/unit/systems/test_mod_drop_era_filter.gd`（12 用例）+
  `tests/unit/economy/test_manufacture_startup_mods.gd`（4 用例）。
  **v6.14.6 卸下改造（用户拍板方案 A：图纸返还）**：`uninstall_modification(card, slot)`
  ——件回 IntelItemBag 库存可转装别的卡 + 纳米按实付 paid_cost 50% 返还（旧存档无
  paid_cost 回退 cost_install 50%）；**出厂赠品（mods 条目 `gift=true`）特殊口径**：
  纳米 0 返、无图纸返还、件消失。UI=改造面板已装行"卸下"按钮（与替换并列）；
  mod_consumable_enabled=false（旧永久解锁行为）时不返图纸。面板旧注释"卸载 API
  未实装"已失效。回归锁 `tests/unit/economy/test_mod_uninstall.gd`（3 用例）。
- **动画雪碧图部署验收（新增两条）**：①帧数与 anim.json counts 一致（rolls 集 idle 4/8、
  attack 6/12 读越界=战斗空帧闪烁）；②内容占比与卡图 bbox 一致（unit_frame_anim 只补分辨
  率差不补占比，占比错=动画态单位偏大/偏小）。c96/garand/flak 已归一（工具
  `tools/_tmp_b7_anim_normalize.py` 可复用）。**rolls 艺术债在案**：双主体/帧数缺口/3.7:1
  扁长比例，参数救不了，需走分帧管线重生成（详见 CHANGELOG v32.2 第 7 条）。
- **命中 VFX 量级口径（v32.2 起）**：爆炸族目标宽 112 / 帧动画 MEDIUM 112·HEAVY 144 /
  快环时长 ×1.0——"直射轻动能 ~50px < 曲射 ~130px < 导弹 ~230px"三级断层是本轮实测拍板的
  可读基线，再调曲射尺寸先对照 docs/vfx_audit_shots 的 f00/f01/f09 三格。
- **大地图冰穹可读性（待用户裁决）**：2026-09-14 全量体检证实 100 节点全部压在内容锚点上
  （"落海"是白色冰穹被读成海面），布点不动；改图（冰穹描边/外海增蓝）是用户手绘定稿，未批
  不动。结论注记在 world_map.gd S11_POINT_OVERRIDES 头注。
- **结算情报收获=事件化摘要（v32.2 追加）**：intel_harvest_display 只列有事件的敌人
  （首次遭遇/新揭示/跨 25·50·75·100% 档——档位与 ManufacturePools 同源），其余折一行汇总；
  **新增情报事件类型时记得在 `_crossed_tier_mark`/`_create_event_row` 旁补 chip 分支**，
  别把逐行进度条加回来（绝对进度归 情报舱·敌方情报）。探针 `tests/_tmp_ihd_probe.tscn`。

## v32.5 实机验收反馈修复批2：进关即开战 + 教学前移基地 + 手感/图鉴/制造（2026-09-15，详见 CHANGELOG）

**改进关开战流/自动部署/教学/背包相位仪/基地 UI 前必读本节。**

- **进关即自动开战**：world_map「进入该关」落地即开打——独立场景链 meta `level_auto_start_pending`（main deferred init 消费）、内嵌链直调 `main.auto_start_battle_from_world_map`；教程期守卫让路。出征战报与战备**并行**（`run_start_battle_sequence` 不再 await 战报，尾轮询 `SortieInterstitial.is_showing()`；战报 0.8s、含战区环境行）——给开战链加新步骤时想清楚与黑幕战报的时序。battle_manager 开战帧 7 个懒加载预热已挪 main `_warmup_battle_lazy_managers`（落地 1s）。
- **自动部署默认开+持久化**：偏好真身 `battle_speed.cfg [deploy] auto_deploy`（BattleTimeState，默认 true）——**该文件现有 speed/deploy 两段，读写全走读-改-写**（save_pref 已补 load，勿回退整文件覆写）。战前可预武装（bottom_instrument_bar 门控已删）；battle_ended 不再自动关；**挂机中控制器让位**（`_afk_owning_deploy`：AFK 自带部署管线，双管线抢格是本轮实测防住的回归）。
- **教学起点在移动基地**：自举点=`truck_base._finish_wakeup`（镜像 main `_start_tutorial_if_needed` 的 NONE 门）；`overlay_requested` 基地本地挂载（`_show_tutorial_overlay_local`）；教学 toggle_* 在基地落地为 `_open_panel`；首战步经 `start_level`→`_launch_battle`+meta `tutorial_first_battle`（main 消费）。**教学覆盖层现在两场景都能弹**（main/truck_base 各自本地实例化），新增教学步不用再管挂载场景。教学进行中 truck_base_intro 气泡静默（防叠窗）。
- **结算弹窗时机**：「欢迎回来」离线弹窗检查在 truck_base（`_maybe_show_offline_rewards_home`，static 每进程一次）；main 的 `_maybe_show_offline_rewards` 已删——别在 main 场景加载上挂弹窗（落地即开战后时机必错）。AFKSettlementDialog 战斗中只暂存（afk_panel `_pending_settlement`）。
- **背包空槽棘轮已修**：`_ensure_min_card_slots` 只数真实卡+双向修剪（回归锁 `tests/unit/ui/test_backpack_slot_ratchet.gd`）；换相位仪选择器保持打开原地刷新（main 不再 queue_free selector、不手动二次 refresh——仪栏自随 phase_slots_changed 重建）；presenter card_added 连发合并（`_queue_grid_refresh`）；符文图标 modulate=WHITE（稀有度由瓷砖边框承载，勿改回乘色）。
- **底栏 8 键**：成长（amber 加权）+卡仓+改造+制造+地图+设置+存档+挂机——改造/制造信号 `btn_modification_pressed`/`btn_evolution_pressed` 直连既有 toggle handler；`_set_active_btn` 的 amber 分档别抹平。
- **truck_base 工位**：HOTSPOTS 尾门跳板 kind=march（行军=开地图，与驾驶室 sortie 分化）；`HOTSPOT_DESC` 功能句表（key>名称>kind 查）——加新热区记得补 desc；战功热区已上移墙面带；「🔔 收取全部(N)」chip 挂 `_refresh_reward_bubbles`（`_collect_all_btn`，空池隐藏）。
- **制造列表行**：解锁行=`战力/HP/三维攻`（card.power 模板直读）；0 情报行不再隐藏（`？？？+情报 N%（25% 解锁）`）——改 `get_recipe_ids`/`is_direct_pool_card` 语义时同步 `_create_recipe_row` 分流。图鉴（collection_panel）已网格化（拥有亮图/未获得黑影问号），详情区顶部 `_detail_icon` 懒建。

## v34 早期体验重构：渐进解锁门控 + 再战回路（2026-09-15）

**加新系统入口/改基地工位/改结算面板前必读本节。** 背景：新档基地首屏 31 个入口零门控（选择过载）+ 战后无"变强可见"与"下一关"直通（拉力断层）。

- **「关卡→系统解锁」唯一真身 `data/feature_unlock_schedule.gd`（温和档）**：modification=3 / evolution=afk=5 / intelligence=7 / faction=store=10 / affix=12 / 旁路六件（quest/achievement/collection/leaderboard/hero_archive/memorial）=15；L1 常开集（出击/卡仓/地图/成长/设置/存档/帮助/sortie/march/terminal/sleep/info）**不进表**。**加新系统入口必须先在此注册**，否则视为常开。查询/信号挂 LevelProgressManager：`is_feature_unlocked(key)`（判定链：总开关关=全开→不在表=常开→教程已完成=全开老档兜底→关卡阈值）+ `feature_gate_hint` + `SignalBus.feature_unlocked`（`_unlock_next_level` 跨级发射，prev_max 守卫防重打旧关重弹）。
- **三入口层 key 对齐**：truck_base HOTSPOTS panel key / bottom_function_bar GATED_KEYS / main._open_overlay panel_key——main 侧差异别名在 `main._GATE_KEY_ALIAS`（info=intelligence）。门控只锁入口层（灰显+🔒短牌+"通关第 N 关解锁"toast），**不动面板内部逻辑**（单测直开面板不受影响）。时代 chips 按 `unlocked_eras` 门控（era N 观感=通关 (N-1)*20 Boss）。
- **解锁仪式链**：跨级发生在战斗结算中（玩家不在基地）→ main 即时 toast + LPM 待播队列 `consume_pending_feature_unlocks`（仅运行期不入存档）→ truck_base._ready / main._on_result_confirmed 消费 → `FeatureUnlockPopup.show_unlock_batch`（批量合并单弹窗，"gate:"+key 与 PANEL_INTROS 裸 key 命名空间隔离去重）；玩家在基地时热区重建+金色脉冲 `_glow_hotspot`。教程 5-14 步靠既有首开机制自然衔接（面板解锁后首次打开才触发 `notify_surface_opened`）——**勿在锁定期用 toggle_* 强开面板**（守卫会 toast 拒开）。
- **总开关 `GameConfig.feature_gates_enabled`（默认 true）**：false=一键回退 v34 前全量敞开。
- **再战回路（B1）**：mvp_panel「▶ 出击下一关」主按钮（`_compute_next_level` 显隐矩阵：胜利·非挂机·教程已完·本战关+1 已解锁；**下一关取 `GameManager._pending_battle_level`+1**，防重打旧关后 current_level 指向跳变）→ `main.launch_next_level_from_settlement`（清场+set_current_level+出战报拍点+`run_start_battle_sequence`，与挂机 enter_next_battle 同管线）；旧「继 续」降级为「返回整备」次按钮。教程期不给直通键（要回基地续播步 5）。
- **结算成长可见（B2/B3）**：`GameManager.last_battle_reward_summary` 增两键——`first_clear`（首通奖励 dict，`_grant_first_clear_if_eligible` 写）+ `card_growth`（上阵卡 [{iid,name,xp,lv,leveled}]，`_grant_battle_experience` 写；**发钱逻辑零改动，纯展示附带数据**）——mvp_panel 缴获页「★ 首次通关奖励」「◆ 战斗卡成长」两区块消费，改键名两处同步。
- **前期高潮（C）**：精英波短定格 `_play_elite_wave_beat`（battle_spectacle，time_scale 0.3×0.15s，守卫与击杀顿帧同门：motion_reduce/慢动作/顿帧/极速推演不叠加；号角 boss_warn 信号侧自带压制）；首机制关预告 `LevelInformation.get_first_seen_mechanic_banner_lines`（首现关播"⚑ 新战术条件"StageBanner，main_battle_setup 开战节拍插播，教程/挂机豁免）——**新增 special_rules 机制键记得同步 `MECHANIC_BANNER_TEXT` 文案**，缺文案静默跳过。
- 数据锁：`tests/unit/systems/test_feature_unlock_schedule.gd`（节奏表/阈值判定/信号与待播队列）+ `tests/unit/ui/test_settlement_next_level.gd`（直通键显隐矩阵/成长区块渲染）。

## v36 实机验收反馈修复批3：开场链演出 + 进度节奏 + 精神同调战力门 + 战斗手感（2026-09-16）

**改掉落视觉/挂机/技能树战力门/世界地图窗口/首关难度前必读本节。**

- **自动存档 toast 静默 + toast 右上角**：`save_manager` 成功分支不再弹"游戏已保存"（失败提示保留；手动存档反馈在 main `_show_save_result_toast`）；ToastManager 层从屏幕中部移右上角（top 64/右缘 24/宽 300 向下堆叠）——改 toast 位置别回"底部居中抬高"旧坐标（实落屏中）。
- **精神同调战力门（新系统）**：设定=相位师越强→精神与暗能交换越深（越易失控迷失，穿越而来中低位居多）→可运用战力上限越高（卡 power 值）。**唯一查询真身 `PhaseMasterSkillManager.get_power_cap()`**（BASE_POWER_CAP=200 + 三系精神同调链 unlock type="power_cap" max 语义：开窍500/深潜1200/无垠2400，基础层 tier2/4 + v8ext tier7）；拦截点=`battle_spawn_system.request_player_deploy`（reason=power_cap）；豁免三键：`debug_no_deploy_limits`/`GameConfig.power_cap_enabled`（总开关，回退 v36 前）/教学进行中。**改 BASE 或节点 value 必同步 `tests/unit/systems/test_power_cap.gd`**；power 分布实测（era0 p50=28/era1 p50=204/max 2200）见 CHANGELOG，数值轮动以试玩数据为准。
- **挂机=本关循环/向前推进 + 行进节拍**：选关槽位退役（`afk_level_selector.tscn` 无引用，面板 `SlotsHBox` 隐藏保留可回滚）；CYCLE 恒刷停靠关（`_resolve_parked_level`），PUSH 从停靠关 +1 推进（v26.19 推进钳制已删，起点钳制保留）；关间 `State.TRAVELING` + StageBanner + 4s（motion_reduce 1.2s），`_travel_gen` 代际守卫——**新增 AFK 状态分支记得同步 afk_panel `_on_afk_state_changed`**。
- **世界地图窗口**：只建停靠关 ±10（`MAP_WINDOW_RADIUS`）节点，overlay 桥线/占领环同口径过滤；锚点（在途=目的地）变化自动重建；**给地图加新图层时按 `_built_window_anchor` 窗口过滤**，防窗外元素悬空。右下角"战线视野"提示标签在 chrome 层。
- **首关难度**：`FORT_MIN_LEVEL`（manifest）——ww1 双堡垒 min_level=4，`get_ids_for_era_at_level` 全链生效；WW1 `ERA_ENEMY_FIELD_CAP`=4（其余时代不动，单变量原则）。
- **直射前排优先**：`ConstructUnitAI.has_more_forward_same_row_target`（共享静态，enemy_unit 对称调）——同排更前目标出现则 retain 放弃自动重选；容差 12px/检查半径 300px；守住指令、曲射、antitank 语义不动。
- **掉落分档变体**：掉落贴图家族 `assets/resources/drops/drop_{nano,battery}_{1,2,3}.png`（256 画布内容高 190px 标定，生成器 `tools/_tmp_drop_variants.py` 可重跑）；`ground_loot_layer` 按 amount 1-7/8-29/30+ 选档，纳米并堆跨档 `refresh_currency_visual` 换贴图；`basic_nano.png` 已抠透明底（原图在 _art_backup，HUD 资源条同源）；货币档地面柔光呼吸在 `_draw`；**换掉落贴图先看 CURRENCY_* 常量标定口径**。
- **开场链**：雪原图 `wakeup_snowfield.png` 已按基地车特征重生成（agnes 兜底，FLOW 当日不可达；原图备份 _art_backup，候选图在 .godot/art_regen/）；欢迎步文案剧情化（教程 `INTRO_WELCOME`）+ 面板半高表 `BOX_HALF_H_BY_STEP`；跳过开场按钮走 PanelStyles ghost。**「伙伴」是语言宪法禁用词（用「同伴」）**——写开场/剧情文案前过宪法。

## v6.14.7 缴获卡可部署 + 直入卡制造修复 + rolls 动画重建（2026-09-16，详见 CHANGELOG）

**改部署次数池/制造 roll/单位动画资产前必读本节。**

- **部署次数池兑底（`battle_spawn_system._resolve_deploy_uses_entry`）**：captured_*/foe_* 缴获卡（~100 张）与 fe_* 势力卡（14 张）不在 UCT，旧逻辑 reset 跳过=池无键=`_has_deploy_uses` 缺键 false="次数耗尽"硬拒——**自 v20.13 起永远无法部署**（自动管线重试 20 轮静默放弃、手动 pickup 不拦但落点被拒）。现剥缴获前缀回表重查（与 `_build_captured_card` 同口径）→ 仍空按卡 combat_kind 构造基线条目；`_reset_deploy_uses` 与 `_get_deploy_uses_total`（HUD/维修返还共用）都走它。`_has_deploy_uses` 缺键时懒建键自愈（战斗中途换装进绿槽的卡不在开战快照池，查询时补建并广播 deploy_uses_changed）；**不在绿槽的键仍保持拒绝语义**。缴获卡次数=剥前缀后的真身条目口径，非基线兜底值。
- **制造 roll 口径对齐 UI（`manufacture_manager.manufacture`）**：掷品质必须走 `_pool_base`（era0/1 直入卡白板档 0.25 特判），**勿回退裸 `get_intel_base`**——直入卡无敌形原型情报恒 0，裸口径 roll 恒空池必失败"品质池异常"（v30.5 引入回归，约 30/46 新配方 UI 全绿却永远造不出）。非直入卡两条口径数学等价零行为变化。
- **rolls 动画已重建（`assets/effects/unit_anims/ww1_arm_rolls/`）**：anim.json 的 frame_size=256 必须与雪碧图实际帧距一致——存量 sheet 曾是 128px 错距（引擎按 256 切格每格 2 辆车，游戏内"一辆变两辆"）且美术本身过时（旧式装甲车，与卡图 vis_player_001/mk2 现役轻型坦克设计族不符）。现从工作区 `039_ww1_arm_rolls_罗尔斯装甲车` 源帧按 `deploy_unit_anims.py` 同管线重建（idle 2048×256 / attack 3072×256）。**改该单位动画走源帧重建，勿手改 anim.json 帧距**——内容集中画面下半带（y135-207），改小帧距会被正方形切格拦腰截断。旧资产+遗留散帧备份 `.godot/art_backup_rolls_fix_2026-09-16/`。
- **分帧动画/卡图审计工具沉淀**：`tools/_tmp_visual_audit.py`（160 套动画逐帧体检：帧数对账/空帧/双主体/占比离群）+ `tools/_tmp_visual_sheets.py`（卡图/动画拼图目视）可复用。2026-09-16 全量体检结论：双主体唯一户=rolls（已修）；360 张卡图零缺陷、敌左我右镜像纪律完好；16 个仅含 attack_f0.png 的目录是攻击姿态系统（AttackPoseAnim）合法资产勿当垃圾清理。
- **回归锁**：`tests/unit/systems/test_deploy_uses_fallback.gd`（6 用例）+ `tests/unit/economy/test_manufacture_direct_roll.gd`（4 用例）。⚠️ 本机新 png 首次落盘后 `--headless --editor --quit` 会在扫描中途退出，导入不完整会拖垮 headless 启动链（v36 A4 drops 六图即踩此坑）——给足编辑器时长完成导入。

## v6.14.8 情报卡改版：六分区战术格版式（2026-09-16，详见 CHANGELOG）

**改 card_info_panel 情报 Tab 版式/战术格填充/词条行前必读本节。** 依据 `design/ux/card-info-panel.md` 落地（设计稿 B 版打底；一期只做背包态，战场对比 HUD/改造模块槽列二期）。

- **六分区（仅词条区滚动）**：标题行（名 26px + Lv 金 + 兵种徽章胶囊[仅卡牌模式，单位模式整胶囊隐藏] + ✕）→ 立绘 190px（UiAssetLoader 卡图全回退链，无图 "？" 占位）→ 核心属性（战力大格 40px 金 + 耐久/射程/移速三小格，耐久支持"当前/上限"）→ 克制矩阵四格（对轻装/对装甲/对空中/防御；0=灰 "--"）→ 斜杠组一行（攻/防三维+最强维攻速秒伤，零值同 "--"）→ 底行（时代/部署能耗/地形修正）。词条以下（当前状态/加成来源/词条/等级/养成/关联技能/描述/风味）全部退入滚动区无框块 + 12px 次级灰小标注。
- **战术格唯一填充口 `_fill_combat_cells(stats, cur_hp, vis)`**：vis 传 `_enemy_stat_visibility_level` 三档掩码（敌方情报可见性 v27.15 不破）；stats=null（相位场基地）只填耐久 cur/—；战力双口径并存——卡牌=养成 `get_current_power`、战场=属性 `combat_power_from_unit_stats`，勿混。5 个 `_show_*` 函数只加了填充调用，长类型行（type_label，单位模式专用）/军衔/0.4s 状态刷新/ESC 链未动。
- **节点路径已全变**（HeaderPanel/StatsSection/AffixSection 等旧区块删除）：`_resolve_nodes` 新路径是唯一真身；summary_label 现挂在滚动区（非战斗卡预览行），战场单位模式恒隐藏。改面板结构先对照 .tscn 新树；`_set_section_visible_by_content` 参数已放宽为 Control。
- **词条行化**：`_refresh_affix_tags` 重写（顺带修复存量死代码 bug——旧 for 循环缩进在 return 后，词条非空时 Flow 永不填充）；真词条=◆名+稀有度色+悬停 detailed_description，"◆ 武装"行（weapon_names）置顶。`_build_star_lines` 只输出效果行（等级数字归标题行 Lv），空时整块隐藏。
- **部署能耗唯一显示位=底行"权重"位**（能量卡=+提供量 M8 口径）；标题行 CostLabel 恒空（节点保留）。数值字体=Rajdhani SemiBold（设计稿 Consolas 的项目替代，已挂 CJK fallback）；面板圆角 6/内块直角（设计稿拍板，6 在圆角梯队内）。
- **二期第四批（D 版收尾）**：标题行血条 `_fill_unit_hp_bar(cur, mx)` + 威胁提示 `_collect_threat_lines(unit)`（对侧组射程覆盖扫描，3 条+汇总，DT.COLOR_WARN_SALMON），均挂 `_refresh_dynamic_battle_info` 的 0.4s 拍子；卡牌模式隐藏。改单位 hp/attack_range 字段语义时同步此面板。
- **二期第三批（改造视图美化，纯装饰）**：`scripts/ui/blueprint_grid.gd` 蓝图网格（钢蓝 24px 网格+四角十字标，IGNORE 鼠标）挂 modification_panel BgPanel 首子节点；TitleSub="MODULAR REFIT"。功能代码零改动。
- **二期第二批（改造槽情报化，用户约束"不要减功能"）**：改造 Tab 功能面板零改动；情报 Tab 新增 `ModsBlock`（砖块数 v6.16 起随品质+兵种动态，rarity 描边/悬停效果摘要/点击 `current_tab = MODIFY` 走既有链）；`_refresh_mods_tiles(card)` 数据源=card.mods+ModificationRegistry（与养成摘要同源），非战斗卡与战场单位模式自隐藏。
- **二期第一批（战场动态）**：底行动态唯一入口 `_refresh_dynamic_battle_info(unit)`（battle_active 守卫，0.4s 同拍）——波次/能量/剩余部署（玩家单位）；`_deploy_uses_remaining_for(card)` 为剩余次数共享查询。目标对比条 `_fill_target_compare(my, its, its_vis, name)`：数据链 `unit.target`→双方 stats；目标在敌方组时 vis<2 则数值掩码且**条长固定 0.4 不参与标尺**（防泄漏）；任一方缺 stats 整块隐藏。改波次/能量/部署 API 时同步此面板。
- **回归锁**：`tests/unit/ui/test_card_info_panel_redesign.gd`（10 用例）；视觉探针 `tests/_tmp_cardinfo_visual_probe.tscn`（五态截图 .godot/agent_tools/cardinfo_*.png，SubViewport 1280×720 免窗口 DPI 缩放——直接截视口会得到 0.803 缩放图，像素断言坐标全错）。视觉验收轮追加修复四个存量残留：show_unit_info 不清操作按钮（敌方单位残留"卸下此卡"）、tier_label 不清（"精英"残留）、非战斗卡错显步兵机制行+词条标题孤行、"继承 0"（evolution_stage 默认 0）。背包 CardDetailPopup 实际 560×720（backpack_panel.gd 内 "340×460" 注释过期勿信）。

## v37 实机验收反馈修复批4：养成节奏重排 + 成长入口直进技能树 + 掉落可读性（2026-09-16）

**改节奏表/成长入口/掉落视觉/教程战斗步/雪原开场图前必读本节。** 七项用户实机反馈一轮清。

- **节奏表 v37 档（用户拍板，`data/feature_unlock_schedule.gd`）**：evolution(制造)=intelligence(情报舱)=**2**、modification(改造)=**6**（原 5/7/3）。解锁语义不变式：节奏表 level=N = 通关第 N-1 关后解锁（`complete_level(k)` 发 `keys_unlocked_at(k+1)`）——制造/情报实际在首战通关后即刻开，改造在通关第 5 关后开。afk=5、faction/store=10、affix=12、旁路六件=15 全不动。**改动门槛必同步 `tests/unit/systems/test_feature_unlock_schedule.gd`**（阈值/开集/跨级信号三用例 + 头注契约）。
- **开局情报地板（用户拍板"早点制造"）**：`IntelManual.grant_intel_floor(archetype_id, floor)`（只抬不降，走 `_add_intel` 正门）；`save_manager._enqueue_starter_backpack_cards` 末段给起始三卡（ww1_mauser/ww1_arty_m81/ww1_arm_ft17）的敌形原型抬到 `ManufacturePools.GATE_RECIPE`(0.25)——制造一解锁配方即可造。经 ManufactureManager `get_archetypes_of` 查原型域，直入卡空列表自然跳过；管理器不可达静默跳过不挡开档。回归锁 `tests/unit/systems/test_starter_intel_floor.gd`（5 用例，独立实例无需存档）。
- **WW1 掉落收口**：`LevelEras.ERA_DROP_MULTIPLIER[WW1]` 0.85→**0.70**（用户"首关掉卡偏多"；同乘纳米/符文击杀路径——前期经济大头在首通奖励与 1500 起步纳米，可承受）。要再调掉卡量优先动这个单变量，勿去拆 manifest 里多处 0.08 字面量。
- **成长入口直进技能树（用户拍板砍中转层）**：底栏「成长」键改标**「技能」**（main `_on_progression_pressed`）、基地「通讯架」工位（`truck_base._open_panel("growth")` 分支）、F 键 pw_open_growth、教程 ENHANCEMENT 步——全部直开 `PhaseMasterSkillHost.open(tree, true)`。根因：growth_panel 的改造/制造跳转按钮走 `main._toggle_overlay`，在基地场景 `/root/Main` 不存在 → **点了没反应**（本批实测根因）。**整备舱 growth_panel 退役为无入口孤儿**（场景/懒加载配置保留不删，关闭链仍引用）；教程触达面键仍叫 "growth"（`SURFACE_FOR_STEP` 不动，入口点手工补 `notify_surface_opened("growth")`）。教程 ENHANCEMENT/TRUCK_BASE/EVOLUTION 步文案已同步改口径（入口=底栏「制造」/「技能」），help_panel 卡牌成长页加技能树条目。
- **教程首战 HUD 指认（用户"开战不知道相位仪/卡仓在哪"）**：main `_show_tutorial_battle_hud_hints`（battle_started 挂钩，仅教程 FIRST_BATTLE(7) 步生效）——底部两栏上沿各浮一条位置指认，9s 自散、battle_ended 即清；FIRST_BATTLE 步描述同步补三块 HUD 位置文案。
- **掉落可读性**：①货币档再缩约 30%（`ground_loot_layer` CURRENCY_PX_NANO 20/26/31→**14/18/23**、BATTERY 23/29/34→**16/21/26**，拾取线索靠 `_draw` 柔光呼吸承担）；②缴获卡地面件加**迷你卡框**（稀有度色描边+深底+画芯+名条，28×36——原 30px 裸贴卡图被用户误读成"骑兵缩小贴图"），`_make_card_sprite` 返回 Node2D 组不再返回裸 Sprite2D。
- **跳过按钮二次收敛（v36 ghost pill 用户仍觉突兀）**：comic_intro + dream_battle 统一 92×26、「跳过 ›」、FONT_SIZE_SMALL、常态 font_color a=0.62 + modulate 0.8，hover 才升白——再调开场 UI 勿回大按钮。
- **雪原黑门远景重生成**：`assets/intro/wakeup_snowfield.png` 已换 v37 版（门=极远地平线小剪影，prompt 锁"高度占画面极小部分+与车间隔空旷雪原"，`tools/_tmp_regen_snowfield.py` v2 段可重跑；三候选在 `.godot/art_regen/snowfield_v2_*`）；v36 原图备份 `_art_backup/wakeup_snowfield_v36_20260916.png`。同路径换图后已跑 `--headless --editor --quit` 完成重导入。
- **基地热区悬浮说明补详**：`truck_base.HOTSPOT_DESC` 全表改两句式（面板是什么+关键规则/消耗），growth 条目改技能树口径；HOTSPOTS hint「成长规划」→「技能树」、短牌 map growth→「技能」。
- **验证**：`tests/_tmp_v37_smoke.gd`（--script 加载冒烟：12 文件可编译 + 节奏表/乘区/货币档/情报地板/教程文案/底栏标签断言，V37_SMOKE_OK）+ 两个测试文件 gdunit 9/9 PASSED。

## v6.15 命中打击感批次：D3 标准规则化 + 命中三件套 + 机制弹字（2026-09-17）

**改任何命中/弹道/枪口特效、加新武器或伤害机制前必读本节与 `docs/命中表现夸张规则.md`（唯一美术验收标准：D3 五律 + 12 武器族词汇表；改动只许向表收敛，新武器/机制先加表再写码；AI 评分只做回归参考，审美裁决归用户）。** 背景连续实测反馈：白团太大"太假"、机枪/步枪"多弹头"、满屏烟团——根因是按 AI 审计调参而非按用户拍板的夸张规则实现，本批起规则先行。

- **白色冲击斑**（vfx_impact_factory `_spawn_impact_poof` + `impact_poof_white.png` 内容实寸 116px）：仅轻动能(0/4)命中叠加，按 power_tier 分档——HEAVY 38-46px/0.22s、MEDIUM 28-34px、轻档 14-18px/0.11s tick；包络=膨胀→满亮保持→淡出（并行淡出亮度立不住，v17 残烟教训同款）。爆炸族/霰弹不叠（防 v18"白屏爆"回归）。**轻动能微烟已清零**（`spawn_layered_impact` 内该 elif 已删——非爆炸零烟，烟是爆炸族(1/3/9)专属词汇；历史 v18-R9b 5 粒→P1-R2 2 粒→0）。
- **剪影推白闪**（`unit_outline.gdshader` 加 `flash_strength` uniform + `UnitOutline.set_flash`/`has_outline_shader`）：受击主反馈 0.10s 敌我同拍（五律1）；全像素向白，深色卡图也读得出；**不动 modulate**（克隆体青蓝/阵营泛光零冲突，旧"modulate=WHITE 才触发"守卫只在 modulate 兜底路径保留）；预烘焙雪碧图（无描边材质）回退旧 modulate 脉冲。驱动口 = `UnitSharedHelpers.hit_flash_apply`（我方 construct_unit `_play_hit_flash` tween / 敌方 `update_hit_animations` 计时，两侧 0.10s 同拍勿改单边）。
- **暴击顿帧**：`battle_spectacle.play_big_hit_hitstop`（0.05s@0.1 复用击杀顿帧，450ms 冷却防机枪暴击连发顿成幻灯片），挂点 = `combat_feedback.show_damage` 的 is_critical（放节流前，合并窗口内暴击不丢拍）。
- **机制弹字层**（`damage_number_display.create_callout` 三样式 callout/callout_dodge/callout_shield + `CombatFeedback.show_callout_at`）：闪避（`show_miss` 已升格"闪避"银白大字替代灰 MISS）、护盾破碎（我方相位盾+常规盾、敌方灵能盾破瞬间青蓝大字）。**克制破解勿走此层**——battle_announcer 已横幅播报，双报。池复用靠 `_override_text`（reset_pool_object 清空，prepare 不清）。
- **点射"多弹头"修复**（bullet.gd `_apply_visual` 尾部 echo_a 块）：纯视觉弹（v20.18 点射后续波，步枪 2 发/机枪 3 发）弹头/拖尾/曳光统一 42% alpha——一次点射一个明显弹头，后续波读作曳光回声；真伤弹池复用对称复位。**只动 alpha 勿动 rgb**（阵营/亚类染色链路在别处）。
- **数字相对分级 + 燃烧升格**：`combat_feedback._do_show_damage` 伤害 ≥15% 目标 maxHP 升 big_crit 金色大样式（绝对 500 保留为下限，传 unit 者才生效）；`dot_vfx_manager` burn 火焰 80→112px、y -10→-26 包住下半身。
- **有意偏离 D3 项（用户裁决保留）**：伤害数字用阵营双色 + 相对量级金色大字（D3 是小数字）；机制弹字保留。
- **验证**：回归冒烟 `tests/weapon_visual_profiles_smoke.gd` 124 PASS；48 格标准帧 `docs/vfx_audit_shots/`（审查页 tools/vfx_audit_review.html）。**教训沉淀**：①子块编辑缩进错一层=孤儿 else（本轮 bullet.gd 实踩，gdparse+HEAD 对照可抓——gdparse 报错先 git show HEAD 对照再定性）；②审计矩阵抓帧计时比标签晚，亚 0.2s 特效逐帧 zoom 看，勿只信像素阈值；③工具视口截图有 0.803 缩放（坐标换算后再断言）。

## v6.15b 单位视觉抖动三修批：步枪班帧动画 + 受击弹跳收敛 + 攻击姿态归一（2026-09-20，详见 CHANGELOG）

**改单位动画部署/受击抖动/attack_f0 姿态资产前必读本节。** 用户实机三症状：敌方步枪班无分帧动画、救护车受击"跳起来"、敌方很多单位攻击时"一会大一会小一会左一会右"。

- **动画部署 key 纪律**：`unit_anims/<key>` 的 key 必须能被 `UnitFrameAnim._resolve_key` 解析链命中——卡 id 直查 → `foe_` 剥前缀 → `EnemyCardModMap.player_card_id` → manifest visual_id。v24 批曾按**源目录名**部署（`ww1_rifle`），卡 id 是 `ww1_inf_rifle` 且映射指向 `ww1_mauser` → 全 miss 静默回退静态卡图。现步枪班动画挂 `ww1_mauser/`（敌经映射链+玩家起始卡直连双收益）。⚠️ `ww1_mp18/ww2_garand/ww2_mg42/ww1_storm` 等源名 key 目录是映射链合法落点**勿当孤儿清理**；真孤儿判定=上述解析链四步全 miss。探针 `tests/anim_key_resolve_probe.gd`。
- **受击抖动幅度**：`HIT_SHAKE_KEYS [0.90,1.06,0.97,1.0]`（原 0.78→1.12 对大体型单位以地面脚点为轴放大=30-50px 垂直抛跳"受击跳起来"）。调受击手感只动这组常量与时长，闪白/击退/血溅通道各归各。
- **attack_f0 归一契约（新增回归锁）**：`AttackPoseAnim` 换 texture 零补偿——`attack_f0.png` 的内容**高比必须=卡图内容高比（±6%）且矩形中心 x 对齐（±4%）**，朝向必须与卡图同侧（敌左），否则每次开火大小跳/横跳/180°翻脸。归一器 `tools/normalize_attack_f0.py`（幂等；映射导出 `tests/attack_f0_map_export.gd`）+ 回归锁 `tests/unit/data/test_attack_f0_consistency.gd`（gdunit 门禁常跑，2026-09-20 自 _tmp 名下正名；硬指标 rh∈[0.94,1.06]+|dRectCx|≤0.04 出带即 FAIL；rw 宽比与质心差是软记录——攻击姿态动势属合法形变勿当缺陷）。v6.15b 已修 6 张镜像错误（ak/m60/cyborg/spectre/delta/marine）+16 张全量归一；原图备份 `.godot/art_backup_attack_f0_20260920/`。**新做攻击姿态资产先过审计锁再入库**。
- **枪口火花现状（勿重复排查）**：敌我双侧共用 `ConstructUnitAI._play_muzzle_feedback` 单一真身（敌方 `_do_attack:1532` / 我方 `do_attack:740`），轻动能族火花参数经 v17c/v18/v26.15f 三轮标定（白热闪核+细火星锥，刻意低调防"橙色糊团"回潮）。审计矩阵 72 格实测双侧镜像正确。

## v37.1 改造图标座统一批：稀有度发光底座收口（2026-09-17）

**改改造图标显示点/稀有度视觉/ModIconTile 前必读本节。** 用户实机反馈"改造图标没有眼前一亮"——根因：约 98 张青橙扁平图标裸贴深底（暗、同质），稀有度在图标层完全不可见（common 与 mythic 可共用同图同貌），详情操作台只显示字母框不显示真图。

- **唯一收口 `scripts/ui/mod_icon_tile.gd`（`ModIconTile.make(mod_data, size, glow_mode=0, dim=false)`）**：底座样式复用 `CardFrameUi.tile_rarity_style`（符文/卡牌瓷砖同一套稀有度递进发光语言：common 无光中性 → mythic 2px 强光），内嵌真图标（边距 size/8 钳 2-5），无图回退稀有度色首字母。tile 及子控件 mouse_filter 全 IGNORE（嵌行按钮防吃点击，v26.16 同律）。⚠️ 返回值内 StyleBox 是缓存共享体勿就地改，改前 duplicate；**tooltip 别挂 tile（IGNORE 收不到鼠标永不触发），挂宿主行按钮**。
- **接入点**：改造库列表行 26px（modification_panel）+ 已装列表行 20px（dim=not enabled）+ 详情操作台 %DeckIcon 44px 激活档（DeckIconTex 首显真图标，无图回退原字母框）+ 制造中心图纸行 26px（evolution_panel `_make_mod_thumb` 已收口为一行）+ 卡情报 ModsBlock 九槽已装态（card_info_panel，tile_rarity_style duplicate 直角保留 + btn.icon 18px）。背包图纸格已有 tile_rarity_style chrome（resource_slot_item）未动。
- **视觉探针** `tests/_tmp_modicon_probe.tscn`（独立窗口跑一次自存图自退出 → `.godot/agent_tools/modicon_probe.png`，SubViewport 直采免 DPI 缩放）。验证：ui_p1_validation ALL PASS（CHANGED_SCRIPTS 已加 mod_icon_tile.gd）。
- **未动（防重复劳动）**：图标贴图本体零重生成（98 张；若仍不够"亮眼"，后续可选项=传说/神话档走 STYLE_BIBLE 6.4 徽章管线出样张，审美裁决归用户）；tile_rarity_style 共享样式未改（符文/卡面零波及）。

## v37.2/v37.3 改造图标全量重生成部署 + 战法件贴花批（2026-09-18）

**改改造图标资产/换图、给单位加贴花、动 mod icon 字段前必读本节。** 用户拍板：自动跑分选优（人不逐张看）、稀有度不进图、贴花只做关键战法/具象装备。

- **图标已全量换代（v37.1 的"零重生成"作废）**：249 张 B 霓虹纹章风（`assets/ui/icons/mod_icons/<mod_id>.png`，相位仪徽章 6.4 同源）替换旧青橙扁平图；249 条 icon 字段已重映射；旧图备份 `.godot/art_backup_modicons_v37_20260918/`。**新加改造要出新图标**：跑 `tools/_tmp_gen_modicon_mapping.py`（关键词词典补一条）→ `tools/_tmp_gen_modicon_full.py`（断点可续，3 掷+六项审计+修复队列）。**审计标准六条在 `tools/_tmp_modicon_audit.py`**（bbox 占比 0.55-0.98/居中<0.20/双主体<0.55/对称<34/族色相±40°/26px 存活≥55），阈值经样张校准，勿凭感觉调。
- **稀有度不进图铁律**：图标本体稀有度中立，价值梯度全由 ModIconTile 底座承载——改稀有度/升档不动图。
- **战法件贴花**：唯一映射真身 `data/mod_visual_decals.gd`（11 贴花+18 映射，新增形象件=加一行，图标自动带琥珀 ◈ 角标）；唯一挂载口 `scripts/battle/unit_mod_decal.gd`——**只加兄弟 Sprite2D，禁直写 unit_spr.texture/scale**（v26.9 描边契约）；尺寸锚点按不透明 bbox（`_content_bounds` 带缓存），敌方自动镜像。我方数据源=stats meta `mod_ids`（build_stats_from_card 写入），敌方=既有 `loadout_mods` meta——**给敌方配装加形象件即自动显示，无需新代码**。
- 验收探针：`tests/_tmp_modicon_deployed_probe.tscn`（图标全链路）+ `tests/_tmp_decal_probe.tscn`（贴花镜像）。批次背景/生成数据在 `docs/待生成徽章_改造图标样张_20260917/`（mapping_draft/full_report/分族对比表；full_raw 约 1.1GB 验收后可清）。

## v38 实机验收反馈修复批5：教程可见性 + 战斗 UI 重排 + 紫框根修 + 掉落/弹体（2026-09-17，详见 CHANGELOG）

**改战斗菜单/情报卡 Tab/掉落入场/弹体尺寸/换相位仪反馈/结算直通键前必读本节。** 用户 12 项连续实机反馈一轮清。

- **胜利后空紫框根因（勿再当教程残留排查）**：`intel_reveal_popup` 曾用 `get_node_or_null` 查**运行期匿名节点**（未显式 name 的容器，Godot 4 自动名带 `@` 前缀）→ 恒 null → 标题/描述从未写入。已改构建期**成员引用**。教训：运行期构建的 UI 一律存成员引用，勿事后按路径反查。
- **背包入队唯一口 `save_manager.enqueue_backpack_card_id` 已带去重**（v38）：互斥不变式（卡要么在相位仪要么在背包）下重复入队=重复卡物化。任何新路径归还卡到背包都走此口，勿绕过直写 `_pending_backpack_ids`。换相位仪（`equip_instrument`）成功后有 toast 说明槽数与归还——槽数 3~9 是仪器星级合法差异。
- **下一关直通键门槛 = `is_past_first_battle()`**（v38，mvp_panel）：不再等教程 14 步全完；首战步完成（点「开始首战」即完成）当屏胜利结算就出直通键。战后续播步回基地照常点播。**v38.1 双直通键**：「↻ 再战本关」（`_compute_replay_level`，胜/败均可、败局占主键位）与「▶ 出击下一关」并存；底栏四键色相区分（绿=下一关/青=再战/灰=返回整备/橙=回基地），改结算底栏布局先看 920 宽四键排布。
- **功能抽屉恒右侧竖排（bottom_function_bar，v38.2 用户拍板勿横竖互变）**：_ready 一次性立形——按钮进 Margin/Column 竖列 + 整条抽屉挂 HudLayer 右缘点锚（grow 向上向左，底边抬离底部两栏 140px）；基地/备战/战斗同一布局。战斗态（battle_started/battle_ended）**只过滤键集**（隐藏技能/改造/制造，剩 卡仓/地图/设置/存档/挂机 5 键），不碰布局。改底栏键集时按 BTN_CONFIGS 全量顾；按钮挪动必须用 `reparent()`（add_child 对已带父节点报错）。
- **情报卡 Tab 契约（v38）**：INFO=六分区速览（立绘纵向填充），**DETAIL(1)=详细情报**（AffixScroll 整棵滚动区，tscn 节点已改名 TabDetail——gd/tscn 路径都用 `TabBar/TabDetail/AffixScroll`）；改造/制造 Tab 仅 MODE_PHASE_INSTRUMENT 显示（背包/战场隐藏，ModsBlock 砖块降级纯悬停）。
- **开场苏醒演出**：无任意点击跳过，只有右上「跳过 ›」ghost pill；教学三拍 5.0/6.0/5.0s。改演出节奏先想"这是唯一一次讲相位仪装配的地方"。
- **卡仓首开指南**：`backpack_panel.on_overlay_opened` → `FeatureUnlockPopup.show_once("backpack_guide")`。改卡仓结构/装配交互时同步该三行文案。
- **世界地图常驻出击入口（v38.1 分离版）**：左下角 MapChromeStack 竖堆——MapActions 动作面板（「▶ 进入本关/↻ 再战本关」按停靠关通关态切换文案 + 「◎ 回到当前关」）在上、MapLegend 纯文字图例面板在下。直进停靠关与锚点弹窗同走 `_enter_level_from_popup`（停靠门控/内嵌直调/meta 链共享）。加新的进关入口勿另起链路；**动作键与说明文字勿再混进同一面板**（用户拍板）。
- **弹体尺寸律（已入 docs/命中表现夸张规则.md 横切规则）**：飞行弹体恒小于一个兵（基准 58.9px）；曲射 PROJ_TEX_SCALE[1]=0.45、榴弹 flavor=1.0。火箭/导弹（wt3/9）未动，用户再提再单变量调。
- **掉落语义 = 击毁炸出、散放地上（v38.2 用户澄清）**：`ground_loot_layer._play_toss` 每件随机方向（全周角）+ 随机距离（18-64px）甩出、小跳 ≤12px、落定**本体**随机倾角 ±14°（倾角只转 _body：光柱/名条/柔光保持竖直）；同次多点各异 = 散放感。**反例：垂直下落/整齐排布**（均被用户否决）。低档落地小尘环、高级件音效在落地瞬间保留。改掉落视觉先看本条再动手。
- **冒烟纪律补充（--script 模式）**：`_initialize()` 阶段 `add_child` **不派发 _ready**（等首帧）——实例化场景做断言须手动 `panel._ready()`；勿用 await process_frame（会挂死）。范本 `tests/_tmp_v38_smoke.gd`。
- **留观**：gdunit 错误监视器上下文报 `unit_stats_table.gd:651 ModBreakpoints not declared`——该文件与 modification_registry.gd 带分支在途未提交改动（+18/+56 行），全 autoload 上下文编译无错，非 v38 引入，待在途改动收口时处理。

## v6.19.3 实机验收修复批6：结算底栏四键重叠 + 战斗「菜单」按钮失效（2026-09-20，详见 CHANGELOG）

**改结算底栏布局 / 按路径查找 BottomFunctionBar 前必读本节。**

- **结算底栏四键坐标契约（mvp_panel `_render_close_button_anchored`）**：`x0` 是「返回整备」自己的起点**不是行起点**——基地键 24..204 / 整备 216..384（`x0=216 if has_home else 100`）/ 再战 396..584 / 主键 596..896，间距 12。写错成 24 = 整备键整键叠死基地键（用户报"按钮重叠、看不到下一关"根因）。回归锁 `test_settlement_next_level.gd::test_bottom_row_four_buttons_no_overlap`；视觉探针 `tests/_tmp_settle_row_probe.tscn`（BunkerManager 懒加载需 `ensure_loaded("bunker")`+等一帧）。
- **BottomFunctionBar 路径查找纪律**：v38.2 起抽屉被 reparent 到 `HudLayer/BottomFunctionBar`（直下），旧嵌套路径 `HudLayer/BattleBottomBar/BottomFunctionBar` 仅在测试/裸实例化成立——**按路径查找它的新代码必须双路径容错**（新路径优先）。v6.19.3 修了三处 reparent 后落空的查找：相位仪栏菜单按钮（`../../BottomFunctionBar`，用户报"菜单按钮按了没反应"根因——旧路径恒 null 静默 return）、`_get_top_controls`（`../TopHudBar`）、battle_manager 开战帧 set_start_battle_text。路径冒烟 `tests/_tmp_v382_paths_smoke.gd`（V382_PATHS_OK）。
- **全 UI 体检探针 `tests/_tmp_ui_audit_probe.tscn`**（2026-09-20 全量过一遍，结论存 CHANGELOG v6.19.3 附录）：窗口化自跑 45 面板+main 合成态，A 同尺度覆盖/B 出界/C 零尺寸三类检测+逐屏截图；ScrollContainer/SubViewport 子树与双全屏层叠豁免。**跑前必须备份 `user://` 目录（`%APPDATA%/Godot/app_userdata/phase-war`）并在跑完还原**——面板 _ready 会触发 show_once/自动存档写盘。新面板入库想兜底体检就复跑它。

## v6.19.5 开场链宽窗适配（2026-09-20，详见 CHANGELOG）

**改 comic_intro / dream_battle 前必读。** stretch aspect=expand 下窗口宽于 16:9 时设计坐标变宽——开场链原全部按 1280×720 钉死（舞台左贴、跳过键悬半空、幕布盖不满），用户实机报"开始剧情，右上角"。现：comic_intro 舞台水平居中 + 跳过键挂根节点 TOP_RIGHT 锚；dream_battle 的 CanvasLayer chrome（跳过/幕布/红晕/白闪/选卡框/标题副标）全改视口锚点自适应。**红线：dream_battle 的 _world/_battlefield/相机坐标未动也不要动**——单位 global_position 生成 + spatial_grid 参与，居中会错位战斗模拟；宽窗下战场左贴是接受的演出观感。验证探针 `tests/_tmp_comic_probe.tscn`（三组 SKIP_AT_CORNER_OK 断言；intro 场景有自播时间轴，不在 ui_audit 探针名单，改后用它验）。

## v6.16 改造爽感批次：D2 门槛装备五层（断点/门槛件/反制配波/槽位预算/数值帽分档）（2026-09-17，详见 CHANGELOG）

**改任何改造数值/槽位/攻速/关卡配波前必读本节。** 用户拍板"要 D2 关键流派门槛装备的感觉（既平衡又碾压）"+槽位按品质/类型分化。五层全部实装，各自有独立总开关可一键回退。

- **攻速断点唯一真身 `data/mod_breakpoints.gd`（ModBreakpoints）**：聚合增益 20/40/70/110% 四档（额外提速 ×1.05~×1.35 + 首弹蓄力 ×0.75~×0.10）。消费点唯一=`unit_stats_table._sync_mod_speed_ratio_to_weapon_slots`（敌我同构；stats 侧同步乘档位乘区）。⚠️ 新类引用必须 preload 而非 class_name（gdunit 错误监视上下文无编辑器扫描，v38 尾注在途报错即此坑）。UI 增益口径=速度键−1（get_modified_stats 速度键从 1.0 起步，勿除卡基础轴速）。总开关 `GameConfig.mod_breakpoints_enabled`。
- **槽位预算唯一真身 `ModManager.get_max_mod_slots_for_card`**：品质基础槽 common5/uncommon6/rare7/epic8/legendary9/mythic10 + 兵种专属槽（堡垒+2 其余+1）。**专属槽只收兵种件**——registry `is_family_mod`（`_family_by_id` 家族索引；universal/enhancement=通用件只占基础槽）。安装链三门：总槽满/通用件超基础预算/冲突。**旧档祖父条款：超额只封新装不剥离**。敌方配装序列不动（9 条=传奇档预算，玩家顶级底盘 10-12 槽即追卡理由）。总开关 `GameConfig.mod_slot_budget_enabled`（false=全卡恒 9）。改 UI 时勿再硬编码 9——砖块数/过滤/N-M 文案全部走该函数。
- **门槛核心件（keystone）纪律**：`ModificationRegistry.KEYSTONE_IDS`（16 件，每兵种 1-3）——**新门槛件必须=行为改写+显式代价键（负值落 effects 与 level_effects 双处）**，代价键限敌方白名单内（max_hp/attack_*/attack_range/single_target_penalty）保敌我对称；数据打 `keystone = true` 标记（UI 金色[门槛]标签消费）。**纯数值传奇一律 epic 化**（本批降 10 条，传奇 49→39/史诗 78→88，总数 249 锁不变）——想加传奇先问"它改不改战法"。
- **数值帽分档 `STAT_VALUE_CAP_BY_RARITY`**：单条 pct 帽 common~epic 0.60/legendary 0.80/mythic 1.00（数据级约束，`test_economy_balance` 稀有度感知扫描）；运行期七通道 pct 仍是乘法叠加（无聚合帽，别找不存在的运行时帽）。
- **反制配波 `counter_bias_tags`**（special_rules 新键，D2 免疫式平衡）：关卡敌方构成 70% 偏向某兵种 tag——**新增该键关卡要四处同步**：`level_information._apply_special_rules` 挂载、`battle_spawn_system._merged_wave_bias_tags`（spawn+预警同口径）、`world_map._format_special_rules` 摘要行、`build_advisor` 规则条建议；MECHANIC_BANNER_TEXT 文案勿漏。tag 词汇表=enemy_archetypes（armored/tank/aircraft/infantry/fast/artillery/backline）。L1 铁律不受影响。
- 回归锁：`tests/unit/data/test_mod_breakpoints.gd` + `tests/unit/systems/test_mod_slot_budget.gd` + `tests/unit/data/test_mod_keystone_rarity.gd`（稀有度 39/88/249 锁在此）+ `tests/unit/data/test_counter_wave_pools.gd`（反制 tag 题面必真——**加新反制关必须过此锁**，L53 backline 零匹配即它抓的）+ `tests/unit/ui/test_modification_panel_v616.gd`（面板运行时：断点行/门槛标签/动态槽）。special_rules_hooks 已扩 8 键。冒烟 `tests/_tmp_v616_smoke.gd`（V616_SMOKE_OK）+ `tests/_tmp_v616_counter_tags_check.gd`（COUNTER_TAGS_OK）。

## v35 旧设定残留清理批：战斗热路径性能 + 遗留枚举/死配置/断链清零（2026-09-15）

**改 bullet/蜂群开火/曲射 batch/卡图视觉辅助/VFX 工厂渐变前必读本节。** 三路审计（旧设定残留/热路径性能/VFX 死配置）后修复，全部现役行为零变化（除注明两处轻微观感修正）。

- **空中瞄准点 sprite 引用缓存**（`card_grid_unit_visuals.aim_pos_for`）：sprite 引用缓存进目标 meta `_aim_spr_ref`（直射弹每帧最多 3 次调用、原每次 get_node_or_null×2）。契约：sprite 引用失效自动重解析（换建 sprite 无需清 meta）；**给单位换 sprite 节点的代码不用管，直接替换同节点 texture 的更不用管**。
- **敌攻速缓存巡检降频**（enemy_unit `_process_attack_timing`）：攻速变化巡检从每帧 `get("stats")`+武器重查 → 0.5s 节流（成员 `_timing_chk_accum`）。攻速改写生效延迟 ≤0.5s，对秒级 debuff 不可感。
- **光束谐振邻搜走空间网格**（bullet `_find_beam_neighbors` 新增）：beam split/reflect 找 120px 邻居从 get_nodes_in_group 全组扫描改 `spatial_grid.query_enemies`；**>N 候选时取最近**（原取组序前 N，语义微调更直觉）；grid 不可用回退全组扫描。
- **蜂群路由撞值消歧义**（swarm_enemy_controller `_fire_from_slot`）：slot wt（archetype 原样透传，legacy/新枚举混域）先按 combat_kind 归一成 canon 新枚举（非 SUPPORT 的 wt1→DIRECT、非 AIR/SUPPORT 的 wt2→DIRECT），曲射 `is_indirect_weapon_type` 前置路由进 enemy_indirect_batch——**现役 roster 路由路径零变化，但有一处连带修复**：wt_canon 也传给了 `cross_row_direct_multiplier`，legacy 步枪/机枪蜂群（wt=1/2）此前被撞值误判成曲射而**意外豁免跨行直射减伤**（恒 ×1.0），现与经典敌兵同口径（跨行 ×0.70、同行全额——经典侧 v26.x 已修，本处补齐）。未来加曲射蜂群不再被 BATCH_FIRE_WEAPON_TYPES 误拦成直线曳光。
- **渐变缓存键 int 化**（vfx_impact_factory 4 处）：`_get_spark_ramp`/`_get_cached_gradient`（键改 salt<<24|RGB 打包 int；金属破片固定档=3）——免每命中 % 格式化拼串。`_get_cached_gradient` 签名已改 `key: int`，**新调用方传 int 键勿传字符串**。
- **命中烟层轻武器域修正**：`_spawn_smoke_puff_layer` 轻武器集 `[0,1,2,4]`→`[0,4]`（新枚举优先约定下 1/2 恒重型；legacy RIFLE/MG 上游已归一 0）——曲射/空射命中烟量 0.85→1.0，轻微观感修正。
- **DOT 状态表 const 化**（dot_vfx_manager `_DOT_STATES`）：原每刷新 new 4 dict+1 Array。加第 5 种 DOT 时在 const 表加一行。
- **曲射 batch 死配置清理**（simple_indirect_projectile_batch）：`_WEAPON_CONFIG` 只留 `explosion_radius`（speed/max_dist 零消费且数值误导；飞行时长唯一真身=fire() 的 `0.6+dist/2000*0.8`×亚类 duration_mul）。`d["impact_spawned"]` 写不读已删。**要给曲射加速度轴另立新键，勿复活死列**。
- **proj_quad_size 收缩**（weapon_projectile_vfx）：只留活档 1/2/3/7/9（唯一消费方=曲射 batch），死档 0/4、5、6、8、10、11 及两个从未消费的错误尺寸（PISTOL 567×131/legacy MG 1349×110）已删。**给直射弹体建 MultiMesh 层时按当时贴图另立新表**。
- **bullet 死代码清除**：FLAME_STAR_TEX 预载、`_beam_visual_phase`、`_impact_spawned`、曲射尾帧恒空 pass 块。
- **死常量/死引用清除**：game_constants 法则碎片三常量+starter 法则函数（法则 P2-7 退役残留；`NEW_GAME_STARTER_RUNE_IDS` 是活数据勿删）；save_manager `SK_PHASE_LAW/SK_CHARACTERS/SK_CHALLENGE_RECORDS` 死别名（SaveConstants 本体保留供迁移链）；world_map 死 preload PhaseLawsData；vfx `normalize_light_kinetic_wt`（零调用，实际归一在 WeaponVisuals.resolve_visual_wt）。
- **断链修复**：gen_23_singularity_core 图标 `assets/ui/icons/mod_special.png`→`mod_icons/mod_special.png`（原路径 404，mythic 改造一直显示占位色块）。
- **main.tscn 墓碑瘦身**：BattleTopStatusBar 内 PlayerSpawnHUD/EnemySpawnHUD 死节点删除（含 4 个场景/脚本文件；单位数显示早已由 TopHudBar 接管）；**BattleInfoDisplay 统计引擎保留原位**（battle_status_strip/mvp_panel/bunker_manager 三方活消费，搬动需先迁移）。
- **资产垃圾清除**：mod_icons/ 4 个 API 响应 `.payload.json`（连同 decals 2 个）入库清理。
- **二批（同日）**：fort_shield_aura `_draw_ring` 改 `draw_arc`（零分配，几何等价）；construct_unit 机制 tick 双收集器改 `BattleManager.get_cached_nodes_in_group`（0.28s 缓存，**新消费方必须保留 is_instance_valid 守卫**）。核实跳过：base_aura（仅 2 实例）/unit_status_collector（有状态才分配）/共感组扫描（组不在缓存名单）——首轮性能代理"每单位"评级有误，实测为噪声。
- **评估未做**（防重复劳动）：①每粒子 SceneTreeTimer+lambda 改 CPUParticles2D.finished 信号回收——26 处调用点且 `spawn_smoke_column` 一处 one_shot=false 不兼容，收益不抵回归风险；②base_aura/fort_shield_aura 每次重绘的多边形分配——20Hz×小数组属噪声级；③instance_registry 序列化 `enhance_level` 残值——battle_spawn/背包仍在读该字段，删除改读档语义；④曲射 MISS 文字提示、batch/bullet 溅射上限差异（4 vs 无上限）——前者是演出设计、后者是性能护栏+平衡面，均维持现状。

## v26.10 改造模块消耗品化 + 双通道供给（2026-09-02，详见 CHANGELOG）

**改改造安装/图纸掉落/制造站相关代码前必读本节。** 核心语义：安装一条改造 =
消耗 1 张对应图纸（IntelItemBag 库存）+ 纳米费；图纸是库存货币不是永久解锁。

- **安装链**（`blueprint_manager.gd`）：`install_modification` 落账扣图纸；价格公式唯一
  真身在 `preview_install_cost(card)`（UI 显示与扣款同源，勿在面板重抄公式）；
  总开关 `GameConfig.mod_consumable_enabled`（false=回退旧永久解锁行为）。
- **见过集合**（`intel_item_bag.gd`）：`consume_item` 归零删 key 查不到"得到过"——
  制造门槛（**得到过就可造**：掉落负责发现、制造负责补给）依赖 `_seen` 集合 +
  `has_seen`；旧档回填=库存∪已装改造（SaveManager critical 批后调
  `backfill_seen_from_registry`）。改造面板列表数据源=见过集合（消耗光仍留在列表，
  灰显"图纸不足"），**勿改回读库存**。
- **制造通道**（`data/mod_manufacture.gd` + `manufacture_manager.gd` + evolution_panel
  双模式）：common/uncommon/rare 定向兑换（80/150/280 纳米档）；epic+ 只能随机箱
  （按 mod 稀有度加权 + pity）；工坊折扣经 `_apply_workshop_discount` 与卡牌制造共用。
- 新档 starter：`clear_slots_for_new_game` 送 2 张 `blueprint_inf_14_knee_pads`
  （全注册表唯一 common/GRUNT 档模块，教程第 6 步依赖）。
- 掉率/纳米费首版未动（单变量原则），供需实测后调；数据锁
  `tests/unit/economy/test_mod_consumable.gd`（14 用例）。
  **v32.2 实测跟进**：掉落侧已加 era_band 时代过滤（`roll_random_mod_blueprint` 增 `max_era`
  参，era0 口径实测原 66/200 掉落装不上）——"图纸积压"应明显缓解；稀有度权重仍未动。

### v26 敌方四档真实配装 + 新飞机（2026-09-01，详见 CHANGELOG）

**改敌方配装/出兵/空中单位前必读本节。**

- **四档体系**（`data/enemy_loadout_tiers.gd`）：新兵/老兵/精英/传奇（时代内 in_era
  1-5/6-11/12-17/18-20 循环；相位师恒传奇）。旧常量 LOW/MID/HIGH 为别名（HIGH=传奇）。
  标量 [×1.20/1.30/1.46/1.66]——**改造贡献计入总量后校准**，调难度改 TIER_BONUS 单变量，
  以 `tools/enemy_tier_strength_audit.gd`（档位归因口径）实测为准（目标 1.40/1.65/1.95/2.25）。
- **配装表**（`data/enemy_fixed_loadouts.gd`，139 敌方 id 全量）：每卡 {identity 定位,
  mods 9 条增量序列, cuts 四档条数}。**v6.14.3 标准三件套（用户拍板）**：每卡序列头
  三槽=该（兵种 unit_type × 时代）的标准件——生成器从未被模板引用的合格件中按
  "本兵种家族 > 其他非词条"优先选取（排除 set 换装件与 enh_ 词条），剩余 6 条保留
  模板块；缴获掉落自此覆盖三件套。改条目跑 `tools/gen_enemy_loadout_draft.gd` 重生成
  （生成区标记之间整块覆写，手改 mods 会被下次生成覆盖；identity 微调同样会被覆盖，
  永久手写覆写应改生成器的模板/overrides）。数据锁在 `tests/unit/data/enemy_loadouts_test.gd`
  （覆盖/cuts/冲突组/时代带/白名单）。三件套轮强度审计均值 -10~-12% 已按容差接受，
  漂移注记见生成器头注；**TIER_BONUS 标量不进审计指标却真实抬战斗内高档敌人，勿当
  审计回中旋钮**（enemy_loadout_tiers.gd 头注）。
- **挂载双侧**：经典敌兵 `enemy_unit._apply_loadout_modifications`（v21 词条同位）/
  相位师产兵 driver 乘区6。管线=玩家同款（四通道+比值同步武器槽+武器槽通道），改造
  等级随档位 Lv1/2/3。**敌方效果键白名单** `LOADOUT_MOD_SUPPORTED_KEYS` 在配装表文件——
  新增改造键要给敌方用必须同步白名单（宁少接不乱接）。**频率轴已开（v26.3）**：
  `attack_interval` 入白名单，落点=`_sync_mod_speed_ratio_to_weapon_slots`（敌我 timing
  主路径都读 `weapon_slots[].attack_speed`，只写 stats per-target 轴会空转——该存量 P1
  双边修复于 v26.3，玩家攻速改造自此实战生效）；SUPPRESS/AA 模板已接攻速件（37/117 条目）。
- **新飞机 8 张**（era1-4 轰炸机/多用途，D 段池）：轰炸机 tags 含 bomber → aoe_cap=8
  （batch 溅射上限放宽）+ AERIAL 半径读 splash_radius_bonus（`simple_indirect_projectile_batch`）。
  **玩家飞行单位索敌已加 AIR 优先**（空优对称）。8 张卡图待 AI 生图（生成后必跑
  `generate_card_foot_anchors.py` + 美术打包铁律）。
- v21 同源词条门槛=精英档（1 条）/传奇（2 条）。
- 数量锁：改造总数 **249**（`modification_modules_test` + `combo_tier_smoke` 两处 +
  armor per-module 18）。

### v26.2 战斗界面 UI 整编（2026-09-01，详见 CHANGELOG）

**改战场名牌/头顶 UI/底部条前必读本节。**

- **战场名牌短名机制**：`CardResource.short_name`（`unified_card_table.gd` 76 条，
  两轮 Noto 真字体实测校准）——名牌条解析顺序 = short_name → display_name 剥
  `VARIANT_SUFFIXES`（·精锐/·敌方/·Boss/·改/五个时代后缀，表在
  `card_grid_name_strip.gd`）。**display_name 全名不动**（图鉴/情报/悬停仍显示全名）。
  名牌条字体=打包 NotoSansSC（`DT.CJK_BUNDLED_BODY`，ThemeDB 回退字体把省略号画成
  下划线的坑勿回踩）；条宽=卡宽 ×1.12。**加新卡必跑 `tests/_tmp_measure_names.gd`**
  （Noto 11px 逐条实测，上限 62px；ASCII 宽度用 0.52em 估算会漏 `m` 类宽字母）。
- **头顶栈单一锚定**：血条/光环条/改造条/buff 文字标签的 y 全部走
  `card_grid_unit_visuals.gd` 的 `overhead_*_y` 四基准函数（血条锚 entity_top−14）；
  等级唯一显示位=血条左侧 LvN（实体左上角 LevelTag 已删，勿复活）。
- **HUD 底板两档规格**：顶部浮动面板=`make_hud_panel`（圆角 6/a0.72）；底部卡片族
  （相位仪栏/功能抽屉/大招条）=`make_panel_frame(青)` 悬浮卡片（圆角 12/alpha 0.92）。
  UltimateCastBar 底板在 `_draw()` 里贴按钮簇绘制，按钮显隐变化记得 `queue_redraw()`。
- **遗留节点墓碑**：main.tscn 的 BattleTopStatusBar 恒 hidden 但内含 BattleInfoDisplay
  （隐形统计引擎，battle_status_strip/mvp_panel/bunker_manager 消费）——删除前先迁移统计累积；
  TopLeftMeta 已删；内含 PlayerSpawnHUD/EnemySpawnHUD 死节点已随 v35 删除（含场景文件）。大招按钮文案"大招:自动/手动"（勿改回"自动"，与自动部署按钮重名）。
- **满血血条减噪**：unit_hp_bar 满血且无护盾/未选中时视觉层淡到 0.45（状态图标/等级
  文字/选中框不降级）——改血条视觉或加新的血面子节点时，记得挂进 `_apply_idle_alpha`
  的淡出名册，否则满血态会突兀地全亮。
- **子弹特效父节点铁律**：v26.11(D1) 起归池子弹常驻 ObjectPool 节点下——bullet.gd 里
  任何特效父节点**禁止裸 `get_parent()`**，一律走 `_resolve_fx_parent()`（识别池容器
  并回退缓存的开火父层），否则归还后时序触发类型报错+特效丢失。
- **战斗实机截图工具**：`tests/_tmp_ui_battle_shot.gd`（.godot/ui_battle_shot_mode.txt
  配 level/frame，载档→选关→自动部署→全视口含 HUD 截图到 .godot/agent_tools/）。

### v25.0/v25.1 改造数值四通道 + 时代适配 + 平衡核查（2026-08-31，详见 CHANGELOG）

**改任何改造（modification）数值/键前必读本节。** 四通道口径（引擎在
`modification_registry.gd` 的 `apply_with_level(base, mods, host_ctx={era})`）：

| 通道 | 写法 | 语义 |
|---|---|---|
| set 替换 | `<stat>_set = N` | 换装类确定值；第 1 遍历覆盖基础值，**更优才生效**（≤当前值不生效）；flat/pct 叠加在新值上。试点：inf_02 突击步枪化（era1 基准 90/105/120）、arm_05 滑膛炮（era2 基准 560/620/680） |
| flat 固定 | 7 键 int（`attack_light = 8`） | 平加；**攻击/HP 族按宿主时代缩放**（声明基准=era_band 下限） |
| pct 百分比 | 7 键 float（`0.25`）或显式 `<stat>_pct` | 乘区 ×(1+v)；混合条目（flat+pct 并存）必须用显式 `_pct` 后缀 |
| 混合 | 同条目 flat+pct | 例：倾斜装甲 `defense_armor=15` + `defense_armor_pct=0.08` |

- **时代缩放表**在 registry：`ERA_FLAT_SCALE_ATK/_HP`（卡池中位推导）；防御族/射程(px)/
  百分比不缩放。旧调用方不传 host_ctx → 绝对值旧行为（零迁移）；进化预览传 era 同口径。
- **时代带硬门**：条目 `era_band = [min,max]`（116 条谱系改造已标带；训练/机制/通用件
  无带=全时代）。装配过滤走 `get_installable_mods_for_card`（面板/安装）；
  `get_mods_for_card` **不过滤**（enemy_card_mod_map/intel 跨时代依赖全集）。
  已装超带改造不回收。带显示用 `data/mod_era_bands.gd`。
- **★ v25.0 修复的存量 P1**：攻击类数值改造此前只落 `stats.attack_*`，实战伤害读
  `weapon_slots[].damage`——攻击改造实战空转整个 v6-24 时期。现经
  `unit_stats_table._sync_mod_attack_ratio_to_weapon_slots`（攻击三维比值同步）落地，
  回归锁在 `tests/unit/data/mod_value_channels_test.gd`。改 build_stats_from_card 的
  mods 时序前先看该函数注释。
- **★ v25.0 连带激活 + v25.1 对冲**：`_sync_kind_bonus_to_weapon_slots` 死代码修复让
  装甲碾压+20%对轻/防空封锁+25%对空**对敌我同时**生效（v8.5 设计回归）；v25.1 接通
  同样死着的巷战掩蔽 0.15（`resolve_hit` 的 `urban_reduction` 独立乘区，受 ARMOR/AIR
  攻击者时生效，双侧同构）——步兵 vs 装甲净克制 ≈ +2%。**玩家空军对防空特化 +25%
  无对冲**（掩蔽只覆盖步兵），留实测。
- 数值审计：`tools/balance_audit_mods_evo.py` 已含 float>1.0 误写检查 / era_band
  合法性 / set 值域（attack_armor_set 帽 800、其余 400）——**改改造数据后必跑**。
  改造总数锁 249（v26 起与 modification_modules_test/combo_tier_smoke 双锁一致；v27 改造2.0 批 202→249，旧值 190/202 均已过时）。

### v21 光环范围化 / 组合满档 / 搭档协同 / 产能打造（2026-08-31，详见 CHANGELOG）

- **光环范围化**：战术光环（医疗/侦查/雷达/堡垒）按带内槽距过滤（`data/aura_data.gd`
  `is_in_aura_range`，★5→+1/★9→+2 格）；指挥/载具维修恒全场。施加按范围、
  **撤销永远全量扫描**（范围过滤撤销会漏 buff）。部署槽位 meta 在 setup 之后才写——
  setup 期光环广播一律走帧末延迟（`broadcast_and_receive_deferred` /
  `receive_auras_from_field_deferred`）。回滚开关 `GameConfig.aura_range_enabled`。
- **组合满档**：`ComboTactics.detect_card_combo_tiers()`（basic/full），满档机制
  flag 由 combo_engine 每秒并入全队机制表；6 个行为改写传奇改造（gen_* v21 P1）
  effect key 走未知键→`_special` 通道；改造总数锁定断言 249（加改造要 bump
  `modification_modules_test.gd` 与 combo_tier_smoke 双处；旧值 190 已过时，v26.4 勘误）。
- **搭档协同**：`data/unit_roles.gd` 九角色归一化 + `pair_synergy_engine.gd`
  事件驱动激活（部署/死亡 + 1s 兜底，禁止每帧扫描），数值对称记账（meta 存原值）。
- **产能打造（存档 v9）**：~~DayClock 产能 → craft_mod 解锁 + 相位师首杀解锁~~
  **已随 v25.3 系统收敛整链退役（2026-08-31）**——解锁集无任何 UI/门禁消费方、
  craft_mod 零 UI 调用方、首杀奖励是幻影。存档段/迁移键/DayClock 产出全部移除，
  旧档 key 静默跳过。详见停用清单与 CHANGELOG v25.3。
- **敌方精英同源词条**：`enemy_loadout_tiers.gd` seeded roll（同关同波同槽可复现），
  挂载点在 `enemy_unit.setup` 末尾（battle_spawn_system 只读约束的等价点）。

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
- `default_cards.gd` — 统一表驱动构建（v8.0 起）：UCT 231 行（玩家侧 117 + 敌专属 114）+ 14 势力专属卡 = 启动构建 131 张卡对象；旧 ~110 张硬编码 _unit() 已废弃（WWI to near-future, 5 eras × 20 levels）
- `enemy_archetypes.gd` (+ era-split variants: `_ww.gd`, `_cold_modern.gd`, `_future.gd`) — Enemy types, drops
- `enemy_phase_masters*.gd` (5 era files + combined) — Phase master (boss) definitions
- `enemy_equipment_*.gd` — Enemy weapons, armor modules, specials
- `enemy_blueprints.gd`, `enemy_unit_manifest.gd`, `enemy_stat_context.gd`, `enemy_stat_resolver.gd`

**Law & Environment:**
- `phase_laws.gd` — Law definitions (4 families: STEEL/FLAME/THUNDER/VOID, passive + active)
- `battle_environments.gd` — Battlefield environment modifiers
- `phase_instruments.gd` — Phase instrument definitions (4-color slot configs)

**Economy & Progression:**
- `basic_resources.gd` — Resource ID definitions（纳米材料/合金/晶体/能量块 共 4 种；许可证 v7.3 删、科研点已随 P2-7 退役。中文名以本文件为唯一权威源——"晶体"勿写成"水晶"，v26.4 统一）
- `battle_card_v3.gd` — Era HP/damage multipliers (v6.1: 近未来伤害倍率 1.90→1.80)
- `level_eras.gd` / `level_information.gd` — Level-to-era mapping (100 levels, 5 eras)
- `rank_rules.gd`, `card_progression_settings.gd` — Progression tuning

**v6.0 Intel System:**
- `intel_dimensions.gd` — 4 intel dimensions (basic/tactical/material/secret)
- `intel_reveal_events.gd` — 28 reveal events（7 enemy types × 4 tiers；原 v6.0 的 112 条 7×4×4 已合并去维）
- `intel_evolution_branches.gd` — 4 hidden evolution branches
- `intel_manual_items.gd` — 蓝图道具目录（商店可售/掉落蓝图 id 清单；v26.10 起改造图纸为 IntelItemBag 库存消耗品。文件头注明确否定旧设计"6 种消耗品"）

**Evolution（已随 v26.8 退役，数据保留）：** 进化 UI 链/权威判定已退役（新卡获取唯一通道=制造）；下列谱系数据保留，供制造中心"来源"展示与 lineage 查询——
- `data/evolution_paths/` — 8 files: infantry/armor/air/artillery/fort/recon/engineer/anti_air evolution paths
- `unit_lineage_config.gd` — Unit lineage and evolution target mapping
- `evolution_paths_supplement.gd` — Supplementary evolution data

**Modification:**
- `data/modification_modules/` — 10 files: infantry/armor/artillery/anti_air/air/recon/engineer/fort/universal/enhancement mods（共 202 条；注册表 ModificationRegistry）
- `mod_effects.gd` — Mod effect definitions and slot cost formulas

**Military Titles:**
- `data/rank_rules.gd` — 13 级军衔唯一权威源（RANK_ORDER/RANK_DISPLAY_NAMES + get_rank_display_name；v6.11 起统一体系）
- ~~`data/military_titles/title_display_names.gd`~~ — 已删除（v26.4 核对：`data/military_titles/` 下仅剩 unified_rank_system.gd，且已瘦身为强化等级倍率表，13 级军衔真身在 rank_rules.gd）

**Faction:**
- `company_definitions.gd` — 7 faction definitions
- `faction_card_bonuses.gd`, `faction_exclusive_cards.gd`, `faction_skill_tree.gd`, `faction_war_events.gd`

**Quest/Achievement/Challenge:**
- `quest_definitions.gd`, `achievement_definitions*.gd` (4 files), `challenge_definitions.gd`, `task_definitions_extended.gd`, `daily_task_definitions.gd`

### Resource Types (`resources/`)

- `CardResource` — Unified card model (combat_unit/energy/law), evolution, affix slots, mods, per-target attack speeds (v5.0)
- `AffixResource` — Modular affix with rarity, level scaling, stat caps
- `UnitStats` / `UnitStatsTable` — Derived combat stats from CardResource with era scaling
- `GameConstants` — All enums: CardType, WeaponType, CombatKind(5), Era(5)。PlatformType(13) 与 WeaponTypeLegacy(12) 枚举壳**已删除**（全项目零枚举引用；12 值 legacy 语义经数据表 + `legacy_weapon_to_new_weapon_type` 映射层存活，v26.4 核对）
- `DropTables` — Weighted drop entries (13 drop types), tables, guarantee drops
- `DesignTokens` — UI theming constants (neon palette, typography, spacing, glow, accessibility)
- `GameConfig` — Tunable game config（仅存有真实消费点的项（v26.9 核对 6 个 + v28 新增 2 个 + v34 新增 1 个）：cross_row_direct_damage_mult / aura_range_enabled / env_effects_enabled / battle_layouts_enabled / debug_no_deploy_limits / debug_grant_all_blueprints（v26.11 实装：新档全蓝图发放的门控开关，默认 false；消费点 save_manager）/ color_grade_enabled + ground_dressing_enabled（v28 质感轮：调色后期层 + 战场地面 dressing，消费点 color_grade.gd / ground_dressing.gd）/ feature_gates_enabled（v34 渐进解锁门控总开关，消费点 level_progress_manager.is_feature_unlocked）；15 个零消费字段已删）

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

- 3 save slots: `user://save_slot_%d.json`（`user://save.json` 仅旧单档迁移源/slot 1 兜底兼容读，不再写入）
- Schema version 9, migration chain v1→v9 via `scripts/systems/save_migration.gd`（主链调度）+ `save_migration_v4/v5/v6/v7/v8/v9.gd`（v4 文件为 v3→v4 ID 映射辅助表；v9 迁移体 no-op，版本号保留不回退）
- Critical managers (12) load immediately; deferred managers (13) load in batches after scene ready
- Auto-save on battle end（结算面板链 + 战斗守卫置脏 0.2s 冲刷）+ window close（WM_CLOSE_REQUEST + about_to_quit 双保险）；backup 为 save_game 调用内 15s 节流（非周期定时器）
- v26.4 修复：`last_active_at` 此前只在迁移分支读取——v9 现行档（不触发迁移）恒读 0，离线挂机奖励失效；已移出分支
- **读侧两条不变式（v26.6 起，改任何 manager 的 load_state 前必读）**：①"先重置再覆盖"——`load_state({})` 必须复位到默认（SaveManager 对存档缺段会调它），禁止空字典早退；②字典 key 若为 int，load_state 必须重建 int key（JSON 往返全变 String）。回归锁 `tests/unit/save/test_save_load_invariants.gd`。另：战斗中回标题走 `end_battle(false)` 正常结算（main.gd _on_back_to_title），勿删该守卫

## ★ 统一化双宪法（改美术/文案前必读，2026-09-08 起）

任何生图 prompt、资产修改、面板/卡牌/改造/任务文案改动，动笔前先查：
- 视觉：`docs/统一化/STYLE_BIBLE.md`（色板/光线/笔触/构图/禁则/资产 prompt 锚模板/分档标准；判档前先跑第二章 rim 判定链）
- 语言：`docs/统一化/LANGUAGE_BIBLE.md`(权威词汇表/面板与卡牌映射/禁用词/语气规则；条目层明细在 `docs/统一化/term_mapping_draft.csv`)
- 铁律：只改显示层（display_name/description/面板标题/按钮文本），id/存档 key/效果键/信号名不动；与宪法冲突时以宪法为准，改宪法须用户批准

## 美术资源工作流（卡图自动生成）

**⚠️ 美术 PNG 全量备份铁律（发行机迁移/换机硬前提）**：`.gitignore` 全局忽略 `*.png`——美术资产**不入 git，删=永久丢失**。两大目录：`assets/card_icons/`（2026-09-07 核对：enemy 178 + player 178 全配对，缩略图四树全齐，共 991 png）与 `assets/ui/instruments/`（相位仪徽章）。
**备份唯一权威目录（2026-09-07 起）**：`F:\godot fair duet\_art_backup\`——所有美术备份 zip 集中于此，**勿再散落**到 F: 根/项目旁其它层级。现存清单（含专项）：`phase-war-art-backup-2026-08-26.zip`（全量 1005 文件，sha16 `cc59b8c8e5a4f77d`，接替已消失的 08-23 首份）、`phase-war-art-backup-2026-09-07.zip`（全量 1153 文件/201MB，sha16 `9bfd539a1da464e6`，含 v26.31 修复后状态）、bunker-v2/v3-2026-08-27（基地专项）、`phase_war_intro_art_v24.5_20260831.zip`（序章专项）、`phase-war-bunker-fixed-base-20260915.zip`（固定基地删除批专项：assets/bunker 全量+死簇脚本，216 文件/69.5MB/sha16 `ea86c51a28db88bb`）。新增/修改图后按日期惯例在权威目录重打包全量基线，并建议同步一份到网盘/异机。打包：两树 walk（png/svg/txt）→ zipfile ZIP_STORED → 权威目录。

**新增卡牌缺卡面图时**，用 AI API 自动生成，完整流程见 `docs/ART_PIPELINE_AI_ICON_GENERATION.md`。

**单位分帧动画生成/替换时**，完整管线（agnes-video keyframe 图生视频：参考图规范/并行限流/质检门/已知坑/部署规范/轮次台账）见 `docs/单位分帧动画生成管线.md`——2026-09-10 批次④重生成轮沉淀，半身/朝向翻面/接缝/脏帧等坑与对策全在表内，动笔前必读。**v32.2 起部署验收加两条**：帧数与 anim.json counts 一致、内容占比与卡图 bbox 一致（详见 v32.2 节；rolls 集双主体/帧数缺口/扁长比例艺术债在案）。

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

该文件是战场卡图视觉数据的唯一真身。**v6.14.8 内容感知重构（2026-09-16，用户拍板"推翻旧数据"）**——卡图大规模换血后旧手填 CSV 全部失真，缩放改为"几何归一 + 兵种档位"两层模型：

| 数据 | 字段 | 说明 |
|------|------|------|
| 脚部锚点 | `FOOT_FRAC` | 脚（最低非透明像素）距纹理底部比例；立绘 offset 据此对齐地面线 |
| 头部锚点 | `HEAD_FRAC` | 头（最高非透明像素）距纹理顶部比例；头顶 UI 据此锚定实体顶部 |
| 内容占比 | `CONTENT_BBOX` | 非透明内容宽/高占画布比例（扫描生成）——几何归一的基础 |
| 缩放语义 | `KIND_ERA_SCALE` | 兵种×时代档位表（CombatKind 0-4 → era 0-4）：装甲 1.10→1.55 / 步兵 0.72→0.82 / 支援 0.78→0.95 / 空中 1.05→1.35 / 堡垒 1.40→1.60——现实层级（FT-17 3.6m→MBT 9.8m→未来机甲 ~12m，相对步兵班正面 0.7×→2.4×）经游戏性压缩，总跨度 ~2.2× |
| 缩放微调 | `VISUAL_SCALE_OVERRIDE` | 个别卡偏离时代档默认时才加条目（id→乘数，乘在档位上；**默认空表**）；查询自动剥 `captured_`/`foe_` 前缀 |

**两层缩放管线**（最终内容屏宽 = 58.9px × 兵种×时代档位 × override）：
- 几何层 `card_grid_thumbnail_scale.compute_battlefield_uniform_width_scale`：按 `CONTENT_BBOX` 的**内容宽**归一（旧口径按画布宽，留白大的单位被放得过大——现役卡图内容占比 0.33~0.88 差 2.7 倍）
- 语义层 `get_visual_scale(card)` / `get_visual_scale_by_id(id)`：override → 兵种×时代档（era 取 `card.era` → manifest 行 `era_for` → id 前缀推断，fe_/xeno 归 4；兵种 by-id 经 `EnemyUnitManifest.combat_kind_for` 查，全段行内 archetype_config 直通）；旧 `PLAYER_PLATFORM_TO_SCALE_ARCHETYPE` platform 兜底链已随重构删除
- 精英/首领威压乘区在演出层（`card_grid_unit_visuals.apply_battle_unit_presentation`：boss ×1.6 / elite ×1.2，接替旧 CSV boss≈2.0 语义；必须在 UnitOutline.apply 前定格）

**配套**：
- 扫描器 `tools/generate_card_foot_anchors.py`：alpha 阈值 getbbox 扫 FOOT_FRAC/HEAD_FRAC/CONTENT_BBOX 三块（就地更新，保留手工内容；**新增/替换卡图后必须重跑**）
- `entity_top_y_for_sprite(spr)` / `get_content_w_frac(name)` / `file_name_of(tex)` 查询方法
- 目检探针 `tests/_tmp_visual_scale_probe.gd`（窗口渲染批量实拍 270 单位：绿框内容 bbox/红十字开火点/黑线脚线，出图 `.godot/agent_tools/scale_probe_*.png` + 逐单位报告；**调缩放/开火点先跑它再看图**）
- ⚠️ 帧动画 attach 的 scale 补偿是乘法（×base_w/frame_w），与本模型正交；但前提仍是"帧内容占比与卡图 bbox 一致"（v32.2 部署验收条款）

**开火点锚点（v6.14.8 修口径 + 2026-09-16 按现图核对轮）**：`data/player_muzzle_anchors.gd`（我方 131 条，源 `docs/敌我双方卡头脚和开火位置.json`，标注工具 `docs/enemy_fire_spawn（标注头脚加弹道起点）.html` 导出）+ `data/muzzle_anchors.gd`（敌方 160 条）。两表 `get_fire_offset` 的 Y 原点是**脚线**不是纹理底边：`px_y = -(1 - ff - fireY_pct/100) × 图高 × scale`——fireY_pct 从纹理顶部量，**漏 ff 项 = 枪口/出膛点浮空 ff×图高**（首版实现的存量 bug，已修）。敌方表无 ff 字段，经 `_foot_frac_for_unit`（图标基名反查 FOOT_FRAC，A/B 段平台敌走 platform 映射）。 2026-09-16 核对轮实绩：像素级审计（FLOAT=标注列处透明 / TIP_OFF=与前端枪口尖差>15%）由 112 降到 10（9 个 TIP_OFF 为堡垒/近战有意不取前端极值；1 个 fut_arm_mech_e 卡图本身朝右属美术例外）；新增 fe_ 14 + xeno 20 锚点；15 个共享平台图单位按"一图一锚"落 platform_* 键；我方 ff 改扫描 FOOT_FRAC 优先；表/JSON/标注工具三域已同步。工具链：tests/_tmp_fire_anchor_audit.gd（像素审计）→ tests/_tmp_fire_anchor_ruler.gd（标尺核对图）→ tools/_tmp_apply_fire_snap.py（吸附回写）；**手调工作台 docs/fire_scale_studio.html（单单位精修）+ 全览页 docs/fire_scale_gallery.html（270 单位全部铺出，图上拖红点=开火点/横拖本体=拉大小/滚轮微调/选中后 ↑↓ 改大小（Shift 微调），修改自动存浏览器 localStorage（刷新自动恢复，重置全部修改可清空），一处导出全部修改）**（浏览器直接打开，标注区拖拽开火点 + 战场实比预览大小/脚线/枪口/步兵基准 + 多单位同地面线对比（列表勾选，1-4x 缩放/按大小排序），override 手调，一键导出 .gd 修改行；数据源 docs/fire_scale_data.js 由 tests/_tmp_export_fire_scale_data.gd 从真表导出——**改表/换图后重跑导出器刷新**）；新增卡图或标注后重跑审计即可回归。

**消费方**（无需改，数据源统一指向本文件）：
- `scripts/card_grid_unit_visuals.gd`（战场单位呈现：缩放/脚部 offset/头顶 UI 锚定/威压乘区）
- `data/enemy_archetypes.gd` 的 `get_visual_scale_for_archetype`（转发到本文件，供 construct_unit/enemy_phase_field_driver 调用）
- `scripts/ui_asset_loader.gd`（battle_tex_for_path 按 vs≥1.6 回退全分辨率——档位系数上限 1.5，正常全走 256 缩略图）
- `scripts/battle/construct_unit_ai.gd`（`_get_direct_fire_spawn_pos`/`_play_muzzle_feedback` 消费开火锚点）

## Engine Version Notes

LLM training data covers Godot up to ~4.3. This project uses Godot 4.5.
Check `docs/engine-reference/godot/VERSION.md` before suggesting API calls.

- ⚠️ **Godot 4.5.1 的 `SceneTree` 没有 `about_to_quit` 信号**（2026-09-12 实测 `get_signal_list()` 共 12 项无此项；旧训练数据里的常用信号，4.5 已移除）。任何 `tree.connect("about_to_quit", ...)` / `has_signal("about_to_quit")` 守卫都**静默失效**——save_manager/debug_log_manager 的连接因此从未生效过（代码保留，未来引擎恢复即自动生效）。程序化退出（`get_tree().quit()`）的收尾存档由退出调用点显式调 `SaveManager.save_game_on_exit()`（title_screen 退出确认已接）；窗口 X 关闭走 `WM_CLOSE_REQUEST` 不受影响。新的退出清理需求一律用调用点显式方案，**别再挂 about_to_quit**；也不用 `_exit_tree` 替代（autoload 逆序析构，退树时后加载的 manager 可能已释放）。

## Collaboration Protocol

User-driven collaboration. Every task follows: **Question → Options → Decision → Draft → Approval**

- Ask before writing to any filepath
- Show drafts before requesting approval
- Multi-file changes need explicit approval for the full changeset
- No commits without user instruction

## 已知停用/移除系统清单（2026-09-03 更新）

改代码/排查 bug 前先对照本表，避免给停用系统"修 bug"或误以为功能缺失：

| 系统 | 状态 | 说明 |
|------|------|------|
| 进化系统（E1/E2 形态升级 + 低进化/完整进化 + 谱系进化链） | **已整体退役** | 2026-09-02 v26.8：由情报驱动的制造系统接管新卡获取（见 docs/design_manufacture_system.md）。进化 UI 链退役（evolution_panel 重写为制造中心，内部 API 护栏保留）；`blueprint_evol_` 进化图纸掉落改道；技能树节点语义平移（"形态进化"→"制造授权"）。谱系数据（data/evolution_paths/ 8 文件 + unit_lineage_config）保留，供制造"来源"展示；hp_floor/inherit_bonus 存档字段保留为惰性数值 |
| EvolutionPathRegistry（autoload + scripts/systems/evolution_path_registry.gd） | **已删除** | 2026-09-02 v26.6 结构收敛批B：零引用整文件下线，权威先迁 LINEAGES + BlueprintManager.get_evolution_options，后随 v26.8 进化退役。autoload 31→30。data/evolution_paths/*.gd 的 check_requirements 存根仍在（fail-closed，指向文案勿再引用） |
| 产能点 + 账号改造解锁集 + 相位师首杀解锁（v21 P3-B） | **已整体删除** | 2026-08-31 v25.3 系统收敛：解锁集（mod_unlock_state）自上线起无任何 UI/门禁消费方（安装认蓝图），craft_mod 零 UI 调用方，首杀"解锁"是玩家不可见的幻影奖励。删除：ModificationRegistry 解锁集段（craft_mod/unlock_mod/unlock_boss_first_kill/CRAFT 表）、BRM production_points、DayClock 产能结算、GameManager 首杀发放、SaveManager 三处清单、SK_MOD_UNLOCK_STATE；v9 迁移体改 no-op（版本号保留）。旧档 mod_unlock_state/production_points key 静默跳过。将来重做"打造"从 git 找回 |
| 进化战力门 + 进化情报基础门 | **已拆除** | 2026-08-31 v25.3：card_evolution_manager 权威判定 7 条件 → 4（保留等级/改造数/进化图纸/技能树时代 + 势力分支门）。战力门是"战力→军衔→战力"循环的根；情报门（low_evo 50%/100%）与低进化对蓝图豁免构成双轴资格。拒绝码映射保留（防御）。连带删 evolution_path_registry 遗留四门死代码 + card_resource 休眠 intel_requirements 门 |
| 战斗抽屉 8 面板入口（势力/任务/商店/排行/情报/图鉴/成就/帮助） | **已收敛** | 2026-08-31 v25.3：BottomFunctionBar 14→6（留背包/成长/地图/设置/存档/挂机），战前字母热键同步裁（留 B/1、7、9、M）。overlay 与 handler 全保留（教程 toggle_* 链/growth 转发仍用），面板本体移基地入口（EMBEDDED_PANELS 同款） |
| 强化①（手动强化轴 enhance_level 0-10） | **已退役** | 2026-08-24 v20.12 等级统一：`card_level`（战斗卡等级 1-30，上阵攒经验自动升）成为唯一玩家卡等级轴。`reinforcement_panel.gd/.tscn` 删除、`BlueprintManager.apply_reinforcement` 删除、card_info_panel 强化 Tab 恒隐藏（TabIdx/节点保留防索引错位）。进化等级门槛改读 card_level（E1=5/E2=10）；进化执行=变成全新卡（等级/经验/改造/词条槽全部重置，仅 inherit_bonus/hp_floor/情报奖励保留）；光环/能力星级 = card_level÷3 映射 1-10；掉落卡星级改发起始经验；教学任务"强化尝试"改升级驱动（`_on_card_level_up` 转发 `enhancement_completed` 信号）。敌方配装档位（enemy_loadout_tiers 的 enhance_level 四档 3/6/8/10；旧记载"3/6/10"漏精英档 8，v26.4 勘误）与攻击公式的 enhance 乘区**不受影响**（内部敌方轴）；旧档存量 enhance_level 保留为惰性数值，无提升入口 |
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
| UILazyLoader 死配置 5 项 | 已清理 | 2026-08-22：occupation/leaderboard/intelligence（面板静态实例化且不在 prune 释放名单）/phase_master_skill（parent 节点不存在）/reinforcement（活于 card_info_panel 嵌入实例化）。**⚠️ 教训：quest/store/faction/settings 曾被同批误删当晚会回滚**——main.`_prune_preloaded_panels` 启动时会释放这四个面板的静态实例"转按需加载"，UILazyLoader 配置是其唯一重建路径，删=面板永远空壳（商店打不开事故）。真懒加载全集：backpack/growth/quest/store/faction/settings/achievement/help/modification/evolution/collection（11 项；旧记载"10 项"为误计，v26.4 勘误） |
| LevelSelectOverlay 空壳 | 已删除 | 2026-08-22：main.tscn 空节点，level_select 配置 v9.x 已先删（选关由 world_map 承担） |
| 相位仪商店（势力商店卖相位仪） | **残骸整链删除** | 2026-09-13 v31（R6 死数据清点）：v8.x 起相位仪改技能树/掉落获取，商店区恒空。删除 fsm 五函数（get_faction_phase_instruments 恒返空/can_buy/buy/grant/unlock）+ unlocked_faction_instruments 存档键（旧档 key 静默跳过）+ store_panel 渲染分支/行构建/购买 handler + store_instrument_row.tscn。活链在 PhaseInstrumentManager 直连（掉落/技能树），勿在 fsm 侧"复活" |
| 情报舱「单位谱系图谱」Tab | **已删除** | 2026-09-13 v31（F-16）：与制造中心"来源"展示重叠。EvolutionTab/EvolutionHost 节点 + _setup_evolution_tab/三 handler + open_progression_requested 信号及 main 接线全移；孤儿视图类 evolution_atlas_view.gd / unit_progression_detail_view.gd 删除。情报舱现为 3 Tab（世界观/符文图鉴/敌方情报）；lineage 数据本体保留（制造中心消费） |
| 法则家族关卡数据（available_law_families） | **已删除** | 2026-09-13 v31：P2-7 法则退役后全链死数据（level_information 自注"仅为兼容保留"）。五时代 builder 的 families 块 + 数据键 + 三个查询函数删除；**faction_id 是活数据**（世界地图驻守加成/势力榜消费），勿连带误删 |
| 旧固定基地（余烬要塞 bunker_main 整簇） | **已删除** | 2026-09-15 v32.5b：场景/子 UI（hud/room_panel/pickers/day_summary/observatory_ending 等 10 脚本）+ assets/bunker 70MB 美术全删（备份 `_art_backup/phase-war-bunker-fixed-base-20260915.zip`）。房间表重构归属 `data/mobile_base_facilities.gd`（车载设施语义，存档 rooms 字段不变，BunkerManager 零逻辑改动）；引擎价目真身在 truck_travel.gd。**勿再引用 bunker_main/BunkerRoomDefs** |
| docs/tech-debt-register.md | 已删除 | 2026-04-09 停更全过时；活债务改记本清单 + CHANGELOG |

### 已知断链资产（不修只记录，2026-09-10 核对）

- `data/combo_tactics.gd`：combo_icons/ 下 chem/emp/incendiary/laser/nano/recon 6 张 PNG 缺失
- `scripts/ui_asset_loader.gd`：`assets/card_icons/law.png` 缺失
- ~~`data/phase_instruments.gd`：pi_r_free_deploy、pi_umbra_01~03 图标缺失~~ — 已补齐（2026-09-10 实测四图全部在）
- ~~enemy/ 目录混入 vis_player_001/075.png（2026-09-09 b4 部署残留，= vis_enemy 同编号原图的镜像，无独有内容）~~ — 已确认无引用后删除（2026-09-11 清理轮）

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

**遗留问题现状（2026-09-15 v35 全量复核更新）**：

- **已修复（v26.x 轮）**：P2 曲射烟迹（batch `trail_acc` 0.09s 沉积 `spawn_projectile_trail_puff`，debris 池）；P2 目标中途死亡（曲射 batch/bullet 兜底照常落地爆炸、直射 batch 补小火花）；曲射 `raw_tgt == null: pass` 空块。
- **已修复（v35 轮）**：P3 蜂群路由裸值（`_fire_from_slot` 先按 combat_kind 归一 canon 新枚举再分流，曲射前置路由进 enemy_indirect_batch）；P3 `_WEAPON_CONFIG` speed/max_dist 死列（整列删除，只留 explosion_radius）；P3 `proj_quad_size` 死档与错误尺寸（收缩到活档 1/2/3/7/9）；P3 `_impact_spawned`（batch dict 键+bullet 成员全删）、bullet `_beam_visual_phase`/`FLAME_STAR_TEX`。
- **维持现状（有意不做）**：MISS 文字提示——目标死亡落地已有爆炸演出，补 MISS 文字是演出设计决策非缺口；溅射两路径差异——batch 上限 4（`MAX_AOE_TARGETS_PER_HIT`，可被 aoe_cap 放宽）是性能护栏+溅射比例已统一读 `splash_damage`（clamp 0.80/回退 0.5），bullet 无上限是兜底路径低频语义，强行拉平属平衡面改动。
- **遗留观察**：`bullet.gd _process_indirect` 落地后无烟迹层（batch 主路径有）；曲射 batch 池化烟迹是轻量档（2 粒/puff），要更浓弧线需加池化粒子层（独立 VFX 轮）。

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

检查范围：`tutorial_progression_manager.gd`（13 步 A 系统；**v26.33 起 14 步**——首战后新增「移动基地」步、改造步改图纸口径、世界地图步改行军语义，save version 4，见 CHANGELOG v26.33）、`tutorial_overlay.gd`、main.gd 教程 handler、`quest_definitions.gd` 教学任务（C 系统）。内容健康项：初始三卡（ww1_mauser/ww1_arty_m81/ww1_arm_ft17，v21.6 预装）、词条里程碑 Lv5/10/15/20/25/30（card_growth_config 每 5 级）、符文入口 `_open_backpack_runes_tab`、9 个 toggle 信号 handler、存档 v1→v2 门控全部核验无误。

**v20.31 已修复**（改动：`scenes/main.gd` / `data/quest_definitions.gd` / `managers/card_enhancement_manager.gd`）：

1. **P1 教程第 7 步"开始首战"按钮无效**：`SignalBus.start_level` 自创建以来零消费方——点击后无任何反应，教程跳到第 8 步而首战从未开始（新手关键路径断裂，战斗结束续播 8-13 步的设计也永不触发）。修复：main.gd 连接 `start_level` → `_on_start_level_from_tutorial`（设 `GameManager.set_current_level(level)` + `_battle_setup.on_start_battle()`，与"开始战斗"按钮同链路）。
2. **P2 `q_tutorial_law`"法则初探"不可完成**：objective_type=research_law 的唯一进度入口 `notify_law_researched()` 随法则系统 P2-7 退役后零调用方，任务接取后永不可完成。已删除定义；旧存档 accepted 残留 id 由 QuestManager 的 def.is_empty() 守卫安全跳过。
3. **P3 过时文案**：`q_collect_fragments_50`（"蓝图碎片"→拥有卡种数，title 改"收藏大家"）、`q_frag_smg`（"解锁卡牌蓝图"→收集战斗卡）——objective 早已适配、描述未同步；`card_enhancement_manager.gd` 头注从已退役的强化① v6.0 设计校正为 v20.12 现状（僵尸文件说明 + 勿新增功能警示）。

**验证**：`tests/_tmp_batch6_audio_tutorial_check.gd` ALL PASS（13 步数据/禁用词/存档门控/action 分支）；smoke 119/119；q_tutorial_law 零残留引用。

### 平衡性审查 + spetsnaz 补强（2026-08-30，v20.32）

全量数值审查（脚本 `tools/balance_audit_cards.py` / `balance_audit_mods_evo.py`，扫 223 卡条目 + 10 MOD 文件 + 8 进化文件；明细 `docs/_balance_dump_cards.json`）：时代/tier 递进、装甲-步兵 HP 关系、MOD 上限（attack_interval -0.40 恰在 v6.1 帽）、level_effects 单调、进化增长、敌我成长对称（双方共用 CardGrowthConfig 曲线，敌方配装档位为难度旋钮。⚠️ v26.4 勘误：本节旧记"3/6/10 档乘区 1.14/1.28/1.63"经不起复核——enhance 乘区按兵种各异（unit_stats_table.apply_enhance_level_bonus）且 battle_card_v3.enhance_stat_multiplier(6)=1.35，该组数值勿再引用；v26 起档位为四档 3/6/8/10）——**全部 PASS，无硬伤**。已知非问题：fut_colossus/fut_arm_omega 同数值为弹道分流有意设计；DPS 离散警告均为对空/反坦克/守护者职能特化；battle_card_v3 的 era/star 倍率为死代码（唯一存活 enhance_stat_multiplier 供敌方配装轴）。

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

### 战利品归仓：基地房间收取气泡（2026-08-30，v23.6）

**借鉴辐射避难所的收集循环**（房间产出→头顶气泡→点击收取），把挂机收益从"逐场静默入账钱包"改成可见的收集时刻；同期补上 `pending_drops` 有存档却无事后领取 UI 的历史空缺。**改挂机/掉落/基地相关代码前先读 CHANGELOG v23.6 全条**。要点：

1. **归仓池在 DropManager**（`_escrow`，按 type+item_id 聚合有界）：挂机每场战后 `deposit_pending_to_escrow()`（game_manager AFK 分支，原 claim_drops）；残留 pending（玩家没点结算"继续"）也送归仓（原静默自动入账）。收取 = `collect_escrow(categories)`，走 claim 同管线（符文/剧情乘区、掉落卡实例化口径不变，仅时点后移）。存档 key `escrow_drops`（旧档无 key=空池，免迁移）。**手动战斗 MvpPanel 与离线奖励链路不动**。池容量靠精神值天然封顶（胜 -10/场，归零停机）。
2. **气泡类别→房间映射在 bunker_main**（`ESCROW_ROOM_MAP`：物资→仓库/战利品→荣誉室/情报→档案室/强化→相位实验室/图纸→工坊；未修复回退仓库→入口大厅）。气泡组件 `scenes/bunker/bunker_reward_bubble.gd` 骑房间底边、点击收取该房全部类别；HUD"收取全部"；挂机结算弹窗"全部入账"逃生阀。
3. **验证件**：`tests/unit/economy/test_drop_escrow.gd`（10 用例）+ 端到端 `tests/_tmp_escrow_bubble_check.gd`（归仓→新档 2 泡回退正确→按类收取→全收清空）。全量 GdUnit 155/155。
4. **下一阶段候选**（设计已定未实施）：卡牌指派驻房（闲置卡提升挂机产出）、气象站地表事件（P3 坑位）、DayClock 时段基地氛围、离线奖励并入气泡。

### 大招自动/手动双轨释放（2026-08-31，v24.1）

相位仪栏上方新增大招按钮带（`scenes/ui/ultimate_cast_bar.gd`，挂在 main.tscn BattleBottomBar 内）：
默认自动（挂机零损失，按钮把隐形自动大招系统变成可见的）；手动模式大招攥住不放、亮起点击即发，纯时机收益零数值改动。
手动白名单（常量表在 `scripts/battle/ultimate_cast_controller.gd`）：相位仪仅核子轰炸(30s 充能上限2)；
兵种机制仅战术核武(45s)/护盾投射(20s)/电子屏蔽(18s)，armed 单位 FIFO 释放（meta `mech_armed_<id>` + `try_manual_fire_<id>` 协议）。
仅当次战斗生效（battle_manager 开始/结束调 `UltimateCastController.reset()`），挂机强制自动，敌方侧不动。
改大招/兵种机制代码前先读 CHANGELOG v24.1 全条。

**⚠️ Godot 4.5.1 静态函数命名坑（存量生产 bug 已修，勿踩）**：静态函数与 **`reset_state`** 同名时，编译期绑定的静态调用会**整体静默失效**（函数体一行不执行、无报错；动态 `.call("reset_state")` 正常；任意 RefCounted 子类即可最小复现）。
`PhaseInstrumentAbilities.reset_state` 因此被 battle_manager 静默空调了整个 4.5 时期（战间清理由此失效）——已改名 **`reset_battle_state`**（battle_manager 两处调用点 + 敌方能力 smoke 同步）。
**新增静态函数避开该名**；排查"静态调用没生效"类怪病时先想到这条。

### 收敛评估结论（2026-09-02 v26.6 结构收敛轮）：敌我 projectile batch 不合并

三套投射批（`simple_player/enemy_projectile_batch.gd` 各 355 行、`simple_indirect_projectile_batch.gd`）**评估后决定不收敛**：
归一化后真实分化仅 ~138 行/侧（tint 阵营色、蜂群冲撞行为、空中瞄准点），且都在每帧热路径、
GdUnit 对 batch 内部行为覆盖薄——合并的回归风险 > 重复代码维护成本。后续若动这两文件，
顺手对齐差异行即可，不做结构重构。

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

## v6.17 命中光学层批次：泛光 + 动态光闪 + 暗底高对比（2026-09-19）

**改战场渲染/泛光/动态光/背景明暗/曳光宽度前必读本节与 `docs/命中表现夸张规则.md` 横切规则（光学层条目）。** 参照系《轮回保险公司 R.I.P.》（Steam 3985950）13 张官方截图拆解：其开火/弹道/命中的"高级感"来自 HDR 发光体+全屏泛光+动态光照+暗底高对比四件光学外衣，命中词汇与本项目 D3 表同构——差距在渲染层不在设计层。本批全是既有词汇的亮度放大器，零新增命中词汇；死亡演出经用户裁决不做。

- **战场泛光唯一挂点 `scripts/battle/battle_optics.gd`（BattleOptics）**：`ensure_glow` 幂等建 WorldEnvironment（battlefield._ready 调，env 名 `BattleOpticsEnv`）。⚠️ **只开第 3 级 glow 模糊**（`set_glow_level` 循环）——默认 3/5 两级在本机（GT 620M/HD4000 级）≈4x 帧率损失（280 帧战斗时钟 00:27 vs 关 00:07），1 级实测 00:08 ≈ 零回归；弱机是 gl_compatibility 目标群体，勿加回多级。发光体=modulate rgb>1（`viewport/hdr_2d=true` 已入 project.godot，本身零成本）。
- **动态光闪池（同文件 `flash()`）**：PointLight2D 上限 10、无投影、range_layer 0-0（不脉冲 HUD）、active/pool 双数组自愈记账（父层随清场释放靠 `_heal_arrays` 滤失效引用）。三挂钩全在 vfx_impact_factory：枪口（spawn_muzzle_flash，轻=小暖闪 64px/能量=冷闪/重化学=大暖闪 92px）、爆炸族+HEAVY（spawn_layered_impact，130px）、大招白闪核同拍（spawn_spell_burst is_ult_scale，210px）。闪寿命 ≤0.5s，FF 极速推演短路。
- **HDR 提亮点**：曳光共享表 `weapon_projectile_vfx.tracer_color_for` rgb×1.5 + `tracer_width_for` 全档 ×1.3（**v38.6 回归锁已锁此值**）+ bullet.gd 白热芯（1.6,1.55,1.4）/坦克炮曳光 5.4×口径·0.065s + `_spawn_impact_poof`（1.45,1.42,1.30）。alpha 口径全不动（42% 点射回声不破）。
- **暗底高对比**：BG_DIM 0.80→0.72 + 新常量 BG_SAT_KEEP 0.82（tint 降饱和）——唯一出口 `battlefield.era_bg_modulate(era)`（出征战报 sortie_interstitial 同源消费）。调背景观感只动 BG_DIM/BG_SAT_KEEP 两常量。
- **焦痕密度**：爆炸族概率 0.5→0.65 / 半径 8-18→10-20 / peak_a 0.42→0.50（MAX_TRACES=48 环缓冲不变）。**伤害数字防叠**：抖动 ±15/±10→±26/-16~+6（damage_number_display）。
- **总开关**：GameConfig.vfx_glow_enabled / vfx_dynamic_lights_enabled + 环境变量 PW_GLOW_OFF=1 / PW_LIGHTS_OFF=1（ColorGrade 先例）。开关关着不建 env/光池，打开后下一场进战斗生效。
- **验证**：`tests/_tmp_v617_smoke.gd`（V617_SMOKE_OK）+ weapon_visual_profiles_smoke 138 PASS + L10 实拍前后对比 `.godot/agent_tools/v617_before_after.png`。⚠️ `--script` 的 `_initialize` 阶段节点不在树内，reparent 类断言不可测（v38 冒烟纪律姊妹坑）；子块编辑缩进错层第三次踩（`var sc` 掉进 if 块）——gdparse+git diff 可抓。

## v6.17.1 精灵帧体检 + 姿态帧/异体帧/白底重生成（2026-09-19）

**改 AttackPoseAnim 姿态帧、boss 散帧、相位仪徽章前必读本节。** 用户复查"多人现象+白底未抠完"全量体检后裁决重生成。CHANGELOG v6.17.1 有全量细节与五连环踩坑。

- **16 个姿态目录曾是审计盲区**（无 anim.json → 审计跳过）：AttackPoseAnim 姿态帧（attack_f0.png）在 `unit_anims/<uid>/` 下与待机集**同层不同体**——uid 是敌方 archetype_id（如 ww1_inf_rifle），兄弟待机集是削前缀名（ww1_rifle）。审计工具已补姿态分支；新增姿态帧必须过"单主体+白残留+内容占比"审计。
- **姿态帧内容纪律**：单兵构图、与兄弟待机集同制服同配色（风味文本"本班原型…"是设定文案，视觉仍单兵）、512 画布内容高对齐旧帧（立绘 448/跪姿 328/机枪巢 322/卧姿 198）、底部居中锚位。现役 16 张全部为 v6.17.1 重生成（agnes-2.1-flash，原图备份 `.godot/art_backup_pose_20260919/`）。
- **fut_boss_nexus 散帧 = f0 黑塔程序化脉冲**（能量掩膜+高斯发光+径向衰减，非 AI 逐帧生成）；官方形象=重型等离子加农炮平台（flavor 文本），翼人帧是历史外来图（备份同目录）。
- **pi_special_nova 已换深底板**（对齐 aegis 家族）；相位仪徽章底板必须深色径向渐变，白底徽章在任何深色 HUD 上都是"白贴纸"。
- **设计脉动帧勿当缺陷清**：ww1_sup_vickers f4-5 金色发热、vis_xeno_dark_templar f4-5 变白闪烁、ww2_fort_bunker f3/f7 灯组变化——逐帧亮度指纹为平滑周期，保留。
- **体检工具**：`tools/_tmp_visual_audit.py`（白底三指标+散帧+姿态分支）与 `tools/_tmp_frame_strips.py`（全帧条带目视）可复用；生图 QC 五连环踩坑见 CHANGELOG v6.17.1（抠图后审计/128 网格坐标/低姿态下限/任一维顶满判定/亮度饱和键控+边缘连通）。
