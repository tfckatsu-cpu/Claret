# Claret Visual Style

Required reference for Claret windows. Implementation patterns (scale, depth, lifecycle, dialogs) are in `ui-rules.md`. The shared source of colors and shell dimensions is `../mods/ClaretCore/modules/Theme.lua`; code values take precedence over examples. Reference: [claret-ui-reference.png](claret-ui-reference.png). Decisions made on 2026-11-11 replace the earlier single-window geometry; verified against Core 0.10.16 / Hotbuild 0.10.41 on 2026-11-19.

## Principles and architecture

Claret Core owns the shared menu and theme. Claret UI registers its overlay settings as a section in that menu. Elements must account for adjacent panels and avoid capturing input unnecessarily.

Use a flat dark interface without gradients, glow, or decorative borders. Hierarchy, alignment, and spacing carry meaning. Semantic colors: `canvas` #080C0A background, `surface` #141416 surface, `border` #343638 divider, `accent` #7A1F30 accent, `text` #E8E8E6 primary text, `muted` #929394 secondary text, `warning` #F0B64D warning. The `health` token (#28B84A) is used for high ACU health; other states and the eight key-combination colors are in Theme. Do not create a separate module palette.

Shell buttons and navigation rows have a subtle 2 px corner radius. When opening and fully closing, the panel group shifts briefly over 160 ms; the launcher fades in, and the group fades out on full close. Opening the right-hand panel and Hotbuild windows uses a short shift that does not change the opacity of nested controls. Stop frame updates when the transition ends. The radius does not yet apply to controls inside Hotbuild editors.

The menu consists of a compact standalone launcher and a settings panel to its right. The Hotbuild keyboard fits its controls vertically, and Claret UI fits both dimensions. On first open, show the launcher; selecting a section opens settings. Reopening the menu in the same match restores the open section or launcher. The settings close button returns to the launcher; the launcher close button closes everything. Before closing or switching sections, check `CanLeave` and preserve the editor if the user cancels. Support Escape and temporary key capture; panels do not capture the keyboard or intercept game commands. Panels can be dragged independently by their headers and retain their positions within the current match when reopened.

## Dimensions, text, and scale

`Theme.Metrics` defines logical dimensions before scaling: launcher width 248 and height up to 400 (depending on visible modules), standard settings 1128×1110, compact Core section 552×408, gap 16, field 24, body text 16, standard button 36, navigation row 40. Module labels in the launcher are 18 logical units and centered in their rows. Core settings cards are 520×56 with 16 px padding; language segments are 48×28. Claret UI uses compact columns with content-driven height. The embedded Hotbuild navigator is up to 1080×984; pages are up to 1080×920 and use the shell's scale. Per user decision, the keyboard page reduces panel height when the NumPad is collapsed and expands it when open. For new elements, use body text 15–16, explanations 13–14, headings 18–22, controls 32–36, and keycaps 28–32; do not shrink them to increase density.

Use `Theme.Fonts.body` (Nunito), `Theme.Fonts.heading` (Nunito SemiBold), and `FloorLayouter(scale)`; pass text `scale / GetPixelScaleFactor()`, as in Menu. Limit the overall group scale to available width and height and UI scale; do not multiply by UI scale twice. On small screens, scale the entire group down: check readability at different resolutions and UI scale in FAF. Do not store coordinates in another coordinate system without an explicit conversion.

## Navigation and content

The Claret UI feature navigation matches the Core launcher rows (confirmed by the user in game on 2026-11-20 for Claret UI 0.2.32): centered text, the same 40 px height, rounded outline, and selected and hover colors. Its binary setting cards match the compact Core cards and use the shared switch. Vertical module rows have consistent heights; mark the selected section with a dark burgundy surface and a narrow bar, and slightly brighten the background on hover. Use the accent for selection and the primary action, not every button. Keep internal tabs in place when content changes. Arrange simple settings in rows: label on the left, control on the right, explanation below; group complex settings without nested cards. Use a 4 px grid, spacing of 8/12/16, and 20–24 between sections. Safely truncate long UTF-8 labels and show the full text in a tooltip.

## Components and states

- Buttons: neutral secondary buttons and one accent primary action; default, hover, pressed, focus, and disabled states. Label deletion actions clearly.
- Binary settings across Claret use `Theme.SettingsSwitch` from Claret Core, including settings rendered by inline sections. Use the compact variant in compact cards. The shared component places the outlined switch on the right and combines thumb position, color, and a filled or hollow dot to show its state. Keep the full settings row clickable. Make future switch style changes in `Theme.SettingsSwitch` so every section updates together.
- Fields and lists: label, visible focus, and error text; native Combo controls retain FAF behavior. Sliders show their value and provide a usable drag target.
- Key combinations: separate readable keycaps, explicit change and clear actions; capture mode looks distinct, Escape cancels it, and conflicts are explained in text.
- Headings and descriptions: size and contrast reflect hierarchy. Pair the `warning` color with text; do not rely on color alone.
- Scrollbars: visible when content overflows, support wheel and pointer input. Tooltips must not permanently cover important actions.
- Tabs: keep size and position stable; the selected state must be recognizable without color alone. Provide disabled and focus states for all interactive elements where applicable.

## Overflow and future modules

Virtualize or scroll long collections inside a bounded area without covering the header or navigation. Simple registered Core rows are virtualized as a whole; Hotbuild lists implement their own scrolling. With mixed content, show the embedded editor in full when scrolled into view and keep it created while hidden so its draft survives. An embedded editor must fit the provided area or implement its own viewport and hit-testing in FAF. Do not rely on clipping child Maui controls without checking. Register with `RegisterSettingsSection`; an embedded editor receives `layout.scale` and implements `CanLeave` when it has a draft.

Recommended: one clear row with enough spacing, a neutral button, and a visible state label. Avoid a heavy border around every setting, red disabled buttons, tiny text, content-sized windows, or using color alone to indicate saved state. Check empty and long lists, keyboard input, drafts, scale, and real clicks in a new match: local mock tests do not confirm rendering.

## Type scale and states (2026-11-19, Core 0.10.15 / Hotbuild 0.10.41)

Sizes are tokens in Theme.Metrics, not point sizes at call sites: 	itle 22 (panel header), heading 18, launcherText 18 (launcher rows), 	ext 16 (body), uttonText 15 (button labels, selector value), secondaryText 14 (list row names, dependency lines), label 13 (field captions, arrows), caption 12 (status line, hints), glyph 20 (symbol buttons such as gear/close). Editors default their text helper to secondaryText; pass a token when a different size is meant.

Disabled text uses Theme.Colors.disabledText (readable contrast), while Theme.Colors.disabled stays a fill for disabled controls — do not use one for the other.

Every interactive control needs four visual states: normal, hover, pressed (Theme.Colors.pressed) and disabled. Buttons return to hover after ButtonRelease, not after the click callback, so a callback that closes a dialog cannot leave a stuck pressed colour. The shell already had hover/pressed/focus/disabled; the Hotbuild editor buttons gained pressed feedback in this build.

The shell sits on the 4 px grid (padding 24, gap 16, rows 40/36/56/64); panelHeight 1110 is the only 2 px exception and is kept for compatibility. List rows stay 34 px high with a 4 px gap (38 px step) because the list background and tests depend on that height.
### Panel surface (2026-11-19, Core 0.10.16)

Shell panels are not flat rectangles any more: Theme.RoundedPanel keeps the control's size and hit area but draws the surface itself — two fills, four corner masks (radius Metrics.panelRadius, currently 8), a 1 px border ring and an optional soft shadow. Masks are PNGs in ClaretCore/textures/ui/ (panel-corner-*, panel-ring-*, panel-shadow-*); they are pixel-exact for the current radius, so changing panelRadius means regenerating them.

The shadow is a 16 px halo built from four stretched strips plus four corner patches, drawn below the fills, so it must stay outside the panel bounds — do not clip the panel control. RoundedPanel returns Resize(width, height); call it wherever a panel changes size (the settings panel does this in SetPanelSize). The launcher and settings panel both use it; Hotbuild editor windows still draw flat panels and are the next candidate.
