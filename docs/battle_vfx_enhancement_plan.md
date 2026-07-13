# Phase War -- 弹道与命中效果视觉冲击优化计划

> 目标：让战斗中的弹道飞行、命中爆炸、伤害数字、受击反馈四个环节形成完整的"打击感链条"，消除当前"子弹飞过去像蚊子叮一下"的平淡感。

---

## 一、现状诊断

### 1.1 当前战斗视觉管线

```
攻击发起 (construct_unit / enemy_unit)
  |
  v
发射子弹 (bullet.tscn)
  |-- 弹体: Polygon2D 弹头形 / Sprite2D 贴图 / Line2D 光束
  |-- 拖尾: CPUParticles2D (重型强/轻武器弱) + Sprite2D 贴图(重型)
  |-- 炮口火焰: VfxImpactFactory.spawn_muzzle_flash() (曲射武器)
  |
  v
飞行 (_process): 直线追踪 / 抛物线 / 激光线段
  |
  v
命中判定 (_on_hit)
  |-- 屏幕震动: BattleManager.request_screen_shake()
  |-- 爆炸特效: VfxImpactFactory.spawn_layered_impact()
  |     Layer1: 冲击波环 Polygon2D (扩散+淡出)
  |     Layer2: 主火花 CPUParticles2D (径向粒子)
  |     Layer3: 碎片/烟尘 (重型专属)
  |-- 伤害数字: DamageNumberDisplay (弹跳+上浮+淡出)
  |-- 暴击光环: spawn_crit_aura (金色脉动环)
  |-- 穿透光线: spawn_pierce_beam (紫色Line2D)
  |-- 激光余晖: spawn_laser_beam (Line2D)
  |-- 单位受击闪白: _trigger_hit_flash() / _trigger_hit_shake()
  |
  v
对象池回收 (_finish_tex_bullet)
```

### 1.2 核心问题

| # | 问题 | 位置 | 影响 |
|---|------|------|------|
| B1 | **弹体太小**：80x120背包格对应战场上的弹体仅6-12px，肉眼几乎看不见 | bullet.gd `_apply_bullet_shape` | 飞行阶段完全无存在感 |
| B2 | **拖尾太弱**：轻武器粒子 amount=8, lifetime=0.30, scale=1-2，密集射击时拖尾几乎不可见 | bullet.gd `_apply_trail` | 机枪/步枪像"瞬移"没有轨迹 |
| B3 | **命中爆炸太短**：spark_life 0.45s 但粒子在0.15s后就消散了，环扩散到24px就没了 | vfx_impact_factory.gd recipe | 命中反馈一闪即逝，没有"砰"的感觉 |
| B4 | **屏幕震动太轻**：`_request_hit_shake` 有两条路径——主路径 `IMPACT_SHAKE_BY_KIND`（按目标兵种 LIGHT=1.8/0.10、ARMOR/FORT=3.2/0.18、AIR=5.0/0.25），fallback 直射=1.8/0.10、爆炸=5.0/0.25 | bullet.gd `_request_hit_shake` + weapon_projectile_vfx.gd `IMPACT_SHAKE_BY_KIND` | 导弹爆炸和机枪射击的震感差异不明显（改值时两条路径都要改） |
| B5 | **伤害数字太小太素**：normal=16px白色，critical=24px红色，只有弹跳没有光晕 | damage_number_display.gd | 大额伤害没有"重击"的视觉分量 |
| B6 | **受击单位无反应**：闪白0.1s + 缩放抖动0.12s，幅度极小（0.85→1.05） | construct_unit.gd `_update_hit_animations` | 被击中像"被风吹过"没有痛感 |
| B7 | **音效键与武器系统脱节**：BattleAudioSystem 有 5 个 if + 3 个 match 分支（melee/ranged/magic），确实在调 `play_sfx`（sword_hit/arrow_hit/magic_cast/unit_death），但全是奇幻题材键，与实际武器系统（SMG/RIFLE/MG…）完全不匹配——"在放但不搭" | battle_audio_system.gd | 视觉+听觉割裂 |
| B8 | **弹道颜色区分弱**：玩家/敌方各两种颜色，同阵营不同武器类型视觉上几乎一样 | bullet.gd `_apply_visual` | 无法通过颜色快速识别武器类型 |
| B9 | **闪光特效粗糙**：CardGridFx 用3点三角形放大1.65倍，0.12s淡出 | card_grid_fx.gd | 命中闪光像"眨眼"而非"爆炸" |
| B10 | **光束武器无贯穿感**：LASER/SNIPER 命中后没有能量残留或穿透特效 | bullet.gd beam logic | 高能武器缺乏"穿透装甲"的爽感 |

### 1.3 约束条件

- 1280x720 分辨率，战场区域约 y=280~440（160px高）
- 对象池复用是性能底线，不能每帧 new/free
- CPUParticles2D 有上限（MAX_SPARKS=200, MAX_DEBRIS=60, MAX_RINGS=80）
- 减少动效模式必须保留基本反馈
- 现有 VfxImpactFactory 三层架构可复用，不推倒重来

---

## 二、设计原则

1. **打击感公式** = 弹道可见性 × 命中体积 × 震动强度 × 数字分量 × 音效配合
2. **差异化**：每种武器类型必须有独特的飞行+命中视觉指纹
3. **层次递进**：弹道（飞行中）→ 命中（0-0.3s）→ 余波（0.3-1.5s）→ 信息（数字/状态）
4. **零额外GC**：所有特效走对象池，Tween 复用，Gradient 缓存
5. **音效即视觉**：没有音效的VFX是不完整的，先补音效再调数值

---

## 三、分模块改造方案

### 3.1 弹体增强（B1+B2+B8）

#### 3.1.1 弹体尺寸放大

**现状**：Polygon2D 弹头形总长约6-12px（scale 0.8-1.85），Sprite2D 贴图 scale 0.05 级别

**方案**：统一放大 2-3 倍，同时调整拖尾比例

```gdscript
# bullet.gd _apply_bullet_shape 修改：
# 原基准：总长约 6*scale，高约 4*scale
# 新基准：总长约 12*scale，高约 8*scale（2倍）

var body_len: float = 8.0 * s   # 4.0 → 8.0
var nose_len: float = 4.0 * s   # 2.0 → 4.0
var half_h: float = 3.5 * s     # 1.5 → 3.5
```

Sprite2D 贴图同步调整 PROJ_DISPLAY_SCALE_MUL：
```gdscript
# weapon_projectile_vfx.gd
const PROJ_DISPLAY_SCALE_MUL: float = 0.10  # 0.05 → 0.10（2倍）
```

#### 3.1.2 拖尾粒子全面增强

**现状**：轻武器 amount=8, lifetime=0.30, scale=1.0-2.0, velocity=6-12

**方案**：按武器类型分级

| 武器类型 | amount | lifetime | vel_min | vel_max | scale_min | scale_max |
|----------|--------|----------|---------|---------|-----------|-----------|
| 轻武器(SMG/RIFLE/MG) | 16 | 0.50 | 15 | 40 | 1.5 | 3.0 |
| 霰弹(SHOTGUN) | 24 | 0.45 | 20 | 60 | 2.0 | 4.0 |
| 狙击(SNIPER) | 12 | 0.60 | 40 | 100 | 1.0 | 2.0 |
| 火箭/导弹(ROCKET/MISSILE) | 30 | 0.70 | 20 | 50 | 2.5 | 5.0 |
| 激光(LASER) | 10 | 0.40 | 60 | 150 | 0.8 | 1.5 |
| 电磁炮(RAIL/OMEGA) | 20 | 0.55 | 30 | 80 | 1.8 | 3.5 |

拖尾颜色改为渐变色带（每个武器类型独立 Gradient）：
```gdscript
# 轻武器: 白→黄→橙→透明
# 火箭: 白→亮橙→深红→透明
# 激光: 白→青→蓝→透明
# RAIL: 白→电蓝→紫→透明
```

#### 3.1.3 弹体发光增强

**现状**：所有弹体共享同一个 ADD blend material，颜色单一

**方案**：按武器类型差异化发光颜色和宽度

```gdscript
# 光束类额外加宽
if use_beam:
    _beam_line.width = 6.0 if weapon_type == 6 else 8.0  # 原3.0/4.5

# 弹体增加发光层（新增 GlowOverlay Polygon2D，z_index=1）
# 用更大的半透明多边形覆盖弹体，ADD混合，产生辉光
```

#### 3.1.4 曲射武器炮口火焰增强

**现状**：VfxImpactFactory.spawn_muzzle_flash amount=12, spread=120

**方案**：曲射武器炮口火焰翻倍

```gdscript
# 迫击炮/野战炮: amount=24, spread=160, velocity 40-120
# 火箭筒: amount=20, spread=140, velocity 30-100
# 导弹发射: amount=16, spread=120, velocity 20-80
```

### 3.2 命中爆炸增强（B3+B9）

#### 3.2.1 冲击波环放大

**现状**：配方表中 ring_r 最大60px（MISSILE），最小22px（LASER）。环持续 `ring_dur` 0.24-0.56s，但粒子寿命 `spark_life` 实际最高 0.62s（MISSILE）/0.58s（ROCKET）。下表"原持续"列取自 `ring_dur`。

**方案**：整体放大 1.5-2 倍，延长持续时间

| 武器类型 | 原环半径 | 新环半径 | 原持续 | 新持续 |
|----------|----------|----------|--------|--------|
| DIRECT/SMG | 24 | 36 | 0.32 | 0.40 |
| SHOTGUN | 29 | 44 | 0.34 | 0.42 |
| SNIPER | 32 | 48 | 0.36 | 0.44 |
| ROCKET | 56 | 80 | 0.52 | 0.60 |
| MISSILE | 60 | 90 | 0.56 | 0.65 |
| LASER | 22 | 30 | 0.24 | 0.30 |
| OMEGA/RAIL | 34 | 50 | 0.36 | 0.45 |

环的内外圈差值从 3px 增加到 6px，让环更"粗"更醒目。

#### 3.2.2 主火花增强

**方案**：增加粒子数量、速度、寿命

| 武器类型 | 原amount | 新amount | 原vmax | 新vmax | 原life | 新life |
|----------|----------|----------|--------|--------|--------|--------|
| DIRECT | 18 | 28 | 170 | 280 | 0.45 | 0.60 |
| SHOTGUN | 28 | 40 | 150 | 250 | 0.42 | 0.55 |
| ROCKET | 32 | 48 | 200 | 320 | 0.58 | 0.70 |
| MISSILE | 36 | 55 | 220 | 350 | 0.62 | 0.75 |
| LASER | 22 | 25 | 260 | 350 | 0.32 | 0.40 |
| OMEGA/RAIL | 24 | 35 | 170 | 280 | 0.48 | 0.58 |

#### 3.2.3 命中闪光升级（替代 CardGridFx 三角形）

**现状**：3点三角形放大1.65倍，0.12s淡出，纯颜色填充

**方案**：改为圆形闪光（Polygon2D 圆），多层叠加

```
Layer1: 白色内圈（快速扩张到半径15，0.08s）
Layer2: 武器色中圈（扩张到半径25，0.15s）
Layer3: 武器色外圈（扩张到半径40，0.25s，带ADD混合）
```

三层错开0.03s启动，形成"爆炸开花"效果。

#### 3.2.4 爆炸碎片增强

**现状**：仅 ROCKET/MISSILE/FLAK 有碎片/烟尘，且 amount=12-16

**方案**：扩展碎片覆盖范围

- SNIPER：增加金属碎片（高速小颗粒）
- DIRECT/SHOTGUN：增加弹壳/火花碎片
- LASER：增加灼烧烟尘
- OMEGA/RAIL：增加电弧碎片

### 3.3 屏幕震动增强（B4）

#### 3.3.1 震动参数全面上调

**现状（两条路径，改值时都要动）**：
- 主路径 `weapon_projectile_vfx.gd` 的 `IMPACT_SHAKE_BY_KIND`（当 `_target_combat_kind >= 0` 时走这条）：LIGHT=1.8/0.10、ARMOR/FORT=3.2/0.18、AIR=5.0/0.25
- fallback（`_target_combat_kind < 0`）：直射=1.8/0.10、爆炸(`_is_indirect or explosion_radius>0`)=5.0/0.25

**方案**：

下表的"原值"同时对应主路径表和 fallback 分支。**实现时必须同步修改 `IMPACT_SHAKE_BY_KIND` 和 fallback 两个地方**，否则按兵种目标的震动不变。

| 场景 | 原 intensity | 新 intensity | 原 duration | 新 duration |
|------|-------------|-------------|------------|------------|
| 直射命中(LIGHT/fallback 直射) | 1.8 | 3.0 | 0.10 | 0.15 |
| 霰弹命中 | - | 4.5 | - | 0.20 |
| 火箭/导弹爆炸(fallback 爆炸) | 5.0 | 8.0 | 0.25 | 0.35 |
| 对装甲目标命中(ARMOR/FORT) | 3.2 | 5.0 | 0.18 | 0.25 |
| 对空目标命中(AIR) | 5.0 | 7.0 | 0.25 | 0.35 |
| 暴击命中 | +0 | +2.0 叠加 | - | +0.10s |
| 大额伤害(>500) | +0 | +1.5 叠加 | - | +0.08s |

#### 3.3.2 震动频率分层

**现状**：使用 FastNoiseLite simplex noise，频率固定 1.0

**方案**：高强度震动使用更高频噪声（模拟"抖动"感），低强度使用低频（模拟"厚重"感）

```gdscript
# screen_shake.gd
func start_shake(intensity, duration, decay=true) -> void:
    var noise_freq := 1.0 + intensity * 0.05  # 强度越高，噪声频率越高
    _noise.frequency = noise_freq
```

### 3.4 伤害数字增强（B5）

#### 3.4.1 字体与光晕

**现状**：Label + LabelSettings outline，无发光效果

**方案**：增加发光层（Shadow + Glow）

```
normal:    16px, 白字, 黑outline 2px, 无发光
critical:  28px (原24), 金色字, 红outline 3px, 金色glow 4px
big_crit:  36px (原28), 金+白渐变字, 黑outline 3px, 金色glow 6px
pierce:    24px (原20), 紫色字, 深紫outline 3px, 紫色glow 3px
miss:      14px, 灰字, 无发光
heal:      20px (原18), 绿色字, 暗绿outline 2px, 绿色glow 3px
```

> 注：原文 normal=16/critical=24/big_crit=28/pierce=20/miss=14/heal=18，颜色敌我一致。

#### 3.4.2 入场动画增强

**现状**：手写两阶段弹跳动画，起始 0.4，总 0.19s（_pop_duration）。**overshoot 按类型分档**：普通/miss/heal=1.25，critical/pierce/big_crit=1.45。新方案需保留这个分档（暴击/穿透的 overshoot 更夸张）。

**方案**：增加旋转和缩放复合动画

```
阶段1 (0-0.06s):  从 0.3 放大到 1.5，同时旋转 -15°→0°（EASE_OUT_BACK）
阶段2 (0.06-0.12s): 从 1.5 缩放到 1.1，旋转 0°→5°→0°（回弹）
阶段3 (0.12-0.19s): 从 1.1 缩放到 1.0（稳定）
```

> overshoot 分档建议保留：普通 1.25 → 新方案峰值 1.5；critical/pierce 1.45 → 新方案峰值 1.7。

暴击数字额外增加"炸开"粒子（从数字中心向外辐射）。

#### 3.4.3 数字排列优化

**现状**：二维随机偏移 `Vector2(randf_range(-15,15), randf_range(-10,10))`（X±15, Y±10），密集时重叠

**方案**：改用网格化偏移算法

```
同一命中点的多个数字：
  第1个: (0, 0)
  第2个: (-12, -8)
  第3个: (+12, -8)
  第4个: (-6, -18)
  第5个: (+6, -18)
  ...
```

### 3.5 受击单位反馈增强（B6）

#### 3.5.1 闪白增强

**现状**：闪白 0.1s（_HIT_FLASH_DURATION），modulate 直接切换。**敌我颜色不同**：我方（construct_unit）闪 `Color.RED`，敌方（enemy_unit）闪 `Color.WHITE`。两套代码各自独立，改的时候两边都要动。

**方案**：改为多阶段闪光。需决定是否保留敌我颜色区分（建议保留：我方红=受伤警示，敌方白=被击中），还是统一为武器色。

```
阶段1 (0-0.03s):  纯白 flash（模拟冲击波照亮）—— 敌我统一纯白
阶段2 (0.03-0.08s):  武器色 flash（模拟弹体颜色反射）
阶段3 (0.08-0.15s):  缓慢回原色（lerp back）
```

> 如保留敌我区分：阶段1 用各自的基色（我方 RED / 敌方 WHITE），阶段2 才用武器色。

#### 3.5.2 缩放抖动增强

**现状**：0.85→1.05→0.95→1.0，总0.12s，4段

**方案**：增大振幅，增加段数

```
阶段1 (0-0.02s):  0.75 → 0.75 (压缩，模拟受击凹陷)
阶段2 (0.02-0.05s):  0.75 → 1.15 (反弹放大)
阶段3 (0.05-0.08s):  1.15 → 0.92 (回缩)
阶段4 (0.08-0.11s):  0.92 → 1.05 (二次微弹)
阶段5 (0.11-0.16s):  1.05 → 1.0 (稳定)
总时长: 0.16s (原0.12s)
```

#### 3.5.3 新增：受击击退

**现状**：无位移反馈

**方案**：受击时沿弹道反方向微位移

```gdscript
# construct_unit.gd / enemy_unit.gd
func _trigger_hit_knockback(direction: Vector2, strength: float) -> void:
    var tween := create_tween()
    var offset := direction.normalized() * strength
    tween.tween_property(self, "position", position + offset, 0.04)
    tween.tween_property(self, "position", position, 0.08)
```

力度：直射 3px，爆炸 6px，暴击 10px

### 3.6 音效系统补全（B7）

> ⚠️ **枚举核对**：项目有**两套武器枚举**（`resources/game_constants.gd`）：
> - `WeaponType`（4值：DIRECT=0/INDIRECT=1/AERIAL=2/SUPPORT=3）——AI 定位用
> - `WeaponTypeLegacy`（12值，**音频 match 必须用这套**）：SMG=0, RIFLE=1, MG=2, ROCKET=3, PISTOL=4, SHOTGUN=5, SNIPER=6, FLAK=7, LASER=8, MISSILE=9, OMEGA_CANNON=10, RAIL_CANNON=11
>
> 早期版本曾误把 4 当作 RIFLE/MG，实际 **4=PISTOL**，而 RIFLE=1/MG=2。下方表格和 match 均已校正。

#### 3.6.1 攻击音效

为每种武器类型添加独立音效（按 `WeaponTypeLegacy` 值排列）：

| 值 | 武器类型 | 音效描述 | 音量 | 音高范围 |
|----|----------|----------|------|----------|
| 0 | SMG | 冲锋枪连发 | 0.6 | 800-1200Hz |
| 1 | RIFLE | 步枪单发 | 0.6 | 700-1000Hz |
| 2 | MG | 机枪连发(低沉) | 0.7 | 500-800Hz |
| 3 | ROCKET | 火箭弹呼啸+爆炸 | 1.0 | 100-300Hz |
| 4 | PISTOL | 手枪短促 | 0.5 | 900-1300Hz |
| 5 | SHOTGUN | 霰弹枪轰鸣 | 0.9 | 200-400Hz |
| 6 | SNIPER | 狙击枪清脆 | 0.7 | 1500-2000Hz |
| 7 | FLAK | 高射炮轰鸣 | 0.9 | 150-350Hz |
| 8 | LASER | 高频能量嗡鸣 | 0.5 | 3000-5000Hz |
| 9 | MISSILE | 导弹追踪嗡鸣 | 0.8 | 400-800Hz |
| 10 | OMEGA_CANNON | 低频能量脉冲 | 0.8 | 80-200Hz |
| 11 | RAIL_CANNON | 电磁充能+击穿 | 0.7 | 2000-4000Hz |

#### 3.6.2 命中音效

| 武器类型(值) | 音效描述 | 音量 |
|----------|----------|------|
| 直射(0/1/2/4) | 金属撞击/火花 | 0.6 |
| 霰弹(5) | 碎屑飞溅 | 0.7 |
| 狙击(6) | 清脆穿透 | 0.7 |
| 火箭/导弹(3/9) | 爆炸轰鸣 | 1.0 |
| 高射炮(7) | 空爆碎片 | 0.8 |
| 激光(8) | 滋滋能量声 | 0.4 |
| 电磁炮(10/11) | 高频穿刺 | 0.7 |
| 暴击(任意) | 爆炸+低频轰击 | 1.2 |

#### 3.6.3 实现方式

```gdscript
# battle_audio_system.gd 重构
# 注意：weapon_type 是 WeaponTypeLegacy 的值（0-11），不是 WeaponType(0-3)
func play_attack_sound(weapon_type: int, is_player: bool) -> void:
    if not _sound_enabled(): return
    var pitch := randf_range(0.9, 1.1)
    match weapon_type:
        0:       AudioManager.play_sfx("gun_smg", 0.6, pitch)            # SMG
        1:       AudioManager.play_sfx("gun_rifle", 0.6, pitch)          # RIFLE
        2:       AudioManager.play_sfx("gun_mg", 0.7, pitch * 0.9)       # MG
        3:       AudioManager.play_sfx("rocket_launch", 1.0, pitch * 0.8)  # ROCKET
        4:       AudioManager.play_sfx("gun_pistol", 0.5, pitch * 1.1)   # PISTOL（不是 RIFLE/MG）
        5:       AudioManager.play_sfx("gun_shotgun", 0.9, pitch)
        6:       AudioManager.play_sfx("gun_sniper", 0.7, pitch * 1.2)   # SNIPER
        7:       AudioManager.play_sfx("flak_fire", 0.9, pitch * 0.9)    # FLAK
        8:       AudioManager.play_sfx("laser_fire", 0.5, pitch * 2.0)   # LASER
        9:       AudioManager.play_sfx("missile_hum", 0.8, pitch)        # MISSILE
        10:      AudioManager.play_sfx("omega_cannon", 0.8, pitch * 0.5) # OMEGA
        11:      AudioManager.play_sfx("rail_cannon", 0.7, pitch * 1.5)  # RAIL
        _:       push_warning("[BattleAudio] unknown weapon_type %d" % weapon_type)

func play_impact_sound(weapon_type: int, is_crit: bool) -> void:
    if not _sound_enabled(): return
    var vol := 0.6
    var pitch := randf_range(0.95, 1.05)
    match weapon_type:
        3, 9:    vol = 1.0                              # ROCKET/MISSILE 爆炸
        8:       vol = 0.4; pitch = randf_range(3.0, 5.0)  # LASER
        7:       vol = 0.8                              # FLAK 空爆
        _:       vol = 0.6
    if is_crit: vol = minf(vol * 1.5, 1.0); pitch *= 0.8
    AudioManager.play_sfx("impact_generic", vol, pitch)
```

### 3.7 特殊效果增强（B10）

#### 3.7.1 激光/电磁炮贯穿效果

**现状**：命中后只显示一条淡出的Line2D余晖

**方案**：增加贯穿电弧和能量残留

```
命中瞬间：
  1. 紫色/青色闪电链从命中点向四周放射（4-6条，0.2s淡出）
  2. 命中点留下一个持续0.5s的能量残影（半透明圆形，ADD混合）
  3. 如果穿透：穿透路径上留下电弧痕迹（Line2D锯齿，0.3s淡出）
```

#### 3.7.2 暴击效果增强

**现状**：双层金色脉冲环 + 金色粒子

**方案**：增加"时间停滞"效果

```
暴击触发时：
  1. 金色脉冲环（现有，放大到 radius 60）
  2. 环形冲击波（0.1s内环膨胀到80px）
  3. 伤害数字金色爆炸粒子（现有）
  4. 屏幕短暂变暗0.05s（全局ColorRect遮罩，模拟"冲击波掠过"）
  5. 音效pitch降低20%（沉闷的重击感）
```

#### 3.7.3 穿透效果增强

**现状**：紫色Line2D从命中点向前延伸60px

**方案**：增加穿透孔洞和能量尾迹

```
穿透命中：
  1. 紫色穿甲光线（现有，加长到120px）
  2. 命中点黑色小圆孔（0.3s淡出，模拟穿透伤）
  3. 穿透路径上的粒子尾迹（沿direction的CPUParticles2D）
```

---

## 四、实施优先级与阶段

### Phase 1 -- 立竿见影（1-2天）

| 任务 | 文件 | 工作量 | 效果 |
|------|------|--------|------|
| 弹体尺寸放大2倍 | bullet.gd, weapon_projectile_vfx.gd | 小 | 飞行中可见弹体 |
| 拖尾粒子增强（轻+重） | bullet.gd `_apply_trail` | 小 | 机枪有轨迹感 |
| 屏幕震动上调 | bullet.gd `_request_hit_shake`, screen_shake.gd | 小 | 爆炸有分量感 |
| 伤害数字放大+发光 | damage_number_display.gd | 小 | 数字更醒目 |
| 受击抖动幅度加大 | construct_unit.gd, enemy_unit.gd | 小 | 受击有痛感 |

### Phase 2 -- 深度强化（2-3天）

| 任务 | 文件 | 工作量 | 效果 |
|------|------|--------|------|
| 冲击波环放大+加厚 | vfx_impact_factory.gd recipe | 中 | 爆炸更壮观 |
| 主火花粒子增强 | vfx_impact_factory.gd recipe | 中 | 火花更密集 |
| 命中闪光三层化 | card_grid_fx.gd | 中 | 爆炸开花感 |
| 受击闪白多阶段 | construct_unit.gd, enemy_unit.gd | 小 | 受击层次丰富 |
| 受击击退位移 | construct_unit.gd, enemy_unit.gd | 小 | 物理反馈 |
| 曲射炮口火焰增强 | vfx_impact_factory.gd spawn_muzzle_flash | 小 | 发射有气势 |

### Phase 3 -- 精细打磨（1-2天）

| 任务 | 文件 | 工作量 | 效果 |
|------|------|--------|------|
| 音效系统补全 | battle_audio_system.gd | 中 | 视听合一 |
| 激光/电磁炮贯穿效果 | vfx_impact_factory.gd | 中 | 高能武器独特感 |
| 暴击时间停滞效果 | vfx_impact_factory.gd spawn_crit_aura | 中 | 暴击爽感 |
| 穿透孔洞+电弧 | vfx_impact_factory.gd spawn_pierce_beam | 中 | 穿甲真实感 |
| 伤害数字排列优化 | damage_number_display.gd | 小 | 不重叠 |

---

## 五、武器类型视觉指纹表（参考）

改造完成后，每种武器应有以下独特视觉特征：

| 武器 | 弹体 | 拖尾 | 爆炸环 | 火花 | 震动 | 音效 |
|------|------|------|--------|------|------|------|
| SMG/RIFLE | 小黄点 | 微弱黄白 | 小环36px | 28粒 | 轻3.0 | 哒哒哒 |
| SHOTGUN | 粗橙色 | 中等橙 | 中环44px | 40粒宽散 | 中4.5 | 嘭！ |
| SNIPER | 细长亮黄 | 高速白 | 中环48px | 25粒集中 | 轻3.0 | 咻-啪 |
| ROCKET | 粗橙弹 | 浓烈橙红 | 大环80px | 48粒+烟 | 重8.0 | 轰！！！ |
| MISSILE | 橙红弹 | 浓烈深橙 | 大环90px | 55粒+碎片 | 重8.0 | 嗡嗡-轰 |
| FLAK | 短粗棕 | 中等棕 | 中环46px | 28粒+烟 | 重6.0 | 砰砰 |
| LASER | 蓝色线 | 细蓝 | 细环30px | 25粒集中 | 轻2.5 | 滋—— |
| OMEGA | 蓝白弹 | 浓烈青 | 中环50px | 35粒 | 重6.5 | 嗡...轰 |
| RAIL_CANNON | 细长蓝 | 电蓝+紫 | 中环50px | 35粒 | 重6.0 | 充能-啪！ |

---

## 六、技术注意事项

### 6.1 性能预算

| 资源 | 当前上限 | 调整后预估峰值 | 安全边际 |
|------|----------|---------------|----------|
| CPUParticles2D (火花) | 200 | ~120 (10敌×3弹×4命中) | 充足 |
| CPUParticles2D (碎片) | 60 | ~30 | 充足 |
| Polygon2D (环) | 80 | ~50 | 充足 |
| Line2D (光束) | 60 (`MAX_BEAMS`) | ~20（§3.7 贯穿电弧/能量残留上线后需重估，可能吃紧） | ⚠️ 关注 |
| Tween | 无限制 | ~100/帧峰值 | 需监控 |

### 6.2 兼容性

- 减少动效模式（MOTION_REDUCE）下只保留核心反馈：弹体可见+命中闪光+伤害数字
- 所有新特效必须走对象池，禁止运行时 ResourceLoader.load()
- Gradient 色带统一缓存，key 用 weapon_type + color hash

### 6.3 美术需求

| 资源 | 规格 | 用途 |
|------|------|------|
| 无（纯程序化VFX） | -- | 本次优化全部用程序化几何+粒子，无需新贴图 |

### 6.4 音效需求

| 音效键 | 对应武器(WeaponTypeLegacy) | 描述 | 来源 |
|------|------|------|------|
| gun_smg | 0 SMG | 冲锋枪连发 | 需制作/购买 |
| gun_rifle | 1 RIFLE | 步枪单发 | 需制作/购买 |
| gun_mg | 2 MG | 机枪连发（低沉） | 需制作/购买 |
| rocket_launch | 3 ROCKET | 火箭弹呼啸+爆炸 | 需制作/购买 |
| gun_pistol | 4 PISTOL | 手枪短促 | 需制作/购买 |
| gun_shotgun | 5 SHOTGUN | 霰弹枪轰鸣 | 需制作/购买 |
| gun_sniper | 6 SNIPER | 狙击枪清脆 | 需制作/购买 |
| flak_fire | 7 FLAK | 高射炮轰鸣 | 需制作/购买 |
| laser_fire | 8 LASER | 高频能量嗡鸣 | 需制作/购买 |
| missile_hum | 9 MISSILE | 导弹追踪嗡鸣 | 需制作/购买 |
| omega_cannon | 10 OMEGA_CANNON | 低频能量脉冲 | 需制作/购买 |
| rail_cannon | 11 RAIL_CANNON | 电磁充能+击穿 | 需制作/购买 |
| impact_generic | 通用命中 | 金属撞击/火花 | 需制作/购买 |

---

## 七、验收标准

1. [ ] 战场上至少能清晰看到弹体的飞行轨迹（拖尾粒子不可见视为失败）
2. [ ] 火箭/导弹爆炸时有明显的冲击波环（半径≥60px）和持续≥0.5s的火花
3. [ ] 机枪齐射时屏幕有轻微连续震动（intensity≥2.5）
4. [ ] 暴击伤害数字至少36px，带金色光晕和炸开粒子
5. [ ] 受击单位有明显的压缩-反弹动画（幅度≥25%缩放变化）
6. [ ] 每种武器类型的命中特效有可区分的颜色和规模
7. [ ] 激光/电磁炮命中有独特的贯穿电弧效果
8. [ ] 减少动效模式下基本视觉反馈仍可用
9. [ ] 战斗中FPS不下降（粒子上限内对象池正常运作）
10. [ ] 音效系统能根据武器类型播放对应攻击/命中音效
