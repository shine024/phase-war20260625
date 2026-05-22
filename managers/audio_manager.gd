extends Node
## 音效：按名称播放，资源缺失时静默跳过
## 可放置 res://assets/sfx/button.ogg, hit.ogg, cast.ogg, win.ogg, lose.ogg
## 扩展音效: blueprint_unlock.ogg, enhance.ogg

const SoundGeneratorScript = preload("res://managers/sound_generator.gd")

var _players: Dictionary = {}
var _sound_generator: Node = null
const SFX_NAMES: Array[String] = [
	"button", "button_hover", "hit", "shoot", "explosion", "cast", "hurt",
	"win", "lose", "blueprint_unlock",
	"enhance", "achievement", "quest_complete", "panel_open", "panel_close",
	"card_pickup", "card_place", "error"
]
const BUS_NAME: String = "Master"

## 音量设置
var sfx_volume: float = 1.0
var music_volume: float = 0.7
var master_volume: float = 1.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# 初始化音效生成器作为备用
	if SoundGeneratorScript:
		_sound_generator = SoundGeneratorScript.new()
		add_child(_sound_generator)

	# 创建音效播放器池
	for name in SFX_NAMES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_NAME
		p.volume_db = linear_to_db(sfx_volume)
		add_child(p)
		_players[name] = p

	# 连接信号
	if SignalBus:
		SignalBus.unit_damaged.connect(_on_unit_damaged)
		SignalBus.active_law_cast_at.connect(_on_cast)
		SignalBus.battle_ended.connect(_on_battle_ended)
		if SignalBus.has_signal("blueprint_unlocked"):
			SignalBus.blueprint_unlocked.connect(_on_blueprint_unlocked)
		if SignalBus.has_signal("achievement_unlocked"):
			SignalBus.achievement_unlocked.connect(_on_achievement_unlocked)

## 播放音效
func play_sfx(name: String) -> void:
	if name.is_empty():
		return

	var p: AudioStreamPlayer = _players.get(name)
	if p == null:
		# 如果没有专用播放器，使用默认的按钮播放器
		p = _players.get("button")
	if p == null:
		return

	# 尝试加载音效文件
	var stream: AudioStream = _load_audio_stream(name)

	# 如果没有找到音效文件，使用音效生成器
	if stream == null and _sound_generator != null:
		stream = _sound_generator.get_sound(name)

	if stream == null:
		return  # 静默跳过

	p.stream = stream
	p.play()

## 加载音频流
func _load_audio_stream(name: String) -> AudioStream:
	var path_ogg: String = "res://assets/sfx/%s.ogg" % name
	var path_wav: String = "res://assets/sfx/%s.wav" % name

	if ResourceLoader.exists(path_ogg):
		return load(path_ogg) as AudioStream
	elif ResourceLoader.exists(path_wav):
		return load(path_wav) as AudioStream

	return null

## 设置音效音量
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	for p in _players.values():
		if p is AudioStreamPlayer:
			p.volume_db = linear_to_db(sfx_volume)

## 设置主音量
func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))

## 播放UI音效
func play_ui_sfx(action: String) -> void:
	match action:
		"button_hover":
			play_sfx("button_hover")
		"panel_open":
			play_sfx("panel_open")
		"panel_close":
			play_sfx("panel_close")
		"card_pickup":
			play_sfx("card_pickup")
		"card_place":
			play_sfx("card_place")
		"error":
			play_sfx("error")
		_:
			play_sfx("button")

func _on_unit_damaged(_unit: Node, _is_player: bool, _amount: float, _at_position: Vector2) -> void:
	play_sfx("hit")

func _on_cast(_law_id: String, _world_pos: Vector2) -> void:
	play_sfx("cast")

func _on_battle_ended(player_won: bool) -> void:
	play_sfx("win" if player_won else "lose")

func _on_blueprint_unlocked(_card_id: String) -> void:
	play_sfx("blueprint_unlock")

func _on_enhancement_completed(success: bool, _card_id: String, _new_stats: Dictionary, _message: String) -> void:
	play_sfx("enhance" if success else "cancel")

func _on_achievement_unlocked(_achievement_id: String, _achievement_name: String) -> void:
	play_sfx("achievement")

func _on_quest_completed(_quest_id: String) -> void:
	play_sfx("quest_complete")

## 播放射击音效
func play_shoot_sfx() -> void:
	play_sfx("shoot")

## 播放爆炸音效
func play_explosion_sfx() -> void:
	play_sfx("explosion")

## 播放受伤音效
func play_hurt_sfx() -> void:
	play_sfx("hurt")
