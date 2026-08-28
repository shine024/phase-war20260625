# 敌方战斗卡情报系统 v21.0 — 详细执行计划（修订版 r2）

> 状态：执行中
> 日期：2026-08-27 初稿 / 2026-08-28 r2 修订实施
> 前置条件：`data/enemy_card_mod_map.gd` ✅ / `data/intel_mod_thresholds.gd` ✅ 已完成

---

## r2 修订要点（初稿评审结论落实）

初稿经与代码库逐项核对，发现 6 处致命问题 + 若干功能缺口，本版全部修正：

1. **base/intel 双轨同步规则定稿（单调 max 模型）**：`intel_progress` 仍是唯一累加轴
   （击败/部署/侦察/分解全走 `_add_intel`），`base_progress = max(历史 intel, 获取下限 0.5)`，
   只增不减。初稿调用的 `_sync_base_from_intel()` 从未定义（加载即报错），同步逻辑下沉到
   `_add_intel` 内部，删除该函数。
2. **部署触发链补齐**：初稿的 `register_deploy()` 没有任何调用方（Phase 2.1 只加了注释），
   核心玩法不会发生。r2 在 `battle_spawn_system.request_player_deploy` 成功路径接线。
3. **信号归属修正**：`base_progress_changed` / `mod_points_gained` / `mod_unlocked` 声明在
   **IntelManual** 并在其内部 emit（初稿声明在 IntelDiscoveryManager 却从 IntelManual 连接，
   `has_signal` 守卫下是永久死代码）。通知复用 `FeatureUnlockPopup.show_once`（项目既有模式，
   instance_registry 有先例），**不新增 SignalBus 信号**（初稿的
   `SignalBus.enemy_low_evolution_available` 不存在，直接 emit 会运行时报错）。
4. **ID 命名空间统一**：IntelManual 条目键 = `archetype_id`（战斗收获链路现状如此）；
   玩家侧缴获卡 card_id 带 `captured_` 前缀（`captured_ww1_inf_mp18`）。所有跨系统调用先
   `trim_prefix("captured_")` 再查 `EnemyCardModMap`。instance_registry 挂钩加
   `begins_with("captured_") + has_entry()` 双守卫——初稿会把所有普通玩家卡也建垃圾情报条目。
5. **进化集成为"低进化"选项**：初稿 `_get_autoload_node("EnemyCardModMap")` 取出恒 null
   （它是 RefCounted 静态类不是 autoload）→ 低进化永不可用。r2 改用 class_name 静态调用；
   `get_evolution_options` 输出 `low_evolution` 键，`can_evolve_blueprint` 对 captured 源
   放行目标校验并新增 `intel_base` 条件；低进化对**跳过 evo_blueprint（图纸）条件**
   （captured→player 对不在图纸掉落链上，不跳过则恒 false）。
6. **旧档迁移改在 `from_dict` 做默认值**：`base_progress` 缺失时取 `intel_progress`。
   初稿挂在 `_migrate_v2_to_v3`，但现行存档已是 v3 + migrated=true + 空4维，
   `_apply_loaded_raw` 的迁移条件永不触发 → 老玩家进度归零。
7. **击败也给 mod 点数**（normal +1 / elite +2 / boss +3，`intel_mod_thresholds.gd` 头注释
   承诺），在 `generate_battle_intel_harvest` 循环接线并汇入收获展示数据（初稿测试表承诺无实现）。
8. **base ≥ 100% 全 mod 解锁**分支落地（初稿同样只有承诺）。
9. **UI 改 `_refresh_intel_tab`/`_add_intel_row`**（初稿只改 `_setup_intel_tab`——该函数只建
   容器，行内容每次切 Tab 由 `_refresh_intel_tab` 重建清空）。保留"遭遇后发现"渐进性
   （继续遍历 `get_all_entries()`，不改为全量 109 条罗列）。
10. **mod_pool 时代考据修正（附录 A.4）暂缓**：A.4 若干"修正"与 A.3 时代基准自相矛盾
    （如一战 MP18 班把二战 SCR-536 换成现代 PRC-152 单兵电台），需单独一轮数据策展，
    本轮不动 `enemy_card_mod_map.gd` 数值。

## 核心设计（r2 定稿）

```
情报轴（不变）  intel_progress ← _add_intel()（击败[递减]/侦察/分解/部署[固定+4%]）
总进度轴（新）  base_progress = max(intel_progress 历史峰值, 获取下限 0.5)   只增不减
mod 点数轴（新）card_mod_intels[archetype][mod_id] ← 部署+2~5 / 击败+1~3（随机落池）
解锁            点数 ≥ 阈值(稀有度) 或 base ≥ 100%（全池无条件解锁）
低进化          缴获卡(captured_X) + base(X) ≥ 50% 且 MAPPING[X].low_evo → 进化为对应玩家卡
完整进化        base ≥ 100%（low_evo=false 的 Boss/平台/特色卡需满情报才能转化）
```

关键链路：

```
击败敌人    intel_discovery_manager.generate_battle_intel_harvest
              → IntelManual.register_defeat（intel 递减增长，base 随 max 同步）
              → IntelManual.add_defeat_mod_points（rank 点数入池，达标解锁）
部署敌形态  battle_spawn_system.request_player_deploy 成功
              → IntelManual.register_deploy（base+4% 固定 + 2~5 点数）
获取敌卡    InstanceRegistry._register_clone（购买/掉落/势力奖励统一口径）
              → IntelManual.set_acquired_base_progress（base/intel 下限 0.5）
低进化      CardEvolutionManager.get_evolution_options 输出 low_evolution
              → can_evolve_blueprint 加 intel_base 条件 → evolve_blueprint 走既有实例化路径
通知        IntelManual 信号 → IntelDiscoveryManager 回调 → FeatureUnlockPopup.show_once
```

---

## Phase 1：修改 `scripts/systems/intel_manual.gd`

### 1.1 新增常量（现有常量块后）

```gdscript
## v21.0: 部署情报增量（固定，不衰减——递减只作用于击败曲线）
const DEPLOY_BASE_INTEL: float = 0.04
const DEPLOY_MIN_MOD_POINTS: int = 2
const DEPLOY_MAX_MOD_POINTS: int = 5
## v21.0: 击败 mod 点数（按 rank）
const DEFEAT_MOD_POINTS_NORMAL: int = 1
const DEFEAT_MOD_POINTS_ELITE: int = 2
const DEFEAT_MOD_POINTS_BOSS: int = 3
## v21.0: 获取敌方形态卡（captured_*，购买/掉落/势力奖励）的情报下限
const ACQUIRED_BASE_FLOOR: float = 0.5
## v21.0: 低进化 / 完整进化 base 门槛
const LOW_EVOLUTION_BASE: float = 0.5
const FULL_EVOLUTION_BASE: float = 1.0
```

### 1.2 新增信号（现有信号块后）

```gdscript
## v21.0: base 进度变化（获取下限/情报增长驱动）
signal base_progress_changed(card_id: String, old_val: float, new_val: float)
## v21.0: mod 点数增加 signal(card_id, mod_id, new_points, threshold)
signal mod_points_gained(card_id: String, mod_id: String, new_points: int, threshold: int)
## v21.0: mod 解锁 signal(card_id, mod_id)
signal mod_unlocked(card_id: String, mod_id: String)
```

### 1.3 `IntelEntry` 新增字段（`migrated` 之后）

```gdscript
## v21.0: 双轨情报（base = max(intel 历史峰值, 获取下限)，只增不减）
var base_progress: float = 0.0
var deploy_count: int = 0                ## 部署该敌方形态的次数
var card_mod_intels: Dictionary = {}     ## archetype_id -> {mod_id: int} 累积点数
var unlocked_mod_ids: Array[String] = [] ## 已解锁 mod_id（派生缓存）
```

`to_dict()` 增加四个键；`from_dict()` 读取（**迁移关键**）：

```gdscript
entry.base_progress = clampf(data.get("base_progress", data.get("intel_progress", 0.0)), 0.0, 1.0)
```

> base_progress 键缺失时默认取 intel_progress——对现行 v3 存档（迁移函数不会跑）同样生效，
> 老玩家进度无损继承。`_migrate_v2_to_v3` 无需改动。

### 1.4 `_add_intel()` 内部追加 base 同步（阶梯信号之后、return 之前）

```gdscript
## v21.0: base 单调同步——base = max(base, intel)，满了全解锁
if entry.base_progress < entry.intel_progress:
    var old_base: float = entry.base_progress
    entry.base_progress = entry.intel_progress
    base_progress_changed.emit(card_id, old_base, entry.base_progress)
_check_mods_full_unlock(card_id)
```

### 1.5 新增情报获取接口（`register_decompose()` 之后）

```gdscript
## v21.0: 部署敌方形态卡（captured_*）——base +4% 固定 + 随机 2~5 mod 点数
func register_deploy(archetype_id: String, enemy_type: String = "") -> Dictionary

## v21.0: 击败获得的 mod 点数（normal+1/elite+2/boss+3），返回实际入池点数（无可选池时 0）
func add_defeat_mod_points(archetype_id: String, unit_rank: String = "normal") -> int

## v21.0: 获取敌方形态卡（购买/掉落/势力奖励）——base 与 intel 同时抬到 50% 下限。
## intel 走 _add_intel（正确触发阶梯/揭示信号）；base 直接抬（可能高于 intel）。
func set_acquired_base_progress(archetype_id: String) -> void
```

### 1.6 新增 mod 点数管理（`_add_intel()` 之后）

```gdscript
## v21.0: 向随机一个未解锁 mod 累积点数，达标自动解锁（emit mod_points_gained/mod_unlocked）
func _add_mod_points(archetype_id: String, points: int) -> int  ## 返回入池点数（0=池满/无池）
## v21.0: 点数达标检查
func _check_mod_unlock(archetype_id: String, mod_id: String) -> void
## v21.0: base ≥ 100% 时该卡 mod_pool 全量无条件解锁（绕过点数检查）
func _check_mods_full_unlock(card_id: String) -> void
```

静态引用：`EnemyCardModMap` / `IntelModThresholds` 直接用 class_name（两者已声明，
**不要**再 const preload——重名遮蔽全局类告警）；`ModificationRegistry` 无 class_name 且与
autoload 重名，用别名 `const ModRegistry = preload("res://scripts/systems/modification_registry.gd")`。

### 1.7 新增查询接口（现有查询块末尾）

```gdscript
func get_base_progress(card_id: String) -> float
func get_deploy_count(archetype_id: String) -> int
func get_mod_intel_points(archetype_id: String, mod_id: String) -> int
func get_all_mod_intel_points(archetype_id: String) -> Dictionary
func get_unlocked_mod_ids(archetype_id: String) -> Array[String]
func is_mod_unlocked(archetype_id: String, mod_id: String) -> bool
func get_mod_unlock_progress(archetype_id: String, mod_id: String) -> float  ## 0.0~1.0
```

---

## Phase 2：修改 `scripts/systems/intel_discovery_manager.gd`

### 2.1 `_ready()` 连接 IntelManual v21 信号

```gdscript
if im.has_signal("base_progress_changed"):
    im.base_progress_changed.connect(_on_base_progress_changed)
if im.has_signal("mod_unlocked"):
    im.mod_unlocked.connect(_on_mod_unlocked)
```

### 2.2 `generate_battle_intel_harvest()` 击败循环内接线

`register_defeat` 调用之后：

```gdscript
## v21.0: 击败 mod 点数（normal+1/elite+2/boss+3），汇入收获展示
if im.has_method("add_defeat_mod_points"):
    var mp_gained: int = im.add_defeat_mod_points(archetype_id, rank)
    if mp_gained > 0:
        mod_points_by_card[archetype_id] = mod_points_by_card.get(archetype_id, 0) + mp_gained
```

`_merge_harvests` 之后把 `mod_points_by_card` 写进各合并条目（新键 `"mod_points": int`），
供结算界面展示。

### 2.3 新增回调（文件末尾）

```gdscript
## v21.0: base 跨过 50% → 低进化可用通知（一次性）
func _on_base_progress_changed(card_id: String, old_val: float, new_val: float) -> void:
    if old_val < IntelManual.LOW_EVOLUTION_BASE and new_val >= IntelManual.LOW_EVOLUTION_BASE \
            and EnemyCardModMap.can_low_evolve(card_id):
        FeatureUnlockPopup.show_once("v21_low_evo_" + card_id, "低进化可用", ...)

## v21.0: mod 解锁通知（一次性）
func _on_mod_unlocked(card_id: String, mod_id: String) -> void:
    FeatureUnlockPopup.show_once("v21_mod_" + card_id + "_" + mod_id, "改造情报解锁", ...)
```

（卡名/mod 名经 `DefaultCards.get_safe_display_name` / `ModRegistry.get_data(mod_id).name` 取；
实际实现直接以 preload/局部引用取，避免 autoload 标识符在 --script 模式编译期不可用。）

---

## Phase 3：修改 `managers/instance_registry.gd`

### 3.1 `_register_clone()` 末尾（`instance_created.emit` 之后）加获取挂钩

```gdscript
# v21.0: 获取敌方形态卡（captured_*，购买/掉落/势力奖励统一经此）→ 情报下限 50%
if canonical_id.begins_with("captured_"):
    var v21_arch: String = canonical_id.trim_prefix("captured_")
    if EnemyCardModMap.has_entry(v21_arch):
        var v21_im: Node = get_node_or_null("/root/IntelManual")
        if v21_im and v21_im.has_method("set_acquired_base_progress"):
            v21_im.set_acquired_base_progress(v21_arch)
```

双守卫确保普通玩家卡（无前缀）与未配置 archetype 不产生垃圾条目。

---

## Phase 4：修改 `managers/battle/battle_spawn_system.gd`

### 4.1 `request_player_deploy()` 成功路径接线

`var unit = _create_player_unit(stats)` 判空守卫**之后**（此处起部署必然成功）：

```gdscript
# v21.0: 部署敌方形态卡 → 该 archetype 情报成长（base+4% 固定 + 2~5 mod 点数）
if base_card_id.begins_with("captured_"):
    _register_enemy_form_deploy_intel(base_card_id)
```

新增私有辅助（解析 IntelManual → `register_deploy(arch)`，arch = trim_prefix("captured_")，
带 has_entry 守卫）。每次部署调用于单位实际生成之后，7星卡多单位部署按每次调用各计一次。

---

## Phase 5：进化集成（4 个文件）

### 5.1 `managers/evolution/card_evolution_manager.gd`

**`get_evolution_options()`** 返回字典新增 `"low_evolution"` 键（captured 源才输出）：

```gdscript
## v21.0: 低进化——缴获敌形态卡 → 对应玩家卡（EnemyCardModMap.player_card_id）
if card_id.begins_with("captured_"):
    var arch: String = card_id.trim_prefix("captured_")
    var pid: String = EnemyCardModMap.get_player_card_id(arch)
    if not pid.is_empty() and DefaultCards.get_card_by_id(pid) != null:
        out["low_evolution"] = {"target_card_id": pid, "archetype_id": arch}
```

**`can_evolve_blueprint()`** 四处改动：
1. 目标校验：`_is_low_evolution_pair(card_id, target_card_id)` 为真 → `valid_target = true`；
2. cross_class 检查：低进化对跳过（缴获原型 → 玩家等价卡 combat_kind 可能有出入）；
3. evo_blueprint 条件：低进化对**跳过**（该对不在图纸掉落链上，不跳过恒 false）；
4. conditions 末尾追加 `intel_base` 条件：

```gdscript
## v21.0: 低进化/完整进化的情报门槛（low_evo 卡 50%，Boss/平台/特色卡 100%）
if is_low_evo_pair:
    var arch: String = card_id.trim_prefix("captured_")
    var threshold: float = LOW_EVOLUTION_BASE if EnemyCardModMap.can_low_evolve(arch) else FULL_EVOLUTION_BASE
    var base_prog: float = <IntelManual>.get_base_progress(arch)
    conditions.append({
        "key": "intel_base",
        "met": base_prog >= threshold,
        "current_text": "%.0f%%" % (base_prog * 100),
        "required_text": "%.0f%%" % (threshold * 100),
        "detail": "击败/部署该敌方形态积累情报（获取实物卡直接过半）",
    })
```

（`<IntelManual>` 经 `_get_autoload_node("IntelManual")` 取，判空回退 0.0。）

**`_condition_key_to_reason()`** 加映射：`"intel_base": return "intel_base_not_enough"`。

### 5.2 `data/unit_lineage_config.gd`

`EVOLVE_REASON_ZH` 加：`"intel_base_not_enough": "敌方形态情报不足（击败/部署该敌卡积累，获取实物卡直接过半）"`。

### 5.3 `resources/card_resource.gd` — `get_evolution_targets()`

intel 分支之后追加 low 分支（opts["low_evolution"] → `_build_evo_target(pid, "low")`），
进化面板自动出现"低进化"目标节点。

### 5.4 `scenes/ui/unit_progression_detail_view.gd` — `_add_forward_evolution_block()`

早退条件扩展：无 lineage 但有 `low_evolution` 时不清空，渲染
`_add_evolution_target("低进化 · 情报过半", target_id, "low")` 一行（状态沿 can_evolve_blueprint）。

### 5.5 执行路径

`evolve_blueprint → _evolve_instance` **零改动**：目标为玩家卡（DefaultCards 有模板），
create_instance + dispose + 传承奖励迁移全部走既有实例化路径。

---

## Phase 6：UI

### 6.1 `scenes/ui/intelligence_hub_panel.gd` — 敌方情报 Tab

- `_setup_intel_tab()`：仅更新顶部 hint 文案（新增部署/获取/低进化说明）。
- `_refresh_intel_tab()` / `_add_intel_row()`：
  - 主进度条改读 `base_progress`（intel 与 base 在无获取下限时相等，老条目无感知差异）；
  - 行内加"部署 ×N"标签（`deploy_count > 0` 时）；
  - base ≥ 50% 且 `can_low_evolve` → 加"低进化可用"徽标（金色）；
  - 条目在 EnemyCardModMap 中 → 追加 mod 小节：每行 `mod名 + 点数/阈值` 进度小条，
    已解锁金色高亮（`is_mod_unlocked`）。

### 6.2 `scenes/ui/intel_harvest_display.gd` — 结算界面

`_create_card_entry()` 进度条行之后：

```gdscript
## v21.0: mod 点数增益（Phase 2.2 写入的 "mod_points" 键）
var mp: int = int(entry.get("mod_points", 0))
if mp > 0:
    var lbl := Label.new()
    lbl.text = "  ▸ 改造情报 +%d 点" % mp
    ...
```

---

## Phase 7：测试与验证

`tests/intel_v21_smoke.gd`（extends SceneTree，--script 模式，不依赖 autoload）：

| # | 断言 |
|---|------|
| 1 | `from_dict`：只有 intel_progress 的旧条目 → base_progress == intel_progress（v3 存档迁移） |
| 2 | `register_defeat` → intel 增长且 base == intel（同步生效），mod 点数入池 |
| 3 | `register_deploy` → deploy_count=1、base +0.04、mod 点数 ∈ [2,5] |
| 4 | `set_acquired_base_progress` → base ≥ 0.5 且 intel ≥ 0.5（信号正常触发不炸） |
| 5 | 连续 `register_defeat`/`register_deploy` 推满 → base=1.0 且 mod_pool 全部 unlocked |
| 6 | 点数单独达标（直接 _add_mod_points）→ 对应 mod unlocked，其余不动 |
| 7 | `get_evolution_options("captured_ww1_inf_mp18")` 输出 low_evolution.target == "ww1_mp18" |
| 8 | `can_evolve_blueprint("captured_ww1_inf_mp18", "ww1_mp18", null)`：intel_base 条件在 base≥0.5 时 met；reason 不再是 target_not_in_path |
| 9 | 存档往返：save_state → load_state 后 base/deploy_count/card_mod_intels/unlocked_mod_ids 无损 |

运行：`godot --headless --rendering-driver opengl3 --path . --script tests/intel_v21_smoke.gd`

---

## 依赖关系

```
Phase 1 (intel_manual.gd)
    ↓
Phase 2 (intel_discovery_manager.gd) ──┐
Phase 3 (instance_registry.gd) ────────┼──→ Phase 6 (UI)
Phase 4 (battle_spawn_system.gd) ──────┘
    ↓
Phase 5 (进化集成 4 文件)
    ↓
Phase 7 (测试)
```

## 文件改动清单（r2）

| # | 文件 | 改动类型 |
|---|------|---------|
| 1 | `scripts/systems/intel_manual.gd` | 核心新增 ~150 行 |
| 2 | `scripts/systems/intel_discovery_manager.gd` | 小改 ~50 行 |
| 3 | `managers/instance_registry.gd` | 小改 ~10 行 |
| 4 | `managers/battle/battle_spawn_system.gd` | 小改 ~15 行 |
| 5 | `managers/evolution/card_evolution_manager.gd` | 中改 ~50 行 |
| 6 | `data/unit_lineage_config.gd` | 1 行（reason 表） |
| 7 | `resources/card_resource.gd` | 小改 ~10 行 |
| 8 | `scenes/ui/unit_progression_detail_view.gd` | 小改 ~15 行 |
| 9 | `scenes/ui/intelligence_hub_panel.gd` | 中改 ~60 行 |
| 10 | `scenes/ui/intel_harvest_display.gd` | 小改 ~15 行 |
| 11 | `tests/intel_v21_smoke.gd` | 新增 |

**已有文件（无需修改）**：
- `data/enemy_card_mod_map.gd` ✅ 109 条 mod_pool（时代考据修正见 r2 修订要点 #10，暂缓）
- `data/intel_mod_thresholds.gd` ✅ 6 档阈值表

---
## 附录 A：敌方战斗卡 mod_pool 完整配置（含中文卡名）

### A.1 改造 ID → 中文对照（按前缀分组）

#### 步兵 `inf_`（28个）

| ID | 中文 | 时代适用 |
|----|------|---------|
| `inf_01` | 冲锋枪改装 | 全时代 |
| `inf_02` | 突击步枪化 | 二战起 |
| `inf_03` | 小口径化 | 冷战起 |
| `inf_05` | 穿甲弹 | 全时代 |
| `inf_07` | 光学瞄准镜 | 全时代 |
| `inf_08` | 全息瞄准镜 | 冷战起 |
| `inf_09` | 双弹匣并联 | 全时代 |
| `inf_10` | 班用机枪化 | 全时代 |
| `inf_11` | 防弹插板 | 二战起 |
| `inf_12` | 防弹背心 | 全时代 |
| `inf_13` | 头盔升级 | 全时代 |
| `inf_14` | 护膝护肘 | 全时代（common级） |
| `inf_16` | 外骨骼原型 | 近未来 |
| `inf_17` | 止血带 | 全时代 |
| `inf_18` | 战场急救包 | 全时代 |
| `inf_19` | 单兵电台 | 全时代 |
| `inf_20` | 夜视仪 | 二战起 |
| `inf_21` | 热成像 | 冷战起 |
| `inf_22` | 破门工具 | 全时代 |
| `inf_23` | 战斗兴奋剂 | 现代起 |
| `inf_24` | 巷战教范 | 近未来 |

#### 装甲 `arm_`（15个）

| ID | 中文 | 时代适用 |
|----|------|---------|
| `arm_01` | 倾斜装甲 | 全时代 |
| `arm_02` | 复合装甲 | 二战起 |
| `arm_03` | 爆反装甲 | 冷战起 |
| `arm_04` | 主动防护 | 冷战起 |
| `arm_05` | 滑膛炮 | 二战起 |
| `arm_06` | 尾翼稳定穿甲弹 | 全时代 |
| `arm_08` | 自动装弹机 | 二战起 |
| `arm_09` | 燃气轮机 | 冷战起 |
| `arm_10` | 柴油增压引擎 | 全时代 |
| `arm_11` | 猎歼火控 | 全时代 |
| `arm_12` | 热成像瞄准镜 | 二战起 |
| `arm_13` | 深涉渡 | 冷战起 |
| `arm_15` | 战术数据链 | 冷战起 |
| `arm_16` | 战斗狂热 | 现代起 |

#### 炮兵 `art_`（12个）

| ID | 中文 |
|----|------|
| `art_01` | 膛线强化 |
| `art_02` | 增程弹 |
| `art_03` | 精确制导炮弹 |
| `art_04` | 子母弹 |
| `art_06` | 射击计算机 |
| `art_07` | 弹药运输车 |
| `art_08` | 炮兵侦察无人机 |
| `art_09` | 急速射系统 |

#### 防空 `aa_`（12个）

| ID | 中文 |
|----|------|
| `aa_01` | 炮瞄雷达 |
| `aa_03` | 防空导弹挂架 |
| `aa_05` | 近炸引信 |
| `aa_07` | 相控阵雷达 |
| `aa_11` | 自动化火控 |

#### 航空 `air_`（14个）

| ID | 中文 |
|----|------|
| `air_01` | 涡扇发动机 |
| `air_02` | 矢量推力 |
| `air_03` | 隐身涂层 |
| `air_04` | 有源相控阵雷达 |
| `air_06` | 超视距导弹 |
| `air_07` | 格斗弹舱 |
| `air_08` | 电子对抗系统 |
| `air_11` | 外挂武器架 |
| `air_12` | 数据链系统 |

#### 侦察 `rec_`（12个）

| ID | 中文 |
|----|------|
| `rec_01` | 光学伪装 |
| `rec_03` | 消音器 |
| `rec_04` | 高倍瞄准镜 |
| `rec_05` | 无人侦察机 |

#### 工程 `eng_`（10个）

| ID | 中文 |
|----|------|
| `eng_01` | 地雷清除器 |
| `eng_08` | 战场急救站 |
| `eng_09` | 弹药补给车 |

#### 堡垒 `for_`（10个）

| ID | 中文 |
|----|------|
| `for_01` | 钢筋混凝土装甲 |
| `for_03` | 自动炮塔 |
| `for_06` | 雷达天线 |
| `for_09` | 雷场 |
| `for_10` | 指挥塔 |

#### 通用 `gen_`（24个）

| ID | 中文 | 时代 |
|----|------|------|
| `gen_01` | 战场通讯 | 全时代 |
| `gen_02` | 数字化单兵 | 冷战起 |
| `gen_03` | 伪装迷彩 | 全时代 |
| `gen_04` | 战术背心 | 全时代 |
| `gen_05` | 防弹盾牌 | 全时代 |
| `gen_06` | 激光指示器 | 现代起 |
| `gen_07` | 防雷座椅 | 现代起 |
| `gen_09` | 红外干扰机 | 现代起 |
| `gen_11` | 相位共鸣 | 近未来 |
| `gen_12` | 相位护盾 | 近未来 |
| `gen_13` | 相位过载 | 近未来 |
| `gen_14` | 相位护盾发生器 | 近未来 |
| `gen_16` | 电磁脉冲装置 | 近未来 |

---

### A.2 敌方战斗卡 mod_pool 完整配置

#### 🔵 一战时代（era=0）

| 敌方卡 | 玩家卡 | mod_pool | 低进化 |
|--------|--------|---------|--------|
| ~~步兵班·MP18~~ ~~MP18突击班~~ ~~冲锋枪改装 · 双弹匣并联 · 战场通讯~~ ~~✅~~ | ~~[错误] SCR-536=二战通讯~~ | | |
| ~~步兵班·步枪~~ ~~毛瑟步枪班~~ ~~突击步枪化 · 光学瞄准镜 · 伪装迷彩~~ ~~✅~~ | ~~[错误] STG44=二战, ACOG=1990s~~ | | |
| 机枪巢 | MG08机枪巢 | 班用机枪化 · 防弹背心 · ~~防弹盾牌~~ | ~~[错误] 凯夫拉盾牌=现代~~ |
| 迫击炮组 | 81mm迫击炮组 | 膛线强化 · 增程弹 · ~~弹药运输车~~ | ~~[错误] M549火箭增程弹=现代~~ |
| 暴风突击队·精锐 | 暴风突击队 | 冲锋枪改装 · 穿甲弹 · 头盔升级 · 破门工具 | ✅ |
| 装甲车·精锐 | 罗尔斯装甲车 | 倾斜装甲 · 柴油增压引擎 · ~~猎歼火控~~ | ~~[错误] 红宝石火控=1980s~~ |
| **圣沙蒙坦克·Boss** | FT-17轻型坦克 | 复合装甲 · 尾翼稳定穿甲弹 · 热成像瞄准镜 · 战斗狂热 | ❌ |
| ~~李-恩菲尔德志愿兵排~~ ~~李恩菲尔德班~~ ~~突击步枪化 · 光学瞄准镜 · 伪装迷彩~~ ~~✅~~ | ~~[错误] STG44=二战, ACOG=1990s~~ | | |
| 劳斯莱斯 Mk.II 装甲车 | 罗尔斯装甲车 | 倾斜装甲 · 柴油增压引擎 | ✅ |
| 维克斯 .303 机枪阵地 | MG08机枪巢 | 班用机枪化 · ~~防弹盾牌~~ | ~~[错误] 凯夫拉盾牌=现代~~ |
| 福特 T 型战地救护车 | MP18突击班 | 战场急救包 · 止血带 · 战术背心 | ✅ |
| ~~MP18 突击队~~ ~~MP18突击班~~ ~~冲锋枪改装 · 双弹匣并联 · 夜视仪~~ ~~✅~~ | ~~[错误] PVS-14=1994年量产~~ | | |

#### 🟢 二战时代（era=1）

| 敌方卡 | 玩家卡 | mod_pool | 低进化 |
|--------|--------|---------|--------|
| 步兵班·汤普森 | 汤普森班 | 冲锋枪改装 · 双弹匣并联 · 单兵电台 | ✅ |
| ~~步枪班·加兰德~~ ~~[错误] STG44正确但ESAPI=2000s~~ ~~突击步枪化 · 光学瞄准镜 · 防弹背心~~ ~~✅~~ | | | |
| ~~MG42机枪组·敌方~~ ~~[错误] ESAPI=2000s~~ ~~班用机枪化 · 防弹插板 · 防弹盾牌~~ ~~✅~~ | | | |
| 反坦克组·精锐 | 铁拳反坦克组 | 穿甲弹 · 防弹背心 · 高倍瞄准镜 | ✅ |
| 伞兵精英 | 汤普森班 | 冲锋枪改装 · 夜视仪 · 消音器 | ✅ |
| 黑豹坦克·精锐 | 黑豹坦克 | 复合装甲 · 滑膛炮 · 热成像瞄准镜 · 战术数据链 | ✅ |
| **虎王坦克·Boss** | 虎式坦克 | 复合装甲 · 主动防护 · 尾翼稳定穿甲弹 · 自动装弹机 · 战斗狂热 | ❌ |
| ~~M1 加兰德伞兵班~~ ~~[错误] 陆地勇士=2000s~~ ~~突击步枪化 · 单兵电台 · 数字化单兵~~ ~~✅~~ | | | |
| 黄蜂 Hummel 自行火炮 | 81mm迫击炮 | 膛线强化 · 增程弹 · 射击计算机 | ✅ |
| PaK 40 反坦克炮组 | 铁拳反坦克组 | 膛线强化 · 射击计算机 · 无人侦察机 | ✅ |
| ~~GMC 2.5t 补给卡车~~ ~~[错误] M113=越战~~ ~~弹药补给车 · 战术背心~~ ~~✅~~ | | | |
| ~~毛瑟 Kar98k 狙击组~~ ~~[错误] AN/PAS-13=1990s~~ ~~光学瞄准镜 · 热成像 · 高倍瞄准镜~~ ~~✅~~ | | | |

#### 🟡 冷战时代（era=2）

| 敌方卡 | 玩家卡 | mod_pool | 低进化 |
|--------|--------|---------|--------|
| 苏军步兵 | AK-47步兵班 | 突击步枪化 · 防弹背心 · 单兵电台 · 伪装迷彩 | ✅ |
| 美军步兵·M60 | M14步兵班 | 小口径化 · 全息瞄准镜 · 防弹插板 | ✅ |
| BTR装甲车·敌方 | M2布雷德利 | 爆反装甲 · 深涉渡 · 战术数据链 | ✅ |
| M113装甲车·敌方 | M2布雷德利 | 爆反装甲 · 燃气轮机 | ✅ |
| 特种部队·精锐 | 阿尔法特种部队 | 突击步枪化 · 夜视仪 · 热成像 · 光学伪装 · 消音器 | ✅ |
| T-72坦克·精锐 | T-72坦克 | 爆反装甲 · 尾翼稳定穿甲弹 · 猎歼火控 · 热成像瞄准镜 | ✅ |
| **米格-29·Boss** | 米格-21战机 | 涡扇发动机 · 超视距导弹 · 电子对抗系统 · 数据链系统 | ❌ |
| BMD-1 空降战车 | M2布雷德利 | 爆反装甲 · 燃气轮机 · 深涉渡 | ✅ |
| BMP-1 步兵战车·改 | M2布雷德利 | 爆反装甲 · 燃气轮机 | ✅ |
| 9K111 法特导弹组 | RPG火箭筒组 | 穿甲弹 · 防弹背心 · 热成像 | ✅ |
| P-18 雷达警戒车 | 米格-21战机 | 炮瞄雷达 · 相控阵雷达 · 自动化火控 | ✅ |
| BREM-1 装甲抢修车 | T-72坦克 | 倾斜装甲 · 地雷清除器 | ✅ |

#### 🔴 现代时代（era=3）

| 敌方卡 | 玩家卡 | mod_pool | 低进化 |
|--------|--------|---------|--------|
| 海军陆战队·敌方 | 海军陆战队 | 突击步枪化 · 小口径化 · 光学瞄准镜 · 单兵电台 · 数字化单兵 | ✅ |
| 皮卡武装·敌方 | 武装皮卡 | 穿甲弹 · 防弹背心 · 单兵电台 · 伪装迷彩 | ✅ |
| 斯特赖克装甲车·敌方 | 斯特赖克MGS | 复合装甲 · 主动防护 · 猎歼火控 · 战术数据链 | ✅ |
| 火箭炮车·敌方 | M270火箭炮 | 增程弹 · 子母弹 · 炮兵侦察无人机 · 急速射系统 | ✅ |
| 三角洲部队·精锐 | 游骑兵 | 突击步枪化 · 穿甲弹 · 夜视仪 · 热成像 · 光学伪装 | ✅ |
| M1A2坦克·精锐 | M1A1坦克 | 爆反装甲 · 尾翼稳定穿甲弹 · 猎歼火控 · 热成像瞄准镜 · 战术数据链 | ✅ |
| 阿帕奇直升机·精锐 | AH-64阿帕奇 | 涡扇发动机 · 隐身涂层 · 超视距导弹 · 格斗弹舱 · 外挂武器架 | ✅ |
| **指挥中枢·Boss** | — | 战场通讯 · 数字化单兵 · 激光指示器 · 红外干扰机 | ❌ |
| M4 卡宾特遣班 | 海军陆战队 | 冲锋枪改装 · 全息瞄准镜 · 伪装迷彩 | ✅ |
| 爱国者 PAC-3 发射车 | ZSU-23-4自行高炮 | 防空导弹挂架 · 近炸引信 · 自动化火控 · 激光指示器 | ✅ |
| HIMARS 火箭炮组 | M270火箭炮 | 精确制导炮弹 · 射击计算机 · 炮兵侦察无人机 | ✅ |
| RQ-7 影子无人机班 | AH-64阿帕奇 | 有源相控阵雷达 · 数据链系统 · 无人侦察机 | ✅ |
| EA-18G 电子战小组 | 攻击无人机 | 电子对抗系统 · 数据链系统 · 红外干扰机 | ✅ |
| 艾布拉姆斯Mk.II | M1A1坦克 | 复合装甲 · 主动防护 · 尾翼稳定穿甲弹 · 猎歼火控 · 热成像瞄准镜 | ✅ |

#### 🟣 近未来时代（era=4）

| 敌方卡 | 玩家卡 | mod_pool | 低进化 |
|--------|--------|---------|--------|
| 机械步兵·敌方 | 机械步兵 | 突击步枪化 · 小口径化 · 外骨骼原型 · 热成像 · 战斗兴奋剂 | ✅ |
| 无人机群 | 攻击无人机 | 涡扇发动机 · 隐身涂层 · 有源相控阵雷达 · 数据链系统 | ✅ |
| 机甲步兵·敌方 | 突击机甲 | 复合装甲 · 主动防护 · 猎歼火控 · 战术数据链 · 相位共鸣 | ✅ |
| 悬浮坦克·精锐 | 悬浮坦克 | 倾斜装甲 · 燃气轮机 · 柴油增压引擎 · 战术数据链 | ✅ |
| 幽灵特工·精锐 | 幽灵特工 | 突击步枪化 · 夜视仪 · 热成像 · 光学伪装 · 消音器 | ✅ |
| 巨神机甲·精锐 | 巨神机甲 | 复合装甲 · 爆反装甲 · 尾翼稳定穿甲弹 · 战斗狂热 · 相位护盾 | ✅ |
| **风暴核心·Boss** | — | 相位共鸣 · 相位护盾 · 相位过载 | ❌ |
| 壁垒 | 要塞核心 | 钢筋混凝土装甲 · 自动炮塔 · 雷达天线 · 指挥塔 | ✅ |
| 泰坦Mk.II | 重装机甲 | 复合装甲 · 主动防护 · 尾翼稳定穿甲弹 · 相位护盾 | ✅ |
| 暴风骑士 | 幽灵特工 | 冲锋枪改装 · 外骨骼原型 · 战斗兴奋剂 · 巷战教范 | ✅ |
| 重装母舰 | 空天战斗机 | 涡扇发动机 · 矢量推力 · 隐身涂层 · 有源相控阵雷达 · 超视距导弹 | ✅ |
| 再生骨架 | 攻击无人机 | 涡扇发动机 · 电子对抗系统 · 数据链系统 | ✅ |
| 神经接口突击兵 | 机械步兵 | 小口径化 · 热成像 · 相位护盾发生器 · 电磁脉冲装置 | ✅ |
| HK-07 量产机兵 | 突击机甲 | 爆反装甲 · 猎歼火控 · 相位共鸣 | ✅ |
| HEL-30 激光炮阵列 | 悬浮自行火炮 | 膛线强化 · 精确制导炮弹 · 射击计算机 · 炮兵侦察无人机 | ✅ |
| N-Repair 纳米工程车 | 要塞核心 | 战场急救站 · 弹药补给车 · 战术背心 | ✅ |
| X-9 猎杀者渗透组 | 幽灵特工 | 穿甲弹 · 光学伪装 · 消音器 · 夜视仪 | ✅ |
| 毛瑟 C96 征召兵排 | 机械步兵 | 冲锋枪改装 · 双弹匣并联 · 伪装迷彩 | ✅ |
| Sd.Kfz.251/1 半履带车 | 突击机甲 | 倾斜装甲 · 柴油增压引擎 · 防雷座椅 | ✅ |
| SS-C-1 岸防导弹组 | 悬浮自行火炮 | 增程弹 · 子母弹 · 急速射系统 | ✅ |
| PS-9 相位中继站 | 要塞核心 | 战场通讯 · 数字化单兵 · 红外干扰机 | ✅ |

#### ⚪ 平台卡（全部 low_evo=false）

| 时代 | 敌方卡 | 玩家卡 | mod_pool |
|------|--------|--------|---------|
| 一战 | 一战轻型平台 | MP18突击班 | 冲锋枪改装 · 伪装迷彩 |
| 一战 | 一战中型平台 | 罗尔斯装甲车 | 倾斜装甲 · 柴油增压引擎 |
| 一战 | 一战炮台平台 | MG08机枪巢 | 班用机枪化 · 防弹盾牌 |
| 一战 | 一战雷达平台 | MG08机枪巢 | 炮瞄雷达 · 战场通讯 |
| 一战 | 一战医疗平台 | MP18突击班 | 战场急救包 · 战术背心 |
| 二战 | 二战轻型平台 | 汤普森班 | 冲锋枪改装 · 伪装迷彩 |
| 二战 | 二战中型平台 | 三号坦克 | 倾斜装甲 · 柴油增压引擎 |
| 二战 | 二战重型平台 | 黑豹坦克 | 复合装甲 · 滑膛炮 |
| 二战 | 二战突袭平台 | 汤普森班 | 突击步枪化 · 单兵电台 |
| 二战 | 二战攻城平台 | 81mm迫击炮 | 膛线强化 · 射击计算机 |
| 二战 | 二战要塞平台 | MG42机枪组 | 班用机枪化 · 钢筋混凝土装甲 · 雷场 |
| 冷战 | 冷战轻型平台 | AK-47步兵班 | 突击步枪化 · 伪装迷彩 |
| 冷战 | 冷战中型平台 | T-72坦克 | 爆反装甲 · 燃气轮机 |
| 冷战 | 冷战重型平台 | T-72坦克 | 爆反装甲 · 尾翼稳定穿甲弹 · 热成像瞄准镜 |
| 冷战 | 冷战雷达平台 | 米格-21战机 | 炮瞄雷达 · 自动化火控 |
| 冷战 | 冷战运输平台 | 米格-21战机 | 涡扇发动机 · 战场通讯 |
| 冷战 | 冷战步战车平台 | M2布雷德利 | 爆反装甲 · 深涉渡 |
| 冷战 | 冷战侦察平台 | AK-47步兵班 | 突击步枪化 · 光学伪装 |
| 现代 | 现代轻型平台 | 海军陆战队 | 突击步枪化 · 伪装迷彩 |
| 现代 | 现代中型平台 | M1A1坦克 | 复合装甲 · 猎歼火控 |
| 现代 | 现代雷达平台 | ZSU-23-4自行高炮 | 炮瞄雷达 · 激光指示器 |
| 现代 | 现代自行火炮平台 | M270火箭炮 | 膛线强化 · 射击计算机 |
| 现代 | 现代隐形平台 | 游骑兵 | 突击步枪化 · 光学伪装 |
| 现代 | 现代重型卫戍平台 | M1A1坦克 | 爆反装甲 · 尾翼稳定穿甲弹 · 相位护盾 |
| 近未来 | 近未来轻型平台 | 机械步兵 | 突击步枪化 · 外骨骼原型 |
| 近未来 | 近未来中型平台 | 悬浮坦克 | 倾斜装甲 · 柴油增压引擎 |
| 近未来 | 近未来雷达平台 | 悬浮自行火炮 | 膛线强化 · 激光指示器 |
| 近未来 | 近未来重型平台 | 重装机甲 | 复合装甲 · 主动防护 · 相位共鸣 |

#### ⭐ 特色掉落卡（low_evo=false）

| 敌方卡 | 玩家卡 | mod_pool |
|--------|--------|---------|
| MP18-II 冲锋班 | MP18突击班 | 冲锋枪改装 · 双弹匣并联 · 班用机枪化 |
| 相位刺刀班 | 汤普森班 | 突击步枪化 · 全息瞄准镜 · 夜视仪 |
| 电磁步枪班 | 机械步兵 | 突击步枪化 · 热成像 · 高倍瞄准镜 |
| 巨型光束炮 | M270火箭炮 | 膛线强化 · 精确制导炮弹 · 射击计算机 |
| 雷霆突击班 | 游骑兵 | 突击步枪化 · 战斗兴奋剂 · 巷战教范 |
| 超频矩阵机 | AH-64阿帕奇 | 涡扇发动机 · 矢量推力 · 超视距导弹 |
| 巨型粒子炮 | 重装机甲 | 复合装甲 · 主动防护 · 战斗狂热 · 相位共鸣 |

---

### A.3 时代技术对照规则（防错参考）

| 时代 | 步兵武器 | 防护 | 通讯 | 特殊科技 |
|------|---------|------|------|---------|
| 一战 | 冲锋枪/步枪 | 无防弹 | 无 | 无 |
| 二战 | 冲锋枪/步枪/机枪 | 防弹背心 | 单兵电台 | 夜视仪（后期） |
| 冷战 | 突击步枪 | 防弹背心/插板 | 电台 | 热成像/夜视 |
| 现代 | 突击步枪/小口径 | 防弹背心/插板 | 数字化 | 全频谱光学 |
| 近未来 | 能量武器/智能弹药 | 复合装甲 | 数据链 | 相位科技/外骨骼 |

**各 mod 时代基准（按 prototype 字段判断）：**

| mod_id | 中文 | prototype | 最早时代 |
|--------|------|-----------|---------|
| `inf_01_submachine_gun` | 冲锋枪改装 | MP18/汤普森 | 一战 |
| `inf_02_assault_rifle` | 突击步枪化 | STG44 | 二战 |
| `inf_03_small_caliber` | 小口径化 | M16/5.56mm | 冷战 |
| `inf_07_optical_scope` | 光学瞄准镜 | ACOG 4倍镜 | 现代 |
| `inf_08_holographic` | 全息瞄准镜 | EOTech | 现代 |
| `inf_11_armor_insert` | 防弹插板 | ESAPI碳化硼板 | 现代 |
| `inf_12_body_armor` | 防弹背心 | IOTV模块化 | 现代 |
| `inf_13_helmet_upgrade` | 头盔升级 | MICH→FAST | 现代 |
| `inf_19_radio` | 单兵电台 | PRC-152 | 现代 |
| `inf_20_night_vision` | 夜视仪 | PVS-14 | 冷战末 |
| `inf_21_thermal` | 热成像 | AN/PAS-13 | 现代 |
| `gen_01_comms` | 战场通讯 | SCR-536 | 二战 |
| `gen_02_digital` | 数字化单兵 | 陆地勇士系统 | 现代 |
| `arm_11_fire_control` | 猎歼火控 | 红宝石 | 冷战末 |
| `arm_12_thermal_sight` | 热成像瞄准镜 | M1艾布拉姆斯 | 现代 |
| `art_06_fire_computer` | 射击计算机 | 莱茵金属L55 | 现代 |
| `air_04_aesa` | 有源相控阵雷达 | F-22 | 现代 |

**禁止跨时代放置的改造：**
- 一战/二战：不可使用 `外骨骼原型`、`热成像`、`数字化单兵`、`相位共鸣`
- 一战：不可使用 `防弹插板`、`单兵电台`、`夜视仪`、`突击步枪化`、`光学瞄准镜`（ACOG）
- 二战：不可使用 `热成像`、`小口径化`、`全息瞄准镜`、`防弹插板`（ESAPI）

---

### A.4 修正后的正确配置（含错误标注）

#### 🔵 一战时代修正版

| 敌方卡 | 玩家卡 | mod_pool | 低进化 | 备注 |
|--------|--------|---------|--------|------|
| 步兵班·MP18 | MP18突击班 | 冲锋枪改装 · 双弹匣并联 · 单兵电台 | ✅ | ~~原错误：战场通讯(SCR-536=二战)~~ |
| 步兵班·步枪 | 毛瑟步枪班 | 冲锋枪改装 · 头盔升级 · 伪装迷彩 | ✅ | ~~原错误：突击步枪化(STG44)、光学瞄准镜(ACOG)~~ |
| 机枪巢 | MG08机枪巢 | 班用机枪化 · 防弹背心 · 头盔升级 | ✅ | ~~原错误：防弹盾牌(凯夫拉)~~ |
| 迫击炮组 | 81mm迫击炮组 | 膛线强化 · 增程弹 | ✅ | ~~原错误：弹药运输车(M549火箭)~~ |
| 暴风突击队·精锐 | 暴风突击队 | 冲锋枪改装 · 穿甲弹 · 头盔升级 · 破门工具 | ✅ | ✅ 无错误 |
| 装甲车·精锐 | 罗尔斯装甲车 | 倾斜装甲 · 柴油增压引擎 · 尾翼稳定穿甲弹 | ✅ | ~~原错误：猎歼火控(红宝石)~~ |
| **圣沙蒙坦克·Boss** | FT-17轻型坦克 | 复合装甲 · 尾翼稳定穿甲弹 · 热成像瞄准镜 · 战斗狂热 | ❌ | Boss可超前 |
| 李-恩菲尔德志愿兵排 | 李恩菲尔德班 | 冲锋枪改装 · 头盔升级 · 伪装迷彩 | ✅ | ~~原错误：突击步枪化、光学瞄准镜~~ |
| 劳斯莱斯 Mk.II 装甲车 | 罗尔斯装甲车 | 倾斜装甲 · 柴油增压引擎 | ✅ | ✅ 无错误 |
| 维克斯 .303 机枪阵地 | MG08机枪巢 | 班用机枪化 · 头盔升级 | ✅ | ~~原错误：防弹盾牌~~ |
| 福特 T 型战地救护车 | MP18突击班 | 战场急救包 · 止血带 · 战术背心 | ✅ | ✅ 无错误 |
| MP18 突击队 | MP18突击班 | 冲锋枪改装 · 双弹匣并联 · 伪装迷彩 | ✅ | ~~原错误：夜视仪(PVS-14)~~ |

#### 🟢 二战时代修正版

| 敌方卡 | 玩家卡 | mod_pool | 低进化 | 备注 |
|--------|--------|---------|--------|------|
| 步兵班·汤普森 | 汤普森班 | 冲锋枪改装 · 双弹匣并联 · 单兵电台 | ✅ | ✅ 无错误 |
| 步枪班·加兰德 | 加兰德班 | 突击步枪化 · 头盔升级 · 防弹背心 | ✅ | ~~原错误：防弹背心(ESAPI=2000s)~~ |
| MG42机枪组·敌方 | MG42机枪组 | 班用机枪化 · 防弹背心 · 防弹盾牌 | ✅ | ~~原错误：防弹插板(ESAPI)~~ |
| 反坦克组·精锐 | 铁拳反坦克组 | 穿甲弹 · 防弹背心 · 高倍瞄准镜 | ✅ | ✅ 无错误 |
| 伞兵精英 | 汤普森班 | 冲锋枪改装 · 夜视仪 · 消音器 | ✅ | ✅ 无错误 |
| 黑豹坦克·精锐 | 黑豹坦克 | 复合装甲 · 滑膛炮 · 热成像瞄准镜 · 战术数据链 | ✅ | ~~注：热成像=冷战，但精锐可超前~~ |
| **虎王坦克·Boss** | 虎式坦克 | 复合装甲 · 主动防护 · 尾翼稳定穿甲弹 · 自动装弹机 · 战斗狂热 | ❌ | Boss可超前 |
| M1 加兰德伞兵班 | 汤普森班 | 突击步枪化 · 单兵电台 · 战场通讯 | ✅ | ~~原错误：数字化单兵(陆地勇士)~~ |
| 黄蜂 Hummel 自行火炮 | 81mm迫击炮 | 膛线强化 · 增程弹 · 射击计算机 | ✅ | ✅ 无错误 |
| PaK 40 反坦克炮组 | 铁拳反坦克组 | 膛线强化 · 射击计算机 · 无人侦察机 | ✅ | ~~注：无人机=现代，但精英可超前~~ |
| GMC 2.5t 补给卡车 | 汤普森班 | 战场急救包 · 战术背心 | ✅ | ~~原错误：弹药补给车(M113)~~ |
| 毛瑟 Kar98k 狙击组 | 加兰德班 | 光学瞄准镜 · 夜视仪 · 高倍瞄准镜 | ✅ | ~~原错误：热成像(AN/PAS-13)~~ |
