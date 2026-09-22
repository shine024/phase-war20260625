# Phase War 全维度可玩性测试计划

> **For Hermes:** 按 Task 顺序执行，每个 Task 产出独立证据（日志/截图/报告），发现的问题统一登记到本文件末尾的"发现清单"格式中。执行时使用实机驱动器 `tests/_playtest_driver.gd` + `tests/_playtest_scenarios.gd`（复用 2026-09-20 全矩阵报告的既有管道），测试全程只用**槽 2 专用测试档**，绝不触碰槽 1 用户真档。

**Goal:** 对 Phase War 做一轮全维度可玩性回归——战斗流程、卡牌养成、数值平衡、UI 流程、存档闭环、性能、资产一致性——产出一份带证据的可玩性测试报告。

**Architecture:** 三层测试策略：① gdunit4 无头单测/平衡测（快，CI 同款）；② 实机驱动器场景模拟真实玩家路径（点按、截图、信号等待）；③ 数据一致性脚本审计（资产 vs 数据源）。每层失败即登记发现，不阻塞后续层执行。

**Tech Stack:** Godot 4.5.x headless + gdunit4、自研 playtest driver、Python 审计脚本（tools/ 既有模式）。

**基线参照:** `docs/上线前全功能矩阵测试报告_2026-09-20.md`（16 面板巡视、S1-S9 场景）。本轮重点核对其遗留项是否已修复 + 全量回归。

---

## 前置检查（Task 0）

### Task 0.1: 环境与引擎版本确认
- 确认 Godot 可执行路径与版本：`godot --version`（报告基线为 4.5.1，tests/README 写 4.6——以实际为准，记录差异）
- 确认 gdunit4 插件在位：`project.godot` 已启用 `addons/gdunit4/plugin.cfg`（已确认）
- 确认槽 2 测试档状态：读 `.godot/agent_tools/` 或存档目录，决定复测或清空还原
- 确认 `battle_speed.cfg` user_scale=4.0 未被上次会话遗留污染

### Task 0.2: 建立证据目录
- 新建 `tests/evidence/playability_2026-09-21/`（日期以执行日为准）
- 所有日志、截图、JSON 结果落此目录

---

## 第一层：无头自动化（快筛）

### Task 1.1: gdunit4 全量单测
- 运行：`godot --headless --script tests/gdunit4_runner.gd`
- 覆盖：`tests/unit/combat`（伤害计算/词条缩放/敌方属性）、`tests/unit/battle`（部署指令/大招/战报）、`tests/unit/balance`（经济/进度曲线/时代平衡）、`tests/unit/blueprint`（改造升级）
- 预期：全绿。任何 FAIL 登记为 P1+ 发现
- 证据：完整输出日志存证据目录

### Task 1.2: 数据完整性 smoke 批
- 运行既有 smoke：`data_validation`、`syntax_check`、`unified_table_smoke`、`card_data_reorg_verify` 类（按 tests/ 根下现存脚本逐个执行）
- 重点：卡牌数据表、词条池、符文数据（data/runes.gd）无悬空引用
- 预期：0 错误；悬空引用登记 P2

### Task 1.3: 资产一致性审计
- 按 game-asset-verification 技能流程：交叉核对 PNG 资产 ↔ GDScript 数据源（卡牌图标、符文图标、单位精灵）
- 重点回归：attack_04/attack_05 符文图标（common 目录）、此前批量重生成文件（补充1/ 目录旧命名）
- 产出：缺失/错位资产清单

---

## 第二层：战斗流程（实机驱动器）

### Task 2.1: 正常关卡链回归（对标 S5）
- 场景：标题→槽2→继续→世界地图→进关→自动战斗→胜利→星级→解锁→存档落盘
- 核验点：
  - 结算面板"出击下一关"数字与实际 next level 一致（**重点：核对 2026-09-20 P2 遗留——新档首通显示"第 3 关"错位，mvp_panel.gd `_compute_next_level` 读 `_pending_battle_level` 时序问题是否已修**）
  - 磁盘 save 核验：level_stars / unlocked / current_level
- 证据：逐节点截图 + 存档 JSON diff

### Task 2.2: 教学链回归（对标 S2）
- 场景：全新档→新游戏→开场漫画→卡车→教学→首战
- 核验点：教学步数衔接、跳过教学路径、首战 HUD 关卡标签与内存 current_level 一致（P2 遗留的另一半）
- 证据：截图 + 日志 0 脚本错误

### Task 2.3: 战斗机制纵深抽查
- 部署上限（deploy_alive_limit_smoke / deploy_limits_toggle_smoke）
- 大招释放（test_ultimate_cast 单测 + 实机一次大招 VFX 触发）
- 敌方行为/AI（enemy_behavior_smoke、enemy_targeting_smoke）
- Boss 模式（_tmp_boss_pattern_exercise 模式复用或重写正式版）
- 相位场/能量机制（phase_field_allocation_smoke、phase_field_level_cap_smoke）
- 预期：全 pass；VFX 异常按 godot-vfx-debugging 技能流程定性

### Task 2.4: 长线 soak（可选，视时间）
- 复用 `_batch9_soak` 模式：全链自动推图至卡关/僵局/时代墙
- 核验：无卡死、无内存泄漏（instance_counter_smoke 配合）、无僵局死锁
- 时长预算：≤30 分钟一轮，卡住即停并保留 repro 日志

---

## 第三层：卡牌养成闭环

### Task 3.1: 卡牌成长/强化面板
- 场景：卡仓→选卡→成长面板→强化面板→升级→属性变化核验
- API 注意：统计读取用 `get_modified_stats()`（不是 get_stats()）
- 按 godot-card-system-debugging 技能：instance_id vs card_id 解析、重复显示、强化状态持久化
- 证据：前后属性截图对比

### Task 3.2: 进化/改造链
- 进化条件与覆盖（evolution_condition_smoke、evolution_path_coverage）
- 改造/词条工坊（manufacture_smoke、mod 前缀全量覆盖 mod_prefix_full_coverage）
- 符文系统：装配/卸下/稀有度目录映射/图标显示
- 证据：面板截图 + 数据断言输出

### Task 3.3: 相位师/主将系统
- 技能树加点与通电门控（phase_master_skill_board_smoke、0/83 基线）
- 疲劳/驻军/层级（phase_master_fatigue_smoke、phase_garrison_smoke、phase_master_tier_smoke）
- 联络台 7 势力技能树
- 证据：截图 + 断言日志

---

## 第四层：数值平衡

### Task 4.1: 平衡单测批
- `tests/unit/balance/` 三件套 + power_formula_smoke、combat_power_comparison_smoke
- 核验：战力公式、经济曲线、时代强度梯度单调性

### Task 4.2: 敌方强度横评
- 复用 classic_enemy_strength_audit 模式：各关敌人战力 vs 推荐玩家战力曲线
- 重点：首通难度曲线是否平滑（第 1-5 关抽样）、时代墙前后是否陡变
- 产出：难度曲线表格（关卡 vs 敌方总战力 vs 玩家预期战力）

### Task 4.3: 经济闭环抽查
- 资源产出（战斗缴获/委托/Exclusive 奖励）vs 消耗（制造/改造/升级）速率比
- test_economy_balance + panel_collected_rewards_smoke + exclusive_rewards_smoke
- 预期：正循环无死锁（不可能出现资源不可再生的软锁）

---

## 第五层：UI 流程全巡视

### Task 5.1: 16 面板回归巡视（对标 S4）
- 复用 ui_panel_smoke_driver / playtest driver 面板遍历
- 重点核对 2026-09-20 遗留 P3/P4 是否已修：
  - 委托台页签 `CommissionTab`/`DailyTab` 本地化
  - 词条工坊头部原始实例 ID 显示
  - MVP"本场最佳" archetype ID 未走显示名链
  - 核心血条左缘裁切
  - 面板栈双层标题头
  - 标题屏版本号低对比度
- 证据：每面板截图，命名 `pt_<面板名>.png`

### Task 5.2: 口径一致性专项
- 卡仓"共 N · 卡牌 N 张" vs 已部署卡计入口径
- 图鉴"已收集 3/332" vs 稀有度页签计数
- 结算"本场最佳" vs "战况"面板统计口径（3-4 倍差异遗留）
- 产出：口径差异清单，标注是否为设计内

### Task 5.3: UI 四级标准抽检
- 按 docs/UI设计审计_知乎四级标准_2026-09-20.md 的 R-A~R-D 标准抽查 5 个面板
- 字号≥14px、无截断、无重叠、对比度达标

---

## 第六层：存档与进程闭环

### Task 6.1: 存档读写闭环（对标 S3）
- 切槽→继续→内存态 vs 磁盘逐字段核对
- 正常退出路径落盘（save_game_on_exit）；驱动器 quit() 绕过属工具 artifact，如实标注
- 教程步数衔接核验

### Task 6.2: 异常路径
- 槽位切换中途退出、损坏 JSON 容错（构造坏档注入槽 3）
- 云/本地冲突场景如适用

---

## 第七层：性能采样

### Task 7.1: FPS 与帧时间
- 标题屏 / 世界地图 / ×4 战斗 / 结算四点采样（perf_smoke、battle_performance_monitor）
- 基线：GT 620M 战斗 ~33 FPS（2026-09-20）。低于基线 20% 即登记
- ui_perf_probe 面板打开耗时抽查

---

## 收尾

### Task 8.1: 汇总报告
- 产出 `docs/可玩性测试报告_YYYY-MM-DD.md`，结构对齐 2026-09-20 报告：
  - 场景结论总览表（S 编号 ✅/⚠️/❌）
  - 发现清单（P1 阻塞 / P2 / P3 / P4 / review / 设计内），每条附证据文件路径与代码定位 `file.gd:line`
  - 遗留项核销表（2026-09-20 报告逐条标注 已修/未修/恶化）
- 测试档处理：槽 2 还原或保留复测，明示用户
- 不主动 commit，等用户确认

---

## 发现清单（执行中登记）

| 级别 | 发现 | 证据 | 代码定位 |
|------|------|------|----------|
| （待登记） | | | |

## 风险与开放问题
- 引擎版本差异（4.5.1 vs 4.6 文档口径）先确认再跑，避免 gdunit 兼容性误报
- soak 长线测试耗时不可控，设 30 分钟熔断
- 实机驱动器依赖文本定位按钮，UI 改版可能让场景脚本失效——失败先怀疑定位器而非游戏 bug
- 机器性能基线偏保守（GT 620M），FPS 结论需注明硬件
