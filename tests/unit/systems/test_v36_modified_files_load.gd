extends GdUnitTestSuite
## v36 改动文件全量加载烟雾测试：在 gdunit 全 autoload 环境下 load 全部本批改动脚本，
## 兜住 --script 裸跑模式编译不了的 autoload 引用链（项目在案限制）。后续批次可追加。

const FILES := [
	"data/enemy_unit_manifest.gd",
	"data/level_eras.gd",
	"scripts/battle/construct_unit_ai.gd",
	"scenes/units/enemy_unit.gd",
	"scripts/battle/construct_unit_deploy.gd",
	"scenes/ui/auto_deploy_controller.gd",
	"scripts/battle/ground_loot_layer.gd",
	"managers/save_manager.gd",
	"managers/toast_manager.gd",
	"scenes/intro/comic_intro.gd",
	"managers/tutorial_progression_manager.gd",
	"scenes/ui/tutorial_overlay.gd",
	"scenes/world_map.gd",
	"scenes/ui/afk_panel.gd",
	"scripts/systems/afk_mode_manager.gd",
	"data/phase_master_skill_tree.gd",
	"data/phase_master_skill_tree_v8_extension.gd",
	"managers/phase_master_skill_manager.gd",
	"managers/battle/battle_spawn_system.gd",
	"resources/game_config.gd",
	"data/company_definitions.gd",
	"scenes/ui/phase_master_skill_panel.gd",
]


func test_all_modified_files_compile_with_autoloads() -> void:
	var broken: Array = []
	for f in FILES:
		var s = load("res://" + f)
		# load 返回非 null 不代表编译成功：引用未注册 autoload 时 GDScript 处于坏态，
		# 静态成员不可见（如 AFKModeManager.State 拿不到）。用成员可见性判别。
		var ok: bool = s != null and not (s as Script).get_script_method_list().is_empty()
		if not ok:
			broken.append(f)
	assert_array(broken).override_failure_message(
		"编译失败：%s" % str(broken)).is_empty()
