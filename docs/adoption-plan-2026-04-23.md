# Adoption Plan

> **Generated**: 2026-04-23 (updated)
> **Project phase**: Production
> **Engine**: Godot 4.5 (GDScript)
> **Template version**: v1.0+

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

---

## Step 1: Fix Blocking Gaps

### ~~1a. Fix parenthetical status value in systems-index.md~~

~~**Problem**: `systems-index.md` line 115 has status `Revised (2026-04-08)` which contains
parentheses.~~

**Status**: FIXED (2026-04-23) — changed to `Needs Revision`.

---

## Step 2: Fix High-Priority Gaps

### 2a. Populate TR registry

**Problem**: `docs/architecture/tr-registry.yaml` has `requirements: []` — no stable
requirement IDs for story traceability. `/create-stories` cannot embed TR-IDs.

**Fix**: Run `/architecture-review` after GDDs exist. This bootstraps the registry from
existing GDDs and ADRs.
**Prerequisite**: GDDs already exist (14 files).

**Time**: 1 session (review can be long for large codebases)
- [ ] tr-registry.yaml populated with requirement IDs

### 2b. Create control manifest

**Problem**: No `docs/architecture/control-manifest.md` — stories have no layer rules to follow.

**Fix**: Run `/create-control-manifest` after ADRs exist.
**Prerequisite**: At least one ADR (currently 0 ADRs).

**Note**: This is blocked by the absence of ADRs. Create ADRs first (see Step 2c),
then run `/create-control-manifest`.

**Time**: 30 min
- [ ] docs/architecture/control-manifest.md created

### 2c. Create Architecture Decision Records

**Problem**: No ADR files in `docs/architecture/`. Key decisions (autoload architecture,
signal bus, data layer, save system) are undocumented. `/architecture-review` and
`/create-control-manifest` depend on ADRs existing.

**Fix**: Run `/architecture-decision` for each key decision.

**Priority decisions**:
1. Autoload singleton architecture (35 singletons)
2. SignalBus as centralized event mediator
3. Data-driven static data + Resource layer
4. SaveManager hub-and-spoke save/load
5. Phase instrument loadout architecture

**Time**: 1-2 sessions
- [ ] ADR: Autoload singleton architecture
- [ ] ADR: SignalBus event mediator
- [ ] ADR: Data layer design
- [ ] ADR: Save system architecture
- [ ] ADR: Phase instrument loadout

### 2d. Expand game-concept.md to full GDD format

**Problem**: `design/gdd/game-concept.md` is a temporary reverse-documented stub missing
7 of 8 required sections (Player Fantasy, Detailed Rules, Formulas, Edge Cases,
Dependencies, Tuning Knobs, Acceptance Criteria). `/create-stories` cannot generate
stories from this.

**Fix**: Run `/design-system retrofit design/gdd/game-concept.md` or manually expand
the document with the 7 missing sections.

**Time**: 1 session
- [x] game-concept.md expanded with all 8 required sections (2026-04-24)

---

## Step 3: Bootstrap Infrastructure

### 3a. Register existing requirements (creates tr-registry.yaml)
Run `/architecture-review` — even if ADRs already exist, this run bootstraps
the TR registry from your existing GDDs and ADRs.
**Time**: 1 session (review can be long for large codebases)
- [ ] tr-registry.yaml created

### 3b. Create control manifest
Run `/create-control-manifest`
**Time**: 30 min
- [ ] docs/architecture/control-manifest.md created

### 3c. Set authoritative project stage
Run `/gate-check production`
**Time**: 5 min
- [ ] production/stage.txt written

### 3d. Create architecture traceability
Run `/architecture-review` — this also generates the traceability matrix.
**Time**: Included in 3a
- [ ] docs/architecture/architecture-traceability.md created

---

## Step 4: Medium-Priority Gaps

### 4a. Normalize systems-index.md status values

**Problem**: 11 rows in systems-index.md use `Partial` which is not in the allowed
status set (`Not Started`, `In Progress`, `In Review`, `Designed`, `Approved`,
`Needs Revision`). The `Revised (2026-04-08)` parenthetical was already fixed.

**Fix**: Manually edit `design/gdd/systems-index.md` to normalize status values.
- `Partial` → `In Progress` (or appropriate status based on actual state)
- `Implemented` → `Approved` (or `In Review` if not formally reviewed)

**Affected rows**: 1, 4, 6, 9, 15, 16, 17, 21, 23, 30, 33 (all `Partial`)
**Also consider**: 2, 3, 5, 7, 8, 11, 13, 14, 19, 20, 24, 25, 27, 28, 31, 32 (all `Implemented`)

**Time**: 15 min
- [ ] All status values in systems-index.md normalized

### 4b. Add missing GDD sections to stub documents

**Problem**: 5 GDDs (achievement-system.md, daily-task-system.md, leaderboard-system.md,
quest-system.md, tutorial-system.md) are minimal stubs with only Overview/Core Flow/Manager
Mapping sections. They're missing: Player Fantasy, Detailed Rules, Formulas, Edge Cases,
Dependencies, Tuning Knobs, Acceptance Criteria.

**Fix**: Run `/design-system retrofit design/gdd/[filename].md` for each, or expand
manually. Since these are meta/systems of lower priority, this can be deferred.

**Priority order** (based on code complexity):
1. quest-system.md
2. daily-task-system.md
3. achievement-system.md
4. tutorial-system.md
5. leaderboard-system.md

**Time**: 30 min per GDD (2-3 sessions total)
- [ ] achievement-system.md expanded
- [ ] daily-task-system.md expanded
- [ ] leaderboard-system.md expanded
- [ ] quest-system.md expanded
- [ ] tutorial-system.md expanded

### 4c. Update engine version in game-concept.md

**Problem**: `design/gdd/game-concept.md` says "Godot 4.6" but technical-preferences.md
and VERSION.md say "Godot 4.5". Version mismatch causes confusion.

**Fix**: Edit `design/gdd/game-concept.md` — change "Godot 4.6" to "Godot 4.5".

**Time**: 1 min
- [x] Engine version corrected in game-concept.md (2026-04-23)

### ~~4d. Update systems-index.md GDD completion list~~

**Status**: FIXED (2026-04-23) — all 13 GDDs now listed with stub annotations.

---

## Step 5: Optional Improvements

### 5a. Update tr-registry.yaml with actual requirements

**Problem**: tr-registry.yaml has `requirements: []` and only example entries. No real
requirement IDs exist.

**Note**: This is resolved by Step 2a/3a (`/architecture-review`). Listed here as
reminder only.

**Time**: Included in architecture-review run
- [ ] tr-registry.yaml has real requirement entries

### 5b. Normalize game-concept.md Status field

**Problem**: game-concept.md uses `> **Status**: Temporary (Reverse-Documented)` which is
not from the allowed status set (`In Design`, `Designed`, `In Review`, `Approved`,
`Needs Revision`).

**Fix**: Update status to `Designed` after the document is expanded.

**Time**: 1 min
- [x] game-concept.md Status field updated to valid value (2026-04-24)

### 5c. Remove example entries from tr-registry.yaml

**Problem**: tr-registry.yaml contains commented-out example entries that clutter the file.

**Fix**: Remove example block after real entries are added (Step 3a).

**Time**: 2 min
- [ ] Example entries removed from tr-registry.yaml

### 5d. Fix technical-preferences.md ADR log

**Problem**: `.claude/docs/technical-preferences.md` says "[No ADRs yet]" but after Step 2c
ADRs will exist.

**Fix**: Update after ADRs are created.

**Time**: 2 min
- [ ] ADR log in technical-preferences.md updated

---

## What to Expect from Existing Stories

No stories exist yet. When they are created (via `/create-stories`), they will automatically
conform to the template format. No migration of existing stories is needed.

---

## Recommended Execution Order

1. ~~**Done** — Fix systems-index.md parenthetical status (Step 1a)~~
2. ~~**Done** — Update GDD completion list in systems-index.md (Step 4d)~~
3. **Next** — Fix engine version in game-concept.md (Step 4c, 1 min)
4. **Next** — Create ADRs (Step 2c, 1-2 sessions)
5. **Then** — Run `/architecture-review` (Step 3a, populates TR registry + traceability)
6. **Then** — Run `/create-control-manifest` (Step 3b)
7. **Then** — Expand game-concept.md to full format (Step 2d)
8. **Later** — Normalize systems-index status values (Step 4a)
9. **Later** — Expand stub GDDs (Step 4b)
10. **Later** — Run `/gate-check production` (Step 3c)

---

## Re-run

Run `/adopt` again after completing Steps 2-3 to verify all high gaps
are resolved. The new run will reflect the current state of the project.
