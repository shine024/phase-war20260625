# 卡图配置审计报告

**生成日期**: 2026-07-16
**数据来源**: `data/unified_card_table.gd` (223张卡) + `scripts/ui_asset_loader.gd` + `data/enemy_unit_manifest.gd` + `assets/card_icons/` 实际文件
**结论**: 223/223 张卡都能解析到图标，**0 张缺图**。其中 190 张有专属图标，33 张共享通用回退图。

---

## 一、图标解析链（card_icon_path_for）

`ui_asset_loader.gd:332-396`，按顺序取第一个命中的：

| 步骤 | 来源 | 说明 |
|------|------|------|
| 0 | `card_icons/{card_id}.png` | 根目录专属图（实际只有 _enemy_placeholder.png） |
| 1 | manifest foe 映射 | `foe_{card_id}` → manifest → vis_player_NNN |
| 1.5 | PLAYER_ICON_OVERRIDE | 74条 card_id → vis_player_NNN 直接映射 |
| 2 | manifest archetype | 去掉 captured_ 前缀后查 manifest |
| 3 | drops 反查 | `get_visual_archetype_id_for_card` 找掉落它的敌人 |
| 4/5 | 根目录 {card_id}.png | 重复检查（实际死路径） |
| 6 | **era_kind 通用回退** | ⚠️ 共享图，无专属 |
| 7 | shape_key / placeholder | 最终兜底 |

---

## 二、现有图标文件清单

### `assets/card_icons/player/`（110 张 PNG）
- **vis_player_001.png ~ vis_player_081.png**（81张编号图，全部存在）
- **29 张专属命名图**：
  `cold_arm_p18, cold_arty_bmd1, cold_arty_brem1, cold_inf_metis, cold_sup_bmp1_x, fut_arm_hk07, fut_arm_sdkfz, fut_arty_hel30, fut_arty_ssc1, fut_inf_c96, fut_inf_neural, fut_inf_x9, fut_sup_nrepair, fut_sup_ps9, mod_arm_himars, mod_arty_rq7, mod_inf_patriot, mod_sup_growler, mod_sup_m4_carbine, ww1_arm_rolls_mk2, ww1_inf_enfield, ww1_inf_mp18_x, ww1_sup_ford_ambulance, ww1_sup_vickers, ww2_arm_garand_para, ww2_arty_hummel, ww2_arty_pak40, ww2_inf_kar98k, ww2_sup_gmc_truck`

### `assets/card_icons/enemy/`（110 张 PNG）
- **vis_enemy_001.png ~ vis_enemy_081.png**（81张，player的镜像翻转版）
- **29 张专属命名图**（与 player 同名）

### `assets/card_icons/` 根目录（1 张）
- `_enemy_placeholder.png`（最终兜底占位符）

---

## 三、映射表数据

### PLAYER_ICON_OVERRIDE（74条）
```
ww1_lanchest→001   ww1_105mm→003   ww1_37mm→003   ww1_mp18→036
ww1_mauser→037     ww1_enfield→037 ww1_mg08→038   ww1_vickers→038
ww1_m76→039        ww1_storm→040   ww1_flame→036  ww1_mark4→041
ww1_a7v→042        ww1_saint→042
ww2_pz3→007        ww2_pz4→007     ww2_t34_76→007 ww2_t34_85→007
ww2_is2→008        ww2_m120→011    ww2_mp40→043   ww2_ppsh→043
ww2_thompson→043   ww2_garand→044  ww2_mg42→045   ww2_browning→045
ww2_panther→048    ww2_kingtiger→049
cold_sam7→017      cold_rpg→046    cold_m60→045   cold_rpk→045
cold_ak47→050      cold_m14→051    cold_leo1→052  cold_m1→052
cold_m60t→052      cold_bradley→053 cold_spetsnaz→054 cold_chieftain→055
cold_t62→055       cold_t72→055    cold_f4→056    cold_mig21→056
mod_t90→055        mod_marine→057  mod_hummer_m2→058 mod_hummer_tow→058
mod_stryker_m2→059 mod_stryker_mgs→059 fut_aa_hover→060 fut_howitzer→060
mod_ranger→061     mod_challenger2→062 mod_leo2a6→062 mod_m1a2→062
mod_ah1→063        mod_ah64→063    mod_stinger→063 mod_uh60→063
mod_javelin→046
fut_attack_drone→065 fut_nano_drone→065 fut_space_fighter→065
fut_stealth_bomber→065 fut_swarm→065 fut_cyborg→066 fut_heavy_trooper→066
fut_assault_mech→067 fut_spectre→069 fut_arm_omega→070 fut_colossus→070
fut_stormcore→071 fut_shield→081
```

### ERA_KIND_FALLBACK_ICON（25条，格式 era_kind）
```
0_0→004  0_1→001  0_2→003  0_3→015  0_4→003   (WW1: 轻/甲/援/空/堡)
1_0→009  1_1→007  1_2→011  1_3→022  1_4→011   (WW2)
2_0→018  2_1→014  2_2→016  2_3→015  2_4→016   (冷战)
3_0→018  3_1→019  3_2→020  3_3→022  3_4→020   (现代)
4_0→024  4_1→025  4_2→020  4_3→022  4_4→025   (近未来)
```

---

## 四、全 223 张卡图标映射明细

格式：`card_id | display_name | era | combat_kind | flags | 解析来源 | 图标文件 | 类型`

### WW1（era 0）— 41 张

| card_id | display_name | 兵种 | flags | 来源 | 图标 | 类型 |
|---------|-------------|------|-------|------|------|------|
| drop_smg_mk2 | MP18-II 冲锋班 | 轻 | enemy_only | drops反查(ww1_inf_storm_e) | vis_player_040 | ✅专属 |
| guardian_ww1_ironclad | 铁壁守护者·一战 | 甲 | 成就 | era_kind回退 | vis_player_001 | ⚠️共享 |
| platform_ww1_fort | 一战炮台平台 | 援 | enemy_only | era_kind回退 | vis_player_003 | ⚠️共享 |
| platform_ww1_light | 一战轻型平台 | 轻 | enemy_only | era_kind回退 | vis_player_004 | ⚠️共享 |
| platform_ww1_medic | 一战医疗平台 | 援 | enemy_only | era_kind回退 | vis_player_003 | ⚠️共享 |
| platform_ww1_medium | 一战中型平台 | 甲 | enemy_only | era_kind回退 | vis_player_001 | ⚠️共享 |
| platform_ww1_radar | 一战雷达平台 | 援 | enemy_only | era_kind回退 | vis_player_003 | ⚠️共享 |
| ww1_105mm | 105mm榴弹炮 | 援 | - | override | vis_player_003 | ✅专属 |
| ww1_37mm | 37mm高射炮 | 援 | - | override | vis_player_003 | ✅专属 |
| ww1_a7v | A7V重型坦克 | 甲 | - | override | vis_player_042 | ✅专属 |
| ww1_arm_ft17 | FT-17轻型坦克 | 甲 | - | manifest | vis_player_002 | ✅专属 |
| ww1_arm_rolls | 罗尔斯装甲车 | 甲 | - | manifest | vis_player_001 | ✅专属 |
| ww1_arm_rolls_e | 装甲车·精锐 | 甲 | enemy_only | manifest | vis_player_041 | ✅专属 |
| ww1_arm_rolls_mk2 | 劳斯莱斯 Mk.II 装甲车 | 甲 | enemy_only | manifest | ww1_arm_rolls_mk2 | ✅专属 |
| ww1_arty_77mm | 77mm野战炮 | 援 | - | manifest | vis_player_003 | ✅专属 |
| ww1_arty_m81 | 81mm迫击炮组 | 援 | - | manifest | vis_player_012 | ✅专属 |
| ww1_arty_mortar | 迫击炮组 | 援 | enemy_only | manifest | vis_player_039 | ✅专属 |
| ww1_boss_av7 | 圣沙蒙坦克·Boss | 甲 | enemy_only | manifest | vis_player_042 | ✅专属 |
| ww1_enfield | 李恩菲尔德班 | 轻 | - | override | vis_player_037 | ✅专属 |
| ww1_flame | 火焰喷射兵 | 轻 | - | override | vis_player_036 | ✅专属 |
| ww1_fort_artillery | 要塞炮台 | 堡 | - | manifest | vis_player_073 | ✅专属 |
| ww1_fort_pillbox | 混凝土机枪碉堡 | 堡 | - | manifest | vis_player_072 | ✅专属 |
| ww1_inf_cavalry | 骑兵斥候 | 轻 | - | manifest | vis_player_004 | ✅专属 |
| ww1_inf_enfield | 李-恩菲尔德志愿兵排 | 轻 | enemy_only | manifest | ww1_inf_enfield | ✅专属 |
| ww1_inf_mp18 | 步兵班·MP18 | 轻 | enemy_only | manifest | vis_player_036 | ✅专属 |
| ww1_inf_mp18_x | MP18 突击队 | 轻 | enemy_only | manifest | ww1_inf_mp18_x | ✅专属 |
| ww1_inf_rifle | 步兵班·步枪 | 轻 | enemy_only | manifest | vis_player_037 | ✅专属 |
| ww1_inf_storm_e | 暴风突击队·精锐 | 轻 | enemy_only | manifest | vis_player_040 | ✅专属 |
| ww1_lanchest | 兰彻斯特装甲车 | 甲 | - | override | vis_player_001 | ✅专属 |
| ww1_m76 | 76mm迫击炮组 | 援 | - | override | vis_player_039 | ✅专属 |
| ww1_mark4 | 马克IV型坦克 | 甲 | - | override | vis_player_041 | ✅专属 |
| ww1_mauser | 毛瑟步枪班 | 轻 | - | override | vis_player_037 | ✅专属 |
| ww1_mg08 | MG08机枪巢 | 援 | - | override | vis_player_038 | ✅专属 |
| ww1_mp18 | MP18突击班 | 轻 | - | override | vis_player_036 | ✅专属 |
| ww1_saint | 圣沙蒙坦克 | 甲 | - | override | vis_player_042 | ✅专属 |
| ww1_storm | 暴风突击队 | 轻 | - | override | vis_player_040 | ✅专属 |
| ww1_sup_engineer | 工兵班 | 援 | - | manifest | vis_player_005 | ✅专属 |
| ww1_sup_ford_ambulance | 福特 T 型战地救护车 | 援 | enemy_only | manifest | ww1_sup_ford_ambulance | ✅专属 |
| ww1_sup_mg_nest | 机枪巢 | 援 | enemy_only | manifest | vis_player_038 | ✅专属 |
| ww1_sup_vickers | 维克斯 .303 机枪阵地 | 援 | enemy_only | manifest | ww1_sup_vickers | ✅专属 |
| ww1_vickers | 维克斯机枪巢 | 援 | - | override | vis_player_038 | ✅专属 |

### WW2（era 1）— 43 张

| card_id | display_name | 兵种 | flags | 来源 | 图标 | 类型 |
|---------|-------------|------|-------|------|------|------|
| drop_phase_lance | 相位刺刀班 | 轻 | enemy_only | drops反查(ww2_inf_para_e) | vis_player_047 | ✅专属 |
| guardian_ww2_blitzkrieg | 闪电守护者·二战 | 甲 | 成就 | era_kind回退 | vis_player_007 | ⚠️共享 |
| platform_ww2_fortress | 二战要塞平台 | 堡 | enemy_only | era_kind回退 | vis_player_011 | ⚠️共享 |
| platform_ww2_heavy | 二战重型平台 | 甲 | enemy_only | era_kind回退 | vis_player_007 | ⚠️共享 |
| platform_ww2_light | 二战轻型平台 | 轻 | enemy_only | era_kind回退 | vis_player_009 | ⚠️共享 |
| platform_ww2_medium | 二战中型平台 | 甲 | enemy_only | era_kind回退 | vis_player_007 | ⚠️共享 |
| platform_ww2_radar | 二战雷达平台 | 援 | enemy_only | era_kind回退 | vis_player_011 | ⚠️共享 |
| platform_ww2_raider | 二战突袭平台 | 轻 | enemy_only | era_kind回退 | vis_player_009 | ⚠️共享 |
| platform_ww2_siege | 二战攻城平台 | 援 | enemy_only | era_kind回退 | vis_player_011 | ⚠️共享 |
| ww2_arm_garand_para | M1 加兰德伞兵班 | 轻 | enemy_only | manifest | ww2_arm_garand_para | ✅专属 |
| ww2_arm_panther_e | 黑豹坦克·精锐 | 甲 | enemy_only | manifest | vis_player_048 | ✅专属 |
| ww2_arm_sherman | M4谢尔曼 | 甲 | - | manifest | vis_player_007 | ✅专属 |
| ww2_arm_tiger | 虎式坦克 | 甲 | - | manifest | vis_player_008 | ✅专属 |
| ww2_arty_hummel | 黄蜂 Hummel 自行火炮 | 援 | enemy_only | manifest | ww2_arty_hummel | ✅专属 |
| ww2_arty_m81 | 81mm迫击炮 | 援 | - | manifest | vis_player_011 | ✅专属 |
| ww2_arty_pak40 | PaK 40 反坦克炮组 | 援 | enemy_only | manifest | ww2_arty_pak40 | ✅专属 |
| ww2_boss_kingtiger | 虎王坦克·Boss | 甲 | enemy_only | manifest | vis_player_049 | ✅专属 |
| ww2_browning | 勃朗宁机枪组 | 援 | - | override | vis_player_045 | ✅专属 |
| ww2_fort_bunker | 混凝土碉堡 | 堡 | - | manifest | vis_player_074 | ✅专属 |
| ww2_fort_flak | 88mm防空塔 | 堡 | - | manifest | vis_player_075 | ✅专属 |
| ww2_garand | 加兰德班 | 轻 | - | override | vis_player_044 | ✅专属 |
| ww2_inf_bazooka | 巴祖卡组 | 轻 | - | manifest | vis_player_009 | ✅专属 |
| ww2_inf_garand | 步枪班·加兰德 | 轻 | enemy_only | manifest | vis_player_044 | ✅专属 |
| ww2_inf_hellcat | M18地狱猫 | 甲 | - | manifest | vis_player_006 | ✅专属 |
| ww2_inf_kar98k | 毛瑟 Kar98k 狙击组 | 轻 | enemy_only | manifest | ww2_inf_kar98k | ✅专属 |
| ww2_inf_panzerschreck_e | 反坦克组·精锐 | 轻 | enemy_only | manifest | vis_player_046 | ✅专属 |
| ww2_inf_panzerschrek | 铁拳反坦克组 | 轻 | - | manifest | vis_player_010 | ✅专属 |
| ww2_inf_para_e | 伞兵精英 | 轻 | enemy_only | manifest | vis_player_047 | ✅专属 |
| ww2_inf_thompson | 步兵班·汤普森 | 轻 | enemy_only | manifest | vis_player_043 | ✅专属 |
| ww2_is2 | IS-2重型坦克 | 甲 | - | override | vis_player_008 | ✅专属 |
| ww2_kingtiger | 虎王坦克 | 甲 | - | override | vis_player_049 | ✅专属 |
| ww2_m120 | 120mm重迫击炮 | 援 | - | override | vis_player_011 | ✅专属 |
| ww2_mg42 | MG42机枪组 | 援 | - | override | vis_player_045 | ✅专属 |
| ww2_mp40 | MP40班 | 轻 | - | override | vis_player_043 | ✅专属 |
| ww2_panther | 黑豹坦克 | 甲 | - | override | vis_player_048 | ✅专属 |
| ww2_ppsh | 波波沙班 | 轻 | - | override | vis_player_043 | ✅专属 |
| ww2_pz3 | 三号坦克 | 甲 | - | override | vis_player_007 | ✅专属 |
| ww2_pz4 | 四号坦克 | 甲 | - | override | vis_player_007 | ✅专属 |
| ww2_sup_gmc_truck | GMC 2.5t 补给卡车 | 援 | enemy_only | manifest | ww2_sup_gmc_truck | ✅专属 |
| ww2_sup_mg42 | MG42机枪组·敌方 | 援 | enemy_only | manifest | vis_player_045 | ✅专属 |
| ww2_t34_76 | T-34/76坦克 | 甲 | - | override | vis_player_007 | ✅专属 |
| ww2_t34_85 | T-34/85坦克 | 甲 | - | override | vis_player_007 | ✅专属 |
| ww2_thompson | 汤普森班 | 轻 | - | override | vis_player_043 | ✅专属 |

### 冷战（era 2）— 44 张

| card_id | display_name | 兵种 | flags | 来源 | 图标 | 类型 |
|---------|-------------|------|-------|------|------|------|
| cold_air_m113_e | M113装甲车·敌方 | 甲 | enemy_only | manifest | vis_player_053 | ✅专属 |
| cold_ak47 | AK-47步兵班 | 轻 | - | override | vis_player_050 | ✅专属 |
| cold_arm_btr_e | BTR装甲车·敌方 | 甲 | enemy_only | manifest | vis_player_052 | ✅专属 |
| cold_arm_p18 | P-18 雷达警戒车 | 援 | enemy_only | manifest | cold_arm_p18 | ✅专属 |
| cold_arm_t55 | T-55坦克 | 甲 | - | manifest | vis_player_014 | ✅专属 |
| cold_arm_t72_e | T-72坦克·精锐 | 甲 | enemy_only | manifest | vis_player_055 | ✅专属 |
| cold_arty_bmd1 | BMD-1 空降战车 | 援 | enemy_only | manifest | cold_arty_bmd1 | ✅专属 |
| cold_arty_brem1 | BREM-1 装甲抢修车 | 甲 | enemy_only | manifest | cold_arty_brem1 | ✅专属 |
| cold_boss_mig | 米格-29·Boss | 空 | enemy_only | manifest | vis_player_056 | ✅专属 |
| cold_bradley | M2布雷德利 | 甲 | - | override | vis_player_053 | ✅专属 |
| cold_chieftain | 酋长坦克 | 甲 | - | override | vis_player_055 | ✅专属 |
| cold_f4 | F-4鬼怪战机 | 空 | - | override | vis_player_056 | ✅专属 |
| cold_fort_missile | 导弹发射井 | 堡 | - | manifest | vis_player_076 | ✅专属 |
| cold_fort_radar | 雷达站 | 堡 | - | manifest | vis_player_077 | ✅专属 |
| cold_inf_ak | 苏军步兵 | 轻 | enemy_only | manifest | vis_player_050 | ✅专属 |
| cold_inf_bmp1 | BMP-1步战车 | 甲 | - | manifest | vis_player_015 | ✅专属 |
| cold_inf_btr60 | BTR-60装甲车 | 甲 | - | manifest | vis_player_013 | ✅专属 |
| cold_inf_m60 | 美军步兵·M60 | 轻 | enemy_only | manifest | vis_player_051 | ✅专属 |
| cold_inf_metis | 9K111 法特导弹组 | 轻 | enemy_only | manifest | cold_inf_metis | ✅专属 |
| cold_inf_spetsnaz_e | 特种部队·精锐 | 轻 | enemy_only | manifest | vis_player_054 | ✅专属 |
| cold_leo1 | 豹1坦克 | 甲 | - | override | vis_player_052 | ✅专属 |
| cold_m1 | M1主战坦克 | 甲 | - | override | vis_player_052 | ✅专属 |
| cold_m14 | M14步兵班 | 轻 | - | override | vis_player_051 | ✅专属 |
| cold_m60 | M60机枪班 | 轻 | - | override | vis_player_045 | ✅专属 |
| cold_m60t | M60坦克 | 甲 | - | override | vis_player_052 | ✅专属 |
| cold_mig21 | 米格-21战机 | 空 | - | override | vis_player_056 | ✅专属 |
| cold_rpg | RPG火箭筒组 | 轻 | - | override | vis_player_046 | ✅专属 |
| cold_rpk | RPK机枪班 | 轻 | - | override | vis_player_045 | ✅专属 |
| cold_sam7 | 萨姆-7防空组 | 援 | - | override | vis_player_017 | ✅专属 |
| cold_spetsnaz | 阿尔法特种部队 | 轻 | - | override | vis_player_054 | ✅专属 |
| cold_sup_bmp1_x | BMP-1 步兵战车·改 | 甲 | enemy_only | manifest | cold_sup_bmp1_x | ✅专属 |
| cold_sup_m113 | M113装甲车 | 援 | - | manifest | vis_player_016 | ✅专属 |
| cold_sup_zsu23 | ZSU-23-4自行高炮 | 援 | - | manifest | vis_player_017 | ✅专属 |
| cold_t62 | T-62坦克 | 甲 | - | override | vis_player_055 | ✅专属 |
| cold_t72 | T-72坦克 | 甲 | - | override | vis_player_055 | ✅专属 |
| drop_mega_beam_cannon | 巨型光束炮 | 援 | enemy_only | drops反查(mod_boss_command) | vis_player_064 | ✅专属 |
| drop_railgun | 电磁步枪班 | 轻 | enemy_only | drops反查(cold_inf_spetsnaz_e) | vis_player_054 | ✅专属 |
| guardian_cold_thunder | 雷霆守护者·冷战 | 援 | 成就 | era_kind回退 | vis_player_016 | ⚠️共享 |
| platform_cold_carrier | 冷战运输平台 | 空 | enemy_only | era_kind回退 | vis_player_015 | ⚠️共享 |
| platform_cold_ifv | 冷战步战车平台 | 空 | enemy_only | era_kind回退 | vis_player_015 | ⚠️共享 |
| platform_cold_light | 冷战轻型平台 | 轻 | enemy_only | era_kind回退 | vis_player_018 | ⚠️共享 |
| platform_cold_medium | 冷战中型平台 | 甲 | enemy_only | era_kind回退 | vis_player_014 | ⚠️共享 |
| platform_cold_radar | 冷战雷达平台 | 援 | enemy_only | era_kind回退 | vis_player_016 | ⚠️共享 |
| platform_cold_scout | 冷战侦察平台 | 轻 | enemy_only | era_kind回退 | vis_player_018 | ⚠️共享 |

### 现代（era 3）— 46 张

| card_id | display_name | 兵种 | flags | 来源 | 图标 | 类型 |
|---------|-------------|------|-------|------|------|------|
| drop_overclock_matrix | 超频矩阵机 | 空 | enemy_only | drops反查(mod_air_apache_e) | vis_player_063 | ✅专属 |
| drop_thunder_field | 雷霆突击班 | 轻 | enemy_only | drops反查(mod_inf_delta_e) | vis_player_061 | ✅专属 |
| guardian_modern_stealth | 幽灵守护者·现代 | 空 | 成就 | era_kind回退 | vis_player_022 | ⚠️共享 |
| mod_ah1 | AH-1眼镜蛇 | 空 | - | override | vis_player_063 | ✅专属 |
| mod_ah64 | AH-64阿帕奇 | 空 | - | override | vis_player_063 | ✅专属 |
| mod_air_apache_e | 阿帕奇直升机·精锐 | 空 | enemy_only | manifest | vis_player_063 | ✅专属 |
| mod_air_technical_e | 皮卡武装·敌方 | 轻 | enemy_only | manifest | vis_player_058 | ✅专属 |
| mod_arm_abrams_e | M1A2坦克·精锐 | 甲 | enemy_only | manifest | vis_player_062 | ✅专属 |
| mod_arm_abrams_mk2 | 艾布拉姆斯Mk.II | 甲 | enemy_only | manifest(foe) | vis_player_035 | ✅专属 |
| mod_arm_himars | HIMARS 火箭炮组 | 援 | enemy_only | manifest | mod_arm_himars | ✅专属 |
| mod_arm_m1a1 | M1A1坦克 | 甲 | - | manifest | vis_player_019 | ✅专属 |
| mod_arm_m1a2sep | M1A2 SEP | 甲 | - | manifest | vis_player_023 | ✅专属 |
| mod_arm_stryker_e | 斯特赖克装甲车·敌方 | 甲 | enemy_only | manifest | vis_player_059 | ✅专属 |
| mod_arty_m270 | M270火箭炮 | 援 | - | manifest | vis_player_021 | ✅专属 |
| mod_arty_mlrs_e | 火箭炮车·敌方 | 援 | enemy_only | manifest | vis_player_060 | ✅专属 |
| mod_arty_rq7 | RQ-7 影子无人机班 | 空 | enemy_only | manifest | mod_arty_rq7 | ✅专属 |
| mod_boss_command | 指挥中枢·Boss | 堡 | enemy_only | manifest | vis_player_064 | ✅专属 |
| mod_challenger2 | 挑战者2坦克 | 甲 | - | override | vis_player_062 | ✅专属 |
| mod_fort_citadel | 要塞核心 | 堡 | - | manifest | vis_player_078 | ✅专属 |
| mod_fort_phalanx | 近防炮系统 | 堡 | - | manifest | vis_player_079 | ✅专属 |
| mod_hummer_m2 | 悍马·M2 | 轻 | - | override | vis_player_058 | ✅专属 |
| mod_hummer_tow | 悍马·陶式 | 轻 | - | override | vis_player_058 | ✅专属 |
| mod_inf_delta_e | 三角洲部队·精锐 | 轻 | enemy_only | manifest | vis_player_061 | ✅专属 |
| mod_inf_marine | 海军陆战队·敌方 | 轻 | enemy_only | manifest | vis_player_057 | ✅专属 |
| mod_inf_patriot | 爱国者 PAC-3 发射车 | 援 | enemy_only | manifest | mod_inf_patriot | ✅专属 |
| mod_inf_scout_drone | 侦察无人机 | 空 | - | manifest | vis_player_022 | ✅专属 |
| mod_inf_technical | 武装皮卡 | 轻 | - | manifest | vis_player_018 | ✅专属 |
| mod_javelin | 标枪导弹兵 | 轻 | - | override | vis_player_046 | ✅专属 |
| mod_leo2a6 | 豹2A6坦克 | 甲 | - | override | vis_player_062 | ✅专属 |
| mod_m1a2 | M1A2艾布拉姆斯 | 甲 | - | override | vis_player_062 | ✅专属 |
| mod_marine | 海军陆战队 | 轻 | - | override | vis_player_057 | ✅专属 |
| mod_ranger | 游骑兵 | 轻 | - | override | vis_player_061 | ✅专属 |
| mod_stinger | 毒刺导弹兵 | 援 | - | override | vis_player_063 | ✅专属 |
| mod_stryker_m2 | 斯特赖克M2 | 甲 | - | override | vis_player_059 | ✅专属 |
| mod_stryker_mgs | 斯特赖克MGS | 甲 | - | override | vis_player_059 | ✅专属 |
| mod_sup_growler | EA-18G 电子战小组 | 援 | enemy_only | manifest | mod_sup_growler | ✅专属 |
| mod_sup_m4_carbine | M4 卡宾特遣班 | 轻 | enemy_only | manifest | mod_sup_m4_carbine | ✅专属 |
| mod_sup_m6 | 自行高炮M6 | 援 | - | manifest | vis_player_020 | ✅专属 |
| mod_t90 | T-90坦克 | 甲 | - | override | vis_player_055 | ✅专属 |
| mod_uh60 | UH-60黑鹰 | 空 | - | override | vis_player_063 | ✅专属 |
| platform_modern_guard_heavy | 现代重型卫戍平台 | 甲 | enemy_only | era_kind回退 | vis_player_019 | ⚠️共享 |
| platform_modern_light | 现代轻型平台 | 轻 | enemy_only | era_kind回退 | vis_player_018 | ⚠️共享 |
| platform_modern_medium | 现代中型平台 | 甲 | enemy_only | era_kind回退 | vis_player_019 | ⚠️共享 |
| platform_modern_radar | 现代雷达平台 | 援 | enemy_only | era_kind回退 | vis_player_020 | ⚠️共享 |
| platform_modern_spg | 现代自行火炮平台 | 援 | enemy_only | era_kind回退 | vis_player_020 | ⚠️共享 |
| platform_modern_stealth | 现代隐形平台 | 轻 | enemy_only | era_kind回退 | vis_player_018 | ⚠️共享 |

### 近未来（era 4）— 49 张

| card_id | display_name | 兵种 | flags | 来源 | 图标 | 类型 |
|---------|-------------|------|-------|------|------|------|
| drop_mega_particle_cannon | 巨型粒子炮 | 甲 | enemy_only | drops反查(fut_boss_nexus) | vis_player_071 | ✅专属 |
| fut_aa_hover | 防空悬浮车 | 援 | - | override | vis_player_060 | ✅专属 |
| fut_air_drone | 无人机群 | 空 | enemy_only | manifest | vis_player_065 | ✅专属 |
| fut_air_heavy_carrier | 重装母舰 | 空 | enemy_only | manifest(foe) | vis_player_033 | ✅专属 |
| fut_air_regen_frame | 再生骨架 | 空 | enemy_only | manifest(foe) | vis_player_034 | ✅专属 |
| fut_arm_colossus_e | 巨神机甲·精锐 | 甲 | enemy_only | manifest | vis_player_070 | ✅专属 |
| fut_arm_heavy_mech | 重装机甲 | 甲 | - | manifest | vis_player_027 | ✅专属 |
| fut_arm_hk07 | HK-07 量产机兵 | 甲 | enemy_only | manifest | fut_arm_hk07 | ✅专属 |
| fut_arm_hovertank | 悬浮坦克 | 甲 | - | manifest | vis_player_025 | ✅专属 |
| fut_arm_hovertank_e | 悬浮坦克·精锐 | 甲 | enemy_only | manifest | vis_player_068 | ✅专属 |
| fut_arm_mech_e | 机甲步兵·敌方 | 甲 | enemy_only | manifest | vis_player_067 | ✅专属 |
| fut_arm_nexus | 虚空领主 | 甲 | - | manifest | vis_player_028 | ✅专属 |
| fut_arm_omega | 全装型机动舱 | 甲 | - | override | vis_player_070 | ✅专属 |
| fut_arm_prism | 光棱坦克 | 甲 | - | manifest | vis_player_026 | ✅专属 |
| fut_arm_sdkfz | Sd.Kfz.251/1 半履带车 | 甲 | enemy_only | manifest | fut_arm_sdkfz | ✅专属 |
| fut_arm_titan_mk2 | 泰坦Mk.II | 甲 | enemy_only | manifest(foe) | vis_player_031 | ✅专属 |
| fut_arty_hel30 | HEL-30 激光炮阵列 | 援 | enemy_only | manifest | fut_arty_hel30 | ✅专属 |
| fut_arty_ssc1 | SS-C-1 岸防导弹组 | 援 | enemy_only | manifest | fut_arty_ssc1 | ✅专属 |
| fut_assault_mech | 突击机甲 | 甲 | - | override | vis_player_067 | ✅专属 |
| fut_attack_drone | 攻击无人机 | 空 | - | override | vis_player_065 | ✅专属 |
| fut_boss_nexus | 风暴核心·Boss | 甲 | enemy_only | manifest | vis_player_071 | ✅专属 |
| fut_colossus | 巨神机甲 | 甲 | - | override | vis_player_070 | ✅专属 |
| fut_cyborg | 机械步兵 | 轻 | - | override | vis_player_066 | ✅专属 |
| fut_fort_ion | 离子炮台 | 堡 | - | manifest | vis_player_080 | ✅专属 |
| fut_fort_shield | 能量护盾发生器 | 堡 | - | manifest | vis_player_081 | ✅专属 |
| fut_heavy_trooper | 重装机兵 | 轻 | - | override | vis_player_066 | ✅专属 |
| fut_howitzer | 悬浮自行火炮 | 援 | - | override | vis_player_060 | ✅专属 |
| fut_inf_c96 | 毛瑟 C96 征召兵排 | 轻 | enemy_only | manifest | fut_inf_c96 | ✅专属 |
| fut_inf_cyborg | 机械步兵·敌方 | 轻 | enemy_only | manifest | vis_player_066 | ✅专属 |
| fut_inf_neural | 神经接口突击兵 | 轻 | enemy_only | manifest | fut_inf_neural | ✅专属 |
| fut_inf_scout_mech | 侦察机甲 | 轻 | - | manifest | vis_player_024 | ✅专属 |
| fut_inf_spectre_e | 幽灵特工·精锐 | 轻 | enemy_only | manifest | vis_player_069 | ✅专属 |
| fut_inf_storm_rider | 暴风骑士 | 轻 | enemy_only | manifest(foe) | vis_player_032 | ✅专属 |
| fut_inf_x9 | X-9 猎杀者渗透组 | 轻 | enemy_only | manifest | fut_inf_x9 | ✅专属 |
| fut_nano_drone | 纳米修复机 | 空 | - | override | vis_player_065 | ✅专属 |
| fut_shield | 力场发生器 | 援 | - | override | vis_player_081 | ✅专属 |
| fut_space_fighter | 空天战斗机 | 空 | - | override | vis_player_065 | ✅专属 |
| fut_spectre | 幽灵特工 | 轻 | - | override | vis_player_069 | ✅专属 |
| fut_stealth_bomber | 隐形轰炸机 | 空 | - | override | vis_player_065 | ✅专属 |
| fut_stormcore | 风暴核心原型 | 援 | - | override | vis_player_071 | ✅专属 |
| fut_sup_bulwark | 壁垒 | 援 | enemy_only | manifest(foe) | vis_player_030 | ✅专属 |
| fut_sup_nrepair | N-Repair 纳米工程车 | 援 | enemy_only | manifest | fut_sup_nrepair | ✅专属 |
| fut_sup_ps9 | PS-9 相位中继站 | 援 | enemy_only | manifest | fut_sup_ps9 | ✅专属 |
| fut_swarm | 蜂群无人机 | 空 | - | override | vis_player_065 | ✅专属 |
| guardian_future_omega | 终焉守护者·近未来 | 甲 | 成就 | era_kind回退 | vis_player_025 | ⚠️共享 |
| platform_future_heavy | 近未来重型平台 | 甲 | enemy_only | era_kind回退 | vis_player_025 | ⚠️共享 |
| platform_future_light | 近未来轻型平台 | 轻 | enemy_only | era_kind回退 | vis_player_024 | ⚠️共享 |
| platform_future_medium | 近未来中型平台 | 甲 | enemy_only | era_kind回退 | vis_player_025 | ⚠️共享 |
| platform_future_radar | 近未来雷达平台 | 援 | enemy_only | era_kind回退 | vis_player_020 | ⚠️共享 |

---

## 五、⚠️ 共享通用图的卡（33张，无专属图）

### A. 平台卡（28张，全部 enemy_only 敌方部署模板）

这些卡只在敌方部署时作为模板使用，`FOE_PLATFORM_CARD_IDS` 存的是源ID（如 `ww1_arm_rolls`）而非 `platform_ww1_medium`，所以 `platform_*` ID 走不到 manifest 映射，回退到 era_kind 通用图。

| card_id | display_name | 时代 | 兵种 | 共享图标 |
|---------|-------------|------|------|---------|
| platform_ww1_light | 一战轻型平台 | WW1 | 轻 | vis_player_004 |
| platform_ww1_medium | 一战中型平台 | WW1 | 甲 | vis_player_001 |
| platform_ww1_fort | 一战炮台平台 | WW1 | 援 | vis_player_003 |
| platform_ww1_radar | 一战雷达平台 | WW1 | 援 | vis_player_003 |
| platform_ww1_medic | 一战医疗平台 | WW1 | 援 | vis_player_003 |
| platform_ww2_light | 二战轻型平台 | WW2 | 轻 | vis_player_009 |
| platform_ww2_medium | 二战中型平台 | WW2 | 甲 | vis_player_007 |
| platform_ww2_heavy | 二战重型平台 | WW2 | 甲 | vis_player_007 |
| platform_ww2_raider | 二战突袭平台 | WW2 | 轻 | vis_player_009 |
| platform_ww2_radar | 二战雷达平台 | WW2 | 援 | vis_player_011 |
| platform_ww2_siege | 二战攻城平台 | WW2 | 援 | vis_player_011 |
| platform_ww2_fortress | 二战要塞平台 | WW2 | 堡 | vis_player_011 |
| platform_cold_light | 冷战轻型平台 | 冷战 | 轻 | vis_player_018 |
| platform_cold_medium | 冷战中型平台 | 冷战 | 甲 | vis_player_014 |
| platform_cold_ifv | 冷战步战车平台 | 冷战 | 空 | vis_player_015 |
| platform_cold_scout | 冷战侦察平台 | 冷战 | 轻 | vis_player_018 |
| platform_cold_radar | 冷战雷达平台 | 冷战 | 援 | vis_player_016 |
| platform_cold_carrier | 冷战运输平台 | 冷战 | 空 | vis_player_015 |
| platform_modern_light | 现代轻型平台 | 现代 | 轻 | vis_player_018 |
| platform_modern_medium | 现代中型平台 | 现代 | 甲 | vis_player_019 |
| platform_modern_radar | 现代雷达平台 | 现代 | 援 | vis_player_020 |
| platform_modern_spg | 现代自行火炮平台 | 现代 | 援 | vis_player_020 |
| platform_modern_stealth | 现代隐形平台 | 现代 | 轻 | vis_player_018 |
| platform_modern_guard_heavy | 现代重型卫戍平台 | 现代 | 甲 | vis_player_019 |
| platform_future_light | 近未来轻型平台 | 近未来 | 轻 | vis_player_024 |
| platform_future_medium | 近未来中型平台 | 近未来 | 甲 | vis_player_025 |
| platform_future_radar | 近未来雷达平台 | 近未来 | 援 | vis_player_020 |
| platform_future_heavy | 近未来重型平台 | 近未来 | 甲 | vis_player_025 |

### B. 守护者成就卡（5张，achievement_exclusive 玩家终极奖励）

玩家击败各时代Boss获得的终极奖励卡，目前没有专属图，与大量普通卡共享通用图。

| card_id | display_name | 时代 | 兵种 | 共享图标 |
|---------|-------------|------|------|---------|
| guardian_ww1_ironclad | 铁壁守护者·一战 | WW1 | 甲 | vis_player_001 |
| guardian_ww2_blitzkrieg | 闪电守护者·二战 | WW2 | 甲 | vis_player_007 |
| guardian_cold_thunder | 雷霆守护者·冷战 | 冷战 | 援 | vis_player_016 |
| guardian_modern_stealth | 幽灵守护者·现代 | 现代 | 空 | vis_player_022 |
| guardian_future_omega | 终焉守护者·近未来 | 近未来 | 甲 | vis_player_025 |

---

## 六、本次新增的 7 张特色掉落卡（全部有专属图）

通过 drops 反查机制自动继承掉落它的敌人的图标：

| card_id | 掉落它的敌人 | 继承图标 |
|---------|-------------|---------|
| drop_smg_mk2 | ww1_inf_storm_e | vis_player_040 |
| drop_phase_lance | ww2_inf_para_e | vis_player_047 |
| drop_railgun | cold_inf_spetsnaz_e | vis_player_054 |
| drop_mega_beam_cannon | mod_boss_command (chance最高0.6) | vis_player_064 |
| drop_thunder_field | mod_inf_delta_e | vis_player_061 |
| drop_overclock_matrix | mod_air_apache_e | vis_player_063 |
| drop_mega_particle_cannon | fut_boss_nexus (chance最高1.0) | vis_player_071 |

---

## 七、统计汇总

| 指标 | 数量 |
|------|------|
| 总卡数 | 223 |
| 缺图（解析失败） | 0 |
| 有专属图标 | 190 |
| 共享通用回退图 | 33（28平台 + 5守护者） |
| 现有图标文件(player) | 110 PNG |
| 现有图标文件(enemy) | 110 PNG |

**图标来源分布**:
- manifest 映射: 109 张
- PLAYER_ICON_OVERRIDE: 74 张
- drops 反查: 7 张（新增 drop_*）
- era_kind 通用回退: 33 张
