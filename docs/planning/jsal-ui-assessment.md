# jsal-ui: code assessment and action items

Repo: `superjsal/jsal-ui` (WoW addon, Lua 5.1, `jsalUI/`, ~72k lines in 118 files, much of it generated `*Data.lua`).
Method: `luac5.1 -p` on all files, `luacheck --std lua51` (excluding `*Data.lua`). Not run in-game.

## Verdict
Healthy. All files parse, no TODO/FIXME, no real bugs found by lint. Gaps are tooling (no tests, no lint in CI) and a few oversized files.

## Tasks (in priority order)

### 1. Add `.luacheckrc` and a CI lint job
- Create `.luacheckrc` at repo root: `std = "lua51"`, `max_line_length = false`, `exclude_files = { "jsalUI/**/*Data.lua" }`.
- `globals` (writable): `jsalUIDB`, `jsalUICharDB`, `SLASH_JSALUI1`, `SLASH_JSALUI2`, `jsalUI_OnCompartmentClick`, `jsalUI_OnCompartmentEnter`, `jsalUI_OnCompartmentLeave`; `SlashCmdList` as `read_globals` with `other_fields`/mutable.
- `read_globals`: WoW API globals. Generate the list from the ~2,550 W113 warnings (`luacheck jsalUI --codes | grep W113`), or use a community WoW stds file.
- Add `.github/workflows/lint.yml` that runs `luacheck jsalUI` on push/PR.
- Acceptance: `luacheck jsalUI` exits 0 in CI.

### 2. Fix remaining lint findings (~60)
- Unused: `Endgame/GoalCard.lua:11` `MUTED`; `Games/IconGuess.lua:123` `marks`; `Guild.lua:7` `Style`; `Core.lua:425` `copy`; `Gear/Goal.lua:526` two `_`.
- `Endgame/RaidNight.lua:98`: empty `if` branch. Implement or remove.
- `Dungeons/Map.lua:494`: loop executes at most once. Likely should be an `if`/direct access.
- Shadowing (W431/W421), 26+ cases. Rename the inner variables:
  - `Dungeons/Page.lua`: 865, 896, 897, 1643 (`top`, `tab`), 2070 (`key`), 2271 and 2378 (`side`)
  - `Gear/Gear.lua`: 1232, 1237 (`total`)
  - `Gear/Page.lua:955` (`order`)
  - `Guild.lua:477` (`Newer`)
  - `Games/DailyWord.lua:349` (`n`)
- Acceptance: luacheck clean.

### 3. Add unit tests for pure-logic modules
- Use `busted` (Lua 5.1) under `spec/`; run in CI.
- Start with `Games/PalRunRules.lua`.
- Next: `Games/DailyWord.lua` scoring logic, and any pure helpers in `Gear/Weights.lua`.
- The modules must be loadable without the WoW API: pass a stub `ns` table (`local addonName, ns = ...`) and stub `Compat`. Move any WoW calls out of the rules module if it blocks this.
- Acceptance: `busted` passes in CI.

### 4. Split oversized files
Largest non-data files, with deep closures and shadowed upvalues:
- `Dungeons/Page.lua` (2443)
- `Professions/Crafts.lua` (2226)
- `Home.lua` (1707)
- `Dungeons/DungeonLoot.lua` (1699)
- `Gear/Gear.lua` (1472)
- `Professions/Shopping.lua` (1457)
- `Journal/Page.lua` (1436)
- `Style.lua` (1286)

Extract cohesive sections (tabs, row builders, tooltip code) into sibling files, register them in `jsalUI.toc`, and keep behaviour identical. Do `Dungeons/Page.lua` first, since it has the most shadowing. Verify in-game after each split.

### 5. (Optional) Reduce `ns.db` coupling
`ns.db` is referenced ~225 times directly. Add small accessors per feature (e.g. `Journal.GetSettings()`), so schema changes and defaults live in one place.

## Don't change
- Error capture in `Errors.lua`, the `Compat` layer, the `tools/` data pipeline and the weekly data-check and nightly release workflows all work well.
