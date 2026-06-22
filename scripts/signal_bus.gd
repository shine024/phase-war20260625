extends Node
## 全局信号总线
## 用于战斗、能量、UI 等模块解耦

# 能量
signal energy_changed(current: float, maximum: float)
signal energy_insufficient(amount: float)

# 相位仪 / 装备
signal card_equipped(slot_index: int, card_id: String, card_type: String)
signal card_unequipped(slot_index: int)
signal phase_slots_changed(slots: Array)
signal phase_field_xp_changed(source: String, delta: int, total: int)
signal phase_field_level_up(old_level: int, new_level: int, unspent_points: int)

# 单位生成 / 指令
signal unit_spawned(unit: Node, is_player: bool)
signal unit_died(unit: Node, is_player: bool)
signal unit_selected(unit: Node, is_player: bool, at_position: Vector2)
signal unit_move_command(unit: Node, target_position: Vector2)

# 单位伤害反馈
signal unit_damaged(unit: Node, is_player: bool, amount: float, at_position: Vector2)

# 战斗
signal battle_started()
signal battle_ended(player_won: bool)
signal wave_spawned(wave_index: int)

# 相位场驱动器（我方基地）
signal phase_driver_hp_changed(current: float, maximum: float)
signal phase_driver_destroyed()

# 敌方相位场驱动器（相位师基地）
signal enemy_phase_driver_hp_changed(current: float, maximum: float)
signal enemy_phase_driver_destroyed()

# 卡片 / 背包
signal backpack_changed()
signal card_added_to_backpack(card: CardResource)

# 蓝图（敌人掉落等）
signal blueprint_unlocked(card_id: String)
signal blueprint_star_upgraded(card_id: String, new_star: int)
signal blueprint_obtained(card_id: String, count: int)

# 战斗掉落领取
signal drops_ready_to_claim(drops: Array)

# 主动法则施放：点击法则后进入选点模式，再点战场即在此信号中传出
# 曲线/箭头起点：来自“点击的法则格”的屏幕位置（用于映射到战场子视口坐标）
signal active_law_cast_at(law_id: String, world_pos: Vector2)
signal phase_law_runtime_changed()

# 单位部署：战斗中点击绿槽的平台/合成卡后，再点战场放置虚影 → 计时后实体化
## reason_code: out_of_bounds | insufficient_energy | max_units | unit_on_field | invalid_loadout | internal
signal player_deploy_failed(reason_code: String, message: String)

# 新系统信号
# 相位法则施放效果
signal phase_law_cast(law_id: String, position: Vector2, family: String)

# 成就系统
signal achievement_unlocked(achievement_id: String, achievement_name: String)
signal achievement_progress_updated(achievement_id: String, current_progress: int, max_progress: int)
signal milestone_reached(milestone_id: String, milestone_name: String)

# 日常任务系统
signal daily_tasks_refreshed()
signal quest_completed(quest_id: String, rewards: Dictionary)
signal task_completed(task: Dictionary)
signal task_reward_granted(task: Dictionary)
signal all_tasks_completed()

# 挑战模式
signal challenge_started(challenge_type: int, difficulty: int) ## challenge_type 对应 ChallengeModeManager.ChallengeType, difficulty 对应 ChallengeModeManager.ChallengeDifficulty
signal challenge_completed(challenge_type: int, difficulty: int, result: Dictionary) ## challenge_type 对应 ChallengeModeManager.ChallengeType, difficulty 对应 ChallengeModeManager.ChallengeDifficulty
signal challenge_failed(challenge_type: int, reason: String) ## challenge_type 对应 ChallengeModeManager.ChallengeType

# 卡牌收集
signal card_obtained(card_id: String)
signal card_max_level(card_id: String)
signal collection_milestone_reached(milestone: Dictionary)

# 故事系统
signal story_chapter_started(chapter_id: String)
signal story_node_reached(node_index: int)
signal story_choice_made(choice_result: String)
signal story_chapter_completed(chapter_id: String)

# 角色系统
signal relationship_changed(character_id: String, new_value: int)
signal character_unlocked(character_id: String)

# 音效播放（战斗反馈）
signal play_sound(sound_id: String)

# UI 切换（教程驱动）
signal toggle_backpack()
signal toggle_phase_instrument()
signal toggle_factions()
signal toggle_phase_laws()

# 教程
signal tutorial_completed(tutorial_id: String)

# 关卡/流程控制
signal start_level(level: int)
signal level_selected(level: int)

# 塔爬模式
# @deprecated v6.0 — 爬塔模式已移除，以下信号保留仅供存档兼容
# signal tower_run_started()
# signal tower_floor_changed(floor: int)
# signal tower_run_ended(victory: bool, final_floor: int, final_score: int)
# signal tower_reward_offered(choices: Array)
# signal tower_hp_changed(current: int, maximum: int)
# signal tower_gold_changed(gold: int)
# signal tower_reward_selected(reward: Dictionary)
# signal tower_state_changed(state: int)
# signal tower_relic_obtained(relic_id: String)

# 故事 UI
signal show_story_ui(chapter: String, first_node: int)
signal show_story_node(node_index: int)

# v6.3: 剧情模式信号
signal story_show_pre_battle_dialogue(chapter_id: String)     ## 显示战前对话
signal story_show_post_battle_dialogue(chapter_id: String)    ## 显示战后对话
signal story_show_chapter_select()                            ## 显示章节选择面板
signal story_chapter_selected(chapter_id: String)             ## 玩家选择了某章节
signal story_campaign_completed()                             ## 剧情模式全部完成
signal story_dialogue_finished()                              ## 对话播放完毕

# v6.7(剧情任务): 自由模式关卡剧情任务（docs/补剧情.txt 关卡映射）
# GameManager 在进关/过关时 emit，story_dialogue_panel 监听后播放对应任务的对话
# phase = "pre"（战前）/ "post"（战后）
signal story_mission_dialogue(quest_id: String, phase: String)

# v6.6(剧情): docs/补剧情.txt 城市循环模式专用信号
signal city_day_started(day: int)                              ## 每天开始（DayClock.day_started 镜像转发）
signal city_emergency(announcement: String)                    ## 全城紧急事件（如海伦宣告倒计时）
signal helen_guidance(message: String)                         ## 海伦主动引导提示
signal npc_event(npc_id: String, event_key: String)            ## NPC 剧情事件（林薇归来/洛克失踪等）

# 通用 UI 反馈
signal show_toast(message: String)

# v6.2: 符文系统信号
signal rune_acquired(rune_id: String, source: String)  ## 获得符文（掉落/购买/奖励）

# 日常任务
signal daily_task_reward_granted(task: Dictionary)

# 战斗掉落奖励
signal kill_reward_granted(reward_type: String, amount: float)

# 情报手册系统
# v6.6 现状说明：以下情报/阵营/合成/强化/改造/成长/进化系统的 SignalBus 信号
# 目前均为"声明未接通"状态——真实事件流发生在各 manager 的本地 signal 上
# （如 IntelManual.intel_dimension_changed、FactionSystemManager.faction_reputation_changed、
#   SynthesisManager.synthesis_completed 等）。
# 这是因为相关 manager 在 v6.0 重构时改用本地 signal 解耦，未同步迁移到 SignalBus。
# 后续若需统一总线化，应在各 manager emit 本地信号处追加 SignalBus.xxx.emit()。
# 保留这些声明供未来接通或外部插件监听使用，不影响当前功能。
signal intel_updated(card_id: String, progress: float, tier: int)
signal intel_unlocked(card_id: String)
signal intel_tier_reached(card_id: String, tier: int)

# 势力系统
signal faction_reputation_changed(faction_id: String, delta: int, new_value: int)
signal faction_level_up(faction_id: String, new_level: int)
signal faction_store_updated(faction_id: String)
signal active_faction_changed(faction_id: String)
signal faction_skill_unlocked(faction_id: String, skill_id: String)
signal faction_event_generated(event: Dictionary)

# 合成系统
signal synthesis_completed(hybrid_card_id: String)
signal synthesis_failed(reason: String)

# 强化系统
signal card_reinforced(card_id: String, old_level: int, new_level: int)
signal reinforcement_failed(card_id: String, reason: String)

# 改造系统
signal modification_installed(card_id: String, mod_id: String)
signal modification_removed(card_id: String, mod_id: String)
signal modification_failed(card_id: String, mod_id: String, reason: String)

# 成长面板系统
signal growth_panel_saved(card: CardResource)
signal card_data_changed(card_id: String)

# 进化系统
signal card_evolved(source_card_id: String, target_card_id: String)
signal evolution_failed(source_card_id: String, target_card_id: String, reason: String)
signal evolution_path_unlocked(card_id: String, branch_name: String)
