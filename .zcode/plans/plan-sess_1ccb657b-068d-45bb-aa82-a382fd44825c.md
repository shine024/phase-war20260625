## Boss 唯一性限制方案

### 根因
所有 boss 单位（tags 含 "boss"）在战场上可无限同名刷新。第49关相位师产兵 `cold_boss_mig` 一次战场刷出2-3个是同平台重复产出导致。

### 实现内容

**1. 新增 `_count_alive_enemy_by_archetype(archetype_id)` — battle_spawn_system.gd 末尾**

遍历 `_enemy_units_node` 子树，兼容两种敌方单位类型：
- EnemyUnit: 读裸字段 `unit.archetype_id`
- ConstructUnit: 读 meta「archetype_id」或 stats.platform_card_id

跳过死亡中 (`_is_dying`) 和部署虚影 (`is_deploy_ghost`) 的单位。返回存活计数。

**2. enemy_phase_field_driver.gd — 产兵前检查同名 boss**

在 L599（ConstructUnit 实例化前）插入：
```gdscript
var is_boss := cfg.get("tags", []).has("boss")
if is_boss and _count_alive_enemy_by_archetype(platform_id) >= 1:
    return  # 跳过本次产兵
```
- 仅对有 boss tag 的单位生效
- 已在场则直接返回，不产兵；`_produce_unit()` 的 while 循环会自动重试下一个平台
- 不影响非 boss 单位和普通单位的产兵逻辑

**3. battle_spawn_system.gd — 普通波次 boss 检查**

在 L317（`_create_enemy_unit_with_id(archetype_id)` 之前）插入：
```gdscript
var tags: Array = EnemyArchetypes.get_config(archetype_id).get("tags", [])
if type_pick == "boss" and tags.has("boss") and _count_alive_enemy_by_archetype(archetype_id) >= 1:
    continue  # 跳过本个 boss 产兵
```
- 仅在抽到 boss 时检查
- 已在场则 continue，少刷一个单位（不降级为普通/精英）

### 设计决策
1. **只限 boss**（用户确认）：非 boss/精英单位不受影响
2. **跳过产兵**（用户确认）：不是降级为普通单位，而是本场少刷一个——保持战斗节奏
3. **按 archetype_id 精确匹配**：同名 boss 只限 1 个，不同 boss 互不冲突

### 涉及文件
- `managers/battle/battle_spawn_system.gd` — 新增工具函数 + 普通波次修改
- `scenes/units/enemy_phase_field_driver.gd` — 产兵前 boss 存在检查
