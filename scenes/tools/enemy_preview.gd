@tool
extends Node2D

const EnemyUnitScene := preload("res://scenes/units/enemy_unit.tscn")
const EnemyArchetypes := preload("res://data/enemy_archetypes.gd")

enum PreviewAnim {
	AUTO,
	IDLE,
	RUN,
	ATTACK,
}

@export var preview_archetype_id: String = "enemy_ww1_infantry_basic":
	set(value):
		preview_archetype_id = value
		_request_refresh()

@export var preview_anim: PreviewAnim = PreviewAnim.AUTO:
	set(value):
		preview_anim = value
		_request_refresh()

@export var preview_wave: int = 1:
	set(value):
		preview_wave = maxi(1, value)
		_request_refresh()

@export var center_position: Vector2 = Vector2(640, 360):
	set(value):
		center_position = value
		_request_refresh()

var _preview_unit: Node2D = null
var _refresh_queued: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	if Engine.is_editor_hint():
		_request_refresh()

func _request_refresh() -> void:
	if not Engine.is_editor_hint():
		return
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh_preview")

func _refresh_preview() -> void:
	_refresh_queued = false
	if not is_inside_tree():
		return
	if _preview_unit != null and is_instance_valid(_preview_unit):
		_preview_unit.queue_free()
		_preview_unit = null

	var use_id: String = preview_archetype_id.strip_edges()
	if use_id.is_empty() or EnemyArchetypes.get_config(use_id).is_empty():
		var ids: Array = EnemyArchetypes.get_all_ids()
		if ids.is_empty():
			return
		ids.sort()
		use_id = String(ids[0])

	var unit := EnemyUnitScene.instantiate() as Node2D
	add_child(unit)
	unit.owner = get_tree().edited_scene_root
	unit.global_position = center_position

	if unit.has_method("setup"):
		unit.setup(false, preview_wave, use_id)
	if unit.has_method("set_physics_process"):
		unit.set_physics_process(false)
	if unit.has_method("set_process"):
		unit.set_process(false)

	_apply_preview_animation(unit, use_id)
	_preview_unit = unit

func _apply_preview_animation(_unit: Node2D, _archetype_id: String) -> void:
	# 敌人已改为单张卡图 Sprite2D；AnimatedSprite 预览与 anim_idle/run/attack 已弃用。
	pass

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if not Engine.is_editor_hint():
		return warnings
	var cfg: Dictionary = EnemyArchetypes.get_config(preview_archetype_id)
	if cfg.is_empty():
		warnings.append("preview_archetype_id 无效，已在运行时回退到第一个可用敌人 ID。")
	return warnings
