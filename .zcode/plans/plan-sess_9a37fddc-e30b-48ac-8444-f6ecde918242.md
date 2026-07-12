# 敌方卡数据全面重新标定方案

## 问题诊断（已审计确认）

当前敌方卡数据有 **4 类严重问题**：

| # | 问题 | 示例 |
|---|------|------|
| **时代断崖** | 冷战(era2)比二战(era1)弱 | 二战虎王精英620血 → 冷战T-72精英500血（时代倒退） |
| **三套数据打架** | JSON/统一表/硬编码match三套值 | 同一虎王Boss：JSON=800血/统一表=1000血/不进表 |
| **weapon_type枚举冲突** | 新SUPPORT(3)被bullet.gd当旧ROCKET(3) | 10张支援/雷达卡发射火箭弹爆炸特效 |
| **A段平台卡缺失** | 28张卡靠硬编码fallback，量级差3-5倍 | 统一表T-72=800血 vs platform_cold_medium=200血 |

## 标定原则（标准曲线表）

建立 **时代×档次×兵种** 三维基准表，所有卡按基准值±兵种微调：

### HP基准表（敌方裸值，不含wave/level加成）

| 档次 | 一战 | 二战 | 冷战 | 现代 | 近未来 |
|------|------|------|------|------|--------|
| GRUNT杂兵 | 90-130 | 140-180 | 180-240 | 240-320 | 320-420 |
| VETERAN老练 | 150-220 | 220-320 | 320-450 | 450-650 | 650-900 |
| ELITE精英 | 250-380 | 380-550 | 550-800 | 800-1150 | 1150-1600 |
| CHAMPION头目 | 400-550 | 550-750 | 750-1000 | 1000-1350 | 1350-1800 |
| BOSS时代Boss | 600-800 | 900-1200 | 1200-1600 | 1600-2100 | 2100-2800 |
| ULTIMATE终极 | - | - | - | - | 2500-3500 |
| FORT堡垒 | 500-800 | 800-1200 | 1100-1600 | 1500-2200 | 2200-3000 |

### 攻击基准（主攻维度DPS = 伤害×攻速）

DPS基准：杂兵 40-80 / 老练 80-160 / 精英 160-320 / 头目 300-500 / Boss 400-800 / 终极 700-1200。三维攻击按combat_kind比例分配（步兵0.6/1.0/0.2，装甲0.6/1.0/0.3，支援0.4/1.2/0.4等）。

### 防御基准（三维）

按兵种定位：步兵(8/4/3)、装甲(20/30/8)、支援(15/12/6)、空军(8/6/15)、堡垒(60/80/40)，随时代×0.1递增。

### 射程/攻速/移速基准

- 射程：直射1-3格/曲射4-5格/防空5-6格/全图99格（不变大改，微调）
- 攻速：步兵1.0-1.8次/秒、装甲0.33-0.83次/秒、炮兵0.5-2.0次/秒、近防3-8次/秒
- 移速：步兵80-100、装甲50-80、空中120-160、固定0

## 实施方案（6个阶段）

### 阶段1：修复 weapon_type 枚举冲突（基础设施）

**问题**：新枚举SUPPORT(3)和旧legacy ROCKET(3)在bullet.gd共用match分支，10张支援卡发射火箭弹。

**方案**：bullet.gd把新枚举值（0/1/2）和legacy值（3-11）分到不同的match分支区域，新增SUPPORT(3)专属分支（不开火/纯光环视觉）：
- `scenes/units/bullet.gd` — `_configure_behavior` match 分支重组：0/4→直射、1→曲射、2→空射、3→SUPPORT(不开火/禁用) 、5-11→legacy弹道保留
- `resources/game_constants.gd` — `is_indirect_weapon_type` 移除 legacy 值3/7/9 的新枚举误判（改为 `wt==1 or wt==2` 或加legacy前缀判断）
- 确认我方卡（default_cards._infer_weapon_type）和敌方卡（统一表weapon_type）都用新4值，legacy只走stats.legacy_weapon_type

### 阶段2：扩展敌方三维攻速支持（基础设施）

**问题**：敌方只有单一attack_interval，无法表达"防空特化(低对地伤害+高对空攻速)"。

**方案**（最小改动集）：
- `data/enemy_stat_resolver.gd` `resolve_classic_enemy` (L131-294) — 输出字典新增 `attack_light_interval/attack_armor_interval/attack_air_interval`，从cfg三维攻速字段读取，fallback到单一attack_interval
- `scenes/units/enemy_unit.gd` `_build_enemy_unit_stats` (L413-417) — 改为分别读取三维interval → 三维speed，替换统一赋值
- `data/unified_card_table.gd` `build_enemy_archetype_config` (L1760-1778) — 输出新增三维interval字段（从atk_l_speed/atk_a_speed/atk_air_speed派生）

### 阶段3：重写统一表全部敌方卡数值（核心）

按标准曲线表，逐条重写 `data/unified_card_table.gd` 中约 **120条** 记录（含玩家卡+敌方卡）：
- 修复时代断崖：确保 era0 < era1 < era2 < era3 < era4 严格递增（同档次横向比较）
- 修复同档卡量级统一：GRUNT/VETERAN/ELITE/CHAMPION/BOSS 各档内HP差异≤30%
- 三维攻防按兵种定位重算（步兵重轻装、装甲重装甲防御、堡垒全维高）
- 武器名与weapon_type/combat_kind对齐（修正武器名错误如MG08标"81mm火炮"→"重机枪"）
- 约120条逐条过，每条确认 HP/三维攻击/三维防御/射程/攻速/weapon_type/weapon_label 全部对齐曲线

### 阶段4：补齐28张A段平台卡进统一表

将 `enemy_unit_manifest.gd` 的28张platform_*平台卡补入统一表（新增条目），然后删除/废弃硬编码match fallback：
- 新增约28条 `platform_*` 记录到 `unified_card_table.gd`
- `enemy_unit_manifest.gd` `_get_foe_stats` 的 match fallback 删除（或改为push_warning + 回退统一表默认值）
- `_FOE_ID_TO_PLATFORM` 映射保留但改走统一表查询

### 阶段5：重构覆盖逻辑（统一表为唯一源）

- `data/enemy_archetypes.gd` `_ensure_manifest_merged` (L338-394) — 简化：数值字段全部从统一表覆盖（白名单扩展到全字段），JSON只保留 drops/tags/display_name/anim/visual_scale
- `data/json/enemy_archetypes.json` — 移除数值字段（hp/attack_damage/attack_range/attack_interval/weapon_type/defense），保留 drops/tags/display_name 等。或标记为deprecated不再加载
- `enemy_unit_manifest.gd` `_get_foe_stats` — 删除所有硬编码match分支，全部走统一表

### 阶段6：验证

- Godot `--check-only` 通过
- 写一个 smoke test 验证：
  - 时代递进断言（每个档次 era0<era1<era2<era3<era4）
  - weapon_type 值域检查（所有统一表条目 weapon_type∈[0,3]）
  - 统一表条目数 ≈ 现有+28平台卡
  - 三维攻防不为负
- Grep 核对覆盖逻辑链路拼写一致

## 改动文件清单

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `data/unified_card_table.gd` | **重写数值** | ~120条卡数值全量重标定 + 28条平台卡新增 |
| `scenes/units/bullet.gd` | 修复 | weapon_type match分支重组，SUPPORT(3)隔离 |
| `resources/game_constants.gd` | 修复 | is_indirect_weapon_type 去legacy误判 |
| `data/enemy_stat_resolver.gd` | 扩展 | resolve_classic_enemy 输出三维攻速 |
| `scenes/units/enemy_unit.gd` | 扩展 | _build_enemy_unit_stats 读取三维攻速 |
| `data/enemy_archetypes.gd` | 重构 | _ensure_manifest_merged 覆盖逻辑简化 |
| `data/json/enemy_archetypes.json` | 清理 | 移除数值字段 |
| `data/enemy_unit_manifest.gd` | 重构 | 删除硬编码match，走统一表 |

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 120条数值重写工作量大、易错 | 按标准曲线表批量计算，每条过公式核对；先做结构改动（阶段1/2），再做数值（阶段3） |
| 玩家卡数值也变（统一表含玩家卡） | 玩家卡power用于强化消耗/进化门槛，重标定后需检查 reinforcement_panel 和 unit_lineage_config 的阈值是否需调整 |
| 战斗节奏可能变化 | 基准表以现有满强化量级为锚（玩家Lv10近未来终极~3000-5000血），确保Boss≤玩家上限 |
| 三维攻速扩展影响敌方产兵 | 相位师产兵(enemy_phase_field_driver)走build_stats_from_card，不经过resolve_classic_enemy，不受阶段2影响 |

## 不做的事（范围外）

- 不改相位师数据（enemy_phase_masters，30条，独立体系）
- 不改波次/关卡/master/faction 加成公式（resolve_classic_enemy乘区链不动）
- 不改改造模块数值（modification_modules）
- 不改进化路径数值（evolution_paths）
- 玩家卡power的强化消耗/进化门槛调整留待实机观察后微调（仅记录到AGENTS.md）
