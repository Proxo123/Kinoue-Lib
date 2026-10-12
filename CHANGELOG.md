# Changelog

## 0.1.3

- Increase primary text from 12px to 14px and secondary counts/key hints from 11px to 12px.
- Tighten control gaps, section spacing, and the space between field labels and inputs.
- Measure tab and button widths using their actual font size; update action widths when labels change.
- Keep material counts smaller and grey, positioned after the larger material name.

## 0.1.2

- Keep the root frame anchored at the top-left instead of compensating for a center anchor during resize.
- Read logical position and size during corner capture so stale rendered coordinates cannot introduce drift.
- Preserve the current position when an opening animation is interrupted by a resize.
- Reuse preview grid dots instead of destroying/recreating the whole grid on each resize frame.
- Add regressions for repeated pointer moves, repeated grabs, stale rendered positions, and interrupted animations.

## 0.1.1

- Use native Frame rendering instead of a CanvasGroup texture for clearer text at lower graphics quality.
- Remove window font scaling; opening/closing uses a short slide animation.
- Align settled window position and column widths to whole pixels.
- Add an invisible 18 × 18 pixel bottom-right resize handle for mouse and touch.
- Add `MinSize`, `Resizable`, and `Window:SetSize(Vector2)`.
- Keep the top-left fixed during resize and constrain sizes to the screen.
- Update the example to use the new release.

## 0.1.0

- Initial reusable library, complete UI demo, modular source, importable Roblox assets, persistence adapter, build tools, and CI.
