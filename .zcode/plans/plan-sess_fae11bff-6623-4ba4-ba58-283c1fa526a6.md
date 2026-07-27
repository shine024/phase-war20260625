## 重构计划：新兵种改为纯标签层，不侵入三维攻防系统

### 设计原则（用户确认）
1. **回到原点**——不加新 CombatKind 枚举值，三维攻防系统（LIGHT/ARMOR/AIR + weapon_slots）保持封闭
2. **完全重写**——清理已写入的 CombatKind.ENGINEER/SNIPER + 5×5 矩阵
3. **新兵种走纯标签层**——独特性靠 tags + meta + TAG_COUNTER_RULES + 兵种机制实现
4. **修复 card.tags 流动 bug**——让 build_stats_from_card 把 card.tags 复制到 stats meta
5. **保留 TAG_COUNTER_RULES**——8 条标签硬克制作为独立伤害加成层（bullet.gd 调用）

### Step 1: 回退三维侵入部分（game_constants.gd）
- 删除 `CombatKind.ENGINEER = 5` 和 `CombatKind.SNIPER = 6`（恢复为 5 值枚举）
- 删除 `COMBAT_KIND_ATTACK_MATRIX` 和 `COMBAT_KIND_DEFENSE_MATRIX` 两个 5×5 矩阵
- 删除 `get_attack_matrix_multiplier` 和 `get_defense_matrix_multiplier` 两个查询函数
- **保留** `TAG_COUNTER_RULES`（8 条标签硬克制，这是正确的标签层）

### Step 2: 回退 attack_calculator.gd 的三维侵入
- `get_attack_vs`：删除 ENGINEER/SNIPER 的 match 分支 + matrix_mult 调用（恢复原版 return 语句）
- `get_defense_vs`：删除 ENGINEER/SNIPER 的 match 分支（恢复原版）
- `get_attack_timing`：删除 ENGINEER/SNIPER（恢复原版 LIGHT/SUPPORT 分支）
- `get_weapon_for_target`：删除 ENGINEER/SNIPER（恢复原版）
- **保留** `compute_tag_counter_multiplier`（这是标签层，正确）

### Step 3: 修复 card.tags 流动 bug（unit_stats_table.gd）
- `build_stats_from_card` 开头加一行：`stats.set_meta("card_tags", card.tags.duplicate())`
- 让 `_apply_v8_unit_type_meta` 能正确读到卡牌 tags（当前只能靠 card_id 前缀兜底）

### Step 4: 更新 smoke test（v8_skills_smoke.gd）
- 删除 Test 2/3（5维矩阵测试）、Test 21（5×5 矩阵完整覆盖）
- 保留 Test 1（改为验证 CombatKind 恢复为 5 值）、Test 4-20（标签层测试）、Test 22（card_skill/tactic 解锁）
- 新增 Test：验证 card.tags 流动到 stats meta

### Step 5: 更新设计文档（COMBAT_SYSTEM_V8_GRID_COMPATIBLE.md）
- 修正"5维克制系统"章节为"标签层兵种机制"
- 说明三维攻防系统保持封闭，新兵种不扩展 CombatKind

### 保留不动的部分（这些是正确的标签层实现）
- `TAG_COUNTER_RULES`（8 条标签硬克制）+ `compute_tag_counter_multiplier`
- `_apply_v8_unit_type_meta`（按 tags/card_id 打 is_stalker/is_sniper 等 meta）
- construct_unit.gd 的兵种机制（STALKER 隐身/SNIPER 首击/ECM 光环/卡片技能 stat_bonus）
- construct_unit_ai.gd 的首击检测
- bullet.gd 的 SNIPER 必爆 + 标签克制调用
- enemy_unit.gd 的 ECM 减益读取
- 卡片定时技能引擎 + 战法系统 + 技能树扩展（这些完全不依赖 CombatKind）

### 文件清单
| 操作 | 文件 | 改动 |
|------|------|------|
| 改 | resources/game_constants.gd | 删 CombatKind.ENGINEER/SNIPER + 2矩阵 + 2查询函数 |
| 改 | scripts/battle/attack_calculator.gd | 删 4 处 ENGINEER/SNIPER match + matrix_mult |
| 改 | resources/unit_stats_table.gd | build_stats_from_card 加 card.tags 复制 |
| 改 | tests/v8_skills_smoke.gd | 删矩阵测试，加 tags 流动测试 |
| 改 | docs/design/COMBAT_SYSTEM_V8_GRID_COMPATIBLE.md | 修正架构说明 |

### 验证
- Godot --check-only exit 0
- v8_skills_smoke.gd 全 PASS（预计 18-20 项）
- star_config_smoke.gd OK（无回归）

### 预期效果
- 三维攻防系统恢复封闭（LIGHT/ARMOR/AIR + weapon_slots 不变）
- 新兵种（STALKER/ENGINEER/ECM/SNIPER）完全靠标签层实现独特性
- 现有 133 张卡的行为零变化（向后兼容）
- 标签硬克制（sniper 打 boss +50% 等）继续生效