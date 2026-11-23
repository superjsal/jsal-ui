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

## Review of the other two planning docs

Companion docs in this folder: `jsal-ui-action-plan.md` (docs, licence, CI, templates) and `jsal-ui-roadmap-to-10.md` (product and polish). Findings below are corrections and gaps to fold in before relaying them.

### Action plan: corrections
- **§5 Chess:** decided. Chess is unused, so take Option B (remove). Keep `jsalUI/Media/Chess/dot.tga`, or move it and update the 4 users (`Professions/Panel.lua:209`, `Helpers/Launcher.lua:433`, `Helpers/MenuBar.lua:106`, `Games/Flight.lua:256`). Chess is also wired into `Core.lua`, `Home.lua`, `Launcher.lua`, `MinimapButton.lua`, `Settings.lua`, `Window.lua`, `Guild.lua`, `Flight.lua`, `tools/make_part_icons.mjs` and `tools/README.md`, not only the three Chess files and the TOC. It is currently "shelved" via `ns.SHELVED` in `Core.lua:137`. Search `grep -rni chess .`.
- **§9 `tools/README.md`:** it already exists. Extend it instead of creating it.
- **§8 CI:** `luac -p` alone catches syntax only. Add `luacheck` (task 1 above); a syntax-only gate is weak.
- **§11 "No gameplay Lua changed except Chess removal":** the Chess removal touches about 10 Lua files. List each one in the PR.
- **`.pkgmeta`:** new root folders such as `docs/` and files such as `CONTRIBUTING.md` must not ship in the addon zip. Add them to `ignore`. Check that `LICENSE` ships, as §4.1 says. `docs` is already added.
- **Stale facts:** the plan hard-codes counts (960 commits, 486 downloads, v0.3.62). Treat them as a snapshot and re-verify before use.
- **Version bump:** say who bumps to 0.3.63. §11 forbids it in the PR; the nightly job ships whatever is in the TOC.

### Action plan: strengths
- Correct order (licence first; the repo has none), PR only, no release or tag, no hand-edited generated data.
- The "do not invent features" and "do not touch third-party LICENSE" constraints are good.
- Acceptance criteria are concrete.

### Roadmap to 10/10: findings
- **Direction is right:** polish and cohesion over feature count.
- **Strongest items:** §4 architecture, §5 accuracy, §3 "what should I do next?" dashboard.
- **Missing, measurable targets.** Replace vague checkboxes with numbers, e.g. luacheck at zero warnings, tests for pure-logic modules, regression cases per release, no file over about 1,500 lines.
- **§4 is backed by evidence from this assessment:**
  - `ns.db` is referenced about 225 times directly (accessor layer, task 5 above).
  - The largest hand-written files are 1,400 to 2,400 lines (split, task 4 above).
  - 176 `pcall` uses and a custom `Errors.lua` already exist, so "standardize error handling" means consolidating, not starting.
  - There is no SavedVariables version or migration code (grep for `migrat`/`schema`/`dbVersion` finds none), so "implement migrations" is new work. Do it before the next saved-data schema change.
- **§5 accuracy:** most data is generated by `tools/`, so validate in the generators and add sanity checks there (e.g. fail the build when a spell, item or recipe ID is missing), not only manual spot tests.
- **Mixed scope.** §1, §2, §7 and §8 are website, CurseForge and community work and do not belong in this repo's PRs. Keep them as a separate track from the code items (§3 to §6).
- **Overlap with the action plan:** roadmap §7 (bug process, changelog) and §8 (docs) are covered by action plan §7 and §9. Do these once.

### Suggested combined order
1. Remove chess (action plan §5, Option B); add `.luacheckrc` and CI lint (task 1 above).
2. Licence, README, templates, `check.yml` (action plan §4, §7, §8).
3. Lint cleanup and PalRun/DailyWord tests (tasks 2 to 3 above).
4. File splits and `ns.db` accessors (tasks 4 to 5 above); add SavedVariables migrations.
5. Dashboard intelligence and visual consistency (roadmap §3, §6), after the architecture is cleaner.
6. Website, CurseForge and community items (roadmap §1, §2, §7, §8) as a separate track.
