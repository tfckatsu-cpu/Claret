# Visual style and theme tokens

> **Answers:** exact colours, sizes, type scale, component states, panel surface, assets. **Read when:** choosing a colour/size/state, matching the shell, adding a switch or button, checking contrast. **Next:** `ui-code.md` for implementation; `menu.md` for shell geometry.

Single source of values: `mods/ClaretCore/modules/Theme.lua`. Code values beat any example here. No module may define its own palette.

## Principles

- Flat, dark interface. No gradients, glow, bevels or decorative borders. Hierarchy comes from size, alignment, spacing and one accent.
- Semantic colours only. `accent` marks selection and the single primary action — not every button.
- Every colour value is ARGB `'aarrggbb'` (Maui `SetSolidColor`/`SetColor` format), lowercase hex.
- State is never communicated by colour alone: pair with text, glyph or position.
- Everything sits on a 4 px grid; spacing steps 8 / 12 / 16, 20–24 between sections.

## Colours

Source: `Theme.Colors`.

| Token | Value | Use |
|---|---|---|
| `canvas` | `ff080c0a` | window background |
| `surface` | `ff141416` | panels, cards |
| `raised` | `ff1b1b20` | raised rows, fields |
| `hover` | `ff27232a` | hover fill |
| `pressed` | `ff3b3039` | pressed fill |
| `scrim` | `78000000` | dialog scrim (48% black) |
| `transparent` | `00000000` | invisible control fills |
| `border` | `ff343638` | dividers, outlines |
| `text` | `ffe8e8e6` | primary text |
| `muted` | `ff929394` | secondary text, captions, hints |
| `accent` | `ff7a1f30` | burgundy: selection, primary action |
| `accentHover` | `ff962a43` | accent hover |
| `accentPressed` | `ff57131f` | accent pressed |
| `selected` | `ff32171f` | selected row surface |
| `selectedBorder` | `ff743043` | selected row outline |
| `accentText` | `ffe5a1b0` | text/glyph on accent |
| `danger` | `fff06b7a` | destructive action, errors |
| `success` | `ff99bd69` | success |
| `health` | `ff28b84a` | healthy ACU |
| `warning` | `fff0b64d` | warnings (always with text) |
| `warningSurface` / `warningBorder` | `ff342817` / `ff80602e` | warning block |
| `lock` / `lockSurface` / `lockBorder` | `ffb6b1bc` / `ff1b1b20` / `ff55515b` | position-lock affordance |
| `disabled` | `ff605d65` | disabled control **fill** |
| `disabledText` | `ff8a8792` | disabled **text** (readable contrast) |

HUD value tokens (Selection Info uses these; headings stay `muted`):

| Token | Value | Meaning |
|---|---|---|
| `hudValue` | `ffffffff` | neutral number |
| `hudMass` | `ffcdff65` | mass |
| `hudEnergy` | `ffffd426` | energy |
| `hudHealth` | `ff35ef70` | HP |
| `hudShield` | `ff55d6ff` | shield |
| `hudDamage` | `ffff676d` | damage / DPS |

Key-combination colours (modifier ordinal 0–7): `keyCombo0` `ff7f8794` (none), `keyCombo1` `ff64b5f6` (Ctrl), `keyCombo2` `ffc792ea` (Shift), `keyCombo3` `ff4db6ac` (Ctrl+Shift), `keyCombo4` `ffffba66` (Alt), `keyCombo5` `ffff7785` (Ctrl+Alt), `keyCombo6` `ff9ccc65` (Shift+Alt), `keyCombo7` `ff7986cb` (Ctrl+Shift+Alt).

Fonts: `Theme.Fonts.body` = `Nunito`, `Theme.Fonts.heading` = `Nunito SemiBold`. TTFs ship in `ClaretCore/fonts/Nunito` (SIL OFL 1.1) and are copied into the game's `fonts` folder by `fonts/Install-Nunito.cmd`. A missing font silently falls back — check `DiskGetFileInfo` if a layout depends on metrics.

## Metrics

Logical units before the shared `FloorLayouter` scale.

| Key | Value | Meaning |
|---|---|---|
| `launcherWidth` | 248 | launcher panel width |
| `launcherHeight` | 400 | launcher max height |
| `panelWidth` / `panelHeight` | 1128 / 1110 | standard settings panel (the only 2 px exception on the grid) |
| `corePanelWidth` / `corePanelHeight` | 552 / 408 | compact Core section |
| `coreCardWidth` | 520 | compact card width |
| `coreRowHeight` / `coreRowStep` | 56 / 64 | compact row and step |
| `coreControlHeight` | 56 | compact control host |
| `panelGap` | 16 | gap between launcher and panel |
| `padding` | 24 | panel padding |
| `rowHeight` | 40 | navigation / setting row |
| `buttonHeight` | 36 | standard button |
| `fieldHeight` | 36 | input field |
| `panelRadius` | 8 | rounded panel radius |
| `title` | 22 | panel header |
| `heading` | 18 | section heading |
| `launcherText` | 18 | launcher rows |
| `text` | 16 | body |
| `buttonText` | 15 | button labels, selector values |
| `secondaryText` | 14 | list row names, dependency lines |
| `label` | 13 | field captions, arrows |
| `caption` | 12 | status line, hints |
| `glyph` | 20 | symbol buttons (gear, close) |

Other fixed values: panel drag header `width-72` × 72; name field 656×36; picker search 300×36; embedded Hotbuild navigator up to 1080×984, pages up to 1080×920; list rows 34 high with a 4 px gap (38 step).

New elements: body 15–16, explanations 13–14, headings 18–22, controls 32–36, keycaps 28–32. Do not shrink text to gain density.

## Panel surface

`Theme.RoundedPanel(control, layout, width, height, fill, border, shadow)` turns a solid control into a rounded surface:

- keeps the control's size and hit area, sets its own fill transparent;
- draws two fills, four corner masks, a 1 px ring and an optional 16 px shadow (`PANEL_BLUR`);
- masks are PNGs in `ClaretCore/textures/ui/` with baked canvas/border colours — changing `panelRadius` or those colours requires regenerating them;
- the shadow lies **outside** the panel bounds: never clip the panel;
- returns `Resize(width, height)`; call it on every size change.

`Theme.Outline(control, layout, width, height, color)` draws four flat 1 px strips and returns `(paint(color), resize(w, h))` — used for switches and selected rows.

Hotbuild editor windows still draw flat panels; they are the next candidate for `RoundedPanel`.

## Components

- **Buttons** — neutral secondary by default, one accent primary action per view. Four states: normal, hover, pressed (`pressed` colour), disabled (`disabled` fill + `disabledText` label). Buttons return to hover after `ButtonRelease`, not after the click callback, so a callback that closes a dialog cannot leave a stuck pressed colour.
- **Binary settings** — always `Theme.SettingsSwitch(row, layout, rowWidth, rowHeight, textScale, compact)`; compact variant in compact cards. Size 56×32 (compact 48×28), thumb 20×24 (compact 18×20), state glyph `●`/`○` at `rowWidth-16-width-32`. The host row owns input and persistence; the whole row is clickable. Change the switch style only inside `Theme.SettingsSwitch`.
- **Fields and lists** — label above or left, visible focus, error text below. Native Combo keeps FAF behaviour. Sliders show value and a usable drag target.
- **Key combinations** — separate readable keycaps, explicit change/clear actions, capture mode visually distinct, Escape cancels, conflicts explained in text. Colour by modifier ordinal (`keyCombo*`).
- **Selected row** — dark burgundy `selected` fill plus a narrow accent bar; hover slightly brighter (`hover`).
- **Navigation rows** — 40 high, centered text (`launcherText` 18), rounded outline, selected/hover colours matching Core launcher rows. Mark selection without colour alone.
- **Tabs** — stable size and position; keep internal tabs in place when content changes; disabled and focus states where applicable.
- **Scrollbars** — visible only when content overflows, wheel and pointer support. Tooltips must not permanently cover important actions.
- **Overflow** — virtualize or scroll long collections inside a bounded area; the header and navigation never scroll away. Mixed sections virtualize simple rows and keep an embedded editor created while hidden so its draft survives.

## Layout grammar

- Simple settings: label left, control right, explanation below. Avoid nested cards; group complex settings under a heading instead.
- Cards: 520×56 with 16 px padding; language segments 48×28.
- Master-detail columns: 224 navigation + 16 gap + 384 detail; each column ends below its content; clicking the selected group again collapses the detail column.
- Do not: heavy border around every setting, red disabled buttons, tiny text, content-sized windows, colour as the only saved-state indicator.

## Assets

- Runtime textures are DDS (`.dds`); masks that carry colour are PNG, baked at build time.
- Maui has no documented texture tinting. `SetSolidColor` on a textured Bitmap replaces the image with a flat rectangle — bake the colour into the texture instead.
- Faction icons: 32 and 48 px raster sets in `textures/factions/`; `Theme.FactionIcon(faction, preferredSize)` returns the nearest size and the path.
- Branding: `textures/branding/claret-mark.dds`, `claret-wordmark.dds`.
- Panel corner/ring/shadow masks in `textures/ui/` are pixel-exact for `panelRadius = 8`; changing the radius or the baked colours requires regenerating them.
- Decorative bitmaps always `DisableHitTest()`.

## Do not

- Hardcode point sizes or state colours at call sites — use tokens.
- Use `disabled` for text or `disabledText` for fills.
- Mix `Colors.accent` with local reds/maroons; the accent family is `accent`, `accentHover`, `accentPressed`, `selected`, `selectedBorder`, `accentText`.
- Use bright saturated colours for icons and markers unless the feature is a map marker with a faction colour (Reveal Positions uses flat faction colours, no brightness boost, transparent internal lines).
