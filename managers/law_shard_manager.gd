## @deprecated — ADR-001: 法则碎片已移除，此管理器仅保留用于旧存档迁移
extends RefCounted
class_name LawShardManager

## 碎片计数（遗留字段，仅存档兼容）
var law_shard_count: int = 0


## [legacy] 返回空字典，保持旧存档格式兼容
func get_save_data() -> Dictionary:
	return {}


## [legacy] 静默吞掉旧存档数据，不做任何业务处理
func load_save_data(_data: Dictionary) -> void:
	pass
