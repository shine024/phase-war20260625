# Phase War 发行执行计划（P0-4 → P2-7）

> 生成：2026-08-23。范围：RELEASE_ROADMAP.md 的 P0-4 至 P2-7（P0-1~3 发行打包三件套与 P3 商店线不在本计划内，另行安排）。
> 组织方式：按**执行批次**重排（非路线图原顺序）——先做会改动大量文件的系统删除，再做依赖系统稳定的测试/平衡/验收，避免同一文件被多批次反复触碰。
> 每批次 = 一次工作会话 + 一个独立 commit，遵循协作协议（先草案后动手）。所有批次共用验证基线：**gdunit 全量 19 个既有失败（memory 清单）为基线，任何批次不得新增失败**。

## 批次总览与依赖

```
批次1 发行卫生（P0-4+P0-5）          ── 无依赖，立即做，S
批次2 旧养成体系退役（P2-7）          ── 大删除，必须先于 4/7/8，M~L
批次3 资产收尾（P2-1残余+P2-6）       ── 依赖批次2（商店/法则图标口径已定），S~M
批次4 假技能处置（P1-5）              ── 依赖批次2（法则相关占位随之消失），M
批次5 存档损坏明示（P1-4）            ── 无依赖，S
批次6 音频+教程（P2-3+P2-4）          ── 教程依赖批次2后的系统终态，S~M
批次7 平衡终审（P1-3）                ── 依赖批次2（删除系统后数值面才定），M
批次8 测试清零（P1-1）                ── 依赖批次2~7全部落定，M
批次9 全流程通关验收（P1-2）           ── 最后，依赖全部，M
──── 并行轨道（无代码依赖，穿插进行）────
轨道A 相位师美术（P2-2）              ── 纯资产+少量接线，M~L
轨道B VFX 收尾（P2-5）               ── 遵循 vfx-tuning 五步铁律，M~L
```

关键排序理由：批次2 删除法则/研究/合成会牵动商店、掉落、背包、存档、教程文案、测试断言等大量文件——**它不先做，后面每个批次都要返工**。测试清零（批次8）放最后，因为前面每个批次都会再改动断言；平衡终审（批次7）同理要在系统面冻结后定稿。

---

## 批次1 · 发行卫生（P0-4 + P0-5）｜S，半天

**目标**：release 构建不再写用户目录调试文件；调试配置死项清零。

改动：
- `managers/performance_metrics_manager.gd`：`_ready` 与每 15s 落盘路径加 `OS.is_debug_build()` 门控（或 GameConfig 开关，但开关必须有真实消费者——P0-5 删的就是死开关，别再造一个）
- `resources/game_config.gd`：删 `enable_debug_logs` / `enable_performance_stats`（零消费者）；`reset_to_defaults()`（L114-131）补 `debug_no_deploy_limits` 重置
- 顺带核对：`debug_no_deploy_limits` 默认 false 保持（`tests/deploy_limits_toggle_smoke.gd` 锁定该默认值，勿破）

验证：`--script` 加载断言两个文件 + main boot headless 300 帧零错误 + gdunit 基线对比。

## 批次2 · 旧养成体系退役（P2-7）｜M~L，2~4 天，本计划最大批次

**目标**：法则卡/法则研究/科研点/合成系统整体退役，符文成为唯一装配养成线。按路线图 P2-7 三范围执行，建议拆成 3 个 commit：

**commit 2a · 范围A 法则卡链路**（商店/掉落/发放/背包/UI/同步六处 + 4 张断链武器蓝图下架）
- 关键文件：`faction_shop.gd`、`drop_manager.gd:362`、`card_drop_grants.gd`、`backpack_data.gd:111`/`backpack_presenter`/`backpack_card_item`/`card_info_panel`/`store_panel`/`instrument_bar_drag` 的 `CardType.LAW` 分支、`phase_instrument_loadout_sync.gd:151/161`
- `DefaultCards.create_law_card_resource` 消费清零后保留函数本体（范围B/C 还要删调用它的 phase_instrument_manager）

**commit 2b · 范围B 蓝槽法则链 + PhaseLawManager 退场**
- `phase_instrument_manager.gd`：`:759` LAW 入槽判定、`:691-733` 开战装配刷新、`:644/:666` `_compact_law_ids_for_kind`、`:1552-1556` 蓝槽被动收容规则
- 迁移两件保留件：starter 符文发放（`phase_law_manager.gd:643` → PhaseInstrumentManager）、`battle_nano_budget`（核对战斗消费方后迁移 BattleManager 或一并退役）
- 删 `phase_law_manager.gd` + autoload + `managers/active_law_effects.gd`（法则战斗态，整文件随之死）；核对 enemy_unit 侧法则减益消费点清理
- 读档路径：红/蓝槽残留法则卡**静默移出槽位**（防 UI 空引用）
- ⚠️ AGENTS 架构表 32→31 autoload、System Dependencies 图、停用清单同步更新

**commit 2c · 范围C 研究链 + 科研点 + 合成删除**
- 科研点：`basic_resources.gd:15/:88-94`、`drop_manager`、`afk_settlement_dialog`、`faction_war_events`、`resource_info_panel`/`buff_fold_card`（资源栏 UI 你已先行移除，跳过）
- 研究链：`phase_law_manager.gd:16/:137-195+` 知识值/研究函数族、starter 法则发放
- 合成：删 `managers/synthesis/` + `data/synthesis_recipes.gd`；`faction_system_manager.gd` 拆 preload(:21)/实例(:165)/初始化(:697,:924-932)/getter(:934)/存档段(:674-676,:686)；`signal_bus.gd:152-154` 双信号随删；核对 `faction_card_generator` 耦合与旧档混编卡可用性
- 存档兼容全部 key 级静默跳过：`research_points`、已研究法则、`synthesis_state`、槽位法则卡

验证：panel_open_smoke 五面板 + main boot + 掉落/商店购买冒烟（含符文正路径）+ gdunit 基线对比（daily_task 等涉及科研点的既有失败用例可能变化——记录差异，归因后更新 memory 清单）。

## 批次3 · 资产收尾（P2-1 残余 + P2-6）｜S~M，1 天

- faction_shop 在售 4 张断链武器蓝图（bp_cold_014/bp_cold_020/bp_modern_011/bp_near_012）——已并入批次2a 顺手下架，此处只复核
- 断链小项：combo_icons 6 张（目录不存在）、pi_r_free_deploy/pi_umbra_01~03 图标（走 AI 图管线生成 or 改指向现有聚合图，二选一执行时定）；`law.png` 与法则图标**不再补**（随批次2退役）
- **PNG 全量备份归档**：`assets/card_icons/` 866 张 + 缩略图树不入 git——打 zip 存项目外/网盘，并写进 AGENTS 美术工作流章节（发行机迁移的硬前提）
- P2-6：`tests/evolution_path_coverage.gd` 纳入 14 张势力专属卡
- 删除过时清单 `assets/card_icons/work_全卡面加工/卡面文件名与显示名_最全表.txt`

验证：复跑 `tests/_tmp_card_icon_dedicated_audit.gd` 确认零 MISSING；进化覆盖测试通过。

## 批次4 · 假技能处置（P1-5）｜M，2~3 天

前置核对：批次2 后部分占位面可能已消失（active_law_effects 已删）。剩余清单逐条定"实装 or 移除展示"：

| 项 | 位置 | 处置方向 |
|---|---|---|
| 召唤类技能占位 | `card_periodic_skill_engine.gd:431` | 实装（接 battle_spawn_system）或从技能池移除召唤类 |
| 敌方技能树空转（v17m 五条） | `enemy_phase_field_driver.gd` 无消费路径 | 实装（AGENTS v17m 已留补全思路四步）或敌方配置移除 special/unit_ability 字段 |
| 声望解锁 TODO | `intel_manual_items.gd:446` | 实装解锁 or 移除入口 |
| 神话卡牌未实现 | `card_collection_manager.gd:28` | 移除稀有度档 or 补 |
| 关键道具 reserved | `save_manager.gd:946` | 保留 reserved（无展示面，无害）可不动 |

原则：每条以"玩家能否看到不生效的东西"为判据。实装项各配冒烟断言。

## 批次5 · 存档损坏明示（P1-4）｜S，半天

- `save_manager.gd` `load_game()`（L1197-1205）主档→备份 fallback 成功时 emit 一个 SignalBus 信号（新增 `save_restored_from_backup(slot)`）
- 标题屏/存档位面板接信号弹 toast："检测到存档损坏，已自动从备份恢复"
- 冒烟：人为损坏主档 JSON → 断言 fallback 成功 + toast 信号发出

## 批次6 · 音频 + 教程（P2-3 + P2-4）｜S~M，1~2 天

- P2-3：补 `bgm_battle_cold.ogg`（冷战 41-60 关战斗 BGM；走既有 AI 音频管线或素材库，风格对齐其余 7 首）——放 `assets/sfx/`，`.import` 齐全后 `BGM_MAP` 已有键无需改代码
- P2-4 教程（在批次2 终态上写）：
  - 修 2 处陈旧文案：强化步骤（面板已删）、"相位仪"步骤实际打开背包符文 Tab → 按新口径改指符文装配
  - 扩展覆盖：至少补"进化、势力声望、商店、世界地图选关、相位场加点"五个中后期系统的引导步骤（数据驱动结构现成，加枚举步骤即可）
  - 教程文案不得再出现"法则/研究/合成"字样

## 批次7 · 平衡终审（P1-3）｜M，2~3 天

- 前置：批次2 后经济面已变（科研点/合成消失）——重跑 `/balance-check` 全量核对单位/MOD 数据
- 重点：时代 DPS 比（unit_era_balance 既有失败项）、近未来伤害倍率定稿、删除系统后的资源产出/消耗再平衡（升级奖励里科研点没了，核对纳米/合金产出曲线是否仍成立）
- 产出：数值定稿表 + 断言新基准值（供批次8 更新测试用）

## 批次8 · 测试清零（P1-1）｜M，1~2 天

- 前置：批次1~7 全部落定，断言不再漂移
- 逐个处置 19 个既有失败（批次2/7 可能已消化一部分）：`git stash` 对比归因 → 断言过期更新、真回归修复
- 批次7 的平衡新基准写入对应测试
- 验收：gdunit 全量绿灯；**更新/删除 memory 的既有失败清单**；`.github/workflows/tests.yml` 从此作为合并门禁

## 批次9 · 全流程通关验收（P1-2）｜M，2~3 天

- 新档→教程→首关→中期→100 关通关→相位师关（5 时代各至少 1 场）
- 长局 soak：连续战斗 30+ 场盯 orphan_nodes/FPS；重点历史崩溃模式（段错误/OOM）与 v20-3d 手写 Tween 手感
- 验收清单存 `docs/`（或并入 CHANGELOG）：发现的问题按 P0/P1 回灌路线图

## 并行轨道A · 相位师美术（P2-2）｜M~L

- 先决策阵容：A 补 30 张用满 / B 收缩到上场 20 位 / C 接受复用（EA 可 C，1.0 建议 A/B）
- boss 待机帧 2/5 → 若选 A/B 顺带补齐 3 组帧动画
- 走 AI 图管线（提示词文档体系现成）；新图落盘后重跑 `tools/generate_card_foot_anchors.py` + 缩略图树生成

## 并行轨道B · VFX 收尾（P2-5）｜M~L

- 遵循 `.agents/skills/vfx-tuning/SKILL.md` 五步铁律：先读 v12/v17 报告取历史正确值
- 已记录的下一杠杆：f01/f02 弹道飞行弹体（2/10）、f05 霰弹 6 发 18° 散射签名
- 单轮单变量 + AI 三次取中位；达标线 6.0/10 即收

---

## 总量预估

| 串行主线（批次1~9） | 约 2~3 周 |
| 并行轨道 A+B | 与主线穿插，不占串行关键路径 |
| 总计（到 M2 可发 EA 状态，另加 P0-1~3 打包与 P3 商店线） | 3~4 周 |

## 全局纪律（每批次必做）

1. 动手前给改动草案（文件清单+关键 diff），批准后执行
2. 每批次独立 commit，message 注明批次号与路线图条目（如 `refactor: 批次2b 蓝槽法则链退役（P2-7范围B）`）
3. 每批次验证三件套：main boot headless 零错误 + 相关冒烟 + gdunit 基线对比（不新增失败）
4. 触碰美术资产立即备份（PNG 不入 git，删=永久）
5. 涉及系统删除的批次，AGENTS.md 停用清单/架构表同 commit 更新
