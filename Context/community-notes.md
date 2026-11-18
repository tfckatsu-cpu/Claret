# Community Notes (Translated Excerpts)

These are informal community comments, not verified requirements or technical facts. See `prestudy-notes.md` and check any technical claims against source code and the target FAF version.

**Smooth Legs [DPG], [DPG] Prime — 1:42:** “Suggest ideas for new things you want overall; don't ask for things that can already be added from existing mods (those will be included anyway).”

**SkuGGnatt — 8:04:** Asked for a clear table with a short summary and a separate detailed description of each existing mod's capabilities, to understand the overall landscape and avoid duplication when users have different mod sets. Proposed listing new requests separately below the table so they can be merged later with the full picture in view.

**[DPG] Prime — 8:07–8:09:** Proposed combining not only 4z0t's mods but as many compatible mods as possible, adding controls for all of them, and including options such as a minimap toggle when zoomed out. The aim was a “gold collection” of genuinely useful features in one place, with an intuitive interface that lets users turn features on or off.

**SkuGGnatt — 8:10–8:15:** Suggested a shared interactive map (for example, Miro) to track dependencies and common mechanisms. Several mods may scan units/buildings independently and add overhead; a shared Core API for unit scans could serve smaller mods. Also noted the need to understand the ecosystem and duplicate work before optimizing it.

**[DPG] Prime — 8:11–8:14:** Said that removing mods can break dependent features and that the intended direction was an integrated DPG ecosystem.

**[DPG] Prime — 10:59:** Said they were reviewing how other mods work and wondered whether ReUI itself might be the problem; if so, a custom library could be considered, otherwise use ReUI Core.

## Preliminary Notes Mentioned in the Discussion

The initial notes were gathered from public pages (FAF wiki, forum, repository pages), without access to the user's mods or source-code inspection. They were intended to speed up Stage 1, not replace code review or in-game checks. See `prestudy-notes.md`.

**Unattributed message — 12:33:** Mentioned that another developer was also making a bottom-panel mod and that chat notes had been copied to learn what UI limitations they encountered.

**SkuGGnatt — 12:33–12:41:** Reported several suspected automation limits: orders might only append to the end of a queue; reclaim (and some other) orders might not target props, units, or buildings from the UI; enemy information might be heavily restricted beyond hover; allied unit/building information might require an executable patch; and icons might be immutable after loading. These were explicitly informal beliefs and were later marked as unverified in `tech-findings.md`. One proposed workaround for icon customization was a small companion desktop utility to produce a ready-to-use mod package.
