extends Node
## 音效：按名称播放，资源缺失时静默跳过
## 可放置 res://assets/sfx/<name>.ogg（或 .wav），缺失时用 sound_generator 合成兜底
## 已接入音效见 SFX_NAMES；BGM/背景音乐尚未实装（无 MusicPlayer）。
## 音效事件订阅见 _ready 末尾 connect 块。

const SoundGeneratorScript = preload("res://managers/sound_generator.gd")

var _players: Dictionary = {}
var _sound_generator: Node = null
# P0 性能优化：缓存已加载的音频流，避免每次受击都 ResourceLoader.exists + load
var _audio_cache: Dictionary = {}
const SFX_NAMES: Array[String] = [
	"button", "button_hover", "hit", "shoot", "explosion", "cast", "hurt",
	"win", "lose", "blueprint_unlock",
	"enhance", "achievement", "quest_complete", "panel_open", "panel_close",
	"card_pickup", "card_place", "error",
	# v8.3: 按武器类型（WeaponTypeLegacy）的攻击/命中音效
	"gun_smg", "gun_rifle", "gun_mg", "rocket_launch", "gun_pistol",
	"gun_shotgun", "gun_sniper", "flak_fire", "laser_fire", "missile_hum",
	"omega_cannon", "rail_cannon", "impact_generic",
	# 战斗节奏/养成事件音效（多数复用既有音色，音频文件可后补）
	"cancel",           # 失败/取消（强化失败、合成失败、错误操作回退）
	"wave_start",       # 新波次开始
	"boss_warn",        # BOSS 波/相位师登场警告
	"master_appear",    # 相位师登场
	"base_destroy",     # 基地（相位场驱动器）被摧毁
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

	# 连接信号（is_connected 守卫防止重复注册）
	if SignalBus:
		if not SignalBus.unit_damaged.is_connected(_on_unit_damaged):
			SignalBus.unit_damaged.connect(_on_unit_damaged)
		if not SignalBus.active_law_cast_at.is_connected(_on_cast):
			SignalBus.active_law_cast_at.connect(_on_cast)
		if not SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.connect(_on_battle_ended)
		if SignalBus.has_signal("blueprint_unlocked"):
			if not SignalBus.blueprint_unlocked.is_connected(_on_blueprint_unlocked):
				SignalBus.blueprint_unlocked.connect(_on_blueprint_unlocked)
		if SignalBus.has_signal("achievement_unlocked"):
			if not SignalBus.achievement_unlocked.is_connected(_on_achievement_unlocked):
				SignalBus.achievement_unlocked.connect(_on_achievement_unlocked)
		# v7.3 修复 BUG-5: 任务完成音效——补 connect（原 handler 存在但从未连接，是死代码）。
		# SignalBus.quest_completed 在 QuestManager._try_complete 镜像 emit（quest_manager.gd）。
		if SignalBus.has_signal("quest_completed"):
			if not SignalBus.quest_completed.is_connected(_on_quest_completed):
				SignalBus.quest_completed.connect(_on_quest_completed)
		# v7.x 修复: daily_task 完成（含 SignalBus 镜像 emit）此前零订阅者，任务完成无音效。
		# 与 quest_completed/achievement_unlocked 对齐，让任务完成也播放音效。
		if SignalBus.has_signal("task_completed"):
			if not SignalBus.task_completed.is_connected(_on_task_completed):
				SignalBus.task_completed.connect(_on_task_completed)
		# v6.6 修复: play_sound 信号原 emit 无 connect，战斗/UI 音效静默失效。
		# 直接桥接到 play_sfx（签名匹配：都接收音效名 String）
		if SignalBus.has_signal("play_sound"):
			if not SignalBus.play_sound.is_connected(play_sfx):
				SignalBus.play_sound.connect(play_sfx)
		# ── 战斗节奏音效 ──
		if SignalBus.has_signal("wave_spawned") and not SignalBus.wave_spawned.is_connected(_on_wave_spawned):
			SignalBus.wave_spawned.connect(_on_wave_spawned)
		if SignalBus.has_signal("boss_wave_started") and not SignalBus.boss_wave_started.is_connected(_on_boss_wave_started):
			SignalBus.boss_wave_started.connect(_on_boss_wave_started)
		if SignalBus.has_signal("phase_master_appeared") and not SignalBus.phase_master_appeared.is_connected(_on_phase_master_appeared):
			SignalBus.phase_master_appeared.connect(_on_phase_master_appeared)
		if SignalBus.has_signal("phase_driver_destroyed") and not SignalBus.phase_driver_destroyed.is_connected(_on_phase_driver_destroyed):
			SignalBus.phase_driver_destroyed.connect(_on_phase_driver_destroyed)
		if SignalBus.has_signal("player_deploy_failed") and not SignalBus.player_deploy_failed.is_connected(_on_player_deploy_failed):
			SignalBus.player_deploy_failed.connect(_on_player_deploy_failed)
		if SignalBus.has_signal("energy_insufficient") and not SignalBus.energy_insufficient.is_connected(_on_energy_insufficient):
			SignalBus.energy_insufficient.connect(_on_energy_insufficient)
		# ── 养成事件音效（复用既有音色） ──
		if SignalBus.has_signal("synthesis_completed") and not SignalBus.synthesis_completed.is_connected(_on_synthesis_completed):
			SignalBus.synthesis_completed.connect(_on_synthesis_completed)
		if SignalBus.has_signal("synthesis_failed") and not SignalBus.synthesis_failed.is_connected(_on_synthesis_failed):
			SignalBus.synthesis_failed.connect(_on_synthesis_failed)
		if SignalBus.has_signal("rune_acquired") and not SignalBus.rune_acquired.is_connected(_on_rune_acquired):
			SignalBus.rune_acquired.connect(_on_rune_acquired)
		if SignalBus.has_signal("faction_level_up") and not SignalBus.faction_level_up.is_connected(_on_faction_level_up):
			SignalBus.faction_level_up.connect(_on_faction_level_up)
		if SignalBus.has_signal("milestone_reached") and not SignalBus.milestone_reached.is_connected(_on_milestone_reached):
			SignalBus.milestone_reached.connect(_on_milestone_reached)
		if SignalBus.has_signal("phase_field_level_up") and not SignalBus.phase_field_level_up.is_connected(_on_phase_field_level_up):
			SignalBus.phase_field_level_up.connect(_on_phase_field_level_up)
		# v7.x 修复: CardEnhancementManager.enhancement_completed 此前零订阅 + handler 签名错配（Dictionary vs String）。
		# 延迟到首次强化时连接（cem 是 lazy-load，启动时不一定就绪）。
		_connect_enhancement_signal()

## 播放音效
## v8.3: 增加 volume（0.0~1.0，线性→db）和 pitch（0.5~2.0，音高倍率）参数（默认值保证旧调用零变化）
func play_sfx(name: String, volume: float = 1.0, pitch: float = 1.0) -> void:
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
	# v8.3: volume 叠加到全局 sfx_volume；pitch 微调播放速度（合成时已定型，此处作音高变化）
	p.volume_db = linear_to_db(sfx_volume * clampf(volume, 0.0, 1.0))
	if p is AudioStreamPlayer:
		(p as AudioStreamPlayer).pitch_scale = clampf(pitch, 0.2, 3.0)
	p.play()

## 加载音频流
func _load_audio_stream(name: String) -> AudioStream:
	# P0 性能优化：命中缓存直接返回（原每次 play_sfx 都 ResourceLoader.exists + load，
	# 受击密集时每秒数十次资源存在性查询）
	if _audio_cache.has(name):
		return _audio_cache[name]
	var path_ogg: String = "res://assets/sfx/%s.ogg" % name
	var path_wav: String = "res://assets/sfx/%s.wav" % name

	var stream: AudioStream = null
	if ResourceLoader.exists(path_ogg):
		stream = load(path_ogg) as AudioStream
	elif ResourceLoader.exists(path_wav):
		stream = load(path_wav) as AudioStream
	# 缓存结果（包括 null，避免反复查询不存在的资源）
	_audio_cache[name] = stream
	return stream

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

# v7.x 修复: 签名对齐 CardEnhancementManager.enhancement_completed(success, card_id, action, message)。
# 原声明第3参为 Dictionary（错配 String action），即使连接也会运行时报错；且从未 connect（死代码）。
# 由 _connect_enhancement_signal() 延迟连接（cem 为 lazy-load）。
func _on_enhancement_completed(success: bool, _card_id: String, _action: String, _message: String) -> void:
	play_sfx("enhance" if success else "cancel")

## 延迟连接 CardEnhancementManager.enhancement_completed（cem lazy-load，启动时不一定就绪）。
func _connect_enhancement_signal() -> void:
	# AudioManager 自身是 Node，用绝对路径直接访问 autoload 节点（get_node_or_null 是 Node 方法，非 SceneTree）。
	var cem: Node = get_node_or_null("/root/CardEnhancementManager")
	if cem == null:
		return  # lazy-load 未就绪，下次强化时由调用方重试；此处不阻塞
	if cem.has_signal("enhancement_completed") and not cem.enhancement_completed.is_connected(_on_enhancement_completed):
		cem.enhancement_completed.connect(_on_enhancement_completed)

func _on_achievement_unlocked(_achievement_id: String, _achievement_name: String) -> void:
	play_sfx("achievement")

# v7.3 修复 BUG-5: 签名改为双参数匹配 SignalBus.quest_completed(quest_id, rewards)。
# 原 handler 单参数，即使 connect 也会因参数不匹配报错；且原代码从未 connect（死代码）。
func _on_quest_completed(_quest_id: String, _rewards: Dictionary) -> void:
	play_sfx("quest_complete")

# v7.x: daily_task 完成音效，签名匹配 SignalBus.task_completed(task: Dictionary)。
# 复用 quest_complete 音效（日常任务/委托性质相近，无需独立音效资源）。
func _on_task_completed(_task: Dictionary) -> void:
	play_sfx("quest_complete")

# ── v7.x 新增: 战斗节奏 / 养成事件音效 handler ──
# 战斗节奏（每关周期性触发，音色需有辨识度避免腻）
func _on_wave_spawned(_wave_index: int) -> void:
	play_sfx("wave_start")
func _on_boss_wave_started(_boss_ids: Array) -> void:
	play_sfx("boss_warn")
func _on_phase_master_appeared(_config: Dictionary) -> void:
	play_sfx("master_appear")
func _on_phase_driver_destroyed() -> void:
	play_sfx("base_destroy")
func _on_player_deploy_failed(_reason: String, _message: String) -> void:
	play_sfx("error")
func _on_energy_insufficient(_amount: float) -> void:
	play_sfx("error")
# 养成事件（复用既有音色，无需新增音频文件即可生效）
func _on_synthesis_completed(_card_id: String) -> void:
	play_sfx("enhance")
func _on_synthesis_failed(_reason: String) -> void:
	play_sfx("error")
func _on_rune_acquired(_rune_id: String, _source: String) -> void:
	play_sfx("blueprint_unlock")
func _on_faction_level_up(_faction_id: String, _new_level: int) -> void:
	play_sfx("achievement")
func _on_milestone_reached(_milestone_id: String, _milestone_name: String) -> void:
	play_sfx("achievement")
func _on_phase_field_level_up(_old: int, _new: int, _unspent: int) -> void:
	play_sfx("enhance")

## 播放射击音效
func play_shoot_sfx() -> void:
	play_sfx("shoot")

## 播放爆炸音效
func play_explosion_sfx() -> void:
	play_sfx("explosion")

## 播放受伤音效
func play_hurt_sfx() -> void:
	play_sfx("hurt")
