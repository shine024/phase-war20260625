extends GdUnitTestSuite
## 防复活锁：RefCounted 拖拽辅助类编译完整性（v6.53 拖拽装配瘫痪批）
##
## 根因档案：v6.53（记录1二轮#2）在两个 extends RefCounted 的拖拽辅助类里裸调
## get_node_or_null（Node 方法，RefCounted 无此函数）→ 两脚本编译失败 →
## 级联 bottom_instrument_bar.gd（相位仪栏）与 backpack_card_item.gd（背包卡格）
## 依赖链整体编译崩溃 → 背包里既无卡格也无绿槽 =「战斗卡拉不到相位仪格子装配」
## 实机主诉。单元教程锁只测 TPM 门逻辑、不实例化这条 UI 链，故 25/25 绿而实机全炸。
##
## 本锁三层拦截：
##   1) 两脚本 load 后可实例化（编译失败的 GDScript can_instantiate()=false）
##   2) 源码级断言：两个 RefCounted 文件禁止裸调 get_node_or_null（行内无接收者）
##   3) helper 存在：_autoload_node / _host_autoload_node（RefCounted 取 autoload 唯一口）

const HELPER_SCRIPTS: Array = [
	"res://scenes/ui/backpack_card_item_drag.gd",
	"res://scenes/ui/instrument_bar_drag.gd",
]


func test_drag_helper_scripts_compile_and_instantiate() -> void:
	for path in HELPER_SCRIPTS:
		var s: Script = load(path)
		assert_object(s).is_not_null()
		# 编译失败（含"函数不存在于 base self"类 parse error）时 can_instantiate 恒 false
		assert_bool(s.can_instantiate()) \
			.override_failure_message("拖拽辅助类编译失败（RefCounted 裸调 Node 方法？）: " + path) \
			.is_true()


func test_refcounted_drag_helpers_no_bare_get_node_or_null() -> void:
	for path in HELPER_SCRIPTS:
		var src := FileAccess.get_file_as_string(path)
		assert_int(src.length()).is_greater(0)
		var line_no := 0
		for line in src.split("\n"):
			line_no += 1
			var idx := line.find("get_node_or_null(")
			if idx < 0:
				continue
			# 接收者形式（item.get_node_or_null / tree.root.get_node_or_null）合法；
			# 裸调（行首到函数名之间只有空白/制表）= RefCounted 编译崩溃地雷。
			var prefix := line.substr(0, idx)
			assert_bool(prefix.strip_edges().is_empty()
				and not prefix.contains(".")
				and not line.strip_edges().begins_with("#")) \
				.override_failure_message(
					"RefCounted 类裸调 get_node_or_null（v6.53 拖拽瘫痪同款地雷）%s:%d" % [path, line_no]) \
				.is_false()


func test_refcounted_autoload_helper_present() -> void:
	var src_drag := FileAccess.get_file_as_string(HELPER_SCRIPTS[0])
	var src_bar := FileAccess.get_file_as_string(HELPER_SCRIPTS[1])
	assert_bool(src_drag.contains("static func _autoload_node")) \
		.override_failure_message("BackpackCardItemDrag 缺 _autoload_node helper").is_true()
	assert_bool(src_bar.contains("func _host_autoload_node")) \
		.override_failure_message("InstrumentBarDrag 缺 _host_autoload_node helper").is_true()
	# 装配成功路径仍需触达教程实操旗标（v6.53 #2 语义保活）
	assert_bool(src_drag.contains("notify_assembly_touched")) \
		.override_failure_message("拖入装配成功路径丢教程旗标置位").is_true()
	assert_bool(src_bar.contains("notify_assembly_touched")) \
		.override_failure_message("拖出卸下成功路径丢教程旗标置位").is_true()
