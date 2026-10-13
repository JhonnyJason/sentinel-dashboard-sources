# Cycle Definition Component — Specification

A portable UI component that lets a user define a **cycle** (unit, size, anchor) and shows a date range chunked into that cycle as a table.

## 1. Deliverables

| File | Purpose |
|---|---|
| `cycle-definition.pug` | Mixin `+cycleDefinition(id)`. Renders a host `div` with the given `id` containing a `<template shadowrootmode="open">` (Declarative Shadow DOM) with a `<style>` block (`include ./cycle-definition.css`) and the editor + table markup. |
| `cycle-definition.css` | All component styles. Only applied inside the shadow root. |
| `cycle-definition.js` | ESM module, `export class CycleDefinition`. Vanilla JS, no dependencies. Bundled by the host. |
| `cycle-definition.d.ts` | TypeScript types for the external contract only. |

The JS is not a Web Component (no custom element).

## 2. Concepts

- **Unit**: `'years' | 'quarters' | 'months' | 'weeks'`.
- **Period**: one unit-sized chunk of time: a calendar year, a calendar quarter, a calendar month, or an ISO week (Monday–Sunday).
- **Size `n`**: number of periods per cycle. Integer, `1 ≤ n ≤ max(unit)`:

  | Unit | Max |
  |---|---|
  | years | 20 |
  | quarters | 80 |
  | months | 160 |
  | weeks | 320 |

- **Position**: index `0 … n-1` of a period within its cycle.
- **Anchor**: an absolute period at position 0. Anchors are equivalent modulo `n` (for a 4-year cycle, `2018`, `2022` and `2026` are the same anchor).
- **Today**: the local date, or `options.today` if given. Read at construction and at every render. No automatic refresh at midnight.

### 2.1 Period keys and labels

| Unit | Key (internal, sortable; also anchor format) | Display label |
|---|---|---|
| years | `2026` | `2026` |
| quarters | `2026-Q1` | `Q1.2026` |
| months | `2026-03` | `03.2026` |
| weeks | `2026-03-30` (the week's Monday) | `30.03.2026` |

## 3. Contract (TypeScript)

```ts
export type CycleUnit = 'years' | 'quarters' | 'months' | 'weeks';
export type Orientation = 'rows' | 'columns';

export interface CycleConfigSetting {
  name: string;        // '' = unsaved custom setting
  unit: CycleUnit;
  size: number;        // integer, 1..max(unit)
  anchor?: string;     // period key of the unit (§2.1); omitted = default anchor
}

export interface CycleDefinitionOptions {
  presets?: CycleConfigSetting[];
  initset?: CycleConfigSetting;
  rangeFrom?: string;  // 'YYYY-MM-DD', inclusive
  rangeTo?: string;    // 'YYYY-MM-DD', inclusive
  orientation?: Orientation; // default 'rows'
  today?: string;      // 'YYYY-MM-DD', override for "today"
}

export type ChangeListener = (setting: CycleConfigSetting) => void;
export type PresetSaveListener = (preset: CycleConfigSetting) => void;

export declare class CycleDefinition {
  constructor(idOrRootEl: string | HTMLElement, options?: CycleDefinitionOptions);
  addChangeListener(fn: ChangeListener): void;
  removeChangeListener(fn: ChangeListener): void;
  addPresetSaveListener(fn: PresetSaveListener): void;
  removePresetSaveListener(fn: PresetSaveListener): void;
  updateRange(rangeFrom: string, rangeTo: string): void;
  setOrientation(orientation: Orientation): void;
  getSettings(): CycleConfigSetting | null;
  setSettings(setting: CycleConfigSetting): void;
  destroy(): void;
}
```

## 4. Cycle arithmetic

Every period maps to an integer index `idx(p)`:

| Unit | `idx` |
|---|---|
| years | `year` |
| quarters | `year * 4 + (quarter - 1)` |
| months | `year * 12 + (month - 1)` |
| weeks | number of weeks since a fixed reference Monday |

With anchor index `a`, size `n` and `mod` = non-negative modulo:

- `position(p) = mod(idx(p) - a, n)`
- `cycle(p) = floor((idx(p) - a) / n)`. The cycle containing today is cycle `0`.
- **Slider value** `k = position(today)`. Moving the slider to `k` sets `a = idx(today) - k`.
- **Default anchor**: `k = 0` (the currently running period is position 0).
- **Normalized anchor**: the key of the period with index `idx(today) - k`, i.e. the start of the current cycle. `getSettings()` always returns this normalized anchor.

## 5. Table

Rendered only when the settings are complete and the range is valid.

- `pFrom = idx(period containing rangeFrom)` and `pTo = idx(period containing rangeTo)`.
- A period **has data** if `pFrom ≤ idx(p) ≤ pTo`. Partial periods at the range edges count fully and look the same as complete ones.
- **Cycles shown**: every cycle `c` from `cycle(pTo)` down to `cycle(pFrom)`, newest first.
- **Cells of cycle `c`**: positions `0 … n-1`, period index `a + c·n + position`. A cell with data shows its label. A cell without data (before the range, or after it, e.g. the future part of the current cycle) is rendered empty.
- **Orientation `'rows'`**: one cycle per row, newest row on top. A header row shows positions `0 … n-1`.
- **Orientation `'columns'`**: one cycle per column, newest column on the left. A header column shows positions `0 … n-1`.
- Each cell carries `data-period="<key>"` (prepared for later cell interaction; no interaction now).
- Nothing is sticky. The table area scrolls horizontally and/or vertically inside the component only when needed, and never widens the host page.

**Range problems**: if `rangeFrom` or `rangeTo` is missing, or `rangeFrom > rangeTo`, the table area shows `Keine Daten im gewählten Zeitraum`.
**Incomplete settings** (unit or size missing): the table area is empty.

## 6. Editor

From top to bottom:

1. **Vorlage**: dropdown containing the presets plus `Benutzerdefiniert`.
2. **Einheit**: segmented control `Jahre | Quartale | Monate | Wochen`.
3. **Länge**: number input, `min=1`, `max=max(unit)`.
4. **Anker**: slider with discrete steps `0 … n-1` (mirrored: value = `n-1-k`, right = later anchor) and a readout, e.g. `Aktuell: Position 2 → Zyklus begann Q2.2026`. Disabled until the size is set.
5. **Als Vorlage speichern**: button that reveals a name field plus `Speichern` / `Abbrechen`.

### 6.1 Editing rules

- **Selecting a preset** applies its unit, size and anchor (the default anchor if `anchor` is omitted). The dropdown shows the preset, and `name` = the preset's name.
- **Editing any field** sets the dropdown to `Benutzerdefiniert` and `name` to `''`. Editing the fields back to match a preset does **not** reselect that preset.
- **Changing the unit** resets the anchor to the default (`k = 0`). The size is kept, clamped to the new maximum, and stays empty if it was empty.
- **Changing the size** keeps `k`, clamped to `n - 1`.
- **Invalid size** (non-integer, out of range, non-numeric, empty) snaps to the nearest valid value on commit: round, then clamp to `1 … max`. Non-numeric or empty input reverts to the last valid value, or stays empty if there never was one.
- **Picking a unit with no size set**: the size field stays empty (no default size).
- The table re-renders whenever settings change.

### 6.2 Saving a preset

- The button is disabled while the settings are incomplete.
- `Speichern` is disabled while the trimmed name is empty.
- If the trimmed name equals an existing preset name, saving is blocked and the hint `Name existiert bereits` is shown.
- On save:
  1. The preset-save listeners receive `{ name, unit, size, anchor }`, with the anchor normalized.
  2. The preset is appended to the dropdown and selected.
  3. The change listeners receive the setting, now carrying the new name.
- The component does not persist presets. Persisting is the host's job, e.g. passing the preset in `presets` on the next render.

## 7. Behaviour of the API

### Construction

- `idOrRootEl`: a string is resolved with `document.getElementById`. If no element is found, the constructor throws.
- **Shadow root**: if `root.shadowRoot` exists (the Declarative Shadow DOM was parsed), it is used. Otherwise, if the root contains a `<template shadowrootmode>` (e.g. HTML inserted via `innerHTML`), the constructor calls `attachShadow({ mode: 'open' })` and moves the template content into the new shadow root. If neither exists, it throws.
- **Initial state**: `initset` if given. Otherwise the first preset. If there are no presets, unit and size are empty, the dropdown is on `Benutzerdefiniert`, and the table is empty.
- **Name handling in `initset`**: a non-empty `name` selects the preset with that name in the dropdown, while the values come from `initset`.

### Methods

- **`getSettings()`**: returns a fresh copy with the normalized anchor, or `null` while unit or size is missing.
- **`setSettings(s)`**: validates, applies and re-renders. Does **not** fire change listeners. Name handling is the same as for `initset`.
- **`updateRange(from, to)`**: re-renders. Fires no events.
- **`setOrientation(o)`**: re-renders. Fires no events.
- **Listeners** are kept in a `Set`, so adding the same function twice registers it once. Removing an unknown function does nothing.
- **Change listeners** fire only on user commits (the native `change` event of inputs and selects, a preset selection, or a preset save), and only with complete, valid settings. Each listener gets its own copy.
- **`destroy()`**: removes all DOM event listeners the component attached, clears all registered callbacks, and drops internal references. It does **not** touch the DOM, so a new `CycleDefinition` can be constructed on the same root. Calling any method after `destroy()` throws.

### Validation (programming errors throw)

All of the following throw: an unknown unit, a non-integer or out-of-range size, an anchor whose format does not match the unit (e.g. `2026-03` for quarters), a weeks anchor that is not a Monday, a malformed date, an invalid orientation, a non-function listener, a non-empty `name` with no matching preset, or presets with empty or duplicate names.

## 8. Styling

- Styles are scoped by the shadow root, so no class prefixes are needed.
- Theming happens only through CSS custom properties set on the host `div`. Initial set: `--cd-font`, `--cd-text`, `--cd-bg`, `--cd-border`, `--cd-cell-bg`, `--cd-cell-empty-bg`, `--cd-accent`.
- All UI text is fixed German.

## 9. Worked examples (acceptance tests)

All examples use today = **2026-10-12** (a Monday) and orientation `'rows'` unless stated. `·` marks an empty cell.

**E1: 4 × years, default anchor, range 2015-03-01 … 2026-10-12.** Slider `k = 0`, normalized anchor `2026`.

| 0 | 1 | 2 | 3 |
|---|---|---|---|
| 2026 | · | · | · |
| 2022 | 2023 | 2024 | 2025 |
| 2018 | 2019 | 2020 | 2021 |
| · | 2015 | 2016 | 2017 |

**E2: E1 with orientation `'columns'`.** Column 0 holds only `2026`. Column 1 holds `2022, 2023, 2024, 2025` (positions 0–3, top to bottom), and so on.

**E3: E1 with the slider at `k = 2`.** The anchor becomes `2024`, and the top row is `2024 | 2025 | 2026 | ·`.

**E4: anchor normalization.** `setSettings({ name:'', unit:'years', size:4, anchor:'2018' })`: `getSettings().anchor === '2026'` and `k = 0`. With `anchor:'2019'`: `k = position(2026) = 3`, so `getSettings().anchor === '2023'`.

**E5: 5 × weeks, default anchor, range 2026-08-20 … 2026-10-12.** The range starts mid-week, so the week of 17.08. still counts.

| 0 | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| 12.10.2026 | · | · | · | · |
| 07.09.2026 | 14.09.2026 | 21.09.2026 | 28.09.2026 | 05.10.2026 |
| · | · | 17.08.2026 | 24.08.2026 | 31.08.2026 |

**E6: 12 × months, default anchor.** The anchor is `2026-10` and the first cell of the top row shows `10.2026`.

**E7: size change keeps position.** At `k = 3` with size 5, changing the size to 3 sets `k = 2`.

**E8: unit change.** 4 × years at `k = 2` → switching to quarters gives size 4 and `k = 0`. 30 × months → switching to years clamps the size to 20.

**E9: incomplete state.** No presets and no `initset`: `getSettings() === null`, the table area is empty, and the slider and save button are disabled. Choosing `Monate` keeps the size empty, and no change event fires.

**E10: events.** Selecting a preset fires change listeners once. Typing in the size field fires nothing until commit. `setSettings`, `updateRange` and `setOrientation` fire nothing.

**E11: saving.** Saving with an empty name is impossible. A duplicate name shows `Name existiert bereits`. A valid save fires preset-save listeners, then change listeners with the new name, and the preset appears selected in the dropdown.

**E12: invalid size.** Typing `500` with unit months commits as `160`. Typing `0` commits as `1`. Typing `abc` reverts to the last valid value.

**E13: invalid host input throws.** Each of these throws: `setSettings({ name:'', unit:'quarters', size:4, anchor:'2026-03' })`, `{ unit:'years', size:21 }`, and a weeks anchor `'2026-10-13'` (a Tuesday).

**E14: fallback shadow root.** Inserting the rendered mixin HTML via `innerHTML` and then constructing the component works and renders the same as server-rendered HTML.

**E15: destroy.** After `destroy()`, user interaction fires no listeners, the DOM remains, and constructing again on the same id works.
