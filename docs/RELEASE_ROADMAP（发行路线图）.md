# Phase War 发行路线图（Release Roadmap）

> 生成日期：2026-08-22。基于当日全项目发行就绪度审计（两轮深度审计：工程卫生侧 + 内容侧，含 AGENTS.md / CHANGELOG / 配置 / git 状态核对）。
> 用法：勾选 `[x]` 跟踪进度；每完成一项在 CHANGELOG 记批次。文中 S=小时级 / M=1~3 天 / L=周级。

## 总体判断

玩法闭环与内容量大体就绪：100 关背景逐号全齐、音频 43 条全真（仅缺 1 首冷战 BGM）、进化路径 111/112 覆盖、存档防护四层文件机制完善。但项目**从未做过任何发行工程**：无导出配置、新档内置作弊发放、标题屏裸露开发按钮。距"能打包出门"是短距离（P0 约 1~2 天）；距"能上架"还需一轮质量关卡 + 内容取舍 + 商店物料。

---

## 第 0 步：先决决策（影响后续所有项，先定再动）

| # | 决策 | 选项 | 现状/备注 |
|---|------|------|-----------|
| D1 | 平台/渠道 | PC Steam / itch.io / 移动端 | `project.godot` features 标了 "Mobile"；走国内移动端=版号问题（重）；推荐 PC Steam 为主 |
| D2 | 发行形态 | 抢先体验 / 完整 1.0 / 先发 Demo | 内容量够 1.0；EA 可把 P2 部分项延后 |
| D3 | 语言范围 | 仅中文 / 加英文 | 当前全部硬编码中文、零本地化设施（无 .po）。仅中文上 Steam 可行；英文版=65+ UI 面板文本外化，独立工程（M~L） |

---

## P0 发行阻断（不做就不能出门；合计 S~M，约 1~2 天）

- [ ] **P0-1 移除新档作弊发放**（S）
  - `managers/save_manager.gd` `_enqueue_starter_backpack_cards()`（L866-924）：5 种资源各 100,000、相位师 +100 技能点、开局全送全部改造+进化蓝图。
  - 三处注释自认"⚠️ 测试模式…正式上线前需改回"，正式起步量注释（nano 1500/alloy 800 等）就在旁边。
  - 验收：新建档资源/技能点/蓝图数与正式注释一致；`tests/` 相关断言更新。
- [ ] **P0-2 摘除标题屏开发按钮**（S）
  - `scenes/title_screen.tscn` L185-207 两个可见按钮："🔧 战斗效果检查"、"⚔ 3v3 群战演练"，直达 `scenes/tools/combat_check.tscn` / `combat_arena_3v3.tscn`。
  - 方案：`OS.is_debug_build()` 门控或直接删。
- [ ] **P0-3 从零建导出配置**（当前**无 export_presets.cfg**）（M）
  - 排除清单：`docs/`（280MB！含 vfx_realism_shots 66M、enemy_fire_icons 55M）、`addons/`（agent_tools/gdunit4/godot-mcp 共 3.9M）、`tests/`（1.1M）、`tools/`（1.2M Python 脚本）、`skill_tree_designs/`——默认导出会全部打进包。
  - `config/name`：`phase-war` → 显示名（如 "Phase War 相位战争"）；补 `config/version`（现在没有版本号设置）。
  - Windows 图标（现仅 icon.svg，需 .ico/.png 多尺寸）。
  - 注：`_MCPGameBridge` autoload 有 `OS.is_debug_build()` 守卫（`addons/agent_tools/runtime/game_bridge.gd` L32-35），release 包零开销，不急删；但建议导出模板用 release 而非 debug。
- [x] **P0-4 release 门控性能采集**（S）✅ 2026-08-23 批次1（4af80b6）
- [x] **P0-5 清理死调试配置 + 修 reset 漏项**（S）✅ 2026-08-23 批次1（4af80b6）

---

## P1 质量关卡（1~2 周量级）

- [x] **P1-1 清零 19 个既有测试失败**（M）✅ 2026-08-23 批次8（676b310）：145 例 0 失败；tests.yml 自此为有效门禁；附带修复 USE_PHASE_LAWS 死任务 + gitignore 盲区 7 套件收编
- [x] **P1-2 全流程实机通关测试**（M）✅ 自动化部分 2026-08-24 批次9（1bebdd4）：soak L1-100 全覆盖 113 战/41 PM 战/零崩溃（清单 docs/RELEASE_ACCEPTANCE_BATCH9.md）。**人工 B 部分待实测**（教程/中期手感/PM 关/存档回环）
- [x] **P1-3 平衡终审**（M）✅ 2026-08-23 批次7（9466f3d）：定稿表 docs/BALANCE_FINAL_2026-08-23.md
- [x] **P1-4 存档损坏明示 UX**（S）✅ 2026-08-23 批次5（a4e2f1e）
- [x] **P1-5 "看得到但不生效"机制处置**（M）✅ 2026-08-23 批次4（018e655）：召唤死链/敌方技能空转/声望解锁/收集统计全部结案，关键道具 reserved 保留
  - 召唤类技能占位：`managers/battle/card_periodic_skill_engine.gd:431` "P1 占位：实际召唤需 battle_spawn_system 支持"。
  - 敌方技能树空转（v17m 立案，CHANGELOG 有完整清单）：敌方相位师 special/光环/stacking/unit_ability/unit_mechanism 数据存在但敌方侧永不消费。
  - 原则：不能带"假技能"上架——每条要么实装，要么从敌方配置与 UI 展示面移除。
  - 顺手项（非阻断，列入跟踪）：`data/intel_manual_items.gd:446` 声望解锁 TODO、`managers/active_law_effects.gd:89` 未实现效果类型、神话卡牌未实现（`card_collection_manager.gd:28`）、关键道具 reserved（`save_manager.gd:946`）。

---

## P2 内容补完（按 D2 发行形态取舍；EA 可延后）

- [x] **P2-1 卡面图实况** ✅ 2026-08-23 批次3 收口（6150ace）：断链图标清零（combo_icons 6 张死字段删除、相位仪 5 张补齐）、美术全量备份 zip 已建、卡面审计 294 张零 MISSING。原"192 张缺图"说法作废（2026-08-23 两轮运行时审计定稿）
  - **审计方法**：`tests/_tmp_card_icon_dedicated_audit.gd`（headless 可复跑）走 `UiAssetLoader.card_icon_path_for` 真实七级解析链。
  - **结论：全量 319 卡（玩家/势力 131 + 缴获 109 + 法则 25 + 敌蓝图 54）零破图**。玩家卡 131 = 专属 by-id 17 + manifest 38 + override 精选 76；缴获卡 109/109 全走 manifest 映射到真实图（含 2026-08 补的 38 张 enemy/ by-id 专属图——已验证全部生效）。
  - 旧"192 无 PNG"来源：`work_全卡面加工/卡面文件名与显示名_最全表.txt`（05-22 清单）按逻辑 id 同名文件核对，运行时不按那些文件名取图。**该 txt 已过时，勿再引用**。
  - **剩余事项（均非美术缺口，是系统清理决策）**：
    1. **法则卡链路清理**——已确认方向：**符文全面取代法则**（2026-08-23），展开为独立任务 **P2-7**；25 张法则卡统一 `icon_law.svg` 的"图标缺口"随该批次关闭，不再补图。
    2. **敌蓝图 id 残留**：bp_* 平台蓝图 54 张走同时代共享图展示，但蓝图体系已删、无正常获取途径；**faction_shop 仍在售 4 张武器蓝图 id（bp_cold_014/bp_cold_020/bp_modern_011/bp_near_012）且不在 EnemyBlueprints 缓存内**——购买发放走 `card_drop_grants.gd:57` 判 `DefaultCards.get_card_by_id(id)==null` → :63 静默跳过，**疑似"付款后卡不到账"**。处置：下架这 4 条或接通到缴获卡体系（可与 P2-7 同批顺手处理，同在 faction_shop）。
    3. AGENTS.md 已知断链小项（与本审计无关，仍待补）：combo_icons 6 张、`law.png`（若 P2-7 全退役则此图不再需要）、相位仪图标 4 张（pi_r_free_deploy、pi_umbra_01~03）。
  - ⚠️ PNG 不入 git（项目政策），已有 866 张图需发布前做一次全量备份归档（否则换机/发布机丢失）。
- [ ] **P2-2 相位师（boss）形象**（M~L，或降级处理）——**轨道A 未启动，唯一待决策：阵容 A 补 30 张 / B 收缩 20 位 / C 接受复用（EA 可 C）**
  - 30 位 master（`data/enemy_phase_masters_*.gd` 5 文件×6 位）**零专属立绘/图标**——战场复用时代原型贴图+势力染色，世界地图仅 tooltip 名字。
  - 驻守映射 `data/phase_master_garrison.gd` 仅 20 关→20 位，**10 位从未上场**。
  - boss 待机帧动画仅 2/5 有帧组（cold_boss_mig、fut_boss_nexus），其余程序化摇摆兜底。
  - 选项：A 补 30 张立绘+用满；B 收缩阵容至上场的 20 位；C 接受复用（EA 可接受）。
- [x] **P2-3 补 `bgm_battle_cold.ogg`**（S）✅ 2026-08-23 批次6（a48bf48）：WW2 曲变体过渡版，正式曲走 P3-5 采购线替换
- [x] **P2-4 教程扩展与文案修正**（M）✅ 2026-08-23 批次6（a48bf48）：8 步→13 步重制
  - 现 8 步只覆盖"打完第一关"最小闭环；中后期 12+ 系统（进化/势力/商店/任务/情报/法则/加点/成就）零引导。
  - 陈旧文案 2 处：强化步骤仍写"Lv1-10 消耗纳米材料"（强化面板 v8.x 已删，main.gd 已重定向到成长中枢）；"相位仪"步骤实际打开背包符文 Tab。
- [ ] **P2-5 VFX 真实度迭代收尾**（M~L，打磨项非阻断）——**轨道B 未启动**
  - 自评 4.16/10 → 目标 6.0/10。"下一杠杆"已记录于 CHANGELOG v19/VFX 报告：f01/f02 弹道飞行弹体、f05 霰弹 6 发 18° 散射。铁律见 `.agents/skills/vfx-tuning/SKILL.md`。
- [x] **P2-6 势力专属卡进化路径纳入覆盖测试**（S）✅ 2026-08-23 批次3（6150ace）：覆盖 112→126 卡
- [x] **P2-7 法则→符文替代 + 研究/科研点退役清理批次**（M~L）✅ 2026-08-23 批次2a/2b/2c（8ecefc4/db3174f/63177af）：三范围整体收官，autoload 32→31
  - **范围 A · 法则卡获取/展示链路移除**：
    - `faction_shop.gd`：默认库存与在售条目中的法则卡下架（steel_phase_armor/steel_quick_repair/steel_bastion_wall/flame_heat_overload/thunder_emp_storm 等）；:313 法则卡购买分支移除；顺手处置在售的 4 张断链武器蓝图 id（见 P2-1 事项 2）
    - `drop_manager.gd:362` `_add_law_card`：战斗掉落的法则卡路径移除（含掉落表 law 类型条目）
    - `card_drop_grants.gd` `grant_law_cards_to_backpack`：移除（调用方随之清理）
    - `backpack_data.gd:111`、backpack_presenter / backpack_card_item / card_info_panel / store_panel / instrument_bar_drag 的 `CardType.LAW` 分支收敛
    - `phase_instrument_loadout_sync.gd:151/161`、`phase_instrument_manager.gd:717/727`：法则模板创建/同步链路移除
    - `DefaultCards.create_law_card_resource` 与 `PhaseLaws.get_all_ids` 的卡牌侧消费清零后，评估是否保留数据定义（法则研究侧可能仍用，见范围 B）
  - **范围 B · 蓝槽法则链退役**（2026-08-23 确认设计口径：**符文装备于相位仪蓝槽，取代法则**）：
    - 退役 `phase_instrument_manager.gd` 蓝槽法则链：`:759` LAW 卡入红/蓝槽判定、`:691-733` 开战前以红/蓝槽法则卡刷新 PhaseLawManager 装配、`:644/:666` `_compact_law_ids_for_kind`
    - 符文沿用 v6.2 既有 `rune` 槽位机制（`:1578` 起 `_rune_slots`）；执行时核对 UI 槽位呈现与"符文在蓝槽"口径一致——底部仪器栏/装配面板若仍渲染法则蓝槽行，收敛为符文行（消除"符文槽与蓝槽双轨并存"的分裂）
    - PhaseLawManager 退场路径：装配链（本范围）+ 研究链（范围 C）都退役后，仅剩两件迁移——starter 符文发放（`:643`，迁至 PhaseInstrumentManager）与 `battle_nano_budget`（`:30/:447`，核对战斗消费方后迁移至 BattleManager 或一并退役）；迁移完成删管理器与 autoload，AGENTS 架构表 32→31，enemy_unit 侧法则减益消费点同步清理
  - **范围 C · 研究与科研点退役**（2026-08-23 确认：设计上已无研究系统；资源栏 UI 已先行移除科研点显示——`resource_bar.gd` 工作树已改）：
    - 货币链路移除：`data/basic_resources.gd` `ID_RESEARCH_POINTS`（:15）与升级奖励发放（:88-94）、`drop_manager` 掉落、`afk_settlement_dialog` 挂机结算、`faction_war_events` 事件奖励、`resource_info_panel`/`buff_fold_card` 展示
    - **合成系统一并删除**（2026-08-23 确认）——它正是科研点唯一剩余 sink，整体删除后科研点货币链干净退场，无需改价。删除面：
      - 文件：`managers/synthesis/`（synthesis_manager.gd）+ `data/synthesis_recipes.gd`
      - `faction_system_manager.gd`：preload(:21)/实例字段(:165)/初始化(:697, :924-932)/getter(:934)/存档段(:674-676, :686 `synthesis_state` key)
      - `signal_bus.gd:152-154` 合成双信号（synthesis_completed/failed）随删；`backpack_data.gd` 的合成字样执行时核对（疑为注释）
      - **UI 零调用方**（2026-08-23 核对：scenes/ 无任何合成面板/入口——系统本就是无界面僵尸），删除无用户可见影响
      - 执行时核对：混编卡生成链（faction_card_generator）与 synthesis_manager 的耦合度，确保旧档已有混编卡实例可用性不受影响
      - 存档兼容：势力存档段 `synthesis_state` key 静默跳过（key 级先例沿用）
    - PhaseLawManager 研究链删除：知识值上限（:16）、`get_law_research_requirements`/`can_research_law`/`research_law`（:137-195+）、开局 starter 法则发放（:631-643 的法则部分；starter 符文发放保留，见范围 B 退场路径）
    - 存档兼容：旧档 `research_points` 资源值与已研究法则 key 静默忽略（key 级先例沿用）
  - **存档兼容**：旧档背包中的法则卡按项目惯例静默跳过（先例：eom/characters/challenge_records 的 key 级忽略）；**已装备在红/蓝槽的法则卡读档时静默移出槽位**（避免退役后残留在 slot 数组里被 UI 渲染成空引用）；是否对拥有法则卡的旧档折算补偿（如转符文）执行时定
  - **验证**：panel_open_smoke 五面板 + main boot headless + 掉落/商店购买冒烟（含买符文正路径）+ gdunit 全量与既有基线对比（19 失败清单外不得新增）
  - **文档**：AGENTS.md 停用清单补条目 + CHANGELOG 记批次；`work_全卡面加工/卡面文件名与显示名_最全表.txt` 过时清单顺带删除或标记废弃
- [ ] **P2-8 相位师基地战出口机制**（S~M；2026-08-24 批次9 回灌）
  - soak 实测：弱势方（打不动也打不死）可令 PM 基地战无限僵持（bot 视角 20+ 游戏分钟无结算）。真实玩家可重开规避，但缺体面出口。
  - 方案候选：战斗内"撤退"按钮（判负保进度）；或 N 游戏分钟无有效伤害判平/判负。
- [ ] **P2-9 击杀掉真卡通道复活**（M；2026-08-24 批次9 回灌，经济面需评估）
  - bp_* 蓝图掉落已随体系退役清零（批次9 F1）。原"敌人作为装备来源"设计可复活为真卡直掉（先例：ww2_panther/ww2_kingtiger/ww1_saint），但掉率/经济影响需重审计（批次7 经济审计基于无此通道的现状）。
- [ ] **P2-10 合金/晶体资源处置**（S~M；2026-08-23 批次7 决议：EA 保持现状 + 记录）
  - 合成+蓝图制造删除后两资源零消耗方、纯展示。1.0 前接消耗（如改造升级/商店定价）或退役。
- [ ] **P2-11 L43+ 难度曲线人工核验**（S；2026-08-24 批次9 观察）
  - soak 中无强化账号在冷战后期（L43+）遭遇秒败级首波。真实玩家有商店/强化/满 4 卡位缓冲，但断崖体感需实测（挂 P1-2 人工 B 部分一起做）。
- [ ] **P2-12 低频 Lambda capture 残留定位**（S；工程尾巴）
  - ~1/25 场战斗一次 "Lambda capture at index 1 was freed"（良性有守卫）。attack_pose 已修一例（批次9 F4），余一处无堆栈未定位。

---

## P3 发行工程与商店（上架前 1~2 周）

- [ ] **P3-1 版本号体系 + 分支整理**（S）
  - `feat/v6.14-system-integration` 领先 main **79 提交**未合并（main 零领先，完全过时）→ 回并 main。
  - 对外版本统一（CHANGELOG 内部 v6/v9/v17/v20 混用，对外收敛为 0.x → 1.0）。
- [ ] **P3-2 Steam Direct 流程**（若 D1=Steam；M，含等待审核）
  - $100/APP 注册 → 商店页创建 → 内容调查问卷/年龄分级。
  - **AI 生成内容披露（必填）**：美术与音乐大量 AI 生成，如实勾选。
  - 隐私政策 URL：游戏零网络调用/零遥客观感（无 HTTPRequest/OS.execute），页面可极简。
  - 构建上传：steamcmd + depot 配置（Windows x64 先行）。
- [ ] **P3-3 Steamworks 集成（可选增强）**（M）
  - 游戏内成就系统已有 → 接 Steam 成就需 GodotSteam 扩展。
  - Steam Cloud：存档是小 JSON（每槽 4 文件），勾选路径 `user://` 即用。
- [ ] **P3-4 商店物料**（M，可与 P2 并行）
  - 胶囊图（主/小/竖版等 6 种尺寸）、截图 ≥5（1280x720）、预告片 30s~1min、简短/详细描述（中）。
- [ ] **P3-5 第三方许可留档**（S）
  - 已妥：代码 MIT（LICENSE）、字体 OFL（Rajdhani）+ `assets/fonts/LICENSE`、addons 各带 LICENSE。
  - 待办：43 SFX + 7 BGM 来源凭证（AI 生成记录或采购许可）留档，供披露与争议自查。
- [ ] **P3-6 手柄 / Steam Deck 核对**（S~M，未审计）
  - 若上 Steam：至少核对键位提示；Deck 兼容（gl_compatibility 对 Deck 友好）。当前无手柄输入映射（input_map 仅键鼠）则标注"仅键鼠"。
- [ ] **P3-7 CI 门禁转正**（S）
  - `.github/workflows/tests.yml` 已存在；P1-1 清零后将 gdunit 全量设为合并/发布门禁（`tests/gdunit4_runner.gd` 已核验可跑，AGENTS 相关旧说法过时）。

---

## 里程碑建议

| 里程碑 | 内容 | 预估 |
|--------|------|------|
| **M1 能打包** | P0 全部（1~5）+ 导出冒烟（打包→裸机装→新档开局打 3 关） | ~2 天 |
| **M2 能发 EA** | M1 + P1-1/2/4/5 + P2-3 + P2-7 范围A（法则卡下架，商店不能卖不该存在的卡）+ P2-1 小缺口取舍 + P3-1/2/4/5 最小集 | 2~3 周 |
| **M3 完整 1.0** | M2 + P1-3 终审 + P2 全部 + P3-3/6 | 视 P2 取舍 |

## 证据来源（2026-08-22 审计；P2-1 于 2026-08-23 复核修正）

- 工程侧：save_manager.gd / game_config.gd / title_screen.tscn / performance_metrics_manager.gd / settings_panel.gd / object_pool.gd / project.godot 逐处核对；print 卫生（游戏代码活跃 print ~24 处，战斗路径无逐帧输出，release 门控到位）。
- 内容侧：audio_manager.gd 引用 vs 磁盘（SFX 36/36、BGM 7/8）、`tests/evolution_path_coverage.gd`（111/112）、TODO 全项目 grep（真 TODO 仅 10 处）、卡面最全表逐条核磁盘（192 缺）、`assets/backgrounds/` bg_level_01~100 脚本核对无缺口、tutorial_progression_manager.gd + main.gd 接线核对。
- 版本/分支：CHANGELOG.md 2659 行、git log main..HEAD=79、无 export_presets.cfg、无 .po、LICENSE=MIT。
