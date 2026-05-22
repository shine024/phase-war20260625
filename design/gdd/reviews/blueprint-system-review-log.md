# Blueprint System Review Log

This document tracks all reviews and revisions for the Blueprint System GDD.

---

## Review — 2026-04-08 — Verdict: MAJOR REVISION NEEDED → REVISED

**Scope signal**: L (large scope, multiple ADRs required)
**Specialists consulted**: game-designer, systems-designer, economy-designer, qa-lead
**Blocking items**: 10 | Recommended revisions: 8

### Summary

**Initial review findings**: The Blueprint System GDD was well-documented (8/8 sections, clear formulas) but fundamentally broken from a game design perspective. The core mechanics directly contradicted the stated Player Fantasy at multiple points:

1. **"1 copy = infinite manufacturing"** made fragment collection meaningless after the first drop
2. **Auto-upgrade** removed player agency and celebration moments
3. **Law fragments shoehorned** into blueprint system created conceptual incoherence
4. **Star thresholds (25-57 copies)** delivered "mastery" in 13-25 hours, not "long-term progression"
5. **Affix RNG without re-roll** locked players into bad builds

**Verdict**: MAJOR REVISION NEEDED — Core fantasy-implementation disconnect required foundational redesign.

### Revisions Applied

**User design decisions**:
- Core fantasy resolution: **Manufacturing consumes blueprints** (Option A)
- Star progression: **Manual upgrade with celebration moments**
- Law fragments: **Keep unified** (design choice for consistency)
- Affix system: **Deterministic by platform/weapon type**

**Changes implemented**:
1. Manufacturing now consumes 1 blueprint fragment per card (addresses "infinite manufacturing" contradiction)
2. Star progression changed to manual upgrade (cost: fragments + nano, adds celebration moments)
3. Affixes changed from random to deterministic (based on platform/weapon type)
4. Star thresholds increased from 3-7 copies/star to 10-30 copies/star (long-term progression: 20-50 hours for 9★)
5. Nano conversion increased from 2 to 50 per fragment with 1000/day cap (meaningful reward)
6. Formula edge cases fixed: explicit star=0 handling, input validation, affix value clamping
7. Documentation error fixed: 2.664× multiplier (not 2.62×)
8. Acceptance criteria rewritten with deterministic testing (seed-based verification)
9. Excluded platforms removed: all platforms now collectible via fragments
10. Law shard consumption method flagged for removal (conflicts with new consumption model)

### Remaining Open Questions

1. **Manufacturing Cost Balance**: Is 1 fragment per card balanced against acquisition rates?
2. **Star Upgrade Nano Costs**: What should the nano cost scaling be for star upgrades?
3. **Deterministic Affix Pools**: How are affix pools assigned to blueprints?
4. **Nano Conversion Cap**: Should the 1000/day cap be per-blueprint or global?

### Next Steps

- **Re-review recommended**: Run `/design-review design/gdd/blueprint-system.md` in a fresh session after `/clear` to validate revisions
- **ADR required**: Create ADR documenting "Blueprint Fragment Consumption Model" decision
- **Balance testing**: Validate new progression timescales (20-50 hours for 9★) through playtesting

---

**Prior verdict resolved**: Yes — 10 blocking items addressed through foundational redesign.
