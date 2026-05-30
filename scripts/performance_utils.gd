## 性能优化工具：提供批量处理、缓存、异步操作等性能优化工具

## 批量操作工具类
extends Node

## 批量处理数组（减少频繁的函数调用）
static func batch_process(items: Array, processor: Callable, batch_size: int = 100) -> void:
	for i in range(0, items.size(), batch_size):
		var end_index = mini(i + batch_size, items.size())
		for j in range(i, end_index):
			processor.call(items[j])

## 批量保存数据（减少文件IO）
static func batch_save(data_chunks: Array, file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[PerformanceUtils] Failed to open file for batch save: %s" % file_path)
		return

	for chunk in data_chunks:
		var json_string = JSON.stringify(chunk)
		file.store_line(json_string)

	file.close()

## 内存缓存系统
var _cache: Dictionary = {}
var _cache_max_size: int = 100
var _cache_ttl: float = 300.0  # 缓存有效期（秒）

## 缓存条目
class CacheEntry:
	var data
	var timestamp: float
	var hits: int = 0

	func _init(_data):
		data = _data
		timestamp = Time.get_unix_time_from_system()

	func is_expired(ttl: float) -> bool:
		return (Time.get_unix_time_from_system() - timestamp) > ttl

	func increment_hits():
		hits += 1

## 获取缓存数据
func get_from_cache(key: String, default_value = null):
	if not _cache.has(key):
		return default_value

	var entry: CacheEntry = _cache[key]
	if entry.is_expired(_cache_ttl):
		_cache.erase(key)
		return default_value

	entry.increment_hits()
	return entry.data

## 存入缓存
func put_in_cache(key: String, data) -> void:
	# 如果缓存满了，移除最少使用的条目
	if _cache.size() >= _cache_max_size:
		_evict_least_used_entry()

	var entry = CacheEntry.new(data)
	_cache[key] = entry

## 移除最少使用的缓存条目
func _evict_least_used_entry() -> void:
	var least_used_key = ""
	var least_used_hits = 999999

	for key in _cache:
		var entry: CacheEntry = _cache[key]
		if entry.hits < least_used_hits:
			least_used_hits = entry.hits
			least_used_key = key

	if not least_used_key.is_empty():
		_cache.erase(least_used_key)

## 清除所有缓存
func clear_cache() -> void:
	_cache.clear()

## 获取缓存统计
func get_cache_stats() -> Dictionary:
	var total_hits = 0
	for key in _cache:
		var entry: CacheEntry = _cache[key]
		total_hits += entry.hits

	return {
		"size": _cache.size(),
		"max_size": _cache_max_size,
		"total_hits": total_hits,
		"ttl": _cache_ttl
	}

## 设置缓存配置
func set_cache_config(max_size: int, ttl: float) -> void:
	_cache_max_size = max_size
	_cache_ttl = ttl
	# 如果新大小小于当前大小，清除部分缓存
	if _cache.size() > _cache_max_size:
		while _cache.size() > _cache_max_size:
			_evict_least_used_entry()

## 对象池系统（重用对象，减少内存分配）
var _object_pools: Dictionary = {}

## 获取对象池中的对象
func get_pooled_object(scene: PackedScene) -> Node:
	if scene == null:
		return null

	var scene_path = scene.resource_path
	if not _object_pools.has(scene_path):
		_object_pools[scene_path] = []

	var pool = _object_pools[scene_path]

	if pool.size() > 0:
		var obj = pool.pop_back()
		if is_instance_valid(obj):
			return obj

	# 如果池中没有可用对象，创建新的
	return scene.instantiate()

## 归还对象到池中
func return_pooled_object(scene: PackedScene, obj: Node) -> void:
	if scene == null or obj == null:
		return

	if not is_instance_valid(obj):
		return

	var scene_path = scene.resource_path
	if not _object_pools.has(scene_path):
		_object_pools[scene_path] = []

	var pool = _object_pools[scene_path]

	# 限制池的大小，避免无限增长
	var max_pool_size = 50
	if pool.size() < max_pool_size:
		# 从场景树中移除但不销毁
		var parent = obj.get_parent()
		if parent != null:
			parent.remove_child(obj)

		pool.append(obj)
	else:
		# 池满了，直接销毁
		obj.queue_free()

## 清空对象池
func clear_object_pools() -> void:
	for scene_path in _object_pools:
		var pool = _object_pools[scene_path]
		for obj in pool:
			if is_instance_valid(obj):
				obj.queue_free()

	_object_pools.clear()

## 获取对象池统计
func get_pool_stats() -> Dictionary:
	var stats = {}
	for scene_path in _object_pools:
		var pool = _object_pools[scene_path]
		stats[scene_path] = pool.size()
	return stats

## 异步加载资源（避免阻塞主线程）
func load_resource_async(path: String, callback: Callable) -> void:
	var loader = ResourceLoader.load_interactive(path)
	if loader == null:
		push_error("[PerformanceUtils] Failed to load resource: %s" % path)
		callback.call(null)
		return

	# 创建一个定时器来监控加载进度
	var timer = Timer.new()
	timer.wait_time = 0.1  # 每100ms检查一次
	timer.autostart = true
	timer.timeout.connect(func():
		var error = loader.poll()
		if error == OK:
			# 加载完成
			timer.queue_free()
			var resource = loader.get_resource()
			callback.call(resource)
		elif error == ERR_FILE_EOF:
			# 加载完成
			timer.queue_free()
			var resource = loader.get_resource()
			callback.call(resource)
		elif error > OK:
			# 加载出错
			timer.queue_free()
			push_error("[PerformanceUtils] Error loading resource: %s" % path)
			callback.call(null)
	)

	# 将定时器添加到场景树
	get_tree().root.add_child(timer)

## 性能监控
var _performance_markers: Dictionary = {}

## 开始性能标记
func start_performance_marker(name: String) -> void:
	_performance_markers[name] = Time.get_ticks_usec()

## 结束性能标记并返回耗时（毫秒）
func end_performance_marker(name: String) -> float:
	if not _performance_markers.has(name):
		push_warning("[PerformanceUtils] Performance marker not found: %s" % name)
		return 0.0

	var start_time = _performance_markers[name]
	var end_time = Time.get_ticks_usec()
	var elapsed_ms = float(end_time - start_time) / 1000.0

	_performance_markers.erase(name)

	return elapsed_ms

## 测量函数执行时间
func measure_execution_time(name: String, func_ref: Callable) -> void:
	start_performance_marker(name)
	func_ref.call()
	var elapsed = end_performance_marker(name)
	if OS.is_debug_build(): print("[PerformanceUtils] %s executed in %.2f ms" % [name, elapsed])

## 优化的数组查找（使用字典索引）
static func create_array_index(items: Array, key_field: String) -> Dictionary:
	var index = {}
	for item in items:
		if item is Dictionary and key_field in item:
			var key = item[key_field]
			index[key] = item
		elif item.has_method(key_field):
			var key = item.call(key_field)
			index[key] = item
	return index

## 使用索引快速查找
static func fast_lookup(index: Dictionary, key) -> Variant:
	return index.get(key, null)

## 减少字符串拼接（使用数组join）
static func efficient_string_join(parts: Array, separator: String = "") -> String:
	return separator.join(PackedStringArray(parts))

## 延迟执行（避免在同一帧执行过多操作）
static func deferred_call(callback: Callable, delay_frames: int = 1) -> void:
	if delay_frames <= 0:
		callback.call()
		return

	var tree = Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.process_frame.connect(func():
			callback.call()
		, CONNECT_ONE_SHOT)

## 批量节点操作（减少场景树遍历）
static func batch_add_children(parent: Node, children: Array) -> void:
	for child in children:
		if child is Node and is_instance_valid(child):
			parent.add_child(child)

## 批量移除子节点
static func batch_remove_children(parent: Node, children: Array) -> void:
	for child in children:
		if child is Node and is_instance_valid(child):
			if child.get_parent() == parent:
				parent.remove_child(child)

## 优化的字典查找（带默认值）
static func safe_dict_lookup(dict: Dictionary, key, default_value = null):
	return dict.get(key, default_value)

## 批量设置属性（减少函数调用）
static func batch_set_properties(obj: Object, properties: Dictionary) -> void:
	for prop in properties:
		if prop in obj:
			obj.set(prop, properties[prop])

## 内存使用统计
func get_memory_usage() -> Dictionary:
	var static_mem = OS.get_static_memory_usage_by_type()
	var peak_mem = OS.get_static_memory_peak_usage()

	return {
		"static_memory": static_mem,
		"peak_memory": peak_mem,
		"formatted_static": _format_bytes(static_mem),
		"formatted_peak": _format_bytes(peak_mem)
	}

## 格式化字节数
func _format_bytes(bytes: int) -> String:
	var units = ["B", "KB", "MB", "GB"]
	var size = float(bytes)
	var unit_index = 0

	while size >= 1024.0 and unit_index < units.size() - 1:
		size /= 1024.0
		unit_index += 1

	return "%.2f %s" % [size, units[unit_index]]
