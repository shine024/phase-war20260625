# 敌人全数据审核表（基础数据，不含加成）

> 生成日期：2026-07-15
> 数据来源：data/enemy_archetypes_*.gd、data/enemy_phase_masters_*.gd、data/enemy_equipment_*.gd、data/enemy_unit_manifest.gd
> 说明：仅基础数值，不含任何加成/乘区/难度系数

---

## 目录

1. [常规敌人原型（36个）](#1-常规敌人原型36个)
2. [补充池敌人（29个，ID清单）](#2-补充池敌人29个id清单)
3. [堡垒敌人（10个，ID清单）](#3-堡垒敌人10个id清单)
4. [敌方平台卡（34个，ID清单）](#4-敌方平台卡34个id清单)
5. [相位师（30个）](#5-相位师30个)
6. [相位师装备平台（24个）](#6-相位师装备平台24个)
7. [相位师武器（24个）](#7-相位师武器24个)
8. [数量统计汇总](#8-数量统计汇总)

---

## 1. 常规敌人原型（36个）

> 来源：enemy_archetypes_ww.gd / cold_modern.gd / future.gd
> 每时代：4基础 + 2~3精英 + 1头目
> 字段说明：hp=生命值, speed=移动速度(负=向左), attack_damage=单次伤害, attack_range=攻击距离(像素), attack_interval=攻击间隔(秒), weapon_type=武器类型

### 武器类型对照
| 值 | 类型 |
|----|------|
| 0 | SMG 冲锋枪 |
| 1 | RIFLE 步枪 |
| 2 | MG 机枪 |
| 3 | ROCKET 火箭弹 |
| 4 | PISTOL 手枪 |
| 5 | SHOTGUN 霰弹枪 |
| 6 | SNIPER 狙击枪 |
| 7 | FLAK 高射炮 |
| 8 | LASER 激光 |
| 9 | MISSILE 导弹 |
| 10 | OMEGA 米加炮 |

### 1.1 一战（7个，时代 0）

| # | ID | 显示名 | 类型 | HP | 速度 | 伤害 | 射程 | 攻速间隔 | 武器 | 标签 |
|---|-----|--------|------|-----|------|------|------|---------|------|------|
| 1 | ww1_inf_mp18 | 步兵班·MP18 | 基础 | 40 | -80 | 8 | 80 | 0.25 | SMG | infantry, frontline, 蜂群 |
| 2 | ww1_inf_rifle | 步兵班·步枪 | 基础 | 45 | -70 | 12 | 150 | 0.67 | RIFLE | infantry, backline, 蜂群 |
| 3 | ww1_sup_mg_nest | 机枪巢 | 基础 | 80 | 0 | 10 | 120 | 0.33 | MG | turret, sustained |
| 4 | ww1_arty_mortar | 迫击炮组 | 基础 | 60 | -40 | 20 | 180 | 2.00 | ROCKET | artillery, backline |
| 5 | ww1_inf_storm_e | 暴风突击队 | 精英 | 70 | -100 | 12 | 80 | 0.25 | SMG | elite, infantry, fast |
| 6 | ww1_arm_rolls_e | 装甲车 | 精英 | 120 | -60 | 15 | 120 | 0.33 | MG | elite, vehicle, armored |
| 7 | ww1_boss_av7 | 圣沙蒙坦克 | 头目 | 600 | -30 | 25 | 150 | 1.50 | ROCKET | boss, tank, armored |

### 1.2 二战（7个，时代 1）

| # | ID | 显示名 | 类型 | HP | 速度 | 伤害 | 射程 | 攻速间隔 | 武器 | 标签 |
|---|-----|--------|------|-----|------|------|------|---------|------|------|
| 8 | ww2_inf_thompson | 步兵班·汤普森 | 基础 | 50 | -90 | 10 | 85 | 0.22 | SMG | infantry, frontline, 蜂群 |
| 9 | ww2_inf_garand | 步枪班·加兰德 | 基础 | 55 | -70 | 15 | 160 | 0.50 | RIFLE | infantry, backline, 蜂群 |
| 10 | ww2_sup_mg42 | MG42机枪组 | 基础 | 90 | -50 | 14 | 130 | 0.20 | MG | turret, sustained |
| 11 | ww2_inf_panzerschreck_e | 反坦克组 | 基础 | 70 | -60 | 30 | 140 | 2.50 | ROCKET | infantry, antitank |
| 12 | ww2_inf_para_e | 伞兵精英 | 精英 | 80 | -110 | 16 | 90 | 0.22 | SMG | elite, infantry, fast |
| 13 | ww2_arm_panther_e | 黑豹坦克 | 精英 | 200 | -50 | 35 | 150 | 1.00 | ROCKET | elite, tank, armored |
| 14 | ww2_boss_kingtiger | 虎王坦克 | 头目 | 800 | -30 | 40 | 160 | 1.20 | ROCKET | boss, tank, armored |

### 1.3 冷战（7个，时代 2）

| # | ID | 显示名 | 类型 | HP | 速度 | 伤害 | 射程 | 攻速间隔 | 武器 | 标签 |
|---|-----|--------|------|-----|------|------|------|---------|------|------|
| 15 | cold_inf_ak | 苏军步兵 | 基础 | 60 | -90 | 14 | 140 | 0.33 | RIFLE | infantry, frontline, 蜂群 |
| 16 | cold_inf_m60 | 美军步兵 | 基础 | 65 | -90 | 15 | 150 | 0.25 | MG | infantry, frontline, 蜂群 |
| 17 | cold_arm_btr_e | BTR装甲车 | 基础 | 120 | -80 | 18 | 130 | 0.30 | MG | vehicle, armored |
| 18 | cold_air_m113_e | M113装甲车 | 基础 | 110 | -70 | 12 | 120 | 0.35 | MG | vehicle, support |
| 19 | cold_inf_spetsnaz_e | 特种部队 | 精英 | 90 | -120 | 20 | 220 | 1.25 | SNIPER | elite, infantry, fast |
| 20 | cold_arm_t72_e | T-72坦克 | 精英 | 375 | -60 | 40 | 160 | 0.80 | ROCKET | elite, tank, armored |
| 21 | cold_boss_mig | 米格-29 | 头目 | 750 | -150 | 55 | 210 | 0.80 | MISSILE | boss, aircraft, fast |

### 1.4 现代（8个，时代 3）

| # | ID | 显示名 | 类型 | HP | 速度 | 伤害 | 射程 | 攻速间隔 | 武器 | 标签 |
|---|-----|--------|------|-----|------|------|------|---------|------|------|
| 22 | mod_inf_marine | 海军陆战队 | 基础 | 70 | -100 | 16 | 150 | 0.29 | RIFLE | infantry, frontline, 蜂群 |
| 23 | mod_air_technical_e | 皮卡武装 | 基础 | 90 | -120 | 18 | 130 | 0.30 | MG | vehicle, fast |
| 24 | mod_arm_stryker_e | 斯特赖克装甲车 | 基础 | 150 | -80 | 22 | 150 | 0.35 | MG | vehicle, armored |
| 25 | mod_arty_mlrs_e | 火箭炮车 | 基础 | 100 | -50 | 35 | 250 | 2.00 | ROCKET | artillery, backline |
| 26 | mod_inf_delta_e | 三角洲部队 | 精英 | 100 | -130 | 24 | 150 | 0.29 | RIFLE | elite, infantry, fast |
| 27 | mod_arm_abrams_e | M1A2坦克 | 精英 | 450 | -60 | 45 | 200 | 0.80 | ROCKET | elite, tank, armored |
| 28 | mod_air_apache_e | 阿帕奇直升机 | 精英 | 220 | -120 | 38 | 250 | 0.60 | MISSILE | elite, aircraft, fast |
| 29 | mod_boss_command | 指挥中枢 | 头目 | 1200 | 0 | 70 | 220 | 1.20 | MG | boss, support |

### 1.5 近未来（7个，时代 4）

| # | ID | 显示名 | 类型 | HP | 速度 | 伤害 | 射程 | 攻速间隔 | 武器 | 标签 |
|---|-----|--------|------|-----|------|------|------|---------|------|------|
| 30 | fut_air_drone | 无人机群 | 基础 | 40 | -150 | 12 | 180 | 0.40 | LASER | aircraft, fast, 蜂群 |
| 31 | fut_inf_cyborg | 机械步兵 | 基础 | 100 | -100 | 22 | 160 | 0.25 | LASER | infantry, frontline, 蜂群 |
| 32 | fut_arm_mech_e | 机甲步兵 | 基础 | 180 | -80 | 30 | 150 | 0.67 | LASER | vehicle, armored |
| 33 | fut_arm_hovertank_e | 悬浮坦克 | 基础 | 250 | -110 | 40 | 250 | 0.50 | LASER | vehicle, armored, fast |
| 34 | fut_inf_spectre_e | 幽灵特工 | 精英 | 120 | -140 | 35 | 210 | 0.40 | LASER | elite, infantry, fast, stealth |
| 35 | fut_arm_colossus_e | 巨神机甲 | 精英 | 600 | -60 | 55 | 250 | 1.00 | LASER | elite, tank, armored |
| 36 | fut_boss_nexus | 风暴核心 | 头目 | 1800 | -30 | 90 | 300 | 0.90 | OMEGA | boss, ultimate |

### 1.6 原型数据趋势速览

| 时代 | 基础HP范围 | 精英HP范围 | 头目HP | 基础伤害范围 | 精英伤害范围 | 头目伤害 |
|------|-----------|-----------|--------|------------|------------|--------|
| 一战 | 40-80 | 70-120 | 600 | 8-20 | 12-15 | 25 |
| 二战 | 50-90 | 80-200 | 800 | 10-30 | 16-35 | 40 |
| 冷战 | 60-120 | 90-375 | 750 | 12-18 | 20-40 | 55 |
| 现代 | 70-150 | 100-450 | 1200 | 16-35 | 24-45 | 70 |
| 近未来 | 40-250 | 120-600 | 1800 | 12-40 | 35-55 | 90 |

---

## 2. 补充池敌人（29个，ID清单）

> 来源：enemy_unit_manifest.gd POOL_ENEMY_IDS
> 说明：这些敌人运行时从 UnifiedCardTable 取数值，静态文件中无独立HP/伤害数据
> 下列为各 kind 的回退默认值（仅当统一表查不到时使用）

### kind 回退值

| kind | HP | 轻攻 | 中攻 | 空攻 | 轻防 | 中防 | 空防 | 射程 | 间隔 | 速度 |
|------|-----|------|------|------|------|------|------|------|------|------|
| 0 步兵 | 55 | 10 | 7 | 6 | 4 | 3 | 3 | 110 | 0.50 | 120 |
| 1 载具 | 120 | 16 | 11 | 10 | 10 | 8 | 8 | 155 | 0.90 | 60 |
| 2 阵地 | 200 | 25 | 18 | 16 | 14 | 11 | 11 | 180 | 1.50 | 0 |
| 3 支援 | 90 | 8 | 6 | 5 | 6 | 5 | 5 | 130 | 0.40 | 70 |

### 29个补充池敌人ID与显示名

| # | ID | 显示名 | 时代 |
|---|-----|--------|------|
| 1 | ww1_inf_enfield | 李-恩菲尔德志愿兵排 | 一战 |
| 2 | ww1_arm_rolls_mk2 | 劳斯莱斯 Mk.II 装甲车 | 一战 |
| 3 | ww1_sup_vickers | 维克斯 .303 机枪阵地 | 一战 |
| 4 | ww1_sup_ford_ambulance | 福特 T 型战地救护车 | 一战 |
| 5 | ww1_inf_mp18_x | MP18 突击队 | 一战 |
| 6 | ww2_arm_garand_para | M1 加兰德伞兵班 | 二战 |
| 7 | ww2_arty_hummel | 黄蜂 Hummel 自行火炮 | 二战 |
| 8 | ww2_arty_pak40 | PaK 40 反坦克炮组 | 二战 |
| 9 | ww2_sup_gmc_truck | GMC 2.5t 补给卡车 | 二战 |
| 10 | ww2_inf_kar98k | 毛瑟 Kar98k 狙击组 | 二战 |
| 11 | cold_arty_bmd1 | BMD-1 空降战车 | 冷战 |
| 12 | cold_sup_bmp1_x | BMP-1 步兵战车 | 冷战 |
| 13 | cold_inf_metis | 9K111 法特导弹组 | 冷战 |
| 14 | cold_arm_p18 | P-18 雷达警戒车 | 冷战 |
| 15 | cold_arty_brem1 | BREM-1 装甲抢修车 | 冷战 |
| 16 | mod_sup_m4_carbine | M4 卡宾特遣班 | 现代 |
| 17 | mod_inf_patriot | 爱国者 PAC-3 发射车 | 现代 |
| 18 | mod_arm_himars | HIMARS 火箭炮组 | 现代 |
| 19 | mod_arty_rq7 | RQ-7 影子无人机班 | 现代 |
| 20 | mod_sup_growler | EA-18G 电子战小组 | 现代 |
| 21 | fut_inf_neural | 神经接口突击兵 | 近未来 |
| 22 | fut_arm_hk07 | HK-07 量产机兵 | 近未来 |
| 23 | fut_arty_hel30 | HEL-30 激光炮阵列 | 近未来 |
| 24 | fut_sup_nrepair | N-Repair 纳米工程车 | 近未来 |
| 25 | fut_inf_x9 | X-9 猎杀者渗透组 | 近未来 |
| 26 | fut_inf_c96 | 毛瑟 C96 征召兵排 | 近未来 |
| 27 | fut_arm_sdkfz | Sd.Kfz.251/1 半履带车 | 近未来 |
| 28 | fut_arty_ssc1 | SS-C-1 岸防导弹组 | 近未来 |
| 29 | fut_sup_ps9 | PS-9 相位中继站 | 近未来 |

---

## 3. 堡垒敌人（10个，ID清单）

> 来源：enemy_unit_manifest.gd FORT_ENEMY_IDS
> 说明：堡垒类敌人，运行时从 UnifiedCardTable 取数值；tags 含 fortress/immobile，speed=0

| # | ID | 时代 |
|---|-----|------|
| 1 | ww1_fort_pillbox | 一战 |
| 2 | ww1_fort_artillery | 一战 |
| 3 | ww2_fort_bunker | 二战 |
| 4 | ww2_fort_flak | 二战 |
| 5 | cold_fort_missile | 冷战 |
| 6 | cold_fort_radar | 冷战 |
| 7 | mod_fort_citadel | 现代 |
| 8 | mod_fort_phalanx | 现代 |
| 9 | fut_fort_ion | 近未来 |
| 10 | fut_fort_shield | 近未来 |

---

## 4. 敌方平台卡（34个，ID清单）

> 来源：enemy_unit_manifest.gd
> 说明：可被玩家缴获的敌方卡牌。运行时从 UnifiedCardTable 取数值，静态文件中无独立战斗数据
> A段=前线平台卡(28)，B段=精英掉落特殊卡(6)

### A段 前线平台卡（28个）

| # | ID | 映射平台 | 时代 |
|---|-----|---------|------|
| 1 | ww1_arm_rolls | platform_ww1_medium | 一战 |
| 2 | ww1_arm_ft17 | platform_ww1_medium | 一战 |
| 3 | ww1_arty_77mm | platform_ww1_fort | 一战 |
| 4 | ww1_inf_cavalry | platform_ww1_light | 一战 |
| 5 | ww1_sup_engineer | platform_ww1_medic | 一战 |
| 6 | ww2_inf_hellcat | platform_ww2_raider | 二战 |
| 7 | ww2_arm_sherman | platform_ww2_medium | 二战 |
| 8 | ww2_arm_tiger | platform_ww2_heavy | 二战 |
| 9 | ww2_inf_bazooka | platform_ww2_light | 二战 |
| 10 | ww2_inf_panzerschrek | platform_ww2_light | 二战 |
| 11 | ww2_arty_m81 | platform_ww2_fortress | 二战 |
| 12 | ww1_arty_m81 | platform_ww1_fort | 一战 |
| 13 | cold_inf_btr60 | platform_cold_ifv | 冷战 |
| 14 | cold_arm_t55 | platform_cold_medium | 冷战 |
| 15 | cold_inf_bmp1 | platform_cold_ifv | 冷战 |
| 16 | cold_sup_m113 | platform_cold_carrier | 冷战 |
| 17 | cold_sup_zsu23 | platform_cold_radar | 冷战 |
| 18 | mod_inf_technical | platform_modern_light | 现代 |
| 19 | mod_arm_m1a1 | platform_modern_medium | 现代 |
| 20 | mod_sup_m6 | platform_modern_radar | 现代 |
| 21 | mod_arty_m270 | platform_modern_spg | 现代 |
| 22 | mod_inf_scout_drone | platform_modern_stealth | 现代 |
| 23 | mod_arm_m1a2sep | platform_modern_guard_heavy | 现代 |
| 24 | fut_inf_scout_mech | platform_future_light | 近未来 |
| 25 | fut_arm_hovertank | platform_future_medium | 近未来 |
| 26 | fut_arm_prism | platform_future_heavy | 近未来 |
| 27 | fut_arm_heavy_mech | platform_future_heavy | 近未来 |
| 28 | fut_arm_nexus | fut_arm_omega | 近未来 |

### B段 精英掉落特殊卡（6个）

| # | ID | 掉落来源 | 时代 |
|---|-----|---------|------|
| 1 | fut_sup_bulwark | ww1_arm_rolls_e | 近未来 |
| 2 | fut_arm_titan_mk2 | ww1_boss_av7 | 近未来 |
| 3 | fut_inf_storm_rider | ww2_arm_panther_e | 近未来 |
| 4 | fut_air_heavy_carrier | ww2_boss_kingtiger | 近未来 |
| 5 | fut_air_regen_frame | cold_arm_t72_e | 近未来 |
| 6 | mod_arm_abrams_mk2 | mod_arm_abrams_e | 现代 |

---

## 5. 相位师（30个）

> 来源：enemy_phase_masters_ww1/ww2/cold/modern/future.gd
> 字段说明：HP=本体生命, ATK=攻击力, DEF=防御力, EREG=能量回复/秒, ULIM=单位上限
> 5时代 × 6个/时代，等级 Lv5~30，难度 easy→ultimate

### 5.1 一战相位师（6个）

| # | ID | 名称 | 称号 | Lv | 势力 | 难度 | HP | ATK | DEF | EREG | ULIM |
|---|-----|------|------|-----|------|------|-----|-----|-----|------|------|
| 1 | enemy_master_001 | 钢铁先锋·马库斯 | 钢铁防线守卫 | 5 | steel | easy | 1500 | 120 | 80 | 2.0 | 5 |
| 2 | enemy_master_002 | 烈焰使者·伊格尼斯 | 火焰狂暴者 | 6 | flame | easy | 1200 | 150 | 50 | 2.5 | 6 |
| 3 | enemy_master_003 | 雷击者·沃尔特 | 闪电链大师 | 7 | thunder | medium | 1100 | 160 | 45 | 3.0 | 5 |
| 4 | enemy_master_004 | 虚空行者·奈克萨斯 | 时空操纵者 | 8 | void | medium | 1300 | 140 | 60 | 2.8 | 5 |
| 5 | enemy_master_005 | 钢铁元帅·克劳斯 | 不可破之盾 | 10 | steel | medium | 2200 | 200 | 120 | 2.5 | 7 |
| 6 | enemy_master_006 | 炎魔女王·赫卡特 | 毁灭之焰 | 12 | flame | medium | 2000 | 260 | 70 | 3.0 | 7 |

### 5.2 二战相位师（6个）

| # | ID | 名称 | 称号 | Lv | 势力 | 难度 | HP | ATK | DEF | EREG | ULIM |
|---|-----|------|------|-----|------|------|-----|-----|-----|------|------|
| 7 | enemy_master_007 | 雷神之子·索尔 | 万钧雷霆 | 13 | thunder | hard | 1800 | 300 | 65 | 3.5 | 6 |
| 8 | enemy_master_008 | 虚空领主·萨洛斯 | 维度撕裂者 | 14 | void | hard | 2100 | 280 | 80 | 3.8 | 6 |
| 9 | enemy_master_009 | 钢铁军团长·费米 | 钢铁军团统帅 | 16 | steel | hard | 3000 | 280 | 150 | 3.0 | 8 |
| 10 | enemy_master_010 | 炎帝·普罗米修斯 | 永恒烈焰 | 17 | flame | hard | 2800 | 380 | 90 | 3.5 | 8 |
| 11 | enemy_master_011 | 雷皇·宙斯 | 雷霆主宰 | 18 | thunder | hard | 2600 | 420 | 85 | 4.0 | 7 |
| 12 | enemy_master_012 | 虚空虚主·阿扎托斯 | 虚空君王 | 19 | void | expert | 3200 | 400 | 100 | 4.2 | 7 |

### 5.3 冷战相位师（6个）

| # | ID | 名称 | 称号 | Lv | 势力 | 难度 | HP | ATK | DEF | EREG | ULIM |
|---|-----|------|------|-----|------|------|-----|-----|-----|------|------|
| 13 | enemy_master_013 | 钢铁烈焰·卡尔 | 熔铸大师 | 18 | steel_flame | hard | 2800 | 340 | 120 | 3.2 | 8 |
| 14 | enemy_master_014 | 雷霆钢铁·维克多 | 电磁装甲师 | 19 | thunder_steel | hard | 2700 | 360 | 140 | 3.5 | 7 |
| 15 | enemy_master_015 | 虚空烈焰·塞拉菲娜 | 熵增炎魔 | 20 | void_flame | expert | 2600 | 380 | 85 | 3.8 | 7 |
| 16 | enemy_master_016 | 不朽钢铁·阿特拉斯 | 世界承载者 | 22 | steel | expert | 5000 | 400 | 200 | 3.5 | 9 |
| 17 | enemy_master_017 | 永恒炎魔·苏尔特 | 诸神黄昏 | 23 | flame | expert | 4200 | 520 | 110 | 4.0 | 8 |
| 18 | enemy_master_018 | 万雷之主·雷神 | 雷霆化身 | 24 | thunder | expert | 3800 | 560 | 95 | 4.5 | 8 |

### 5.4 现代相位师（6个）

| # | ID | 名称 | 称号 | Lv | 势力 | 难度 | HP | ATK | DEF | EREG | ULIM |
|---|-----|------|------|-----|------|------|-----|-----|-----|------|------|
| 19 | enemy_master_019 | 虚空主宰·尼德霍格 | 世界吞噬者 | 25 | void | expert | 4500 | 500 | 120 | 4.5 | 8 |
| 20 | enemy_master_020 | 钢铁雷霆·泰尔 | 电磁战神 | 24 | steel_thunder | expert | 4200 | 480 | 160 | 4.0 | 8 |
| 21 | enemy_master_021 | 烈焰虚空·克尔加 | 混沌炎魔 | 25 | flame_void | legendary | 4000 | 520 | 100 | 4.5 | 7 |
| 22 | enemy_master_022 | 战争机器·铁骑 | 钢铁风暴 | 26 | steel | legendary | 5500 | 480 | 200 | 3.5 | 10 |
| 23 | enemy_master_023 | 火术宗师·凤凰 | 不死鸟 | 27 | flame | legendary | 4800 | 580 | 100 | 4.2 | 9 |
| 24 | enemy_master_024 | 风暴使者·赛勒斯 | 疾风迅雷 | 27 | thunder | legendary | 4000 | 550 | 80 | 4.8 | 8 |

### 5.5 近未来相位师（6个）

| # | ID | 名称 | 称号 | Lv | 势力 | 难度 | HP | ATK | DEF | EREG | ULIM |
|---|-----|------|------|-----|------|------|-----|-----|-----|------|------|
| 25 | enemy_master_025 | 暗影主宰·深渊 | 暗影之王 | 28 | void | legendary | 4500 | 580 | 80 | 4.5 | 7 |
| 26 | enemy_master_026 | 钢铁之神·赫淮斯托斯 | 锻造之神 | 28 | steel | legendary | 7000 | 550 | 230 | 4.0 | 12 |
| 27 | enemy_master_027 | 炎魔之神·赫卡特 | 炼狱女王 | 29 | flame | legendary | 6500 | 750 | 140 | 4.5 | 11 |
| 28 | enemy_master_028 | 雷神·托尔 | 雷霆之神 | 29 | thunder | legendary | 6000 | 850 | 130 | 6.0 | 10 |
| 29 | enemy_master_029 | 虚空女神·尼克斯 | 夜之女神 | 30 | void | legendary | 5800 | 800 | 110 | 5.5 | 9 |
| 30 | enemy_master_030 | 全能相位师·奥米伽 | 完美融合 | 30 | all | ultimate | 10000 | 1000 | 200 | 8.0 | 15 |

### 5.6 相位师数据趋势

| 难度 | Lv范围 | HP范围 | ATK范围 | DEF范围 | EREG范围 | ULIM范围 |
|------|--------|--------|---------|---------|---------|---------|
| easy | 5-6 | 1200-1500 | 120-150 | 50-80 | 2.0-2.5 | 5-6 |
| medium | 7-12 | 1100-2200 | 140-260 | 45-120 | 2.5-3.0 | 5-7 |
| hard | 13-19 | 1800-3200 | 280-420 | 65-150 | 3.0-4.2 | 6-8 |
| expert | 19-25 | 2600-5000 | 340-560 | 85-200 | 3.2-4.5 | 7-9 |
| legendary | 25-29 | 4000-7000 | 480-850 | 80-230 | 3.5-6.0 | 7-12 |
| ultimate | 30 | 10000 | 1000 | 200 | 8.0 | 15 |

---

## 6. 相位师装备平台（24个）

> 来源：enemy_equipment_armor_modules.gd LEGACY_WAR_PLATFORMS
> 说明：相位师召唤的产兵平台本体数据
> 字段：HP=生命, ATK=攻击, DEF=防御, MSPD=移速, ASPD=攻速间隔

### 6.1 钢铁系（6个）

| # | ID | 名称 | 等级 | 类型 | HP | ATK | DEF | MSPD | ASPD |
|---|-----|------|------|------|-----|-----|-----|------|------|
| 1 | steel_fortress_basic | 要塞固定炮平台 | 5 | 要塞 | 1500 | 80 | 100 | 20 | 1.0 |
| 2 | steel_titan_basic | 马克V型坦克平台 | 5 | 泰坦 | 1200 | 100 | 80 | 35 | 0.9 |
| 3 | steel_fortress_advanced | 要塞固定炮平台 | 12 | 要塞 | 2500 | 150 | 180 | 15 | 0.8 |
| 4 | steel_titan_advanced | 马克V型坦克平台 | 12 | 泰坦 | 2000 | 180 | 140 | 30 | 0.85 |
| 5 | steel_fortress_expert | 要塞固定炮平台 | 18 | 要塞 | 4000 | 250 | 250 | 10 | 0.7 |
| 6 | steel_titan_expert | 马克V型坦克平台 | 18 | 泰坦 | 3500 | 300 | 200 | 25 | 0.8 |

### 6.2 烈焰系（6个）

| # | ID | 名称 | 等级 | 类型 | HP | ATK | DEF | MSPD | ASPD |
|---|-----|------|------|------|-----|-----|-----|------|------|
| 7 | flame_raider_basic | BA-64轻型突击车 | 6 | 突袭 | 900 | 120 | 40 | 60 | 1.2 |
| 8 | flame_siege_basic | 203mm迫击炮 | 6 | 围攻 | 1100 | 150 | 60 | 25 | 0.7 |
| 9 | flame_raider_advanced | BA-64轻型突击车 | 13 | 突袭 | 1400 | 200 | 50 | 70 | 1.4 |
| 10 | flame_siege_advanced | 203mm迫击炮 | 13 | 围攻 | 1800 | 250 | 80 | 20 | 0.6 |
| 11 | flame_raider_expert | BA-64轻型突击车 | 19 | 突袭 | 2000 | 320 | 60 | 80 | 1.6 |
| 12 | flame_siege_expert | 203mm迫击炮 | 19 | 围攻 | 2800 | 380 | 90 | 18 | 0.5 |

### 6.3 雷霆系（6个）

| # | ID | 名称 | 等级 | 类型 | HP | ATK | DEF | MSPD | ASPD |
|---|-----|------|------|------|-----|-----|-----|------|------|
| 13 | thunter_striker_basic | 雷霆打击者 | 7 | 打击 | 800 | 140 | 35 | 65 | 1.5 |
| 14 | thunter_sniper_basic | 雷霆狙击手 | 7 | 狙击 | 600 | 200 | 20 | 30 | 0.5 |
| 15 | thunter_striker_advanced | 雷霆打击者 | 14 | 打击 | 1200 | 220 | 50 | 75 | 1.8 |
| 16 | thunter_sniper_advanced | 雷霆狙击手 | 14 | 狙击 | 900 | 320 | 30 | 35 | 0.4 |
| 17 | thunter_striker_expert | 雷霆打击者 | 20 | 打击 | 1800 | 350 | 65 | 85 | 2.0 |
| 18 | thunter_sniper_expert | 雷霆狙击手 | 20 | 狙击 | 1300 | 500 | 40 | 40 | 0.3 |

### 6.4 虚空系（6个）

| # | ID | 名称 | 等级 | 类型 | HP | ATK | DEF | MSPD | ASPD |
|---|-----|------|------|------|-----|-----|-----|------|------|
| 19 | void_stealth_basic | 虚空潜行者 | 8 | 潜行 | 700 | 130 | 30 | 80 | 1.3 |
| 20 | void_mage_basic | 虚空法师 | 8 | 法师 | 650 | 180 | 25 | 35 | 0.8 |
| 21 | void_stealth_advanced | 虚空潜行者 | 15 | 潜行 | 1100 | 200 | 45 | 95 | 1.5 |
| 22 | void_mage_advanced | 虚空法师 | 15 | 法师 | 1000 | 280 | 35 | 40 | 0.7 |
| 23 | void_stealth_expert | 虚空潜行者 | 21 | 潜行 | 1600 | 320 | 60 | 110 | 1.8 |
| 24 | void_mage_expert | 虚空法师 | 21 | 法师 | 1500 | 420 | 50 | 45 | 0.6 |

### 6.5 平台数据趋势

| 势力 | 基础HP范围 | 进阶HP范围 | 专家HP范围 | 基础ATK范围 | 专家ATK范围 |
|------|-----------|-----------|-----------|------------|------------|
| 钢铁 | 1200-1500 | 2000-2500 | 3500-4000 | 80-100 | 250-300 |
| 烈焰 | 900-1100 | 1400-1800 | 2000-2800 | 120-150 | 320-380 |
| 雷霆 | 600-800 | 900-1200 | 1300-1800 | 140-200 | 350-500 |
| 虚空 | 650-700 | 1000-1100 | 1500-1600 | 130-180 | 320-420 |

---

## 7. 相位师武器（24个）

> 来源：enemy_equipment_weapons.gd LEGACY_WAR_WEAPONS
> 字段：DMG=伤害, ASPD=攻击间隔, RNG=射程

### 7.1 钢铁系（6个）

| # | ID | 名称 | 等级 | 类型 | DMG | ASPD | RNG |
|---|-----|------|------|------|-----|------|-----|
| 1 | steel_machinegun_basic | 钢铁机枪·基础 | 5 | 机枪 | 25 | 0.15 | 200 |
| 2 | steel_cannon_basic | 钢铁火炮·基础 | 5 | 火炮 | 80 | 1.5 | 300 |
| 3 | steel_minigun_advanced | 钢铁转轮机枪·进阶 | 12 | 机枪 | 35 | 0.08 | 220 |
| 4 | steel_railcannon_advanced | 钢铁电磁炮·进阶 | 12 | 电磁炮 | 150 | 2.0 | 400 |
| 5 | steel_gatling_expert | 钢铁转轮机枪·专家 | 18 | 机枪 | 50 | 0.05 | 250 |
| 6 | steel_artillery_expert | 钢铁重炮·专家 | 18 | 火炮 | 220 | 1.8 | 450 |

### 7.2 烈焰系（6个）

| # | ID | 名称 | 等级 | 类型 | DMG | ASPD | RNG |
|---|-----|------|------|------|-----|------|-----|
| 7 | flame_thrower_basic | 火焰喷射器·基础 | 6 | 喷射 | 40 | 0.1 | 120 |
| 8 | incendiary_mortar_basic | 燃烧迫击炮·基础 | 6 | 迫击炮 | 100 | 2.5 | 350 |
| 9 | flame_thrower_advanced | 火焰喷射器·进阶 | 13 | 喷射 | 65 | 0.08 | 140 |
| 10 | incendiary_cannon_advanced | 燃烧炮·进阶 | 13 | 迫击炮 | 160 | 2.0 | 380 |
| 11 | flame_thrower_expert | 等离子喷射器·专家 | 19 | 喷射 | 100 | 0.06 | 160 |
| 12 | plasma_cannon_expert | 等离子炮·专家 | 19 | 火炮 | 280 | 1.5 | 400 |

### 7.3 雷霆系（6个）

| # | ID | 名称 | 等级 | 类型 | DMG | ASPD | RNG |
|---|-----|------|------|------|-----|------|-----|
| 13 | tesla_coil_basic | 特斯拉线圈·基础 | 7 | 特斯拉 | 45 | 0.5 | 180 |
| 14 | railgun_basic | 电磁炮·基础 | 7 | 电磁炮 | 120 | 1.8 | 500 |
| 15 | tesla_coil_advanced | 特斯拉线圈·进阶 | 14 | 特斯拉 | 75 | 0.4 | 200 |
| 16 | railgun_advanced | 电磁炮·进阶 | 14 | 电磁炮 | 200 | 1.5 | 550 |
| 17 | tesla_coil_expert | 特斯拉线圈·专家 | 20 | 特斯拉 | 120 | 0.3 | 250 |
| 18 | railgun_expert | 电磁炮·专家 | 20 | 电磁炮 | 320 | 1.2 | 600 |

### 7.4 虚空系（6个）

| # | ID | 名称 | 等级 | 类型 | DMG | ASPD | RNG |
|---|-----|------|------|------|-----|------|-----|
| 19 | void_lance_basic | 虚空长矛·基础 | 8 | 长矛 | 90 | 1.2 | 150 |
| 20 | gravity_well_basic | 重力井·基础 | 8 | 重力 | 60 | 2.0 | 200 |
| 21 | void_lance_advanced | 虚空长矛·进阶 | 15 | 长矛 | 140 | 1.0 | 170 |
| 22 | gravity_well_advanced | 重力井·进阶 | 15 | 重力 | 100 | 1.5 | 250 |
| 23 | void_lance_expert | 虚空长矛·专家 | 21 | 长矛 | 220 | 0.8 | 190 |
| 24 | entropy_caster_expert | 熵增法杖·专家 | 21 | 重力 | 180 | 1.2 | 280 |

### 7.5 武器数据趋势

| 势力 | 基础DMG范围 | 专家DMG范围 | 基础RNG范围 | 专家RNG范围 |
|------|------------|------------|-----------|-----------|
| 钢铁 | 25-80 | 50-220 | 200-300 | 250-450 |
| 烈焰 | 40-100 | 100-280 | 120-350 | 160-400 |
| 雷霆 | 45-120 | 120-320 | 180-500 | 250-600 |
| 虚空 | 60-90 | 180-220 | 150-200 | 190-280 |

---

## 8. 数量统计汇总

| 类别 | 数量 | 数据完整度 | 说明 |
|------|------|-----------|------|
| 常规敌人原型 | 36 | ✅ 完整 | 5时代手填数据，有独立HP/伤害/射程/攻速 |
| 补充池敌人 | 29 | ⚠️ 无独立数据 | 运行时从 UnifiedCardTable 取值 |
| 堡垒敌人 | 10 | ⚠️ 无独立数据 | 运行时从 UnifiedCardTable 取值 |
| 敌方平台卡(A段) | 28 | ⚠️ 无独立数据 | 运行时从 UnifiedCardTable 取值 |
| 敌方特殊卡(B段) | 6 | ⚠️ 无独立数据 | 运行时从 UnifiedCardTable 取值 |
| 相位师 | 30 | ✅ 完整 | 5时代×6个，有HP/ATK/DEF/EREG/ULIM |
| 相位师装备平台 | 24 | ✅ 完整 | 4势力×2型×3阶，有HP/ATK/DEF/MSPD/ASPD |
| 相位师武器 | 24 | ✅ 完整 | 4势力×2型×3阶，有DMG/ASPD/RNG |
| **合计** | **187** | | 其中 114 条有独立基础数据，73 条从统一卡表取值 |
