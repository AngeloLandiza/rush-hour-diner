# Changelog

## Wave 0: Scaffold and contracts (2026-10-28)

### Added
- **Toolchain** (pinned with rokit): rojo 7.7.1, wally 0.3.2, selene 0.32.0, stylua 2.6.0, luau-lsp 1.70.1, lune 0.11.1 and wally-package-types 1.7.0.
- **Packages:**
  - from Wally: Promise 4.0.0, Signal 2.0.3 and Trove 1.8.0
  - vendored: ProfileStore (commit `45c9847`) in `vendor/`
- **Rojo tree:**
  - R15-only (`StarterPlayer.GameSettingsAvatar`)
  - Future lighting
  - TextChatService
- **Contracts:** `Types`, `Remotes`, `Events` and `WorldSchema`.
- **Glue:**
  - `Shared/Net` creates and looks up the remotes
  - `Server/Util/Guard` handles rate limits and payload validation
  - `init.server.luau` boots the server, provides the `GetSnapshot` remote and runs the R15 check
- **Stubs with the final public API:**
  - all services, World modules, VFX presets and client controllers
  - all `Logic/*` modules
- **Config stubs:** Stations, Dishes, Upgrades (13 levels), Customers, Economy, Products (placeholder IDs), Timings, Palette, Lighting and Audio.
- **Tests and checks:**
  - a Lune test runner (`lune run tools/test`) and smoke test
  - `tools/check.sh` runs the same checks as CI
- **CI:**
  - `ci.yml` runs StyLua, Selene, luau-lsp strict, Lune and `rojo build`
  - `publish.yml` publishes through Open Cloud. It's gated behind `vars.PUBLISH_ENABLED == 'true'`
- **Docs:** `ARCHITECTURE.md`, `GDD.md`, `CLAUDE.md`.

### Decisions
- Upgrades total 13 levels, following the spec's itemized list rather than its "12" summary.
- Serve coins go to the serving player. Bot serves go to the plot owner.
- Rush Hour Now during an active rush extends the current rush instead of being refused.
- Auto-Chef pass pays in-game AFK income through `Logic/Offline.autoChefIncome`.

## Wave 1: Core game (2026-10-28)

### Added
- **Economy Logic (B):**
  - pure Cooking, Economy, Orders, Upgrades, Offline, Streak and Schedule modules
  - 120 Lune tests
  - `tools/econ_sim`: the first upgrade takes 51s (free) or 40s (2× Tips), and all 13 levels take 7h18m (free) or 4h46m (2× Tips)
- **Data & Purchases (A):**
  - ProfileStore sessions with v1 migrations
  - idempotent ProcessReceipt (grant, then record, then confirmed save, then acknowledge)
  - pass caching and a Studio `DebugAllPasses` hook
  - opt-in rewarded ads through AdService
  - OrderedDataStore lifetime leaderboard, server best-Rush-Hour board and leaderstats
- **Gameplay (C):**
  - plots auto-claimed on join, friends-only crew, filtered crew names
  - server-timed cook state machine with ProximityPrompts
  - R15 customers with walking, seating, patience and serving
  - legendary announcements
  - Rush Hour scheduler (Rush Hour Now extends an active rush)
  - auto-server bot and Auto-Chef AFK income
- **World, Look & Sound (E):**
  - a 6-plot street with diner shells for decor tiers 0–2
  - station, dish and bot props
  - Day and Rush lighting with a tween between them
  - VFX presets
  - SoundGroups and an audio director
  - 7 generated SFX WAVs
  - Open Cloud asset uploader (`--dry-run`)
- **Client & UI (D):**
  - state store, theme and components
  - HUD: coins, an always-on Rush countdown, streak, restock, menu drop, boosts, combo
  - shop for upgrades, passes, products and the ad opt-in
  - station minigame
  - order bubbles, toasts and the legendary banner
  - 60-second tutorial
  - coin and tip FX
  - crew, settings and leaderboard panels
  - `[VIP]` chat tag

### Contract changes
- `Types.LegendaryAnnouncement.text` was added.
- Timings now holds the data, retry, walk, tick, lift and grip constants.
- The `FX` attachment now lives under `Interact`.

### Known gaps
- Audio and music IDs are still 0. They need the asset upload and licensed music IDs.
- Product and pass IDs are still placeholders.
- Nothing has been playtested in Studio yet. That's Wave 2.
