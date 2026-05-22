# Architecture Traceability Index

> **Last Updated**: 2026-04-24
> **Engine**: Godot 4.5

## Coverage Summary

- Total requirements: 28
- Covered: 23 (82%)
- Partial: 3 (11%)
- Gaps: 2 (7%)

## Full Matrix

| TR-ID | GDD | System | Requirement | ADR Coverage | Status |
|-------|-----|--------|-------------|--------------|--------|
| TR-battle-001 | battle-system.md | Battle | Deployment energy cost calculation | ADR-0005 | ✅ |
| TR-battle-002 | battle-system.md | Battle | Deployment time from energy cost / output rate | ADR-0005 | ✅ |
| TR-battle-003 | battle-system.md | Battle | Unit cap (max 5) and duplicate restriction | ADR-0001 | ✅ |
| TR-battle-004 | battle-system.md | Battle | Star rating (1-3★) thresholds | — | ⚠️ |
| TR-battle-005 | battle-system.md | Battle | Victory/defeat conditions | ADR-0001 | ✅ |
| TR-battle-006 | battle-system.md | Battle | Blueprint fragment drop chance + recon bonus | ADR-0003 | ✅ |
| TR-battle-007 | battle-system.md | Battle | Enemy wave spawn timing + cap | — | ❌ |
| TR-battle-008 | battle-system.md | Battle | Phase master battle mode | — | ❌ |
| TR-battle-009 | battle-system.md | Battle | Law shard drop chance by enemy tier | ADR-0003 | ✅ |
| TR-battle-010 | battle-system.md | Battle | Energy integration (spend/insufficient) | ADR-0001 | ✅ |
| TR-blueprint-001 | blueprint-system.md | Blueprint | Fragment accumulation (never consumed) | ADR-0003 | ✅ |
| TR-blueprint-002 | blueprint-system.md | Blueprint | Manual star progression (1-9★) | ADR-0003 | ✅ |
| TR-blueprint-003 | blueprint-system.md | Blueprint | Manufacturing consumes 1 fragment | ADR-0003 | ✅ |
| TR-blueprint-004 | blueprint-system.md | Blueprint | Stat multiplier by star + rarity | ADR-0003 | ✅ |
| TR-blueprint-005 | blueprint-system.md | Blueprint | Surplus fragment → nano conversion | ADR-0004 | ✅ |
| TR-blueprint-006 | blueprint-system.md | Blueprint | Law fragment unified management | ADR-0003 | ✅ |
| TR-phase-law-001 | phase-law-system.md | Phase Law | Law unlock via blueprint fragments | ADR-0003 | ✅ |
| TR-phase-law-002 | phase-law-system.md | Phase Law | Equipping laws with nano activation cost | ADR-0005 | ✅ |
| TR-phase-law-003 | phase-law-system.md | Phase Law | Environmental match power multiplier | — | ⚠️ |
| TR-phase-law-004 | phase-law-system.md | Phase Law | Battle casting (energy + nano + limits) | ADR-0001, ADR-0005 | ✅ |
| TR-phase-law-005 | phase-law-system.md | Phase Law | Passive law effects + star scaling | ADR-0005 | ✅ |
| TR-phase-law-006 | phase-law-system.md | Phase Law | Law cast environment changes | ADR-0002 | ✅ |
| TR-phase-law-007 | phase-law-system.md | Phase Law | Knowledge value system (future) | ADR-0001 | ✅ |
| TR-synthesis-001 | synthesis-system.md | Synthesis | Card+Card rarity upgrade | ADR-0003 | ✅ |
| TR-synthesis-002 | synthesis-system.md | Synthesis | Success rate mechanics (80%/90%) | — | ⚠️ |
| TR-synthesis-003 | synthesis-system.md | Synthesis | Card+Blueprint fusion (stat bonus) | ADR-0003 | ✅ |
| TR-synthesis-004 | synthesis-system.md | Synthesis | Nano material costs | ADR-0003 | ✅ |
| TR-energy-001 | energy-system.md | Energy | Energy capacity from equipped cards | ADR-0005 | ✅ |
| TR-energy-002 | energy-system.md | Energy | Net regeneration formula | ADR-0001 | ✅ |
| TR-energy-003 | energy-system.md | Energy | Post-battle auto-recharge from blocks | ADR-0004 | ✅ |
| TR-energy-004 | energy-system.md | Energy | Top-tier phase instrument ×5 regen bonus | ADR-0005 | ✅ |
| TR-unitstats-001 | unit-stats-system.md | Unit Stats | Stat composition from platform+weapon+affix | ADR-0003 | ✅ |
| TR-unitstats-002 | unit-stats-system.md | Unit Stats | Multi-weapon configuration (OMEGA) | ADR-0003 | ✅ |
| TR-unitstats-003 | unit-stats-system.md | Unit Stats | 8 affix combat modifiers | ADR-0003 | ✅ |
| TR-unitstats-004 | unit-stats-system.md | Unit Stats | 6 mutation binary states | ADR-0003 | ✅ |
| TR-unitstats-005 | unit-stats-system.md | Unit Stats | Damage calc with crit/armor/lifesteal | ADR-0003 | ✅ |
| TR-drop-001 | drop-system.md | Drop | Era-specific drop tables | ADR-0003 | ✅ |
| TR-drop-002 | drop-system.md | Drop | Weighted random selection | ADR-0003 | ✅ |
| TR-drop-003 | drop-system.md | Drop | 10 drop types with claim distribution | ADR-0003, ADR-0004 | ✅ |
| TR-drop-004 | drop-system.md | Drop | Pending drops + save/load | ADR-0004 | ✅ |

## Known Gaps

| TR-ID | GDD | Requirement | Suggested ADR |
|-------|-----|-------------|---------------|
| TR-battle-007 | battle-system.md | Enemy wave spawn timing + cap | `/architecture-decision enemy-wave-spawn-system` |
| TR-battle-008 | battle-system.md | Phase master battle mode | `/architecture-decision phase-master-battle-mode` |
