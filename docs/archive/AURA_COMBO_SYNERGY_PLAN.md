# 光环范围化 × 改造/兵种配合强化 — 修订与提升计划

> 状态：待批准执行 | 起草：2026-08-30 | 来源：《龙崖》(Dragon Cliff) 资料搜集 + 全码摸底
> 决策记录（用户拍板）：
> 1. 龙崖借鉴清单**除"自动/手动双轨收益（怒气不放→全队 buff）"明确否决外全部采纳**；
> 2. 三个重点方向：**光环影响范围**（混合方案：战术范围化、战略全场）、**多改造配合**、**多兵种配合**（双轨并行）；
> 3. 本计划写入 docs 分阶段执行（P0→P3），每批独立验收。

---

## 0. 设计北极星

用**站位决策 + 编成决策**替代纯数值堆叠：光环范围化让"部署谁、先部署谁、部署在哪"重新成为决策点；
改造套装档位和兵种搭档让"装什么、带谁上场"产生 1+1>2 的组合收益。所有新增强度走"机制解锁"而非"数值翻倍"。

## 1. 架构现状（摸底事实，改动前必读）

### 1.1 光环有两条独立链，全部全场化

| 链 | 数据 | 执行 | 现状 |
|----|------|------|------|
| 平台光环链 | `data/aura_data.gd`（6 类：MEDIC_HEAL / CARRIER_REPAIR / SCOUT_CRIT / RADAR_RANGE / FORTRESS_DEF / COMMAND_GLOBAL） | `managers/aura_manager.gd`（0.5s 全局 tick 批处理；一次性类型注册即应用） | `aura_data.is_in_aura_range()` **恒返回 true**（v6.2 起），`get_slot_targets` 的 radius 参数是摆设 |
| 改造光环链（v6.8） | `unit_stats_table._extract_aura_summary_to_meta`（L576）：10 个 `ally_*` 效果键 → 8 个 stat 字段 → stats meta `mod_aura_summary` | `scripts/battle/mod_aura_handler.gd`：setup 广播 / _die 撤销 / 后入场补偿 `receive_mod_auras_from_field`（H9） | 同样全场广播；v10(H11) 已有 clamp 施加量记账（按实际施加量撤销） |

关键利好：**格子战术下单位不移动**（move_speed 是死属性），槽位在部署时写入 `card_grid_slot` meta（`battle_spawn_system.gd` L754）。
→ 范围判定只需在**部署/死亡事件**时重算，无需实时空间查询，性能成本极低。

### 1.2 组合技已有双轴骨架（v9.1）

- `data/combo_tactics.gd`：6 套路，每条含 `mod_ids`（单卡 ≥2 配套改造→单卡增益）+ `kind_combo`（combat_kind 5 桶计数→全队新机制 flag）。
- 执行：`combo_engine.gd`（battle_manager 持有，`get_combo_engine()` 暴露）+ `module_effect_handler.gd`（命中/DOT 消费）+ `bullet.gd`（读 `_special` flags）；浓度场 `combo_field_state.gd`（纳米/化学）。
- UI：`combo_status_strip.gd` 每秒轮询。已知断链：`combo_icons/` 6 张 PNG 缺失（AGENTS.md 断链资产）。
- 单卡 combo 检测写入 stats meta `combo_active`（`unit_stats_table.gd` L554-569），运行时只读 meta，**不重复扫描**。

### 1.3 配合粒度的缺口

- `kind_combo` 只认 combat_kind 5 桶（轻装/装甲/支援/空中/堡垒）；`unit_subtype`（NONE/ARTILLERY/SUPPORT/FORT/ANTI_AIR，`game_constants.gd` L182）与侦察卡前缀（`unit_stats_table._RECON_PREFIXES`）**未参与任何配合判定**——这正是"火炮+侦察"类搭档协同的空位。
- 9 改造兵种（ModificationRegistry：infantry/armor/artillery/anti_air/air/recon/engineer/fort/universal）与战斗桶之间没有统一的"角色"查询函数。

### 1.4 槽位几何

`scripts/card_grid_battle_layout.gd`：`SLOTS_PER_SIDE`、`get_row_for_slot()`（slot_index ÷ 每边槽数）、带内列距 pitch。槽距可直接用 **(行, 带内列) 的切比雪夫距离**表达，无需像素。

### 1.5 历史踩坑（改光环代码前对照）

- H9：光环源只覆盖"当时在场"友军 → 后入场补偿链（`receive_*_from_field`，AuraManager v20.15 已仿制同款）。
- H11：撤销按 raw 回退会在 clamp 截断时永久削低友军属性 → 已改按"实际施加量"记账（`_record_applied_delta`/`_pop_applied_delta`）。**范围化后撤销仍按记账回退，不按范围**——记账模型不受影响。
- v6.2 全场化本身是一次"范围判定伤害了可玩性/性能"的历史决策；本次恢复范围必须带**回滚开关**和**可读性投资**（当时弃坑的原因大概率是看不清谁吃到了光环）。

---

## 2. P0 战术光环范围化（混合方案）

**范围定位（用户已选）**：战术光环（SCOUT_CRIT / RADAR_RANGE / FORTRESS_DEF / MEDIC_HEAL）恢复槽距范围；
战略光环（COMMAND_GLOBAL 指挥 / CARRIER_REPAIR 载具维修）保持全场。

### P0-1 范围判定核心

- `data/aura_data.gd`：
  - `is_in_aura_range(source_slot, target_slot, range_cols)` 真实现：切比雪夫距离 ≤ range；
  - `get_aura_params()` 每类增加 `range` 字段（战术类默认 2；战略类 -1=∞）；
  - 新增 `slot_grid_coords(slot_index) -> Vector2i(带内列, 行)`（调 `card_grid_battle_layout` 现有换算，避免第三份几何表）。
- 星级扩列：**★5 起 range+1，★9 起 range+2**（只动范围不动 heal/crit 数值乘数，避免牵动全表重平衡；范围本身就是强度）。

### P0-2 判定插入点（两链同改）

- `AuraManager.get_slot_targets()`：按源单位 `card_grid_slot` + 目标 `card_grid_slot` 过滤（任一缺失时回退全场，保部署竞态安全）；
- `ModAuraHandler._get_all_allies()`：同样过滤，**改造光环默认 R=2**；`mod_aura_summary` meta 支持可选 `range_override`（为 P1 的"中继天线"传奇改造预留）；
- 后入场补偿 `receive_auras_from_field` / `receive_mod_auras_from_field` **不改结构**——它们复用同一判定函数，天然只补范围内;
- 医疗 3s tick（`_apply_medic_aura`）：源死后 unregister 已有；范围内目标列表按 tick 重算（n≤30 时 O(n²) 槽距比较可忽略，不引入缓存复杂度）。

### P0-3 UI 可读性（v6.2 弃坑的对症药）

- 部署瞬间：光环源脚下画范围框/圈（复用 `scenes/effects/` 演出层，0.8s 淡出，motion_reduce 分支静默）；
- `unit_info_panel` / `card_info_panel` 的 `_build_aura_text()` 加"影响范围：±2 格 / 全场"；
- 战术/战略光环图标区分：全场光环加"全域"角标；
- `unit_hp_bar` 或 buff strip：被战术光环覆盖的单位显示来源小标（复用 `mod_aura_applied` meta，已有读取方）。

### P0-4 敌方侧

- 敌方光环单位（enemy_unit/蜂群槽注册链）走同一 `get_slot_targets(is_player=false)` 路径，自动范围化；
- 实施时核对 `enemy_unit.gd` / `swarm_enemy_slot` 的光环注册点，确认敌方槽位 meta `card_grid_slot` 全部写入（`battle_spawn_system` 敌方路径 L525/L674 已写，蜂群路径需验证）。

### P0-5 验收

- 新增 `tests/unit/aura_range_smoke.gd`（--script 模式，不依赖 GdUnit）四断言：范围内友军吃到 buff / 范围外没吃到 / 源死亡后撤销（含 clamp 记账回退无漂移）/ 后入场单位只补范围内；
- GdUnit：`tests/unit/managers/` 补 aura_data 参数表单测（range 字段完整性）；
- 平衡：`balance-check` 技能全量审一遍光环强度变化（全场→±2 格是净削弱，输出调参建议：如医疗 heal_pct 0.08→0.10 或维持）；
- **回滚开关**：GameConfig battle 段新增 `aura_range_enabled`（默认 true；false = 完整回退 v6.2 全场行为，判定函数直接短路 true）。

---

## 3. P1 多改造配合强化

### P1-1 套装档位（2 件套保留，新增 4 件套机制升级）

`combo_tactics.gd` 每套路增加 `mod_combo_full`（4 件套效果 id），检测函数扩展返回档位。6 套路 4 件套（机制解锁，非数值翻倍）：

| 套路 | 4 件套效果 |
|------|-----------|
| 助燃燃烧链 | 燃烧目标死亡时留火种（继承 50% 燃烧层数的范围 DOT） |
| 电磁脉冲链 | 脉冲反射附带 0.5s 瘫痪 |
| 纳米浓度场 | 浓度自然衰减 -50% |
| 光束谐振链 | 反射次数 +1 |
| 侦察链式 | 弱点暴露改为全队共享（原仅侦察/狙击消费） |
| 化学污染场 | 污染可跨列蔓延（原限邻接） |

执行落点全在 `combo_engine` / `module_effect_handler` 现有机制函数内加档位分支，不动 bullet 路由。

### P1-2 行为改写型传奇改造（6 个，龙崖映射）

高费高识别度：占用尾槽成本档（`mod_effects.SLOT_COST` 14-20 档），`power_mult` 按战力标定走 balance-check。实现优先用"effects 新键 + 消费点分支"，不新建系统：

| 改造 | 行为改写 | 龙崖原型 | 实现挂点 |
|------|---------|---------|---------|
| 弹道重赋（gen_converted_munitions） | 攻击维度转换：对轻→对甲 | 转属性卷轴 | `attack_calculator` 维度选择段读 stats meta |
| 扩容弹舱（gen_expansion_chamber） | 同时攻击目标数 +1 | 温玉戒指（单奶→群奶） | `target_selection` |
| 溢流护盾（gen_overflow_shield） | 溢出维修→按比例转护盾 | 治疗吸收属性 | `module_effect_handler` 治疗/heal() 入口 |
| 精确制导针（gen_truestrike_pinpoint） | 无视 50% 闪避 | 混沌异界命中轴 | `attack_calculator` 命中段（补"命中 vs 闪避"缺失的半轴） |
| 中继天线（gen_relay_antenna） | 该卡改造光环 R2→全场 | ——（联动 P0） | `mod_aura_summary.range_override` |
| 统一装药（gen_unified_splash） | 溅射公式统一词条（在 B4 两路径统一后才有意义，若 B4 未做则先做 B4） | —— | `simple_indirect_projectile_batch` / `bullet.gd` |

其中"精确制导针"与"溢流护盾"同时是龙崖属性借鉴（B2/B3）的正式落点。

### P1-3 断链修复

`combo_icons/` 6 张 PNG（chem/emp/incendiary/laser/nano/recon）：走 `tools/generate_missing_card_icons` 同款流程生成，或永久改为文字 icon（与 P1-1 UI 一并处理）。

### P1-4 验收

- `detect_card_combos` 档位单测（2 件=现效果、4 件=升级效果、混装不误触发）；
- 每个传奇改造一条 smoke（效果触发 + 撤销/死亡无残留）；
- balance-check 全量审（新改造 power_mult + 套路档位）。

---

## 4. P2 多兵种配合（subtype 档搭档，双轨）

**双轨定义（用户已选）**：保留现有 combat_kind 5 桶 `kind_combo` 全队机制；**新增**角色级"搭档协同"——双方各 ≥1 在场即激活，围绕"一个单位的行为给另一个单位的攻击充能"（龙崖玩火→吞火模型）。

### P2-0 角色归一化（前置）

新增 `data/unit_roles.gd`：`resolve_role(card_id, combat_kind, unit_subtype) -> Role` 枚举 9 角色（infantry/armor/artillery/anti_air/air/recon/engineer/fort/universal），归一化规则：
- combat_kind 直接映射 armor/air/fort；unit_subtype 映射 artillery/sUPPORT→按卡 tag 细分；
- 侦察用 `_RECON_PREFIXES`（提升为该文件常量，`unit_stats_table` 转引用）；工程从 engineer 模组类别/卡 tag 判定；
- 结果缓存到 stats meta，P2 全部搭档表只认 Role。

### P2-1 搭档表（首批 5 对，`combo_tactics.gd` 新增 `PAIR_SYNERGIES`）

| 搭档 | 效果 | 龙崖原型 |
|------|------|---------|
| 侦察 × 火炮 | 侦察命中写入"标记"（目标 meta），火炮弹命中带标记目标：必暴 + 溅射 +50% | 玩火丢火种→吞火秒杀 |
| 工程 × 步兵 | 开战一次性：全体步兵 defense_light +20%（战壕掩体） | —— |
| 防空 × 己方空中 | 制空协同：己方空中对空攻速 +15% | —— |
| 装甲 × 轻装 | 掩护推进：双方部署延迟 bonus -15%（复用 deploy_delay_bonus） | —— |
| 堡垒 × 支援 | 庇护网络：FORTRESS_DEF 光环 range +1 列 | 联动 P0 |

### P2-2 执行框架

- 激活检测：部署/死亡事件驱动（复用 combo_engine 的战场事件入口，**不加每帧扫描**）；
- 标记类效果：目标 meta（`unit_status_collector` 范式），消费点在开火/命中路径，带过期清理；
- 数值类效果：走 `ModAuraHandler._apply_buffs_to_unit` 同款记账（apply/撤销对称），杜绝 H11 类漂移；
- UI：`combo_status_strip` 增加"搭档协同"显示区（激活对图标 + 一句话效果）。

### P2-3 敌方侧（可选，放 P2 尾部）

相位师遭遇战敌方携带搭档组合（`enemy_loadout_tiers` 高档解锁），情报系统（`intel_reveal_events`）增加"敌方搭档"揭示词条——敌我同源，可读性最好。

### P2-4 验收

- 5 对搭档各一条 smoke（激活条件、标记过期、死亡撤销）；
- 角色归一化单测（subtype/前缀/tag 三来源）；
- balance-check：搭档强度 vs 单兵种纯堆的期望收益差（目标：搭档 ≈ +15~25% 等效强度，不是翻倍）。

---

## 5. P3 外围采纳项（龙崖其余借鉴，按依赖分两批）

### 批 A（都动敌方难度/掉落，一并做）

| 项 | 内容 | 挂点 |
|----|------|------|
| A2 敌方精英同源词条 | `enemy_loadout_tiers` 档 2/3 除数值乘区外，从 AffixManager 现成词条池挂 1 条玩家侧同款词条 | `enemy_stat_resolver` / `battle_spawn_system._apply_enemy_loadout_tier_*` |
| C2 资源分级跟随难度 | 高档位敌人掉"精材料"（独立掉落表），供 P3 批 B 的打造 sink | `drop_manager` 掉落表 |
| B1 面板首行主攻击维度 | 单位详情第一行显示三攻最强维（对应龙崖"面板第一行=元素"） | `unit_info_panel` / `card_info_panel` |

### 批 B（养成/经济 sink）

| 项 | 内容 | 挂点 |
|----|------|------|
| C1 产能→改造打造 | DayClock 离线产能 → 指定改造模块打造/洗练材料（填蓝图删除后的制造位） | `day_clock` + `basic_resource_manager` + `ModificationRegistry` |
| A4 首杀解锁 | 相位师/boss 首杀"解锁"（非赠送）稀有改造/传奇改造 | `drop_manager` + InstanceRegistry 记账；**注意 SaveManager schema v8→v9 迁移** |
| C3 build-around 传奇词条 | 5-8 个 `special_mechanic` 型词条（改规则不加数值），与 P1-2 传奇改造共用设计语言 | `AffixManager`（reroll/lock/变异链已齐） |

---

## 6. 实施顺序与验收矩阵

| 批次 | 核心改动文件 | 预估 | 验收 |
|------|-------------|------|------|
| P0 光环范围化 | aura_data / aura_manager / mod_aura_handler / unit_info_panel / effects 层 / GameConfig | 中（核心 ~3 文件，UI/测试占半） | aura_range_smoke 4 断言 + balance-check + 开关回滚验证 |
| P1 改造配合 | combo_tactics / combo_engine / module_effect_handler / modification_modules(+6 传奇) / tools 图标 | 中偏大（数据为主） | 档位单测 + 6 传奇 smoke + balance-check |
| P2 兵种搭档 | unit_roles(新) / combo_tactics / combo_engine / unit_status_collector / combo_status_strip | 中 | 5 搭档 smoke + 角色归一化单测 |
| P3-A 敌方侧 | enemy_loadout_tiers / enemy_stat_resolver / drop_manager / unit_info_panel | 小 | 掉落表单测 + 词条挂载 smoke |
| P3-B 经济 sink | day_clock / basic_resource_manager / affix_manager / save_migration_v9 | 中（含存档迁移） | 存档完整性测试 + 迁移链 v1→v9 |

验证方式按 AGENTS.md 分层：纯逻辑 gdparse → 单文件 `--script` load+断言 → 大批次才 `--check-only` 兜底；每批结束跑一次 `balance-check` 技能。

## 7. 风险与回滚

1. **光环范围化是净削弱**（全场→±2 格）：开关 `aura_range_enabled` 可整体回退；数值补偿以 balance-check 输出为准，先保机制后调数值。
2. **meta 记账是事故高发区**（H9/H11 前科）：P0/P2 所有 buff 施加/撤销对称性先写 smoke 断言再动代码。
3. **槽位 meta 缺失竞态**：部署瞬间 `card_grid_slot` 未写时判定函数回退全场（宁可多给不误伤）。
4. **存档迁移**：仅 P3-B 触及 schema，走 v8→v9 迁移链 + 旧档 key 级静默跳过惯例。
5. combo/bullet 路由敏感区（AGENTS.md 弹道遗留问题清单）：P1 一律不动 batch/bullet 路由，行为改写只挂 stats meta 消费点；统一装药词条依赖的 B4（溅射两路径统一）若未完成则该改造延后。

## 8. 明确不做（本轮）

- 自动/手动双轨收益（怒气不放→全队 buff）——用户否决（2026-08-30）；
- 像素半径圆判定（槽距方案已定，格子战术下无增益）；
- 爬塔/异界式难度层（爬塔已移除，难度由 enemy_loadout_tiers 承担）；
- 城镇居民经营规模（只取"产能→打造"一点）；
- 怒气/战法实时释放系统（与布阵战术定位冲突）。
