extends Node
## UI性能优化工具：减少不必要的UI更新，提升界面响应速度

## UI更新节流器
class UIThrottler:
	var last_update_time: Dictionary = {}
	var update_intervals: Dictionary = {}
	var pending_updates: Dictionary = {}

	func _init():
		pass

	## 设置更新间隔（秒）
	func set_update_interval(key: String, interval: float) -> void:
		update_intervals[key] = interval

	## 检查是否应该更新
	func should_update(key: String) -> bool:
		var current_time = Time.get_ticks_msec() / 1000.0

		# 如果没有设置间隔，总是更新
		if not update_intervals.has(key):
			return true

		var interval = update_intervals[key]
		var last_time = last_update_time.get(key, 0.0)

		if current_time - last_time >= interval:
			last_update_time[key] = current_time
			return true

		return false

	## 标记待处理更新
	func mark_pending(key: String) -> void:
		pending_updates[key] = true

	## 清除待处理更新
	func clear_pending(key: String) -> void:
		pending_updates.erase(key)

	## 是否有待处理更新
	func is_pending(key: String) -> bool:
		return pending_updates.has(key)

	## 处理所有待处理更新
	func process_pending(callback: Callable) -> void:
		for key in pending_updates.keys():
			callback.call(key)
		pending_updates.clear()

## UI变化追踪器
class UIChangeTracker:
	var tracked_values: Dictionary = {}
	var change_callbacks: Dictionary = {}

	## 追踪数值变化
	func track(key: String, value: Variant) -> bool:
		var old_value = tracked_values.get(key)
		tracked_values[key] = value

		# 检查是否真正变化
		if old_value != null and old_value == value:
			return false

		# 触发变化回调
		if change_callbacks.has(key):
			var callback = change_callbacks[key]
			if callback.is_valid():
				callback.call(value, old_value)

		return true

	## 设置变化回调
	func set_change_callback(key: String, callback: Callable) -> void:
		change_callbacks[key] = callback

	## 清除追踪
	func clear(key: String) -> void:
		tracked_values.erase(key)
		change_callbacks.erase(key)

## UI批量更新器
class UIBatchUpdater:
	var update_queue: Array = []
	var is_processing: bool = false

	## 添加更新操作到队列
	func queue_update(callback: Callable, priority: int = 0) -> void:
		update_queue.append({
			"callback": callback,
			"priority": priority
		})

	## 处理所有队列更新
	func process() -> void:
		if is_processing:
			return

		is_processing = true

		# 按优先级排序
		update_queue.sort_custom(func(a, b): return a.priority > b.priority)

		# 执行所有更新
		for update_data in update_queue:
			var callback = update_data.callback
			if callback.is_valid():
				callback.call()

		update_queue.clear()
		is_processing = false

## UI缓存管理器
class UICacheManager:
	var cache: Dictionary = {}
	var cache_hit_count: int = 0
	var cache_miss_count: int = 0

	## 获取缓存值
	func get(key: String, default_value: Variant = null) -> Variant:
		if cache.has(key):
			cache_hit_count += 1
			return cache[key]

		cache_miss_count += 1
		return default_value

	## 设置缓存值
	func set(key: String, value: Variant) -> void:
		cache[key] = value

	## 清除缓存
	func clear(key: String = "") -> void:
		if key.is_empty():
			cache.clear()
		else:
			cache.erase(key)

	## 获取缓存统计
	func get_stats() -> Dictionary:
		var total = cache_hit_count + cache_miss_count
		var hit_rate = 0.0
		if total > 0:
			hit_rate = float(cache_hit_count) / float(total)

		return {
			"hits": cache_hit_count,
			"misses": cache_miss_count,
			"total": total,
			"hit_rate": hit_rate,
			"size": cache.size()
		}

## 全局实例
static var throttler: UIThrottler = UIThrottler.new()
static var change_tracker: UIChangeTracker = UIChangeTracker.new()
static var batch_updater: UIBatchUpdater = UIBatchUpdater.new()
static var cache_manager: UICacheManager = UICacheManager.new()

## 便捷函数

## 节流更新（减少频繁更新）
static func throttle_update(key: String, interval: float, callback: Callable) -> bool:
	if not throttler.should_update(key):
		throttler.mark_pending(key)
		return false

	if callback.is_valid():
		callback.call()

	return true

## 处理待处理更新
static func process_pending_updates(callback: Callable) -> void:
	throttler.process_pending(callback)

## 追踪并只在变化时更新
static func update_on_change(key: String, value: Variant, callback: Callable) -> void:
	if change_tracker.track(key, value):
		if callback.is_valid():
			callback.call(value)

## 批量更新UI
static func batch_update(callbacks: Array) -> void:
	for cb in callbacks:
		if cb is Callable and cb.is_valid():
			batch_updater.queue_update(cb)

	batch_updater.process()

## 获取缓存值
static func get_cached(key: String, default_value: Variant = null) -> Variant:
	return cache_manager.get(key, default_value)

## 设置缓存值
static func set_cached(key: String, value: Variant) -> void:
	cache_manager.set(key, value)

## 清除缓存
static func clear_cache(key: String = "") -> void:
	cache_manager.clear(key)

## 获取缓存统计
static func get_cache_stats() -> Dictionary:
	return cache_manager.get_stats()

## UI更新优化装饰器
## 用法：@optimize_ui_update(0.1) 表示最多每0.1秒更新一次
static func optimize_ui_update(min_interval: float) -> Callable:
	return func(key: String, callback: Callable):
		if not throttler.should_update(key):
			return

		if callback.is_valid():
			callback.call()

## 创建智能更新器
## 自动检测变化并节流更新
static func create_smart_updater(key: String, min_interval: float = 0.1) -> RefCounted:
	var updater = RefCounted.new()

	updater.set("last_value", null)
	updater.set("last_update_time", 0.0)
	updater.set("key", key)
	updater.set("min_interval", min_interval)

	updater.set("update", func(value, callback: Callable):
		var current_time = Time.get_ticks_msec() / 1000.0
		var last_update = updater.get("last_update_time")
		var last_value = updater.get("last_value")

		# 检查值是否变化
		if last_value == value:
			return

		# 检查是否应该更新（节流）
		if current_time - last_update < min_interval:
			return

		# 执行更新
		if callback.is_valid():
			callback.call(value)

		updater.set("last_value", value)
		updater.set("last_update_time", current_time)
	)

	return updater

## 性能统计
static func get_performance_stats() -> Dictionary:
	return {
		"cache": cache_manager.get_stats(),
		"throttler": {
			"tracked_keys": throttler.update_intervals.size(),
			"pending_updates": throttler.pending_updates.size()
		},
		"batch_updater": {
			"queued_updates": batch_updater.update_queue.size(),
			"is_processing": batch_updater.is_processing
		},
		"change_tracker": {
			"tracked_values": change_tracker.tracked_values.size(),
			"callbacks": change_tracker.change_callbacks.size()
		}
	}

## 重置所有统计
static func reset_stats() -> void:
	cache_manager.cache_hit_count = 0
	cache_manager.cache_miss_count = 0
