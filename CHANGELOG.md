# Changelog

## 0.10.2

- Draw generated UI outlines inside their frames so scroll containers no longer clip section borders along the left and top edges. Keep border colors and visibility fades in sync.

## 0.10.1

- Integrate the 0.10.0 quieter look with the compact key dialog, Session license countdown, and authenticated execution reporting from 0.9.2/0.9.3.
- Preserve remembered sessions, logout/re-login, and per-key admin execution history during migration.

## 0.10.0

New look, based on the quieter Elevated design:

- Calmer palette: graphite surfaces, a softer default blue, and the accent color used only for things that are on.
- Tabs sit in a pill bar in the header. A single highlight slides and resizes to the selected tab, and the new page eases into place.
- Groupboxes are cards with a plain title and a thin divider under it, with no lines between rows.
- Smaller switches with white knobs, a soft row hover, outlined keycaps, plain slider values and softer buttons.
- Pages no longer show a title row unless `SetTitle` or `SetMode` is used.
- The rainbow line under the header is now off by default; turn it on with `RainbowAccent = true` or in settings.
- The footer is plain text: status on the left, version on the right.

## 0.9.3

- Add a License section to authenticated scripts' Session tab with the key's remaining time. Use license expiry and the server clock, handle keys without expiry, and release the countdown on unload.
- Report successful script starts with the Roblox player ID, username, display name, place, and library version. Authenticate reports against the key's device-bound session and make retries idempotent.
- Add private, paginated execution history to each key in the admin dashboard, with player profile links and server-recorded timestamps. Preserve history through key resets and revocation; deleting the key removes its history.

## 0.9.2

- Replace the full key window with a compact dialog containing a key input, Redeem, and Close. Remove tabs, search, settings, group headers, the footer, and the Remember toggle from authentication.
- Keep remembered sessions automatic by default, with `Remember = false` to disable caching. Show verification progress and errors only when needed.
- Keep Close available during verification, cancel pending work when closed, and reopen the compact dialog after logout.

## 0.9.1

- Fix the sub-toggle cog: clicks went to the toggle row underneath, flipping the toggle instead of opening its settings. Keycaps and the clear button also sit above the row now.
- Put the tabs in the header row next to the title, as in the Refined design. When they do not fit, they move to their own row under the header.
- Switch labels to Builder Sans, which renders sharper in Roblox, and raise text sizes by one step.

## 0.9.0

New look, based on the "Refined" design:

- Rounded window, cards, fields and buttons, with a flat header and footer separated by thin dividers.
- Gotham for labels, bold uppercase group headers, and monospace only for values and keys.
- Tabs sit in a pill-shaped strip; the active tab is filled and marked with a small accent bar. Sub-tabs use the same pills.
- Toggles are sliding switches. Rows highlight on hover.
- Keybinds are keycaps. Unbound keys are a faint `Unbound` keycap, capture shows an accent outline, and conflicts turn the keycap red.
- Sliders have a thin track, a round knob and a value chip.
- Dropdowns, textboxes and the search field get rounded fields with an accent focus outline. Dropdown menus are rounded, highlight on hover and mark the selection with a check.
- Primary buttons are filled with the accent color; other buttons are soft and lighten on hover. Button labels no longer repeat the key, which is shown as a keycap instead.
- The search field is always visible in the header.
- Notifications are rounded cards with a status badge, a bold message, a grey source line and a slim timer.
- The footer shows a status dot, and `Subtitle` (or `Footer`) appears next to the window name.
- Theme presets now include a `Success` color and were retuned for the new surfaces.
## 0.8.1

- Remove the Forget button from the key page and add Logout to authenticated windows' built-in settings.
- Unload the protected script, clear its remembered login, revoke the current server session, and reopen the key page on logout. Preserve UI settings and allow signing in again without rerunning the loader.
- Add `KeySystem:Logout`, `KeySystem:AttachWindow`, `Window:SetLogoutHandler`, and optional `OnUnload(result)` cleanup for reusable integrations.

## 0.8.0

- Add `CreateKeySystem`: a reusable key UI, HWID capability checks, remembered sessions, and authenticated script loading. Unsupported executors fail closed without substituting another identifier.
- Add a self-hosted backend with per-application keys, atomic first-device binding, expiring/rotating sessions, authenticated payload downloads, revocation/device reset commands, and API tests.
- Cache session tokens instead of raw keys or HWIDs; revalidate on every launch and require HTTPS for public services.
- Add a Vercel-ready admin dashboard, durable Postgres payload/license storage, scrypt admin login with CSRF protection, and key creation, renewal, revocation, deletion, and encrypted HWID view/reset/replacement. Invalidate remembered sessions when access changes and run backend tests against both database engines.

## 0.7.0

- Add local PNG, JPEG, and animated GIF window backgrounds through executor file and asset functions.
- Add Background settings with file loading, image and panel opacity, fit, playback speed, and config persistence.
- Decode GIF transparency, palettes, interlacing, timing, and disposal into cached PNG sprite sheets. Bound decoding work and memory, yield during preparation, and pause playback while hidden or animations are disabled.
- Add `SetBackground`, `ClearBackground`, and `GetBackgroundStatus`; retain the current background when a replacement fails.

## 0.6.0

- Add notifications: `window:Notify(text or options)` and a `Notify` option on every control and button. Cards slide in at the bottom right with a close button and a timer bar, stay visible while the menu is hidden, and can be turned off in settings.
- Add header search: a magnifier next to the gear finds tabs, sub-tabs, groupboxes, sections and controls, then jumps to the result, opening whatever it is inside.
- Show keybind conflicts: shared keys turn red, show a warning icon, and list the other binds on hover.
- Stop crashing on duplicate IDs. Same-text button and toggle keybinds get unique IDs, and explicit duplicates are renamed with a warning.
- Shut an old window down completely when `ReplaceExisting` (or anything else) destroys its ScreenGui. Its keybinds, auto-save and notifications no longer linger after a script re-run.
- Show the library version in small grey text at the bottom right of the footer.
- Add a `Danger` theme color.

## 0.5.1

- Keybinds now fire while the menu is hidden. Keys the game already handled, such as chat, and typing in a textbox are still ignored.

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
