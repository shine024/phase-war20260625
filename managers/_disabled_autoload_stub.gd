extends Node
## 已停用 autoload 的占位脚本（P0-1 修复用）
##
## project.godot [autoload] 中残留若干以 "#注释#名称" 为键的注册行（历史编码事故产物）。
## 由于无法从外部工具精确改写这些含乱码字节的键名行，此方案将其 value 指向本空壳脚本：
##   - 若 Godot 解析了这些键：只创建一个无逻辑的空 Node（无 _ready 副作用、无信号连接），
##     不再实例化真实 manager，消除"怪名 autoload + 懒加载实例"双实例风险。
##   - 若 Godot 忽略这些键：本脚本从不被加载，零开销。
##
## 正确的最终清理方式：在 Godot 编辑器 Project Settings → Autoload 中删除这些乱码条目
##（编辑器会以干净编码重写 project.godot），然后可删除本文件。
## 相关管理器（IntelDiscovery/Lore/Character/ChallengeMode/CardCollection/Leaderboard/
## StatBoost 等）均已由 ManagerLazyLoader 按需实例化，不受影响。
