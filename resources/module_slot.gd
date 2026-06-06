class_name ModuleSlot
extends RefCounted
## v6.0 词条槽位（替代旧 AffixResource）
##
## 每个槽位存储一个已选词条的 ID 和等级。
## 一张卡最多 5 个词条槽（对应强化 Lv10）。
## 词条等级 Lv1-3（通过偶数级强化升级）。

var module_id: String = ""    ## 词条 ID（如 "module_crit"）
var level: int = 1             ## 词条等级 1-3
var slot_index: int = 0       ## 槽位编号 0-4

# ─────────────────────────────────────────────
#  序列化 / 反序列化
# ─────────────────────────────────────────────

## 序列化为字典（存档用）
func to_dict() -> Dictionary:
	return {
		"module_id": module_id,
		"level": level,
		"slot_index": slot_index,
	}

## 从字典反序列化
static func from_dict(d: Dictionary) -> ModuleSlot:
	var slot := ModuleSlot.new()
	slot.module_id = d.get("module_id", "")
	slot.level = clampi(int(d.get("level", 1)), 1, 3)
	slot.slot_index = int(d.get("slot_index", 0))
	return slot

# ─────────────────────────────────────────────
#  效果查询
# ─────────────────────────────────────────────

## 获取当前效果值
func get_effect_value() -> float:
	return ModuleDefinitions.get_effect_value(module_id, level)

## 获取效果描述（用于 UI 显示）
func get_effect_description() -> String:
	return ModuleDefinitions.get_effect_description(module_id, level)

## 获取词条名称
func get_module_name() -> String:
	return ModuleDefinitions.get_module_name(module_id)

## 获取词条定义数据
func get_module_data() -> Dictionary:
	return ModuleDefinitions.get_module_data(module_id)

## 是否可以升级
func can_upgrade() -> bool:
	return level < 3

## 创建副本
func duplicate_slot() -> ModuleSlot:
	var s := ModuleSlot.new()
	s.module_id = module_id
	s.level = level
	s.slot_index = slot_index
	return s

## 验证数据完整性
func is_valid() -> bool:
	return not module_id.is_empty() and level >= 1 and level <= 3

## 获取效果类型
func get_effect_type() -> String:
	return ModuleDefinitions.get_effect_type(module_id)

## 获取效果键
func get_effect_key() -> String:
	return ModuleDefinitions.get_effect_key(module_id)

## 获取分类
func get_category() -> String:
	var d: Dictionary = get_module_data()
	return d.get("category", "")
