extends PanelContainer
## 战场单位情报面板：监听 unit_selected 信号，委托给统一的 CardInfoPanel 显示
## 本脚本保留在 main.tscn 中，接收战场信号后创建/复用全局 CardInfoPanel 单例

const CardInfoPanel = preload("res://scenes/ui/card_info_panel.gd")
const NodeFinder = preload("res://scripts/node_finder.gd")

func _ready() -> void:
	visible = false  # 本面板自身不再显示内容，仅作为容器
	if SignalBus:
		SignalBus.unit_selected.connect(_on_unit_selected)

func _on_unit_selected(unit: Node, is_player: bool, at_position: Vector2 = Vector2.ZERO) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if SignalBus:
		BattleInputState.current_selected_unit = unit
	# 先隐藏全局 CardInfoPanel 单例（防止悬停残留）
	_dismiss_global_card_info_panel()
	# 获取全局 CardInfoPanel（挂在 InfoPanelLayer layer=90，不被 HUD 遮挡）
	var info_panel: Control = NodeFinder.get_card_info_panel()
	if info_panel == null:
		return
	# 计算显示位置（在单位附近）
	var panel_pos: Vector2 = at_position
	if at_position == Vector2.ZERO and is_instance_valid(unit):
		var unit_pos: Vector2 = unit.global_position if unit is Node2D else Vector2.ZERO
		panel_pos = unit_pos + Vector2(60, -80)
	# 使用统一面板显示战场单位信息
	if info_panel.has_method("set_panel_mode"):
		info_panel.set_panel_mode(CardInfoPanel.PanelMode.MODE_BATTLEFIELD)
	if info_panel.has_method("show_unit_info"):
		info_panel.show_unit_info(unit, is_player, panel_pos)

func _dismiss_global_card_info_panel() -> void:
	var info_panel: Control = NodeFinder.get_card_info_panel()
	if info_panel != null and info_panel.has_method("hide_panel"):
		info_panel.hide_panel()
