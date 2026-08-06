# 敌方相位师战法提升计划（v9.1）

**日期：** 2026-08-04
**范围：** 30 个敌方相位师的 traits/passives 战斗化 + 基地视觉增强
**分支：** feat/v6.14-system-integration（可新建 `feat/v9.1-master-vfx`）

---

## 一、背景与问题

### 1.1 现状问题

| 问题 | 现状 | 影响 |
|------|------|------|
| **Traits 数据不生效** | 30 相位师 `traits[].effects` 完整定义（如"新兵教官"→防御+10%），但战斗代码零消费，数据完全空转 | 玩家看到的 trait 描述与实际战斗无关联 |
| **被动技能覆盖不全** | `enemy_master_skill_engine._apply_passive_buffs` 仅处理 `armor_boost`/`damage_boost`/`thorn` 3 类 | `energy_shield`/`death_shield`/`high_energy_bonus` 等 6+ 类 effect 静默跳过 |
| **视觉区分度极低** | 相位师基地仅有阵营 tint + 疲劳暗化，无光环/边框/粒子 | 玩家无法从视觉上感知"这是高级 boss，不是普通产兵单位" |
| **情报面板无数值** | trait 只显示名称和描述文字，不显示实际数值 | 玩家不知道这个 trait 具体带来多少加成 |

### 1.2 数据验证

`EnemyPhaseMasters.get_master_traits(pm_id)` 已存在，30 个相位师全部有 `traits` 数组：
- WW1（001-006）：`def_*`/`atk_*`/`crit_chance`/`dodge_chance`/`hp` 类型
- WW2（007-012）：同上 + `all_stat_boost` 类型
- 冷战（013-018）：`atk_*` 类型
- 现代（019-024）：`divine_transform`/`auto_resurrect` 类型
- 近未来（025-030）：同上 + `void_damage_boost`/`instant_delete` 类型

---

## 二、改动清单

### 涉及文件

| 文件 | 类型 | 改动模块 |
|------|------|---------|
| `scenes/units/enemy_phase_field_driver.gd` | 修改 | A+C+D |
| `managers/battle/enemy_master_skill_engine.gd` | 修改 | B+D |
| `scenes/units/enemy_phase_aura_ring.gd` | **新建** | C |
| `scenes/ui/card_info_panel.gd` | 修改 | E |

---

## 三、详细设计

### A. Traits 效果战斗化

**目标：** 让 30 个相位师的 traits.effects 在战斗中真实生效，加成应用到所有敌方单位。

#### A.1 数据结构回顾

每个 trait 的 `effects` dict 支持以下 key（数据层已有注释）：
```
atk_light/atk_armor/atk_air   → UnitStats.attack_light/armor/air（三维攻击）
def_light/def_armor/def_air   → UnitStats.defense_light/armor/air（三维防御）
hp                            → UnitStats.max_hp（生命值）
crit_chance                   → UnitStats.crit_chance（暴击率）
dodge_chance                  → UnitStats.dodge_chance（闪避率）
unit_limit_bonus              → 不写 stats，缓存到 driver 影响产兵上限
all_stat_boost                → 三维攻防 + max_hp 统一乘区
```

#### A.2 新增字段（enemy_phase_field_driver.gd）

```gdscript
## v9.1: traits 效果缓存（setup 时计算，产兵时复用）
var _trait_stat_mods: Dictionary = {}  # key → ratio（如 {"defense_light": 1.10, "attack_light": 1.08}）
var _trait_unit_limit_bonus: int = 0   # unit_limit_bonus 累加值
```

#### A.3 新增方法：`_apply_trait_effects()`

在 `setup()` 末尾（L257 附近）调用：

```gdscript
## v9.1: 读取 master_config.traits，计算统计加成，应用到现有敌方单位
func _apply_trait_effects() -> void:
    var traits: Array = _master_config_cache.get("traits", [])
    if traits.is_empty():
        return
    _trait_stat_mods = {}
    _trait_unit_limit_bonus = 0
    for trait in traits:
        if not (trait is Dictionary):
            continue
        var fx: Dictionary = trait.get("effects", {})
        for key in fx:
            var val: float = float(fx[key])
            _apply_trait_effect_key(key, val)
    # 应用到已存在的 enemy_units（setup 后产兵可能已有单位）
    _apply_trait_mods_to_units()

## v9.1: 按 key 分类写入 _trait_stat_mods
func _apply_trait_effect_key(key: String, val: float) -> void:
    match key:
        "unit_limit_bonus":
            _trait_unit_limit_bonus += int(val)
        "all_stat_boost":
            # 统一加成：三维攻防 + max_hp 同比例
            _trait_stat_mods["attack_light"] = _trait_stat_mods.get("attack_light", 1.0) * (1.0 + val)
            _trait_stat_mods["attack_armor"] = _trait_stat_mods.get("attack_armor", 1.0) * (1.0 + val)
            _trait_stat_mods["attack_air"]   = _trait_stat_mods.get("attack_air", 1.0) * (1.0 + val)
            _trait_stat_mods["defense_light"] = _trait_stat_mods.get("defense_light", 1.0) * (1.0 + val)
            _trait_stat_mods["defense_armor"] = _trait_stat_mods.get("defense_armor", 1.0) * (1.0 + val)
            _trait_stat_mods["defense_air"]   = _trait_stat_mods.get("defense_air", 1.0) * (1.0 + val)
            _trait_stat_mods["max_hp"]        = _trait_stat_mods.get("max_hp", 1.0)  * (1.0 + val)
        "atk_light":   _trait_stat_mods["attack_light"] = _trait_stat_mods.get("attack_light", 1.0) * (1.0 + val)
        "atk_armor":   _trait_stat_mods["attack_armor"] = _trait_stat_mods.get("attack_armor", 1.0) * (1.0 + val)
        "atk_air":     _trait_stat_mods["attack_air"]   = _trait_stat_mods.get("attack_air", 1.0) * (1.0 + val)
        "def_light":   _trait_stat_mods["defense_light"] = _trait_stat_mods.get("defense_light", 1.0) * (1.0 + val)
        "def_armor":   _trait_stat_mods["defense_armor"] = _trait_stat_mods.get("defense_armor", 1.0) * (1.0 + val)
        "def_air":     _trait_stat_mods["defense_air"]   = _trait_stat_mods.get("defense_air", 1.0) * (1.0 + val)
        "hp":          _trait_stat_mods["max_hp"]        = _trait_stat_mods.get("max_hp", 1.0)  * (1.0 + val)
        "crit_chance": _trait_stat_mods["crit_chance"]   = _trait_stat_mods.get("crit_chance", 0.0) + val
        "dodge_chance":_trait_stat_mods["dodge_chance"]  = _trait_stat_mods.get("dodge_chance", 0.0) + val
        # 其他 key（如 void_damage_boost）暂不处理，留待后续扩展
```

#### A.4 新增方法：`_apply_trait_mods_to_units()`

```gdscript
## v9.1: 将缓存的 trait 加成应用到所有现有敌方单位 stats
func _apply_trait_mods_to_units() -> void:
    if _trait_stat_mods.is_empty():
        return
    var all_units: Array = get_tree().get_nodes_in_group("enemy_units")
    for u in all_units:
        if u == null or not is_instance_valid(u):
            continue
        if "stats" in u and u.stats != null:
            _apply_trait_mods_to_stats(u.stats)

## v9.1: 将 _trait_stat_mods 应用到单个 UnitStats
func _apply_trait_mods_to_stats(stats: Object) -> void:
    if "attack_light" in _trait_stat_mods:
        stats.attack_light *= _trait_stat_mods["attack_light"]
        stats.attack_armor *= _trait_stat_mods.get("attack_armor", 1.0)
        stats.attack_air   *= _trait_stat_mods.get("attack_air", 1.0)
    if "defense_light" in _trait_stat_mods:
        stats.defense_light *= _trait_stat_mods["defense_light"]
        stats.defense_armor *= _trait_stat_mods.get("defense_armor", 1.0)
        stats.defense_air   *= _trait_stat_mods.get("defense_air", 1.0)
    if "max_hp" in _trait_stat_mods:
        stats.max_hp *= _trait_stat_mods["max_hp"]
    if "crit_chance" in _trait_stat_mods:
        stats.crit_chance = clampf(stats.crit_chance + _trait_stat_mods["crit_chance"], 0.0, 1.0)
    if "dodge_chance" in _trait_stat_mods:
        stats.dodge_chance = clampf(stats.dodge_chance + _trait_stat_mods["dodge_chance"], 0.0, 1.0)
```

#### A.5 产兵路径接入

在 `_produce_unit()` 方法中，ConstructUnit 创建后、加入战场前，调用：

```gdscript
## v9.1: 给产出的单位应用 trait 加成
func _apply_trait_to_spawned_unit(unit: Node2D) -> void:
    if unit == null or not is_instance_valid(unit):
        return
    if "stats" in unit and unit.stats != null and not _trait_stat_mods.is_empty():
        _apply_trait_mods_to_stats(unit.stats)
```

在 `_produce_unit_with_equipment()` 和 `_produce_unit_fallback()` 的末尾各加一行调用。

#### A.6 公开 getter

```gdscript
## v9.1: 返回缓存的 trait 统计加成 dict，供 UI 和测试使用
func get_trait_stat_mods() -> Dictionary:
    return _trait_stat_mods.duplicate()
```

---

### B. 被动技能覆盖补全

**目标：** 让 `_apply_passive_buffs` 和 `_tick_aura_damage` 处理 data 中定义的全部 effect 类型。

#### B.1 扩展 `_apply_passive_buffs`

在现有 thorn 分支（L148）之后新增：

```gdscript
## v9.1: 能量护盾被动（energy_shield）→ boss 自身获得护盾
elif effect.find("energy_shield") >= 0 or effect.find("shield") >= 0:
    var shield_pct: float = float(params.get("shield_pct", params.get("bonus", 0.20)))
    if _driver != null and is_instance_valid(_driver) and _driver.has_method("add_boss_shield"):
        var boss_max_hp: float = float(_driver.get("max_hp", 1000.0))
        var shield_amt: float = boss_max_hp * shield_pct
        shield_amt = minf(shield_amt, boss_max_hp * 0.60)
        _driver.add_boss_shield(shield_amt)
    _show_toast("🛡 %s：boss 获得 %.0f 护盾" % [name_text, shield_amt])

## v9.1: 友军死亡回盾被动（death_shield）→ 标记回调
elif effect.find("death_shield") >= 0:
    var shield_pct: float = float(params.get("shield_percent", params.get("shield_pct", 0.05)))
    if _driver != null and is_instance_valid(_driver):
        _driver.set_meta("death_shield_pct", shield_pct)
    _show_toast("💚 %s：友军死亡时恢复护盾" % name_text)

## v9.1: 高能量增益被动（high_energy_bonus）→ 记录阈值
elif effect.find("high_energy") >= 0 or effect.find("overcharge") >= 0:
    var threshold: float = float(params.get("threshold", 0.8))
    var boost: float  = float(params.get("attack_speed_boost", params.get("boost", 0.4)))
    if _driver != null and is_instance_valid(_driver):
        _driver.set_meta("high_energy_threshold", threshold)
        _driver.set_meta("high_energy_boost", boost)
    _show_toast("⚡ %s：能量超 %d%% 时攻速+%d%%" % [name_text, int(threshold*100), int(boost*100)])

## v9.1: 大规模治疗光环被动（massive_heal_aura）→ 标记到 driver，由 tick 处理
elif effect.find("heal") >= 0 or effect.find("healing") >= 0 or effect.find("massive_heal") >= 0:
    var heal_pct: float = float(params.get("heal_percent", params.get("bonus", 0.04)))
    var radius: float = float(params.get("radius", 250.0))
    if _driver != null and is_instance_valid(_driver):
        _driver.set_meta("heal_aura_percent", heal_pct)
        _driver.set_meta("heal_aura_radius", radius)
    _show_toast("✨ %s：范围内友军每秒恢复 %d%% HP" % [name_text, int(heal_pct*100)])
```

#### B.2 扩展 `_tick_aura_damage` 支持治疗

```gdscript
## v9.1: 治疗光环 tick（massive_heal_aura 类，正向治疗友军）
func _tick_aura_heal(params: Dictionary, tick_dt: float) -> void:
    if not _driver or not is_instance_valid(_driver):
        return
    if not _driver.has_meta("heal_aura_percent"):
        return
    var radius: float = float(_driver.get_meta("heal_aura_radius", 250.0))
    var heal_pct: float = float(_driver.get_meta("heal_aura_percent", 0.04))
    var boss_pos: Vector2 = _get_driver_pos()
    var allies: Array = _driver.get_tree().get_nodes_in_group("enemy_units")
    for a in allies:
        if a == null or not is_instance_valid(a) or not (a is Node2D):
            continue
        if boss_pos.distance_to(a.global_position) > radius:
            continue
        var a_max_hp: float = 100.0
        if "stats" in a and a.stats != null and "max_hp" in a.stats:
            a_max_hp = float(a.stats.max_hp)
        var heal_amt: float = a_max_hp * heal_pct * tick_dt
        if heal_amt > 0.0 and a.has_method("heal"):
            a.heal(heal_amt)
```

在 `update_passives` 中（L104 之后）追加调用：
```gdscript
        if _is_heal_aura_effect(effect):
            _tick_aura_heal(params, tick_dt)
```

新增辅助函数：
```gdscript
## v9.1: 治疗光环判定
func _is_heal_aura_effect(effect: String) -> bool:
    return effect.find("heal") >= 0 or effect.find("healing") >= 0 or effect.find("massive_heal") >= 0
```

#### B.3 友军死亡触发回盾

在 `_apply_passive_buffs` 中 `death_shield` 分支已标记 `set_meta("death_shield_pct", ...)`。
在 driver 的 `_on_any_unit_died()` 末尾追加：
```gdscript
## v9.1: 友军死亡触发 death_shield 回盾
if _master_config_cache.has("passive_spells"):
    for spell in _master_config_cache["passive_spells"]:
        if spell is Dictionary and String(spell.get("effect", "")).find("death_shield") >= 0:
            var pct: float = float(spell.get("params", {}).get("shield_percent", 0.05))
            if hp > 0:
                add_boss_shield(max_hp * pct)
```

---

### C. Phase师基地光环环（新建视觉）

**目标：** 相位师基地周围显示一个呼吸光环，与普通敌方单位（仅阵营 tint）形成明显视觉区分。

#### C.1 新建 `scenes/units/enemy_phase_aura_ring.gd`

```gdscript
extends Control
## v9.1: 敌方相位师基地专属光环环
## 呼吸动画 + 阵营色驱动，绘制在基地底座下方（z_index=-1）
## 类似 FortShieldAura 但更大（半径 120~200px）、更醒目

const SEGMENTS: int = 64
const BREATH_PERIOD: float = 2.5     # 呼吸周期，比 FortShieldAura 更慢（基地是固定点）
const BREATH_AMP: float = 0.08       # 呼吸幅度较小（基地不活跃移动）
const RING_WIDTH: float = 4.0        # 环宽度
const OUTER_GLOW_MULT: float = 1.35  # 外层柔光晕半径倍数

var _base_radius: float = 120.0      # 可通过 meta 覆盖
var _base_color: Color = Color.WHITE # 可通过 meta 设置

func _draw() -> void:
    var t: float = Time.get_ticks_msec() / 1000.0
    var breath: float = 1.0 + BREATH_AMP * (0.5 + 0.5 * sin(t * TAU / BREATH_PERIOD))
    var radius: float = _base_radius * breath

    # 外层柔光晕
    var glow_alpha: float = _base_color.a * 0.20
    draw_circle(Vector2.ZERO, radius * OUTER_GLOW_MULT, Color(_base_color.r, _base_color.g, _base_color.b, glow_alpha))
    # 主圆环
    draw_polyline(_make_ring_pts(radius), _base_color, RING_WIDTH, true)
    # 内层细环（增加层次感）
    var inner_alpha: float = _base_color.a * 0.4
    draw_polyline(_make_ring_pts(radius * 0.88), Color(_base_color.r, _base_color.g, _base_color.b, inner_alpha), 1.5, true)

func _make_ring_pts(radius: float) -> PackedVector2Array:
    var pts: PackedVector2Array = PackedVector2Array()
    pts.resize(SEGMENTS + 1)
    for i in SEGMENTS + 1:
        var ang: float = TAU * float(i) / float(SEGMENTS)
        pts[i] = Vector2(cos(ang), sin(ang)) * radius
    return pts
```

#### C.2 修改 driver：setup() 末尾创建光环

在 `_apply_body_visual_from_master()`（L285）调用之后，加：

```gdscript
## v9.1: 创建基地光环环（视觉区分相位师与普通敌方单位）
_apply_phase_aura_ring()

## v9.1: 懒创建基地光环环节点
func _apply_phase_aura_ring() -> void:
    if has_node("PhaseAuraRing"):
        return
    var ring: Control = Control.new()
    ring.name = "PhaseAuraRing"
    ring.set_script(preload("res://scenes/units/enemy_phase_aura_ring.gd"))
    ring.set_meta("_base_radius", 130.0)
    ring.set_meta("_base_color", _base_body_tint)
    ring.z_index = -1
    add_child(ring)
    ring.pivot_offset = size / 2.0  # 中心对齐

## v9.1: 同步疲劳视觉到光环环
func _sync_aura_ring_fatigue(tier: int) -> void:
    var ring: Control = get_node_or_null("PhaseAuraRing") as Control
    if ring == null:
        return
    var base: Color = _base_body_tint
    var alpha: float
    match tier:
        0: alpha = 0.6
        1: alpha = 0.45
        2: alpha = 0.25
        _:   alpha = 0.08
    ring.set_meta("_base_color", Color(base.r, base.g, base.b, alpha))
    ring.queue_redraw()
```

#### C.3 修改 `_apply_fatigue_visual`：同步光环

在现有 `_apply_fatigue_visual`（L849）末尾追加：
```gdscript
    _sync_aura_ring_fatigue(tier)
```

---

### D. 被动 buff 视觉脉冲

**目标：** buff 应用时基地短暂闪光，让玩家感知到"这个 boss 有被动效果"。

#### D.1 新增 `_flash_body_on_buff()`

```gdscript
## v9.1: buff 应用时基地闪光反馈（0.4s 亮度脉冲）
var _buff_flash_tween: Tween = null
func _flash_body_on_buff() -> void:
    if _buff_flash_tween:
        _buff_flash_tween.kill()
    _buff_flash_tween = create_tween()
    _buff_flash_tween.tween_method(_set_flash_modulate, 0.0, 1.0, 0.15)
    _buff_flash_tween.tween_interval(0.1)
    _buff_flash_tween.tween_method(_unset_flash_modulate, 1.0, 0.0, 0.15)
    _buff_flash_tween.set_trans(Tween.TRANS_QUAD)
    _buff_flash_tween.set_ease(Tween.EASE_OUT)

func _set_flash_modulate(t: float) -> void:
    var spr: Sprite2D = get_node_or_null("Body") as Sprite2D
    if spr == null:
        return
    spr.modulate = _base_body_tint.lerp(Color.WHITE, t * 0.3)

func _unset_flash_modulate(t: float) -> void:
    var spr: Sprite2D = get_node_or_null("Body") as Sprite2D
    if spr == null:
        return
    spr.modulate = _base_body_tint.lerp(Color.WHITE, t * 0.3)
```

#### D.2 在 trait 应用和 buff 应用后调用闪光

- `_apply_trait_effects()` 末尾：`_flash_body_on_buff()`
- `_apply_passive_buffs()` 每个分支 toast 后：`_driver._flash_body_on_buff()`（skill_engine 回调）

---

### E. 情报面板 trait 数值化

**目标：** trait 显示从纯文字改为显示具体数值，让玩家直观感知加成。

#### E.1 修改 `_show_enemy_phase_driver`（card_info_panel.gd L1544-1554）

原代码：
```gdscript
for t in cfg.get("traits", []) as Array:
    if t is Dictionary:
        var tn: String = str(t.get("name", ""))
        var td: String = str(t.get("description", ""))
        if not tn.is_empty():
            trait_lines.append("◆ %s%s" % [tn, "：" + td if not td.is_empty() else ""])
```

改为：
```gdscript
for t in cfg.get("traits", []) as Array:
    if t is Dictionary:
        var tn: String = str(t.get("name", ""))
        var val_str: String = _format_trait_effects(t)
        if not tn.is_empty():
            trait_lines.append("◆ %s%s" % [tn, "：" + val_str if not val_str.is_empty() else str(t.get("description", ""))])
```

#### E.2 新增辅助函数 `_format_trait_effects`

```gdscript
## v9.1: 将 trait.effects dict 格式化为中文数值描述
func _format_trait_effects(trait: Dictionary) -> String:
    var fx: Dictionary = trait.get("effects", {})
    if fx.is_empty():
        return ""
    var parts: Array[String] = []
    for key in fx:
        var val: float = float(fx[key])
        var label: String = _trait_key_to_label(key)
        if label.is_empty():
            continue
        if key == "crit_chance" or key == "dodge_chance" or key == "all_stat_boost":
            parts.append("%s+%d%%" % [label, int(val * 100)])
        elif key == "hp":
            parts.append("HP+%d%%" % int(val * 100))
        elif key == "unit_limit_bonus":
            parts.append("出兵上限+%d" % int(val))
        else:
            parts.append("%s+%d%%" % [label, int(val * 100)])
    return "、".join(parts)

## v9.1: trait effect key → 中文标签映射
func _trait_key_to_label(key: String) -> String:
    match key:
        "atk_light", "atk_armor", "atk_air", "all_stat_boost": return "攻击"
        "def_light", "def_armor", "def_air":                 return "防御"
        "crit_chance":                                        return "暴击率"
        "dodge_chance":                                       return "闪避"
        "hp":                                                 return "生命"
        "unit_limit_bonus":                                   return "出兵上限"
        _: return ""
```

#### E.3 同步修改 `_show_enemy_phase_master_unit`（L1883-1892）

同样的 trait 格式化逻辑，保持两处显示一致。

---

## 四、改动文件汇总

| 文件 | 改动行数（估） | 改动模块 |
|------|--------------|---------|
| `scenes/units/enemy_phase_field_driver.gd` | +60 ~ +80 | A+C+D |
| `managers/battle/enemy_master_skill_engine.gd` | +40 ~ +50 | B+D |
| `scenes/units/enemy_phase_aura_ring.gd` | ~40（新建） | C |
| `scenes/ui/card_info_panel.gd` | +25 ~ +35 | E |

---

## 五、验证计划

### 5.1 语法验证
```bash
"D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --check-only
```
注意：本项目 133 卡构建常接近 5 分钟超时，属既有现象。

### 5.2 静态核对

| 检查项 | 方法 |
|--------|------|
| trait key 映射与 UnitStats 字段名一致 | grep `attack_light`/`defense_light`/`crit_chance`/`dodge_chance` |
| `_apply_trait_effects` 在 setup 末尾被调用 | grep `_apply_trait_effects` |
| `_apply_trait_to_spawned_unit` 在产兵路径被调用 | grep `_apply_trait_to_spawned_unit` |
| `_apply_phase_aura_ring` 在 setup 末尾被调用 | grep `_apply_phase_aura_ring` |
| `_sync_aura_ring_fatigue` 在 `_apply_fatigue_visual` 中被调用 | grep `_sync_aura_ring_fatigue` |
| 被动技能扩展分支拼写正确 | grep `death_shield`/`high_energy`/`massive_heal` |
| `_format_trait_effects` 在两处 trait 显示处被调用 | grep `_format_trait_effects` |

### 5.3 实机验证清单

- [ ] 进入任意相位师关卡，点击基地 → 情报面板 trait 显示具体数值（如"防御+10%"）
- [ ] 产兵完成后，战场敌方单位 stats 有 trait 加成（攻击/防御数值高于配置表）
- [ ] 相位师基地周围可见呼吸光环环（区别于普通敌方单位的纯色 tint）
- [ ] buff 应用时基地有短暂白色闪光反馈
- [ ] fatigue tier 变化时光环透明度同步降低
- [ ] `energy_shield`/`death_shield` 类被动技能在战斗中实际触发（toast 提示 + 护盾值变化）
- [ ] `high_energy_bonus` 在能量超阈值时攻速提升（可通过 toast 确认）
- [ ] Godot `--check-only` 无语法错误

---

## 六、风险与注意事项

1. **Trait 加成叠加问题**：同一相位师可能有多个 trait，各自修改同一字段（如两个 trait 都改 `def_light`）。方案采用乘法叠加（`_trait_stat_mods[key] *= (1+val)`），避免加法重复计算。

2. **产兵时序**：trait 在 setup 时缓存，产兵路径独立应用。若 setup 时已有 enemy_units（补兵队列残留），会同步应用；后续产兵也会各自应用，不会出现遗漏。

3. **光环环性能**：`_draw()` 每帧调用，但仅绘制 64 段圆环 + 2 个圆，计算量极小。无粒子系统，不会对低端设备造成负担。

4. **向后兼容**：所有新字段用 `.get(key, default)` 读，旧相位师数据缺省 `traits` 字段时返回空数组，行为与改动前完全一致。

5. **被动技能扩展范围**：本次仅扩展 `_apply_passive_buffs` 中未覆盖的 effect 类型。`auto_resurrect`/`cheat_death`/`execute_damage` 等复杂 effect 留待后续独立任务（需写入 unit meta 并在受击/死亡时触发）。
