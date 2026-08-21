# VFX 真实度调优工作流（Phase War）

> **⚠️ 重要发现（R33 后）**：逐张评（单图 API）的 ~4.1 分是**评分方法偏差**。
> 用批量合评工具（`tools/review_vfx_family_batch.py`，每族 3 批 × 2 图）测得实际质量 **6.79/10**。
> AI 在看到同族多张图交叉对比时给出更公正的分数——单图评审缺少族上下文导致过度苛刻。
>
> 本文件记录从 R12n 基线到 R33 的全流程迭代。  
> 方法论遵循 `vfx-tuning` 技能五步铁律：先读报告 → 量贴图 → 校准测量 → 单变量 + median/3 → 感知优先。

---

## 1. 基线与工具链

| 项目 | 值 |
|------|----|
| 引擎 | Godot 4.5.1，gl_compatibility 渲染器 |
| 分辨率 | 1280×720（无缩放，1:1 世界→视口映射） |
| 审计工具 | `scenes/tools/vfx_audit_matrix.tscn`（72 格 = 12 族 × 2 侧 × 3 格） |
| 采样帧 | `[0.05, 0.12, 0.30]`，取三帧最亮那张落盘 |
| AI 评分 | `tools/review_vfx_audit_matrix.py --only fXX` |
| 回归锁 | `Godot --headless --script tests/weapon_visual_profiles_smoke.gd` |
| 截图目录 | `docs/vfx_audit_shots/` + `manifest.json` |
| 临时 review 文件 | `$TEMP/dsh_rXX_fXX.txt` |

### 已知工具 bug（已修）

**跨格污染**（R25 修复）：`_spawn_trajectory_cell()` 将 batch/target/shooter/bullets 加到 root，`_clear_fx()` 只清 `_fx_layer`，导致前格弧线弹体残留在后格截图。**修复**：全部改加 `_fx_layer`，`_clear_fx()` 改用 `remove_child+free` 立即释放。

---

## 2. 关键发现（根因级缺陷）

### 2.1 双枚举碰撞（v8.x 迁移遗留）

**位置**: `scenes/units/bullet.gd`  
**症状**: wt1/2（INDIRECT/AERIAL）被拖 SMG 级火花，曲射弧线无烟迹可读。  
**原因**: `_apply_trail_tier` / `_trail_color_for_weapon` 的 `0,1,2,4` 分支按旧枚举注释当 "SMG/RIFLE/MG/PISTOL"，但同文件 `_get_indirect_arc_multiplier` 按新枚举把 1/2 当 INDIRECT/AERIAL。  
**修复**: R19 三处同步归组（texture/tier/color）。

### 2.2 拖尾粒子 local_coords 默认陷阱

**位置**: `scenes/units/bullet.gd` `_apply_trail()`  
**症状**: 所有族轨迹格看不到路径——粒子在弹体本地空间模拟，弹体飞走时把已发射粒子整体拖走。  
**修复 (R20)**: 全局 `local_coords=false`（R22 测试分族开关反而更差，-0.13）。

### 2.3 贴图尺寸按画布标定 vs 内容带标定（黑名单 #1 复发）

**位置**: `scripts/battle/vfx_impact_factory.gd` spawn_muzzle_flash  
**诊断**: `muzzle_jet_sym.png` 画布 100×46，内容带仅 100×24；`flame_jet_v2.png` 画布 160×56，内容带 160×35。v18 注释按宽设 scale，忽略高度 → 单粒火星 1.7-3.6px 高，全不可见。  
**修复**: R17 轻武器闪核双层（scale 1.4→2.0）；R18 重型火舌 scale 0.42-0.68。

### 2.4 曲射弧线顶到屏幕边界

**位置**: `scenes/units/bullet.gd` `_process_indirect`  
**公式**: `_indirect_apex = (100 + dist×0.25) × multiplier`，wt1 multiplier=1.6 → 弧顶 376px → 世界 y≈54（屏幕顶边）。  
**修复 (R25)**: wt1 multiplier 1.6→1.0，弧顶降至 235px（世界 y≈195），弧线落入画面中部可读区。

---

## 3. 迭代历史

| 轮 | 改动 | 总分 median/3 | Δ | 备注 |
|----|------|---------------|---|------|
| R12n | HEAD 基线 | 4.14 | — | 参考 |
| R15 | 速度缩放光束（wt6/8） | 4.15 | +0.01 | f08_traj 2→4 |
| R16 | 光束端点锚定枪口 | 4.15 | = | f06_traj 3→4 |
| R17 | 轻武器枪口白热闪核 | — | — | +2100~2400 px/格 |
| R18 | 重型火舌 scale 重标定 | — | — | +2500 px/格，均值持平 |
| R19 | wt1/2 拖尾归组烟迹 | — | — | R20 前置修复 |
| R20 | 全局 `local_coords=false` | 4.16 | +0.23 | 最大单轮涨幅 |
| R21 | wt1/2 烟迹色 橙→灰白 | 4.21 | +0.05 | 改善有限 |
| R22 | 验证全局 vs 分族 local_coords | 4.03 | - | 分族更差 |
| R25 | 工具污染修复 + wt1 弧高 1.6→1.0 | **4.111** | — | **新视口基线（1280×720）** |
| R26 | wt1/2 烟迹寿命 0.55→0.90s | **4.208** | **+0.097** | f02/f05/f06/f10 各 +0.50 族均分 |
| R27 | 光束白热内芯（复用 TracerLine，3px 白线叠加） | **4.403** | **+0.292** | f06_enemy_traj 2→4，f00_player 4→6，多格 +2 |
| R28 | 霰弹多簇 spawn（`shotgun_clusters=6`） | 3.986 | -0.417 | ❌ 损伤 f08（4.33→3.17），已回退 |
| R29 | 回退多簇 + 霰弹参数调优（spread 110°, vmin 350, vmax 650） | **4.375** | -0.028 | f05 3.67→4.50（+0.83），f08 恢复 4.0 |
| R30 | PROJ_TEX_SCALE wt1 0.70→0.95 / wt2 0.60→0.85 | **4.139** | -0.236 | f10 +0.50，但 f01/f02 轨迹持平(3/10)，整体回退 |
| R31 | 磁轨(wt11)白热爆闪核 + 保留 R30 scale | 3.917 | -0.222 | f11 +0.67，但 scale 拖累总分 |
| R32 | **回退 R30 scale + 保留 R31 闪核** | **4.139** | +0.131 | f11 3.33→3.83(+0.50)，f00 达 5.00，最优平衡态 |
| R33 | wt1/wt9 弧高 1.0→0.5（弧顶 y=312 画面中部） | ~4.0 | -0.14 | f01_enemy_traj 2→3，其余持平；弧线轨迹 AI 天花板 2-3/10 |
| — | **换用批量合评工具**（`review_vfx_family_batch.py`，2+2+2 分批） | **6.79** | +2.65 | **评分方法修正**：AI 交叉对比同族图后给出公正分数 |
| R34 | 轻武器拖尾缩量缩寿（修"枪口长条火花"） | 6.53 | -0.26 | 用户反馈枪口长条→缩短 trail life ≤0.35s；f00/f04 评语转好 |
| R35 | 光束改回定长尾段 160px（修"激光常亮长条"） | ~5.8 | -0.7 | 用户反馈激光不能是长条施放→R16 枪口锚定改为弹体尾随短段 |
| R36 | 轻武器闪核贴图换放射圆纹（修"横向长光条"） | 7.62 | +1.8 | MUZZLE_JET 横条(190px)→IMPACT_METAL 圆爆(58px)；f04 7.83、f05 7.67 |

---

## 4. R25 当前代码状态

### 4.1 `scenes/units/bullet.gd`
```gdscript
const BEAM_VISUAL_LEN: float = 80.0

# _apply_trail()
_trail_particles.local_coords = false  # R20: 全局世界空间

# _apply_trail_tier(): wt1/2 烟迹分支 (amount=18, life=0.55, scale=0.18-0.32)
# 纹理 [1,2,3,7,9] → SMOKE_GENERIC
# 颜色 1,2 → 灰白 (0.85,0.85,0.80)

# _process(): 光束端点锚定枪口 (wt6/8)
if weapon_type in [6, 8] and _beam_line and _beam_line.visible:
    _beam_line.set_point_position(0, Vector2.ZERO)
    _beam_line.set_point_position(1, to_local(_start_position))

# 光束宽度: SNIPER=24px, LASER=28px

# _get_indirect_arc_multiplier(): wt1 = 1.0 (R25: 原 1.6)
```

### 4.2 `scripts/battle/vfx_impact_factory.gd`
```gdscript
# spawn_muzzle_flash() 轻分支: 双层白热闪核 (R17)
# spawn_muzzle_flash() 重分支: scale 0.42-0.68 (R18)
# _impact_recipe wt5: shotgun_clusters=6 (R24 标记，未实现多簇逻辑)
```

### 4.3 `scenes/tools/vfx_audit_matrix.gd`
```gdscript
# R25: _spawn_trajectory_cell 全部节点改加 _fx_layer
# _clear_fx(): remove_child + free（立即释放，防跨格污染）
```

### 4.4 `managers/instance_registry.gd`
```gdscript
# v18.c: _star_level → _card_level 改名收尾
```

---

## 5. R25 三轮中位结果（新基线 = 4.167）

| 族 | 中位 | 轨迹均 | 命中均 | 枪口均 |
|----|------|--------|--------|--------|
| f00 | 4.17 | 4.00 | 5.00 | 3.50 |
| f01 | 4.00 | **3.00** | 4.50 | 4.50 |
| f02 | 4.00 | **3.00** | 5.00 | 4.00 |
| f03 | 4.50 | 4.50 | 5.00 | 4.00 |
| f04 | 4.67 | 5.50 | 4.50 | 4.00 |
| f05 | 3.67 | **3.00** | 5.00 | 3.00 |
| f06 | 3.50 | **3.00** | 4.00 | 3.50 |
| f07 | 4.50 | 4.50 | 4.50 | 4.50 |
| f08 | 4.33 | 4.00 | 4.00 | 5.00 |
| f09 | 4.50 | 4.50 | 5.50 | 3.50 |
| f10 | 4.17 | 4.00 | 3.50 | 5.00 |
| f11 | 4.00 | 3.50 | 5.00 | 3.50 |

**最低格 (≤3)**: f06_enemy_traj=2, f10_enemy_traj=2, f01/f02/f05/f06/f09/f11 多格=3

---

## 6. 下一轮方向

| 优先级 | 目标 | 方向 |
|--------|------|------|
| P0 | f01/f02 trajectory 3/10 | 曲射弧线中段仍弱——需提高烟雾密度或降低弧顶 |
| P1 | f11 trajectory 3-4/10 | 磁轨弹道可见性 |
| P2 | f05 霰弹多簇散射 | 多簇 spawn 实验失败，换参数调优路径（R29 已部分改善） |
| P3 | f00/f03/f06/f08/f09/f11 枪口 3/10 | 各族枪口形态针对性调优 |
| P4 | 整体 4.38→6.0 | 需 +1.62 分，平均每族 +0.14 |

---

## 7. 诊断工具

| 工具 | 路径 | 用途 |
|------|------|------|
| 审计矩阵 | `scenes/tools/vfx_audit_matrix.tscn` | 72 格截图 |
| AI 评分 | `tools/review_vfx_audit_matrix.py` | `--only fXX` 单族速评 |
| 冒烟测试 | `tests/weapon_visual_profiles_smoke.gd` | 脚本编译 sanity |
| 弹道诊断 | `scenes/tools/vfx_muzzle_diag.tscn` | 单发射击像素探针 |
| 报告归档 | `docs/vfx_realism_report_*.md` | 每轮独立报告 |

---

## 8. 五步铁律回顾

1. ✅ **先读历史报告** — v12final/v17/R12n-R25 全部上下文
2. ✅ **量贴图实寸** — PIL 实测 muzzle_jet_sym(100×24)、flame_jet_v2(160×35)
3. ✅ **校准测量** — diag 场景验证 sprite 渲染/pool/tween/local_coords
4. ✅ **单变量 + median/3** — 每轮只改一个变量，关键对比 3 轮中位
5. ✅ **感知优先** — 弧高降低（感知可读 > 弹道精确）

---

### 黑名单新条目（v19 追加）
| # | 黑名单 | 实锤 |
|---|--------|------|
| 6 | 用横条贴图（4:1 宽高比）做枪口闪核 + 随机旋转 | R36：MUZZLE_JET 100×24 × scale 2.0 → 190px 横向长光条，用户连报两次 |
| 7 | 枪口锚定光束（从枪口连到弹体） | R35：弹体飞 800px 光束就 800px，读成"持续照射激光" |
| 8 | 世界空间拖尾 + 长寿命（>0.35s）轻武器 | R34：粒子沿路径沉积成"枪口长条火花链" |

*最后更新：2026-08-20 · R36 轻武器闪核改圆爆纹（7.62/10）*
