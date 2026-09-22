extends RefCounted
## 可玩性回归专用场景（追加，不动 _playtest_scenarios.gd）
## 关键差异：切槽用 SaveManager.set_slot(2) 程序化调用，不再依赖坐标点击（v38 后标题屏布局漂移导致点击失准）。
## 槽 2 状态：新档·第 1 关未通（save_slot_2.json max_unlocked=1）→ 本关按钮应为「▶ 进入本关」非通关态。

static func get_scenario(name: String) -> Dictionary:
	match name:
		"r_s5b":
			# 关卡链闭环（槽2 程序化切槽版）
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "probe", "label": "slot_must_be_2", "path": "/root/SaveManager", "prop": "current_slot"},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 90},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "战区地图"},
					{"t": "wait_scene", "match": "world_map", "timeout": 2400},
					{"t": "frames", "n": 90},
					{"t": "probe", "label": "parked_slot", "path": "/root/SaveManager", "prop": "current_slot"},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_s5_map.png"},
					{"t": "click_text", "text": "进入本关"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 120},
					{"t": "call", "path": ".", "method": "_on_start_battle"},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_s5_battle.png"},
					{"t": "fps", "label": "s5_battle"},
					{"t": "wait_sig", "name": "battle_ended", "timeout": 9000},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_s5_aftermath.png"},
					{"t": "fps", "label": "s5_aftermath"},
					{"t": "call", "path": "/root/LevelProgressManager", "method": "get_level_stars", "args": [1]},
					{"t": "probe", "label": "max_unlocked", "path": "/root/LevelProgressManager", "prop": "max_unlocked_level"},
					{"t": "call", "path": "/root/SaveManager", "method": "save_game"},
					{"t": "frames", "n": 30},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_s5_end.png"},
					{"t": "quit_ok"},
				],
			}
		"r_s4d", "r_s4d_0", "r_s4d_1", "r_s4d_2", "r_s4d_3", "r_s4d_4":
			# 面板巡视（槽2 程序化切槽版，PANEL_SCENES 全键）
			# r_s4d_* 为分批版：ANGLE/D3D11 视口回读（get_image）会在连续截图 2-4 张后堆损坏崩溃，
			# 每批 ≤3 面板、批间独立进程规避。批定义：
			var batches := {
				"r_s4d_0": ["backpack", "intelligence", "store"],
				"r_s4d_1": ["modification", "affix", "collection"],
				"r_s4d_2": ["faction", "leaderboard", "quest"],
				"r_s4d_3": ["achievement", "hero_archive", "memorial"],
				"r_s4d_4": ["help", "growth"],
			}
			var panels: Array = batches.get(name, ["backpack", "intelligence", "store", "modification",
					"affix", "collection", "faction", "leaderboard", "quest",
					"achievement", "hero_archive", "memorial", "help", "growth"])
			var tour: Array = []
			for p in panels:
				tour.append({"t": "call", "path": ".", "method": "_open_panel", "args": [p]})
				tour.append({"t": "frames", "n": 70})
				tour.append({"t": "shot", "path": "res://.godot/agent_tools/pr_s4d_%s.png" % p})
				tour.append({"t": "click_text", "text": "×", "soft": true})
				tour.append({"t": "click_text", "text": "关闭", "soft": true})
				tour.append({"t": "key", "code": "Escape"})
				tour.append({"t": "frames", "n": 25})
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 60},
				] + tour + [
					{"t": "quit_ok"},
				],
			}
		"r_s4d_h":
			# 高进度面板巡视（槽2 内存注入 max=30，不落盘）：新档下 modification/store/collection
			# 被渐进解锁门控（truck_base._open_panel:1840 直接 return），无法巡视内容。
			# 每面板后显式 _close_top_embed_panel ×2 收口——_open_panel 不互斥，叠层污染后续截图。
			var levels: Array = []
			for i in range(1, 31):
				levels.append(i)
			var tour: Array = []
			for p in ["backpack", "intelligence", "store", "modification",
					"affix", "collection", "faction", "leaderboard", "quest",
					"achievement", "hero_archive", "memorial", "help", "growth"]:
				tour.append({"t": "call", "path": ".", "method": "_open_panel", "args": [p]})
				tour.append({"t": "frames", "n": 70})
				tour.append({"t": "shot", "path": "res://.godot/agent_tools/pr_s4dh_%s.png" % p})
				tour.append({"t": "call", "path": ".", "method": "_close_top_embed_panel"})
				tour.append({"t": "call", "path": ".", "method": "_close_top_embed_panel"})
				tour.append({"t": "frames", "n": 25})
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "call", "path": "/root/LevelProgressManager", "method": "load_state", "args": [{"unlocked_levels": levels}]},
					{"t": "frames", "n": 15},
				] + tour + [
					{"t": "quit_ok"},
				],
			}
		"r_perf2":
			# 标题屏 FPS 复测：首采 12 FPS 疑为启动 shader 编译峰，预热 8s 后再采
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 150},
					{"t": "fps", "label": "title_cold"},
					{"t": "frames", "n": 480},
					{"t": "fps", "label": "title_warm"},
					{"t": "quit_ok"},
				],
			}
		"r_perf":
			# Task 7.1 性能四点采样：标题屏 / 关卡内待机 / 主基地(bunker) / 战区地图
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 150},
					{"t": "fps", "label": "title"},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 150},
					{"t": "fps", "label": "battlefield_idle"},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 150},
					{"t": "fps", "label": "truck_base"},
					{"t": "click_text", "text": "战区地图"},
					{"t": "wait_scene", "match": "world_map", "timeout": 2400},
					{"t": "frames", "n": 150},
					{"t": "fps", "label": "world_map"},
					{"t": "quit_ok"},
				],
			}
		"r_p2_newsave":
			# P2 核销复测（2026-09-20 报告）：新档教程链首战——结算"出击下一关"应为
			# "第 2 关"（_pending_battle_level 进战捕获=1）。前置：槽 2 存档文件必须先删
			#（bash 侧清场），否则标题屏走"覆盖确认弹窗"分支点不进新档。
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "新游戏 NEW GAME"},
					{"t": "frames", "n": 20},
					# set_slot 后内存可能残留他槽档数据 → v38.5 覆盖确认弹窗，需点掉
					{"t": "click_text", "text": "覆盖并开始", "soft": true},
					{"t": "wait_scene", "match": "comic_intro", "timeout": 2400},
					{"t": "frames", "n": 30},
					{"t": "click_text", "text": "跳过 ›", "soft": true},
					{"t": "wait_scene", "match": "truck_base", "timeout": 3600},
					{"t": "frames", "n": 30},
					{"t": "click_text", "text": "跳过 ›", "soft": true},
					{"t": "frames", "n": 90},
					{"t": "click_text", "text": "跳过", "soft": true},
					{"t": "frames", "n": 60},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_p2_truck.png"},
					{"t": "click_text", "text": "▶ 出击"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 120},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_p2_battle.png"},
					{"t": "wait_sig", "name": "battle_ended", "timeout": 9000},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_p2_aftermath.png"},
					{"t": "probe", "label": "pending_lvl", "path": "/root/GameManager", "prop": "_pending_battle_level"},
					{"t": "probe", "label": "cur_lvl", "path": "/root/GameManager", "prop": "current_level"},
					{"t": "probe", "label": "max_unlocked", "path": "/root/LevelProgressManager", "prop": "max_unlocked_level"},
					{"t": "quit_ok"},
				],
			}
		"r_t31_cards":
			# Task 3.1：卡牌养成面板实机链——卡仓/制造/改造开合 + 实例链探针。
			# 前置：r_p2_newsave 已在槽 2 产出"首战胜"档（制造已解锁，成长可见）；
			# 改造需 L6 → 用 LPM.load_state 内存注入放宽（不落盘，run3 同款）。
			var lv31: Array = []
			for i in range(1, 31):
				lv31.append(i)
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 90},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "call", "path": "/root/LevelProgressManager", "method": "load_state", "args": [{"unlocked_levels": lv31}]},
					{"t": "frames", "n": 15},
					{"t": "call", "path": "/root/InstanceRegistry", "method": "get_all_instance_ids", "args": []},
					{"t": "call", "path": ".", "method": "_open_panel", "args": ["backpack"]},
					{"t": "frames", "n": 70},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_t31_backpack.png"},
					{"t": "call", "path": ".", "method": "_close_top_embed_panel"},
					{"t": "frames", "n": 25},
					{"t": "call", "path": ".", "method": "_open_panel", "args": ["evolution"]},
					{"t": "frames", "n": 70},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_t31_evolution.png"},
					{"t": "call", "path": ".", "method": "_close_top_embed_panel"},
					{"t": "frames", "n": 25},
					{"t": "call", "path": ".", "method": "_open_panel", "args": ["modification"]},
					{"t": "frames", "n": 70},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_t31_modification.png"},
					{"t": "call", "path": ".", "method": "_close_top_embed_panel"},
					{"t": "frames", "n": 25},
					{"t": "quit_ok"},
				],
			}
		"r_t61_save":
			# Task 6.1 写侧：内存加 77 纳米 → 显式 save_game → 退出（r_t61_verify 读回核对）。
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "probe", "label": "nano_before", "path": "/root/BasicResourceManager", "prop": "total_nano_materials"},
					{"t": "call", "path": "/root/BasicResourceManager", "method": "add_resource", "args": ["nano_materials", 77]},
					{"t": "probe", "label": "nano_after", "path": "/root/BasicResourceManager", "prop": "total_nano_materials"},
					{"t": "call", "path": "/root/SaveManager", "method": "save_game", "args": []},
					{"t": "frames", "n": 30},
					{"t": "quit_ok"},
				],
			}
		"r_t61_verify":
			# Task 6.1 读侧：新进程读档，纳米应=写侧 after 值（磁盘→内存闭环）。
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "probe", "label": "nano_reloaded", "path": "/root/BasicResourceManager", "prop": "total_nano_materials"},
					{"t": "probe", "label": "cur_lvl_reloaded", "path": "/root/GameManager", "prop": "current_level"},
					{"t": "quit_ok"},
				],
			}
		"r_t62_corrupt":
			# Task 6.2 异常路径：槽 3 主档为坏 JSON（备份提前移走）→ 加载应优雅降级
			#（新档状态进游戏 / 停留标题均可，判据=零崩溃零脚本错误）。
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [3]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 90},
					{"t": "probe", "label": "corrupt_cur_lvl", "path": "/root/GameManager", "prop": "current_level"},
					{"t": "probe", "label": "corrupt_slot", "path": "/root/SaveManager", "prop": "current_slot"},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_t62_corrupt.png"},
					{"t": "quit_ok"},
				],
			}
		"r_t53_uiqa":
			# Task 5.3 抽检复核：委托台页签本地化（quest_panel set_tab_title）+
			# 图鉴稀有度页签口径（collection_panel._is_owned 重算）。高进度内存注入。
			var lv53: Array = []
			for i in range(1, 31):
				lv53.append(i)
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "call", "path": "/root/LevelProgressManager", "method": "load_state", "args": [{"unlocked_levels": lv53}]},
					{"t": "frames", "n": 15},
					{"t": "call", "path": ".", "method": "_open_panel", "args": ["quest"]},
					{"t": "frames", "n": 70},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_t53_quest.png"},
					{"t": "call", "path": ".", "method": "_close_top_embed_panel"},
					{"t": "frames", "n": 25},
					{"t": "call", "path": ".", "method": "_open_panel", "args": ["collection"]},
					{"t": "frames", "n": 70},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_t53_collection.png"},
					{"t": "call", "path": ".", "method": "_close_top_embed_panel"},
					{"t": "frames", "n": 25},
					{"t": "call", "path": ".", "method": "_open_panel", "args": ["affix"]},
					{"t": "frames", "n": 70},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_t53_affix.png"},
					{"t": "call", "path": ".", "method": "_close_top_embed_panel"},
					{"t": "frames", "n": 25},
					{"t": "quit_ok"},
				],
			}
		"r_t54_growth":
			# 续批复核：技能板 LANE_SLOTS 4→5 加宽后实机渲染确认
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "call", "path": ".", "method": "_open_panel", "args": ["growth"]},
					{"t": "frames", "n": 90},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_t54_growth.png"},
					{"t": "call", "path": ".", "method": "_close_top_embed_panel"},
					{"t": "frames", "n": 25},
					{"t": "quit_ok"},
				],
			}
		"r_t20_projvisual":
			# 新弹体贴图实机观感：继续直入 main 开战（绕开基地/地图停靠态漂移）
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "call", "path": ".", "method": "_on_start_battle"},
					{"t": "frames", "n": 200},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_t20_battle1.png"},
					{"t": "frames", "n": 120},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_t20_battle2.png"},
					{"t": "wait_sig", "name": "battle_ended", "timeout": 12000},
					{"t": "quit_ok"},
				],
			}
		"r_p1_pm_garrison":
			# P1-2 人工B-PM关走查（自动化替身）：L10 驻守关（相位师 100% 遭遇）——
			# 内存放宽解锁到 30，直开 L10 战斗；判据=boss 波信号 + 战斗链完整 + 结算渲染
			#（新手卡打 L10 预期败局，败局结算同在覆盖范围）。
			var lv10: Array = []
			for i in range(1, 31):
				lv10.append(i)
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "call", "path": "/root/SaveManager", "method": "set_slot", "args": [2]},
					{"t": "frames", "n": 15},
					{"t": "click_text", "text": "继续"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "call", "path": "/root/LevelProgressManager", "method": "load_state", "args": [{"unlocked_levels": lv10}]},
					{"t": "frames", "n": 15},
					{"t": "call", "path": "/root/GameManager", "method": "set_current_level", "args": [10]},
					{"t": "frames", "n": 15},
					{"t": "call", "path": ".", "method": "_on_start_battle"},
					{"t": "frames", "n": 100},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_p1_pm_intro.png"},
					{"t": "wait_sig", "name": "boss_wave_started", "timeout": 8000},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_p1_pm_battle.png"},
					{"t": "wait_sig", "name": "battle_ended", "timeout": 20000},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/pr_p1_pm_aftermath.png"},
					{"t": "probe", "label": "pm_pending_lvl", "path": "/root/GameManager", "prop": "_pending_battle_level"},
					{"t": "quit_ok"},
				],
			}
	return {}
