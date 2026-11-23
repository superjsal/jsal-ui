# jsal.ui — Action Plan for Claude

> Relay this file to Claude as the brief. Work in the repo below. Do not publish, tag, or release anything until the owner approves. Open the work as a branch / PR, not a direct push to `main`.

## 1. Context

- **Project:** jsal.ui — a free WoW Forever addon. One dashboard for leveling 1–60 and raid night at 60: training, talents, gear, dungeons, professions, guild crafting, journal, daily games, and a pal to raise.
- **Landing page:** https://jsal.io/jsal-ui/
- **Repo:** https://github.com/superjsal/jsal-ui — public, `main`, Lua
- **CurseForge:** https://www.curseforge.com/wow/addons/jsal-ui — author `superjsal`
- **Wago:** linked from the repo TOC, X-Wago-ID `aND9B96o`
- **Author / maintainer:** John Salvador — dev@jsal.io — Discord (jsal.ui Discord, linked on jsal.io and CurseForge)
- **Current version, verified 23 Nov 2026:** **v0.3.62**, released 23 Nov 2026
  - jsal.io, GitHub, and CurseForge all agree on v0.3.62 / 23 Nov 2026.
  - 0.3.62 adds: new Endgame page, Dungeon guide Trash cards, flight-bar timing fixes, quest-reward upgrade arrows.
  - Game version: WoW Forever **1.60.1**. TOC: `Interface: 16001`, `Version: 0.3.62`, `Author: John Salvador`, `OptionalDeps: EllesmereUI, RXPGuides, Auctionator`, `SavedVariables: jsalUIDB`, `SavedVariablesPerCharacter: jsalUICharDB`, `X-Curse-Project-ID: 1788011`.

## 2. Current state (verified 23 Nov 2026 — do not re-derive, verify before changing)

- GitHub: 960 commits, 76 releases/tags, 0 stars, 0 watchers, 1 fork, 1 open issue (`Forever data check`, #1, from 16 Nov 2026).
- Repo size: ~50 MB, 861 files, 118 Lua files. Largest Lua files are generated data tables (e.g. `DailyWordData.lua`, `GearData.lua`, `QuestScoreData.lua`), not hand-written logic.
- Layout: `jsalUI/` (addon), `data/` (generated source data), `tools/` (~45 Python/JS builders), `.github/workflows/` (`release.yml`, `nightly.yml`, `data-check.yml`), `.pkgmeta`, `CHANGELOG.md`, `README.md`.
- Release flow (do not break it): pushing a `v*` tag runs BigWigs packager and publishes to GitHub Releases, CurseForge, and Wago. Nightly job ships a queued TOC version at 08:00 UTC. Weekly data-check job maintains the single `Forever data check` issue.
- CurseForge: 486 total downloads, updated 2026-11-23T03:11:36Z, category Quests & Leveling, 12 screenshots. Description is the most detailed of the three surfaces.
- jsal.io: 36 parts, 3 groups (Plan, Craft, Play), every part has its own toggle in Settings. Install: GitHub zip into `World of Warcraft\_forever_\Interface\AddOns` (folder `jsalUI`), or CurseForge / Wago apps. Opens with `/jsal` or the minimap button.

## 3. Goal

Close the documentation / discoverability / consistency gaps found in the 23 Nov 2026 assessment, without changing gameplay logic. Ship the result together as **v0.3.63** only after the owner reviews the PR.

**Out of scope:** no new features, no balance/data changes, no UI redesign, no in-game review prompts, no changes to `data/` tables by hand (see §7), no changes to the release / nightly / data-check workflows except the new check workflow in §8.

**Constraints:**
- Do not invent features. Use the CurseForge description and the code as the source of truth for what the addon does.
- Do not touch `data/gear/wowsims-forever/LICENSE` or any third-party attribution.
- Do not add secrets, tokens, or credentials. Do not commit `.env` or API keys.
- Keep the tone of existing copy: plain, direct, player-facing. No marketing hype.
- Every file you add must be listed in §10 verification.

## 4. P0 — Do first

### 4.1 Add a license (blocking)

- [ ] Choose **MIT** (owner's decision — do not switch to GPL without asking).
- [ ] Create `LICENSE` at the repo root with the full MIT text below, copyright John Salvador, 2026:

```text
MIT License

Copyright (c) 2026 John Salvador

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

- [ ] Verify GitHub detects the license (repo header shows MIT) after the PR merges.
- [ ] Verify the next release zip (do not release yet — check `.pkgmeta` / packager output) includes `LICENSE`. It is not in the `.pkgmeta` ignore list, so it should ship; confirm, don't assume.
- [ ] Update wording everywhere the addon is called just "free": README → "Free, MIT-licensed"; jsal.io → "Free, open source" (see §6, owner edits the site separately — list the exact wording change in the PR description, do not edit the site repo here).

**Acceptance:** `LICENSE` exists at root, GitHub shows MIT, README has a License section linking to it.

### 4.2 Rewrite the README (`README.md`, currently 815 bytes)

Replace the current README with a complete one. Required sections, in order:

1. Title + tagline: "Your road to 60 in WoW Forever, planned." + one screenshot (`https://jsal.io/img/jsal-ui/store/cards-0362/01-home.jpg` or the existing dashboard image).
2. Badges: version (v0.3.62 → update to v0.3.63 on release), license MIT, CurseForge link.
3. **What's in it** — table by group:
   - Plan: Training Planner, Build Planner, Gear plan, Dungeon guide, Endgame
   - Craft: Professions, Guild Crafts, Crafting profit
   - Play: Journal, Daily games, Jsal's Pals
   - Plus "And the little things": Quick buttons, Unlock Mode, Flight bar, Waypoint label, Vendor run, Bag and gear warnings, Quest reward upgrades, Quest tags.
   - Source the descriptions from the CurseForge page, not from memory. Do not add Chess here until §5 is decided.
4. **Install:** CurseForge, Wago, GitHub zip (`World of Warcraft\_forever_\Interface\AddOns\jsalUI`), log in / restart, type `/jsal`.
5. **Commands:** `/jsal` plus `journal`, `gear`, `dungeons`, `crafts`, `profit`, `shop`, `word`, `icons`, `run`, `pet`, `recap`, `welcome`, `unlock`, `bug`.
6. **Settings defaults — state these explicitly:** almost everything is on by default; the **talent helper and the gear goal for 60 are off** until turned on in Settings. Every part has its own toggle.
7. **Compatibility:** works alongside EllesmereUI and RestedXP Guides; Auctionator is used for Crafting profit prices when present. Nothing heavy runs in combat; jsal.ui never reads the combat log.
8. **Data sources:** WoWSims Forever stat weights, Wowhead Forever data, Forever game tables, player-contributed trainer/vendor/quest data. Credit Santiago Reyes for Forever dungeon maps (Atlas de Azeroth: Forever), used with permission.
9. **Support:** Discord, dev@jsal.io, Report a problem inside the addon (`/jsal bug`).
10. **Contributing / Changelog / License:** link to `CONTRIBUTING.md`, `CHANGELOG.md`, and `LICENSE`.

**Acceptance:** a stranger can install and use the addon from the README alone, without opening jsal.io or CurseForge. No feature is listed that is not in the code or on CurseForge.

### 4.3 GitHub repo settings (owner to apply, or list exact steps in the PR)

- [ ] About → Homepage: `https://jsal.io/jsal-ui/`
- [ ] Topics (add all): `wow`, `world-of-warcraft`, `wow-addon`, `wow-forever`, `vanilla-wow`, `leveling`, `lua`
- [ ] Confirm Issues are enabled.

## 5. P0 — Decide Chess (do not leave orphaned)

Investigate first, then do exactly one of A or B. Do not do both, do not leave it undecided.

- [ ] Inspect: `jsalUI/Games/ChessRules.lua`, `jsalUI/Games/Chess.lua`, `jsalUI/Games/ChessPage.lua`, their entries in `jsalUI/jsalUI.toc`, and any registration in `jsalUI/Settings.lua` / `jsalUI/Games/Games.lua`.
- [ ] Answer in the PR description: Is Chess registered in Settings? Is it playable? Is it listed anywhere player-facing?
- [ ] **Option A — Ship it:** add Chess to jsal.io Daily games, CurseForge Play section, and README §4.2, with a screenshot. List the exact copy changes needed on jsal.io / CurseForge in the PR description (do not edit those sites here).
- [ ] **Option B — Remove it:** delete the three Chess files, remove them from `jsalUI.toc`, remove any Settings / Games registration, and add one line to `CHANGELOG.md` for the next release noting the removal.
- [ ] **Acceptance:** TOC, Settings, jsal.io, CurseForge, and README all list the same games. No Chess file remains unreferenced, and no marketing page mentions a game that is not in the TOC.

## 6. P1 — Make jsal.io, CurseForge, and README match

Create and apply this single checklist to all three surfaces. Where a surface lives outside this repo (jsal.io, CurseForge), list the exact edit in the PR description instead of editing it here.

| Field | Correct value |
|---|---|
| Version | v0.3.62 now; v0.3.63 on release |
| Tagline | From level 1 to raid night in WoW Forever, planned |
| Parts | 36 parts, 3 groups (Plan, Craft, Play), each with its own toggle |
| Defaults | Talent helper and gear goal for 60 are off by default; everything else on |
| Requirements | WoW Forever 1.60.1 |
| Install | GitHub zip / CurseForge / Wago; `/jsal` or minimap button |
| Links | jsal.io, GitHub, CurseForge, Wago, Discord, dev@jsal.io |

- [ ] jsal.io: add the defaults note and a link to the full changelog.
- [ ] CurseForge: confirm description and 12 screenshots are the 0.3.62 set; add a short FAQ: Is it really free? Does it work with EllesmereUI / RestedXP? Does it run in combat?
- [ ] README: apply §4.2.

**Acceptance:** no feature appears on one surface that is missing or contradicted on another.

## 7. P1 — Contributing, security, templates

- [ ] Create `CONTRIBUTING.md`:
  - How to report a bug: version, class/level, what happened, what you expected, steps to reproduce, `/jsal bug` output if available.
  - How to suggest a data fix (trainer price, drop, recipe, quest): say where the data came from.
  - **Rule: do not hand-edit generated data tables in `jsalUI/` (`*Data.lua`, `GearData.lua`, `DungeonLoot.lua`, etc.). Regenerate via `tools/` — see §9.**
  - How to submit a PR: branch, one change per PR, run the check workflow (§8) first.
  - Pre-release manual checklist: fresh character, mid-level character, level 60 character, `/reload` after update, check the new Endgame page.
- [ ] Create `SECURITY.md`: report privately to dev@jsal.io; do not open a public issue for anything sensitive.
- [ ] Create `.github/ISSUE_TEMPLATE/bug_report.yml` — fields: version, game version, class/level, description, steps, expected, actual.
- [ ] Create `.github/ISSUE_TEMPLATE/feature_request.yml` — fields: what, why, which part (Plan / Craft / Play / little things).
- [ ] Create `.github/PULL_REQUEST_TEMPLATE.md` — fields: what changed, why, how tested, checklist (no generated data hand-edited, check workflow passes).

**Acceptance:** a bug report filed with these templates contains version + steps, not just "it broke."

## 8. P1 — Minimal QA in CI

- [ ] Create `.github/workflows/check.yml` — runs on push and pull requests:
  - Syntax-check every Lua file under `jsalUI/` (e.g. `luac -p` or the Lua version already used in CI; if no Lua is available in the runner, install it explicitly — do not silently skip the check).
  - Fail if the version in `jsalUI/jsalUI.toc` does not match the pushed tag (on tag pushes only).
  - Do not change `release.yml`, `nightly.yml`, or `data-check.yml`.
- [ ] Test the workflow on the PR branch and paste the run link / result in the PR description.

**Acceptance:** a Lua file with a syntax error cannot reach a tag; the check run is green on the PR.

## 9. P2 — Document the data pipeline

- [ ] Create `tools/README.md`:
  - What each builder does (at minimum: `build_gear.py`, `build_dungeons.py`, `build_spells.py`, `build_professions.py`, `build_talents.py`, `build_trainers.py`, `build_words.py`, `build_consumables.py`, `fetch_tables.py`, `what_changed.py`).
  - Its source for each: Forever game tables, Wowhead Forever, WoWSims Forever, EG Link / player data.
  - How to regenerate after a new Forever build, and in what order.
  - Note that `data/` is generated source and `jsalUI/*Data.lua` is generated output — fixes go in `tools/`, not in the output files.
- [ ] Cross-link it from `CONTRIBUTING.md` §7.

## 10. P2 — Discoverability

- [ ] CurseForge + Wago: verify both show the same version, description, and links as §6. List any drift in the PR description.
- [ ] Do not add in-game review prompts.

## 11. Verification — run before asking for review

- [ ] `LICENSE` exists at root; GitHub detects MIT.
- [ ] `README.md` covers all 10 sections in §4.2; all links work.
- [ ] No Chess orphan: §5 A or B is complete, with the decision recorded in the PR description.
- [ ] `CONTRIBUTING.md`, `SECURITY.md`, issue templates, PR template exist and render.
- [ ] `tools/README.md` exists and lists every builder it claims to cover.
- [ ] `.github/workflows/check.yml` is green on the PR branch.
- [ ] No gameplay Lua changed except Chess removal (Option B) — list every changed Lua file in the PR description.
- [ ] No version bump, tag, or release in this PR. Version bump to 0.3.63 happens only when the owner approves the release, via the existing nightly/tag flow.
- [ ] PR description includes: (1) Chess decision, (2) exact jsal.io edits needed, (3) exact CurseForge edits needed, (4) check workflow run link, (5) files changed.

## 12. Suggested order

1. §4.1 License
2. §4.2 README
3. §5 Chess decision
4. §7 Contributing / security / templates
5. §8 Check workflow
6. §9 tools/README
7. §6 consistency list (as PR-description edits for jsal.io / CurseForge)
8. Owner review → bump to v0.3.63 via the existing release flow

---

*Source: assessment of https://jsal.io/jsal-ui/, https://github.com/superjsal/jsal-ui, and https://www.curseforge.com/wow/addons/jsal-ui on 23 Nov 2026, v0.3.62. Prepared 23 Nov 2026.*
