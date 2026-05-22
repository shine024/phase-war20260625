# Plan Title: Start Screen Redesign (Phase War)

## TL;DR
> Quick objective: Modernize start screen with sleek Sci‑Fi aesthetics, accessible UI, and responsive layout. Deliver a reusable start screen scene with a parallax background, animated title, and four primary actions: Play, Settings, Credits, Quit.
> Deliverables: Start screen scene, tokens/style guide, basic interactions, accessibility tweaks, low-poly background assets.
> Estimated Effort: Large
> Parallel Execution: YES (multiple UI assets and tokens can be prepared in parallel)
> Critical Path: Token design → Moodboard → Start Screen Scene skeleton → Animations → Accessibility & Input → Polish & QA

---

## Context
### Original Request
- Beautify the game's start screen with better visuals and usability.

### Interview Summary
- Visual direction chosen: Sleek Sci‑Fi. 
- Branding: No external branding required. 
- Layout: Title logo + 4 primary actions. 
- Accessibility: Prioritize high contrast and large typography. 
- Performance: Prefer low-poly background for smooth performance.

### Metis Review
- Gaps: Need concrete token set, UI wiring, and navigation plan.

---

## Work Objectives
### Core Objective
- Deliver a polished, accessible, and responsive start screen that aligns with the chosen visual direction and branding constraints.

### Concrete Deliverables
- [ ] 1) Visual tokens: color palette, typography, elevation, shadows
- [ ] 2) Moodboard and style guide documenting assets and usage
- [ ] 3) Godot start screen scene: parallax background, animated logo, 4 buttons
- [ ] 4) Button interactions: hover/focus states, keyboard/controller navigation
- [ ] 5) Accessibility improvements: large typography option, high contrast preset
- [ ] 6) Lightweight background assets (low-poly) to meet performance needs
- [ ] 7) Basic sound cues for navigation/clicks (optional for MVP)

### Definition of Done
- [ ] Start screen scene loads at a variety of resolutions (720p, 1080p, 4K) without layout breaks
- [ ] All 4 buttons are navigable via mouse, keyboard, and controller
- [ ] High-contrast and large typography presets are functional
- [ ] Background uses low-poly assets and parallax performs smoothly (120fps target on typical hardware)

### Must Have
- Visual direction aligned with Sleek Sci‑Fi
- Parallax background and animated title
- Accessible UI with high contrast and legible typography
- Responsive layout adapts to screen sizes

### Must NOT Have (Guardrails)
- No heavy 3D scenes that hurt performance
- No branding assets that imply external IPs
- Do not modify existing gameplay scenes beyond start screen dependencies

---

## Verification Strategy (MANDATORY)
- Agent-Executed QA scenarios are planned for every task
- [ ] UI aesthetics QA: verify color, typography, spacing, and contrast
- [ ] Interaction QA: keyboard/controller navigation works, focus rings visible
- [ ] Layout QA: responsive at 1280x720, 1920x1080, and 3840x2160
- [ ] Performance QA: background parallax runs smoothly with minimal frame drops

---

## Execution Strategy
### Parallel Execution Waves
Wave 1 (Foundation + Tokens):
- [ ] 1. Define design tokens (colors, typography, elevations)
- [ ] 2. Create moodboard & style guide
- [ ] 3. Sketch start screen layout wireframes
- [ ] 4. Prepare low-poly background assets

Wave 2 (UI Construction):
- [ ] 5. Implement start screen scene skeleton in Godot
- [ ] 6. Implement logo/title animation
- [ ] 7. Implement 4 button components with states

Wave 3 (Accessibility & Polish):
- [ ] 8. Add high-contrast preset and large typography option
- [ ] 9. Implement responsive layout and input navigation
- [ ] 10. Add sound cues (hover/click) and polish

Wave FINAL (QA & Handoff):
- [ ] Wave 1 Task 1: Define design tokens for start screen (colors, typography, elevation)
- [ ] Wave 1 Task 2: Create moodboard and style guide baseline
- [ ] Wave 1 Task 3: Implement start screen scene skeleton in Godot (parallax background, title, 4 buttons)
- [ ] Wave 1 Task 5: Implement Start Screen Skeleton in Godot (scene: StartScreen.tscn) with parallax background, title node, and four buttons
- [ ] Wave 1 Task 6: Create title/logo animation sequence (AnimationPlayer/Tween)
- [ ] Wave 1 Task 7: Style four buttons (Play, Settings, Credits, Quit) with hover/focus states and accessible text
- [ ] Wave 1 Task 8: Accessibility: High contrast preset and large typography options
- [ ] Wave 1 Task 9: Responsive layout: ensure layout adapts to 1280x720, 1920x1080
- [ ] Wave 1 Task 10: Add minimal sound cues for navigation and clicks (optional MVP)

---

## TODOs
- [ ] 1. Create design token sheet (colors, typography, elevations)
- [ ] 2. Assemble moodboard and style guide document
- [ ] 3. Build start screen scene skeleton in Godot (scene tree plan, node naming)
- [ ] 4. Create parallax background with 2-3 layers (low-poly assets)
- [ ] 5. Add animated logo reveal sequence
- [ ] 6. Implement 4 interactive buttons with states and input navigation
- [ ] 7. Implement accessibility presets (High Contrast, Large UI)
- [ ] 8. Add UI sound cues for hover/click
- [ ] 9. Test plan and automation hooks (Plan + QA docs)

---

## Final Verification Wave
- F1 Plan Compliance Audit (oracle)
- F2 UI/UX Quality Review (visual-engineering)
- F3 Automated UI QA (Playwright) or manual QA (if Playwright not set up)
- F4 Scope Fidelity Check (deep)

## Commit Strategy
- type(scope): start-screen design & polish

## Success Criteria
- MVP start screen matches the selected direction, accessible, responsive, and performant
- All 4 buttons are operable with mouse/keyboard/controller
- Visual tokens are consistently applied across the start screen
- No code changes bleed into gameplay scenes
