# Changelog

## 0.1.8

- Run owned UI signal callbacks with CoreGui identity when paired identity helpers are available, restoring the calling identity afterward.
- Fix protected-instance permission failures when clicking controls or rebinding keys from lower-identity GUI events.
- Add callback, key capture, error-path, and identity-restoration regressions.

## 0.1.7

- Add optional `AllowOffscreen` window dragging with flush corner/edge snapping and configurable `SnapDistance`.
- Add `Window:SetPosition(Vector2, snapEdges)`; offscreen placement survives resize, fitting, and visibility fades.
- Release first-person cursor ownership when the window is completely outside the viewport.
- Preserve bounded placement by default; Booga enables offscreen movement explicitly.
- Add regressions for all four corners, offscreen dragging, resize stability, and cursor release.

## 0.1.6

- Only unlock the menu cursor when the current camera is in first person; leave zoomed-out camera controls untouched.
- Release cursor ownership when zooming out, disabling/hiding the GUI, closing the menu, or unloading.
- Remove saved mouse-lock restoration so closing after a zoom change cannot reapply a stale LockCenter state.
- Remove the resize handle's modal flag, which interfered with native camera behavior.
- Add camera-transition, third-person drag, close/unload, scriptable/missing-camera, and disabled-GUI regression checks.

## 0.1.5

- Upgrade color swatches to a compact HSV popup with live mouse/touch dragging, a hue strip, hex input, and Reset.
- Close picker popups on outside clicks, Escape, disabling/hiding the control, menu hide, or unload.
- Add `Window:OnDestroy(callback)` for example and feature cleanup.
- Add `examples/ESP.lua`: basic player highlights with live color, fill transparency, through-wall visibility, and self preview.
- Cover picker interaction, invalid hex input, silent updates, player joins/leaves, respawns, and ESP cleanup in regression tests.

## 0.1.4

- Replace position-based opening and closing with 180ms / 150ms transparency fades.
- Fade native backgrounds, text, images, scrollbars, and matching border strokes without CanvasGroup rendering.
- Unlock and show the cursor while a window is open, after camera updates; restore previous behavior on close or unload.
- Always mount in CoreGui, call available GUI protection hooks, and retry permission failures with available identity helpers while restoring the original identity.
- Clean up failed mounts and report unsupported CoreGui access without silently switching to PlayerGui.

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
