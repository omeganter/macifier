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
