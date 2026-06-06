## 通用保存/加载工具：为管理器提供简单的数据保存功能

## 保存数据到文件
static func save_data_to_file(data: Dictionary, file_name: String) -> void:
	var save_dir = OS.get_user_data_dir()
	if save_dir.is_empty():
		# [LOG-v5.1] print("[SaveUtils] 无法获取用户数据目录")
		return

	var save_path = save_dir + "/" + file_name + ".json"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		# [LOG-v5.1] print("[SaveUtils] 无法打开文件进行写入: ", save_path)
		return

	var json_string = JSON.stringify(data)
	file.store_line(json_string)
	file.close()
	# [LOG-v5.1] print("[SaveUtils] 数据已保存到: ", save_path)

## 从文件加载数据
static func load_data_from_file(file_name: String) -> Dictionary:
	var save_dir = OS.get_user_data_dir()
	if save_dir.is_empty():
		# [LOG-v5.1] print("[SaveUtils] 无法获取用户数据目录")
		return {}

	var save_path = save_dir + "/" + file_name + ".json"
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		# [LOG-v5.1] print("[SaveUtils] 无法打开文件进行读取: ", save_path)
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[SaveUtils] JSON解析错误: ", error)
		return {}

	var data = json.data
	if data is Dictionary:
		return data
	else:
		# [LOG-v5.1] print("[SaveUtils] 数据格式错误")
		return {}
