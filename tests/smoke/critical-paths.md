# Smoke Test: Critical Paths

**Purpose**: Run these 10-15 checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New game / session can be started from the main menu
3. Main menu responds to all inputs without freezing

## Core Mechanic

4. Player can enter battle from preparation phase
5. Player units spawn and move toward enemies
6. Enemy units spawn in waves per era configuration
7. Win/lose conditions trigger correctly (driver destruction / waves cleared)

## Card & Blueprint

8. Backpack displays collected cards correctly
9. Blueprint fragments accumulate on victory
10. Blueprint unlock triggers at correct threshold
11. Card star level displays correctly in backpack

## Data Integrity

12. Save game completes without error
13. Load game restores correct state (blueprints, progress, resources)

## Performance

14. No visible frame rate drops during battle (60fps target)
15. No memory growth over 5 minutes of play
