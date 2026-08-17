# Phase War (相位战争：构装纪元) — 复审与修复意见报告

> **复审日期**: 2026-08-19
> **项目路径**: `F:\godot fair duet\create\phase-war`
> **引擎**: Godot 4.5 | **语言**: GDScript
> **复审范围**: project.godot、managers/、scenes/ui/、data/evolution_paths/、scripts/signal_bus.gd、save_manager.gd 等核心文件

---

## 一、复审结论摘要

| 维度 | 状态 | 说明 |
|------|------|------|
| 核心战斗循环 | ✅ 基本完整 | 三攻三防、曲射防御计算已修复 |
| 卡牌/进化/改造系统 | ⚠️ 部分存根 | 进化条件检查仍为 TODO 存根 |
| 存档系统 | ⚠️ 有安全网但 reset 不完整 | 收集有 ManagerLazyLoader 兜底，重置没有 |
| Autoload 配置 | 🔴 存在伪装注释问题 | 多个 autoload 以 `"#..."` 形式注册，实际节点名错误 |
| 测试模式残留 | 🔴 发布前必修 | 初始资源 10 万、全蓝图开局发放、技能点 +100 |
| UI 系统 | ✅ 基本完整 | 孤儿信号、TRANS_FADE、按钮连接均已修复 |
| 资源文件 | ⚠️ 5 个缺失 | 需补全或修改引用 |
| 项目卫生 | ⚠️ 待清理 | 大量临时脚本/输出文件 |

**总体完成度评估：约 85%**。核心玩法可运行，但存在若干发布阻断问题（见 P0）。

---

## 二、相比上次审计已修复的问题（确认）

以下问题经本次复审确认已修复，无需再处理：

| # | 问题 | 修复位置 |
|---|------|----------|
| 1 | 强化按钮 `pressed` 信号未连接 | `scenes/ui/reinforcement_panel.gd:64` 已连接 |
| 2 | `growth_panel_saved` / `card_data_changed` 孤儿信号 | `scripts/signal_bus.gd:206-207` 已定义 |
| 3 | `help_panel.gd` 使用 Godot 4 已移除的 `Tween.TRANS_FADE` | `scenes/ui/help_panel.gd:40-54` 已移除 |
| 4 | 曲射批处理缺少防御计算 | `managers/battle/simple_indirect_projectile_batch.gd` 已修复 |
| 5 | 武器槽位 weapon_type 继承错误 | `resources/card_resource.gd` 已修复 |
| 6 | GameConstants 类名冲突 | `resources/game_constants.gd` 已修复 |
| 7 | 关键 Autoload 缺失（Quest/Faction/Affix/LevelProgress 等） | `project.godot` 已注册 + `save_manager.gd` 有 ManagerLazyLoader 兜底 |
| 8 | 情报掉落/解锁 TODO 存根 | `data/intel_manual_items.gd` 已实现 `_collect_all_evolution_steps()` 等 |
| 9 | 数组越界、对象池失败标记、冗余类型转换 | 均已修复（见 `CODE_QUALITY_FIXES.md`） |

---

## 三、当前仍存在的问题

### 🔴 P0 — 发布阻断（必须修复）

#### P0-1. Autoload 伪注释导致节点名错误、潜在重复实例

**位置**: `project.godot` 第 42-44、52-60 行

**问题**: 多个 Autoload 注册使用了 `"#注释文本#真实名称"` 作为键名。Godot 的 project.godot 注释符是 `;`，`#` 开头的行**不会**被忽略，会被解析为名为 `#注释文本#真实名称` 的 autoload。实际效果：

1. 代码 `get_node_or_null("/root/IntelDiscoveryManager")` 找不到该节点（实际节点名是那一长串 `#v7.x性能...#IntelDiscoveryManager`）
2. 依赖 ManagerLazyLoader 二次实例化 `IntelDiscoveryManager`，造成**场景树中同时存在两个实例**（一个怪名 autoload + 一个懒加载实例），可能引发双重 `_ready()`、重复信号连接、内存浪费
3. 启动时加载了本应延迟加载的脚本，违背性能优化初衷

**涉及行**:
- 第 42 行: `"#v7.x性能...#IntelDiscoveryManager"`
- 第 43 行: `#IntelEvolutionManager`（整行被注释，但格式不规范）
- 第 44 行: `#EnemyOriginModManager`
- 第 52 行: `"#v7.x性能...#LoreManager"`
- 第 53 行: `#AchievementManager`
- 第 54 行: `#DailyTaskManager`
- 第 56 行: `"#CharacterManager...#CharacterManager"`
- 第 57 行: `"#ChallengeModeManager...#ChallengeModeManager"`
- 第 58 行: `"#CardCollectionManager...#CardCollectionManager"`
- 第 59 行: `"leaderboard)守卫#LeaderboardManager"`
- 第 60 行: `"#StatBoostManager...#StatBoostManager"`

**修复方案**:
- 方案 A（推荐）: 彻底删除这些被注释的 autoload 行，统一由 `ManagerLazyLoader` 按需加载
- 方案 B: 如果希望保留 autoload，则改为标准注册名（`LoreManager="*res://managers/lore_manager.gd"`），但会失去懒加载收益
- 注意：无论选哪个方案，都要确保 `save_manager.gd` 的 `CRITICAL_MANAGER_LOADS` / `DEFERRED_MANAGER_LOADS` 与最终注册方式一致

---

#### P0-2. 测试模式残留（发布前必须改回正式数值）

**位置**: `managers/save_manager.gd` `_enqueue_starter_backpack_cards()`

**问题**:
| 行号 | 残留内容 | 正式建议 |
|------|----------|----------|
| L872-876 | 初始资源各 **100,000** | 改为 nano 1500 / alloy 800 / crystal 500 / energy 1000 / research 500 |
| L881 | 初始技能点 **+100** | 删除或改为 0 |
| L903-924 | 开局发放**全部**改造蓝图 + **全部**进化蓝图 | 只保留 `IntelManualItems.ALL_TYPES` 中的 7 张基础图纸，删除全量发放代码块 |

**风险**: 直接上线会导致游戏经济系统完全失效，所有养成内容开局即解锁。

---

#### P0-3. 进化条件检查与继承计算仍为存根

**位置**:
- `data/evolution_paths/infantry_evolution.gd` L283-286（`TODO: 实现条件检查逻辑`）、L289-302（`TODO: 实现继承计算`）
- `data/evolution_paths/armor_evolution.gd` L134-146（无 TODO 但同样是空实现）
- 其余 6 个进化路径文件大概率相同（建议全量排查）

**问题**: `check_requirements()` 恒返回 `{passed = true}`，`calculate_evolved_stats()` 恒返回目标白板值。虽然实际进化判定可能由 `BlueprintManager.can_evolve_blueprint()` 完成（需确认），但这些静态方法若被 UI 或其他系统调用，会让玩家绕过所有进化门槛。

**修复方案**:
1. 确认 `BlueprintManager.can_evolve_blueprint()` 是唯一权威判定入口；若是，则在所有 `evolution_paths/*.gd` 的存根方法中显式转发到 BlueprintManager，或添加 `push_warning` 标记废弃
2. 若这些静态方法仍被使用，则实现真实的 `requirements` 检查（等级、改造数、情报值、战力比等字段已在节点数据中定义）
3. 实现 `calculate_evolved_stats()` 的继承加成：`max(目标白板, 旧卡对应值 × inherit_multiplier)` 并处理 HP 下限 ×1.10 的规则

---

### 🟡 P1 — 建议尽快修复

#### P1-1. `_reset_manager_by_name` 缺少懒加载安全网

**位置**: `managers/save_manager.gd` L615-626

**问题**: `_collect_manager_state` 已有 ManagerLazyLoader 兜底，但 `_reset_manager_by_name` 没有。新游戏重置时，如果一个 DEFERRED 管理器从未被实例化过（场景树中不存在），重置会被静默跳过。下次该管理器被实例化时，可能带着旧存档的数据（如果其脚本有默认值或类级缓存），导致新游戏数据污染。

**修复方案**:
```gdscript
func _reset_manager_by_name(manager_name: String) -> void:
    var mgr: Node = get_node_or_null("/root/" + manager_name)
    if mgr == null:
        var lazy_loader = get_node_or_null("/root/ManagerLazyLoader")
        if lazy_loader and lazy_loader.has_method("get_manager_by_name"):
            mgr = lazy_loader.get_manager_by_name(manager_name)
    if mgr == null:
        return
    # ... 其余重置逻辑不变
```

---

#### P1-2. 缺失资源文件（5 个）

**来源**: `验收报告.md`，本次复审未发现已补全证据。

| 缺失路径 | 被引用场景 | 建议 |
|----------|-----------|------|
| `assets/sfx/button.ogg` | UI 按钮音效 | 用现成素材替换或生成静音占位 |
| `assets/unit_sprites/omega_platform.png` | 欧米茄平台单位 | 用其他平台图替代或补图 |
| `audio/sfx/interface_sound.tres` | 界面音效 | 创建 `.tres` 或改引用 |
| `models/characters/player_model.tscn` | 角色模型 | 删除引用或补占位场景 |
| `textures/ui/ui_theme.tres` | UI 主题 | 删除引用或指向现有主题 |

**建议**: 运行一次全项目资源扫描（`scripts/scan_refs.py` 或 Godot `--check-only`）确认当前缺失列表。

---

#### P1-3. `_enqueue_starter_backpack_cards` 缩进与作用域问题

**位置**: `managers/save_manager.gd` L883-941

**问题**: "初始情报"（L883-889）和"初始蓝图"（L891-936）代码块的缩进疑似嵌套在 `if BasicResourceManager:`（L871）块内部。若 `BasicResourceManager` 为 null，`var ml` 不会被声明，后续 `if ml` 会触发运行时错误。即使现在因 autoload 存在不会触发，这也是脆弱的控制流。

**修复方案**: 将 L883-941 的"初始情报/初始蓝图/初始进化分支"逻辑移出 `if BasicResourceManager:` 块，保持独立顶格（与函数体一致），并格式化缩进。

---

#### P1-4. `_open_overlay` 与 `_PANEL_NODE_NAMES` 缺少部分面板

**位置**: `scenes/main.gd` L402-413

**问题**: `_PANEL_NODE_NAMES` 未覆盖 `growth`、`backpack`、`afk`、`progression` 等面板（这些面板在 `_open_overlay` 中有特殊分支，属正常）。但 `enhancement`、`modification`、`evolution` 的 overlay 存在却未在 `_notify_panel_opened` 的映射中统一处理（modification/evolution 在映射中，enhancement 不在）。建议核对所有 overlay 的打开通知路径是否一致，避免面板打开不刷新。

---

#### P1-5. 代码中仍有全局 `GameConstants` 引用，与预加载别名不一致

**位置**: `scenes/ui/evolution_panel.gd` L892 等

**问题**: 部分文件预加载了 `const GC = preload("res://resources/game_constants.gd")`，但调用时使用全局类名 `GameConstants.get_era_name()`。虽然 GDScript 的 `class_name` 全局解析通常可用，但在 `--check-only` 或特定加载顺序下可能失败。

**修复方案**: 统一使用预加载别名（`GC.get_era_name()`）或统一使用全局类名，全项目二选一。

---

### 🟢 P2 — 代码质量与项目卫生

#### P2-1. 项目根目录临时文件堆积

以下文件/目录属于开发过程残留，建议移入 `tmp_build/` 或删除：
- `nul`、`nul_`（Windows 重定向残留）
- `_rune_sheet.jpg.import`（孤立的 .import 文件）
- `_vfx_trash_20260817/`（已标记为 trash）
- `all_icons.txt`、`icons_list.txt`、`icons_unique.txt`、`MISSING_ICONS_LIST.txt`（审计中间产物）
- `cards_parsed.json`、`audit_assets.json`、`audit_res_refs.json`（审计中间产物）
- `ui-prototype.html`、`ui-prototype-updated.html`、`projectile_showcase.html` 等 8 个 HTML 原型（建议移入 `design/`）
- 根目录 20+ 份散落的 `.md` 报告（建议归入 `reports/` 或 `docs/`）

#### P2-2. `scripts/` 与 `tests/` 下大量临时脚本

- `scripts/_tmp_check.gd`、`temp_audit3.gd`、`temp_full2.gd`、`temp_test.gd`、`test_syntax.gd` 等
- `tests/_afk_fix_verify.gd`、`tests/_tmp_*.gd` 等
- `scripts/` 下 40+ 个 Python 生图脚本（`generate_*.py`、`batch_gen*.py`、`retry_*.py` 等），建议移到 `tools/asset_pipeline/`

#### P2-3. `data/evolution_paths/` 存根方法全量排查

除 `infantry_evolution.gd` 和 `armor_evolution.gd` 外，还需检查：
- `air_evolution.gd`
- `anti_air_evolution.gd`
- `artillery_evolution.gd`
- `engineer_evolution.gd`
- `fort_evolution.gd`
- `recon_evolution.gd`

统一处理 `check_requirements` / `calculate_evolved_stats` 两个方法的存根状态。

#### P2-4. 死代码与废弃引用

- `save_manager.gd` 中 `_grant_all_evolution_blueprints()` / `_unlock_all_enemy_origin_mods()` 已无调用方（注释说明保留供测试），建议移到 `tests/manual/`
- `scripts/signal_bus.gd` 中若干信号仍为预留声明（注释已说明），建议每季度核对一次

---

## 四、建议修复顺序

| 优先级 | 项目 | 预估工作量 | 说明 |
|--------|------|-----------|------|
| P0-1 | 修复 Autoload 伪注释 | 30 分钟 | 删除注释行或改标准注册 |
| P0-2 | 清除测试模式残留 | 15 分钟 | 改数值 + 删代码块 |
| P0-3 | 进化条件存根 | 2-4 小时 | 实现或明确转发 |
| P1-1 | reset 安全网 | 10 分钟 | 复制 collect 的兜底逻辑 |
| P1-2 | 补全缺失资源 | 1-2 小时 | 视素材准备情况 |
| P1-3 | 修复缩进作用域 | 20 分钟 | 整理 `_enqueue_starter_backpack_cards` |
| P1-4 | 面板通知一致性 | 30 分钟 | 核对 overlay 映射 |
| P1-5 | GameConstants 引用统一 | 30 分钟 | 全项目统一别名 |
| P2 | 项目卫生清理 | 2-3 小时 | 移文件/删死代码 |

---

## 五、验证清单

修复完成后，建议依次验证：

1. **Godot 无头检查**
   ```bash
   godot --headless --path "F:\godot fair duet\create\phase-war" --check-only
   ```

2. **启动验证**
   - 启动后检查 `/root/` 下节点名称，确认没有 `#` 开头的 autoload 节点
   - 确认 `IntelDiscoveryManager` 等 DEFERRED 管理器不会在启动时自动加载（懒加载生效）

3. **新游戏验证**
   - 新开存档后资源数量为正式起步量（nano 1500 等）
   - 背包只有 `ww1_ft17` 一张初始卡 + 7 张基础图纸
   - 技能点无 +100 残留

4. **存档验证**
   - 存档 → 读档后 DEFERRED 管理器（成就/日常/图鉴等）数据完整
   - 新游戏后旧 DEFERRED 管理器数据被正确清空

5. **进化验证**
   - 不满足条件时进化按钮置灰且显示具体缺口
   - 满足条件后进化成功，属性继承正确

6. **运行测试套件**
   ```bash
   godot --headless --path "F:\godot fair duet\create\phase-war" --script res://tests/gdunit4_runner.gd
   ```

---

## 六、总结

本项目经过多轮迭代，核心战斗、卡牌、UI 系统已接近完成，架构设计（信号总线 + 懒加载 + 原子存档）优秀。当前主要风险集中在：

1. **Autoload 伪注释**是隐蔽但影响面广的配置错误，可能造成重复实例和资源浪费；
2. **测试模式残留**会直接破坏正式游戏经济；
3. **进化系统存根**可能让玩家绕过核心养成门槛。

修复以上问题后，项目完成度可达到 **90%+**，具备对外测试条件。

---

---

## 七、修复执行记录（2026-08-19 第二轮）

> 应用户要求：**跳过 P0-2（测试模式残留）**，数值保留原样（10 万资源 / 技能点+100 / 全蓝图发放），上线前需另行处理。

### 7.1 已完成的修复

#### ✅ P0-1 Autoload 伪注释（project.godot）

**执行方式**（因乱码行含 C1 控制字符无法精确改写键名，采用混合方案）：

| 处理 | 条目 |
|------|------|
| 整行删除，改 `;` 规范注释 | `#IntelEvolutionManager`、`#EnemyOriginModManager`、`#AchievementManager`、`#DailyTaskManager`（纯 ASCII 行） |
| value 改指向空壳脚本 | 7 个乱码键行（IntelDiscoveryManager / LoreManager / CharacterManager / ChallengeModeManager / CardCollectionManager / LeaderboardManager / StatBoostManager）→ `res://managers/_disabled_autoload_stub.gd` |

**新增文件**: `managers/_disabled_autoload_stub.gd`（无逻辑空 Node，无 `_ready` 副作用）

**双解释下的安全性**:
- 若 Godot 解析了这些乱码键 → 只创建空 Node，**不再实例化真实 manager**，消除"怪名 autoload + 懒加载实例"双实例风险
- 若 Godot 忽略这些键 → 空壳脚本永不加载，零开销

**⚠️ 遗留手工步骤**: 乱码键名本身仍在 project.godot 中（外部工具无法精确匹配含 0x8A/0xA0 控制字节的行）。**请在 Godot 编辑器 Project Settings → Autoload 中删除这 7 个乱码条目**（编辑器会以干净 UTF-8 重写 project.godot），随后可删除 `_disabled_autoload_stub.gd`。相关管理器均已由 ManagerLazyLoader 覆盖（intel_discovery / lore / character / challenge_mode / card_collection / leaderboard / stat_boost），功能不受影响。

#### ✅ P0-3 进化路径死存根（8 个文件）

**核实结论**（比第一轮报告更进一步）：`data/evolution_paths/__init__.gd` 分发器与 `scripts/systems/evolution_path_registry.gd` 均有**完整实现**（`check_evolution_requirements` 含等级/改造/EOM/战力/情报校验；`calculate_evolved_stats` 含改造继承）。面板实际走 `BlueprintManager.can_evolve_blueprint()`（返回 conditions 快照）。各路径文件的 `check_requirements`/`calculate_evolved_stats` 静态方法为**从未被调用的遗留死代码**。

**修复**（infantry / armor / artillery / anti_air / air / recon / engineer / fort 全部 8 个）:
- `check_requirements`: 由恒 `passed = true`（可绕过所有门槛）改为 **@deprecated 注释 + push_warning + 恒 passed = false**（fail-closed，若有未知调用方会显式暴露而非静默放行）
- `calculate_evolved_stats`（仅 infantry 有 TODO 残留）: 移除误导性 `TODO: 实现继承计算`（继承已由 EPR 权威层实现），对齐其余 7 个文件的白板返回 + @deprecated 说明

**测试安全性**: 已核对 `tests/evolution_path_coverage.gd`（仅用 `get_evolution_path`）与 `tests/evolution_condition_smoke.gd`（仅用 EPR + BlueprintManager），均不触及被改静态方法。

#### ✅ P1-3 `_enqueue_starter_backpack_cards` 作用域错误（save_manager.gd）

**实际问题比报告描述更严重**: "初始情报/初始蓝图/初始进化分支"三段（原 L883-936）因缩进错误整体嵌套在 `if pmsm_starter != null and pmsm_starter.has_method("add_bonus_points"):` 块内——PhaseMasterSkillManager 缺失时**所有初始蓝图发放会被静默跳过**，且 `var ml` 声明位置脆弱。

**修复**: `var ml` 提升至函数作用域，三段代码全部提升到函数级，逐行降一级缩进。**测试模式数值全部原样保留**（P0-2 跳过项不受影响）。

#### ✅ P1-1 `_reset_manager_by_name`（结论修正，未改行为）

**复审修正**: 第一轮建议"加 ManagerLazyLoader 兜底"是**错误方向**——未实例化的懒加载管理器本就无内存态可清，跳过即正确；强行实例化会让"新游戏"路径一次性拉起 15+ 个 DEFERRED 管理器，破坏懒加载收益。已改为在设计说明注释中固化该结论（防止后人"顺手修复"引入回归）。

### 7.2 核实后降级/关闭的项

| 项 | 复核结论 |
|----|----------|
| P1-2 缺失资源（部分过时） | `assets/sfx/button.ogg` **已存在**（2026-06-28 审计过时）。仍确认缺失：`assets/unit_sprites/`（整目录为空）、`audio/sfx/interface_sound.tres`（`audio/` 目录不存在）、`models/characters/player_model.tscn`（`models/` 不存在）、`textures/ui/ui_theme.tres`（`textures/` 下只有 `icons/mods/`）。**未做处理**：无法用现有工具定位引用代码（grep 不可用），且伪造占位资源可能引入新问题（空主题/空场景破坏运行时假设）。建议在 Godot 编辑器中全局搜索这 4 个路径，删除死引用或补真实资源。 |
| P1-4 面板通知映射 | **非问题**。`_PANEL_NODE_NAMES` 已覆盖 modification/evolution/collection/occupation/leaderboard 等；`enhancement` 未列入是 v8.x 有意停用（见 ui_lazy_loader 注释"强化②停用"）。关闭。 |
| P1-5 GameConstants 别名 | **非问题**。`resources/game_constants.gd` 保留 `class_name GameConstants`（早期审计所称"已移除类名"实为回退），全局引用合法有效。可选做纯风格统一，无功能影响。关闭。 |
| P2 项目卫生 | **未执行**。当前工具链（无 bash/move/delete）无法移动或删除文件。清单保留在第三节 P2，建议在编辑器或资源管理器中手工归档。 |

### 7.3 修复后必须执行的验证

```bash
# 1. 语法/加载检查（必须通过）
godot --headless --path "F:\godot fair duet\create\phase-war" --check-only

# 2. 启动检查：/root 下不应出现名称以 # 开头的【带逻辑】节点
#    （改指向 stub 后，最多出现 7 个空壳节点，无 _ready 副作用，属预期）

# 3. 新游戏冒烟：背包应有 ww1_ft17 + 7 张基础图纸 +（测试模式）全部蓝图；
#    初始情报/初始进化分支逻辑不再依赖 PhaseMasterSkillManager 存活

# 4. 进化系统回归（确认改动未破坏权威链路）
godot --headless --path "F:\godot fair duet\create\phase-war" --script res://tests/evolution_condition_smoke.gd
godot --headless --path "F:\godot fair duet\create\phase-war" --script res://tests/evolution_path_coverage.gd

# 5. 存档回归：读档→存档往返，DEFERRED 管理器数据完整
```

### 7.4 修改文件清单

| 文件 | 变更 |
|------|------|
| `project.godot` | 4 行伪注释→`;` 注释；7 个乱码键 value→stub 脚本 |
| `managers/_disabled_autoload_stub.gd` | **新增**（空壳 autoload 占位） |
| `managers/save_manager.gd` | P1-3 结构修复（保留测试数值）；P1-1 设计注释 |
| `data/evolution_paths/infantry_evolution.gd` | 存根 fail-closed + 清除 TODO |
| `data/evolution_paths/armor_evolution.gd` | 存根 fail-closed |
| `data/evolution_paths/artillery_evolution.gd` | 存根 fail-closed |
| `data/evolution_paths/anti_air_evolution.gd` | 存根 fail-closed |
| `data/evolution_paths/air_evolution.gd` | 存根 fail-closed |
| `data/evolution_paths/recon_evolution.gd` | 存根 fail-closed |
| `data/evolution_paths/engineer_evolution.gd` | 存根 fail-closed |
| `data/evolution_paths/fort_evolution.gd` | 存根 fail-closed（注：此文件为 CRLF 行尾，编辑引入少量 LF 混排，Godot 解析器兼容） |

---

*本报告由项目复审生成并附修复执行记录，保存于项目根目录，供开发团队逐项落实。*
