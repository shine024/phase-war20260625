# 战斗卡 v3 — 代码架构、SSOT 与存档迁移

本文档配合 [`BATTLE_CARD_V3.md`](BATTLE_CARD_V3.md) 使用，描述 **当前仓库** 向「单张战斗卡」真源收敛时的技术约定。

---

## 1. 单一真源（SSOT）

| 层级 | 内容 | 现状与目标 |
|------|------|------------|
| 策划真源 | 卡面六维、时代、TYPE、特效、进化/变异表 | [`BATTLE_CARD_V3.md`](BATTLE_CARD_V3.md) + 后续外置表（JSON/Resource） |
| 运行时战斗体 | `UnitStats` | 由 **card_id + 养成状态** 在出战时 **派生**（见 §3） |
| 蓝图养成 | `BlueprintManager`：`blueprint_stars`、`blueprint_mods`、`blueprint_inherit_bonus` | 已按 `card_id` 存储；与 v3 经济对齐见 `blueprint_star_config.gd` |

**`card_id`** 为跨系统主键：掉落、存档、蓝图、战斗特殊逻辑（如 `UnitStats.card_id`）应统一使用该字符串。

---

## 2. `CardType` 与平台/武器拆分 — 弃用策略

`GameConstants.CardType` 中 `PLATFORM` / `WEAPON` / `COMBINED` 与 `CardResource` 上的 `source_platform_id` / `weapon_card_ids` 等为 **历史拆分式战斗卡** 路径。

**策略（渐进）**

1. **新内容与 UI 文案**：一律以「战斗卡」/`COMBAT_UNIT` 为主表述；拆分类型仅用于读档与旧资源兼容。
2. **新卡数据**：优先使用 `CardType.COMBAT_UNIT`，在单资源上填齐 `platform_type`（映射为 TYPE）与战斗数值；不再新增依赖 `COMBINED` 的关卡奖励路径（除非过渡期需要）。
3. **存档**：不强制改写历史字段；加载后若存在「仅平台+武器、无合一卡」的旧组合，在 **制造/出战** 时解析为等效 `card_id`（具体映射表随默认卡数据迭代）。
4. **删除时机**：当 `grep` 显示无运行时依赖 `PLATFORM`/`WEAPON`/`COMBINED` 后，再收缩枚举并 bump `SAVE_SCHEMA_VERSION`（避免过早破坏旧档）。

---

## 3. `UnitStats` 派生

[`resources/unit_stats.gd`](../resources/unit_stats.gd) 仍为战斗用扁平结构（含 `platform_type` / `weapon_type`、词条字段）。

**派生规则（目标）**

1. 输入：`card_id`、`star`、`era`、`enhance_level`、改装与变异加成、继承倍率。
2. 从 `DefaultCards` / 外置 `BattleCardDef` 读取基础 HP/ATK/射程/间隔/移速/COST/TYPE。
3. 依次应用：`BattleCardV3` 时代倍率 → 星级倍率 → 稀有度（若单独成乘区）→ 强化/改装/继承（顺序以战斗数值文档为准，实现时需单点函数避免重复乘算）。
4. **单武器制**：`UnitStats.weapons` 在战斗构建中 **最多保留 1 条**（与 `attack_damage` / `attack_range` / `attack_interval` 主行一致）。`BlueprintManager.apply_growth_to_stats` 在养成倍率结算后调用 `_sync_single_weapon_damage_from_attack`，把 `weapons[0].damage` 写成与 `attack_damage` 相同。`ConstructUnit` 在法则被动（`_apply_phase_law_passives`）后通过 `_sync_single_weapon_cfg_from_stats` 把唯一 `_weapon_cfgs[0]` 与 `stats` 主行对齐。

拆分式字段可保留为「兼容层」：例如 `weapon_type` 由默认武器映射填默认值，直至战斗系统完全按 `card_id` 分支。

---

## 4. 进化路线准入（`任意平台` 等）

在数据层为每条进化路线增加：

- `evolution_route_id: String`
- `entry_card_ids: Array[String]` **或** `entry_tags: Array[String]`（如 `["ww1_hound","cold_hound"]` 或 `["tag:scout_line"]`）

校验进化按钮时：**当前卡** 的 `card_id` 或 tags 与路线表求交，非空则允许进入该线下一节点。

---

## 5. 存档迁移

**经济数值（升星/改装）** 由 `BlueprintStarConfig` 在运行时计算，**无需**为对齐 v3 单独 bump 存档版本。

若未来将「强化等级 / 纳米」写入存档并改语义，应在 `SaveManager._migrate_save_data` 增加链式步骤，并递增 `SAVE_SCHEMA_VERSION`。

**拆分卡 → 合一战斗卡**：若引入新 `card_id` 合并旧对，需要一次性迁移：`blueprint_copies` / `blueprint_stars` 键名替换表，并在迁移后删除旧键（单独版本号 + 备份策略）。

---

## 6. 乘区与 PvE 建议（实现侧）

- 继承总上限 100% 已在设定中写明。
- 建议在 `DamageCalculation` 或统一 `CombatStatAggregator` 中记录各乘区贡献，便于对 **终局特性 + 改装 + 稀有** 做 **clamp 或递减收益**，与关卡 `enemy_power_scale` 同步调参。

---

## 7. 相关文件索引

| 文件 | 职责 |
|------|------|
| [`data/battle_card_v3.gd`](../data/battle_card_v3.gd) | 时代 / 星级公式（与设定一致） |
| [`data/blueprint_star_config.gd`](../data/blueprint_star_config.gd) | 升星研究点表、改装点与许可、副本→星换算 |
| [`managers/blueprint_manager.gd`](../managers/blueprint_manager.gd) | 蓝图状态与改装消费 |
| [`resources/unit_stats.gd`](../resources/unit_stats.gd) | 运行时单位属性 |
| [`resources/game_constants.gd`](../resources/game_constants.gd) | `CardType` / `PlatformType` / `Era` |
| [`resources/card_resource.gd`](../resources/card_resource.gd) | 单卡资源字段 |
