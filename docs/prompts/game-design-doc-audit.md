---
name: game-design-doc-audit
description: "Audit a game system's code implementation against its design document to find data mismatches, silent fallbacks, and missing fields. Covers stat pipeline tracing, filtering exclusion bugs, sprite reference verification, and tier alignment checks."
trigger: "User asks to verify/check if game system implementation matches design document specs, combat power, stats, or visual references"
tags: [audit, design-doc, combat, stats, godot]
---

# Game System Design Doc Audit

Audit a game system's code implementation against its design document to find data mismatches, silent fallbacks, and missing fields.

## Approach

### 1. Read Design Doc for Expected Behavior
- Extract the system's expected data structure, stats, tiers, and visual references
- Note which fields are required vs optional
- Document the expected tier/difficulty distribution

### 2. Read Code Implementation
- Trace the FULL data pipeline: config data → spawn logic → stats build → visual display
- For enemy/boss systems, check:
  - `enemy_phase_masters.gd` / `enemy_blueprints.gd` — data definitions
  - `enemy_phase_field_driver.gd` / `enemy_unit.gd` — spawn and stats application
  - `unit_stats_table.gd` — stat build with era scaling
  - `enemy_phase_equipment.gd` — equipment data (check JSON vs LEGACY fallback)

### 3. Use delegate_task for Large Data Extraction
- For files >500 lines (like enemy_phase_masters.gd at 2195 lines), delegate extraction:
  - Extract structured data (stats, equipment, metadata) from all entries
  - Return as tables for comparison

### 4. Cross-Reference Checks

#### Data Completeness
- Does each config entry have ALL required fields?
- Are there fields referenced in code but missing from data (e.g., `era`, `default_weapon`)?
- What are the silent fallback defaults? (`get("era", "future")` → ALL units default to era=4)

#### Filtering Exclusion Bugs
- Does any filtering logic exclude valid entries entirely?
- **Classic trap**: platform type filters that remove ALL platforms for certain factions
  - e.g., filtering `striker/sniper/stealth/mage` kills thunder/void faction masters completely
  - Check: after filtering, is `filtered_list.is_empty()` → early return → unit never spawns?

#### Stat Calculation Chain
- `build_multi_stats(platform_type, weapon_types, era)` applies era scaling
- `era_hp_multiplier(era)` = 1.0 + era × 0.15 — wrong era means wrong HP
- Equipment `stats.hp` can OVERRIDE the calculated value (line ~231 in spawn driver)
- Master's `attack_power` / `defense` apply multipliers to spawned units

#### Visual/Sprite References
- Check `_ERA_VISUAL_ARCHETYPES` mapping — does era match available sprites?
- Verify `_pick_visual_archetype_for_era()` fallback chain finds actual assets
- Confirm sprite files exist on disk with `ResourceLoader.exists()`

#### Tier/Difficulty Alignment
- Compare design doc tier definitions vs actual code distribution
- Different tier labels (doc: 3 tiers, code: 6 tiers) can cause mismatched difficulty matching

### 5. Report Format
```
## [System Name] Audit Report

### Problem N [Severity] — Short Description
- Affected entries: list specific IDs/names
- Root cause: what in the code causes this
- Impact: gameplay consequence

### Correct Findings
- What was verified correct
```

Severity levels: Severe (gameplay breaking), Medium (wrong balance), Low (cosmetic/informational)

## Key Files in Phase War Project
- `docs/相位战争：战斗卡牌完整设定与养成系统.txt` — unit design specs
- `docs/AI_REVIEW_GAME_DESIGN_DOCUMENT游戏介绍.md` — full design doc (含相位师附录B)
- `data/enemy_phase_masters.gd` — 30 enemy phase master definitions (2195 lines)
- `data/enemy_phase_equipment.gd` — equipment data (LEGACY + JSON)
- `data/json/enemy_phase_platforms.json` — platform data with `default_weapon`
- `scenes/units/enemy_phase_field_driver.gd` — phase master spawn logic
- `scenes/units/enemy_unit.gd` — enemy unit setup
- `scenes/units/construct_unit.gd` — construct unit setup with enemy visual
- `resources/unit_stats_table.gd` — stat build functions
- `data/battle_card_v3.gd` — era scaling multipliers
- `data/enemy_archetypes.gd` — visual archetype definitions
