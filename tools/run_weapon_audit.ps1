# Weapon semantics audit runner (v38.5)
# Purpose: one command to run all three audit layers - regression locks +
#          full semantic audit probe + burst visual audit probe.
#          Run this after adding new cards/enemies/weapon names on the data side;
#          it catches name-vs-classification misalignment without manual playtesting.
# Usage:   powershell -ExecutionPolicy Bypass -File tools/run_weapon_audit.ps1
#          Add -Quick to run regression locks only (seconds). Default: full run (~1 min).
# Note:    ASCII-only on purpose - Windows PowerShell 5.1 parses BOM-less UTF-8 as ANSI,
#          and non-ASCII text in this script would break the parser on CN-locale machines.
param([switch]$Quick)

$ErrorActionPreference = "Continue"

# Godot auto-detection (two dev machines, first hit wins; console build preferred)
$GODOT = ""
foreach ($c in @(
  "D:/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64_console.exe",
  "D:/Downloads/Godot/Godot_v4.5.1-stable_win64_console.exe",
  "D:/Downloads/Godot/Godot_v4.5.1-stable/Godot_v4.5.1-stable_win64.exe",
  "D:/Downloads/Godot/Godot_v4.5.1-stable_win64.exe",
  "D:/Downloads/Godot/Godot_v4.5.1.exe")) {
  if (Test-Path $c) { $GODOT = $c; break }
}
if ($GODOT -eq "") {
  Write-Host "[X] Godot executable not found - check paths in AGENTS.md" -ForegroundColor Red
  exit 1
}
$PROJ = Split-Path -Parent $PSScriptRoot
Write-Host "[i] Godot = $GODOT"
Write-Host "[i] Project = $PROJ"

$fail = $false

# Layer 1: regression locks (incl. [14] semantic alignment hard locks + [15] resource chain)
# NOTE 1: capture via `cmd /c "... 2>&1"` - Godot is a GUI-subsystem executable; plain PS
#         variable assignment ($v = & $GODOT ...) silently captures ZERO lines. cmd-level
#         redirection is the reliable path. v38.5 pitfall.
# NOTE 2: capture full output BEFORE filtering. An early-terminating pipeline
#         (Select-Object -First) upstream of a native command deadlocks: the child blocks
#         writing to a full stdout pipe that nobody reads anymore. v38.5 pitfall.
Write-Host ""
Write-Host "========== [1/3] regression locks: weapon_visual_profiles_smoke.gd ==========" -ForegroundColor Cyan
$smokeOut = & cmd /c "`"$GODOT`" --headless --rendering-driver opengl3 --path `"$PROJ`" --script tests/weapon_visual_profiles_smoke.gd 2>&1"
$smokeOut | Select-String -Pattern "FAIL" | Select-Object -First 12
$smokeText = ($smokeOut -join "`n")
if ($smokeText -match "(\d+) FAIL" -and $Matches[1] -ne "0") {
  Write-Host "[X] regression lock has failures" -ForegroundColor Red
  $fail = $true
} else {
  Write-Host "[OK] regression locks passed" -ForegroundColor Green
}

if (-not $Quick) {
  # Layer 2: full semantic audit (six rules + baseline data)
  Write-Host ""
  Write-Host "========== [2/3] semantic audit: _tmp_weapon_semantics_audit.gd ==========" -ForegroundColor Cyan
  $auditOut = & cmd /c "`"$GODOT`" --headless --rendering-driver opengl3 --path `"$PROJ`" --script tests/_tmp_weapon_semantics_audit.gd 2>&1"
  $auditOut | Select-String -Pattern "^=|^---- R" | Select-Object -First 14
  Write-Host "[i] R1/R3 must stay 0; R2/R5/R6 are soft findings (see CHANGELOG v38.4/v38.5)"

  # Layer 3: burst visual audit (single-damage vs multi-bullet distribution)
  Write-Host ""
  Write-Host "========== [3/3] burst audit: _tmp_burst_visual_audit.gd ==========" -ForegroundColor Cyan
  $burstOut = & cmd /c "`"$GODOT`" --headless --rendering-driver opengl3 --path `"$PROJ`" --script tests/_tmp_burst_visual_audit.gd 2>&1"
  $burstOut | Select-String -Pattern "^=" | Select-Object -First 8
}

Write-Host ""
Write-Host "========== audit run finished =========="
if ($fail) { exit 1 }
exit 0
