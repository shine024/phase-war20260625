# Adoption Plan

> **Generated**: 2026-04-08
> **Project phase**: Production
> **Engine**: Godot 4.6 (GDScript)
> **Template version**: v1.0+

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

---

## Step 1: Fix Blocking Gaps

No blocking gaps found. No template-format artifacts exist that could be malformed.

---

## Step 2: Fix High-Priority Gaps

### 2a. Create game concept document

**Problem**: No `design/gdd/game-concept.md` — concept pipeline skills have no entry point.

**Fix**: Run `/brainstorm` (if concept needs discovery) or manually create from existing
`docs/GAME_INTRODUCTION.md` and `docs/game_design_overview.md`.

**Time**: 30 min (manual creation from existing docs)
- [ ] `design/gdd/game-concept.md` created

### 2b. Create systems index

**Problem**: No `design/gdd/systems-index.md` — `/create-epics`, `/gate-check`, and
`/architecture-review` cannot enumerate systems.

**Fix**: Run `/map-systems` to decompose the game into a systems index, or manually create
from the architecture doc at `docs/architecture/project-architecture.md`.

**Time**: 1 session
- [ ] `design/gdd/systems-index.md` created

### 2c. Bootstrap TR registry

**Problem**: `docs/architecture/tr-registry.yaml` has empty `requirements: []` — no stable
requirement IDs for story traceability.

**Fix**: Run `/architecture-review` after GDDs and ADRs exist. This bootstraps the registry.
**Prerequisite**: Step 2a (game concept) and at least one GDD.

**Time**: 1 session (review can be long)
- [ ] tr-registry.yaml populated with requirement IDs

### 2d. Create control manifest

**Problem**: No `docs/architecture/control-manifest.md` — stories have no layer rules to follow.

**Fix**: Run `/create-control-manifest` after ADRs exist.
**Prerequisite**: At least one ADR.

**Time**: 30 min
- [ ] `docs/architecture/control-manifest.md` created

---

## Step 3: Bootstrap Infrastructure

### 3a. Create sprint tracking file

**Problem**: No `production/sprint-status.yaml` — `/sprint-status` falls back to markdown.

**Fix**: Run `/sprint-plan` (planned as P3 in this session).

**Time**: 15 min
- [ ] `production/sprint-status.yaml` created

### 3b. Set authoritative project stage

**Problem**: No `production/stage.txt` — phase must be inferred from heuristics.

**Fix**: Run `/gate-check production` after infrastructure is in place.
**Prerequisite**: Steps 2a, 2b at minimum.

**Time**: 5 min
- [ ] `production/stage.txt` written

---

## Step 4: Medium-Priority Gaps

### 4a. Formal GDDs for implemented systems

**Problem**: No GDD files in `design/gdd/`. The architecture doc captures structure but not
the 8-section GDD format required by `/create-stories`.

**Fix**: Run `/reverse-document design` for each major system (battle, cards, blueprint,
affix, energy, phase laws, drops). Or run `/design-system` to author new GDDs.

**Priority systems** (based on code complexity):
1. Battle system (managers/battle_manager.gd)
2. Card/Blueprint system (managers/blueprint_manager.gd)
3. Affix/Combat effects (managers/affix_manager.gd)
4. Energy economy (managers/energy_manager.gd)
5. Phase Law system (managers/phase_law_manager.gd)
6. Drop/Reward pipeline (managers/drop_manager.gd)

**Time**: 2-3 sessions
- [ ] Battle system GDD
- [ ] Card/Blueprint system GDD
- [ ] Affix system GDD
- [ ] Energy system GDD
- [ ] Phase Law system GDD
- [ ] Drop system GDD

### 4b. Architecture Decision Records

**Problem**: No ADR files in `docs/architecture/`. Key decisions (autoload architecture,
signal bus, data layer, save system) are undocumented.

**Fix**: Run `/architecture-decision` for each key decision, or `/reverse-document architecture`
for individual decisions.

**Priority decisions**:
1. Autoload singleton architecture (27 singletons)
2. SignalBus as centralized event mediator
3. Data-driven static data + Resource layer
4. SaveManager hub-and-spoke save/load
5. Two-tier data architecture (static tables + runtime resources)

**Time**: 1-2 sessions
- [ ] ADR: Autoload singleton architecture
- [ ] ADR: SignalBus event mediator
- [ ] ADR: Data layer design
- [ ] ADR: Save system architecture
- [ ] ADR: Resource pipeline

---

## Step 5: Optional Improvements

None — all gaps are HIGH or MEDIUM. No LOW items at this time.

---

## What to Expect from Existing Stories

No stories exist yet. When they are created (via `/create-stories`), they will automatically
conform to the template format. No migration of existing stories is needed.

---

## Recommended Execution Order

Given the current session plan (P1: reverse-document → P1: adopt → P2: test-setup → P3: sprint-plan):

1. **Now** — `/adopt` plan written (this document)
2. **Next** — `/test-setup` (P2, independent of doc work)
3. **After** — `/sprint-plan` (P3, creates sprint tracking)
4. **Later** — `/map-systems` or manual systems-index creation
5. **Later** — `/reverse-document design` for each system GDD
6. **Later** — `/architecture-decision` for key ADRs

---

## Re-run

Run `/adopt` again after completing Steps 2-3 to verify gaps are resolved.
