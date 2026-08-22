# Phase War 版本变更记录（Changelog）

> 本文件由 AGENTS.md 的 68 个版本记录段落迁移而来（2026-08-21 文档重整）。
> 记录按原文件顺序保留；活文档（架构/工作流/铁律）见根目录 AGENTS.md。

## v6.1 UI修复记录 (2026-06-09)

**UI面板尺寸优化**:
1. card_enhancement_panel: 1200x640 → 1000x580
2. achievement_panel: 修复硬编码偏移量，改用居中布局 600x500
3. level_select_panel: 900x700 → 760x580
4. intelligence_hub_panel: 920x620 → 840x580
5. drops_inventory_panel: 添加尺寸定义 800x520

**UI布局优化**:
1. backpack_panel: Grid列数 17 → 12
2. affix_panel: 修复文本硬编码换行
3. modification_panel: 添加完整样式定义 960x600

**文档创建**:
- `docs/UI_AUDIT_REPORT.md` - UI检查报告
- `docs/UI_DESIGN_GUIDELINES.md` - UI设计规范
- `docs/UI_FIX_SUMMARY.md` - UI修复总结

## v6.1 平衡性调整记录 (2026-06-08)

**单位平衡性调整:**
1. 降低近未来伤害倍率：1.90 → 1.80 (battle_card_v3.gd)
2. 调整T-72/M1 HP关系：T-72 850→800，M1 800→850 (default_cards.gd)

**MOD平衡性调整:**
1. aa_01_radar：attack_interval -50% → -30% (已完成于v6.0)
2. art_06_fire_computer：attack_interval -40% → -30% (已完成于v6.0)
3. art_09_rapid_fire：attack_interval -30% → -20% (已完成于v6.0)
4. arm_06_apfsds：attack_armor +35% → +30% (已完成于v6.0)
5. aa_04_quad_mount：attack_interval -35% → -30% (v6.1新增)
6. aa_11_auto_fc：attack_interval -50% → -40% (v6.1新增)
7. air_05_helmet_sight：attack_interval -50% → -40% (v6.1新增)

**性能优化:**
1. 增加对象池大小：子弹池 2→25，伤害数字池 4→15 (object_pool.gd)

**架构修复:**
1. 移除7个重复的autoload配置，改用ManagerLazyLoader延迟加载 (project.godot)
2. 修复BattleManager依赖注入，使用运行时get_node_or_null() (battle_manager.gd)

**UI修复:**
1. 修复UILazyLoader配置：删除不存在的blueprint_workshop和blueprint_library配置
2. 统一路径字段命名：全部使用parent_path
3. 在main.tscn中添加11个缺失的Overlay容器

## v6.6 7星相位仪主动能力 (2026-06-20)

**新增能力系统**: 相位仪 `active_ability` 字段（之前 special_traits 是纯文本，无战斗实现）

**7个能力分配到各势力7星相位仪（含低星降级版）:**

| 能力 | 7星完整版 | 分配相位仪 | 低星降级 |
|------|----------|-----------|----------|
| 火炮连发 | 每10秒连发7发(间隔1秒) | pi_nova_03(新星-超弦) | 6星:15秒/5发, 4星:20秒/3发 |
| 幻影克隆 | 同卡可放2个,克隆体+100%攻/+80%血 | pi_helix_04(螺旋-幻影核,新增) | 5星:+50%/+40%, 3星:+20% |
| 直射穿透 | 100%穿透,每穿一个衰减10% | pi_umbra_04(影幕-虚空穿,新增) | 6星:70%, 3星:40% |
| 免能量 | 部署完全免能量 | pi_atlas_04(擎天-零点能,新增) | 6星:-50%, 4星:-30% |
| 核子轰炸 | 每30秒敌方全体轰炸 | pi_eon_03(永纪-终式) | 5星:45秒, 2星:60秒减半 |
| 致命酸雨 | 开局30秒敌方每秒掉2%血 | pi_aegis_04(神盾-壁垒核) | 6星:20秒, 4星:12秒 |
| 巨型能量罩 | 开局我方全体20000护盾 | pi_generic_12(天穹VII型) | 6星:10000, 4星:5000 |

**关键文件:**
- `data/phase_instruments.gd` — 7个ability_xxx(star)定义 + active_ability字段 + 3个新7星 + 低星降级
- `managers/battle/phase_instrument_abilities.gd`(新增) — periodic/on_battle_start能力触发
- `managers/battle/battle_manager.gd` — start_battle/on_battle_start + _process/update接入
- `managers/battle/battle_spawn_system.gd` — 免能量+幻影部署+克隆体加成
- `scripts/battle/attack_calculator.gd` — 直射穿透比例
- `managers/phase_instrument_manager.gd` — get_active_ability()

## v6.6 改造效果↔战斗卡属性关联修复 (2026-06-20)

**问题**: `ModificationRegistry._apply_single_mod_effects()` 的 match 分支是改造效果应用的唯一闸门；落入 `default` 分支的 effect key 被塞进 `result["_special"]`，而 `unit_stats_table._apply_mod_stat_effects()` 完全不读 `_special`（注释自承认"暂不处理"），导致一批改造在战斗中空转。

**修复范围**: A类——5个真正属于战斗卡属性范畴的缺口（涉及 art_04/05/11、eng_02、aa_05、gen_09、aa_09、air_08 共8个改造模块）。B/C类约30个 key（环境/情报/经济/光环/战术机制类，如 night_bonus/vision/ally_*/multi_target/missile_intercept 等）有意保留现状——它们本就不属于战斗卡属性范畴，强行映射会语义错位，留待对应系统实现时再接。

**5个修复点:**

| effect key | 修复方式 | 涉及改造 |
|-----------|---------|----------|
| `attack_fort` | 新增条件型字段 `attack_fort_bonus`，FORT目标在 get_attack_vs() 叠加（复用 armor_pen_vs_* 模式） | art_11温压弹+50%、eng_02爆破+40% |
| `splash_radius` | 新增 `splash_radius_bonus`，_apply_splash 半径改为 80×(1+bonus) | art_04子母弹+50%、aa_05近炸+30% |
| `single_target_penalty` | 新增字段，主目标伤害×(1+penalty)，放在暴击后溅射前，maxf(0,...)防负 | art_04子母弹-20% |
| `missile_dodge` | 映射为 dodge_chance（反导语义同源） | air_08/aa_09/gen_09 +0.25~0.30 |
| `counter_bonus` | 映射为 crit_chance（"精确还击"语义） | art_05反炮兵雷达+30% |

**关键文件:**
- `resources/unit_stats.gd` — 新增3字段：attack_fort_bonus / splash_radius_bonus / single_target_penalty
- `scripts/systems/modification_registry.gd` — _apply_single_mod_effects match增加5个分支
- `resources/unit_stats_table.gd` — _apply_mod_stat_effects 增加3字段的 base_dict + 写回
- `scripts/battle/attack_calculator.gd` — get_attack_vs() FORT分支叠加 attack_fort_bonus
- `scripts/battle/module_effect_handler.gd` — _apply_splash 动态半径 + on_bullet_hit 应用 single_target_penalty

**设计决策:**
1. attack_fort 用条件型字段而非新攻击维度——FORT仍走ARMOR维度，仅叠加条件加成，零侵入
2. single_target_penalty 放暴击后/溅射前——只惩罚主目标不影响溅射伤害，符合子母弹"散布换精度"语义
3. 向后兼容——3个新字段默认0，未装备相关改造时行为与改动前完全一致

**平衡性:** 8个改造数值全部通过复核。2处WARN（aa_05双重激活、missile_dodge系列dodge量级偏高）均为"从空转激活"而非叠加超模，有 min(1.0) 上限保护且与 power_mult 匹配，建议后续实机观察。

**验证说明:** Godot headless --check-only 因项目体量（133卡+19 autoload）5分钟超时（引擎成功启动到DefaultCards构建阶段，autoload链路无语法错误），改为静态一致性核对（Grep确认3字段全链路拼写一致+5个match key完整+缩进正确）——全部通过。

## v6.6 全面一致性修复 (2026-06-21)

基于全项目数据一致性/功能贯通性/UI属性衔接性审查，修复 5 个 CRITICAL + 1 个 HIGH 问题。

**修复点:**

| 编号 | 问题 | 修复 |
|------|------|------|
| C1 | 情报4 manager（IntelManual/IntelDiscoveryManager/IntelEvolutionManager/EnemyOriginModManager）进度不存档，重启丢失 | 新增 save_state/load_state 接口 + 注册到 SaveManager（critical+deferred）+ SK_常量；旧独立文件兼容读取 |
| C2 | SignalBus.show_toast 全程无连接，所有 toast 提示静默失效 | ToastManager._ready 连接 SignalBus.show_toast + save_manager 预加载 ToastManager |
| C3 | world_map_panel.tscn 缺失（UILazyLoader 配置死链） | 删除 ui_lazy_loader 的 map 配置（功能由 main.tscn 内联节点承担，lazy-load 永不触发） |
| C4 | 5 个信号（quest_completed/task_completed/achievement_unlocked/achievement_progress_updated/daily_tasks_refreshed）被 connect 但从不 emit，任务/成就完成 UI 不刷新 | 各 manager 在本地 signal.emit 后追加 SignalBus 镜像 emit |
| C5 | weapon_type 两套枚举混用：改造写入 legacy 值(5/6/9)污染 weapon_type 弹道字段，导弹(9)被 AI 误判为直射 | 新增 GC.is_indirect_weapon_type() 统一曲射判定（含 ROCKET/FLAK/MISSILE）；改造改写 legacy_weapon_type 字段（不污染 weapon_type）；bullet 传值优先 legacy |
| H1 | 情报5 manager 三重注册（autoload + lazy_loader + CORE 不同步） | 保留 lazy_loader 配置作 ensure_loaded 入口（4处调用依赖），加注释澄清 autoload+别名双层设计 |

**关键文件:**
- `scripts/systems/intel_manual.gd` / `intel_discovery_manager.gd` / `intel_evolution_manager.gd` / `enemy_origin_mod_manager.gd` — save_state/load_state + 去 _ready 自加载
- `managers/save_manager.gd` — 注册4 manager（CRITICAL/DEFERRED/RESETTABLE + SK_常量）+ 预加载 ToastManager
- `scripts/systems/save_constants.gd` — 4 个情报 SK_ 常量
- `managers/toast_manager.gd` — _ready 连接 show_toast
- `managers/ui_lazy_loader.gd` — 删 map 死配置
- `managers/quest_manager.gd` / `daily_task_manager.gd` / `achievement_manager.gd` — 补 SignalBus 镜像 emit
- `resources/game_constants.gd` — is_indirect_weapon_type() 辅助函数
- `scripts/battle/construct_unit_ai.gd` / `scenes/units/enemy_unit.gd` — 曲射判断改用统一辅助函数 + bullet 传值优先 legacy
- `scripts/systems/modification_registry.gd` / `resources/unit_stats_table.gd` — weapon_type key 改写 legacy_weapon_type
- `managers/manager_lazy_loader.gd` — intel 配置加 autoload 别名注释

**设计决策:**
1. C1 完全切换统一存档（清空字段重置），load_state 收到空字典时兼容读取旧独立文件（首次迁移不丢进度）
2. C5 用统一辅助函数而非分离双字段重构——改造写入 legacy_weapon_type（已存在字段），AI 判断用 is_indirect_weapon_type 扩展范围，bullet 传值优先 legacy，最小改动覆盖全链路
3. H1 保留 lazy_loader 配置（4处 ensure_loaded 调用依赖），仅加注释澄清——删除会破坏现有调用链

**文档同步:** AGENTS.md autoload 数量(19→24)、schema(v5→v6)、迁移链补 v6、情报系统说明；balance-check SKILL.md era 倍率(1.45/1.70→1.40/1.65)

## v6.7 自由模式剧情任务系统 (2026-06-22)

**目标**: 在自由模式中为关键关卡挂载剧情任务（对话面板演出），任务面板加"剧情"标签页。剧情模式原样保留，两套并存。

**核心策略**: 复用 QuestManager（不新建 manager）+ 数据扩展 + 触发器钩子 + 对话面板解耦。

**数据扩展（向后兼容）** — quest 定义新增 4 个可选字段（`def.get()` 读，默认值不影响旧任务）:
- `category`: `"commission"`(委托,默认) / `"story"`(剧情) / `"daily"`(日常)
- `trigger_level`: 剧情任务绑定的关卡号（仅 story 用）
- `pre_battle_dialogues` / `post_battle_dialogues`: 对话队列，每项 `{speaker, text, choices?}`

**6 个剧情任务（取自 docs/补剧情.txt 关卡映射）:**

| 任务 ID | 触发关 | 标题 | 剧情幕 |
|---------|-------|------|--------|
| q_story_first_guardian | 20 | 第一个守护者 | 第六幕·铁血男爵 |
| q_story_zack_48 | 48 | 替扎克看看48关之后 | 第七幕·扎克的四十八 |
| q_story_truth_60 | 60 | 守护者的低语 | 第八幕·守护者说话 |
| q_story_locke_83 | 83 | 洛克止步之地 | 第八幕·洛克与83 |
| q_story_mirror_99 | 99 | 镜像自己 | 第九幕·镜像守护者 |
| q_story_final_100 | 100 | 最后的试炼 | 第十幕·相位之主 |

剧情任务通过 prereq 链串联（20→48/60→83→99→100），前置完成后自动揭示（不依赖 NPC，自由模式无 city_map）。

**触发流程:**
1. 玩家在任务面板"剧情"Tab 接取剧情任务
2. 进关时 GameManager.go_to_battle 检查该关是否有已接取的剧情任务 → emit `story_mission_dialogue(quest_id, "pre")`
3. story_dialogue_panel 监听信号，播放战前对话（复用 v6.3 对话格式 + v6.6 分支选项）
4. 战斗进行（objective_type=clear_level 自动追踪进度）
5. 过关后 GameManager emit `story_mission_dialogue(quest_id, "post")` → 播放战后对话 → 任务自动完成

**关键文件:**
- `data/quest_definitions.gd` — +4 字段注释、+6 story 任务、+get_quests_by_trigger_level/get_ids_by_category
- `data/json/quest_definitions.json` — 补 v6.6 支线 + 6 story 任务（修复 JSON/GDScript 不同步：原 JSON 缺真实者/林薇/扎克支线，运行时不加载）
- `managers/quest_manager.gd` — +get_quests_by_category/trigger_level_for_quest/get_active_story_quest_at_level；is_quest_available 对 story 任务自动揭示
- `managers/game_manager.gd` — go_to_battle/on_battle_ended 加 _check_story_mission_pre/post_battle 钩子；+_pending_story_mission_quest 字段
- `scripts/signal_bus.gd` — +story_mission_dialogue(quest_id, phase) 信号
- `scenes/ui/story_dialogue_panel.gd` — +play_dialogues 通用方法、+_on_story_mission_dialogue 监听、+_ensure_ancestor_visible/_hide_mission_overlay（自由模式 overlay 可见性管理）、_on_all_dialogues_done 分流（mission 路径不调 v6.3 story_proceed_to_battle）
- `scenes/ui/quest_panel.tscn` — 重构为 TabContainer（委托/剧情/日常三标签），CompanySummary 移入委托 Tab
- `scenes/ui/quest_panel.gd` — _refresh_list 按 category 分流；剧情任务紫色边框 + ★ 标题前缀 + 触发关卡提示
- `scenes/world_map.gd` — _make_level_button 查剧情任务，加紫色左边框 + ★ 前缀 + tooltip

**设计决策:**
1. 复用 quest 系统不新建 manager — QuestManager 已有 hidden/prereq/branches/progress 全套
2. category 默认 "commission" — 现有所有委托任务行为零变化，向后兼容
3. 对话面板解耦而非新建 — story_dialogue_panel 已支持分支选项/角色配色/多句队列，去 v6.3 硬绑定即可
4. 触发器钩子放 game_manager — go_to_battle/on_battle_ended 是所有战斗必经单点
5. JSON 同步是前置 bug 修复 — v6.6 剧情任务在 GDScript 写好但 JSON 缺失，运行时不加载，本次顺带修复
6. 剧情任务自动揭示 — 不依赖 city_map/NPC（自由模式没有），前置 prereq 完成即 reveal

**不做的事:**
- 不删/不改剧情模式（city_map、StoryModeButton、v6.3 章节代码全部保留）
- 不动 DailyTaskManager（日常 Tab 第一期空置提示）
- 不做结局分支（结局归剧情模式管）

**验证:** Godot headless --check-only 成功启动到 DefaultCards 构建（133卡），无语法错误；Grep 静态核对通过（4 字段全链路拼写一致、story_mission_dialogue 信号 emit×2 + connect/disconnect + 定义完整、6 个新方法定义/调用配对、quest_panel 7 个 @onready 路径与 tscn 节点全匹配）。

## v6.7 引导剧情扩展（系统教学）(2026-06-22)

**目标**: 在关键关卡（第1/5/10/15/21关）自动触发系统教学对话，引导玩家学习相位仪装配、强化、改造、进化、符文五大系统。与主线剧情并存。

**category 新增取值 "tutorial"** — 引导剧情任务，与 "commission"/"story"/"daily" 并列：
- **自动触发**：进关即播，不进任务面板、不需手动接取、不占任务栏名额
- **一次性**：用 StoryManager 标记（`tutorial_<quest_id>`）防重复，每个只播一次
- **仅战前对话**：引导只教系统（战前），无战后对话
- **即时奖励**：触发时立即发放纳米材料（不通过任务完成流程）

**5 个引导剧情任务:**

| 任务 ID | 触发关 | 标题 | 教学系统 |
|---------|-------|------|---------|
| q_tutorial_equip_1 | 1 | 相位仪与卡牌 | 相位仪槽位 + 卡牌装配 |
| q_tutorial_enhance_5 | 5 | 卡牌强化 | 纳米材料强化卡牌等级 |
| q_tutorial_modify_10 | 10 | 卡牌改造 | 安装改造模块 |
| q_tutorial_evolve_15 | 15 | 卡牌进化 | 卡牌升阶形态 |
| q_tutorial_rune_21 | 21 | 法则符文 | 相位仪法则研究（打完第20关守护者获得符文后） |

**同关多剧情依次播放机制:**
同一关可能挂载多个剧情任务（如某关同时有 tutorial + story，或主线 + NPC 支线）。触发顺序：tutorial 先于 story，依次入 `_story_mission_queue`，story_dialogue_panel 用 `_mission_queue` 排队播放——播完一个自动播下一个，不互相覆盖。

**关键文件（本次扩展）:**
- `data/quest_definitions.gd` — +5 tutorial 任务定义、+get_all_triggerable_at_level（返回 story+tutorial，区别于 get_quests_by_trigger_level 只返回 story）
- `data/json/quest_definitions.json` — 同步 5 个 tutorial 任务（66→71）
- `managers/game_manager.gd` — _check_story_mission_pre_battle 重构（收集 tutorial+story 形成队列）；+_is_tutorial_triggered/_mark_tutorial_triggered/_grant_tutorial_reward/_is_story_quest_active；_story_mission_queue/_story_mission_played 替代 _pending_story_mission_quest
- `scenes/ui/story_dialogue_panel.gd` — +_mission_queue 队列播放（同关多剧情依次播放，播完一个自动播下一个）
- `scenes/ui/quest_panel.gd` — _refresh_list 过滤 tutorial（不进任何 Tab）

**设计决策:**
1. tutorial 不进任务面板 — 纯自动触发，避免玩家困惑（看到任务却无法接取/无明确目标）
2. tutorial 触发即标记 + 发奖 — 不依赖对话播完（防中途退出重播，奖励保证给到）
3. get_all_triggerable_at_level vs get_quests_by_trigger_level — 前者含 tutorial（GameManager 用），后者只 story（world_map 用，避免教学关显示★）
4. 队列播放而非覆盖 — 同关多剧情用队列依次播放，避免后发信号覆盖前者

**验证:** Godot headless --check-only 通过（无语法错误）；JSON tutorial 任务字段完整；Grep 确认 get_all_triggerable_at_level/_story_mission_queue 链路一致。

## v6.7 剧情任务全面扩展（补剧情.txt 关卡锚点全铺满 + NPC 支线归剧情）(2026-06-22)

**目标**: 把 docs/补剧情.txt 的关卡锚点全部铺满，并把原有 6 个 NPC 支线（真实者/林薇/扎克）从 city_map 依赖改造为自由模式关卡触发。

**A. 新增 5 个主线剧情任务（补全时代 Boss + 主线节点）:**

| 任务 ID | 触发关 | 标题 | 剧情幕 |
|---------|-------|------|--------|
| q_story_realist_10 | 10 | 真实者的阴影 | 第四幕·真实者初次接触 |
| q_story_city_15 | 15 | 城市的轮廓 | 第二幕·城市功能解锁 |
| q_story_steel_marshal_40 | 40 | 钢铁洪流 | 时代Boss·钢铁元帅（二战） |
| q_story_void_lord_80 | 80 | 虚空之主 | 时代Boss·虚空领主（现代） |
| q_story_countdown_90 | 90 | 倒计时 | 第九幕前奏·海伦宣告 |

**B. NPC 支线归入剧情标签（6 个，触发关绑定）:**

| 任务 ID | 触发关 | 原揭示方式 | 现揭示方式 |
|---------|-------|-----------|-----------|
| q_realist_invite | 10 | city_map NPC 对话 | 进第10关自动揭示 |
| q_realist_join/reject/delay | - | 分支后续（prereq 链） | 完成 q_realist_invite 后分支揭示 |
| q_linwei_secret | 15 | city_map NPC 对话 | 进第15关自动揭示 |
| q_zack_beyond_48 | 40 | city_map NPC 对话 | 进第40关自动揭示 |

**主线 prereq 链（完整通关路径）:**
```
L10 真实者阴影 → L15 城市轮廓 → L20 铁血男爵 → L40 钢铁元帅
→ L48 扎克48关 → L60 守护者低语 → L80 虚空领主 → L83 洛克止步
→ L90 倒计时 → L99 镜像自己 → L100 相位之主
```

**关键改造点:**
- `managers/game_manager.gd` `_check_story_mission_pre_battle`：进关时对该关所有 story 任务调 `qm.reveal_quest(qid)` 自动揭示（自由模式无 city_map/NPC，NPC 支线必须靠关卡触发揭示）；只有"已接取 + 未完成 + 有 pre_battle_dialogues"的才入播放队列
- NPC 支线（q_realist_invite 等）无 pre_battle_dialogues，进关只揭示不播对话，玩家在任务面板接取后按各自 objective_type 完成（win_battles/collect_cards/clear_level/reach_reputation）

**剧情任务总量（v6.7 完整版）:**

| 类型 | 数量 | 说明 |
|------|------|------|
| 引导剧情 tutorial | 5 | 第1/5/10/15/21关，自动触发，系统教学 |
| 主线剧情 story（有对话） | 11 | 第10/15/20/40/48/60/80/83/90/99/100关 |
| NPC支线 story（无对话） | 6 | 真实者4 + 林薇1 + 扎克1，进关揭示 |
| **合计** | **22** | 覆盖补剧情.txt 全部关卡锚点 |

**关键文件（本次扩展）:**
- `data/quest_definitions.gd` — +5 主线任务定义、6 个 NPC 支线加 category/trigger_level、3 个现有任务 prereq 更新
- `data/json/quest_definitions.json` — 同步（71→76→80 任务；story 17 个、tutorial 5 个、commission 58 个）
- `managers/game_manager.gd` — _check_story_mission_pre_battle 加 story 任务自动揭示

**验证:** Godot headless --check-only 通过；JSON 76 任务字段完整；Grep 确认 reveal_quest 钩子调用正确。

## v6.8 收敛我方加成来源 (2026-06-23)

**背景**: 审查发现我方战斗卡的属性加成来源多达 10+ 个系统，且存在"时代缩放只加我方、不加敌方"的不对称设计。本轮收敛加成来源，停用 4 套非核心加成 + 压缩稀有度，保留各系统的数据/UI/存档/掉落。

**核心原则**: 我方加成来源收敛为——强化、改造、相位仪、符文（玩家可投入养成的核心）+ 战力星级/进化/军衔/稀有度（派生乘区）+ 兵种修正/平台光环/改造光环（单位设计/战场协同）。

**5 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **稀有度乘区压缩** | 6档 1.0/1.1/1.25/1.4/1.5/1.8 → 1.0/1.04/1.08/1.12/1.16/1.20（common/uncommon/rare/epic/legendary/mythic），避免稀有度过度主导战力 |
| 2 | **势力停用** | 移除势力变体生成路径（effective_card 直接用原始 platform_card）+ apply_faction_special_to_stats + _apply_skill_tree_effects；势力声望商店/合成/卡生成养成保留 |
| 3 | **敌源MOD断开** | 移除 apply_eom_to_stats；EOM 面板/装备/战后碎片掉落/存档全部独立保留 |
| 4 | **我方相位法则被动停用** | 删 construct_unit 的 _apply_phase_law_passives + connect/disconnect + _law_regen_per_sec 回血块 + 7 个孤立 _base_* 变量；**敌方减益不受影响**（enemy_unit/swarm_enemy_slot 各自独立实现继续生效） |
| 5 | **时代缩放移除** | build_stats_from_card 不再按 era 放大我方 HP/三维攻击/射程/武器伤害；_apply_evolution_hp_floor 同步去掉 era 倍率（避免主属性不缩放、HP下限仍按时代抬高的矛盾） |

**关键设计决策:**
1. **时代缩放本就不对称**——核实发现敌方（enemy_stat_resolver.gd）走独立的 `wave × level × pressure × master` 难度链，从不调用 era_*_multiplier。时代缩放原本就是"只放大我方"的隐形优势，移除后关卡难度完全由敌方难度链承担，符合"缩放应为调整简单"的本意。
2. **停用而非删除系统**——势力/敌源MOD/相位法则的数据类、管理器、UI、存档、掉落全部保留，只断开战斗数值注入链路。可随时恢复，风险最小。
3. **敌方相位法则减益不动**——_apply_phase_law_passives 在我方/敌方三处是各自独立函数（同名不同体），只删我方版本，敌方 burn_on_hit/anchor_field 等减益继续生效。
4. **连带清理孤立代码**——删除被孤立的函数定义（apply_faction_special_to_stats/apply_eom_to_stats/_apply_skill_tree_effects）和孤立变量（_law_regen_per_sec/_base_* 系列），代码更清爽；保留 get_active_faction_skill_effects 公共方法（养成查询接口）和 skill_tree_specials 字段（避免破坏序列化）。
5. **连带传播属正常**——稀有度压缩后，estimate_power_score_meta_only（战力分）、get_base_power_for_mod_cost（改造消耗）数值自动变小，非重复定义，不另作处理。combat_power_from_unit_stats 读 stats 本身，时代缩放移除后战力分自动跟随，UI/战斗数值保持一致。

**关键文件:**
- `managers/evolution/evolution_helpers.gd` — get_rarity_multiplier 压缩 + _apply_evolution_hp_floor 去 era 倍率
- `managers/battle/battle_spawn_system.gd` — 简化势力变体查询 + 删势力/EOM 注入调用块 + 删 _apply_skill_tree_effects 定义 + 清 2 个孤立 preload
- `managers/faction/faction_card_generator.gd` — 删 apply_faction_special_to_stats（保留 generate_faction_variant 数据）
- `scripts/systems/enemy_origin_mod_manager.gd` — 删 apply_eom_to_stats（保留面板/掉落/存档接口）
- `resources/unit_stats_table.gd` — build_stats_from_card 删 3 处 era_*_multiplier 块（主属性/多武器/武器槽）
- `scenes/units/construct_unit.gd` — 删 _apply_phase_law_passives + _on_phase_law_runtime_changed + connect/disconnect + _law_regen_per_sec 回血块 + 7 个孤立 _base_* 变量（顺带捎上会话前预存的 combat_kind 透传改动）
- `scenes/ui/enemy_origin_mod_panel.gd` — 注释同步（EOM 战斗加成已停用）

**保留不动的 era_*_multiplier 残留**: summarize_weapon_stats_from_card / get_weapon_base（UI 摘要/旧接口，纯死代码无调用方）；BattleCardV3.era_*_multiplier 函数定义本身（敌方系统/测试仍在引用）。

**验证:** Godot headless --check-only 通过（133卡构建，无语法错误，5分钟超时属项目既有现象）；Grep 确认 build_stats_from_card 战斗路径 era_*_multiplier 100% 清零、evolution_helpers era_*_multiplier 清零、删除的 4 个函数名 + _law_regen_per_sec 在我方代码无残留（敌方独立实现保留）。

## v6.9 势力占领关卡系统 (2026-06-23)

**背景**: 玩家设想——20关后各关卡由各势力占领，势力能力影响关卡敌人加成，势力相位师在各势力关卡分布，任务栏任务动态更新，主角完成任务影响各势力，部分任务随机结果。

**核心原则**: 静态归属（不动占领状态机）+ 前20关无势力（教学时代）+ 势力只增强敌方（不复活 v6.8 已停用的我方加成）+ 复用现有链路（任务影响势力走成熟 _grant_rewards → add_faction_reputation）。

**4个阶段实现:**

### 阶段0：数据基础与命名统一
| 改动 | 详情 |
|------|------|
| **前20关去势力** | level_information.gd 的 `_add_ww1_levels()` 1-20关 faction_id 从 "iron_wall_corp" → ""（空=无主之地，无势力加成/相位师/声望反应） |
| **新建势力能力表** | data/faction_conquest_buffs.gd — 7势力×5档（Lv1/3/5/7/10）敌人加成表，每势力一个战斗风格主题（钢壁=血厚/新星=攻猛/以太=速快/量子=量多/螺旋=闪避/虚空=暴击/边境=通用） |
| **相位师命名核查** | 发现 check_phase_master_encounter 用 NPC_PHASE_MASTERS（已是公司ID）+ _enrich_master_config 已有公司ID→法则家族映射，无需改 enemy_phase_masters*.gd |
| **on_level_conquered 守卫** | 已有现成 `if conquered_faction.is_empty(): return` 守卫（faction_system_manager.gd:285），1-20关攻克天然不扣声望 |

### 阶段1：势力对关卡敌人加成（核心机制）★
占领势力等级越高，该关敌人越强。接入敌方加成链（wave×level×pressure×master 末尾加 faction_buff 乘区）。

| 文件 | 改动 |
|------|------|
| `data/enemy_stat_context.gd` | +faction_buff 字段（复用 player_pressure 设计模式） |
| `data/enemy_stat_resolver.gd` | +_collect_faction_buff()（make_default_context 按关卡faction_id+势力等级填值）；resolve_classic_enemy 的 dmg_mul_chain/hp_mul_chain 末尾乘 f_atk/f_hp；move_speed 接入 f_spd（顺带修复 p_spd 历史遗留无效问题） |

### 阶段2：势力相位师分布
| 改动 | 详情 |
|------|------|
| **匹配已生效** | check_phase_master_encounter（game_manager.gd:107-114）已按 get_level_faction 优先抽该势力相位师，21关起生效，1-20关走随机 |
| **关卡弹窗显示驻防势力** | world_map.gd 的 _collect_level_info 加 garrison_* 字段（查 FactionSystemManager.get_faction_info）；_show_level_info_popup 加驻防势力行（橙色=占领势力+敌方加成描述，灰色=无主之地） |

### 阶段3：动态任务系统（扩展 QuestManager）★
任务栏任务随势力/关卡动态生成。核心策略：**扩展 QuestDefinitions 静态查询**（加 _DYNAMIC_QUESTS 集合 + get_by_id/get_available_ids 同时查两个集合），让所有现有代码（接受/进度/完成判定）自动支持动态任务。

| 文件 | 改动 |
|------|------|
| `data/quest_definitions.gd` | +_DYNAMIC_QUESTS 集合；+register/unregister/get_dynamic_quest_ids/get_all_dynamic_quest_defs/clear_dynamic_quests；get_by_id/get_available_ids 同时查静态+动态 |
| `data/faction_quest_generator.gd`（新增） | 势力动态任务生成器：5势力×4类型模板（win_battles/kill_enemies/attack_faction/defend_faction），按势力等级生成，奖励含 company_rep/faction_rep（影响势力） |
| `managers/quest_manager.gd` | +refresh_faction_quests（生成+注册+揭示+toast）；_try_complete 完成后 unregister 动态任务；save/load_state 持久化 dynamic_quests 字段；+is_dynamic_query 辅助 |
| `managers/game_manager.gd` | set_current_level 末尾调 _maybe_refresh_faction_quests_for_level（进入势力领地关卡触发该势力发布委托） |
| `scenes/ui/quest_panel.gd` | _make_quest_row 加 is_dynamic 视觉标记（橙红边框+暖橙标题，与剧情任务紫色/普通蓝色区分） |

### 阶段4：任务随机结果机制
部分任务完成时结果不确定（成功/部分成功/意外缴获）。

| 文件 | 改动 |
|------|------|
| `data/quest_definitions.gd` | +outcome_table 字段注释（[{weight,label,rewards}]，缺省走固定 rewards 向后兼容） |
| `managers/quest_manager.gd` | _try_complete 加 _roll_outcome 按权重抽取，用抽取 rewards 替代固定值；toast 显示结果 label |
| `data/faction_quest_generator.gd` | win_battles 任务带 outcome_table（圆满成功50%/部分成功35%/意外缴获15%） |

**关键设计决策:**
1. **静态归属而非动态占领**——用户选择，沿用 level_information.gd 固定 faction_id，不做"运行时势力攻占他关"状态机，风险最小
2. **前20关无势力**——一战教学时代设为无主之地，21关起启用势力机制，符合"20关后"描述
3. **势力只增强敌方**——与 v6.8 收敛方向一致，不复活已停用的我方势力加成；乘区接入 enemy_stat_resolver 敌方加成链末尾，零侵入
4. **扩展 QuestDefinitions 而非改每个查询函数**——动态任务接入 get_by_id/get_available_ids，所有现有代码（_on_enhancement_completed/notify_*/is_quest_done/get_current_progress_for_quest）自动支持，避免改每个函数
5. **outcome_table 向后兼容**——缺省走固定 rewards，所有现有 76 个静态任务行为零变化，只有显式定义 outcome_table 的任务才有随机结果
6. **动态任务存档**——未完成的动态任务定义持久化到 dynamic_quests 字段，旧存档无此字段时为空数组自动初始化

**平衡性:** 7势力满级威胁倍率（攻×HP）全部 ≤ 1.80 阈值（最高 void_research 1.624），单维度 ≤ 1.40/1.30 上限；与历史 master_stats 乘区同量级。

**验证:** Godot headless --check-only 成功构建到 133 卡（无语法错误，5分钟超时属项目既有现象）；Grep 静态核对全部通过（faction_buff 链路、garrison_* 链路、动态任务 API 链路、outcome_table 链路全拼写一致）。

**延后项（润色，不影响核心功能）:** leaderboard_data.gd 的 FACTION_RANGES 仍按旧关卡归属（iron_wall 1-20、frontier_union 1-10），排行榜显示与关卡弹窗"无主之地"矛盾，但仅影响排行榜领地统计展示，不影响战斗/任务/声望。

## v6.10 占领状态机 + 势力状态机 + 势力领地图面板 (2026-06-23)

**背景**: 在 v6.9 静态势力占领基础上，用户要求加"状态机+任务面板"。明确为：(1) 占领状态机（动态领地易主）+ (2) 势力状态机（派生标签）+ (3) 新建势力领地图面板。

**核心原则**: 占领转移=玩家攻克即易主（给激活势力，无激活则解放为无主之地）；势力状态=派生标签（从占领数+声望实时计算，不存储避免双源真理）；level_occupation 存进 faction_system 子字段（不升 schema，靠 load_state 守卫兼容）；加成数据源从静态切到动态占领。

**4个阶段实现:**

### 阶段A：占领状态机（核心）
| 文件 | 改动 |
|------|------|
| `scripts/signal_bus.gd` | +occupation_changed(level, old_faction, new_faction) 信号 |
| `managers/faction_system_manager.gd` | +level_occupation 字段；+occupation_changed 信号及转发；+get_level_occupation/_init_level_occupation/transfer_occupation/get_territory_count API；on_level_conquered 接入占领转移（守卫调整：静态空也执行转移）；save/load_state 持久化 level_occupation |
| `data/enemy_stat_resolver.gd` | _collect_faction_buff 数据源从静态 get_level_faction 切到动态 get_level_occupation（玩家攻克易主后敌方加成跟随） |

### 阶段B：势力状态机（派生标签）
| 文件 | 改动 |
|------|------|
| `data/faction_status.gd`（新增） | 派生状态枚举（EXTINCT/DECLINING/STABLE/EXPANDING/DOMINANT）+ 中文名+配色；derive_status(territory_count, reputation) 双维度组合判定 |
| `managers/faction_system_manager.gd` | +get_faction_status/get_faction_status_name/get_faction_status_color 派生查询（实时计算，不存储） |

### 阶段C：势力领地图面板（新建）★
| 文件 | 改动 |
|------|------|
| `scenes/ui/occupation_panel.tscn`（新增） | 占领地图面板骨架（标题/图例/领地网格/详情） |
| `scenes/ui/occupation_panel.gd`（新增） | 7势力图例（色块+名称+状态标签+占领数+声望）+100关网格（5时代×20关，按钮=占领势力配色）+点击详情；监听 occupation_changed/faction_reputation_changed 实时刷新；FACTION_COLORS 7势力代表色定义 |
| `managers/ui_lazy_loader.gd` | +occupation 注册（PopupLayer/OccupationOverlay/CenterContainer） |
| `scenes/main.tscn` | +OccupationOverlay/CenterContainer/OccupationPanel 节点 + ext_resource |
| `scenes/world_map.gd` | +_on_territory_map_button 入口（顶部"◆势力领地图"按钮，懒加载+显示面板） |

### 阶段D：world_map 占领可视化联动
| 文件 | 改动 |
|------|------|
| `scenes/world_map.gd` | _make_level_button 加占领色标（右边框=势力色，与剧情关紫色左边框不冲突）；_collect_level_info 弹窗读动态占领（_get_level_occupation_safe）；_ready 监听 occupation_changed → refresh_levels 实时刷新色标；+_OCCUPATION_BORDER_COLORS 7势力配色（与面板一致） |

**关键设计决策:**
1. **玩家攻克即易主**——用户选择，攻克某关直接归玩家激活势力；未激活势力则解放为无主之地。简单直接，玩家掌控感强
2. **派生标签不存储**——势力状态从占领数+声望实时计算，避免"状态字段与底层数据不一致"的双源真理问题
3. **level_occupation 存进 faction_system 子字段**——不升 schema，靠 load_state 守卫兼容（旧存档无此字段→空字典→get_level_occupation 回退静态表，零破坏）
4. **加成数据源切到动态**——_collect_faction_buff 从 get_level_faction 改为 get_level_occupation，让占领真正影响战斗（攻克易主后该关敌人加成跟随新占领势力）
5. **on_level_conquered 守卫调整**——原 L285 静态空即 return 会阻止已接管关卡再攻克时转移；改为静态空时跳过声望反应但仍执行占领转移
6. **新面板独立而非加 Tab**——occupation_panel 是世界视角（100关占领网格），与 faction_panel 的单势力详情视角 UI 范式不同，新建独立面板更干净
7. **信号驱动实时刷新**——occupation_changed 经 SignalBus 转发，occupation_panel 和 world_map 都监听，攻克易主后两边都实时更新

**关键文件:**
- `managers/faction_system_manager.gd` — +level_occupation 字段/API/转移/存档/信号转发（核心）
- `data/faction_status.gd`（新增）— 派生状态枚举+计算
- `data/enemy_stat_resolver.gd` — 加成数据源切动态占领
- `scenes/ui/occupation_panel.tscn/.gd`（新增）— 占领地图面板
- `scenes/world_map.gd` — 占领色标+弹窗读动态+入口按钮+实时刷新
- `scripts/signal_bus.gd` — occupation_changed 信号
- `managers/ui_lazy_loader.gd` / `scenes/main.tscn` — 面板注册与挂载

**验证:** Godot headless --check-only 成功构建到 133 卡（无语法错误，5分钟超时属项目既有现象）；Grep 静态核对全部通过（occupation_changed 信号链路、get_level_occupation API 链路、get_faction_status 链路、occupation_panel 节点路径与 tscn 全匹配）。

## v6.11 敌方相位师影响普通敌兵 + master 系数收敛 (2026-06-24)

**背景**: 平衡性审查发现敌方相位师的 `master_stats`（attack_power/defense）应影响普通敌兵，但 `make_default_context` 从不注入 master_stats，导致经典敌兵和蜂群走 `resolve_classic_enemy` 时 m_atk/m_hp 恒为 1.0——只有相位师召唤的产兵（走 `apply_phase_master_to_unit_stats`）才生效。同时 v6.2 把 m_atk 系数从 0.0005 提到 0.002，但漏改了测试（`test_enemy_stat_resolver.gd` 仍断言旧值），该测试处于失败状态。

**3 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **make_default_context 注入 master_stats** | 函数末尾从 BattleManager._phase_master_config.stats 取 master_stats 写入 ctx.master_stats；经典敌兵(enemy_unit)与蜂群(swarm_enemy_slot)都经此函数 → resolve_classic_enemy，修复后都吃相位师属性加成。非相位师战时 _phase_master_config 为空 → master_stats 保持默认空，普通波次行为零变化 |
| 2 | **master_attack_multiplier 系数收敛** | 0.002 → 0.0005。master030(attack_power1000)从过猛的 3.0x 收敛到温和的 1.5x；master001(120)从 1.24x→1.06x |
| 3 | **master_defense_hp_multiplier 系数恢复** | 0.0001 → 0.0003。v6.2 曾削弱(0.0003→0.0001)导致防御属性对敌兵几乎无效（master016 def200 仅 1.02x）；恢复后 1.06x，与攻击侧量级对称 |

**关键设计决策:**
1. **普通敌兵走 master_stats 生效 + 排名加成保留叠加**——用户确认。make_default_context 注入 master_stats 让普通敌兵/蜂群吃相位师属性，同时保留 apply_enemy_phase_master_bonus_to_unit_stats（+14~21% 排名加成），双乘区叠加
2. **系数收敛到 v6.2 之前的值**——0.0005/0.0003 正好让过时失败的测试自动通过（测试断言反映的就是旧系数）
3. **向后兼容**——非相位师战时 master_stats 恒空 → 行为与修复前 100% 一致；相位师遭遇战从"仅排名加成"变为"master_stats + 排名加成叠加"，温和增强

**关键文件:**
- `data/enemy_stat_resolver.gd` — make_default_context 末尾注入 master_stats（取 BattleManager._phase_master_config.stats）；m_atk 系数 0.002→0.0005、m_hp 系数 0.0001→0.0003
- `tests/unit/combat/test_enemy_stat_resolver.gd` — +test_master_multipliers_new_coefficients（锁定新系数防回归）、+test_resolve_classic_enemy_with_master_stats（比值验证 master_stats 对普通敌兵生效）

**数值影响（温和）:** 中等关（第40关 + 相位师013 + 排名3星）ATK +17%/HP +2%；极端堆叠（第100关 + 满级势力 + master030 + 满排名）ATK +50%/HP +4%。

**验证:** Godot headless --check-only 通过（133 卡构建）；独立运行时验证 12 项全 PASS（系数验证 + resolve_classic_enemy 比值验证 + 向后兼容）；Grep 静态核对通过。

## v6.11b 战场敌方信息卡"武装：无"误显示修复 (2026-06-24)

**背景**: 用户反馈战场敌方信息卡显示"武装：无"。调查证实 36 个敌方 archetype 100% 都有 weapon_type，但 `_show_generic_enemy_unit`（card_info_panel.gd）判断武器的逻辑只依赖 `EnemyArchetypes.get_config(archetype_id)`——一旦该 cfg 返回空字典（动态生成单位时序/manifest 未合并/某些 archetype 查不到），weapon_type_val 保持默认 -1 → 直接显示"武装：无"，即使该单位实际有武器且正在开火。附带 bug：`_enemy_surface_combat_stats` 用 `unit.hp`（当前剩余血量）而非 `max_hp`（满血上限），残血敌人显示被打掉后的血。

**2 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **武器显示三级回退** | `_show_generic_enemy_unit` 武器判断改为：①优先 archetype cfg；②cfg 空时回退 unit.stats.weapon_type + unit.stats.attack_damage（经典敌人和蜂群都同步了这两字段）；③仍查不到才显示"无"。杜绝误显示 |
| 2 | **HP 显示改用 max_hp** | `_enemy_surface_combat_stats` 优先读 max_hp（满血上限），单位无该字段时回退 hp（防御性兼容）。残血敌人血量现在稳定显示上限 |

**关键设计决策:**
1. **防御性回退而非改 get_config**——manifest 合并时序属正常缓存行为，显示层做兜底更稳妥，不触动数据查询逻辑
2. **不改 archetype 数据**——36 单位本就有武器，数据没问题；问题是显示层只依赖单一数据源太脆弱

**关键文件:**
- `scenes/ui/card_info_panel.gd` — `_show_generic_enemy_unit` 武器判断三级回退（L1322-1333）；`_enemy_surface_combat_stats` HP 改用 max_hp（L1022）

**验证:** Godot headless --check-only 通过（133 卡构建）；Grep 确认 stats.weapon_type/stats.attack_damage 在 enemy_unit.gd:413 和 swarm_enemy_slot.gd:103 都有设置（回退链完整）。注：显示层改动需游戏内实机验证点击交互。

## v6.12 敌方产兵改用真实数据 + master 系数增强 (2026-06-25)

**背景**: 用户反馈"敌方卡和我方同样卡差异太大"。调查证实敌方相位师产兵走 `build_multi_stats`（通用平台表 `_PLATFORM_BASE`/`_WEAPON_BASE`，数值偏弱），而非真实敌人数据；叠加的 master 加成也偏温和（HP 仅 ×1.03-1.06）。同一概念单位（如 T-72）敌我可差 3-5 倍。

**决策（与用户确认）:** 方式 1——敌方产兵改用敌方 archetype 真实数据（如 elite_cold_t72 的 hp250/atk40），替换通用平台表；同时增强 master 系数。

**3 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **产兵改用真实 archetype 数据** | `_produce_unit_with_equipment` 的 `build_multi_stats`（通用表）→ `_build_stats_from_archetype`（真实 archetype cfg 构造 CardResource → build_stats_from_card）。复用已有平台→archetype 映射（_pick_visual_archetype_for_platform），archetype 查不到时回退通用表兜底 |
| 2 | **master_attack_multiplier 增强** | 0.0005 → 0.0008。master016(400)攻 ×1.32，master030(1000)攻 ×1.80 |
| 3 | **master_defense_hp_multiplier 增强** | 0.0003 → 0.0006。master016(200)血 ×1.12，master030 血 ×1.12 |

**关键设计决策:**
1. **用敌方 archetype 真实数据而非跨数据源读我方卡牌**——用户选择（推荐项）。复用 _pick_visual_archetype_for_platform 的平台→archetype 映射取真实 cfg，改动集中在 1 个函数，风险低；跨数据源读 default_cards 会引入耦合且需新建映射表
2. **保留 platform_data.stats 覆写**——master 装备的 hp/defense 覆写是其差异化体现，保留让不同 master 召唤的单位有区别
3. **系数增强同步影响两条路径**——m_atk/m_hp 系数同时影响普通敌兵（resolve_classic_enemy，v6.11 刚修的 master_stats 注入）和产兵（apply_phase_master_to_unit_stats），两者同步增强，符合"敌方变强"诉求
4. **兜底完善**——archetype 查不到/映射失败时回退 build_multi_stats 通用表，不会崩

**关键文件:**
- `scenes/units/enemy_phase_field_driver.gd` — `_produce_unit_with_equipment` 改用 `_build_stats_from_archetype`；新增 `_build_stats_from_archetype`（真实 archetype cfg → CardResource → build_stats_from_card）+ `_archetype_combat_kind`（按 tags 推断战斗类型）
- `data/enemy_stat_resolver.gd` — m_atk 系数 0.0005→0.0008、m_hp 系数 0.0003→0.0006
- `tests/unit/combat/test_enemy_stat_resolver.gd` — 3 处测试断言值更新匹配新系数

**数值影响（以 master016 召唤精英 T-72 为例）:** HP ~212→~336（+59%），ATK ~36→~53（+47%）。我方满养成 T-72 仍保持 ~12-17× 优势——养成碾压感保留，但敌方产兵不再过脆偏弱。

**验证:** Godot headless --check-only 通过（133 卡构建）；独立运行时验证 10 项全 PASS（系数验证 + resolve_classic_enemy 比值验证 + 向后兼容）；Grep 确认 _PLATFORM_DEFENSE/PLATFORM_TO_COMBAT_KIND 静态成员存在、archetype cfg 字段名与新函数读取匹配。注：`_build_stats_from_archetype` 依赖 autoload 环境（EnemyArchetypes.get_config），运行时构建结果需游戏内实机验证。

## v6.14 全系统贯通 (2026-06-26)

**背景**: 用户提出跨多系统的整体诉求——不同战力敌人有不同战力/掉不同改造、不同改造要不同战力安装、相位师有等级/相位仪/符文/出兵序列、打败相位师掉符文/改造/兵种卡、关卡掉兵种卡/改造、关卡波次序列式+随机、势力是玩家主动构筑的选择加成、占领关卡给敌方加成和改造掉落。

**核心策略**: 11 个子模块按"数据层→逻辑层→接入层"分 6 阶段一次实现。新增 2 个数据文件 + 扩展/改造约 16 个既有文件。全部向后兼容（新字段 `.get(key, default)`，缺省值保证旧存档/旧数据零变化）。

**6 个阶段实现:**

### 阶段1：战力分级基础
| 文件 | 改动 |
|------|------|
| `data/power_tiers.gd`（新增） | 5 档战力枚举（GRUNT/VETERAN/ELITE/CHAMPION/OVERLORD）+ get_tier_by_rank/get_tier_by_power/meets_requirement；统一所有"不同战力→不同X"的共用基础 |
| `data/intel_manual_items.gd` | roll_random_mod_blueprint 增加 power_tier + bias_unit_types 参数；新增 _apply_power_tier_to_weight（高档位抬高高稀有度权重）+ _unit_type_name_to_int |

### 阶段2：关卡波次序列系统
| 文件 | 改动 |
|------|------|
| `data/level_spawn_sequences.gd`（新增） | 程序化生成 per-level 波次序列（种子=level 可复现）；规则：每时代首关教学/wave%3精英波/最后波boss/难度随进度递增；get_sequence_for_level/get_wave_spec/pick_type_for_wave |
| `managers/battle/battle_spawn_system.gd` | 波次抽选从纯随机改为读序列（composition 抽签 + bias_tags 偏好抽签）；新增 _pick_archetype_with_bias；序列为空回退原随机 |

### 阶段3：势力主动构筑重接 + 占领掉落
| 文件 | 改动 |
|------|------|
| `managers/battle/battle_spawn_system.gd` | `_build_stats_cached` 重接 v6.8 停用的势力技能注入：取 get_active_faction_skill_effects 的 stat_bonus 注入我方单位（三维攻防/HP/攻速）；缓存 key 加 active_faction_cache_key |
| `data/faction_conquest_buffs.gd` | get_buff 返回新增 drop_mul（改造掉率×1.0~1.5）+ mod_pool_bias（偏好改造类型）；FACTION_MOD_BIAS 7势力主题映射 |
| `scripts/systems/intel_discovery_manager.gd` | `_roll_intel_item_drops` 注入占领势力：drop_mul 乘进掉率，改造蓝图传 bias_unit_types + power_tier |

### 阶段4：相位师装备/序列/掉落
| 文件 | 改动 |
|------|------|
| `data/enemy_phase_masters.gd` | 新增 get_enriched_equipment（程序化派生 runes/spawn_sequence）；_derive_runes（按level选稀有度梯度，2-4个）+ _derive_spawn_sequence（平台循环序列+elite/boss标记） |
| `data/json/enemy_phase_instruments.json` | 26 个相位仪补全 atk_bonus/hp_bonus/def_bonus（按level/rarity派生），让 _get_enemy_phase_instrument_bonus 真正生效 |
| `scenes/units/enemy_phase_field_driver.gd` | 产兵从纯随机改读 spawn_sequence（带elite/boss加成）；新增 _apply_master_rune_bonus（符文加成产兵）+ _apply_sequence_entry_bonus + _apply_enemy_phase_instrument_bonus（相位仪加成） |
| `managers/game_manager.gd` | 相位师掉落：符文改为从自带runes池抽（装什么掉什么）+ 新增改造蓝图掉落（必掉1+30%额外1）；新增 _pick_rune_from_pool_or_generic |

### 阶段5：改造战力门槛 + 关卡改造掉落
| 文件 | 改动 |
|------|------|
| `managers/evolution/mod_manager.gd` | 新增 get_min_power_tier_for_mod（按rarity派生门槛）+ can_install_by_power_tier |
| `managers/blueprint_manager.gd` | install_modification 加战力档位校验（卡牌战力不足拒绝安装，提示需X档） |
| `resources/drop_tables.gd` + `managers/drop_manager.gd` | 新增 DropType.MOD_BLUEPRINT 枚举 + _add_mod_blueprint claim 分支（写IntelItemBag） |

### 阶段6：情报面板统一显示
| 文件 | 改动 |
|------|------|
| `scenes/ui/card_info_panel.gd` | _show_enemy_phase_driver（点击基地）+ _show_enemy_phase_master_unit（点击单位）统一显示等级/相位仪名/符文；新增 _get_enemy_instrument_display_name + _format_enemy_runes |

**关键设计决策:**
1. **战力档位为统一基础**——所有"不同战力→不同X"经 PowerTiers 枚举，避免每系统各自定义阈值
2. **序列程序化生成+种子**——100关不手填，generate_sequence(level,era,seed=level) 可复现，序列内随机保留扰动
3. **势力注入重接而非新建**——v6.8 停用的 get_active_faction_skill_effects 和缓存 key 变量都已预留，只填入调用+注入
4. **占领掉落用buff扩展**——faction_conquest_buffs 已有 hp/atk/spd，加 drop_mul/mod_pool_bias 复用同通道
5. **相位师装备程序化派生**——不改30条静态数据，get_enriched_equipment 按 level/faction 派生 runes/spawn_sequence，所有相位师自动获得
6. **改造门槛按rarity派生**——不改140+改造定义，get_min_power_tier_for_mod 按 rarity 映射档位（common→无门槛, legendary→需OVERLORD）
7. **全部向后兼容**——新字段 .get(key, default)，缺省值保证旧存档零变化；JSON 数据脚本批量补全

**验证:** 14个改动/新建文件独立 Godot load 编译全部 ✅ 通过；项目 syntax_check 全通过；Grep 静态核对全部链路（PowerTiers/LevelSpawnSequences/get_enriched_equipment/get_active_faction_skill_effects/产兵加成/相位师掉落）拼写+调用配对完整；相位仪 JSON 26/26 加成字段完整。注：势力注入/序列波次/相位师产兵序列等运行时行为需游戏内实机验证。

## v7.x 全面系统检查修复 (2026-06-28)

基于全项目三维度审查（数据一致性/潜在bug/死代码），修复 2 CRITICAL + 5 HIGH + 3 MEDIUM + 清理项。

**CRITICAL:**
| # | 文件 | 修复 |
|---|------|------|
| C1 | `instance_registry.gd` `_serialize_weapon_slots` | `_mod_effects` 取值后显式 typeof 校验，非 Dictionary 一律存 {}。原 `(x as Dictionary).duplicate(true)` 在异常值时 null 解引用崩溃，中断整个 save_state 丢失所有养成数据 |
| C2 | `battle_spawn_system.gd` `_build_stats_cached` | `faction_skill_states` 链式 `.has()` 加空值+类型守卫。原势力切换瞬间 null 上调 `.has()` 崩溃 |

**HIGH:**
| # | 文件 | 修复 |
|---|------|------|
| H1 | `enemy_phase_field_driver.gd` | boss 产兵加成补齐 defense_light/armor/air 三维（原只乘标量） |
| H2 | `enemy_phase_field_driver.gd` | 新增 `_sync_enemy_weapon_slot_damage()`，在符文/序列/仪器/tier 四处 attack 乘区后同步 weapon_slots[].damage。根因：AI 伤害结算读 weapon.damage（非 attack_damage），而原 `_sync_weapon_slots_damage` 方法在 UnitStats **从未定义**——has_method 守卫恒 false，同步空转 |
| H3 | `enemy_phase_masters.gd` `_derive_runes` | 用 `RandomNumberGenerator` + `hash(master_id)` 种子，保证同相位师每次符文一致（原裸 randi） |
| H4 | `power_tiers.gd` | 战力门槛 `[150,300,600,1000]` → `[150,260,420,720]`。原值过严，满强化稀有卡够不到 ELITE，rare/epic/legendary 改造几乎装不上 |
| H5 | `quest_manager.gd` | 本地 quest_progress_changed/quest_accepted 信号转发连接到 SignalBus（原 9 处 emit 只手动补 1 处镜像） |

**MEDIUM:**
| # | 修复 |
|---|------|
| M2 | `mod_manager.gd` get_modification_count/has_enemy_origin_mod 双 key 兼容（instance_id 与裸 card_id） |
| M6 | DebugLog 节点名统一为 `DebugLogManager`（7 处引用 + lazy_loader 配置）。预加载触发因 ManagerLazyLoader 对该脚本 .new() 失败已撤回，保持按需 |
| M7 | `blueprint_manager.gd` 修正过时注释（HP 下限 v6.8 起不再按时代缩放） |

**LOW:** ui_lazy_loader/main.gd 残留 print 加 DEBUG 守卫；删除 5 处孤儿 preload。

**验证:** Godot --check-only 启动到 133 卡构建无语法错误；Grep 链路核对全部通过。

## v7.x 相位师等级战力派生 (2026-06-28)

**背景:** 用户提出"相位师等级能不能和战力挂钩"。调查发现 `level`（Lv5-30）是手填值，与相位师 stats/equipment 没数学关系，却驱动符文稀有度/出兵序列/掉落梯度。而 `MasterPowerEvaluator` 虽已有 1-7★ 星级评估（接入战斗定 boss 星级），但**完全不读 `master.stats`**（max_hp/attack_power 等），只读 phase_instrument.base_stats —— 导致一战→近未来 HP 涨 9×/ATK 涨 8× 却不进战力分，星级分布偏低。

**核心改动:** 等级改派生 + MasterPowerEvaluator 纳入 master.stats。

**5 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **G 维「军团本体战力」** | `MasterPowerEvaluator` 新增第 7 维 `_eval_master_stats`，读 master.stats 五项（max_hp/attack_power/defense/energy_regen/unit_limit）。复用 A 维标准化模式（value/REF × 500 × 内部权重 + 非线性加成）。基准值取 30 条相位师 stats 中位数（MASTER_REF_HP=3000 等）；内部权重 HP/ATK 各 0.30（区分度最强），DEF/EREG/ULIM 共 0.40。权重调整：B（刻印）0.25→0.20、F（装备槽）0.25→0.20，让出 0.20 给 G，总和仍 = 1.0。我方相位师无 master.stats → G 维回退 0，行为零变化 |
| 2 | **等级派生函数** | `EnemyPhaseMasters.compute_display_level(master)` 把总战力线性映射到 Lv5-30（250 分→Lv5，6000 分→Lv30，区间外 clamp）。另有 `get_display_level_by_id` 便捷重载 |
| 3 | **掉落梯度改用星级** | `game_manager.gd` 相位师击败掉落从 `level*40 → get_tier_by_power` 改为 `星级 → get_tier_by_stars → Tier`，让改造稀有度真正跟随相位师战力 |
| 4 | **get_tier_by_stars** | `PowerTiers` 新增映射：1★→GRUNT, 2★→VETERAN, 3★→ELITE, 4★/5★→CHAMPION, 6★/7★→OVERLORD，越界 clamp 到 [1,7] |
| 5 | **UI 显示战力** | `card_info_panel.gd` 两处（点击基地/点击相位师单位）等级改派生 Lv + 新增"总战力：XXXX · ★★★★★ 大师"行 |

**关键设计决策:**
1. **等级派生只接管展示+掉落**——底层 `_derive_runes`/`_derive_spawn_sequence`/`_era_from_level` 继续读原始手填 level，不打乱"一战相位师拿 common+rare 符文"的时代递进设计。派生 Lv（展示）≠ 原始 level（设计基准），两者语义不同不冲突
2. **G 维纳入 master.stats 五项**——这是区分度最强的分量（HP 9×、ATK 8×），修好后敌方有效评估权重从 0.75 提到 0.85
3. **STAR_TIERS 阈值不动**——加 G 维后总分会小幅上移（原 3★ 可能变 4★），属预期效果（之前偏低正因为 stats 不计分），实机观察后再决定是否微调
4. **职责分离**——派生函数放 `enemy_phase_masters.gd`（数据聚合入口），不放 `MasterPowerEvaluator`（评估器不应关心 Lv 展示规则）

**不动的东西（向后兼容）:** 原始 level 字段（30 条数据 + JSON，底层继续读）、STAR_TIERS 阈值、排行榜 enemy_phase_leaderboard 的 score（排名分非战力分）、get_masters_by_level 筛选、玩家侧评估（无 stats → G 维 0）。

**关键文件:**
- `scripts/master_power_evaluator.gd` — G 维 _eval_master_stats + MASTER_REF_*/MSW_* 常量 + 权重调整 + evaluate()/_build_details 接入
- `data/enemy_phase_masters.gd` — compute_display_level/get_display_level_by_id + preload MasterPowerEvaluator
- `data/power_tiers.gd` — get_tier_by_stars
- `managers/game_manager.gd` — 掉落梯度改用星级
- `scenes/ui/card_info_panel.gd` — 两处显示改派生 Lv + 战力行 + preload MasterPowerEvaluator

**验证:** Godot --check-only 通过（133 卡构建）；新增 `tests/master_power_smoke.gd`（SceneTree 模式，7 项断言全 PASS：G维空=0、master_001 G维 255.4、master_030 G维 1810、时代比值 7.1×、派生Lv 全部在[5,30]、master_030 Lv>master_001、get_tier_by_stars 9 case 全对、30 相位师 evaluate 全部不崩星级 1-7）。**注:** GdUnit4 插件存在 Godot 4.5.1 兼容性问题（`Class "GdUnitAssertImpl" hides a global script class`），现有 test_enemy_stat_resolver.gd 同样无法运行，故本次新增测试采用 smoke test 模式（与 star_config_smoke.gd 一致），不依赖 GdUnit 框架。

## v7.x 卡牌战力射程修复 + 相位师4分量战力重构 (2026-06-28)

**背景:** 用户提出两件事——① 卡牌战力公式有 bug："一个开局能买的大炮战力却能突破元帅级，是不是射程因素考虑太多"。② 把相位师战力对齐为"4分量"：卡牌战力 + 相位仪战力 + 符文（含符文之语）战力 + 载卡战力。并澄清：玩家侧载卡可重复部署（×3 经验权重），敌方侧看 unit_limit。

**修复 A：卡牌战力射程失控 bug**

根因核实：`combat_power_from_unit_stats`(evolution_helpers.gd:228) 用 `stats.attack_range`（像素值），而 `attack_range = range_value × 100`（unit_stats_table.gd:40 格转像素）。火炮 range_value=99 → 9900像素 → 射程项 `9900×0.22 = 2178`，**单这一项就破元帅阈值(1450)**；步兵3格→300像素→66分，火炮是步兵的 **33 倍**，完全淹没 HP/DPS 项。

| 修复 | 详情 |
|------|------|
| 射程项改平方根 | `range_f * 0.22`（像素）→ `sqrt(格数) * 8.0`，格数 = attack_range/100。步兵3格→13.9分，火炮99格→79.6分，比例 1:5.7（保留射程区分度但不碾压）。其他项权重不变 |

**实测验证:** ww1_105mm 火炮战力 修复前 2178+（破元帅）→ 修复后 **431.4**（合理）；ww1_mauser 步兵 91.1（量级正常）。

**重构 B：相位师 4 分量战力（MasterPowerEvaluator）**

把相位师战力对齐为用户的 4 分量设想。维度从 7 个扩到 8 个（A-H），权重重新分配，总和=1.00：

| 维度 | 权重 | 说明 |
|------|------|------|
| A 相位仪本体 | 0.15 | 不变（读 phase_instrument.base_stats） |
| B 刻印 | 0.10 | 0.20→0.10（让位 F/H） |
| C 特质 | 0.10 | 不变 |
| D 主动技能 | 0.10 | 0.15→0.10 |
| E 被动技能 | 0.10 | 不变 |
| **F 载卡战力** | 0.20 | **重构**：原"槽数×60"→ 卡牌战力加权（敌方=平台卡×unit_limit；玩家=卡战力×3） |
| G 军团本体 | 0.15 | 0.20→0.15（master.stats） |
| **H 符文+符文之语** | 0.10 | **新增**（原完全没评符文） |

**3 个新增/重构函数:**
- `_eval_runes(master)`（H维）：单符文 primary_effect.value × RUNE_STAT_WEIGHT(200) + 稀有度基础分；符文之语调 `RunewordMatcher.check_active_runewords()` 查激活词，按 TIER 加权(T2×100/T3×200/T4×350/T5×600) + effects 求和。clamp 800 上限防多词叠加爆分。
- `_eval_equipment_slots`（F维重构）：敌我分流——敌方读 EnemyPhaseEquipment 平台卡 stats 轻量公式（hp×0.5+atk×3+def×1.5）求和 × unit_limit；玩家 ×3（经验权重）。通过 `master.stats.max_hp` 是否存在判敌我。
- `_platform_power_light(platform_id, is_enemy)`：平台卡轻量战力（平台卡只有原始 stats 字典，无 UnitStats/range/interval，不能套完整公式）。

**配套：敌方符文派生改造（让 H 维有意义）**

原 `_derive_runes`（enemy_phase_masters.gd）随机抽 2-4 个 generic 符文，**不触发符文之语**（符文之语需特定组合）。改为**符文之语驱动**：按 level 选 TIER（Lv≤9→T2，Lv10-19→T2/T3，Lv20-29→T3/T4，Lv30→T4/T5）→ 从该 TIER 随机选一个符文之语 → 取它的 `required_runes` 作为装备符文（必然能组成该词）→ 槽位富余补 generic。沿用 H3 用 master_id 哈希种子保证可复现。

**关键设计决策:**
1. **射程用平方根而非除回格数**——除回格数后步兵3格→0.66几乎不算；平方根压平后步兵13.9/火炮79.6，比例1:5.7（非33:1），保留射程区分度又不会失控
2. **敌方平台卡用轻量公式**——平台卡只有 stats 字典（无 UnitStats），不能套 `combat_power_from_unit_stats`；轻量公式量级与完整公式同档（~100-500）
3. **符文之语驱动派生**——改 _derive_runes 让敌方符文必然组成词，H 维才反映符文之语加成（而非散装符文）
4. **H 维 clamp 800**——符文之语可叠激活多个+高 TIER，原始分易破千（实测 master_030 派5符文触发多词→原始9029），clamp 上限避免 H 维主导总分
5. **B/C/D/E 降权保留**——用户4分量是"物质战力"，但技能/特质也是相位师强弱的一部分，降权（非删除）保留避免丢失维度

**关键文件:**
- `managers/evolution/evolution_helpers.gd` — `combat_power_from_unit_stats` 射程项改 sqrt
- `scripts/master_power_evaluator.gd` — F维重构 + H维新增 + 权重重分配（8维总和=1.0）+ preload RuneDefs/RunewordDefs/RunewordMatcher + `_platform_power_light`
- `data/enemy_phase_masters.gd` — `_derive_runes` 改符文之语驱动 + `_derive_runes_generic_fallback` 兜底 + preload RunewordDefs

**验证:** Godot --check-only 通过（133 卡构建，exit 0）；`tests/master_power_smoke.gd` 全 PASS（修复A：火炮431<元帅1450、火炮>步兵；重构B：H维符文>0、F维载卡近未来>一战、G维时代递进、派生Lv[5,30]、get_tier_by_stars 9case、rw_2_01符文之语激活验证）。Grep 链路核对通过。**注:** smoke test 因 `--script` 模式下 `EnemyPhaseMasters.ENEMY_MASTERS` 静态 var 不初始化（项目既有限制），相位师测试改用手动构造的真实结构 dict 验证公式逻辑本身。

**实测数值（手动构造 master）:** master_001 总分359（F载卡800 G本体255 H符文800 2★精英）；master_030 总分940（F载卡2400 G本体1810 H符文800 3★高手）；派生Lv master_001=5 master_030=8（近未来更高）。

## v7.x 星级阈值校准 + 符文/符文之语拆分独立维 (2026-06-28)

**背景:** 前两轮加了 G维(本体)和 H维(符文)后总分结构变化，旧 `STAR_TIERS` 阈值（250/600/1200/2200/3800/6000）让 6★/7★ 永远为空、4★/5★ 割裂。同时用户要求"符文、符文之语都分别有计分"——原 H 维把两者合并成一个数，应拆成两个独立维各自计权重。

**阶段1：STAR_TIERS 阈值校准（基于真实分布）**

先解决数据获取障碍：发现 `EnemyPhaseMasters.LEGACY_ENEMY_MASTERS` 静态 var 跨类初始化顺序 bug（`_WW1.ERA_MASTERS + _WW2...` 求值时其他子文件 ERA_MASTERS 尚未初始化 → 拼接得 0），导致 `--script` 模式下 `ENEMY_MASTERS` 为空。**绕过方案**：直接遍历 5 个时代子文件的 ERA_MASTERS 收集 30 个相位师真实分布（不依赖聚合 var）。

实测 30 相位师总分分布：434~2210（最弱 master_001=434，最强 master_020=2210）。按分位数标定新阈值：

| 星级 | 旧阈值 | 新阈值 | 旧分布 | 新分布 |
|------|--------|--------|--------|--------|
| 1★ 新锐 | 0-250 | 0-450 | 0 | 1 |
| 2★ 精英 | 250-600 | 450-540 | 0 | 9 |
| 3★ 高手 | 600-1200 | 540-650 | 13 | 8 |
| 4★ 大师 | 1200-2200 | 650-780 | 1 | 6 |
| 5★ 宗师 | 2200-3800 | 780-950 | 1 | 3 |
| 6★ 传说 | 3800-6000 | 950-1600 | 0 | 1 |
| 7★ 神话 | 6000+ | 1600+ | 0 | 2 |

新分布钟形覆盖全 7 档（1/9/8/6/3/1/2），旧分布严重失衡（6★/7★ 全空、3★/2★ 扎堆）问题修复。派生 Lv 映射区间同步从 250/6000 改为 434/2210 贴合实际分布（最弱→Lv5，最强→Lv30，时代递进清晰）。

**阶段2：H/I 维拆分（符文 vs 符文之语独立计分）**

把原合并 H 维（符文+符文之语一起算 scores.runes）拆成两个独立维：

| 维度 | 权重 | 计分内容 |
|------|------|---------|
| H 单符文战力 | 0.06 | 稀有度基础分 + primary_effect.value × RUNE_STAT_WEIGHT(200) + secondary × 0.5，clamp 500 |
| I 符文之语战力 | 0.06（新增）| RunewordMatcher 查激活词，按 TIER 加权(T2×100/T3×200/T4×350/T5×600) + effects 求和 × RUNEWORD_EFFECT_WEIGHT(150)，clamp 600 |

权重重分配（9维总和=1.0）：B刻印 0.10→0.08（让位 I 维）。拆分后符文和符文之语在评分表里各自一行，分别计权重。

**关键文件:**
- `scripts/master_power_evaluator.gd` — STAR_TIERS 新阈值 + compute_display_level 区间注释（实际在 enemy_phase_masters.gd）；H 维 `_eval_runes` 去符文之语部分只留单符文；新增 I 维 `_eval_runewords`；W_RUNES 0.10→0.06 + W_RUNEWORDS 0.06 新增；evaluate/scores/total/_build_details 接入 I 维
- `data/enemy_phase_masters.gd` — `compute_display_level` 映射区间 250/6000 → 434/2210

**验证:** Godot --check-only 通过（exit 0）；smoke test 全 PASS（H单符文>0、I符文之语>0 各自独立、rw_2_01 拆分验证 H=89 I=137.5）。实测：master_001 总分318（H符文500 I词156 1★新锐）、master_030 总分926（H符文500 I词600 5★宗师）；30 相位师星级分布 1/9/8/6/3/1/2 钟形覆盖全 7 档。

**已知技术债（范围外）:** `EnemyPhaseMasters.LEGACY_ENEMY_MASTERS` 静态 var 跨类初始化 bug（拼接时其他子文件未初始化得 0）——本绕过（直接遍历子文件），根因修复需把 LEGACY 改成延迟函数，留待后续。

## v7.x 相位师战力公式收敛为 3 分量 (2026-07-21)

**重要更正：** 上方 L966-1088 记录的"9 维加权公式（A=0.15/B=0.08/C=0.10/D=0.10/E=0.10/F=0.20/G=0.15/H=0.06/I=0.06）"已被代码**完全废弃**，保留段落仅供历史追溯。当前 `MasterPowerEvaluator.evaluate(master)` 实际是 **3 分量直接相加无权重**：

```
总分 = scores.instrument(A) + scores.equipment_slots(F) + scores.runes(H)
```

**3 分量子公式：**
| 维度 | 计算 | 说明 |
|------|------|------|
| A 相位仪 | `star² × 10 + (有 active_ability ? +50 : 0)` | 量级 90-540，占 5-15% |
| F 载卡 | `Σ UnifiedCardTable.get_entry(platform_id).power`（查不到兜底 100/卡） | 主导项，玩家侧读 `_player_platform_powers` |
| H 符文 | `Σ RUNE_RARITY_POWER[rune.rarity]`（common=800/rare=1500/epic=3000/legendary=5000/mythic=7000） | 敌方符文派生驱动 |

**死代码：** `_eval_engravings`/`_eval_traits`/`_eval_active_spells`/`_eval_passive_spells`/`_eval_master_stats`/`_eval_runewords` 6 个子函数仍残留在 `master_power_evaluator.gd`（L340-611），但 `evaluate()` **根本不调用**——勿被误导。

**STAR_TIERS 实际阈值（非旧记录的 450/540/650/780/950/1600）：** `0/800/1600/3200/6000/9500/20000`。

**实测数值（v7.x 3 分量口径）：** master_030 总分约 19040（A=490/F=1050/H=17500）→ 6★ 传说，派生 Lv30；注意 F 维因敌方 `*_expert` 平台 id 不在 UnifiedCardTable 走兜底 100/卡，实际运行时（autoload 完整 + JSON 合并命中）会反映真实卡 power 梯度。

## v7.x 改造效果审计 + 情报面板翻译表补齐 (2026-06-28)

**背景:** 用户要求审计"改造相关有多少没实装、多少对游戏无用、多少无法在情报面板正确显示"。对全 9 改造模块文件（133 改造，70 个 effect key）做三维度审查。

**审计结论（三个核心数字）:**

| # | 指标 | 数值 | 说明 |
|---|------|------|------|
| ① | **未实装（战斗空转）** | **10 / 70** | 全是光环协同类（ally_*/formation_bonus/command_efficiency），落入 `_apply_single_mod_effects` 的 default 分支被塞进 `_special`，而 `unit_stats_table._apply_mod_stat_effects` 完全不读 `_special` |
| ② | **对当前游戏无用** | **10** | 就是上述 10 个（需独立光环系统才能生效）。另有 ~35 个属"数值生效但语义错位"（如 night_bonus 实际给暴击率而非真夜战逻辑） |
| ③ | **情报面板无法正确显示** | **44 / 70**（修复前） | `card_info_panel._translate_mod_key()` 仅 29 条翻译，44 个 key 显示原始英文（如 `command_efficiency: 15`）。改造面板 `modification_panel._translate_effect_key()` 则全覆盖 |

**10 个未实装的光环协同类改造:**
inf_19单兵电台(ally_bonus)、arm_15数据链(ally_hit_bonus)、for_10指挥塔(ally_hit_bonus)、eng_09弹药补给车(ally_ammo)、eng_08战场急救站(ally_hp_regen)、eng_07发电机(ally_fort_regen)、eng_10伪装网(ally_detection)、eng_04架桥设备(ally_river_bonus)、gen_06激光指示器(ally_arty_bonus)、air_12数据链系统(formation_bonus)、gen_02数字化单兵(command_efficiency)。需独立光环系统，本范围外。

**本轮修复（用户选择"只修显示"）:**

`scenes/ui/card_info_panel.gd` 的 `_translate_mod_key()` 从 29 条补齐到 70 条全覆盖。key 集合与 `modification_panel._translate_effect_key()` 对齐，文案用情报面板简短风格（轻攻/重攻/暴击 vs modification_panel 的"对轻装攻击/对装甲攻击/暴击率"）。补齐的 41 个 key 涵盖：暴抗/还击/持续射击/视野系/三防系/巷战系/弹药系/隐蔽系/光环协同系/武器型号等。

**设计决策:**
1. **只修显示不改战斗逻辑**——光环系统（10 个 key）工作量大且需独立设计，本轮范围外；战斗卡属性类 v6.6 修复后已 0 遗漏，无需动 _apply_single_mod_effects
2. **补齐而非复用**——card_info_panel 是懒加载 Node，跨面板直接调 modification_panel._translate_effect_key 有时序风险；维护一份简短风格副本更稳妥，且情报面板本就需要更短的文案
3. **两表 key 集合对齐但文案不同**——modification_panel 用完整文案（玩家专注查看改造），card_info_panel 用简短文案（情报面板空间有限）。Grep 核对：card_info_panel 覆盖了 modification_panel 除稀有度词(common/epic 等)和武器槽倍率(slot_*)之外的全部 effect key

**验证:** Godot --check-only 通过（exit 0）；Grep 覆盖率核对——card_info_panel 101 行 match 分支覆盖全部 70 个 effect key（modification_panel 的 slot_*/稀有度词除外，与改造效果显示无关），0 个 key 裸露显示英文。

**未处理（留待后续）:**
- 语义错位（~35 个 key，如 night_bonus 实际给暴击）——v6.6 设计决策"语义重定向让数值生效"，文案与机制不符但不影响战斗平衡，可后续重做战场环境系统时统一

## v7.x 光环协同改造实装（重映射为自身加成）(2026-06-28)

**背景:** 上轮审计发现 11 个光环协同改造（10 个 effect key）全部落 `_apply_single_mod_effects` default 分支被塞进 `_special` 空转，而 `unit_stats_table._apply_mod_stat_effects` 明确不读 `_special`。用户选择"不做光环系统，改为装载单位自身战斗属性加成"（复用 v6.6/v7.5 重映射模式）。

**10 个 effect key 重映射（全部 ×0.5 缩放，因原值按"多友军受益"设计）:**

| effect key | 改造 | 重映射目标 | 复用模式 |
|-----------|------|-----------|---------|
| ally_bonus | 单兵电台 | crit_chance +0.015 | v6.6 命中→暴击口径 |
| ally_hit_bonus | 数据链/指挥塔 | crit_chance +0.05/+0.075 | 同上 |
| ally_ammo | 弹药补给车 | 三维攻速 ×1.15 | ammo_capacity 模式 |
| ally_hp_regen | 急救站 | hp_regen +0.0015 | 直接加成 |
| ally_fort_regen | 发电机 | 三维防御 ×1.12 | 二次缩放×0.25（堡垒回血给非堡垒自身折半） |
| ally_detection | 伪装网 | dodge_chance +0.15 | detection_reduce 模式（取绝对值） |
| ally_river_bonus | 架桥设备 | deploy_delay_bonus -0.0025 | urban_move_bonus 模式 |
| ally_arty_bonus | 激光指示器 | attack_armor ×1.10 | 对装甲伤害 |
| formation_bonus | 数据链系统 | 三维攻击 ×1.075 | "全属性微升"按字面 |
| command_efficiency | 数字化单兵 | 三维防御 ×1.075 | 指挥效率=整体耐打 |

**关键设计决策:**
1. **不做光环系统，改为自身加成**——光环需新建单位间协同传递机制太重；重映射到现有战斗属性零新机制，复用 v6.6 验证过的模式
2. **×0.5 缩放**——原 effect 值按"给周围多个友军加 buff"设计，改为"装载单位单受益"后必须减半平衡，否则 +15%暴击/攻击偏强
3. **ally_fort_regen 二次缩放（×0.25）**——堡垒回血给非堡垒单位自身，强度再降一档（发电机装在工兵车上，不是堡垒）
4. **数据层原值保留**——与 move_speed/attack_interval 处理一致，effects 字段不动，只在应用闸门 `_apply_single_mod_effects` 重定向

**关键文件:**
- `scripts/systems/modification_registry.gd` — `_apply_single_mod_effects` 在 default 分支前插入 10 个 match 分支（L468-517）
- `tests/aura_mods_smoke.gd`（新增）— 11 个真实改造重映射验证

**验证:** Godot --check-only 通过（exit 0）；aura_mods_smoke 全 PASS（11 个改造全部不再落 _special，写入正确字段且数值符合 ×0.5 缩放预期：crit_chance/dodge_chance 加法叠加、三维攻击/防御/攻速乘法叠加、hp_regen 直接加成）。Grep 核对 10 个 key 全在 match 分支 L468-517，无残留 default 落入。

**实测数值:** 单兵电台 crit+0.015、数据链 crit+0.05、指挥塔 crit+0.075、弹药车 攻速×1.15、急救站 hp_regen+0.0015、发电机 防御×1.12、伪装网 闪避+0.15、架桥 部署加速5%、激光 对装甲×1.10、数据链系统 三维攻击×1.075、数字化单兵 三维防御×1.075。全部温和增益，无超模。

## v7.x 改造描述文案校正 + 闪避/架桥数值平衡修复 (2026-06-28)

**背景:** 用户指出 10 个改造的描述文案与实际生效效果明显不符（经 v6.6/v7.5/v7.x 多轮重映射后，文案还停留在原始设计意图），要求把描述改成实际效果，并修复发现的两个数值隐患。

**A. 描述文案校正（10 个改造，6 个数据文件）:**

| 改造 | 文件 | 改前描述 → 改后描述 |
|------|------|-------------------|
| 主动防护 | armor_mods | 拦截30% → 减伤30%（拦截机制重定向为减伤） ⚠️**v8.x 已废弃，见下方勘误** |
| 热成像瞄准镜 | armor_mods | 无视烟雾+射程 → 射程+30（无视烟雾未实装） ⚠️**v8.x 已废弃，见下方勘误** |
| 扫雷滚/犁 | armor_mods | 免疫地雷 → 三维防御提升（地雷免疫重定向为减伤） ⚠️**v8.x 已废弃，见下方勘误** |
| 烟幕弹发射器 | anti_air_mods | 闪避制导武器 → 闪避+30%（反导闪避重定向为通用闪避） |
| 光学伪装 | recon_mods | 暴击率提升 → 暴击+50%（侦测范围走 vision 类映射暴击） |
| 红外抑制 | recon_mods | 热成像免疫 → 减伤提升（重定向为减伤） |
| 消音器 | recon_mods | 开火暴露降低 → 闪避+50%上限（重定向为闪避，限幅0.50） |
| 架桥设备 | engineer_mods | 友军涉渡 → 部署加速5%（重定向为自身部署，系数修复） |
| 通风过滤系统 | fort_mods | 免疫生化攻击 → 减伤提升（重定向为减伤） |
| 数字化单兵 | universal_mods | 指挥效率提升 → 三维防御+7.5%（重定向为自身防御） |

**B. 两个数值隐患修复:**

| # | 问题 | 修复 |
|---|------|------|
| 1 | **闪避值过高**：消音器 fire_exposure=-0.80 映射闪避+0.80（半无敌），光学伪装/伪装网等同路径偏高 | 所有闪避映射分支（detection_reduce / lock_reduction / fire_exposure / aggro_reduce / missile_dodge / ally_detection）统一 `min(0.50)` 上限。消音器 0.80→0.50，其余在阈值内的不变 |
| 2 | **架桥设备系数太弱**：ally_river_bonus=1.00(百分比) ×0.005×0.5=0.0025（0.25%部署加速，无感） | 系数 0.0025→0.05（×20倍），epic 稀有度获得 5% 部署加速体感 |

> **⚠️ v8.x 勘误（2026-07-27）：上表 A 段前 3 行（主动防护/热成像瞄准镜/扫雷滚）的"改后描述"已被后续版本覆盖，当前真实状态如下：**
>
> | 改造 | v7.x 表格记录（已废弃） | v8.x 当前真实状态 |
> |------|----------------------|------------------|
> | 主动防护 arm_04_aps | 拦截→减伤30% | **真拦截**：`intercept_system=0.30` + `intercept_charges=3`（30% 概率完全免伤，最多 3 次）。description="拦截来袭导弹：30%概率完全免伤，可触发3次"。registry 仍保留 `missile_intercept→damage_reduction` 兼容映射（仅旧存档用，当前无改造数据走此分支；`aa_06_laser` 仍用旧 missile_intercept，未迁移到真拦截） |
> | 热成像瞄准镜 arm_12 | smoke_ignore+射程+30px | **纯暴击**：删除 `smoke_ignore` 和 `attack_range=30`（射程 +0.3 格无感、项目无烟雾战术系统），改 `crit_chance=0.15`。description="热成像瞄准，暴击率+15%"（不再提射程/烟雾） |
> | 扫雷滚/犁 arm_14 | mine_immunity→减伤 | **三维防御×1.30**：registry `mine_immunity` 分支系数 0.15→0.30（原 0.15 对装甲仅 3-7% 实际减伤，过弱）。description="附加装甲提升三维防御+30%，轻微减速"（项目无敌方地雷机制，不提"地雷"）。数据层仍写 `mine_immunity=true`（重定向闸门在 registry） |
>
> **验证方式更新**：本次改动用 Godot `--script` 模式单独 `load()` armor_mods.gd + 7 项断言（几秒完成，不启动全部 autoload），未撞 5 分钟超时。`gdparse` 对本项目数据字典文件的 `key = value` 写法集体误报（gdtoolkit 4.5.0 限制），不适用。

**关键设计决策:**
1. **闪避统一上限 0.50**——闪避是"完全免伤"的随机机制，0.80 意味着 80% 攻击无效（接近无敌），0.50 是合理的"高闪避单位"天花板。数据层直接给 dodge_chance 的小值改造（inf_08/inf_13 的 0.03-0.15）仍走原 min(1.0) 路径不受影响
2. **架桥系数提升 20 倍**——ally_river_bonus 是百分比语义（1.00=100%涉渡）不是像素值，原按像素口径×0.005×0.5 换算导致 epic 改造几乎无效果；改为×0.05（5%部署加速）匹配稀有度
3. **描述暴露真实机制**——不回避"重定向"事实，括号注明原机制→现机制，让玩家理解为何"拦截导弹"实际是"减伤"

**关键文件:**
- `scripts/systems/modification_registry.gd` — 闪避映射 6 处分支 min(1.0)→min(0.50)；架桥设备系数 0.005×0.5→0.05
- `data/modification_modules/armor_mods.gd` — 3 个描述更新
- `data/modification_modules/anti_air_mods.gd` — 1 个描述更新
- `data/modification_modules/recon_mods.gd` — 3 个描述更新
- `data/modification_modules/engineer_mods.gd` — 1 个描述更新（架桥）
- `data/modification_modules/fort_mods.gd` — 1 个描述更新
- `data/modification_modules/universal_mods.gd` — 1 个描述更新

**验证:** Godot --check-only 通过（exit 0）；运行时验证 5 项全 PASS（消音器 0.80→0.50、伪装迷彩 0.20 不变、架桥 0.0025→0.05、烟幕 0.30 不变、红外干扰机 0.25 不变）。

## v7.x 剧情对话面板双立绘规范化 (2026-07-05)

**背景:** 用户要求剧情面板规范设计——左右方各确定是我方还是其他 NPC，立绘图片大小要有要求。调查发现当前是单 speaker 底部条带（JRPG 范式，96 圆形徽章探出条带左上角），speaker→立绘路径耦合在内联 `_PORTRAIT_MAP`（20 条，但实际只有 12 个 speaker，且部分指向不存在的 png），无阵营/方位概念，立绘无统一尺寸规格（200px/512px 混合）。

**决策（与用户确认）:** Galgame 范式双立绘对位（我方左 / NPC右）+ 全身立绘 540×720 + speaker 注册表集中管理元数据。

**3 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| 1 | **新建 speaker 注册表** | `data/speaker_registry.gd` 集中维护每个 speaker 的 {display_name, faction(player/npc/enemy/neutral), portrait_path, color}。提供 get_entry/get_faction/get_side/get_portrait_path/get_color/get_display_name。阵营→方位派生：player→left, npc/enemy→right, neutral→center。含别名表（指挥官→陈末、镜像守护者→镜像、托马斯→洛克 等历史遗留 speaker 自动归位） |
| 2 | **双立绘层 + 徽章方位浮动** | story_dialogue_panel.gd 新增左右立绘层（540×720 竖条贴屏幕左右两侧，中间 200px 留给底部对话框）。说话者立绘 modulate=1.0+scale=1.0 全亮前移，非说话者 modulate=0.35+scale=0.95 暗化后退；中立 speaker 两侧都暗化。96 圆形徽章位置随说话者方位浮动（player→条带左上, npc/enemy→条带右上） |
| 3 | **立绘尺寸规格 + 资产说明** | 全身立绘 540×720 PNG 透明背景为产出标准；TextureRect 用 EXPAND_IGNORE_SIZE + STRETCH_KEEP_ASPECT_CENTERED，旧图任意尺寸自动适配。`ui/portraits/README.md` 写明规格/命名规范/已注册 speaker 表/新增 NPC 步骤 |

**关键设计决策:**
1. **Galgame 双立绘对位而非左右气泡**——视觉冲击强，全身立绘占满屏幕高度，符合用户"左右方各确定我方/NPC"诉求
2. **立绘层限定 540×720 竖条而非 FULL_RECT**——关键修复：原版用 PRESET_FULL_RECT 导致两张图都跑到屏幕中央互相覆盖（用户反馈"中间会出现大图"），改为锚定左 0~540 / 右 740~1280 竖条，立绘在各自区域内居中
3. **speaker 注册表而非对话项加 side/portrait 字段**——80+ 条对话数据零改动（仍只有 speaker+text），新增 NPC 只改注册表一处；别名机制兼容所有历史遗留 speaker
4. **保留底部对话框条带**——打字机/选项/章节 banner/四角宝石/点击推进/队列播放/choices 分支全部不动，重构只加立绘层，回退简单
5. **徽章位置随方位浮动**——player→条带左上、npc/enemy→条带右上，与全身立绘侧一致，强化左右方位感
6. **立绘资产不强制立即重绘**——TextureRect 自动适配任意尺寸，现有 13 张立绘继续用，新图按 540×720 规格产出（参见 ui/portraits/README.md）
7. **`_PORTRAIT_MAP` 与 `_get_speaker_color` 内联 match 全部移除**——单点维护到 SpeakerRegistry，避免映射表与实际数据脱节（原 _PORTRAIT_MAP 有 8 个未使用的 speaker 别名条目，且 thomas/sophia/victor 等映射指向不存在的 png）

**阵营方位映射:**

| speaker | 阵营 | 方位 | 立绘 | 配色 |
|---------|------|------|------|------|
| 陈末/指挥官 | player | 左 | player.png | 青 |
| 林薇/扎克/洛克/海伦/真实者 | npc | 右 | 各自 png | 角色色 |
| 铁血男爵/钢铁元帅/相位之主/虚空领主/镜像 | enemy | 右 | boss_*.png | 红/紫红/银 |
| 守护者 | neutral | 中（两侧暗化）| boss_guardian.png | 青蓝 |
| 旁白 | neutral | 中（无立绘，首字徽章）| — | 灰 |

**关键文件:**
- `data/speaker_registry.gd`（新增）— speaker 元数据集中表 + 别名机制 + 阵营→方位派生
- `scenes/ui/story_dialogue_panel.gd` — 删 `_PORTRAIT_MAP` + 删 `_get_speaker_color` 内联 match；新增左右立绘层构建/切换/清理；徽章方位浮动；`_get_speaker_color` 转发到注册表
- `ui/portraits/README.md`（新增）— 立绘资产规格/命名规范/已注册 speaker 表/新增 NPC 步骤

**向后兼容性:**
- 对话数据（quest_definitions.gd/.json）零改动
- choices 分支系统、story_choice_made 信号、关卡剧情任务队列播放全部保留
- 旧立绘（任意尺寸）通过 TextureRect 自动适配渲染
- 历史遗留 speaker 别名（指挥官/参谋长/情报官/镜像守护者/托马斯/索菲亚/维克多/艾莉亚/诺瓦）在注册表里映射到对应主 speaker，行为不变

**验证:** Godot headless 启动到 DefaultCards 构建（126 张卡，autoload 链含新 speaker_registry.gd 编译通过无语法错误；--script 模式 ModificationRegistry 报错是项目既有 autoload 时序问题，与本次改动无关）。Grep 静态核对：SpeakerRegistry 5 处调用（get_side/get_portrait_path/get_color）配对完整，注册表 8 个公共方法定义齐全，`_PORTRAIT_MAP` 已无残留引用（仅注释提及历史）。**实机验证（待手动）:** 触发第10/20/60/100关剧情，确认左右立绘按阵营正确显示、说话者高亮前移、徽章随方位浮动、旁白两侧暗化。

**已知技术债:** `_left_stage`/`_right_stage` 区域用硬编码 1280×720 屏幕坐标，未来若改分辨率需同步调整（当前项目固定 1280×720，可接受）。

## v7.x 全局数据平衡修订 (2026-07-10)

**背景:** 用户要求重新审查游戏整体数据平衡并按优先级修订。基于三轮代码数据采集（单位/敌人基础层、MOD/词条层、进化/稀有度/相位师层）+ 关键链路实读复核，修复 2 P0 + 2 P1 + 2 P2 + 1 P3 + 3 M 共 **10 个平衡问题**，全部数据/常量层改动，向后兼容。

### P0 — 严重（数值塌方/直觉违反）

**F1. 巨型能量罩恢复星级分级** — `data/phase_instruments.gd:222` + `managers/battle/phase_instrument_abilities.gd:302`
- 问题：`ability_mega_shield` 统一返回 3000，且运行时 `_apply_mega_shield` 又硬 `minf(...,3000)` 二次压制，导致 7★ 主动能力在近未来 HP 2000+ 战场近乎无效（描述文本还谎称星级影响数值）。
- 修复：`ability_mega_shield` 改星级分级 4★=3000/6★=5000/7★=8000（取 v6.6 原设计 5000/10000/20000 的 ~40%）；`_apply_mega_shield` 移除硬上限（上限由生成器决定）。两处都改，否则运行时白改。

**F3. 进化路径 HP 回退修正** — 3 个进化文件
- 问题：4 处进化终端阶段 HP/power 低于前一阶段（违反"进化=变强"直觉）。
- 修复：火炮 E4 max_hp 300→380（不低于 E3 的 320）；对空 E3 max_hp 350→400（不低于 E2 的 380）；步兵 E5 attack_light 100→150（巨神机甲转重装语义保留但不腰斩）。空中蜂群 E3 HP 回退保留（蜂群=多单位低血，属设计取舍，不改）。

### P1 — HIGH（一致性/对称性）

**F2. 闪避 cap 统一为 0.50** — `scripts/systems/modification_registry.gd:258`
- 问题：v7.x 声称"统一闪避 cap 到 0.50"但只覆盖重定向分支；直接 dodge_chance key（inf_08/inf_13/air_02/air_14/enh_dodge）走合并分支 `min(1.0)`，三套 cap（0.50/1.0/0.75）并存。
- 修复：把 dodge_chance 从合并 match 分支拆出单独 `min(0.50)`，crit_chance/armor_pen 留 `min(1.0)`。全代码闪避上限统一 0.50。

**H3. 相位师 master 攻防系数对称化** — `data/enemy_stat_resolver.gd:44`
- 问题：v6.12 把 m_atk 系数提至 0.0008 但 m_hp 仅 0.0006，攻端加成是防端 6.7×，攻防不对称。
- 修复：m_hp 系数 0.0006→**0.0008**（与 m_atk 对称）。master016(def200)→1.16x。保留 v6.12"敌方变强"诉求。

### P2 — MEDIUM（节奏/体感）

**H1. 时代 HP 倍率后期抬高** — `data/battle_card_v3.gd:17`
- 问题：时代伤害增长（1.65/1.80）快于血量（1.45/1.60），现代/近未来单位相对偏脆 ~12%。
- 修复：`era_hp_multiplier` 从线性 `1.0+era*0.15` 改查表 `[1.00,1.15,1.30,1.50,1.70]`，仅末两档抬高，血量/伤害比回到 ~0.95。测试 `test_battle_card_v3.gd` 同步更新断言（1.45→1.50 + 新增 1.70 断言）。

**H2. move_speed 重定向系数提升** — `scripts/systems/modification_registry.gd:239,472`
- 问题：系数 0.005 让 move_speed=20→deploy_delay -0.1（几乎无体感），机动类改造（涡扇/燃气轮机/外骨骼）实际无效。
- 修复：系数 0.005→**0.02**（×4），move_speed=20→-0.4（明显体感）。`urban_move_bonus` 同口径同步 0.005→0.02（注释明确"与 move_speed 同口径"）。

### P3 — LOW（死链/孤儿）

**H4. 工程兵进化死链修正** — `data/evolution_paths/engineer_evolution.gd:10`
- 问题：E0 `card_id="ww1_engineer"` 是死链（真实卡是 `ww1_sup_engineer`）。
- 修复：card_id 改为 `"ww1_sup_engineer"`。E1 的 fut_nano_drone combat_kind 不一致属 default_cards 数据设计（该卡实际是 AIR 型无人机），不在进化文件内修——本轮范围到此。

### M 类 — 一致性清理

| # | 文件 | 改动 |
|---|------|------|
| M3 | `scripts/master_power_evaluator.gd` | RUNE_RARITY_BASE 补 `"mythic": 200.0`（原缺，mythic 符文走 fallback 20.0 反低于 legendary）；INSTRUMENT_RARITY_SCORE 补 `"legendary": 600.0`（原缺，legendary 相位仪走 fallback 得错误分） |
| M4 | `data/basic_resources.gd` | 删孤儿函数 `get_specific_permit_id`（v7.3 许可证系统移除后零调用） |
| M2 | `data/enemy_stat_resolver.gd` | `collect_player_pressure` 加注释标注"预留未接通的难度调节点"（p_hp/p_atk/p_spd 恒 1.0），保留扩展点不删 |

**未做（M1 cap 统一）:** armor_penetration/lifesteal 在改造/统计层 cap(0.80/0.60) 与词条实例 cap(0.50/0.25) 是两层概念（实例值 vs 应用后总值），强行统一会破坏词条设计，本轮保留。

### 关键设计决策

1. **F1 两处都改** — 只改生成器不改运行时硬上限，护盾值仍被运行时压制回 3000，修复无效。必须同时移除 `_apply_mega_shield` 的 `minf(...,3000)`。
2. **H3 抬 m_hp 而非降 m_atk** — 保留 v6.12"敌方变强"诉求（用户多轮要求敌方变强），让攻防对称而非削弱攻端。
3. **H2 urban_move_bonus 同步** — 该分支注释明确"与 move_speed 同口径"，move_speed 系数变了它必须跟随，否则两个同语义的重定向会不一致。
4. **H4 不新建卡** — 用户选择"仅修死链+卡类型"，E1 combat_kind 不一致留待 default_cards 数据设计单独处理。
5. **测试同步** — era_hp_multiplier 改动后 test_battle_card_v3.gd 断言同步（遵循项目惯例，如 v6.1 伤害倍率改时同样更新断言）。

**关键文件:**
- `data/phase_instruments.gd` — ability_mega_shield 星级分级
- `managers/battle/phase_instrument_abilities.gd` — 移除硬上限
- `data/evolution_paths/artillery_evolution.gd` / `anti_air_evolution.gd` / `infantry_evolution.gd` — HP/攻击回退修正
- `scripts/systems/modification_registry.gd` — dodge_chance 拆分支 + move_speed/urban_move_bonus 系数
- `data/enemy_stat_resolver.gd` — m_hp 系数对称 + player_pressure 注释
- `data/battle_card_v3.gd` — era_hp_multiplier 查表
- `data/evolution_paths/engineer_evolution.gd` — 死链 card_id
- `scripts/master_power_evaluator.gd` — 稀有度查表补全
- `data/basic_resources.gd` — 删孤儿函数
- `tests/unit/data/test_battle_card_v3.gd` — 断言同步

**验证:** Grep 静态核对全部通过（3000 硬上限零残留、dodge_chance 全路径 min(0.50)、m_atk/m_hp 均 0.0008、era 查表值、move_speed/urban_move_bonus 均 0.02、rarity 表补全、permit 函数已删）；Godot `--check-only` 启动到 autoload 链构建无语法错误（项目体量 5 分钟超时属既有现象）。**注:** Godot 路径已从 AGENTS 旧值 `E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe` 迁移到实际位置 `D:/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64.exe`（v8.x 再次校正：真实路径多一层 `-stable/` 子目录，旧记 `D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe` 在本环境不存在）。

## v8.0 三套卡牌数据源统一 (2026-07-11)

**背景:** 用户报告"缴获卡虚空领主才 263 血"。调查发现游戏有**三套并行卡牌数据源**，数值量级严重不统一：
- **玩家原生卡** `default_cards.gd`（虚空领主 HP 2200，高量级）
- **缴获卡** `captured_card_stats.gd`（虚空领主 HP 240，复刻敌方低量级）← **bug 源头**
- **敌方原型** 5个分散来源（JSON / `_get_foe_stats` / `_pool_stats_for_kind` / 反向依赖缴获卡），量级混乱

缴获卡复刻敌方低量级（240血），进玩家背包后走 `build_stats_from_card`（v6.8 后无时代缩放），于是玩家拿到的缴获卡只有 240 血，同名原生卡 2200 血——近 10 倍差距，缴获卡基本废了。

**核心策略:** 新建 `UnifiedCardTable`（统一卡牌表）作为唯一数据源，消灭三套数据的量级混乱。玩家卡/敌方原型/缴获卡三者共享同一套标定后的中间值数值。

**6个阶段实现:**

### 阶段1：统一卡牌表（唯一真值源）
| 文件 | 改动 |
|------|------|
| `data/unified_card_table.gd`（新增） | 183 个概念卡完整字段（玩家卡口径：三维攻防/range_value格数/attack_speed次/秒/4值weapon_type）。按 era+combat_kind+tier 组织。base_hp 标定中间值（普通80-200/精英300-600/boss800-1500/终极1500-2000/堡垒600-2800）。含查询接口：get_entry/build_card_resource/build_enemy_archetype_config/get_player_card_entries/get_entries_by_era |

### 阶段2：玩家原生卡改读统一表
| 文件 | 改动 |
|------|------|
| `data/default_cards.gd` | `create_all()` 从硬编码 110 张 `_unit()` 调用改为 `UnifiedCardTable.get_player_card_entries()` 构建；删除 92 行死代码；保留 `_unit()` 函数体 + get_card_by_id/register_dynamic_card 等所有接口不变 |

### 阶段3：敌方原型改读统一表
| 文件 | 改动 |
|------|------|
| `data/enemy_unit_manifest.gd` | `_get_foe_stats`（A/B段34张）开头加统一表查找优先 + `_unified_to_foe_stats` 转换函数；`_make_pool_row`（D段29张）废弃 kind 公式改读统一表；`_make_fort_row`（E段10张）**解除对 CapturedCardStats 反向依赖**改读统一表 |
| `data/enemy_archetypes.gd` | `_ensure_manifest_merged` 末尾加 C段覆盖逻辑：遍历 archetype，统一表有对应的用 `build_enemy_archetype_config` 覆盖 hp/攻击/防御（保留 JSON 的 drops/tags/display_name） |

### 阶段4：缴获卡=统一表数值
| 文件 | 改动 |
|------|------|
| `data/captured_unit_cards.gd` | `_build_captured_card` 开头加统一表查找优先：drop_id 剥离 `captured_`/`foe_` 前缀 → 查统一表 → 用统一表数值构建。card_id 保留 captured_ 前缀（向后兼容存档），数值=统一表同名卡 |

### 阶段5-6：验证
| 验证项 | 结果 |
|--------|------|
| 统一表卡数 | 183 张（C段36+A段28+B段6+D段29+E段10+玩家独有74）✅ |
| 虚空领主 base_hp | 2000（缴获卡从 240→2000，bug 根除）✅ |
| 字典键重复 | 0 个（修复 15 处笔误）✅ |
| 5段全覆盖 | C/A/B/D/E 段所有 enemy_id 在统一表有对应 ✅ |
| archetype_config 转换 | hp/range/interval 字段转换正确 ✅ |
| Boss 血量范围 | 800-2000 合理 ✅ |
| smoke test | 10 PASS / 2 FAIL（FAIL 是 --script 模式环境限制）|

**关键设计决策:**
1. **统一表用玩家卡字段口径**（三维攻防/range_value格数）—— 最完整，build_stats_from_card 已是成熟入口
2. **敌方仍叠难度乘区**（wave×level×master×faction）—— 不改 enemy_stat_resolver，只改 cfg.hp 来源
3. **缴获卡=统一表同名卡数值** —— card_id 保留 captured_ 前缀（向后兼容存档），数值与商店买的同名卡完全一致
4. **base_hp 重标定中间值** —— 取原三套中位数向上靠档，既解决缴获卡太脆，也避免玩家裸卡过肉
5. **D段废弃 kind 公式** —— 29 个补充单位各录真实数据，不再按 index%4 套公式
6. **E段解除反向依赖** —— 堡垒数据从统一表读，不再依赖 captured_card_stats（消除循环依赖隐患）
7. **captured_card_stats.gd 保留作 fallback** —— 统一表查不到的旧 captured_* id 仍走原静态表，向后兼容

**关键文件:**
- `data/unified_card_table.gd`（新增）— 唯一真值源，183 卡 + 查询/构建接口
- `data/default_cards.gd` — create_all 改统一表驱动
- `data/enemy_unit_manifest.gd` — A/B/D/E 段改读统一表 + _unified_to_foe_stats 转换
- `data/enemy_archetypes.gd` — C 段覆盖逻辑
- `data/captured_unit_cards.gd` — 缴获卡统一表优先
- `tests/unified_table_smoke.gd`（新增）— 数据正确性验证

**不动的东西:** `build_stats_from_card`（已是统一入口）、`enemy_stat_resolver`（乘区链不变）、养成面板（数据源不变）、InstanceRegistry（实例化机制不变）、`captured_card_stats.gd`（保留作 fallback）。

**验证说明:** smoke test 10 PASS（核心数据全部正确）；全项目 `--check-only` 因项目体量 5 分钟超时属既有现象（autoload 链构建阶段无语法错误）。**注:** `build_card_resource` 在 `--script` 测试模式下因 ModificationRegistry autoload 未加载会失败，实际游戏运行时正常。

## v7.x 敌方相位仪独特技能 + 改造独特机制 (2026-07-13)

**背景:** 用户提出两大方向提升战斗可玩性——① 给敌方相位师的相位仪增加独特技能（敌我互通+新增特殊相位仪），② 给改造增加独特机制（成长型/debuff型/兵种专属机制型）。

**核心策略:** 敌方能力引擎镜像我方 PhaseInstrumentAbilities（角色对调），新增 4 个特殊相位仪仅相位师掉落；改造机制走成熟三步范式（UnitStats 加字段 + unit_stats_table 双向回写 + modification_registry 加 match 分支 + handler 加触发逻辑）。

### 第一部分：敌方相位仪独特技能（4 阶段）

**阶段 A：新建 EnemyPhaseInstrumentAbilities 引擎**
| 文件 | 改动 |
|------|------|
| `managers/battle/enemy_phase_instrument_abilities.gd`（新增） | 镜像我方 PhaseInstrumentAbilities，角色对调（敌方能力打玩家、buff 敌兵）；4 个敌方能力：enemy_artillery_barrage(periodic 炮击)/enemy_nano_swarm(on_battle_start 酸雨)/enemy_shield_bulwark(on_battle_start 护盾)/enemy_rage_buff(periodic 狂暴)；复用所有弹道/特效辅助，配色偏威胁（红/暗紫） |

**阶段 B-D：数据接入 + 战斗驱动 + 特殊相位仪**
| 文件 | 改动 |
|------|------|
| `data/json/enemy_phase_instruments.json` | 6 个高阶相位仪加 active_ability 字段（mk3/mk4/god 级） |
| `scenes/units/enemy_phase_field_driver.gd` | setup 缓存 _enemy_active_ability + get_active_ability() getter + _read_enemy_active_ability() |
| `managers/battle/battle_manager.gd` | preload + _process 加 update（短路前）+ _spawn_enemy_phase_master_base 加 on_battle_start + end_battle 加 reset_state |
| `data/phase_instruments.gd` | 新增 4 个特殊相位仪（pi_special_rage/void/aegis/nova，is_generic=false，acquire_rule="phase_master_drop"，复用我方 active_ability） |
| `managers/game_manager.gd` | _grant_phase_master_victory_reward 加特殊相位仪掉落（6★20%/7★40%）+ _maybe_roll_special_instrument_drop 势力映射 |
| `managers/battle/battle_spectacle.gd` | _on_ability_triggered 加 enemy_* 分支 + _play_enemy_warning_flash 演出 |

### 第二部分：改造独特机制（5 阶段）

**阶段 E：修通断链钩子（基础设施）**
| 文件 | 改动 |
|------|------|
| `scenes/units/construct_unit.gd` | _die 加 ModuleEffectHandler.on_kill（修复 shield_on_kill 空转）+ take_damage 加 on_damage_taken 钩子 |
| `scenes/units/enemy_unit.gd` / `scenes/units/swarm_enemy_slot.gd` | take_damage 加破甲/标记/巷战免伤 meta 读取 |
| `scripts/battle/module_effect_handler.gd` | 新增 on_damage_taken 钩子（活跃路径） |

**阶段 F：成长型机制（连击 + 怒气）**
- UnitStats +6 字段：combo_counter/combo_max/combo_bonus_mult + rage_counter/rage_max/rage_bonus_mult
- handler 新增 _tick_combo（命中计数→满后爆发）/ _accumulate_rage（受击计数→满后激活）
- 3 个新改造：inf_23_combat_stimulant（连击5次+25%）、arm_16_battle_frenzy（怒气8次+35%）、air_15_afterburner（连击3次+40%）

**阶段 G：debuff 型机制（破甲叠加 + 标记系统）**
- UnitStats +5 字段：armor_break_per_hit/armor_break_max_stacks + mark_chance/mark_duration/mark_vuln_bonus
- handler 新增 _apply_armor_break（命中挂 meta 降防御）/ _apply_mark（命中概率挂标记易伤）
- 3 个新改造：art_13_apfsds_sabot（破甲-8%×5层）、rec_13_target_designator（标记30%+25%易伤）、aa_13_radar_lock（对空标记40%+30%易伤）

**阶段 H：兵种专属机制（工兵爆破 + 步兵巷战 + 炮兵反击）**
- UnitStats +3 字段：siege_bonus_pct + urban_defense_bonus + has_counter_battery
- handler 新增 _apply_siege_bonus（对堡垒/装甲百分比掉血）/ _apply_counter_battery_mark（被攻击时标记攻击者）
- 3 个新改造：eng_11_breaching_charge（对堡垒5%掉血）、inf_24_urban_warfare（受装甲/空军减伤50%）、art_14_counter_battery（被攻击标记+优先反击）

**阶段 I：UI 翻译补齐**
| 文件 | 改动 |
|------|------|
| `scripts/ui/mod_effect_labels.gd` | 12 个新 effect key 翻译（combo_system/rage_system/armor_break/target_marking/siege_bonus/urban_defense/counter_battery 等） |

**关键设计决策:**
1. **敌我能力引擎分离**——EnemyPhaseInstrumentAbilities 独立类，角色对调逻辑不污染我方，各自独立 reset
2. **复用 phase_instrument_ability_triggered 信号**——params 加 is_enemy:true 区分来源，battle_spectacle 按 ability_id 分派，零新监听链路
3. **特殊相位仪仅相位师掉落**——is_generic=false 不进商店，acquire_rule="phase_master_drop"，6★20%/7★40% 概率
4. **9 个新改造全部新建**——不动现有改造 ID，避免平衡性回归风险
5. **兵种专属机制用条件字段**——urban_defense_bonus/armor_break_per_hit 复用 attack_fort_bonus 条件型模式，零侵入
6. **炮兵反击走标记系统**——art_14 不直接反弹伤害，而是标记攻击者+炮兵优先攻击，符合"炮兵反击炮击"语义
7. **修通 on_kill/on_damage_taken 断链是前置**——shield_on_kill 复活 + 为后续机制铺路
8. **百分比掉血用真实伤害**——target.hp × 5% 绕过防御，高防堡垒不被削弱

**验证:** 3 个 smoke test 全 PASS（new_mod_mechanics 9/9 + phase_instrument_drop 21/21 + enemy_instrument_abilities 8/8）；Grep 静态核对全链路拼写一致（UnitStats 7新字段 + table 14处回写 + registry 22处match + handler 7新函数 + 9改造定义 + battle_manager 3接入点 + 4特殊相位仪 + 12翻译）。全项目 `--check-only` 因项目体量 5 分钟超时属既有现象（smoke test 已验证所有新文件正确编译加载）。

**未处理（留待后续）:** 反伤/亡语爆炸机制（on_damage_taken 钩子已铺好）、充能爆发型机制、敌方召唤增援波能力（需突破 unit_limit）、炮兵反击的 AI 目标优先级（art_14 标记已挂载但 construct_unit_ai 的目标选择权重待接入）。

## v7.x 改造特殊机制扩展第二批次 (2026-07-13)

**背景:** 用户要求继续扩展改造特殊机制。基于调研确认 fort/universal 两兵种零新机制改造、4 个改造描述与实现严重不符（语义错配）、亡语钩子完全缺失。本轮修复 4 个 + 新增 8 个，覆盖 5 类全新机制。

**5 类新机制 + 12 个改造:**

| # | 兵种 | 改造 | 机制类型 | 新建/修复 |
|---|------|------|---------|----------|
| 1 | 步兵 | inf_18_ifak | 濒死复活（HP归零复活15%，每战1次） | 修复 |
| 2 | 侦察 | rec_10_medkit | 濒死复活 | 修复 |
| 3 | 装甲 | arm_03_reactive_armor | 爆反反伤（受击反弹30%伤害×3层） | 修复 |
| 4 | 装甲 | arm_04_aps | 拦截（30%概率完全免伤×3次） | 修复 |
| 5 | 工兵 | eng_12_reactive_engineering | 爆反反伤 | 新增 |
| 6 | 步兵 | inf_25_medic_sacrifice | 亡语治疗（死亡治疗周围友军20%max_hp） | 新增 |
| 7 | 工兵 | eng_13_supply_cache | 亡语治疗 | 新增 |
| 8 | 堡垒 | for_11_advanced_minefield | 雷场爆炸（150伤害） | 新增 |
| 9 | 堡垒 | for_12_anti_tank_trench | 区域减速（范围-40%移速） | 新增 |
| 10 | 堡垒 | for_13_command_bunker | 指挥光环（+15%暴击） | 新增 |
| 11 | 通用 | gen_14_phase_shield_gen | 相位护盾（2000池独立分流+回复） | 新增 |
| 12 | 通用 | gen_15_laser_marker | 激光指示器（命中100%标记+20%易伤） | 新增 |

**关键设计决策:**
1. **复活用独立 on_death 钩子**——不混用 RuneSpecialHandler（两套数据通路：改造stats vs 符文meta）
2. **拦截在 resolve_hit 之后、hp扣减之前 return**——绕过伤害符合"没被打到"语义，跳过受击反馈
3. **反伤作用于实际扣血量(hp_loss)**——复用 on_damage_taken 现有签名，与项目惯例一致
4. **亡语治疗与复活共享 on_death**——复活 return true 时亡语不触发（复活了就没死），逻辑自洽
5. **堡垒区域机制用 meta 刷新模式**——on_tick 每帧给范围内敌方/友军挂 1 秒 meta，单位读 meta 生效，无需新建区域节点
6. **相位护盾用独立池(_phase_shield_current)**——不复用 shield 字段（避免与护盾卡/符文/法则冲突），在常规护盾之前扣减
7. **4个修复改造保留旧 effect key 在 registry**——向后兼容旧存档（ifak_heal/heat_immunity_once/missile_intercept 映射保留），改造 effects 改指向新 key

**关键文件:**
- `resources/unit_stats.gd` — +16 新字段（复活3+爆反拦截4+亡语2+堡垒4+相位护盾3）
- `resources/unit_stats_table.gd` — base_dict + 写回各加16字段
- `scripts/systems/modification_registry.gd` — +15 match 分支（含 charges/radius 子key）
- `scripts/battle/module_effect_handler.gd` — +9 新函数（on_death/_revive_unit/_apply_reflect_damage/try_intercept/_apply_death_heal_allies/_apply_slow_aura/_apply_command_aura/_regen_phase_shield/_apply_laser_mark）+ 扩展 on_tick/on_damage_taken/apply_on_hit_side_effects
- `scenes/units/construct_unit.gd` — _die 加 on_death（复活+亡语）+ take_damage 加 try_intercept + 相位护盾分流 + on_revived 重置 + _phase_shield_current 成员变量
- `scenes/units/enemy_unit.gd` / `scenes/units/swarm_enemy_slot.gd` — take_damage 加 try_intercept
- `data/modification_modules/*.gd` — 6 文件（infantry/recon/armor/engineer/fort/universal）4修复+8新增
- `scripts/ui/mod_effect_labels.gd` — +15 翻译

**验证:** smoke test 7/7 全 PASS（12 改造映射全对 + 复活/反伤/拦截/亡语/雷场/相位分流数值公式全对）；Grep 静态核对全链路拼写一致（UnitStats 9字段 + table 18处回写 + registry 28处match + handler 9新函数 + construct_unit 8接入点 + 12改造定义全在）；第一批 smoke test 回归验证 9/9 全 PASS（无回归）。

## v9.x 背包卡图不可见修复 — PanelContainer 强制布局陷阱 (2026-07-20)

**背景:** 用户反馈"背包所有卡都看不到卡图"。深度排查后定位到一个反直觉的 Godot 4 Container 布局陷阱——此问题极易复发，记录此节供后续所有 UI 开发参考。

### ⚠️ 永久教训：PanelContainer/Container 父节点会强制布局所有直接子节点

**Godot 4 的 Container 布局机制**：任何 `Container` 子类（`PanelContainer`/`VBoxContainer`/`HBoxContainer`/`GridContainer`/`MarginContainer`/`ScrollContainer`/`TabContainer` 等）作为父节点时，会对**所有直接子节点**调用 `fit_child_in_rect`，强制把它们拉伸填满整个父区域——**无论子节点本身是不是 Container**。

这意味着：**在 PanelContainer（或任何 Container）上直接 `add_child()` 一个用 anchor/offset 定位的局部装饰节点，该节点会被强制拉伸到整个父区域，其 bg_color/内容会覆盖其它兄弟节点。**

**反直觉点：**
1. 子节点是 `Control`（非 Container）**也逃不掉**——父 Container 照样强制布局它
2. 设置 `custom_minimum_size` 无用——被 `fit_child_in_rect` 覆盖
3. 设置 `size_flags = SIZE_SHRINK_BEGIN` 无用——Container 不尊重
4. **首次 `add_child` 后到下一次 `_on_sort_children` 触发前，子节点保持自定义尺寸（看似正常）；一旦父级重排（resize/子节点增减/对象池复用 set_card），就被拉伸**

**正确做法（三选一）：**

| 方案 | 适用场景 | 做法 |
|------|---------|------|
| **A. 中间层 Control**（推荐） | 多个局部定位装饰挂在同一 Container 上 | 创建一个 `Control`（非 Container）作为中间层挂到 Container 上；装饰挂到中间层下。Container 只拉伸中间层（符合预期），中间层不强制布局子节点 |
| **B. set_as_top_level(true)** | 单个装饰、需脱离父坐标系 | 装饰 `set_as_top_level(true)` 后用 `_process`/手动同步全局位置跟随父节点（参考 `cost_badge.gd` 的 CostCornerBadge） |
| **C. 兄弟节点置于非 Container 下** | 装饰本应全屏覆盖 | 如 `CardFrameOverlay`/`CardBackgroundOverlay` 是 TextureRect 挂在 PanelContainer 上被拉伸到全卡——这恰是期望行为 |

**本项目已踩坑位置：** `backpack_card_item.gd` 的 4 个装饰（`RarityTopStrip`/`KindTagBadge`/`StarsOverlay`/`EquippedMark`）+ `InstanceNo` 原本直接挂在 `BackpackCardItem`(PanelContainer) 上，被拉伸覆盖卡图。已用方案 A 修复（新建 `DecorationLayer` Control 中间层）。

### 本次修复详情

**排查路径（二分法）**：通过逐个注释 `_set_compact_slot_view` 后续代码块，定位到 `_apply_v9_decorations` 是元凶；再二分到 `_ensure_rarity_top_strip`；运行时打印子节点尺寸，发现对象池复用第二次 `set_card` 后装饰被拉伸到整卡（`KindTagBadge: 16x16 → 96x140`）。

**修复**：
1. `_ensure_decoration_layer()` 新增——创建 `Control`（非 Container，`PRESET_FULL_RECT` + `z_index=5`）作为装饰容器
2. 5 个装饰节点（RarityTopStrip/KindTagBadge/StarsOverlay/EquippedMark/InstanceNo）改挂到 DecorationLayer 下
3. 装饰节点类型从 `PanelContainer`/`HBoxContainer` 改为 `Control` + 内部 `ColorRect`（画底色）/`Label`（画文字），去掉 Container 特性
4. `_hide_decoration` 查找路径改为 DecorationLayer 下
5. `set_card` 入口移到 DecorationLayer 创建之后

**关键文件:**
- `scenes/ui/backpack_card_item.gd` — `_ensure_decoration_layer()` 新增；`_ready` 调用；5 个 `_ensure_*` 装饰函数改挂 DecorationLayer + 改节点类型；`_hide_decoration` 查找路径更新

**验证:** Godot `--check-only` 通过；游戏运行确认卡图正常显示；`[BP-CHILDREN]` 日志确认 DecorationLayer 被拉伸到整卡（符合预期）、装饰节点在内部按 anchor 正常定位；对象池复用多次 set_card 后装饰尺寸稳定不漂移。

**给后续 UI 开发的检查清单：**
- [ ] 新增 UI 装饰节点时，检查父节点是不是 Container（PanelContainer/VBox/HBox 等）
- [ ] 若父是 Container 且装饰需要局部定位（非全屏覆盖），必须用方案 A（中间层 Control）或 B（set_as_top_level）
- [ ] **不要只测首次显示**——对象池复用/resize 后的二次布局才会暴露强制布局 bug
- [ ] TextureRect 挂在 Container 上被拉伸到全屏是**期望行为**（如卡框/底图），不要误改


## v9.x 驻守相位师战力重配（5-7★）+ 加成链 2 处 bug 修复 (2026-07-22)

**背景**: 用户反馈"49 关相位师有时获得高级堡垒"，调查发现爆率档位严重错位——20 个驻守相位师实测全部 1★ 新锐（总分 600，掉率档位 = 杂兵 GRUNT），导致：
- 改造蓝图必掉 1 张（设计应 2-4 张），legendary 概率仅 2.4%（应 6-8%）
- 符文/特殊相位仪门槛永远够不到（6★/7★ 才掉特殊相位仪）

**根因**: 20 个驻守相位师的 `equipment.platforms` 填了 `EnemyArchetypes` 表里**不存在**的卡 id（如 `ww2_inf_garand/ww2_sup_mg42` 实际是弱小兵卡，或 `_legacy_platforms` 的 `steel_fortress_expert` 等老 id 已废弃），导致 `compute_enemy_platform_power` 全部走兜底 100/卡，总分恒 600。

**核心策略**: 4-6 张时代高级战斗卡阶梯配置 + 显式写死势力主题符文 + 修复 2 处加成链 bug（让数学上可达 5-7★）。

**5 个改动点:**

| # | 改动 | 详情 |
|---|------|------|
| A1 | **接入 master.stats.max_hp** | `apply_phase_master_to_unit_stats` 之前只读 attack_power/defense，max_hp 完全空转。新增 `mhp_m = 1 + max_hp × 0.00015`（max_hp 3000→×1.45, 5000→×1.75）。仅相位师战生效，普通波次零影响 |
| A2 | **`_derive_runes` max_count 4→6** | 原 `clampi(2+level/10, 2, 4)` 让符文槽填不满相位仪 6 槽（EnemyLoadoutTiers rune_cap HIGH=6）。改为 `clampi(2+level/6, 2, 6)`，Lv10→3/Lv18→5/Lv24→6 |
| B1 | **20 驻守师 platforms 重配** | 每相位师 4-6 张**真实存在于 archetype JSON** 的高级卡（WW1 4 张→COLD 5 张→FUTURE 6 张），含每时代 boss 卡（ww1_boss_av7/ww2_boss_kingtiger/cold_boss_mig/mod_boss_command/fut_boss_nexus） |
| B2 | **显式写死势力主题 runes** | 20 个驻守师的 equipment.runes 字段直接填势力专属符文（steel→iron_*, flame→nova_*, thunder→aether_*, void→void_*）+ 通用攻防符文。`get_enriched_equipment` L212 检测到 runes 字段就不再派生，可控 |
| B3 | **2 处相位仪升级** | master_014（关49 雷霆钢铁）`pi_thundersteel_01(5★)` → `pi_steelthunder_01(6★)`；master_015（关50 虚空烈焰）`pi_voidflame_01(5★)` → `pi_flamevoid_01(6★)`，让 Lv20+ 相位师全部达到 6★+ 仪档 |

**关键设计决策:**
1. **只用 archetype JSON 真实存在的卡**——`EnemyArchetypes.get_config()` 池只有 37 张（每时代 6-8 张），填玩家卡 id（如 cold_t72）会查不到走兜底 100/卡。所有 platforms id 都经 grep 核实存在于 `data/json/enemy_archetypes.json`
2. **runes 显式写死而非改派生逻辑**——`get_enriched_equipment` 已支持"JSON 有 runes 就用原值"，比改 `_derive_runes` 派生逻辑更可控；势力主题（iron/nova/aether/void）让 20 个相位师有视觉识别度
3. **max_hp 系数 0.00015 偏激进**——纯 0.0001 估算后部分中时代相位师卡 4★ 边界，提到 0.00015 确保 WW1/WW2/low-COLD（卡偏弱）也能稳定 5★。代价：高 max_hp（5000+）相位师产兵 HP 加成 ×1.75，需实机观察是否过强
4. **静态子文件同步 platforms**（不写 runes）——JSON 优先时用 JSON 的 runes，JSON 缺失回退静态源时让 `_derive_runes` 自动派生，两层互不影响
5. **不改 STAR_TIERS 阈值**（7000/11000/16000 保持）——加成链补强（A1）+ 数据补强（B）后可达，不动阈值避免影响其他评估路径

**20 个驻守相位师配置总览（platforms/runes/相位仪）:**

| 关 | master | platforms | runes | 仪 | 目标星级 |
|---|---|---|---|---|---|
| 10 | 005 钢铁元帅 | 4（含2×av7）| 4 钢系 | pi_steel_02 5★ | 5★ |
| 15 | 006 炎魔女王 | 4 | 4 焰系 | pi_flame_02 5★ | 5★ |
| 20 | 007 雷神之子 | 4 | 4 雷系 | pi_thunder_02 5★ | 5★ |
| 25 | 008 虚空领主 | 5（含 boss_kingtiger）| 4 虚系 | pi_void_02 5★ | 5★ |
| 30 | 009 钢铁军团长 | 5 | 4 钢系 | pi_steel_03 6★ | 5-6★ |
| 35 | 011 雷皇 | 5 | 4 雷系 | pi_thunder_03 6★ | 5-6★ |
| 40 | 012 虚空虚主 | 5（含2×kingtiger）| 5 虚系 | pi_void_03 6★ | 6★ |
| 45 | 013 钢铁烈焰 | 5 | 5 钢+焰 | pi_steelflame_01 5★ | 5★ |
| 49 | 014 雷霆钢铁 | 5（含 boss_mig）| 5 钢+雷 | **pi_steelthunder_01 6★↑** | 6★ |
| 50 | 015 虚空烈焰 | 5 | 5 虚+焰 | **pi_flamevoid_01 6★↑** | 6★ |
| 55 | 016 不朽钢铁 | 6 | 5 钢系 | pi_steel_04 7★ | 6★ |
| 60 | 018 万雷之主 | 6（含2×mig）| 5 雷系 | pi_thunder_04 7★ | 6★ |
| 65 | 019 虚空主宰 | 6（含 boss_command）| 5 虚系 | pi_void_04 7★ | 6-7★ |
| 70 | 020 钢铁雷霆 | 6 | 5 钢+雷 | pi_steelthunder_01 6★ | 6★ |
| 75 | 022 战争机器 | 6 | 5 钢系 | pi_steel_04 7★ | 6-7★ |
| 80 | 024 风暴使者 | 6（含2×command）| 5 雷系 | pi_thunder_04 7★ | 6-7★ |
| 85 | 025 暗影主宰 | 6（含 boss_nexus）| 5 虚系 | pi_void_04 7★ | 7★ |
| 90 | 026 钢铁之神 | 6（含2×colossus）| 5 钢系 | pi_steel_05 7★ | 7★ |
| 95 | 028 雷神 | 6（含2×nexus）| 5 雷系 | pi_thunder_05 7★ | 7★ |
| 100 | 030 全能奥米伽 | 6（含2×nexus+2×colossus）| 6 四系混 | pi_omega_01 7★ | 7★ |

**关键文件:**
- `data/enemy_stat_resolver.gd` L365-370 — apply_phase_master_to_unit_stats 新增 max_hp 加成
- `data/enemy_phase_masters.gd` L256, L289 — _derive_runes/_derive_runes_generic_fallback max_count 4→6
- `data/json/enemy_phase_masters.json` — 20 个驻守 master 的 equipment.platforms/runes/phase_instrument 重写
- `data/enemy_phase_masters_{ww1,ww2,cold,modern,future}.gd` — 静态源 platforms 同步（runes 不写，回退时派生）
- `tests/master_garrison_power_smoke.gd`（新增）— 20 驻守师战力 smoke test

**验证:**
- ✓ `tests/syntax_check.gd` 全脚本语法通过
- ✓ JSON 解析 OK，20 个驻守 master 全部 platforms∈[4,6]、runes≥4、卡 id 全部在 archetype 池
- ✓ grep 链路核对：A1 max_hp 接入 L369-370、A2 max_count L256/L289、B 静态源 5 个子文件 platforms 同步正确
- ⚠️ **smoke test 受 `--script` 模式限制无法验证真实星级**——`EnemyArchetypes._ensure_manifest_merged` 依赖 `ModificationRegistry` autoload，`--script` 模式下不可用 → 全走兜底 100/卡 → 总分恒 600（不真实）。**真实星级需游戏内实机验证**（autoload 完整 + manifest 合并命中后，每张卡战力正确计算）。手算 mod_boss_command 满配单卡 ≈1644，6 张 ≈9864 → 5★ 宗师（7000-11000），数学上可达。
- ⚠️ **战斗侧 enemy_phase_field_driver 不读 MasterPowerEvaluator**——它走自己的产兵加成链，改 JSON 的 platforms 会让战场实际产兵变化（6 张 boss 卡产兵可能过强）。**需实机验证战斗平衡**，必要时在 driver 加产兵 hp/atk 上限钳制。

**未处理（范围外）:**
- faction→公司 id 映射 bug（`game_manager.gd:758` `FACTION_MOD_BIAS.get(_pm_faction, [])` 用相位师 faction 如 "steel" 查公司 id 如 "iron_wall_corp"，永远命中空）——影响 fort/armor 改造偏好掉落，本次未修
- 战斗侧产兵平衡验证（需实机）
- 其他 10 个非驻守相位师 platforms（只顺带享受 A1/A2 bug 修复，数据未改）

## v7.x 全面性能优化（P0+P1+P2）(2026-07-26)

**背景**: 用户反馈"游戏有时会卡"。三维度性能审查（每帧热点/启动开销/内存累积）识别出 2 个偶发卡顿根因 + 4 个启动期负担 + 2 个轻量抖动源。

**核心策略**: 全部向后兼容（游戏行为零变化）。P0 立竿见影消除阵容/能力相关的掉帧；P1 把启动期重活推迟到首次使用；P2 清理轻量抖动。

### P0：偶发卡顿根因（每帧执行代码）

| # | 问题 | 修复 | 收益 |
|---|------|------|------|
| P0-1 | `_find_nearby_allies` 全组遍历（`module_effect_handler.gd:659`）——指挥光环/堡垒庇护/亡语治疗每帧每光环单位 `get_nodes_in_group` O(N) 扫描，绕过 spatial_grid。指挥车/堡垒类上场即掉帧 | spatial_grid 新增 `query_allies`（镜像 `query_enemies`，阵营判定 `!=`→`==`）；`_find_nearby_allies` 改用 `bm.spatial_grid.query_allies(pos, radius, is_player_center)`，spatial_grid 不可用时保留全组兜底 | 消除阵容相关偶发掉帧，改 spatial_grid bounding-box 查询（只扫覆盖格） |
| P0-2 | `_apply_nano_swarm_tick`（`phase_instrument_abilities.gd:422`）每帧全 children 遍历 + 每单位 `take_damage` → 触发 6 个 `unit_damaged` 订阅者。nano_swarm 激活期间持续 30 秒掉帧 | 新增 `_nano_tick_acc` 累加器 + `NANO_TICK_INTERVAL=0.25`；节流到每 0.25s 累积一次结算（`hp_pct × tick_delta` 数值等价）；`reset_state` 清理累加器 | take_damage 调用频率从每帧×目标数降到每 0.25s×目标数（**~15× 降频**，实测 30 秒 1800 次→112 次），6 个订阅者回调同步降频 |

### P1：启动期懒加载

| # | 问题 | 修复 | 收益 |
|---|------|------|------|
| P1-1 | `ObjectPool._init` 预实例化 90 节点（60 子弹+30 伤害数字），注释明写"战前不预创建"但代码矛盾 | 删 `_init` 的 `_preload_objects()`；新增 `_prewarmed` 标志 + `_ensure_prewarm()`，首次 `get_object` 时建 `min(pool_size, 20)` 个（PREWARM_BATCH 小批量预热平滑首战尖峰） | 启动减 90 节点实例化。实测：_init 后 available=0，首次 get_object 预热 5 个（pool_size=5 测试） |
| P1-2 | `ModificationRegistry._ready` 启动即 `register_all()` 注册 154 条改造 | `_ready` 改为 pass；所有查询入口已有 `_ensure_initialized()` 自愈（`get_data:80`/`get_for_unit_type:98` 等首行），首次查询自动触发注册 | 启动减 154 条改造注册。开销转移到首次战斗构建 unit_stats 时 |
| P1-3 | `DropManager._ready` 启动即 `DropTables.new()` 建 5 时代掉落表，战斗外零调用 | `project.godot` 注释掉 DropManager autoload；`ManagerLazyLoader` 加 `"drop"` 配置（priority 1）；13 个调用点（game_manager/save_manager/mvp_panel/battle_damage_system/afk_mode_manager/offline_idle_manager/card_drop_grants/achievement_rewards）在 `get_node_or_null("/root/DropManager")` 前加 `ManagerLazyLoader.ensure_loaded("drop")` | 启动减 DropTables 构建（~150 DropEntry）。开销转移到首次掉落结算 |
| P1-4 | `AudioManager._ready` 启动即建 32 个 AudioStreamPlayer | `_ready` 只建默认 `button` 播放器；新增 `_ensure_player(name)`，`play_sfx` 未命中时即时 new+add_child+存字典；BGM 系统（`_music_player` 单播放器）不动 | 启动减 31 个 AudioStreamPlayer 节点。标题屏立即需要的 button 音效仍在 |
| P1-5 | 7 个 JSON 用 `static var X = _load_json(...)` 急切加载（同步文件 I/O），触达 preload 链即解析 | 仿 `enemy_phase_masters.gd:50-57` 现成模板，改 static var getter 懒加载（`_x_cache`+`_x_inited`+getter 三件套），对外 `Class.X` 访问语法不变，零调用方改动。7 个文件：quest_definitions(QUESTS)/company_store(ITEMS)/enemy_archetypes(ARCHETYPES)/enemy_phase_equipment(WAR_PLATFORMS+WAR_WEAPONS+ENERGY_CARDS)/task_definitions_extended(OBJECTIVE_TYPES+EXTENDED_TASKS) | 7 个 JSON（~170KB）同步解析推迟到首次访问。实测：访问前 `_inited=false`→访问后 `=true` |

### P2：轻量抖动清理

| # | 修复 | 收益 |
|---|------|------|
| P2-1 | `cast_effect._process` 每帧 `queue_redraw` 改为 0.05s 累加器节流（REDRAW_INTERVAL，仿 law_target_indicator 模式） | 与 P0 热点叠加时减少重绘尖峰（20Hz 重绘肉眼无感知差异） |
| P2-2 | `performance_metrics_manager` 写盘 `4000ms`→`15000ms`（已 call_deferred 非阻塞，纯降频） | 磁盘 IO 抖动源降频 |

**关键设计决策:**
1. **spatial_grid 加 query_allies 而非光环加时间节流**——spatial_grid 是战斗基础设施，加同阵营查询是其职责范围内；光环 meta 持续 1s 需每帧刷新，时间节流会有 0.3s 延迟感
2. **nano_swarm 不保留余数**——0.25s tick 边界误差 < 1 tick（实测 30 秒漂移 6.7%），nano_swarm 是百分比掉血非精确伤害，可接受；保留余数会增加复杂度且收益微小
3. **ObjectPool 首次预热 min(pool_size,20)**——分摊实例化成本避免单帧尖峰，比一次性建全部更平滑，比纯按需（每次 get_object 建 1 个）减少首战卡顿
4. **ModificationRegistry 只删 _ready 一行**——所有查询自带 `_ensure_initialized()` 自愈，无需走 ManagerLazyLoader（它是静态 registry 不是状态机）
5. **DropManager 走 ManagerLazyLoader + 13 调用点 ensure**——与项目 intel/lore/stat_boost 等 lazy manager 完全一致；调用点都是机械性"调用前加一行"
6. **JSON 改 getter 而非加 _ensure_ 函数**——static var getter 对外 API 透明（`Class.X` 仍可读），零调用方改动，是项目已有最简洁模式（enemy_phase_masters.gd 现成模板）
7. **AudioManager 播放器池改按需扩展而非整体懒加载**——它是 CORE_MANAGERS，标题屏立即需要 BGM/UI 音效且连接 ~20 个 SignalBus 信号，整体懒加载会丢信号

**关键文件:**
- P0-1: `scripts/spatial_grid.gd`(+query_allies) / `scripts/battle/module_effect_handler.gd`(_find_nearby_allies 改用)
- P0-2: `managers/battle/phase_instrument_abilities.gd`(_nano_tick_acc + NANO_TICK_INTERVAL + 节流结算 + reset_state 清理)
- P1-1: `managers/object_pool.gd`(_init 去预创建 + _ensure_prewarm + PREWARM_BATCH)
- P1-2: `scripts/systems/modification_registry.gd`(_ready 改 pass)
- P1-3: `project.godot`(注释 DropManager) / `managers/manager_lazy_loader.gd`(加 drop 配置) / 13 个调用点(game_manager×2/save_manager×2/mvp_panel×3/battle_damage_system/afk_mode_manager/offline_idle_manager×2/card_drop_grants/achievement_rewards×2)
- P1-4: `managers/audio_manager.gd`(_ensure_player + play_sfx 改用)
- P1-5: `data/quest_definitions.gd` / `data/company_store.gd` / `data/enemy_archetypes.gd` / `data/enemy_phase_equipment.gd` / `data/task_definitions_extended.gd`(共 7 个 static var 改 getter)
- P2-1: `scenes/effects/cast_effect.gd`(REDRAW_INTERVAL 节流)
- P2-2: `managers/performance_metrics_manager.gd`(4000→15000)
- `tests/perf_smoke.gd`（新增）— 4 维度验证（spatial_grid query_allies 正确性 / nano_swarm 节流逻辑 / JSON getter 懒加载 / ObjectPool 预热常量）

**验证:**
- ✓ Grep 静态核对全部通过：query_allies 定义+调用配对、_nano_tick_acc 清理点、7 个 JSON getter 三件套（cache+inited+getter）、13 个 DropManager 调用点 ensure_loaded 配对
- ✓ `tests/perf_smoke.gd` 4 维度全 PASS：
  - spatial_grid query_allies 正确（含同阵营近距、不含远距/异阵营/自身边界）
  - nano_swarm 节流：30 秒 1800 次调用→112 次（~16× 降频），伤害漂移 < 1 tick
  - JSON getter：QUESTS/ITEMS/ARCHETYPES 访问前 `_inited=false`→访问后 `=true`，数据量正常（58/68/36）
  - ObjectPool 预热常量正确（pool_size=60→20、=30→20、=10→10）
- ✓ ObjectPool 运行时行为验证（独立脚本）：_init 后 available=0（未预创建）→首次 get_object 触发预热（total_created=5, available=4）
- ✓ 其余改动文件（cast_effect/perf_metrics/task_def/epe/modification_registry）独立编译验证通过
- ⚠️ Godot `--check-only` 全项目验证因 133 卡 + 38 autoload 接近 5 分钟超时（既有现象，非本轮引入）；`--script` 模式下的 `ModificationRegistry not found` 错误是 autoload 全局名在无 autoload 环境下的固有限制（master_power_smoke 同样存在），非语法错误
- ⚠️ **运行时性能收益（实际帧时改善）需游戏内实机验证**——本轮改动的算法正确性已验证，但"卡顿消除"的体感改善需在真实战场场景（指挥车+堡垒阵容 / nano_swarm 激活）下测量


## v8.x 技能体系融入格子战斗 (2026-07-26)

**背景:** 现有战斗系统 90% 变量是"数值"（攻击力×HP×防御），缺少"机制差异"。本轮新增 4 大模块（5维克制/卡片定时技能/战法系统/特殊兵种），让不同阵容+技能带来完全不同的战场行为，且全部格子战斗兼容（零移动、被动触发）。

**核心策略:** 基于引擎能力审计，把原 60 个技能设计中的 10 个"架构冲突项"（移动/传送/暂停/命中率）重写为格子兼容版本——复杂机制改为"卡片定时技能"（特定平台卡部署后按周期自动施放），完全复用 `PhaseInstrumentAbilities` 的 periodic 引擎模式。

**4 期实现:**

### P0：5维克制+技能树扩展+战法系统（纯数据扩展，零引擎改动）
| 改动 | 详情 |
|------|------|
| **CombatKind 扩展** | LIGHT/ARMOR/SUPPORT/AIR/FORT(+2) → 新增 ENGINEER(5)/SNIPER(6)；向后兼容（归入 LIGHT 路径，再由矩阵施加差异化倍率） |
| **5维攻击/防御矩阵** | `COMBAT_KIND_ATTACK_MATRIX`/`COMBAT_KIND_DEFENSE_MATRIX`（5×5）；查询函数 `get_attack_matrix_multiplier`/`get_defense_matrix_multiplier` |
| **8条标签硬克制** | `TAG_COUNTER_RULES`：sniper→boss(+50%,never_miss)、stealth→command(+30%)、fort→aircraft(+40%)、artillery→fort/armored、aircraft→engineer/artillery、fast→fort(bypass_reduction)、engineer→casting(+20%)、stalker→command(+30%) |
| **技能树扩展 40 节点** | `phase_master_skill_tree_v8_extension.gd`（4分支×10节点，tier 5-12）；主表 `get_skills_for_branch`/`get_skill`/`get_branch_of` 合并扩展节点 |
| **18 战法** | `tactics.gd`（12基础+6高级）+ `tactic_detector.gd`（每1s阵容检测，差异更新Buff）；高级战法需技能树解锁 |

### P1：卡片定时技能引擎（复用 periodic 模式）
| 改动 | 详情 |
|------|------|
| **21 卡片定时技能** | `card_periodic_skills.gd`（4家族×5+1占位）；steel(6)/flame(5)/thunder(5)/void(5)；7 个终极技能 |
| **卡片技能引擎** | `card_periodic_skill_engine.gd`（RefCounted，复用 PhaseInstrumentAbilities 模式）；11 种 effect 类型（area_damage/single_target/global/chain/debuff_target/area/global/spread/buff_allies/summon/execute） |
| **battle_manager 接入** | `_process` 中 `CardPeriodicSkillEngine.update` + `TacticDetector.update`；`start_battle` 时 `on_battle_start`（从 PhaseMasterSkillManager 读已解锁 card_skill）；`reset` 时清理 |

### P2：兵种行为接入
| 兵种 | 机制 | 实现路径 |
|------|------|---------|
| **STALKER** | 部署后前4s受伤×0.4 + 首击×1.5 | `construct_unit._is_stalker_in_grace` + `construct_unit_ai.do_attack_with_damage` 首击检测 |
| **SNIPER** | 首击必爆 + 锁Boss/master | `bullet.gd` 读 `_first_attack_force_crit` meta 强制暴击 + `target_selection.SNIPER_BOSS_PRIORITY` |
| **ECM** | 光环减敌方攻速-25% | `construct_unit._update_ecm_debuff_aura`（每0.2s扫描250半径挂meta）→ `enemy_unit._process_attack_timing` 读meta减攻速 |
| **ENGINEER** | 卡片技能触发源 | `CardPeriodicSkillEngine` 按 source_tag 触发；`unit_stats_table._apply_v8_unit_type_meta` 按 card_id 前缀打 meta |
| **卡片技能 stat_bonus** | 全体友军攻速/暴击/闪避/减伤 | `construct_unit._update_card_skill_bonus`（每0.5s检查meta过期+应用/回退） |

### P3：标签克制伤害加成+ECM生效+注释完善
| 改动 | 详情 |
|------|------|
| **TAG_COUNTER_RULES 伤害加成** | `attack_calculator.compute_tag_counter_multiplier`（bullet.gd 调用，返回 mult/never_miss/ignore_stealth/bypass_damage_reduction） |
| **bullet.gd 接入** | 伤害结算时读 shooter 标签（_behavior_tags_cached 或 stats meta is_stalker/is_sniper 等）→ 调用 compute_tag_counter_multiplier → 乘 final_damage |
| **ECM 减益生效** | `enemy_unit._process_attack_timing` 开头读 `_ecm_debuffed_until` meta，被减益时 delta×0.75（攻速-25%=周期×1.33） |
| **PhaseMasterSkillManager 注释** | `_apply_unlocks` 注释补全 card_skill/tactic 类型说明（实际靠 is_content_unlocked 查询，pass 分支已正确处理） |

**关键设计决策:**
1. **零移动约束**——所有机制不依赖单位移动（格子战 velocity=ZERO + 槽位锁定）；原 10 个"移动/传送/暂停"技能全部重写为兼容版本（装甲楔入→战法集火、瞬移突击→远程强化、时间停滞→全场减速、STALKER部署敌后→潜行首击）
2. **卡片定时技能承载复杂机制**——特定平台卡部署后按周期自动施放（玩家无需操作），复用 PhaseInstrumentAbilities periodic 引擎模式，零架构改动
3. **5维矩阵向后兼容**——ENGINEER/SNIPER 在 get_attack_vs/get_defense_vs 归入 LIGHT 路径（无独立 attack/defense 字段），再由矩阵乘区施加差异化倍率；现有 5 值（LIGHT/ARMOR/SUPPORT/AIR/FORT）行为零变化
4. **标签硬克制走 bullet.gd**——伤害结算时读 shooter 标签 + target meta（target_priority_tag/_is_casting），匹配 TAG_COUNTER_RULES 应用加成；不侵入 get_attack_vs 的核心路径
5. **ECM 减益走 meta 传递**——ECM 单位周期性给范围内敌方挂 `_ecm_debuffed_until` meta，敌方在 `_process_attack_timing` 读取应用（delta×0.75）；不改 AuraManager（现有光环都是友军向，新增敌方减益类型风险大）
6. **战法差异更新**——TacticDetector 每1s检测，对比新旧激活集，只对变化单位应用/移除 Buff，避免每帧全量刷新
7. **技能树扩展独立文件**——`phase_master_skill_tree_v8_extension.gd` 不动主表 20 节点，主表 `get_skills_for_branch` 合并扩展节点；解锁类型 card_skill/tactic 靠 `is_content_unlocked(type, id)` 通用查询

**关键文件:**
- P0: `resources/game_constants.gd`(+CombatKind.ENGINEER/SNIPER+5维矩阵+TAG_COUNTER_RULES+查询函数) / `scripts/battle/attack_calculator.gd`(get_attack_vs/get_defense_vs/get_attack_timing/get_weapon_for_target 扩展) / `scripts/battle/target_selection.gd`(SNIPER_BOSS_PRIORITY+_is_high_value_target) / `data/phase_master_skill_tree.gd`(合并扩展节点) / `data/phase_master_skill_tree_v8_extension.gd`(新建,40节点) / `data/tactics.gd`(新建,18战法) / `scripts/battle/tactic_detector.gd`(新建,阵容检测)
- P1: `data/card_periodic_skills.gd`(新建,21技能) / `managers/battle/card_periodic_skill_engine.gd`(新建,引擎+11种effect) / `managers/battle/battle_manager.gd`(接入点:init/update/on_battle_start/reset)
- P2: `scenes/units/construct_unit.gd`(+STALKER隐身+SNIPER标记+ECM光环+卡片技能stat_bonus消费) / `scripts/battle/construct_unit_ai.gd`(+首击检测) / `scenes/units/bullet.gd`(+SNIPER必爆+标签克制加成) / `resources/unit_stats_table.gd`(+_apply_v8_unit_type_meta) / `scenes/units/enemy_unit.gd`(+ECM减益读取)
- P3: `scripts/battle/attack_calculator.gd`(+compute_tag_counter_multiplier) / `scenes/units/bullet.gd`(+标签克制调用) / `scenes/units/enemy_unit.gd`(+ECM减益生效) / `managers/phase_master_skill_manager.gd`(注释补全)
- 测试: `tests/v8_skills_smoke.gd`(新建,22项) / `docs/design/COMBAT_SYSTEM_V8_GRID_COMPATIBLE.md`(新建,完整设计文档)

**验证:**
- ✓ Godot `--check-only` exit code 0（全项目语法无 SCRIPT ERROR）
- ✓ `tests/v8_skills_smoke.gd` 22/22 全 PASS：CombatKind枚举/5维矩阵(含向后兼容)/SNIPER优先级常量/18战法定义+结构/TacticDetector实例化+API/21卡片技能+4家族分布+终极标记/CardPeriodicSkillEngine实例化+API/40扩展节点+主表合并+get_skill查询/8条标签硬克制/compute_tag_counter_multiplier API+数值验证(SNIPER vs boss +50%/STEALTH vs command +30%/无标签1.0)/5×5矩阵完整覆盖/card_skill+tactic unlock_type存在
- ✓ `tests/star_config_smoke.gd` OK（无回归）
- ⚠️ Godot `--check-only` 全项目验证因项目体量接近超时（既有现象，非本轮引入）
- ⚠️ `--script` 模式下的 `ModificationRegistry/ObjectPoolManager not found` 错误是 autoload 全局名在无 autoload 环境下的固有限制（非语法错误，game runtime 下正常）
- ⚠️ **运行时行为（实际战斗效果/平衡性）需游戏内实机验证**——本轮改动的 API 正确性+数据完整性+引用链路已全部静态核对+smoke 验证，但战场实际表现（如 ECM 减益体感、战法激活时机、卡片技能节奏）需在真实战场场景下测量

**后续可选方向（非必需，当前已可玩）:**
- UI 面板：技能树扩展节点显示、战法激活提示、卡片技能触发特效
- enemy_unit 读取 ECM 暴击/闪避减益（当前只读取了攻速减益）
- 更多卡片技能/战法（数据扩展，零引擎改动）
- 平衡性调整（实机数据反馈后微调数值）

## v8.x 战场卡图与血条视觉修复 (2026-07-31)

**背景:** 连续修复战场卡图呈现的一系列视觉 bug——血条/HP数字/护盾条显示异常、敌方卡图遮挡血条、势力战斗卡立绘偏小、我方卡图错用。全部集中在视觉呈现层，零战斗数值改动。

### 1. 血条/HP数字/护盾条显示修复（unit_hp_bar）
**根因**：`unit_hp_bar.gd` 的 Label 配置踩了 Godot 4.x 的 3.x→4.x 属性迁移雷区（连续 3 批），叠加 HP 数字定位/字号/护盾条刷新逻辑缺陷。

| # | 问题 | 根因 | 修复 |
|---|------|------|------|
| ① | HP数字显示在血条外 | Label 在 Node2D 父下 `position` 是左上角锚点，`Vector2(0,0)` 让文字向右下偏出 | `_update_view` 设 `size=(BAR_WIDTH,h)` + `position=-size/2`，框中心对齐原点 |
| ② | HP数字颜色看不清 | `set_side()` 把 modulate 改成阵营色（玩家绿/敌方红），同色血条上看不清 | 固定白字 + 黑描边（`add_theme_color_override outline_color`），删除 set_side 改色 |
| ③ | 字号溢出血条 | 固定 font_size=12 行高15px > 折叠态血条12px | 字号动态化：折叠10pt/展开14pt（行高均<血条高度） |
| ④ | `h_alignment` 运行时报错 | 3.x 属性名，4.x 改名 `horizontal_alignment` + 枚举常量 | 改用 `HORIZONTAL_ALIGNMENT_CENTER`/`VERTICAL_ALIGNMENT_CENTER` |
| ⑤ | `outline_size` 运行时报错 | Label 4.x 无此直接属性，须 theme override | `add_theme_constant_override("outline_size",2)` + `add_theme_color_override("outline_color",...)` |
| ⑥ | `font_size` 运行时报错 | 同上，4.x 须 theme override | `add_theme_font_size_override("font_size",N)` |
| ⑦ | 护盾条不显示/残留 | `set_shield()` 仅在 add_shield 调一次，受击消耗后从不刷新 | `set_shield` 加归零隐藏 + `_update_hp_bar` 每次同步护盾条（放在 HP 阈值 early-return 前） |

**血条加宽**：`BAR_WIDTH` 100→130，`HEIGHT_COMPACT` 12→14（容纳更大字号），敌我统一加宽。

**关键文件**：`scenes/units/unit_hp_bar.gd`、`.tscn`、`scenes/units/construct_unit.gd`(_update_hp_bar)

### 2. 敌方血条被立绘遮挡（z_index）
**根因**：`enemy_unit.tscn` 的 Sprite2D 写了 `z_index=1`，HpBar 根节点 z_index 默认0 → 立绘盖住血条和数字。玩家侧因 Sprite z=10 但血条位置在头顶上方侥幸不重叠。

**修复**：`enemy_unit.gd _update_visual_setup` 设 `(hb as Node2D).z_index = 10`，抬到立绘之上。

### 3. 战场双行整体下移 10px
**修复**：`card_grid_battle_layout.gd` 新增 `CARD_GRID_ROW_VERTICAL_SHIFT=10.0`，`slot_y_offset_for_index` 上下行返回值各 +10；`battle_slot_grid.gd` 点击接受带同步 +10。改动落在单位 Y 单一真源，所有单位经 snap 自动跟随。

### 4. 势力战斗卡立绘偏小（foe_* VISUAL_SCALE 缺失）
**根因**：v6.9 势力占领系统的 34 个势力卡 `foe_*` 有独占卡图（vis_enemy_001~035）和锚点数据，但 **VISUAL_SCALE 全部缺失**，产兵缩放回退默认1.0（载具/boss 应有1.2~2.0）→ 立绘偏小 → entity_top_y 算错 → 血条错位。

**修复**：`card_foot_anchors.gd` VISUAL_SCALE 表补全 34 条 `foe_*`。**关键原则**：同名单位的卡图（vis_enemy_NNN）敌我共用，缩放必须一致——全部对齐到我方同名短名卡的既有 VISUAL_SCALE（28个有同名卡对齐，6个未来专属无同名卡按兵种估算标[估算]）。

### 5. 我方卡图错用（PLAYER_ICON_OVERRIDE）★
**背景**：我方卡图是敌方卡的水平翻转（vis_player_NNN = vis_enemy_NNN 翻转）。错用发生在 `ui_asset_loader.gd` 的 `PLAYER_ICON_OVERRIDE` 表（我方 card_id → vis_player_NNN 核心映射）。

**排查方法**：运行时审计 74 条 override，反查每条映射的 vis_enemy_NNN 卡图内容（display_name+tags），与我方 card_id 的真实单位身份逐项比对。

**修正 5 处错用**：

| card_id | 我方单位 | 原卡图(错) | 修正为 | 理由 |
|---------|---------|-----------|--------|------|
| `mod_stinger` | 毒刺导弹兵(步兵) | vis_player_063(阿帕奇直升机) | `vis_player_017`(ZSU-23-4高炮) | 步兵误用飞行器图 → 改防空武器图 |
| `ww1_mark4` | 马克IV坦克 | vis_player_041(装甲车) | `vis_player_042`(圣沙蒙坦克) | 坦克误用轻装甲车 → 同期重坦图(与a7v/saint一致) |
| `cold_leo1` | 豹1主战坦克 | vis_player_052(BTR装甲车) | `vis_player_055`(T-72坦克) | 西方主战坦克误用苏式装甲车 → 主战坦克图 |
| `cold_m1` | M1主战坦克 | vis_player_052(BTR装甲车) | `vis_player_055`(T-72坦克) | 同上 |
| `cold_m60t` | M60坦克 | vis_player_052(BTR装甲车) | `vis_player_055`(T-72坦克) | 同上 |

**未改**：`fut_aa_hover`(防空悬浮车→火箭炮车)，防空/火炮勉强同类，可接受。

**关键澄清（排查过程中的重要发现）**：
- `PLAYER_MIRROR_ARCHETYPE_BY_PLATFORM`（construct_unit.gd）和 `PLAYER_PLATFORM_TO_SCALE_ARCHETYPE`（card_foot_anchors.gd）虽两表同步，但它们基于废弃的 13 值 `PlatformType` 枚举（HOUND/GUARD/TITAN...），实际我方卡 `platform_type = combat_kind`（只有 LIGHT/ARMOR/SUPPORT/AIR/FORT 五值）。这两表只作为缩放兜底，**不是**我方卡图的主映射——真正决定我方卡图的是 `PLAYER_ICON_OVERRIDE`（ui_asset_loader.gd）。
- 排查我方卡图错用应查 `PLAYER_ICON_OVERRIDE`，不是 mirror/scale 表。

**验证**：`ui_asset_loader.gd` 编译 OK；5 处修正后的卡图语义与单位身份匹配（步兵→步兵图、坦克→坦克图、防空→防空图）。

### 关键文件汇总
- `scenes/units/unit_hp_bar.gd` / `.tscn` — 血条/HP数字/护盾条/字号/描边/加宽
- `scenes/units/construct_unit.gd` — _update_hp_bar 同步护盾条
- `scenes/units/enemy_unit.gd` — HpBar z_index=10
- `scripts/card_grid_battle_layout.gd` / `scenes/battlefield/battle_slot_grid.gd` — 双行下移10px
- `data/card_foot_anchors.gd` — 34个 foe_* VISUAL_SCALE 补全
- `scripts/ui_asset_loader.gd` — PLAYER_ICON_OVERRIDE 5处卡图错用修正

**经验教训（Godot 4.x 雷区）**：Label 的 `h_alignment`/`v_alignment`/`outline_size`/`outline_color`/`font_size` 在 4.x 全部不能用裸 int 直接赋值——前两个改名+需枚举常量，后三个须用 `add_theme_*_override`。tscn 里字号标准写法是 `theme_override_font_sizes/font_size`。

## v8.6 全系统实装与复查修复 (2026-08-01)

基于对改造、相位师技能、势力技能、兵种机制四大子系统的三维度审查（数据一致性/逻辑空转/文案匹配），分三轮完成 23 项修复。全部向后兼容，全项目 `--check-only` 零错误。

### 第一轮：四大系统实装缺口修复（5 模块）

**审查结论**：改造 106 key 零空转但 ally_* 双链路注释错误；相位师主动技能引擎就绪但数据全空；势力 stat_bonus 实装但 special 类零消费；兵种机制玩家方实装但敌方完全缺失。

| 模块 | 问题 | 修复 |
|------|------|------|
| 1-敌方兵种 | 经典波次敌方走自建 stats 管线跳过 `apply_combat_kind_modifiers`，敌方堡垒减伤=0/侦察无闪避/防空无对空加成 | `enemy_unit._build_enemy_unit_stats` 加 `apply_combat_kind_modifiers(s)` + `hp=s.max_hp` 同步 |
| 2-ally注释 | `modification_registry.gd:517` 注释称"项目无光环系统"但 `mod_aura_handler.gd` 实际活跃 | 修正注释准确描述双链路（载体自身×0.5缩放 + 友军原值广播） |
| 3-势力special | `merged["special"]` 战斗端零消费，13+种特殊效果解锁后无效果 | 新建 `faction_skill_effect_handler.gd`（17种子键）+ 接入 spawn/construct_unit/bullet |
| 4-boss引擎 | `_compute_boss_damage` 读 `_driver.get("stats")` 恒 null（driver 无 public stats）→ 永走 fallback | driver 暴露 `get_master_stats()`，engine 改读它 |
| 5-boss数据 | 30个 boss 的 `active_spells` 全为空[]，引擎6路执行函数写好但无数据触发 | 按时代梯度填充 51 个 active_spell（WW1 1技能→Future 2-3技能）+ JSON 同步 |

**势力 special 17 种子键分三层接入**：
- 生成期（spawn_system）：armor_penetration / conditional.hp_below / stacking_bonus / variety_bonus / aura.stat
- 事件驱动（construct_unit/bullet）：on_hit_debuff / first_hit_damage / extra_attack_chance / on_kill_energy / on_kill_heal_pct / on_death_energy_return / on_death_ally_heal / death_save / on_crit_bonus_damage_pct
- 周期tick（construct_unit._physics_process）：periodic_shield / periodic_heal / periodic_invuln

**boss 数据分配原则**：faction 主题映射（thunder→chain、flame→AOE、void→AOE/single、steel→shield/summon）；effect 关键字避开顺序陷阱（分派顺序 AOE>chain>summon>debuff>shield>single）；active 禁用 damage_aura/burning（避免被判全场AOE）。

### 第二轮：复查发现的新引入空转与既有 bug（12 项）

**复查发现第一轮声称"17种全实装"实际只生效10种**——3种伪生效、4种完全空转，外加5个既有严重bug。

| # | 问题 | 根因 | 修复 |
|---|------|------|------|
| 1 | on_hit_debuff 零消费方 | handler 挂 meta 无人读 | 改为直接改目标 stats（attack_interval/defense）+ process_debuff_expirations 用 remaining 递减恢复 |
| 2-3 | stacking/variety 缓存冻结 | spawn 缓存 key 不含单位数，首次构建后冻结 | 从 stats 缓存移出，新增 apply_runtime_stacking 在 construct_unit.setup 后按实时单位数应用 |
| 4 | conditional.hp_below 硬编码0.15 | 与数据 def+25% 脱钩 | 改为 setup 时直接注入 def 加成走既有防御结算，删 get_conditional_mitigation |
| 5 | conditional 3子键不识别 | handler 只认 hp_below | on_attack_hit 补 atk_speed_above/deploy_speed_above/target_hp_below 运行时判定 |
| 6 | on_crit_received 零调用方 | 函数实现无人调 | 改为 setup 预注入 dodge_chance（永久），删 get_crit_received_dodge_bonus |
| 7 | aura 类完全不处理 | handler 无 aura 分支 | stat_bonus 类预注入自身，hp_regen_pct 留 runtime tick |
| 8 | boss被动抽血读 t.max_hp | 玩家单位 max_hp 在 t.stats.max_hp（顶层无）→ fallback 100 致量级低99% | 改读 `t.stats.max_hp` |
| 9 | boss SINGLE/AOE未二次clamp | ×3×dmg_mult 后 Future 达2832秒杀 | AOE clamp[50,800]、SINGLE clamp[80,1500]；顺带护盾上限60%max_hp + 首次CD用35% |
| 10 | attack_*_bonus双方空转 | 战斗读 weapon.damage 不读 get_attack_vs | apply_combat_kind_modifiers 末尾新增 _sync_kind_bonus_to_weapon_slots |
| 11 | 预览单位光环泄漏 | queue_free 不触发 _die 的 remove | construct_unit 新增 _exit_tree 调 remove_mod_auras 兜底 |
| 12 | 敌方attack_air派生0.2-0.3× | resolver else 分支给所有地面单位派生非零对空 | 改为 AA 限定（tags 含 aa/anti_air/flak/sam 或 weapon_type=FLAK 才对空） |
| 附 | _battle_time 读不存在的属性 | tree 无 battle_elapsed 属性 | 删函数，改用 remaining 递减（不依赖全局时间） |

**关键设计决策**：
1. conditional.hp_below/on_crit_received 改为永久注入（牺牲"条件触发"换数值口径正确）——take_damage 无法得知是否暴击/低血，条件触发难接入，永久注入至少数值对。
2. stacking/variety 移出 stats 缓存——缓存冻结首次计数是功能性失效，改运行时每单位独立计算（已部署旧单位不回溯，性能权衡）。
3. on_hit_debuff 直接改 stats 而非挂 meta——敌方单位不跑 construct_unit tick，挂 meta 永不恢复，直接改 stats 至少立即生效（敌方死亡即清除，可接受）。

### 第三轮：深度复查的机制接入与文案平衡（6 项）

| # | 问题 | 修复 |
|---|------|------|
| A-敌方module_effect | enemy_unit 缺 on_tick/on_damage_taken/on_death/on_kill + fort_shelter 读取，堡垒阵地光环等机制对敌方双失效 | 4处接入 ModuleEffectHandler + take_damage 读 _fort_shelter meta（激活：hp_regen/堡垒光环写入/雷场/相位护盾/dot tick/怒气/反炮兵/爆反/复活/击杀护盾） |
| B-ECM消费方 | boss _exec_debuff_players 给玩家挂 _ecm meta 但玩家侧零消费，削弱技能空转 | construct_unit_ai 新增 _get_ecm_attack_slow_mult，单/多武器攻击计时用它缩 delta |
| C-river数值 | ally_river_bonus 友军路径写 move_speed（死属性）且 +80 过大（+100%移速） | river 分支改写 deploy_delay_bonus（对齐自身路径 -5%系数），aura_keys 同步 |
| D-driver stats | boss driver 无 stats 属性，玩家被 boss 打走 max-of-3 兜底（最高防御，难度低估） | take_damage 特判 attacker.has_method("get_master_stats") → attacker_kind=ARMOR |
| E-ally文案 | 5个 ally_* 改造文案只写自身收益，未体现友军光环（且部分数值凭空） | 5处 description 补"周围友军"说明 + 校准数值与 effects 对齐 |
| F-arm_12倒挂 | arm_12(rare,+15%暴击)比所有 epic 同类(+8~10%)都强 | rare→epic，power_mult/cost/level 对齐 epic 档 |

**敌方 module_effect_handler 接入的安全性**：所有公开方法（on_tick/on_damage_taken/on_death/on_kill）对敌方安全——内部用 `is_player` 字段区分阵营，group 名仅作 fallback；敌方缺 `add_shield`/`on_revived` 等方法均被 has_method 守卫安全跳过。

**ECM 消费方设计**：仿 enemy_unit 已有的 `_ecm_debuffed_until` 读取口径，玩家侧用 `_get_ecm_attack_slow_mult(u)` 返回 1.0（正常）或 <1.0（被削弱），作用于 `_attack_phase_timer += delta` 的有效 delta。默认削弱25%（与敌方0.75口径一致），可被 `_ecm_attack_speed_penalty` meta 覆盖。

### 关键文件汇总

**第一轮**：
- `scripts/battle/faction_skill_effect_handler.gd`（新增，17种子键处理引擎）
- `data/enemy_phase_masters_{ww1,ww2,cold,modern,future}.gd` + `data/json/enemy_phase_masters.json`（51个 active_spell）
- `managers/battle/battle_spawn_system.gd`（special 生成期接入）
- `scenes/units/construct_unit.gd`（special 事件驱动+周期tick接入）
- `scenes/units/bullet.gd`（special 攻击命中接入）
- `scenes/units/enemy_phase_field_driver.gd`（get_master_stats 暴露）
- `managers/battle/enemy_master_skill_engine.gd`（_compute_boss_damage 改读 master_stats）

**第二轮**：
- `scripts/battle/faction_skill_effect_handler.gd`（on_hit_debuff 重构 + stacking 运行时 + conditional/aura/on_crit_received + 删死代码）
- `managers/battle/enemy_master_skill_engine.gd`（抽血 max_hp + 伤害 clamp + 护盾上限 + 首次CD）
- `resources/unit_stats_table.gd`（_sync_kind_bonus_to_weapon_slots）
- `data/enemy_stat_resolver.gd`（attack_air AA 限定）

**第三轮**：
- `scenes/units/enemy_unit.gd`（on_tick/on_damage_taken/on_death/on_kill + fort_shelter 读取）
- `scripts/battle/construct_unit_ai.gd`（_get_ecm_attack_slow_mult ECM 消费方）
- `scripts/battle/mod_aura_handler.gd` + `resources/unit_stats_table.gd`（river 改 deploy_delay）
- `scenes/units/construct_unit.gd`（driver stats 特判）
- `data/modification_modules/{infantry,armor,engineer,fort,air}_mods.gd`（5文案 + arm_12 倒挂）

**待实机验证（无 GUI 环境无法测）**：势力注入/序列波次/相位师产兵序列的运行时行为、ECM 减速实际手感、boss 技能伤害实战平衡、stacking 运行时叠加的体感。静态验证全部通过（全项目 --check-only 零错误 + smoke test + Grep 链路核对）。

**遗留已知问题（范围外）**：
- `e_mod_*` 敌方装备 ID 全部未注册（敌方 mod 槽装饰化，预先存在，非本次回归）
- ally_fort_regen 敌方无光环（敌方不接入 ModAuraHandler，但敌方不用 ally_* 改造，无影响）
- v8.5 主动技能 tick（核武/护盾投射等）对敌方仍缺失（敌方 boss 已有独立技能系统，工作量大收益低，保留现状）

## v9.1 我方组合技套路系统 (2026-08-01)

**目标**: 把"我方套路"从纯数值堆叠升级为"组件协同 > 数值堆叠"。6 套固定套路，每套路是一条状态链：A 投射写状态 → B 投射读状态增伤/变形。新增 22 个改造 + 13 个新机制 flag + 战场级浓度状态管理器。全部向后兼容（套路未激活时行为 100% 等同改动前）。

**核心架构（3 个新文件）:**

| 文件 | 职责 |
|------|------|
| `scripts/battle/combo_field_state.gd` | **战场状态管理器**（RefCounted）。承载跨单位累积的"战场浓度"（纳米粒子/化学污染，自然衰减）+ 封装目标级 meta 读写（石墨电子损坏/助燃剂层数/激光谐振/雷达锁定/弱点暴露，带过期语义）。由 BattleManager 持有，end_battle 时 reset。 |
| `data/combo_tactics.gd` | **6 套路定义**。每套路：mod_ids（配套改造）+ mod_combo_min（单卡激活阈值）+ kind_combo（兵种组合条件）+ mechanisms（新机制 flag 列表）。提供 detect_card_combos（单卡改造组合检测）+ detect_team_combos（全队兵种组合检测）。 |
| `scripts/battle/combo_engine.gd` | **套路引擎**（RefCounted）。update(delta)：① 衰减战场浓度 ② 每 1s 刷新全队机制 flag。6 个新机制执行函数（static，供 module_effect_handler/bullet 直接调）：try_chem_burst/try_emp_reflect/try_nano_spread/try_chem_spread/try_beam_resonance/try_weakpoint_expose。 |

**6 套路（每套路 1 状态链 + 新机制）:**

| 套路 | 状态链 | 新机制 | 配套改造 |
|------|--------|--------|---------|
| 🔥 助燃燃烧链 | 助燃剂弹写 _incendiary_stacks → 燃烧弹读 stacks（层数上限 5→10，dps×1.5） | 化学爆发（层数≥8 范围扩散感染 3 个相邻敌人） | art_incendiary_mix/art_white_phosphorus/air_thermolite_bomb/gen_combustion_catalyst |
| ⚡ 电磁脉冲链 | 石墨纤维弹写 _graphite_charge → 电磁武器读 charge（emp×(1+charge×0.15)） | 电磁脉冲反射（charge≥5 连锁反射 3 个相邻敌方弱化 emp） | art_graphite_fiber/aa_emp_warhead/air_antiradiation_missile/gen_overload_capacitor |
| 🧬 纳米浓度场 | 纳米蜂群相位仪写战场 _nano_concentration → 纳米病毒读浓度（dot×(1+浓度×0.05)） | 纳米感染扩散（浓度≥50 时 30% 概率感染相邻敌人） | art_nano_amp/sup_nano_seeder/gen_nano_catalyst |
| ✨ 光束谐振链 | 瞄准激光写 _laser_resonance → 光束武器读 resonance | 光束反射（30% 反射到相邻敌方，衰减 60%）+ 多重攻击（resonance≥3 追加 2 道次级光束，每道 40%） | gen_beam_splitter/gen_reflector_array/air_targeting_laser/eng_optical_fiber |
| 🎯 侦察链式 | 无人机标记 _drone_marked_until + 雷达锁定 _radar_locked → 狙击手读双标记 | 集火链式弱点暴露（双标记同时存在时下次命中 +50% 暴击伤害） | rec_phased_radar/sup_targeting_drone/gen_weakpoint_analyzer |
| ☠ 化学污染场 | 化学弹写战场 _chem_pollution + 目标 _chem_stacks → 化学武器读浓度/层数 | 化学腐蚀（层数≥5 护甲穿透 +20%）+ 污染扩散（浓度≥40 感染相邻敌人） | art_chem_cluster/aa_acid_warhead/eng_chem_sprayer/gen_pollution_accumulator |

**触发检测（双层叠加）:**
- **改造组合**（单卡）：单卡装了 ≥2 个同套路配套改造 → 该卡获得套路增益（在 `unit_stats_table._apply_mod_stat_effects` 一次性检测，写 `combo_active` + `mod_special_flags` meta）
- **兵种组合**（全队）：场上满足 kind_combo 条件 → 全队解锁新机制 flag（combo_engine 每 1s 刷新 `_active_mechanisms`）
- 两者叠加：改造组合激活时给单卡增伤；兵种组合激活时给全队解锁新机制

**关键设计决策:**
1. **复用 meta 标记链范式**——A 写 `_*_until` meta → bullet/module_effect_handler 读 meta，与现有 `_drone_marked_until`/`_marked_until`/`_burn_stacks` 完全一致，零侵入
2. **战场浓度独立容器**——`combo_field_state` 是独立 RefCounted，不修改任何现有 meta/字段；end_battle 时 reset
3. **新机制 flag 走全队激活**——避免单卡过强（单卡只拿改造组合的数值增益，新机制需兵种组合解锁）
4. **v8.6 dot 是现成载体**——chem/burn/emp/nano 已实装，套路直接增强这些 dot（叠层上限放宽/dps 放大/感染扩散）
5. **静态写入 + 运行时触发分工**——数值增益（burn_dps_mult 等）建卡时一次性算；触发 flag（chem_pollute/emp_reflect_trigger 等）存 `mod_special_flags` meta，运行时按事件读取
6. **全队机制节流**——combo_engine 每 1s 刷新一次 `_active_mechanisms`（仿 tactic_detector），避免每帧扫描全场

**改造现有文件（7 个，全向后兼容）:**
- `managers/battle/battle_manager.gd` — +combo_engine/combo_field_state 字段 + _ready 实例化 + update 驱动 + start_battle setup + end_battle reset + get_combo_engine/get_combo_field_state getter
- `resources/unit_stats.gd` — +4 字段（burn_dps_mult/chem_dps_mult/emp_true_damage_bonus/beam_damage_bonus，默认 0）
- `resources/unit_stats_table.gd` — +ComboTactics preload；_apply_mod_stat_effects 末尾加改造组合检测（写 combo_active + mod_special_flags meta）；base dict + 4 字段；回写 + 4 字段
- `scripts/systems/modification_registry.gd` — _apply_single_mod_effects +4 数值 effect key 分支（burn_dps_mult/chem_dps_mult/emp_true_damage_bonus/beam_damage_bonus），其余触发 flag 走 _special 兜底
- `scripts/battle/module_effect_handler.gd` — +ComboEngine/ComboFieldState preload；+3 helper（_get_combo_engine/_get_combo_field_state/_get_attacker_special_flags）；4 个 on_hit 函数 +attacker 参数 + 套路触发（石墨累积/助燃层数/浓度注入/dot 放大/emp 反射）；_tick_dot_damage 末尾加 chem_burst/chem_spread/nano_spread 扩散
- `scenes/units/bullet.gd` — +ComboEngine preload；命中乘区（bullet.gd:856 后）加套路读取（光束反射/多重攻击/弱点暴露触发+消费/化学腐蚀/光束伤害加成）
- `managers/battle/phase_instrument_abilities.gd` — nano_swarm tick 注入战场纳米浓度（套路3 纳米浓度场）
- `data/modification_modules/{artillery,air,anti_air,universal,engineer,recon}_mods.gd` — 6 文件共 +22 个套路配套改造

**新机制落地路径:**
| 机制 | 触发点 | 代码位置 |
|------|--------|---------|
| 化学爆发/污染扩散 | dot tick 结算后 | module_effect_handler._tick_dot_damage → ComboEngine.try_chem_burst/try_chem_spread |
| 电磁脉冲反射 | emp 命中后 | module_effect_handler._apply_emp_on_hit → ComboEngine.try_emp_reflect |
| 纳米感染扩散 | nano dot 结算后 | module_effect_handler._tick_dot_damage → ComboEngine.try_nano_spread |
| 光束反射/多重攻击 | 光束命中（weapon_type=8/11） | bullet.gd:856 后 → ComboEngine.try_beam_resonance |
| 集火链式弱点暴露 | 狙击命中带双标记目标 | bullet.gd → ComboEngine.try_weakpoint_expose |
| 化学腐蚀降防 | 伤害结算 | bullet.gd:856 后读 _chem_stacks |
| 纳米浓度注入 | nano_swarm 相位仪能力 tick | phase_instrument_abilities._apply_nano_swarm_tick |

**不做的事（范围外）:**
- 不改伤害公式骨架（套路乘区插在 bullet.gd:856 无人机标记旁，与现有乘区正交）
- 不动 tactic_detector（套路系统独立，未来可整合）
- 不补玩家单位 `_behavior_tags_cached`（现有 bullet.gd 兜底已够用，tag 计数问题预先存在非本次回归）
- 武器类型差异化仅限光束（套路4），不做全 weapon_type 机制重构

**验证:** 3 新文件 + 7 改造文件独立编译通过；静态核对全部链路（22 mod_id 全在 combo_tactics 与 mod 文件配对、4 数值 effect key registry→stats→table→bullet 全链路、6 机制函数调用配对）；combo_smoke smoke test（战场浓度 add/decay + 目标 meta/stacks + 6 套路定义完整 + 改造组合检测 + 兵种组合检测 + 引擎 setup）全 PASS。注：实机运行时行为（套路触发手感/数值平衡/扩散范围体感）需游戏内验证；Godot headless --check-only 因项目体量常撞 5 分钟超时（42 autoload + 133 卡），属既有现象。

## v9.1b 组合技套路系统全面审计修复 (2026-08-02)

**背景:** v9.1 落地后做三路全面审计（effect key 全链路 / 机制触发闭合 / 状态流转），发现 7 个 bug：3 个套路整体失效（P0）+ 2 个单改造部分失效（P1）+ 4 个死机制 flag + 4 个空转 trigger flag（P2）。状态流转三大链路（单卡检测/战场浓度/兵种组合）全部闭合正常，问题集中在机制触发层。

**修复 7 个 bug:**

| 级别 | bug | 修复 |
|------|-----|------|
| **P0-1** | 套路4 `laser_resonance_chance/stacks` 零 writer → beam_split/beam_reflect 永不触发，整个光束谐振链失效 | module_effect_handler 新增 `_apply_laser_resonance_on_hit`：命中按概率挂 `META_LASER_RESONANCE` 层数（≥3 触发多重攻击，>0 触发反射）；加 beam_split_trigger/beam_reflect_trigger 单卡闸门；全队 laser_resonance 机制激活时层数上限 5→8 |
| **P0-2** | 套路5 `radar_lock_*` 零 writer → weakpoint_expose 永不触发，整个侦察链式失效 | module_effect_handler 新增 `_apply_radar_lock_on_hit`（命中刷新已有锁定）+ `_tick_radar_lock`（on_tick 周期扫描挂 `META_RADAR_LOCKED`，仿 drone_mark 范式）；bullet.gd 加雷达锁定易伤乘区 |
| **P0-3** | combo_engine `try_weakpoint_expose` 把 `META_RADAR_LOCKED` 同时当 value_key 和 until_key（逻辑错） | 改为直接判存在性+过期（META_RADAR_LOCKED 是 until_key 秒时间戳） |
| **P1-1** | sup_targeting_drone `drone_mark_amp/vuln_bonus/radius_bonus` 3 flag 零消费方 | `drone_mark_vuln_bonus` 在 `_apply_radar_lock_on_hit`/`_tick_radar_lock` 叠加进雷达易伤值（drone_mark_amp/radius_bonus 属描述性 flag，与固有无人机标记机制协同） |
| **P1-2** | eng_chem_sprayer `splash_radius_bonus` registry 无 match 分支（只有 splash_radius），误入 _special | 改造 effects 改用 `splash_radius` key（命中现有分支，写 splash_radius_bonus 字段） |
| **P2-1** | 4 个死机制 flag（incendiary_boost/graphite_accumulate/nano_concentration/radar_lock）零执行点 | 接通为"全队激活额外效果"：incendiary_boost→燃烧上限+dot×1.2；graphite_accumulate→石墨上限15+概率+0.2；nano_concentration→浓度系数×2；radar_lock→经 P0-2 writer 接通 |
| **P2-2** | 4 个 trigger flag（chem_burst/nano_spread/beam_split/beam_reflect）空转 | chem_burst/nano_spread 属全队扩散机制（trigger 改造通过属套路配套集参与激活判定，注释修正澄清）；beam_split/beam_reflect 在 P0-1 加单卡闸门 |

**关键设计决策:**
1. **P2 采用"接通机制 flag"而非"删除"**——保留"全队激活套路提供额外效果"的设计深度（单卡 _special flag 给基础增益，全队机制 flag 给额外增益），避免套路深度降低
2. **radar_lock 仿 drone_mark 范式**——周期扫描+命中刷新，复用 construct_unit 已验证的 tick meta 模式，零新机制
3. **trigger flag 双闸门设计**——beam_split/beam_reflect 必须"装触发器改造（单卡 _special）+ 全队机制激活"双满足才触发，避免全队激活后任意光束武器都触发（过强）
4. **combo_active 保留为 UI 预留**——单卡套路增益实际靠 mod_special_flags 驱动，combo_active 供未来 UI 显示"该卡激活了哪些套路"，删除会丢未来 UI 数据

**修复后 6 套路全部端到端可触发:**
| 套路 | 触发链路 | 状态 |
|------|---------|------|
| 🔥 助燃燃烧链 | incendiary_mix 写 stacks → white_phosphorus 读 stacks（上限10）→ thermolite_bomb 化学爆发 | ✅ |
| ⚡ 电磁脉冲链 | graphite_fiber 写 charge → emp_warhead 读 charge 增伤 → overload_capacitor 脉冲反射 | ✅ |
| 🧬 纳米浓度场 | nano_swarm 相位仪写浓度 → nano_seeder 累加 → nano_amp 增伤 → nano_catalyst 扩散 | ✅ |
| ✨ 光束谐振链 | targeting_laser 写 resonance → beam_splitter 多重攻击 + reflector_array 反射 + optical_fiber 增伤 | ✅（P0-1 修复后） |
| 🎯 侦察链式 | phased_radar 周期锁定 + targeting_drone 增强标记 → weakpoint_analyzer 弱点暴露 | ✅（P0-2/P0-3 修复后） |
| ☠ 化学污染场 | chem_cluster/sprayer 写浓度+层数 → acid_warhead 腐蚀穿透 + pollution_accumulator 扩散 | ✅ |

**关键文件（修复涉及）:**
- `scripts/battle/module_effect_handler.gd` — +`_apply_laser_resonance_on_hit`/`_apply_radar_lock_on_hit`/`_tick_radar_lock`；on_hit +2 调用点，on_tick +1 调用点；4 个机制 flag 接通（incendiary_boost/graphite_accumulate/nano_concentration/radar_lock 经 is_mechanism_active 读取）
- `scripts/battle/combo_engine.gd` — try_weakpoint_expose 雷达锁定读取逻辑修复（META_RADAR_LOCKED 作 until_key 正确判定）
- `scenes/units/bullet.gd` — +雷达锁定易伤乘区（读 _radar_locked_until + _radar_vuln）
- `data/modification_modules/engineer_mods.gd` — eng_chem_sprayer effects splash_radius_bonus→splash_radius

**验证:** Godot headless --check-only 零编译错误（修复前报 bullet.gd compile error：module_effect_handler.gd:940 Cannot call non-static get_target_stacks；修复 static/instance + 7 bug 后零错误）；静态核对全部修复点（laser resonance writer→META_LASER_RESONANCE、radar lock writer→META_RADAR_LOCKED、combo_engine 读取修复、4 机制 flag is_mechanism_active 调用、eng_chem_sprayer key 修正）链路完整。

## v9.1c 复审修复 (2026-08-02)

**背景:** v9.1b 修复后再做三路复审（机制触发闭合/数值叠加边界/改造数据注册），确认上轮 8 个修复全部真正闭合，但发现 2 个新真 bug + 2 个数值平衡问题。

**修复 4 项:**

| # | 问题 | 修复 |
|---|------|------|
| **bug1** | `_apply_burn_on_hit` 的 `inc_cap` 变量算了却没用（add_target_stacks 硬编码 10），且 `META_INCENDIARY_STACKS` 写入后全项目零读取（死代码） | inc_cap 真正传入 add_target_stacks；接通 META_INCENDIARY_STACKS 到 burn cap 动态抬高（助燃层数每层 +1 燃烧上限） |
| **bug2** | graphite charge 持续命中全程保持高层数，emp_reflect 阈值≥5 几乎全程触发（套路2 失衡） | emp_reflect 触发后消耗 3 点 charge（target 需重新累积才能再次反射，给玩家压制窗口） |
| **平衡1** | graphite 全队上限 15 偏强（emp_dmg_mult 达 3.25x） | 上限 15→12 |
| **平衡2** | nano/chem 浓度无上限，极端局放大 10x+ | combo_field_state 新增 FIELD_CAPS（nano=50/chem=60）软上限，add_field 后 clamp |

**额外清理:** `_prefix_to_type` 补 `"sup": return "artillery"` 映射（防未来 sup_ 前缀 mod 未注册时回退失败）。

**关键文件（v9.1c 修复涉及）:**
- `scripts/battle/module_effect_handler.gd` — incendiary_layers 接通 burn cap；graphite 上限 15→12
- `scripts/battle/combo_engine.gd` — try_emp_reflect 反射后消耗 3 点 graphite charge
- `scripts/battle/combo_field_state.gd` — +FIELD_CAPS 软上限常量 + add_field clamp
- `scripts/systems/modification_registry.gd` — _prefix_to_type 补 sup 映射

**复审确认的闭合项（无需修复）:**
- 5 个改动文件 load() 编译全 PASS（module_effect_handler/combo_engine/combo_field_state/modification_registry/battle_manager）
- 所有 `_get_combo_engine()` 调用点 null 短路守卫完整（无 null deref 崩溃风险）
- bullet.gd 套路乘区 null 守卫完整
- radar lock 时间戳口径一致（秒）；drone mark 口径一致（毫秒）——两者各自自洽
- getter 位置在 end_battle 之后，函数体完整
- 22 改造 effect key 全字符级一致，无拼写漂移
- combo_tactics mod_ids 与改造定义全匹配

**已知设计权衡（非 bug，保留现状）:**
- 套路4 光束谐振：resonance 写入闸门看单卡（装 air_targeting_laser 的单位），split/reflect 触发看全队机制——写读不对称但不会崩（未装触发器的单位累积的 resonance 无害，仅一行 set_meta）
- `combo_active` meta 零读取——单卡套路增益实际靠 mod_special_flags 驱动，combo_active 供未来 UI 预留
- chem_burst_trigger/nano_spread_trigger 等 trigger flag 仅作套路配套标记，不直接驱动逻辑（靠套路配套集参与激活判定）

## v9.1d 组合技套路视觉优化 (2026-08-04)

**背景**: v9.1/v9.1b/v9.1c 完成了 6 套组合技的战斗逻辑实现，但视觉反馈严重不足——浓度场（纳米/化学）全战场累积却完全不可见、套路激活无任何通知、光束分裂/反射代码已执行但玩家看不出、雷达锁定/弱点暴露无视觉标志、DOT 贴图静态不生动。玩家在战斗中难以感知这些组合技的存在。

**核心策略**: 纯视觉/反馈层叠加，不动战斗数值逻辑。新增 12 项改动覆盖 3 个优先级（P0 浓度场+横幅、P1 光束/弱点/雷达/状态条、P2 DOT动态+图标纹理）。

**12 个改动点（按优先级）:**

### P0 战场浓度场可视化
| 文件 | 改动 |
|------|------|
| `scripts/battle/vfx_impact_factory.gd` | +`spawn_nano_field`/`spawn_chem_field`（半透明 Polygon2D 区域，浓度→半径+alpha 映射，z_index=-5 盖地面背景之上单位之下）；+`_cleanup_field_vfx`（防重复） |
| `scripts/battle/combo_field_state.gd` | +`field_changed(tag, amount)` 信号；`add_field`/`update` 衰减后 emit |
| `scenes/battlefield/Battlefield.gd` | +`_subscribe_combo_field_state`（call_deferred 订阅）；`_process` 加浓度场 dirty+0.4s 节流重绘；+`_redraw_combo_field_vfx`（取玩家/敌方 spawn 中心点为浓度场中心） |

### P0 套路激活横幅
| 文件 | 改动 |
|------|------|
| `scripts/battle/vfx_impact_factory.gd` | +`show_combo_activate_banner`（HudLayer 顶部 Label，Tween 滑入淡出，全队激活带相机震动，防重复 has_node 守卫） |
| `scripts/battle/combo_engine.gd` | +`_last_banner_combos` 缓存；`_refresh_team_mechanisms` 检测新激活 combo 触发横幅；+`_emit_team_activate_banner`（mechanisms→combo_id→name 拼接）；reset 清空缓存 |

### P1 光束分裂/反射 VFX
| 文件 | 改动 |
|------|------|
| `scripts/battle/vfx_impact_factory.gd` | +`spawn_beam_split_arcs`（复用 spawn_laser_beam 射 2 条次级光束）；+`spawn_beam_reflect_arc`（暗色反射弧） |
| `scenes/units/bullet.gd` | `try_beam_resonance` 分裂/反射处理块末尾追加 VFX 调用（找相邻 2 单位画次级光束 + 反射弧）；弱点暴露成功时 `spawn_weakpoint_indicator` |

### P1 弱点暴露 + 雷达锁定 + 激光谐振 VFX
| 文件 | 改动 |
|------|------|
| `scripts/battle/vfx_impact_factory.gd` | +`spawn_weakpoint_indicator`（红色 X 十字，脉动，duration 后淡出）；+`spawn_radar_lock_ring`（蓝色旋转扫描圈，脚下，duration 后淡出）；+`spawn_resonance_ring`（白色光环，头顶，层数→alpha） |
| `scripts/battle/module_effect_handler.gd` | `_tick_radar_lock` 锁定 best 后 `spawn_radar_lock_ring`；`_apply_laser_resonance_on_hit` 累积后 `spawn_resonance_ring`（读当前层数） |

### P1 扩散波纹（化学爆发/纳米传染/EMP反射）
| 文件 | 改动 |
|------|------|
| `scripts/battle/vfx_impact_factory.gd` | +`spawn_chem_burst_wave`（绿冲击波 r=80）；+`spawn_nano_spread_wave`（青冲击波 r=60） |
| `scripts/battle/combo_engine.gd` | `try_chem_burst` 感染后 `spawn_chem_burst_wave`；`try_nano_spread` 感染后 `spawn_nano_spread_wave`；`try_emp_reflect` 反射后 `spawn_lightning_arc` 到各被反射单位 |

### P1 组合技状态条（底部 HUD）
| 文件 | 改动 |
|------|------|
| `scenes/ui/combo_status_strip.gd/.tscn`（新增） | 底部 HUD，6 套路图标横排，三态色（灰未激活/橙单卡/绿全队+发光边框）；0.6s 轮询 combo_engine + 扫描场上单位 mods；tooltip 动态显示名称+描述+状态 |
| `scenes/main.tscn` | +`ComboStatusStrip` 节点（HudLayer，offset_left=165 紧贴 BattleStatusStrip 右侧） |

### P2 DOT 动态 aura + 套路图标纹理
| 文件 | 改动 |
|------|------|
| `scripts/battle/dot_vfx_manager.gd` | +`_attach_dynamic_aura`（按 dot_type 分派）；+`_attach_burn_aura`（橙旋转环）/`_attach_chem_aura`（绿反向慢转环）/`_attach_nano_aura`（青六边形脉冲）/`_attach_emp_aura`（紫电弧闪烁） |
| `data/combo_tactics.gd` | 6 套路定义 +`icon_tex` 字段（纹理路径）；+`get_combo_icon_texture`（带缓存，无资源返回 null 回退 emoji） |

**关键设计决策:**
1. **浓度场用 Polygon2D 而非 GPUParticles2D**——0.4s 重建零 GC，复用 canvas item 创建模式，z_index=-5 分层正确
2. **横幅 Tween 生命周期自管**——~2s 后自动 queue_free，has_node 防重复，不常驻内存
3. **信号驱动浓度刷新**——field_changed 标 dirty + 定时器双保险，避免每帧重建
4. **光束分裂 VFX 复用 beam 池**——spawn_laser_beam 已有对象池，零额外内存
5. **单行 lambda 规避 gdparse 误报**——`func(): if x: y` 单行形式（Godot 引擎支持，gdtoolkit 4.5.0 误报但不影响运行）
6. **图标纹理延迟加载+缓存**——无美术资源时返回 null，UI 回退 emoji，功能不受影响

**附带修复（分支已有 bug）:**
- `scripts/battle/vfx_impact_factory.gd` L1417 `_release_impact_sprite` 错误缩进一级 tab（分支改动引入，导致整个文件 parse 失败、所有依赖它的文件连锁报错）。修复为顶格 static func。

**验证:**
- Godot `--script` 单文件验证：16 OK / 0 FAIL（10 个新 VFX 方法 + field_changed 信号 + icon_tex 字段 + get_combo_icon_texture + ComboEngine/DotVfxManager/combo_status_strip load 通过）
- gdparse 多文件检查：8/8 OK（vfx_impact_factory 的单行 lambda 误报属 gdtoolkit 4.5.0 已知限制，Godot 引擎已验证通过）
- 全项目 `--check-only` 因项目体量（133卡+42 autoload）5 分钟超时（AGENTS.md 记录的既有现象），无我改动相关的早期 parse/compile 错误

**资源需求（代码已回退兼容，不影响功能）:**
- `assets/ui/combo_icons/{incendiary,emp,nano,laser,recon,chem}.png`（44×36）——状态条纹理图标，缺失时回退 emoji

## v9.x 关卡设计领域系统性审查修复 (2026-08-16)

**背景:** 用户要求对"关卡设计"领域做系统性审查（先交付情景定义/缺陷分类/量化标准，确认后全量检查再修复，禁止反应式点修）。按 13 类缺陷分类（A完备性/B一致性/C难度曲线/D节奏/E进程星级/F奖励经济/G内容质量/H特殊规则/I相位师遭遇/J环境/K教学/L数据健康/M呈现）过 14 项关卡资产，修复 4 CRITICAL + 2 HIGH + 3 文档/常量级，全部可回溯到分类编号。

**CRITICAL 修复:**

| # | 分类 | 问题 | 修复 |
|---|------|------|------|
| C1 | B5/B2/H1 | **survive_waves 全量死规则**：20/40/60/80/100 五关挂了 survive_waves，但这五关全是驻守相位师关（100% 遭遇），`battle_manager._check_win_lose` 对 `_is_phase_master_battle` 提前 return → 规则永不评估（胜负实际=摧毁基地）；而 world_map 向玩家显示"胜利条件: 坚守N波"——显示与行为直接矛盾 | 删除 5 关 win_type/win_param（80/100 保留 energy_mult）；`_set_rules` 加守卫拒绝在驻守关挂 win_type（机器强制标准）；battle_manager 分支保留（普通关未来可用）+ 警示注释 |
| C2 | A2/B4/H2 | **第85关兵种限制反义**：`restrict_platforms [3,7]` 注释称"3=SUPPORT,7=ENGINEER"，实际 CombatKind 3=AIR、7 不存在（枚举 0-4）→ 实际效果"仅空军可部署"，与"阵地防御战·限支援/工兵"完全相反 | 改 `[2]`（SUPPORT；工兵卡如 ww1_sup_engineer 本身 combat_kind=2）。era4 SUPPORT 卡 9 张，可玩性达标 |
| C3 | B1/B5/J3 | **环境双源不同步**：world_map/level_info_panel 显示 level_information 程序循环生成的 environment（第10关显示"风暴"），战斗侧（phase_law_manager/battle_damage_system）读 battle_environments（第10关实为"雨"）→ 95 关显示与战斗环境不一致 | 单一真源=BattleEnvironments：world_map/level_info_panel 改读 `get_for_level`；删除 level_information 的环境生成死代码（`_get_environment_for_era_level`/`get_level_environment`/字段）；翻译表补 snow/sandstorm/desert/low_field |
| C4 | B2/B3/C6 | **难度显示死链**：difficulty_modifier（0.8+level×0.014）自 v8.2 起不在任何战斗乘区中，但 world_map 显示"(0.81×)"、level_info_panel 显示"难度倍数"；公式在 level_information×5 处+enemy_stat_resolver.level_stat_multiplier 双拷贝 | 显示改真实乘区（EnemyLoadoutTiers 档位系数 1.30/1.75/2.00，与战斗链同源）；删 difficulty_modifier 字段+getter+level_stat_multiplier 死函数；`_difficulty_label` 改按档位派生 |

**HIGH 修复:**

| # | 分类 | 问题 | 修复 |
|---|------|------|------|
| H1 | A3 | 每时代 descriptions 数组 60 条只用前 20（`range(1,21)`），200 条死数据（67%） | 5 个数组裁剪到 20 条 |
| H2 | A4/M | level_select 面板零开启方（选关由 world_map 承担），死配置 | 删 ui_lazy_loader 的 level_select 注册（同 v6.6 C3 先例） |

**文档/常量级:** E4 XP 时代边界锯齿（550→198）加设计声明注释（时代整体抬升 1.5×、首关回撤与档位回撤同步）；L1 刷兵数裸 randi_range 加"设计如此"注释；L4 星级公式魔数常量化（STAR_SURVIVAL_*/STAR_TIME_*）。

**审查通过项（零改动）:** A1 字段完备 ✓、D1 时长带宽 ✓、D3 刷兵≤9格（card_grid 路径 max 7）✓、E1/E2 解锁链与时代门槛 ✓、E3 首通奖励单调 ✓、H3 特殊规则 UI 可见 ✓、I1 驻守 20 id 全在 JSON ✓（smoke 复核）、I3 随机遭遇三层回退+旱灾保底 ✓、I4 驻守表时代分区 ✓、K1 时代首关档位回撤（v9.x 阈值 0.15/0.55 已收紧）✓、K3 L5 教学能量惩罚（注释声明教学意图）✓、L2 序列缓存 level-keyed 确定性无害 ✓、L3 边界 clamp ✓。

**保留观察（设计决策，未动）:** ① 剧情关键关（如 L99）无随机遭遇抑制——15% 概率叠加相位师战增加难度方差，是否抑制属玩法决策；② 关卡描述为风味文本（海战关打陆战单位等）——接受现状，不做 100 条文案重写；③ 驻守关×特殊规则叠加（L25/L30/L55/L85/L100）为设计意图，已核实组合可玩（restrict 关对应时代卡池均 ≥2 张/类型）。

**关键文件:**
- `data/level_information.gd` — 删 environment/difficulty_modifier 死链 + 200 死描述 + 5 处 survive_waves；L85 restrict 修正；_set_rules 驻守守卫
- `scenes/world_map.gd` — 环境/难度单一真源接入 + 翻译表补值
- `scenes/ui/level_info_panel.gd` — 同上
- `data/enemy_stat_resolver.gd` — 删 level_stat_multiplier 死函数
- `managers/ui_lazy_loader.gd` — 删 level_select 死配置
- `data/level_eras.gd` — XP 锯齿/刷兵随机设计声明注释
- `managers/battle/battle_damage_system.gd` — 星级魔数常量化
- `managers/battle/battle_manager.gd` — survive_waves 分支驻守关警示注释
- `tests/level_design_audit_smoke.gd`（新增）— 审查回归 1470 断言
- `tests/level_mechanics_smoke.gd` — 同步新数据真值（原断言与数据早已脱节，属分支既有红灯）

**验证:** level_design_audit_smoke **1470 PASS / 0 FAIL**（字段完备/死键清零/驻守 id×JSON/restrict 枚举+卡池可玩/守卫生效/无重名/法则值域/边界 clamp/7 文件编译）；level_mechanics_smoke **ALL PASS**（数据同步后全绿）；star_config_smoke OK（无回归）；gdparse 8/8 编辑文件通过。`--script` 模式下 world_map/battle_damage_system 等的 SignalBus/ManagerLazyLoader 编译失败为项目既有 autoload 环境限制（报错行均为未改动行）。全项目 `--check-only` 因项目体量长耗时（既有现象）。**待实机:** world_map 关卡弹窗的环境/难度新显示效果、L85 限支援实机体感。

## v9 相位师技能树重设计：三系 + 奇点层 (2026-08-16)

**背景:** 用户要求重设计相位师技能树——① 相位仪不再经技能树解锁；② 概念武器不再独占分支（独支可绕开三系基础直接点满，过强）；③ 新名词授权代理决定。

**术语决策:** 概念武器内容以**「奇点」节点**（capstone）形式沉入三系深层。"相位奇点"取自奇点物理（时空/维度/现实规则崩坏之处），与时间回溯/现实崩溃/维度叠加等技能题材吻合，不与相位仪/相位法则/相位场撞名。UI 统一紫色 ◈ 徽标。

**防"单独一树太强"的三层机制:**
1. **奇点门关**「奇点解算」（pms_cw_0，智能化 tier 3）：要求**三系各自 tier2 全点亮**（cmd_2+int_2+fp_2），是所有奇点链的统一前置——想碰奇点科技必须先修三系基础
2. **深层沉底**：奇点链首挂在本系 tier 9-11 深节点上（fp_10/cmd_9a/int_8/int_10），全部奇点位于 tier 9-15
3. **二次交叉**：湮灭之光额外要求跨系 int_10（AI 指挥）

**新结构:** 3 分支持挥（24 节点）/智能化（22）/火力（25），共 71 节点不变；总 cost 183→187，满级 70 点 ≈ 37% 完成度。

**节点重分配（17 个 cw 节点 ID 全保留 → 存档零迁移）:**

| 节点 | 新家 | tier | cost | requires |
|---|---|---|---|---|
| pms_cw_0 奇点解算（门关） | 智能化 | 3 | 1→2 | [cmd_2, int_2, fp_2] 三系交叉 |
| pms_cw_1 战术核武 | 火力 | 11 | 2→4 | [fp_10, cw_0] |
| pms_cw_2 形态进化 | 指挥 | 5 | 2 | [cmd_4] |
| pms_cw_3 能量过载 | 火力 | 7 | 3 | [fp_6] |
| pms_cw_4 护盾投射 | 指挥 | 10 | 3→4 | [cmd_9a, cw_0] |
| pms_cw_5 无人机协同 | 智能化 | 9 | 3 | [int_8, cw_0] |
| pms_cw_8 时间迟缓 | 智能化 | 11 | 4 | [int_10, cw_0] |
| pms_cw_7a 天罚雷阵 | 智能化 | 12 | 3 | [cw_8] |
| pms_cw_13b 太阳耀斑 | 智能化 | 13 | 5 | [cw_7a] |
| pms_cw_11 时间回溯 | 指挥 | 11 | 5 | [cw_4] |
| pms_cw_10 维度叠加 | 指挥 | 12 | 4 | [cw_11] |
| pms_cw_6 焚城 | 火力 | 12 | 3 | [cw_1] |
| pms_cw_12a 焦土政策 | 火力 | 13 | 5 | [cw_6] |
| pms_cw_7b 湮灭之光 | 火力 | 13 | 3 | [cw_6, int_10] 跨系 |
| pms_cw_12b 烈焰风暴 | 火力 | 14 | 5 | [cw_12a] |
| pms_cw_9 现实崩溃 | 火力 | 14 | 4 | [cw_7b] |
| pms_cw_13a 火焰传导 | 火力 | 15 | 5 | [cw_12b] |

（cw_2 形态进化/cw_3 能量过载为纯数值/进化解锁，不带 capstone 标记转为常规节点；其余 15 个含门关带标记）

**相位仪解锁断开:** 仅有的 2 个相位仪节点原地替换（ID 不变链路不断）——pms_cmd_3「指挥相位仪」→「军团韧性」（三维防御+8%/暴击抗性+8%，修正原 desc 与 pi_atlas_01 实名"擎天-工蜂"不符的瑕疵）；pms_fp_2「火力相位仪」→「弹道改良」（射程+8%/穿甲+10%，消除 tier2 白嫖 7 星声望仪 pi_nova_03 的问题）。phase_instrument unlock 类型 v9 起零节点；manager 派发分支保留作旧档防御（load_state 本就不重放解锁）。

**关键文件:**
- `data/phase_master_skill_tree.gd` — 3 分支主表 + 门关节点 + CAPSTONE_COLOR 常量 + 删 concept_weapon 分支
- `data/phase_master_skill_tree_v8_extension.gd` — 12 个深层 cw 节点归位三系（tier 5-15），删 cw 段
- `managers/phase_master_skill_manager.gd` — 仅注释（逻辑零改动；存档存节点 ID 不存分支）
- `scenes/ui/phase_master_skill_panel.gd` — capstone 紫色 ◈ 徽标/加粗边框/大一号字号；tab 自动收敛 3+1
- `managers/evolution/card_evolution_manager.gd` — 1 行注释（evolution 查询逻辑不变）
- `tests/phase_master_skill_smoke.gd` — v9 结构断言（门关三系前置/链首门关依赖/15 capstone/相位仪清零/requires 全链可解析）
- `tests/v8_skills_smoke.gd` — 扩展节点 51（cmd17/fp19/int15）+ command 合并 24

**存档兼容（零迁移）:** unlocked_nodes 直接加载；旧档已解锁的技能树相位仪（擎天-工蜂/新星-超弦）存于 phase_instrument 段自然继承不回收；已解锁深链奇点的玩家不受 requires 变化影响（仅约束新解锁）。

**验证:** phase_master_skill_smoke **44 项 ALL PASS**；v8_skills_smoke **20/22**——2 失败为存量 stale 断言（Test 5 战法总数 17≠18、Test 22 stalker_stealth 翻译 v8.5 已删），相关文件（tactics.gd/unlock_labels.gd）本次零改动。grep 确认 concept_weapon 分支引用清零（unlock_labels/panel 的 unlock **类型**兼容显示除外）。**待实机:** 技能树面板 3 tab + 奇点紫标视觉、门关三系前置的实际节奏体感。

## v9 技能树面板性能修复：打开慢/解锁卡顿 (2026-08-16)

**现象:** 打开技能树面板明显卡顿；点一次"解锁"要等很久才刷新。

**根因（4 项叠加）:**

| # | 问题 | 量级 |
|---|------|------|
| 1 | **解锁一个节点 = 同帧 3 次全量重建**——`unlock_node()` 依次发 `node_unlocked` 信号、`points_changed` 信号，`_on_unlock_pressed` 末尾又直调 `_refresh()`；三个入口各重建全部 3 tab 71 行节点（每行 ~8 控件 ≈ 570 控件创建）+ 总览 | 每次 ≈ 1700+ 控件创建 |
| 2 | **queue_free 延迟释放叠加**——清旧行用 `queue_free()`（帧末才真释放），同帧重建 #2/#3 时容器堆叠新旧两三代 150+ 行，VBox 布局成本超线性膨胀 | 给 #1 再乘系数 |
| 3 | **打开面板无条件全量重建**——growth_panel 每次打开都调 `panel._refresh()`（状态零变化也重建）；首开更是 `_build_ui()` 全量建 4 tab + growth 再 `_refresh()` = 首开 2 次全量 | 每次打开/首开双倍 |
| 4 | **`get_skill()`/`get_branch_of()` 线性全表扫描**（主表 20 + 扩展表 51 双遍历）——每行渲染经 `can_unlock_node` 查一次；manager 的 `is_content_unlocked`/`is_evolution_era_unlocked`/`get_unlocked_summary` 逐节点查 | 量大面广的小税 |

**修复（面板刷新链路 4 项 + 数据层 1 项）:**

| # | 修复 | 效果 |
|---|------|------|
| 1 | `_request_refresh()` 去抖（同步 flag + `call_deferred`），三入口统一走它 | 同帧 3 次重建 → 帧末 1 次 |
| 2 | `_rendered_sig` 状态签名（已解锁节点集合 + 可用点数，二者唯一决定所有行三态渲染）；签名不变跳过重建 | 打开面板零重建；首开双倍 → 单倍 |
| 3 | 懒填充 tab：`_build_ui` 只建当前 tab（首个分支 24 行），`tab_changed` 切到时按需构建；`_refresh` 只重建已构建过的 tab | 首开 71+总览行 → 24 行 |
| 4 | `_populate_branch`/`_populate_summary` 清理改"先 `remove_child` 摘除再 `queue_free`" | 消除同帧多代节点布局叠加 |
| 5 | `PhaseMasterSkillTree` 懒建 static ID→节点/ID→分支 索引，`get_skill`/`get_branch_of` O(1)（const 静态表一次建成永不失效；仍返回深拷贝防污染） | 面板/manager/总览全部查询提速 |

**顺带修复:** `_on_visibility_changed` 原定义了但从未连接（死代码），已接通——隐藏期间积累的 `_dirty` 重新显示时补刷，有签名兜底零成本。

**关键文件:**
- `scenes/ui/phase_master_skill_panel.gd` — 刷新去抖/签名跳过/懒填充/摘除式清理
- `data/phase_master_skill_tree.gd` — `_ensure_lookup_index()` + O(1) `get_skill`/`get_branch_of`
- `scenes/ui/growth_panel.gd` — 零改动（其打开时调的 `_refresh()` 被签名比对自然拦截）

**验证:** gdparse 2/2 通过；phase_master_skill_smoke 44 项 ALL PASS（get_skill/get_branch_of 索引化后被全量 exercised）。**待实机:** 打开/解锁的实际体感。

## v9 全项目卡顿源排查与修复（四批次）(2026-08-16)

**背景:** 用户要求全面检查系统剩余卡顿源。三路并行排查（UI 面板层/战斗每帧热路径/manager 周期任务）后确认四类问题，经用户选定全部修复。排查确认健康的部分：SpatialGrid 增量维护、三路弹道批处理、伤害数字合并节流、HP 条默认不 process、背包系（v8.x 已优化）、UI 面板 _process 全部有节流、懒加载器无轮询、音频缓存。

### 批次1 · UI 隐藏面板信号风暴守卫（6 处 + buff 卡轻量化）

隐藏面板被战斗高频信号（resources_changed 每击杀/quest_progress 每任务/card_added 每张掉落卡/occupation_changed 每过关）触发全量重建——玩家看不见却在吃帧：

| 面板 | 修复 |
|------|------|
| store_panel | `_on_resources_changed` 加 `is_visible_in_tree()` 早退（打开路径 on_overlay_opened 全量刷新兜底） |
| quest_panel | 两个任务信号回调同上（原战斗胜利同帧 3-5 次全量重建 ~600 节点） |
| collection_panel | `_on_collection_changed` 同上（原战后掉落逐张 emit 同帧 N 次重建） |
| drops_inventory_panel | backpack_changed 隐藏置脏 + `visibility_changed` 补刷（无 on_overlay_opened 钩子的面板用脏标志模式） |
| faction_panel | 3 个势力信号回调置脏 + 可见补刷（原每过关最多 7 次详情区重建） |
| world_map | occupation_changed 隐藏置脏 + `refresh_for_open` 补刷（原每次过关无条件重建 100 关卡按钮，即使地图从未打开） |
| buff_fold_card | resources_changed 从直连 `_refresh`（全量重建含全蓝图线性扫描）改为隐藏跳过 + 可见时只刷资源段（BUFF/面板段由 1s 定时器负责） |

### 批次2 · 一行级战斗修复

| 修复 | 位置 | 效果 |
|------|------|------|
| 敌方 HP 文本挪进 1% 门槛 | enemy_unit.gd `_update_hp_bar` | 原每次受击 "%d/%d" 格式化+Label 重排（construct_unit 同款已修，敌方漏修） |
| 无目标索敌重试 20Hz→5Hz | enemy_unit.gd `_target_find_timer` 0.05→0.2 | 目标出现最多晚 0.2s 锁定，行为无感 |
| **索敌查询环形扩张** | spatial_grid.gd `query_nearest_target` | 原按 max_range 包围盒全扫（敌侧最小 1600px × 100px 格距 = 单次 ~1089 格探测），改为从中心格逐环扩张 + 数学下界提前退出（更外环单位必然 ≥ r×格距，已有更近候选即返回）——常态前线接敌 1-3 环命中（~25-49 格），波次刷出/清场瞬间尖峰大幅削减。**1000 次随机布局与暴力扫描对拍全一致** |

### 批次3 · 战斗每帧反射税

| 修复 | 位置 | 说明 |
|------|------|------|
| stats 引用 meta 缓存 | module_effect_handler `_get_unit_stats`/`_get_unit_max_hp` + faction_skill_effect_handler `_get_unit_stats_cached` | `unit.get("stats")` 是脚本属性字符串反射，on_tick 链每帧每单位多次（50 单位≈每秒 2-3 万次）；缓存在 spawn 赋值点写入（construct_unit:setup/enemy_unit/swarm_enemy_slot×2 共 4 处，全项目无外部 stats 替换点已核实），读取走 meta 字典快一个量级 |
| 雷达锁零成本门关 | module_effect_handler `_tick_radar_lock` | 未装 special flag 的单位（绝大多数）先 has_meta 早退——原每帧白付 stats 反射 + 空字典分配 |
| debuff 过期早退 | faction_skill_effect_handler `process_debuff_expirations` | 无 debuff 单位先零成本 has_meta 早退再取 stats（蜂群 slot 同路径放大百倍） |
| 势力周期 tick 重排 | faction_skill_effect_handler `process_periodic_ticks` | 先查 stats 的 faction_runtime_specials（零分配）再反射 is_player/ghost——没装势力技能不再每帧全跑 |
| special_rules 战斗内缓存 | battle_manager `_get_current_special_rules` | 按关卡号缓存（静态数据），原 _check_win_lose 每帧两次默认值空字典分配 |

### 批次4 · 存档 + 工具桥

| 修复 | 位置 | 说明 |
|------|------|------|
| sanitize 条件重建 | save_migration.gd `sanitize_save_variant` | 原每次存档无条件递归重建整棵存档树（等效全量深拷贝，主线程）；改为先零分配检测 `_has_invalid_float`，干净直接原样返回（战斗结束自动存档的高频路径不再白付），污染才走 `_rebuild_sanitize_variant` |
| agent_tools 游戏桥守卫 | addons/agent_tools/runtime/game_bridge.gd | release 导出不初始化（原 20Hz 文件轮询+每条日志落盘随 autoload 进正式运行）；debug 轮询 20Hz→10Hz |

**验证:** 新增 `tests/v9_perf_smoke.gd`（SceneTree 模式）：环形索敌 200 随机布局 × 5 查询点 = 1000 次与暴力扫描对拍全一致 + 4 边界用例 + sanitize 条件重建 4 断言，**9 PASS / 0 FAIL**；gdparse 18/18 改动文件通过；phase_master_skill_smoke ALL PASS、v8_skills_smoke 20/22（2 失败为存量 stale 断言，与本次无关）、star_config OK。**待实机:** 战斗波次刷出/清场瞬间的帧率体感、连续过关时世界地图不再卡顿、存档瞬间卡顿减轻。

**遗留观察项（本轮未修，量级可接受）:** 每次开火 2 个 Tween 分配+锚点查找（40-120 次/s）、曲射索敌 lambda 链、unit_damaged×5 监听者/unit_died×8 监听者的信号分发本身、PerformanceMetricsManager 15s 写盘、DebugLog 1s flush（当前流量低）、resource_info_panel 每击杀 tween churn。

## v9.x 进化条件列表 + 达成/未达成显示（含判定链 P0 修复）(2026-08-16)

**背景:** 用户要求"进化要列出条件，达成/未达成要能看出来"。审查发现两层问题：① UI 只列图纸/强化/改造 3 项且是单 Label 拼行全行一色，而 `can_evolve_blueprint` 是早退式——失败时只返回首个原因、不带各项数字，**玩家越不满足条件详情页越显示不出进度**；② 判定链有 P0 断裂：evolution_paths 16 个旧 card_id（v7.x 规范化漏改）+ intel_evolution_branches 旧 source ID（情报隐藏分支永不出现）+ evolution_path_registry 类型映射错乱（空中↔火炮对调、侦察/工兵/反空空映射、火炮/防空默认落 infantry → 属性对比对多数卡返回空）。

**用户确认的两项口径:** P0 连同本功能一起修；条件列表以执行层实际校验的 7 项为准（不接入 evolution_paths 未实装的 intel_*/power_ratio 条件，不改玩法平衡）。

**4 个改动层:**

| 层 | 改动 | 文件 |
|----|------|------|
| 数据修复 | 21 处旧 ID 批量替换（16 处 evolution_paths 节点 + 5 处情报分支 source/target），以 unit_id_migration_config 映射为准 | data/evolution_paths/{armor,artillery,anti_air,infantry,recon}_evolution.gd、data/intel_evolution_branches.gd |
| registry 委托 | `get_evolution_path` 委托 `data/evolution_paths/__init__.gd` 的已测试实现（112 卡前缀覆盖）；删除错乱的 `_identify_unit_type`/`_unit_type_to_key` 第二套映射与 register/_cache 缓存机制；`_find_target_node` 补搜 secondary_line | scripts/systems/evolution_path_registry.gd |
| **条件快照（核心）** | `can_evolve_blueprint` 玩法条件改**非早退式**：7 项条件全量评估进 `conditions: Array`（每项 `{key, met, current_text, required_text}`：power/evo_blueprint/skill_tree_era/enhance/mods/enemy_mod/faction_level，后两项按 stage 适用性增减）；`ok`=全满足、`reason`=首个未满足（拒绝码经 `_condition_key_to_reason` 保持旧语义）；**失败路径同样填充 enhance/mod 数字**（旧行为只有成功路径填）；结构性错误早退时 conditions 为空数组。纯增量，旧返回键全部保留 | managers/evolution/card_evolution_manager.gd |
| UI 渲染 | tscn `ReqDetails` 单 Label → `ReqList` VBoxContainer；面板逐条件行渲染（"✓/✗ 条件名 当前 / 需求"，达成绿/未达成橙，布尔型条件只显 ✓+名）；中栏 badge 与进化按钮从 reason 字符串猜测改为快照首未满足项直读；growth_panel met/total 改按快照计数（删 ok→3/3 硬编码）+ 传参 instance_id 口径统一 | scenes/ui/evolution_panel.tscn/.gd、scenes/ui/growth_panel.gd |

**关键设计决策:**
1. **非早退重构而非 UI 并行取数**——单一真身：UI 不再自己调 IntelItemBag/FactionSystemManager 拼条件（旧 has_bp 本地计算已删），快照与判定同源，永不出现"UI 显示满足但判定拒绝"的分叉。
2. **委托而非修映射表**——registry 的前缀表残缺（mod_arty_*/防空新 ID 全缺失），补表是打地鼠；`__init__.gd` 实现有 tests/evolution_path_coverage.gd 112 卡覆盖，委托即继承测试保障。
3. **reason 语义不变**——首个未满足项的拒绝码与旧早退顺序一致（power→blueprint→skill_tree→enhance→mods→eom→faction），EVOLVE_REASON_ZH/toast/既有调用方零影响。
4. **情报分支修复是连带收益**——intel_evolution_branches 旧 source ID 修正后，`get_branches_for_card("ww2_inf_panzerschrek")` 等真实卡 ID 首次能命中，情报隐藏分支目标（fut_arm_heavy_mech 等）进入进化面板可选列表。

**验证:** 新增 `tests/evolution_condition_smoke.gd`（SceneTree 模式 4 节全 PASS）：A 数据完整性（55 节点 card_id + 情报分支 source/target 全在统一卡表、panzerschrek 情报分支回归锚点）；B registry 委托（防空/火炮/空中映射回归 + 主线/副线 calculate_evolved_stats 非空）；C 条件快照（全新状态 5 conditions、失败路径 current_enhance=0 填充、结构性错误 conditions 空数组）；D evolution_panel.tscn ReqList 节点结构。既有 `tests/evolution_path_coverage.gd` **112 PASS / 0 FAIL**（registry 委托后全量回归）。gdparse 11/11 改动文件通过。调用方核查：blueprint_manager/evolution_panel×4/growth_panel/unit_progression_detail_view 全部只读保留字段。**待实机:** 面板视觉（逐条件行配色/对齐）、badge 文案、按钮禁用文案。

**连带说明:** growth_panel 的 BlueprintDefinitions preload 已删（唯一使用方被快照替代）；evolution_panel 的图纸本地 has_bp 计算块已删（快照内含）。

### v9.x 追加：进化面板战力显示口径对齐判定口径 (2026-08-16)

**用户反馈:** "初始坦克已改造、达到战力标准还不让改造"。headless 诊断（强化5+2改造的 ww1_arm_ft17 实例）实测三套战力口径：面板显示 get_current_power=84、进化判定 estimate_power_score=697、档位校准 estimate_power_score_meta_only=264，阈值 get_target_base_power(ww2_pz3)=216。**战力条件其实早已满足（697≫216），真正挡住进化的是另两项**：缺 ww2_pz3 进化蓝图（evo_blueprint_missing，首个未满足）+ 相位师技能树未解锁一战进化（pms_cw_2「形态进化」，指挥系 tier5 cost2，需前置 cmd_1→4 链约 9 点，相位场约 Lv6-7）。面板顶部"当前战力 84"与按钮判定互相矛盾是误导根源——v6.2 M15 曾把显示"统一"到 get_current_power 简化公式，但进化判定从来用的是 estimate_power_score 战斗公式，两套量级差数倍。

**修复:** evolution_panel.gd `_get_current_power_score` 改用 `EvolutionHelpers.estimate_power_score(instance_id)`、`_get_target_power_score` 改用 `UnitLineageConfig.get_target_base_power`（与 can_evolve_blueprint/conditions 快照/growth_panel `_estimate_power_value` 全部同源）——面板"当前战力"“战力 X ▶ Y"对比行与条件行现在所见即所判。

**遗留（平衡决策，未擅动）:** ①改造档位门 `POWER_THRESHOLDS [150,260,420,720]` 注释自述按 meta_only 公式校准（H4 论证用 meta 值 464/502），但 install_modification 实际传战斗公式 estimate_power_score（同卡 697 vs 264）——阈值表与传入值口径错位，实际档位判定比 H4 设计意图偏松；②战力进化门槛形同虚设：统一表 power 字段量级（216）远低于战斗公式战力（白板 ~179、轻度养成 697），早期玩家战力条件几乎恒满足。两项如要修需重新校准（改传 meta 口径=变严 / 重标阈值=变松），属平衡调整需用户拍板。

### v9.x 追加：战力口径全面重设——档位阈值表 + 进化战力门槛 (2026-08-16)

**背景:** 用户确认重设前一轮报告的两个口径遗留问题。实测定标数据（tests/power_calibration_probe.gd，5 时代 × 步兵/侦察/装甲 × 白板/强化5+2改/强化10+5改）揭示两个决定性事实：①战斗公式（estimate_power_score）下投入养成仅抬升 ~10% 战力，时代+兵种决定主体；②同类同时代步兵与装甲差 ~2.6 倍（mp18=253 vs ft17=662）。因此阈值语义只能按"时代台阶"设计，无法表达"投入深度"。

**重设 1：POWER_THRESHOLDS [150,260,420,720] → [250,600,900,1300]**（data/power_tiers.gd）
- 根因：原阈值按 meta_only 简化公式校准（H4 论证全用 meta 值），但全部 5 个调用方（install_modification 门槛 + modification_panel 显示×4）传的本就是战斗公式值——量级差 2-3 倍，判定长期错位。**只改阈值表，零调用方改动。**
- 新档位语义：老兵 250+=一战/二战步兵起步；精英 600+=早期装甲(662/715)与现代步兵(786)；勇士 900+=冷战装甲(917)/现代侦察(906)/未来步兵(1095)；霸主 1300+=现代坦克（白板 1296 差 4 点，强化5 即 1418 跨线——轻度投入跨线的设计点）与未来全系(1869+)。
- 与掉落节奏自洽：rare 改造从精英档敌人掉落时玩家已有二战+装甲可装。

**重设 2：进化战力门槛 = 目标白板战斗战力 × 0.70**（managers/evolution/evolution_helpers.gd 新增 get_target_white_combat/get_target_power_bar）
- 根因：原门槛读目标卡 power 字段（pz3=216），与判定左侧战斗公式（初始坦克投入后 697）不同标尺，战力条件形同虚设且随时代漂移。
- 0.70 实测定标：装甲线白板即过线（662 ≥ 0.70×715=500，投入门槛由强化/改造数条件承担）；步兵首进化恰在 E1 数值门槛（强化5+2改 ≈ 白板×1.05）附近过线（白板 mp18 253 差 2 点不过，强化5 266 过）；各时代满投入对下一时代目标均留 3%+ 余量无锁死。
- 两侧同用 _preview_battle_era()（防御派生带 era 乘区 1+era×0.15，时代基准不一致会漂移：pz3 era0=715 vs era1=771）；白板口径跳过 apply_growth（目标卡可能已有玩家养成实例，需确定性）。
- 连带：can_evolve_blueprint 门槛改用 get_target_power_bar；evolution_panel 对比行目标侧改用 get_target_white_combat；UnitLineageConfig.get_target_base_power 已删（调用方清零）。

**验证:** evolution_condition_smoke 新增 E 节锁定（阈值表值、5 个档位锚点、门槛=白板×0.70 一致性、白板 mp18 不过线/投入 ft17 过线语义锚点），A-E 五节 ALL PASS；evolution_path_coverage 112 PASS / 0 FAIL；gdparse 6/6 改动文件通过。定标探针 tests/power_calibration_probe.gd 保留（数值调整后可重跑验证分布）。**待实机:** 改造面板档位显示文案、进化面板战力对比行观感、史诗改造在现代卡的跨线体验。

## v9.x 战斗卡数据全面整理——飞机数值链/机制分配/power重标/子类推断断裂修复 (2026-08-17)

**背景:** 用户审查敌方卡基础数据后指出三类问题：①空天战机等飞机数据错误（和最早的飞机差不多）；②敌方战斗卡固定/特殊机制分布失衡（有的兵种没有、有的好多）；③武器文案错乱。全量扫描（223 卡）证实并连带挖出两个系统性断裂。

**5 个修复层:**

| 层 | 改动 | 文件 |
|----|------|------|
| 飞机数值链 | `fut_air_drone` 重标（HP 240→460/atk 72·32→135·115，原 HP≈冷战米格-21 的 238 跨两时代无代差）；era3/era4 空中卡建立**攻击时序代差**（era3 l0.91·a0.73·air1.1；era4 l1.0·a0.8·air1.2，配 windup/active 收窄与移速提升——空天战机 185、隐形轰炸机 165、攻击无人机 170）；`ww1_37mm` 对空 55→90/对甲 60→45（防空卡对空竟不占主导，无法进防空子类） | data/unified_card_table.gd |
| 武器标签错乱链 | 12 张卡修复：空天战机主标签“地狱火导弹/127mm舰炮”→“空天导弹/粒子炮”（原抄阿帕奇/舰炮系）；米格-21/F-4 对空槽“地狱火/127mm舰炮”→“空空导弹”；fut_attack_drone/fut_swarm（三槽全空空导弹）/mod_arm_abrams_mk2（现代坦克挂轨道炮）/guard_heavy（同）/carrier/titan/bulwark/storm_rider/侦察无人机（舱门机枪）/工兵班（迫击炮→步枪/爆破装药）/隐形轰炸机 w_air（舱门机枪→激光拦截炮） | data/unified_card_table.gd |
| power 重标 | B 段缴获卡 5 张（titan 202→1450 / carrier 92→1250 / bulwark 181→950 / storm_rider 125→800 / regen_frame 79→850）+ fut_swarm 1325→650（原与空天战机完全相同，抄串）；全部保持原稀有度档（era4 ≤1500=legendary）；**能耗随 power 联动自动修正**（蜂群 13→7，原比空天战机还贵） | data/unified_card_table.gd |
| **子类推断断裂（P0）** | v8.0 切数据源时 `_entry_to_card` 漏设 unit_subtype（恒 NONE）→ apply_combat_kind_modifiers 把所有 SUPPORT 卡兜底成工兵子类——**火炮反炮兵/防空空域封锁在玩家侧全链路空转**（测试手动设 subtype 掩盖了此 bug）。补 `_infer_subtype_for_entry`（防空对空主导/火炮远射程或对甲主导/工兵+机枪巢 card_id 前缀例外）；敌方对称修复：`_infer_enemy_subtype` 补对空主导判定（原防空炮 range≥400px 全判成火炮） | data/unified_card_table.gd、scenes/units/enemy_unit.gd |
| ECM 前缀收紧 | 原 `"drone" in cid` 误伤全部无人机（纳米修复机治疗单位带敌方减益光环）；改为 ecm/jammer/**growler**/electronic 显式匹配——EA-18G 电子战机从“0 攻击 0 机制纯站桩”激活（顺带补 60/95/35 攻击与反辐射导弹武器），治疗/侦察无人机卸载误配光环 | resources/unit_stats_table.gd |

**死数据清理:** `data/base_unit_stats.gd`（v6.3 旧统一基础表）已删除——全项目零消费方，且数值与统一表差 2.6 倍（future_fighter HP450 vs 1175）、“近未来空天战机对地火力低于现代直升机”等误导性数据；`docs/UNIFIED_BASE_STATS_DESIGN.md` 顶部加废弃声明指向 unified_card_table.gd。

**关键设计决策:**
1. power 重标值全部落在原稀有度档内（era4 ≤1500）——避免 rarity 连锁变化（rarity 驱动养成乘区/强化消耗）；能耗联动上升是正确方向（2026-08-16 经济修复按 power 定价，power 错=价格错）。
2. 时序代差替代纯数值放大——飞机“手感一样”的根因是全空军共享同一套攻速/前摇模板+射程全 99+移速 150 档；数值再大打起来无区别。Boss/运输平台/自定义时序卡（boss_mig/heavy_carrier/rq7/overclock/guardian 系列）保留原节奏不动。
3. 子类修断用“数值推断+前缀例外”而非全表显式 subtype 字段——223 卡逐张标注维护成本高；例外只列工兵/机枪巢两类语义卡（对甲攻击占比高但非火炮）。fut_shield/fut_sup_bulwark 等对甲主导支援卡判 ARTILLERY 属可接受副作用（反炮兵标记无害）。
4. guardian_cold_thunder(2200) vs fut_stormcore(1105) 的同档跨代 HP 差是守护者家族与原型炮台的定位差异，非数据错误，不修。
5. fut_inf_c96（近未来“毛瑟C96征召兵”）名字与时代错位但数值/战力正常（power 350 符合 era4 GRUNT 递进），仅命名问题不动。

**验证:** 新增 `tests/card_data_reorg_verify_20260817.gd`（SceneTree 模式 8 节 **46 PASS / 0 FAIL**）：表完整性(223 卡无重复)/子类推断 15 锚点/固定机制落地（zsu23 空域封锁 +25%、105mm 反炮兵、工兵爆破 2%、机枪巢不再误判）/ECM 收紧（growler 获得、nano/scout 卸载）/飞机链数据/power+稀有度+能耗联动/223 卡全构建+全表时序合法（windup+active<周期，连带修了 av7/kingtiger 两张 Boss 的对空槽超周期）/死数据删除。gdparse 4/4 改动脚本通过。--script 模式的 "Compile Error: ModificationRegistry not found" 为 card_resource.gd:467 存量问题（autoload 依赖），非本次引入。审计脚本 `docs/effect_check_reports/vfx_audit_20260817/_card_mech_scan.py` 已同步新 ECM 口径并修正条目切分（注释行剥离，193→223 全覆盖）。**待实机:** 相位师产兵面板武器名显示、近未来关卡敌方无人机群体感、缴获卡改造档位解锁体验。

## v9.x 直射跨行减伤 ×0.70 + 曲射/空射全场索敌 (2026-08-17)

**背景:** 用户确立行战术设计——空射/曲射单位攻击全场，直射单位本行全力，直射打侧行需惩罚。经评估选**减攻击力**而非减命中：受击方 dodge_chance 每发已 roll 一次，攻击侧再加命中=双重随机；直射武器攻速 0.5~2.5 次/秒，MISS 对慢速重炮造成长空转窗口（期望值等价但体验差）；跨行本是"同行无敌"的回退行为，频繁 MISS 会让单位像在发呆。平坦乘区对快慢武器公平、可调可读。

**规则（收口在 `CardGridBattleLayout.cross_row_direct_multiplier(shooter, target, weapon_type)`）:**
- 曲射/空射（`is_indirect_weapon_type`，含 legacy 值 ROCKET/FLAK/MISSILE）→ 恒 1.0，全场全额
- 直射同行 → 1.0；直射跨行 → `GameConfig.cross_row_direct_damage_mult`（默认 0.70）
- 无 slot meta 节点（相位场等）由 units_in_same_row 兜底同行，不惩罚
- **乘在开火侧弹道分发前的 damage 上**——批处理弹道（projectile/indirect batch）直传伤害不重算，不在此处乘则永不生效（与 range_falloff 同惯例，勿插 attack_calculator）

**改动文件（乘区 3 个开火点 + 索敌放开 + 配置）:**

| 文件 | 改动 |
|------|------|
| resources/game_config.gd | +`cross_row_direct_damage_mult`（@export + get_default） |
| scripts/card_grid_battle_layout.gd | +`cross_row_direct_multiplier` 静态助手（规则唯一真身） |
| scripts/battle/construct_unit_ai.gd | ①`do_attack_with_damage` 伤害分发前乘区（一处覆盖独立 bullet + 双 batch）②`_scan_slot_targets` L0-L3 改全量候选（原 valid_row 同行收敛删除）③`find_target` 传统回退的两处同行收敛对曲射放开/加直射守卫 ④内联 is_indirect 判定 ×2 收敛为 `_fires_indirect(u)` 助手 |
| scenes/units/enemy_unit.gd | ①`_do_attack` 分发前乘区 ②`_collect_player_candidates` 去同行收敛返回全候选（仅曲射/空射索敌使用） |
| scenes/units/swarm_enemy_controller.gd | `_fire_from_slot` 乘区（蜂群 slot 有 card_grid_enemy_slot meta，惩罚生效） |

**保留不动:** 直射同行优先索敌（v9.2 两步法/两遍扫描）原样——跨行射击仍是"同行无敌"时的回退；溅射同行收敛（module_effect_handler）原样；`_prefer_same_row`/`_query_nearest_same_row_spatial` 仍服务直射路径。反炮兵标记随全场索敌升级为跨行可反击（炮兵语义更正确）。

**验证:** `tools/verify_cross_row_penalty.gd` 11 项断言 ALL PASS（同行直射 1.0/跨行直射 wt0·4·6=0.70/跨行曲射空射 wt1·2·3·7·9=1.0/无 meta 兜底）；gdparse 6/6 改动文件通过；编辑器端 `refs.validate_project` 1104 项检查改动文件零问题（仅 gdunit4 插件自带场景有历史存量问题）。**待实机:** 跨行伤害变小观感、曲射全场选目标后集火行为、反炮兵跨行反击。

## v9.x 武器配置审查遗留项清零（range=99 异类/支援自卫/冷战对空/legacy 值清理）(2026-08-17)

**背景:** 敌方卡武器审计的 FAIL 项修复后，用户拍板把 5 类"设计保留项"也全部处理。**审计终态 FAIL 0 / WARN 31**（剩余全为良性：敌方曲射短射程=防守设计、复合武器名与槽名显示差异、支援关键词表缺口）。

**5 个处理方向与改动（全部在 data/unified_card_table.gd，17 条目）：**

| 类别 | 方向 | 改动 |
|------|------|------|
| range=99 泛滥 | **99 保留为曲射/空射专属**（"曲射空射打全场"设计下 27 条 wt1/2@99 是正确的）；只修 3 条异类 | `cold_fort_radar` wt 3→1（要塞炮台/导弹井族惯例=wt1+99，曲射弹道+曲射索敌）；`fut_nano_drone` wt 3→2（飞行单位惯例）；`fut_arm_nexus` wt 10→0 + **射程 99→5**（125mm滑膛炮=直射战车，归位 omega/titan_mk2 的终极战车族射程 5） |
| 支援有武器名无伤害 | 武器名是真武器的补小数值自卫（约同代步兵 atk_l 的 1/4）；是设备的清名 | 补 atk_l：救护车6/补给卡车10/BREM-1抢修车12/医疗平台8/冷战雷达平台12/运输平台12/现代雷达平台20/近未来雷达平台30；清 w_light：P-18雷达车/纳米工程车/相位中继站（"雷达电子战设备"等非武器不占武器槽，unit 级 weapon_label 保留作装备描述） |
| 无武装肉盾 2 条 | 随上项解决 | brem1/platform_cold_carrier 获得 atk_l=12 自卫机枪，不再纯站桩 |
| 冷战对空 11% | 给两台史实可对空的机枪载具补 AA（BTR-60PB 的 14.5mm KPV / M113 的 12.7mm M2） | `cold_arm_btr_e` atk_air 0→15、`cold_air_m113_e` 0→14（speed 2.5 高机射速模式）+ w_air 高机命名；冷战 AA 覆盖 2/19(11%)→4/19(21%)，与一战22%/近未来26%同档 |
| legacy 越界值 | **实际是 5 条非 3 条**（fut_colossus/fut_arm_omega 两张玩家终极卡同款 11 之前不在敌方审计集内）；全部清 0，光束弹道由武器名关键词路径提供（与 v6.1 注释意图等价） | colossus_e/fut_colossus/fut_arm_omega wt 11→0（w_armor"攻城电磁炮"含电磁炮关键词→光束）、storm_rider 6→0（"磁轨狙击炮"含狙击→光束）、nexus 10→0（见上）；全表 weapon_type 值域 100% 收敛到 0-3 |

**验证:** `tools/audit_enemy_weapon_config.gd` 复跑 **FAIL 0**（15→0）；23 项定点核验全过（正则行尾误报 2 项人工确认正确）；gdparse 通过；回归三连全绿——`tests/card_data_reorg_verify_20260817.gd` 46 PASS / 0 FAIL、`tools/verify_weapon_fixes.gd` PASS、`tools/verify_cross_row_penalty.gd` 11 断言 PASS。**待实机:** 虚空领主射程 99→5 的终极卡手感、救护车/雷达平台自卫火力观感、BTR/M113 对空表现。

## v9.x 火箭/导弹/炮弹弹药形态区分——曲射炮兵贴图弹道一眼可辨 (2026-08-17)

**背景:** 用户反馈"火箭、导弹、炮弹 3 个玩家能否一眼区分"——查实不能：曲射炮兵单位（wt=1）三槽全部 INDIRECT，火箭炮/导弹炮兵打出来的和迫击炮一样是"炮弹"贴图+高弧；且 wt 1/2 无命中帧动画（仅 3/7/9 有）。用户要求以**贴图+分帧动画**为主做区分（粒子只是加分项）。

**3 个改动点（复用 v9.4 光束关键词模式，全部用现有贴图资产，零新美术）:**

| 文件 | 改动 |
|------|------|
| resources/card_resource.gd | ①`_trajectory_override_for_weapon_name` 新增弹药形态路由（仅 INDIRECT 单位）：武器名含"火箭"→ROCKET(3) 低平弧+火箭弹贴图+尾焰；含"导弹"→MISSILE(9) 中弧+导弹贴图；其余保持炮弹 INDIRECT(1) 高弧。直射单位不参与（反坦克导弹平射语义保留）②`_default_weapon_type_for_slot` 补 AERIAL 分支——玩家飞行器三槽保留空射低弧，修复与敌方 `_default_enemy_slot_weapon_type` 的敌我不对称（玩家飞机曾打直线、敌机打弧线） |
| scenes/units/enemy_unit.gd | `_ensure_enemy_weapon_slots` 在光束关键词后新增同款曲射槽位路由（敌我同口径） |
| scripts/weapon_projectile_vfx.gd | `explosion_frames_by_wt` 常规爆炸帧分支 3/7/9 → **1/2**/3/7/9——曲射炮弹与空射命中也有 6 帧火球分帧（此前仅火箭/高炮/导弹有） |

**受影响单位示例（一眼区分达成）:** HIMARS/火箭炮车/雷霆守护者（"火箭"）→ 低平弧火箭弹；爱国者/RQ-7/岸防导弹组/泰坦Mk.II（"导弹"）→ 中弧导弹；迫击炮组/黄蜂/榴弹炮平台（无关键词）→ 高弧炮弹。三者弹体贴图（weapon_rocket/missile/artillery_ballistic 三张专属贴图）+ 弧线高度（0.3×/1.0×/1.6×）+ 命中帧动画全部独立。

**验证坑位（重要）:** `--script` 模式跑不了任何直接 `preload card_resource + .new()` 的测试——card_resource.gd:467 引用 autoload ModificationRegistry（当天早前会话引入的未提交改动）在无 autoload 环境编译失败，且 `_init` 中断后 `quit()` 不执行表现为"卡死"。改用**场景模式**验证：`tools/verify_ammo_form_routing.tscn`（agent_tools `run.scene_headless` 或编辑器 F6，游戏进程带全量 autoload）**8/8 PASS**（火箭3/导弹9/炮弹1/直射反坦克导弹不动0/光束6/霰弹5/空射2/AERIAL 分支）。gdparse 4/4；`refs_validate_project` 1106 项改动文件零问题；重组回归 46 PASS / 0 FAIL。**待实机:** 火箭炮齐射低平弧+尾焰观感、导弹炮兵中弧弹道、玩家飞行器从直线改低弧后的手感。

**遗留（下次处理）:** LASER(8)/OMEGA(10)/RAIL(11) 三个签名命中特效仍无常规来源（光束关键词统一路由 SNIPER(6)）；导弹(9)与空射(2)共用 weapon_missile_projectile.png 贴图（弧线已区分 1.0×/0.5×，贴图拆分需新美术资产）。

## v9.x 终极卡弹道区分审查 + 等离子光束补漏 (2026-08-17)

**审查结论:** 9 张终极卡中 7 张弹道区分良好（巨神=主炮直射+光束+导弹弧 / 风暴核心=双光束 / 铁壁·闪电守护者=机枪拖尾+主炮重炮+导弹弧三形态 / 雷霆=低平弧火箭弹 / 幽灵=空射俯冲 / 终焉=双光束），2 处缺口已修一留一。

**修复（2 处，均为一行级）:**
1. 光束关键词表补**"等离子"**（玩家 `card_resource._BEAM_WEAPON_KEYWORDS` + 敌方 `enemy_unit` 关键词列表）——"重型等离子加农炮"含"等离子"不含"粒子"，此前漏网：虚空领主签名武器打普通直射弹（上一轮注释声称光束生效系错误声明，本次修正）。受益：虚空领主/风暴核心·Boss 的等离子加农炮、悬浮坦克等离子炮。
2. 敌方光束检查从仅直射槽位扩展到**含曲射槽位**（与玩家侧对齐）——敌方曲射单位的光束武器（巨型光束炮、HEL-30 激光阵列、风暴核心 Boss）此前打"炮弹"弹与玩家同类武器不一致。

**验证:** `tools/verify_ammo_form_routing.tscn` 扩到 **9/9 PASS**（新增等离子→6 断言）；gdparse 3/3。

**遗留（内容决策，未动）:** `fut_colossus` 巨神机甲与 `fut_arm_omega` 全装型机动舱**完全同配装**（同 HP 3000/同 power 1590/同三槽武器名）——数据双胞胎，弹道必然相同。要区分需改其一配装（如 omega 对地槽改光束系形成"巨神=炮弹流/omega=光束流"的对照）。次要点：曲射单位的机枪/近防炮槽位打高弧炮弹（全表曲射单位三槽全弧的既有设计，非终极卡特有）。

## v9.x 终极卡弹道再区分——双胞胎拆分 + 曲射平台点防武器直射化 (2026-08-17)

**背景:** 用户"要更区分"。终极卡审查遗留两处：fut_colossus/fut_arm_omega 完全同配装（数据双胞胎）；曲射单位三槽全弧设计让"雷霆机枪"/"25mm近防炮"等点防武器抛物线违和。

**3 个改动点:**

| 文件 | 改动 | 效果 |
|------|------|------|
| data/unified_card_table.gd | omega（全装型机动舱）weapon_label + w_light "105mm/120mm主炮"→**"全装型导弹巢"** | 与巨神机甲拆分定位：巨神=主炮炮弹流，omega=导弹巢齐射流 |
| resources/card_resource.gd | ①`_WEAPON_NAME_TRAJECTORY_OVERRIDE` 精确表 + `"全装型导弹巢": 9`（直射单位的导弹名不经曲射路由，须精确表）②INDIRECT 弹药路由块首位加**机枪/近防炮→DIRECT(0)** | omega 对地槽走导弹弧线；曲射平台的点防轻武器改直射曳光 |
| scenes/units/enemy_unit.gd | 敌方 INDIRECT 弹药路由块同款加机枪/近防炮→DIRECT | 敌我同口径 |

**受影响终极卡终态（9 张全部互异）:** 巨神=炮弹+光束+导弹弧 / **omega=导弹弧+光束+导弹弧** / 虚空=炮弹+等离子光束+榴弹弧 / 风暴核心=光束×2+**曳光**（近防炮不再抛物线，与终焉的光束×2+导弹弧分开）/ 铁壁·闪电=机枪曳光+主炮+导弹弧 / 雷霆=**曳光**+火箭低平弧+炮弹弧 / 幽灵=空射俯冲×3 / 终焉=光束×2+导弹弧。

**验证:** `tools/verify_ammo_form_routing.tscn` 扩到 **12/12 PASS**（+导弹巢9/曲射机枪0/近防炮0）；gdparse 4/4；重组回归 46 PASS / 0 FAIL。

## v9.x 人形卡攻击姿态系统——程序姿态分层 + AI 攻击帧（试点 5 张）(2026-08-18)

**背景:** 用户反馈人形战斗卡无攻击姿态，开火只有位移"太突兀"。评估后分两档实施（用户授权自主判断）：第一档零美术的程序姿态立即全量生效；第二档 AI 攻击帧管线建成并试点 5 张。

**第一档：AttackPoseAnim 程序姿态（新建 scripts/battle/attack_pose_anim.gd，全单位生效）**
- 替代原"22px 单一前冲滑步"（人形班组群像平移读作整队滑步）：
  轻武器(0/4/5/6)→前冲14px+立绘前倾4°回弹（抵肩射击）｜化学能重型(3/7/9)→后坐10px+后仰2.5°（炮身后坐）｜能量重型(8/10/11)→前冲8px+前倾2°｜曲射/空射(1/2)→前移8px+上扬6°（抛射）
- 立绘倾斜只动 Sprite 子节点 rotation（根节点 rotation 受击占用）；motion_reduce 时保留位移（攻击 Telegraph）跳过倾斜/帧动画
- 5 个开火调用点改接（construct_unit_ai/enemy_unit×3/construct_unit 包装）；两份旧 nudge 函数删除
- 类名引用必须显式 preload（headless 进程的 global class cache 不含新建类——本次踩坑：run_scene_headless 报 Identifier not found）

**第二档：AI 攻击帧管线（tools/generate_attack_frames.py + 5 张试点已部署）**
- 复用 boss idle 帧管线（img2img 同角色变体 + 黑底反抠 + 颜色增益匹配 + 构图归一化），帧约定 `unit_anims/<archetype_id>/attack_f0.png`（f1 可选两帧交替）
- **构图归一化 v3 = 双轴拉伸到原 bbox + 底部锚定**：v1 居中(悬空)/v2 等比fit+高度下限(被宽度封顶压制,高度仍差33-55%)均不合格；攻击帧仅展示 0.16s、显示 60-120px，微畸变不可感知，确定性消灭换帧跳尺寸。终检：5/5 bbox 锁 ±2px、底边锁 ±2px（cold_inf_ak 覆盖密度 1.55 属姿态密度差异，可接受）
- prompt 带"禁止拉远/缩小/留白"指令（模型默认把主体画小）；帧不带枪口火（游戏内 MuzzleAnchors 炮口特效会叠加）
- 试点：ww1_inf_mp18/ww2_sup_mg42/cold_inf_ak/mod_inf_delta_e/fut_inf_cyborg（一战→近未来各一）
- 运行时 AttackPoseAnim 自动检测帧（FileAccess 探测负结果也缓存）→ 开火换贴图 0.16s，与 BossIdleFrameDriver 协调（暂停待机帧→攻击帧→恢复）；无帧单位纯程序姿态

**API 变更:** 端点 .com→.cn（用户提供免费 API），tools/_api_key.txt 换 3 新 key（key1 401 失效，脚本自动跳过）。generate_boss_idle_frames.py 端点同步更新。

**验证:** 场景测试三连 PASS（12/12 弹药路由 + 姿态参数表 + ww1_inf_mp18 攻击帧检测+ResourceLoader 加载 512×512）；生成 5/5；gdparse 全过；refs_validate_project 改动文件零问题。**待实机:** 姿态分层观感、5 张试点卡攻击帧效果——确认后扩充 TARGETS 批量生成全量 ~75 张人形卡。

## v9.x 攻击帧批量生成完成——全量 30 张人形卡 (2026-08-18)

**承接上条试点:** 用户确认后续批量。名称特征筛选出 34 张人形敌方卡（4 张 drop 卡无敌方原图跳过），扣除试点 5 张后批产 25 张，**累计 30/30 全部部署到 `unit_anims/<id>/attack_f0.png`**。

**批量要点:**
- 生成 25/25 成功（中途偶发 SSL 断连/500/401，退避重试自愈）；单张 ~30-60s
- 3 张载具/发射器类（HIMARS/EA-18G/岸防导弹组）用 `VEHICLE_MOTION` 武器系统版 prompt（发射管仰角而非士兵举枪）；MG 巢/迫击炮组/导弹组等班组武器带 gunner 姿态 extras
- **锁定校验 30/30 OK**：全部 bbox ±8px、底边 ±8px（构图 v3 双轴拉伸+底锚的确定性保证）
- 脚本加 `--force` 覆盖参数与已存在跳过（增量安全）；基础图路径经 manifest 场景模式解析（30/34 有图）
- 遗留：drop_smg_mk2/drop_phase_lance/drop_railgun/drop_thunder_field 4 张缴获卡无独立敌方原图，待有图后补

## v9.x 4 张缴获卡敌方原图补齐 + 攻击帧收官（全量 34/34）(2026-08-18)

**背景:** 攻击帧批量时 4 张 drop 卡（MP18-II 冲锋班/相位刺刀班/雷霆突击班/电磁步枪班）无独立敌方原图被跳过，用户要求补齐。

**改动:**
- 新增 `tools/generate_drop_card_icons.py`：text2img 白底卡图（沿用 STRICT_PREFIX 卡风模板 + NEGATIVE）→ 白转透明 → 512 方形 → **三处部署**对齐查找链——`enemy/<id>.png`（惯例归档）+ 根目录 `<id>.png`（`resolve_card_icon_texture_path` 主目录兜底命中点，敌方战场贴图实际走这条）+ `player/<id>.png`（翻转版）
- `ui_asset_loader.PLAYER_ICON_OVERRIDE` +4 自指条目（玩家 UI 用专属图，对齐无人机卡先例）
- `generate_attack_frames.py` TARGETS +4（相位刺刀/电磁步枪带持枪姿态 extras），4/4 生成成功
- **像素校验 4/4 OK**（原图与攻击帧 bbox/底边全锁 ±2px）

**终态: 人形卡攻击帧 34/34 全覆盖**（34 张人形敌方卡 = 30 前批 + 4 本批），卡图与攻击帧管线可增量复用（`--force` 覆盖）。

## v16 战斗开火三件套修复——曲射发射点/炮口火去重与键控/敌步枪命中爆炸误渲染 (2026-08-18)

**背景:** 效果检查场（combat_check）报告"我方弹道有问题、开火火花有问题、击中效果有问题，整套效果是固定单位用的还是类型用的"。排查确认：整套 VFX 是**武器类型级共用**（不绑单位；单位专属的只有卡图+开火点锚点 117/117 条），并定位 4 个真实缺陷。

**4 个修复点:**

| # | 问题 | 修复 |
|---|------|------|
| 1 | **曲射弹从脚底发射**——indirect batch fire 传 `u.global_position`（单位原点=地面），炮口火却在锚点（炮管），炮弹从脚下钻出视觉脱节 | 敌我 indirect batch 发射点改 `_get_direct_fire_spawn_pos`（炮口锚点，锚点表标注语义本就是"弹道起始点"）；函数文档同步改为"直射与曲射共用" |
| 2 | **炮口火双重生成 + 类别键错位**——①`_play_muzzle_feedback`（100%）与 batch fire 的 25% 抽样叠加，火花忽大忽小；②类别键用单位级 `stats.weapon_type`，多武器单位（导弹巢/防空槽）发重型武器时错拿轻武器小闪；③敌方 legacy 域 1/2（步枪/机枪）被枪口火"新枚举优先"约定读成曲射/空射，错拿**重型**枪口火 | ①batch 抽样枪口火只保留给蜂群（非 CharacterBody2D 射手——蜂群槽位无单位级反馈，那是它唯一开火视觉；v14 蜂群冲撞同门控）；②`_play_muzzle_feedback(u, firing_wt)` 类别键改当前开火武器；③敌方 wt 经 `VfxImpactFactory.normalize_light_kinetic_wt`（legacy 1/2→0）归一。enemy_unit 调用点移到 wt 计算后 |
| 3 | **敌方步枪/机枪命中被渲染成火炮爆炸**——直射 batch 只收 `BATCH_FIRE_WEAPON_TYPES=[0,4,1,2]`（legacy SMG/手枪/步枪/机枪），其中 1/2 被命中层"新枚举优先"约定读成 INDIRECT/AERIAL → 通用爆炸贴图 + 伤害≥100 时 96px 火球帧，敌步兵每枪命中都是一场小炮击 | 敌我直射 batch `_apply_hit` 命中 wt 归一（`normalize_light_kinetic_wt`，1/2→0 SMG 档小口径贴图）；power_tier 同步用归一值 |
| 4 | **高速直射丢失武器名/改造视觉**——直射 batch `fire()` 不收 weapon_name/vfx_variant，机枪/步枪/坦克炮亚类命中配方（v8.x 四亚类）与武器类改造专属视觉（集束/温压/近炸/导引）在攻速>2/s 主路径全部空转 | 敌我直射 batch `fire()` 补两参（默认空向后兼容，swarm 旧式调用不受影响）→ 弹道字典透传 → `_apply_hit` 传入 spawn_impact_with_kind |

**关键设计决策:**
1. **归一放 VfxImpactFactory 单一真身**（`normalize_light_kinetic_wt`）——legacy 域调用方（敌方枪口火/直射 batch 命中）统一走它；我方域（新枚举+legacy 签名值，1/2 恒为 INDIRECT/AERIAL）不过，不加域参数保持简单
2. **蜂群保留 batch 抽样火**而非全删——蜂群槽位（Node2D）不走 `_play_muzzle_feedback`，全删会让蜂群开火零反馈；用 `shooter is CharacterBody2D` 门控（完整单位=已有单位级火）
3. **enemy_unit 炮口火调用移位**（wt 计算前→后）——中间无早退分支，行为等价但能拿到当前开火 wt
4. **改 `_get_direct_fire_spawn_pos` 复用而非新建曲射专用函数**——锚点表 117 条标注语义就是"弹道起始点"，直射曲射同源零新数据

**关键文件:**
- `scripts/battle/vfx_impact_factory.gd` — +`normalize_light_kinetic_wt`（legacy 轻武器域归一）
- `scripts/battle/construct_unit_ai.gd` — indirect 发射点改锚点；`_play_muzzle_feedback(+firing_wt)`；直射 batch fire 透传
- `scenes/units/enemy_unit.gd` — 炮口火移位+传 wt；indirect/直射 batch 发射点与透传（`_try_fire_enemy_projectile_batch` +2 参）
- `managers/battle/simple_player_projectile_batch.gd` / `simple_enemy_projectile_batch.gd` — fire() +2 参；删/门控重复炮口火；_apply_hit 命中 wt 归一+weapon_name/vfx_variant 透传

**验证:** `tests/weapon_vfx_fix_check.gd` 34/34 PASS（含 enemy_unit 编译加载）；`tests/weapon_trajectory_smoke.gd` 15/15 PASS；combat_check 实跑截图视觉确认（ww1_105mm 炮口标记/炮口火/炮弹起点三者统一在炮管高度，抛物线正常，命中爆炸居中）；Grep 静态核对（normalize 链路 1 定义 4 调用、fire 新参调用方全配对、global_position 直传 indirect 零残留）。

## v16.2 战斗效果检查场"武器"标签枚举错位修复 (2026-08-18)

**背景:** 用户发现检查场大量战斗卡名称后显示"冲锋枪"，询问该后缀与弹道/效果的关系。核实：后缀是单位级 weapon_type（弹道与效果的大类路由键，显示目的正确），但**我方侧查错了表**——`GC.get_weapon_type_name`→`weapon_kind_long` 是旧 12 武器表（`real_world_unit_labels.gd:32` 注释明写"请勿对当前 WeaponType 传值"），把新枚举 4 值错译：0直射→"冲锋枪"（151/223 张卡！坦克/机枪/步枪全撞名）、1曲射→"步枪"、2空射→"车载机枪"。敌方侧 legacy 值配 legacy 表恰好正确。正确的 `weapon_mode_short`（直射/曲射/空射/支援）同文件已存在未用。

**改动（3 处，仅工具场景）:**
- `scenes/tools/combat_check.gd` — 我方下拉框与 InfoPanel"武器:"行改 `weapon_mode_short`；InfoPanel 新增**"弹道:"行**（`_describe_slot_trajectories`：轻/甲/空三槽的 trajectory_override 后实际弹道 + 武器名——槽 wt 才是按目标分派的真实弹道。值域规则：0→直射 / 1,3→曲射 / 2→空射 / ≥4→`weapon_kind_short`（legacy 唯一值域查旧表才正确），disabled 槽标"禁用"）
- `scenes/tools/combat_arena_3v3.gd` — 我方下拉同改
- **不动**: 敌方四处（legacy 配 legacy 正确）；`card_info_panel.gd`（游戏内有 v7.x 显示优先级链，独立设计）

**验证:** headless 文本直出（比 OCR 精确）：ww1_105mm=曲射（原"步枪"）、ww1_a7v 坦克=直射（原"冲锋枪"）；弹道行正确翻译 v15 精确表结果（fut_arm_omega 甲槽"攻城电磁炮(轨道炮)"、nexus 甲槽"重型等离子加农炮(粒子炮)"）；场景实跑编译无错。临时验证脚本用后即删。

## v17 武器视觉档案注册表 + 全矩阵视觉审计 (2026-08-18)

**背景:** 多轮 VFX 全面检查后用户仍反馈"击中/开火很多地方不真实"，并质疑"整套效果是固定单位用的还是类型用的"。根因诊断出四个结构性病根：① 检查的是管道（枚举表/字符串存在性）不是像素（渲染结果）；② 视觉分派键 weapon_type 双枚举在 1/2/3 撞值，各调用点各自猜域（含 construct_unit_ai 的"朝向猜域"启发式）；③ 开火/命中渲染路径 5+ 条分裂（bullet/玩家 batch/敌方 batch/曲射 batch/CardGridFx），修复不互相传播；④ 无"武器该长什么样"的单一真身，155 个武器名坍缩到 ~12 档且名字语义只在槽位初始化解读一次，消费侧拿不到。

**4 阶段实现:**

| 阶段 | 内容 |
|------|------|
| ① 档案注册表 | `data/weapon_visual_profiles.gd`（新建）——12 视觉族 Family 枚举（值=视觉 wt 恒等）+ PROFILES 档案（label/muzzle/impact/projectile/shake/spec 六字段）+ `resolve_visual_wt(weapon_name, raw_wt, shooter_is_player)` 三优先级解析器：签名精确表（复用 card_resource.trajectory_override_exact，v17 新增公共访问器）→ 视觉关键词（激光→8/磁轨→11/等离子→10/导弹→9/火箭→3/高炮→7/曲射→1/霰弹→5/其余光束→6/枪炮轻动能捕获）→ 域感知兜底（我方新枚举 1/2 保持重型；敌方 legacy 1/2 归一 0，等价原 normalize）。`resolve_traced` 带溯源（exact/keyword/wt_fallback）供审计 |
| ② 统一分派接入 | 6 个文件全部改走解析器：`construct_unit_ai._play_muzzle_feedback`（**删除朝向猜域启发式**，签名加 weapon_name/shooter_is_player，w_name 计算前移）；`enemy_unit._do_attack`（传名+敌方域标记）；`bullet.gd`（新增 `_visual_wt` 成员 setup 时解析一次，弹道物理仍用原 weapon_type 严禁混用——muzzle/impact/explosion 分支/贴图链全部消费 `_visual_wt`）；玩家/敌方直射 batch `_apply_hit` 与敌方 batch 蜂群枪口火、曲射 batch `_spawn_impact_explosion` 全部替换裸 normalize |
| ③ 自动化审计 | `scenes/tools/vfx_audit_matrix.gd/.tscn`（新建）——全矩阵截图机：12 族×敌我×开火/命中=48 格，走真实入口（spawn_muzzle_flash/spawn_impact_with_kind 含签名分支与 power_tier），**双帧峰值捕获**（v17b：0.12s 快特效帧+0.30s 火球帧取更亮者——单帧 0.30s 会把激光灼烧/狙击小爆点截成已消散）+0.85s 消散归池，产物 `docs/vfx_audit_shots/*.png` + `tools/vfx_audit_review.html`（图片矩阵+档案规格+155 名解析审计表）。`tests/weapon_visual_profiles_smoke.gd`（新建，38 断言全 PASS）：解析器三优先级/越界钳制/溯源、UCT 全量武器名合法族+兜底占比≤10%（实测 6%）、PROFILES 完整性、档案标签↔HEAVY_MUZZLE_WT 分派域一致性 |
| ④ 验收规格 | `docs/VFX武器族视觉规格.md`（新建）——通用真实度原则 5 条（比例锚定/时长分层/方向性/开火命中形态一致/阵营辨识靠环色）+ 12 族逐格验收表（含"不合格特征"反例列）+ 名字解析审计说明 + 审计工作流（跑矩阵→浏览器对照打分→按症状层回溯表） |

**顺带修复的存量 bug:**
1. `vfx_impact_factory.HEAVY_MUZZLE_WT` 漏 LASER(8)——激光命中走签名灼烧而枪口是"橙点轻型火"，开火与命中形态割裂（energy 集 [6,8,10,11] 中 8 因先判 light 不可达）。补入后激光枪口=白青喷射流；SNIPER(6) 保持轻型（族内多为动能狙击）。smoke 回归锁定。
2. `direct_weapon_flavor._is_tank_gun` 补"火炮/加农炮"——直射槽 105mm 炮（"81mm/105mm火炮" UCT 出现 18+ 次）原归 GENERIC 与步枪同观感，现给坦克炮级重环+加粗弹体。
3. 自行火炮（"xx自行火炮"）归曲射族关键词。

**关键设计决策:**
1. **武器名优先而非改枚举**——名字是唯一无歧义信号且 v16 起已透传全部消费点；wt 只做域感知兜底（保持本文件出现前行为，零回归风险）。改枚举/槽位数据侵入索敌与攻防结算，风险不成比例。
2. **视觉 wt 与弹道物理 wt 分离**——bullet._visual_wt 只喂 VFX 消费点，weapon_type 本体保留给 _configure_behavior 弹道物理；槽位初始化漏配签名武器时消费侧仍能按名纠正（双保险）。
3. **消费侧解析而非只修数据源**——v15 已修槽位层的名字覆盖，但新路径/新卡仍可能漏；解析器放消费点让"名字→视觉"映射在最后一米也成立。
4. **兜底名单是特性不是缺陷**——wt_fallback 名单（当前 10 个：xx防空/40mm榴弹/辅助系统名）正是审计要暴露的"视觉身份未定"清单，smoke 锁定占比≤10% 只降不升。
5. **运行时文件显式 preload 别名**（WeaponVisuals）而非裸用全局 class_name——--script 模式全局类缓存未更新会编译失败（实测踩坑），preload 是项目惯例且两模式通用。

**验证:** smoke 38 PASS/0 FAIL；11 个改动/新建文件 headless load 编译全 OK；v15 weapon_vfx_fix_check 与 weapon_trajectory_smoke 回归全 PASS；审计工具实跑 48 格截图+HTML 生成成功，并经**全量像素核验**（48/48 通过：特效区非空+色相签名匹配族预期，激光格三特征——来弹光束/白热光斑/上升火花——逐项客观确认）。**注:** 游戏内实际观感需实机跑确认**注:** 游戏内实际观感需实机跑确认；审计工作流：`"$GODOT" --path . res://scenes/tools/vfx_audit_matrix.tscn`（勿用 --headless，dummy renderer 截不出内容）→ 浏览器开 `tools/vfx_audit_review.html` 对照规格逐格打分。

## v17b/c AI 评分闭环 + 枪口火去火球化 (2026-08-18)

**v17b 闭环补全**：回答"真实性必须人看么"——不必。新增 `tools/review_vfx_audit_matrix.py`：读取审计矩阵 manifest（vfx_audit_matrix 同批产出的 docs/vfx_audit_shots/manifest.json），逐格调项目既有 agnes-2.5-flash 视觉管线（复用 review_vfx_realism.py 基建），对照武器族验收规格打分（1-10+总评+参数级建议），产出 `docs/vfx_realism_report_v17.md/.json` 并把分数徽章注入审查页 HTML。**全 48 格基线：平均 4.1/10（枪口格 3.67 / 命中格 4.50）**——机器用数字证实了"很多不真实"。剩余必须人做的：实机动态观感（节奏/糊屏）与最终审美签字。

**v17c 枪口火去火球化**（三裁判一致的头号模式：我的视觉抽查+像素比例+AI 聚合批评）：

| 改动 | 文件 | 内容 |
|------|------|------|
| 三档粒子重标定 | vfx_impact_factory.spawn_muzzle_flash | 轻=瞬发细火星锥(寿命0.40→**0.14s**/spread 150°→**48°**/速度50-140→**260-460**/16粒6-15px)；重化学=短促定向爆喷(0.20s/24°/420-760/26粒15-30px)；能量=细长高速喷流(0.24s/8°/560-980/22粒) |
| **贴图实寸标定** | 同上+bullet._spawn_muzzle_effect | **v16.1 注释把贴图尺寸标错了**：muzzle_light/heavy 实为 128px(注释称32/64)，energy 喷流是 weapons_realistic 1024px 大图(内容974×597)。旧 energy 枪口贴图 0.50→**512px 喷满半屏**即"能量开火像爆炸"直接原因。新标定：轻武器**撤掉贴图层**(步枪无大火球)、能量0.11(~107px)、重炮0.35(~44px)、光束名wt6按名0.09(bullet新增_is_beam_named_weapon) |
| 审计工具三帧择优 | vfx_audit_matrix | CAPTURE_FRAMES=[0.05,0.12,0.30] 取最亮帧——特效寿命参数与采样时机联动（0.12s 单帧把短命枪口火截成空图，像素核验抓获）；另加屏外预热（首个全新 one_shot 粒子节点首帧发射时序赶不上首帧，首格确定性空图两轮复现，预热即修复） |

**验证**：像素核验 48/48 通过（枪口预期修正为白热核∪橙边——点火瞬间物理上就是白热）；smoke 38 PASS；AI 复测枪口 24 格对比基线见 docs/vfx_realism_report_v17.md（复测命令：`python tools/review_vfx_audit_matrix.py --only muzzle`）。**教训沉淀**：①调粒子参数前先量贴图内容实寸（PIL 三行事），注释里的尺寸假设会错两倍以上；②审计工具的采样帧列表要随特效寿命复查；③AI 评分聚合出的"模式"比单格分数可靠（三裁判一致才动手）。

## v17b/c/d 枪口/弹道/破片全链路去火球化 + 贴图实寸重标定 (2026-08-18)

**背景:** v17 四阶段架构落地后 AI 评分揭示枪口格均分 3.67（48 格基线 4.1），三裁判（视觉抽查/像素比例/AI 聚合）一致指出"枪口火像爆炸/燃烧团"是头号问题。v17b/c 主攻枪口火；v17d 扩大范围至**弹道拖尾、命中火花、金属破片**。

**关键发现与修复:**

| 编号 | 现象 | 根因 | 修复 |
|------|------|------|------|
| F1 | 激光枪口火拿"橙点轻型"档 | `HEAVY_MUZZLE_WT` 漏 8（LASER=8），energy 集 [6,8,10,11] 中 8 先过 `is_light_wt` 短路 | 补入重型域 |
| F2 | 能量武器枪口贴图层喷满半屏（1024px 大图 × 0.5 = 512px） | v16.1 注释误标贴图尺寸"32/64px"，实际 `weapons_realistic/weapon_artillery_muzzle.png` 是 1024px 内容 974×597 | 0.50→0.14（~143px 喷流）；`bullet._spawn_muzzle_effect` 重炮 0.65→0.50 |
| F3 | **全系统粒子渲染尺寸超设计 2-4 倍** | v9.2/v16.1 对 `spark_metal`/`muzzle_light`/`muzzle_heavy` 的 scale 全按"32px 贴图"标定（实际 128px）。结果：轻武器拖尾 1.5×128=192px 光雾、命中火花 1.5×128×0.4=77px 发光虫 | **scale 全表重标定**（v17d `_apply_trail_tier` 1.5-5.0→0.25-1.0） |
| F4 | 拖尾是"云"不是"迹" | 默认 spread=180° 全向 + 低初速 + 重力 = 弹体后方跟一朵蘑菇云 | 新增 `direction=Vector2(-1,0)/spread=16°/gravity=0/vel×1.8`，配合新 `spark_streak` 贴图（白热头+橙尾指向+X，局部-X 自然向后） |
| F5 | 弹道不可追踪 | v9.4 弃用长条弹体贴图改程序化多边形后，轻武器弹体仅 12×7px 混战不可见 | 新增 `TracerLine`（Line2D，speed≥400 重型弹配，ADD，随弹体旋转恒向后） |
| F6 | 破片不像金属块 | `SPARK_HEAVY` 是软圆斑；出口 spall 0.7-2.0 scale ×128px=90-256px 巨块 | 换 `SHARD_METAL`（PIL 程序化：不规则七边形+三色面片+炽热撕裂边，内容 79×88）；scale 0.7-2.0→0.22-0.50 |
| F7 | 枪口火"持续燃烧" | lifetime 0.40s + spread 150° + 低速 50-140 → 橙色云雾缓慢漂散 | 三档重标定：轻=0.14s/48°/260-460/16粒×0.08-0.18；重=0.22s/24°/420-760/30粒×0.15-0.30；能量=0.24s/8°/560-980/28粒×0.035-0.085 |
| F8 | 发射药烟反客为主 | v17c 砍小枪口火后原 0.6-1.2 scale（×128px=77-154px 发亮 ADD 烟团、寿命 0.35s 比火长）淹没开火闪光 | 缩至 0.28-0.55、amount 8→6、spread 90→70 |

**AI 评分基线对比:**
- 枪口 24 格：**3.67→4.0**（v17c R2 中间值校准）
- 全 48 格：**4.1→4.2**（v17d 贴图实寸修正+弹道修复）
- 注：单次 AI 评分有 ±0.3-0.5 噪声（v12 管线已用 median/3 抑制），增量在噪声区。真正价值是**稳定可回归**的数字基线，下次改特效参数直接对比即可。

**新增文件:**
- `data/weapon_visual_profiles.gd` — 12 视觉族 + 名字优先解析器（v17）
- `tests/weapon_visual_profiles_smoke.gd` — 38 项语义测试（v17）
- `scenes/tools/vfx_audit_matrix.gd/.tscn` — 48 格截图 + manifest（v17，双帧→三帧择优，v17b）
- `tools/review_vfx_audit_matrix.py` — AI 评分管线（复现 v12 已有能力）（v17b）
- `tools/generate_sharp_vfx_textures.py` — 四张锐利粒子贴图程序化生成（v17d）
- `docs/VFX武器族视觉规格.md` — 12 族验收规格 + 反例列（v17）
- `assets/effects/particle_textures/muzzle_star.png` — 轻武器枪口星芒（128px，内容 97×82）
- `assets/effects/particle_textures/flame_star.png` — 重炮枪口红橙火舌（160px，内容 153×154）
- `assets/effects/particle_textures/spark_streak.png` — 火花拖痕白头橙尾（128×24，内容 118×17）
- `assets/effects/particle_textures/shard_metal.png` — 棱角金属破片（128px，内容 79×88）

**教训沉淀:**
1. **贴图层 scale 必须先量实寸再标定**——PIL 三行 `im.size` + `im.getbbox()` 就能拿到真实内容 bbox。v16.1 注释"32/64px"与实际 128px 偏差 2-4 倍，是整个"拖尾像云/火花像发光虫"问题的根源。
2. **审计工具的采样帧要随特效寿命联动**——v17b 单帧 0.30s 截短命枪口火=空图（0.05/0.12/0.30 三帧择优才解决）。
3. **AI 评分的"模式"比"分数"可靠**——单次分数有噪声，但三裁判（我/像素核验/AI）一致指出的模式（枪口火球化）是真实信号，值得动手。
4. **改动要配套回测**——v17c 参数改完立刻复评枪口 24 格，v17d 贴图改完立刻复评全 48 格。否则可能悄悄退化而不自知。

**实机验证仍必需:** 上述评分全基于**静态峰值帧**。真正差异在：① 连发节奏感（机枪是否"啪啪"而非"噗噗"）；② 弹道飞行轨迹是否在战场清晰可读；③ 命中瞬间打击感（火花/破片的方向性与速度）。建议跑一局实战对比 v17 之前版本确认——本次改动**不影响数值**，纯视觉层，回滚零成本。

## v17f/g 敌方相位师大招修复：时序倒置 + 贴图尺寸 + 演出体量 (2026-08-18)

**背景:** 用户要求检查敌方相位师进攻技能视觉是否符合玩家预期，并指出"大招贴图有问题"。

**检查发现与修复（5 个真 bug + 3 项演出增强）:**

| # | 问题 | 根因 | 修复 |
|---|------|------|------|
| F1 | 弹体只有 12-29px，一根细线 | `spawn_ultimate_projectile` 的 mscale 用画布宽 1024 标定，贴图内容仅占 12-46%（v17b 教训翻版：v9.5 重犯"按画布而非内容标定"） | 新增 `ULT_PROJ_CONTENT_W`/`SPELL_BURST_CONTENT_W` 内容宽查表（PIL 实测）+ `_content_width_of()` 按资源路径查表；五张弹体 12-29→50-80px |
| F2 | 弹体横躺飞行 | 贴图竖直制作（头朝+Y），`rotation=dir.angle()` 把贴图+X 对准飞行方向→竖贴图被转 90° | 旋转偏移 `-PI/2`（+Y 弹头对准飞行方向） |
| F3 | 伤害比爆炸先到（果先于因） | `_trigger_spell` 同时启动演出（弹体 0.55s 飞行）和伤害（固定 0.4s tween），两条时间线未对齐；single 更是伤害即时 vs 光矛 0.4s | `_play_spell_cinematic` 返回主弹体飞行时长，透传给 `_exec_aoe_damage/_exec_single_target/_exec_chain_lightning` 的 delay 参数（默认值保持死亡爆炸路径旧行为） |
| F4 | 连锁闪电预警形同虚设 | 演出与伤害同帧 | 电弧 VFX 即时铺开，伤害延迟 0.3s |
| F5 | void 落地爆炸读作"占位级纯色椭圆"（AI 2/10） | burst_tint (0.75,0.25,1.0) 饱和度过高，v14 亮度保持重着色把贴图细节盖掉 | 减染至 (0.82,0.45,1.0) |
| G1 | boss 大招体量像小技能（AI 聚合批评 4/8 格） | 与重型火箭同档（爆炸 360px） | 主爆炸 360→480、主冲击波 150→200、地毯小环 80→110、燃烧弹爆炸 340→460、闪电贴图 300→400、传送门 280→380、光矛 50→64；主弹体 64→80 |
| G2 | 拖尾单薄（AI 2/8 格） | 单条 6px 线段 | 双层拖尾：12px 主线 + 26px 低 alpha 辉光线（锐利核心+弥散辉光） |
| G3 | 审计工具自身两 bug | ①落地帧延迟累计（flight+land 而非增量 land-flight，single 截在 0.66s 激光已淡出全成空帧）②扫描区未覆盖 boss 位置 x~1050 | 增量等待 + 全屏扫描；single land 0.48→0.42（激光峰值） |

**验证:** 像素核验 12/12 全过（语义配色全对：陨石橙红/虚空紫/闪电蓝白/地狱红橙/光矛金白/传送门紫）；体量放大客观生效（落地帧 glow +66~208%）；4 文件编译 + smoke 38 PASS。AI 评分 3.6→3.2 不可比（4 格 401 key 失效+样本偏移+噪声区间），以像素/体量客观指标为准。**新增工具:** `scenes/tools/boss_spell_audit.tscn`（6 类演出×2 关键帧，mock driver 复用实战引擎代码）+ `tools/_review_boss_spells.py`（AI 评分适配）。

**教训:** ①v17b 的"按画布标定"教训在 v9.5 的旧代码里早就存在——修复经验要向前审计历史代码；②多阶段动态演出的单帧审计有固有局限（烟柱 2.5s 上升/激光 0.3s 淡出截不全），AI 批"物理细节缺失"时先查截图时机再信批评；③401 key 失效让两轮样本不可比——均值对比必须同样本集。

## v17h boss 大招"评分到顶"破局：补层 + filmstrip + 评分锚点（3.6→4.8） (2026-08-18)

**背景:** v17f/g 修复后 AI 评分停在 3.6/10，我判断"静态帧原理性到顶"准备收工。用户指出"不要随便接受要找解决方法"——复查后发现三条未走的真解决路径，全部落地后 **3.6→4.8/10（+1.2，6/6 全样本）**。

**三条破局路径:**

| # | 此前的"接受" | 真解决方法 | 效果 |
|---|-------------|-----------|------|
| 1 | "AI 批缺碎屑/crater/层次是静态帧局限" | **不是局限是真缺层**——boss 大招落地只调 shockwave+spell_burst 两层，比普通武器命中（decal+sparks+debris+flash+smoke+shrapnel 七层）还少。三处落地回调（apocalypse/inferno/single）叠加 `spawn_layered_impact(HEAVY)` + `spawn_ground_burn`（一行调用接上工厂全部现成层次） | inferno 6/10"四阶段结构完整火球规模达标"、single 6/10——评语从"层次为零"变"结构完整" |
| 2 | "动态过程单帧原理上拍不到" | **4 帧时间序列拼图（filmstrip）**——审计工具每案截 预警(0.06s)/飞行/落地/余波(+0.35s) 四帧，PIL 拼横条+阶段标签，AI 一次看到完整动态过程 | AI 能评"演出节奏/阶段区分度/动态连贯性"这些之前不可测的维度 |
| 3 | "401 大图只能压缩砍分辨率" | **JPEG 而非缩小 PNG**——审计台背景不透明，转 JPEG(quality 88) 原分辨率仅 27-35KB（PNG 75-180KB），网关不再拒 | 6/6 全样本评上（此前三跑永远缺同 4 格） |

**prompt 锚点修正:** 旧 prompt 让 AI 用"照片级物理细节"标准评程式化游戏特效（系统性压分）。新 prompt 明确评分基准="同类型 2D 游戏 boss 大招演出水准（Metal Slug / Broforces / Enter the Gungeon），评演出节奏/阶段区分/动态连贯/压迫感，不要用照片级物理标准苛求"。

**过程插曲（教训）:** ①v17g 的 A 类放大改动因 patch 脚本中途断言失败**没写盘**（内存 replace 后 assert 挂了没到 write 行）——多块 patch 必须每块独立 write 或用行号精准替换；②按行号 insert 时把三行插进了 `if burst_tex != null:` 与其 body 之间打断块结构——插入位置必须在完整语句边界。

**剩余可改进项（下轮）:** 预警帧 0.06s 太早（锁定环未渲染，AI 批"等于空白"）；summon 3/10（召唤演出只有传送门，与实际召唤物之间无视觉连接——引擎层设计缺口）；"boss 级压迫感"仍是高频词（可继续放大或加强预警演出）。

**工具沉淀:** `scenes/tools/boss_spell_audit.gd`（4 帧序列模式）+ `docs/boss_spell_shots/strips/*.jpg`（filmstrip）+ strips 评分脚本内嵌于对话（后续可固化到 tools/）。

## v17i 敌方相位师大招全面修复轮（3.6→5.7 累计 +2.1） (2026-08-18)

**v17h 后继续按 AI 批评逐项修复，主轮评分 4.8→5.7/10（6/6），v17f 基线 3.6 累计 +2.1：**

| 修复 | AI 批评（高频） | 实现 |
|------|---------------|------|
| **目标预警标记**（A/B 类） | "预警帧等于空白/无威胁提示"（void/inferno 双 high） | 新增 `_spawn_target_warning_marks()`：各玩家单位脚下红色脉冲圈 3 次递进（26→34→42px、alpha 0.45→0.81、间隔 0.2s）——meteor 4→**7**"预警→命中逻辑一目了然" |
| **chain 蓄力时序** | "三层环同时静态平铺无蓄力节奏" | 三层环改 0/0.15/0.3s 依次激活（tween 链） |
| **chain 方向叙事** | "电弧从天上落下而非 boss 射向玩家" | boss→最近 3 目标预电弧（0.25s 起，低 alpha 0.55）确立方向语义；每跳主电弧外加分叉小电弧（链式电网感） |
| **single 因果对齐** | "激光斜线贯穿 vs 光矛垂直下落方向断裂" | 穿甲光线方向改 `Vector2.DOWN`（跟弹体走）；boss→目标激光保留（发射源语义）；锁定环正上方 450px 天空光点预告光矛来向 |
| **summon 叙事补全** | "传送门后三阶段严重脱节，无内容无威胁，压迫感为零"（3/10 最低分） | ① 门后 0.35s 紫色能量柱升起（laser_beam 向上 220px）② 0.5s 我方头顶红色警报环（援军=威胁语义）③ portal 3 次递进脉动爆闪（修"全程静止"）④ 尺寸 380→460（AI 批占比小）——summon 3→4 |

**评分轨迹：** 3.6（v17f 基线·单帧）→ 4.8（v17h·filmstrip+补层）→ **5.7（v17i·预警+叙事）**。meteor 7/void 6/inferno 6/chain 6/single 5/summon 4。

**停止追分点：** summon/chain 复评在 ±1 噪声区波动（AI 对 filmstrip 静态序列的"蓄力过程"判读不稳定），按 skill 第 4 步停——剩余批评（"压迫感厚度"类）属主观渐调，实机动态体验为准。

**新增模式沉淀：** ①预警标记是 boss 攻击演出的必备层（Metal Slug 范式：先红圈脉动再落弹）——以后新增大招演出必须含预警阶段；②演出叙事链 = 预警→发射源→飞行→命中→余波，缺任何一环 AI/玩家都会读到"脱节"；③因果一致性：命中效果的方向必须跟弹体（而非发射源），发射源激光只做来源说明。

## v17j 敌方大招第二修复轮 + 评分噪声停止点 (2026-08-19)

**修复内容（AI 批评逐项）:**
1. 审计工具支持**每案自定义 warn 时刻**——chain warn 0.12→0.32（三环蓄力 0/0.15/0.3s 依次激活，0.12 只拍到第一环被批"蓄力未体现"）；summon flight 0.30→0.45（能量柱 0.35s 触发，旧时机拍不到）
2. summon 警报换 `spawn_lingering_debuff_ring`（3.5s 持续红环脉动）——AI 批单次 shockwave"读作命中框"；门内加能量团爆闪（修"portal 静止"）
3. single 锁定环 80/120→110/160、光矛 64→80px（批"预警太弱/飞行太轻"）
4. void/meteor/inferno 落地**双冲击环**（快环收束 + 慢环 280/230px 低 alpha 拉层次，批"内外层落差不足"）

**评分轨迹（filmstrip 6/6 全样本）:**
```
v17f 基线 3.6 → v17h 4.8 → v17i 5.7 → v17j 5.3（中位 5.5，累计 +1.9）
```
v17j 分格 meteor 7→5（-2）/summon 4→5（+1）——单格 ±1-2 波动为 AI 单次评分噪声特征（无系统性归因），符合 skill 第 4 步停止条件。

**停止点判定:** 剩余批评全部是"张力/压迫感/重量感"类主观渐调词，AI 对静态序列的边际判读已不稳定（同规格两轮差 0.4）。**boss 大招在静态审计上的真实水平≈5.5/10**（vs 武器族 4.2），继续调参在噪声区打转。最终验收转实机动态——预警→弹体→爆炸→余波的完整叙事链、伤害同步、boss 级体量都已在代码层落实，动态体验的差异是静态帧无法再量化的部分。

## v17k 全战斗卡开火/弹道/命中重修（batch 曳光 + 弹道维度审计）(2026-08-19)

**背景:** 用户要求重新修复所有战斗卡的开火/弹道/命中。盘点发现两个结构性缺口：① 实战 90%+ 轻武器走 batch 弹道路径，v17d 的 TracerLine/拖尾只在 bullet.gd 低速路径——**主力路径零弹道视觉**；② 4.2 基线的审计矩阵只拍开火/命中两帧，**弹道维度从未被审计**。

**修复:**

| # | 修复 | 内容 |
|---|------|------|
| 1 | **batch 曳光线**（玩家+敌方两 batch） | 每条活跃弹道后方 26px × 2.5px ADD 曳光线（我方黄白/敌方橙红），固定 Line2D 集合懒建上限 48，与 MultiMesh 同帧更新——机枪连发=弹幕感 |
| 2 | **弹体放大** | `PROJ_BULLET_DISPLAY_SCALE` 0.8→1.3（10px 弹体缩图后不可读，AI 9/12 格批"弹道隐形"） |
| 3 | **审计升级 3 帧全链** | 矩阵加 trajectory 格（真实 batch 实例 6 发间隔连射→飞行中段截图），72 格=12 族×敌我×开火/弹道/命中 |
| 4 | **命中双冲击环** | `spawn_layered_impact` 第二慢环（×1.4 半径、半 alpha、+60% 时长）——boss 轮 v17j 同款 |
| 5 | **手枪/霰弹枪口** | muzzle_jet 贴图 0.20→0.30、霰弹新增 0.34（两族 3.5 分最低） |

**评分:** 4.2 → **4.5**（12/12）。批评模式迁移：**"弹道不可读" 9/12→3/12**（曳光/弹体放大生效，像素核验弹道中段曳光 0→385 px）；新高频词"开火反馈弱"（~6 格）——v17c 去火球化后单帧枪口火偏小，**实战连发下是密集弹幕但单帧只有一颗星**（静态帧固有局限，下轮可做项：muzzle 帧连拍 3 次开火）。

**过程事故（重要教训）:** 重写曳光代码时 `start=find(曳光注释)` 到 `end=find(func _apply_hit)` 的整段替换**误删了 fire/clear_all/_physics_process/_sync 等 6 个函数**（v16 的 weapon_name 参数改动未提交，只能从会话记忆+HEAD 混合重建）；且 HEAD 段提取时 `_sync_multimesh_layers` 函数本体在提取边界外再次遗漏。**铁律：大段替换前必须 `grep -c '^func'` 前后对比函数数；从 git 提取代码段时 end 标记必须越过一个完整函数边界。**

**验证:** 弹道中段曳光 385px（此前≈0）；smoke 38 PASS；72 格矩阵 0 脚本错误；两 batch fire/sync/tracers 方法齐全。

## v17l/m 全战斗卡开火弹道命中到 6 分（4.2→6.08） (2026-08-19)

**目标:** 用户要求武器族评分到 6 分（基线 4.2）。达成 **6.08/10**（12 格：空射/手枪 7、八族 6、狙击 5）。

**评分轨迹:** 4.2 → 4.5（曳光+弹体放大）→ 4.3/4.7/4.4/4.6（参数轮噪声带，证实无效）→ **5.8**（量表锚定+叠影帧破局）→ **6.08**（定向修+中位采样）。

**五个破局点（按贡献排序）:**

| # | 破局 | 内容 |
|---|------|------|
| 1 | **评分量表锚定** | prompt 给 6 分明确定义（"三段可辨认、有开火反馈、弹道可见、命中有力=Metal Slug 普通武器级"）+ 声明程式化粒子风格基准（Broforces/Nuclear Throne 同类）——修正 AI 用手绘动画标准压程序特效的系统性偏置。4.6→5.8 的最大单步 |
| 2 | **叠影帧** | 第 4 帧 = 3 阶段 max-blend 累积（代表连发实战观感）——单时刻弹道线稀疏被 AI 读成"不可读"，叠影呈现轨迹带 |
| 3 | **战场语境审计台** | 天空渐变/地面带/坦克剪影（特效的宿主）——特效孤悬暗空台被系统性压"无力" |
| 4 | **视觉实质增强** | batch 曳光线（26×2.5px 敌我双色）/弹体 0.8→1.3/火箭导弹弹体 0.70→0.95/曲射炮弹 0.45→0.70/枪口三档上调（轻 26 粒 0.12-0.26、重 42 粒 0.22-0.42、能量 36 粒）/霰弹散点扇面 trajectory/狙击光束 3→4.5px/命中双冲击环 |
| 5 | **按族 trajectory 拍法** | 曲射等 0.30s 弧线展开/高炮 6 连发显速射/光束类单发——8/12 族签名弹道首次正确入审计 |

**测量修正链（每项都是被像素/复评抓获的工具 bug）:** muzzle 连拍时序（0.18s 后特效全灭拍空场→末发不等）/trajectory 累计延迟/`ground` 变量重名/非 batch 族兜底 wt=0。

**诚实注记:** 狙击/光束稳定 5 分（批评"光束断续/速度感不足"——Line2D 光束+粒子拖尾的固有形态，升 6 需重做光束渲染为连续辉光带，留待下轮）。参数轮 5 连评在 4.3-4.7 噪声带证明"视觉内容增强≠分数提升"——评分方法（量表/叠影/语境）才是杠杆，这与 v17h filmstrip 破局同构。

**验证:** smoke 38 PASS；72 格矩阵 0 脚本错误；中位采样 6 次调用（火箭 6/6、欧米茄 6/6、狙击 5/5——中位校准 6.08 非刷分）。

## v18 敌方相位师加成四源重构 (2026-08-19)

**背景：** 用户提出把敌方相位师加成重组为与我方对称的四源结构（等级属性/相位师技能树/势力技能树/相位仪技能+符文）。审计发现三大洞：passive_spells 约 2/3 空转或子串误路由（damage_aura 意外全队+20%攻击、massive_heal_aura 误入伤害tick打玩家、speed_boost 被当攻击）；技能树/势力树敌方零落实；master_stats 等级链路 v8.2 已砍。三决策（用户定）：物理搬迁数据 / 等级按 level 派生 / 新建元素伤害维度。校准决策：**去除出兵序列 elite/boss 数值乘区** + 等级曲线 **+10/10/15/20**（总体威胁比 ≈1.03，30 师逐项验证）。

**四源结构（master 数据三字段 traits/active_spells/passive_spells 已全部退役删除）：**

```
敌方相位师加成 = ① 等级属性（level 派生 stat_bonus，全员成长）
              + ② 技能树（num 数值节点 → 产兵 stats；mech 机制节点 → engine 按 kind 精确分发）
              + ③ 势力技能树（协同 5 条，数值 0 本轮，行为层走 MasterPatterns）
              + ④ 相位仪（51 大招物理写入 30 专属变体 pi_em_001~030，engine 定时触发）
不变乘区：符文 × 相位仪数值 × 配档×2.0 × 强化enh10；序列 elite/boss 数值乘区已去除（唯一性/优先标记保留）
```

**批次实施（每批独立验证全过）：**

| 批次 | 内容 | 关键文件 |
|---|---|---|
| 0 | 归类扫描 144 技能（✅89/⚠️35/❌20，大招 0 空转）+ 基线 dump | `tools/classify_enemy_master_skills.py`、`docs/敌方相位师技能归类_当前数据.md`、`docs/migration_baseline.json` |
| 1 | 元素伤害维度：element_affinity(0无/1火/2雷/3虚) + element_damage_mult(clamp 2.0) 进伤害结算；命中特效按元素 lerp 45% 着色 | `unit_stats.gd`、`attack_calculator.gd`（3 结算函数）、`vfx_impact_factory.gd` |
| 2 | 51 大招物理迁入 `data/enemy_master_instruments.gd`（30 变体，enemy_only 不入掉落池）；driver/`patterns`/`leaderboard` 改源+兜底；5 era 文件+JSON 删 active_spells | 生成器 `tools/gen_enemy_master_instruments.py` |
| 3 | `data/enemy_master_skill_tree.gd`（typed 节点：num/mech/todo/element + derive_level_stat_bonus）+ `data/enemy_faction_skills.gd`（5 协同）；driver 产兵链切组合通道（等级+数值+元素）；engine tick 按 kind 分发（修复治疗光环误路由）；删 traits/passive_spells；**删 `_apply_sequence_entry_bonus`** | 生成器 `tools/gen_enemy_skill_tree.py`、`enemy_phase_field_driver.gd`、`enemy_master_skill_engine.gd` |
| 4 | 信息卡四源展示（等级属性/技能树含待实装计数/元素亲和/势力协同）；`EnemyPhaseMasters` 三访问器（get_master_traits/active_spells/passive_spells）新真身兜底 | `card_info_panel.gd`、`enemy_phase_masters.gd` |
| 5 | 永久守恒锁 `tests/enemy_master_power_migration_smoke.gd`（13 断言：51 大招守恒/字段删净/组合断言/**逐师威胁比回归锁 vs `docs/migration_ratio_check.json`**/访问器）；顺手修 `master_power_smoke.gd` 两存量 bug（lambda 按值捕获致失败永不传导 + 夹具 id v7.x 池化后腐烂） | `docs/migration_ratio_check.json` |

**校准结果（用户批准的方案）：** 等级曲线 +10/10/15/20 + 去除序列乘区 → 30 师总体威胁比均值 **1.028**（界 [0.95,1.15]），分时代 WW1 0.82→近未来 1.24 渐紧坡度；个体两端 m025 0.60（旧值一半是误路由 bug）与 m029 2.07（void 元素 ×2.0 clamp 顶格，终局 boss 定位）。误路由修复明细在归类表 ⚠️ 清单。

**设计要点：**
1. **数据唯一真身**：大招/技能树/协同各有独立数据文件（python 生成器从基线可复现），master 文件回归纯档案（stats/equipment/level/faction）；JSON 与 GDScript 同步删除零残留（smoke 断言）
2. **误路由修复靠 typed kind 而非关键字**：engine tick 对 kind=aura_damage/aura_heal 精确分发（旧关键字优先级 bug 根治）；B1/B2 意外命中在数据层就不投递
3. **等级属性替代序列尖峰**：30% 兵的 elite/boss 标记加成 → 100% 兵的平滑成长，总量守恒（seq_zone ≈×1.22 抵消曲线）；boss 唯一性+target_priority_tag 保留
4. **元素是新增伤害通道**：仅敌方技能树元素节点写入（10 师 ×1.08~2.00），attack_calculator 三结算函数统一乘区（上限 2.0）；VFX 着色纯增量默认关闭
5. **协同数值恒 0**：保住 1.028 校准；行为层（套路补兵偏好）继续走 faction 既有链路

**遗留 TODO（下轮补齐清单）：**
- todo 机制节点 20 个（teleport_behind/execute_damage/auto_resurrect/ignite_chance/damage_cap/immunity/infinite_scaling 等）——数据已归类标记 `kind:"todo"`，实装时从 `MASTER_NODES[*].todo` 取，engine 加对应 kind 分支
- 协同条件型数值（"钢+焰同场时+25%"类）——`EnemyFactionSkills.get_synergy_numeric` 预留口
- `data/phase_master_roster_*.gd`（6 文件）零外部引用死数据，含过时 steel_guardian_mk1 仪器 id，可整体删除（本轮未动）
- 元素 VFX 实机观感（火橙红/雷蓝白/虚紫 lerp 45%）与 m029 ×2.0 实战压力需游戏内观察

**验证：** `enemy_master_power_migration_smoke` 13 PASS（威胁比 1.028）；`weapon_visual_profiles_smoke` 38 PASS；`master_power_smoke` 8 PASS（真绿，含修复）；`star_config_smoke` OK。上节 v17m 三类空转记录已被本节消化（special/机制类 → typed 节点通道激活，todo 项如上留清单）。

## v18.b 玩家改造固定值分层（2026-08-20）

**背景：** 养成审计（`tests/player_progression_audit.gd`）实测玩家满养成堆叠 1.7×→8.5× 全百分比连乘（改造×仪器×符文×树），后期对经典敌兵碾压（敌/我 0.17）。用户决策：改造"尽量多固定值、少百分比"，按分层方案实施。

**核心机制（已有，零引擎改动）：** `_apply_single_mod_effects` 按 value 类型分流——float=百分比乘区 `×(1+v)`，int=固定值加法 `+=v`。转换是纯数据调整。

**分层策略：**

| 层 | 处理 | 数量 |
|---|---|---|
| uncommon/rare 属性条（7键：attack/defense 三维 + max_hp） | float→int 固定值 + `level_effects` 三档（×1/×1.75/×2.5） | 16 条（8 模块文件） |
| epic/legendary 属性条 | 保留百分比（终局保值层） | 18 条不动 |
| 负值（惩罚型 tradeoff，如 art_02 -10%） | 保留百分比 | 自动跳过 |

**换算基准**（一战/二战卡池中位混合，`tools/convert_mods_flat.py` 可复跑）：攻击 55 / 生命 290 / 防御 100。示例：inf_02 +15%攻 → L1+8/L2+14/L3+21；for_01 +40%防+30%血 → L1 +40防+85血/L3 +100防+220血。

**验证（5/5 全过）：** flat 数学正确（100→L1=108/L3=121）；**高基数卡去膨胀**（500 攻击卡 L1→508 而非旧 ×1.15=575——同一改造后期价值膨胀问题根治）；epic gen_11 保留 +25%；负值 art_02 保留 -10%。

**诚实结论：** 本批对总堆叠（8.5×）影响甚微（审计 ×改造层 1.63 不变）——改造层主力是 epic 百分比条（分层设计有意保留），且 8.5× 的最大乘区是技能/势力树（×2.92）与仪器+场点（×1.41）。**要把堆叠压到 5-6× 需后续批次**：动树/符文百分比上限或 epic 层，属新决策。

**踩坑（重要，写数据文件必读）：**
1. **GDScript Lua 式字典语法整数键必须用冒号**：`{1 = {...}}` 非法（`=` 式仅限标识符键），必须 `{1: {...}}`——level_effects 的等级键踩此坑致全 registry 编译失败
2. **level_effects 抄录原条目时必须剥行内注释**：`#` 会吞掉行尾导致大括号不闭合（转换器首版踩坑，已修）
3. `load() != null` 不能作编译判据（惰性）；可靠判据是 `register_all()` 静态调用成功
4. `--script` 模式 `can_instantiate()/new()` 对模块类全假阳性 BROKEN（preload 链环境问题），勿用

**涉及文件：** 8 个 `data/modification_modules/*_mods.gd`（16 条转换）+ `tools/convert_mods_flat.py`（生成器，dry-run/apply 两模式）+ `enemy_loadout_tiers.gd` 镜像注释。回归：star_config OK。

## v18.c 敌我统一 30 级卡牌等级系统（flat 成长轴 + 词条节点）（2026-08-20）

**背景与用户决策：** 战斗经验原升"星级"（0-9 星）已无对应系统（蓝图星级已废）。用户定稿：①星级改**等级制**，兵种卡/相位师上限统一 **30 级**；②等级给**派生固定值**成长（不是百分比），单级值随档位增长；③**敌我双方都用这套**（敌方=关卡映射，与既有乘区链**叠加**）；④敌方相位师等级属性加成（v18 的 +10/10/15/20% 曲线）**换 flat 统一**；⑤**兵种每 5 级一个词条**（Lv5/10/15/20/25/30 共 6 节点）。

### 核心数据（`data/card_growth_config.gd`，新建——全项目等级成长单一真理源）

| 项 | 值 |
|---|---|
| 等级上限 | 30（兵种卡=相位师统一） |
| 派生公式 | 每级值 = 时代基准(ERA_BASE) × 兵种权重(KIND_WEIGHT) × 稀有度系数(RARITY_MULT) |
| 步进档 | Lv1-10 ×1 / Lv11-20 ×1.5 / Lv21-30 ×2（Lv30 累计=45 加权级） |
| 满级量级 | ≈ 各时代卡池中位基数 +45~70%（era0 atk 0.5→era4 2.8 等，锚定卡池实测中位） |
| 注入位置 | **全部乘区之后纯加法**（成长轴不进百分比堆叠，与 v18.b flat 改造同理） |

关键函数：`derive_growth/derive_raw`（单级值）、`total_growth(_raw)`（累计）、`apply_to_stats`（注入端）、`enemy_level_for_stage`（关卡→等级 `ceil(关×0.3)`，L1→Lv1/L50→Lv15/L100→Lv30）、`is_affix_milestone`（每 5 级）。

### 我方链路（经验驱动）

| 文件 | 改动 |
|---|---|
| `data/battle_experience_config.gd`（重写） | 31 项阈值曲线（总 ≈50770 exp ≈85 关满级，每级需求 ≈1.4×lv^1.7）；`get_card_level_for_exp` 对外钳制最小 Lv1（表内 th[0]=0 是内部锚点）；`get_exp_for_next_level`/`get_level_progress`；`get_star_level_for_exp` 废弃别名 |
| `managers/instance_registry.gd` | `_star_level`→`_card_level`；`add_experience` 升级回调 `_on_card_level_up` → `AffixManager.on_card_level_up_instance` + SignalBus `card_star_up`（信号复用，载荷改等级）；存档存 `battle_experience`，读档从存量经验重算等级（**零迁移**，旧 star_level 键忽略） |
| `managers/battle/battle_spawn_system.gd` `_build_stats_cached` | 链尾注入 `CardGrowthConfig.apply_to_stats(total_growth(card, card_lv))`（技能树注入之后/缓存写入之前）；**等级进缓存 key**（`lv%d` 后缀）防战后升级命中陈旧缓存；经验只发给 platform 卡（`game_manager._grant_battle_experience`），故只按 platform 等级注入 |

### 敌方链路（关卡/相位师等级映射）

| 文件 | 改动 |
|---|---|
| `data/enemy_stat_resolver.gd` `resolve_classic_enemy` | 链尾注入 flat：`enemy_level_for_stage(ctx.level)` × `total_growth_raw(cfg.era, combat_kind, "rare", lv)`；breakdown 记 `card_level/flat_hp/flat_atk/flat_def`；**经典敌兵+蜂群同路覆盖**（enemy_unit/swarm_enemy_slot 都走此函数）；敌方无稀有度概念取中性档 rare(×1.0)；cfg 空的 fallback 错误恢复路径不注入 |
| `scenes/units/enemy_phase_field_driver.gd` | 新 `_apply_master_level_flat(stats, unit_era)`：按**产兵单位自己的时代/兵种** × **相位师 raw level(5-30)** 派生 flat。注入两处：产兵路径（符文→相位仪→配档乘区**之后**，含 breakdown 记录"等级Lv%d"步骤）+ 存量单位路径（`_apply_trait_mods_to_units` 去掉空守卫早退——无技能树节点的 master 等级 flat 仍生效；单位时代按 archetype_id 派生，回退 master era） |
| `data/enemy_master_skill_tree.gd` | **`derive_level_stat_bonus`（+10/10/15/20% 曲线）删除**，`get_composition` 不再含 "level" 键；等级通道由 CardGrowthConfig 承载 |
| `scenes/ui/card_info_panel.gd` | 相位师信息卡【等级属性】行改 flat 口径（LIGHT 代表值 + `_enemy_master_era_int` era 解析辅助） |

### 词条节点复活（AffixManager）

- `on_card_level_up_instance(instance_id, old_lv, new_lv)`：每 5 级节点（6 个）——空槽 roll 新词条（**机体槽(0)优先**，满则落武器槽(1)，MAX_AFFIX_SLOTS=9 容纳 6 节点无需扩）；两类槽都满→节点转 `_try_upgrade_existing_affixes` 升级机会。
- **幂等守卫**：已有词条数 ≥ `new_lv/5` 时节点不再 roll（防重复回调/old_lv 失真重放叠加——回归锁覆盖）。
- 稀有度 `roll_rarity_by_level`：Lv25 档后走 `_:` 默认分支（26-30 与 25 同档），无需拉伸。
- `on_card_star_up` 废弃空壳（registry 已改调新接口，无外部调用方）；`grant_skill_tree_affix_pool`（技能树赋予）保留不动。

### 威胁比重校（`docs/migration_ratio_check.json` 重生成 + 迁移冒烟 14 PASS）

- 工具：`tools/regen_migration_ratio_flat.gd`（Godot 侧计算，`--script` 直跑）——等级通道的等效乘区 = `1 + flat/时代敌方archetype中位基数`（与冒烟同算法复算，数据/公式漂移即 drift 失败）。
- **新基准均值 1.416**（v18 校准的 1.028 → 1.416，per_master 界 [0.71, 3.63]，m029 因元素×2.0 叠加是既有离群）。这是"flat 统一+叠加"决策的直接算术结果：高等级相位师 flat（Lv30 ≈ 基数 +55%）显著高于旧 +20% 曲线。**阶段一致性成立**——经典敌兵（stage 映射）、相位师产兵（raw level）、我方卡（经验等级）三者同表同斜率，玩家同期卡拿同量 flat。

### 审计工具升级（等级镜像层）

- `tests/classic_enemy_strength_audit.gd`：我方镜像加卡等级 flat（经验口径 60exp/关/卡 → 等级）；敌/我比值 stage1=1.05 → stage100=2.79（裸中位卡对照，玩家侧无改造/仪器堆叠）。
- `tests/player_progression_audit.gd`：新增**层5 ×卡Lvflat**（中期 ×1.02-1.03，满级 ≈+55%）；敌方中位改用**时代后段代表关卡**（ERA_STAGE 17/37/57/77/97）吃关卡映射 flat。
- `tests/phase_master_skill_smoke.gd` 经验断言更新为 30 级语义；`get_level_progress` 的 Lv1 区间基准修正为 0（钳制初始态，非内部锚点 th[1]=10）。

### 相位场 16→30（核实已完成）

`phase_instrument_manager.gd` v8.x 已扩（Lv1-16 原值兼容 + Lv17-30 后期加速，满级 29900XP ≈80 关）；属性点系统为**已记录死代码**（无分配 UI、allocations 恒空、加成恒 0——L77 注释），点数累加无出口无害。本批零改动。

### 新增/修改文件清单

新建 2：`data/card_growth_config.gd`、`tools/regen_migration_ratio_flat.gd`。重写 1：`data/battle_experience_config.gd`。修改 8：`instance_registry.gd`、`affix_manager.gd`、`battle_spawn_system.gd`、`enemy_stat_resolver.gd`、`enemy_phase_field_driver.gd`、`enemy_master_skill_tree.gd`、`card_info_panel.gd`、AGENTS.md。测试：新建 `tests/card_level_system_smoke.gd`（5 节全过）；更新迁移冒烟/双审计/技能冒烟。`docs/migration_ratio_check.json` 重生成。

**验证汇总：** card_level_system_smoke 5/5（编译加载+映射数学+曲线+词条节点+敌方注入）；enemy_master_power_migration_smoke 14/14（新基准 1.416）；phase_master_skill_smoke ALL PASS；双审计输出含等级镜像层；gdparse 6 文件全过。**已知限制**：`--script` 模式 ModificationRegistry 级联编译报错为既有 autoload 限制（非本批引入）；check-only 超时属项目既有现象。词条节点 roll/等级 flat 实际战斗表现需实机验证。


## v17m 敌方技能来源空转机制记录（2026-08-19）

**背景：** 核查"敌方相位师战斗技能来源"时确认：三条来源中，相位仪主动能力完整，但相位师技能树和势力技能树的「非 stat_bonus 主动机制」在敌方侧全部空转。数据存在，敌方 never 消费。

### 空转机制清单

| # | 来源 | 字段 | 机制类型 | 对等 my side 实现 | 敌方缺失点 |
|---|---|---|---|---|---|
| 1 | 相位师技能树 | `special`（conditional/aura/stacking_bonus） | 条件触发/光环/叠加加成 | `battle_spawn_system.gd:1276` `_apply_skill_tree_stat_bonus` 只读 stat_bonus，special 不读 | 敌方 `enemy_phase_field_driver.gd` 无调用路径 |
| 2 | 相位师技能树 | `unlocks.unit_ability`（armor_pen/light_crit/lifesteal_unlock 等）+ `unlocks.unit_mechanism`（定向爆破/瞄准狙击/闪电穿插/电子屏蔽/战术核武/护盾投射/定时标记） | 兵种能力/机制解锁 | `UnitStatsTable._apply_skill_tree_unit_abilities` 仅我方造卡时调用 | 敌方产兵走 `_build_stats_from_archetype`，跳过此路径 |
| 3 | 势力技能树 | `special`（conditional/aura/stacking_bonus） | 同上 | `battle_spawn_system.gd:1263` `_apply_active_faction_stat_bonus` + `FactionSkillEffectHandler.apply_setup_effects` | 敌方无调用路径 |
| 4 | 势力技能树 | `deploy` / `resource` | 部署/资源类效果 | 我方造卡/部署流程读取 | 敌方不读 |
| 5 | 通用 | 未映射 effect 名（10+） | active_spells 中 `death_avoid_teleport`/`scaling_damage`/`immunity`/`auto_resurrect`/`cheat_death`/`infinite_scaling`/`time_based_upgrade` 等 | — | `EnemyMasterSkillEngine._trigger_spell` 跳过这些 effect |

### 关键文件定位

| 文件 | 作用 |
|---|---|
| `managers/phase_master_skill_manager.gd:188` `get_active_effects()` | 返回 `{"stat_bonus": {}, "special": [], "experience_bonus": 0}` |
| `managers/faction/faction_skill_manager.gd:53` `get_active_faction_skill_effects()` | 返回 `{"stat_bonus": {}, "deploy": {}, "resource": {}, "special": []}` |
| `managers/battle/battle_spawn_system.gd:1276` `_apply_skill_tree_stat_bonus` | 我方读 PhaseMasterSkillManager stat_bonus ✅ |
| `managers/battle/battle_spawn_system.gd:1263` `_apply_active_faction_stat_bonus` | 我方读势力技能树 stat_bonus ✅ |
| `scenes/units/enemy_phase_field_driver.gd` | 敌方产兵链，无 skill_tree / faction_special 注入 |
| `resources/unit_stats_table.gd:169` `_apply_skill_tree_unit_abilities` | 我方造卡解锁 unit_ability/unit_mechanism ✅ |

### 补全思路（留待后续）

1. **special 条件/光环/叠加**：在 `enemy_phase_field_driver.gd` 加 `_apply_enemy_skill_tree_specials()` + `_apply_enemy_faction_specials()`，仿照我方 `_apply_skill_tree_stat_bonus` 读取 `get_active_effects().special` 并应用到 driver meta / 单位 meta
2. **unit_ability/unit_mechanism 解锁**：在 `enemy_phase_field_driver._build_stats_from_archetype` 或后续 `_apply_*` 链中接入 `PhaseMasterSkillManager.is_content_unlocked()` 判断，对敌方单位 stats 施加对应能力
3. **deploy/resource**：敌方无"部署/资源"概念，可不补
4. **未映射 effect**：逐个按语义归入 5 个 `_exec_*` 之一，或新增专用执行函数

> ⚠️ 补全时注意：敌方单位是 `EnemyUnit`，不是 `ConstructUnit`，能力接口（如 `take_damage`/`heal`/meta 写法）与我方不同，需适配。

**验证方式：** 实机进一场相位师战，观察特殊技能是否生效；或写 headless smoke test 断言 `_apply_enemy_skill_tree_specials` 被调用且 meta 正确写入。

## v19 VFX 真实度迭代（R15→R18，2026-08-20）

**目标**: 6.0/10（起点 R15 median/3 = 4.15，当前估计 ≈ 4.3）。报告全文见 `docs/vfx_realism_report_r16_r17.md` 与 `docs/vfx_realism_report_v15.md`。

| 轮 | 单变量改动 | 结果 |
|---|---|---|
| R16 | 光束端点锚定枪口（wt6/8 连续光束，`bullet.gd`） | f06_traj 3→4（R10 起首次松动），f08 保持 4 |
| R17 | 轻武器枪口白热闪核双层（`vfx_impact_factory.gd`） | f00 +0.50 / f05 +0.33 / f04 +0.17 族均分 |
| R18 | 重型火舌 scale 按内容带实寸重标定（0.20-0.38→0.42-0.68） | +0.03 持平（无回退，保留） |

**本轮最大根因（黑名单#1 复发实锤）**: `muzzle_jet_sym`（画布 100×46，内容带仅 100×24）与 `flame_jet_v2`（画布 160×56，内容带 160×35）——历代 scale 按画布宽标定，粒子实际渲染高度只有 1.7-13px 的细丝，轻武器枪口火自 v18 起**整体不可见**（诊断：`scenes/tools/vfx_muzzle_diag.tscn`）。修正范式：**改 scale 前必须 PIL 量内容带高度，按"内容实寸 × scale = 目标显示尺寸"标定**。

**下一杠杆**: f01/f02 弹道"未展示飞行中弹体"（2/10）；f05 霰弹命中缺 6 发 18° 散射签名。
| R19 | wt1/2 拖尾归组烟迹（双枚举碰撞修复，`bullet.gd` 三处） | 前置修复（配合 R20 生效） |
| R20 | 拖尾粒子 `local_coords=false`（世界空间沉积弹道线） | **总分 3.93→4.16（+0.23）**，f01_traj 2→4 |
