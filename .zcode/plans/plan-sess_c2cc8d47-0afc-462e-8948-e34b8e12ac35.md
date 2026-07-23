## 目标

把 20 个驻守相位师从当前的 1-2★（掉率档位"杂兵"，因为 platforms 填了查不到的卡 id 走兜底 100/卡）提升到 **5-7★**（CHAMPION/OVERLORD 档位），并修复 2 个加成链 bug 让数学上可达。

## 改动文件清单（4 个）

1. `data/json/enemy_phase_masters.json` — **核心数据**：给 20 个驻守相位师重配 platforms（4-6 张）+ runes（势力主题显式写死）+ 调整 2 处 phase_instrument
2. `data/enemy_phase_masters_ww2.gd`、`_cold.gd`、`_modern.gd`、`_future.gd`、`_ww1.gd` — **同步静态源**（JSON 优先，但静态 GDScript 是 _load_json_data 的回退源，要保持一致避免单测或 JSON 缺失时回退到弱卡）
3. `data/enemy_stat_resolver.gd` L347-363 — **修 Bug 1**：`apply_phase_master_to_unit_stats` 接入 `master_stats.max_hp`（当前完全空转，只读 attack_power/defense）
4. `data/enemy_phase_masters.gd` L255 — **修 Bug 2**：`_derive_runes` 的 `max_count` 从 `clampi(2+level/10, 2, 4)` 改为 `clampi(2+level/6, 2, 6)`，让符文能填满相位仪 6 槽（虽驻守相位师 JSON 写死了 runes 不走派生，但这条改让其他 10 个非驻守相位师也顺带修复）
5. 新增 `tests/master_garrison_power_smoke.gd` — smoke test：跑 20 个驻守相位师 evaluate()，断言全部 5-7★ + key 数值链路

## 详细改动

### A. 加成链 2 处 bug 修复（代码）

**A1. `enemy_stat_resolver.gd:347-363`** — `apply_phase_master_to_unit_stats` 末尾加 max_hp 乘区：
```gdscript
# 新增：master.stats.max_hp 对单位 HP 的加成（系数 0.0001，master max_hp=3000→×1.3）
if master_stats.has("max_hp"):
    var mhp_m: float = 1.0 + float(master_stats["max_hp"]) * 0.0001
    stats.max_hp *= mhp_m
```
注：系数 0.0001 与现有 master_defense_hp_multiplier（defense×0.0008）量级协调；max_hp 3000→×1.30，max_hp 5000→×1.50。只影响"相位师战产兵/召唤单位"（master_stats 非空才进此分支），普通波次行为零变化（向后兼容）。

**A2. `enemy_phase_masters.gd:255`** — `_derive_runes` 符文数量上限提到 6：
```gdscript
# 原：var max_count: int = clampi(2 + int(level / 10), 2, 4)
var max_count: int = clampi(2 + int(level / 6), 2, 6)
```
Lv10→3/Lv18→5/Lv24→6/Lv30→6，匹配 EnemyLoadoutTiers 的 rune_cap(HIGH=6)。

### B. 20 个驻守相位师重配（数据，JSON 为主、GDScript 同步）

每相位师配 4-6 张**该时代 archetype JSON 里真实存在的卡**（agent 已确认池子只有 37 张），按时代阶梯：

| 时代 | 可用 archetype | 配置规则 |
|---|---|---|
| WW1 | mp18, rifle, mg_nest, mortar, storm_e, rolls_e, boss_av7 | 驻守师配 4 张（含 1-2 张 boss_av7） |
| WW2 | thompson, garand, mg42, panzerschreck_e, para_e, panther_e, boss_kingtiger | 驻守师配 4-5 张（含 boss_kingtiger） |
| COLD | inf_ak, inf_m60, arm_btr_e, air_m113_e, inf_spetsnaz_e, arm_t72_e, boss_mig | 驻守师配 5 张（含 boss_mig 或 arm_t72_e×2） |
| MODERN | inf_marine, air_technical_e, arm_stryker_e, arty_mlrs_e, inf_delta_e, arm_abrams_e, air_apache_e, boss_command | 驻守师配 5-6 张（含 boss_command） |
| FUTURE | air_drone, inf_cyborg, arm_mech_e, arm_hovertank_e, inf_spectre_e, arm_colossus_e, boss_nexus | 驻守师配 6 张（含 boss_nexus + arm_colossus_e） |

**20 个驻守相位师具体配置**（每个含 platforms + runes + phase_instrument + 预期星级）：

| 关卡 | master_id | platforms（卡数）| phase_instrument | runes（势力主题） | 预期星级 |
|---|---|---|---|---|---|
| 10 | 005 钢铁元帅 | [ww1_boss_av7×2, ww1_arm_rolls_e, ww1_inf_storm_e] (4) | pi_steel_02 (5★) | [iron_01, iron_03, defense_07, defense_08] | 5★ 宗师 |
| 15 | 006 炎魔女王 | [ww1_boss_av7, ww1_arm_rolls_e×2, ww1_inf_storm_e] (4) | pi_flame_02 (5★) | [nova_01, nova_02, attack_07, attack_08] | 5★ |
| 20 | 007 雷神之子 | [ww1_boss_av7×2, ww1_arm_rolls_e, ww1_sup_mg_nest] (4) | pi_thunder_02 (5★) | [aether_01, aether_02, attack_06, mobility_04] | 5★ |
| 25 | 008 虚空领主 | [ww2_boss_kingtiger, ww2_arm_panther_e×2, ww2_inf_panzerschreck_e, ww2_inf_para_e] (5) | pi_void_02 (5★) | [void_01, void_03, void_02, attack_07] | 5★ |
| 30 | 009 钢铁军团长 | [ww2_boss_kingtiger×2, ww2_arm_panther_e, ww2_inf_panzerschreck_e, ww2_inf_para_e] (5) | pi_steel_03 (6★) | [iron_01, iron_03, iron_02, defense_08] | 5-6★ |
| 35 | 011 雷皇 | [ww2_boss_kingtiger, ww2_arm_panther_e×2, ww2_sup_mg42, ww2_inf_panzerschreck_e] (5) | pi_thunder_03 (6★) | [aether_01, aether_02, aether_03, attack_08] | 5-6★ |
| 40 | 012 虚空虚主 | [ww2_boss_kingtiger×2, ww2_arm_panther_e, ww2_sup_mg42, ww2_inf_para_e] (5) | pi_void_03 (6★) | [void_01, void_03, void_02, attack_07, special_05] | 6★ |
| 45 | 013 钢铁烈焰 | [cold_arm_t72_e×2, cold_arm_btr_e, cold_air_m113_e, cold_inf_ak] (5) | pi_steelflame_01 (5★) | [iron_01, nova_01, iron_03, nova_02, defense_07] | 5★ |
| 49 | 014 雷霆钢铁 | [cold_arm_t72_e, cold_arm_btr_e, cold_air_m113_e, cold_inf_spetsnaz_e, cold_boss_mig] (5) | pi_steelthunder_01 (6★，升级) | [iron_01, aether_01, iron_03, aether_02, attack_07] | 6★ |
| 50 | 015 虚空烈焰 | [cold_boss_mig, cold_arm_t72_e×2, cold_air_m113_e, cold_inf_spetsnaz_e] (5) | pi_flamevoid_01 (6★，升级) | [void_01, nova_01, void_03, nova_02, attack_07] | 6★ |
| 55 | 016 不朽钢铁 | [cold_boss_mig, cold_arm_t72_e×2, cold_air_m113_e, cold_inf_spetsnaz_e, cold_arm_btr_e] (6) | pi_steel_04 (7★) | [iron_01, iron_03, iron_02, defense_08, attack_07] | 6★ |
| 60 | 018 万雷之主 | [cold_boss_mig×2, cold_arm_t72_e, cold_air_m113_e, cold_inf_spetsnaz_e, cold_arm_btr_e] (6) | pi_thunder_04 (7★) | [aether_01, aether_02, aether_03, attack_08, mobility_05] | 6★ |
| 65 | 019 虚空主宰 | [mod_boss_command, mod_arm_abrams_e×2, mod_air_apache_e, mod_arm_stryker_e, mod_inf_delta_e] (6) | pi_void_04 (7★) | [void_01, void_03, void_02, attack_08, special_05] | 6-7★ |
| 70 | 020 钢铁雷霆 | [mod_boss_command, mod_arm_abrams_e×2, mod_arm_stryker_e, mod_air_apache_e, mod_inf_delta_e] (6) | pi_steelthunder_01 (6★) | [iron_01, aether_01, iron_03, aether_02, attack_08] | 6★ |
| 75 | 022 战争机器 | [mod_boss_command, mod_arm_abrams_e×2, mod_arm_stryker_e, mod_air_apache_e, mod_arty_mlrs_e] (6) | pi_steel_04 (7★) | [iron_01, iron_03, iron_02, defense_08, attack_08] | 6-7★ |
| 80 | 024 风暴使者 | [mod_boss_command×2, mod_air_apache_e, mod_arm_abrams_e, mod_arm_stryker_e, mod_arty_mlrs_e] (6) | pi_thunder_04 (7★) | [aether_01, aether_02, aether_03, attack_08, mobility_05] | 6-7★ |
| 85 | 025 暗影主宰 | [fut_boss_nexus, fut_arm_colossus_e×2, fut_arm_mech_e, fut_inf_spectre_e, fut_air_drone] (6) | pi_void_04 (7★) | [void_01, void_03, void_02, attack_08, special_06] | 7★ |
| 90 | 026 钢铁之神 | [fut_boss_nexus, fut_arm_colossus_e×2, fut_arm_hovertank_e, fut_arm_mech_e, fut_inf_cyborg] (6) | pi_steel_05 (7★) | [iron_01, iron_03, iron_02, defense_08, attack_08] | 7★ |
| 95 | 028 雷神 | [fut_boss_nexus×2, fut_arm_colossus_e, fut_arm_hovertank_e, fut_inf_spectre_e, fut_air_drone] (6) | pi_thunder_05 (7★) | [aether_01, aether_02, aether_03, attack_08, mobility_05] | 7★ |
| 100 | 030 全能奥米伽 | [fut_boss_nexus×2, fut_arm_colossus_e×2, fut_arm_hovertank_e, fut_arm_mech_e] (6) | pi_omega_01 (7★) | [iron_01, void_01, nova_01, aether_01, attack_08, defense_08] | 7★ |

（实际实施时会跑 smoke test 实测每个的精确星级，若个别相位师仍卡在 4★，微调 1-2 张卡换成 boss 卡 / 加 max_hp 系数小调）

### C. 验证（smoke test）

新增 `tests/master_garrison_power_smoke.gd`（SceneTree 模式，仿 `master_power_smoke.gd`）：
- 遍历 20 个驻守相位师，调 `MasterPowerEvaluator.evaluate(master)`
- 断言每个 stars ≥ 5
- 打印每个相位师：platforms / 单卡战力分解 / 总分 / 星级 / 派生 Lv
- 全部 PASS 后 quit(0)，任一 <5★ 则 quit(1)

## 不做的事

- **不改 STAR_TIERS 阈值**（7000/11000/16000 保持）——加成链补强 + 数据补强后可达
- **不改其他 10 个非驻守相位师**的 platforms（只顺带享受 A1/A2 bug 修复）
- **不修 faction→公司 id 映射 bug**（用户选"保持现状"掉率档位）
- **不动玩家侧**相位师（master_player_assembler 链路）
- **不改 phase_master_garrison.gd 映射表**（关卡→master_id 已正确）

## 向后兼容性

- A1（max_hp 接入）：master_stats 非空才生效，普通波次 master_stats 恒空 → 零变化
- A2（max_count 4→6）：相位师没装备 runes 字段时走派生，加了显式 runes 字段的驻守师跳过派生 → 互不影响
- B（JSON platforms/runes）：旧存档不存 platforms（只存关卡进度），重新战斗时读取最新 JSON → 无存档迁移问题
- 卡 id 全部用 archetype JSON 真实存在的 id，`EnemyArchetypes.get_config()` 运行时必命中

## 风险

1. **WW1/WW2 相位师可能勉强卡在 4-5★ 边界**（boss_av7 hp 600 / boss_kingtiger hp 800 偏低）。若 smoke test 实测达不到 5★，预案是把 A1 的 max_hp 系数从 0.0001 抬到 0.00015。
2. **战斗侧 enemy_phase_field_driver 不读 MasterPowerEvaluator**——它直接走自己的产兵加成链。改 JSON 的 platforms 会让战场实际产兵变化（产 6 张 boss 卡可能过强）。**需在实施后实机验证战斗平衡**，必要时在 driver 加"相位师产兵 hp/atk 上限"钳制。
3. **掉率联动**：用户选"保持现状"，但相位师升到 5-7★ 后 `get_tier_by_stars` 会自动把掉率档位提到 CHAMPION/OVERLORD（必掉 3-4 张蓝图、legendary 概率 6-8%）。这是用户期望的"高级相位师掉好东西"，符合设计。

## 实施顺序

1. A1 + A2 代码 bug 修复（先做，让加成链补强）
2. 新增 smoke test 框架（先能跑测试）
3. B 数据改动（JSON 为主，逐个相位师改 + 跑 smoke 验证星级）
4. 静态 GDScript 子文件同步（保持一致性）
5. Godot `--check-only` 语法验证
6. 总结报告 + 文档更新（AGENTS.md 增补本次变更记录）