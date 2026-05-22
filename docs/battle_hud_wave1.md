# Battle HUD Wave 1 Notes

Wave 1 focuses on establishing a maintainable, neon-styled battle HUD baseline:

- Shared design tokens in `resources/design_tokens.gd`
- Health / Energy bars with smooth animation
- Phase instrument panel + unit info panel styling
- Combat feedback via floating text
- Simple parallax background

## Design Tokens

File: `resources/design_tokens.gd`

- Color palette: background, panel, text, accent cyan/purple, health, energy, danger
- Typography: base sizes (small/medium/large/title/huge)
- Spacing: padding, border, corner radius
- Glow flags and strength
- Accessibility:
  - `HIGH_CONTRAST_ENABLED`
  - `LARGE_TYPE_ENABLED`
  - Helper functions:
    - `get_accent_color(accent_type, high_contrast := HIGH_CONTRAST_ENABLED)`
    - `get_bg_color(high_contrast := HIGH_CONTRAST_ENABLED)`
    - `get_panel_color(high_contrast := HIGH_CONTRAST_ENABLED)`
    - `get_text_color(high_contrast := HIGH_CONTRAST_ENABLED)`
    - `get_font_size(base_size, large_type := LARGE_TYPE_ENABLED)`

## Health / Energy Bars

- `scenes/ui/health_bar.tscn` / `.gd`
  - Public API: `set_values(current: float, maximum: float, animate := true)`
  - Uses `DesignTokens` for colors and font sizes
  - Short tween for smooth value changes
- `scenes/ui/energy_bar.tscn` / `.gd`
  - Listens to `SignalBus.energy_changed(current, max)`
  - Neon energy color and tweened progress bar

## Phase Instrument Panel

- `scenes/ui/phase_instrument_panel.tscn` / `.gd`
  - Spawns 4 `phase_slot.tscn` children
  - Listens to `SignalBus.phase_slots_changed`
  - Uses `DesignTokens` spacing for layout

## Unit Info Panel

- `scenes/ui/unit_info_panel.tscn` / `.gd`
  - Subscribes to `SignalBus.unit_selected`
  - Shows stats for player / enemy units
  - Uses `DesignTokens` for panel/background, typography and colors

## Combat Floating Text

- `scenes/ui/components/floating_text.tscn` / `.gd`
  - Label-based popup with `show_text(value: String, color: Color, start_position: Vector2)`
  - Simple rise + fade tween, then `queue_free`
- `scenes/ui/battle_hud.gd`
  - Uses `FloatingText` for `show_damage_popup(damage, position)`

## Battle Parallax Background

- `scenes/ui/background/battle_parallax.tscn` / `.gd`
  - Three Parallax layers:
    - Far: dark background using `get_bg_color`
    - Mid: purple haze
    - Near: cyan scan band
  - Designed to sit behind the battlefield nodes

