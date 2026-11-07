# jsal.ui 0.3.14

- **Fixed:** the "jsalUI has been blocked from an action only available to the Blizzard UI" message at login. The Journal asked the game for its combat log, which WoW Forever keeps from addons.
  - The Journal now counts your kills from the game's own statistics, notes a rare's first kill when a rare you're targeting dies, and shows Dungeon bosses and Flights taken where Damage dealt and Healing done were (Forever doesn't give addons those). A death is noted without its cause.
- **Updates tell you what they need:** after updating, a /reload is enough for this one. From now on, when an update adds files and needs a full restart, jsal.ui says so after your /reload, and the guild's "newer version" notice says which one it needs.
