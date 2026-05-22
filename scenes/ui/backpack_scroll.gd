extends ScrollContainer

## 与背包卡行高（PhaseSlot.SLOT_SIZE.y）一致，滚轮步进对齐格子
const _SCROLL_STEP_Y: int = int(PhaseSlot.SLOT_SIZE.y)

func _ready() -> void:
	set_process_unhandled_input(true)

func _exit_tree() -> void:
	set_process_unhandled_input(false)

func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton

	if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	if not get_global_rect().has_point(mb.position):
		return
	var step := _SCROLL_STEP_Y
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_vertical = scroll_vertical - step
	else:
		scroll_vertical = scroll_vertical + step
