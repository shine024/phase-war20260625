# 坦克炮类武器（TANK_GUN）弹道/击中效果排查手册

> **用途**：本文档记录"重装机甲主武器看似连发弹道、击中效果弱"的根因、修复方案，以及如何用同一线索排查其他卡牌的类似问题。
>
> **生成日期**：2026-08-07  ·  **版本**：v9.3（基于 bullet.gd / construct_unit_ai.gd / vfx_impact_factory.gd）

---

## 一、问题现象

重装机甲（`fut_arm_heavy_mech`）主武器"105mm主炮"+"重型等离子加农炮"，玩家反馈：
- **"主武器应该是单发的，现在看是一串弹道"**——屏幕上同时存在多颗飞行中的炮弹
- **"击中效果不好"**——命中反馈缺乏重炮的打击感

---

## 二、根因分析（三因素叠加）

### 因素 1：弹道重叠（"一串弹道"的主因）

```
attack_armor_speed = 0.5（次/秒）  → 攻击间隔 = 1/0.5 = 2.0s
bullet speed       = 720 px/s      （weapon_type=0 DIRECT 的默认值）
max_distance       = 1200 px       （weapon_type=0 DIRECT 的默认值）
→ 子弹最长飞行时间 = 1200 / 720 ≈ 1.67s
```

**关键判据**：`子弹飞行时间（1.67s） ≈ 攻击间隔（2.0s）` → 旧子弹还没消失，新子弹已发射 → 屏幕上同时 2+ 颗。

> 注：这不是 bug，是**低射速直射重炮的固有视觉问题**。机枪（attack_speed>2.0）走 batch 路径（MultiMesh 无独立节点）反而没这问题；问题专属于"射速 ≤ 2.0 且飞行时间接近攻击间隔"的直射武器。

### 因素 2：粒子拖尾加剧"光带感"

`bullet.gd::_apply_trail_tier()` 对 `DirectWeaponFlavor.TANK_GUN` 配置：
```gdscript
amount = 20; life = 0.50; vmin = 12.0; vmax = 35.0; smin = 2.5; smax = 4.5
```
每发炮弹拖一条 20 粒子 × 0.5s 寿命的橙白火星尾迹。多颗炮弹重叠时，尾迹叠加成杂乱光带，进一步放大"连发感"。

### 因素 3：命中震动不足（"击中效果弱"的主因）

`bullet.gd::_request_hit_shake()` 对所有 DIRECT 武器统一：
```gdscript
BattleManager.request_screen_shake(3.0, 0.15)  # 直射轻震动
```
重装机甲主炮单发伤害 1865（atk_a），是战场顶级火力，但震动量级与冲锋枪（伤害数十）相同——打击感不足。

---

## 三、修复方案（v9.3，仅改 `scenes/units/bullet.gd`）

### 修复 A：TANK_GUN 命中后快速淡出（解决"一串弹道"）

新增成员变量 + 命中触发 + `_process` 计时淡出：

```gdscript
# 类级常量/变量（顶部声明区）
const TANK_GUN_DISAPPEAR_AFTER: float = 0.20  # 命中后保持可见 0.2s
var _tank_gun_terminate: bool = false
var _tank_gun_timer: float = 0.0

# _on_hit() 开头
func _on_hit(primary: Node2D) -> void:
    if DirectWeaponFlavor.classify(_weapon_name, weapon_type) == DirectWeaponFlavor.Flavor.TANK_GUN:
        _tank_gun_terminate = true
        _tank_gun_timer = 0.0
    # ... 原有逻辑

# _process() 开头（曲射 return 之后）
if _tank_gun_terminate:
    _tank_gun_timer += delta
    var life_pct := 1.0 - _tank_gun_timer / TANK_GUN_DISAPPEAR_AFTER
    if _tex_sprite:
        _tex_sprite.modulate.a = maxf(0.0, life_pct)
    if _trail_particles:
        _trail_particles.emitting = _tank_gun_timer < TANK_GUN_DISAPPEAR_AFTER
    return

# _process() 命中判定前（max_distance 检查前）
if _tank_gun_terminate and _tank_gun_timer >= TANK_GUN_DISAPPEAR_AFTER:
    _finish_tex_bullet()
    return
```

**效果**：TANK_GUN 命中后 0.2s 内淡出消失，新旧炮弹不再重叠。

### 修复 B：TANK_GUN 禁用粒子拖尾（消除"光带感"）

`bullet.gd::_apply_trail()` 的 `_trail_particles` 分支开头加守卫：

```gdscript
if _trail_particles != null:
    _trail_particles.material = _get_add_blend_mat()
    if DT.is_motion_reduce():
        _trail_particles.emitting = false
        _trail_particles.visible = false
        return
    # v9.3 新增：TANK_GUN 禁用粒子拖尾
    if DirectWeaponFlavor.classify(_weapon_name, weapon_type) == DirectWeaponFlavor.Flavor.TANK_GUN:
        _trail_particles.emitting = false
        _trail_particles.visible = false
        return
    # ... 原有贴图分流逻辑
```

**效果**：单发重炮只剩清晰弹体（专属贴图 `*_proj.png`），无杂乱火星尾迹。

### 修复 C：TANK_GUN 命中震动增强（提升打击感）

`bullet.gd::_request_hit_shake()` 的 fallback 分支细化：

```gdscript
else:
    # v9.3: TANK_GUN 重炮应有重打击感（5.5 vs 原 3.0）
    if DirectWeaponFlavor.classify(_weapon_name, weapon_type) == DirectWeaponFlavor.Flavor.TANK_GUN:
        BattleManager.request_screen_shake(5.5, 0.25)
    else:
        BattleManager.request_screen_shake(3.0, 0.15)
```

**效果**：重炮命中震动从 3.0 提升到 5.5（接近 OMEGA/RAIL 量级），打击感明显。

---

## 四、踩坑记录（修复过程中遇到的）

| # | 错误 | 根因 | 解决 |
|---|------|------|------|
| 1 | `Identifier "life_pct" not declared in the current scope` | `var life_pct` 原声明在 `if _tex_sprite:` 块内，但 `if _trail_particles:` 块也引用它——GDScript 块级作用域不互通 | 把 `var life_pct` 提前到 `if _tank_gun_terminate:` 块顶部，两个子块共享 |
| 2 | `Invalid access to property 'process_material' on CPUParticles2D` | `process_material` 是 `GPUParticles2D` 的属性，`CPUParticles2D` 没有；`set_process_material_emission_sphere_radius` 更是臆造的方法 | 删除该行——CPUParticles2D 停止 `emitting` 后粒子按自身 `lifetime` 自然消散，无需手动控制 |

---

## 五、排查其他卡牌的线索（★ 重点）

### 5.1 哪些卡牌可能有同类问题？

**判定公式**：`子弹飞行时间 ≈ 攻击间隔` → 视觉重叠

```python
# 排查脚本（复制即用）
bullet_speed = {0:720, 1:800, 2:680, 4:720}.get(weapon_type, 650)  # DIRECT直射类
max_dist     = {0:1200, 1:1600, 2:1400, 4:1200}.get(weapon_type, 1300)
flight_time  = max_dist / bullet_speed
attack_interval = 1.0 / attack_speed  # attack_speed = per-target speed (atk_l/a/air_speed)
# 若 flight_time / attack_interval > 0.5 → 可能有重叠问题
```

**高风险卡牌特征**：
- `combat_kind = 1`（ARMOR 装甲）或 `combat_kind = 4`（FORT 堡垒）
- `weapon_type = 0`（DIRECT 直射，走独立 bullet 路径）
- 主武器名含"主炮/滑膛炮/反坦克炮/加农炮"（→ `DirectWeaponFlavor.TANK_GUN`）
- `attack_speed ≤ 1.0`（攻击间隔 ≥ 1s，单发重炮）

**已确认的高风险武器名清单**（来自 `data/unified_card_table.gd`，含"主炮/加农炮/电磁炮/等离子/轨道炮/离子炮"）：
```
100mm主炮 / 105mm/120mm主炮 / 105mm主炮 / 120mm L55主炮
120mm/125mm主炮 / 120mm主炮 / 122mm主炮 / 75mm主炮
85mm/105mm主炮 / 85mm主炮 / 88mm主炮 / 守护者主炮 / 闪电主炮
双联装电磁炮 / 攻城电磁炮 / 电磁炮 / 电磁轨道炮
离子炮 / 离子炮阵列 / 等离子炮 / 重型等离子加农炮
轨道炮 / 轨道炮/激光
```
（这些武器名都会被 `DirectWeaponFlavor._is_tank_gun()` 判定为 TANK_GUN，已自动享受 v9.3 修复）

**另有"坦克炮"关键词的武器名**（同样会被归类）：
```
37mm/57mm坦克炮 / 57mm/75mm坦克炮 / 75mm/76mm坦克炮 / 75mm坦克炮
```

### 5.2 DirectWeaponFlavor 分类速查

排查时先确认武器名会被归到哪个 Flavor（决定拖尾/命中配方）：

| Flavor | 关键词 | 拖尾配方 | 命中配方 |
|--------|--------|---------|---------|
| **TANK_GUN** | "主炮/滑膛炮/反坦克炮/坦克炮"（排除高炮/防空炮/迫击炮/榴弹炮/要塞炮/野战炮/舰炮） | 已禁用（v9.3） | 大环52px + 26粗火花 |
| MG | "机枪" / "MG" | 30粒子密集弹幕 | 34px环 + 22火花 |
| RIFLE | "步枪" / "冲锋枪" | 14粒子细长冷白 | 30px环 + 18窄角火花 |
| SMALL_ARMS | "手枪/卡宾/马刀" | 8粒子最弱 | 22px环 + 12火花 |
| GENERIC | 有名但无匹配 | 16粒子基准 | 28px环 + 16火花 |
| NONE | 非直射系(weapon_type∉[0,1,2,4]) | 走 weapon_type 配方 | 走 weapon_type 配方 |

> **分类逻辑真身**：`data/direct_weapon_flavor.gd` 的 `classify()` + `_is_tank_gun()`

### 5.3 弹道路由判定速查

确认某卡牌走哪条弹道路径（影响能否享受本修复）：

```
construct_unit_ai.do_attack_with_damage() 路由逻辑（行 636-680）：

1. GC.is_indirect_weapon_type(wt) == true
   → simple_indirect_projectile_batch（MultiMesh 抛物线）★ 不受本修复影响
   触发条件：wt ∈ {1 INDIRECT, 2 AERIAL, 3 ROCKET, 7 FLAK, 9 MISSILE}

2. wt == DIRECT(0) and weapon_speed > 2.0
   → simple_player/enemy_projectile_batch（MultiMesh 直线）★ 不受本修复影响
   特征：机枪类高频直射，batch 不传 weapon_name（v9.3 未改 batch，是已知遗留）

3. 其他（wt==DIRECT 且 weapon_speed ≤ 2.0，或霰弹5）
   → 独立 bullet 节点（对象池）★ 本修复生效路径
   特征：单发重炮、低频直射
```

**weapon_speed 来源**：`attack_calculator.get_weapon_speed()`
- 有 weapon_resource：读 `weapon.attack_speed`
- 无 weapon_resource：按 `combat_kind` 读 `attack_light/armor/air_speed`

### 5.4 命中效果链路速查

排查"击中效果不好"时，沿此链路核对：

```
bullet._on_hit(target)
  → _spawn_tex_impact_at(world_pos)           # bullet.gd:491
    → _spawn_impact_v2(parent, pos, name, opts) # 有 _weapon_name 时
      → WeaponProjectileVfx.spawn_impact_with_kind(parent, pos, wt, is_player, kind, opts, weapon_name)
        ├─ VfxFactory.spawn_impact_sprite(...)   # 贴图层（generic_impact_tex_by_wt 或 impact_texture_by_name）
        ├─ VfxFactory.spawn_animated_nuclear(...) # 帧动画层（仅 3/7/9/8/10/11）
        └─ VfxImpactFactory.spawn_layered_impact(...)  # 粒子层
             → _impact_recipe(wt, weapon_name)       # 配方（按 flavor 细分）
               → _impact_recipe_build(wt, flavor)    # match wt → match flavor
```

**关键检查点**：
1. `weapon_name` 是否透传到 bullet？（`construct_unit_ai` 行 675 `bullet.setup(..., w_name, ...)`）
2. `_weapon_name` 是否能查到专属贴图？（`WeaponVfxMapping.get_weapon_safe_id(name)` 返回非空）
3. 配方是否被 `_recipe_cache` 缓存命中？（同 wt+flavor 只算一次）

### 5.5 命中震动链路速查

```
bullet._on_hit → _request_hit_shake()           # bullet.gd:691
  → BattleManager.request_screen_shake(mag, dur)
```

**震动量级参考**（用于对比调参）：
| 武器类型 | 震动强度 | 持续 |
|---------|---------|------|
| 直射轻武器（原值） | 3.0 | 0.15s |
| **TANK_GUN（v9.3）** | **5.5** | **0.25s** |
| 爆炸类（explosion_radius=40 基准） | 8.0 | 0.35s |
| OMEGA（radius=70） | 12.5 | 0.35s |
| RAIL（radius=58） | 10.5 | 0.35s |

---

## 六、已知遗留 / 未处理项

### 6.1 直射 batch 路径不传 weapon_name（影响机枪类坦克炮）

`simple_player_projectile_batch.gd` / `simple_enemy_projectile_batch.gd` 的 `fire()` 签名：
```gdscript
func fire(from, tgt, dmg, wt, shooter, shooter_stats, forced_miss = false) -> void:
```
**不接受 weapon_name**，所以 batch 路径的弹道永远用 `weapon_smg_projectile.png`（SMG 小点），命中也不走专属贴图。

**影响范围**：`weapon_type=0` 且 `attack_speed > 2.0` 的武器（理论上罕见的"高频坦克炮"）。现有坦克炮 attack_speed 多 ≤ 1.0 走独立 bullet，**实际影响小**，但若新增高频直射重武器需补此参数。

**修复方式（如需）**：参照 `simple_indirect_projectile_batch.gd` 的 `fire()` 签名加 `weapon_name` + `p_vfx_variant` 参数，透传到 `_apply_hit` 的 `spawn_impact_with_kind`。

### 6.2 能量类坦克炮（等离子/轨道炮/离子炮）的命中贴图

"重型等离子加农炮"等武器名虽含"等离子"，但 `weapon_type=0`（DIRECT 动能类），命中走 `generic_impact_tex_by_wt(0)` = `IMPACT_TEX_SMALL_ARMS`（轻武器黄白贴图），**不走 OMEGA(10) 的蓝白能量爆裂贴图**。

这是设计取舍： weapon_type 决定弹道物理类型（动能 vs 能量），武器名只决定亚类视觉风味。若要让等离子炮有能量爆裂感，需把 weapon_type 改为 OMEGA(10)，但这会改变索敌/攻防结算——侵入性大，暂不动。

---

## 七、相关文件清单

| 文件 | 作用 | 本修复改动 |
|------|------|-----------|
| `scenes/units/bullet.gd` | 独立子弹节点（直射低频/曲射/霰弹） | ★ 三处改动（A/B/C） |
| `data/direct_weapon_flavor.gd` | 直射武器亚类分类器（TANK_GUN 判定真身） | 未改（只读） |
| `scripts/battle/construct_unit_ai.gd` | AI 攻击路由（决定走 batch 还是独立 bullet） | 未改（只读） |
| `scripts/battle/vfx_impact_factory.gd` | 命中粒子配方（按 wt+flavor） | 未改（只读） |
| `scripts/weapon_projectile_vfx.gd` | 弹道/命中贴图查询 + spawn_impact_with_kind | 未改（只读） |
| `data/weapon_vfx_mapping.gd` | 武器名 → 贴图 safe_id 映射表 | 未改（只读） |
| `managers/battle/simple_player_projectile_batch.gd` | 玩家直射 batch（高频机枪） | 未改（遗留 6.1） |
| `managers/battle/simple_enemy_projectile_batch.gd` | 敌方直射 batch | 未改（遗留 6.1） |
| `managers/battle/simple_indirect_projectile_batch.gd` | 曲射 batch（已支持 weapon_name，参考实现） | 未改（参考） |

---

## 八、快速验证清单

修复后实机验证要点：
- [ ] 重装机甲主炮命中后 0.2s 内淡出，无多颗炮弹重叠
- [ ] 重装机甲主炮无橙白火星拖尾（只剩清晰弹体贴图）
- [ ] 重装机甲主炮命中时屏幕震动明显增强（对比冲锋枪）
- [ ] 其他坦克炮类武器（T-72/M1 等）同步生效（因 Flavor=TANK_GUN）
- [ ] 机枪/步枪/手枪类武器视觉无变化（Flavor≠TANK_GUN）
- [ ] 曲射武器（迫击炮/火箭）视觉无变化（走 indirect 路径）
