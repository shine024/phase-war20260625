extends Node
## 全局信号总线
## 用于战斗、能量、UI 等模块解耦

# 能量
signal energy_changed(current: float, maximum: float)
signal energy_insufficient(amount: float)

# 相位仪 / 装备
signal card_equipped(slot_index: int, card_id: String, card_type: String)
## 换装原子信号：槽位原有 old_card 被替换为 new_card_id（=instance_id，缺省回退 card_id）。
## 订阅者一次性完成"移新卡出包 + 加旧卡入包"（先移后加），避免 card_added_to_backpack(old) +
## card_equipped(new) 双信号中间态导致背包重复（"换装多出一张卡"bug 的根因）。
## 仅 equip_card 的"替换已有卡"分支 emit；装到空槽仍走 card_equipped，unequip 仍走 card_added_to_backpack。
signal card_swapped(slot_index: int, old_card: CardResource, new_card_id: String)
# v7.x 现状：card_unequipped 由 phase_instrument_manager/phase_instrument_loadout_sync 在卸下时 emit，
# 但无 SignalBus 订阅者——卸下时"卡归还背包"的状态同步实际由同一处的 card_added_to_backpack.emit 覆盖
# （save_manager/backpack_presenter 均订阅 card_added_to_backpack）。此信号保留供需要"按槽位感知卸载"的
# 订阅者使用，属合法预留，非 bug。
signal card_unequipped(slot_index: int)
signal phase_slots_changed(slots: Array)
signal phase_field_xp_changed(source: String, delta: int, total: int)
signal phase_field_level_up(old_level: int, new_level: int, unspent_points: int)
# v8.x: 相位场属性点分配/回收/重置时触发，UI 据此刷新（区别于 phase_field_level_up 的"升级"语义）
signal phase_field_points_changed(unspent_points: int)

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
# v9.x UI 性能：单位数变化广播（替代各 UI 面板各自 _process 轮询 BattleManager 计数）。
# BattleManager 在单位 spawn/die 后 emit，top_hud_bar / battle_status_strip 监听刷新。
signal unit_counts_changed(player_count: int, enemy_count: int)

# 相位场驱动器（我方基地）
signal phase_driver_hp_changed(current: float, maximum: float)
signal phase_driver_destroyed()

# 敌方相位场驱动器（相位师基地）
# v7.x 现状：enemy_phase_driver_hp_changed 由 enemy_phase_field_driver emit，但无 SignalBus 订阅者——
# 敌方血条 UI（card_info_panel._show_enemy_phase_driver）走"点击时按需读节点"机制，不订阅信号。
# 玩家方 phase_driver_hp_changed 的订阅者（battle_hud._on_phase_driver_hp_changed）也是 pass 空实现（血条由 main.tscn 独立面板处理）。
# 此信号保留供未来需要"敌方血量实时推送"的订阅者使用，属合法预留，非 bug。
signal enemy_phase_driver_hp_changed(current: float, maximum: float)
signal enemy_phase_driver_destroyed()

# 卡片 / 背包
signal backpack_changed()
signal card_added_to_backpack(card: CardResource)

# 卡牌掉落解锁（v7.x）：掉落/购买/奖励获得卡时的总线广播（蓝图解锁体系已移除）

# 战斗掉落领取
# v7.x 现状：掉落领取 UI 走 backpack_changed 刷新，post_battle 掉落经 battle_ended → GameManager 流程处理。
# 2026-08-22 清理：drops_ready_to_claim 信号及其 emit 已移除——全项目零订阅者、零触发链路
# （原 emit 点 battle_damage_system 同步删除；如需"掉落就绪推送"从 git 历史找回）。

# v9.x（P2-7范围B）：active_law_cast_at / phase_law_runtime_changed / phase_law_cast
# 三条法则信号已随法则系统退役移除

# 单位部署：战斗中点击绿槽的平台/合成卡后，再点战场放置虚影 → 计时后实体化
## reason_code: out_of_bounds | insufficient_energy | max_units | unit_on_field | invalid_loadout | internal
signal player_deploy_failed(reason_code: String, message: String)

# 新系统信号

# 存档系统
# v9.x（P1-4 批次5）：主档损坏/缺失经备份恢复成功时发出（标题屏/存档位面板接此弹 toast）
signal save_restored_from_backup(slot: int)

# 成就系统
signal achievement_unlocked(achievement_id: String, achievement_name: String)
signal achievement_progress_updated(achievement_id: String, current_progress: int, max_progress: int)

# 日常任务系统
signal daily_tasks_refreshed()
signal quest_completed(quest_id: String, rewards: Dictionary)
# v7.3 修复 BUG-6: 补 quest_accepted/quest_progress_changed 镜像信号。
# 原 SignalBus 只有 quest_completed，QuestManager 的 quest_accepted/quest_progress_changed 无全局镜像，
# 违背 v6.6 "全局监听者订阅 SignalBus 版本" 的设计意图。
# v7.x 现状：quest_manager 已 emit 这两个镜像信号；当前直接订阅者（quest_panel）仍连 manager 本地信号，
# 此镜像供"不直接持有 QuestManager 的全局订阅者"使用，属合法预留，非 bug。
signal quest_accepted(quest_id: String)
signal quest_progress_changed(quest_id: String)
signal task_completed(task: Dictionary)
# v7.x 数据一致性核对：原 task_reward_granted 为死声明（与 daily_task_reward_granted 同义重复，从未 emit），
# 已删除。日常任务奖励发放统一用 daily_task_reward_granted（daily_task_manager emit）。

# 挑战模式

# 卡牌收集

# 角色系统

# 音效播放（战斗反馈）
signal play_sound(sound_id: String)

# UI 切换（教程驱动）
signal toggle_backpack()
signal toggle_phase_instrument()
# v7.x 教程引导：强化/改造面板切换（main.gd _on_*_from_tutorial 监听）
signal toggle_enhancement()
signal toggle_modification()
# v9.x（P2-4 批次6）：教程中后期引导步骤的面板入口
signal toggle_evolution()
signal toggle_faction()
signal toggle_store()
signal toggle_world_map()
signal open_phase_field_points()

# 教程
signal tutorial_completed(tutorial_id: String)

# 关卡/流程控制
signal start_level(level: int)

# v9.x 清理（2026-08-22）：爬塔模式注释信号块已删——注释代码不参与序列化，
# 爬塔 v6.0 已移除，无任何存档兼容价值

# 通用 UI 反馈
signal show_toast(message: String)

# v7.x 面板统一：main.gd overlay 开关的全局广播（高亮联动/统计解耦用）
signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

# v6.2: 符文系统信号
signal rune_acquired(rune_id: String, source: String)  ## 获得符文（掉落/购买/奖励）

# 日常任务
signal daily_task_reward_granted(task: Dictionary)

# 战斗掉落奖励

# 情报手册系统
# 事件流在各 manager 的本地 signal 上（如 IntelManual.intel_dimension_changed），
# 未迁移到 SignalBus。需要全局监听时直接订阅对应 manager。

# 势力系统
signal faction_reputation_changed(faction_id: String, delta: int, new_value: int)
signal faction_level_up(faction_id: String, new_level: int)
signal faction_store_updated(faction_id: String)
signal active_faction_changed(faction_id: String)
signal faction_skill_unlocked(faction_id: String, skill_id: String)
signal faction_event_generated(event: Dictionary)
# v6.10: 占领状态机——关卡领地易主（攻克后玩家激活势力接管）
signal occupation_changed(level: int, old_faction: String, new_faction: String)

# 合成系统
# v9.x（P2-7范围C）：synthesis_completed/synthesis_failed 已随合成系统删除移除

# 强化系统

# 改造系统

# 成长面板系统

# 进化系统

# v7.x 实例生命周期（转发 InstanceRegistry.instance_disposed，供背包/存档清理幽灵 instance_id）
signal instance_disposed(instance_id: String)

# v7.x(A3): 可访问性运行时变更。由 DesignTokens.set_accessibility 经由本总线广播，
# 已打开的面板/血条/能量条等监听以即时重绘（GDScript 不支持 static signal，故走 autoload）。
signal accessibility_changed()

# v7.x 战场视觉反馈（克制版）
# 击杀事件：含击杀者，供 BattleSpectacle/BattleLog/MVP 使用。killer 可能为 null（环境死/超时死）。
signal unit_killed(victim: Node, killer: Node, is_player_victim: bool)
# BOSS 波次开始：本波 boss archetype_id 列表，供 BattleSpectacle 播放 BOSS 登场特效。
signal boss_wave_started(boss_archetype_ids: Array)
# 相位师登场：相位师战开始时广播 master_config，供 Announcer/Spectacle 播报。
signal phase_master_appeared(master_config: Dictionary)
# v7.x 玩家相位师战力变化：战斗开始算出玩家相位师星级/等级后广播，
# 供 bottom_instrument_bar 等更新玩家相位师等级显示。
# raw_score: 真实总分（不压缩）；score_alias: 兼容参数（与 raw_score 相同）；stars/star_name: 星级；display_level: Lv5-30
signal player_phase_master_power_changed(raw_score: float, score_alias: float, stars: int, star_name: String, display_level: int)
# 符文之语激活：RunewordMatcher 命中时广播，供 Announcer 播报。
signal runeword_triggered(rw_id: String, unit: Node)
# v10 解题式玩法：标签克制质变生效（break_effect 命中）时广播，供 Announcer 播报"敌方优势瓦解"横幅。
# break_type: strip_fort_aura / ground_aircraft / interrupt_cast / guaranteed_crit
# target_name: 目标显示名（Announcer 用）
signal counter_break_triggered(break_type: String, target_name: String)
# v8.1 相位仪主动能力触发：供 BattleSpectacle 编排全屏演出。
# ability_id: 能力标识（nuclear_bombardment/nano_swarm/mega_shield 等）
# stage: "warning"(预警) / "impact"(命中) / "start"(开局开始) / "end"(结束)
# params: 自定义参数（位置/伤害值/持续时间等）
signal phase_instrument_ability_triggered(ability_id: String, stage: String, params: Dictionary)

# ── v8.5 兵种机制技能 VFX 信号（battle_spectacle 监听播特效）──
# 定向爆破（侦察）：from 发射点 → to 目标点（抛物线弹+爆炸）
signal mechanism_demolition_fired(from_pos: Vector2, to_pos: Vector2)
# 瞄准狙击锁定（狙击就绪时，pos 为狙击单位位置，播瞄准镜十字线）
signal mechanism_sniper_aim_locked(pos: Vector2)
# 瞄准狙击开火（消费瞄准时，from→to 播红色锁定框+射击线）
signal mechanism_sniper_fired(from_pos: Vector2, to_pos: Vector2)
# 闪电穿插开火（装甲穿透射击时，from→to 播贯穿光线+后排命中标记）
signal mechanism_blitz_fired(from_pos: Vector2, to_pos: Vector2)
# 电子屏蔽（防空/电子战释放屏蔽波，center+radius 播紫色扩散波纹）
signal mechanism_jamming_field_activated(center: Vector2, radius: float)
# 战术核武（导弹发射井发射核弹：from→to 弹道飞行+落点预警+多层核爆+震屏）
# owner_str: "player"/"enemy" 用于敌我配色（当前仅玩家发射井，预留敌方扩展）
# victims: [{"target": Node, "damage": float, "attacker": Node}, ...] 发射时锁定的目标列表
#   伤害结算延后到 battle_spectacle 的爆炸回调（tween_callback），避免「敌人先死、导弹还在飞」脱节
#   延迟期间目标可能移动，但 victims 在发射时已锁定，结算不重算位置（A1 风险缓解）
signal mechanism_nuclear_launched(from_pos: Vector2, target_pos: Vector2, owner_str: String, victims: Array)
# 护盾投射（堡垒投射护盾，from 施放者 + target_positions 多个友军位置，播蓝色护盾展开）
signal mechanism_shield_projected(from_pos: Vector2, target_positions: Array)
# 无人机定时标记（无人机标记敌方，from 无人机 + target_positions 多个敌方位置，播红色锁定框+扫描波纹）
signal mechanism_drone_marked(from_pos: Vector2, target_positions: Array)
