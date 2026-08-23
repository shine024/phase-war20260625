class_name UiCompileCheckTest
extends GdUnitTestSuite
## 临时编译验证：preload v7.x 战力重构改动过的 3 个 UI 脚本 + 核心脚本，
## 确保无语法/类型错误（--check-only 在本环境卡 autoload，改用 GdUnit 编译）。

const PlayerMasterPanel = preload("res://scenes/ui/player_master_panel.gd")
const BottomInstrumentBar = preload("res://scenes/ui/bottom_instrument_bar.gd")
const CardInfoPanel = preload("res://scenes/ui/card_info_panel.gd")
const MasterPowerEvaluator = preload("res://scripts/master_power_evaluator.gd")
const MasterPlayerAssembler = preload("res://scripts/master_player_assembler.gd")
const MasterPlatformPower = preload("res://scripts/master_platform_power.gd")
const EnemyPhaseMasters = preload("res://data/enemy_phase_masters.gd")


func test_scripts_compile() -> void:
	# preload 即编译；脚本能加载 = 语法/类型/依赖全通过
	assert_bool(PlayerMasterPanel != null).is_true()
	assert_bool(BottomInstrumentBar != null).is_true()
	assert_bool(CardInfoPanel != null).is_true()
	assert_bool(MasterPowerEvaluator != null).is_true()
	assert_bool(MasterPlayerAssembler != null).is_true()
	assert_bool(MasterPlatformPower != null).is_true()
	assert_bool(EnemyPhaseMasters != null).is_true()
