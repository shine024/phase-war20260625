# Phase War（相位战争）

战术卡牌策略游戏——在格子战场上部署从一战到近未来的历史军事单位，
经营卡牌养成（强化/改造/进化/词条/符文）、势力外交、情报驱动的关卡进程，
并迎战各时代的相位师（Boss）。

- **引擎**：Godot 4.5.1（`gl_compatibility` 渲染器，1280×720 / 60fps）
- **语言**：GDScript（数据即代码，无 JSON/CSV 运行时数据）
- **入口场景**：`res://scenes/title_screen.tscn` → 主场景 `res://scenes/main.tscn`
- **平台**：Windows（跨两台机器开发，Godot 路径自动探测见 AGENTS.md）

## 运行

```bash
# 用 Godot 4.5.1 打开项目后 F5，或命令行：
Godot_v4.5.1-stable_win64.exe --path .
```

## 项目结构

| 目录 | 内容 |
|------|------|
| `scenes/` | 场景与 UI 面板（main/battlefield/units/effects/ui） |
| `scripts/` | 战斗逻辑/系统/工具脚本 |
| `managers/` | 32 个 autoload 管理器 + 子系统 |
| `data/` | 全部游戏数据表（卡牌/敌人/法则/进化/改造/情报/势力…） |
| `resources/` | CardResource/UnitStats/GameConstants 等资源类型 |
| `assets/` | 卡图/背景/特效/UI 素材 |
| `tests/` | GdUnit4 套件（tests/unit）+ 冒烟测试 |
| `docs/` | 活文档（美术/VFX 管线、数据总表）+ CHANGELOG |
| `tools/` | 美术/审计/评审 Python 工具链 |

## 开发文档

- **[AGENTS.md](AGENTS.md)** — 架构与工作流真身（改代码前必读）
- **[docs/CHANGELOG.md](docs/CHANGELOG.md)** — 版本变更记录（v6.1→v20，含 2026-08-16~22 补录节）
- `docs/engine-reference/` — Godot 4.5 API 笔记

## 测试

```bash
# GdUnit4 全套件
Godot_v4.5.1-stable_win64.exe --headless --rendering-driver opengl3 --path . --script tests/gdunit4_runner.gd
# 快速冒烟（无 GdUnit 依赖）
Godot_v4.5.1-stable_win64.exe --headless --rendering-driver opengl3 --path . --script tests/master_power_smoke.gd
```
