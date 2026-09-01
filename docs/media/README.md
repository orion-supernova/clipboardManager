# How the README media was made

All of it is a real capture of a real build — not a mockup and not the offline
renderer. macOS 26.5.2, a 3360×2100 Retina display, real Liquid Glass sampling
the real desktop picture. That matters: `PanelGlass` falls back to a flat
frosted stand-in whenever `marketingRender` is set, because `ImageRenderer`
can't sample a backdrop, and the difference is obvious next to the real thing.

## The setup

The App Store build was quit first so it couldn't record the sample copies into
the real history. The capture build is an unsigned `xcodebuild` Debug product,
which means no sandbox, which means its Core Data store lands in
`~/Library/Application Support/Mahmut Clipboard/` instead of the container —
a completely separate history that was deleted afterwards.

The seven items were genuinely copied, each from the app whose badge it shows.
`NSRunningApplication.activate()` brings the app forward, then the copy happens,
so the source badges are recorded by the app the normal way rather than written
into the database. The link card's title, favicon and hero image were fetched
live from developer.apple.com.

Two things were adjusted in SQLite afterwards, both cosmetic:

- **Timestamps** were backdated to 1 / 3 / 4 / 6 / 10 / 15 / 22 minutes, because
  seven items all reading "34 sec. ago" looks like what it is.
- **One row was deleted and re-copied.** A notification stole focus during the
  colour copy and the card recorded `UserNotificationCenter` as its source. It
  was re-copied from Chrome rather than edited in the database.

The card number is `4242 4242 4242 4242` — Stripe's public test Visa. It is
Luhn-valid, which is the point: the detector has to actually pass it to mask it.

The wallpaper is the machine's own (`~/Documents/lucy-wallpaper.png`). Every
scene was shot with all other apps hidden, so the Dock and menu bar in frame are
the real ones.

## Sources and timestamps

| File | Source | Trim | Crop (from 3360×2100) |
|---|---|---|---|
| `hero.jpg` | `hero-full` still | — | `3360×1720 +0+380` |
| `masked.jpg` | `quicklook-masked` still | — | `3300×1430 +30+515` |
| `paste-as.jpg` | `paste-as` still | — | `3300×770 +30+1175` |
| `panel.gif` | `nav.mov` (9.78 s) | 1.35 → 9.20 s | `3300×770 +30+1175` |
| `search.gif` | `search.mov` (8.98 s) | 1.30 → 8.60 s | `3300×770 +30+1175` |
| `quick-look.gif` | `quicklook.mov` (10.0 s) | 1.20 → 8.80 s | `3300×1430 +30+515` |

The stills are JPEG at `-q:v 2`, not PNG. A 1:1 crop of the code card — the
worst case, small monospaced text on a translucent panel — is indistinguishable
from the PNG, and the file is a sixth of the size (320 KB against 1.9 MB).

The same captures, scaled to 2880×1800 for App Store Connect, live in the
marketing folder alongside the copy deck. That set has two scenes this one
doesn't — the Save-to-Folder chooser and a populated folder scope — and it
carries the caption block (icon, wordmark, headline, subtitle) burned in, drawn
by `tools/caption.swift` with the same typography `MarketingScenes` used. The
bare versions stay in `assets/uncaptioned/` so the copy can change without
re-shooting anything.

The README images stay uncaptioned on purpose. A store listing is a shop window
and needs the pitch on the glass; a repo readme is standing next to the thing
itself, and a headline pasted over a screenshot only gets in the way.

The crop numbers come from `PanelMetrics`: the panel is `maxWidth`-clamped to
the visible frame minus `horizontalScreenInset` on each side, sits
`bottomScreenInset` above the Dock, and is `height` tall — or `expandedHeight`
once a preview sheet is open, which is the taller crop.

## Cutting the GIFs

Two-pass palette, one shared palette per clip, or the glass gradients band into
mush:

```bash
ffmpeg -y -i nav.mov -filter_complex \
  "[0:v]trim=1.35:9.20,setpts=PTS-STARTPTS[t];\
   [t]crop=3300:770:30:1175,fps=12,scale=1100:-1:flags=lanczos[c];\
   [c]split[s0][s1];[s0]palettegen=max_colors=128:stats_mode=diff[p];\
   [s1][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" panel.gif
```

12 fps and 128 colours were chosen after 14 fps / 256 came out at 1.8–2.4 MB.
The UI is dark and mostly flat, so the smaller palette costs nothing visible and
roughly halves the file.

## What was cut, and what wasn't

**Nothing was cut to hide anything.** A luma sweep over the panel band of all
three clips came back flat — `min 55.9, max 69.0` across 579 frames, with no
sustained drop — so no permission dialog, sheet or modal ever dimmed the screen
during a take:

```bash
ffmpeg -i nav.mov -vf "crop=3300:770:30:1175,fps=20,signalstats,\
metadata=print:key=lavfi.signalstats.YAVG:file=-" -f null -
```

The only deliberate omissions are the leading and trailing seconds of each clip,
which are the recorder starting and stopping.

Two takes were thrown away and re-shot rather than salvaged:

- A first Quick Look take where ⌘⇧V *closed* the panel instead of opening it —
  the hotkey toggles, and the panel was already up from the previous clip.
- A first pass of the whole set where the file card showed a scratchpad path
  (`/private/tmp/claude-501/…`) instead of `~/Documents`, and every card said
  `Supacode` because that was the frontmost app when the copies happened.

## One thing to know before you drive it with a script

`⌘[` and `⌘]` cannot be sent from System Events on this machine, and it is not a
scripting problem. `PanelController.handle(_:)` matches those two shortcuts by
comparing `charactersIgnoringModifiers` against the literal `"["` and `"]"`,
which is layout-dependent — on the Turkish layout this Mac runs, that key
produces `ğ`, so the `case` never fires and scope switching silently does
nothing. Every other shortcut in the panel is a digit or a Latin letter, so this
is the only pair affected. The folder-scope screenshots were staged by restarting
the app (it opens in History) and filing items with `⌘S`, not by cycling scopes.

## Re-recording it

`MAHMUT_SHOW_PANEL=1` opens the panel a second after launch, which avoids the
toggle problem entirely. The old offline path still exists —
`MAHMUT_RENDER_MARKETING=1` renders the same scenes to `tmp/marketing` with
`MarketingScenes`' own sample data — and is the right tool when you need
deterministic frames, App Store screenshot dimensions, or a machine without a
display. It just doesn't look like a shipped app, because it can't.
