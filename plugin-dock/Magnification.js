.pragma library

// The macOS dock magnification wave.
//
// Both functions below are taken, unmodified, from macOS Magnify Dock by
// Wisang Drillian Geni (wdg) — the DockModel.js of
// https://github.com/wisangdg/omarchy-magnify-dock at commit
// fc2ee90ce414eafcbff2f388f0782988dbd860f6. That project is MIT licensed; its
// full notice is in THIRD_PARTY_NOTICES.md and must travel with this file.
//
// Only these two are here. wdg's computeBaselineCenters assumes his dock's
// layout — an applications launcher, then a separator, then pinned and
// unpinned rows — and ours is not that shape, so Dock.qml computes its own
// baseline and calls into these.
//
// The comments on the two functions are wdg's own, kept because they explain
// choices the code cannot: why a raised cosine rather than a smoothstep, and
// why half of each icon's extra width goes to either side.

// Raised cosine bell: continuous slope at both ends, with a wider shoulder
// than smoothstep. It makes adjacent icons participate in the magnification
// wave instead of snapping between a large icon and nearly resting neighbors.
function scaleFromDistance(dist, maxScale, radius) {
  var limit = radius || 140;
  var topScale = maxScale || 1.6;
  if (dist >= limit) return 1.0;
  var norm = dist / limit;
  var cosine = Math.cos(norm * Math.PI / 2);
  return 1.0 + (topScale - 1.0) * cosine * cosine;
}

// Return transform-only horizontal offsets for a centered row of fixed slots.
// Each magnified icon contributes visual width; half is distributed to either
// side so the wave stays centered and neighboring icons never collide.
function computeMagnifiedOffsets(scales, baseSize, expansionRatio) {
  var values = Array.isArray(scales) ? scales : [];
  var ratio = typeof expansionRatio === "number" ? expansionRatio : 0.82;
  var extras = [];
  var totalExtra = 0;

  for (var i = 0; i < values.length; i++) {
    var extra = Math.max(0, (Number(values[i]) - 1.0) * baseSize * ratio);
    extras.push(extra);
    totalExtra += extra;
  }

  var offsets = [];
  var cursor = -totalExtra / 2;
  for (var j = 0; j < extras.length; j++) {
    offsets.push(cursor + extras[j] / 2);
    cursor += extras[j];
  }
  offsets.totalExtra = totalExtra;
  return offsets;
}
