extends RefCounted
## 试玩场景库（发行前全功能矩阵测试，用完归档）
## 坐标=1280x720 视口坐标（窗口模式 1:1）。按钮坐标来自运行期 state dump。

static func get_scenario(name: String) -> Dictionary:
	match name:
		"s2_newplayer":
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "probe", "label": "slot_label_before", "path": "CenterContainer/MainVBox/ButtonsVBox/SlotLabel", "prop": "text"},
					{"t": "click", "x": 332, "y": 532},   # 切换存档: 1→2
					{"t": "frames", "n": 30},
					{"t": "probe", "label": "slot_label_after", "path": "CenterContainer/MainVBox/ButtonsVBox/SlotLabel", "prop": "text"},
					{"t": "click", "x": 332, "y": 235},   # 新游戏（槽2 无档→直接开新档）
					{"t": "wait_scene", "match": "comic_intro", "timeout": 900},
					{"t": "frames", "n": 60},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_comic.png"},
					{"t": "click", "x": 1218, "y": 27},   # 跳过›
					{"t": "wait_scene", "match": "truck_base", "timeout": 900},
					{"t": "frames", "n": 180},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_truck1.png"},
					{"t": "frames", "n": 300},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_truck2.png"},
					{"t": "probe", "label": "slot_after_newgame", "path": "/root/SaveManager", "prop": "current_slot"},
				],
			}
		"s2b_battle":
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "probe", "label": "slot_label", "path": "CenterContainer/MainVBox/ButtonsVBox/SlotLabel", "prop": "text"},
					{"t": "click", "x": 332, "y": 532},   # 切换存档（启动默认槽1→2）
					{"t": "frames", "n": 30},
					{"t": "probe", "label": "slot_must_be_2", "path": "CenterContainer/MainVBox/ButtonsVBox/SlotLabel", "prop": "text"},
					{"t": "click", "x": 332, "y": 235},   # 新游戏（槽2 已清空→无确认弹窗）
					{"t": "wait_scene", "match": "comic_intro", "timeout": 900},
					{"t": "frames", "n": 30},
					{"t": "click", "x": 1218, "y": 27},   # 跳过›
					{"t": "wait_scene", "match": "truck_base", "timeout": 900},
					{"t": "frames", "n": 90},
					{"t": "click", "x": 1218, "y": 27},   # 跳过醒来演出（若在播）
					{"t": "frames", "n": 90},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_hub.png"},
					{"t": "call", "path": "/root/TutorialProgressionManager", "method": "get_tutorial_progress"},
					{"t": "call", "path": "/root/TutorialProgressionManager", "method": "execute_tutorial_action", "args": ["next"]},
					{"t": "frames", "n": 40},
					{"t": "call", "path": "/root/TutorialProgressionManager", "method": "execute_tutorial_action", "args": ["next"]},
					{"t": "frames", "n": 40},
					{"t": "call", "path": "/root/TutorialProgressionManager", "method": "get_tutorial_progress"},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_tutorial.png"},
					{"t": "call", "path": "/root/TutorialProgressionManager", "method": "execute_tutorial_action", "args": ["start_first_battle"]},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 900},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_battle_start.png"},
					{"t": "fps", "label": "battle_early"},
					{"t": "wait_sig", "name": "battle_ended", "timeout": 5400},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_aftermath.png"},
					{"t": "fps", "label": "aftermath"},
					{"t": "call", "path": "/root/TutorialProgressionManager", "method": "get_tutorial_progress"},
				],
			}
		"s3_continue":
			# 存档闭环前半：槽2 继续 → 读档 → 内存态逐项比对磁盘基准
			# 基准（save_slot_2.json）：current_level=1 教程step=0 alloy=800 nano=1344
			# crystal=500 energy=1000 卡3张 ft17#1/m81#1/mauser#1
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "click", "x": 332, "y": 532},   # 切换存档 → 槽2
					{"t": "frames", "n": 30},
					{"t": "probe", "label": "slot_must_be_2", "path": "CenterContainer/MainVBox/ButtonsVBox/SlotLabel", "prop": "text"},
					{"t": "click", "x": 332, "y": 293},   # 继续
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 120},
					{"t": "dump", "depth": 6},
					{"t": "probe", "label": "live_slot", "path": "/root/SaveManager", "prop": "current_slot"},
					{"t": "probe", "label": "live_level", "path": "/root/GameManager", "prop": "current_level"},
					{"t": "probe", "label": "live_alloy", "path": "/root/BasicResourceManager", "prop": "total_alloy"},
					{"t": "probe", "label": "live_nano", "path": "/root/BasicResourceManager", "prop": "total_basic_nano"},
					{"t": "probe", "label": "live_crystal", "path": "/root/BasicResourceManager", "prop": "total_crystal"},
					{"t": "probe", "label": "live_energy", "path": "/root/BasicResourceManager", "prop": "total_energy_block"},
					{"t": "call", "path": "/root/TutorialProgressionManager", "method": "get_tutorial_progress"},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_s3_loaded.png"},
					{"t": "quit_ok"},
				],
			}
		"s4_recon":
			# 面板巡视侦察：真实点击教程 overlay 按钮，学习各面板开启/关闭形态
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "click", "x": 332, "y": 532},
					{"t": "frames", "n": 30},
					{"t": "probe", "label": "slot_must_be_2", "path": "CenterContainer/MainVBox/ButtonsVBox/SlotLabel", "prop": "text"},
					{"t": "click", "x": 332, "y": 293},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 120},
					{"t": "click_text", "text": "启程"},
					{"t": "frames", "n": 90},
					{"t": "dump", "depth": 9},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_s4_step2.png"},
					{"t": "click_text", "text": "下一步"},
					{"t": "frames", "n": 90},
					{"t": "dump", "depth": 9},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_s4_step3.png"},
					{"t": "quit_ok"},
				],
			}
		"s4b_hub":
			# 从 L1 战场待命态点"返"退出，侦察 hub 布局与面板入口按钮
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "click", "x": 332, "y": 532},
					{"t": "frames", "n": 30},
					{"t": "click", "x": 332, "y": 293},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 90},
					{"t": "click_text", "text": "跳过"},
					{"t": "frames", "n": 30},
					{"t": "click_text", "text": "返"},
					{"t": "frames", "n": 150},
					{"t": "dump", "depth": 9},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_s4_hub.png"},
					{"t": "quit_ok"},
				],
			}
		"s4c_tour":
			# 面板全巡视：卡车基地 _open_panel 走教程同款真路径；每面板截图后 ESC 关闭
			var tour: Array = []
			for p in ["card_collection", "phase_instrument", "enhancement", "modification",
					"runes", "evolution", "faction_rep", "shop", "phase_field_points", "world_map"]:
				tour.append({"t": "call", "path": ".", "method": "_open_panel", "args": [p]})
				tour.append({"t": "frames", "n": 70})
				tour.append({"t": "shot", "path": "res://.godot/agent_tools/pt_s4_panel_%s.png" % p})
				tour.append({"t": "key", "code": "Escape"})
				tour.append({"t": "frames", "n": 30})
			for extra in ["委托台", "成就", "车长手册", "同伴档案", "纪念墙"]:
				tour.append({"t": "click_text", "text": extra})
				tour.append({"t": "frames", "n": 50})
				tour.append({"t": "shot", "path": "res://.godot/agent_tools/pt_s4_extra_%s.png" % extra})
				tour.append({"t": "key", "code": "Escape"})
				tour.append({"t": "frames", "n": 30})
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "click", "x": 332, "y": 532},
					{"t": "frames", "n": 30},
					{"t": "click", "x": 332, "y": 293},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "call", "path": "/root/TutorialProgressionManager", "method": "skip_tutorial"},
					{"t": "frames", "n": 20},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 90},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_s4_truck_home.png"},
				] + tour + [
					{"t": "fps", "label": "hub_after_tour"},
					{"t": "quit_ok"},
				],
			}
		"s4d_tour2":
			# 面板巡视第二轮：真实 EMBEDDED_PANELS 键名（PANEL_SCENES 全 15 键）
			var tour2: Array = []
			for p in ["backpack", "intelligence", "store", "modification", "growth",
					"affix", "collection", "faction", "leaderboard", "quest",
					"achievement", "hero_archive", "memorial", "help"]:
				tour2.append({"t": "call", "path": ".", "method": "_open_panel", "args": [p]})
				tour2.append({"t": "frames", "n": 70})
				tour2.append({"t": "shot", "path": "res://.godot/agent_tools/pt_s4d_%s.png" % p})
				tour2.append({"t": "click_text", "text": "×", "soft": true})
				tour2.append({"t": "click_text", "text": "关闭", "soft": true})
				tour2.append({"t": "key", "code": "Escape"})
				tour2.append({"t": "frames", "n": 25})
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "click", "x": 332, "y": 532},
					{"t": "frames", "n": 30},
					{"t": "click", "x": 332, "y": 293},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 60},
				] + tour2 + [
					{"t": "quit_ok"},
				],
			}
		"s9_video":
			# 上线演示视频用：干净槽2 全新首畅——标题→新游戏→漫画→卡车→欢迎→跳过教学→出击→首战→结算
			# 运行命令需带 --write-movie <path.avi> --fixed-fps 30；运行前宿主侧清空 save_slot_2*
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 120},
					{"t": "shot", "path": "res://.godot/agent_tools/vid_title.png"},
					{"t": "click", "x": 332, "y": 532},   # 切到槽2
					{"t": "frames", "n": 30},
					{"t": "click", "x": 332, "y": 235},   # 新游戏（空槽直开）
					{"t": "wait_scene", "match": "comic_intro", "timeout": 2400},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/vid_comic.png"},
					{"t": "frames", "n": 300},
					{"t": "click", "x": 1218, "y": 27},   # 跳过›
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 150},
					{"t": "click", "x": 1218, "y": 27},   # 跳过醒来演出
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/vid_truck.png"},
					{"t": "frames", "n": 120},
					{"t": "click_text", "text": "启程"},  # 教程欢迎
					{"t": "frames", "n": 80},
					{"t": "click_text", "text": "跳过"},  # 教学完成（出击自动开战的守卫让路）
					{"t": "frames", "n": 100},
					{"t": "shot", "path": "res://.godot/agent_tools/vid_truck2.png"},
					{"t": "click_text", "text": "出击"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 240},
					{"t": "shot", "path": "res://.godot/agent_tools/vid_battle1.png"},
					{"t": "frames", "n": 600},
					{"t": "shot", "path": "res://.godot/agent_tools/vid_battle2.png"},
					{"t": "frames", "n": 600},
					{"t": "shot", "path": "res://.godot/agent_tools/vid_battle3.png"},
					{"t": "frames", "n": 600},
					{"t": "shot", "path": "res://.godot/agent_tools/vid_battle4.png"},
					{"t": "frames", "n": 900},
					{"t": "click_text", "text": "继续", "soft": true},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/vid_aftermath.png"},
					{"t": "quit_ok"},
				],
			}
		"s4e_tour3":
			# 剩余面板巡视（growth 已单独验证且会全屏遮挡后续面板，故不含）
			var tour3: Array = []
			for p in ["affix", "collection", "faction", "leaderboard", "quest",
					"achievement", "hero_archive", "memorial", "help"]:
				tour3.append({"t": "call", "path": ".", "method": "_open_panel", "args": [p]})
				tour3.append({"t": "frames", "n": 70})
				tour3.append({"t": "shot", "path": "res://.godot/agent_tools/pt_s4e_%s.png" % p})
				tour3.append({"t": "click_text", "text": "×", "soft": true})
				tour3.append({"t": "frames", "n": 25})
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "click", "x": 332, "y": 532},
					{"t": "frames", "n": 30},
					{"t": "click", "x": 332, "y": 293},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 60},
				] + tour3 + [
					{"t": "quit_ok"},
				],
			}
		"s5a_map":
			# 世界地图侦察：战区地图入口 → 地图场景结构 → 关卡入口按钮
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "click", "x": 332, "y": 532},
					{"t": "frames", "n": 30},
					{"t": "click", "x": 332, "y": 293},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "战区地图"},
					{"t": "wait_scene", "match": "world_map", "timeout": 2400},
					{"t": "frames", "n": 120},
					{"t": "dump", "depth": 8},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_s5_map.png"},
					{"t": "quit_ok"},
				],
			}
		"s5b_battle":
			# 正常关卡链闭环：地图进战 → ×4 胜利 → 显式存档 → 验证 level_stars/解锁 → 结算继续
			return {
				"start": "res://scenes/title_screen.tscn",
				"steps": [
					{"t": "frames", "n": 90},
					{"t": "click", "x": 332, "y": 532},
					{"t": "frames", "n": 30},
					{"t": "click", "x": 332, "y": 293},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "返"},
					{"t": "wait_scene", "match": "truck_base", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "战区地图"},
					{"t": "wait_scene", "match": "world_map", "timeout": 2400},
					{"t": "frames", "n": 60},
					{"t": "click_text", "text": "进入本关"},
					{"t": "wait_scene", "match": "scenes/main", "timeout": 2400},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_s5_battle.png"},
					{"t": "fps", "label": "s5_battle"},
					{"t": "wait_sig", "name": "battle_ended", "timeout": 9000},
					{"t": "frames", "n": 150},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_s5_aftermath.png"},
					{"t": "fps", "label": "s5_aftermath"},
					{"t": "call", "path": "/root/LevelProgressManager", "method": "get_level_stars", "args": [1]},
					{"t": "probe", "label": "max_unlocked", "path": "/root/LevelProgressManager", "prop": "max_unlocked_level"},
					{"t": "call", "path": "/root/SaveManager", "method": "save_game"},
					{"t": "frames", "n": 30},
					{"t": "click_text", "text": "继续", "soft": true},
					{"t": "frames", "n": 120},
					{"t": "shot", "path": "res://.godot/agent_tools/pt_s5_after_click.png"},
					{"t": "quit_ok"},
				],
			}
	return {}
