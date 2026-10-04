extends GdUnitTestSuite
## v6.38.1 回归锁：main 启动链树外守卫（2026-10-02 实机风暴）。
##
## 不变式：`_deferred_non_critical_init` 由 _ready 经 call_deferred 排队，若 flush 时
## main 已被摘树（场景切换竞态），整链必须让位——树外跑启动链只会留下半残实例
## （挂机管理器半初始化、autoload 绝对路径报错串、出击链静默失败）。
##
## 哨兵口径：守卫在位时，树外直调启动链不得设置 `_afk_manager`（守卫缺失时
## `_init_afk_manager` 会在树外照常 new 并赋值，本用例即红）。

const MAIN_SCENE := preload("res://scenes/main.tscn")


func test_deferred_init_out_of_tree_is_noop() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	# 刻意不入树——复刻风暴状态：deferred flush 时 main 已在树外
	main._deferred_non_critical_init()
	assert_that(main.get("_afk_manager")).is_null()
	main.free()


func test_deferred_init_out_of_tree_double_call_stays_noop() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	main._deferred_non_critical_init()
	main._deferred_non_critical_init()
	assert_that(main.get("_afk_manager")).is_null()
	main.free()
