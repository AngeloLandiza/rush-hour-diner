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
