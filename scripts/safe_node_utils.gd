## 安全节点工具函数：提供安全的节点释放和验证方法

## 安全释放节点
## 避免内存泄漏和悬空引用
static func safe_queue_free(node: Node) -> void:
	if node == null:
		return
	if not is_instance_valid(node):
		return
	# 检查节点是否已经在释放队列中
	if not is_inside_tree():
		return
	node.queue_free()

## 安全从父节点移除并释放
static func safe_remove_and_free(node: Node) -> void:
	if node == null:
		return
	if not is_instance_valid(node):
		return

	var parent = node.get_parent()
	if parent != null and is_instance_valid(parent):
		parent.remove_child(node)

	safe_queue_free(node)

## 安全删除节点的所有子节点
static func safe_free_all_children(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	var children = node.get_children()
	for child in children:
		safe_queue_free(child)

## 安全设置节点属性（验证属性存在后再设置）
static func safe_set_property(node: Node, property: String, value) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_method("get") and not node.has_method("set"):
		return false
	if not property in node:
		return false

	node.set(property, value)
	return true

## 安全获取节点属性
static func safe_get_property(node: Node, property: String, default_value = null):
	if node == null or not is_instance_valid(node):
		return default_value
	if not property in node:
		return default_value

	return node.get(property)

## 安全连接信号（避免重复连接）
static func safe_connect_signal(
	node: Node,
	signal_name: String,
	callable: Callable,
	extra_args: Array = []
) -> bool:
	if node == null or not is_instance_valid(node):
		push_error("[SafeNodeUtils] Cannot connect signal: node is invalid")
		return false
	if not node.has_signal(signal_name):
		push_error("[SafeNodeUtils] Signal not found: %s" % signal_name)
		return false

	# 检查是否已经连接（避免重复连接）
	if not node.is_connected(signal_name, callable):
		if extra_args.is_empty():
			node.connect(signal_name, callable)
		else:
			node.connect(signal_name, callable.bind(extra_args))

	return true

## 安全断开信号
static func safe_disconnect_signal(
	node: Node,
	signal_name: String,
	callable: Callable
) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_signal(signal_name):
		return false

	if node.is_connected(signal_name, callable):
		node.disconnect(signal_name, callable)
		return true

	return false

## 验证节点是否在场景树中且有效
static func is_node_valid_and_in_tree(node: Node) -> bool:
	return node != null and is_instance_valid(node) and node.is_inside_tree()

## 批量安全释放节点数组
static func safe_free_nodes(nodes: Array) -> void:
	for node in nodes:
		if node is Node:
			safe_queue_free(node)

## 延迟安全释放（在下一帧执行）
static func safe_queue_free_deferred(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	node.call_deferred("queue_free")

## 创建Timer并自动管理生命周期
## Timer会自动清理，不需要手动queue_free
static func create_auto_cleanup_timer(delay: float, callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	timer.timeout.connect(callback)
	timer.timeout.connect(func():
		# Timer会在timeout后自动被父节点清理
		# 不需要显式queue_free
	)
	return timer
