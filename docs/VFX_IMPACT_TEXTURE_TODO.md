# 命中贴图补图清单（v8.4）

> 生成时间：2026-07-15
> 关联改动：v8.4 弹道与击中效果系统补强（见 git log）
> 当前状态：**未补图也能运行**——所有缺口已 fallback 到通用贴图 `weapon_artillery_impact.png`，命中贴图层全覆盖。本清单是为"想给每个武器专属爆炸图"准备的美术任务清单。

## 背景

重型爆炸武器（`weapon_type ∈ {3 ROCKET, 7 FLAK, 9 MISSILE}`）命中时，会叠加一张专属爆炸贴图层（在三层粒子特效之上）。贴图通过 `data/weapon_vfx_mapping.gd` 的 `WEAPON_ID_MAP`（武器 display_name → 8位hex safe_id）查找：

- 路径规则：`assets/effects/projectiles/weapons_realistic/<safe_id>_impact.png`
- 查找逻辑：`scripts/weapon_projectile_vfx.gd` → `impact_texture_by_name()`
- **查不到时**：fallback 到 `weapon_artillery_impact.png`（通用爆炸图，所有缺口当前都用它）

**贴图规格**（参考现有专属贴图）：
- 尺寸：512×512 PNG 透明背景（仓库现有贴图多为 4-8KB，通用图 1MB 偏大属特例）
- 风格：径向爆炸火光，中心亮、向外扩散，可带武器特征（导弹尾焰/高炮破片/激光能量等）
- 命名：`<safe_id>_impact.png`，safe_id 是 8 位 hex（生成后填入映射表）

## 缺口总览

共 **10 个缺口** display_name。去重后统计：
- **A 类（3 个）**：只需在 `weapon_vfx_mapping.gd` 加一条别名映射，复用现有贴图，**零补图**
- **B 类（7 个）**：需要新画一张专属 `<safe_id>_impact.png`

---

## A 类：加别名映射即可（零补图）✅ 已完成 (2026-07-15)

已在 `data/weapon_vfx_mapping.gd` 的 `WEAPON_ID_MAP` 末尾加这 3 条别名，复用现有贴图。

| display_name | weapon_type | 来源卡牌 | 建议映射 | 复用的贴图（已有） |
|---|---|---|---|---|
| `空空导弹` | 9 MISSILE | `cold_boss_mig`(Boss)、`mod_air_apache_e`(精锐)、`fut_air_heavy_carrier`(改造 air_06/07) | `"空空导弹": "24b45a0c"` | `24b45a0c_impact.png`（现有"空空导弹/20mm机炮"） |
| `萨姆-7防空导弹` | 9 MISSILE | `cold_sam7`（含装 aa_05 近炸引信场景） | `"萨姆-7防空导弹": "70912efd"` | `70912efd_impact.png`（现有"萨姆-7导弹/防空导弹"） |
| `防空导弹` | 9 MISSILE | `mod_boss_command`(Boss)、`mod_inf_patriot`(爱国者)、`fut_arm_titan_mk2` | `"防空导弹": "e676771a"` | `e676771a_impact.png`（现有"便携式防空导弹"） |

---

## B 类：需新画专属贴图（6 张，B7 已转代码修复）

每张画完后，按"画完后的处理"两步走：① 把 png 放到 `assets/effects/projectiles/weapons_realistic/`；② 在 `data/weapon_vfx_mapping.gd` 加映射条目。

> ✅ **B 类 6 张已全部交付 (2026-07-15)**：贴图已放入目录，映射已配入 `weapon_vfx_mapping.gd:69-75`，safe_id 与下表建议值一致。

| # | display_name | weapon_type | 来源卡牌/改造 | 建议 safe_id | 优先级 | 备注 |
|---|---|---|---|---|---|---|
| **B1** | `炮射导弹` | 9 MISSILE | 改造 `arm_07_gun_missile`（`armor_mods.gd:206` 显式设 display_name） | `9c8d7e6f` | **高** | 影响**所有装炮射导弹的装甲卡**对空射击。是唯一来自"改造显式命名"的缺口。建议画细长导弹爆炸+蓝白尾焰（与该改造的程序化蓝白拖尾视觉呼应） |
| **B2** | `毒刺防空导弹` | 9 MISSILE | `mod_stinger` 毒刺导弹兵（含装 aa_05 场景） | `f1a2b3c4` | 中 | 可选降级为复用 `e676771a`（便携式防空导弹），但"毒刺"有辨识度，建议新画 |
| **B3** | `守护者防空` | 9 MISSILE | `guardian_ww1_ironclad` 铁壁守护者·一战（Boss，slot2） | `a1b2c3d4` | 低 | 守护者系列专属命名（4 张 Boss 卡） |
| **B4** | `闪电防空` | 9 MISSILE | `guardian_ww2_blitzkrieg` 闪电守护者·二战（Boss，slot2） | `b2c3d4e5` | 低 | 守护者系列专属命名 |
| **B5** | `幽灵空空导弹` | 9 MISSILE | `guardian_modern_stealth` 幽灵守护者·现代（Boss，slot2） | `c3d4e5f6` | 低 | 守护者系列专属命名 |
| **B6** | `终焉防空` | 9 MISSILE | `guardian_future_omega` 终焉守护者·近未来（Boss，slot2） | `d4e5f6a7` | 低 | 守护者系列专属命名 |
| ~~**B7**~~ | ~~`霰弹枪`~~ | ~~9 MISSILE~~ | ~~`fut_sup_bulwark`~~ | ~~`e5f6a7b8`~~ | — | ✅ **已修复 (2026-07-15)**：经核实是数据语义错配——"霰弹枪"配在 w_light(slot0) 默认走 DIRECT 直射，无散射效果。已在 `card_resource.gd` 加 `_WEAPON_NAME_TRAJECTORY_OVERRIDE` 按武器名覆盖为 SHOTGUN(5) 弹道（6发18°散射）。SHOTGUN 走纯粒子命中特效（不在贴图查找范围），**无需补图** |

> safe_id 是建议值，实际生成贴图后可改用任意 8 位 hex（保证不与现有 55 个 safe_id 重复即可）。现有 safe_id 清单见 `weapon_vfx_mapping.gd`。

---

## 5 个武器类改造的贴图缺口速查

针对 v8.4 新增的 5 个改造（专属视觉是程序化粒子，**与贴图无关**；此处仅指命中贴图层）：

| 改造 | 装备卡牌 | 命中贴图层 | 缺口 |
|---|---|---|---|
| `art_03` 制导炮弹 | 所有火炮（6张） | ✅ 全生效（w_armor 都在映射） | 无 |
| `art_04` 子母弹 | 所有火炮（6张） | ✅ 全生效 | 无 |
| `art_11` 温压弹 | 所有火炮（6张） | ✅ 全生效 | 无 |
| `aa_05` 近炸引信 | 高炮类（4张） | ✅ 生效 | 无 |
| `aa_05` 近炸引信 | 萨姆-7 / 毒刺 | ⚠️ fallback 通用图 | A2 + B2 |
| `arm_07` 炮射导弹 | 所有装甲卡 | ⚠️ fallback 通用图 | **B1** |

---

## 不在清单里的（已全覆盖）

以下重型爆炸武器的 display_name 已在 `WEAPON_ID_MAP` 中且有对应贴图，命中贴图层正常生效，**无需补图**：

- 所有火炮的 w_armor 武器名（迫击炮/野战炮、105mm/120mm榴弹炮、81mm/105mm火炮、电磁轨道炮等）
- 高炮类 w_air 武器名（23mm/30mm高射炮、20mm/25mm高炮、25mm近防炮、点防御激光、MG42/双联防空炮等）
- 舰炮/重机枪类（12.7mm重机枪、150mm要塞炮/88mm防空炮、地狱火导弹/127mm舰炮等）
- 未来能量武器（离子炮、离子炮阵列、轨道炮/激光等）

合计 **55 个 display_name 已全覆盖**（与 55 张现有贴图一一对应）。

---

## 处理优先级建议

1. ~~**先做 A 类**（3 条别名映射，零补图）~~ ✅ 已完成 (2026-07-15)
2. ~~**B1 炮射导弹**~~ ✅ 已交付
3. ~~**B2 毒刺**~~ ✅ 已交付
4. ~~**B3-B6 守护者系列**~~ ✅ 已交付
5. ~~**B7 霰弹枪**~~ ✅ 已转代码修复（数据语义错配，无需补图）

**全部完成。命中贴图层已 100% 覆盖所有重型爆炸武器 + 霰弹枪弹道已修正。**

---

## 相关文件

- `data/weapon_vfx_mapping.gd` — WEAPON_ID_MAP（55 条，需加映射的地方）
- `scripts/weapon_projectile_vfx.gd` — `impact_texture_by_name()`（查找逻辑 + fallback）
- `assets/effects/projectiles/weapons_realistic/` — 贴图存放目录
- `resources/card_resource.gd:720-733` — 对空槽默认 weapon_type=9（MISSILE 缺口的根源）
- `data/unified_card_table.gd` — 卡牌武器槽数据真身（w_light/w_armor/w_air）
