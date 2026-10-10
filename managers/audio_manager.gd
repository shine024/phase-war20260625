extends Node
## 音效：按名称播放，资源缺失时静默跳过
## 可放置 res://assets/sfx/<name>.ogg（或 .wav），缺失时用 sound_generator 合成兜底
## 已接入音效见 SFX_NAMES；BGM 系统已实装（MusicPlayer + fade 切换）。
## 音效事件订阅见 _ready 末尾 connect 块。

const SoundGeneratorScript = preload("res://managers/sound_generator.gd")
const GameConstants = preload("res://resources/game_constants.gd")

var _players: Dictionary = {}
## v6.38（记录5#2/#3）：每音效名最多 3 个播放器轮转（round-robin）——旧实现一名一播放器，
## 同名重触发必截断前一响（核爆齐射 10 连 explosion 只剩最后一响的尾巴、密集枪战
## hit/shoot 互相吞）。_players[name] = Array[AudioStreamPlayer]。
const _PLAYERS_PER_NAME: int = 3
var _player_rr: Dictionary = {}  # name → 下一个使用的池下标
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
	# v27: 战斗反馈补强（音频=反馈系统；文件可后补，先落合成兜底）
	"ultimate_ready",   # 大招就绪（手动模式按钮亮起时的轻提示音）
	"base_alarm",       # 基地低血量告警
	"unit_death",       # v26.6: 单位阵亡（合成爆炸短音，sound_generator 已生成；接 unit_died 信号）
	"return_base",      # v6.38 记录5#5: 回基地转场音（世界地图→移动基地）
	"story_page",       # v6.54 记录6#2: 剧情漫画翻页/按钮提示音（纸感划擦，Kenney CC0）
]
const BUS_NAME: String = "Master"
const MUSIC_BUS: String = "Music"

## BGM 播放器（淡入淡出用）
var _music_player: AudioStreamPlayer = null
var _music_player_active: AudioStreamPlayer = null  # 用于交叉淡出的活跃播放器
var _current_bgm_name: String = ""

## BGM 映射表
## v6.52.2（记录1#7 工单案A）：hub 按时代五键——基地/大地图不再全时代共用一首。
## 文件未落地时 music_key_for_current_era() 回退 "hub"，接线先于资产零行为变化。
const BGM_MAP: Dictionary = {
	"title": "bgm_title",
	"hub": "bgm_hub",
	"hub_ww1": "bgm_hub_ww1",
	"hub_ww2": "bgm_hub_ww2",
	"hub_cold": "bgm_hub_cold",
	"hub_modern": "bgm_hub_modern",
	"hub_future": "bgm_hub_future",
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

# ── v32.0 B1-1: 极速推演期间的战斗音效压制（UI 白名单外静默，防 8x 下音效堆积）──
var battle_sfx_suppressed: bool = false
const _FF_SFX_ALLOWLIST: Array[String] = ["button", "button_hover", "panel_open", "panel_close", "error", "cancel"]

func set_battle_sfx_suppressed(on: bool) -> void:
	battle_sfx_suppressed = on

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# 初始化音效生成器作为备用
	if SoundGeneratorScript:
		_sound_generator = SoundGeneratorScript.new()
		add_child(_sound_generator)

	# v7.x 性能优化：启动时只建默认 button 播放器池（标题屏立即需要），
	# 其余 SFX 在首次 play_sfx 时按需 new + add_child（_ensure_player_pool）。
	# 原 _ready 一次性建 32 个 AudioStreamPlayer，启动期无谓节点创建。
	_ensure_player_pool("button")

	# 连接信号（is_connected 守卫防止重复注册）
	if SignalBus:
		if not SignalBus.unit_damaged.is_connected(_on_unit_damaged):
			SignalBus.unit_damaged.connect(_on_unit_damaged)
		# v26.6: 死亡音接线——unit_died 此前 5 个消费方无一播报，音效已生成但从未播放。
		if SignalBus.has_signal("unit_died") and not SignalBus.unit_died.is_connected(_on_unit_died):
			SignalBus.unit_died.connect(_on_unit_died)
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
		if SignalBus.has_signal("rune_acquired") and not SignalBus.rune_acquired.is_connected(_on_rune_acquired):
			SignalBus.rune_acquired.connect(_on_rune_acquired)
		if SignalBus.has_signal("faction_level_up") and not SignalBus.faction_level_up.is_connected(_on_faction_level_up):
			SignalBus.faction_level_up.connect(_on_faction_level_up)
		if SignalBus.has_signal("phase_field_level_up") and not SignalBus.phase_field_level_up.is_connected(_on_phase_field_level_up):
			SignalBus.phase_field_level_up.connect(_on_phase_field_level_up)
	# v27: 基地低血量告警——相位场驱动器完整度 ≤30% 播警示音（10s 重提醒，战斗开始复位）
	if SignalBus.has_signal("phase_driver_hp_changed") \
			and not SignalBus.phase_driver_hp_changed.is_connected(_on_phase_driver_hp_changed_alarm):
		SignalBus.phase_driver_hp_changed.connect(_on_phase_driver_hp_changed_alarm)
	if SignalBus.has_signal("battle_started") \
			and not SignalBus.battle_started.is_connected(_on_battle_started_reset_alarm):
		SignalBus.battle_started.connect(_on_battle_started_reset_alarm)
	# v7.x 修复: CardEnhancementManager.enhancement_completed 此前零订阅 + handler 签名错配（Dictionary vs String）。
	# 延迟到首次强化时连接（cem 是 lazy-load，启动时不一定就绪）。
	_connect_enhancement_signal()

	# v27: 全局按钮悬停音——所有 BaseButton 挂 mouse_entered（60ms 节流 + 低音量）。
	# 与 main.gd 手型光标钩子同构：那是视觉反馈，这是听觉反馈（ui-review 易用性：可交互处多状态）。
	# 挂在 autoload 上而非 main.gd，覆盖标题屏等所有场景。
	# 批次1（拼凑感修复）：同一钩子补挂 pressed → 点击音，覆盖全部无点击音面板
	#（faction/achievement/collection/settings/help/intelligence_hub 等内部按钮此前全哑）。
	if not get_tree().node_added.is_connected(_on_node_added_ui_sfx):
		get_tree().node_added.connect(_on_node_added_ui_sfx)

	# 初始化 BGM 系统
	_init_music_player()

## P0 性能优化：退出时断开所有 SignalBus 连接并释放播放器，
## 防止场景切换后信号连接累积（原无任何清理，长时间游玩 GC 压力持续增长）
func _exit_tree() -> void:
	if SignalBus:
		if SignalBus.unit_damaged.is_connected(_on_unit_damaged):
			SignalBus.unit_damaged.disconnect(_on_unit_damaged)
		if SignalBus.has_signal("unit_died") and SignalBus.unit_died.is_connected(_on_unit_died):
			SignalBus.unit_died.disconnect(_on_unit_died)
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
		if SignalBus.has_signal("rune_acquired") and SignalBus.rune_acquired.is_connected(_on_rune_acquired):
			SignalBus.rune_acquired.disconnect(_on_rune_acquired)
		if SignalBus.has_signal("faction_level_up") and SignalBus.faction_level_up.is_connected(_on_faction_level_up):
			SignalBus.faction_level_up.disconnect(_on_faction_level_up)
		if SignalBus.has_signal("phase_field_level_up") and SignalBus.phase_field_level_up.is_connected(_on_phase_field_level_up):
			SignalBus.phase_field_level_up.disconnect(_on_phase_field_level_up)
		# v27: 基地告警 + 悬停音钩子
		if SignalBus.has_signal("phase_driver_hp_changed") and SignalBus.phase_driver_hp_changed.is_connected(_on_phase_driver_hp_changed_alarm):
			SignalBus.phase_driver_hp_changed.disconnect(_on_phase_driver_hp_changed_alarm)
		if SignalBus.has_signal("battle_started") and SignalBus.battle_started.is_connected(_on_battle_started_reset_alarm):
			SignalBus.battle_started.disconnect(_on_battle_started_reset_alarm)
		if get_tree().node_added.is_connected(_on_node_added_ui_sfx):
			get_tree().node_added.disconnect(_on_node_added_ui_sfx)
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
		var pool: Variant = _players.get(p_name)
		if pool is Array:
			for p in pool:
				if p is Node and is_instance_valid(p):
					p.queue_free()
		elif _players.get(p_name) is Node and is_instance_valid(_players.get(p_name)):
			(_players.get(p_name) as Node).queue_free()
	_players.clear()
	_player_rr.clear()

## 播放音效
## v8.3: 增加 volume（0.0~1.0，线性→db）和 pitch（0.5~2.0，音高倍率）参数（默认值保证旧调用零变化）
func play_sfx(name: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	if name.is_empty():
		return

	# v32.0 B1-1: 极速推演期间战斗音效静默（UI 白名单放行；结算音在推演结束后才触发）
	if battle_sfx_suppressed and not (name in _FF_SFX_ALLOWLIST):
		return

	# 批次1: "button" 点击音 50ms 去重——全局钩子与 ~65 处手写调用并存，
	# 同一次点击（含 50ms 内的极快连点）只响一次，防双响/机关枪
	if name == "button":
		var now_msec := Time.get_ticks_msec()
		if now_msec - _last_button_sfx_msec < BUTTON_SFX_MIN_INTERVAL_MSEC:
			return
		_last_button_sfx_msec = now_msec

	# v6.38：按名取轮转池（无则懒建 3 播放器），同名连发在池内轮转不截断
	var pool: Array = _players.get(name, [])
	if pool.is_empty():
		pool = _ensure_player_pool(name)
	if pool.is_empty():
		# 极端兜底：池创建失败则放弃
		return
	var idx: int = int(_player_rr.get(name, 0)) % pool.size()
	_player_rr[name] = idx + 1
	var p: AudioStreamPlayer = pool[idx]
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

## v7.x: 按需创建播放器池并加入场景树（懒扩展）。
## v6.38（记录5#2/#3）：一名一播放器改 3 池轮转——同名连发（核爆齐射/密集枪战）
## 不再截断前一响。返回空数组的唯一情形是极端创建失败。
func _ensure_player_pool(name: String) -> Array:
	var pool: Array = _players.get(name, [])
	if not pool.is_empty():
		return pool
	for i in _PLAYERS_PER_NAME:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_NAME
		p.volume_db = linear_to_db(sfx_volume)
		add_child(p)
		pool.append(p)
	if pool.is_empty():
		return []
	_players[name] = pool
	_player_rr[name] = 0
	return pool

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
	for v in _players.values():
		if v is Array:
			for p in v:
				if p is AudioStreamPlayer:
					(p as AudioStreamPlayer).volume_db = linear_to_db(sfx_volume)
		elif v is AudioStreamPlayer:
			(v as AudioStreamPlayer).volume_db = linear_to_db(sfx_volume)

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
	# v32.0 演出层：战场环境音起
	play_ambient("battle_wind")

## v6.52.2（记录1#7 工单案A）：按当前战线时代取 hub 音乐键——大地图/移动基地
## 不再全时代共用一首。时代曲文件未落地（资产分批换）时回退 "hub" 单曲，
## 接线先于资产零行为变化。PlayerA/temp 探针/无 GameManager 场景同样回退。
func music_key_for_current_era() -> String:
	var key := "hub"
	if GameManager:
		var era: int = GameConstants.get_era_for_level(int(GameManager.current_level))
		match era:
			GameConstants.Era.WW1: key = "hub_ww1"
			GameConstants.Era.WW2: key = "hub_ww2"
			GameConstants.Era.COLD_WAR: key = "hub_cold"
			GameConstants.Era.MODERN: key = "hub_modern"
			GameConstants.Era.NEAR_FUTURE: key = "hub_future"
	if key != "hub":
		var fname: String = String(BGM_MAP.get(key, ""))
		if fname.is_empty() or not ResourceLoader.exists("res://assets/sfx/%s.ogg" % fname):
			key = "hub"
	return key

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
	# v27: BGM 循环——8 首 bgm_*.ogg 的 .import 均 loop=false（导入期遗留），
	# 每首放完一次即永久静音。此处运行时置 loop（load() 返回共享缓存资源，置位一次即持久）；
	# .import 文件已同步改 loop=true 作源头对齐（下次重导入后两边一致）。
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	
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

## v6.38（记录5#4）：淡出并停掉当前 BGM（记录 _current_bgm_name 复位，下次 play_music 正常起播）。
## 开场苏醒演出用它让位给雪原风声环境音；演出收场再进基地曲。
func stop_music(fade_sec: float = 1.2) -> void:
	_current_bgm_name = ""
	if _music_player == null or not _music_player.playing:
		return
	if _music_player_active == _music_player:
		_music_player_active = null
	var player := _music_player
	if fade_sec <= 0.0:
		player.stop()
		player.stream = null
		return
	var tw := create_tween()
	tw.tween_property(player, "volume_db", -60.0, fade_sec)
	tw.tween_callback(func():
		player.stop()
		player.stream = null
	)

## 设置音乐音量
func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	if _music_player:
		_music_player.volume_db = linear_to_db(music_volume)

## 战斗结束回调：切回 hub BGM
func _on_battle_ended_bgm(player_won: bool) -> void:
	# 延迟一小段时间再切 BGM，让 win/lose SFX 先播放
	await get_tree().create_timer(0.5).timeout
	# v6.56 记录1#2（用户拍板"复用现有曲"）：黑门无限 run 的战斗结束切 boss 曲驻留
	# （原硬编码回 hub——黑门域没有 hub 概念，口型不符）；L100 胜利后结局独白段切
	# title 曲（原独白零配乐）。其余战原著回 hub。
	var ebm: Node = get_node_or_null("/root/EndlessBlackgateManager")
	if ebm != null and bool(ebm.get("run_active")):
		play_music("boss")
	elif player_won and GameManager != null and int(GameManager.get("current_level")) >= 100:
		play_music("title")
	else:
		play_music("hub")
	# v32.0 演出层：战场环境音收（延迟同 BGM，让胜负音先出）
	stop_ambient(1.5)

# ── v32.0 演出层：战场环境音（持续氛围底噪，独立于 BGM/事件 SFX 层）──
## battle_started 起 battle_wind 风声循环（含远炮闷响），battle_ended 淡出。
## 音量独立线性参数；极速推演期间不停（底噪无事件堆积问题）。
var _ambient_player: AudioStreamPlayer = null
## v6.42: wakeup_wind=苏醒演出专用柔化雪原风声（与战斗氛围 battle_wind 分离）
const AMBIENT_MAP: Dictionary = {
	"battle_wind": "ambient_battle_wind",
	"wakeup_wind": "ambient_wakeup_wind",
}
const AMBIENT_DEFAULT_LINEAR: float = 0.22

func play_ambient(key: String, linear_volume: float = AMBIENT_DEFAULT_LINEAR) -> void:
	var file_name: String = String(AMBIENT_MAP.get(key, ""))
	if file_name.is_empty():
		return
	if _ambient_player == null:
		_ambient_player = AudioStreamPlayer.new()
		add_child(_ambient_player)
	if _ambient_player.get_meta("ambient_key", "") == key and _ambient_player.playing:
		return
	var stream: AudioStream = load("res://assets/sfx/%s.wav" % file_name)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2  # 16-bit 单声道帧数
	_ambient_player.set_meta("ambient_key", key)
	_ambient_player.stream = stream
	_ambient_player.volume_db = linear_to_db(clampf(linear_volume, 0.0, 1.0))
	_ambient_player.play()

func stop_ambient(fade_sec: float = 1.0) -> void:
	if _ambient_player == null or not _ambient_player.playing:
		return
	if fade_sec <= 0.0:
		_ambient_player.stop()
		return
	var base_db: float = linear_to_db(AMBIENT_DEFAULT_LINEAR)
	var tw := create_tween()
	tw.tween_property(_ambient_player, "volume_db", -60.0, fade_sec)
	tw.tween_callback(func():
		_ambient_player.stop()
		_ambient_player.volume_db = base_db)

## T1 性能优化：命中音效最小间隔节流——原每次命中无条件重启同一 AudioStreamPlayer，
## 密集交火 + DOT tick 时每秒几十次音频重启（声音上也糊成一片）。
## 80ms 间隔下听觉无损失（人耳对同类短音效 12 次/秒已饱和）。
var _last_hit_sfx_msec: int = -10000
const HIT_SFX_MIN_INTERVAL_MSEC: int = 80

## v6.52（记录1#3，用户主诉"发射/击中的音效不好，前边让改过实际根本就没改"）：
## v6.42 的力度分级只覆盖了开火音与 bullet.gd 兜底命中——batch 主力路径的命中
## 恒播通用 "hit"（手枪弹与重炮弹同声）。现按本次伤害分三档：
##   轻击 <60  → impact_light（轻动能）
##   中击 <150 → hit（通用）
##   重击 ≥150 → impact_heavy（重炮/爆炸级）
## 阈值口径：单发直射轻武器几十、重炮对甲 200+（实机自行火炮 20 vs 280 量级差）。
func _on_unit_damaged(_unit: Node, _is_player: bool, amount: float, _at_position: Vector2) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_hit_sfx_msec < HIT_SFX_MIN_INTERVAL_MSEC:
		return
	_last_hit_sfx_msec = now
	if amount >= 150.0:
		play_sfx("impact_heavy")
	elif amount >= 60.0:
		play_sfx("hit")
	else:
		play_sfx("impact_light")

## v26.6: 死亡音——此前 unit_died 信号 5 个消费方（battle_manager/new_systems/quest 等）
## 无一播报，"unit_death" 合成音效在 sound_generator 已生成却从未播放。120ms 节流
## 防团灭/AOE 团杀瞬间同帧几十次触发糊成一片。
var _last_death_sfx_msec: int = -10000
const DEATH_SFX_MIN_INTERVAL_MSEC: int = 120

func _on_unit_died(_unit: Node, _is_player: bool) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_death_sfx_msec < DEATH_SFX_MIN_INTERVAL_MSEC:
		return
	_last_death_sfx_msec = now
	play_sfx("unit_death")

func _on_battle_ended(player_won: bool) -> void:
	play_sfx("win" if player_won else "lose")

# v7.x 修复: 签名对齐 CardEnhancementManager.enhancement_completed(success, card_id, action, message)。
# 原声明第3参为 Dictionary（错配 String action），即使连接也会运行时报错；且从未 connect（死代码）。
# 由 _connect_enhancement_signal() 延迟连接（cem 为 lazy-load）。
# 2026-09-02 勘误：上方 2026-08-22"死代码"标注已过时——v20.12 等级统一后教学任务
# 改升级驱动，card_enhancement_manager._on_card_level_up 会转发 emit 本信号（:244），
# handler 现真实触发（升级成功播 enhance / 失败播 cancel）。保留 lazy 连接不变。
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
func _on_boss_wave_started(wave_kind: String, _boss_ids: Array) -> void:
	# v6.35: 精英波不吹警笛（每 5 波一响过频），首领/本体波保留 boss_warn
	if wave_kind != "elite":
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
func _on_rune_acquired(_rune_id: String, _source: String) -> void:
	play_sfx("blueprint_unlock")
func _on_faction_level_up(_faction_id: String, _new_level: int) -> void:
	play_sfx("achievement")
func _on_phase_field_level_up(_old: int, _new: int, _unspent: int) -> void:
	play_sfx("enhance")

# ── v27: 全局按钮悬停音（ui-review 易用性：可交互处听觉反馈，与手型光标成对） ──
var _last_hover_sfx_msec: int = -10000
const HOVER_SFX_MIN_INTERVAL_MSEC: int = 60
const HOVER_SFX_VOLUME: float = 0.35

# ── 批次1: 全局按钮点击音（与悬停音同构挂 node_added → BaseButton.pressed）──
# 既有 ~65 处手写 _play_sfx("button") 保留不删（少数在非按钮 gui_input 路径上，
# 删了会哑）；play_sfx 内对 "button" 做 50ms 窗口去重——钩子与手写谁先触发都只响一次。
var _last_button_sfx_msec: int = -10000
const BUTTON_SFX_MIN_INTERVAL_MSEC: int = 50

func _on_node_added_ui_sfx(node: Node) -> void:
	if node is BaseButton:
		if not node.mouse_entered.is_connected(_on_button_hovered):
			node.mouse_entered.connect(_on_button_hovered.bind(node))
		if not node.pressed.is_connected(_on_button_clicked_sfx):
			node.pressed.connect(_on_button_clicked_sfx)
		# 批次2：按压微动效（视觉反馈也走这唯一全局钩子，PanelAnim 承担行为）
		PanelAnim.attach_press_feedback(node)
		return
	# v6.56 记录1#3：TabBar 切标签音——TabBar 不是 BaseButton，吃不到 pressed 钩子
	# （背包/情报等切标签界面此前静默）；一处生效全项目所有切标签界面。
	if node is TabBar:
		if not node.tab_changed.is_connected(_on_tabbar_tab_changed):
			node.tab_changed.connect(_on_tabbar_tab_changed)

func _on_tabbar_tab_changed(_tab: int) -> void:
	play_sfx("button")

func _on_button_clicked_sfx() -> void:
	play_sfx("button")

func _on_button_hovered(btn: BaseButton) -> void:
	if btn == null or not is_instance_valid(btn) or btn.disabled:
		return
	# 节流：快速划过列表时 60ms 内只响一次，低音量不与点击音争
	var now: int = Time.get_ticks_msec()
	if now - _last_hover_sfx_msec < HOVER_SFX_MIN_INTERVAL_MSEC:
		return
	_last_hover_sfx_msec = now
	play_sfx("button_hover", HOVER_SFX_VOLUME)

# ── v27: 基地低血量告警（≤30% 触发，10s 重提醒，战斗开始复位） ──
const BASE_ALARM_RATIO: float = 0.30
const BASE_ALARM_REMIND_MSEC: int = 10000
var _last_base_alarm_msec: int = -100000

func _on_phase_driver_hp_changed_alarm(current: float, maximum: float) -> void:
	if maximum <= 0.0 or current / maximum > BASE_ALARM_RATIO:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_base_alarm_msec < BASE_ALARM_REMIND_MSEC:
		return
	_last_base_alarm_msec = now
	play_sfx("base_alarm", 0.8)

func _on_battle_started_reset_alarm() -> void:
	_last_base_alarm_msec = -100000

# ── 初始 BGM ──

## 启动时播放标题 BGM（场景加载完成后调用）
func _play_initial_bgm() -> void:
	await get_tree().process_frame  # 等一帧确保播放器就绪
	play_music("title")
