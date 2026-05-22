extends Node
## 战斗输入状态管理（从 SignalBus 中剥离）
## 仅存储战斗中待执行的指令状态，SignalBus 只负责 signal。
## 在 project.godot 中注册为 Autoload（名称：BattleInputState）。

# --- 主动法则施放 ---
var pending_cast_law_id: String =