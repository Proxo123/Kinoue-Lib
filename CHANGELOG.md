# Changelog

## 0.5.0

- Add sub-toggles: `SubToggle = true` puts a cog on the right of a toggle that opens an animated settings panel (`toggle.Settings`).
- Replace the text arrow on disclosures with a chevron icon that rotates, and animate opening and closing.
- Draw every icon (header gear, sub-toggle cog, chevron) from one shared module; the header gear now spins when settings open.
- Add a built-in Menu key setting (RightShift by default) that cannot be cleared. `SetToggleKey` keeps it in sync, and the examples no longer need their own menu key bind.
- Add the `Clearable` keybind option and the `AddDisclosure(title, open)` and `SetOpen` disclosure API.

## 0.4.0

- Add a grey × button left of every bound key that unbinds it, plus `keybind:Unbind()`. Unbinding cancels key capture and releases a held key.
- Show `[Unbound]` instead of `[Unknown]` for empty binds. Buttons drop the key suffix while unbound.
- Allow `Keybind = true` on toggles and buttons for an empty slot, and add the `BindableToggles` window option.
- Toggle keybinds flip the toggle by default.
- Ignore mouse clicks when the menu key is unbound; before this, every click toggled the window.

## 0.3.0

- Toggles no longer show a check mark; an enabled toggle fills with the accent color.
- Replace the header's PlaceId label with a gear button that opens a built-in settings page.
- Add live themes: six presets, per-color editing, `UI:SetTheme`, `UI:GetTheme` and `UI.Themes`. Theme changes update every open window, and colors set manually on instances are kept.
- Add Lock to screen, Snap to edges, Animations and Rainbow accent line settings, plus `SetLockToScreen`, `SetReducedMotion` and `SetRainbowAccent`.
- Save settings with the window config under `UI.*` IDs.
- Add `ShowSettings` and `RainbowAccent` window options.

## 0.2.0

- Rename the bundle to `dist/Kinoue.lua` and `dist/Kinoue.rbxmx`, and the demo to `dist/KinoueDemo.lua` and `dist/KinoueDemo.rbxlx`. Update `loadstring` URLs that point at `dist/BoogaUI.lua`.
- Default window ID, title, warnings and cursor binding now use `Kinoue`.
- Split `Window` into `Chrome`, `Input`, `Page` and `Config` modules, and `Controls` into one module per control.
- Replace the game-specific demo with a generic showcase in `examples/Demo.client.luau`.
- Format all Luau with StyLua and check formatting in CI.
- Write `.rbxmx` and `.rbxlx` output with LF line endings on every platform.

## 0.1.12

- Run public control, page, and window methods with CoreGui context, so calls from feature threads (`task.defer` config restores, Heartbeat loops) no longer fail with "lacking capability Plugin".
- Load the remaining saved values when one is stale (removed dropdown option, unknown key) instead of discarding the whole config.
- Stop mouse clicks from triggering unbound keybinds (`KeyCode.Unknown`).
- Fire keybind `Released` only after a matching `Pressed`.
- End slider, window, and color picker drags on any left-button release, not only the original InputObject.
- Close an open dropdown when it is disabled or hidden; cancel key capture when a keybind is disabled.
- Keep a button keybind's `[Key]` suffix after `SetText`; button keybinds no longer require an `Id`.
- Hide only the key for inline toggle/button keybinds on `SetVisible(false)`.
- Connect global input listeners for sliders and window drag/resize only while dragging.
- Cache text measurements and skip redundant per-frame cursor writes.

## 0.1.11

- Hide and remove the window before feature cleanup, preserving control values until settings saves finish.
- Restore CoreGui context for direct teardown and isolate cleanup steps so a stale tween, popup, or callback cannot stop window removal.
- Continue disconnecting/cancelling other resources after individual cleanup failures.
- Ignore late status updates after destruction.
- Add optional `ReplaceExisting` for removing orphaned ScreenGuis with the same ID.
- Cover unload-button interaction, direct low-identity teardown, injected cleanup failures, recursion, context restoration, and orphan replacement.

## 0.1.10

- Fix fade opacity drift caused by comparing double calculations with Roblox's float32 transparency values.
- Use opaque muted text for disabled buttons so unavailable actions stay readable.
- Add float32 regressions spanning twenty complete fade cycles.

## 0.1.9

- Skip rendering and tween creation for unchanged control values; changed values still animate.
- Keep dropdown quantity metadata current when options change without changing the selection.
- Reuse preview pixel instances and skip identical geometry/count updates.
- Disconnect the rainbow accent animation while hidden; reduced-motion windows use a static accent.
- Exclude fully transparent containers/properties from fade rendering while preserving live opacity changes.
- Add performance regressions for idle synchronization, preview allocation, metadata refresh, and repeated reopen cleanup.

## 0.1.8

- Run owned UI signal callbacks with CoreGui identity when paired identity helpers are available, restoring the calling identity afterward.
- Fix protected-instance permission failures when clicking controls or rebinding keys from lower-identity GUI events.
- Add callback, key capture, error-path, and identity-restoration regressions.

## 0.1.7

- Add optional `AllowOffscreen` window dragging with flush corner/edge snapping and configurable `SnapDistance`.
- Add `Window:SetPosition(Vector2, snapEdges)`; offscreen placement survives resize, fitting, and visibility fades.
- Release first-person cursor ownership when the window is completely outside the viewport.
- Preserve bounded placement by default.
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
