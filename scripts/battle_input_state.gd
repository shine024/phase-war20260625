extends Node
## 战斗输入状态管理（从 SignalBus 中剥离）
## 仅存储战斗中待执行的指令状态

# 主动法则施放
var pending_cast_law_id: String = ""
var pending_cast_law_origin_global: Vector2 = Vector2.ZERO

# 单位部署
var pending_deploy_platform_card_id: String = ""
var pending_deploy_origin_global: Vector2 = Vector2.ZERO

# 当前选中单位
var current_selected_unit: Node = null

func clear_all_pending() -> void:
	pending_cast_law_id = ""
	pending_cast_law_origin_global = Vector2.ZERO
	pending_deploy_platform_card_id = ""
	pending_deploy_origin_global = Vector2.ZERO
	current_selected_unit = null

func has_pending_cast() -> bool:
	return not pending_cast_law_id.is_empty()

func has_pending_deploy() -> bool:
	return not pending_deploy_platform_card_id.is_empty()
