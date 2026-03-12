# Data Browser Devtool Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A minimal devtool webpage for browsing, filtering, sorting, and inline-editing game JSON data files.

**Architecture:** Two files in `tools/` — a Python HTTP server (`server.py`) that serves the `data/` directory with REST endpoints, and a single vanilla HTML/JS/CSS file (`browser.html`) that renders sortable/filterable tables per resource type with inline editing.

**Tech Stack:** Python 3 stdlib (http.server, json), vanilla HTML/CSS/JS (no dependencies)

---

### Task 1: Python Server

**Files:**
- Create: `tools/server.py`

**Step 1: Write the server**

`tools/server.py` — a Python HTTP server with these endpoints:

- `GET /` — serves `tools/browser.html`
- `GET /api/types` — returns list of resource type directories in `data/` (guests, stalls, relics, spells, status_effects, etc.)
- `GET /api/data/<type>` — returns all JSON files for that type as an array. For `stalls`, walk subdirectories recursively. Each object includes an extra `_file_path` field (relative to project root) so the frontend knows which file to PUT back.
- `PUT /api/data` — accepts `{ "_file_path": "data/guests/hungry_ghost.json", ...rest }` and writes the JSON back to disk (pretty-printed, 2-space indent). Strips `_file_path` and `$schema` from the written content, then re-adds `$schema` as the first key.

Server details:
- Runs on `localhost:8099`
- CORS not needed (same origin)
- Serves from the project root directory (assumes `python tools/server.py` is run from project root)
- Prints a startup message with the URL
- Auto-opens the browser on startup (`webbrowser.open`)

**Step 2: Test the server manually**

Run: `cd /Users/pern/night && python tools/server.py &`
Then: `curl http://localhost:8099/api/types`
Expected: JSON array of type names like `["enhancements", "guests", "heroes", ...]`

Then: `curl http://localhost:8099/api/data/guests | python -m json.tool | head -20`
Expected: JSON array of guest objects, each with `_file_path` field

Kill server after testing.

---

### Task 2: HTML Shell and Resource Type Navigation

**Files:**
- Create: `tools/browser.html`

**Step 1: Write the HTML shell**

Single HTML file with embedded CSS and JS. Structure:

```
┌──────────────────────────────────────────────┐
│  Patrons of the Night — Data Browser         │
├────────┬─────────────────────────────────────┤
│ Guests │  [Search...] [Rarity ▼] [Tags ▼]   │
│ Stalls │─────────────────────────────────────│
│ Relics │  Table here                         │
│ Spells │                                     │
│ Status │                                     │
│        │                                     │
└────────┴─────────────────────────────────────┘
```

CSS:
- Minimal, developer-tool aesthetic. Dark background (#1a1a2e), light text (#e0e0e0)
- Monospace font for data cells, sans-serif for UI chrome
- Sidebar: fixed 160px, vertical list of type buttons
- Active type button highlighted
- Table: full width, striped rows, compact cells

JS on load:
- Fetch `/api/types` to populate sidebar
- Click a type → fetch `/api/data/<type>` → render table
- Default to "guests" on first load

**Step 2: Verify the shell loads**

Run server, open `http://localhost:8099`, confirm:
- Sidebar shows resource types
- Clicking "guests" loads and displays guest data in a raw table

---

### Task 3: Type-Specific Table Columns

**Files:**
- Modify: `tools/browser.html`

**Step 1: Define column configs per type**

In the JS, define a `COLUMN_CONFIGS` object mapping type name to column definitions:

```js
const COLUMN_CONFIGS = {
  guests: [
    { key: "id", label: "ID", editable: false },
    { key: "rarity", label: "Rarity", editable: true, type: "select", options: ["common", "rare", "epic", "legendary"] },
    { key: "base_stats.needs.food", label: "Food", editable: true, type: "number" },
    { key: "base_stats.needs.joy", label: "Joy", editable: true, type: "number" },
    { key: "base_stats.money", label: "Money", editable: true, type: "number" },
    { key: "base_stats.movement_speed", label: "Speed", editable: true, type: "number" },
    { key: "is_core_guest", label: "Core", editable: false, type: "boolean" },
    { key: "skills.length", label: "Skills", editable: false, type: "number" },
    { key: "tags", label: "Tags", editable: false, type: "tags" },
  ],
  stalls: [
    { key: "id", label: "ID", editable: false },
    { key: "_hero", label: "Hero", editable: false },  // derived from _file_path
    { key: "rarity", label: "Rarity", editable: true, type: "select", options: ["common", "rare", "epic", "legendary"] },
    { key: "operation_model", label: "Model", editable: true, type: "select", options: ["product", "service", "bulk_service"] },
    { key: "need_type", label: "Need", editable: true, type: "select", options: ["food", "joy", "any"] },
    // Tier-dependent columns (shown for currently selected tier):
    { key: "_tier.cost_to_guest", label: "Cost", editable: true, type: "number", tierDependent: true },
    { key: "_tier.value", label: "Value", editable: true, type: "number", tierDependent: true },
    { key: "_tier.restock_amount", label: "Restock Amt", editable: true, type: "number", tierDependent: true },
    { key: "_tier.restock_duration", label: "Restock Dur", editable: true, type: "number", tierDependent: true },
    { key: "_tier.service_duration", label: "Svc Dur", editable: true, type: "number", tierDependent: true },
    { key: "_tier.capacity", label: "Capacity", editable: true, type: "number", tierDependent: true },
    { key: "tags", label: "Tags", editable: false, type: "tags" },
  ],
  relics: [
    { key: "id", label: "ID", editable: false },
    { key: "rarity", label: "Rarity", editable: true, type: "select", options: ["common", "rare", "epic", "legendary"] },
    { key: "hero_id", label: "Hero", editable: false },
    { key: "skills.length", label: "Skills", editable: false, type: "number" },
    { key: "tags", label: "Tags", editable: false, type: "tags" },
  ],
  spells: [
    { key: "id", label: "ID", editable: false },
    { key: "rarity", label: "Rarity", editable: true, type: "select", options: ["common", "rare", "epic", "legendary"] },
    { key: "hero_id", label: "Hero", editable: false },
    { key: "target_type", label: "Target", editable: true, type: "select", options: ["none", "tile", "stall", "guest"] },
    { key: "effects.length", label: "Effects", editable: false, type: "number" },
    { key: "tags", label: "Tags", editable: false, type: "tags" },
  ],
  status_effects: [
    { key: "id", label: "ID", editable: false },
    { key: "effect_type", label: "Type", editable: true, type: "select", options: ["buff", "debuff"] },
    { key: "stack_type", label: "Stack", editable: true, type: "select", options: ["time", "trigger", "passive"] },
    { key: "max_stacks", label: "Max Stacks", editable: true, type: "number" },
    { key: "initial_stacks", label: "Init Stacks", editable: true, type: "number" },
    { key: "applicable_to", label: "Applies To", editable: false, type: "tags" },
    { key: "tags", label: "Tags", editable: false, type: "tags" },
  ],
};
```

For types without a config (enhancements, heroes, levels, runs, skills), show a generic fallback: display all top-level keys as columns (read-only).

**Step 2: Implement nested key resolution**

Write a `getNestedValue(obj, keyPath)` function that handles dot-notation paths like `base_stats.needs.food`. Returns `""` if path doesn't exist.

**Step 3: Stall hero derivation**

When loading stalls, derive `_hero` from `_file_path` — e.g. `data/stalls/angry_bull/common/mooncake_stand.json` → `"angry_bull"`.

**Step 4: Stall tier toggle**

Add a tier toggle (buttons: T1 / T2 / T3) above the stalls table. Default to T1. When switched, re-render tier-dependent columns from the selected tier's data. Store current tier index in state.

For tier-dependent column resolution: `_tier.cost_to_guest` reads from `item.tiers[selectedTierIndex].cost_to_guest`. Show `"-"` if the tier doesn't have that field (e.g. product stalls don't have `capacity`).

**Step 5: Verify column rendering**

Open browser, check:
- Guests table shows food/joy/money/speed columns with correct values
- Stalls table shows tier 1 stats, switching to T2/T3 updates the stat columns
- Status effects show effect_type, stack_type, etc.

---

### Task 4: Sorting and Filtering

**Files:**
- Modify: `tools/browser.html`

**Step 1: Sortable columns**

Click a column header to sort by that column. Click again to reverse. Show a small ▲/▼ indicator on the active sort column. Sort numerically for number columns, alphabetically for strings.

**Step 2: Search bar**

Text input above the table. Filters rows by matching the search term against all visible column values (case-insensitive substring match). Debounce 200ms.

**Step 3: Dropdown filters**

Add dropdown filters for key categorical fields. Which filters appear depends on the current type:
- All types: rarity filter
- Stalls: hero_id, operation_model, need_type
- Guests: is_core_guest
- Status effects: effect_type, stack_type

Dropdowns show "All" plus unique values found in the data. Multiple filters are AND-combined.

**Step 4: Verify filtering**

- Type "ghost" in search → only hungry_ghost and similar guests shown
- Select rarity "rare" → only rare items shown
- Both combined → intersection

---

### Task 5: Inline Editing and Save

**Files:**
- Modify: `tools/browser.html`

**Step 1: Editable cells**

For columns where `editable: true`:
- **number**: Click cell → turns into `<input type="number">`, press Enter or blur to confirm
- **select**: Click cell → turns into `<select>` with the defined options
- **text**: Click cell → turns into `<input type="text">`

When a cell value changes from the original:
- Highlight the cell (e.g. yellow border-left or background tint)
- Show a "Save" button on that row (right side)
- Track dirty state per row

**Step 2: Save handler**

Clicking "Save" on a row:
- Reconstruct the full JSON object from the original data + edits
- For tier-dependent edits, write back to the correct tier in the tiers array
- PUT to `/api/data` with the full object including `_file_path`
- On success: remove dirty highlighting, brief green flash
- On error: show red flash with error message

**Step 3: Write-back for nested values**

Write a `setNestedValue(obj, keyPath, value)` function that handles dot-notation. For `_tier.cost_to_guest`, resolve to `obj.tiers[selectedTierIndex].cost_to_guest`.

**Step 4: Verify editing**

- Change a guest's money value, click Save
- Check the JSON file on disk has the new value
- Reload the page → value persists

---

### Task 6: Polish and Edge Cases

**Files:**
- Modify: `tools/browser.html`
- Modify: `tools/server.py`

**Step 1: Empty states**

Show "No results" when filters produce no matches.

**Step 2: Row count**

Show "Showing X of Y items" above the table.

**Step 3: Keyboard navigation**

Tab between editable cells. Enter to confirm edit and move to next row's same column.

**Step 4: Unsaved changes warning**

If any row has unsaved changes and the user navigates to a different type, show a confirm dialog.

**Step 5: Final verification**

Test the full workflow:
1. Start server
2. Browse guests, sort by money
3. Filter by rarity "common"
4. Change hungry_ghost money from 3 to 5
5. Save
6. Verify `data/guests/hungry_ghost.json` has `"money": 5`
7. Revert the change manually
