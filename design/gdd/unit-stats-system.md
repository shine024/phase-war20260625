# Unit Stats System

> **Status**: Reverse-Documented
> **Source**: `resources/unit_stats.gd` (66 lines)
> **Author**: Reverse-documented from implementation
> **Last Updated**: 2026-04-08
> **Implements Pillar**: Combat Mechanics & Unit Customization

## Overview

The Unit Stats System defines all combat-relevant properties for player and enemy units through a centralized `UnitStats` Resource. Stats are derived from platform + weapon card combinations and modified by affix system enhancements. The system supports multi-weapon configurations, platform card special abilities, and mutation-based stat bonuses. Stats are attached to unit nodes at spawn and drive all combat calculations (damage, movement, attack timing).

Key design philosophy: **Compositional design** (units are built from platform + weapon cards) and **Customization depth** (affixes and mutations provide stat variety).

## Player Fantasy

**The Loadout Architect Fantasy**: Players feel like armory engineers customizing every aspect of their units:

- **Meaningful Choices**: Every platform and weapon card choice changes core stats (HP, damage, speed, range)
- **Affix Crafting**: Collecting affixes through blueprint star progression adds layers of stat customization
- **Mutation Discovery**: High-level affix combinations unlock mutations that dramatically alter unit behavior
- **Build Expression**: Different stat profiles enable distinct playstyles (tanky slow pushers vs. glass cannon rushers)

The system should feel like **customizing a loadout in an RPG** — every point in HP or damage matters, and affix combinations create unique builds.

## Detailed Design

### Core Rules

1. **Stat Source Composition**
   - **Base Stats**: Derived from platform card + weapon card data
   - **Affix Bonuses**: Added from blueprint star progression (1-9★ = 1-9 affixes)
   - **Mutation Bonuses**: Applied when affix combinations trigger mutations
   - **Runtime Tags**: Passive laws may add temporary stat bonuses during battle

2. **Core Stats (7 Base Attributes)**
   - **platform_type** (int): Platform type enum (HOUND, GUARD, TITAN, etc.)
   - **weapon_type** (int): Primary weapon type enum (SMG, RIFLE, MG, etc.)
   - **max_hp** (float): Maximum hit points (base: 100.0)
   - **move_speed** (float): Movement speed in pixels/sec (base: 80.0)
   - **attack_damage** (float): Damage per attack (base: 10.0)
   - **attack_range** (float): Attack range in pixels (base: 120.0)
   - **attack_interval** (float): Seconds between attacks (base: 1.0)
   - **is_stationary** (bool): If true, unit cannot move (fortress platforms)

3. **Multi-Weapon Configuration**
   - **weapons** (Array): List of weapon dictionaries
   - Each weapon contains: `{ weapon_type, damage, range, interval, timer }`
   - Supports units with multiple weapons (e.g., OMEGA platforms)
   - Each weapon tracks its own attack timer

4. **Card Identification (For Special Abilities)**
   - **platform_card_id** (String): Current platform card's card_id
   - **weapon_card_ids** (Array[String]): Current weapon card IDs
   - Used by combat handlers to check platform-specific abilities (e.g., bulwark, titan_mk2)

5. **Affix Stats (8 Combat Modifiers)**
   - **damage_reduction** (float 0.0-1.0): Incoming damage reduced by this percentage (from `platform_armor` affix)
   - **crit_chance** (float 0.0-1.0): Chance to deal double damage (from `crit_chance` affix)
   - **lifesteal** (float 0.0-1.0): Heal for % of damage dealt (from `lifesteal` affix)
   - **splash_damage** (float 0.0-1.0): % of damage dealt as AOE (from `splash_dmg` affix)
   - **armor_penetration** (float 0.0-1.0): Ignores enemy damage reduction (from `armor_break` affix)
   - **chain_chance** (float 0.0-1.0): Chance to chain lightning to nearby enemies (from `chain_lightning` affix)
   - **shield_on_kill** (float): Shield gained on kill (as % of max_hp, from `shield_on_kill` affix)
   - **hp_regen** (float): HP regenerated per second (as % of max_hp, from `nano_regen` affix)

6. **Mutation Flags (6 Binary States)**
   - **has_weapon_dmg_mutation**: Weapon damage has double damage probability
   - **has_weapon_atkspd_mutation**: 3 consecutive attacks trigger attack speed bonus
   - **has_crit_mutation**: Critical hits heal instead of dealing extra damage
   - **has_lifesteal_mutation**: Lifesteal doubled when below 50% HP
   - **has_hp_regen_mutation**: HP regen doubled when below 50% HP
   - **has_platform_hp_mutation**: +10% damage reduction when above 80% HP

7. **Stat Application Flow**
   - **Card Manufacturing**: BlueprintManager creates UnitStats from platform + weapon cards
   - **Affix Application**: BlueprintManager adds affix bonuses based on star level
   - **Unit Spawn**: ConstructUnit receives UnitStats via `setup(p_is_player, p_stats)`
   - **Combat Use**: Unit reads stats for damage calc, movement, attack timing

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **Created** | UnitStats Resource instantiated | Passed to unit node | Stats are data container, no state machine |
| **Attached** | `setup(p_stats)` called on unit | Unit destroyed | Unit reads stats for all combat calculations |
| **Modified** | AffixCombatHandler applies temporary bonuses | Battle ends | Runtime stat bonuses from passive laws |

### Interactions with Other Systems

| System | Interface | Data Flow | Direction |
|--------|-----------|-----------|-----------|
| **BlueprintManager** | Creates UnitStats from cards | Stat data with affix bonuses | BlueprintManager → UnitStats |
| **AffixManager** | Affix stat bonuses | Stat modifiers | AffixManager → BlueprintManager → UnitStats |
| **AffixCombatHandler** | Reads stats to apply combat effects | Stat-based triggers | AffixCombatHandler ← UnitStats |
| **ConstructUnit** | `setup(p_is_player, p_stats)` | Stats attached to unit | UnitStats → ConstructUnit |
| **Damage Calculation System** | Reads attack_damage, crit_chance, etc. | Combat calculation inputs | Damage Calculation System ← UnitStats |
| **CardAbilityManager** | Checks platform_card_id for special abilities | Platform ID lookup | CardAbilityManager ← UnitStats |

## Formulas

### Stat Composition (From Blueprint Manufacturing)

```
max_hp = base_max_hp × (1.0 + platform_hp_affix_sum + weapon_hp_affix_sum)
attack_damage = base_attack_damage × (1.0 + weapon_dmg_affix_sum)
move_speed = base_move_speed × (1.0 + platform_speed_affix_sum)
attack_range = base_attack_range × (1.0 + weapon_range_affix_sum)
attack_interval = base_attack_interval × (1.0 - weapon_aspd_affix_sum)  # Lower is faster
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| base_* | float | varies | Card data (DefaultCards) | Base stat from platform/weapon card definition |
| *_affix_sum | float | 0-2.0+ | AffixManager | Sum of all relevant affix bonuses (e.g., 0.12 = +12%) |
| max_hp | float | 50-500+ | Calculated | Final maximum HP after all bonuses |

**Expected output range**:
- **max_hp**: 50 (low base + no affixes) to 500+ (high base + 9 affixes)
- **attack_damage**: 5 to 200+
- **move_speed**: 40 to 200+
- **attack_range**: 60 to 400+
- **attack_interval**: 0.3 to 3.0

### Affix Value Scaling (By Star Level)

```
affix_value = base_value + (star_level - 1) × value_per_star
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| base_value | float | 0.08-0.20 | AffixDefinitions | Base affix bonus at 1★ |
| star_level | int | 1-9 | Blueprint star level | Current blueprint star level |
| value_per_star | float | 0.02-0.10 | AffixDefinitions | Additional bonus per star level |
| affix_value | float | varies | Calculated | Final affix percentage to apply |

**Example**: platform_hp affix (base: 0.12, per_star: 0.03)
- 1★: 0.12 = +12% HP
- 5★: 0.12 + (5-1)×0.03 = 0.24 = +24% HP
- 9★: 0.12 + (9-1)×0.03 = 0.36 = +36% HP

### Damage Calculation With Affixes

```
# Base damage
base_damage = attacker.attack_damage

# Crit check
if randf() < attacker.stats.crit_chance:
    base_damage ×= 2.0  # Double damage

# Armor penetration
effective_damage_reduction = defender.stats.damage_reduction × (1.0 - attacker.stats.armor_penetration)
final_damage = base_damage × (1.0 - effective_damage_reduction)

# Splash damage
if attacker.stats.splash_damage > 0:
    splash_damage = final_damage × attacker.stats.splash_damage
    # Apply to nearby enemies
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| base_damage | float | 5-200+ | Attacker stats | Raw attack damage |
| crit_chance | float | 0.0-1.0 | Attacker stats | Probability of crit |
| damage_reduction | float | 0.0-1.0 | Defender stats | % damage reduced |
| armor_penetration | float | 0.0-1.0 | Attacker stats | % of damage_reduction ignored |
| splash_damage | float | 0.0-1.0 | Attacker stats | % of damage dealt as AOE |
| final_damage | float | 0-500+ | Calculated | Damage after all modifiers |

**Expected output range**: 0 (full mitigation) to 500+ (crit + high damage vs no armor)

### Shield On Kill Calculation

```
shield_gained = stats.max_hp × stats.shield_on_kill
current_shield = min(current_shield + shield_gained, stats.max_hp × 2.0)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| shield_on_kill | float | 0.0-1.0 | Unit stats | % of max_hp gained as shield per kill |
| shield_gained | float | 0-200+ | Calculated | Shield amount gained |
| current_shield | float | 0-2×max_hp | Tracked | Current shield (capped at 2× max_hp) |

### HP Regen Per Second

```
hp_regen_per_second = stats.max_hp × stats.hp_regen
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| hp_regen | float | 0.0-0.10 | Unit stats | % of max_hp regenerated per second |
| hp_regen_per_second | float | 0-50+ | Calculated | HP regenerated each second |

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| No affixes on blueprint | Stats use base values only | New blueprints start at 1★ with 0-1 affixes |
| Multi-weapon unit (OMEGA) | All weapons fire independently with own timers | Each weapon in `weapons` array tracks its own `timer` |
| Platform with is_stationary=true | move_speed ignored, velocity set to (0,0) | Fortress platforms cannot move |
| Crit + lifesteal both trigger | Crit heals based on final damage (lifesteal applies after crit) | Order: base damage → crit → lifesteal |
| Damage reduction > 1.0 | Clamped to 1.0 (100% mitigation) by combat handler | Prevents invincible units |
| Shield exceeds 2× max_hp | Clamped to 2× max_hp in `add_shield()` | Hard cap on shield |
| Mutation flags not set | Mutation-based bonuses skipped in combat handler | Mutations are optional enhancements |
| weapon_card_ids empty | No weapon-specific abilities trigger | Unit functions with base stats only |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **DefaultCards** | This depends on DefaultCards | Base stat values from card definitions |
| **BlueprintManager** | BlueprintManager depends on this | Creates UnitStats when manufacturing cards |
| **AffixManager** | AffixManager depends on this | Applies affix bonuses to UnitStats |
| **AffixCombatHandler** | AffixCombatHandler depends on this | Reads stats to apply combat effects |
| **ConstructUnit** | ConstructUnit depends on this | Attaches UnitStats to unit nodes |
| **Damage Calculation System** | Damage Calculation System depends on this | Uses stats for damage formulas |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| **base max_hp** | 100.0 | 50-200 | Higher survivability, longer battles | Lower survivability, faster deaths |
| **base attack_damage** | 10.0 | 5-30 | Higher lethality, faster combat | Lower lethality, slower combat |
| **base move_speed** | 80.0 | 40-150 | Faster map traversal, more aggression | Slower positioning, more tactical |
| **base attack_range** | 120.0 | 60-300 | Kiting advantage, safer positioning | Riskier positioning, more brawling |
| **base attack_interval** | 1.0 | 0.3-3.0 | Slower attacks, less DPS | Faster attacks, more DPS |
| **affix base_value** | 0.08-0.20 | 0.05-0.30 | Stronger affix bonuses | Weaker affix bonuses |
| **affix value_per_star** | 0.02-0.10 | 0.01-0.15 | Faster affix scaling with stars | Slower affix scaling |
| **shield cap (× max_hp)** | 2.0 | 1.5-3.0 | Higher shield ceiling | Lower shield ceiling |
| **mutation trigger chance** | 0.25 (25%) | 0.15-0.40 | More mutations, more variety | Fewer mutations, less variety |

**Balance Concerns**:
- **Stat scaling range**: With 9 affixes at +36% each, stats can reach 4-5× base values. Monitor if high-star units trivialize content.
- **Multi-weapon balance**: OMEGA platforms with multiple weapons may have exponentially higher DPS. Consider if shared cooldowns or damage penalties are needed.
- **Mutation stacking**: Some units may have multiple mutations simultaneously. Ensure mutation combinations don't create overpowered outliers.
- **Crit + lifesteal synergy**: High crit + high lifesteal creates sustain outliers. Consider if these should have diminishing returns.

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Unit spawned | Unit materializes with stats-based visuals (size, weapons) | Spawn sound | HIGH |
| Stat modified (affix added) | Stat change indicator, unit glows | Power-up sound | MEDIUM |
| Critical hit | Damage number pops larger (yellow/gold), distinct impact | Crit impact sound | HIGH |
| Shield gained | Shield overlay appears, shield bar fills | Shield gain sound | MEDIUM |
| HP regen tick | Green +HP number floats up | Heal tick sound | LOW |
| Mutation triggered | Mutation icon flashes, special effect | Mutation trigger sound | MEDIUM |

**UI Elements Required**:
- Unit stat tooltip (shows all 7 core stats)
- Affix list panel (shows all 8 affix values)
- Mutation indicator (shows which mutations are active)
- Weapon list (for multi-weapon units)

## Game Feel

### Feel Reference

**Stat Customization**: Should feel like **customizing a character in an ARPG** — each affix point feels meaningful, and seeing 9 affixes on a maxed blueprint feels like a major achievement.

**Multi-Weapon Units**: Should feel like **unlocking a new tier** — OMEGA platforms with multiple weapons are dramatically more complex and powerful than single-weapon units.

**Mutations**: Should feel like **discovering secret techniques** — rare and powerful, mutations create unique build possibilities.

**Stat Scaling**: Should feel like **clear progression** — a 9★ unit should feel noticeably stronger than a 1★ unit, not just 20% better.

### Input Responsiveness

Not applicable (no direct player input in core mechanics — this is a data container system).

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Critical hit | 200-400 | Large damage number, screen shake, distinct sound | Yes (damage number size, shake intensity) |
| Shield break | 300-500 | Shield shatter effect, sound | Yes (effect duration) |
| Mutation trigger | 500-800 | Special visual effect, icon flash, sound | Yes (effect complexity) |

## Open Questions

1. **Stat Scaling Ceiling**: With 9 affixes at +36% each, stats can reach 4-5× base values. Is this intended for late-game power, or should affix scaling be capped?

2. **Multi-Weapon Balance**: OMEGA platforms with multiple weapons may have exponentially higher DPS. Should there be shared cooldowns or damage penalties to balance this?

3. **Mutation Stacking**: Can units have multiple mutations simultaneously? Should there be a limit (e.g., max 2 mutations per unit)?

4. **Crit + Lifesteal Synergy**: High crit + high lifesteal creates sustain outliers. Should these have diminishing returns (e.g., lifesteal less effective on crits)?

5. **Affix Randomness**: Are affix rolls deterministic (seeded) or truly random? If random, should there be a reroll mechanic?

## Acceptance Criteria

- **GIVEN** blueprint at 1★, **WHEN** card manufactured, **THEN** UnitStats created with 1 affix (or 0 if no affixes rolled)
- **GIVEN** blueprint at 9★, **WHEN** card manufactured, **THEN** UnitStats created with 9 affixes
- **GIVEN** unit spawned, **WHEN** UnitStats attached, **THEN** unit reads stats for all combat calculations
- **GIVEN** unit with multi-weapon config, **WHEN** attacking, **THEN** each weapon fires independently with own timer
- **GIVEN** unit with is_stationary=true, **WHEN** spawned, **THEN** velocity set to (0,0), unit cannot move
- **GIVEN** crit affix equipped, **WHEN** attack deals damage, **THEN** crit_chance check determines if damage doubled
- **GIVEN** damage_reduction affix, **WHEN** unit takes damage, **THEN** incoming damage reduced by damage_reduction percentage
- **GIVEN** lifesteal affix, **WHEN** unit deals damage, **THEN** unit heals for damage × lifesteal
- **GIVEN** shield_on_kill affix, **WHEN** unit kills enemy, **THEN** shield added (capped at 2× max_hp)
- **GIVEN** hp_regen affix, **WHEN** unit in combat, **THEN** HP regenerates by max_hp × hp_regen each second
- **GIVEN** mutation flag set, **WHEN** mutation condition met, **THEN** mutation-based bonus applied

---

**Document Status**: Reverse-documented from existing implementation. All core mechanics documented.

**Notes**:
- **Stat scaling ceiling (4-5× base) flagged for balance review**. Monitor if late-game units trivialize content.
- **Multi-weapon balance (OMEGA platforms) flagged**. Consider if shared cooldowns or damage penalties are needed.
- **Mutation stacking is currently unlimited**. Consider implementing a max mutations per unit cap if abuse occurs.
- **Affix randomness**: AffixManager handles affix allocation. Document if reroll mechanics are planned.
