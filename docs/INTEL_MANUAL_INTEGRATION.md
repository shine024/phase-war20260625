# 情报道具系统集成摘要

## 完成日期
2026年6月2日

## 系统设定（当前版本）
- **强化**：只需纳米材料
- **改造**：纳米材料 + 改造指南（根据稀有度）
- **进化**：纳米材料 + 进化图纸

## 情报道具类型
根据 `IntelManualItems` 定义：
- `TYPE_ENHANCE` - 强化手册（旧设定，现已废弃）
- `TYPE_STAR_UPGRADE` - 升星指南
- `TYPE_MOD_A` - 改装指南·基础（uncommon稀有度）
- `TYPE_MOD_B` - 改装指南·进阶（rare稀有度）
- `TYPE_MOD_C` - 改装指南·高级（epic/legendary稀有度）
- `TYPE_EVOLVE` - 进化图纸

## 修改的文件

### 1. BlueprintManager (managers/blueprint_manager.gd)

#### install_modification() 函数
- 移除研究点消耗系统
- 添加纳米材料消耗（卡牌战力50%）
- 根据改造稀有度检查并消耗相应改造指南：
  - uncommon → TYPE_MOD_A
  - rare → TYPE_MOD_B
  - epic/legendary → TYPE_MOD_C
  - common → 无需指南

#### evolve_card() 函数
- 添加纳米材料消耗（目标卡牌战力2倍）
- 添加进化图纸（TYPE_EVOLVE）检查和消耗
- 在满足条件后再执行进化操作

### 2. ModificationPanel (scenes/ui/modification_panel.gd)

#### 添加 IntelManualItems 预加载
```gdscript
const IntelManualItems = preload("res://data/intel_manual_items.gd")
```

#### 更新资源标签显示
从 "研究点：X" 改为 "纳米：X | 指南 A:X B:X C:X"

#### 更新安装按钮
显示实际消耗：
- 普通改造：`"安装（消耗：X纳米）"`
- 需要指南：`"安装（消耗：X纳米 + 指南·基础/进阶/高级）"`

### 3. EvolutionPanel (scenes/ui/evolution_panel.gd)

#### 添加 IntelManualItems 预加载
```gdscript
const IntelManualItems = preload("res://data/intel_manual_items.gd")
```

#### 添加资源信息显示
新增 ResourceLabel 显示：
- 当前资源：纳米数量 + 图纸数量
- 进化需要：纳米数量 + 图纸1张

#### 更新进化按钮
根据资源情况显示：
- 有图纸且纳米足够：`"进化（消耗：X纳米 + 图纸）"`
- 图纸不足：`"图纸不足"`
- 纳米不足：`"纳米不足（需要 X）"`

## 资源消耗公式

### 改造消耗
```
纳米材料 = 卡牌战力 × 0.5
改造指南 = 根据稀有度：
  - uncommon → TYPE_MOD_A（基础）
  - rare → TYPE_MOD_B（进阶）
  - epic/legendary → TYPE_MOD_C（高级）
  - common → 无需指南
```

### 进化消耗
```
纳米材料 = 目标卡牌战力 × 2.0
进化图纸 = 1张（TYPE_EVOLVE）
```

## 获取方式

### 改造指南
- 战斗掉落（不同敌人类型掉落不同稀有度）
- 商店购买（不同价格）

### 进化图纸
- Boss/精英敌人掉落
- 商店购买

## 后续工作
1. 在游戏内测试改造和进化功能
2. 验证资源消耗正确性
3. 检查UI显示是否清晰
4. 美化面板UI设计
