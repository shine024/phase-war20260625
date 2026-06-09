---
name: godot-validate
description: 使用 Godot headless 模式验证项目语法和配置
disable-model-invocation: true
---

# Godot 语法验证技能

## 功能

在编辑 GDScript 文件后，自动运行 Godot headless 模式验证，捕获语法错误和配置问题。

## 验证命令

```powershell
& "E:\下载\Godot_4.41\Godot_v4.5-stable_win64.exe" --headless --rendering-driver opengl3 --path "." --check-only
```

## 使用场景

- 编辑任何 `.gd` 文件后
- 修改 `project.godot` 配置后
- 更新 autoload 单例后
- 添加/删除资源文件后

## 输出示例

### 成功输出
```
GDScript validation completed successfully.
All scripts are syntactically valid.
```

### 错误输出
```
ERROR: Syntax error in scripts/battle_manager.gd:42
Expected '}' after function body
```

## 注意事项

- 此技能不会运行游戏，仅验证语法
- 使用 OpenGL3 渲染驱动以确保兼容性
- 无需启动编辑器

## 相关技能

- `/gdunit-run` - 运行完整的测试套件
