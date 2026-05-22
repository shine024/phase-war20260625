# Performance Guardrail (Mid-Low-End PC)

This project uses a low-end-PC gate inspired by the target fluency baseline.

## Required Metrics

- `TTI` (Main first interactive): measured by `PerformanceMetricsManager`.
- `Backpack first-open ms`: measured from backpack button press to panel ready.
- `Battle frame time p50/p95 ms`: sampled during active battle.

## Suggested Gate Thresholds

- `TTI <= 2500ms`
- `Backpack first-open <= 450ms`
- `Battle p50 <= 16.7ms` (60fps target median)
- `Battle p95 <= 25.0ms` (frame spike control)

## Data Source

- Runtime output file: `user://performance_baseline.json`
- Producer: `res://managers/performance_metrics_manager.gd`

## Release Gate Rule

A performance-sensitive PR should include before/after values for:

1. `tti_ms`
2. `backpack_first_open_ms`
3. `battle_p50_ms`
4. `battle_p95_ms`

If any metric regresses by more than 10%, the PR should not merge without explicit approval and mitigation notes.

## Quick Manual Validation

1. Start game, enter main scene (records `tti_ms`).
2. Open backpack once (records first-open metric).
3. Start a representative battle and play for ~60s.
4. End battle (flushes battle summary).
5. Inspect `user://performance_baseline.json`.
