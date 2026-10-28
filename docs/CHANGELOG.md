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

## Wave 2: Integration, balance and launch kit (2026-10-28)

### Integration (F, static review; no Studio access)
- **Glue fixes:**
  - `GetSnapshot` waits for the profile
  - the R15 check covers players already in the server
  - PropBuilder now boots before MapBuilder
- **Fixes routed to owners:**
  - `WaitForData` returned nil before loading started, so a player could end up with no plot (critical, A)
  - the Serve prompt was hidden by the station prompt (now AlwaysShow on F/ButtonY) (C)
  - a crew member's plot id was wrong on the client (D)
  - serve stats and the legendary SFX fired twice (C)
  - `DebugAllPasses` didn't work with placeholder ids (A)
  - the station panel stayed open beyond the server's interact range (D)
  - minor HUD, tutorial and crew-broadcast fixes
- The onboarding analytics funnel is logged from events in AnalyticsService.
- ProximityPrompt key and exclusivity conventions were added to WorldSchema.

### Balance (G)
- Retuned costs, offline rate, streak rewards and the large coin pack.
- All 13 upgrades take 7h27m free and 4h56m with the pass (66%).
- The longest wait is 24% of progression.
- Details are in `docs/ECONOMY.md`.

### Launch kit (H)
- `docs/LAUNCH.md` covers the Creator Hub product table, titles, descriptions, icon, thumbnails, 10 Shorts scripts and maturity guidance.

## Wave 3: Security review, Studio playtests, art and UI overhaul (2026-10-28)

### Security and compliance review (I, fresh context)
- No Critical or High findings. ProcessReceipt is idempotent, and all 12 remotes are validated.
- **Fixed:**
  - Instant Restock now pays out pending plus a full restock.
  - A failed save session no longer steals another server's session.
  - Per-player state no longer leaks after a yield.
  - The ad availability check fails closed.
  - Crew joins are re-validated after the friendship yield.
  - Guard rate-limits before walking the payload.
- **Documented:** Max Players 6 and the R15 universe setting, in `docs/LAUNCH.md`.
- **Open (Low):** distance checks trust the character's position, so movement isn't verified server-side.

### Studio playtests (orchestrator, via the Studio MCP)
- **Verified end to end:**
  - join → R15 → plot claim → customers within seconds
  - cook (Start/Flip/Collect) → serve (F) → payout → HUD
  - streak, upgrade purchase, and rejected exploit probes
  - Rush Hour on the hour, with lighting, neon and HUD
  - a legendary spawn, the server-wide announcement and banner, and a 312-coin tip
- **Fixed from the playtests:**
  - customers standing on stools, and missing faces
  - Rush preset washed out, then overcorrected
  - legendaries lost when seats were full
  - blank crew sign
  - Serve prompts firing together
  - bulbs covering the menu board
- **Added:** Studio-only debug hooks (`workspace` attributes `DebugRushNow`, `DebugLegendary`, `DebugAllPasses`).

### Art overhaul (Opus)
- Retro diner decor tiers, a detailed street, chrome stations, and the `RushNeon` tag on 160 neon parts.
- Generated meshes for the dishes and the bot, loaded at runtime from `Config/Art` with primitive fallbacks.
- Fixed stations sitting below the floor.
- 2,492 parts at max decor.

### UI redesign (Opus, "Neon Diner Pop")
- A research-backed `docs/UI_STYLE.md`.
- Icon stickers, 3D press buttons, a currency count-up with coin fly, and a neon Rush bar.
- Patience-ring bubbles, custom prompts and a coach-mark tutorial.
- Verified in Studio across 4 rounds, including 360×640 portrait and landscape.
