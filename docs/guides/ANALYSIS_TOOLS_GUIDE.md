# Phase War 数据分析和平衡系统 - 使用指南

## 概述

本系统为Phase War游戏项目提供了全面的数据分析、平衡性评估和系统优化工具。所有工具位于`tools/`目录下。

## 工具列表

### 1. 游戏数据分析器 (GameDataAnalyzer)

**文件**: `tools/game_data_analyzer.gd`

**功能**:
- 统计敌人属性分布（HP、伤害、速度、射程等）
- 分析关卡难度曲线
- 评估卡牌平衡性
- 分析掉落率
- 生成平衡建议

**使用方法**:
```bash
godot --script tools/run_data_analysis.gd
```

**输出**: `user://game_analysis_report.txt`

### 2. 游戏平衡管理器 (GameBalanceManager)

**文件**: `tools/game_balance_manager.gd`

**功能**:
- 配置平衡参数（敌人属性、关卡难度、掉落率）
- 计算推荐的属性值
- 生成平衡调整建议
- 应用平衡调整

**主要配置参数**:
```gdscript
balance_config = {
    "enemy": {
        "hp_scale_per_era": 1.35,      # 每时代HP增长倍数
        "damage_scale_per_era": 1.3,   # 每时代伤害增长倍数
        "speed_scale_per_era": 1.05,   # 每时代速度增长倍数
    },
    "level": {
        "base_difficulty": 0.8,        # 基础难度
        "difficulty_growth_per_level": 0.025,  # 每关难度增长
    },
    "drop": {
        "common_drop_chance": 0.10,    # 普通敌人掉率
        "elite_drop_chance": 0.22,     # 精英掉率
        "boss_drop_chance": 0.50,      # 头目掉率
    }
}
```

### 3. 性能分析器 (PerformanceAnalyzer)

**文件**: `tools/performance_analyzer.gd`

**功能**:
- 检测性能瓶颈
- 分析内存使用
- 识别低效代码模式
- 生成优化建议

**检测的问题类型**:
- 帧率下降
- 内存泄漏
- 脚本执行慢
- 低效循环
- 对象过多
- 纹理内存问题
- 音频重叠

### 4. Bug追踪器 (BugTracker)

**文件**: `tools/bug_tracker.gd`

**功能**:
- 扫描代码中的潜在Bug
- 按严重程度分类
- 提供修复建议
- 生成Bug报告

**检测的Bug类型**:
- 空引用风险
- 数组越界
- 类型转换错误
- 资源泄漏
- 无限循环
- 除零错误
- 废弃API使用

### 5. 系统优化器 (SystemOptimizer)

**文件**: `tools/system_optimizer.gd`

**功能**:
- 代码质量分析
- 性能优化建议
- 架构改进建议
- 安全检查
- 可维护性评估

**优化类别**:
- 代码质量
- 性能优化
- 内存优化
- 架构设计
- 安全性
- 可维护性

### 6. 综合系统分析工具

**文件**: `tools/run_system_analysis.gd`

**功能**:
- 运行所有分析工具
- 生成完整报告包
- 创建综合摘要

**使用方法**:
```bash
godot --script tools/run_system_analysis.gd
```

**输出目录**: `user://analysis_reports_<timestamp>/`

包含文件:
- `data_analysis.txt` - 游戏数据分析
- `balance_analysis.txt` - 平衡性分析
- `bug_detection.txt` - Bug检测结果
- `optimization_suggestions.txt` - 优化建议
- `performance_analysis.txt` - 性能分析
- `summary.txt` - 综合摘要

## 快速开始

### 1. 运行完整分析

```bash
godot --script tools/run_system_analysis.gd
```

### 2. 查看报告

分析完成后，会在输出目录中生成所有报告文件。建议按以下顺序查看：

1. `summary.txt` - 查看综合摘要
2. `data_analysis.txt` - 了解当前数据状态
3. `balance_analysis.txt` - 查看平衡性问题
4. `bug_detection.txt` - 检查需要修复的Bug
5. `optimization_suggestions.txt` - 查看优化建议

### 3. 应用平衡调整

如果需要调整游戏平衡，可以修改`GameBalanceManager`中的配置参数：

```gdscript
# 示例：调整每时代HP增长
var manager = GameBalanceManager.new()
manager.balance_config.enemy.hp_scale_per_era = 1.4  # 从1.35提升到1.4
```

## 工作流程建议

### 日常开发

1. **代码变更后**: 运行Bug检测
   ```bash
   godot --script tools/run_bug_detection.gd
   ```

2. **添加新内容后**: 运行数据分析
   ```bash
   godot --script tools/run_data_analysis.gd
   ```

### 版本发布前

1. 运行完整的系统分析
2. 修复所有严重和高优先级问题
3. 根据平衡分析调整游戏参数
4. 重新运行分析验证改进效果

### 定期维护

建议每周或每个里程碑运行一次完整分析，持续监控代码质量和性能状况。

## 报告解读

### 数据分析报告

关注以下指标：
- **敌人属性增长曲线**: 每时代HP、伤害增长是否合理（建议30-50%）
- **关卡难度曲线**: 难度增长是否平滑
- **卡牌费用**: 是否与属性匹配
- **掉落率**: 是否平衡，蓝图覆盖率是否足够

### 平衡分析报告

如果报告显示"当前游戏数据平衡良好"，说明各项指标在合理范围内。
如果有调整建议，按优先级处理：
- **高优先级**: 可能严重影响游戏体验
- **中等优先级**: 有改进空间
- **低优先级**: 微调建议

### Bug检测报告

按严重程度处理：
- **严重**: 必须立即修复
- **高**: 尽快修复
- **中等**: 计划修复
- **低**: 可以延后处理

### 性能分析报告

关注：
- **严重性能问题**: 可能导致帧率显著下降
- **内存泄漏**: 长时间运行可能导致崩溃
- **优化建议**: 实施成本vs收益分析

## 扩展和定制

### 添加自定义分析

所有工具都是基于`RefCounted`的类，可以轻松扩展：

```gdscript
extends RefCounted
class_name MyCustomAnalyzer

static func analyze_my_data() -> Dictionary:
    # 你的分析逻辑
    return result
```

### 修改平衡参数

根据游戏设计需求，调整`GameBalanceManager`中的参数。

### 集成到CI/CD

可以将这些工具集成到持续集成流程中：

```yaml
# 示例GitHub Actions
- name: Run Game Analysis
  run: godot --script tools/run_system_analysis.gd

- name: Upload Reports
  uses: actions/upload-artifact@v2
  with:
    name: analysis-reports
    path: user://analysis_reports_*/
```

## 常见问题

**Q: 分析工具会影响游戏性能吗？**
A: 不会，所有工具都是离线运行的，不会影响运行时性能。

**Q: 可以在编辑器中运行吗？**
A: 可以，创建一个测试场景调用相应的分析函数。

**Q: 如何只运行特定的分析？**
A: 使用对应的独立脚本，如`run_data_analysis.gd`。

**Q: 报告可以自定义格式吗？**
A: 可以，修改相应的生成函数，支持输出JSON、CSV等格式。

## 技术支持

如有问题或建议，请在项目仓库提交Issue。

---

**最后更新**: 2026-03-30
**版本**: 1.0
**作者**: Claude Code
