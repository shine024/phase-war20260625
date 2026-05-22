# Plan Title: Battle UI Redesign (Phase War)

## TL;DR
> Quick objective: Redesign the in-battle UI to match the Sleek Sci‑Fi aesthetic from the start screen, with neon accents, improved readability, and responsive layout. Deliver a cohesive HUD consisting of health/energy indicators, phase instrument, unit info, and combat feedback.
> Deliverables: Updated Battle HUD scene(s), design tokens, interaction states, accessibility presets, and QA plan.
> Estimated Effort: Large
> Parallel Execution: YES - multiple UI components can be worked on in parallel
> Critical Path: Tokens → HUD layout → Animations → Accessibility → QA

---

## Context
### Original Request
- Beautify the in-battle user experience to be visually consistent with the start screen's sci‑fi style.

### Interview Summary
- Visual direction: Sleek Sci‑Fi, neon accents, dark backgrounds.
- Breakpoints: 1280x720 and 1920x1080 supported, ensure responsive behavior.
- Accessibility: high contrast, legible typography.
- Performance: lightweight 2D assets, avoid heavy textures.

### Metis Review
- Gaps: Need canonical token usage, consistent button/iconography, and HUD layout wiring to existing game state (HP, energy, phase).

---

## Work Objectives
### Core Objective
- Create a visually cohesive, accessible, and performant battle UI that mirrors the start screen's neon sci‑fi theme and provides clear, intuitive feedback during combat.

### Concrete Deliverables
- [ ] 1) Design tokens: color palette, typography scale, glow/shadow system
- [ ] 2) HUD mockups for: Health, Energy, Phase Instrument, Unit Info, Combat Feedback
- [ ] 3) HUD scenes in Godot (e.g., BattleHUD.tscn) wired to existing managers
- [ ] 4) Input states: hover, focus, selection, and controller navigation cues
- [ ] 5) Accessibility presets: High Contrast mode and Large Typography support
- [ ] 6) Parallax/background layer concepts for battle scene (2-3 layers)
- [ ] 7) Basic animations: health/energy bar transitions, phase instrument glow
- [ ] 8) QA plan: scenarios for different resolutions and devices

### Definition of Done
- [ ] HUD loads without layout issues on 1280x720 and 1920x1080
- [ ] All UI elements are accessible via mouse/keyboard/controller
- [ ] Neon glow and parallax layers render within performance budgets
- [ ] No regressions to existing battle mechanics (health/energy updates still reflected)
- [ ] Documentation updated with design tokens and usage rules

### Must Have
- Neon sci‑fi visuals, dark background, readable text
- HUD components that convey health, energy, phase status, and combat feedback
- Responsive layout with consistent spacing
- Accessibility presets (high contrast, large typography)

### Must NOT Have (Guardrails)
- No heavy 3D UI; stick to lightweight 2D/Canvas rendering
- Do not break existing battle logic or data flow
- Do not remove existing HUD hooks without replacement

---

## Verification Strategy (MANDATORY)
- Agent-Executed QA scenarios planned for every task
- [ ] Layout QA across 1280x720 and 1920x1080
- [ ] Accessibility QA: High Contrast and Large Typography
- [ ] Interaction QA: focus/hover/keyboard/controller navigation
- [ ] Performance QA: frame-rate under load with new UI
- [ ] Integration QA: ensure new HUD components reflect game state (HP/energy/phase)

---

## Execution Strategy
### Parallel Execution Waves
Wave 1 (Foundation & Tokens):
- [ ] 1. Define design tokens (colors, typography scale, glow system)
- [ ] 2. Create HUD wireframes/mockups (Health, Energy, Phase Instrument, Info panels)
- [ ] 3. Build a BattleHUD scaffold (scene: BattleHUD.tscn) with placeholder nodes
- [ ] 4. Integrate neon glow visuals for health/energy bars

Wave 2 (HUD Construction & Interactions):
- [ ] 5. Implement HealthBar/EnergyBar visuals and transitions
- [ ] 6. Implement PhaseInstrumentPanel with 4 slots and glow states
- [ ] 7. Implement UnitInfoPanel (unit portrait, stats highlights)
- [ ] 8. Implement Feedback/Indicators (damage popups, combo indicators)
- [ ] 9. Add input navigation and focus rings for accessibility

Wave 3 (Polish & Accessibility):
- [ ] 10. Add High Contrast/Large Typography presets and switch UI
- [ ] 11. Add parallax battle background layers
- [ ] 12. Add subtle sound cues for HUD interactions

Wave FINAL (QA & Handoff):
- [ ] 13. Cross-resolution QA and perf checks
- [ ] 14. Documentation: design tokens usage and component API
- [ ] 15. Handoff: update README/notes for future work

---

## Tasks (Selected Details)
- Task A: Design tokens
- Task B: HUD skeleton in Godot
- Task C: Health/Energy bars with neon glow
- Task D: PhaseInstrumentPanel wiring to game state
- Task E: UnitInfoPanel visuals
- Task F: Accessibility presets (toggle for high contrast/large text)
- Task G: Parallax battle background layers
- Task H: Input navigation & focus cues
- Task I: QA test plan & coverage

---

## Final Verification Wave
- F1: Plan compliance audit (oracle)
- F2: Code quality review (unspecified-high)
- F3: Real manual QA or Playwright UI tests (unspecified-high)
- F4: Scope fidelity check (deep)

## Commit Strategy
- type(scope): battle-ui-redesign: neon HUD polish

## Success Criteria
- Battle HUD visually cohesive with start screen's sci‑fi style
- All HUD elements reflect game state accurately and updates smoothly
- Accessibility presets active and tested
- Performance remains within acceptable budget
