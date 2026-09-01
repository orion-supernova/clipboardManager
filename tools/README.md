# tools

## make-icon.swift

The app icon is drawn in code, not exported from a design file, so it can be
re-tuned by changing numbers instead of reopening a canvas.

```sh
swift tools/make-icon.swift <out-dir>          # the full three-card stack
swift tools/make-icon.swift <out-dir> simple   # one card, for the small slots
```

Then scale into `Assets.xcassets/AppIcon.appiconset`:

```sh
for s in 512 256 128 64; do
  ffmpeg -y -i <out-dir>/icon-1024.png -vf "scale=${s}:${s}:flags=lanczos" g${s}.png
done
for s in 32 16; do
  ffmpeg -y -i <out-dir>/icon-simple-1024.png -vf "scale=${s}:${s}:flags=lanczos" s${s}.png
done
```

`16.png`, `32.png` and `32 1.png` come from the simple variant; `64.png` and up
come from the full one. Three overlapping cards at 16pt is just grey mush, so
the small slots drop the back cards and the second text line.

The body is a superellipse (`n = 5.4`) rather than a circular rounded rect —
that corner continuity is most of what separates a macOS icon from a rounded
square. It sits on Apple's grid: an 848pt body inside a 1024pt canvas.
