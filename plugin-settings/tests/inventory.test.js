// Tests for the settings inventory.
//
// The inventory is data, not code, and it is the thing docs/SETTINGS.md calls
// the actual deliverable — so the rules that make it honest are worth holding
// to mechanically. The one that matters most is the grey-row rule: a row the
// user cannot act on must say why, or it reads as broken rather than absent.
//
// These run against the repo's copy, which is what install.sh deploys.
//
//   node plugin-settings/tests/inventory.test.js

const fs = require("fs");
const path = require("path");
const assert = require("assert");

const inventoryPath = path.join(__dirname, "..", "..", "share", "settings-inventory.json");
const qmlPath = path.join(__dirname, "..", "Settings.qml");

const inventory = JSON.parse(fs.readFileSync(inventoryPath, "utf8"));
const qml = fs.readFileSync(qmlPath, "utf8");

const TAGS = ["omarchy", "macifier", "plugin", "planned", "notonlinux"];
const GREY = ["planned", "notonlinux"];
const ACTION_KINDS = ["run", "menu", "plugin"];

const allRows = [];
for (const pane of inventory.panes) {
  for (const row of pane.rows) allRows.push({ pane, row });
}

let failures = 0;
function test(name, fn) {
  try {
    fn();
    console.log("  ok   " + name);
  } catch (e) {
    failures++;
    console.log("  FAIL " + name + "\n       " + e.message);
  }
}

console.log("settings inventory");

test("every pane has an id, a name and at least one row", () => {
  for (const pane of inventory.panes) {
    assert.ok(pane.id, "pane without an id");
    assert.ok(pane.name, `pane ${pane.id} has no name`);
    assert.ok(Array.isArray(pane.rows) && pane.rows.length > 0, `pane ${pane.id} has no rows`);
  }
});

test("pane ids are unique", () => {
  const seen = new Set();
  for (const pane of inventory.panes) {
    assert.ok(!seen.has(pane.id), `duplicate pane id: ${pane.id}`);
    seen.add(pane.id);
  }
});

test("row labels are unique within a pane", () => {
  for (const pane of inventory.panes) {
    const seen = new Set();
    for (const row of pane.rows) {
      assert.ok(!seen.has(row.label), `duplicate row "${row.label}" in ${pane.id}`);
      seen.add(row.label);
    }
  }
});

test("every row has a label and a known tag", () => {
  for (const { pane, row } of allRows) {
    assert.ok(row.label, `row without a label in ${pane.id}`);
    assert.ok(TAGS.includes(row.tag), `row "${row.label}" has unknown tag ${JSON.stringify(row.tag)}`);
  }
});

// The rule the whole window rests on.
test("every grey row says why", () => {
  for (const { row } of allRows) {
    if (!GREY.includes(row.tag)) continue;
    assert.ok(row.note && row.note.trim().length > 0,
      `grey row "${row.label}" (${row.tag}) has no note — it would read as broken, not absent`);
  }
});

test("grey rows are inert — no action to click", () => {
  for (const { row } of allRows) {
    if (!GREY.includes(row.tag)) continue;
    assert.ok(!row.action, `grey row "${row.label}" carries an action; it must not be clickable`);
  }
});

test("a planned row names its phase", () => {
  for (const { row } of allRows) {
    if (row.tag !== "planned") continue;
    assert.ok(/^P[0-9]$/.test(row.phase || ""),
      `planned row "${row.label}" has no phase (got ${JSON.stringify(row.phase)})`);
  }
});

test("every action has exactly one kind, and it is a known one", () => {
  for (const { row } of allRows) {
    if (!row.action) continue;
    const kinds = Object.keys(row.action);
    assert.strictEqual(kinds.length, 1,
      `row "${row.label}" has ${kinds.length} action kinds: ${kinds.join(", ")}`);
    assert.ok(ACTION_KINDS.includes(kinds[0]),
      `row "${row.label}" has unknown action kind ${kinds[0]}`);
  }
});

test("a run action is a non-empty argv of strings", () => {
  for (const { row } of allRows) {
    if (!row.action || !row.action.run) continue;
    const argv = row.action.run;
    assert.ok(Array.isArray(argv) && argv.length > 0, `row "${row.label}" has an empty run action`);
    for (const a of argv) {
      assert.strictEqual(typeof a, "string", `row "${row.label}" has a non-string argument`);
    }
  }
});

// A row that offers to install something already present says we did not look.
// The window can only tell the difference when the row carries the plugin's id.
test("a plugin id, where given, is a plausible plugin id", () => {
  for (const { row } of allRows) {
    if (!row.pluginId) continue;
    assert.strictEqual(row.tag, "plugin", `row "${row.label}" has a pluginId but is not tagged plugin`);
    assert.ok(/^[a-z0-9]+([.-][a-z0-9]+)+$/.test(row.pluginId),
      `row "${row.label}" has an implausible pluginId: ${row.pluginId}`);
  }
});

test("a plugin row names the plugin and installs over https", () => {
  for (const { row } of allRows) {
    if (row.tag !== "plugin") continue;
    assert.ok(row.pluginName, `plugin row "${row.label}" does not name the plugin`);
    assert.ok(row.action && row.action.plugin,
      `plugin row "${row.label}" has no install action`);
    assert.ok(/^https:\/\//.test(row.action.plugin),
      `plugin row "${row.label}" installs from a non-https URL`);
  }
});

// Cheap guard against the two files drifting: a tag added to the data but not
// to the window would render as its own raw id.
test("Settings.qml renders every tag the inventory uses", () => {
  const used = new Set(allRows.map(({ row }) => row.tag));
  for (const tag of used) {
    assert.ok(qml.includes(`"${tag}"`),
      `Settings.qml has no branch for tag "${tag}"`);
  }
});

// `dock <id>` with no verb pins an app by that name, so a row invoking a dock
// subcommand the installed CLI does not know does not fail — it silently pins a
// phantom app called "calendar". The CLI reserves those words precisely so that
// cannot happen; this holds the inventory to the same list.
test("a dock row names a subcommand the CLI reserves", () => {
  const cliPath = path.join(__dirname, "..", "..", "bin", "omarchy-macifier");
  const cli = fs.readFileSync(cliPath, "utf8");
  const m = cli.match(/^DOCK_RESERVED=\(([^)]*)\)/m);
  assert.ok(m, "bin/omarchy-macifier no longer declares DOCK_RESERVED");
  const reserved = new Set(m[1].trim().split(/\s+/));

  for (const { row } of allRows) {
    if (!row.action || !row.action.run) continue;
    const [verb, sub] = row.action.run;
    if (verb !== "dock" || !sub) continue;
    assert.ok(reserved.has(sub),
      `row "${row.label}" runs \`dock ${sub}\`, which the CLI does not reserve — ` +
      `an older CLI would pin an app called "${sub}" instead`);
  }
});

test("Macifier rows point at a real macifier verb", () => {
  for (const { row } of allRows) {
    if (row.tag !== "macifier" || !row.action || !row.action.run) continue;
    const verb = row.action.run[0];
    assert.ok(["option", "dock", "panel", "key", "preset", "airpods"].includes(verb),
      `row "${row.label}" runs unknown verb "${verb}"`);
  }
});

// The window reads live option state out of `status --json`. That command
// reports each option as {on, available, description} — not a bare boolean —
// and reading the object itself is truthy for every option, which lights every
// dot. Guard the agreement rather than the assumption.
test("status --json still reports options as objects with a boolean `on`", () => {
  const { execFileSync } = require("child_process");
  const cli = path.join(__dirname, "..", "..", "bin", "omarchy-macifier");
  let parsed;
  try {
    parsed = JSON.parse(execFileSync("bash", [cli, "status", "--json"], { encoding: "utf8" }));
  } catch (e) {
    console.log("       (skipped: could not run the CLI here)");
    return;
  }
  assert.ok(parsed.options, "status --json has no `options` object");
  for (const [name, value] of Object.entries(parsed.options)) {
    assert.strictEqual(typeof value, "object", `option ${name} is not an object`);
    assert.strictEqual(typeof value.on, "boolean", `option ${name} has no boolean \`on\``);
  }
  assert.ok(qml.includes("typeof s.on"),
    "Settings.qml no longer reads `.on` — it would light every state dot");
});

// P0's acceptance criterion was "every Omarchy row goes somewhere". A route
// that no longer exists fails silently: `omarchy menu summon` opens the menu at
// its root, so the row looks like it worked and simply went to the wrong place.
// The menu definition is a flat map of dotted ids, which makes the check exact.
function menuRoutes() {
  const base = process.env.OMARCHY_PATH || "/usr/share/omarchy";
  const file = path.join(base, "default", "omarchy", "omarchy-menu.jsonc");
  if (!fs.existsSync(file)) return null;

  // JSONC: comments and trailing commas. `//` also appears inside strings
  // (every webapp route is a URL), so the scanner has to track strings.
  const src = fs.readFileSync(file, "utf8");
  let out = "", i = 0, inStr = false, esc = false;
  while (i < src.length) {
    const c = src[i];
    if (inStr) {
      out += c;
      if (esc) esc = false;
      else if (c === "\\") esc = true;
      else if (c === '"') inStr = false;
      i++;
      continue;
    }
    if (c === '"') { inStr = true; out += c; i++; continue; }
    if (c === "/" && src[i + 1] === "/") { while (i < src.length && src[i] !== "\n") i++; continue; }
    if (c === "/" && src[i + 1] === "*") { i += 2; while (i < src.length && !(src[i] === "*" && src[i + 1] === "/")) i++; i += 2; continue; }
    out += c;
    i++;
  }

  const menu = JSON.parse(out.replace(/,(\s*[}\]])/g, "$1"));
  const routes = new Set(Object.keys(menu));
  for (const entry of Object.values(menu)) {
    for (const alias of entry.aliases || []) routes.add(alias);
  }
  return routes;
}

test("every menu row points at a route this Omarchy actually has", () => {
  const routes = menuRoutes();
  if (!routes) {
    console.log("       (skipped: no Omarchy menu definition on this machine)");
    return;
  }
  for (const { row } of allRows) {
    if (!row.action || !row.action.menu) continue;
    assert.ok(routes.has(row.action.menu),
      `row "${row.label}" summons "${row.action.menu}", which is not a route — ` +
      `the menu would open at its root instead`);
  }
});

console.log(
  `\n${allRows.length} rows across ${inventory.panes.length} panes; ` +
  (failures === 0 ? "all checks passed" : `${failures} failed`)
);
process.exit(failures === 0 ? 0 : 1);
