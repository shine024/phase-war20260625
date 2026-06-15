# 基本单位卡图清单（100）

**用途**：透明底单位主体 PNG（`assets/card_icons/units/<visual_id>.png`）；与 **8 张势力底图**、稀有度边框分层叠加。  
**命名规则**：`display_name` **不含**「一战 / 二战 / 冷战 / 现代 / 近未来」等时代前缀；时代记在 `era` 列（0～4）。  
**版本**：v1.2 明细 | 2026-05-20 | 代码：`data/enemy_unit_manifest.gd`

**目标**：100 条**全部是战场敌人**；默认 **击杀**（`on_kill`）掉落 `captured_<archetype_id>` 进背包。详见 `docs/ENEMY_UNIT_CAPTURE_DESIGN.md`。

### 显示名规范（真实感）

1. 有型号则写 **型号 + 职能**（如「BTR-60PB 装甲输送车」）。  
2. 一战早期写 **厂商/特征 + 类型**（如「劳斯莱斯 Mk.I 装甲车」）。  
3. 近未来用 **代号 + 类型**（如「HK-07 量产机兵」）。  
4. 班组写 **武器/载具 + 编制**，避免单独「步兵班」。  
5. 建议 **6～14 字**。

### 列说明

| 列 | 含义 |
|----|------|
| `archetype_id` | 战场上刷新的敌人 ID（`EnemyArchetypes.get_all_ids()`） |
| `captured_card_id` | 击杀概率掉落的缴获成品卡（可进背包、可部署） |
| `template_card_id` / `缴获克隆` | A/B/D 与 manifest 一致；C 段见表内「缴获克隆」列（运行时推断） |
| `drop` | 掉落时机；当前均为 `on_kill` |
| `掉落率` | 单次击杀独立 roll 的概率（精英/Boss 更高） |

### 结构

| 区块 | 条数 | archetype_id 规则 |
|------|------|-------------------|
| A 原平台线 | 29 | `foe_<platform_card_id>` |
| B 原精英平台 | 6 | `foe_<special_card_id>` |
| C 固定原型 | 36 | 与 `enemy_archetypes.json` 同 id |
| D 补充池 | 29 | `foe_pool_001` … `foe_pool_029` |
| **合计** | **100** | 缴获卡均为 `captured_<archetype_id>` |

---

## A. 原平台线（29）— 敌人 `foe_platform_*`

| # | visual_id | display_name | era | 兵种 | archetype_id | captured_card_id | template_card_id | drop | 掉落率 |
|---|-----------|--------------|-----|------|--------------|------------------|------------------|------|--------|
| 1 | vis_player_001 | 威克斯侦察车 | 0 | 猎犬 | foe_platform_ww1_light | captured_foe_platform_ww1_light | platform_ww1_light | on_kill | 8% |
| 2 | vis_player_002 | 马克V型坦克 | 0 | 泰坦 | foe_platform_ww1_medium | captured_foe_platform_ww1_medium | platform_ww1_medium | on_kill | 8% |
| 3 | vis_player_003 | 150mm 岸防火炮阵地 | 0 | 要塞 | foe_platform_ww1_fort | captured_foe_platform_ww1_fort | platform_ww1_fort | on_kill | 8% |
| 4 | vis_player_004 | 系留气球观测队 | 0 | 雷达 | foe_platform_ww1_radar | captured_foe_platform_ww1_radar | platform_ww1_radar | on_kill | 8% |
| 5 | vis_player_005 | 福特 T 型救护改装车 | 0 | 医疗 | foe_platform_ww1_medic | captured_foe_platform_ww1_medic | platform_ww1_medic | on_kill | 8% |
| 6 | vis_player_006 | M8灰狗装甲车 | 1 | 侦察 | foe_platform_ww2_light | captured_foe_platform_ww2_light | platform_ww2_light | on_kill | 8% |
| 7 | vis_player_007 | 谢尔曼坦克 | 1 | 哨兵 | foe_platform_ww2_medium | captured_foe_platform_ww2_medium | platform_ww2_medium | on_kill | 8% |
| 8 | vis_player_008 | 虎式坦克 | 1 | 泰坦 | foe_platform_ww2_heavy | captured_foe_platform_ww2_heavy | platform_ww2_heavy | on_kill | 8% |
| 9 | vis_player_009 | BA-64轻型突击车 | 1 | 突袭 | foe_platform_ww2_raider | captured_foe_platform_ww2_raider | platform_ww2_raider | on_kill | 8% |
| 10 | vis_player_010 | SCR-584 雷达指挥车 | 1 | 雷达 | foe_platform_ww2_radar | captured_foe_platform_ww2_radar | platform_ww2_radar | on_kill | 8% |
| 11 | vis_player_011 | 203毫米迫击炮 | 1 | 攻城 | foe_platform_ww2_siege | captured_foe_platform_ww2_siege | platform_ww2_siege | on_kill | 8% |
| 12 | vis_player_012 | 海岸混凝土炮堡 | 1 | 要塞 | foe_platform_ww2_fortress | captured_foe_platform_ww2_fortress | platform_ww2_fortress | on_kill | 8% |
| 13 | vis_player_013 | 悍马侦察车 | 2 | 猎犬 | foe_platform_cold_light | captured_foe_platform_cold_light | platform_cold_light | on_kill | 8% |
| 14 | vis_player_014 | T-72主战坦克 | 2 | 泰坦 | foe_platform_cold_medium | captured_foe_platform_cold_medium | platform_cold_medium | on_kill | 8% |
| 15 | vis_player_015 | 布雷德利步战车 | 2 | 运输 | foe_platform_cold_ifv | captured_foe_platform_cold_ifv | platform_cold_ifv | on_kill | 8% |
| 16 | vis_player_016 | BRDM-2侦察车 | 2 | 侦察 | foe_platform_cold_scout | captured_foe_platform_cold_scout | platform_cold_scout | on_kill | 8% |
| 17 | vis_player_017 | R-330 电子干扰车 | 2 | 雷达 | foe_platform_cold_radar | captured_foe_platform_cold_radar | platform_cold_radar | on_kill | 8% |
| 18 | vis_player_018 | BMP步战车 | 2 | 运输 | foe_platform_cold_carrier | captured_foe_platform_cold_carrier | platform_cold_carrier | on_kill | 8% |
| 19 | vis_player_019 | L-ATV 全地形侦察车 | 3 | 猎犬 | foe_platform_modern_light | captured_foe_platform_modern_light | platform_modern_light | on_kill | 8% |
| 20 | vis_player_020 | 艾布拉姆斯坦克 | 3 | 哨兵 | foe_platform_modern_medium | captured_foe_platform_modern_medium | platform_modern_medium | on_kill | 8% |
| 21 | vis_player_021 | 相控阵雷达车 | 3 | 雷达 | foe_platform_modern_radar | captured_foe_platform_modern_radar | platform_modern_radar | on_kill | 8% |
| 22 | vis_player_022 | 帕拉丁自行火炮 | 3 | 攻城 | foe_platform_modern_spg | captured_foe_platform_modern_spg | platform_modern_spg | on_kill | 8% |
| 23 | vis_player_023 | Fennek 侦察车 | 3 | 隐匿 | foe_platform_modern_stealth | captured_foe_platform_modern_stealth | platform_modern_stealth | on_kill | 8% |
| 24 | vis_player_024 | 豹2A7主战坦克 | 3 | 哨兵 | foe_platform_modern_guard_heavy | captured_foe_platform_modern_guard_heavy | platform_modern_guard_heavy | on_kill | 8% |
| 25 | vis_player_025 | RQ-45 无人侦察车 | 4 | 隐匿 | foe_platform_future_light | captured_foe_platform_future_light | platform_future_light | on_kill | 8% |
| 26 | vis_player_026 | L-220 悬浮突击车 | 4 | 突袭 | foe_platform_future_medium | captured_foe_platform_future_medium | platform_future_medium | on_kill | 8% |
| 27 | vis_player_027 | AEW-12 感知阵列车 | 4 | 雷达 | foe_platform_future_radar | captured_foe_platform_future_radar | platform_future_radar | on_kill | 8% |
| 28 | vis_player_028 | HK-09 重型机兵 | 4 | 泰坦 | foe_platform_future_heavy | captured_foe_platform_future_heavy | platform_future_heavy | on_kill | 8% |
| 29 | vis_player_029 | 全装型机动舱 | 4 | 终极 | foe_omega_platform | captured_foe_omega_platform | omega_platform | on_kill | 8% |

---

## B. 原精英平台线（6）— 敌人 `foe_<id>`

| # | visual_id | display_name | era | 兵种 | archetype_id | captured_card_id | template_card_id | drop | 掉落率 |
|---|-----------|--------------|-----|------|--------------|------------------|------------------|------|--------|
| 30 | vis_player_030 | 兰开夏 FV603 装甲车 | 0 | 哨兵 | foe_bulwark | captured_foe_bulwark | bulwark | on_kill | 8% |
| 31 | vis_player_031 | 马克V型·改 | 0 | 泰坦 | foe_titan_mk2 | captured_foe_titan_mk2 | titan_mk2 | on_kill | 8% |
| 32 | vis_player_032 | M10 狼獾歼击车 | 1 | 突袭 | foe_storm_rider | captured_foe_storm_rider | storm_rider | on_kill | 8% |
| 33 | vis_player_033 | LST-1 两栖指挥舰 | 1 | 运输 | foe_heavy_carrier | captured_foe_heavy_carrier | heavy_carrier | on_kill | 8% |
| 34 | vis_player_034 | M88A1 抢救牵引车 | 2 | 医疗 | foe_regen_frame | captured_foe_regen_frame | regen_frame | on_kill | 8% |
| 35 | vis_player_035 | 艾布拉姆斯坦克·改 | 3 | 哨兵 | foe_abrams_mk2 | captured_foe_abrams_mk2 | abrams_mk2 | on_kill | 8% |

---

## C. 固定敌方原型（36）

数值以 `enemy_archetypes.json` 为准；下表 `display_name` 为清单/卡图用名（与 JSON 可逐步对齐）。

| # | visual_id | display_name | era | 兵种 | archetype_id | captured_card_id | 缴获克隆 | drop | 掉落率 |
|---|-----------|--------------|-----|------|--------------|------------------|----------|------|--------|
| 36 | vis_enemy_036 | 步兵班·MP18 | 0 | 步兵 | enemy_ww1_infantry_basic | captured_enemy_ww1_infantry_basic | platform_ww1_light | on_kill | 8% |
| 37 | vis_enemy_037 | 李-恩菲尔德步枪班 | 0 | 步兵 | enemy_ww1_infantry_rifle | captured_enemy_ww1_infantry_rifle | platform_ww1_light | on_kill | 8% |
| 38 | vis_enemy_038 | 马克沁机枪阵地 | 0 | 阵地 | enemy_ww1_mg_nest | captured_enemy_ww1_mg_nest | enemy_ww1_mg_nest | on_kill | 8% |
| 39 | vis_enemy_039 | 81mm 斯托克斯迫击炮组 | 0 | 阵地 | enemy_ww1_mortar | captured_enemy_ww1_mortar | elite_ww1_armored | on_kill | 8% |
| 40 | vis_enemy_040 | 暴风突击队 | 0 | 精英步兵 | elite_ww1_storm | captured_elite_ww1_storm | elite_ww1_armored | on_kill | 22% |
| 41 | vis_enemy_041 | 劳斯莱斯 Mk.I 装甲车 | 0 | 载具 | elite_ww1_armored | captured_elite_ww1_armored | elite_ww1_armored | on_kill | 22% |
| 42 | vis_enemy_042 | 圣沙蒙坦克 | 0 | Boss | boss_ww1_av7 | captured_boss_ww1_av7 | elite_ww1_armored | on_kill | 55% |
| 43 | vis_enemy_043 | 步兵班·汤普森 | 1 | 步兵 | enemy_ww2_infantry | captured_enemy_ww2_infantry | platform_ww2_light | on_kill | 8% |
| 44 | vis_enemy_044 | 步枪班·加兰德 | 1 | 步兵 | enemy_ww2_rifleman | captured_enemy_ww2_rifleman | platform_ww2_light | on_kill | 8% |
| 45 | vis_enemy_045 | MG42机枪组 | 1 | 阵地 | enemy_ww2_mg42 | captured_enemy_ww2_mg42 | enemy_ww2_mg42 | on_kill | 8% |
| 46 | vis_enemy_046 | 铁拳 88mm 反坦克组 | 1 | 阵地 | enemy_ww2_panzerschreck | captured_enemy_ww2_panzerschreck | platform_ww2_heavy | on_kill | 8% |
| 47 | vis_enemy_047 | FG42 伞兵班 | 1 | 精英步兵 | elite_ww2_paratrooper | captured_elite_ww2_paratrooper | platform_ww2_heavy | on_kill | 22% |
| 48 | vis_enemy_048 | 黑豹坦克 | 1 | 精英载具 | elite_ww2_panther | captured_elite_ww2_panther | platform_ww2_heavy | on_kill | 22% |
| 49 | vis_enemy_049 | 虎王坦克 | 1 | Boss | boss_ww2_kingtiger | captured_boss_ww2_kingtiger | platform_ww2_heavy | on_kill | 55% |
| 50 | vis_enemy_050 | AKM 摩托化步兵班 | 2 | 步兵 | enemy_cold_ak | captured_enemy_cold_ak | platform_cold_light | on_kill | 8% |
| 51 | vis_enemy_051 | M60 机枪步兵班 | 2 | 步兵 | enemy_cold_m60 | captured_enemy_cold_m60 | platform_cold_light | on_kill | 8% |
| 52 | vis_enemy_052 | BTR-60PB 装甲输送车 | 2 | 载具 | enemy_cold_btr | captured_enemy_cold_btr | platform_cold_medium | on_kill | 8% |
| 53 | vis_enemy_053 | M113A1 装甲输送车 | 2 | 载具 | enemy_cold_m113 | captured_enemy_cold_m113 | platform_cold_carrier | on_kill | 8% |
| 54 | vis_enemy_054 | Spetsnaz 侦察小组 | 2 | 精英步兵 | elite_cold_spetsnaz | captured_elite_cold_spetsnaz | platform_cold_medium | on_kill | 22% |
| 55 | vis_enemy_055 | T-72A 主战坦克 | 2 | 精英载具 | elite_cold_t72 | captured_elite_cold_t72 | platform_cold_medium | on_kill | 22% |
| 56 | vis_enemy_056 | 米格-29 | 2 | Boss | boss_cold_mig | captured_boss_cold_mig | platform_cold_medium | on_kill | 55% |
| 57 | vis_enemy_057 | M27 海军陆战队班 | 3 | 步兵 | enemy_modern_marine | captured_enemy_modern_marine | platform_modern_light | on_kill | 8% |
| 58 | vis_enemy_058 | 丰田 Hilux 重机枪车 | 3 | 步兵 | enemy_modern_technical | captured_enemy_modern_technical | platform_modern_light | on_kill | 8% |
| 59 | vis_enemy_059 | M1126 斯特赖克 ICV | 3 | 载具 | enemy_modern_stryker | captured_enemy_modern_stryker | platform_modern_stryker | on_kill | 8% |
| 60 | vis_enemy_060 | M270 MLRS 火箭炮 | 3 | 阵地 | enemy_modern_mlrs | captured_enemy_modern_mlrs | enemy_modern_mlrs | on_kill | 8% |
| 61 | vis_enemy_061 | CAG 三角洲小队 | 3 | 精英步兵 | elite_modern_delta | captured_elite_modern_delta | platform_modern_stryker | on_kill | 22% |
| 62 | vis_enemy_062 | M1A2 SEP v3 | 3 | 精英载具 | elite_modern_abrams | captured_elite_modern_abrams | platform_modern_stryker | on_kill | 22% |
| 63 | vis_enemy_063 | AH-64D 阿帕奇 | 3 | 精英航空 | elite_modern_apache | captured_elite_modern_apache | platform_modern_stryker | on_kill | 22% |
| 64 | vis_enemy_064 | 联合星区指挥所 | 3 | Boss | boss_modern_command | captured_boss_modern_command | platform_modern_stryker | on_kill | 55% |
| 65 | vis_enemy_065 | 蜂群微型无人机 | 4 | 步兵 | enemy_future_drone | captured_enemy_future_drone | platform_future_light | on_kill | 8% |
| 66 | vis_enemy_066 | 外骨骼突击兵 | 4 | 步兵 | enemy_future_cyborg | captured_enemy_future_cyborg | platform_future_light | on_kill | 8% |
| 67 | vis_enemy_067 | XM-3 机步突击车 | 4 | 载具 | enemy_future_mech | captured_enemy_future_mech | platform_future_heavy | on_kill | 8% |
| 68 | vis_enemy_068 | L-220 悬浮主战平台 | 4 | 载具 | enemy_future_hovertank | captured_enemy_future_hovertank | platform_future_heavy | on_kill | 8% |
| 69 | vis_enemy_069 | 光学迷彩渗透组 | 4 | 精英步兵 | elite_future_spectre | captured_elite_future_spectre | platform_future_heavy | on_kill | 22% |
| 70 | vis_enemy_070 | GK-1 重型步行机 | 4 | 精英载具 | elite_future_colossus | captured_elite_future_colossus | platform_future_heavy | on_kill | 22% |
| 71 | vis_enemy_071 | 风暴核心指挥塔 | 4 | Boss | boss_future_nexus | captured_boss_future_nexus | platform_future_heavy | on_kill | 55% |

> C 段 manifest 行内 `template_card_id` 与 `archetype_id` 相同；注册缴获卡时若该 id 不是 `default_cards` 中的卡，则由 `CapturedUnitCards._resolve_template_card_id()` 按 era + 兵种推断 `platform_*`（下表「缴获克隆」列为推断结果，与代码一致）。

---

## D. 补充敌方池（29）— `foe_pool_*`

已关闭 `enemy_ww1_01` 类程序生成 ID；波次/大地图从本表 `foe_pool_001`…`029` 抽敌人。

| # | visual_id | display_name | era | 兵种 | archetype_id | captured_card_id | template_card_id | drop | 掉落率 |
|---|-----------|--------------|-----|------|--------------|------------------|------------------|------|--------|
| 72 | vis_pool_001 | 李-恩菲尔德志愿兵排 | 0 | 步兵 | foe_pool_001 | captured_foe_pool_001 | platform_ww1_light | on_kill | 8% |
| 73 | vis_pool_002 | 劳斯莱斯 Mk.II 装甲车 | 0 | 载具 | foe_pool_002 | captured_foe_pool_002 | elite_ww1_armored | on_kill | 8% |
| 74 | vis_pool_003 | 维克斯 .303 机枪阵地 | 0 | 阵地 | foe_pool_003 | captured_foe_pool_003 | enemy_ww1_mg_nest | on_kill | 8% |
| 75 | vis_pool_004 | 福特 T 型战地救护车 | 0 | 支援 | foe_pool_004 | captured_foe_pool_004 | platform_ww1_medic | on_kill | 8% |
| 76 | vis_pool_005 | MP18 突击队 | 0 | 步兵 | foe_pool_005 | captured_foe_pool_005 | platform_ww1_light | on_kill | 8% |
| 77 | vis_pool_006 | M1 加兰德伞兵班 | 1 | 步兵 | foe_pool_006 | captured_foe_pool_006 | platform_ww2_heavy | on_kill | 8% |
| 78 | vis_pool_007 | 黄蜂 Hummel 自行火炮 | 1 | 载具 | foe_pool_007 | captured_foe_pool_007 | enemy_ww2_mg42 | on_kill | 8% |
| 79 | vis_pool_008 | PaK 40 反坦克炮组 | 1 | 阵地 | foe_pool_008 | captured_foe_pool_008 | platform_ww2_raider | on_kill | 8% |
| 80 | vis_pool_009 | GMC 2.5t 补给卡车 | 1 | 支援 | foe_pool_009 | captured_foe_pool_009 | platform_ww2_light | on_kill | 8% |
| 81 | vis_pool_010 | 毛瑟 Kar98k 狙击组 | 1 | 步兵 | foe_pool_010 | captured_foe_pool_010 | platform_ww2_heavy | on_kill | 8% |
| 82 | vis_pool_011 | BMD-1 空降战车 | 2 | 步兵 | foe_pool_011 | captured_foe_pool_011 | enemy_cold_btr | on_kill | 8% |
| 83 | vis_pool_012 | BMP-1 步兵战车 | 2 | 载具 | foe_pool_012 | captured_foe_pool_012 | platform_cold_carrier | on_kill | 8% |
| 84 | vis_pool_013 | 9K111 法特导弹组 | 2 | 阵地 | foe_pool_013 | captured_foe_pool_013 | platform_cold_light | on_kill | 8% |
| 85 | vis_pool_014 | P-18 雷达警戒车 | 2 | 支援 | foe_pool_014 | captured_foe_pool_014 | platform_cold_medium | on_kill | 8% |
| 86 | vis_pool_015 | BREM-1 装甲抢修车 | 2 | 支援 | foe_pool_015 | captured_foe_pool_015 | enemy_cold_btr | on_kill | 8% |
| 87 | vis_pool_016 | M4 卡宾特遣班 | 3 | 步兵 | foe_pool_016 | captured_foe_pool_016 | platform_modern_marine | on_kill | 8% |
| 88 | vis_pool_017 | 爱国者 PAC-3 发射车 | 3 | 载具 | foe_pool_017 | captured_foe_pool_017 | platform_modern_light | on_kill | 8% |
| 89 | vis_pool_018 | HIMARS 火箭炮组 | 3 | 阵地 | foe_pool_018 | captured_foe_pool_018 | platform_modern_stryker | on_kill | 8% |
| 90 | vis_pool_019 | RQ-7 影子无人机班 | 3 | 支援 | foe_pool_019 | captured_foe_pool_019 | enemy_modern_mlrs | on_kill | 8% |
| 91 | vis_pool_020 | EA-18G 电子战小组 | 3 | 支援 | foe_pool_020 | captured_foe_pool_020 | platform_modern_marine | on_kill | 8% |
| 92 | vis_pool_021 | 神经接口突击兵 | 4 | 步兵 | foe_pool_021 | captured_foe_pool_021 | platform_future_light | on_kill | 8% |
| 93 | vis_pool_022 | HK-07 量产机兵 | 4 | 载具 | foe_pool_022 | captured_foe_pool_022 | platform_future_heavy | on_kill | 8% |
| 94 | vis_pool_023 | HEL-30 激光炮阵列 | 4 | 阵地 | foe_pool_023 | captured_foe_pool_023 | enemy_future_mech | on_kill | 8% |
| 95 | vis_pool_024 | N-Repair 纳米工程车 | 4 | 支援 | foe_pool_024 | captured_foe_pool_024 | enemy_future_drone | on_kill | 8% |
| 96 | vis_pool_025 | X-9 猎杀者渗透组 | 4 | 步兵 | foe_pool_025 | captured_foe_pool_025 | platform_future_light | on_kill | 8% |
| 97 | vis_pool_026 | 毛瑟 C96 征召兵排 | 4 | 步兵 | foe_pool_026 | captured_foe_pool_026 | platform_future_heavy | on_kill | 8% |
| 98 | vis_pool_027 | Sd.Kfz.251/1 半履带车 | 4 | 载具 | foe_pool_027 | captured_foe_pool_027 | enemy_future_mech | on_kill | 8% |
| 99 | vis_pool_028 | SS-C-1 岸防导弹组 | 4 | 阵地 | foe_pool_028 | captured_foe_pool_028 | enemy_future_drone | on_kill | 8% |
| 100 | vis_pool_029 | PS-9 相位中继站 | 4 | 支援 | foe_pool_029 | captured_foe_pool_029 | platform_future_light | on_kill | 8% |

---

## 附录

### era 对照

| era | 关卡时代 |
|-----|----------|
| 0 | 一战 |
| 1 | 二战 |
| 2 | 冷战 |
| 3 | 现代 |
| 4 | 近未来 |

### 势力底图（8 张，与单位表独立）

| 文件建议 | 用途 |
|----------|------|
| `assets/cards/backgrounds/bg_neutral.png` | 无势力 / E1 进化 |
| `assets/cards/backgrounds/bg_iron_wall_corp.png` | 钢壁防务 |
| `assets/cards/backgrounds/bg_nova_arms.png` | 新星兵工 |
| `assets/cards/backgrounds/bg_aether_dynamics.png` | 以太动力 |
| `assets/cards/backgrounds/bg_quantum_logistics.png` | 量子后勤 |
| `assets/cards/backgrounds/bg_helix_recon.png` | 螺旋侦察 |
| `assets/cards/backgrounds/bg_void_research.png` | 虚空相位 |
| `assets/cards/backgrounds/bg_frontier_union.png` | 边境联合 |

- 敌人卡面：关卡 `faction_id` → 对应势力底。  
- 缴获卡部署：E2 势力进化 → 对应势力底；否则 neutral。

### PNG 单位层

- 路径：`assets/card_icons/units/<visual_id>.png`  
- 透明底 512×512；不 baked 势力底/稀有度框。  
- **#1～#5** 已用 Cursor Agent 生图 + 绿幕抠图（见 `docs/card_icon_manifest_100_agent_prompts.md` §1–5）。  
- **#1～#100** 各一条独立英文提示词：`docs/card_icon_manifest_100_agent_prompts.md`（由 `tools/gen_card_icon_manifest_100_prompts.py` 生成）。

### 重名立绘

| display_name | 行号 | 说明 |
|--------------|------|------|
| L-220 悬浮突击车 / 悬浮主战平台 | #26 / #68 | 近未来两种构型，各一张图 |
| 劳斯莱斯 Mk.I / Mk.II | #41 / #73 | 固定精英 vs 补充池，可共用或分绘 |

### 代码同步状态

| 项 | 状态 |
|----|------|
| 100 敌人合并进 `EnemyArchetypes` | 已实现 |
| `GENERATED_PER_ERA = 0` | 已实现 |
| `captured_*` 注册 | 已实现 |
| 势力底 + 卡面 UI 叠层 | 已实现：底图 `assets/cards/backgrounds/bg_*.png` + 稀有度框；背包/相位仪槽/底部条 |
| 游戏内 `display_name` 与表完全一致 | 待对齐 JSON/UI |
