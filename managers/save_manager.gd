extends Node
## 存档管理：读写 save.json，协调 BlueprintManager / PhaseInstrumentManager / 背包 状态
## 写入固定为 user://save.json；读取优先该文件，再兼容旧版（项目根 / 旧 user 路径），避免仓库内 res 存档遮挡真存档
## ─── 预加载提取模块 ───
const SaveConstants = preload("res://scripts/systems/save_constants.gd")
const SaveMigration = preload("res://scripts/systems/save_migration.gd")
const IntelManualItems = preload("res://data/intel_manual_items.gd")
var DEBUG_SAVE_LOG := false

var _pending_backpack_ids: Array = []
var _is_exiting: bool = false
var _is_saving: bool = false
var _exit_save_done: bool = false
var _save_deferred_pending: bool = false
var _last_save_ms: int = 0
var _last_backup_ms: int = 0
var _save_dirty_during_battle: bool = false
var _battle_end_save_hooked: bool = false
var _backpack_signal_hooked: bool = false
## 兜底：上次成功保存时的额外卡ID列表（背包面板不可用时使用）
var _last_known_extra_ids: Array = []



var _slot_info_cache: Array = []
var _slot_info_cache_valid: bool = false
var _noncritical_save_cache: Dictionary = {}
var _last_noncritical_save_ms: int = 0

## 多存档位支持
var current_slot: int = 1
const MAX_SLOTS := 3

const SAVE_FILE_USER := "user://save.json"
const SAVE_FILE_BACKUP := "user://save_backup.json"
const SAVE_FILE_TEMP := "user://save.json.tmp"
const SAVE_SCHEMA_VERSION := 5
const SAVE_MIN_INTERVAL_MS := 1200
const SAVE_BACKUP_INTERVAL_MS := 15000
const NONCRITICAL_SAVE_INTERVAL_MS := 10000
## 读档性能优化：默认使用轻量校验，减少 continue 卡顿。
const ENABLE_DETAILED_LOAD_VALIDATION := false
const DEFERRED_LOAD_BATCH_SIZE := 5
const CRITICAL_MANAGER_LOADS: Array = [
	["/root/BlueprintManager", "blueprint"],
	["/root/PhaseInstrumentManager", "phase_instrument"],
	["/root/PhaseLawManager", "phase_law"],
	["/root/QuestManager", "quest"],
	["/root/BasicResourceManager", "basic_resources"],
	["/root/FactionSystemManager", "faction_system"],
	["/root/AffixManager", "affix_data"],
	["/root/LevelProgressManager", "level_progress"],
	["/root/DropManager", "drop_manager"],
	["/root/IntelItemBag", "intel_item_bag"],
]
const DEFERRED_MANAGER_LOADS: Array = [
	["/root/LoreManager", "lore"],
	["/root/StatBoostManager", "stat_boost"],
	["/root/AchievementManager", "achievement"],
	["/root/DailyTaskManager", "daily_task"],
	["/root/StatisticsManager", "statistics"],
	["/root/CardEnhancementManager", "card_enhancement"],
	["/root/TutorialProgressionManager", "tutorial_progress"],
	["/root/StoryManager", "story_progress"],
	["/root/CharacterManager", "characters"],
	["/root/ChallengeModeManager", "challenge_records"],
	["/root/CardCollectionManager", "card_collection"],
	["/root/LeaderboardManager", "leaderboard"],
]
const CRITICAL_RESETTABLE_MANAGERS: Array[String] = [
	"BlueprintManager",
	"PhaseInstrumentManager",
	"PhaseLawManager",
	"QuestManager",
	"BasicResourceManager",
	"FactionSystemManager",
	"AffixManager",
	"LevelProgressManager",
	"IntelItemBag",
]
const DEFERRED_RESET_BATCH_SIZE := 4

const RESETTABLE_MANAGERS := [
	"BlueprintManager",
	"PhaseInstrumentManager",
	"PhaseLawManager",
	"QuestManager",
	"BasicResourceManager",
	"FactionSystemManager",
	"AffixManager",
	"LevelProgressManager",
	"LoreManager",
	"StatBoostManager",
	"CardEnhancementManager",
	"TutorialProgressionManager",
	"StoryManager",
	"CharacterManager",
	"ChallengeModeManager",
	"CardCollectionManager",
	"IntelItemBag",
]

## ─── 存档数据键名常量（别名，定义见 scripts/systems/save_constants.gd）───
const SK_SCHEMA_VERSION: String = SaveConstants.SK_SCHEMA_VERSION
const SK_BLUEPRINT: String = SaveConstants.SK_BLUEPRINT
const SK_BASIC_RESOURCES: String = SaveConstants.SK_BASIC_RESOURCES
const SK_PHASE_LAW: String = SaveConstants.SK_PHASE_LAW
const SK_QUEST: String = SaveConstants.SK_QUEST
const SK_FACTION_SYSTEM: String = SaveConstants.SK_FACTION_SYSTEM
const SK_AFFIX_DATA: String = SaveConstants.SK_AFFIX_DATA
const SK_LEVEL_PROGRESS: String = SaveConstants.SK_LEVEL_PROGRESS
const SK_DROP_MANAGER: String = SaveConstants.SK_DROP_MANAGER
const SK_INTEL_ITEM_BAG: String = "intel_item_bag"
const SK_GAME: String = SaveConstants.SK_GAME
const SK_CURRENT_LEVEL: String = SaveConstants.SK_CURRENT_LEVEL
const SK_PHASE_SLOTS: String = SaveConstants.SK_PHASE_SLOTS
const SK_PHASE_SLOTS_ORDER: String = SaveConstants.SK_PHASE_SLOTS_ORDER
const SK_PHASE_INSTRUMENT: String = SaveConstants.SK_PHASE_INSTRUMENT
const SK_BACKPACK_EXTRA_IDS: String = SaveConstants.SK_BACKPACK_EXTRA_IDS
const SK_LORE: String = SaveConstants.SK_LORE
const SK_STAT_BOOST: String = SaveConstants.SK_STAT_BOOST
const SK_ACHIEVEMENT: String = SaveConstants.SK_ACHIEVEMENT
const SK_DAILY_TASK: String = SaveConstants.SK_DAILY_TASK
const SK_STATISTICS: String = SaveConstants.SK_STATISTICS
const SK_CARD_ENHANCEMENT: String = SaveConstants.SK_CARD_ENHANCEMENT
const SK_LAW_SHARDS: String = SaveConstants.SK_LAW_SHARDS
const SK_TUTORIAL_PROGRESS: String = SaveConstants.SK_TUTORIAL_PROGRESS
const SK_STORY_PROGRESS: String = SaveConstants.SK_STORY_PROGRESS
const SK_CHARACTERS: String = SaveConstants.SK_CHARACTERS
const SK_CHALLENGE_RECORDS: String = SaveConstants.SK_CHALLENGE_RECORDS
const SK_CARD_COLLECTION: String = SaveConstants.SK_CARD_COLLECTION
const SK_LEADERBOARD: String = SaveConstants.SK_LEADERBOARD
const SK_LEGACY_COMPANY_REP: String = SaveConstants.SK_LEGACY_COMPANY_REP

var _deferred_load_data: Dictionary = {}
var _deferred_manager_queue: Array = []
var _deferred_reset_queue: Array[String] = []
var _load_game_perf_pending: bool = false
var _start_new_game_perf_pending: bool = false
var _load_game_parse_phase_open: bool = false
var _load_game_critical_phase_open: bool = false
var _load_game_deferred_phase_open: bool = false

func _ready() -> void:
	_sync_debug_log_flag()
	_ensure_battle_end_save_hook()
	_ensure_backpack_signal_hook()
	# 部分启动序下 SignalBus 可能晚于本节点就绪，下一帧重试一次挂钩。
	call_deferred("_ensure_backpack_signal_hook")

func _sync_debug_log_flag() -> void:
	var debug_mgr: Node = get_node_or_null("/root/DebugLogManager")
	if debug_mgr != null and debug_mgr.has_method("is_channel_enabled"):
		DEBUG_SAVE_LOG = bool(debug_mgr.is_channel_enabled("save_manager", DEBUG_SAVE_LOG))

func _perf_phase_begin(phase_name: String) -> void:
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("begin_phase"):
		PerformanceMetricsManager.begin_phase(phase_name)

func _perf_phase_end(phase_name: String) -> void:
	if PerformanceMetricsManager and PerformanceMetricsManager.has_method("end_phase"):
		PerformanceMetricsManager.end_phase(phase_name)

func _finalize_load_game_perf_on_fail() -> void:
	if _load_game_parse_phase_open:
		_load_game_parse_phase_open = false
		_perf_phase_end("load_game_parse_json")
	if _load_game_critical_phase_open:
		_load_game_critical_phase_open = false
		_perf_phase_end("load_game_critical_managers")
	if _load_game_deferred_phase_open:
		_load_game_deferred_phase_open = false
		_perf_phase_end("load_game_deferred_managers")
	if _load_game_perf_pending:
		_load_game_perf_pending = false
		_perf_phase_end("load_game")

func _ensure_battle_end_save_hook() -> void:
	if _battle_end_save_hooked:
		return
	if SignalBus and SignalBus.has_signal("battle_ended"):
		if not SignalBus.battle_ended.is_connected(_on_battle_ended_flush_save):
			SignalBus.battle_ended.connect(_on_battle_ended_flush_save)
		_battle_end_save_hooked = true

func _ensure_backpack_signal_hook() -> void:
	if _backpack_signal_hooked:
		return
	if SignalBus == null:
		return
	if SignalBus.has_signal("card_added_to_backpack"):
		if not SignalBus.card_added_to_backpack.is_connected(_on_card_added_to_backpack_fallback):
			SignalBus.card_added_to_backpack.connect(_on_card_added_to_backpack_fallback)
	if SignalBus.has_signal("card_equipped"):
		if not SignalBus.card_equipped.is_connected(_on_card_equipped_remove_fallback):
			SignalBus.card_equipped.connect(_on_card_equipped_remove_fallback)
	_backpack_signal_hooked = true

func _on_card_added_to_backpack_fallback(card: CardResource) -> void:
	if card == null:
		return
	var cid: String = String(card.card_id)
	if cid.is_empty():
		return
	enqueue_backpack_card_id(cid)

func _on_card_equipped_remove_fallback(_slot_index: int, card_id: String, _card_type: String) -> void:
	if card_id.is_empty():
		return
	var idx_pending: int = _pending_backpack_ids.find(card_id)
	if idx_pending >= 0:
		_pending_backpack_ids.remove_at(idx_pending)
	var idx_last: int = _last_known_extra_ids.find(card_id)
	if idx_last >= 0:
		_last_known_extra_ids.remove_at(idx_last)

## 背包懒加载兜底：在未实例化背包面板时，也可先把新增卡加入 pending 队列。
func enqueue_backpack_card_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	_pending_backpack_ids.append(card_id)
	_last_known_extra_ids.append(card_id)

func _is_battle_active_now() -> bool:
	if BattleManager == null:
		return false
	return BattleManager.get("battle_active") == true

func _on_battle_ended_flush_save(_player_won: bool) -> void:
	if not _save_dirty_during_battle:
		return
	_save_dirty_during_battle = false
	# 结算链较重，稍延后一帧/短延时落盘，避开战斗结束同帧尖峰。
	var tree := get_tree()
	if tree == null:
		return
	var t := tree.create_timer(0.2)
	t.timeout.connect(func() -> void:
		if not _is_saving:
			save_game()
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_is_exiting = true

func _exit_tree() -> void:
	_is_exiting = true

func _user_save_byte_size() -> int:
	if not FileAccess.file_exists(SAVE_FILE_USER):
		return -1
	var rf: FileAccess = FileAccess.open(SAVE_FILE_USER, FileAccess.READ)
	if rf == null:
		return -1
	var n: int = int(rf.get_length())
	rf.close()
	return n

func _remove_file_at_user(virtual_path: String) -> void:
	if not FileAccess.file_exists(virtual_path):
		return
	var abs_path: String = ProjectSettings.globalize_path(virtual_path)
	var e: Error = DirAccess.remove_absolute(abs_path)
	if e != OK:
		push_warning("[SaveManager] 删除 %s 失败 (错误码 %s)" % [abs_path, e])

func _get_legacy_res_save_path() -> String:
	return ProjectSettings.globalize_path("res://") + "save.json"

func _get_legacy_user_save_path() -> String:
	return OS.get_user_data_dir().path_join("save.json")

## 获取指定存档位的主文件路径
func _slot_file(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

func _slot_backup_file(slot: int) -> String:
	return "user://save_slot_%d_backup.json" % slot

func _slot_temp_file(slot: int) -> String:
	return "user://save_slot_%d.json.tmp" % slot

## 获取当前存档位的文件路径（兼容旧单存档）
func _current_save_file() -> String:
	return _slot_file(current_slot)

func _current_backup_file() -> String:
	return _slot_backup_file(current_slot)

func _current_temp_file() -> String:
	return _slot_temp_file(current_slot)

## 设置当前存档位
func set_slot(slot: int) -> void:
	current_slot = clampi(slot, 1, MAX_SLOTS)
	if DEBUG_SAVE_LOG:
		pass  # LOG: 切换到存档位

## 获取当前存档位
func get_slot() -> int:
	return current_slot

## 获取所有存档位的信息（是否存在、关卡）
func get_slot_info() -> Array:
	if _slot_info_cache_valid:
		return _slot_info_cache.duplicate(true)
	var info: Array = []
	for slot_num in range(1, MAX_SLOTS + 1):
		var slot_data: Dictionary = {"slot": slot_num, "exists": false, "level": 0}
		var path := _slot_file(slot_num)
		var backup_path := _slot_backup_file(slot_num)
		var read_path := ""
		if FileAccess.file_exists(path):
			slot_data["exists"] = true
			read_path = path
		# 主档不存在时，继续识别备份档（与 load_game 实际兜底保持一致）
		elif FileAccess.file_exists(backup_path):
			slot_data["exists"] = true
			read_path = backup_path
		# 兼容旧单存档（slot 1）
		if slot_num == 1 and not slot_data["exists"] and FileAccess.file_exists(SAVE_FILE_USER):
			slot_data["exists"] = true
			read_path = SAVE_FILE_USER
		if not read_path.is_empty():
			var f := FileAccess.open(read_path, FileAccess.READ)
			if f:
				var json := JSON.new()
				if json.parse(f.get_as_text()) == OK:
					var data = json.get_data()
					if data is Dictionary and data.has(SK_GAME):
						var gd: Dictionary = data[SK_GAME]
						if gd.has(SK_CURRENT_LEVEL):
							slot_data["level"] = int(gd[SK_CURRENT_LEVEL])
					f.close()
		info.append(slot_data)
	_slot_info_cache = info.duplicate(true)
	_slot_info_cache_valid = true
	return info

## 将旧单存档迁移到存档位 1（仅在 slot 1 为空且旧存档存在时执行）
func _migrate_old_save_if_needed() -> void:
	var slot1_path := _slot_file(1)
	if FileAccess.file_exists(slot1_path):
		return  # slot 1 已有存档，不迁移
	if not FileAccess.file_exists(SAVE_FILE_USER):
		return  # 无旧存档可迁移
	var old_f := FileAccess.open(SAVE_FILE_USER, FileAccess.READ)
	if old_f == null:
		return
	var content := old_f.get_as_text()
	old_f.close()
	# 读取并校验
	var json := JSON.new()
	if json.parse(content) != OK:
		return
	var data = json.get_data()
	if not data is Dictionary:
		return
	# 写入 slot 1
	var new_f := FileAccess.open(slot1_path, FileAccess.WRITE)
	if new_f:
		new_f.store_string(content)
		new_f.close()
		_slot_info_cache_valid = false
		if DEBUG_SAVE_LOG:
			pass  # LOG: 已迁移旧存档

func _resolve_read_save_path() -> String:
	# 优先当前存档位
	var slot_path := _current_save_file()
	if FileAccess.file_exists(slot_path):
		return slot_path
	# slot 1 兼容旧单存档
	if current_slot == 1 and FileAccess.file_exists(SAVE_FILE_USER):
		return SAVE_FILE_USER
	var res_p := _get_legacy_res_save_path()
	if FileAccess.file_exists(res_p):
		return res_p
	var leg_u := _get_legacy_user_save_path()
	if FileAccess.file_exists(leg_u):
		return leg_u
	return ""

func has_save() -> bool:
	_migrate_old_save_if_needed()
	return _resolve_read_save_path() != ""

## 检查指定存档位是否有存档
func has_save_slot(slot: int) -> bool:
	var path := _slot_file(slot)
	if FileAccess.file_exists(path):
		return true
	if slot == 1 and FileAccess.file_exists(SAVE_FILE_USER):
		return true
	return false

## 自动备份当前存档
func _backup_current_save() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if not _is_exiting and now_ms - _last_backup_ms < SAVE_BACKUP_INTERVAL_MS:
		return
	var cur := _current_save_file()
	if not FileAccess.file_exists(cur):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("[SaveManager] 无法打开user://目录进行备份")
		return
	var backup := _current_backup_file()
	if dir.copy(cur, backup) != OK:
		push_warning("[SaveManager] 存档备份失败")
	else:
		_last_backup_ms = now_ms
		if DEBUG_SAVE_LOG:
			pass  # LOG: 已创建存档备份

func _schedule_deferred_save() -> void:
	if _save_deferred_pending:
		return
	_save_deferred_pending = true
	var delay_sec: float = maxf(0.1, float(SAVE_MIN_INTERVAL_MS) / 1000.0)
	var tree := get_tree()
	if tree == null:
		_save_deferred_pending = false
		return
	var timer := tree.create_timer(delay_sec)
	timer.timeout.connect(func() -> void:
		_save_deferred_pending = false
		if not _is_saving:
			save_game()
	)

func _find_backpack_panel() -> Node:
	var paths: Array[String] = [
		"/root/Main/PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/BackpackPanel",
		"/root/Main/PopupLayer/BackpackOverlay/BackpackVBox/CenterRow/BackpackCenter/backpack_panel",
		"/root/Main/PrepPanel/RootMargin/HBox/BackpackArea/Margin/VBox/BackpackScroll/BackpackPanel",
		"/root/Main/PrepPanel/BackpackArea/Margin/VBox/BackpackScroll/BackpackPanel",
	]
	for p in paths:
		var n: Node = get_node_or_null(p)
		if n != null and n.has_method("get_extra_card_ids"):
			return n
	return null

func _collect_manager_state(data: Dictionary, node_path: String, data_key: String) -> void:
	var mgr: Node = get_node_or_null(node_path)
	if mgr != null and mgr.has_method("save_state"):
		data[data_key] = mgr.save_state()

func _collect_noncritical_save_data(data: Dictionary, now_ms: int) -> void:
	var should_refresh: bool = _is_exiting or _noncritical_save_cache.is_empty() or (now_ms - _last_noncritical_save_ms >= NONCRITICAL_SAVE_INTERVAL_MS)
	if should_refresh:
		var fresh: Dictionary = {}
		_collect_manager_state(fresh, "/root/LoreManager", SK_LORE)
		_collect_manager_state(fresh, "/root/StatBoostManager", SK_STAT_BOOST)
		_collect_manager_state(fresh, "/root/AchievementManager", SK_ACHIEVEMENT)
		_collect_manager_state(fresh, "/root/DailyTaskManager", SK_DAILY_TASK)
		_collect_manager_state(fresh, "/root/StatisticsManager", SK_STATISTICS)
		_collect_manager_state(fresh, "/root/CardEnhancementManager", SK_CARD_ENHANCEMENT)
		_collect_manager_state(fresh, "/root/TutorialProgressionManager", SK_TUTORIAL_PROGRESS)
		_collect_manager_state(fresh, "/root/StoryManager", SK_STORY_PROGRESS)
		_collect_manager_state(fresh, "/root/CharacterManager", SK_CHARACTERS)
		_collect_manager_state(fresh, "/root/ChallengeModeManager", SK_CHALLENGE_RECORDS)
		_collect_manager_state(fresh, "/root/CardCollectionManager", SK_CARD_COLLECTION)
		_collect_manager_state(fresh, "/root/LeaderboardManager", SK_LEADERBOARD)
		_noncritical_save_cache = fresh
		_last_noncritical_save_ms = now_ms
	for key in _noncritical_save_cache.keys():
		data[key] = _noncritical_save_cache[key]

func _reset_manager_by_name(manager_name: String) -> void:
	var mgr: Node = get_node_or_null("/root/" + manager_name)
	if mgr == null:
		return
	if mgr.has_method("clear_all"):
		mgr.clear_all()
	elif mgr.has_method("reset_to_defaults"):
		mgr.reset_to_defaults()
	elif mgr.has_method("reset_progress"):
		mgr.reset_progress()
	elif mgr.has_method("load_state"):
		mgr.load_state({})

func _schedule_deferred_manager_resets() -> void:
	_deferred_reset_queue.clear()
	for manager_name in RESETTABLE_MANAGERS:
		if not CRITICAL_RESETTABLE_MANAGERS.has(manager_name):
			_deferred_reset_queue.append(manager_name)
	call_deferred("_process_deferred_manager_resets")

func _process_deferred_manager_resets() -> void:
	if _deferred_reset_queue.is_empty():
		if _start_new_game_perf_pending:
			_start_new_game_perf_pending = false
			_perf_phase_end("start_new_game")
		return
	var batch_count: int = mini(DEFERRED_RESET_BATCH_SIZE, _deferred_reset_queue.size())
	for _i in range(batch_count):
		var manager_name: String = _deferred_reset_queue.pop_front()
		_reset_manager_by_name(manager_name)
	if not _deferred_reset_queue.is_empty():
		call_deferred("_process_deferred_manager_resets")
	elif _start_new_game_perf_pending:
		_start_new_game_perf_pending = false
		_perf_phase_end("start_new_game")

func save_game() -> bool:
	_ensure_battle_end_save_hook()
	if not _is_exiting and _is_battle_active_now():
		_save_dirty_during_battle = true
		return true
	if _is_saving:
		return false
	var now_ms: int = Time.get_ticks_msec()
	if not _is_exiting and now_ms - _last_save_ms < SAVE_MIN_INTERVAL_MS:
		_schedule_deferred_save()
		return true
	_is_saving = true

	# 先备份当前存档
	_migrate_old_save_if_needed()
	_backup_current_save()

	var bm: Node = get_node_or_null("/root/BlueprintManager")
	var pm: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if bm == null:
		push_error("[SaveManager] BlueprintManager 未找到")
		_is_saving = false
		return false
	var data: Dictionary = {SK_SCHEMA_VERSION: SAVE_SCHEMA_VERSION}
	if bm.has_method("save_state"):
		data[SK_BLUEPRINT] = bm.save_state()
	_collect_manager_state(data, "/root/BasicResourceManager", SK_BASIC_RESOURCES)
	_collect_manager_state(data, "/root/PhaseLawManager", SK_PHASE_LAW)
	_collect_manager_state(data, "/root/QuestManager", SK_QUEST)
	_collect_manager_state(data, "/root/FactionSystemManager", SK_FACTION_SYSTEM)
	_collect_manager_state(data, "/root/AffixManager", SK_AFFIX_DATA)
	_collect_manager_state(data, "/root/LevelProgressManager", SK_LEVEL_PROGRESS)
	_collect_manager_state(data, "/root/DropManager", SK_DROP_MANAGER)
	_collect_manager_state(data, "/root/IntelItemBag", SK_INTEL_ITEM_BAG)
	_collect_noncritical_save_data(data, now_ms)
	var gmgr: Node = get_node_or_null("/root/GameManager")
	# 保存前同步 current_level：确保与 LevelProgressManager.max_unlocked_level 一致
	if gmgr != null and "current_level" in gmgr:
		var lpm_sync: Node = get_node_or_null("/root/LevelProgressManager")
		if lpm_sync != null and lpm_sync.has_method("get_max_unlocked_level"):
			var max_u_save: int = lpm_sync.get_max_unlocked_level()
			var cur: int = int(gmgr.current_level)
			if max_u_save > cur:
				gmgr.set_current_level(max_u_save)
		data[SK_GAME] = {SK_CURRENT_LEVEL: int(gmgr.current_level)}
	else:
		# GameManager 不可用时仍写入默认值，避免校验缺失 game 字段
		data[SK_GAME] = {SK_CURRENT_LEVEL: 1}
	if pm != null and pm.has_method("get_slot_card_ids"):
		data[SK_PHASE_SLOTS] = pm.get_slot_card_ids()
		data[SK_PHASE_SLOTS_ORDER] = "rbgy"
	if pm != null and pm.has_method("save_state"):
		data[SK_PHASE_INSTRUMENT] = pm.save_state()
	var backpack: Node = _find_backpack_panel()
	if backpack != null and backpack.has_method("get_extra_card_ids"):
		var extra_ids: Array = backpack.get_extra_card_ids()
		data[SK_BACKPACK_EXTRA_IDS] = extra_ids
		_last_known_extra_ids = extra_ids.duplicate()
	elif not _last_known_extra_ids.is_empty():
		# 背包面板不可用时使用上次已知值，防止额外卡丢失
		data[SK_BACKPACK_EXTRA_IDS] = _last_known_extra_ids.duplicate()
		if not _is_exiting:
			push_warning("[SaveManager] 背包面板不可用，使用上次已知的额外卡ID (%d 张)" % _last_known_extra_ids.size())

	# 保存前清洗非法浮点值（inf/-inf/nan），防止写出不可解析的 JSON。
	data = SaveMigration.sanitize_save_variant(data)

	# JSON预检：确保序列化成功
	var json_str: String = JSON.stringify(data)
	if json_str.is_empty():
		push_error("[SaveManager] JSON序列化失败，存档数据异常")
		_is_saving = false
		return false

	var dir_swap := DirAccess.open("user://")
	if dir_swap == null:
		push_error("[SaveManager] 无法打开 user://，存档失败")
		_is_saving = false
		return false
	var temp_name := "save_slot_%d.json.tmp" % current_slot
	if dir_swap.file_exists(temp_name):
		dir_swap.remove(temp_name)

	var f: FileAccess = FileAccess.open(_current_temp_file(), FileAccess.WRITE)
	if f == null:
		var open_err: Error = FileAccess.get_open_error()
		push_error("[SaveManager] 无法写入临时存档 %s (错误码 %s)" % [_current_temp_file(), open_err])
		_is_saving = false
		return false
	f.store_string(json_str)
	var write_err: Error = f.get_error()
	f.close()
	if write_err != OK:
		push_error("[SaveManager] 写入临时存档失败: %s" % write_err)
		var toast_mgr_err2 = get_node_or_null("/root/ToastManager")
		if not _is_exiting and toast_mgr_err2 and toast_mgr_err2.has_method("show_error"):
			toast_mgr_err2.show_error("存档保存失败！")
		_is_saving = false
		return false

	dir_swap = DirAccess.open("user://")
	if dir_swap == null:
		push_error("[SaveManager] 无法打开 user:// 以替换正式存档")
		_is_saving = false
		return false
	# 原子写入：先将现有存档 rename 为 .prior（不删除），再 rename tmp 为正式文件
	var main_name := "save_slot_%d.json" % current_slot
	var prior_name := "save_slot_%d.json.prior" % current_slot
	var tmp_name := "save_slot_%d.json.tmp" % current_slot
	if dir_swap.file_exists(main_name):
		var prior_err: Error = dir_swap.rename(main_name, prior_name)
		if prior_err != OK:
			push_error("[SaveManager] 无法重命名旧存档为 prior: %s" % prior_err)
			_is_saving = false
			return false
	var ren_err: Error = dir_swap.rename(tmp_name, main_name)
	if ren_err != OK:
		push_error("[SaveManager] 无法将临时存档 rename 为正式存档: %s" % [ren_err, {
			"slot": current_slot,
			"tmp_name": tmp_name,
			"main_name": main_name,
			"ren_err": int(ren_err),
		}])
		#endregion
		# Windows 下退出阶段偶发 rename 失败；兜底为 tmp 直写正式存档，避免”退出后没档”
		var tmp_read: FileAccess = FileAccess.open(_current_temp_file(), FileAccess.READ)
		if tmp_read != null:
			var tmp_json: String = tmp_read.get_as_text()
			tmp_read.close()
			var main_write: FileAccess = FileAccess.open(_current_save_file(), FileAccess.WRITE)
			if main_write != null:
				main_write.store_string(tmp_json)
				main_write.close()
				var cleanup_dir := DirAccess.open("user://")
				var tmp_n := "save_slot_%d.json.tmp" % current_slot
				if cleanup_dir != null and cleanup_dir.file_exists(tmp_n):
					cleanup_dir.remove(tmp_n)
				if DEBUG_SAVE_LOG:
					pass  # LOG: rename失败，已使用临时存档直写恢复
				_is_saving = false
				return true
			push_error("[SaveManager] 临时存档读取失败，无法直写恢复: %s" % [{
				"slot": current_slot,
				"tmp_read_null": tmp_read == null,
			}])
		#endregion
		push_error("[SaveManager] 无法完成存档替换 rename: %s" % ren_err)
		# rename 失败且直写也失败：恢复 .prior 文件
		var prior_name_rollback := "save_slot_%d.json.prior" % current_slot
		var main_name_rollback := "save_slot_%d.json" % current_slot
		if FileAccess.file_exists(prior_name_rollback):
			if dir_swap.rename(prior_name_rollback, main_name_rollback) == OK:
				if DEBUG_SAVE_LOG:
					pass  # LOG: 已从 prior 恢复
		var toast_mgr_err3 = get_node_or_null("/root/ToastManager")
		if not _is_exiting and toast_mgr_err3 and toast_mgr_err3.has_method("show_error"):
			toast_mgr_err3.show_error("存档保存失败！")
		_is_saving = false
		return false
	if DEBUG_SAVE_LOG:
		pass  # LOG: 已保存到
	# 显示成功Toast
	var toast_mgr = get_node_or_null("/root/ToastManager")
	if not _is_exiting and toast_mgr and toast_mgr.has_method("show_success"):
		toast_mgr.show_success("游戏已保存")
	_last_save_ms = Time.get_ticks_msec()
	_slot_info_cache_valid = false
	_is_saving = false
	return true

## 获取待处理的背包ID
func get_pending_backpack_ids() -> Array:
	return _pending_backpack_ids.duplicate()

## 获取最近一次已知的背包额外卡ID（用于背包面板重建时的会话内恢复）
func get_last_known_backpack_ids() -> Array:
	return _last_known_extra_ids.duplicate()

## 直接设置 _last_known_extra_ids（供 BackpackPresenter 首次加载后同步完整列表）
func _set_last_known_extra_ids_direct(ids: Array) -> void:
	_last_known_extra_ids.clear()
	for id_val in ids:
		var sid: String = str(id_val) if id_val != null else ""
		if not sid.is_empty() and not _last_known_extra_ids.has(sid):
			_last_known_extra_ids.append(sid)

## 清除待处理的背包ID
func clear_pending_backpack_ids() -> void:
	_pending_backpack_ids.clear()

## 新存档初始背包卡牌 + 初始资源
func _enqueue_starter_backpack_cards() -> void:
	# 初始卡牌
	enqueue_backpack_card_id("omega_platform")
	enqueue_backpack_card_id("energy_start_1")
	enqueue_backpack_card_id("energy_start_2")
	# 初始资源：各资源100000点
	if BasicResourceManager:
		BasicResourceManager.add_resource("nano_materials", 100000)
		BasicResourceManager.add_resource("alloy", 100000)
		BasicResourceManager.add_resource("crystal", 100000)
		BasicResourceManager.add_resource("energy_block", 100000)
		BasicResourceManager.add_resource("research_points", 100000)

	# 初始情报：解锁所有情报
	if IntelManual and IntelManual.has_method("unlock_all_intel"):
		IntelManual.unlock_all_intel()

	# 初始蓝图：授予所有改造情报书和进化蓝图
	if IntelItemBag:
		const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
		var mod_registry = get_node_or_null("/root/ModificationRegistry")
		# 授予所有改造蓝图（改造情报书）
		# 注意：ModificationRegistry.get_all_ids() 是 static 方法，
		# Godot 4 的 has_method() 不检测 static 方法，所以直接调用
		if mod_registry:
			var all_mod_ids = ModificationRegistry.get_all_ids()
			for mod_id in all_mod_ids:
				if mod_id is String and not mod_id.is_empty():
					var blueprint_id = BlueprintDefinitions.get_mod_blueprint_id(mod_id)
					IntelItemBag.add_item(blueprint_id, 1)

		# 授予所有进化蓝图
		_grant_all_evolution_blueprints()

	# 初始改装材料：所有改装库存100
	# TODO: 需要根据改装系统实现添加
	# if ModificationRegistry:
	#     for mod_id in ModificationRegistry.get_all_mod_ids():
	#         BlueprintManager.add_modification_stock(mod_id, 100)

	# 初始进化材料：所有进化材料库存100
	# TODO: 需要根据进化系统实现添加

	# 初始关键道具：所有关键道具库存100
	# TODO: 需要根据道具系统实现添加

## 辅助函数：为单个进化路径生成蓝图
func _process_evolution_blueprint_path(path_data: Dictionary) -> void:
	const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
	# 按 stage 数值排序，而不是字符串键
	var sorted_entries = []
	for key in path_data.keys():
		var node = path_data[key]
		var stage = node.get("stage", 0)
		sorted_entries.append({"key": key, "stage": stage, "node": node})
	# 按 stage 升序排序
	sorted_entries.sort_custom(func(a, b): return a.stage < b.stage)

	var previous_card = ""
	for entry in sorted_entries:
		var card_id = entry.node.get("card_id", "")
		if not card_id.is_empty() and not previous_card.is_empty():
			var evo_bp_id = BlueprintDefinitions.get_evolution_blueprint_id(previous_card, card_id)
			print("[SaveManager] 添加进化蓝图: %s (E%d→E%d: %s → %s)" % [evo_bp_id, entry.stage - 1, entry.stage, previous_card, card_id])
			IntelItemBag.add_item(evo_bp_id, 1)
		previous_card = card_id

## 辅助函数：为隐藏分支生成蓝图
func _process_evolution_hidden_branches(branches_data: Dictionary) -> void:
	const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
	for branch_name in branches_data.keys():
		var branch = branches_data[branch_name]
		# 按 stage 数值排序
		var sorted_entries = []
		for key in branch.keys():
			var node = branch[key]
			var stage = node.get("stage", 0)
			sorted_entries.append({"key": key, "stage": stage, "node": node})
		sorted_entries.sort_custom(func(a, b): return a.stage < b.stage)

		var branch_prev_card = ""
		for entry in sorted_entries:
			var card_id = entry.node.get("card_id", "")
			if not card_id.is_empty():
				if not branch_prev_card.is_empty():
					var evo_bp_id = BlueprintDefinitions.get_evolution_blueprint_id(branch_prev_card, card_id)
					print("[SaveManager] 添加隐藏分支蓝图: %s (E%d→E%d: %s → %s)" % [evo_bp_id, entry.stage - 1, entry.stage, branch_prev_card, card_id])
					IntelItemBag.add_item(evo_bp_id, 1)
				branch_prev_card = card_id

## 授予所有进化蓝图
## 遍历所有进化路径，为每个进化节点生成对应的蓝图
func _grant_all_evolution_blueprints() -> void:
	# 加载所有进化路径类
	const InfantryEvolution = preload("res://data/evolution_paths/infantry_evolution.gd")
	const ArmorEvolution = preload("res://data/evolution_paths/armor_evolution.gd")
	const ArtilleryEvolution = preload("res://data/evolution_paths/artillery_evolution.gd")
	const AntiAirEvolution = preload("res://data/evolution_paths/anti_air_evolution.gd")
	const AirEvolution = preload("res://data/evolution_paths/air_evolution.gd")
	const ReconEvolution = preload("res://data/evolution_paths/recon_evolution.gd")
	const EngineerEvolution = preload("res://data/evolution_paths/engineer_evolution.gd")
	const FortEvolution = preload("res://data/evolution_paths/fort_evolution.gd")

	# 步兵进化路径
	_process_evolution_blueprint_path(InfantryEvolution.get_main_line())
	_process_evolution_hidden_branches(InfantryEvolution.get_hidden_branches())

	# 装甲兵进化路径（两条主线）
	_process_evolution_blueprint_path(ArmorEvolution.get_main_line())        # 机动路线
	_process_evolution_blueprint_path(ArmorEvolution.get_secondary_line())   # 重甲路线
	_process_evolution_hidden_branches(ArmorEvolution.get_hidden_branches())  # 豹系分支

	# 炮兵进化路径
	_process_evolution_blueprint_path(ArtilleryEvolution.get_main_line())
	_process_evolution_hidden_branches(ArtilleryEvolution.get_hidden_branches())

	# 防空兵进化路径
	_process_evolution_blueprint_path(AntiAirEvolution.get_main_line())
	_process_evolution_hidden_branches(AntiAirEvolution.get_hidden_branches())

	# 空中单位进化路径（两条主线）
	_process_evolution_blueprint_path(AirEvolution.get_main_line())           # 制空路线
	_process_evolution_blueprint_path(AirEvolution.get_secondary_line())      # 对地攻击路线
	_process_evolution_hidden_branches(AirEvolution.get_hidden_branches())    # 隐形轰炸机

	# 侦察/特种进化路径
	_process_evolution_blueprint_path(ReconEvolution.get_main_line())
	_process_evolution_hidden_branches(ReconEvolution.get_hidden_branches())

	# 工程/支援进化路径
	_process_evolution_blueprint_path(EngineerEvolution.get_main_line())
	_process_evolution_hidden_branches(EngineerEvolution.get_hidden_branches())

	# 堡垒单位进化路径（两条主线）
	_process_evolution_blueprint_path(FortEvolution.get_main_line())         # 防御路线
	_process_evolution_blueprint_path(FortEvolution.get_secondary_line())    # 防空路线
	_process_evolution_hidden_branches(FortEvolution.get_hidden_branches())   # 雷达站


## 处理一个待入包的卡牌ID（从pending中移除，标记为已处理）
func consume_pending_backpack_card_id(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var idx: int = _pending_backpack_ids.find(card_id)
	if idx >= 0:
		_pending_backpack_ids.remove_at(idx)
		return true
	return false

## 直接添加待入包的卡牌ID（用于制造/掉落等场景）
func add_pending_backpack_card_id(card_id: String) -> void:
	if card_id.is_empty():
		return
	if not _pending_backpack_ids.has(card_id):
		_pending_backpack_ids.append(card_id)

## 开始新游戏：重置所有管理器状态
func start_new_game() -> void:
	_perf_phase_begin("start_new_game")
	_start_new_game_perf_pending = true
	if DEBUG_SAVE_LOG:
		pass  # LOG: 开始新游戏，重置所有管理器
	# 关键管理器同步重置；其余管理器分批 deferred 重置，降低按钮点击同帧阻塞。
	for manager_name in CRITICAL_RESETTABLE_MANAGERS:
		_reset_manager_by_name(manager_name)
	_schedule_deferred_manager_resets()
	# 同步重置 GameManager.current_level
	var gm = get_node_or_null("/root/GameManager")
	if gm != null and "current_level" in gm and gm.has_method("set_current_level"):
		gm.set_current_level(1)
	# 删除当前存档位的文件
	_remove_file_at_user(_current_save_file())
	_remove_file_at_user(_current_backup_file())
	_remove_file_at_user(_current_temp_file())
	_noncritical_save_cache.clear()
	_last_noncritical_save_ms = 0
	_slot_info_cache_valid = false
	# 清除待处理的背包ID（开始新游戏时）
	_pending_backpack_ids.clear()
	_last_known_extra_ids.clear()
	# 新存档初始背包：全装型战斗卡 ×1，2星能量卡 ×2
	_enqueue_starter_backpack_cards()
	if DEBUG_SAVE_LOG:
		pass  # LOG: 新游戏已准备完毕
	if _deferred_reset_queue.is_empty() and _start_new_game_perf_pending:
		_start_new_game_perf_pending = false
		_perf_phase_end("start_new_game")

func load_game() -> bool:
	_perf_phase_begin("load_game")
	_load_game_perf_pending = true
	_load_game_parse_phase_open = false
	_load_game_critical_phase_open = false
	_load_game_deferred_phase_open = false
	_migrate_old_save_if_needed()
	var path: String = _resolve_read_save_path()
	if path.is_empty():
		# 当前存档位无存档，尝试备份
		var backup := _current_backup_file()
		if FileAccess.file_exists(backup):
			if DEBUG_SAVE_LOG:
				pass  # LOG: 主存档不存在，尝试从备份恢复
			return _load_from_path(backup)
		_finalize_load_game_perf_on_fail()
		return false

	# 先尝试加载主存档
	if not _load_from_path(path):
		# 主存档加载失败，尝试备份
		var backup := _current_backup_file()
		if FileAccess.file_exists(backup):
			if DEBUG_SAVE_LOG:
				pass  # LOG: 主存档损坏，尝试从备份恢复
			return _load_from_path(backup)
		_finalize_load_game_perf_on_fail()
		return false
	return true

## 从指定路径加载存档（辅助方法）
func _load_from_path(path: String) -> bool:
	if path.is_empty():
		_finalize_load_game_perf_on_fail()
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[SaveManager] 无法读取存档: %s" % path)
		_finalize_load_game_perf_on_fail()
		return false
	var json_str: String = f.get_as_text()
	f.close()
	if json_str.strip_edges().is_empty():
		push_error("[SaveManager] 存档文件为空: %s" % path)
		_finalize_load_game_perf_on_fail()
		return false
	if not _load_game_parse_phase_open:
		_load_game_parse_phase_open = true
		_perf_phase_begin("load_game_parse_json")
	var json := JSON.new()
	var err: Error = json.parse(json_str)
	if err != OK:
		# 兼容旧坏档：若包含 inf/-inf/nan，尝试修复为 0 后重试解析。
		var repaired_json_str: String = SaveMigration.repair_non_finite_json_tokens(json_str)
		if repaired_json_str != json_str:
			var json_retry := JSON.new()
			var retry_err: Error = json_retry.parse(repaired_json_str)
			if retry_err == OK:
				json = json_retry
				var wf: FileAccess = FileAccess.open(path, FileAccess.WRITE)
				if wf != null:
					wf.store_string(repaired_json_str)
					wf.close()
					push_warning("[SaveManager] 检测到非有限数值(inf/nan)，已自动修复并重写: %s" % path)
			else:
				push_error("[SaveManager] JSON解析失败(修复后仍失败): %s  错误: %s  行: %d  内容前200字符: %s" % [
					path, json_retry.get_error_message(), json_retry.get_error_line(), repaired_json_str.left(200)])
				_finalize_load_game_perf_on_fail()
				return false
		else:
			push_error("[SaveManager] JSON解析失败: %s  错误: %s  行: %d  内容前200字符: %s" % [
				path, json.get_error_message(), json.get_error_line(),
				json_str.left(200)])
			_finalize_load_game_perf_on_fail()
			return false
	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[SaveManager] 存档数据格式错误: %s" % path)
		_finalize_load_game_perf_on_fail()
		return false

	# 数据校验（性能模式默认走轻量校验；需要排查时可打开详细校验）
	if ENABLE_DETAILED_LOAD_VALIDATION:
		if not SaveMigration.validate_save_data(data, DEBUG_SAVE_LOG):
			# 详细错误已由 SaveMigration.validate_save_data 内部打印
			push_error("[SaveManager] 存档数据校验失败，拒绝加载: %s (schema v%s, 共 %d 个顶层键)" % [
				path, data.get(SK_SCHEMA_VERSION, "?"), data.size()])
			_finalize_load_game_perf_on_fail()
			return false
	else:
		SaveMigration.apply_fast_load_normalization(data)

	# 检查存档版本并迁移
	var version: int = data.get(SK_SCHEMA_VERSION, 1)
	if version < SAVE_SCHEMA_VERSION:
		SaveMigration.migrate_save_data(data, version, DEBUG_SAVE_LOG)
	_noncritical_save_cache.clear()
	_last_noncritical_save_ms = 0
	if _load_game_parse_phase_open:
		_load_game_parse_phase_open = false
		_perf_phase_end("load_game_parse_json")

	# 关键管理器同步加载，保证主流程稳定；其余管理器分批 deferred，降低 Continue 同帧尖峰。
	_load_game_critical_phase_open = true
	_perf_phase_begin("load_game_critical_managers")
	_load_manager_batch(data, CRITICAL_MANAGER_LOADS)
	if _load_game_critical_phase_open:
		_load_game_critical_phase_open = false
		_perf_phase_end("load_game_critical_managers")
	_load_game_deferred_phase_open = true
	_perf_phase_begin("load_game_deferred_managers")
	_schedule_deferred_manager_loads(data)

	# 特殊处理：phase_slots（仅旧档兼容，新版存档已在 load_state 内部恢复）
	var pm: Node = get_node_or_null("/root/PhaseInstrumentManager")
	if pm != null and data.has(SK_PHASE_SLOTS) and pm.has_method("set_slots_from_card_ids"):
		var pi_data: Dictionary = data.get(SK_PHASE_INSTRUMENT, {}) as Dictionary
		if not (pi_data.has("slot_card_ids")):
			var slot_ids: Array = data[SK_PHASE_SLOTS] as Array
			if String(data.get(SK_PHASE_SLOTS_ORDER, "")) != "rbgy" and pm.has_method("remap_legacy_green_first_slots"):
				slot_ids = pm.remap_legacy_green_first_slots(slot_ids)
			pm.set_slots_from_card_ids(slot_ids)

	# 特殊处理：backpack_extra_ids（必须先加载，避免后续操作被覆盖）
	if data.has(SK_BACKPACK_EXTRA_IDS) and data[SK_BACKPACK_EXTRA_IDS] is Array:
		_pending_backpack_ids = (data[SK_BACKPACK_EXTRA_IDS] as Array).duplicate()
		_last_known_extra_ids = _pending_backpack_ids.duplicate()
	else:
		_pending_backpack_ids = []

	# 确保槽位中已恢复的额外卡（非默认卡池）也加入背包追踪
	# 注意：仅将不在默认卡池中的卡标记为额外卡；默认池中的卡（如 omega_platform、energy_start_4）
	# 是初始装备卡，不应出现在背包中（它们属于相位仪槽位）
	# 追加到 _pending_backpack_ids 和 _last_known_extra_ids，不覆盖已有数据
	if pm != null and pm.has_method("get_slot_card_ids"):
		var restored_slot_ids: Array = pm.get_slot_card_ids()
		for sid_raw in restored_slot_ids:
			var sid: String = str(sid_raw) if sid_raw != null else ""
			if sid.is_empty():
				continue
			# 跳过初始装备卡（这些是相位仪自带的默认卡，不是玩家额外获取的）
			if sid == "omega_platform" or sid == "energy_start_4":
				continue
			if not _pending_backpack_ids.has(sid):
				_pending_backpack_ids.append(sid)
			if not _last_known_extra_ids.has(sid):
				_last_known_extra_ids.append(sid)

	# 特殊处理：game.current_level
	var gmgr_load: Node = get_node_or_null("/root/GameManager")
	if gmgr_load != null and data.has(SK_GAME) and data[SK_GAME] is Dictionary:
		var gdict: Dictionary = data[SK_GAME]
		if gdict.has(SK_CURRENT_LEVEL) and gmgr_load.has_method("set_current_level"):
			gmgr_load.set_current_level(int(gdict[SK_CURRENT_LEVEL]))

	# 旧存档常见：level_progress 已推进但 game.current_level 仍为 1，读档后主界面/教程判断会误以为新档
	var lpm_cursor: Node = get_node_or_null("/root/LevelProgressManager")
	var gmgr_cursor: Node = get_node_or_null("/root/GameManager")
	if lpm_cursor != null and gmgr_cursor != null and lpm_cursor.has_method("get_max_unlocked_level") and gmgr_cursor.has_method("set_current_level"):
		var max_u: int = lpm_cursor.get_max_unlocked_level()
		var gl0: int = int(gmgr_cursor.current_level)
		if max_u > 1 and gl0 <= 1:
			gmgr_cursor.set_current_level(max_u)

	# 特殊处理：legacy company
	var fsm: Node = get_node_or_null("/root/FactionSystemManager")
	if fsm != null and data.has("company") and data["company"] is Dictionary:
		var legacy: Dictionary = data["company"].get("company_rep", {}) as Dictionary
		if not legacy.is_empty() and fsm.has_method("merge_legacy_company_rep"):
			fsm.merge_legacy_company_rep(legacy)

	# 特殊处理：phase instrument migration
	if pm != null:
		if pm.has_method("migrate_law_slots_from_phase_law_manager_if_empty"):
			pm.migrate_law_slots_from_phase_law_manager_if_empty()
		if pm.has_method("sync_law_slots_to_plm_if_has_law_cards"):
			pm.sync_law_slots_to_plm_if_has_law_cards()

	# 补偿缺失的改造蓝图（老存档可能因为 has_method 不检测 static 方法而缺失）
	_ensure_mod_blueprints_exist()

	if DEBUG_SAVE_LOG:
		pass  # LOG: 已加载存档
	return true

## 补偿缺失的改造蓝图（每次加载存档时自动检查）
func _ensure_mod_blueprints_exist() -> void:
	if IntelItemBag == null:
		return
	var mod_registry = get_node_or_null("/root/ModificationRegistry")
	if mod_registry == null:
		return
	var all_mod_ids = ModificationRegistry.get_all_ids()
	const BlueprintDefinitions = preload("res://data/blueprint_definitions.gd")
	var granted_count: int = 0
	for mod_id in all_mod_ids:
		if mod_id is String and not mod_id.is_empty():
			var blueprint_id = BlueprintDefinitions.get_mod_blueprint_id(mod_id)
			if not IntelItemBag.has_item(blueprint_id):
				IntelItemBag.add_item(blueprint_id, 1)
				granted_count += 1
	if granted_count > 0:
		print("[SaveManager] 补偿了 %d 个缺失的改造蓝图" % granted_count)

## 安全加载管理器数据（类型检查+错误日志）
## 支持延迟加载管理器：如果管理器不在场景树中，尝试通过 ManagerLazyLoader 实例化
func _safe_load_manager(node_path: String, data: Dictionary, data_key: String) -> void:
	var manager: Node = get_node_or_null(node_path)
	if manager == null:
		# 尝试通过 ManagerLazyLoader 按需实例化
		var lazy_loader = get_node_or_null("/root/ManagerLazyLoader")
		if lazy_loader and lazy_loader.has_method("get_manager_by_name"):
			var node_name = node_path.get_file()
			manager = lazy_loader.get_manager_by_name(node_name)
	if manager == null:
		push_warning("[SaveManager] 管理器不存在且无法实例化: %s" % node_path)
		return

	if not data.has(data_key):
		return  # 数据中没有该字段，跳过

	var manager_data: Variant = data[data_key]

	# 类型检查：必须是Dictionary
	if typeof(manager_data) != TYPE_DICTIONARY:
		push_error("[SaveManager] %s 数据类型错误: 期望Dictionary，实际%s" % [data_key, type_string(typeof(manager_data))])
		return

	# 检查管理器是否有 load_state 方法
	if not manager.has_method("load_state"):
		push_warning("[SaveManager] %s 没有 load_state 方法" % node_path)
		return

	# 尝试加载数据
	manager.load_state(manager_data)

func _load_manager_batch(data: Dictionary, loads: Array) -> void:
	for entry in loads:
		if entry is Array and entry.size() >= 2:
			_safe_load_manager(String(entry[0]), data, String(entry[1]))

func _schedule_deferred_manager_loads(data: Dictionary) -> void:
	_deferred_load_data = data
	_deferred_manager_queue = DEFERRED_MANAGER_LOADS.duplicate(true)
	call_deferred("_process_deferred_manager_loads")

func _process_deferred_manager_loads() -> void:
	if _deferred_manager_queue.is_empty():
		_deferred_load_data.clear()
		if _load_game_deferred_phase_open:
			_load_game_deferred_phase_open = false
			_perf_phase_end("load_game_deferred_managers")
		if _load_game_perf_pending:
			_load_game_perf_pending = false
			_perf_phase_end("load_game")
		return
	var batch_count: int = mini(DEFERRED_LOAD_BATCH_SIZE, _deferred_manager_queue.size())
	for _i in range(batch_count):
		var entry = _deferred_manager_queue.pop_front()
		if entry is Array and entry.size() >= 2:
			_safe_load_manager(String(entry[0]), _deferred_load_data, String(entry[1]))
	if not _deferred_manager_queue.is_empty():
		call_deferred("_process_deferred_manager_loads")
	else:
		_deferred_load_data.clear()
		if _load_game_deferred_phase_open:
			_load_game_deferred_phase_open = false
		if _load_game_perf_pending:
			_load_game_perf_pending = false
			_perf_phase_end("load_game")
