---
name: godot-run
description: 启动 Phase War 游戏进行功能验证
disable-model-invocation: true
---

# Godot 游戏运行技能

## 功能

启动 Phase War 游戏进行实际运行验证。用于 UI 变更后的视觉确认、功能流程测试。

## 运行命令

### 启动游戏（带窗口）
```powershell
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --rendering-driver opengl3 --path "."
```

### 指定场景运行
```powershell
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --rendering-driver opengl3 --path "." scenes/main.tscn
```

## 使用场景

- UI 面板尺寸/布局变更后验证
- 新增 UI 功能的交互测试
- 战斗流程端到端验证
- 资源加载/显示问题排查

## 验证检查点

启动后检查：
1. 控制台无红色错误输出
2. 主界面正常渲染（1280x720）
3. UI 面板可正常打开/关闭
4. 无资源缺失警告

## 相关技能

- `/godot-validate` — 语法验证（不运行游戏）
- `/gdunit-run` — 运行测试套件
