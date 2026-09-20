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

## v26.x 改造消耗品化：「见过集合」item_type -> true。
## consume_item 数量归零会删库存 key，消耗完查不到"得到过"——制造站门槛
## （得到过就可造）依赖此集合而非 _inventory。add_item 时自动记录。
var _seen: Dictionary = {}

## ── 生命周期 ──────────────────────────────────────────────

func _ready() -> void:
	# 不在_ready中自行加载，由SaveManager统一加载
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()

# ── 存档 ───────────────────────────────────────────────────

func _save_state() -> void:
	SaveUtils.save_data_to_file({"inventory": _inventory.duplicate(), "seen": _seen.duplicate()}, "intel_item_bag_state")

func _load_state() -> void:
	var data: Dictionary = SaveUtils.load_data_from_file("intel_item_bag_state")
	_inventory = data.get("inventory", {})
	if not (_inventory is Dictionary):
		_inventory = {}
	_seen = _coerce_seen(data.get("seen", {}))
	_backfill_seen_from_inventory()
	# [LOG-v5.1] print("[IntelItemBag] 加载完成，道具种类 %d" % _inventory.size())

## 旧存档/外部数据的 seen 段清洗（key 转 String，剔除非改造图纸条目）
func _coerce_seen(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if raw is Dictionary:
		for k in raw:
			out[str(k)] = true
	return out

# ── 核心接口 ──────────────────────────────────────────────

## 添加道具
func add_item(item_type: String, count: int = 1) -> void:
	if not IntelManualItems.is_valid_blueprint(item_type):
		push_warning("[IntelItemBag] 无效蓝图类型: %s" % item_type)
		return
	if count <= 0:
		return
	_inventory[item_type] = int(_inventory.get(item_type, 0)) + count
	_seen[item_type] = true
	item_count_changed.emit(item_type, int(_inventory[item_type]))

## 消耗一个道具（返回是否成功）
func consume_item(item_type: String) -> bool:
	if not IntelManualItems.is_valid_blueprint(item_type):
		push_warning("[IntelItemBag] 无效蓝图类型: %s" % item_type)
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

## 统计以指定前缀开头的道具库存总张数（2026-09-19：改造解锁衔接提示"已攒 N 张图纸"用）
func count_by_prefix(prefix: String) -> int:
	var total: int = 0
	for item_type in _inventory:
		if String(item_type).begins_with(prefix):
			total += int(_inventory[item_type])
	return total

# ── 见过集合（v26.x 改造消耗品化） ─────────────────────────

## 是否得到过该道具（与当前库存无关，消耗光也算）
func has_seen(item_type: String) -> bool:
	return _seen.has(item_type)

## 全部见过的道具 id 列表
func get_seen_item_ids() -> Array:
	return _seen.keys()

## 用现有库存回填见过集合（旧档无 seen key 时兜底）
func _backfill_seen_from_inventory() -> void:
	for k in _inventory:
		_seen[str(k)] = true

## 旧档回填：库存 ∪ InstanceRegistry 全部实例已安装改造（mod_id → blueprint_ 前缀）。
## 由 SaveManager 加载完 critical 段后调用一次（IntelItemBag/InstanceRegistry 均
## critical 立即加载，顺序安全）；新特性前的老玩家凭已装改造直接解锁制造目录。
func backfill_seen_from_registry() -> void:
	_backfill_seen_from_inventory()
	var ir: Node = get_node_or_null("/root/InstanceRegistry")
	if ir == null or not ir.has_method("get_all_instance_ids"):
		return
	for inst_id in ir.get_all_instance_ids():
		var inst = ir.get_instance(String(inst_id))
		if inst == null:
			continue
		for entry in inst.mods:
			var mod_id: String = ""
			if entry is Dictionary:
				mod_id = String(entry.get("id", ""))
			elif entry is String:
				mod_id = entry  # 旧存档裸字符串条目
			if not mod_id.is_empty():
				_seen["blueprint_" + mod_id] = true

# ── 兼容 SaveManager ──────────────────────────────────────

func save_state() -> Dictionary:
	return {"inventory": _inventory.duplicate(true), "seen": _seen.duplicate(true)}

func load_state(data: Dictionary) -> void:
	_inventory = data.get("inventory", {})
	if not (_inventory is Dictionary):
		_inventory = {}
	_seen = _coerce_seen(data.get("seen", {}))
	_backfill_seen_from_inventory()
