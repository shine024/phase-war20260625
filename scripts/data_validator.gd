## 数据验证工具：提供统一的数据验证和错误处理

## 验证字符串不为空
static func validate_string(value: String, field_name: String = "Value") -> bool:
	if value.is_empty():
		push_error("[DataValidator] %s cannot be empty" % field_name)
		return false
	return true

## 验证数值范围
static func validate_range(value: float, min_val: float, max_val: float, field_name: String = "Value") -> bool:
	if value < min_val or value > max_val:
		push_error("[DataValidator] %s (%.2f) out of range [%.2f, %.2f]" % [field_name, value, min_val, max_val])
		return false
	return true

## 验证整数范围
static func validate_int_range(value: int, min_val: int, max_val: int, field_name: String = "Value") -> bool:
	if value < min_val or value > max_val:
		push_error("[DataValidator] %s (%d) out of range [%d, %d]" % [field_name, value, min_val, max_val])
		return false
	return true

## 验证数组不为空
static func validate_array(value: Array, field_name: String = "Array") -> bool:
	if value.is_empty():
		push_error("[DataValidator] %s cannot be empty" % field_name)
		return false
	return true

## 验证字典包含必需键
static func validate_dict_keys(dict: Dictionary, required_keys: Array, dict_name: String = "Dictionary") -> bool:
	for key in required_keys:
		if not key in dict:
			push_error("[DataValidator] %s missing required key: %s" % [dict_name, key])
			return false
	return true

## 验证节点有效性
static func validate_node(node: Node, node_name: String = "Node") -> bool:
	if node == null:
		push_error("[DataValidator] %s is null" % node_name)
		return false
	if not is_instance_valid(node):
		push_error("[DataValidator] %s is invalid (freed)" % node_name)
		return false
	return true

## 验证卡牌ID格式
static func validate_card_id(card_id: String) -> bool:
	if not validate_string(card_id, "Card ID"):
		return false

	# 检查卡牌ID格式（假设格式为 type_name 或 type_variant_name）
	if "_" in card_id:
		return true

	push_warning("[DataValidator] Card ID format unusual: %s" % card_id)
	return true  # 警告但不阻止

## 验证能量值
static func validate_energy_value(energy: float) -> bool:
	return validate_range(energy, 0.0, 1000.0, "Energy")

## 验证百分比（0-1）
static func validate_percentage(value: float, field_name: String = "Percentage") -> bool:
	return validate_range(value, 0.0, 1.0, field_name)

## 验证概率（0-1）
static func validate_probability(value: float, field_name: String = "Probability") -> bool:
	return validate_range(value, 0.0, 1.0, field_name)

## 验证卡牌数据字典
static func validate_card_data(card_data: Dictionary) -> bool:
	var required_keys = ["id", "name", "type"]
	if not validate_dict_keys(card_data, required_keys, "Card Data"):
		return false

	if not validate_string(card_data.get("id", ""), "Card ID"):
		return false
	if not validate_string(card_data.get("name", ""), "Card Name"):
		return false

	return true

## 验证相位仪数据字典
static func validate_instrument_data(instrument_data: Dictionary) -> bool:
	# v7.x: 移除 energy_output_rate 必填校验（属性已删除）
	var required_keys = ["id", "name", "star", "slot_counts"]
	if not validate_dict_keys(instrument_data, required_keys, "Instrument Data"):
		return false

	if not validate_string(instrument_data.get("id", ""), "Instrument ID"):
		return false
	if not validate_int_range(instrument_data.get("star", 1), 1, 7, "Instrument Star"):
		return false

	# 验证槽位数量
	var slot_counts = instrument_data.get("slot_counts", {})
	var slot_colors = ["green", "red", "blue", "yellow"]
	for color in slot_colors:
		var count = slot_counts.get(color, 0)
		if count < 0 or count > 5:
			push_error("[DataValidator] Invalid slot count for %s: %d" % [color, count])
			return false

	return true

## 验证时代和关卡
static func validate_era_and_level(era: int, level: int) -> bool:
	var era_valid = validate_int_range(era, 1, 100, "Era")
	var level_valid = validate_int_range(level, 1, 100, "Level")
	return era_valid and level_valid

## 批量验证数据数组
static func validate_data_array(data_array: Array, validator: Callable) -> int:
	var error_count = 0
	for i in range(data_array.size()):
		var data = data_array[i]
		if not validator.call(data):
			push_error("[DataValidator] Data at index %d failed validation" % i)
			error_count += 1
	return error_count

## 验证文件路径
static func validate_file_path(path: String, must_exist: bool = false) -> bool:
	if not validate_string(path, "File Path"):
		return false

	if must_exist:
		if not FileAccess.file_exists(path):
			push_error("[DataValidator] File does not exist: %s" % path)
			return false

	return true

## 验证资源类型
static func validate_resource_type(resource: Resource, expected_type: String) -> bool:
	if resource == null:
		push_error("[DataValidator] Resource is null")
		return false

	if not resource.is_class(expected_type):
		push_error("[DataValidator] Resource type mismatch: expected %s, got %s" % [expected_type, resource.get_class()])
		return false

	return true

## 验证Vector2不为零（某些场景下需要）
static func validate_vector2_non_zero(vector: Vector2, field_name: String = "Vector2") -> bool:
	if vector == Vector2.ZERO:
		push_error("[DataValidator] %s cannot be ZERO" % field_name)
		return false
	return true

## 验证颜色值（RGBA各分量在0-1范围）
static func validate_color(color: Color, field_name: String = "Color") -> bool:
	if not validate_percentage(color.r, field_name + ".r"):
		return false
	if not validate_percentage(color.g, field_name + ".g"):
		return false
	if not validate_percentage(color.b, field_name + ".b"):
		return false
	if not validate_percentage(color.a, field_name + ".a"):
		return false
	return true

## 清理和验证字符串输入（防止注入攻击）
static func sanitize_string_input(input: String) -> String:
	# 移除可能的危险字符
	var sanitized = input.strip_edges()
	sanitized = sanitized.replace("\n", "")
	sanitized = sanitized.replace("\r", "")
	sanitized = sanitized.replace("\t", "")
	return sanitized
