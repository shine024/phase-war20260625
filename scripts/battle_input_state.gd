extends Node
## 战斗输入状态管理（从 SignalBus 中剥离）
## 仅存储战斗中待执行的指令状态
## v9.x（P2-7范围B）：主动法则施放状态已随法则系统退役移除

# 单位部署
var pending_deploy_platform_card_id: String = ""
var pending_deploy_origin_global: Vector2 = Vector2.ZERO

# 当前选中单位
var current_selected_unit: Node = null

func clear_all_pending() -> void:
	pending_deploy_platform_card_id = ""
	pending_deploy_origin_global = Vector2.ZERO
	current_selected_unit = null

func has_pending_deploy() -> bool:
	return not pending_deploy_platform_card_id.is_empty()
