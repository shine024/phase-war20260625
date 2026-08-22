extends Node
## 音效：按名称播放，资源缺失时静默跳过
## 可放置 res://assets/sfx/<name>.ogg（或 .wav），缺失时用 sound_generator 合成兜底
## 已接入音效见 SFX_NAMES；BGM 系统已实装（MusicPlayer + fade 切换）。
## 音效事件订阅见 _ready 末尾 connect 块。

const SoundGeneratorScript = preload("res://managers/sound_generator.gd")
const GameConstants = preload("res://resources/game_constants.gd")

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
const MUSIC_BUS: String = "Music"

## BGM 播放器（淡入淡出用）
var _music_player: AudioStreamPlayer = null
var _music_player_active: AudioStreamPlayer = null  # 用于交叉淡出的活跃播放器
var _current_bgm_name: String = ""

## BGM 映射表
const BGM_MAP: Dictionary = {
	"title": "bgm_title",
	"hub": "bgm_hub",
	"battle_ww1": "bgm_battle_ww1",
	"battle_ww2": "bgm_battle_ww2",
	"battle_cold": "bgm_battle_cold",
	"battle_modern": "bgm_battle_modern",
	"battle_future": "bgm_battle_future",
	"boss": "bgm_boss",
}

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

	# v7.x 性能优化：启动时只建默认 button 播放器（标题屏立即需要），
	# 其余 SFX 在首次 play_sfx 时按需 new + add_child（_ensure_player）。
	# 原 _ready 一次性建 32 个 AudioStreamPlayer，启动期无谓节点创建。
	_ensure_player("button")

	# 连接信号（is_connected 守卫防止重复注册）
	if SignalBus:
		if not SignalBus.unit_damaged.is_connected(_on_unit_damaged):
			SignalBus.unit_damaged.connect(_on_unit_damaged)
		if not SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.connect(_on_battle_ended)
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
		if SignalBus.has_signal("phase_field_level_up") and not SignalBus.phase_field_level_up.is_connected(_on_phase_field_level_up):
			SignalBus.phase_field_level_up.connect(_on_phase_field_level_up)
		# v7.x 修复: CardEnhancementManager.enhancement_completed 此前零订阅 + handler 签名错配（Dictionary vs String）。
		# 延迟到首次强化时连接（cem 是 lazy-load，启动时不一定就绪）。
		_connect_enhancement_signal()

	# 初始化 BGM 系统
	_init_music_player()

## P0 性能优化：退出时断开所有 SignalBus 连接并释放播放器，
## 防止场景切换后信号连接累积（原无任何清理，长时间游玩 GC 压力持续增长）
func _exit_tree() -> void:
	if SignalBus:
		if SignalBus.unit_damaged.is_connected(_on_unit_damaged):
			SignalBus.unit_damaged.disconnect(_on_unit_damaged)
		if SignalBus.battle_ended.is_connected(_on_battle_ended):
			SignalBus.battle_ended.disconnect(_on_battle_ended)
		if SignalBus.has_signal("achievement_unlocked") and SignalBus.achievement_unlocked.is_connected(_on_achievement_unlocked):
			SignalBus.achievement_unlocked.disconnect(_on_achievement_unlocked)
		if SignalBus.has_signal("quest_completed") and SignalBus.quest_completed.is_connected(_on_quest_completed):
			SignalBus.quest_completed.disconnect(_on_quest_completed)
		if SignalBus.has_signal("task_completed") and SignalBus.task_completed.is_connected(_on_task_completed):
			SignalBus.task_completed.disconnect(_on_task_completed)
		if SignalBus.has_signal("play_sound") and SignalBus.play_sound.is_connected(play_sfx):
			SignalBus.play_sound.disconnect(play_sfx)
		if SignalBus.has_signal("wave_spawned") and SignalBus.wave_spawned.is_connected(_on_wave_spawned):
			SignalBus.wave_spawned.disconnect(_on_wave_spawned)
		if SignalBus.has_signal("boss_wave_started") and SignalBus.boss_wave_started.is_connected(_on_boss_wave_started):
			SignalBus.boss_wave_started.disconnect(_on_boss_wave_started)
		if SignalBus.has_signal("phase_master_appeared") and SignalBus.phase_master_appeared.is_connected(_on_phase_master_appeared):
			SignalBus.phase_master_appeared.disconnect(_on_phase_master_appeared)
		if SignalBus.has_signal("phase_driver_destroyed") and SignalBus.phase_driver_destroyed.is_connected(_on_phase_driver_destroyed):
			SignalBus.phase_driver_destroyed.disconnect(_on_phase_driver_destroyed)
		if SignalBus.has_signal("player_deploy_failed") and SignalBus.player_deploy_failed.is_connected(_on_player_deploy_failed):
			SignalBus.player_deploy_failed.disconnect(_on_player_deploy_failed)
		if SignalBus.has_signal("energy_insufficient") and SignalBus.energy_insufficient.is_connected(_on_energy_insufficient):
			SignalBus.energy_insufficient.disconnect(_on_energy_insufficient)
		if SignalBus.has_signal("synthesis_completed") and SignalBus.synthesis_completed.is_connected(_on_synthesis_completed):
			SignalBus.synthesis_completed.disconnect(_on_synthesis_completed)
		if SignalBus.has_signal("synthesis_failed") and SignalBus.synthesis_failed.is_connected(_on_synthesis_failed):
			SignalBus.synthesis_failed.disconnect(_on_synthesis_failed)
		if SignalBus.has_signal("rune_acquired") and SignalBus.rune_acquired.is_connected(_on_rune_acquired):
			SignalBus.rune_acquired.disconnect(_on_rune_acquired)
		if SignalBus.has_signal("faction_level_up") and SignalBus.faction_level_up.is_connected(_on_faction_level_up):
			SignalBus.faction_level_up.disconnect(_on_faction_level_up)
		if SignalBus.has_signal("phase_field_level_up") and SignalBus.phase_field_level_up.is_connected(_on_phase_field_level_up):
			SignalBus.phase_field_level_up.disconnect(_on_phase_field_level_up)
		# BGM 监听（_init_music_player 内连接的 3 条）
		if SignalBus.has_signal("battle_ended") and SignalBus.battle_ended.is_connected(_on_battle_ended_bgm):
			SignalBus.battle_ended.disconnect(_on_battle_ended_bgm)
		if SignalBus.has_signal("battle_started") and SignalBus.battle_started.is_connected(_on_battle_started_bgm):
			SignalBus.battle_started.disconnect(_on_battle_started_bgm)
		if SignalBus.has_signal("phase_master_appeared") and SignalBus.phase_master_appeared.is_connected(_on_phase_master_appeared_bgm):
			SignalBus.phase_master_appeared.disconnect(_on_phase_master_appeared_bgm)
	# CardEnhancementManager（lazy-load，可能未连接）
	var cem: Node = get_node_or_null("/root/CardEnhancementManager")
	if cem != null and cem.has_signal("enhancement_completed") and cem.enhancement_completed.is_connected(_on_enhancement_completed):
		cem.enhancement_completed.disconnect(_on_enhancement_completed)
	# 释放音频播放器
	for p_name in _players.keys():
		var p: AudioStreamPlayer = _players.get(p_name)
		if p is Node and is_instance_valid(p):
			p.queue_free()
	_players.clear()

## 播放音效
## v8.3: 增加 volume（0.0~1.0，线性→db）和 pitch（0.5~2.0，音高倍率）参数（默认值保证旧调用零变化）
func play_sfx(name: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	if name.is_empty():
		return

	var p: AudioStreamPlayer = _players.get(name)
	if p == null:
		# v7.x: 未命中时按需创建（原启动期一次性建 32 个，现懒扩展）
		p = _ensure_player(name)
	if p == null:
		# 极端兜底：仍未取到（如 _ensure_player 内部失败）则放弃
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

## v7.x: 按需创建播放器并加入场景树（懒扩展池）
## 首次 play_sfx(name) 未命中时调用，创建后存入 _players 字典，后续直接复用。
func _ensure_player(name: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = _players.get(name)
	if p != null:
		return p
	p = AudioStreamPlayer.new()
	p.bus = BUS_NAME
	p.volume_db = linear_to_db(sfx_volume)
	add_child(p)
	_players[name] = p
	return p

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

# ── BGM 系统 ──

## 初始化 MusicPlayer（在 _ready 末尾调用）
func _init_music_player() -> void:
	# 确保 Music bus 存在（默认 -1 末尾追加，避免 Master（恒在 index 0）被推后）
	if not AudioServer.get_bus_index(MUSIC_BUS) >= 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, MUSIC_BUS)
	
	# 创建淡入播放器
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.stream = null
	_music_player.volume_db = linear_to_db(music_volume)
	add_child(_music_player)
	
	# 默认播放标题 BGM（适用于启动即主菜单的情况）
	call_deferred("_play_initial_bgm")
	
	# 监听战斗结束，切回 hub BGM
	if SignalBus:
		if SignalBus.has_signal("battle_ended") and not SignalBus.battle_ended.is_connected(_on_battle_ended_bgm):
			SignalBus.battle_ended.connect(_on_battle_ended_bgm)
		# 战斗开始：切战斗 BGM（根据当前关卡时代）
		if SignalBus.has_signal("battle_started") and not SignalBus.battle_started.is_connected(_on_battle_started_bgm):
			SignalBus.battle_started.connect(_on_battle_started_bgm)
		# BOSS 登场：切 BOSS BGM
		if SignalBus.has_signal("phase_master_appeared") and not SignalBus.phase_master_appeared.is_connected(_on_phase_master_appeared_bgm):
			SignalBus.phase_master_appeared.connect(_on_phase_master_appeared_bgm)

## 战斗开始：切战斗 BGM（根据当前关卡时代）
func _on_battle_started_bgm() -> void:
	if not GameManager:
		return
	var lvl: int = GameManager.current_level
	var era: int = GameConstants.get_era_for_level(lvl)
	var bgm_key: String = "battle_future"
	match era:
		GameConstants.Era.WW1: bgm_key = "battle_ww1"
		GameConstants.Era.WW2: bgm_key = "battle_ww2"
		GameConstants.Era.COLD_WAR: bgm_key = "battle_cold"
		GameConstants.Era.MODERN: bgm_key = "battle_modern"
		GameConstants.Era.NEAR_FUTURE: bgm_key = "battle_future"
	play_music(bgm_key)

## BOSS 登场：切 BOSS BGM
func _on_phase_master_appeared_bgm(_master_config: Dictionary) -> void:
	play_music("boss")

## 播放 BGM（带淡入淡出切换）
func play_music(bgm_key: String, fade_out_duration: float = 1.5) -> void:
	var bgm_name: String = BGM_MAP.get(bgm_key, "")
	if bgm_name.is_empty():
		return
	
	if bgm_name == _current_bgm_name:
		return  # 同一首，不重复播放
	
	_current_bgm_name = bgm_name
	
	var path: String = "res://assets/sfx/%s.ogg" % bgm_name
	if not ResourceLoader.exists(path):
		path = "res://assets/sfx/%s.wav" % bgm_name
		if not ResourceLoader.exists(path):
			print("[AudioManager] BGM not found: ", bgm_name)
			return
	
	var stream = load(path) as AudioStream
	if stream == null:
		return
	
	# 如果已有活跃播放器，先淡出它
	if _music_player_active and _music_player_active.playing:
		_music_player_active.volume_db = linear_to_db(music_volume)
		await get_tree().create_timer(fade_out_duration).timeout
		_music_player_active.stop()
		_music_player_active.stream = null
	
	# 新播放器淡入
	_music_player.stream = stream
	_music_player.volume_db = -80  # 从静音开始
	_music_player.play()
	
	# 淡入动画
	var fade_steps = 30
	var fade_step_time = fade_out_duration / fade_steps
	for i in range(fade_steps + 1):
		var vol = clampf(i * 80.0 / fade_steps, 0.0, 80.0)
		_music_player.volume_db = linear_to_db(music_volume) - (80.0 - vol)
		await get_tree().create_timer(fade_step_time).timeout
	
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player_active = _music_player

## 停止当前 BGM（淡出）
func stop_music(fade_duration: float = 1.0) -> void:
	if _music_player and _music_player.playing:
		var fade_steps = 20
		var fade_step_time = fade_duration / fade_steps
		for i in range(fade_steps + 1):
			var vol = clampf(1.0 - i / fade_steps, 0.0, 1.0)
			_music_player.volume_db = linear_to_db(music_volume * vol)
			await get_tree().create_timer(fade_step_time).timeout
		_music_player.stop()
		_music_player.stream = null
		_current_bgm_name = ""

## 设置音乐音量
func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	if _music_player:
		_music_player.volume_db = linear_to_db(music_volume)

## 战斗结束回调：切回 hub BGM
func _on_battle_ended_bgm(player_won: bool) -> void:
	# 延迟一小段时间再切 BGM，让 win/lose SFX 先播放
	await get_tree().create_timer(0.5).timeout
	play_music("hub")

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

## T1 性能优化：命中音效最小间隔节流——原每次命中无条件重启同一 AudioStreamPlayer，
## 密集交火 + DOT tick 时每秒几十次音频重启（声音上也糊成一片）。
## 80ms 间隔下听觉无损失（人耳对同类短音效 12 次/秒已饱和）。
var _last_hit_sfx_msec: int = -10000
const HIT_SFX_MIN_INTERVAL_MSEC: int = 80

func _on_unit_damaged(_unit: Node, _is_player: bool, _amount: float, _at_position: Vector2) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_hit_sfx_msec < HIT_SFX_MIN_INTERVAL_MSEC:
		return
	_last_hit_sfx_msec = now
	play_sfx("hit")

func _on_battle_ended(player_won: bool) -> void:
	play_sfx("win" if player_won else "lose")


# v7.x 修复: 签名对齐 CardEnhancementManager.enhancement_completed(success, card_id, action, message)。
# 原声明第3参为 Dictionary（错配 String action），即使连接也会运行时报错；且从未 connect（死代码）。
# 由 _connect_enhancement_signal() 延迟连接（cem 为 lazy-load）。
# 2026-08-22 审计标注：此链路当前为死代码——v8.x 强化停用后 do_enhance 在
# card_enhancement_manager.gd:222 提前 return "强化系统已改为自动升级"，
# emit(:243) 不可达，本 handler 永不触发。保留是因 new_systems_integration
# 也监听同信号；若彻底移除强化管理器，连同本 handler/连接一起删。
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

# ── 初始 BGM ──

## 启动时播放标题 BGM（场景加载完成后调用）
func _play_initial_bgm() -> void:
	await get_tree().process_frame  # 等一帧确保播放器就绪
	play_music("title")
