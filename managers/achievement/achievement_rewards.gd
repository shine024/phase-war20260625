extends RefCounted
## 成就奖励发放器：负责发放成就奖励
##
## 从 achievement_manager.gd 拆分的职责：
## - 根据奖励类型（basic_nano / energy_block / phase_field_xp / card）发放资源
## - 通过依赖注入的资源管理器节点操作，不硬编码单例路径
## - 提供奖励可领取状态查询

class_name AchievementRewards

const DEBUG_LOG_PATH := "debug-756b82.log"

static func _debug_log(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	# #region agent log
	var payload: Dictionary = {
		"sessionId": "756b82",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0),
	}
	var f: FileAccess = FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(JSON.stringify(payload))
		f.close()
	# #endregion

static func _get_autoload(root_path: String, run_id: String, hypothesis_id: String) -> Node:
	# #region agent log
	var loop_obj := Engine.get_main_loop()
	if not (loop_obj is SceneTree):
		_debug_log(run_id, hypothesis_id, "achievement_rewards.gd:_get_autoload", "main_loop_not_scenetree", {"root_path": root_path, "main_loop_type": typeof(loop_obj)})
		return null
	var tree := loop_obj as SceneTree
	if tree == null or tree.get_root() == null:
		_debug_log(run_id, hypothesis_id, "achievement_rewards.gd:_get_autoload", "scene_tree_or_root_null", {"root_path": root_path})
		return null
	var node := tree.get_root().get_node_or_null(root_path)
	_debug_log(run_id, hypothesis_id, "achievement_rewards.gd:_get_autoload", "autoload_lookup", {"root_path": root_path, "found": node != null})
	return node
	# #endregion

## 尝试发放成就奖励
## @param reward: 成就定义中的 reward 字典 { type, amount, card_id }
## @param resource_managers: 资源管理器字典，可选键：
##   "BasicResourceManager" -> Node
##   "PhaseInstrumentManager" -> Node
##   "DropManager" -> Node
## @return bool 是否成功发放
static func grant(reward: Dictionary, resource_managers: Dictionary = {}) -> bool:
	if reward.is_empty():
		return false

	var run_id := "run-pre-fix-achievement-rewards"
	var reward_type: String = reward.get("type", "")
	var reward_amount: int = reward.get("amount", 0)
	# #region agent log
	_debug_log(run_id, "H4", "achievement_rewards.gd:grant", "grant_enter", {"reward_type": reward_type, "reward_amount": reward_amount, "has_managers": not resource_managers.is_empty()})
	# #endregion

	match reward_type:
		"basic_nano":
			var brm: Node = resource_managers.get("BasicResourceManager")
			if brm == null:
				brm = _get_autoload("/root/BasicResourceManager", run_id, "H1")
			if brm != null and brm.has_method("add_resource"):
				brm.add_resource("nano_materials", reward_amount)
				# #region agent log
				_debug_log(run_id, "H5", "achievement_rewards.gd:grant", "basic_nano_granted", {"amount": reward_amount})
				# #endregion
				return true
			return false

		"energy_block":
			var brm: Node = resource_managers.get("BasicResourceManager")
			if brm == null:
				brm = _get_autoload("/root/BasicResourceManager", run_id, "H1")
			if brm != null and brm.has_method("add_resource"):
				brm.add_resource("energy_block", reward_amount)
				# #region agent log
				_debug_log(run_id, "H5", "achievement_rewards.gd:grant", "energy_block_granted", {"amount": reward_amount})
				# #endregion
				return true
			return false

		"phase_xp", "phase_field_xp":
			var pm: Node = resource_managers.get("PhaseInstrumentManager")
			if pm == null:
				pm = _get_autoload("/root/PhaseInstrumentManager", run_id, "H2")
			if pm != null and pm.has_method("grant_phase_field_xp"):
				pm.grant_phase_field_xp("achievement", reward_amount)
				# #region agent log
				_debug_log(run_id, "H5", "achievement_rewards.gd:grant", "phase_field_xp_granted", {"amount": reward_amount})
				# #endregion
				return true
			return false

		"card":
			var dm: Node = resource_managers.get("DropManager")
			if dm == null:
				dm = _get_autoload("/root/DropManager", run_id, "H3")
			var card_id: String = reward.get("card_id", "")
			if dm != null and dm.has_method("_add_card_to_backpack") and not card_id.is_empty():
				dm._add_card_to_backpack(card_id)
				# #region agent log
				_debug_log(run_id, "H5", "achievement_rewards.gd:grant", "card_granted", {"card_id": card_id})
				# #endregion
				return true
			return false

	return false

## 检查奖励是否有实际内容
## @param reward: 成就定义中的 reward 字典
## @return bool
static func has_reward(reward: Dictionary) -> bool:
	if reward.is_empty():
		return false
	var reward_type: String = reward.get("type", "")
	return reward_type in ["basic_nano", "energy_block", "phase_xp", "phase_field_xp", "card"]
