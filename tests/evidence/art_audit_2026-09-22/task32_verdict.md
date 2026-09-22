# Task 3.2 地图/过场图审计结论（2026-09-22）

- 目检面：assets/map 全量 32 张（2 张拼图逐张看）。
- 证据：task32_map_sheet_1~2.png、task32_map_scores.csv、task32_map_refs.json。
- 引用核对（world_map.gd MAP_DIR 拼路径链）：**在用 21 张，悬空引用 0**；孤儿 11 张：
  - 7 张 bubble_*（v23 起退役，程序绘制圆环取代，注记在案）——退役留档
  - gate_near.png（注记"保留给终局近接演出"，当前零加载行）——有意保留
  - black_sun.png / mountain_bunker_marker.png——零注记纯孤儿（质量均 8-9 分，候选将来接线或清理）
  - 大地图.png——与在用 dawn_dusk_continent 同画异尺寸（2752×1536 vs 2560×1440），零加载行，疑似旧版残留
- 质量目检：**均分 8.2/10，无 <6**；全部透明底干净（gate_near/map 底图/大地图为不透明整图属正常）、无水印文字、同系列（debris 8 件 / wreck 8 件 / gate 三档）风格与色调一致、尺寸档位合理（底图 2560 档、散件 200-900 档）。
- 观察项：wreck_4（断桥）右下缘混入一个白色小三角异物（7 分，轻微，重生成时清掉）。
- 修复（Task 3.3）：无需重生成；孤儿处置建议随总报告呈批（bubble 系留档、black_sun/mountain 候选接线、大地图 候选删除）。
