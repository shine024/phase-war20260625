# 曲射/空射战斗卡入场后游戏卡顿 — 根因诊断与修复计划

> 日期：2026-06-11
> 范围：曲射(INDIRECT)、空射(AERIAL) 战斗卡入场后游戏帧率骤降

---

## 一、根因分析

### 🔴 问题1：新旧武器类型枚举冲突 → 批处理路由错误（主因）

项目存在**新旧两套武器类型枚举混用**，导致曲射/空射弹道无法正确进入批处理系统。

**新枚举** (`GameConstants.WeaponType`)：
```
DIRECT = 0, INDIRECT = 1, AERIAL = 2, SUPPORT = 3
```

**旧枚举** (bullet.gd 内的 0~11 物理武器 ID)：
```
0=SMG, 1=RIFLE, 2=MG, 3=ROCKET, 4=PISTOL, 5=SHOTGUN, 6=SNIPER, 7=FLAK, 8=LASER, 9=MISSILE, 10=OMEGA_CANNON, 11=RAIL_CANNON
```

**冲突位置**：`construct_unit_ai.gd` → `do_attack_with_damage()`

```gdscript
# 轻武器批处理：用的是【旧ID】
if u.is_player and wt in [0, 4, 1, 2]:    # SMG=0, PISTOL=4, RIFLE=1, MG=2
    player_projectile_batch.fire(...)
    return

# 曲射批处理：用的也是【旧ID】
if u.is_player and wt in [3, 7, 9]:       # ROCKET=3, FLAK=7, MISSILE=9
    player_indirect_batch.fire(...)
    return
```

**但 `WeaponResource.weapon_type` 存的是【新枚举】值**（INDIRECT=1, AERIAL=2）。

结果：
- 曲射单位 wt=1（新枚举 INDIRECT） → 命中 `[0,4,1,2]` → **错误地走了轻武器直线弹道批处理**
- 空射单位 wt=2（新枚举 AERIAL） → 不命中任何批处理条件 → **每个子弹都创建独立 Bullet 节点**
- 如果 `_weapon_cfgs` 字典存的是旧 ID（如 3/7/9），wt=3/7/9 → 尝试走 `player_indirect_batch`，但如果该批处理因 bug 为 null → 同样回退到独立 Bullet

**后果**：曲射/空射单位每发子弹都创建独立 `_process` 节点（Bullet），弹道飞行 0.6~1.4 秒不释放，数量快速累积。

---

### 🔴 问题2：`end_battle()` 未清理 `player_indirect_batch`

**文件**：`managers/battle/battle_manager.gd` 第 226~228 行

```gdscript
func end_battle(player_won: bool) -> void:
    ...
    _cleanup_spatial_grid()
    _cleanup_enemy_projectile_batch()
    _cleanup_player_projectile_batch()
    # ❌ 缺少: _cleanup_player_indirect_batch()
```

`player_indirect_batch` 在战斗结束后不被清理，其 `_physics_process` 持续运行。下一场战斗 `start_battle()` 虽然会调用 `_setup_player_indirect_batch()`（内部先 `_cleanup_player_indirect_batch()`），但两场战斗之间残留的批处理节点引用了已释放的目标节点，每帧执行无效的 Dictionary 遍历。

---

### 🟡 问题3：多武器同时开火 × AOE 伤害信号链过重

`_process_multi_weapons()` 为每个武器槽独立运行攻击状态机。曲射/空射卡通常有 3 个武器槽：

- 每个武器约 0.35s 一次射击
- 3 武器 × (1 / 0.35) ≈ **8.5 发/秒/单位**

每发曲射弹（ROCKET/MISSILE）命中时触发链：
1. `_get_aoe_targets()` — 空间网格查询，返回 3~5 个目标
2. 对每个溅射目标调用 `target.take_damage()` → 触发信号链：
   - `SignalBus.unit_damaged.emit()` → `_on_unit_damaged_combat_feedback()` → `CombatFeedback.show_damage()` → **创建 Label + Tween**
   - `_update_hp_bar()` → UI 更新
3. 创建爆炸特效 Sprite2D + Tween（`_spawn_impact_explosion`）

**8.5 命中/秒 × 3~5 溅射目标 = 25~42 个 damage 事件/秒/单位**

如果有 2 个曲射单位在场：**50~84 个 damage 事件/秒**，每个事件创建 Label + Sprite2D + 2 个 Tween。

---

### 🟡 问题4：弹道积压

曲射/空射单位 `attack_range` 通常 800~2000px，弹道飞行时间 0.6~1.4 秒。同时空中弹道数量远超直射单位：

| 类型 | 射程 | 飞行时间 | 在飞弹道数（每单位） |
|------|------|----------|----------------------|
| 直射 | ~300px | ~0.4s | ≈1 |
| 曲射 | ~1200px | ~1.2s | ≈10 |

未批处理时，每个在飞弹道是一个独立 `_process` 节点，每帧计算位置。3 武器 × 10 在飞 = 30 个活跃 Bullet 节点/曲射单位。

---

### 🟡 问题5：曲射批处理的 `_sync_multimesh_layers` 每帧重建

**文件**：`simple_indirect_projectile_batch.gd` → `_physics_process`

即使弹道为空也调用 `_sync_multimesh_layers()`，每帧遍历 `_proj` 数组构建 `counts` 字典再写入 MultiMesh。弹道多时（≥50），Dictionary 遍历 + 多次 `set_instance_transform_2d` 开销显著。

---

## 二、涉及文件清单

| 文件 | 角色 |
|------|------|
| `scripts/battle/construct_unit_ai.gd` | 攻击逻辑，批处理路由（**核心问题**） |
| `managers/battle/battle_manager.gd` | 批处理生命周期管理 |
| `managers/battle/simple_indirect_projectile_batch.gd` | 曲射弹道批处理 |
| `managers/battle/simple_player_projectile_batch.gd` | 玩家轻武器批处理 |
| `scenes/units/bullet.gd` | 独立子弹节点（回退路径） |
| `scripts/weapon_projectile_vfx.gd` | 特效对象池 |
| `scripts/combat_feedback.gd` | 伤害数字显示 |
| `resources/game_constants.gd` | 新 WeaponType 枚举定义 |
| `resources/weapon_resource.gd` | WeaponResource.weapon_type 字段 |

---

## 三、修复计划

### 第一批：核心路由修复（P0 — 必须先做）

#### Fix-1：统一武器类型路由
**文件**：`scripts/battle/construct_unit_ai.gd` → `do_attack_with_damage()`

将批处理路由改为基于新枚举值：

```gdscript
# ---- 新路由：基于 GameConstants.WeaponType ----

# 直射 → 轻武器批处理
if u.is_player and wt == GC.WeaponType.DIRECT:
    if BattleManager and BattleManager.player_projectile_batch:
        BattleManager.player_projectile_batch.fire(
            u.global_position, u.target, damage, 0, u, u.stats, miss
        )
        return

# 曲射/空射 → 曲射批处理
if u.is_player and wt in [GC.WeaponType.INDIRECT, GC.WeaponType.AERIAL]:
    if BattleManager and BattleManager.player_indirect_batch:
        BattleManager.player_indirect_batch.fire(
            u.global_position, u.target, damage, wt, u, u.stats, miss, w_name
        )
        return
```

**同时**需要在 `simple_indirect_projectile_batch.gd` 的 `_BATCH_WEAPON_TYPES` 和 `_WEAPON_CONFIG` 中添加新枚举值的映射：

```gdscript
# 新增 INDIRECT=1 和 AERIAL=2 的配置
const _BATCH_WEAPON_TYPES: Array[int] = [
    3,  # ROCKET (旧)
    7,  # FLAK (旧)
    9,  # MISSILE (旧)
    1,  # INDIRECT (新枚举)
    2,  # AERIAL (新枚举)
]

const _WEAPON_CONFIG: Dictionary = {
    3: {"speed": 420.0, "max_dist": 2000.0, "explosion_radius": 40.0},
    7: {"speed": 520.0, "max_dist": 1500.0, "explosion_radius": 36.0},
    9: {"speed": 380.0, "max_dist": 2300.0, "explosion_radius": 55.0},
    1: {"speed": 420.0, "max_dist": 2000.0, "explosion_radius": 40.0},  # INDIRECT
    2: {"speed": 520.0, "max_dist": 2000.0, "explosion_radius": 36.0},  # AERIAL
}
```

`_make_layer` 中也需要为新类型提供贴图回退。

#### Fix-2：`end_battle` 补充间接批处理清理
**文件**：`managers/battle/battle_manager.gd` → `end_battle()`

```gdscript
func end_battle(player_won: bool) -> void:
    ...
    _cleanup_spatial_grid()
    _cleanup_enemy_projectile_batch()
    _cleanup_player_projectile_batch()
    _cleanup_player_indirect_batch()   # ← 添加这行
```

---

### 第二批：伤害信号链节流（P1）

#### Fix-3：AOE 溅射目标数上限
**文件**：`managers/battle/simple_indirect_projectile_batch.gd` → `_apply_hit()`

```gdscript
const MAX_AOE_TARGETS_PER_HIT: int = 4

var targets: Array = _get_aoe_targets(hit_pos, explosion_r, tgt)
for target in targets.slice(0, MAX_AOE_TARGETS_PER_HIT):
    ...
```

**同样**修改 `scenes/units/bullet.gd` → `_get_aoe_damage_targets()` 返回后截断。

#### Fix-4：CombatFeedback 全局节流
**文件**：`scripts/combat_feedback.gd`

添加全局每帧最大伤害数字数量：

```gdscript
const MAX_ACTIVE_LABELS: int = 20
static var _active_count: int = 0

static func show_damage(pos, amount, target, ...):
    if _active_count >= MAX_ACTIVE_LABELS:
        return
    _active_count += 1
    ...  # Tween 结束时 _active_count -= 1
```

#### Fix-5：AOE 溅射伤害信号抑制
**文件**：`scenes/units/bullet.gd` → `_on_hit()` 的 AOE 循环

溅射伤害不 emit `unit_damaged` 信号（或使用 `_skip_feedback` 参数），避免每次溅射都创建伤害数字。只对主目标显示伤害数字。

---

### 第三批：弹道性能优化（P2）

#### Fix-6：曲射批处理空弹道跳过同步
**文件**：`managers/battle/simple_indirect_projectile_batch.gd` → `_physics_process()`

```gdscript
if _proj.is_empty():
    # 空时完全跳过 MultiMesh 同步
    for wt in _BATCH_WEAPON_TYPES:
        var mmi = _layers[wt]
        if mmi and mmi.multimesh and mmi.multimesh.instance_count > 0:
            mmi.multimesh.instance_count = 0
    return
```

#### Fix-7：减少多武器曲射单位的攻击频率
**文件**：`scripts/battle/construct_unit_ai.gd` → `_process_multi_weapons()`

为 INDIRECT/AERIAL 武器类型添加最小攻击间隔限制（如 0.5s），避免 3 槽同时高速射击：

```gdscript
# 曲射/空射武器最小攻击间隔
if w_wt in [GC.WeaponType.INDIRECT, GC.WeaponType.AERIAL]:
    timing["windup"] = maxf(timing.get("windup", 0.0), 0.15)
    timing["cooldown"] = maxf(timing.get("cooldown", 0.0), 0.25)
```

---

### 第四批：验证与监控（P3）

#### Fix-8：添加性能监控日志
在 `simple_indirect_projectile_batch.gd` 的 `_physics_process` 中添加：

```gdscript
# 每 5 秒打印一次弹道数量（仅调试）
if Engine.get_frames_drawn() % 300 == 0 and _proj.size() > 20:
    push_warning("[IndirectBatch] 高弹道数: %d" % _proj.size())
```

#### Fix-9：确认 `_weapon_cfgs` 中 weapon_type 的一致性
检查 `construct_unit.gd` → `setup()` 中 `_weapon_cfgs` 的 `weapon_type` 字段存的是新枚举还是旧 ID。确保与批处理路由一致。

---

## 四、修复优先级排序

| 优先级 | 编号 | 修复内容 | 预期效果 |
|--------|------|----------|----------|
| 🔴 P0 | Fix-1 | 统一武器类型路由 | 曲射/空射弹道进入批处理，消除 Bullet 节点堆积 |
| 🔴 P0 | Fix-2 | `end_battle` 清理间接批处理 | 消除战斗间残留节点 |
| 🟡 P1 | Fix-3 | AOE 目标数上限 | 减少 50%+ 溅射 damage 事件 |
| 🟡 P1 | Fix-4 | CombatFeedback 全局节流 | 限制伤害数字节点数量 |
| 🟡 P1 | Fix-5 | 溅射伤害信号抑制 | 避免每帧 40+ 个 Label 创建 |
| 🟢 P2 | Fix-6 | 空弹道跳过同步 | 减少无效 MultiMesh 操作 |
| 🟢 P2 | Fix-7 | 曲射武器最小间隔 | 降低弹道生成速率 |
| 🟢 P3 | Fix-8 | 性能监控日志 | 方便后续定位 |
| 🟢 P3 | Fix-9 | weapon_type 一致性检查 | 防止数据层混乱 |

---

## 五、验证步骤

1. 放置 1 个曲射单位 + 3 个敌方单位进入战斗
2. 观察 Godot Profiler → Frame Time 是否稳定在 16ms 以内
3. 观察 `ObjectPoolManager` 活跃 Bullet 数量（应接近 0，全部走批处理）
4. 检查 `player_indirect_batch._proj.size()` 是否在合理范围（<20）
5. 战斗结束后确认 `player_indirect_batch` 节点已被清理
6. 放置 2 个曲射 + 1 个空射单位，验证混合场景无卡顿
