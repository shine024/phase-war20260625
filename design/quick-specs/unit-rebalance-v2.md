# 单位重平衡方案 v2

> **状态**: 待审核
> **日期**: 2026-05-25
> **影响文件**: `resources/unit_stats_table.gd`, `data/affix_definitions.gd`, `data/battle_card_v3.gd`
> **设计原则**: 缩小DPS极差 / 平台定位分化 / 新增3个词条

---

## 一、核心问题诊断

| # | 问题 | 严重度 |
|---|------|--------|
| 1 | OMEGA_CANNON DPS=100, 是MG的4倍 — 终极武器碾压过大 | 高 |
| 2 | RAIL_CANNON DPS=84.8, 仅次于OMEGA | 高 |
| 3 | SHOTGUN 射程65 + DPS=16 — 近战武器缺乏DPS补偿 | 中 |
| 4 | SNIPER DPS=11.0 低于RIFLE(12.0) — 远距高单发但不突出 | 中 |
| 5 | FORTRESS(HP280/DEF16) vs SIEGE(HP350/DEF15) 定位重叠 | 中 |
| 6 | COMMAND(HP120/DEF6) 太脆弱 | 中 |
| 7 | PISTOL DPS=12.5 最弱武器 | 低 |
| 8 | SCOUT耐久指数63 vs SIEGE 875 — 13.9倍差距 | 低(闪避补偿) |

---

## 二、平台属性调整

### get_platform_base 新数值

| 平台 | 旧HP | **新HP** | 旧SPD | **新SPD** | 固定 | 变更理由 |
|------|------|----------|-------|-----------|------|----------|
| HOUND | 60 | **65** | 120 | **115** | 否 | HP微升提高生存 |
| GUARD | 100 | **110** | 80 | **75** | 否 | 增强前线坦克定位 |
| TITAN | 180 | **200** | 45 | **40** | 否 | 强化重装肉盾 |
| FORTRESS | 280 | **260** | 0 | **0** | 是 | HP↓但DEF↑↑(→20)，纯防御 |
| RADAR | 200 | **180** | 0 | **0** | 是 | 降低HP，辅助角色 |
| SCOUT | 45 | **50** | 140 | **135** | 否 | HP微升 |
| RAIDER | 85 | **90** | 95 | **100** | 否 | 速度微升，突击更敏捷 |
| SIEGE | 350 | **300** | 25 | **0** | 是 | **改为完全固定**，与FORTRESS区分(攻 vs 防) |
| CARRIER | 130 | **140** | 55 | **50** | 否 | HP↑增强辅助续航 |
| MEDIC | 90 | **80** | 70 | **75** | 否 | 降低坦度，辅助不应太硬 |
| STEALTH | 55 | **50** | 110 | **115** | 否 | 与HOUND同级速度(渗透定位) |
| OMEGA | 260 | **240** | 35 | **30** | 否 | HP↓DEF↑，3武器槽已提供输出 |
| COMMAND | 120 | **150** | 0 | **0** | 是 | 大幅强化，指挥车不应脆弱 |

### get_platform_defense 新数值

| 平台 | 旧DEF | **新DEF** | 变更理由 |
|------|-------|-----------|----------|
| HOUND | 5 | **5** | 不变 |
| GUARD | 8 | **9** | 增强前线定位 |
| TITAN | 12 | **13** | 增强重装 |
| FORTRESS | 16 | **20** | **大幅提升**，定义"纯防御" |
| RADAR | 13 | **11** | 辅助不需要高DEF |
| SCOUT | 4 | **4** | 不变 |
| RAIDER | 7 | **7** | 不变 |
| SIEGE | 15 | **14** | 微降，攻击型不需要最高DEF |
| CARRIER | 9 | **8** | 辅助型 |
| MEDIC | 7 | **6** | 辅助型 |
| STEALTH | 5 | **5** | 不变 |
| OMEGA | 14 | **15** | 微升，终极平台 |
| COMMAND | 6 | **10** | **大幅提升**，指挥车需要存活 |

### get_weapon_defense 新数值

| 武器 | 旧wDEF | **新wDEF** | 理由 |
|------|--------|-----------|------|
| SMG/PISTOL/SNIPER/ROCKET/MISSILE | 0~1 | **0** | 轻型武器不加防 |
| RIFLE/SHOTGUN/LASER/FLAK | 1~2 | **1** | 标准武器+1 |
| MG/OMEGA_CANNON/RAIL_CANNON | 2 | **2** | 重型武器+2 |

---

## 三、武器属性调整

### get_weapon_base 新数值

| 武器 | 旧DMG | **新DMG** | 旧RNG | **新RNG** | 旧IVL | **新IVL** | 旧DPS | **新DPS** |
|------|-------|-----------|-------|-----------|-------|-----------|-------|-----------|
| SMG | 7 | **8** | 90 | **95** | 0.39 | **0.38** | 17.9 | **21.1** |
| PISTOL | 5 | **7** | 80 | **85** | 0.40 | **0.45** | 12.5 | **15.6** |
| RIFLE | 12 | **14** | 150 | **155** | 1.00 | **0.95** | 12.0 | **14.7** |
| SNIPER | 17 | **28** | 230 | **240** | 1.545 | **1.60** | 11.0 | **17.5** |
| MG | 6 | **7** | 165 | **160** | 0.24 | **0.25** | 25.0 | **28.0** |
| SHOTGUN | 16 | **22** | 65 | **60** | 1.00 | **0.85** | 16.0 | **25.9** |
| ROCKET | 29 | **30** | 190 | **195** | 1.80 | **1.70** | 16.1 | **17.6** |
| MISSILE | 36 | **38** | 210 | **215** | 2.00 | **2.00** | 18.0 | **19.0** |
| FLAK | 8 | **9** | 120 | **125** | 0.364 | **0.35** | 22.0 | **25.7** |
| LASER | 11 | **13** | 180 | **185** | 0.55 | **0.50** | 20.0 | **26.0** |
| OMEGA_CANNON | 220 | **85** | 250 | **260** | 2.20 | **2.00** | 100.0 | **42.5** |
| RAIL_CANNON | 140 | **55** | 240 | **250** | 1.65 | **1.50** | 84.8 | **36.7** |

### DPS 分层设计

```
终极武器:  OMEGA_CANNON(42.5) / RAIL_CANNON(36.7)   — 仅为常规的 ~1.5x
常规DPS王: MG(28.0) / LASER(26.0) / SHOTGUN(25.9) / FLAK(25.7)
中距离:    SMG(21.1) / MISSILE(19.0) / ROCKET(17.6) / SNIPER(17.5)
基准线:    RIFLE(14.7) / PISTOL(15.6)
```

---

## 四、平台固有能力调整

### apply_platform_innate_modifiers 变更

| 平台 | 旧固有能力 | **新固有能力** |
|------|-----------|---------------|
| SIEGE | 射程×1.15 | **射程×1.18** (增强) |
| FORTRESS | HP×1.10 | **HP×1.12, DEF+3** (防御大幅强化) |
| RADAR | 射程×1.10 | **射程×1.12** (微增) |
| TITAN | DEF+3 | **DEF+4** (增强) |
| SCOUT/STEALTH | 闪避≥15% | SCOUT **≥18%**, STEALTH **≥20%** |
| CARRIER | — | **HP×1.08** (新增) |
| COMMAND | — | **光环: 友军DMG+10% DEF+10%** (新增) |

---

## 五、星级成长倾斜调整

### get_platform_growth_bias 变更

| 平台 | 新倾斜 | 说明 |
|------|--------|------|
| HOUND | hp_bias=0.04, dmg_bias=0.05, **dodge_bias=0.03** | 新增闪避成长 |
| GUARD | hp_bias=0.06, def_bias=0.04, dmg_bias=0.04 | 均衡成长 |
| TITAN | hp_bias=0.08, def_bias=0.06 | 重装堆叠 |
| FORTRESS | hp_bias=0.10, **def_bias=0.08** | 防御堆叠(旧无def_bias) |
| RADAR | range_bias=0.06, def_bias=0.04 | 辅助射程成长 |
| SCOUT | **dodge_bias=0.05**, dmg_bias=0.05, speed_bias=0.03 | 闪避+伤害 |
| RAIDER | dmg_bias=0.07, speed_bias=0.04 | 纯攻击成长 |
| SIEGE | hp_bias=0.08, **dmg_bias=0.06**, range_bias=0.04 | 新增伤害成长 |
| CARRIER | hp_bias=0.05, heal_bias=0.08 | 辅助续航 |
| MEDIC | heal_bias=0.10, hp_bias=0.04 | 纯治疗 |
| STEALTH | **dodge_bias=0.06**, dmg_bias=0.04 | 闪避为主 |
| OMEGA | hp_bias=0.08, dmg_bias=0.08, def_bias=0.06 | 全方位成长 |
| COMMAND | hp_bias=0.06, def_bias=0.05 | 生存成长 |

---

## 六、新增词条

### affix_definitions.gd 新增3个词条

#### 1. platform_def_up — 复合装甲
```gdscript
"platform_def_up": {
    "affix_name":         "复合装甲",
    "description":        "平台防御值提升",
    "affix_type":         "base_property",
    "effect_key":         "defense",
    "base_value":         1.0,     # +1 DEF (Lv1)
    "card_type_filter":   0,       # 仅平台
    "weapon_type_filter": -1,
    "rarity_pool":        ["common", "rare", "epic", "legendary"],
    "unlock_condition":   "none",
}
```

#### 2. dodge_chance — 相位闪避
```gdscript
"dodge_chance": {
    "affix_name":         "相位闪避",
    "description":        "攻击有一定几率被完全闪避",
    "affix_type":         "combat_feature",
    "effect_key":         "dodge_chance",
    "base_value":         0.05,    # +5% 闪避 (Lv1)
    "card_type_filter":   0,       # 仅平台
    "weapon_type_filter": -1,
    "rarity_pool":        ["common", "rare", "epic", "legendary"],
    "unlock_condition":   "none",
}
```

#### 3. crit_dmg_up — 致命一击
```gdscript
"crit_dmg_up": {
    "affix_name":         "致命一击",
    "description":        "暴击造成的额外伤害提升",
    "affix_type":         "combat_feature",
    "effect_key":         "crit_damage_bonus",
    "base_value":         0.15,    # 暴击倍率 +0.15 (Lv1)
    "card_type_filter":   1,       # 仅武器
    "weapon_type_filter": -1,
    "rarity_pool":        ["rare", "epic", "legendary"],
    "unlock_condition":   "boss_1",
}
```

### 现有词条数值微调

| 词条ID | 旧base_value | **新base_value** | 说明 |
|--------|-------------|-----------------|------|
| platform_speed_up | 0.10 | **0.08** | 速度不宜过高 |
| platform_armor | 0.08 | **0.06** | 减伤过高会让坦克无敌 |
| crit_chance | 0.08 | **0.06** | 暴击基础过高 |
| lifesteal | 0.05 | **0.04** | 微调 |
| splash_dmg | 0.20 | **0.15** | 溅射过高 |
| nano_regen | 0.005 | **0.004** | 回复稍强 |

---

## 七、时代缩放系数调整

### BattleCardV3 缩放变更

| 系数 | 旧公式 | **新公式** | 理由 |
|------|--------|-----------|------|
| 伤害 | 1.0 + era × 0.25 | **1.0 + era × 0.225** | 降低每级跳跃(0.25→0.225) |
| 射程 | 1.0 + era × 0.10 | **1.0 + era × 0.08** | 射程成长过快 |
| HP | 1.0 + era × 0.15 | **1.0 + era × 0.12** | HP成长过快 |

时代伤害/射程/HP 具体数值:

| 时代 | 旧DMG倍率 | 新DMG | 旧RNG | 新RNG | 旧HP | 新HP |
|------|----------|-------|-------|-------|------|------|
| WW1(0) | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| WW2(1) | 1.25 | **1.225** | 1.10 | **1.08** | 1.15 | **1.12** |
| COLD(2) | 1.50 | **1.45** | 1.20 | **1.16** | 1.30 | **1.24** |
| MODERN(3)| 1.75 | **1.675** | 1.30 | **1.24** | 1.45 | **1.36** |
| FUTURE(4)| 2.00 | **1.90** | 1.40 | **1.32** | 1.60 | **1.48** |

---

## 八、100种核心单位组合评分表

见上方输出中的完整100行组合表。评分公式:

```
score = (DPS × 2 + HP/10 + DEF) × (Range/150)^0.5
```

评分等级: S(>35) / A(>25) / B(>18) / C(>12) / D(≤12)

### 预期分布
- S级(~60%): 高端组合，策略首选
- A级(~25%): 中等强度，可用的替代方案
- B级(~10%): 特殊场景有用(如MEDIC)
- C/D级(~5%): 弱势但辅助型(如MEDIC+PISTOL)

---

## 九、影响评估

### 受影响的系统
1. **unit_stats_table.gd** — 平台/武器基础数值、防御、固有能力、成长倾斜
2. **affix_definitions.gd** — 新增3词条 + 现有词条数值微调
3. **battle_card_v3.gd** — 时代缩放系数
4. **default_cards.gd** — summary_line文案需更新(防御值变化)
5. **UnitStats** — 需确认 dodge_chance / crit_damage_bonus 字段是否存在
6. **战斗系统** — 需确认闪避/暴击倍率是否有对应计算逻辑

### 不受影响
- 敌人生成逻辑(enemy_unit_manifest.gd 会自动读取新数值)
- 掉落表(不变)
- 法则系统(不变)
- 经济系统(不变)

### 风险点
- OMEGA_CANNON伤害从220→85，可能导致OMEGA平台吸引力下降
  - **缓解**: OMEGA仍有3武器槽，总DPS仍然领先
- SIEGE改为完全固定(速度25→0)，可能影响现有关卡设计
  - **缓解**: 攻城炮本就应该固定(曲射武器)

---

## 十、实施步骤

1. 修改 `resources/unit_stats_table.gd` (平台/武器数值、防御、固有能力、成长倾斜)
2. 修改 `data/affix_definitions.gd` (新增3词条 + 微调现有数值)
3. 修改 `data/battle_card_v3.gd` (时代缩放系数)
4. 更新 `data/default_cards.gd` (summary_line防御值文案)
5. 确认 `resources/unit_stats.gd` 有 dodge_chance / crit_damage_bonus 字段
6. 运行单元测试验证
7. 运行 Godot --check-only 验证编译

---

**文档状态**: 待审核。确认后即可按步骤实施。
