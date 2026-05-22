extends Node2D
## 伤害数字显示：静态出现，淡出消失，无跳动无特效
## 使用 PROCESS_MODE_ALWAYS：战斗暂停/结算时仍能跑完 _process 并归还对象池，避免残留在屏幕上

const DAMAGE_STYLES: Dictionary = {
	"normal": {
		"font_size": 16,
		"color": Color(1.0, 1.0, 1.0, 1.0),
		"outline_color": Color(0.1, 0.1, 0.1, 0.8),
		"scale": 0.85
	},
	"critical": {
		"font_size": 24,
		"color": Color(1.0, 0.2, 0.1, 1.0),
		"outline_color": Color(0.8, 0.0, 0.0, 0.9),
		"scale": 1.12
	},
	"heal": {
		"font_size": 18,
		"color": Color(0.2, 1.0, 0.4, 1.0),
		"outline_color": Color(0.0, 0.3, 0.1, 0.8),
		"scale": 0.95
	},
	"shield": {
		"font_size": 14,
		"color": Color(0.2, 0.8, 1.0, 1.0),
		"outline_color": Color(0.0, 0.3, 0.5, 0.8),
		"scale": 0.85
	},
	"dot": {
		"font_size": 13,
		"color": Color(1.0, 0.6, 0.1, 1.0),
		"outline_color": Color(0.3, 0.2, 0.0, 0.8),
		"scale": 0.75
	},
	"miss": {
		"font_size": 14,
		"color": Color(0.6, 0.6, 0.6, 0.7),
		"outline_color": Color(0.2, 0.2, 0.2, 0.6),
		"scale": 0.85
	}
}

static var _label_settings_cache: Dictionary = {}

var damage_value: int = 0
var is_critical: bool = false
var damage_type: String = "normal"  # normal, critical, heal, shield, dot, miss

var _fade_duration: float = 1.2
var _lifetime: float = 0.0
var _label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("battle_damage_numbers")

static func _get_cached_label_settings(damage_type_key: String) -> LabelSettings:
	if _label_settings_cache.has(damage_type_key):
		return _label_settings_cache[damage_type_key] as LabelSettings
	var style: Dictionary = DAMAGE_STYLES.get(damage_type_key, DAMAGE_STYLES["normal"]) as Dictionary
	var settings := LabelSettings.new()
	settings.font_size = int(style.get("font_size", 16))
	settings.font_color = style.get("color", Color.WHITE) as Color
	settings.outline_size = 2
	settings.outline_color = style.get("outline_color", Color.BLACK) as Color
	_label_settings_cache[damage_type_key] = settings
	return settings

## 从对象池取出后、加入战斗节点树之前调用
func prepare_for_display(damage: int, crit: bool, type_str: String) -> void:
	set_process(false)
	damage_value = damage
	is_critical = crit
	damage_type = type_str
	_lifetime = 0.0
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_create_damage_label()

func _create_damage_label() -> void:
	var style: Dictionary = DAMAGE_STYLES.get(damage_type, DAMAGE_STYLES["normal"]) as Dictionary
	var settings: LabelSettings = _get_cached_label_settings(damage_type)

	if _label == null or not is_instance_valid(_label):
		_label = Label.new()
		_label.z_index = 150
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)

	_label.text = _get_display_text()
	_label.label_settings = settings

	scale = Vector2(float(style.get("scale", 1.0)), float(style.get("scale", 1.0)))

func _get_display_text() -> String:
	match damage_type:
		"heal":
			return "+" + str(damage_value)
		"shield":
			return "+" + str(damage_value)
		"miss":
			return "MISS"
		"dot":
			return str(damage_value)
		_:
			return str(damage_value)

func _process(delta: float) -> void:
	_lifetime += delta
	# 后半段淡出
	if _lifetime >= _fade_duration * 0.5:
		var alpha: float = 1.0 - ((_lifetime - _fade_duration * 0.5) / (_fade_duration * 0.5))
		modulate.a = alpha
	# 到期归还池
	if _lifetime >= _fade_duration:
		set_process(false)
		if ObjectPoolManager:
			ObjectPoolManager.return_object("damage_numbers", self)
		else:
			queue_free()

func reset_pool_object() -> void:
	_lifetime = 0.0
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	# 保留 Label 供下次 prepare 复用，避免反复 new/free

## 静态创建：走 ObjectPoolManager.damage_numbers
static func create_damage_number(parent: Node, world_pos: Vector2, damage: int, is_crit: bool = false, type: String = "normal") -> void:
	if not parent or not is_instance_valid(parent):
		return
	if ObjectPoolManager == null:
		push_warning("[DamageNumberDisplay] ObjectPoolManager 未就绪")
		return
	var display: Node = ObjectPoolManager.get_object("damage_numbers")
	if display == null:
		return
	if display.has_method("set_process"):
		display.set_process(false)
	if display.has_method("prepare_for_display"):
		display.call("prepare_for_display", damage, is_crit, type)
	parent.add_child(display)
	if display is Node2D:
		(display as Node2D).global_position = world_pos + Vector2(randf_range(-15, 15), randf_range(-10, 10))
	if display.has_method("set_process"):
		display.set_process(true)

static func create_critical_damage(parent: Node, world_pos: Vector2, damage: int) -> void:
	create_damage_number(parent, world_pos, damage, true, "critical")

static func create_heal_number(parent: Node, world_pos: Vector2, heal: int) -> void:
	create_damage_number(parent, world_pos, heal, false, "heal")

static func create_shield_number(parent: Node, world_pos: Vector2, shield: int) -> void:
	create_damage_number(parent, world_pos, shield, false, "shield")

static func create_dot_damage(parent: Node, world_pos: Vector2, damage: int) -> void:
	create_damage_number(parent, world_pos, damage, false, "dot")

static func create_miss(parent: Node, world_pos: Vector2) -> void:
	create_damage_number(parent, world_pos, 0, false, "miss")

## 战斗清理时强制归还（避免 queue_free 破坏池）
static func try_return_to_pool(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if ObjectPoolManager:
		ObjectPoolManager.return_object("damage_numbers", node)
	else:
		node.queue_free()
