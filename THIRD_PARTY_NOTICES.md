# Third-party notices

Macifier is MIT ([LICENSE](LICENSE)). It also carries code written by other
people, under their own terms. This file is where those terms live. It is not
a formality: MIT permits the reuse below precisely *because* the notice travels
with the code, so this file has to stay accurate and has to ship.

---

## macOS Magnify Dock — the dock magnification wave

**What we use:** `scaleFromDistance` and `computeMagnifiedOffsets`, copied
unmodified into [`plugin-dock/Magnification.js`](plugin-dock/Magnification.js).
Together they are the magnification wave: the raised-cosine bell that decides
how much each icon grows with the pointer's distance, and the offset
distribution that keeps the wave centred and stops neighbours colliding.

We did not take the rest of the dock. Macifier's dock already had its own
tiles, context menu, barred placeholders and system trash; what it lacked was
this wave.

**Author:** Wisang Drillian Geni (wdg)
**Project:** macOS Magnify Dock (`wdg.dock`)
**Source:** https://github.com/wisangdg/omarchy-magnify-dock
**Commit taken from:** `fc2ee90ce414eafcbff2f388f0782988dbd860f6`
**Licence:** MIT

```
MIT License

Copyright (c) 2026 Wisang Drillian Geni (wdg)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Interoperated with, but not carried

Nothing in this section is bundled, copied or redistributed, so nothing here
carries a licence obligation for us. It is listed because "Macifier drives it"
and "Macifier contains it" are different claims, and the notice file is the
natural place someone checks which one applies.

### Chronica — the dock's Calendar tile

**What we use:** nothing of the code. The tile calls the `IpcHandler` Chronica
publishes on `promaa.clock` (`open` / `close` / `toggle`), the same public
entry point a keybinding would use. Chronica is installed by the user, from
upstream, through `omarchy plugin add`; if it is absent or disabled the tile
does not appear.

**Author:** promaaa
**Project:** Chronica (`promaa.clock`)
**Source:** https://github.com/promaaa/sync-calendar-omarchy
**Licence:** MIT — theirs, and it stays with their repository.

### LibrePods — the AirPods advertisement format

This entry needs more care than the one above it, because LibrePods is GPL-3.0
and Macifier is MIT. The distinction it rests on:

**What we use:** no code, and no binary. `bin/macifier-pods` reads Apple's
proximity-pairing advertisement (manufacturer `0x004C`, TLV type `0x07`) and
decodes the byte layout LibrePods documents in `linux/ble/blemanager.cpp` —
which nibble holds which battery, which bit says the lid is open, which byte
says the buds are on a call. That layout is a fact about Apple's radio traffic,
not an expression of LibrePods' authorship: our decoder is written against
BlueZ's D-Bus API in Python and shares no lines, no structure and no build
system with theirs. We are grateful for the reverse-engineering; we have not
taken the work product.

**What we do not do:** carry, vendor, link, redistribute or derive from any
LibrePods source. Nothing in this repository is a GPL-3.0 derivative.

**Where users get the real thing:** the AirPods battery and noise-control UI is
*not* ours and we do not reimplement it. It is the `omapods` / `omarchy-pods`
plugin, which builds and ships the LibrePods daemon proper. Macifier points at
it through `omarchy plugin add`, exactly as it points at Chronica, and that
plugin's GPL-3.0 obligations live with that plugin — which is precisely why we
link to it rather than absorb it.

**Author:** Kavish Devar and the LibrePods contributors
**Project:** LibrePods
**Source:** https://github.com/librepods-org/librepods
**Licence:** GPL-3.0 — theirs, and it stays with their repository.
