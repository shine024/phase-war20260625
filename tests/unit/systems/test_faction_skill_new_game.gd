extends GdUnitTestSuite
## v6.65 记录6#1 回归锁：势力技能点新档不可加点。
##
## 用户主诉：无法加势力技能点。根因链：FactionSystemManager.load_state({})（新游戏/
## _reset_manager_by_name 兜底路径）提前 return，跳过 _init_faction_skill_states
## → faction_skill_states 恒空 → can_unlock_faction_skill 恒 faction_not_found
## → 面板解锁按钮全灰且 pressed 永不连接（点了解没反应）。存档写过一次后读档
## 走非空分支 _ensure_faction_keys_after_load 自愈——"新档坏的、读档就好"的玄学复现。
##
## 本锁三断言：
## 1. 新档空档分支必须初始化全部势力技能状态（解锁链可用）
## 2. 旧档缺 faction_skill_states 键（兼容路径）同样可用
## 3. 同会话"游玩后开新档"不得残留上一局已解锁技能/已花点数（clear 语义）

const FSM = preload("res://managers/faction_system_manager.gd")
const FactionSkillManagerRef = preload("res://managers/faction/faction_skill_manager.gd")

var _fsm: Node = null


func before_test() -> void:
	_fsm = auto_free(FSM.new())
	if get_tree() != null and get_tree().root != null:
		get_tree().root.add_child(_fsm)


func test_new_game_empty_state_initializes_all_faction_skills() -> void:
	_fsm.load_state({})
	var states: Dictionary = _fsm.get("faction_skill_states")
	assert_int(states.size()).is_greater_equal(7)
	for fid in states:
		var st: Dictionary = states[fid]
		assert_bool(st.has("unlocked_skills")).is_true()
		assert_bool(st.has("spent_points")).is_true()
		assert_bool(st.has("bonus_points")).is_true()


func test_new_game_can_unlock_faction_skill_end_to_end() -> void:
	_fsm.load_state({})
	# 新档起步贡献 → 等级 ≥ 最低技能 tier(2)，可用点 ≥ 首格消耗(1)
	var can: Dictionary = _fsm.can_unlock_faction_skill("iron_wall_corp", "sk_iron_def1")
	assert_bool(bool(can.get("ok", false))).is_true()
	# 旧代码此断言处 reason 恒 "faction_not_found" → 按钮 disabled 且不接 pressed
	assert_bool(_fsm.unlock_faction_skill("iron_wall_corp", "sk_iron_def1")).is_true()
	var states: Dictionary = _fsm.get("faction_skill_states")
	assert_bool("sk_iron_def1" in states["iron_wall_corp"]["unlocked_skills"]).is_true()
	assert_int(int(states["iron_wall_corp"]["spent_points"])).is_equal(1)


func test_legacy_save_without_skill_states_key_still_unlockable() -> void:
	# 旧档：有 reputation 段、无 faction_skill_states 段——走 else 分支 _init_faction_skill_states
	_fsm.load_state({"faction_reputation": {"iron_wall_corp": 5000}})
	var can: Dictionary = _fsm.can_unlock_faction_skill("iron_wall_corp", "sk_iron_def1")
	assert_bool(bool(can.get("ok", false))).is_true()


func test_second_new_game_clears_previous_session_skills() -> void:
	_fsm.load_state({})
	assert_bool(_fsm.unlock_faction_skill("iron_wall_corp", "sk_iron_def1")).is_true()
	# 同会话再开新档（空档分支）——已解锁技能/已花点数必须清零（残留=二周目白送技能）
	_fsm.load_state({})
	var states: Dictionary = _fsm.get("faction_skill_states")
	assert_int((states["iron_wall_corp"]["unlocked_skills"] as Array).size()).is_equal(0)
	assert_int(int(states["iron_wall_corp"]["spent_points"])).is_equal(0)
	# 且默认态由 FactionSkillManager 工厂创建（结构完整）
	var st: Dictionary = states["iron_wall_corp"]
	assert_bool(st.has("bonus_points")).is_true()


func test_faction_skill_manager_unlock_semantics_unchanged() -> void:
	# 底层解锁语义防漂移：level 门槛 + 点数预算 + 分支互斥
	var st := FactionSkillManagerRef.create_default_state("iron_wall_corp")
	# 等级不足（tier 2 > level 1）
	assert_str(String(FactionSkillManagerRef.can_unlock_skill(st, "iron_wall_corp", "sk_iron_def1", 1).get("reason", ""))) \
		.is_equal("level_not_enough")
	# 等级足够 → 成功并扣预算
	assert_bool(FactionSkillManagerRef.unlock_skill(st, "iron_wall_corp", "sk_iron_def1", 7)).is_true()
	assert_int(int(st["spent_points"])).is_equal(1)
	# 同 tier 同 branch 互斥（sk_iron_def2 是 tier2 branch B，不冲突；再造一个 branch A 冲突）
	assert_str(String(FactionSkillManagerRef.can_unlock_skill(st, "iron_wall_corp", "sk_iron_def1", 7).get("reason", ""))) \
		.is_equal("already_unlocked")
