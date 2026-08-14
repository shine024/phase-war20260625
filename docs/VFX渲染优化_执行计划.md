# VFX 渲染优化 + 贴图 + 效果动画(Track 2 执行计划)

> 本文档是**参考计划**,非已执行。审完再决定做不做、做哪些。
> 生成时间:2026-08-13。关联:`docs/vfx_realism_report.md`(诊断报告)、`tools/review_vfx_realism.py`、`scenes/tools/vfx_showcase.tscn`、`tools/regen_vfx_textures_v10.py`。

## 方向
单位分帧精灵动画**不做**(已论证:单位侧已有 tween 反应——震动/击退/前冲/开火脉冲/死亡淡出 + 新增受击闪白;帧动画对多单位游戏贵且低 ROI)。本轮投 VFX 三块:**渲染优化 + 贴图 + 效果动画**。

## 两个硬约束(决定方案形态)
1. **`gl_compatibility` 渲染器 → 真 bloom(`WorldEnvironment.glow`)不可用**;项目无 WorldEnvironment / BackBufferCopy / blur shader。所以"渲染优化"不走全局 bloom。
2. **视觉评分 ±2-3 噪声**盖过增量信号(Phase D 撞过:技能未改却 -0.5)→ 必须先降噪才能可信度量。

## 执行步骤(按 ROI 排序)

### Step 1 — 评分降噪(最先,否则后面白做)
给 `tools/review_vfx_realism.py` 加 `--deterministic` 模式:温度 0 + 每张跑 3 次取中位数。压住 ±2-3 抖动,后续每步改动才能看出真实涨跌。

### Step 2 — 上下文重测(诊断,便宜,可能大跌眼镜)
改 `scenes/tools/vfx_showcase`:在特效后放虚拟单位/地面贴图,让 VFX **在上下文里**被评分。之前低分很可能是"孤立黑底无上下文"的测试假象。先验证——**若分数大涨,说明 VFX 本身没那么差,后面就不必重投**。

### Step 3 — 贴图放大 + 关键重生
关键粒子贴图(spark_metal/heavy/energy)重生到 64px(已有 `regen_vfx_textures_v10.py`,改 target)+ 调 `SPARK_SCALE_FIX`(0.4→相应值)让热梯度细节真正可见(32px 把细节压没了)。deterministic 评分对比前后。

### Step 4 — 效果动画帧改进
先审计 `assets/effects/` 下帧动画当前质量:
- `explosion_frames/`(常规橙红 / 能量蓝白 各 6 帧)
- `nuclear/nuke_mushroom_f0..f8`(9 帧蘑菇云序列)
- `spell_burst/`(10 张大招命中)

**差的**用 AI(`tools/generate_*_vfx*.py` 范式,已有 key)重生更锐利/更真实的帧序列。这是"效果动画"主体。

### Step 5 — 局部假辉光(轻量,可选)
对最亮特效(核爆/爆炸/大招)补局部 ADD 辉光层(复用 `VfxImpactFactory.spawn_impact_sprite` 已有 glow 层范式)。不做全局 bloom。

### Step 6 — 重投项(默认不做,你说了算)
- **自建 BackBufferCopy + blur shader 假 bloom**:渲染器无关,但每帧全屏模糊 = 性能开销(项目一直避免的),增益不确定。
- **切渲染器 forward_plus 开真 Glow**:效果最好,但影响移动端/低端(当初刻意选 gl_compatibility)。

看完 1-5 效果再决定要不要投。

## 验证
每步用 deterministic 评分对比,看真实涨跌(非噪声)。**Step 2 是关键诊断**——可能直接改写"VFX 差"的结论。

## 不做
- 单位分帧精灵动画
- 切渲染器(除非 Step 6 明确要)
- 动战斗逻辑/伤害数值

## 起步建议
Step 1(降噪)+ Step 2(上下文重测)先做——便宜且诊断性。**如果 Step 2 证明低分是测试假象,Step 3-5 投入就能精准很多,不必盲目重投。**

---

## 已完成的前置(供参考,均未 commit)
- **Track 1 单位受击反应**:我方(`_play_hit_flash` tween)+ 经典敌方(`_update_hit_animations` lerp modulate)+ 蜂群(slot `_hit_flash_t` + controller `_sync` lerp visual_color)。parse 过、combat_check 运行时烟雾无报错。
- **VFX 诊断流水线**:`scenes/tools/vfx_showcase.tscn`(31 特效自截)+ `tools/review_vfx_realism.py`(Agnes 2.5 Flash 视觉评分)+ `tools/regen_vfx_textures_v10.py`(贴图重生)。
- **Phase A+B+C VFX 工厂改造**(`scripts/battle/vfx_impact_factory.gd`):spark 短条贴图 / 方向锥 / 热色梯度 / 闪光+烟+破片 3 新层 / 光束辉光 / 核爆 t=0 瞬闪 / 炮口白热核心 / 池扩容。
- **Phase D 贴图重生**:6 张粒子贴图 AI 重生(8/10 质量),原件备份在 `assets/effects/particle_textures_backup_v10/`。

## 关联基线数据
- 改前基线:`docs/vfx_realism_report_BASELINE.json`(均分 2.84)
- 最新报告:`docs/vfx_realism_report.md` / `.json`
