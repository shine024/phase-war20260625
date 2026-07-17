# 清理计划 v7 — 删除死代码 + 剧情系统

> 创建日期：2026-07-17
> 范围：删除 P0 死代码 + 完整剧情对话/任务系统
> 保留：音效、成就、开始动画(title_screen)、通关动画(Battlefield final_battle)
> 用户决策："教程现在游戏已经实现一个简单的了，原有的准备删除；剧情只准备以后加一个游戏开始动画、一个通关动画，其他的剧情准备不要了"

---

## 第一阶段：P0 纯死代码（整文件删除，零风险）

### 步骤 1.1：删除 B 系统教程管理器

| 文件 | 操作 | 行数 |
|------|------|------|
| `managers/tutorial_manager.gd` | **整文件删除** | 144 行 |
| `managers/tutorial_manager.gd.uid` | 删除 | - |

**证据**：文件自承 `v7.x(A5) 已弃用：本管理器从未被 autoload，且 game_launcher 引用的 tutorial id（'basic_gameplay'）在 TutorialDefs 中不存在`。实际生效的是 A 系统 `TutorialProgressionManager`（autoload）。全项目无 import 引用它。

### 步骤 1.2：删除启动器死代码

| 文件 | 操作 | 行数 |
|------|------|------|
| `scenes/game_launcher.gd` | **整文件删除** | 419 行 |
| `scenes/game_launcher.gd.uid` | 删除 | - |

**证据**：全项目无任何 `.tscn` 挂载它，无任何 GDScript preload/load 它。它是 `achievement_panel`/`help_panel` 的唯一入口（也是死入口）。连带问题：L98-107 `_load_assets()` 的 resource_queue 是空 stub；引用的 `ui_theme.tres`/`interface_sound.tres`/`player_model.tscn` 三个文件磁盘不存在。

### 步骤 1.3：删除未挂载的扩展功能栏

| 文件 | 操作 | 行数 |
|------|------|------|
| `scenes/ui/new_functions_bar_addon.gd` | **整文件删除** | 120 行 |
| `scenes/ui/new_functions_bar_addon.gd.uid` | 删除 | - |

**证据**：全项目无 `instance=ExtResource` 或 `add_child` 引用它。其内部 6 个按钮（日常/挑战/图鉴/成就/敌源改造/合成）全部失效。

### 步骤 1.4：删除旧版教程场景

| 文件 | 操作 | 行数 |
|------|------|------|
| `scenes/ui/interactive_tutorial.tscn` | **整文件删除** | 94 行 |
| `scenes/ui/interactive_tutorial.tscn.uid` | 删除 | - |
| `scenes/ui/interactive_tutorial.gd` | **整文件删除** | ~200 行 |
| `scenes/ui/interactive_tutorial.gd.uid` | 删除 | - |

**证据**：`tutorial_overlay.gd:6` 注释明确"历史版本（B 系统）已弃用"。无入口。

### 步骤 1.5：删除备份文件

| 文件 | 操作 |
|------|------|
| `scenes/ui/card_enhancement_panel.tscn.original` | **整文件删除**（8861 字节） |

---

## 第二阶段：删除剧情对话面板系统

### 步骤 2.1：删除对话面板脚本和场景

| 文件 | 操作 | 行数 |
|------|------|------|
| `scenes/ui/story_dialogue_panel.gd` | **整文件删除** | 882 行 |
| `scenes/ui/story_dialogue_panel.gd.uid` | 删除 | - |
| `scenes/ui/story_dialogue_panel.tscn` | **整文件删除** | 12 行 |
| `scenes/ui/story_dialogue_panel.tscn.uid` | 删除 | - |

**依赖**：该文件 preload 了 `speaker_registry.gd` 和 `portrait_circle_mask.gdshader`，删除后这两个也成孤儿。

### 步骤 2.2：删除 speaker_registry

| 文件 | 操作 | 行数 |
|------|------|------|
| `data/speaker_registry.gd` | **整文件删除** | 177 行 |
| `data/speaker_registry.gd.uid` | 删除 | - |

**证据**：唯一引用者是 `story_dialogue_panel.gd:29`（已删）。

### 步骤 2.3：删除立绘资源目录

| 文件/目录 | 操作 |
|------|------|
| `ui/portraits/` | **整目录删除**（~26 张 png + .import + README.md） |

**证据**：所有立绘仅被 `speaker_registry.gd` 和 `story_dialogue_panel.gd` 引用（均已删）。

### 步骤 2.4：删除 shader

| 文件 | 操作 |
|------|------|
| `shaders/portrait_circle_mask.gdshader` | 删除 |
| `shaders/portrait_circle_mask.gdshader.import` | 删除 |

**证据**：唯一引用 `story_dialogue_panel.gd:31`（已删）。

### 步骤 2.5：清理 main.tscn 中的 StoryOverlay 节点

| 文件 | 行号 | 操作 |
|------|------|------|
| `scenes/main.tscn` | L25 | 删除 ext_resource 注册 `[ext_resource type="PackedScene" path="res://scenes/ui/story_dialogue_panel.tscn" id="36_story_dialogue"]` |
| `scenes/main.tscn` | L695-725 | 删除整个 StoryOverlay 节点树（Backdrop → CenterContainer → StoryDialoguePanel） |

### 步骤 2.6：清理 main.gd 中的引用

| 文件 | 行号 | 操作 |
|------|------|------|
| `scenes/main.gd` | L74 | 删除 `@onready var story_overlay: Control = $PopupLayer/StoryOverlay` |
| `scenes/main.gd` | L522 | 删除 `"story_dialogue": return story_overlay,` 这一 case |

### 步骤 2.7：清理 ui_lazy_loader 中的注册

| 文件 | 行号 | 操作 |
|------|------|------|
| `managers/ui_lazy_loader.gd` | L63-68 | 删除 `"story_dialogue": { scene: "...", ... }` 整个字典条目 |

---

## 第三阶段：删除 SignalBus 剧情信号

| 文件 | 行号 | 操作 |
|------|------|------|
| `scripts/signal_bus.gd` | L147-151 | 删除注释块 `# v6.7(剧情任务)` + `signal story_mission_dialogue(quest_id: String, phase: String)` |

---

## 第四阶段：删除剧情任务数据

### 步骤 4.1：清理 quest_definitions.gd

| 文件 | 行号 | 操作 |
|------|------|------|
| `data/quest_definitions.gd` | 顶部 | 删除 `STORY_DISABLED` 常量（如有） |
| `data/quest_definitions.gd` | 顶部 | 删除 `TUTORIAL_DISABLED` 常量（如有） |
| `data/quest_definitions.gd` | LEGACY_QUESTS 数组内 | 删除所有 category="story" 的任务 dict（约 17 个） |
| `data/quest_definitions.gd` | LEGACY_QUESTS 数组内 | 删除所有 category="tutorial" 的任务 dict（5 个） |
| `data/quest_definitions.gd` | 方法区 | 删除 `get_quests_by_trigger_level()` |
| `data/quest_definitions.gd` | 方法区 | 删除 `get_all_triggerable_at_level()` |
| `data/quest_definitions.gd` | 方法区 | 删除 `get_ids_by_category()` |
| `data/quest_definitions.gd` | 字段说明注释 | 清理 v6.7 剧情任务字段注释 |

**注意**：以下**保留不动**：
- 普通 commission 任务（无 category 或 category="commission"）
- `q_tutorial_win_1` / `q_tutorial_enhance` 等（这些没有 category 字段，是普通委托任务，非教程对话）
- `get_by_id()` / `get_available_ids()` / `get_all()` / `register_dynamic_quest()`（通用委托任务依赖）

### 步骤 4.2：清理 quest_definitions.json

| 文件 | 操作 |
|------|------|
| `data/json/quest_definitions.json` | 删除 22 个 story/tutorial 任务条目，与 quest_definitions.gd 一一对应 |

**待删除的 quest_id 清单：**
```
# NPC 支线（5 个）
q_realist_invite, q_realist_join, q_realist_reject, q_realist_delay
q_linwei_secret, q_zack_beyond_48

# 主线剧情（11 个）
q_story_first_guardian, q_story_truth_60, q_story_zack_48
q_story_locke_83, q_story_mirror_99, q_story_final_100
q_story_realist_10, q_story_city_15, q_story_steel_marshal_40
q_story_void_lord_80, q_story_countdown_90

# 引导教程（5 个）
q_tutorial_equip_1, q_tutorial_enhance_5, q_tutorial_modify_10
q_tutorial_evolve_15, q_tutorial_rune_21
```

---

## 第五阶段：清理 QuestManager 剧情专用方法

| 文件 | 行号 | 操作 |
|------|------|------|
| `managers/quest_manager.gd` | `_revealed_quest_ids` 字段 | 谨慎：如果 `is_quest_available` 仍需要，保留字段但清空逻辑 |
| `managers/quest_manager.gd` | `is_quest_available` 中 `if def.get("category")=="story"...` 块 | 删除（仅影响 story 自动 reveal） |
| `managers/quest_manager.gd` | `reveal_quest()` 方法 | 删除（仅 story 流程调用） |
| `managers/quest_manager.gd` | `is_quest_revealed()` 方法 | 删除 |
| `managers/quest_manager.gd` | `set_quest_branch()` 方法 | 删除（仅 story_dialogue_panel 监听 story_choice_made 触发） |
| `managers/quest_manager.gd` | `get_quest_branch()` 方法 | 删除 |
| `managers/quest_manager.gd` | `save_state` 中 `"revealed_quest_ids"` 键 | 删除此行 |
| `managers/quest_manager.gd` | `load_state` 中恢复 `_revealed_quest_ids` 块 | 删除 |
| `managers/quest_manager.gd` | `get_quests_by_category()` 方法 | 删除 |
| `managers/quest_manager.gd` | `trigger_level_for_quest()` 方法 | 删除 |
| `managers/quest_manager.gd` | `get_active_story_quest_at_level()` 方法 | 删除 |

**注意**：以下**保留不动**：
- `accept_quest()` / `abandon_quest()` / `is_quest_done()` / `is_accepted()`（通用委托任务）
- `is_mission_quest()` / `is_mission_quest_done()` / `get_quest_progress_for_mission()` / `get_quest_target_faction()`（势力进攻/防守任务，与剧情无关）

---

## 第六阶段：清理 GameManager 剧情钩子

### 步骤 6.1：删除剧情队列字段

| 文件 | 行号 | 操作 |
|------|------|------|
| `managers/game_manager.gd` | 字段区 | 删除 `_story_mission_queue` |
| `managers/game_manager.gd` | 字段区 | 删除 `_story_mission_played` |
| `managers/game_manager.gd` | 字段区 | 删除顶部 v6.7 剧情任务队列说明注释 |

### 步骤 6.2：删除剧情钩子调用

| 文件 | 行号 | 操作 |
|------|------|------|
| `managers/game_manager.gd` | `go_to_battle()` | 删除 `_check_story_mission_pre_battle()` 调用 |
| `managers/game_manager.gd` | `on_battle_ended` 流程 | 删除 `_check_story_mission_post_battle()` 调用 |

### 步骤 6.3：删除剧情方法实现

| 文件 | 行号 | 操作 |
|------|------|------|
| `managers/game_manager.gd` | `_check_story_mission_pre_battle()` | 整段删除（~50 行） |
| `managers/game_manager.gd` | `_grant_tutorial_reward()` | 整段删除 |
| `managers/game_manager.gd` | `_check_story_mission_post_battle()` | 整段删除 |
| `managers/game_manager.gd` | `_is_tutorial_triggered()` | 整段删除 |
| `managers/game_manager.gd` | `_mark_tutorial_triggered()` | 整段删除 |
| `managers/game_manager.gd` | `_is_story_quest_active()` | 整段删除 |

### 步骤 6.4：删除必败战机制（force_defeat）

| 文件 | 行号 | 操作 |
|------|------|------|
| `managers/game_manager.gd` | 字段区 | 删除 `_is_force_defeat_battle` / `_force_defeat_duration` / `_force_defeat_reason` |
| `managers/game_manager.gd` | 方法区 | 删除 `start_force_defeat_battle()` / `start_prologue_force_defeat()` / `is_force_defeat_battle()` / `get_force_defeat_duration()` / `get_force_defeat_reason()` / `clear_force_defeat_state()` |
| `managers/game_manager.gd` | `_on_battle_ended` | 删除 force_defeat match 块（含 StoryFlags 写入） |
| `managers/game_manager.gd` | 顶部 | 删除 `const StoryFlags := preload(...)` |
| `managers/game_manager.gd` | 顶部注释 | 删除 v6.6 必败战注释 |

**注意**：以下**保留不动**（通关动画用）：
- `set_final_battle()` / `is_final_battle()` / `_is_final_battle()` / `clear_final_battle_state()` — 被 `Battlefield.gd:142, 269-274` 调用，属于用户要保留的②通关动画
- `_is_final_battle` 字段

---

## 第七阶段：清理 WorldMap 和 QuestPanel 剧情可视化

### 步骤 7.1：清理 world_map.gd

| 文件 | 行号 | 操作 |
|------|------|------|
| `scenes/world_map.gd` | QuestDefs preload | 删除（确认无其他 QuestDefs 调用后） |
| `scenes/world_map.gd` | `_make_level_button` | 删除 story ★ 前缀逻辑 |
| `scenes/world_map.gd` | tooltip 生成 | 删除"★ 剧情任务"逻辑 |
| `scenes/world_map.gd` | 按钮样式 | 删除紫色左边框逻辑 |

### 步骤 7.2：清理 quest_panel.gd

| 文件 | 行号 | 操作 |
|------|------|------|
| `scenes/ui/quest_panel.gd` | 顶部注释 | "委托/剧情/日常三标签" → "委托/日常两标签" |
| `scenes/ui/quest_panel.gd` | `@onready var story_list` | 删除 |
| `scenes/ui/quest_panel.gd` | `@onready var story_header` | 删除 |
| `scenes/ui/quest_panel.gd` | `_refresh_list` | 删除 story_list 子节点遍历、tutorial+story 跳过逻辑、story 分支、story_header 文本设置 |
| `scenes/ui/quest_panel.gd` | `_make_quest_row` | 删除 is_story 变量 + 紫色边框分支 + ★ 前缀 + 触发关卡 label |

### 步骤 7.3：清理 quest_panel.tscn

| 文件 | 行号 | 操作 |
|------|------|------|
| `scenes/ui/quest_panel.tscn` | StoryTab 节点树 | 整段删除 |
| `scenes/ui/quest_panel.tscn` | TabContainer._tab_index | DailyTab 从 2 改为 1 |

---

## 第八阶段：删除 StoryManager autoload + 清理注册

### 步骤 8.1：删除 StoryManager 文件

| 文件 | 操作 |
|------|------|
| `managers/story_manager.gd` | **整文件删除** |
| `managers/story_manager.gd.uid` | 删除 |

**证据**：StoryManager 仅服务剧情系统（tutorial 触发标记、story_flags、节点追踪），无其他系统共用。

### 步骤 8.2：清理 project.godot autoload

| 文件 | 行号 | 操作 |
|------|------|------|
| `project.godot` | [autoload] 段 | 删除 StoryManager 条目 |

### 步骤 8.3：清理 manager_lazy_loader

| 文件 | 行号 | 操作 |
|------|------|------|
| `managers/manager_lazy_loader.gd` | _MANAGER_CONFIGS | 删除 story 配置条目（node_name: "StoryManager"） |
| `managers/manager_lazy_loader.gd` | ensure_loaded 路由 | 删除 story key 的路由分支 |

### 步骤 8.4：清理 save_manager

| 文件 | 行号 | 操作 |
|------|------|------|
| `managers/save_manager.gd` | DEFERRED_MANAGER_LOADS | 删除 `["/root/StoryManager", "story_progress"]` |
| `managers/save_manager.gd` | RESETTABLE_MANAGERS | 删除 `"StoryManager"` |
| `managers/save_manager.gd` | SK_STORY_PROGRESS 常量 | 删除 |
| `managers/save_manager.gd` | `_collect_manager_state` | 删除 StoryManager 调用 |

### 步骤 8.5：清理 save_constants

| 文件 | 行号 | 操作 |
|------|------|------|
| `scripts/systems/save_constants.gd` | SK_STORY_PROGRESS | 删除 |

---

## 第九阶段：清理成就死代码

| 文件 | 行号 | 操作 |
|------|------|------|
| `data/achievements_special.gd` | phase_master 成就 | 删除 type="story_flag" 的成就条目（achievement_checker 不处理 story_flag，已是死代码） |

---

## 第十阶段：验证

### 步骤 10.1：Godot 语法检查

```powershell
& "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --check-only
```

### 步骤 10.2：Smoke Test

```powershell
& "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/star_config_smoke.gd"
```

### 步骤 10.3：Grep 残留检查

确保删除的符号全项目无残留引用：
```bash
grep -r "story_dialogue_panel" scripts/ managers/ scenes/ data/ resources/
grep -r "SpeakerRegistry" scripts/ managers/ scenes/ data/ resources/
grep -r "StoryManager" scripts/ managers/ scenes/ data/ resources/ project.godot
grep -r "_check_story_mission" scripts/ managers/ scenes/
grep -r "_is_tutorial_triggered\|_mark_tutorial_triggered\|_grant_tutorial_reward" scripts/ managers/
grep -r "get_quests_by_trigger_level\|get_all_triggerable_at_level\|get_ids_by_category" scripts/ managers/ scenes/
grep -r "set_quest_branch\|get_quest_branch\|reveal_quest\|is_quest_revealed" scripts/ managers/
grep -r "start_force_defeat\|_force_defeat\|StoryFlags" scripts/ managers/
grep -r "SK_STORY_PROGRESS" scripts/ managers/
```

---

## 保留清单（不可删除）

| 功能 | 关键文件 | 说明 |
|------|---------|------|
| **开始动画** | `scenes/title_screen.gd` L71 `_play_intro_animation()` | 独立于剧情系统 |
| **通关动画** | `scenes/battlefield/Battlefield.gd` L142, 269-274 | 依赖 `GameManager.is_final_battle()` |
| **音效** | `managers/audio_manager.gd` | 用户要求保留 |
| **成就** | `managers/achievement_manager.gd` + `data/achievements_*.gd` | 用户要求保留 |
| **A 系统教程** | `managers/tutorial_progression_manager.gd` + `scenes/ui/tutorial_overlay.gd` | 现有简单教程 |
| **通用委托任务** | `quest_definitions.gd` 中 category="commission" 任务 | 核心玩法 |
| **势力动态任务** | `faction_quest_generator.gd` + QuestManager 动态任务 API | 核心玩法 |
| **剧情模式（非自由模式）** | `scenes/story_mode/`（如存在） | 剧情模式是独立于自由模式的玩法 |

---

## 执行建议

1. **先做第一阶段**（P0 死代码），5 个文件秒删，零风险验证
2. **再做第二到四阶段**（剧情面板 + 信号 + 数据），这是核心删除量
3. **第五到八阶段**（Manager 清理），逐个文件 patch，每完成一个跑一次 `--check-only`
4. **最后阶段**（验证），全量 Grep 残留检查 + Godot 编译

预计总删除量：~2500 行代码 + 15+ 个文件。
