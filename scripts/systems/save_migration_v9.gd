class_name SaveMigrationV9
extends RefCounted
## v8 → v9 存档迁移：改造解锁集 + 产能点（v21 P3-B，计划 C1/A4）
##
## v25.3（2026-08-31 系统收敛）：本迁移引入的两个字段已随账号解锁集/产能点整链退役——
## ModificationRegistry 不再持有 load_state（存档段已摘）、BasicResourceManager 不再读写
## production_points。迁移体改为 no-op（保留版本链 v8→v9 与文件本身，避免版本号回退/
## 迁移链断档）；旧档残留的 mod_unlock_state / production_points key 在下一次存档时
## 自然落盘丢弃（读写两侧均已无消费方，字段级静默跳过惯例）。

## v8 → v9 迁移（v25.3 起 no-op）
static func migrate_v8_to_v9(data: Dictionary, debug_log: bool = false) -> void:
	# 退役字段不再补默认值；data 仅经手不改。
	if debug_log:
		push_warning("[SaveMigrationV9] v8→v9: no-op（解锁集/产能点已 v25.3 退役）")
