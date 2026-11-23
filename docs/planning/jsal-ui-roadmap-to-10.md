# JSAL.UI — Roadmap to 10/10

A practical improvement plan for taking JSAL.UI from a well-presented WoW Forever addon to a polished, reliable, cohesive software product.

## Guiding principle

Treat this as a product-polishing exercise, not a redesign. Preserve the existing **Plan / Craft / Play** hierarchy and focus on making the current features more cohesive, dependable, discoverable, and useful.

---

## 1. Landing page & conversion

**Priority: Critical**

The landing page should turn visitors into addon users.

- [ ] Keep the existing hero headline: **“From level 1 to raid night, planned.”**
- [ ] Add a supporting sentence that explains Plan, Craft, and Play.
- [ ] Add a visible CurseForge rating and download count, if available and kept current.
- [ ] Add a second installation CTA after the feature showcase.
- [ ] Clarify the distinction between 11 primary features and 36 independently configurable components.
- [ ] Add a small “What’s new” indicator near the download button.
- [ ] Explain what the Discord community offers: support, discussion, and feedback.

Suggested supporting copy:

> Plan your character, master your professions, support your guild, and enjoy everything WoW Forever has to offer.

Keep the existing headline; the supporting sentence should explain the functionality rather than compete with it.

## 2. Feature presentation

**Priority: Critical**

The feature descriptions are already a strong foundation. Make each feature’s value immediately understandable.

- [ ] Standardize screenshot dimensions and presentation.
- [ ] Ensure each screenshot shows the feature at its best.
- [ ] Add small contextual labels to complicated screenshots where they improve comprehension.
- [ ] Give flagship features more visual prominence.
- [ ] Explain how related features work together.
- [ ] Distinguish primary features from smaller helpers.

### Suggested flagship features

Give these five particular prominence:

1. Home Dashboard
2. Training Planner
3. Build Planner
4. Gear Planner
5. Guild Crafts

Keep the other features discoverable; prominence does not mean hiding them.

## 3. Home dashboard

**Priority: Critical**

Evolve Home from an information display into a character activity center.

- [ ] Surface the next available training milestone.
- [ ] Show the next talent recommendation.
- [ ] Highlight a worthwhile equipment upgrade.
- [ ] Show upcoming dungeon objectives.
- [ ] Show profession milestones.
- [ ] Identify incomplete objectives.
- [ ] Allow users to customize dashboard sections.

**Important:** Do not simply add more cards. Prioritize information according to the character’s level and progression. A level 12 character should not see the same priorities as a level 60 character.

The dashboard should answer: **“What should I do next?”**

## 4. Technical architecture

**Priority: Critical**

Before expanding the feature set, make sure the growing addon remains maintainable.

- [ ] Centralize shared character data.
- [ ] Standardize module initialization.
- [ ] Establish consistent event registration and cleanup.
- [ ] Audit unnecessary `OnUpdate` handlers.
- [ ] Audit SavedVariables growth and retention.
- [ ] Standardize error handling.
- [ ] Implement SavedVariables migrations.
- [ ] Establish a shared UI component library.
- [ ] Ensure modules initialize only when necessary.

### Shared data layer

Features should consume shared information rather than independently maintaining duplicate character state.

```text
Character Data
    |
    ├── Training
    ├── Build
    ├── Gear
    ├── Dungeons
    ├── Endgame
    └── Professions
```

A shared data layer can reduce duplication and make future integrations between features easier.

## 5. Feature accuracy and reliability

**Priority: Critical**

Recommendations must be accurate. Establish a repeatable testing process.

- [ ] Validate talent recommendations.
- [ ] Verify trainer spell availability.
- [ ] Verify equipment sources and drop locations.
- [ ] Validate dungeon loot tables.
- [ ] Test profession recipes and requirements.
- [ ] Test different classes and specializations.
- [ ] Test fresh characters and existing characters.
- [ ] Test level transitions, especially 59 → 60.
- [ ] Maintain a regression checklist for every release.

The number of systems covered makes it important not to rely exclusively on manual spot-checking.

## 6. Branding and visual identity

**Priority: High**

Preserve the recognizable dark interface and gold accents. Improve consistency rather than radically changing the visual direction.

- [ ] Establish consistent spacing values.
- [ ] Standardize typography hierarchy.
- [ ] Standardize button styles and states.
- [ ] Standardize cards and information panels.
- [ ] Improve empty states.
- [ ] Improve loading and unavailable states.
- [ ] Audit long text and small interface elements for readability.
- [ ] Review scaling at different UI resolutions.

Watch visual density. Information hierarchy is more important than showing every available piece of information at once.

## 7. Community and adoption

**Priority: High**

Build a transparent feedback loop with the WoW Forever community.

- [ ] Establish a public feature roadmap.
- [ ] Create a dedicated bug-reporting process.
- [ ] Maintain a public changelog.
- [ ] Encourage feature requests through Discord.
- [ ] Publish short feature demonstrations.
- [ ] Create a quick-start guide.
- [ ] Highlight community contributions.

Consider a community showcase where players can share builds, progression plans, or guild crafting activities.

## 8. Website, documentation and SEO

**Priority: High**

Expand supporting content rather than making the main landing page excessively long.

- [ ] Create individual feature documentation pages.
- [ ] Add installation troubleshooting.
- [ ] Add a complete feature reference.
- [ ] Clearly list supported versions.
- [ ] Add structured FAQ content.
- [ ] Publish feature tutorials.
- [ ] Link relevant documentation from the addon.

Keep the website, GitHub, and CurseForge aligned on version information, feature counts, and installation instructions.

---

## Recommended implementation order

Avoid tackling every workstream simultaneously. Use this sequence:

| Phase | Focus | Priority |
|---|---|---|
| 1 | Landing page conversion improvements | Immediate |
| 2 | Technical architecture audit | Immediate |
| 3 | Feature accuracy and regression testing | Immediate |
| 4 | Dashboard intelligence | High |
| 5 | Visual consistency and UI polish | High |
| 6 | Documentation and onboarding | Medium |
| 7 | Community growth | Medium |
| 8 | Additional integrations and features | Later |

## 10/10 acceptance criteria

| Category | 10/10 standard |
|---|---|
| Product identity | Instantly recognizable and understandable |
| Navigation | Every feature is easy to locate |
| Dashboard | Provides genuinely useful next actions |
| Functionality | Features work reliably across supported classes and levels |
| Performance | No unnecessary background processing |
| Architecture | Modular, maintainable, and extensible |
| UI | Consistent, readable, and polished |
| Onboarding | New users understand the addon quickly |
| Documentation | Complete and easy to navigate |
| Community | Feedback and development are transparent |
| Marketing | Visitors understand the value and know how to install |

## The five highest-priority assignments

If development time is limited, start here:

1. **Technical audit:** Establish whether the current architecture can comfortably support another year of development.
2. **Dashboard intelligence:** Make Home the central progression hub.
3. **Accuracy audit:** Verify every recommendation-producing feature.
4. **Conversion polish:** Add social proof, clarify the 36 components, and improve installation CTAs.
5. **Onboarding:** Make the first 10 minutes with the addon exceptional.

## What to avoid

Do not chase feature count. Another five features will not necessarily make JSAL.UI better.

Make the existing components feel like one cohesive, dependable product.

The ultimate goal:

> A player installs JSAL.UI at level 1, finds it useful immediately, and still has a reason to open it every time they play at level 60.
