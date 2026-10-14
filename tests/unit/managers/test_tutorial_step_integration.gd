extends GdUnitTestSuite
## v5 教程整合批（2026-10-13）回归锁：步骤流重构 × 旧档迁移 × 实操门 fail-open ×
## TutorialHost 宿主门面。
##
## 锁四个维度：
##   步骤流 —— STEP_ORDER 10 步制内容锁（退役四步不得复活）；战后续播段全即开面
##             （SURFACE_FOR_STEP 的面不得落入 FeatureUnlockSchedule 门控——门控步
##             = 教程链被拖长数小时后随机弹框，本批主诉本体）
##   迁移   —— 旧档（version<5）停在退役步 → 前跳到下一个存活步；终态/存活步不受扰
##   门     —— PHASE_FIELD_POINTS 无可分配点数（unspent=0 且从未分过）不拦（fail-open，
##             原 fail-closed 硬卡=教程永不结课）；有点没分才拦
##   宿主   —— TutorialHost.ensure_layer 层号 105 / show_overlay 防重复 /
##             has_overlay 纯查询不建层
## 测试直接操纵 autoload 内存态，测毕全量还原。

const TpmScript = preload("res://managers/tutorial_progression_manager.gd")
const Schedule = preload("res://data/feature_unlock_schedule.gd")
const TutorialHost = preload("res://scripts/ui/tutorial_host.gd")

var _tpm: Node = null
var _orig_state: Dictionary = {}


func before_test() -> void:
	_tpm = get_node_or_null("/root/TutorialProgressionManager")
	assert_bool(_tpm != null).is_true()
	_orig_state = _tpm.save_state()


func after_test() -> void:
	_tpm.load_state(_orig_state)
	# load_state 对 version<5 会做退役步前跳；还原用直接字段写回保真
	_tpm.current_step = int(_orig_state.get("current_step", 0))
	_tpm.completed_steps = _orig_state.get("completed_steps", [])
	_tpm.chain_paused = bool(_orig_state.get("chain_paused", false))
	_tpm.pending_close_surface = String(_orig_state.get("pending_close_surface", ""))
	var seen: Dictionary = {}
	for k in _orig_state.get("seen_surfaces", []):
		seen[String(k)] = true
	_tpm.seen_surfaces = seen


# ── 步骤流维度 ──────────────────────────────────────────────────────

func test_step_order_is_ten_steps_no_retired() -> void:
	# 10 步内容锁：退役步（2 卡仓/5 改造/9 势力/10 商店）不得复活
	assert_int(TpmScript.STEP_ORDER.size()).is_equal(10)
	for retired in [TpmScript.TutorialStep.CARD_COLLECTION,
			TpmScript.TutorialStep.MODIFICATION,
			TpmScript.TutorialStep.FACTION_REP,
			TpmScript.TutorialStep.SHOP]:
		assert_bool(TpmScript.STEP_ORDER.has(retired)).is_false()
	# 首四步连讲段 + 战后续播段骨架（TRUCK_BASE 紧跟 FIRST_BATTLE）
	assert_int(int(TpmScript.STEP_ORDER[0])).is_equal(int(TpmScript.TutorialStep.INTRO_WELCOME))
	assert_int(int(TpmScript.STEP_ORDER[3])).is_equal(int(TpmScript.TutorialStep.TRUCK_BASE))
	assert_int(int(TpmScript.STEP_ORDER[-1])).is_equal(int(TpmScript.TutorialStep.FREEDOM_MODE))


func test_waiting_surfaces_all_ungated() -> void:
	# 战后续播段即开面纪律：SURFACE_FOR_STEP 的面必须在首战后（玩家 L2）即可用——
	# 解锁等级 >2 的面会拖长教程链数小时后随机弹框（本批主诉本体；evolution L2 属
	# 首战通关即达，放行）。常开面 unlock_level_for=0。
	for step in TpmScript.SURFACE_FOR_STEP:
		var surface := String(TpmScript.SURFACE_FOR_STEP[step])
		assert_int(Schedule.unlock_level_for(surface)).is_less(3)


func test_every_playable_step_has_data() -> void:
	# 播放序每步必须有内容（缺数据=框空壳 queue_free，步永不可见）
	for step in TpmScript.STEP_ORDER:
		var content: Dictionary = _tpm.tutorial_data.get(step, {})
		assert_bool(content.is_empty()).is_false()
		assert_str(String(content.get("title", ""))).is_not_empty()
		assert_str(String(content.get("description", ""))).is_not_empty()
		assert_str(String(content.get("action_text", ""))).is_not_empty()


# ── 旧档迁移维度 ────────────────────────────────────────────────────

func test_migration_retired_step_snaps_forward() -> void:
	# version 4 旧档停在退役步 → 前跳到下一个存活步（2→3 / 5→6 / 9→11）
	var cases := {
		TpmScript.TutorialStep.CARD_COLLECTION: TpmScript.TutorialStep.PHASE_INSTRUMENT,
		TpmScript.TutorialStep.MODIFICATION: TpmScript.TutorialStep.RUNES,
		TpmScript.TutorialStep.FACTION_REP: TpmScript.TutorialStep.WORLD_MAP,   # 9→10(退役)→11
		TpmScript.TutorialStep.SHOP: TpmScript.TutorialStep.WORLD_MAP,
	}
	for saved in cases:
		_tpm.load_state({"version": 4, "current_step": int(saved), "completed_steps": []})
		assert_int(int(_tpm.current_step)).is_equal(int(cases[saved]))


func test_migration_alive_step_and_terminal_untouched() -> void:
	# 存活步原位续看；终态不被拉回
	_tpm.load_state({"version": 4, "current_step": int(TpmScript.TutorialStep.TRUCK_BASE),
		"completed_steps": [], "chain_paused": true})
	assert_int(int(_tpm.current_step)).is_equal(int(TpmScript.TutorialStep.TRUCK_BASE))
	assert_bool(bool(_tpm.chain_paused)).is_true()
	_tpm.load_state({"version": 4, "current_step": int(TpmScript.TutorialStep.FREEDOM_MODE),
		"completed_steps": []})
	assert_int(int(_tpm.current_step)).is_equal(int(TpmScript.TutorialStep.FREEDOM_MODE))


func test_v5_save_roundtrip_keeps_step() -> void:
	# v5 档存取保真（不触发迁移分支）
	_tpm.load_state({"version": 5, "current_step": int(TpmScript.TutorialStep.RUNES),
		"completed_steps": [11], "chain_paused": true, "seen_surfaces": ["growth"]})
	var saved: Dictionary = _tpm.save_state()
	assert_int(int(saved.get("version", 0))).is_equal(5)
	assert_int(int(saved.get("current_step", 0))).is_equal(int(TpmScript.TutorialStep.RUNES))


# ── 实操门 fail-open 维度 ───────────────────────────────────────────

func test_phase_field_gate_failopen_without_points() -> void:
	# 无可分配点数且从未分过 → 不拦（fail-open；原 fail-closed=教程永不结课）
	var pim: Node = get_node_or_null("/root/PhaseInstrumentManager")
	assert_bool(pim != null).is_true()
	var snap_alloc: Dictionary = pim.get_phase_field_allocations()
	var snap_unspent: int = int(pim.get("unspent_phase_field_points"))
	pim.set("phase_field_allocations", {})
	pim.set("unspent_phase_field_points", 0)
	_tpm.current_step = TpmScript.TutorialStep.PHASE_FIELD_POINTS
	assert_bool(_tpm._step_gate_blocked(TpmScript.TutorialStep.PHASE_FIELD_POINTS)).is_false()
	# 有点没分 → 拦（教学要求动手）
	pim.set("unspent_phase_field_points", 2)
	assert_bool(_tpm._step_gate_blocked(TpmScript.TutorialStep.PHASE_FIELD_POINTS)).is_true()
	# 还原
	pim.set("phase_field_allocations", snap_alloc)
	pim.set("unspent_phase_field_points", snap_unspent)


# ── TutorialHost 宿主门面维度 ───────────────────────────────────────

func test_host_layer_number_and_dedup() -> void:
	# 层号 105（>PopupLayer 100，<InfoPanel 110）；show_overlay 防重复；has_overlay 不建层
	var scene := Control.new()
	assert_bool(TutorialHost.has_overlay(scene)).is_false()
	assert_bool(scene.get_node_or_null("TutorialLayer") == null).is_true()  # 查询不建层
	var layer: CanvasLayer = TutorialHost.ensure_layer(scene)
	assert_int(layer.layer).is_equal(105)
	TutorialHost.show_overlay(scene)
	TutorialHost.show_overlay(scene)
	var found := 0
	for child in layer.get_children():
		if child.name == "TutorialOverlay":
			found += 1
	assert_int(found).is_equal(1)
	scene.free()


# ── v5 通道整合维度（教程 × 一次性气泡一套驱动）─────────────────────

func test_tutorial_active_semantics() -> void:
	# 统一判定口：教程进行中（含 NONE 未启动——欢迎框随时自举）true；
	# 完成/跳过（FREEDOM_MODE）false。skill_tree/backpack_guide/PANEL_INTROS/
	# truck_base_intro 四类调用点共用此口，勿散写内联查询。
	var orig := int(_tpm.current_step)
	_tpm.current_step = TpmScript.TutorialStep.ENHANCEMENT
	assert_bool(TutorialHost.is_tutorial_active()).is_true()
	_tpm.current_step = TpmScript.TutorialStep.NONE
	assert_bool(TutorialHost.is_tutorial_active()).is_true()
	_tpm.current_step = TpmScript.TutorialStep.FREEDOM_MODE
	assert_bool(TutorialHost.is_tutorial_active()).is_false()
	_tpm.current_step = orig


func test_consume_once_silently_yields_to_tutorial() -> void:
	# 教程让位口：consume_once 标 seen 但不弹模态——之后的 show_once 同键直接
	# 早退（教程框全权教学，战后不补弹=零重复）。
	const KEY := "v5_test_consumed_yield"
	FeatureUnlockPopup._seen_cache.erase(KEY)
	FeatureUnlockPopup.consume_once(KEY)
	assert_bool(FeatureUnlockPopup._already_seen(KEY)).is_true()
	# consume 后 show_once 不再弹（返回 null=无模态实例）
	assert_object(FeatureUnlockPopup.show_once(KEY, "t", "d")).is_null()
	# 还原 seen 存储（测试键不入档）
	FeatureUnlockPopup._seen_cache.erase(KEY)
	var f := FileAccess.open("user://feature_unlock_seen.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(FeatureUnlockPopup._seen_cache))
		f.close()
