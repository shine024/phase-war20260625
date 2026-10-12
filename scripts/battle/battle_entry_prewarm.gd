extends RefCounted
class_name BattleEntryPrewarm

## ============================================================
## v6.65 记录6#2：战斗入场卡顿治理——开战帧冷读搬家。
##
## 主诉：点「开始战斗」入场时卡一下。根因（探查实证）：开战 deferred 帧同帧挤了
## ①首波敌单位呈现链冷读（vis_enemy 卡图 + sheet_idle/sheet_attack PNG + anim.json）
## ②battle_started 同步 load 战斗 BGM（3~4MB OGG）+ 环境音（1.3MB WAV）。
##
## 方案：点击出击瞬间（run_start_battle_sequence 头部，过场 0.1~1.5s 窗口）对本关
## 敌方池 + 战斗音频发起 ResourceLoader.load_threaded_request——引擎内建线程加载
## （main._preload_common_panels 同款先例），开战帧 load() 直接命中资源缓存。
##
## 线程安全纪律：本模块只做只读路径解析 + load_threaded_request，**不写任何
## GDScript 侧缓存字典**（UnitFrameAnim 的 _key_cache/_seq_cache 等仍由主线程
## 首次 attach 时填充，届时磁盘 IO 已被线程预热摊掉，只剩纯内存小活）。
## 无尽/渗透战的敌方池不在 classic 关卡池内——跳过（BGM/环境音预热照常生效）。
## ============================================================

const UnitFrameAnim = preload("res://scripts/battle/unit_frame_anim.gd")
const EnemyArchetypes = preload("res://data/enemy_archetypes.gd")
const GameConstants = preload("res://resources/game_constants.gd")


## 主入口：本关战斗音频 + 敌方池资产（basic 在前——首波只出 basic）
static func prewarm_for_level(level: int) -> void:
	if level < 1:
		return
	var paths: Array[String] = []
	paths.append_array(_audio_paths())
	paths.append_array(_enemy_asset_paths(level))
	for p in paths:
		if p.is_empty() or ResourceLoader.has_cached(p) or not ResourceLoader.exists(p):
			continue
		ResourceLoader.load_threaded_request(p)


## 战斗 BGM（当前关卡时代）+ 战场环境音——路径口径与 AudioManager 播放侧同源
static func _audio_paths() -> Array[String]:
	var out: Array[String] = []
	var am := _autoload("AudioManager")
	if am != null and am.has_method("battle_audio_prewarm_paths"):
		for p in am.battle_audio_prewarm_paths():
			out.append(String(p))
	return out


## 本关敌方池的卡图 + 帧动画 sheet。排序 basic→elite/boss（首波只出 basic，
## 精英/首领在波次中后段登场，预热请求排队后置正好摊到前几波期间）。
## 无尽战（level>100 xeno 池）与渗透战编队不走 classic 池——get_ids_for_era_at_level
## 返回空即整体跳过，零行为差异。
static func _enemy_asset_paths(level: int) -> Array[String]:
	var out: Array[String] = []
	var era: int = GameConstants.get_era_for_level(level)
	var ids: Array = EnemyArchetypes.get_ids_for_era_at_level(era, level)
	if ids.is_empty():
		return out
	var basic: Array[String] = []
	var later: Array[String] = []
	for aid_var in ids:
		var aid: String = String(aid_var)
		var cfg: Dictionary = EnemyArchetypes.get_config(aid)
		if cfg.is_empty():
			continue
		if (cfg.get("tags", []) as Array).has("boss") or (cfg.get("tags", []) as Array).has("elite"):
			later.append(aid)
		else:
			basic.append(aid)
	for aid in basic + later:
		out.append_array(_assets_for_archetype(aid))
	return out


static func _assets_for_archetype(aid: String) -> Array[String]:
	var out: Array[String] = []
	var cfg: Dictionary = EnemyArchetypes.get_config(aid)
	# 敌方战场卡图（vis_enemy 路径与 resolve_battle_icon_texture 敌方分支同源）
	var icon_path: String = EnemyArchetypes.resolve_card_icon_texture_path(aid, cfg, aid)
	if not icon_path.is_empty():
		out.append(icon_path)
	# 帧动画 sheet——只读解析（不写 _key_cache，主线程 attach 时才入缓存）
	var key: String = UnitFrameAnim.resolve_key_readonly(aid)
	if not key.is_empty():
		out.append(UnitFrameAnim.ANIM_ROOT + key + "/sheet_idle.png")
		out.append(UnitFrameAnim.ANIM_ROOT + key + "/sheet_attack.png")
	return out


## RefCounted 静态上下文取 autoload（项目惯例：Engine.get_main_loop 路线）
static func _autoload(singleton_name: String) -> Node:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null(NodePath(singleton_name))
	return null
