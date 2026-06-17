# 敌方卡完整属性数据表

**版本**: v1.0 | **日期**: 2026-06-15
**数据源**: `data/captured_card_stats.gd` (`CAPTURED_STATS`)
**总条目**: 146 条（110 缴获卡 + 36 敌人原图）

---

## 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `display_name` | String | 显示名称 |
| `era` | int | 时代：0=一战, 1=二战, 2=冷战, 3=现代, 4=近未来 |
| `combat_kind` | int | 作战种类：0=轻装, 1=装甲, 2=支援, 3=空中, 4=堡垒 |
| `base_hp` | float | 基础HP |
| `range_value` | int | 射程档（1~4） |
| `attack_speed` | float | 攻速（1/秒间隔） |
| `attack_light` | float | 对轻装甲伤害 |
| `attack_armor` | float | 对重装甲伤害 |
| `attack_air` | float | 对空伤害 |
| `defense_light` | float | 对轻装甲防御 |
| `defense_armor` | float | 对重装甲防御 |
| `defense_air` | float | 对空防御 |
| `weapon_type` | int | 武器类型：0=机枪, 1=迫击炮, 2=步枪, 3=火炮, ... |
| `deploy_speed` | int | 部署速度（0=原地, 1~7递增） |
| `base_speed` | float | 移动速度 |
| `power` | int | 战力值 |
| `weapon_label` | String | 武器标签 |
| `type_line` | String | 类型行（时代 — 分类） |
| `appear_scope` | String | 出现范围 |

---

## 目录

- [第一篇：主线波次缴获卡（A+B+D段）](#第一篇主线波次缴获卡ab段)
  - [一战](#一战)
  - [二战](#二战)
  - [冷战](#冷战)
  - [现代](#现代)
  - [近未来](#近未来)
- [第二篇：任务专属缴获卡（C段）](#第二篇任务专属缴获卡c段)
  - [一战](#一战-1)
  - [二战](#二战-1)
  - [冷战](#冷战-1)
  - [现代](#现代-1)
  - [近未来](#近未来-1)
- [第三篇：堡垒卡（E段）](#第三篇堡垒卡e段)
  - [一战](#一战-2)
  - [二战](#二战-2)
  - [冷战](#冷战-2)
  - [现代](#现代-2)
  - [近未来](#近未来-2)
- [第四篇：敌人原图数据（vis_enemy_036~071）](#第四篇敌人原图数据vis_enemy036071)
  - [一战](#一战-3)
  - [二战](#二战-3)
  - [冷战](#冷战-3)
  - [现代](#现代-3)
  - [近未来](#近未来-3)

---

## 第一篇：主线波次缴获卡（A+B+D段）

> 共 63 条，出现在主线波次中，可通过击败敌人缴获。

### 一战（13条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | weapon_label |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_foe_ww1_rolls | 罗尔斯装甲车 | 0 | 1 | 200 | 2 | 1.25 | 25 | 40 | 0 | 18 | 22 | 10 | 0 | 3 | 40 | 208 | 机枪 |
| captured_foe_ww1_ft17 | FT-17轻型坦克 | 0 | 1 | 200 | 2 | 1.25 | 25 | 40 | 0 | 18 | 22 | 10 | 0 | 3 | 40 | 208 | 机枪 |
| captured_foe_ww1_77mm | 77mm野战炮 | 0 | 2 | 260 | 2 | 2.0 | 45 | 0 | 25 | 12 | 8 | 10 | 0 | 0 | 0 | 197 | 机枪 |
| captured_foe_ww1_cavalry | 骑兵斥候 | 0 | 0 | 65 | 1 | 1.49 | 35 | 0 | 0 | 8 | 5 | 3 | 0 | 4 | 115 | 121 | 冲锋枪 |
| captured_foe_ww1_engineer | 工兵班 | 0 | 2 | 80 | 1 | 1.0 | 30 | 25 | 0 | 10 | 8 | 5 | 0 | 4 | 75 | 133 | 步枪 |
| captured_foe_ww1_m81 | 81mm迫击炮组 | 0 | 2 | 260 | 2 | 2.0 | 45 | 0 | 25 | 12 | 8 | 10 | 0 | 0 | 0 | 197 | 机枪 |
| captured_foe_pool_001 | 李-恩菲尔德志愿兵排 | 0 | 0 | 55 | 1 | 2.0 | 20 | 14 | 12 | 0 | 0 | 0 | 0 | 5 | 120 | 101 | 冲锋枪 |
| captured_foe_pool_002 | 劳斯莱斯 Mk.II 装甲车 | 0 | 1 | 120 | 1 | 1.11 | 17.8 | 13.3 | 12 | 0 | 0 | 0 | 0 | 3 | 120 | 127 | 步枪 |
| captured_foe_pool_003 | 维克斯 .303 机枪阵地 | 0 | 2 | 200 | 2 | 0.67 | 16.8 | 12 | 10.7 | 0 | 0 | 0 | 1 | 0 | 0 | 192 | 迫击炮 |
| captured_foe_pool_026 | 毛瑟 C96 征召兵排 | 0 | 1 | 120 | 1 | 1.11 | 17.8 | 13.3 | 12 | 0 | 0 | 0 | 0 | 3 | 120 | 127 | 步枪 |

### 二战（14条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | weapon_label |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_foe_ww2_hellcat | M18地狱猫 | 1 | 0 | 90 | 2 | 4.0 | 7 | 3 | 3 | 7 | 5 | 5 | 0 | 4 | 100 | 69 | 机枪 |
| captured_foe_ww2_sherman | M4谢尔曼 | 1 | 1 | 110 | 2 | 1.05 | 14 | 8 | 7 | 9 | 7 | 7 | 0 | 3 | 75 | 103 | 步枪 |
| captured_foe_ww2_tiger | 虎式坦克 | 1 | 1 | 200 | 2 | 0.59 | 30 | 18 | 15 | 13 | 10 | 10 | 1 | 1 | 40 | 168 | 迫击炮 |
| captured_foe_ww2_bazooka | 巴祖卡组 | 1 | 0 | 50 | 1 | 2.63 | 8 | 4 | 4 | 4 | 3 | 3 | 0 | 5 | 135 | 88 | 冲锋枪 |
| captured_foe_ww2_panzerschrek | 铁拳反坦克组 | 1 | 0 | 50 | 2 | 2.63 | 8 | 4 | 4 | 4 | 3 | 3 | 0 | 5 | 135 | 88 | 冲锋枪 |
| captured_foe_ww2_m81 | 81mm迫击炮 | 1 | 2 | 260 | 2 | 4.0 | 7 | 3 | 3 | 20 | 16 | 16 | 0 | 0 | 0 | 154 | 机枪 |
| captured_foe_pool_005 | MP18 突击队 | 1 | 0 | 55 | 1 | 2.0 | 20 | 14 | 12 | 0 | 0 | 0 | 0 | 5 | 120 | 101 | 冲锋枪 |
| captured_foe_pool_006 | M1 加兰德伞兵班 | 1 | 1 | 120 | 1 | 1.11 | 17.8 | 13.3 | 12 | 0 | 0 | 0 | 0 | 3 | 120 | 127 | 步枪 |
| captured_foe_pool_007 | 黄蜂 Hummel 自行火炮 | 1 | 2 | 200 | 2 | 0.67 | 16.8 | 12 | 10.7 | 0 | 0 | 0 | 1 | 0 | 0 | 192 | 迫击炮 |
| captured_foe_pool_008 | PaK 40 反坦克炮组 | 1 | 3 | 90 | 1 | 2.5 | 20 | 15 | 12.5 | 0 | 0 | 0 | 2 | 3 | 120 | 153 | 手枪 |
| captured_foe_pool_009 | GMC 2.5t 补给卡车 | 1 | 0 | 55 | 1 | 2.0 | 20 | 14 | 12 | 0 | 0 | 0 | 0 | 5 | 120 | 101 | 冲锋枪 |
| captured_foe_pool_010 | 毛瑟 Kar98k 狙击组 | 1 | 1 | 120 | 1 | 1.11 | 17.8 | 13.3 | 12 | 0 | 0 | 0 | 0 | 3 | 120 | 127 | 步枪 |
| captured_foe_pool_027 | Sd.Kfz.251/1 半履带车 | 1 | 2 | 200 | 2 | 0.67 | 16.8 | 12 | 10.7 | 0 | 0 | 0 | 1 | 0 | 0 | 192 | 迫击炮 |

### 冷战（12条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | weapon_label |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_foe_cold_btr60 | BTR-60装甲车 | 2 | 3 | 140 | 2 | 4.0 | 7 | 4 | 4 | 8 | 6 | 6 | 0 | 3 | 50 | 95 | 机枪 |
| captured_foe_cold_t55 | T-55坦克 | 2 | 1 | 200 | 2 | 0.59 | 30 | 20 | 16 | 13 | 11 | 10 | 1 | 2 | 40 | 197 | 迫击炮 |
| captured_foe_cold_bmp1 | BMP-1步战车 | 2 | 3 | 140 | 2 | 4.0 | 7 | 4 | 4 | 8 | 6 | 6 | 0 | 3 | 50 | 95 | 机枪 |
| captured_foe_cold_m113 | M113装甲车 | 2 | 3 | 140 | 2 | 4.0 | 7 | 4 | 5 | 8 | 6 | 6 | 2 | 2 | 50 | 98 | 机枪 |
| captured_foe_cold_zsu23 | ZSU-23-4自行高炮 | 2 | 2 | 180 | 2 | 1.05 | 14 | 10 | 9 | 11 | 9 | 9 | 0 | 0 | 0 | 122 | 步枪 |
| captured_foe_pool_011 | BMD-1 空降战车 | 2 | 2 | 200 | 2 | 0.67 | 16.8 | 12 | 10.7 | 0 | 0 | 0 | 1 | 0 | 0 | 192 | 迫击炮 |
| captured_foe_pool_012 | BMP-1 步兵战车 | 2 | 3 | 90 | 1 | 2.5 | 20 | 15 | 12.5 | 0 | 0 | 0 | 2 | 3 | 120 | 153 | 手枪 |
| captured_foe_pool_013 | 9K111 法特导弹组 | 2 | 0 | 55 | 1 | 2.0 | 20 | 14 | 12 | 0 | 0 | 0 | 0 | 5 | 120 | 101 | 冲锋枪 |
| captured_foe_pool_014 | P-18 雷达警戒车 | 2 | 1 | 120 | 1 | 1.11 | 17.8 | 13.3 | 12 | 0 | 0 | 0 | 0 | 3 | 120 | 127 | 步枪 |
| captured_foe_pool_015 | BREM-1 装甲抢修车 | 2 | 2 | 200 | 2 | 0.67 | 16.8 | 12 | 10.7 | 0 | 0 | 0 | 1 | 0 | 0 | 192 | 迫击炮 |
| captured_foe_pool_028 | SS-C-1 岸防导弹组 | 2 | 3 | 90 | 1 | 2.5 | 20 | 15 | 12.5 | 0 | 0 | 0 | 2 | 3 | 120 | 153 | 手枪 |

### 现代（17条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | weapon_label |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_foe_mod_technical | 皮卡武装 | 3 | 0 | 90 | 1 | 3.33 | 18 | 5 | 5 | 7 | 5 | 5 | 0 | 4 | 120 | 120 | 机枪 |
| captured_foe_mod_m1a1 | M1A1主战坦克 | 3 | 1 | 220 | 2 | 0.56 | 50 | 40 | 35 | 15 | 12 | 12 | 1 | 2 | 60 | 286 | 火炮 |
| captured_foe_mod_m6 | 自行高炮M6 | 3 | 2 | 160 | 3 | 6.67 | 25 | 15 | 35 | 12 | 10 | 12 | 0 | 0 | 0 | 203 | 机枪 |
| captured_foe_mod_m270 | M270火箭炮 | 3 | 2 | 200 | 4 | 0.4 | 40 | 30 | 20 | 10 | 8 | 8 | 1 | 0 | 0 | 216 | 火箭炮 |
| captured_foe_fut_scout_drone | 侦察无人机 | 3 | 3 | 50 | 2 | 2.86 | 8 | 8 | 8 | 3 | 3 | 3 | 0 | 6 | 135 | 94 | 机枪 |
| captured_foe_mod_m1a2sep | M1A2 SEP主战坦克 | 3 | 1 | 240 | 3 | 0.59 | 55 | 45 | 40 | 16 | 13 | 13 | 1 | 2 | 65 | 308 | 火炮 |
| captured_foe_foe_abrams_mk2 | 艾布拉姆斯Mk.II | 3 | 1 | 220 | 2 | 0.61 | 140 | 100 | 90 | 12 | 10 | 9 | 1 | 2 | 65 | 769 | 轨道炮 |
| captured_foe_pool_016 | M4 卡宾特遣班 | 3 | 3 | 90 | 1 | 2.5 | 20 | 15 | 12.5 | 0 | 0 | 0 | 2 | 3 | 120 | 153 | 手枪 |
| captured_foe_pool_017 | 爱国者 PAC-3 发射车 | 3 | 0 | 55 | 1 | 2.0 | 20 | 14 | 12 | 0 | 0 | 0 | 0 | 5 | 120 | 101 | 冲锋枪 |
| captured_foe_pool_018 | HIMARS 火箭炮组 | 3 | 1 | 120 | 1 | 1.11 | 17.8 | 13.3 | 12 | 0 | 0 | 0 | 0 | 3 | 120 | 127 | 步枪 |
| captured_foe_pool_019 | RQ-7 影子无人机班 | 3 | 2 | 200 | 2 | 0.67 | 16.8 | 12 | 10.7 | 0 | 0 | 0 | 1 | 0 | 0 | 192 | 迫击炮 |
| captured_foe_pool_020 | EA-18G 电子战小组 | 3 | 3 | 90 | 1 | 2.5 | 20 | 15 | 12.5 | 0 | 0 | 0 | 2 | 3 | 120 | 153 | 手枪 |
| captured_foe_pool_029 | PS-9 相位中继站 | 3 | 0 | 55 | 1 | 2.0 | 20 | 14 | 12 | 0 | 0 | 0 | 0 | 5 | 120 | 101 | 冲锋枪 |

### 近未来（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | weapon_label |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_foe_fut_scout_mech | 侦察机甲 | 4 | 0 | 50 | 2 | 2.0 | 13 | 9 | 9 | 5 | 4 | 4 | 0 | 5 | 115 | 98 | 光束步枪 |
| captured_foe_fut_hovertank | 悬浮坦克 | 4 | 1 | 90 | 2 | 2.0 | 13 | 9 | 9 | 7 | 6 | 6 | 0 | 4 | 100 | 110 | 光束步枪 |
| captured_foe_fut_prism | 光棱坦克 | 4 | 1 | 200 | 3 | 0.45 | 220 | 180 | 160 | 13 | 11 | 10 | 1 | 1 | 40 | 1226 | 米加粒子炮 |
| captured_foe_fut_heavy_mech | 重装机甲 | 4 | 1 | 200 | 3 | 0.45 | 220 | 180 | 160 | 13 | 11 | 10 | 1 | 1 | 40 | 1226 | 米加粒子炮 |
| captured_foe_fut_nexus | 虚空领主 | 4 | 1 | 240 | 3 | 0.45 | 220 | 180 | 160 | 15 | 12 | 11 | 1 | 1 | 30 | 1248 | 米加粒子炮 |
| captured_foe_omega_platform | 全装型机动舱 | 4 | 1 | 200 | 2 | 0.45 | 220 | 180 | 160 | 13 | 11 | 10 | 1 | 1 | 40 | 1226 | 米加粒子炮 |
| captured_foe_pool_021 | 神经接口突击兵 | 4 | 0 | 55 | 1 | 2.0 | 20 | 14 | 12 | 0 | 0 | 0 | 0 | 5 | 120 | 101 | 冲锋枪 |
| captured_foe_pool_022 | HK-07 量产机兵 | 4 | 1 | 120 | 1 | 1.11 | 17.8 | 13.3 | 12 | 0 | 0 | 0 | 0 | 3 | 120 | 127 | 步枪 |
| captured_foe_pool_023 | HEL-30 激光炮阵列 | 4 | 2 | 200 | 2 | 0.67 | 16.8 | 12 | 10.7 | 0 | 0 | 0 | 1 | 0 | 0 | 192 | 迫击炮 |
| captured_foe_pool_024 | N-Repair 纳米工程车 | 4 | 3 | 90 | 1 | 2.5 | 20 | 15 | 12.5 | 0 | 0 | 0 | 2 | 3 | 120 | 153 | 手枪 |
| captured_foe_pool_025 | X-9 猎杀者渗透组 | 4 | 0 | 55 | 1 | 2.0 | 20 | 14 | 12 | 0 | 0 | 0 | 0 | 5 | 120 | 101 | 冲锋枪 |

### B段：特殊/精英单位（6条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | weapon_label |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_foe_bulwark | 壁垒 | 4 | 2 | 300 | 1 | 1.18 | 22 | 15 | 13 | 20 | 16 | 16 | 0 | 0 | 0 | 181 | 霰弹枪 |
| captured_foe_titan_mk2 | 泰坦Mk.II | 4 | 1 | 250 | 2 | 0.5 | 38 | 26 | 23 | 15 | 12 | 11 | 1 | 2 | 35 | 202 | 导弹 |
| captured_foe_storm_rider | 暴风骑士 | 4 | 0 | 60 | 2 | 0.63 | 28 | 19 | 17 | 5 | 4 | 4 | 2 | 5 | 120 | 125 | 狙击枪 |
| captured_foe_heavy_carrier | 重装母舰 | 4 | 3 | 160 | 2 | 4.0 | 7 | 5 | 5 | 9 | 7 | 7 | 2 | 2 | 50 | 92 | 机枪 |
| captured_foe_regen_frame | 再生骨架 | 4 | 3 | 100 | 1 | 2.22 | 7 | 5 | 4 | 6 | 5 | 5 | 0 | 3 | 75 | 79 | 手枪 |

---

## 第二篇：任务专属缴获卡（C段）

> 共 36 条，仅通过特定任务/关卡获得，对应战场敌人的缴获卡面版本。

### 一战（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | appear_scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_enemy_ww1_infantry_basic | 步兵班·MP18 | 0 | 0 | 40 | 1 | 4.0 | 8 | 3.2 | 2.4 | 0 | 0 | 0 | 0 | 4 | 80 | 52 | 任务专属 |
| captured_enemy_ww1_infantry_rifle | 步兵班·步枪 | 0 | 0 | 45 | 2 | 1.49 | 9.6 | 7.2 | 6 | 0 | 0 | 0 | 1 | 3 | 70 | 73 | 任务专属 |
| captured_enemy_ww1_mg_nest | 机枪巢 | 0 | 2 | 80 | 1 | 3.03 | 30.2 | 16.6 | 13.3 | 0 | 0 | 0 | 2 | 0 | 0 | 139 | 任务专属 |
| captured_enemy_ww1_mortar | 迫击炮组 | 0 | 2 | 60 | 2 | 0.5 | 80 | 48 | 32 | 0 | 0 | 0 | 3 | 4 | 40 | 241 | 任务专属 |
| captured_elite_ww1_storm | 暴风突击队 | 0 | 0 | 70 | 1 | 4.0 | 36 | 14.4 | 10.8 | 0 | 0 | 0 | 0 | 5 | 100 | 136 | 任务专属 |
| captured_elite_ww1_armored | 装甲车 | 0 | 2 | 120 | 1 | 1.82 | 50.4 | 27.7 | 22.2 | 0 | 0 | 0 | 2 | 3 | 60 | 193 | 任务专属 |
| captured_boss_ww1_av7 | 圣沙蒙坦克 | 0 | 1 | 300 | 2 | 0.67 | 100 | 60 | 40 | 0 | 0 | 0 | 3 | 1 | 30 | 495 | BOSS |

### 二战（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | appear_scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_enemy_ww2_infantry | 步兵班·汤普森 | 1 | 0 | 50 | 1 | 4.55 | 45 | 18 | 13.5 | 0 | 0 | 0 | 0 | 4 | 90 | 163 | 任务专属 |
| captured_enemy_ww2_rifleman | 步枪班·加兰德 | 1 | 0 | 55 | 2 | 2.0 | 48 | 28.8 | 24 | 0 | 0 | 0 | 1 | 3 | 70 | 178 | 任务专属 |
| captured_enemy_ww2_mg42 | MG42机枪组 | 1 | 2 | 90 | 1 | 5.0 | 63 | 31.5 | 25.2 | 0 | 0 | 0 | 2 | 3 | 50 | 232 | 任务专属 |
| captured_enemy_ww2_panzerschrek | 反坦克组 | 1 | 0 | 70 | 1 | 0.4 | 120 | 72 | 48 | 0 | 0 | 0 | 3 | 3 | 60 | 418 | 任务专属 |
| captured_elite_ww2_paratrooper | 伞兵精英 | 1 | 0 | 80 | 1 | 4.55 | 73 | 29.2 | 21.9 | 0 | 0 | 0 | 0 | 5 | 110 | 205 | 任务专属 |
| captured_elite_ww2_panther | 黑豹坦克 | 1 | 1 | 200 | 2 | 1.11 | 168 | 100.8 | 67.2 | 0 | 0 | 0 | 3 | 2 | 50 | 779 | 任务专属 |
| captured_boss_ww2_kingtiger | 虎王坦克 | 1 | 1 | 400 | 2 | 1.0 | 200 | 120 | 80 | 0 | 0 | 0 | 3 | 1 | 30 | 880 | BOSS |

### 冷战（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | appear_scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_enemy_cold_ak | 苏军步兵 | 2 | 0 | 60 | 2 | 3.03 | 67.2 | 40.3 | 33.6 | 0 | 0 | 0 | 1 | 4 | 90 | 229 | 任务专属 |
| captured_enemy_cold_m60 | 美军步兵 | 2 | 0 | 65 | 2 | 4.0 | 100.8 | 50.4 | 40.3 | 0 | 0 | 0 | 2 | 4 | 90 | 281 | 任务专属 |
| captured_enemy_cold_btr | BTR装甲车 | 2 | 1 | 120 | 1 | 3.33 | 105.8 | 52.9 | 42.3 | 0 | 0 | 0 | 2 | 3 | 80 | 308 | 任务专属 |
| captured_enemy_cold_m113 | M113装甲车 | 2 | 3 | 110 | 1 | 2.86 | 61.7 | 30.8 | 24.7 | 0 | 0 | 0 | 2 | 3 | 70 | 216 | 任务专属 |
| captured_elite_cold_spetsnaz | 特种部队 | 2 | 0 | 90 | 2 | 0.8 | 112 | 89.6 | 67.2 | 0 | 0 | 0 | 6 | 5 | 120 | 434 | 任务专属 |
| captured_elite_cold_t72 | T-72坦克 | 2 | 1 | 250 | 2 | 1.25 | 160 | 96 | 64 | 0 | 0 | 0 | 3 | 2 | 60 | 612 | 任务专属 |
| captured_boss_cold_mig | 米格-29 | 2 | 3 | 450 | 2 | 1.25 | 162 | 216 | 108 | 0 | 0 | 0 | 9 | 6 | 150 | 1014 | BOSS |

### 现代（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | appear_scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_enemy_modern_marine | 海军陆战队 | 3 | 0 | 70 | 2 | 3.45 | 81.9 | 49.1 | 40.9 | 0 | 0 | 0 | 1 | 4 | 100 | 284 | 任务专属 |
| captured_enemy_modern_technical | 皮卡武装 | 3 | 3 | 90 | 1 | 3.33 | 113.4 | 56.7 | 45.4 | 0 | 0 | 0 | 2 | 4 | 120 | 326 | 任务专属 |
| captured_enemy_modern_stryker | 斯特赖克装甲车 | 3 | 1 | 150 | 2 | 2.86 | 126 | 63 | 50.4 | 0 | 0 | 0 | 2 | 3 | 80 | 348 | 任务专属 |
| captured_enemy_modern_mlrs | 火箭炮车 | 3 | 2 | 100 | 3 | 0.5 | 210 | 126 | 84 | 0 | 0 | 0 | 3 | 4 | 50 | 592 | 任务专属 |
| captured_elite_modern_delta | 三角洲部队 | 3 | 0 | 100 | 2 | 3.45 | 133.9 | 80.4 | 66.9 | 0 | 0 | 0 | 1 | 5 | 130 | 379 | 任务专属 |
| captured_elite_modern_abrams | M1A2坦克 | 3 | 1 | 300 | 2 | 1.25 | 270 | 162 | 108 | 0 | 0 | 0 | 3 | 2 | 60 | 880 | 任务专属 |
| captured_elite_modern_apache | 阿帕奇直升机 | 3 | 3 | 220 | 3 | 1.67 | 266 | 177.3 | 118.2 | 0 | 0 | 0 | 9 | 5 | 120 | 938 | 任务专属 |
| captured_boss_modern_command | 指挥中枢 | 3 | 2 | 700 | 2 | 0.83 | 294 | 147 | 117.6 | 0 | 0 | 0 | 2 | 0 | 0 | 1211 | BOSS |

### 近未来（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | appear_scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_enemy_future_drone | 无人机群 | 4 | 3 | 40 | 2 | 2.5 | 120 | 120 | 120 | 0 | 0 | 0 | 8 | 6 | 150 | 550 | 任务专属 |
| captured_enemy_future_cyborg | 机械步兵 | 4 | 0 | 100 | 2 | 4.0 | 132 | 132 | 132 | 0 | 0 | 0 | 8 | 4 | 100 | 624 | 任务专属 |
| captured_enemy_future_mech | 机甲步兵 | 4 | 1 | 180 | 2 | 1.49 | 126 | 126 | 126 | 0 | 0 | 0 | 8 | 3 | 80 | 729 | 任务专属 |
| captured_enemy_future_hovertank | 悬浮坦克 | 4 | 1 | 250 | 3 | 2.0 | 200 | 200 | 200 | 0 | 0 | 0 | 8 | 4 | 110 | 1062 | 任务专属 |
| captured_elite_future_spectre | 幽灵特工 | 4 | 0 | 120 | 2 | 2.5 | 210 | 210 | 210 | 0 | 0 | 0 | 8 | 5 | 140 | 812 | 任务专属 |
| captured_elite_future_colossus | 巨神机甲 | 4 | 1 | 400 | 3 | 1.0 | 440 | 440 | 440 | 0 | 0 | 0 | 8 | 1 | 60 | 2432 | 任务专属 |
| captured_boss_future_nexus | 风暴核心 | 4 | 2 | 900 | 3 | 1.11 | 900 | 900 | 900 | 0 | 0 | 0 | 10 | 0 | 30 | 5923 | BOSS |

---

## 第三篇：堡垒卡（E段）

> 共 10 条，固定阵地类型，出现在堡垒关卡中。

### 一战（2条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | power | appear_scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_fort_ww1_pillbox | 混凝土机枪碉堡 | 0 | 4 | 600 | 1 | 0.5 | 60 | 0 | 40 | 50 | 60 | 40 | 418 | 堡垒 |
| captured_fort_ww1_artillery | 要塞炮台 | 0 | 4 | 500 | 1 | 3.03 | 80 | 0 | 0 | 40 | 50 | 30 | 481 | 堡垒 |

### 二战（2条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | power | appear_scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_fort_ww2_bunker | 混凝土碉堡 | 1 | 4 | 1000 | 1 | 0.5 | 80 | 0 | 60 | 80 | 100 | 60 | 780 | 堡垒 |
| captured_fort_ww2_flak | 88mm防空塔 | 1 | 4 | 800 | 1 | 0.67 | 40 | 0 | 200 | 60 | 80 | 100 | 763 | 堡垒 |

### 冷战（2条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | power | appear_scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_fort_cold_missile | 导弹发射井 | 2 | 4 | 1200 | 1 | 1.67 | 120 | 0 | 100 | 80 | 100 | 80 | 950 | 堡垒 |
| captured_fort_cold_radar | 雷达站 | 2 | 4 | 800 | 1 | 0.0 | 0 | 0 | 0 | 60 | 80 | 60 | 284 | 堡垒 |

### 现代（2条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | power | appear_scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_fort_modern_citadel | 要塞核心 | 3 | 4 | 2000 | 1 | 1.0 | 120 | 0 | 80 | 120 | 180 | 100 | 1266 | 堡垒 |
| captured_fort_modern_phalanx | 近防炮系统 | 3 | 4 | 1000 | 1 | 0.33 | 50 | 0 | 300 | 80 | 100 | 120 | 818 | 堡垒 |

### 近未来（2条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | power | appear_scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_fort_future_ion | 离子炮台 | 4 | 4 | 2500 | 1 | 1.49 | 200 | 0 | 150 | 150 | 200 | 150 | 1535 | 堡垒 |
| captured_fort_future_shield | 能量护盾发生器 | 4 | 4 | 3000 | 0 | 0.0 | 0 | 0 | 0 | 200 | 250 | 200 | 1050 | 堡垒 |

---

## 第四篇：敌人原图数据（vis_enemy_036~071）

> 共 36 条，战场敌人原图设计数据，key 以 `_v2` 后缀标识，与缴获卡面 `vis_player_036~071` 不同。
> 数据来源：`data/json/enemy_archetypes.json` 的 FIXED_ENEMY_IDS。

### 一战（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | _icon_ref |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_enemy_ww1_infantry_basic_v2 | 步兵班·MP18（敌人原图） | 0 | 0 | 40 | 1 | 4.0 | 8 | 3.2 | 2.4 | 0 | 0 | 0 | 0 | 4 | 80 | 52 | vis_enemy_036 |
| captured_enemy_ww1_infantry_rifle_v2 | 步兵班·毛瑟（敌人原图） | 0 | 0 | 45 | 2 | 1.49 | 9.6 | 7.2 | 6 | 0 | 0 | 0 | 1 | 3 | 70 | 73 | vis_enemy_037 |
| captured_enemy_ww1_mg_nest_v2 | 机枪巢（敌人原图） | 0 | 2 | 80 | 1 | 3.03 | 30.2 | 16.6 | 13.3 | 0 | 0 | 0 | 2 | 0 | 0 | 139 | vis_enemy_038 |
| captured_enemy_ww1_mortar_v2 | 迫击炮组（敌人原图） | 0 | 2 | 60 | 2 | 0.5 | 80 | 48 | 32 | 0 | 0 | 0 | 3 | 4 | 40 | 241 | vis_enemy_039 |
| captured_elite_ww1_storm_v2 | 暴风突击队（敌人原图） | 0 | 0 | 70 | 1 | 4.0 | 36 | 14.4 | 10.8 | 0 | 0 | 0 | 0 | 5 | 100 | 136 | vis_enemy_040 |
| captured_elite_ww1_armored_v2 | 装甲车（敌人原图） | 0 | 2 | 120 | 1 | 1.82 | 50.4 | 27.7 | 22.2 | 0 | 0 | 0 | 2 | 3 | 60 | 193 | vis_enemy_041 |
| captured_boss_ww1_av7_v2 | 圣沙蒙坦克（敌人原图） | 0 | 1 | 300 | 2 | 0.67 | 100 | 60 | 40 | 0 | 0 | 0 | 3 | 1 | 30 | 495 | vis_enemy_042 |

### 二战（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | _icon_ref |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_enemy_ww2_infantry_v2 | 步兵班·汤普森（敌人原图） | 1 | 0 | 50 | 1 | 4.55 | 45 | 18 | 13.5 | 0 | 0 | 0 | 0 | 4 | 90 | 163 | vis_enemy_043 |
| captured_enemy_ww2_rifleman_v2 | 步枪班·加兰德（敌人原图） | 1 | 0 | 55 | 2 | 2.0 | 48 | 28.8 | 24 | 0 | 0 | 0 | 1 | 3 | 70 | 178 | vis_enemy_044 |
| captured_enemy_ww2_mg42_v2 | MG42机枪组（敌人原图） | 1 | 2 | 90 | 1 | 5.0 | 63 | 31.5 | 25.2 | 0 | 0 | 0 | 2 | 3 | 50 | 232 | vis_enemy_045 |
| captured_enemy_ww2_panzerschreck_v2 | 反坦克组（敌人原图） | 1 | 0 | 70 | 1 | 0.4 | 120 | 72 | 48 | 0 | 0 | 0 | 3 | 3 | 60 | 418 | vis_enemy_046 |
| captured_elite_ww2_paratrooper_v2 | 伞兵精英（敌人原图） | 1 | 0 | 80 | 1 | 4.55 | 73 | 29.2 | 21.9 | 0 | 0 | 0 | 0 | 5 | 110 | 205 | vis_enemy_047 |
| captured_elite_ww2_panther_v2 | 黑豹坦克（敌人原图） | 1 | 1 | 200 | 2 | 1.11 | 168 | 100.8 | 67.2 | 0 | 0 | 0 | 3 | 2 | 50 | 779 | vis_enemy_048 |
| captured_boss_ww2_kingtiger_v2 | 虎王坦克（敌人原图） | 1 | 1 | 400 | 2 | 1.0 | 200 | 120 | 80 | 0 | 0 | 0 | 3 | 1 | 30 | 880 | vis_enemy_049 |

### 冷战（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | _icon_ref |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_enemy_cold_ak_v2 | 苏军步兵（敌人原图） | 2 | 0 | 60 | 2 | 3.03 | 67.2 | 40.3 | 33.6 | 0 | 0 | 0 | 1 | 4 | 90 | 229 | vis_enemy_050 |
| captured_enemy_cold_m60_v2 | 美军步兵（敌人原图） | 2 | 0 | 65 | 2 | 4.0 | 100.8 | 50.4 | 40.3 | 0 | 0 | 0 | 2 | 4 | 90 | 281 | vis_enemy_051 |
| captured_enemy_cold_btr_v2 | BTR装甲车（敌人原图） | 2 | 1 | 120 | 1 | 3.33 | 105.8 | 52.9 | 42.3 | 0 | 0 | 0 | 2 | 3 | 80 | 308 | vis_enemy_052 |
| captured_enemy_cold_m113_v2 | M113装甲车（敌人原图） | 2 | 3 | 110 | 1 | 2.86 | 61.7 | 30.8 | 24.7 | 0 | 0 | 0 | 2 | 3 | 70 | 216 | vis_enemy_053 |
| captured_elite_cold_spetsnaz_v2 | 特种部队（敌人原图） | 2 | 0 | 90 | 2 | 0.8 | 112 | 89.6 | 67.2 | 0 | 0 | 0 | 6 | 5 | 120 | 434 | vis_enemy_054 |
| captured_elite_cold_t72_v2 | T-72坦克（敌人原图） | 2 | 1 | 250 | 2 | 1.25 | 160 | 96 | 64 | 0 | 0 | 0 | 3 | 2 | 60 | 612 | vis_enemy_055 |
| captured_boss_cold_mig_v2 | 米格-29（敌人原图） | 2 | 3 | 450 | 2 | 1.25 | 162 | 216 | 108 | 0 | 0 | 0 | 9 | 6 | 150 | 1014 | vis_enemy_056 |

### 现代（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | _icon_ref |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_enemy_modern_marine_v2 | 海军陆战队（敌人原图） | 3 | 0 | 70 | 2 | 3.45 | 81.9 | 49.1 | 40.9 | 0 | 0 | 0 | 1 | 4 | 100 | 284 | vis_enemy_057 |
| captured_enemy_modern_technical_v2 | 皮卡武装（敌人原图） | 3 | 3 | 90 | 1 | 3.33 | 113.4 | 56.7 | 45.4 | 0 | 0 | 0 | 2 | 4 | 120 | 326 | vis_enemy_058 |
| captured_enemy_modern_stryker_v2 | 斯特赖克装甲车（敌人原图） | 3 | 1 | 150 | 2 | 2.86 | 126 | 63 | 50.4 | 0 | 0 | 0 | 2 | 3 | 80 | 348 | vis_enemy_059 |
| captured_enemy_modern_mlrs_v2 | 火箭炮车（敌人原图） | 3 | 2 | 100 | 3 | 0.5 | 210 | 126 | 84 | 0 | 0 | 0 | 3 | 4 | 50 | 592 | vis_enemy_060 |
| captured_elite_modern_delta_v2 | 三角洲部队（敌人原图） | 3 | 0 | 100 | 2 | 3.45 | 133.9 | 80.4 | 66.9 | 0 | 0 | 0 | 1 | 5 | 130 | 379 | vis_enemy_061 |
| captured_elite_modern_abrams_v2 | M1A2坦克（敌人原图） | 3 | 1 | 300 | 2 | 1.25 | 270 | 162 | 108 | 0 | 0 | 0 | 3 | 2 | 60 | 880 | vis_enemy_062 |
| captured_elite_modern_apache_v2 | 阿帕奇直升机（敌人原图） | 3 | 3 | 220 | 3 | 1.67 | 266 | 177.3 | 118.2 | 0 | 0 | 0 | 9 | 5 | 120 | 938 | vis_enemy_063 |
| captured_boss_modern_command_v2 | 指挥中枢（敌人原图） | 3 | 2 | 700 | 2 | 0.83 | 294 | 147 | 117.6 | 0 | 0 | 0 | 2 | 0 | 0 | 1211 | vis_enemy_064 |

### 近未来（7条）

| captured_id | display_name | era | combat_kind | base_hp | range | atk_spd | atk_L | atk_A | atk_K | def_L | def_A | def_K | weapon_type | deploy | spd | power | _icon_ref |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| captured_enemy_future_drone_v2 | 无人机群（敌人原图） | 4 | 3 | 40 | 2 | 2.5 | 120 | 120 | 120 | 0 | 0 | 0 | 8 | 6 | 150 | 550 | vis_enemy_065 |
| captured_enemy_future_cyborg_v2 | 机械步兵（敌人原图） | 4 | 0 | 100 | 2 | 4.0 | 132 | 132 | 132 | 0 | 0 | 0 | 8 | 4 | 100 | 624 | vis_enemy_066 |
| captured_enemy_future_mech_v2 | 机甲步兵（敌人原图） | 4 | 1 | 180 | 2 | 1.49 | 126 | 126 | 126 | 0 | 0 | 0 | 8 | 3 | 80 | 729 | vis_enemy_067 |
| captured_enemy_future_hovertank_v2 | 悬浮坦克（敌人原图） | 4 | 1 | 250 | 3 | 2.0 | 200 | 200 | 200 | 0 | 0 | 0 | 8 | 4 | 110 | 1062 | vis_enemy_068 |
| captured_elite_future_spectre_v2 | 幽灵特工（敌人原图） | 4 | 0 | 120 | 2 | 2.5 | 210 | 210 | 210 | 0 | 0 | 0 | 8 | 5 | 140 | 812 | vis_enemy_069 |
| captured_elite_future_colossus_v2 | 巨神机甲（敌人原图） | 4 | 1 | 400 | 3 | 1.0 | 440 | 440 | 440 | 0 | 0 | 0 | 8 | 1 | 60 | 2432 | vis_enemy_070 |
| captured_boss_future_nexus_v2 | 风暴核心（敌人原图） | 4 | 2 | 900 | 3 | 1.11 | 900 | 900 | 900 | 0 | 0 | 0 | 10 | 0 | 30 | 5923 | vis_enemy_071 |

---

## 附录

### A. 数据统计汇总

| 分类维度 | 统计 |
|----------|------|
| **总条目** | 146（110 缴获卡 + 36 敌人原图） |
| 按时代 | 一战 27 / 二战 28 / 冷战 26 / 现代 31 / 近未来 34 |
| 按出现范围 | 主线波次 63 / 任务专属 31 / BOSS 10 / 堡垒 10 / 敌人原图 36 |
| 按作战种类 | 轻装 46 / 装甲 38 / 支援 28 / 空中 22 / 堡垒 12 |

### B. 数据源说明

| 数据段 | 来源文件 | 说明 |
|--------|----------|------|
| A段（28条） | `data/enemy_unit_manifest.gd` FOE_PLATFORM_CARD_IDS | 新时代单位，主线波次 |
| B段（6条） | `data/enemy_unit_manifest.gd` FOE_SPECIAL_CARD_IDS | 特殊/精英掉落 |
| C段（36条） | `data/enemy_unit_manifest.gd` FIXED_ENEMY_IDS | 固定战场敌人，任务专属 |
| D段（29条） | `data/enemy_unit_manifest.gd` POOL_ENEMY_IDS | 补充池 |
| E段（10条） | `data/enemy_unit_manifest.gd` FORT_ENEMY_IDS | 堡垒类型 |
| C段补充_v2（36条） | `data/json/enemy_archetypes.json` | 战场敌人原图数据 |

### C. 待完善清单

| # | 项目 | 说明 |
|---|------|------|
| 1 | C 段敌人防御三维 | `enemy_archetypes.json` 中 C 段仅含单值 `defense`，缴获卡和敌人原图的防御值均为 0。建议后续展开为 `defense_light/armor/air` |
| 2 | weapon_type 枚举对照 | 需维护 `weapon_type` int→String 完整映射表（当前 0~10 均有使用） |
| 3 | power 公式校验 | 当前 `power = round(hp*0.3 + Σatk*2 + Σdef*1.5 + spd*0.1)`，部分条目可能存在舍入差异 |
| 4 | 缴获卡 vs 敌人原图区分 | C 段缴获卡（`captured_enemy_*`）与敌人原图（`captured_enemy_*_v2`）数值完全一致，仅 `display_name` 和 `_icon_ref` 不同 |
