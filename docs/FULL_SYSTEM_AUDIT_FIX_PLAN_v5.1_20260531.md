# 📋 《相位战争》全系统审计与修复计划 v5.1

> **审计日期**：2026-05-31
> **基准文档**：《相位战争》完整设计文档 v5.0 - 最终版20260529
> **审计范围**：设计文档 ↔ 全量代码实现 + 存量审计报告交叉验证
> **审计方法**：逐文件 grep 源码 + 人工比对设计文档数据 + 审阅已有审计报告差异

---

## 一、总体评估

| 维度 | 得分 | 说明 |
|------|------|------|
| **数据一致性** | 90/100 | 110单位数据已对齐；MOD_20效果完整含attack_multiplier；RPG组已补充 |
| **功能完整性** | 82/100 | 改造伤害已接入；情报门控已启用；部署速度已实现 |
| **代码正确性** | 88/100 | BUG-01/BUG-02/BUG-03 均已修复；enhance_level顺序已修正 |
| **遗留债务** | 55/100 | 词缀系统553处引用仍活跃；星级系统22处写入仍在运转；omega_platform等遗留ID大量残留 |
| **文档一致性** | 70/100 | 文档标题编号仍有错；空中线用AH-64替代F-22未更新文档 |
| **综合评分** | **77/100** | 核心玩法系统已基本对齐，最大风险在于遗留系统清理不彻底 |

---

## 二、已修复的问题（✅ 确认）

以下问题在上次审计后已被修复，本次确认代码中已正确处理：

| ID | 问题 | 修复状态 |
|-----|------|----------|
| BUG-01 | `card_enhancement_manager.gd` 中 `base_damage` 不存在 | ✅ 已改为 `card.power`（L58） |
| BUG-02 | `attack_calculator.gd` 改造伤害倍率被注释 | ✅ 已实现 `get_mod_damage_multiplier()` 并接入第6步（L70-80） |
| BUG-03 | 全局 autoload 不安全引用 | ✅ `PhaseLawManager.` 直接引用已清零 |
| BUG-1(v5.1) | `enhance_level >= 9` 在 `>= 10` 之前（死代码） | ✅ `attack_calculator.gd` L61-65 和 `bullet.gd` L354-359 均已改为 `>= 10` 优先 |
| BUG-2(v5.1) | 硬编码绝对路径 `F:/godot fair duel/...` | ✅ 已清零 |
| DIFF-01a | 缺失 `cold_rpg` 单位 | ✅ 已在 `default_cards.gd` L78 补充 |
| DIFF-01b | 反坦克线进化链缺少RPG环节 | ✅ `unit_lineage_config.gd` L52/117 已插入 |
| MISSING-02 | 情报100%检查被注释 | ✅ `unit_lineage_config.gd` L453-454 已启用 `target_intel < 1.0` 检查 |
| MISSING-01 | deploy_speed 未在战斗中生效 | ✅ `construct_unit_deploy.gd` 已完整实现（含公式、虚影模式、进度条） |

---

## 三、🔴 仍未修复的问题（需立即处理）

### 问题 A-01：词缀系统（Affix）—— 553处引用仍在代码中活跃运行

**严重程度**：🔴 P0（影响战斗正确性）

**现状**：
- `affix_resource.gd`（149行）完整类定义仍在
- `affix_manager.gd`（643行）完整管理器仍在，被 aura_manager、card_ability_manager 调用
- `affix_combat_handler.gd`（340行）仍在 `bullet.gd` L367 被调用计算伤害
- `card_resource.gd` L148-151：`affix_slot_ids`、`affix_slot_count` 仍作为 `@export` 字段存在
- `card_resource.gd` L379-380：`duplicate()` 仍复制词缀字段
- `drop_manager.gd` L139/142：掉落时仍写入词缀数据
- `UnitStats` 中仍包含 `damage_reduction`, `crit_chance`, `lifesteal`, `splash_damage` 等词缀专属属性

**影响**：
1. `bullet.gd` L367：弹道命中后通过 `AffixCombatHandler.calculate_damage()` 二次修改伤害，此修改**叠加在 v5.0 改造加成之后**，导致伤害计算链不可预测
2. 词缀系统的暴击/吸血/溅射效果仍在战斗中生效，与设计文档「词缀已删除」矛盾
3. 词缀UI面板（`affix_panel.gd`）仍存在，可能误导玩家

**建议决策**：
- **方案A（推荐）**：保留词缀为「模块化词条」的底层实现，将 `affix_slot_ids` 重命名为 `module_slots` 的别名，统一 `module_slots` → `affix_slot_ids` 的映射。更新文档说明模块化词条=词缀系统v2
- **方案B**：彻底删除词缀系统（预估16h工作量，需全面回归测试）
- **方案C（最低成本）**：在 `bullet.gd` 中移除 `AffixCombatHandler.calculate_damage()` 调用，让词缀数据存在但不影响战斗

**涉及文件**（553处引用）：
| 文件 | 引用数 | 关键引用 |
|------|--------|---------|
| `managers/affix_combat_handler.gd` | — | 被 bullet.gd 调用（影响战斗伤害） |
| `managers/affix_manager.gd` | — | 被 aura_manager、card_ability_manager 调用 |
| `resources/affix_resource.gd` | — | 词缀资源定义 |
| `resources/card_resource.gd` | — | affix_slot_ids/affix_slot_count 字段 |
| `scenes/units/bullet.gd` | L367 | AffixCombatHandler.calculate_damage() |
| `managers/drop_manager.gd` | L139/142 | 掉落写入词缀 |
| `scenes/ui/affix_panel.gd` | — | 词缀UI面板 |

---

### 问题 A-02：星级系统（star_level）—— 22处代码仍在写入/读取

**严重程度**：🔴 P0（影响进化系统正确性）

**现状**：
- `card_resource.gd` L160：`@export var star_level: int = 1` 仍存在
- `card_resource.gd` L382：`duplicate()` 仍复制 star_level
- `blueprint_manager.gd` L554：制造时写入 `out_card.star_level = star`
- `blueprint_manager.gd` L68：`var blueprint_stars: Dictionary = {}` 仍在管理星级数据
- `blueprint_manager.gd` L338-339：`get_blueprint_star()` 函数仍被调用
- `drop_manager.gd` L136/302：掉落时写入 `card.star_level`
- `aura_manager.gd` L187/197-199：读取/写入 `unit.get_meta("star_level")`
- `card_ability_manager.gd` L559/567/569：同上
- `scenes/tools/card_ui_preview.gd` L609/611/642：UI 显示/设置星级
- `scenes/ui/backpack_card_item.gd` L819：背包UI读取星级
- `scenes/ui/backpack_panel.gd` L347：背包面板显示星级
- `scenes/ui/manufacture_panel.gd` L257/271：制造面板显示星级
- `affix_manager.gd` L479-480：词缀效果依赖星级

**影响**：
1. 设计文档说「星级已删除」，但进化系统实际上**不依赖星级**（unit_lineage_config 中已无 E1_MIN_STAR/E2_MIN_STAR），所以进化逻辑本身没有bug
2. 但星级仍在制造、掉落、UI显示中活跃写入，造成玩家可看到星级数字但星级无实际功能——**UI误导**
3. 存档中仍序列化星级数据，造成存档膨胀

**建议决策**：
- **方案A（推荐）**：移除所有 star_level 写入代码，UI 中将星级显示替换为蓝图等级（enhance_level 可视化）
- **方案B**：暂时保留但添加 `@deprecated` 标注，在中期统一清理

**涉及文件**（22处）：
| 文件 | 行号 | 操作 |
|------|------|------|
| `resources/card_resource.gd` | L160 | 删除 @export 或标记 @deprecated |
| `resources/card_resource.gd` | L382 | 从 duplicate() 移除 |
| `managers/blueprint_manager.gd` | L554 | 移除 star_level 赋值 |
| `managers/blueprint_manager.gd` | L68/215/234/235/247/306/327/338/339/343 | 清理 blueprint_stars |
| `managers/drop_manager.gd` | L136/302 | 移除 star_level 赋值 |
| `managers/aura_manager.gd` | L187-199 | 替换为 enhance_level |
| `managers/card_ability_manager.gd` | L559-569 | 替换为 enhance_level |
| `scenes/tools/card_ui_preview.gd` | L609/611/642 | 替换显示 |
| `scenes/ui/backpack_card_item.gd` | L819 | 替换显示 |
| `scenes/ui/backpack_panel.gd` | L347 | 替换显示 |
| `scenes/ui/manufacture_panel.gd` | L257/271 | 替换显示 |
| `managers/affix_manager.gd` | L479-480 | 移除词缀星级依赖 |

---

### 问题 A-03：blueprint_copies（蓝图碎片）—— BlueprintManager 仍在管理

**严重程度**：🟠 P1

**现状**：
- `blueprint_manager.gd` L65：`var blueprint_copies: Dictionary = {}` 仍在
- 至少 18 处引用（L213/227/230/243/245/305/315/316/326/402/403/409/609/737/738/756/777/778）
- 存档仍序列化/反序列化 blueprint_copies
- achievement_definitions.gd 和 quest_definitions.gd 中 135 处 `blueprint_fragments` 奖励引用

**影响**：
- 碎片系统已不再有意义（蓝图解锁由游戏进度驱动），但数据仍在存档中写入
- 任务/成就奖励中的 `blueprint_fragments` 无法被正常消费（无消费代码），导致奖励失效
- **成就/任务系统有135处奖励可能无法正确发放**

**建议决策**：
- 将 achievement/quest 中的 `blueprint_fragments` 奖励替换为等价的 `nano_materials` 或 `research_points`
- 从 BlueprintManager 存档中移除 blueprint_copies 序列化（保留字段但标记 @deprecated）

---

### 问题 A-04：omega_platform 遗留ID—— 与 fut_colossus 数据完全相同

**严重程度**：🟡 P2

**现状**：
- `default_cards.gd` L144-146：omega_platform 仍作为第113个单位存在，数据与 fut_colossus 完全相同
- `enemy_unit_manifest.gd` L264/559/614：仍有 omega_platform 条目
- `blueprint_manager.gd` L193/230/231：仍引用 omega_platform
- `achievement_definitions.gd`：7处 omega_platform 引用
- `quest_definitions.gd`：5处 omega_platform 引用
- `data/unit_id_migration_config.gd` L52：`"omega_platform": "fut_nexus"` 已定义迁移映射

**影响**：单位总数实际为113个（110+omega_platform+14势力卡+7能量卡），存档中可能有玩家持有 omega_platform 卡牌

**建议**：保留 omega_platform 作为存档兼容shim，但不再在新流程中生成。在 enemy_unit_manifest 中添加迁移逻辑。

---

## 四、🟡 设计文档需要更新的问题

### 问题 D-01：文档标题编号不一致

| 位置 | 当前写法 | 应改为 |
|------|---------|--------|
| 第七章主标题 | "完整**100**个基础单位数据" | "完整**110**个基础单位数据" |
| 中间小标题 | "完整**105**个单位数据" | 删除此行（从未存在105个） |
| 文档底部 | "v5.1 - 含堡垒类最终版" / "总单位数：110个" | ✅ 已正确 |
| 总计标题 | "完整110个单位数据（含堡垒类）" | 保留，其余统一为110 |

### 问题 D-02：空中战斗机线—— F-22 不存在，文档未更新

| 设计文档描述 | 代码实际实现 |
|-------------|-------------|
| 战斗机线：米格-21(400) → **F-22(800)** → 空天(1325) | 代码：米格-21(400) → **AH-64阿帕奇(800)** → 空天(1325) |

**问题**：AH-64 是攻击直升机，不是固定翼战斗机。设计文档写的 F-22 在代码中从未实现。

**建议**：
- **方案A**：在 default_cards.gd 中新增 `mod_f22` 单位（空中/空射/power=800/HP=350/对轻=80/对甲=70/对空=250），更新进化链
- **方案B**：更新设计文档，将战斗机线改为"米格-21 → AH-64 → 空天战斗机"，并说明AH-64在此进化链中代表"重型对地攻击机升级为空天战斗机"
- **方案C**：将 AH-1 眼镜蛇改为空战中间节点（攻击直升机线保留AH-64，战斗机线用AH-1）

### 问题 D-03：堡垒类（FORT）无进化路线

**现状**：10个堡垒单位在 `unit_lineage_config.gd` 的 LINEAGES 中**没有任何条目**。

**设计文档**：未明确堡垒是否有进化路线，属于设计遗漏。

**建议进化路线**（需设计确认）：
```
防御线：fort_ww1_pillbox(80) → fort_ww2_bunker(200) → fort_cold_missile(500) → fort_modern_citadel(800) → fort_future_ion(1200)
防空线：fort_ww2_flak(220) → fort_modern_phalanx(600) → fort_future_shield(1000)
终端节点：fort_ww1_artillery, fort_cold_radar（辅助功能单位，不进化）
```

### 问题 D-04：纯辅助堡垒单位武器类型推断

| 单位 | attack全0 | 当前推断 | 问题 |
|------|----------|---------|------|
| `fort_cold_radar`（雷达站） | 0/0/0, range=99 | INDIRECT | ❌ 雷达无曲射能力 |
| `fort_future_shield`（护盾发生器） | 0/0/0, range=0 | DIRECT | ❌ 无直射能力 |
| `fut_shield`（力场发生器） | 0/0/0, range=0 | DIRECT | ❌ 无直射能力 |

**影响**：这些单位被归入错误的武器类型，虽然它们攻击力全为0不影响伤害计算，但可能影响选敌逻辑和UI显示。

**建议**：在 `_infer_weapon_type()` 中增加"三维攻击全为0"的处理，标记为 SUPPORT 类型或不参与选敌。

---

## 五、🟢 已正确实现确认（无问题）

| 系统 | 验证点 | 状态 |
|------|--------|------|
| WeaponType 枚举 | DIRECT=0, INDIRECT=1, AERIAL=2 | ✅ |
| CombatKind 枚举 | 含 FORT=4 | ✅ |
| 三维攻击/防御 | attack_light/armor/air, defense_light/armor/air | ✅ |
| 每目标攻击速度 | 9字段（力/速/前摇/动作×3套） | ✅ |
| 伤害公式 | 击穿检查 + 100/(100+def) | ✅ |
| 射程衰减 | 仅 DIRECT 武器，6种系数 | ✅ |
| 三种选敌逻辑 | DIRECT/INDIRECT/AERIAL 完整实现 | ✅ |
| 110个战斗单位 | default_cards.gd 100+10堡垒+omega_platform | ✅（113含兼容） |
| 强化100%成功 | 无随机判定 | ✅ |
| 强化倍率 | Lv1-8线性, Lv9=1.50, Lv10=1.60 | ✅ |
| 强化消耗 | base_power × 等级系数 | ✅ |
| 20种改造效果 | MOD_01-MOD_20 含 attack_multiplier/condition_type | ✅ |
| 改造伤害接入 | get_mod_damage_multiplier() 在 calculate_damage 第6步调用 | ✅ |
| 情报门控 | unit_lineage_config L453-454 已启用 | ✅ |
| 部署速度系统 | construct_unit_deploy.gd 完整实现 | ✅ |
| 情报手册系统 | IntelManual 49处引用，功能完整 | ✅ |
| 改造进化继承 | BlueprintManager 中 mods 复制到目标 | ✅ |
| RPG组单位 | cold_rpg 已补充，反坦克链已插入 | ✅ |
| LawShardManager | 已完全清理（0处引用） | ✅ |
| 硬编码绝对路径 | 已完全清理 | ✅ |
| 对象池 | ObjectPool 已到位 | ✅ |
| 空间网格 | BattleManager 中已实现 | ✅ |
| 9条进化主线 + 势力分支 | LINEAGES 含 faction_branches 数据 | ✅ |

---

## 六、🔧 详细修复计划

### Phase P0：遗留系统决策与清理（预估 2-3天）

#### 任务 P0-1：词缀系统决策
- **工作量**：0.5h（决策）+ 方案执行时间
- **行动**：
  1. 确认方案A/B/C
  2. 如选方案C（最低成本）：仅修改 `bullet.gd` L367，移除 `AffixCombatHandler.calculate_damage()` 调用
  3. 如选方案A：将 affix_slot_ids 映射为 module_slots 别名，更新文档

#### 任务 P0-2：星级系统清理
- **工作量**：4h
- **文件清单**：
  1. `resources/card_resource.gd` — 删除 star_level @export（保留字段但去掉 @export）
  2. `managers/blueprint_manager.gd` — 移除 blueprint_stars 管理逻辑
  3. `managers/drop_manager.gd` — 移除 star_level 赋值
  4. `managers/aura_manager.gd` — 替换为 enhance_level
  5. `managers/card_ability_manager.gd` — 替换为 enhance_level
  6. `scenes/tools/card_ui_preview.gd` — 替换显示
  7. `scenes/ui/backpack_card_item.gd` — 替换显示
  8. `scenes/ui/backpack_panel.gd` — 替换显示
  9. `scenes/ui/manufacture_panel.gd` — 替换显示
  10. `managers/affix_manager.gd` — 移除词缀星级依赖
  11. `scripts/data_validator.gd` L62 — 移除 validate_star_level
  12. `scripts/ui_asset_loader.gd` L79-80 — 移除 star_icon()

#### 任务 P0-3：成就/任务奖励中的 blueprint_fragments 修复
- **工作量**：3h
- **文件清单**：
  1. `data/achievement_definitions.gd` — 7处 omega_platform 引用，将 blueprint_fragments 替换为 nano_materials
  2. `data/quest_definitions.gd` — 5处 omega_platform 引用，同上
  3. `managers/quest_manager.gd` L381-383 — blueprint_fragments 奖励发放逻辑替换
  4. `managers/tutorial_manager.gd` L98-99 — 同上
  5. `managers/achievement/achievement_rewards.gd` — 同上

### Phase P1：设计文档更新（预估 1天）

#### 任务 P1-1：修正文档标题编号
- 修正第七章标题"100"→"110"
- 删除"105"的错误中间标题

#### 任务 P1-2：空中线进化决策
- 确认是新增 F-22 还是更新文档接受 AH-64 路线

#### 任务 P1-3：补充堡垒进化路线（设计确认后）
- 在 `unit_lineage_config.gd` 新增堡垒 LINEAGES 条目

#### 任务 P1-4：纯辅助单位武器类型处理
- 修改 `_infer_weapon_type()` 增加全0攻击力的判断

### Phase P2：代码质量提升（预估 2-3天）

#### 任务 P2-1：清理 _agent_log 调试日志
- 46处 `_agent_log` 函数定义 + 调用，多数已改为空壳但仍占行数
- 建议：删除所有 `_agent_log` 定义和调用（除非有活跃使用者）

#### 任务 P2-2：清理 DEFAULT_MOD_OPTIONS 旧引用
- `scenes/ui/card_enhancement_panel.gd` L511-512 仍引用 `BlueprintManager.DEFAULT_MOD_OPTIONS`
- 替换为 `ModEffects.get_mod_info()`

#### 任务 P2-3：清理 print() 残留
- scenes/ 约30处，scripts/ 约20处
- 替换为项目统一的日志系统（如存在）或直接删除

#### 任务 P2-4：BlueprintManager 职责拆分（可选，中期）
- 当前 866 行，管理蓝图+星级+改造+进化+存档
- 建议拆分为 CardDataManager / CardEnhancementManager / CardEvolutionManager / ModManager

### Phase P3：长期优化（预估 1-2月）

#### 任务 P3-1：势力分支进化内容填充
- 当前 faction_branches 已有数据（非空字典），但部分分支指向的目标可能与设计意图不完全一致
- 需要设计确认每个势力分支的具体目标单位

#### 任务 P3-2：堡垒单位特殊行为实现
- 雷达站（attack全0）：光环提升周围友军精度+15%
- 护盾发生器（attack全0）：为周围友军提供HP护盾
- 通过已存在的 `aura_manager.gd` 实现

#### 任务 P3-3：数据驱动设计迁移
- 110个单位数据从 default_cards.gd 硬编码迁移到 data/json/units.json

#### 任务 P3-4：自动化一致性测试
- 扩展 `tests/unit/test_v5_data_consistency.gd`
- 新增：单位数量验证、LINEAGES目标存在性、fort类型验证、强化倍率验证

---

## 七、📊 优先级总结

```
紧急程度:  ████████████████████░░░░░░  P0（3项：词缀决策+星级清理+碎片奖励）
重要性:    ████████████████████░░░░░░  P1（4项：文档更新+堡垒进化+辅助单位处理）
代码质量:  ████████████████░░░░░░░░░░  P2（4项：日志清理+引用清理+print清理+拆分）
战略价值:  ████████████░░░░░░░░░░░░░░  P3（4项：势力内容+堡垒行为+数据驱动+自动化测试）
```

**如果只能做3件事**：
1. **P0-1**：词缀系统决策（影响战斗伤害计算正确性）
2. **P0-2**：星级系统清理（影响UI一致性+玩家体验）
3. **P0-3**：成就/任务碎片奖励修复（影响奖励发放正确性）

---

## 八、附录：问题发现明细

### A. 需要设计决策的问题

| # | 问题 | 选项 | 推荐方案 |
|---|------|------|---------|
| 1 | 词缀系统去留 | 删除/保留为模块化词条底层/禁用战斗效果 | 方案C：仅移除战斗调用 |
| 2 | 空中线F-22 vs AH-64 | 新增F-22/接受AH-64/改用AH-1 | 方案B：接受AH-64更新文档 |
| 3 | 堡垒是否可进化 | 可进化/终端节点 | 推荐可进化（2条线） |
| 4 | omega_platform 处理 | 删除/保留为兼容shim | 保留为兼容shim |

### B. 各系统遗留引用统计

| 系统 | 引用数 | 活跃影响 |
|------|--------|---------|
| affix/词缀 | 553 | 🔴 影响战斗伤害（bullet.gd） |
| star_level | 22 | 🔴 影响UI显示+制造/掉落 |
| blueprint_copies | 18 | 🟠 存档数据残留 |
| blueprint_fragments | 135 | 🟠 影响135处任务/成就奖励 |
| omega_platform | ~20 | 🟡 存档兼容+enemy_manifest |
| _agent_log | 46 | 🟢 调试残留，无功能影响 |
| DEFAULT_MOD_OPTIONS | 2 | 🟡 UI面板引用旧数据 |
| print() | ~50 | 🟢 调试残留 |

### C. 总工作量估算

| Phase | 工作量 | 前置条件 |
|-------|--------|---------|
| P0 | ~8h | 设计决策确认 |
| P1 | ~4h | P0-1完成后 |
| P2 | ~8h | P0完成后 |
| P3 | ~80h | P1完成后 |
| **合计** | **~100h** | |

---

> **报告生成时间**：2026-05-31
> **下审计日期建议**：P0 修复完成后（预计 2026-06-07）
