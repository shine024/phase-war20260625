# Phase War 全表平衡审查报告 — 对照大战略参考数据
> 脚本: docs/balance_reference/check_fulltable.py (v2 时代跨度重校准)
> 数据源: data/unified_card_table.gd + data/enemy_archetypes*.gd
> 日期: 2026-08-25

> **v2 校准说明**：Phase War 时代跨度为一战→近未来（5 时代 ~130 年，进度型卡牌游戏），
> 大战略每部作品仅覆盖窄时代带（单作 10~60 年，无跨代进度需求）。
> 因此跨代总增幅不再按大战略"平曲线"判 WARN，改为审查曲线形状质量。
[CHECK] 01-时代倍率表（battle_card_v3.gd）
  INFO: 表值单调无异常，但 v8.2 简化公式后战斗链已不引用——仅 tests/ 调用（legacy）。实际跨代递进全部烧在 unified_card_table / enemy_archetypes 的 base 属性里
  DATA: damage=[1.00,1.20,1.40,1.65,1.80] hp=[1.00,1.15,1.30,1.50,1.70]（测试断言仍锁这些值）

[CHECK] 02-WW1装甲HP>步兵HP
  PASS: 步兵均值=120 装甲均值=529

[CHECK] 02-WW2装甲HP>步兵HP
  PASS: 步兵均值=202 装甲均值=648

[CHECK] 02-冷战装甲HP>步兵HP
  PASS: 步兵均值=257 装甲均值=537

[CHECK] 02-现代装甲HP>步兵HP
  PASS: 步兵均值=502 装甲均值=988

[CHECK] 02-近未来装甲HP>步兵HP
  PASS: 步兵均值=800 装甲均值=1780

[CHECK] 03-步兵:装甲 HP 比——时代漂移追踪（大战略同期参考 1:2~4）
  WW1: 1:4.42
  WW2: 1:3.20
  冷战: 1:2.09
  现代: 1:1.97
  近未来: 1:2.23
  → 五时代漂移 4.42 → 2.23（-50%）。大战略单作内此比恒定；跨代收窄=兵种克制关系随进度被压缩，步兵相对越打越"肉"
  [设计意图确认 2026-08-25] 近未来段收窄由动力装甲题材引入（重装机兵1200HP/def_a104、
   侦察机甲三武器槽、机械步兵等），侦察机甲/重装机兵本质是"小型机甲"而非传统步兵。
   冷战/现代段(1:2.09/1:1.97)另有口径因素：装甲分类含 IFV/APC(BMD-1 300HP、BTR 320HP)，
   纯坦克口径下比例会更宽。判定降级为 INFO-设计确认。

[CHECK] 04-跨时代递进——每时代步进分析（时代跨度重校准）
  框架：Phase War=5时代进度型卡牌游戏，跨代总增幅是设计需求（不同于大战略单作窄时代带）。
  审查改为：单调性（无倒退）+ 步进平滑度 + 兵种斜率一致性
  口径：median（稳健，免疫 boss/守护者 outlier）+ 纯战斗单位 mean（剔除 boss/guardian/platform/drop）
  轻装 HP(纯战斗): 总增幅 7.25x | 每步 1.80/1.30/2.03/1.54 | 平滑度 45% INFO
  轻装 HP(median): 每步 1.76/1.23/2.14/1.55
  轻装 对甲攻(纯战斗): 总增幅 6.70x | 每步 5.07/1.08/1.44/0.85
  装甲 HP(纯战斗): 总增幅 5.70x | 每步 1.55/1.16/1.88/1.68 | 平滑度 46% INFO
  装甲 HP(median): 每步 1.52/1.19/1.94/1.43
  装甲 对甲攻(纯战斗): 总增幅 6.62x | 每步 1.81/1.04/2.21/1.59
  [参考锚] 大战略跨作隐含曲线（大東亜1930s→VII现代，~60年=2步）：坦克耐久 1.3-2.0x、火力 1.33x、价格 1.75x
  [参考锚] 现实跨度：Mark I(1916,57mm,6mph) → M1A2(120mm,42mph)——真实代差远超任何游戏曲线，游戏值是设计权衡

[CHECK] 05-同级同类HP公差带（>30%标注）
  WW1/轻装/普通 n=9 mean=104 spread=18.3% PASS
  WW1/装甲/老练 n=5 mean=305 spread=19.7% PASS
  WW1/装甲/精英 n=4 mean=311 spread=20.3% PASS
  WW1/支援/普通 n=7 mean=105 spread=45.9% WARN
  WW1/支援/老练 n=7 mean=140 spread=38.5% WARN
  WW2/轻装/普通 n=4 mean=160 spread=12.5% PASS
  WW2/轻装/老练 n=8 mean=233 spread=37.4% WARN
  WW2/轻装/精英 n=3 mean=178 spread=24.1% PASS
  WW2/装甲/精英 n=11 mean=468 spread=53.8% WARN
  WW2/支援/老练 n=7 mean=201 spread=45.7% WARN
  WW2/堡垒/堡垒 n=3 mean=867 spread=21.9% PASS
  冷战/轻装/普通 n=4 mean=196 spread=12.8% PASS
  冷战/轻装/老练 n=6 mean=310 spread=37.5% WARN
  冷战/装甲/老练 n=8 mean=360 spread=44.7% WARN
  冷战/装甲/精英 n=11 mean=666 spread=43.0% WARN
  现代/轻装/普通 n=3 mean=270 spread=11.1% PASS
  现代/轻装/老练 n=5 mean=442 spread=38.2% WARN
  现代/轻装/精英 n=5 mean=700 spread=50.0% WARN
  现代/装甲/精英 n=3 mean=967 spread=31.0% WARN
  现代/装甲/精英头目 n=8 mean=1117 spread=34.3% WARN
  现代/支援/老练 n=4 mean=450 spread=115.7% WARN
  现代/支援/精英 n=3 mean=610 spread=73.8% WARN
  现代/空中/老练 n=3 mean=441 spread=77.8% WARN
  现代/空中/精英 n=4 mean=844 spread=41.5% WARN
  近未来/轻装/精英 n=9 mean=899 spread=55.6% WARN
  近未来/装甲/老练 n=4 mean=758 spread=29.0% PASS
  近未来/装甲/精英头目 n=7 mean=1678 spread=48.9% WARN
  近未来/装甲/终极 n=4 mean=3164 spread=15.8% PASS
  近未来/支援/精英 n=5 mean=835 spread=29.9% PASS
  近未来/空中/老练 n=3 mean=610 spread=8.2% PASS
  近未来/空中/精英 n=4 mean=1156 spread=34.6% WARN

[CHECK] 06-档次HP带（头文件注释为 WW1 基线，跨时代膨胀后注释过时）
[CHECK] 06-档次HP带合规（跨时代视角）
  INFO: 头文件 HP 带按 WW1 基线书写；5 时代膨胀后 143 单位越界属预期——建议把注释改为"每时代×档位"二维表或删除绝对值

[CHECK] 07-曲射兵器射程
  WARN: 武器类型=1且射程≠99的条目（21）——2026-08-25 核实：其中 20/21 为 enemy_only（敌方 3-6 格与敌机 3-5 同构，属"敌方射程受限"系统性设计而非数据错误；唯一我方为守护者(5-6)亦自成体系。判定降级为设计确认，不改数值
  DATA: ww1_arty_mortar, ww2_arty_hummel, cold_arty_bmd1, cold_sup_bmp1_x, mod_arty_mlrs_e, mod_inf_patriot, mod_arm_himars, mod_arty_rq7, fut_boss_nexus, fut_arm_titan_mk2, fut_arty_hel30, fut_arty_ssc1, platform_ww2_heavy, platform_ww2_siege, platform_cold_medium, platform_modern_medium, platform_modern_spg, platform_modern_guard_heavy, platform_future_heavy, guardian_cold_thunder, drop_mega_beam_cannon

[CHECK] 08-步兵对装甲克制硬度（atk_a/def_a，跨代视角）
  WW1: 0.104 PASS
  WW2: 0.359 WARN
  冷战: 0.550 WARN
  现代: 0.295 WARN
  近未来: 0.176 WARN
  → 同时代步兵 AT 武器(火箭筒/导弹)命中坦克造成有效伤害是二战后设计常态；
    大战略"步枪对甲0%"由武器命中表实现，我方由 atk_a 数值差实现——口径不同，0.15 阈值仅作参考

[CHECK] 09-装甲单位atk_a/atk_l专化度
  WW1: 3.94x（大战略~1.1x，我方设计性专化）
  WW2: 4.45x（大战略~1.1x，我方设计性专化）
  冷战: 3.84x（大战略~1.1x，我方设计性专化）
  现代: 4.15x（大战略~1.1x，我方设计性专化）
  近未来: 4.20x（大战略~1.1x，我方设计性专化）

[CHECK] 10-power锚比例
  WW1: base=55  轻装=1 | 装甲=4 | 支援=2 | 堡垒=2
  WW2: base=110  轻装=1 | 装甲=3 | 支援=2 | 堡垒=5
  冷战: base=194  轻装=1 | 装甲=2 | 支援=2 | 空中=2 | 堡垒=2
  现代: base=333  轻装=1 | 装甲=3 | 支援=2 | 空中=3 | 堡垒=2
  近未来: base=446  轻装=1 | 装甲=3 | 支援=1 | 空中=2 | 堡垒=2

[CHECK] 11-武器标签历史口径抽查（v3：21 卡史实口径表，2026-08-25 批量修正后固化）
  ww2_arm_tiger 虎式: label="88mm坦克炮" w_armor="88mm坦克炮" PASS
  ww2_kingtiger 虎王: label="88mm坦克炮" w_armor="88mm坦克炮" PASS
  ww2_t34_76 T-34/76: label="75mm/76mm坦克炮" w_armor="105mm/120mm主炮" PASS
  ww2_t34_85 T-34/85: label="85mm坦克炮" w_armor="85mm坦克炮" PASS
  ww2_is2 IS-2: label="122mm主炮" w_armor="122mm主炮" PASS
  cold_arm_t55 T-55: label="100mm主炮" w_armor="100mm线膛炮" PASS
  cold_t62 T-62: label="115mm滑膛炮" w_armor="115mm滑膛炮" PASS
  cold_t72 T-72: label="125mm滑膛炮" w_armor="125mm滑膛炮" PASS
  cold_m60t M60: label="105mm线膛炮" w_armor="105mm线膛炮" PASS
  cold_m1 M1: label="105mm线膛炮" w_armor="105mm线膛炮" PASS
  cold_leo1 豹1: label="105mm线膛炮" w_armor="105mm线膛炮" PASS
  cold_chieftain 酋长: label="120mm线膛炮" w_armor="120mm线膛炮" PASS
  mod_arm_m1a1 M1A1: label="120mm滑膛炮" w_armor="120mm滑膛炮" PASS
  mod_m1a2 M1A2: label="120mm滑膛炮" w_armor="120mm滑膛炮" PASS
  mod_arm_m1a2sep M1A2SEP: label="120mm滑膛炮" w_armor="120mm滑膛炮" PASS
  mod_t90 T-90: label="125mm滑膛炮" w_armor="125mm滑膛炮" PASS
  mod_leo2a6 豹2A6: label="120mm L55滑膛炮" w_armor="120mm L55滑膛炮" PASS
  mod_challenger2 挑战者2: label="120mm线膛炮" w_armor="120mm线膛炮" PASS
  mod_stryker_mgs 斯特赖克MGS: label="105mm线膛炮" w_armor="105mm线膛炮" PASS
  cold_inf_btr60 BTR-60: label="14.5mm KPVT重机枪" w_armor="14.5mm穿甲弹链" PASS
  cold_sup_m113 M113: label="12.7mm车载机枪" w_armor="12.7mm穿甲弹链" PASS
  cold_inf_bmp1 BMP-1: label="73mm低压滑膛炮" w_armor="9M14反坦克导弹" PASS
  cold_bradley 布雷德利: label="25mm M242链炮" w_armor="TOW反坦克导弹" PASS

[CHECK] 12-攻速参数自洽
  PASS: 全部正常

[CHECK] 13-时代0空军
  INFO: 无（符合大战略WWI基准）

[CHECK] 14-与大战略VII一对一对照（同期同代对比，非跨代）
| Phase War | VII单位 | 我方HP/atk_a | VII价格 |
|---|---|---|---|
| mod_m1a2 | M-1A2 | 1185 / 995 | 400 (4) |
| mod_leo2a6 | 豹2A6 | 1165 / 979 | 500 (8) |
| mod_challenger2 | 挑战者2 | 1283 / 1078 | 400 (4) |
| mod_t90 | T-90 | 1135 / 953 | ? |
| mod_arty_m270 | M270 | 900 / 684 | ? |
| mod_marine | 海陆 | 800 / 91 | ? |

[CHECK] 15-全局统计
  总单位数: 223 | HP: mean=660 med=480 min=82 max=3500

[CHECK] 16-玩家-敌方时代递进对齐（v2 新增：跨代曲线的两端必须同斜率）
  机制：v8.2 后敌我 base 都自带时代递进；敌方再乘档位(1.30/1.75/2.00)+波数。
  若玩家每步增速 > 敌方每步增速 → 后期越打越轻松（反向则后期卡关）
  口径：玩家=全卡 median；敌方=原型 median（每时代仅 5-7 个原型，mean 被单个大单位主导不可靠）
  [HP] 玩家每步: 1.86/1.36/2.13/1.27 | 敌方每步: 1.17/1.43/1.00/1.80
    WW1→WW2: 玩家/敌方步进比 1.59 ⚠失配
    WW2→冷战: 玩家/敌方步进比 0.95 OK
    冷战→现代: 玩家/敌方步进比 2.13 ⚠失配
    现代→近未来: 玩家/敌方步进比 0.71 ⚠失配
  [对甲攻] 玩家每步: 2.89/0.70/1.79/1.32 | 敌方每步: 1.25/1.10/1.45/1.46
    WW1→WW2: 玩家/敌方步进比 2.31 ⚠失配
    WW2→冷战: 玩家/敌方步进比 0.64 ⚠失配
    冷战→现代: 玩家/敌方步进比 1.23 OK
    现代→近未来: 玩家/敌方步进比 0.90 OK
  ⚠ 统计警示：敌方每时代仅 5-7 个原型，median 步进（1.17/1.43/1.00/1.80）本身抖动大，
    失配标记置信度低。结构性观察更可靠：敌方基础 HP 中位数全程仅 ~3x（60→180），
    而玩家卡 ~7x——差额必须由档位(1.30→2.00)+波次(+8%/波)+难度乘区补足。
    若某段关卡配档偏低/偏高，会在该段出现难度陡变——建议在关卡维度做 TTK 实测校准，而非只调 base 表。

[CHECK] 17-空军数据专项（combat_kind=3 全链路）
  总数: 20 | 时代分布: WW1=0 WW2=0 冷战=4 现代=8 近未来=8

  17a. [WARN] WW1/WW2 零空中单位——二战是空权时代（不列颠空战/珍珠港/斯图卡），
      大战略参考：大東亜興亡史收录 18 种日军飞机（隼/疾风/烈风/舰战/舰爆），AD-MD 有德军全空军。
      玩法影响：era 0-1 约 21 个关卡无制空维度，玩家/敌方的对空武器（atk_air 11-30）无回报目标。
      若为 EA 阶段裁剪可接受，1.0 前建议补 WWII 战机卡。

  17b. [WARN] 非空优平台对空>对甲（武器逻辑反常；战斗机不在此列——对空强于对甲是其本职）：
      mod_inf_scout_drone 侦察无人机: atk_air=133 > atk_a=99
      fut_swarm 蜂群无人机: atk_air=256 > atk_a=191
      fut_attack_drone 攻击无人机: atk_air=380 > atk_a=284
      fut_nano_drone 纳米修复机: atk_air=176 > atk_a=131
      fut_air_heavy_carrier 重装母舰: atk_air=448 > atk_a=336
      大战略口径：直升机对固定翼"ほとんど無力"（VII手册），毒刺仅为自卫。
      ✅已修复(2026-08-25 G组)：UH-60 237→90 / AH-64 361→110 / AH-1 332→105 / 隐形轰炸机 399→100 /
        阿帕奇·精锐 361→110(对齐原版)。剩余无人机类(侦察/蜂群/攻击/纳米/重装母舰)保留——
        近未来"点防御激光反导"是题材内设定，且 w_air 标签已一致(D组补齐)。

  17c. [WARN] w_air 空槽但 atk_air>0（UI 显示将缺武器名）：

  17d. [INFO-设计确认 2026-08-25] 空中单位射程分裂——我方全 99，敌方/守护者全 3-5：
      冷战[我] cold_mig21 range=99
      冷战[我] cold_f4 range=99
      冷战[敌] cold_boss_mig range=3
      冷战[敌] platform_cold_carrier range=3
      现代[我] mod_ah64 range=99
      现代[我] mod_ah1 range=99
      现代[我] mod_uh60 range=99
      现代[我] mod_inf_scout_drone range=99
      现代[我] guardian_modern_stealth range=5
      现代[敌] mod_air_apache_e range=4
      现代[敌] drop_overclock_matrix range=4
      现代[敌] mod_sup_growler range=3
      近未来[我] fut_swarm range=99
      近未来[我] fut_attack_drone range=99
      近未来[我] fut_stealth_bomber range=99
      近未来[我] fut_space_fighter range=99
      近未来[我] fut_nano_drone range=99
      近未来[敌] fut_air_drone range=4
      近未来[敌] fut_air_heavy_carrier range=4
      近未来[敌] fut_air_regen_frame range=3
      同名对照：mod_ah64(我)=99 vs mod_air_apache_e(敌)=4。
      判定：敌方射程受限是系统性模式（敌机 3-5/敌曲射 3-6/守护者 5-6 完全同构），保留——
      敌方若获全图射程会破坏防御玩法。

  17e. [INFO] 空战 TTK（互殴口径）：冷战 ≈0.9s（接近互秒，n=4 样本小）/ 现代 ≈2.3s / 近未来 ≈2.0s
      冷战 F-4/Mig-21 HP 238-267 vs 空战 DPS~355——先手方一刀。可考虑提高冷战战机 HP 或压 atk_air_speed。

  17f. [INFO] 空中:装甲 HP 比对照大战略（参考 1:1.5~2）：现代 1:1.22（稍肉）/ 近未来 1:2.06（吻合）

  17g. [INFO] 装甲对空覆盖（车载高机/近防炮）：WW1-冷战 IFV/装甲车 11-30 合理；
      近未来机甲全员 74-141（标配 CIWS）合理；现代段仅斯特赖克(109)独一份，其余 MBT 全 0——覆盖随机，
      若现代 MBT 定位"无高机"则斯特赖克应是特例而非孤例，建议口径统一（全有或全无或按武器系统定义）。

[CHECK] 18-武器三槽与三维攻击对齐（w_light/w_armor/w_air vs atk_l/atk_a/atk_air）
  消费链：unified_card_table → CardResource.weapon_names[0..2] → card_info_panel/backpack_combat_preview
  UI 格式 = 武器名+数值；空槽时显示裸数字（"1350" 而非 "125mm滑膛炮 1350"）。战斗数值不受影响，纯展示退化。
  [WARN] 严重漏填（atk>=100 无标签，UI 裸数字醒目）: 22 处
      ww2_arty_pak40 PaK 40 反坦克炮组: atk_a=214 无 w_armor
      cold_inf_metis 9K111 法特导弹组: atk_a=283 无 w_armor
      fut_nano_drone 纳米修复机: atk_a=131 无 w_armor
      fut_air_drone 无人机群: atk_a=115 无 w_armor
      fut_sup_bulwark 壁垒: atk_a=300 无 w_armor
      fut_air_heavy_carrier 重装母舰: atk_a=336 无 w_armor
      fut_air_regen_frame 再生骨架: atk_a=450 无 w_armor
      fut_arm_hk07 HK-07 量产机兵: atk_a=720 无 w_armor
      fut_arm_sdkfz Sd.Kfz.251/1 半履带车: atk_a=350 无 w_armor
      platform_ww1_medium 一战中型平台: atk_a=278 无 w_armor
      platform_ww1_fort 一战炮台平台: atk_a=150 无 w_armor
      platform_ww2_medium 二战中型平台: atk_a=336 无 w_armor
      platform_ww2_heavy 二战重型平台: atk_a=450 无 w_armor
      platform_ww2_siege 二战攻城平台: atk_a=300 无 w_armor
      platform_ww2_fortress 二战要塞平台: atk_a=350 无 w_armor
      platform_cold_medium 冷战中型平台: atk_a=405 无 w_armor
      platform_cold_ifv 冷战步战车平台: atk_a=160 无 w_armor
      platform_modern_medium 现代中型平台: atk_a=585 无 w_armor
      platform_modern_spg 现代自行火炮平台: atk_a=750 无 w_armor
      platform_modern_guard_heavy 现代重型卫戍平台: atk_a=740 无 w_armor
      platform_future_medium 近未来中型平台: atk_a=765 无 w_armor
      platform_future_heavy 近未来重型平台: atk_a=990 无 w_armor
  [INFO] 轻微缺槽（atk<100，可解释为口径附带伤害）: w_armor 55 处 / w_air 27 处
  修复进度（2026-08-25 批量执行后）：✅F组工事数值锚定 ✅B组二战坦克口径(label+双槽) 
              ✅C组机枪巢错位+穿甲弹链 ✅A组敌方变体抄原版(16) ✅D组近未来w_air ✅E组散装。
              剩余严重项 = platform_* 模板(15) + 少量大攻敌卡；轻微缺槽为口径附带伤害(设计合理)。


## 附录: 各时代各兵种基础数值均值
| Era | Kind | n | base_hp | atk_l | atk_a | def_a |
|-----|------|---|---------|-------|-------|-------|
| WW1 | 轻装 | 13 | 120 | 34 | 15 | 9 |
| WW1 | 装甲 | 11 | 529 | 76 | 299 | 146 |
| WW1 | 支援 | 15 | 148 | 31 | 83 | 13 |
| WW1 | 堡垒 | 2 | 600 | 86 | 290 | 154 |
| WW2 | 轻装 | 15 | 202 | 58 | 64 | 18 |
| WW2 | 装甲 | 15 | 648 | 100 | 446 | 179 |
| WW2 | 支援 | 10 | 229 | 49 | 167 | 23 |
| WW2 | 堡垒 | 3 | 867 | 103 | 277 | 171 |
| 冷战 | 轻装 | 12 | 257 | 74 | 72 | 28 |
| 冷战 | 装甲 | 19 | 537 | 97 | 373 | 131 |
| 冷战 | 支援 | 6 | 656 | 109 | 340 | 174 |
| 冷战 | 空中 | 4 | 564 | 127 | 153 | 23 |
| 冷战 | 堡垒 | 2 | 1164 | 178 | 562 | 321 |
| 现代 | 轻装 | 13 | 502 | 138 | 100 | 49 |
| 现代 | 装甲 | 13 | 988 | 197 | 820 | 340 |
| 现代 | 支援 | 9 | 531 | 118 | 329 | 74 |
| 现代 | 空中 | 8 | 812 | 170 | 257 | 124 |
| 现代 | 堡垒 | 3 | 1733 | 371 | 987 | 458 |
| 近未来 | 轻装 | 12 | 800 | 224 | 94 | 78 |
| 近未来 | 装甲 | 18 | 1780 | 328 | 1376 | 536 |
| 近未来 | 支援 | 10 | 716 | 135 | 406 | 119 |
| 近未来 | 空中 | 8 | 864 | 197 | 267 | 56 |
| 近未来 | 堡垒 | 2 | 2650 | 362 | 1090 | 680 |
