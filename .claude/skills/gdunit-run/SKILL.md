---
name: gdunit-run
description: 运行 GdUnit4 测试套件
disable-model-invocation: true
---

# GdUnit4 测试运行技能

## 功能

运行 Phase War 项目的 GdUnit4 测试套件，确保代码更改不会破坏现有功能。

## 测试命令

### 完整测试套件
```powershell
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/gdunit4_runner.gd"
```

### 快速烟雾测试
```powershell
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --script "tests/star_config_smoke.gd"
```

### 语法检查
```powershell
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --check-only
```

## 使用场景

- 修改核心管理器（BattleManager、BlueprintManager）后
- 更新存档系统或数据结构后
- 添加新的 MOD 或进化路径后
- 更改战斗计算逻辑后

## 测试目录结构

```
tests/
├── unit/
│   ├── blueprint/       # 蓝图星级配置测试
│   ├── combat/          # 战斗计算测试
│   ├── data/            # 数据表验证测试
│   ├── economy/         # 经济系统测试
│   ├── energy/         # 能量系统测试
│   ├── progression/     # 进化系统测试
│   ├── resources/       # 资源管理测试
│   └── save/            # 存档系统测试
├── gdunit4_runner.gd    # CI 测试运行入口
└── star_config_smoke.gd # 快速烟雾测试
```

## 输出示例

### 成功输出
```
GdUnit4 Execution Report
========================
Total Tests: 45
Passed: 43
Failed: 0
Skipped: 2
Duration: 12.5s
```

### 失败输出
```
FAILED: test_energy_pool_capacity
Expected: 100
Actual: 150
at tests/unit/energy/test_energy_manager.gd:23
```

## 相关技能

- `/godot-validate` - 语法验证（不含测试）
- `/godot-smoke` - 仅运行烟雾测试

## 注意事项

- 使用 `--headless` 模式，无需 GUI
- 使用 OpenGL3 渲染驱动以确保兼容性
- 失败的测试会返回非零退出码
