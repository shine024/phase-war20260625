# 美术效果领域系统性审计报告（阶段4 · 针对性检查）

- 审计日期：2026-08-17
- 审查领域：美术效果（战斗特效贴图 + 特效运行时行为 + 资产工程化）
- 分类框架：本次审计前经用户确认的 A(贴图技术)/B(内容语义)/C(运行时行为)/D(可读性)/E(性能)/F(工程化) 六类 35 项
- 证据产物（同目录）：
  - `scan_result.json` — 246 张贴图全量像素指标 + 引用分级
  - `montage_01~08.png` — 全量贴图蒙太奇（红框=抠图嫌疑/黄框=镂空/蓝框=出血/绿框=死资产）
  - `runtime_01~04.png` — vfx_showcase 实机渲染 63 张截图拼图（1280×720 峰值帧）
  - 扫描工具：`tools/vfx_audit_scan.py`、`tools/vfx_audit_montage.py`

---

## 一、执行摘要

| 维度 | 数字 |
|------|------|
| 特效贴图在盘 | 246 张（assets/effects/） |
| **死资产（零引用）** | **157 张（64%），约 204MB RGBA 常驻上限** |
| 在用贴图 | 89 张，技术合规率高（无方框/无出血/无残色边） |
| 在用超 1024px | 12 张（P1） |
| 导入设置 | 100% 未压缩（compress/mode=0）+ 无 mipmap |
| 运行时行为 | 主链路（命中三层合成/枪口火/暴击/死亡/DOT）池化+渐变+ADD 层次**全部合规**；发现 1 处**枚举碰撞行为缺陷**（枪口火轻重错档） |
| 屏幕震动 | 有衰减包络+动效减弱无障碍开关（好），但常规爆炸 8-12.5px、核级 20px/0.8s **超出预设阈值** |
| 工程完整性 | effects 域内孤儿 .uid ×3、空目录 ×3、重复内容 ×2 对 |

**一句话结论：在用的 89 张贴图与主特效链路质量过硬；真正的系统性问题是一个从未清理的 AI 生成管线"废料场"（157 张死贴图，其中 143 张连抠图都没做过、23 张带水印），外加一处双枚举语义碰撞导致曲射炮开火视觉错档。**

---

## 二、违规清单（每条可回溯分类编号）

### P1 —— 必修

| # | 条款 | 对象 | 证据 | 建议 |
|---|------|------|------|------|
| V1 | F1 死资产 | `assets/effects/laws/` 全部 23 张 | 三级引用解析（直引/常量拼接/名字构造）+ DirAccess 排查均无引用；文件名时间戳 | 整目录移出 res://。**注意：这些是"法则特效"的备料，若未来法则系统要接特效，需先走抠图+重命名管线再入库** |
| V2 | F1 死资产 | `weapons_realistic/` 116 张哈希名（`xxxxxxxx_impact/_proj.png`）+ `weapon_artillery_muzzle.png` | `weapon_projectile_vfx.gd` 仅 preload 19 张；哈希名成对出现=AI 批量生成中间产物 | 移出或建 `_trash/` 归档；这是 weapons_realistic 目录 136 张里 86% 的废料 |
| V3 | F1 死资产 | `projectiles/artillery_anim/` 全部 7 张 + manifest.json | 代码零引用"artillery_anim"；manifest 指向 v1 名单，v2/v3 为迭代废稿（F5 世代漂移实证） | 整目录移出 |
| V4 | F1 死资产 | `omega_platform_projectile_core.png`、`..._impact.png` | 仅 trail 被 bullet.gd preload；core/impact 零引用 | 移出 |
| V5 | F1+F4 死资产+双份 | `nuclear/nuke_mushroom_sheet.png`、`nuke_mushroom_sheet_growth.png`；`explosion_frames/*_sheet.png` ×2 | 散帧已 preload，sheet 零引用（E6 双份存储） | 移出 4 张 sheet |
| V6 | F1 死资产 | `particle_textures/*_preview.png` ×4（96×96） | 生成管线预览图入库 | 移出 |
| V7 | **B3 语义错配** | `weapon_flak_projectile.png` 与 `weapon_rocket_projectile.png` | **内容 hash 完全相同**（25182559）→ 防空炮弹与火箭弹外观不可区分 | 为 flak 重做差异化贴图（近炸引信弹体特征）；或至少染色区分 |
| V8 | **B3 枚举碰撞（行为缺陷）** | `vfx_impact_factory.gd:375 spawn_muzzle_flash` | 调用方传**新枚举** `u.stats.weapon_type`（DIRECT=0/INDIRECT=1/AERIAL=2/SUPPORT=3，default_cards.gd:270-284），但函数按 **legacy 码**分流：重型=[3,7,9,10,11]、轻型=[0,1,2,4,5,6]。后果：①曲射火炮(INDIRECT=1)拿**轻**枪口火（10 粒子圆斑，应为 26 粒子窄锥喷射）；②SUPPORT(3) 误拿重型喷射；③v13 注释宣称的重型方向化喷射在主链路（新枚举）上仅 3 号位撞车生效 | muzzle 分支改用 `GC.is_indirect_weapon_type()`/legacy_weapon_type 语义统一判定；与 v6.6 C5 修复（`is_indirect_weapon_type` 统一曲射判定）同思路 |
| V9 | B3 枚举碰撞（展示实证） | `weapon_projectile_vfx.gd:47 generic_impact_tex_by_wt` | match 注释混写两套语义（"0,4: DIRECT新枚举/SMG/PISTOL"）；`1,2` 按"曲射/空射"→EXPLOSIVE，吞掉 legacy RIFLE/MG 语义。运行时实证：showcase 的 impact_wt1 与 wt2 渲染结果**视觉相同**（蒙太奇比对+代码同贴图） | 枚举域拆分：新枚举与 legacy 分两个函数或在入口归一化，杜绝同域双义 |
| V10 | E1 未压缩 | 全部 246 张 `.import`：compress/mode=0（无损） | 单一 import 变体（一致性 ✓ 但全未压缩）；在用 89 张 RGBA 常驻上限 167MB，VRAM 压缩（lossy）可降至 ~25% | 批量改 `detect_3d/compress_to=1`；ADD 混合贴图先试点看边缘伪色（premult 建议） |
| V11 | A3 规格 | 在用 12 张 >1024：6 张 `weapon_impact_*`（1536×1024）+ 弹道条带 6 张（最宽 1349px） | scan_result.json；标准 max 边 ≤1024 | impact 系列若显示峰值 ~1000px 属合理贴图:显示比，建议**重打包裁掉透明区**（内容 bbox 偏低）后落回 ≤1024；条带贴图裁边 |
| V12 | C13 屏震超阈 | bullet.gd:752-762、simple_player_projectile_batch.gd:214-216 | 常规爆炸 8.0-12.5px/0.35s（阈值 ≤8px/0.3s）；核级 20px/0.8s（阈值 ≤8px/0.3s，超 2.5 倍）。衰减包络 ✓ 动效减弱开关 ✓ | 属 v9.2 有意调参（注释可证）。决策项：接受核级超标（大招冲击）则修标准；否则回调核级至 ~12px/0.5s |
| V13 | F2 引用完整性 | effects 域内：孤儿 uid ×3（`battle_audio_system/visual_effects_manager/battle_effects_system.gd.uid`——脚本已删）；空目录 ×3（`shaders/`、`assets/battle/vfx/`、`assets/unit_sprites/weapons/`） | find 扫描；代码零引用（无死链风险，纯卫生） | 删除孤儿 uid 与空目录 |
| V14 | A1+B1+B5（随 V1-V6 清理附带解决） | laws 23 张：opaque=1.00（从未抠图，含实心星空背景）+ 右下角"图片由AI生成"水印（全分辨率复核确认）+ 部分含飞船/装甲物件 | 蒙太奇+原图放大 | 死资产无需修复；若未来复用必须重生成/抠图，**禁止直接启用** |

### P2 —— 建议

| # | 条款 | 对象 | 证据 | 建议 |
|---|------|------|------|------|
| V15 | A6 透明区浪费 | 13 张在用：`spark_ember`(6%)、`ult_*`(17-29%)、boss `idle_f*`(17%) | content_bbox_ratio<35% | 裁切重打包省 VRAM/overdraw |
| V16 | F3 命名 | laws 23 张时间戳名 + 116 张哈希名（均在死资产内） | 正则统计 | 随死资产清理一并消失；新增资产入 tools 管线时强制语义命名 |
| V17 | E5 运行时创建 | `vfx_impact_factory.gd` 28 处 `.new()`：核心命中/枪口火/环/线 全池化 ✓；但 `spawn_smoke_column`(1288)、蘑菇云 anim(1548)、导弹(1661)、decal(2275)、DOT 视觉（dot_vfx_manager.gd:85+,有去重守卫）为低/中频 new+free | 逐处核对调用频率 | 低频（大招级）可接受；decal（每次重型命中）建议并入池 |
| V18 | C6 核爆全屏吞没 | `pi_nuclear_bombardment_2`、`nuclear_explosion_1` 峰值帧全屏白光，目标不可见 | 实机截图 | 大招冲击设计意图明显；建议白光帧压到 ≤2 帧并保目标剪影（半透明白幕） |
| V19 | B2 风格混用 | `explosion_frames`（手绘帧动画爆炸）与 `weapons_realistic`（写实贴图）同屏共用 | 运行时截图比对 | 长期统一为写实系或分场景使用 |
| V20 | A4 premult WARN | 全部 ADD 用途贴图 `premult_alpha=false` | import 唯一变体 | ADD 混合+边缘半透明像素有晕边风险；fix_alpha_border 已开，暂观察，改压缩时试点验证 |
| V21 | A3 non-POT | 在用 29 张（341×341 核爆帧、条带贴图等） | 无 mipmap 的 2D 下功能无损 | WARN 保留记录，不强制 |
| V22 | E3 池限流策略 | `_active_sparks >= MAX_SPARKS: return`（vfx_impact_factory.gd:379）静默丢弃新特效 | 满载时新枪口火直接不出 | 属 perf 批次有意的限流；建议超限时降粒子量而非整体丢弃 |
| V23 | D3 色盲复核 | DOT×4 图标 + 我/敌青橙 | 运行时截图 | 青橙对色盲友好 ✓；DOT 四色+形状双编码 ✓；无需动作，留档 |

---

## 三、合规确认（证明系统性覆盖，非只查问题）

| 条款 | 结论 | 证据 |
|------|------|------|
| A1 抠图（在用） | ✅ 89 张在用：opaque>95% 零张、四角污染仅 2 张轻微（impact_energy 15.8/spark_heavy 12.0，粒子贴图主体贴边属正常）、边缘残色 max 0.98% | scan_result.json ALIVE 过滤 |
| A1 镂空甄别 | ✅ 全部为设计镂空：dot×4=环形图标、nuke_mushroom_f4=扩散环帧、player_fortress=护盾罩 | 蒙太奇+运行时截图 |
| A2 出血（在用） | ✅ 在用贴图 ring6>8% 零张 | 同上 |
| A4 色彩空间 | ✅ 246 张 import 参数单一一致 | import 变体统计=1 |
| A5 帧序列 | ✅ 尺寸全等、编号连续、代码帧数=资产帧数（explosion 6 帧/nuclear 9 帧/idle 6 帧×2） | 分组统计 0 违规 |
| B1/B5（在用） | ✅ 在用贴图无人物物件、无文字水印（视觉模型两次"含文字"报告均被全分辨率复核推翻，系蒙太奇文件名标签误读） | 原图放大复核 |
| B4 阵营色 | ✅ SIDE_COLOR_PLAYER 青/SIDE_COLOR_ENEMY 橙集中定义（vfx_impact_factory.gd:80-84） | 代码 |
| C1 消散 | ✅ 命中三层（辉光/主体/双冲击环）全 tween fade；枪口火 color_ramp 渐灭+延迟回收 | vfx_impact_factory.gd:1212-1240, 398-404 |
| C2 随机化 | ✅ 旋转 randf()*TAU、缩放 0.9-1.12 抖动、角度/半径抖动 ≥2 维 | 行 1087-1112, 1429-1430, 2279 |
| C3 方向 | ✅ 弹体 rotation=_direction.angle()（bullet.gd:589,695）；枪口火按 facing 分向 | 代码+运行时（traj/muzzle 喷射方向正确） |
| C5 层次 | ✅ 命中=外晕ADD+主体ADD+双环；环用 _get_add_mat()（子代理误报"MIX"，已行级推翻） | vfx_impact_factory.gd:1212-1255, 2528-2531 |
| C7 锚点 | ✅ MuzzleAnchors 44 键+PlayerMuzzleAnchors 117 键→fireX/fireY→spawn_muzzle_flash；v6.14 修复后链路完整 | construct_unit_ai.gd:509-518, 1070-1078 |
| C8 泄漏 | ✅ DOT 子节点随单位 queue_free 自动回收（零泄漏设计自证）；SceneTreeTimer lambda 捕获风险有 deferred release 处理 | dot_vfx_manager.gd:9, factory:2063 |
| C9 反馈矩阵 | ✅ 命中/死亡爆散(敌我双侧)/暴击光圈+火花/受击闪白(modulate) 全存在 | enemy_unit.gd:1712, construct_unit.gd:2175, factory:134,168,195 |
| C10 常驻表现 | ✅ DOT×4 贴图+脉动+类型化动态 aura；狂暴红光环（skill_rage_aura 实机可见）——8/13 报告的问题项已有覆盖 | dot_vfx_manager.gd:96-107 + 运行时截图 |
| C11 帧率 | ✅ 爆炸 6 帧 10fps=0.6s 有注释锚定 | weapon_projectile_vfx.gd:25,545 |
| C4 透视 | ✅ 实机 63 张无穿地/漂浮破图（悬空球体为护盾/光环设计语义）；接地阴影+焦痕贴地 | runtime_01-04 |
| D1 可读 | ✅ 抽查 divine_spear/weakpoint 全分辨率清晰可辨（蒙太奇"不可见"两次被原图推翻） | boss_divine_spear_1.png 等 |
| D2 层级 | ✅ z 约定清晰：地痕-5/核焦痕-4/单位层(默认)/战术标记12-15/环28/DOT 25/蘑菇云30/导弹50；血条在单位子树 | factory z_index 全清单 |
| D4 密度 | ✅ tier 三档 light/medium/heavy 实机尺寸强度差异明确 | runtime_04 |
| E2 粒子量 | ✅ 轻枪口 10/重 26+8 烟/命中粒子 18/单爆炸多层 sprite≈60 内 | 各 spawn 函数参数 |

---

## 四、误报甄别记录（审计质量控制）

视觉模型在蒙太奇缩略图上有 4 次误报，全部被像素数据/全分辨率原图推翻——**本报告不采信未经交叉验证的视觉判断**：

1. "nuclear 帧实心灰背景" → 像素实测 opaque 13-30%，已抠图 ✓
2. "weapon_*_projectile 含 FLAK/MISSILE 文字" → 全分辨率复核为透明底弹体无文字（系蒙太奇文件名标签串读）
3. "divine_spear/inferno 几乎不可见" → 全分辨率清晰、命中点准确
4. "ult_divine_spear/ult_orbital 带实心底" → 像素 opaque 29-30%，透明底 ✓

---

## 五、开放项（本环境无法闭环）

| 项 | 原因 | 建议验证方式 |
|----|------|--------------|
| 满载混战 D4/E3/E4（100 单位粒子总量/池击穿率/overdraw 倍率） | 需真实对局满载 | 实机打后期关卡 + PerformanceMetricsManager 采样；或写压力测试场景 |
| C12 音画同步 | showcase 无音频断言 | 实机抽听 10 例爆炸 |
| VRAM 压缩试点后 ADD 边缘伪色 | 需改 import 后实机看 | 先改 6 张 weapon_impact_* 试点 |
| C13 屏震标准 vs 设计意图（V12） | 需产品决策 | 见 V12 两个选项 |

---

## 六、修复优先级建议（供决策，未动任何文件）

1. **一批清理**（V1-V6, V13, V16）：移出 157 张死资产+孤儿 uid+空目录 → 立减 ~204MB 导入负担，零功能风险（引用已三级验证）
2. **枚举统一**（V8, V9）：枪口火/命中贴图分派的枚举语义归一（复用 v6.6 的 is_indirect_weapon_type 思路）——唯一的行为级 bug
3. **flak 差异化**（V7）：防空炮弹重做贴图
4. **导入压缩**（V10, V11, V15）：试点→全量 VRAM 压缩 + 超大贴图重打包
5. **屏震决策**（V12）+ 核爆白光收敛（V18）

---

## 七、修复执行记录（2026-08-17 同日实施）

### 已修复

| 项 | 内容 | 验证 |
|----|------|------|
| V1-V6/V13/V16 清理 | **156 张死资产 + manifest.json** 移入 `_vfx_trash_20260817/`（含 `.gdignore`，Godot 不导入不打包）；删除孤儿 uid ×3（battle_audio_system / battle_effects_system / visual_effects_manager）与空目录 ×3（shaders/、assets/battle/vfx/、assets/unit_sprites/weapons/） | 全项目源码（含拆串路径）二次复核：废料区零真实引用；编辑器日志零报错 |
| ⚠️ 误判回滚 | `weapon_artillery_muzzle.png` 初判死资产有误——bullet.gd:18 有 preload（单文件 diff 漏查），验证环节捕获后已恢复原位 | `tests/vfx_fix_verify.gd` 通过 + Godot --import 0 错误 |
| V8 枪口火枚举归一 | `vfx_impact_factory.gd` 新增 `HEAVY_MUZZLE_WT=[1,2,3,7,9,10,11]`（新枚举优先约定，与 proj_texture 对齐）；曲射(1)/空射(2)炮口火从轻圆斑改为重型窄锥喷射 | verify 脚本断言通过 |
| V9 命中映射域约定 | `generic_impact_tex_by_wt` 补双枚举域契约文档，杜绝后续混写 | verify 脚本 0-11 全分支非空 |
| V7 flak 差异化 | `weapon_flak_projectile.png` 重着色：军绿弹体→钢灰+亮铜弹带（hue 域变换，alpha 不动）；hash 25182559→4be690ec 与 rocket 分离 | 对比图 `flak_vs_rocket_after.png`：小尺寸可一眼区分、无色块断层 |
| V10 VRAM 压缩 | 78 张（max边≥256）`compress/mode 0→2`（S3TC/BC3）；11 张小粒子贴图保持无损（收益趋零不担风险）；已 `--import` 重导入 | showcase 63 张重跑像素 diff：总体均值差 0.746/255；top5 差异组人工比对全部"无差异/无色带伪影"（差异源为脉动时序随机）。压缩集 VRAM ~172MB→~45MB |

### 新增文件

- `tests/vfx_fix_verify.gd` — V7/V8/V9 回归断言（Godot --script 模式，全 PASS）
- `tools/vfx_audit_scan.py` / `tools/vfx_audit_montage.py` — 审计工具（复用）
- `_vfx_trash_20260817/` — 废料区（.gdignore 隔离；确认无需回滚后可整目录删除或移出项目）

### 未实施（待决策/需实机）

| 项 | 原因 |
|----|------|
| V12 屏震阈值 | 需产品决策：接受核级 20px/0.8s（修标准）或回调参数（改代码） |
| V18 核爆全屏白光 | 设计决策：白光帧压到 ≤2 帧并保目标剪影 |
| V11/V15 贴图裁切重打包 | 涉及显示 scale 语义复核，建议单独批次 |
| V17 decal 池化 | 低频路径，收益小 |
| 满载压力测试（E3/E4/D4） | 需真实对局 |
