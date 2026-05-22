class_name LazyInitHelper
extends RefCounted
## 延迟初始化辅助工具
##
## 为非核心 autoload 管理器提供统一的延迟初始化模式。
## 使用 call_deferred 将耗时的初始化逻辑推迟到主循环空闲时执行，
## 减少启动时的阻塞时间。
##
## 用法：
##   在管理器中：
##   var _lazy: LazyInitHelper
##   func _ready():
##       _lazy = LazyInitHelper.new(self)
##       _lazy.defer_init(_deferred_init)
##
##   或者直接使用静态方法：
##   func _ready():
##       LazyInitHelper.setup_deferred_init(self, "_deferred_init")

## 标记管理器是否已完成延迟初始化
## key: 管理器路径 (String), value: bool
static var _initialized_managers: Dictionary = {}

## 检查指定管理器是否已完成初始化
static func is_initialized(manager: Node) -> bool:
	return _initialized_managers.get(manager.get_path(), false)

## 将管理器标记为已初始化
static func mark_initialized(manager: Node) -> void:
	_initialized_managers[manager.get_path()] = true

## 将管理器标记为未初始化
static func mark_uninitialized(manager: Node) -> void:
	_initialized_managers.erase(manager.get_path())

## 设置延迟初始化（静态便捷方法）
## 调用后，method_name 将在当前帧结束后通过 call_deferred 执行
static func setup_deferred_init(manager: Node, method_name: String) -> void:
	manager.call_deferred(method_name)
	if not _initialized_managers.has(manager.get_path()):
		_initialized_managers[manager.get_path()] = false

## 重置所有初始化状态（用于测试）
static func reset_all() -> void:
	_initialized_managers.clear()

## 获取所有延迟初始化管理器的状态
static func get_status() -> Dictionary:
	return _initialized_managers.duplicate()
