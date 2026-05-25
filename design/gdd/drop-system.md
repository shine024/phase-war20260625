# Drop System

> **Status**: Active (v3 revision)
> **Source**: `managers/drop_manager.gd`, `scripts/card_drop_grants.gd`, `managers/battle/battle_damage_system.gd`
> **Author**: Reverse-documented + v3 design lock
> **Last Updated**: 2026-05-18
> **See also**: `docs/ARCH_DECISIONS.md` ADR-001
> **Implements Pillar**: Resource Economy & Progression

## Overview

The Drop System manages combat rewards for Phase War. **v3**: finished cards go to the **backpack** first (`CardDropGrants` → `DropManager.grant_dropped_cards_by_id`). Blueprint fragment / law shard progression types are **deprecated**; law progression uses **knowledge values** from kills. Pending drops + claim flow unchanged.

Key design philosophy: **Immediate usable loot** (cards in backpack) and **account progression** (stars via research points, laws via knowledge).

## Player Fantasy

**The Loot Collector Fantasy**: Players feel like scavengers gathering resources from the battlefield:

- **Anticipation**: Every battle ends with the question "What did I get?"
- **Variety**: Materials, finished cards (star/rarity/affix), lore, energy cards, stat boosts
- **Progression**: Higher eras improve material tiers and card pool weights; law knowledge from combat by family
- **Excitement**: Rare drops (high-star cards, law cards) create memorable moments
- **Planning**: Players think "I need X more drops to unlock this blueprint" or "This era drops the materials I need"

The system should feel like **opening loot boxes in ARPGs** — every drop is a small reward, and rare drops create excitement.

## Detailed Design

### Core Rules

1. **Drop Generation Trigger**
   - **Battle End**: `generate_battle_drops(era, level, player_won, victory_stars)` called by BattleManager
   - **Boss Battle**: `generate_boss_drops(era, boss_id)` for boss-specific loot
   - **Drop Tables**: Era-specific drop tables define available loot and weights

2. **Drop Types (runtime enum; v3 priorities)**
   - **MATERIAL**: Basic resources (nano, alloy, crystal, energy_block, research_points)
   - **DROPPED_CARD / CARD_DATA**: Finished card → backpack (primary unit reward)
   - **LORE_PAGE**, **ENERGY_CARD**, **STAT_BOOST**, **LAW_DATA**: As before
   - **BLUEPRINT_FRAGMENT / LAW_BLUEPRINT**: **Deprecated** — UI may still deserialize old saves; new tables should not emit these

3. **Drop Table Structure**
   - **DropEntry**: `{ item_id, type, weight, min_count, max_count, metadata }`
   - **DropTable**: `{ table_id, table_name, min_drops, max_drops, entries[], guarantee_drops[] }`
   - **Weighted Random**: Higher weight = more likely to drop
   - **Guarantee Drops**: Always awarded (e.g., basic materials in every battle)

4. **Era-Specific Progression**
   - **Era 0 (WW1)**: Low material drops, basic blueprints
   - **Era 1 (WW2)**: Medium materials, improved blueprints
   - **Era 2 (Cold War)**: Adds crystal drops, advanced blueprints
   - **Era 3 (Modern)**: High material drops, modern blueprints
   - **Era 4 (Near Future)**: Highest material drops, futuristic blueprints

5. **Drop Generation Flow**
   - BattleManager calls `generate_battle_drops(era, level, player_won, victory_stars)`
   - DropManager selects random drops from era-specific table based on weights
   - Guarantee drops always included
   - Victory stars may influence drop quality or count (implementation-specific)
   - Generated drops stored in `pending_drops` array
   - `drops_generated` signal emitted

6. **Drop Claiming Flow**
   - Player claims drops (UI-triggered or auto-claim)
   - `claim_drops()` iterates through `pending_drops`
   - Each drop processed by `_process_single_drop()`:
     - **MATERIAL** → `BasicResourceManager.add_resource()`
     - **BLUEPRINT_FRAGMENT** → legacy: unlock + optional copy (prefer **DROPPED_CARD**)
     - **DROPPED_CARD** → Clone card, random star (1-9★), add affixes, emit `card_added_to_backpack`
     - **LORE_PAGE** → `LoreManager.unlock_lore()` or store in GameManager
     - **CARD/ENERGY_CARD** → `DefaultCards.get_card_by_id()`, emit `card_added_to_backpack`
     - **STAT_BOOST** → `StatBoostManager.apply_boost()` or store in GameManager
     - **LAW_BLUEPRINT** → deprecated; migrate to knowledge on load
     - **LAW_CARD** → backpack law card instance; research still requires knowledge unlock
     - **ENERGY_BLUEPRINT** → Resolve to era-specific energy blueprint, add to BlueprintManager
   - `drops_claimed` signal emitted
   - `pending_drops` cleared

7. **Random Law Selection**
   - Some drops use `random_law_blueprint`, `random_law_passive`, `random_law_active` IDs
   - System randomly selects from all law IDs in PhaseLaws data
   - Filters by law kind (passive/active) if specified
   - Ensures valid law ID before proceeding

8. **Dropped Card Special Handling**
   - Dropped cards are clones of base card data
   - **Random Star Level**: `randi_range(1, 9)` → 1-9★
   - **Affix Generation**: `BlueprintManager.get_default_enhancements(card_id, star)` provides affixes
   - **Mark as Dropped**: `is_dropped_card = true` flag set
   - **Signal Emission**: `SignalBus.card_added_to_backpack.emit(dropped_card)`

9. **Pending Drop Management**
   - **pending_drops**: Array of unclaimed drops
   - **get_pending_drops()**: Returns copy of pending drops (read-only access)
   - **get_pending_drops_count()**: Returns count of pending drops
   - **clear_pending_drops()**: Empties pending drops (rare, used on reset)
   - **Save/Load**: Pending drops serialized/deserialized for save compatibility

10. **Blueprint ID Resolution**
    - Era-specific fragments use virtual IDs like `era_0`, `era_1`
    - `resolve_blueprint_id(item_id, era)` maps to actual blueprint IDs
    - Each era has 26 blueprint IDs (`bp_ww1_001` through `bp_ww1_026`)
    - Random selection from era pool when resolving

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **Idle** | Default state | Battle ends | No pending drops |
| **Generating** | `generate_battle_drops()` called | Drops generated | Drop table queried, drops stored in pending_drops |
| **Pending** | Drops generated, not claimed | `claim_drops()` called | Waiting for player to claim |
| **Claiming** | `claim_drops()` called | All drops processed | Distributing rewards to appropriate managers |
| **Complete** | All drops claimed | Next battle starts | pending_drops cleared |

### Interactions with Other Systems

| System | Interface | Data Flow | Direction |
|--------|-----------|-----------|-----------|
| **BattleManager** | `generate_battle_drops()`, `generate_boss_drops()` | Battle results (era, level, won, stars) | BattleManager → DropManager |
| **DropTables** | Drop table definitions, weight-based random selection | Drop entries, weights | DropTables → DropManager |
| **BasicResourceManager** | `add_resource()` | Material drops (nano, alloy, crystal, energy_block) | DropManager → BasicResourceManager |
| **BlueprintManager** | `add_blueprint_copy()`, `add_law_shard()`, `get_default_enhancements()` | Blueprint fragments, law shards, affix data | DropManager → BlueprintManager |
| **SignalBus** | `drops_generated`, `drops_claimed`, `card_added_to_backpack` | Drop state changes | DropManager → SignalBus |
| **LoreManager** | `unlock_lore()` | Lore page drops | DropManager → LoreManager |
| **StatBoostManager** | `apply_boost()` | Stat boost drops | DropManager → StatBoostManager |
| **PhaseLawManager** | `ensure_law_unlocked()` | Auto-unlock laws when threshold met | DropManager → PhaseLawManager |
| **DefaultCards** | `get_card_by_id()`, `create_law_card_resource()` | Card data lookup | DefaultCards → DropManager |
| **SaveManager** | `save_state()`, `load_state()` | Pending drops serialization | Bidirectional |

## Formulas

### Drop Count Calculation

```
drop_count = randi_range(table.min_drops, table.max_drops)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| table.min_drops | int | 1-3 | DropTable definition | Minimum drops guaranteed |
| table.max_drops | int | 1-5 | DropTable definition | Maximum drops possible |
| drop_count | int | 1-5 | Calculated | Number of drops to generate |

**Expected output range**: 1 to 5 drops per battle

### Weighted Random Drop Selection

```
total_weight = Σ entry.weight for all entries in table
random_roll = randf() × total_weight
cumulative_weight = 0.0

for entry in table.entries:
    cumulative_weight += entry.weight
    if random_roll <= cumulative_weight:
        return entry

# Repeat drop_count times
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| entry.weight | float | 1.0-8.0 | DropEntry definition | Drop probability weight |
| total_weight | float | 20-50 | Calculated | Sum of all entry weights |
| randf() | float | 0.0-1.0 | Godot built-in | Random number generator |
| random_roll | float | 0.0-total_weight | Calculated | Weighted random selection |

**Expected output**: Higher weight entries dropped more frequently

### Drop Quantity Calculation

```
drop_quantity = randi_range(entry.min_count, entry.max_count)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| entry.min_count | int | 1-2 | DropEntry definition | Minimum items in this drop |
| entry.max_count | int | 1-3 | DropEntry definition | Maximum items in this drop |
| drop_quantity | int | 1-3 | Calculated | Number of items in this drop |

**Expected output range**: 1 to 3 items per drop entry

### Material Drop Calculation (Example: Nano Materials)

```
# From DropEntry: "nano_materials", weight=8.0, min=50, max=100
nano_materials_gained = randi_range(50, 100)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| nano_materials_gained | int | 50-200 | Calculated | Nano materials added to BasicResourceManager |

**Expected output range**: 50-200 (WW1) to 120-250 (Modern)

### Dropped Card Star Level

```
star_level = randi_range(1, 9)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| star_level | int | 1-9 | Calculated | Random star level for dropped card |

**Expected output range**: 1★ to 9★ (uniform distribution)

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Empty drop table | Returns empty drops array | Failsafe for missing era tables |
| Zero weight entry | Never dropped (weight = 0) | Zero weight means excluded from pool |
| Invalid item_id | Drop skipped, error logged | Prevents crash on bad data |
| BlueprintManager missing | Blueprint fragments not added, error logged | Graceful degradation if manager unavailable |
| Law card with random_law_* | Randomly selects valid law ID | Handles wildcard law IDs |
| Era 0 blueprint resolution | Maps to WW1 blueprint pool | Era-specific blueprint pools |
| Duplicate drops | All duplicates added (e.g., 2× nano_materials) | Multiple drop entries of same type are additive |
| Pending drops claimed twice | Second claim does nothing (already cleared) | Idempotent claim operation |
| Save load with missing drop types | Loads available drops, skips invalid | Forward compatibility for new drop types |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **DropTables** | This depends on DropTables | Drop table definitions, era-specific pools |
| **BasicResourceManager** | This depends on BasicResourceManager | Material drop distribution |
| **BlueprintManager** | This depends on BlueprintManager | Blueprint fragment distribution, affix generation |
| **SignalBus** | This depends on SignalBus | Drop state change signals |
| **LoreManager** | This depends on LoreManager | Lore page unlock |
| **StatBoostManager** | This depends on StatBoostManager | Stat boost application |
| **PhaseLawManager** | This depends on PhaseLawManager | Law auto-unlock on fragment threshold |
| **DefaultCards** | This depends on DefaultCards | Card data lookup |
| **BattleManager** | BattleManager depends on this | Drop generation trigger |
| **SaveManager** | SaveManager depends on this | Pending drops serialization |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| **min_drops** | 1 | 1-3 | More drops per battle, faster progression | Fewer drops, slower progression |
| **max_drops** | 3 | 2-5 | More drops per battle, higher variance | Fewer drops, lower variance |
| **MATERIAL weight** | 5.0-8.0 | 3.0-10.0 | More material drops, fewer other types | Fewer materials, more variety |
| **BLUEPRINT_FRAGMENT weight** | 3.0-4.5 | 2.0-6.0 | More blueprint fragments, faster collection | Fewer fragments, slower collection |
| **DROPPED_CARD weight** | 1.5 | 1.0-3.0 | More complete cards, immediate power | Fewer cards, more reliance on crafting |
| **min_count (materials)** | 50-120 | 25-200 | Higher material income | Lower material income |
| **max_count (materials)** | 100-200 | 50-300 | Higher material variance | Lower material variance |
| **star_level range** | 1-9 | 1-9 | Wider range includes more high-star drops | Narrower range limits high-star drops |

**Balance Concerns**:
- **Material economy**: Late-game battles drop 120-250 materials. Ensure material sinks (enhancement, affix rerolling) scale appropriately to prevent accumulation.
- **Dropped card star level**: Uniform 1-9★ distribution means 9★ cards are as common as 1★. Consider weighted distribution (more low-star, fewer high-star).
- **Blueprint data vs. complete card balance**: Players get both blueprint data (for long-term progression) and complete cards (immediate power). Ensure this dual system doesn't trivialize progression.
- **Law drop randomness**: Random law cards/blueprints may give unwanted laws. Consider if players should have some control (e.g., law family selection).

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Battle ends (drops generated) | Drop count indicator, "X drops ready" notification | Drop ready sound | HIGH |
| Drop claim started | Cards/resources fly to inventory, progress bar | Collecting sounds per drop | HIGH |
| Rare drop (9★ card, law card) | Special glow effect, distinct color, "RARE!" label | Rare drop fanfare | HIGH |
| Material added | Resource counter animates up, +N number | Coin/jingle sound | MEDIUM |
| Blueprint fragment added | Blueprint icon flies to collection, fragment counter | Collect chime | MEDIUM |
| Card added to backpack | Card slot highlight, card reveal animation | Card acquire sound | HIGH |
| Lore unlocked | Lore icon appears, "New lore unlocked" toast | Discovery sound | MEDIUM |

**UI Elements Required**:
- Drop claim screen (shows all pending drops with icons/quantities)
- Drop rarity indicators (color coding: common, rare, epic, legendary)
- "Claim All" button
- Individual drop tooltips (shows drop details, stats, etc.)
- Drop history (recent drops log)

## Game Feel

### Feel Reference

**Drop Generation**: Should feel like **opening loot boxes in ARPGs** — anticipation, variety, occasional rare drops that create excitement.

**Claiming Drops**: Should feel like **opening reward chests** — satisfying animations, sound effects per drop type, visual feedback flying items to inventory.

**Material Drops**: Should feel like **collecting resources** — steady, reliable income. Not exciting, but necessary for progression.

**Rare Drops**: Should feel like **jackpot moments** — 9★ cards, law cards should have special effects and sounds to make them memorable.

**Progression**: Should feel like **meaningful advancement** — higher eras drop better materials, players see clear progression from WW1 to Near Future drops.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|------------------------|-------|
| Click "Claim Drops" | 50ms | 3 frames | Claim animation starts immediately |
| Individual drop flies to inventory | 200-500ms | 12-30 frames | Per-drop animation duration |
| All drops claimed | 1000-2000ms | 60-120 frames | Total claim sequence duration |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Rare drop reveal | 500-800 | Special glow, sound, "RARE!" label | Yes (effect intensity) |
| Material drop | 100-200 | Quick number popup, subtle sound | Yes (duration, sound) |
| Card drop | 300-500 | Card flip animation, card art reveal | Yes (animation timing) |
| Claim complete | 200-400 | Summary screen, "All drops claimed" message | Yes (display time) |

## Open Questions

1. **Dropped Card Star Distribution**: Currently uniform 1-9★. Should this be weighted (e.g., more 1-3★, fewer 7-9★) to make high-star drops feel rarer?

2. **Law Drop Randomness**: Random law cards/blueprints may give unwanted laws. Should players have some control (e.g., select law family before battle)?

3. **Drop Claim Automation**: Currently manual claim. Should drops be auto-claimed on battle end, or is manual claim part of the gameplay loop?

4. **Material Economy Scaling**: Late-game drops 120-250 materials. Do material sinks scale appropriately, or will players accumulate excessive materials?

5. **Duplicate Drop Handling**: Multiple drops of same type are additive. Is this intended, or should there be caps/diminishing returns?

## Acceptance Criteria

- **GIVEN** battle ends, **WHEN** `generate_battle_drops()` called with era/level/won/stars, **THEN** drops generated from era-specific table, stored in pending_drops
- **GIVEN** drop table with weights, **WHEN** drops generated, **THEN** higher weight entries dropped more frequently
- **GIVEN** guarantee drops defined, **WHEN** drops generated, **THEN** guarantee drops always included
- **GIVEN** MATERIAL drop, **WHEN** claimed, **THEN** BasicResourceManager.add_resource() called with correct material ID and quantity
- **GIVEN** BLUEPRINT_FRAGMENT drop, **WHEN** claimed, **THEN** BlueprintManager.add_blueprint_copy() called with resolved blueprint ID
- **GIVEN** DROPPED_CARD drop, **WHEN** claimed, **THEN** card cloned with random star (1-9★), affixes added, `card_added_to_backpack` emitted
- **GIVEN** LAW_BLUEPRINT drop, **WHEN** claimed, **THEN** BlueprintManager.add_law_shard() called, PhaseLawManager.ensure_law_unlocked() if threshold met
- **GIVEN** LAW_CARD drop with random_law_*, **WHEN** claimed, **THEN** valid law ID randomly selected, law card created and added to backpack
- **GIVEN** pending drops, **WHEN** `claim_drops()` called, **THEN** all drops processed, `drops_claimed` emitted, pending_drops cleared
- **GIVEN** save state with pending drops, **WHEN** `load_state()` called, **THEN** pending drops restored from save data
- **GIVEN** era-specific blueprint ID (era_0), **WHEN** resolved, **THEN** random blueprint from WW1 pool selected

---

**Document Status**: Reverse-documented from existing implementation. All core mechanics documented.

**Notes**:
- **Dropped card star distribution flagged for balance review**. Uniform 1-9★ may make high-star drops too common. Consider weighted distribution.
- **Material economy scaling flagged**. Late-game drops 120-250 materials. Ensure sinks scale to prevent excessive accumulation.
- **Law drop randomness may create frustration**. Players may get unwanted laws. Consider adding law family selection or reroll mechanics.
- **Drop claim automation**: Currently manual. If players find claim tedious, consider auto-claim option with summary screen.
