# 敌人原型基底属性表（中文列）

数据源：data/json/enemy_archetypes.json。表中为**基底**数值；进战斗后由 EnemyStatResolver 叠波次等加成。

| 原型ID | 显示名 | 生命 | 移速 | 攻击 | 射程 | 攻击间隔 | 武器类型 | 时代 | 蜂群 | 标签 | 掉落 |
|--------|--------|-----:|-----:|-----:|-----:|---------:|---------:|-----:|:----:|------|------|
| boss_cold_mig | 米格-29 | 450.0 | -150.0 | 55.0 | 210.0 | 0.8 | 9 | 2 | False | boss,aircraft,fast | mega_beam_cannon 40% |
| boss_future_nexus | 风暴核心 | 900.0 | -30.0 | 90.0 | 300.0 | 0.9 | 10 | 4 | False | boss,ultimate | mega_particle_cannon 100% |
| boss_modern_command | 指挥中枢 | 700.0 | 0.0 | 70.0 | 220.0 | 1.2 | 2 | 3 | False | boss,support | mega_beam_cannon 60% |
| boss_ww1_av7 | 圣沙蒙坦克 | 300.0 | -30.0 | 25.0 | 150.0 | 1.5 | 3 | 0 | False | boss,tank,armored | titan_mk2 100% |
| boss_ww2_kingtiger | 虎王坦克 | 400.0 | -30.0 | 40.0 | 160.0 | 1.2 | 3 | 1 | False | boss,tank,armored | heavy_carrier 100% |
| elite_cold_spetsnaz | 特种部队 | 90.0 | -120.0 | 20.0 | 220.0 | 1.25 | 6 | 2 | False | elite,infantry,fast | railgun 30% |
| elite_cold_t72 | T-72坦克 | 250.0 | -60.0 | 40.0 | 160.0 | 0.8 | 3 | 2 | False | elite,tank,armored | regen_frame 30% |
| elite_future_colossus | 巨神机甲 | 400.0 | -60.0 | 55.0 | 250.0 | 1.0 | 8 | 4 | False | elite,tank,armored | mega_particle_cannon 50% |
| elite_future_spectre | 幽灵特工 | 120.0 | -140.0 | 35.0 | 210.0 | 0.4 | 8 | 4 | False | elite,infantry,fast,stealth | mega_beam_cannon 40% |
| elite_modern_abrams | M1A2坦克 | 300.0 | -60.0 | 45.0 | 200.0 | 0.8 | 3 | 3 | False | elite,tank,armored | abrams_mk2 40% |
| elite_modern_apache | 阿帕奇直升机 | 220.0 | -120.0 | 38.0 | 250.0 | 0.6 | 9 | 3 | False | elite,aircraft,fast | overclock_matrix 35% |
| elite_modern_delta | 三角洲部队 | 100.0 | -130.0 | 24.0 | 150.0 | 0.29 | 1 | 3 | False | elite,infantry,fast | thunder_field 30% |
| elite_ww1_armored | 装甲车 | 120.0 | -60.0 | 15.0 | 120.0 | 0.33 | 2 | 0 | False | elite,vehicle,armored | bulwark 20% |
| elite_ww1_storm | 暴风突击队 | 70.0 | -100.0 | 12.0 | 80.0 | 0.25 | 0 | 0 | False | elite,infantry,fast | smg_mk2 20% |
| elite_ww2_panther | 黑豹坦克 | 200.0 | -50.0 | 35.0 | 150.0 | 1.0 | 3 | 1 | False | elite,tank,armored | storm_rider 25% |
| elite_ww2_paratrooper | 伞兵精英 | 80.0 | -110.0 | 16.0 | 90.0 | 0.22 | 0 | 1 | False | elite,infantry,fast | phase_lance 25% |
| enemy_cold_ak | 苏军步兵 | 60.0 | -90.0 | 14.0 | 140.0 | 0.33 | 1 | 2 | True | infantry,frontline | - |
| enemy_cold_btr | BTR装甲车 | 120.0 | -80.0 | 18.0 | 130.0 | 0.3 | 2 | 2 | False | vehicle,armored | - |
| enemy_cold_m113 | M113装甲车 | 110.0 | -70.0 | 12.0 | 120.0 | 0.35 | 2 | 2 | False | vehicle,support | - |
| enemy_cold_m60 | 美军步兵 | 65.0 | -90.0 | 15.0 | 150.0 | 0.25 | 2 | 2 | True | infantry,frontline | - |
| enemy_future_cyborg | 机械步兵 | 100.0 | -100.0 | 22.0 | 160.0 | 0.25 | 8 | 4 | True | infantry,frontline | - |
| enemy_future_drone | 无人机群 | 40.0 | -150.0 | 12.0 | 180.0 | 0.4 | 8 | 4 | True | aircraft,fast | - |
| enemy_future_hovertank | 悬浮坦克 | 250.0 | -110.0 | 40.0 | 250.0 | 0.5 | 8 | 4 | False | vehicle,armored,fast | - |
| enemy_future_mech | 机甲步兵 | 180.0 | -80.0 | 30.0 | 150.0 | 0.67 | 8 | 4 | False | vehicle,armored | - |
| enemy_modern_marine | 海军陆战队 | 70.0 | -100.0 | 16.0 | 150.0 | 0.29 | 1 | 3 | True | infantry,frontline | - |
| enemy_modern_mlrs | 火箭炮车 | 100.0 | -50.0 | 35.0 | 250.0 | 2.0 | 3 | 3 | False | artillery,backline | - |
| enemy_modern_stryker | 斯特赖克装甲车 | 150.0 | -80.0 | 22.0 | 150.0 | 0.35 | 2 | 3 | False | vehicle,armored | - |
| enemy_modern_technical | 皮卡武装 | 90.0 | -120.0 | 18.0 | 130.0 | 0.3 | 2 | 3 | False | vehicle,fast | - |
| enemy_ww1_infantry_basic | 步兵班·MP18 | 40.0 | -80.0 | 8.0 | 80.0 | 0.25 | 0 | 0 | True | infantry,frontline | - |
| enemy_ww1_infantry_rifle | 步兵班·步枪 | 45.0 | -70.0 | 12.0 | 150.0 | 0.67 | 1 | 0 | True | infantry,backline | - |
| enemy_ww1_mg_nest | 机枪巢 | 80.0 | 0.0 | 10.0 | 120.0 | 0.33 | 2 | 0 | False | turret,sustained | - |
| enemy_ww1_mortar | 迫击炮组 | 60.0 | -40.0 | 20.0 | 180.0 | 2.0 | 3 | 0 | False | artillery,backline | - |
| enemy_ww2_infantry | 步兵班·汤普森 | 50.0 | -90.0 | 10.0 | 85.0 | 0.22 | 0 | 1 | True | infantry,frontline | - |
| enemy_ww2_mg42 | MG42机枪组 | 90.0 | -50.0 | 14.0 | 130.0 | 0.2 | 2 | 1 | False | turret,sustained | - |
| enemy_ww2_panzerschreck | 反坦克组 | 70.0 | -60.0 | 30.0 | 140.0 | 2.5 | 3 | 1 | False | infantry,antitank | - |
| enemy_ww2_rifleman | 步枪班·加兰德 | 55.0 | -70.0 | 15.0 | 160.0 | 0.5 | 1 | 1 | True | infantry,backline | - |

**武器类型**：GameConstants.WeaponType 整型。 **时代**：0=一战 … 4=近未来。