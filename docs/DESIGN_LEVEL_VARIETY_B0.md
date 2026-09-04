# 关卡机制多样性设计（B0 草案 — 待批）

> v26.12 起草（2026-09-03）。目标：解决品质调研最大体验短板——"100 关 ≈ 同玩法重复 80+ 次"。
> 本文批准后才进实现；数值均为首版拍脑袋值，实装后按 audit 工具 + 实测校准。

## 一、现状（调研核实）

| 维度 | 现状 | 覆盖率 |
|---|---|---|
| 特殊规则 | 3 种类型（energy_mult / energy_regen_mult / restrict_platforms） | 11/100 关 |
| 定制棋面 | rows(2/3) / 敌我 cols(2-4) / 废墟格 | 15/100 关 |
| 显式环境 | 四维（天气/地形/能量场/时段）组合 ≈10 种 | 5/100 关（其余落时代默认模板） |
| 战术主题 | 8 种（只改敌方构成比例） | 100/100 关（hash 分配） |

结论：机制骨架单一，差异主要靠数值档位（enemy_loadout_tiers）与敌方构成。

## 二、目标

- 特殊规则覆盖 11 → **45 关**（每时代 ≥8），规则类型 3 → **10 种**
- 定制布局 15 → **35 关**
- 显式环境 5 → **25 关**（环境组合扩到 20+ 种）
- 每时代末 3 关（18/19/20 档）必有一项新机制组合，形成"时代压轴"记忆点

## 三、新规则类型（7 种，全部走 special_rules 字典加键）

| 键 | 语义 | 引擎钩子 | 风险 |
|---|---|---|---|
| `time_limit_sec` | 限时歼灭：超时判负（复用僵持判负 UI 通道） | battle_manager._process 倒计时 + TopHudBar 显示 | 低 |
| `no_heal` | 禁疗：我方治疗/回血效果 ×0 | 治疗入口单点乘区（定位后一行） | 低 |
| `no_mods` | 禁改造：本场 stats 构建跳过 mods 通道 | build_stats 侧开关（与 env_effects 同位） | 低 |
| `elite_wave_bonus` | 每波额外 +1 精英（TAG_PATCH 池按时代取） | spawn 波次组装处 | 中（需强度校准） |
| `first_strike` | 敌方开局全体前压 3 秒（移速 ×2 起步期） | 单位 spawn 后 3s 移速乘区 | 低 |
| `energy_starvation` | 回能速率 -50%（比 energy_regen_mult 更狠的独立档） | 复用 regen 乘区 | 低 |
| `boss_enrage_half` | 相位师 50% 血后攻击间隔 ×0.8 | boss 单位 buff 钩子 | 中 |

**设计原则**：全部是"数值/节奏规则"，不新增胜负类型（win_type 保持歼灭制）——
新胜负类型（护送/占点）是 1.0 后内容，不进本轮。

## 四、分布草案（表加行，零代码）

- 每 10 关一组节奏：1 新规则引入 → 2 复合（规则+布局） → 3 显式环境 → 5-7 主题强化 → 8-9 组合压轴 → 10 boss
- 复合规则（同关 2 条）从 L30 起引入；L80+ 出现"规则+环境+布局"三复合
- 已有 11 关的现有规则全部保留，只做增补

## 五、实现切分

1. **B1（数据层，约 2 天）**：level_information special_rules 挂载 34 关新条目 +
   level_battle_layouts 加 20 行 + battle_environments 扩 15 组合。跑
   `tools/audit_level_enemy_fun.gd` + `balance_audit_cards.py` 校准
2. **B2（引擎钩子，约 3 天）**：7 个新规则键的消费点（上表第三列），每键配一条
   GdUnit 数据锁；`_format_special_rules` 战前摘要同步新键文案
3. **B3（体感验证，约 2 天）**：headless soak 过全 100 关无脚错 + 抽 20 关实机体感

## 六、验证门禁

- 数据锁：每规则类型至少 1 关的 get_special_rules 断言（仿 battle_env_layouts_test）
- balance_audit_mods_evo.py 不回归；敌我强度用 enemy_tier_strength_audit 复测
- L1 教程关保持无任何条目（铁律）
