## 数据平衡修订计划（按优先级顺序）

按顺序修复审计报告的 P0→P2 + M 类共 **9 个问题**，每处改动附 file:line 与精确新旧值。全部为数据/常量层改动，向后兼容。先做改动，后用 Grep 静态核对 + Godot `--check-only` 验证。

---

### P0-F1. 巨型能量罩恢复星级分级（2 处必改）

**问题**：`ability_mega_shield` 统一返回 3000，且 `_apply_mega_shield` 运行时又硬 `minf(...,3000)` 二次压制——两处都得改，否则运行时白改。

| 文件 | 行 | 改动 |
|---|---|---|
| `data/phase_instruments.gd` | `:222-231` | `ability_mega_shield` 恢复按 star 分级：4★=3000 / 6★=5000 / 7★=8000（取 v6.6 原值 5000/10000/20000 的 ~40%，避免 boss 战过强）；移除"统一上限"注释，改"星级分级" |
| `managers/battle/phase_instrument_abilities.gd` | `:302-304` | 移除硬编码 `minf(shield_amount, 3000.0)` 上限压制（改为直接用 params 值）；保留注释说明上限已由生成器决定 |

---

### P0-F3. 进化路径 HP 回退修正（4 个文件）

| 文件 | 阶段 | 当前 → 新值 | 说明 |
|---|---|---|---|
| `data/evolution_paths/artillery_evolution.gd` | E4 (`:41`) | max_hp 300→**380** | 不低于 E3 的 320 |
| `data/evolution_paths/anti_air_evolution.gd` | E3 (`:34`) | max_hp 350→**400** | 不低于 E2 的 380 |
| `data/evolution_paths/air_evolution.gd` | E3 蜂群 (`:55`) | max_hp 300→保持 300，但保留注释说明 | 蜂群=多单位低血，属设计取舍，不改数值但确认注释存在 |
| `data/evolution_paths/infantry_evolution.gd` | E5 巨神 (`:122`) | attack_light 100→**150** | 保留"转重装"语义但不腰斩 |

---

### P1-F2. 闪避 cap 统一为 0.50

**问题**：`modification_registry.gd:258-262` 把 dodge_chance 与 crit_chance/armor_pen 混在一组 `min(1.0)`。要把 dodge_chance 单独拆出用 `min(0.50)`，其余留在 1.0 组。

| 文件 | 行 | 改动 |
|---|---|---|
| `scripts/systems/modification_registry.gd` | `:258-262` | 把当前合并分支拆为两个 match 分支：`"crit_chance","crit_resist","armor_penetration","armor_pen_vs_*"` → `min(1.0)`；`"dodge_chance"` → `min(0.50)`。加注释说明 dodge 全局统一 0.50 cap |

---

### P1-H3. 相位师 master 攻防系数对称化

**决策**：保留 v6.12"敌方变强"诉求，让攻防对称（推荐项：抬 m_hp 系数）。

| 文件 | 行 | 改动 |
|---|---|---|
| `data/enemy_stat_resolver.gd` | `:44` | `master_defense_hp_multiplier` 系数 0.0006 → **0.0008**（与 m_atk 对称）。更新注释：master016(def200)→1.16x、master030(def200)→1.16x |

---

### P2-H1. 时代 HP 倍率提高（用户选定）

| 文件 | 行 | 改动 |
|---|---|---|
| `data/battle_card_v3.gd` | `:17-18` | `era_hp_multiplier` 从线性 `1.0 + era*0.15`（末段 1.45/1.60）改为查表：`[1.00, 1.15, 1.30, 1.50, 1.70]`，仅末两档（现代/近未来）抬高，前段不变。血量/伤害比回到 ~0.95 |

---

### P2-H2. move_speed 重定向系数提升

| 文件 | 行 | 改动 |
|---|---|---|
| `scripts/systems/modification_registry.gd` | `:239` | 系数 0.005 → **0.02**（×4），让 move_speed=20 → deploy_delay -0.4（明显体感）。更新注释的换算示例 |

---

### P3-H4. 工程兵进化死链 + 卡类型修正（用户选定"仅修死链+卡类型"）

**现状**：E0 `card_id="ww1_engineer"` 是死链（真卡是 `ww1_sup_engineer`）；E1 `fut_nano_drone` 在 default_cards 里 combat_kind=3(AIR) 而进化文件按工程兵设计。

| 文件 | 行 | 改动 |
|---|---|---|
| `data/evolution_paths/engineer_evolution.gd` | `:10` | E0 `card_id` "ww1_engineer" → **"ww1_sup_engineer"**（修正死链指向真实卡） |

注：E1 的 fut_nano_drone combat_kind 不一致属 default_cards 数据设计（该卡实际是 AIR 型无人机），不在进化文件内改——进化文件本身不含 combat_kind 字段，无法在此修正。本轮范围确认到此。

---

### P3-M 类（一致性清理，4 项）

| # | 文件 | 行 | 改动 |
|---|---|---|---|
| M3 | `scripts/master_power_evaluator.gd` | `:617-619` | RUNE_RARITY_BASE 补 `"mythic": 200.0` 条目 |
| M3 | `scripts/master_power_evaluator.gd` | `:205-207` | INSTRUMENT_RARITY_SCORE 补 `"legendary": 600.0` 条目（插在 epic 与 mythic 之间语义合理） |
| M4 | `data/basic_resources.gd` | `:97-98` | 删除孤儿函数 `get_specific_permit_id`（v7.3 许可证已删） |
| M2 | `data/enemy_stat_resolver.gd` | `:53-56` | `collect_player_pressure` 加注释标注"预留未接通的难度调节点"，不删（保留扩展点） |

**M1（armor_pen/lifesteal cap 统一）暂不做**：改造/统计层 cap(0.80/0.60) 与词条实例 cap(0.50/0.25) 是两层概念（实例值 vs 应用后总值），强行统一会破坏词条设计。本轮仅 M3/M4/M2。

---

### 验证步骤（改完后）

1. **Grep 静态核对**：确认每处新值拼写一致、无残留旧值（3000 硬上限、dodge_chance 1.0 cap、旧 era 公式等）
2. **Godot `--check-only`**：无语法错误（注：项目体量 5 分钟超时属既有现象，启动到 133 卡构建即视为通过）
3. **生成 smoke test 不做**：数值均为数据/常量改动，无新逻辑分支，静态核对 + check-only 足够

### 文档同步（最后）

在 AGENTS.md 追加一段 v7.x 平衡修订记录（本次所有改动汇总），与既有 v6.x/v7.x 记录格式一致。