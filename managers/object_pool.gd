extends Node
## 对象池系统：减少频繁的对象创建和销毁，提升性能
## 用于管理战斗单位、子弹等频繁创建销毁的对象

## 性能优化：预加载常用场景
const BULLET_SCENE_PATH = "res://scenes/units/bullet.tscn"
const DAMAGE_NUMBER_SCENE_PATH = "res://scenes/effects/damage_number_display.tscn"

## 池配置
class PoolConfig:
	var pool_size: int = 10  # 池大小
	var scene_path: String  # 场景路径
	var auto_expand: bool = true  # 自动扩展
	var max_size: int = 50  # 最大池大小，防止无限扩展
	var reset_on_return: bool = true  # 归还时重置对象状态

	func _init(p_size: int = 10, p_path: String = "", p_auto_expand: bool = true, p_max_size: int = 50, p_reset: bool = true):
		pool_size = p_size
		scene_path = p_path
		auto_expand = p_auto_expand
		max_size = p_max_size
		reset_on_return = p_reset

## 对象池
class ObjectPool extends Node:
	var scene: PackedScene
	var available: Array = []  # 可用对象
	var in_use: Array = []  # 使用中对象
	var config: PoolConfig
	var total_created: int = 0  # 总创建数量统计
	var is_initialized: bool = false

	func _init(p_config: PoolConfig):
		config = p_config
		if config.scene_path.is_empty():
			push_error("[ObjectPool] 场景路径为空")
			return
		scene = load(config.scene_path) as PackedScene
		if scene == null:
			push_error("[ObjectPool] 无法加载场景: %s" % config.scene_path)
			return
		is_initialized = true
		# 预创建对象
		_preload_objects()

	func _preload_objects():
		for i in range(config.pool_size):
			var obj = _create_object()
			if obj:
				available.append(obj)

	func _create_object() -> Node:
		if scene == null:
			push_error("[ObjectPool] 场景未加载")
			return null
		var obj = scene.instantiate()
		if obj == null:
			push_error("[ObjectPool] 实例化失败")
			return null
		total_created += 1
		# 初始停用状态（不add_child，减少场景树节点数）
		if obj.has_method("set_process"):
			obj.set_process(false)
		if obj.has_method("set_physics_process"):
			obj.set_physics_process(false)
		return obj

	func get_object() -> Node:
		if not is_initialized:
			push_error("[ObjectPool] 池未正确初始化")
			return null
		var obj: Node = null
		# 从可用池中获取（跳过已释放/无效对象，避免 freed instance 赋值报错）
		while available.size() > 0 and obj == null:
			var candidate: Variant = available.pop_back()
			if candidate != null and is_instance_valid(candidate) and candidate is Node:
				obj = candidate as Node
		if obj == null:
			# 池为空，检查是否可以创建新对象
			if total_created >= config.max_size:
				push_error("[ObjectPool] 已达到最大池大小 (%d)，无法创建新对象" % config.max_size)
				return null
			if config.auto_expand:
				obj = _create_object()
				if obj == null:
					push_error("[ObjectPool] 无法创建新对象")
					return null
			else:
				push_warning("[ObjectPool] 对象池已空且不允许自动扩展")
				return null
		# 激活对象
		if obj.has_method("set_process"):
			obj.set_process(true)
		if obj.has_method("set_physics_process"):
			obj.set_physics_process(true)
		in_use.append(obj)
		return obj

	func return_object(obj: Node) -> void:
		if obj == null or not is_instance_valid(obj):
			push_warning("[ObjectPool] 尝试归还空对象")
			return
		if not in_use.has(obj):
			push_warning("[ObjectPool] 尝试归还不属于此池的对象")
			return
		# 从使用中移除
		in_use.erase(obj)
		# 重置对象状态
		if config.reset_on_return:
			_reset_object(obj)
		# 停用处理
		if obj.has_method("set_process"):
			obj.set_process(false)
		if obj.has_method("set_physics_process"):
			obj.set_physics_process(false)
		# 从场景树移除，减少objects计数（get时会重新加入）
		if obj.is_inside_tree() and obj.get_parent():
			obj.get_parent().remove_child(obj)
		# 返回到可用池
		available.append(obj)

	func _reset_object(obj: Node) -> void:
		# 基础重置：位置、旋转、缩放
		if obj is Node2D:
			obj.position = Vector2.ZERO
			obj.rotation = 0.0
			obj.scale = Vector2.ONE
		# 如果对象有自定义重置方法，调用它
		if obj.has_method("reset_pool_object"):
			obj.reset_pool_object()

	func clear() -> void:
		# 清理所有对象
		for obj in available:
			if is_instance_valid(obj):
				obj.queue_free()
		for obj in in_use:
			if is_instance_valid(obj):
				obj.queue_free()
		available.clear()
		in_use.clear()

	func get_stats() -> Dictionary:
		return {
			"available": available.size(),
			"in_use": in_use.size(),
			"total": available.size() + in_use.size(),
			"total_created": total_created,
			"pool_size": config.pool_size,
			"max_size": config.max_size,
			"utilization": float(in_use.size()) / float(max(1, total_created))
		}

## 对象池管理器
var _pools: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 性能优化：自动注册常用对象池
	_register_default_pools()

## 注册默认对象池
func _register_default_pools() -> void:
	# 战前不预创建：进入主界面/标题阶段避免一次性实例化数十个战斗节点造成卡顿；首帧开战时按需扩展
	# 小批量预热：降低首战时同步扩容尖峰（仍允许 auto_expand 到 max）
	register_pool("bullets", PoolConfig.new(
		2,
		BULLET_SCENE_PATH,
		true,
		100,
		true
	))
	register_pool("damage_numbers", PoolConfig.new(
		4,
		DAMAGE_NUMBER_SCENE_PATH,
		true,
		40,
		true
	))

## 注册对象池
func register_pool(pool_name: String, config: PoolConfig) -> void:
	if _pools.has(pool_name):
		push_warning("[ObjectPoolManager] 池 '%s' 已存在，将被覆盖" % pool_name)
	var pool = ObjectPool.new(config)
	pool.name = pool_name
	add_child(pool)
	_pools[pool_name] = pool
	if OS.is_debug_build():
		print("[ObjectPoolManager] 注册池 '%s'，大小: %d" % [pool_name, config.pool_size])

## 从池中获取对象
func get_object(pool_name: String) -> Node:
	if not _pools.has(pool_name):
		push_error("[ObjectPoolManager] 池 '%s' 不存在" % pool_name)
		return null
	var pool = _pools[pool_name] as ObjectPool
	return pool.get_object()

## 归还对象到池
func return_object(pool_name: String, obj: Node) -> void:
	if not _pools.has(pool_name):
		push_error("[ObjectPoolManager] 池 '%s' 不存在" % pool_name)
		return
	var pool = _pools[pool_name] as ObjectPool
	pool.return_object(obj)

## 清理指定池
func clear_pool(pool_name: String) -> void:
	if not _pools.has(pool_name):
		push_warning("[ObjectPoolManager] 池 '%s' 不存在" % pool_name)
		return
	var pool = _pools[pool_name] as ObjectPool
	pool.clear()

## 清理所有池
func clear_all() -> void:
	for pool_name in _pools.keys():
		clear_pool(pool_name)

## 获取池统计信息
func get_pool_stats(pool_name: String) -> Dictionary:
	if not _pools.has(pool_name):
		push_error("[ObjectPoolManager] 池 '%s' 不存在" % pool_name)
		return {}
	var pool = _pools[pool_name] as ObjectPool
	return pool.get_stats()

## 获取所有池统计信息
func get_all_stats() -> Dictionary:
	var stats: Dictionary = {}
	for pool_name in _pools.keys():
		stats[pool_name] = get_pool_stats(pool_name)
	return stats
