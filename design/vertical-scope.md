# Vertical Slice Definition — 构装纪元 (Phase War)

> **Status**: Defined (brownfield)
> **Created**: 2026-04-24
> **Build Version**: Current main branch (2026-04-24)

## What Is the Vertical Slice

Phase War 是一个棕地项目。当前可玩的游戏本身就是 Vertical Slice —
一个展示完整核心循环端到端功能的可玩构建。

---

## VS Scope

### Core Loop Demonstrated

The VS demonstrates the full three-layer core loop:

| Loop Layer | Duration | What the player does | Status |
|------------|----------|---------------------|--------|
| **30s loop** (in-battle) | Real-time | Click to deploy units, cast phase laws, observe auto-combat | ✅ Functional |
| **5min loop** (single battle) | ~5 min | Pre-battle loadout assembly → battle → reward settlement | ✅ Functional |
| **Session loop** (long-term) | Cross-session | Collect fragments → upgrade blueprints → unlock levels → optimize builds | ⚠️ Partial |

### Systems Included in VS

**Fully Functional (17 systems):**
- Battle System (deployment, auto-combat, waves, win/lose)
- Energy System (pre-battle selection, regeneration, law casting cost)
- Damage Calculation (stat-based combat with affix modifiers)
- Unit Stats System (platform + weapon card composition)
- Phase Law System (equip, environmental matching 50%~100% power)
- Blueprint System (fragment collection, 1-9 star progression)
- Drop System (weighted random drops with guarantees)
- Wave System (enemy wave spawning with difficulty scaling)
- Star Rating (1-3 stars based on survival + time)
- Backpack / Card Library (view and manage collected cards)
- Synthesis System (card+card rarity upgrade, card+blueprint fusion)
- Quest System (15 objective types, max 5 accepted)
- Achievement System (100+ achievements, 6 categories)
- Daily Task System (7 tasks/day, 8 types)
- Tutorial System (8-step onboarding)
- Level Unlock System (100 levels across 5 eras)
- Save/Load System (23 managers, schema v3)

**Partially Functional (3 systems):**
- Card Manufacturing (blueprint → card crafting needs refinement — Needs Revision)
- Faction System (basic UI, deeper integration in progress)
- Leaderboard (12 local boards, categories tracked)

**Not in VS:**
- Knowledge Value System (Not Started)
- Era System (Not Started, Alpha priority)

### Content Scope

| Content | Count | Coverage |
|---------|-------|----------|
| Playable levels | 100 | 5 eras × 20 levels each |
| Enemy archetypes | 60+ | WWI to Near Future sprites |
| Card blueprints | Multiple | Platform + weapon combinations |
| Phase laws | Multiple | Law cards with environmental dimensions |
| Background art | 100 | Unique per-level backgrounds |
| Affix types | Multiple | Star-based stat enhancements |
| Quest types | 15 | Attack, defend, collect, survive, etc. |

---

## VS Playtest Status

> **Note**: As a brownfield project, the game has been developed and tested by the
> developer throughout its lifecycle. Formal playtest sessions with external players
> have not yet been documented. The playtest template below should be used for
> upcoming sessions.

### Playtest Template

Use `production/playtests/playtest-[date]-[session-N].md` with this structure:

```markdown
# Playtest Session — [date]

## Context
- Tester: [developer / external]
- Build: [branch/version]
- Focus area: [core loop / specific system / onboarding]

## Tasks Given
1. [First task - e.g., "Complete a battle"]
2. [Second task]
3. [Third task]

## Observations
- What did the tester figure out without help?
- Where did they get stuck?
- What confused them?

## Fun Assessment
- Did the tester express enjoyment? (quote if possible)
- Did the core loop feel engaging?
- Did the tester want to play more?

## Issues Found
| # | Issue | Severity | Notes |
|---|-------|----------|-------|

## Action Items
- [ ] [item from issues]
```

### Recommended Playtest Plan

| Session | Focus | Tester Type | Status |
|---------|-------|-------------|--------|
| 1 | First-time player experience | Developer self-test | ⏳ Not documented |
| 2 | Core loop fun validation | External (friend/family) | ⏳ Not documented |
| 3 | Mid-game systems (synthesis, quests) | External (friend/family) | ⏳ Not documented |

---

## VS Quality Checks

| Check | Status | Evidence |
|-------|--------|----------|
| Game runs without crashes | ✅ | 220+ source files, daily development |
| Core loop complete (start → challenge → resolution) | ✅ | Title → Loadout → Battle → Reward |
| Player can understand what to do | ⚠️ Tutorial exists but not formally validated |
| No critical fun-blocker bugs | ⚠️ No formal QA pass documented |
| Core mechanic feels good | ⚠️ Subjective, needs external playtest |
| Performance within budget (60 FPS / 16.6ms) | ⚠️ Budgets defined, not empirically validated |

---

## Known Gaps from Gate Check

The following items were flagged by `/gate-check production` and should be
addressed to elevate the VS from "functional" to "validated":

1. **Formal playtest sessions** — Run 3 sessions using the template above
2. **Core fantasy validation** — Confirm a player independently describes the
   "Phase Commander" experience matching the Player Fantasy definition
3. **Performance profiling** — Run headless benchmark, verify 60 FPS target
4. **Fun assessment** — Explicitly ask: "Would you play this again?"
