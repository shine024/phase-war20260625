# 敌人属性叠乘顺序（EnemyStatResolver）

单一入口：[`data/enemy_stat_resolver.gd`](../../data/enemy_stat_resolver.gd) 的 `resolve_classic_enemy`。

## 经典敌人（有 archetype 配置）

- `hp = base_hp × wave_hp_mul × level_mul × player_pressure.hp_mul × master_def_mul`
- `attack_damage = base_atk × wave_dmg_mul × level_mul × player_pressure.attack_mul × master_atk_mul`
- `move_speed = abs(base_speed) × level_mul × player_pressure.speed_mul`

其中 `wave_hp_mul = 1 + 0.12×max(0, wave−1)`，`wave_dmg_mul = 1 + 0.08×max(0, wave−1)`，与迁移前 `enemy_unit.gd` 一致。

## 无配置回退（空 archetype）

线性波次成长 + 同上 `level_mul` / `pressure` / `master`（`master_stats` 通常为空则倍率为 1）。

## 相位师装备产兵（ConstructUnit）

`UnitStatsTable.build_multi_stats` 后由 `apply_phase_master_to_unit_stats` 叠相位师 `attack_power` / `defense`（公式与迁移前 `enemy_phase_field_driver.gd` 内联实现一致）。

## Knob

- **关卡曲线**：`EnemyStatResolver.level_stat_multiplier(level)` 当前恒为 1.0，后续只改此处。
- **我方压敌**：`collect_player_pressure()` 当前返回空；写入 `hp_mul` / `attack_mul` / `speed_mul` 后自动参与解析。
