# 敌人清单（完整版）

**数据来源**：`data/enemy_unit_manifest.gd` + `data/enemy_archetypes_*.gd` + `data/json/enemy_archetypes.json`
**版本**：v2.0 | 2026-06-12

---

## 总览

| 类别 | 数量 | 说明 |
|------|------|------|
| A段 原平台线 | 28 | 新时代单位 → `foe_<platform_id>` |
| B段 特殊/精英平台 | 6 | `foe_<special_id>` 精英变体 |
| C段 固定原型 | 36 | 步兵/阵地/精英/Boss（子模块定义） |
| D段 补充池 | 29 | `foe_pool_001`~`029`，供波次/大地图抽取 |
| **合计** | **99** | 另有 `GENERATED_PER_ERA=0` 程序生成关闭 |

> 注：原始文档 `card_icon_manifest_100_zh.md` 写的是100条，但实际代码中 A段28+B段6+C段36+D段29=99。
> 文档中的 #29 `foe_omega_platform` 在代码中被 `fut_nexus` → `omega_platform` 替代。

---

## A段：原平台线（28张）

| # | card_id | archetype_id | display_name | era | 兵种(kind) | 武器 |
|---|---------|-------------|-------------|-----|-----------|------|
| 1 | ww1_rolls | foe_ww1_rolls | 罗尔斯装甲车 | 一战 | 载具 | 机枪 |
| 2 | ww1_ft17 | foe_ww1_ft17 | FT-17轻型坦克 | 一战 | 载具 | 机枪 |
| 3 | ww1_77mm | foe_ww1_77mm | 77mm野战炮 | 一战 | 阵地 | 机枪 |
| 4 | ww1_cavalry | foe_ww1_cavalry | 骑兵斥候 | 一战 | 步兵 | 冲锋枪 |
| 5 | ww1_engineer | foe_ww1_engineer | 工兵班 | 一战 | 阵地 | 步枪 |
| 6 | ww2_hellcat | foe_ww2_hellcat | M18地狱猫 | 二战 | 步兵 | 机枪 |
| 7 | ww2_sherman | foe_ww2_sherman | M4谢尔曼 | 二战 | 载具 | 步枪 |
| 8 | ww2_tiger | foe_ww2_tiger | 虎式坦克 | 二战 | 载具 | 迫击炮 |
| 9 | ww2_bazooka | foe_ww2_bazooka | 巴祖卡组 | 二战 | 步兵 | 冲锋枪 |
| 10 | ww2_panzerschrek | foe_ww2_panzerschrek | 铁拳反坦克组 | 二战 | 步兵 | 冲锋枪 |
| 11 | ww2_m81 | foe_ww2_m81 | 81mm迫击炮 | 二战 | 阵地 | 机枪 |
| 12 | ww1_m81 | foe_ww1_m81 | 81mm迫击炮组 | 一战 | 阵地 | 机枪 |
| 13 | cold_btr60 | foe_cold_btr60 | BTR-60装甲车 | 冷战 | 支援 | 机枪 |
| 14 | cold_t55 | foe_cold_t55 | T-55坦克 | 冷战 | 载具 | 迫击炮 |
| 15 | cold_bmp1 | foe_cold_bmp1 | BMP-1步战车 | 冷战 | 支援 | 机枪 |
| 16 | cold_m113 | foe_cold_m113 | M113装甲车 | 冷战 | 支援 | 机枪 |
| 17 | cold_zsu23 | foe_cold_zsu23 | ZSU-23-4自行高炮 | 冷战 | 阵地 | 步枪 |
| 18 | mod_technical | foe_mod_technical | 皮卡武装 | 现代 | 步兵 | 机枪 |
| 19 | mod_m1a1 | foe_mod_m1a1 | M1A1主战坦克 | 现代 | 载具 | 火炮 |
| 20 | mod_m6 | foe_mod_m6 | 自行高炮M6 | 现代 | 阵地 | 机枪 |
| 21 | mod_m270 | foe_mod_m270 | M270火箭炮 | 现代 | 阵地 | 火箭炮 |
| 22 | fut_scout_drone | foe_fut_scout_drone | 侦察无人机 | 现代 | 支援 | 机枪 |
| 23 | mod_m1a2sep | foe_mod_m1a2sep | M1A2 SEP主战坦克 | 现代 | 载具 | 火炮 |
| 24 | fut_scout_mech | foe_fut_scout_mech | 侦察机甲 | 近未来 | 步兵 | 光束步枪 |
| 25 | fut_hovertank | foe_fut_hovertank | 悬浮坦克 | 近未来 | 载具 | 光束步枪 |
| 26 | fut_prism | foe_fut_prism | 光棱坦克 | 近未来 | 载具 | 米加粒子炮 |
| 27 | fut_heavy_mech | foe_fut_heavy_mech | 重装机甲 | 近未来 | 载具 | 米加粒子炮 |
| 28 | fut_nexus | foe_fut_nexus | 虚空领主/全装型机动舱 | 近未来 | 载具 | 米加粒子炮 |

## B段：特殊/精英平台（6张）

| # | card_id | archetype_id | display_name | era | 兵种 | 武器 |
|---|---------|-------------|-------------|-----|------|------|
| 30 | bulwark | foe_bulwark | 壁垒 | 一战 | 阵地 | 霰弹枪 |
| 31 | titan_mk2 | foe_titan_mk2 | 泰坦Mk.II | 一战 | 载具 | 导弹 |
| 32 | storm_rider | foe_storm_rider | 暴风骑士 | 二战 | 步兵 | 狙击枪 |
| 33 | heavy_carrier | foe_heavy_carrier | 重装母舰 | 二战 | 支援 | 机枪 |
| 34 | regen_frame | foe_regen_frame | 再生骨架 | 冷战 | 支援 | 手枪 |
| 35 | abrams_mk2 | foe_abrams_mk2 | 艾布拉姆斯Mk.II | 现代 | 载具 | 轨道炮 |

## C段：固定敌方原型（36张）

| # | archetype_id | display_name | era | 类型 | 掉落率 |
|---|-------------|-------------|-----|------|--------|
| 36 | enemy_ww1_infantry_basic | 步兵班·MP18 | 一战 | 基础步兵 | 8% |
| 37 | enemy_ww1_infantry_rifle | 李-恩菲尔德步枪班 | 一战 | 基础步兵 | 8% |
| 38 | enemy_ww1_mg_nest | 马克沁机枪阵地 | 一战 | 阵地 | 8% |
| 39 | enemy_ww1_mortar | 81mm 斯托克斯迫击炮组 | 一战 | 阵地 | 8% |
| 40 | elite_ww1_storm | 暴风突击队 | 一战 | 精英步兵 | 22% |
| 41 | elite_ww1_armored | 劳斯莱斯 Mk.I 装甲车 | 一战 | 精英载具 | 22% |
| 42 | boss_ww1_av7 | 圣沙蒙坦克 | 一战 | Boss | 55% |
| 43 | enemy_ww2_infantry | 步兵班·汤普森 | 二战 | 基础步兵 | 8% |
| 44 | enemy_ww2_rifleman | 步枪班·加兰德 | 二战 | 基础步兵 | 8% |
| 45 | enemy_ww2_mg42 | MG42机枪组 | 二战 | 阵地 | 8% |
| 46 | enemy_ww2_panzerschreck | 铁拳 88mm 反坦克组 | 二战 | 阵地 | 8% |
| 47 | elite_ww2_paratrooper | FG42 伞兵班 | 二战 | 精英步兵 | 22% |
| 48 | elite_ww2_panther | 黑豹坦克 | 二战 | 精英载具 | 22% |
| 49 | boss_ww2_kingtiger | 虎王坦克 | 二战 | Boss | 55% |
| 50 | enemy_cold_ak | AKM 摩托化步兵班 | 冷战 | 基础步兵 | 8% |
| 51 | enemy_cold_m60 | M60 机枪步兵班 | 冷战 | 基础步兵 | 8% |
| 52 | enemy_cold_btr | BTR-60PB 装甲输送车 | 冷战 | 载具 | 8% |
| 53 | enemy_cold_m113 | M113A1 装甲输送车 | 冷战 | 载具 | 8% |
| 54 | elite_cold_spetsnaz | Spetsnaz 侦察小组 | 冷战 | 精英步兵 | 22% |
| 55 | elite_cold_t72 | T-72A 主战坦克 | 冷战 | 精英载具 | 22% |
| 56 | boss_cold_mig | 米格-29 | 冷战 | Boss | 55% |
| 57 | enemy_modern_marine | M27 海军陆战队班 | 现代 | 基础步兵 | 8% |
| 58 | enemy_modern_technical | 丰田 Hilux 重机枪车 | 现代 | 基础步兵 | 8% |
| 59 | enemy_modern_stryker | M1126 斯特赖克 ICV | 现代 | 载具 | 8% |
| 60 | enemy_modern_mlrs | M270 MLRS 火箭炮 | 现代 | 阵地 | 8% |
| 61 | elite_modern_delta | CAG 三角洲小队 | 现代 | 精英步兵 | 22% |
| 62 | elite_modern_abrams | M1A2 SEP v3 | 现代 | 精英载具 | 22% |
| 63 | elite_modern_apache | AH-64D 阿帕奇 | 现代 | 精英航空 | 22% |
| 64 | boss_modern_command | 联合星区指挥所 | 现代 | Boss | 55% |
| 65 | enemy_future_drone | 蜂群微型无人机 | 近未来 | 基础步兵 | 8% |
| 66 | enemy_future_cyborg | 外骨骼突击兵 | 近未来 | 基础步兵 | 8% |
| 67 | enemy_future_mech | XM-3 机步突击车 | 近未来 | 载具 | 8% |
| 68 | enemy_future_hovertank | L-220 悬浮主战平台 | 近未来 | 载具 | 8% |
| 69 | elite_future_spectre | 光学迷彩渗透组 | 近未来 | 精英步兵 | 22% |
| 70 | elite_future_colossus | GK-1 重型步行机 | 近未来 | 精英载具 | 22% |
| 71 | boss_future_nexus | 风暴核心指挥塔 | 近未来 | Boss | 55% |

## D段：补充池（29张）

| # | archetype_id | display_name | era | 兵种(kind) |
|---|-------------|-------------|-----|-----------|
| 72 | foe_pool_001 | 李-恩菲尔德志愿兵排 | 一战 | 步兵 |
| 73 | foe_pool_002 | 劳斯莱斯 Mk.II 装甲车 | 一战 | 载具 |
| 74 | foe_pool_003 | 维克斯 .303 机枪阵地 | 一战 | 阵地 |
| 75 | foe_pool_004 | 福特 T 型战地救护车 | 一战 | 支援 |
| 76 | foe_pool_005 | MP18 突击队 | 一战 | 步兵 |
| 77 | foe_pool_006 | M1 加兰德伞兵班 | 二战 | 载具 |
| 78 | foe_pool_007 | 黄蜂 Hummel 自行火炮 | 二战 | 阵地 |
| 79 | foe_pool_008 | PaK 40 反坦克炮组 | 二战 | 支援 |
| 80 | foe_pool_009 | GMC 2.5t 补给卡车 | 二战 | 步兵 |
| 81 | foe_pool_010 | 毛瑟 Kar98k 狙击组 | 二战 | 载具 |
| 82 | foe_pool_011 | BMD-1 空降战车 | 冷战 | 阵地 |
| 83 | foe_pool_012 | BMP-1 步兵战车 | 冷战 | 支援 |
| 84 | foe_pool_013 | 9K111 法特导弹组 | 冷战 | 步兵 |
| 85 | foe_pool_014 | P-18 雷达警戒车 | 冷战 | 载具 |
| 86 | foe_pool_015 | BREM-1 装甲抢修车 | 冷战 | 阵地 |
| 87 | foe_pool_016 | M4 卡宾特遣班 | 现代 | 支援 |
| 88 | foe_pool_017 | 爱国者 PAC-3 发射车 | 现代 | 步兵 |
| 89 | foe_pool_018 | HIMARS 火箭炮组 | 现代 | 载具 |
| 90 | foe_pool_019 | RQ-7 影子无人机班 | 现代 | 阵地 |
| 91 | foe_pool_020 | EA-18G 电子战小组 | 现代 | 支援 |
| 92 | foe_pool_021 | 神经接口突击兵 | 近未来 | 步兵 |
| 93 | foe_pool_022 | HK-07 量产机兵 | 近未来 | 载具 |
| 94 | foe_pool_023 | HEL-30 激光炮阵列 | 近未来 | 阵地 |
| 95 | foe_pool_024 | N-Repair 纳米工程车 | 近未来 | 支援 |
| 96 | foe_pool_025 | X-9 猎杀者渗透组 | 近未来 | 步兵 |
| 97 | foe_pool_026 | 毛瑟 C96 征召兵排 | 近未来 | 载具 |
| 98 | foe_pool_027 | Sd.Kfz.251/1 半履带车 | 近未来 | 阵地 |
| 99 | foe_pool_028 | SS-C-1 岸防导弹组 | 近未来 | 支援 |
| 100 | foe_pool_029 | PS-9 相位中继站 | 近未来 | 步兵 |

---

## 分类统计

### 按稀有度/等级

| 类型 | 数量 | 掉落率 |
|------|------|--------|
| 基础单位 | 73 | 8% |
| 精英单位 | 11 | 22% |
| Boss单位 | 5 | 55% |
| 特殊/平台 | 10 | 8% |
| **合计** | **99** | — |

### 按时代

| 时代 | A段 | B段 | C段 | D段 | 合计 |
|------|-----|-----|-----|-----|------|
| 一战 | 6 | 2 | 7 | 5 | 20 |
| 二战 | 6 | 2 | 7 | 5 | 20 |
| 冷战 | 6 | 1 | 7 | 5 | 19 |
| 现代 | 6 | 1 | 8 | 5 | 20 |
| 近未来 | 4 | 0 | 7 | 9 | 20 |

### 按兵种（kind）

| 兵种 | kind值 | 说明 |
|------|--------|------|
| 步兵 | 0 | 蜂群渲染，swarm_unit=true |
| 载具 | 1 | 地面装甲单位 |
| 阵地 | 2 | 固定位置，turret/sustained标签 |
| 支援 | 3 | 后勤/医疗/雷达等 |
| 堡垒 | 4 | 堡垒级单位（tags: fortress, immobile）|

---

## 与原始文档的差异

1. **原始文档100条 vs 实际99条**：文档#29 `foe_omega_platform` 在代码中被 `fut_nexus` → `omega_platform` 替代，实际 archetype_id 为 `foe_omega_platform`
2. **A段实际28张**：文档写29张，但 `foe_omega_platform` 被计入，所以实际是 27+1=28
3. **无独立堡垒类别**：堡垒标签（kind=4）仅在 `_tags_for_kind()` 中定义，但代码中没有 kind=4 的敌人实例
4. **B段6张**：与文档一致，包括特殊精英变体
5. **C段36张**：含5个Boss、11个精英、20个基础单位
6. **D段29张**：与文档一致，按步兵/载具/阵地/支援循环
