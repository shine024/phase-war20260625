extends Node
## v6.28（记录2#5e）：冻住诊断面包屑日志（autoload TraceLog）。
##
## 背景：三条"画面冻住但进程还在"主诉（胜利后/挂机后台/核子轰炸后）。GDScript
## 循环全部有界（已核），冻住=同帧负载饱和或驱动级挂起——事后无现场可查。
## 本工具提供低频面包屑：每条立即落盘 flush，冻住发生时"最后一条写入的事件"
## 必在盘上，下次复现看 user://trace.log 尾行即可定位区间。
##
## 纪律：
##  - 只埋低频点（进场/出场/大招起止/存档出入口），禁逐帧/逐单位埋点——
##    本工具绝不能反过来成为卡顿源。
##  - 失败静默：诊断工具不许产生报错噪音（无写权限/盘满时 mark 变 no-op）。
##  - 静态实现：--script 模式不注册 autoload（CLI autoload 陷阱），静态调用仍安全。
##
## 消费方式：复现冻住后取 %APPDATA%/Godot/app_userdata/<项目名>/trace.log 尾部。

const TRACE_FILE := "user://trace.log"

static var _file: FileAccess = null
static var _session_marked := false


## 懒开文件：每次会话覆盖写（上会话 trace 已随诊断消费，保留纯净）
static func _ensure_open() -> void:
	if _file != null and _file.is_open():
		return
	_session_marked = false
	_file = FileAccess.open(TRACE_FILE, FileAccess.WRITE)
	if _file != null and not _session_marked:
		_session_marked = true
		_file.store_line("=== trace session %s (pid %d) ===" % [
			Time.get_datetime_string_from_system(), OS.get_process_id()])
		_file.flush()


## 记一条面包屑。event 用短词（afk_enter / nuke_begin / save_begin …），
## detail 调用方自行 % 组装。自动带 ticks 时间戳 + 进程帧号。
static func mark(event: String, detail: String = "") -> void:
	_ensure_open()
	if _file == null:
		return
	var t_ms: int = Time.get_ticks_msec()
	var line := "[%d.%03d f%d] %s %s" % [t_ms / 1000, t_ms % 1000, Engine.get_process_frames(), event, detail]
	_file.store_line(line)
	_file.flush()


func _ready() -> void:
	# 会话启动即建文件：哪怕第一场战斗就冻住，此前面包屑也能落盘
	_ensure_open()
