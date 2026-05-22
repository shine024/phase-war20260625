# Energy System

> **Status**: Verified (v3)
> **Source**: `managers/energy_manager.gd`
> **Author**: Reverse-documented from implementation
> **Last Updated**: 2026-05-18
> **v3 note**: ≥4 energy slots → regeneration ×5 is **implemented** (`energy_manager.gd`); energy max also scales with sum of equipped energy card blueprint stars (+100 per star above base).
> **Implements Pillar**: Core Constraints & Rhythm Control

## Overview

The Energy System manages the primary resource for unit deployment and active law casting during battle. Energy is capped by equipped energy cards (yellow slot), regenerates passively during combat at a rate modified by equipment, and automatically recharges from energy blocks after battle. The system serves as both a hard constraint on player actions and a rhythm control tool for pacing combat encounters.

Key design philosophy: **Resource management** (players balance regeneration and expenditure) and **Rhythm control** (energy gates deployment frequency and law casting timing).

## Player Fantasy

**The Phase Commander Fantasy**: Players feel like battlefield commanders managing limited energy reserves:

- **Strategic Planning**: Pre-battle energy card selection determines maximum capacity and regeneration rate
- **Tactical Execution**: During battle, energy expenditure must be timed carefully — deploy now or save for laws?
- **Resource Pressure**: Energy regenerates slowly, forcing meaningful choices about when to spend
- **Progression Relief**: Advanced equipment (4+ energy slots) provides massive regeneration bonuses, reducing resource pressure in late game

The system should feel like **managing a limited budget** — every energy spent is a decision, and regeneration provides a slow but steady income stream. Late-game upgrades should feel like unlocking a higher budget tier.

## Detailed Design

### Core Rules

1. **Energy Capacity**
   - Base maximum: 100 energy (determined by `ENERGY_MAX`)
   - Actual maximum: Set by equipped energy cards (`_max = max(1.0, _base_start)`)
   - If no energy cards equipped: Defaults to `ENERGY_START` (100)
   - Energy is clamped to range `[0, _max]` at all times

2. **Energy Card Types**
   - **Start Energy Cards** (`energy_start_*`): Add to `_base_start` (initial battle energy)
   - **Regeneration Cards** (`energy_regen_*`): Add to `_regen_per_sec` (passive regeneration rate)
   - **Hybrid Energy Card** (`energy_hybrid`): Provides both start bonus (+15) and regeneration (+0.3/sec)

3. **Battle Start Flow**
   - System reads equipped energy cards from PhaseInstrumentManager
   - Calculates `_base_start` and `_regen_per_sec` from card stats
   - **Top-Tier Phase Instrument Bonus**: If ≥4 energy slots equipped, regeneration ×5
   - Sets `_max = max(1.0, _base_start)`
   - **Fallback Protection**: If `_base_start ≤ 0` (no energy cards), sets `_base_start = 100` to prevent soft-lock
   - Sets current energy to `_base_start`
   - Emits `energy_changed(current, _max)` signal

4. **Energy Regeneration (During Battle)**
   - Only active when `_in_battle = true`
   - Calculated **net regeneration per second**:
     ```
     net_regen = ENERGY_REGEN_PER_SEC + _regen_per_sec - PHASE_BASE_DRAIN_PER_SEC
     ```
   - Base values:
     - `ENERGY_REGEN_PER_SEC = 1.0`
     - `PHASE_BASE_DRAIN_PER_SEC = 0.5`
     - **Base net regen = 1.0 + 0 - 0.5 = 0.5/sec** (without equipment)
   - Only regenerates if `net_regen > 0` (no energy loss if regen < drain)
   - Applied per frame: `current += net_regen × delta`
   - Emits `energy_changed(current, _max)` on update

5. **Energy Spending**
   - **Check**: `can_afford(cost)` returns `true` if `current ≥ cost`
   - **Spend**: `spend(cost)` deducts cost from current energy
   - **Validation**: If insufficient energy, emits `energy_insufficient(cost)` signal and returns `false`
   - On successful spend: Emits `energy_changed(current, _max)` signal

6. **Post-Battle Auto-Recharge**
   - Triggered on `end_battle()`
   - Calculates missing energy: `missing = ceil(max(0, _max - current))`
   - Consumes energy blocks from BasicResourceManager:
     - Checks available `energy_block` resources
     - Spends `min(available, missing)` blocks
     - Each block = +1 energy
   - Updates current energy
   - Emits `energy_changed(current, _max)` signal

7. **Energy Cards & Phase Instrument Slots**
   - Energy cards occupy yellow energy slots in phase instrument
   - System reads all equipped slots via `PhaseInstrumentManager.get_slots()`
   - Filters for `CardType.ENERGY` cards only
   - Multiple energy cards stack additively

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **Idle** | Default state | Battle starts | Energy at start value, no regeneration |
| **In Battle** | `start_battle()` called | Battle ends | Energy regenerates based on net_regen formula |
| **Post-Battle Recharge** | `end_battle()` called | Recharge complete | Auto-consumes energy blocks to refill |

### Interactions with Other Systems

| System | Interface | Data Flow | Direction |
|--------|-----------|-----------|-----------|
| **PhaseInstrumentManager** | `get_slots()` | Energy card data | PhaseInstrumentManager → EnergyManager |
| **BasicResourceManager** | `get_total(ID_ENERGY_BLOCK)`, `add_resource(ID_ENERGY_BLOCK, -amount)` | Energy block consumption | EnergyManager → BasicResourceManager |
| **SignalBus** | `energy_changed.emit(current, _max)`, `energy_insufficient.emit(cost)` | Energy state updates | EnergyManager → SignalBus |
| **BattleManager** | `start_battle()`, `end_battle()` | Battle lifecycle | BattleManager → EnergyManager |
| **Deployment System** | `can_afford(cost)`, `spend(cost)` | Energy checks/deduction | Deployment System → EnergyManager |
| **Phase Law System** | `can_afford(cost)`, `spend(cost)` | Energy checks/deduction for law casting | Phase Law System → EnergyManager |

## Formulas

### Maximum Energy Calculation

```
_max = max(1.0, _base_start)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| _base_start | float | 0-200+ | Energy card summation | Sum of all energy_start_* card bonuses |
| _max | float | 1-200+ | Calculated | Maximum energy capacity for current battle |

**Expected output range**: 1.0 (no energy cards, fallback) to 200+ (multiple start energy cards)

### Net Regeneration Per Second

```
net_regen = ENERGY_REGEN_PER_SEC + _regen_per_sec - PHASE_BASE_DRAIN_PER_SEC

# If ≥4 energy slots equipped:
net_regen × 5.0 (top-tier phase instrument bonus)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| ENERGY_REGEN_PER_SEC | float | 1.0 | GameConstants | Base regeneration per second |
| _regen_per_sec | float | 0-10+ | Energy card summation | Sum of all energy_regen_* card bonuses |
| PHASE_BASE_DRAIN_PER_SEC | float | 0.5 | GameConstants | Passive energy drain (phase instrument upkeep) |
| net_regen | float | 0.5-50+ | Calculated | Final energy gain per second |

**Expected output range**:
- No equipment: 1.0 + 0 - 0.5 = **0.5/sec**
- With 1× energy_regen_1 (0.3): 1.0 + 0.3 - 0.5 = **0.8/sec**
- With 4× energy_regen_1 (0.3 × 4 = 1.2) + top-tier bonus: (1.0 + 1.2 - 0.5) × 5 = **8.5/sec**

### Post-Battle Recharge Cost

```
missing_energy = ceil(max(0, _max - current))
energy_blocks_consumed = min(available_energy_blocks, missing_energy)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| _max | float | 1-200+ | Calculated earlier | Maximum energy capacity |
| current | float | 0-_max | Tracked during battle | Current energy at battle end |
| missing_energy | int | 0-200 | Calculated | Energy needed to refill |
| energy_blocks_consumed | int | 0-missing_energy | BasicResourceManager | Actual blocks consumed (limited by availability) |

**Expected output range**: 0 to 200 energy blocks per battle

### Current Energy Update (Per Frame)

```
current = clamp(current + net_regen × delta, 0.0, _max)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| net_regen | float | 0.5-50+ | Calculated | Net regeneration per second |
| delta | float | 0-0.033 | Engine | Time since last frame (at 30 FPS: ~0.033s) |
| current | float | 0-_max | Tracked | Current energy after update |

**Expected output range**: Smooth energy increase during battle, capped at _max

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| No energy cards equipped | _base_start defaults to 100 (ENERGY_START), _max = 100 | Prevents soft-lock where active laws can never be cast |
| _base_start ≤ 0 (invalid cards) | Overrides to 100, sets _max = 100 | Fallback protection ensures playable state |
| net_regen ≤ 0 (regen < drain) | No energy regeneration (current doesn't decrease) | System only adds energy if net_regen > 0 |
| Energy block insufficient for recharge | Consumes available blocks, leaves current < _max | Partial recharge is acceptable; doesn't fail |
| Battle ends with full energy | missing = 0, no energy blocks consumed | No cost for already-full energy |
| spend() called with insufficient energy | Returns false, emits `energy_insufficient(cost)` signal | Caller must handle failure gracefully |
| Top-tier phase instrument (≥4 slots) with no regen cards | Base regen (1.0 - 0.5 = 0.5) × 5 = 2.5/sec | Bonus applies even without regen cards |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| **GameConstants** | This depends on GameConstants | Energy constants (ENERGY_MAX, ENERGY_START, ENERGY_REGEN_PER_SEC, PHASE_BASE_DRAIN_PER_SEC) |
| **PhaseInstrumentManager** | This depends on PhaseInstrumentManager | Energy card data (equipped slots) |
| **BasicResourceManager** | This depends on BasicResourceManager | Energy block consumption (post-battle recharge) |
| **SignalBus** | This depends on SignalBus | Energy state change signals |
| **BattleManager** | BattleManager depends on this | Battle lifecycle (start/end) |
| **Deployment System** | Deployment System depends on this | Energy checks and spending for unit deployment |
| **Phase Law System** | Phase Law System depends on this | Energy checks and spending for law casting |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| **ENERGY_MAX** | 100.0 | 50-200 | Higher energy capacity, slower to deplete | Lower capacity, faster resource pressure |
| **ENERGY_START** | 100.0 | 50-200 | More starting energy, easier early game | Less starting energy, harder early game |
| **ENERGY_REGEN_PER_SEC** | 1.0 | 0.5-3.0 | Faster regeneration, less resource pressure | Slower regeneration, more strategic timing required |
| **PHASE_BASE_DRAIN_PER_SEC** | 0.5 | 0.0-2.0 | Less net regen (harder resource management) | More net regen (easier resource management) |
| **ENERGY_HYBRID_START_BONUS** | 15.0 | 5-30 | Stronger hybrid card start value | Weaker hybrid card start value |
| **ENERGY_HYBRID_REGEN_BONUS** | 0.3 | 0.1-1.0 | Stronger hybrid card regen value | Weaker hybrid card regen value |
| **TOP_TIER_MULTIPLIER** | 5.0 | 2.0-10.0 | Massive late-game regen boost | Smaller late-game regen boost |

**Balance Concerns**:
- **Top-tier multiplier (×5) is extremely powerful**: With 4× regen cards, net regen jumps from ~2/sec to ~8.5/sec. This is intentional to reward advanced equipment, but may make late-game energy trivial.
- **Base drain (0.5/sec) ensures resource pressure**: Without drain, base regen would be 1.0/sec (doubling current rate). Consider if drain should scale with equipment tier.
- **No energy card fallback**: Defaulting to 100 start/100 max prevents soft-locks, but removes build expression pressure. Consider if a lower fallback (e.g., 50) would incentivize energy card inclusion.

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Energy changed | Energy bar updates, number displays current/max | Subtle tick sound on regen | HIGH |
| Energy insufficient | Energy bar flashes red, error message "能量不足" | Error buzz | HIGH |
| Battle start (energy cards applied) | Energy bar animates to new max, shows regen rate | Energy equip sound | MEDIUM |
| Post-battle recharge | Energy blocks fly to energy bar, bar fills | Coin/jingle sound per block | MEDIUM |
| Energy full | Energy bar glows, cap indicator | Full capacity chime | LOW |

**UI Elements Required**:
- Energy bar (current/max display)
- Regeneration rate indicator (e.g., "+0.8/s")
- Energy block counter (post-battle recharge cost)
- Energy card slots (pre-battle loadout)

## Game Feel

### Feel Reference

**Energy Regeneration**: Should feel like **mana regeneration in RPGs** — slow but steady. Every second matters, but it's not fast enough to wait for. Players should plan around regeneration timing ("I'll have enough energy in 5 seconds").

**Energy Spending**: Should feel like **spending a limited budget** — every deployment or law cast is a decision. The resource pressure creates meaningful choices.

**Top-Tier Bonus**: Should feel like **unlocking a new tier** — the ×5 multiplier is dramatic and noticeable. Late-game energy should feel abundant compared to early-game scarcity.

**Post-Battle Recharge**: Should feel like **automatic convenience** — players shouldn't manually click to recharge. The block consumption should be clear but not intrusive.

### Input Responsiveness

Not applicable (no direct player input in core mechanics — this is a backend resource system).

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Energy insufficient | 200-400 | Energy bar flashes red, error message | Yes (flash duration) |
| Post-battle recharge | 500-1000 | Energy blocks animate to bar, bar fills | Yes (animation timing) |
| Top-tier bonus unlock | 1000-1500 | Special visual effect, regen rate highlights | Yes (sequence timing) |

## Open Questions

1. **Top-Tier Multiplier Balance**: ×5 multiplier for ≥4 energy slots is extremely powerful. Is this intentional to make late-game energy abundant, or should it be reduced (e.g., ×2 or ×3)?

2. **No Energy Card Fallback**: Defaulting to 100 start/100 max prevents soft-locks, but removes build pressure. Should the fallback be lower (e.g., 50) to incentivize energy card inclusion?

3. **Base Drain Scaling**: PHASE_BASE_DRAIN_PER_SEC is constant (0.5). Should drain scale with equipment tier or number of equipped cards to maintain late-game pressure?

4. **Energy Block Economy**: Post-battle recharge consumes energy blocks (1:1 ratio). Is this economy balanced, or should the ratio be adjusted (e.g., 1 block = 2 energy)?

## Acceptance Criteria

- **GIVEN** battle starts, **WHEN** energy cards are equipped, **THEN** _max and _regen_per_sec are calculated correctly from card stats
- **GIVEN** battle starts, **WHEN** ≥4 energy slots are equipped, **THEN** regeneration rate is multiplied by 5
- **GIVEN** battle starts, **WHEN** no energy cards are equipped, **THEN** _base_start defaults to 100, _max = 100
- **GIVEN** battle in progress, **WHEN** net_regen > 0, **THEN** energy increases by net_regen × delta each frame
- **GIVEN** battle in progress, **WHEN** net_regen ≤ 0, **THEN** energy does not change (no decrease)
- **GIVEN** spend(cost) called, **WHEN** current ≥ cost, **THEN** energy deducted by cost, `energy_changed` emitted, returns true
- **GIVEN** spend(cost) called, **WHEN** current < cost, **THEN** energy unchanged, `energy_insufficient` emitted, returns false
- **GIVEN** battle ends, **WHEN** current < _max, **THEN** auto-consume energy blocks to refill, `energy_changed` emitted
- **GIVEN** battle ends, **WHEN** energy blocks insufficient, **THEN** consume available blocks, current may remain < _max
- **GIVEN** battle ends, **WHEN** current = _max, **THEN** no energy blocks consumed

---

**Document Status**: Reverse-documented from existing implementation. All core mechanics documented.

**Notes**:
- **Top-tier multiplier (×5) is flagged for balance review**. Monitor player feedback to ensure late-game energy doesn't become trivial.
- **Base drain (0.5/sec) creates resource pressure** but may need scaling in late-game.
- **Post-battle auto-recharge is a convenience feature** — ensure energy block economy is balanced so recharge feels meaningful, not negligible.
