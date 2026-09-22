#!/bin/bash
# P2-11 曲线采集：3 关 × A/B 组 × 3 轮，每轮独立进程
GODOT="/d/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64_console.exe"
cd "F:/godot fair duet/create/phase-war"
PROG="tests/evidence/playability_2026-09-22/curve_progress.txt"
echo "START $(date +%H:%M:%S)" > "$PROG"
for LVL in 43 50 60; do
  for G in a b; do
    for R in 1 2 3; do
      SC="r_curve_L${LVL}"
      [ "$G" = "b" ] && SC="${SC}_b"
      LOG="tests/evidence/playability_2026-09-22/curve_L${LVL}_${G}${R}.log"
      echo "RUN L${LVL}_${G}${R} begin $(date +%H:%M:%S)" >> "$PROG"
      "$GODOT" --path . --resolution 1280x720 res://tests/_playtest_driver_v2.tscn -- --scenario="$SC" > "$LOG" 2>&1
      echo "RUN L${LVL}_${G}${R} done exit=$? $(date +%H:%M:%S)" >> "$PROG"
    done
  done
done
echo "ALLDONE $(date +%H:%M:%S)" >> "$PROG"
