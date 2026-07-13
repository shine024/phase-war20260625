# 敌方相位师出兵疲劳阶梯到停止

## 目标
把现有「疲劳后就变慢但永远继续」改为「三档疲劳阶梯 → 彻底枯竭停止」，给玩家明确的「熬过兵力潮就赢」终局，解决长战斗消耗战问题。

## 改动文件
**仅 1 个主文件 + 1 个新增测试**：
- `scenes/units/enemy_phase_field_driver.gd`（核心改动）
- `tests/phase_master_fatigue_smoke.gd`（新增，SceneTree 模式验证阶梯逻辑）

## 阶梯模型（按 unit_limit 倍数动态派生）

复用 v6.2 已有的 `_total_spawned` / `_spawn_fatigued` / `_record_spawn_and_check_fatigue`，从单档扩展为三档：

| 阶梯 | 累计产兵范围 | 产兵间隔 | 状态 |
|------|-------------|---------|------|
| 正常 | 0 ~ `_tier1_cap` | `spawn_interval`（3~6s） | 战力充沛 |
| 轻度疲劳 | `_tier1_cap` ~ `_tier2_cap` | 18s | 兵力告急 |
| 重度疲劳 | `_tier2_cap` ~ `_exhaustion_cap` | 30s | 兵力枯竭 |
| 枯竭停止 | ≥ `_exhaustion_cap` | —（停止） | 弹尽粮绝 |

**阈值按 unit_limit 倍数（setup 时缓存，因为 _unit_limit 会被相位仪 capacity 和槽位数钳制）**：
```
_tier1_cap        = _unit_limit × 2   # 轻度疲劳阈值
_tier2_cap        = _unit_limit × 4   # 重度疲劳阈值
_exhaustion_cap   = _unit_limit × 6   # 彻底枯竭阈值
```
- 默认 unit_limit=5：正常 0-10，轻度 10-20，重度 20-30，≥30 停（**总兵力 30**）
- 高容量 unit_limit=6：正常 0-12，轻度 12-24，重度 24-36，≥36 停（**总兵力 36**，与原 TOTAL_SPAWN_CAP=12 在轻度阈值对齐，向后兼容）

## 具体改动

### 1. 常量与状态变量（文件顶部）
- **删除** `TOTAL_SPAWN_CAP`（被倍数派生取代）；**保留** `FATIGUED_SPAWN_INTERVAL = 18.0`
- **新增** `HEAVY_FATIGUE_INTERVAL = 30.0`
- **新增** 倍数常量：`FATIGUE_TIER1_MULT = 2`、`FATIGUE_TIER2_MULT = 4`、`EXHAUSTION_MULT = 6`
- **替换** `_spawn_fatigued: bool` → `_fatigue_tier: int`（0=正常, 1=轻度, 2=重度, 3=枯竭）
- **新增** 阈值缓存：`_tier1_cap`、`_tier2_cap`、`_exhaustion_cap`（int，setup 时按 _unit_limit 算）

### 2. setup() 末尾计算阈值（`_unit_limit` 钳制完成后，约 :170 后）
```gdscript
_tier1_cap = _unit_limit * FATIGUE_TIER1_MULT
_tier2_cap = _unit_limit * FATIGUE_TIER2_MULT
_exhaustion_cap = _unit_limit * EXHAUSTION_MULT
_fatigue_tier = 0   # 重置（替代原 _spawn_fatigued = false）
```
同步更新 :186-188 的重置块（`_total_spawned = 0`，`_fatigue_tier = 0`）。

### 3. _process() interval 三档选择 + 枯竭短路（:256-261）
```gdscript
_spawn_timer += delta
if _fatigue_tier >= 3:
    return  # 枯竭：彻底停止产兵
var interval: float = _get_current_spawn_interval()
if _spawn_timer >= interval:
    _spawn_timer = 0.0
    _produce_unit()
```
新增辅助函数：
```gdscript
func _get_current_spawn_interval() -> float:
    match _fatigue_tier:
        2: return HEAVY_FATIGUE_INTERVAL   # 重度疲劳 30s
        1: return FATIGUED_SPAWN_INTERVAL  # 轻度疲劳 18s
        _: return spawn_interval           # 正常 3~6s
```

### 4. _record_spawn_and_check_fatigue() 推进阶梯 + 反馈（:509-513）
```gdscript
_total_spawned += 1
var old_tier := _fatigue_tier
if _total_spawned >= _exhaustion_cap:
    _fatigue_tier = 3
elif _total_spawned >= _tier2_cap:
    _fatigue_tier = 2
elif _total_spawned >= _tier1_cap:
    _fatigue_tier = 1
if _fatigue_tier > old_tier:
    _spawn_timer = 0.0          # 阶梯跃迁重置计时器
    _on_fatigue_tier_changed(_fatigue_tier)  # 视觉 + toast 反馈
```

### 5. 视觉反馈（新增方法）
```gdscript
func _on_fatigue_tier_changed(tier: int) -> void:
    _apply_fatigue_visual(tier)
    if SignalBus:
        var msg: String = ""
        match tier:
            1: msg = "敌方相位师兵力告急！"
            2: msg = "敌方相位师兵力枯竭！"
            3: msg = "敌方相位师弹尽粮绝，停止出兵！"
        if not msg.is_empty():
            SignalBus.show_toast.emit(msg)

func _apply_fatigue_visual(tier: int) -> void:
    var spr := get_node_or_null("Body") as Sprite2D
    if spr == null:
        return
    # 在原阵营 tint 基础上叠暗化 + 偏红（兵力流失视觉）
    var base: Color = _base_body_tint  # setup 时缓存的原始 tint
    match tier:
        0: spr.modulate = base
        1: spr.modulate = base.lerp(Color(0.5, 0.3, 0.3), 0.35)   # 暗化偏红
        2: spr.modulate = base.lerp(Color(0.35, 0.2, 0.2), 0.55)  # 更暗
        3: spr.modulate = base.lerp(Color(0.2, 0.1, 0.1), 0.7)    # 接近灰黑
```
需在 `_apply_body_visual_from_master`（:210）设置 `spr.modulate = tint` 后缓存 `_base_body_tint = tint`，供反馈函数引用原始色。

### 6. 新增 smoke test `tests/phase_master_fatigue_smoke.gd`
SceneTree 模式（参考 `tests/master_power_smoke.gd`），验证：
- unit_limit=5 → 阈值 10/20/30；unit_limit=6 → 12/24/36
- _get_current_spawn_interval 各档返回正确（3~6 / 18 / 30 / 枯竭短路）
- 模拟累计产兵推进阶梯：产 10 个→tier1、20 个→tier2、30 个→tier3
- 枯竭后 _process 不再产兵（_total_spawned 不再增长）

## 向后兼容
- `_total_spawned` 是运行时变量不存档，旧存档零影响
- 非"疲劳阶梯"产兵路径（`_produce_unit_fallback`）同样经 `_record_spawn_and_check_fatigue`，行为一致
- `spawn_sequence` 循环逻辑不变（枯竭后 _process 直接 return，游标自然停住）
- 任何外部引用 `TOTAL_SPAWN_CAP` / `_spawn_fatigued` 的地方需同步改名（先 Grep 确认无外部引用，本文件内自洽）

## 不做的事
- 不引入能量/资源消耗系统（范围外，工程量大）
- 不改 `spawn_sequence` 循环逻辑（枯竭由 _process 短路，不动序列）
- 不改 unit_limit 计算逻辑（阈值在其钳制后派生）
- 不改相位师 HP（保持现有难度，仅加出兵终局）

## 验证
1. Godot headless `--check-only`（确认无语法错误）
2. 运行 `tests/phase_master_fatigue_smoke.gd`（确认阶梯逻辑正确）
3. Grep 静态核对：`_fatigue_tier` / `_tier1_cap` / `_exhaustion_cap` / `_on_fatigue_tier_changed` 链路完整
4. Grep 确认 `TOTAL_SPAWN_CAP` / `_spawn_fatigued` 无残留外部引用