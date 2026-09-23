# Task 4.1/4.2 UI 资产层审计结论（2026-09-22）

## Task 4.1 清点与引用核对（tools/_tmp_art_audit_task41.py 可复跑）
- 清点 assets/ui 全目录 **489 张**（factions 16 / icons 7 / mod_icons 249 / pilot_stage 8 / unit_decals 11 / instruments 94+68 / ranks 13 / stars 8 / truck_base 15）。
- 运行期字面 png 引用 271 处 + 模板目录覆盖（instruments×2、factions %s_128、stars star_%d、truck_tier%d）+ ranks 常量拼接 preload + icons stem/svg 孪生。
- **悬空引用：0**（初扫 4 条全部复核为误报：mod_special.png 仅归档测试引用；3 条 svg 文件实际在盘）。
- **真孤儿 15 张**：factions/*_32 ×8（128 版在用）、icons/res_permit+res_research（退役货币）、truck_base/truck_sprite_era1~5（仅归档测试引用，正身 truck_tier%d）。
- 证据：task41_ui_asset_refs.json（含 corrected_verdict）。

## Task 4.2 全量目检 89 张（3 张拼图逐张看 + 右下角水印专项放大）
- 证据：task42_ui_sheet_1~3.png、task42_watermark_scan.png、task42_watermark_scan2.png、task42_zoom_check.png、task42_scores.csv（89 行）。
- **P1 合规发现：17 张在用图带"图片由AI生成"水印**（生成器残留）：
  - stars/star_1~8.png 全部 8 张（结算/关卡列表高频出镜）
  - factions/*_128.png 全部 8 张（商店/联络台高频出镜）
  - resources/basic_nano.png（常驻资源栏）
  - 修复建议：角部水印可程序化清理（inpaint/裁剪），替换前 bak 快照（红线 3），属合规修复非审美改动，仍呈批后执行。
- 其余 64 张均分 8.16/10：truck_base 切面/tier 图 9 分（教程核心视觉质量过硬）、ranks 圆徽章族统一 8、unit_decals 军绿族统一 8-9、pilot_stage 霓虹徽章与 mod_icons 同源 8、drops 档位递进清晰 8。
- 观察项：resources/drops/gem_debug.png 为调试资产，建议核查发行包导出排除清单（S13#3 工序）。
- 水印普查扩展：instruments 94+68、开场链 17、地图 32 的右下角全部扫描（watermark_census_1~3.png），**零水印**。

## 汇总
| 项 | 数 |
|----|----|
| 目检面 | 89 张全量（重点区 50 先行） |
| P1 水印 | 17 张 |
| 悬空引用 | 0 |
| 真孤儿 | 15 张（另：第二块 pi_drop 1 张、第三块漫画 3 张+地图 11 张，见各块结论） |
