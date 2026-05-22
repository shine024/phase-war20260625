# Phase Law System

> **Status**: Active (v3)
> **Source**: `managers/phase_law_manager.gd`
> **Author**: Reverse-documented + v3 design lock
> **Last Updated**: 2026-05-18
> **See also**: `design/gdd/knowledge-value-system.md`
> **Implements Pillar**: Active Skills & Environmental Strategy

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `BlueprintManager`, `BasicResourceManager`, `PhaseLaws`, `BattleEnvironments`

## Summary

The Phase Law System provides active combat skills ("laws") that players can research, equip, and cast during battle. Laws come in four families (Steel, Flame, Thunder, Void) and have environmental requirements that affect their power. The system supports passive laws (auto-apply effects) and active laws (player-triggered skills with energy/nano costs and usage limits). Laws are unlocked **only** by spending the four knowledge values defined in each law's `research_req` (v3 — no law shards).

Key design philosophy: **Active skill system** (laws provide spell-like abilities for combat depth) and **Environmental strategy** (players adapt their law selection to battle environments for optimal power).

## Overview

The Phase Law System is Phase War's "spell system"—players collect, equip, and cast laws that provide combat effects. Unlike equipment (which provides passive stat bonuses), laws are active abilities players trigger during battle for tactical advantages.

**Core loop**:
1. **Research**: Unlock laws when knowledge thresholds are met; `research_law()` consumes the required amounts
2. **Equip**: Select passive and active laws for battle (constrained by nano cost and family restrictions)
3. **Cast**: During battle, spend energy/nano to trigger active laws
4. **Adapt**: Laws have environmental requirements—matching environments boost power, mismatching reduces it

The system encourages players to build a "law loadout" alongside their equipment loadout, adding a layer of strategic planning.

## Player Fantasy

**The Phase Commander Fantasy**: Players feel like battlefield commanders wielding powerful phase technology:

- **Mastery**: Learning and collecting laws expands your tactical options
- **Preparation**: Choosing laws before battle is like planning your spell loadout
- **Adaptation**: Recognizing environmental advantages and selecting appropriate laws
- **Execution**: Timing law casts during battle for maximum impact
- **Progression**: Unlocking new laws opens new build possibilities

The system should feel like **preparing a spellbook in an RPG**—you choose your tools before battle, then execute your plan. Environmental matching adds "which spell for which dungeon" strategy.

## Detailed Design

### Core Rules

1. **Law Types**
   - **Passive laws**: Auto-apply effects based on runtime tags
   - **Active laws**: Player-triggered skills with costs and limits

2. **Law Families**
   - **STEEL** (钢铁): Defense, fortification, shields
   - **FLAME** (烈焰): Damage, burning, aggression
   - **THUNDER** (雷霆): Chain attacks, mobility, storms
   - **VOID** (虚空): Debuffs, time manipulation, stealth

3. **Unlocking Laws**
   - **Primary method**: Collect blueprint fragments (via `BlueprintManager.can_unlock_law()`)
   - **Fragment threshold**: Each law has `shard_req` (fragments needed to unlock)
   - **Secondary method**: Knowledge values (reserved for future features)
   - `can_research_law(law_id)`: Checks if unlock conditions met
   - `research_law(law_id)`: Unlocks the law

4. **Knowledge Values** (Future Features)
   - Four types: `defense_knowledge`, `energy_knowledge`, `mobility_knowledge`, `mystic_knowledge`
   - **Status**: Implemented but not currently used for unlocking
   - **Intended for**: Future expansion (special laws, alternate unlock paths)
   - **Note**: Fragment-based unlocking is the primary system; knowledge is a separate progression track

5. **Environmental Requirements**
   - Laws may require specific environmental conditions:
     - `weather`: clear, rain, storm
     - `terrain`: plain, mountain, city
     - `energy_field`: normal, high_field, nano_fog, void_rift
     - `time_of_day`: day, dusk, night
   - **Passive laws**: Must match current environment to equip
   - **Active laws**: Can equip regardless, but power affected by match level

6. **Environmental Matching**
   - **Match count**: Number of environment dimensions law requires
   - **Total dimensions**: 0-4 (laws may not require all)
   - **Power multiplier**: `50% + (match_count / total_dims) × 50%`
     - 0 matches = 50% power
     - 2/4 matches = 75% power
     - 4/4 matches = 100% power
     - No requirements = 100% power

7. **Family Restrictions**
   - Levels may restrict which law families are available
   - Checked via: `get_available_law_families_for_level()`
   - Empty list = all families allowed

8. **Equipping Laws**
   - **Pre-battle**: Select passive and active laws in phase instrument
   - **Validation**:
     - Law must be unlocked
     - Passive: Must match current environment
     - Active: Only needs unlock (no environment requirement)
     - Family restrictions apply
   - **Cost**: Nano materials paid from total nano pool
   - **Slots**: Limited by phase instrument configuration

9. **Battle Casting**
   - **Cost**: Energy (from EnergyManager) + Nano (from BasicResourceManager)
   - **Limits**: `max_cast_per_battle` (default: 999999)
   - **Conditions**: `min_friendly_units`, etc.
   - **Validation**: `can_cast(law_id, current_energy, extra_ctx)`
   - **Execution**: `record_cast(law_id)` deducts costs, increments usage

10. **Environment Changes**
    - **Active laws** can modify runtime environment
    - **Changes**: `env_changes` dict (add_tags, remove_tags)
    - **Effects**: Can enable/disable other laws by changing env
    - **Persistence**: Runtime env resets on battle end

11. **Passive Effects**
    - **Runtime tags**: Provide combat bonuses via `runtime_tags`
    - **Target side**: ALLY/ENEMY/BOTH filtering
    - **Value scaling**: Scales with blueprint star level (+2% per star)
    - **Environment check**: Passive laws only apply if environment matches

12. **Battle Lifecycle**
    - **Start**: Sync nano from BasicResourceManager, initialize active law states
    - **End**: Clear temporary state, preserve unlocked/equipped laws

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Locked | Default state | Law researched | Cannot equip or cast |
| Unlocked | Research completed | N/A (permanent) | Can equip (passive requires env match) |
| Equipped (Passive) | Equipped + env match | Env mismatches or battle ends | Provides runtime effects |
| Equipped (Active) | Equipped | Battle ends or manually unequipped | Can cast, tracks usage |
| Casting (Active) | `can_cast` passes + `record_cast` called | Cast execution completes | Deducts costs, applies effects, changes env |

### Interactions with Other Systems

| System | Interface | Data Flow | Direction |
|--------|-----------|-----------|-----------|
| **BlueprintManager** | `can_unlock_law()`, `get_law_blueprint_level()` | Fragment checks, star level | BlueprintManager → PhaseLawManager |
| **BasicResourceManager** | `get_total()`, `add_basic_resource()` | Nano material queries/deductions | PhaseLawManager → BasicResourceManager |
| **EnergyManager** | `current_energy` (via context) | Energy cost checks | EnergyManager → PhaseLawManager |
| **PhaseLaws** | `get_by_id()`, `get_all_ids()`, `get_family()` | Law data | PhaseLaws → PhaseLawManager |
| **BattleEnvironments** | `get_for_level()` | Environment data | BattleEnvironments → PhaseLawManager |
| **SignalBus** | `battle_started`, `battle_ended`, `phase_law_runtime_changed` | Battle events, environment changes | PhaseLawManager → SignalBus |
| **BattleManager** | Law casting context (friendly units) | Cast condition checks | PhaseLawManager ← BattleManager |

## Formulas

### Law Unlock Check (Fragment Method)

```
can_unlock = (BlueprintManager.can_unlock_law(law_id) == true)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| law_id | String | - | Input | Law identifier |
| can_unlock | bool | true/false | BlueprintManager | Whether fragments meet threshold |

**Expected output range**: true or false

### Law Unlock Check (Knowledge Method - Legacy)

```
can_unlock = (unlocked == false) AND
             (defense_knowledge ≥ req.defense_knowledge) AND
             (energy_knowledge ≥ req.energy_knowledge) AND
             (mobility_knowledge ≥ req.mobility_knowledge) AND
             (mystic_knowledge ≥ req.mystic_knowledge)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| req.*knowledge | int | 0-∞ | Law data | Required knowledge threshold |
| current_knowledge | int | 0-∞ | Tracked | Player's current knowledge |

**Expected output range**: true or false

### Environmental Match Count

```
match_count = Σ (environment_dimension in law_requirements)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| environment_dimension | String | - | Current environment | Current value (e.g., "storm") |
| law_requirements | Array[String] | 0-4 | Law data | Required values for each dimension |
| match_count | int | 0-4 | Calculated | Number of matching dimensions |

**Expected output range**: 0 to 4 matches

### Active Law Power Multiplier

```
if total_dimensions == 0:
    power_multiplier = 1.0  # No requirements = full power
else:
    power_ratio = match_count / total_dimensions
    power_multiplier = 0.5 + (power_ratio × 0.5)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| match_count | int | 0-4 | Calculated above | Environment matches |
| total_dimensions | int | 0-4 | Law requirements | Required dimensions |
| power_ratio | float | 0.0-1.0 | Calculated | Match proportion |
| power_multiplier | float | 0.5-1.0 | Calculated | Final damage/effect multiplier |

**Expected output range**: 0.5 (0 matches) to 1.0 (full match or no requirements)

### Nano Activation Cost

```
total_nano_cost = Σ passive_laws.activate_cost.nano + Σ active_laws.activate_cost.nano
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| passive_laws.activate_cost.nano | int | 0-∞ | Law data | Nano cost per passive law |
| active_laws.activate_cost.nano | int | 0-∞ | Law data | Nano cost per active law |
| total_nano_cost | int | 0-∞ | Calculated | Total nano to equip loadout |

**Expected output range**: 0 to 500+ nano

### Passive Law Value Scaling

```
scaled_value = base_value × (1.0 + (law_level - 1) × 0.02)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| base_value | float/int | varies | Law data | Base value from runtime_tags |
| law_level | int | 1-9 | BlueprintManager | Blueprint star level |
| scaled_value | float | varies | Calculated | Level-scaled value |

**Expected output range**: 1.0× (1★) to 1.18× (9★)

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Law not unlocked | Cannot equip, `can_cast` returns false | Must unlock before use |
| Passive law env mismatch | Cannot equip (validation fails) | Enforced environmental strategy |
| Active law env mismatch | Can equip, but power reduced (50-100%) | Active laws always usable, but power varies |
| Family restricted | Cannot equip if family not in allowed list | Level-specific constraints |
| Nano insufficient | Cannot equip (validation fails) | Resource gate |
| Cast limit reached | `can_cast` returns false | Prevents infinite casting |
| Energy insufficient | `can_cast` returns false | Resource gate |
| Nano insufficient for cast | `can_cast` returns false | Resource gate |
| Law changes environment | Runtime env updates, may affect other laws | Cascading environment effects |
| Battle ends | Active law states reset, runtime env resets | Clean slate for next battle |
| Knowledge value present | Tracked but not used for unlocking (future feature) | Reserved for future systems |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **BlueprintManager** | This depends on BlueprintManager | Fragment checks, star level data |
| **BasicResourceManager** | This depends on BasicResourceManager | Nano material management |
| **EnergyManager** | EnergyManager depends on this | Energy cost checks (via context) |
| **PhaseLaws** | This depends on PhaseLaws | Law data definitions |
| **BattleEnvironments** | This depends on BattleEnvironments | Environment data |
| **BattleManager** | BattleManager depends on this | Cast context (friendly units) |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| **MIN_POWER_MULTIPLIER** | 0.5 (50%) | 0.3-0.8 | Higher minimum power (less penalty) | Lower minimum power (harsher penalty) |
| **STAR_SCALING_PER_LEVEL** | 0.02 (2%) | 0.01-0.05 | Faster scaling with law levels | Slower scaling |
| **DEFAULT_MAX_CAST_PER_BATTLE** | 999999 | 1-10 | Limited uses (more strategic) | Unlimited (spam-friendly) |
| **ACTIVATE_COST_NANO** | Varies | 0-200 per law | More expensive (fewer laws) | Cheaper (more laws) |

**Balance Concerns**:
- **Environment matching complexity**: 4 dimensions × multiple values = many combinations. Players may struggle to understand which laws work where.
- **Knowledge value system**: Implemented but unused. If this is for future features, document what those features are so the system isn't over-engineered for nothing.
- **Active law power variance**: 50%-100% power range is significant. Underpowered laws may never be used; overpowered laws may be must-haves.

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Law unlocked | Law card reveals with glow, added to library | Unlock fanfare | HIGH |
| Law equipped | Law icon added to loadout slot | Equip confirmation | HIGH |
| Law unequipped | Law icon removed, nano refunded | Unequip sound | MEDIUM |
| Can cast becomes true | Law icon lights up/becomes enabled | Ready sound | HIGH |
| Cast successful | Cast animation, VFX, sound | Law-specific SFX | HIGH |
| Cast failed (no energy) | Error flash, error message | Error buzz | MEDIUM |
| Environment mismatch | Law icon dimmed, shows "50% power" | Low power indicator | MEDIUM |
| Environment changed | Environment indicator updates, law power updates | Env change sound | MEDIUM |

**UI Elements Required**:
- Law library panel (all laws, unlock status, requirements)
- Law loadout slots (passive/active)
- Environment display (current weather, terrain, etc.)
- Law power indicator (current power %)
- Cast buttons (for active laws)
- Nano cost display
- Law detail tooltip (requirements, effects, power)

## Game Feel

### Feel Reference

**Law Research**: Should feel like **unlocking spells in an RPG**—satisfying progression, new options open up.

**Equipping**: Should feel like **preparing loadout in XCOM**—strategic selection, each choice matters.

**Casting**: Should feel like **triggering abilities in MOBAs**—tactical timing, resource management, visual payoff.

**Environment Matching**: Should feel like **preparation bonus**—"I brought the right tools for this dungeon." Not punitive, but rewarding for planning.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|------------------------|-------|
| Click law to equip | 50ms | 3 frames | Slot update immediate |
| Click cast button | 50ms | 3 frames | Cast execution starts |
| Cast complete | 200-500ms | 12-30 frames | Animation/VFX duration |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Law unlock | 10 | 30 | 10 | Rewarding, exciting | New card reveals |
| Cast execution | 5 | 20-40 | 10 | Impactful, responsive | VFX-heavy |
| Environment change | 5 | 15 | 5 | Noticeable but not disruptive | Subtle shift |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Cast impact | 200-400 | VFX burst, sound plays, damage numbers | Yes (VFX intensity) |
| Environment match notification | 500-1000 | "Environment Match!" toast, power boost | Yes (display time) |
| Max casts reached | 500-1000 | "Exhausted" visual, button grays out | Yes (duration) |

## Open Questions

1. **Knowledge Value Purpose**: The knowledge system (4 types) is implemented but not used for unlocking. What is it intended for? Is it:
   - **Future law types** (only unlockable via knowledge)?
   - **Alternate progression** (side-grade laws)?
   - **Skill tree** (boosts law effectiveness)?
   - If no plans, consider removing to reduce complexity.

2. **Environmental Complexity**: 4 dimensions × 3-5 values each = 81+ combinations. Is this intentional depth, or should it be simplified for player accessibility?

3. **Active Law Balance**: With 50%-100% power variance, some laws may be strictly better/worse. Is this intended, or should power be normalized?

4. **Passive Law Restrictions**: Passive laws require environment match to equip, but active laws don't. Why the asymmetry? Should both follow the same rules?

5. **Law Family Strategy**: How do families interact? Do they combo (e.g., Flame + Thunder = firestorm)? Are there anti-synergies?

## Acceptance Criteria

- **GIVEN** law has fragment threshold met, **WHEN** player researches law, **THEN** law added to unlocked_laws
- **GIVEN** passive law equipped, **WHEN** environment matches, **THEN** law provides runtime effects
- **GIVEN** passive law equipped, **WHEN** environment mismatches, **THEN** law cannot be equipped (or provides no effects)
- **GIVEN** active law equipped, **WHEN** environment mismatches, **THEN** law can be equipped but power reduced to 50%
- **GIVEN** active law equipped, **WHEN** environment fully matches, **THEN** law power at 100%
- **GIVEN** active law cast, **WHEN** costs paid and conditions met, **THEN** effects apply, usage increments, environment may change
- **GIVEN** active law cast limit reached, **WHEN** player attempts cast, **THEN** `can_cast` returns false
- **GIVEN** nano insufficient for equip, **WHEN** player attempts equip, **THEN** equip fails with "纳米材料不足"
- **GIVEN** battle starts, **WHEN** laws equipped, **THEN** active law states initialized, nano budget synced
- **GIVEN** battle ends, **WHEN** cleanup triggered, **THEN** active law states cleared, runtime env reset

---

**Document Status**: Reverse-documented from existing implementation. Knowledge value system marked for future features.

**Notes**:
- **Knowledge values are implemented but unused**. Clarify their intended purpose before removing or expanding.
- **Environmental complexity** may be a player accessibility issue. Consider UI helpers to show which laws work where.
- **Active law power variance** (50%-100%) needs playtesting to ensure underpowered laws aren't ignored.
- **Consider documenting law families and their identities** to help players understand the thematic organization.
