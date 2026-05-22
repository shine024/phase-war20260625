## 延迟初始化Mixin
## 为管理器提供延迟初始化能力

## 延迟初始化标记
var _lazy_init_done: bool = false

## 延迟初始化方法（子类必须重写）
func _lazy_init() -> void:
	push_error("lazy_init_mixin: _lazy_init() must be overridden")

## 确保已初始化
func _check_init() -> void:
	if not _lazy_init_done:
		_lazy_init()

## 检查是否已初始化
func _is_initialized() -> bool:
	return _lazy_init_done
