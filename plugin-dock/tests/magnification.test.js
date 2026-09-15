// Tests for the dock magnification wave.
//
// Two things are under test and they are not equally ours. scaleFromDistance
// and computeMagnifiedOffsets are wdg's, vendored unmodified (see
// THIRD_PARTY_NOTICES.md) — we test them because we depend on them, not
// because we doubt them. The slot geometry is ours, and it is the part that
// has to agree with Dock.qml's delegate or the wave lands on the wrong icons.
//
//   node plugin-dock/tests/magnification.test.js

const fs = require("fs");
const path = require("path");
const assert = require("assert");

// Magnification.js is QML-flavoured JS: strip the .pragma line and eval it.
const source = fs
  .readFileSync(path.join(__dirname, "..", "Magnification.js"), "utf8")
  .replace(/^\.pragma\s+library\s*$/m, "");
const { scaleFromDistance, computeMagnifiedOffsets } = (() => {
  const module_ = {};
  new Function(
    "exports",
    source + "\nexports.scaleFromDistance = scaleFromDistance;" +
             "\nexports.computeMagnifiedOffsets = computeMagnifiedOffsets;"
  )(module_);
  return module_;
})();

let failures = 0;
function test(name, fn) {
  try {
    fn();
    console.log(`  ok   ${name}`);
  } catch (e) {
    failures++;
    console.log(`  FAIL ${name}\n       ${e.message}`);
  }
}

const MAX = 1.6;
const RADIUS = 140;

console.log("scaleFromDistance");

test("at the pointer, the icon is at full magnification", () => {
  assert.strictEqual(scaleFromDistance(0, MAX, RADIUS), MAX);
});

test("beyond the radius, the icon is exactly at rest", () => {
  assert.strictEqual(scaleFromDistance(RADIUS, MAX, RADIUS), 1.0);
  assert.strictEqual(scaleFromDistance(RADIUS + 500, MAX, RADIUS), 1.0);
});

test("falls off monotonically, so no icon outgrows a nearer one", () => {
  let previous = Infinity;
  for (let d = 0; d <= RADIUS; d += 5) {
    const s = scaleFromDistance(d, MAX, RADIUS);
    assert.ok(s <= previous + 1e-9, `scale rose again at distance ${d}`);
    previous = s;
  }
});

test("meets rest continuously — no visible step at the edge", () => {
  const justInside = scaleFromDistance(RADIUS - 0.01, MAX, RADIUS);
  assert.ok(justInside - 1.0 < 1e-4,
            `steps by ${justInside - 1.0} at the radius`);
});

test("neighbours participate: the shoulder is wide, not a spike", () => {
  // The point of the raised cosine over a smoothstep. Half a radius out, an
  // icon should still be meaningfully raised.
  const half = scaleFromDistance(RADIUS / 2, MAX, RADIUS);
  assert.ok(half > 1.25 && half < 1.4, `half-radius scale was ${half}`);
});

console.log("computeMagnifiedOffsets");

test("all at rest means no offsets and no extra width", () => {
  const offsets = computeMagnifiedOffsets([1, 1, 1, 1], 46, 0.82);
  assert.deepStrictEqual(Array.from(offsets), [0, 0, 0, 0]);
  assert.strictEqual(offsets.totalExtra, 0);
});

test("a symmetric wave pushes symmetrically, so the row stays centred", () => {
  const offsets = computeMagnifiedOffsets([1.0, 1.3, 1.6, 1.3, 1.0], 46, 0.82);
  assert.ok(Math.abs(offsets[0] + offsets[4]) < 1e-9, "ends not mirrored");
  assert.ok(Math.abs(offsets[1] + offsets[3]) < 1e-9, "shoulders not mirrored");
  assert.ok(Math.abs(offsets[2]) < 1e-9, "centre icon drifted");
});

test("offsets are ordered left to right — icons never cross over", () => {
  const offsets = computeMagnifiedOffsets([1.6, 1.3, 1.0, 1.0, 1.0], 46, 0.82);
  for (let i = 1; i < offsets.length; i++)
    assert.ok(offsets[i] >= offsets[i - 1], `icon ${i} overtook its neighbour`);
});

test("totalExtra is the width the card must grow by", () => {
  const scales = [1.0, 1.6, 1.0];
  const offsets = computeMagnifiedOffsets(scales, 46, 0.82);
  assert.ok(Math.abs(offsets.totalExtra - 0.6 * 46 * 0.82) < 1e-9);
});

test("survives junk rather than returning NaN offsets", () => {
  const offsets = computeMagnifiedOffsets(null, 46, 0.82);
  assert.strictEqual(offsets.length, 0);
  assert.strictEqual(offsets.totalExtra, 0);
});

console.log("slot geometry (ours — must match Dock.qml's delegate)");

// Mirrors Dock.qml: separators are space(9) wide, every other tile is
// iconSize + space(8), and the row's spacing is space(8).
const ICON = 46, GAP = 8, SEP = 9;
function centresFor(items) {
  const centres = [];
  let x = 0;
  for (const it of items) {
    const w = it.kind === "sep" ? SEP : ICON + GAP;
    centres.push(x + w / 2);
    x += w + GAP;
  }
  return centres;
}

test("a separator occupies its own narrower slot", () => {
  const centres = centresFor([{}, { kind: "sep" }, {}]);
  assert.strictEqual(centres[0], (ICON + GAP) / 2);
  assert.strictEqual(centres[1], ICON + GAP + GAP + SEP / 2);
});

test("pointing at an icon's centre magnifies that icon and no other most", () => {
  const items = [{}, {}, {}, { kind: "sep" }, {}];
  const centres = centresFor(items);
  const target = 2;
  const scales = centres.map((c, i) =>
    items[i].kind === "sep"
      ? 1.0
      : scaleFromDistance(Math.abs(centres[target] - c), MAX, RADIUS));
  const peak = scales.indexOf(Math.max(...scales));
  assert.strictEqual(peak, target);
  assert.strictEqual(scales[target], MAX);
});

test("separators stay at rest even with the pointer on them", () => {
  const items = [{}, { kind: "sep" }, {}];
  const centres = centresFor(items);
  const scales = centres.map((c, i) =>
    items[i].kind === "sep"
      ? 1.0
      : scaleFromDistance(Math.abs(centres[1] - c), MAX, RADIUS));
  assert.strictEqual(scales[1], 1.0);
});

console.log(failures === 0
  ? "\nall magnification tests passed"
  : `\n${failures} failing`);
process.exit(failures === 0 ? 0 : 1);
