# 敌方战斗卡情报系统 v21.0 — 详细执行计划

> 状态：待执行
> 日期：2026-08-27
> 前置条件：`data/enemy_card_mod_map.gd` ✅ / `data/intel_mod_thresholds.gd` ✅ 已完成

---

## Phase 1：修改 `scripts/systems/intel_manual.gd`

### 1.1 添加常量（放在现有常量块后）

```gdscript
## v21.0: 部署情报增量（固定，不衰减）
const DEPLOY_BASE_INTEL: float = 0.04
const DEPLOY_MIN_MOD_POINTS: int = 2
const DEPLOY_MAX_MOD_POINTS: int = 5

## v21.0: 商店购卡直接设定 base_progress
const SHOP_PURCHASED_BASE_PROGRESS: float = 0.5
```

### 1.2 修改 `IntelEntry` 内部类（约第 79-123 行）

**旧字段（保留，迁移兼容）：**
```gdscript
var intel_progress: float = 0.0          # v6.7 单维度 → v21.0 迁移为 base_progress
```

**新增字段（在 `migrated` 之后插入）：**
```gdscript
## v21.0: 双轨情报
var base_progress: float = 0.0           # 总体情报进度（0~1.0），替代原 intel_progress
var deploy_count: int = 0                # 部署该敌方卡的次数（主要情报来源）
var card_mod_intels: Dictionary = {}     # archetype_id -> {mod_id: int} 累积点数
var unlocked_mod_ids: Array[String] = [] # 已解锁的 mod_id 列表（派生缓存）
```

**修改 `to_dict()`（约第 95-107 行）：**
```gdscript
func to_dict() -> Dictionary:
    return {
        "card_id": card_id,
        "intel_progress": intel_progress,        # 保留用于 v2→v3 迁移
        "base_progress": base_progress,          # v21.0 新增
        "deploy_count": deploy_count,             # v21.0 新增
        "card_mod_intels": card_mod_intels.duplicate(), # v21.0 新增
        "unlocked_mod_ids": unlocked_mod_ids.duplicate(), # v21.0 新增
        "intel_dimensions": intel_dimensions.duplicate(),
        "revealed_tiers": revealed_tiers.duplicate(),
        "is_unlocked": is_unlocked,
        "first_encounter": first_encounter,
        "defeat_count": defeat_count,
        "recon_bonus": recon_bonus,
        "decompose_bonus": decompose_bonus,
        "migrated": migrated,
    }
```

**修改 `from_dict()`（约第 109-123 行）：**
```gdscript
static func from_dict(data: Dictionary) -> IntelEntry:
    var entry := IntelEntry.new(data.get("card_id", ""))
    entry.intel_progress = clampf(data.get("intel_progress", 0.0), 0.0, 1.0)
    # v21.0: 读取新字段（旧档缺失则为默认值）
    entry.base_progress = clampf(data.get("base_progress", 0.0), 0.0, 1.0)
    entry.deploy_count = int(data.get("deploy_count", 0))
    if data.has("card_mod_intels") and data["card_mod_intels"] is Dictionary:
        entry.card_mod_intels = (data["card_mod_intels"] as Dictionary).duplicate()
    if data.has("unlocked_mod_ids") and data["unlocked_mod_ids"] is Array:
        entry.unlocked_mod_ids.assign(data["unlocked_mod_ids"] as Array)
    entry.is_unlocked = data.get("is_unlocked", false)
    entry.first_encounter = data.get("first_encounter", false)
    entry.defeat_count = int(data.get("defeat_count", 0))
    entry.recon_bonus = clampf(data.get("recon_bonus", 0.0), 0.0, 1.0)
    entry.decompose_bonus = clampf(data.get("decompose_bonus", 0.0), 0.0, 1.0)
    entry.migrated = data.get("migrated", false)
    if data.has("intel_dimensions") and data["intel_dimensions"] is Dictionary:
        entry.intel_dimensions = (data["intel_dimensions"] as Dictionary).duplicate()
    if data.has("revealed_tiers") and data["revealed_tiers"] is Dictionary:
        entry.revealed_tiers = (data["revealed_tiers"] as Dictionary).duplicate()
    return entry
```

### 1.3 添加 `register_deploy()` 函数

在 `register_decompose()` 函数之后（约第 341 行后）插入：

```gdscript
## v21.0: 部署敌方卡获得 base intel + mod 点数（稳定成长来源，不衰减）
func register_deploy(archetype_id: String, enemy_type: String = "") -> Dictionary:
    var entry := _ensure_entry(archetype_id)
    entry.deploy_count += 1
    if not enemy_type.is_empty():
        _card_to_enemy_type[archetype_id] = enemy_type
    # base intel: +4% 固定
    var base_delta: float = _add_intel(archetype_id, DEPLOY_BASE_INTEL, "deploy")
    # 如果 base 已满，直接用旧 intel_progress 同步 base_progress
    _sync_base_from_intel(archetype_id)
    # mod 点数: 随机 2~5
    var mod_delta: int = randi_range(DEPLOY_MIN_MOD_POINTS, DEPLOY_MAX_MOD_POINTS)
    _add_mod_points(archetype_id, mod_delta)
    return {"base_intel": base_delta, "mod_points": mod_delta}

## v21.0: 商店购卡直接设定 base_progress = 50%
func set_shop_purchased_base_progress(archetype_id: String) -> void:
    var entry := _ensure_entry(archetype_id)
    if entry.base_progress < SHOP_PURCHASED_BASE_PROGRESS:
        var old_val: float = entry.base_progress
        entry.base_progress = SHOP_PURCHASED_BASE_PROGRESS
        # 同步到 intel_progress（向后兼容）
        if entry.intel_progress < old_val + SHOP_PURCHASED_BASE_PROGRESS:
            entry.intel_progress = old_val + SHOP_PURCHASED_BASE_PROGRESS
```

### 1.4 添加 mod 点数管理函数

在 `_add_intel()` 之后（约第 260 行后）插入：

```gdscript
## v21.0: 向某卡的某 mod 累积点数，达标自动解锁
func _add_mod_points(archetype_id: String, points: int) -> void:
    var entry := _ensure_entry(archetype_id)
    if not entry.card_mod_intels.has(archetype_id):
        entry.card_mod_intels[archetype_id] = {}
    var pool: Dictionary = entry.card_mod_intels[archetype_id]
    # 获取该卡可解锁的 mod 列表
    var mod_list: Array[String] = EnemyCardModMap.get_unlockable_mods(archetype_id)
    if mod_list.is_empty():
        return
    # 随机选一个未解锁的 mod 加点
    var available: Array[String] = []
    for mid in mod_list:
        if not pool.has(mid) or pool[mid] < IntelModThresholds.get_threshold(
            ModificationRegistry.get_data(mid).get("rarity", "common")):
            available.append(mid)
    if available.is_empty():
        return
    var chosen: String = available[randi() % available.size()]
    pool[chosen] = int(pool.get(chosen, 0)) + points
    # 检查是否达标解锁
    _check_mod_unlock(archetype_id, chosen)

## v21.0: 检查某 mod 是否达标解锁
func _check_mod_unlock(archetype_id: String, mod_id: String) -> void:
    var entry := _ensure_entry(archetype_id)
    var pool: Dictionary = entry.card_mod_intels.get(archetype_id, {})
    var points: int = int(pool.get(mod_id, 0))
    var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
    if mod_data.is_empty():
        return
    var rarity: String = String(mod_data.get("rarity", "common"))
    var threshold: int = IntelModThresholds.get_threshold(rarity)
    if points >= threshold and not entry.unlocked_mod_ids.has(mod_id):
        entry.unlocked_mod_ids.append(mod_id)
```

### 1.5 添加查询函数

在现有查询接口块末尾（约第 448 行后）插入：

```gdscript
## v21.0: 获取 base_progress（0~1.0）
func get_base_progress(card_id: String) -> float:
    if _entries.has(card_id):
        return _entries[card_id].base_progress
    return 0.0

## v21.0: 获取某卡某 mod 的累积点数
func get_mod_intel_points(archetype_id: String, mod_id: String) -> int:
    if not _entries.has(archetype_id):
        return 0
    var entry: IntelEntry = _entries[archetype_id]
    var pool: Dictionary = entry.card_mod_intels.get(archetype_id, {})
    return int(pool.get(mod_id, 0))

## v21.0: 获取某卡所有 mod 点数
func get_all_mod_intel_points(archetype_id: String) -> Dictionary:
    if not _entries.has(archetype_id):
        return {}
    var entry: IntelEntry = _entries[archetype_id]
    return entry.card_mod_intels.get(archetype_id, {}).duplicate()

## v21.0: 获取某卡已解锁的 mod 列表
func get_unlocked_mod_ids(archetype_id: String) -> Array[String]:
    if not _entries.has(archetype_id):
        return []
    return _entries[archetype_id].unlocked_mod_ids.duplicate()

## v21.0: 检查某 mod 是否已解锁
func is_mod_unlocked(archetype_id: String, mod_id: String) -> bool:
    if not _entries.has(archetype_id):
        return false
    return _entries[archetype_id].unlocked_mod_ids.has(mod_id)

## v21.0: 获取某 mod 解锁进度（0.0~1.0）
func get_mod_unlock_progress(archetype_id: String, mod_id: String) -> float:
    var points: int = get_mod_intel_points(archetype_id, mod_id)
    var mod_data: Dictionary = ModificationRegistry.get_data(mod_id)
    if mod_data.is_empty():
        return 0.0
    var rarity: String = String(mod_data.get("rarity", "common"))
    var threshold: int = IntelModThresholds.get_threshold(rarity)
    return clampf(float(points) / float(threshold), 0.0, 1.0)

## v21.0: 部署次数
func get_deploy_count(archetype_id: String) -> int:
    if _entries.has(archetype_id):
        return _entries[archetype_id].deploy_count
    return 0
```

### 1.6 修改迁移函数 `_migrate_v2_to_v3()`（约第 198 行）

在迁移结束后增加 base_progress 同步：

```gdscript
func _migrate_v2_to_v3(entry: IntelEntry) -> void:
    # ... 现有迁移逻辑不变 ...
    if not entry.intel_dimensions.is_empty():
        var merged: float = IntelDimensions.merge_legacy_dimensions(entry.intel_dimensions)
        entry.intel_progress = maxf(entry.intel_progress, merged)
        entry.intel_dimensions = {}
        entry.revealed_tiers = {}
    entry.migrated = true
    if entry.intel_progress >= 1.0:
        entry.is_unlocked = true
    ## v21.0: 同步 base_progress
    entry.base_progress = entry.intel_progress
```

### 1.7 修改 `_calc_tier()`（约第 224 行）

```gdscript
func _calc_tier(progress: float) -> int:
    if progress >= 1.0:  return TIER_EVOLUTION
    if progress >= 0.75: return TIER_WEAKNESS
    if progress >= 0.50: return TIER_DETAIL_STATS
    if progress >= 0.25: return TIER_BASIC_STATS
    return TIER_NONE
```
> 保持不变，因为 `get_intel_progress()` 仍读 `intel_progress` 字段（向后兼容），
> UI 读 base_progress 则用新函数 `get_base_progress()`。

### 1.8 添加 preload 声明

在文件顶部常量块后添加：
```gdscript
const EnemyCardModMap = preload("res://data/enemy_card_mod_map.gd")
const IntelModThresholds = preload("res://data/intel_mod_thresholds.gd")
const ModificationRegistry = preload("res://scripts/systems/modification_registry.gd")
```

---

## Phase 2：修改 `scripts/systems/intel_discovery_manager.gd`

### 2.1 在 `generate_battle_intel_harvest()` 中增加部署统计

在循环结束后（约第 207 行，信号恢复之前）插入：

```gdscript
    ## v21.0: 统计部署（玩家上阵过的敌方卡形态）
    # 注：部署统计由 battle_spawn_system 调用，此处仅记录首次遭遇+击败
    # deploy_count 的精确计数在 construct_unit_deploy 中由 intel_manual.register_deploy() 触发
```

### 2.2 添加新信号

在信号块后（约第 26 行）插入：
```gdscript
## v21.0: mod 点数增加 signal(archetype_id, mod_id, new_points, threshold)
signal mod_points_gained(archetype_id: String, mod_id: String, new_points: int, threshold: int)
## v21.0: base_progress 变化 signal(archetype_id, old_val, new_val)
signal base_progress_changed(archetype_id: String, old_val: float, new_val: float)
```

### 2.3 连接 IntelManual 新信号

在 `_ready()` 中（约第 52 行）增加连接：
```gdscript
    if im.has_signal("mod_points_gained"):
        im.mod_points_gained.connect(_on_mod_points_gained)
    if im.has_signal("base_progress_changed"):
        im.base_progress_changed.connect(_on_base_progress_changed)
```

### 2.4 添加信号回调

在文件末尾（`_save_state` 之后）添加：
```gdscript
## v21.0: mod 点数增加回调
func _on_mod_points_gained(archetype_id: String, mod_id: String, new_points: int, threshold: int) -> void:
    if new_points >= threshold:
        # 触发全解锁通知（base >= 100% 时绕过点数检查）
        pass

## v21.0: base_progress 变化回调
func _on_base_progress_changed(archetype_id: String, old_val: float, new_val: float) -> void:
    # 低进化触发（base >= 50%）
    if new_val >= 0.5 and old_val < 0.5:
        SignalBus.enemy_low_evolution_available.emit(archetype_id)
```

---

## Phase 3：修改 `managers/instance_registry.gd`

### 3.1 在 `_register_clone()` 末尾（约第 118 行）增加商店购卡 hook

在 `instance_created.emit(...)` 之后、`if get_instances_by_card_id...` 之前插入：

```gdscript
    # v21.0: 商店购卡 → 直接给 50% base_progress
    var im: Node = get_node_or_null("/root/IntelManual")
    if im and im.has_method("set_shop_purchased_base_progress"):
        im.set_shop_purchased_base_progress(canonical_id)
```

---

## Phase 4：修改 `managers/evolution/card_evolution_manager.gd`

### 4.1 新增低进化条件检查

在 `can_evolve_blueprint()` 函数的 conditions 数组构建处（约第 141 行），在 `power` 条件之后插入：

```gdscript
    ## v21.0: 低进化条件检查（base_progress >= 50%）
    var im: Node = _get_autoload_node("IntelManual")
    var base_prog: float = 0.0
    if im and im.has_method("get_base_progress"):
        base_prog = im.get_base_progress(card_id)
    var evo_map: Node = _get_autoload_node("EnemyCardModMap")
    var can_low_evo: bool = false
    if evo_map and evo_map.has_method("can_low_evolve"):
        can_low_evo = evo_map.can_low_evolve(target_card_id)
    conditions.append({
        "key": "base_progress",
        "met": base_prog >= 0.5 and can_low_evo,
        "current_text": "%.0f%%" % (base_prog * 100),
        "required_text": "50%%",
        "detail": "部署/击败该敌方卡形态积累情报，达到 50%% 后可低进化为该形态",
    })
```

### 4.2 修改完整进化条件

在 `mods` 条件之后（约第 223 行），增加 base >= 100% 检查：

```gdscript
    ## v21.0: 完整进化条件（base_progress >= 100%）
    conditions.append({
        "key": "base_full",
        "met": base_prog >= 1.0,
        "current_text": "%.0f%%" % (base_prog * 100),
        "required_text": "100%%",
        "detail": "完全掌握该敌方卡情报（100%% base intel）解锁完整进化路径",
    })
```

---

## Phase 5：修改 UI 文件

### 5.1 `scenes/ui/intelligence_hub_panel.gd` — Tab 3 重写

**步骤：**
1. 找到 `_setup_intel_tab()` 函数（约第 400 行）
2. 重写 Tab 3 内容构建逻辑，改为：
   - 遍历 `EnemyCardModMap.get_all_archetype_ids()`
   - 对每张卡：显示 `base_progress` 进度条 + 部署次数
   - 展开显示 mod_pool 列表，每个 mod 显示进度条（当前点数 / 阈值点数）
   - 已解锁的 mod 高亮显示

**伪代码结构：**
```gdscript
func _setup_intel_tab() -> void:
    # 创建 VBoxContainer
    # 对每个 archetype_id in EnemyCardModMap.get_all_archetype_ids():
    #   - 获取敌方卡名称（EnemyArchetypes）
    #   - 创建行：名称 + base_progress ProgressBar + 部署次数标签
    #   - 若 base >= 0.5，显示"低进化可用"标签
    #   - 展开 mod 列表：
    #     - 对每个 mod_id in mod_pool:
    #       - 获取 mod 数据（ModificationRegistry）
    #       - 获取当前点数和阈值
    #       - 创建 sub-row：mod名 + 进度条 + 点数标签
    #       - 若已解锁，高亮
```

### 5.2 `scenes/ui/intel_harvest_display.gd` — 结算界面

**步骤：**
1. 在 `_create_card_entry()` 函数中（约第 114 行），现有单维度进度条之后：
2. 新增 base_progress 独立进度条
3. 新增 mod 点数增益条目（若有 mod_points 增长）

**修改点：**
```gdscript
func _create_card_entry(entry: Dictionary) -> PanelContainer:
    # ... 现有代码（name_row, icon 等）...
    
    ## v21.0: 新增 base_progress 进度条
    var base_prog: float = entry.get("base_progress", 0.0)
    var base_bar := ProgressBar.new()
    base_bar.value = base_prog * 100
    base_bar.show_percentage = false
    # 样式与普通 intel bar 相同
    card_box.add_child(base_bar)
    
    ## v21.0: 新增 mod 点数条目
    var mod_points_data: Dictionary = entry.get("mod_points", {})
    for mid in mod_points_data.keys():
        var lbl := Label.new()
        lbl.text = "  ▸ +%d mod点数 (%s)" % [mod_points_data[mid], mid]
        lbl.add_theme_font_size_override("font_size", 11)
        lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1.0))
        card_box.add_child(lbl)
```

---

## Phase 6：旧档迁移验证

### 6.1 迁移逻辑

运行游戏后检查：
- 旧存档 `intel_progress` → 自动填充到 `base_progress`
- `card_mod_intels` = `{}`（全新开始，需重新积累）
- `unlocked_mod_ids` = `[]`
- `deploy_count` ≈ `defeat_count`（近似值）

### 6.2 测试清单

| 场景 | 预期结果 |
|------|---------|
| 新游戏 | 所有 base_progress = 0，card_mod_intels = {} |
| 商店购买敌方卡 | base_progress = 0.5，可低进化 |
| 击败敌方卡 1 次 | base += ~3%，mod 点数 +1~2 |
| 部署敌方卡 1 次 | base += 4%，mod 点数 +2~5 |
| base 达到 50% | 低进化可用，进度条显示 "50%" |
| base 达到 100% | 所有 mod 自动解锁，完整进化可用 |
| 某个 mod 达标 | unlocked_mod_ids 包含该 mod_id |

---

## 依赖关系

```
Phase 1 (intel_manual.gd)
    ↓
Phase 2 (intel_discovery_manager.gd) ──┐
    ↓                                    ├──→ Phase 5 (UI)
Phase 3 (instance_registry.gd) ─────────┘
    ↓
Phase 4 (card_evolution_manager.gd)
    ↓
Phase 6 (迁移验证)
```

---

## 文件改动清单

| # | 文件 | 改动类型 | 预估行数 |
|---|------|---------|---------|
| 1 | `scripts/systems/intel_manual.gd` | 核心重写 | ~80 行新增 |
| 2 | `scripts/systems/intel_discovery_manager.gd` | 小改 | ~20 行新增 |
| 3 | `managers/instance_registry.gd` | 小改 | ~5 行新增 |
| 4 | `managers/evolution/card_evolution_manager.gd` | 小改 | ~15 行新增 |
| 5 | `scenes/ui/intelligence_hub_panel.gd` | Tab 3 重写 | ~60 行新增 |
| 6 | `scenes/ui/intel_harvest_display.gd` | 小改 | ~20 行新增 |

**已有文件（无需修改）：**
- `data/enemy_card_mod_map.gd` ✅ 109 条全部配好 mod_pool
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
