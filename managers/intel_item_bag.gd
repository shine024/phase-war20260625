extends Node
## v6.0: 情报道具背包管理器
##
## 管理玩家持有的情报道具库存（一次性消耗品）。
## Autoload: /root/IntelItemBag
##
## 职责：
## - 记录每种情报道具的持有数量
## - 添加/消耗道具
## - 存档/读档
## - 发射库存变更信号

const IntelManualItems = preload("res://data/intel_manual_items.gd")
const SaveUtils = preload("res://scripts/save_utils.gd")

## 库存变更信号 (item_type: String, new_count: int)
signal item_count_changed(item_type: String, new_count: int)

## 库存: item_type -> count
var _inventory: Dictionary = {}

## ── 生命周期 ──────────────────────────────────────────────

func _ready() -> void:
	# 不在_ready中自行加载，由SaveManager统一加载
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()

# ── 存档 ───────────────────────────────────────────────────

func _save_state() -> void:
	SaveUtils.save_data_to_file({"inventory": _inventory.duplicate()}, "intel_item_bag_state")

func _load_state() -> void:
	var data: Dictionary = SaveUtils.load_data_from_file("intel_item_bag_state")
	_inventory = data.get("inventory", {})
	if not (_inventory is Dictionary):
		_inventory = {}
	print("[IntelItemBag] 加载完成，道具种类 %d" % _inventory.size())

# ── 核心接口 ──────────────────────────────────────────────

## 添加道具
func add_item(item_type: String, count: int = 1) -> void:
	if not IntelManualItems.is_valid_type(item_type):
		push_warning("[IntelItemBag] 无效道具类型: %s" % item_type)
		return
	if count <= 0:
		return
	_inventory[item_type] = int(_inventory.get(item_type, 0)) + count
	item_count_changed.emit(item_type, int(_inventory[item_type]))

## 消耗一个道具（返回是否成功）
func consume_item(item_type: String) -> bool:
	if not IntelManualItems.is_valid_type(item_type):
		push_warning("[IntelItemBag] 无效道具类型: %s" % item_type)
		return false
	var have: int = int(_inventory.get(item_type, 0))
	if have <= 0:
		return false
	_inventory[item_type] = have - 1
	if _inventory[item_type] <= 0:
		_inventory.erase(item_type)
	item_count_changed.emit(item_type, int(_inventory.get(item_type, 0)))
	return true

## 检查是否有足够的道具
func has_item(item_type: String, count: int = 1) -> bool:
	return int(_inventory.get(item_type, 0)) >= count

## 获取某种道具数量
func get_count(item_type: String) -> int:
	return int(_inventory.get(item_type, 0))

## 获取全部库存
func get_all_inventory() -> Dictionary:
	return _inventory.duplicate(true)

## 获取库存总数（所有道具种类合计）
func get_total_count() -> int:
	var total: int = 0
	for v in _inventory.values():
		total += int(v)
	return total

# ── 兼容 SaveManager ──────────────────────────────────────

func save_state() -> Dictionary:
	return {"inventory": _inventory.duplicate(true)}

func load_state(data: Dictionary) -> void:
	_inventory = data.get("inventory", {})
	if not (_inventory is Dictionary):
		_inventory = {}
