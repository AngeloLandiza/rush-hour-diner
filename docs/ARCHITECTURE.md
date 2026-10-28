# Rush Hour Diner: Architecture

Source of truth for module boundaries, boot order, public APIs and data flows. Product spec: `docs/GDD.md`. Process rules: `docs/ORCHESTRATOR.md`.

## 1. DataModel layout (Rojo, `default.project.json`)

| Filesystem | DataModel |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` (Contracts, Config, Logic, VFX, Net) |
| `Packages` (Wally, generated) | `ReplicatedStorage.Packages` (Promise, Signal, Trove) |
| `vendor` | `ServerStorage.Vendor` (ProfileStore, pinned commit `45c9847`) |
| `src/server` | `ServerScriptService.Server` (`init.server.luau`, Services, World, Util) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` (`init.client.luau`, Controllers, UI) |

`StarterPlayer.GameSettingsAvatar = R15` (also set it in Creator Hub → Avatar). Lighting technology is Future.

## 2. Conventions

- `--!strict` in every file. StyLua formats (`tools/check.sh --fix`). Selene (`std = roblox`) lints `src`.
- **Requires.** Inside `src/shared` use relative string requires (`require("../Contracts/Types")`) so Lune can load Logic/Config. Everywhere else use instance paths (`require(ReplicatedStorage.Shared.Config.Dishes)`, `require(script.Parent.X)`).
- **Pure layer.** `Shared/Logic/*` and every `Shared/Config/*` except `Palette`, `Lighting` must not touch Roblox globals (`game`, `Instance`, `Color3`, `workspace`, `task`, `os.clock`). Time and randomness are parameters (`now`, `rng`).
- **No magic numbers.** Gameplay numbers live in `Config/`. Colors only from `Config/Palette`.
- **Modules.** Every service/controller/world module returns a table with `Init()` and `Start()`. `Init` sets up state and connects signals (no yielding). `Start` may yield and starts loops.
- **Cross-service calls.** A service may `require` and call the public functions (section 4) of services that boot **before** it. Anything else goes through `Contracts/Events` signals. Never reach into another module's private state.
- **Remotes.** All remotes are declared in `Contracts/Remotes` and accessed with `Shared/Net` (`Net.event(name)`, `Net.func(name)`). Server handlers are registered only through `Server/Util/Guard.onEvent` / `onInvoke` (rate limit from `Config/Timings.RateLimits`, payload must be a plain table or nil, errors isolated). Handlers then validate every field (type, range, enum membership) and ownership (`PlotService.IsMember`, `Guard.isNear`).
- **Server authority.** The client only expresses intent ("start cooking slot 2", "serve customer 17"). Coins, timers, cook results, payouts and purchases are computed on the server.
- **Luau quirk:** `pcall(fn)` where `fn: () -> ()` fails strict typecheck; wrap it: `pcall(function() fn() end)`.
- **Commits:** one per agent task, `feat(<area>): …`. Run `tools/check.sh` before returning.

## 3. Boot order

Server (`src/server/init.server.luau`): `Net.setupServer()`, then `Init()` of each, in order, then `Start()` of each (spawned), in order:

1. AnalyticsService
2. DataService
3. RushHourService
4. PurchaseService
5. LeaderboardService
6. PropBuilder
7. MapBuilder (builds the world in `Init` using PropBuilder, so later services can find plots in their `Init`)
   - StationVisuals (World) boots right after MapBuilder. It drives station food states and VFX from the `Phase`/`Quality` slot attributes.
8. LightingDirector
9. AudioDirector
10. PlotService
11. StationService
12. CustomerService

The `GetSnapshot` RemoteFunction is glue in `init.server.luau` (composed from public APIs).

Client (`src/client/init.client.luau`): State, InputController, SettingsController, HUDController, ShopController, StationController, CustomerController, NotifyController, FXController, TutorialController. Every `Start` waits for `State.waitReady()`. Client state comes from `GetSnapshot` once, then incremental server→client events.

## 4. Public functions per module

Signatures are fixed in the stub files; changing one is a contract change (request it from the orchestrator).

| Module (owner) | Public API |
|---|---|
| **AnalyticsService** (orch.) | `LogEvent(player, name, value?)`, `LogEconomy(player, "Source"\|"Sink", amount, balance, transactionType, sku?)`, `LogOnboarding(player, step, stepName)` |
| **DataService** (A) | `GetData(player): PlayerData?`, `WaitForData(player, timeout?)`, `GetView(player): PlayerDataView?`, `AddCoins(player, amount, reason): number`, `SpendCoins(player, amount, reason): boolean`, `Update(player, mutator)`, `AddBoost(player, boost, seconds)`, `CollectRestock(player, full): number`, `HasReceipt(player, purchaseId)`, `RecordReceipt(player, purchaseId)`, `SaveAndConfirm(player): boolean`, `PushSync(player)` |
| **RushHourService** (C) | `GetState(): RushHourState`, `IsActive(): boolean`, `TriggerNow(buyer?): boolean`, `GetSpawnMultiplier(): number` |
| **PurchaseService** (A) | `OwnsPass(player, pass): boolean`, `GetPasses(player)`, `GetTipBoostPct(player): number` |
| **LeaderboardService** (A) | `GetSnapshot(): LeaderboardSnapshot` |
| **MapBuilder** (E) | `GetPlotModel(plotId)`, `ApplyDecor(plotId, tier)`, `SetSeatCount(plotId, n)`, `SetStationSlots(plotId, n)`, `SetSignText(plotId, filteredText)`, `SetVIPBooth(plotId, enabled)` |
| **PropBuilder** (E) | `MakeStation(stationId): Model`, `MakeDish(dishId): Model`, `MakeAutoServerBot(): Model` |
| **LightingDirector** (E) | `Apply(presetName, instant?)` |
| **AudioDirector** (E) | `PlaySfx(name, parent?)` |
| **Shared/VFX/Presets** (E) | `Create(name, parent): ParticleEmitter`, `Burst(name, parent, scale?)` |
| **PlotService** (C) | `GetPlotOf(player)`, `GetOwnedPlot(player)`, `GetOwner(plotId)`, `GetMembers(plotId)`, `IsMember(player, plotId)`, `GetPlotInfo(plotId)`, `GetAllPlotInfo()` |
| **StationService** (C) | `GetHeldItem(player)`, `TakeHeldItem(player)`, `GetStations(plotId)`, `GetAllStates()`, `TakeReadyDish(plotId, dishId)` |
| **CustomerService** (C) | `GetCustomer(id)`, `GetCustomersOnPlot(plotId)`, `GetAllViews()`, `SpawnLegendary(plotId, legendaryId)` |
| **Logic/Economy** (B) | `computePayout(ctx): Payout`, `crewMultiplier(crewSize)`, `nextCombo(combo, wait, patience)`, `tipBoostPct(boosts, now)` |
| **Logic/Orders** (B) | `rollKind(rng, rush): (kind, legendaryId?)`, `pickDish(rng, kind, legendaryId?, available)`, `patienceSeconds(kind, legendaryId?, ownerUpgrades)`, `spawnInterval(rush)`, `remainingPatience(order, now)` |
| **Logic/Upgrades** (B) | `getLevel`, `nextCost`, `canBuy(levels, coins, id): (ok, reason?)`, `stationSpeedMultiplier`, `seatCount`, `patienceMultiplier`, `tipMultiplier`, `decorTier`, `decorTipPct`, `hasAutoServer`, `totalLevels` |
| **Logic/Offline** (B) | `coinsPerMinute(levels)`, `pending(lastRestock, now, levels)`, `fullRestock(levels)`, `autoChefIncome(levels, seconds)` |
| **Logic/Streak** (B) | `dayIndex(now)`, `canClaim(streak, now)`, `claim(streak, now): (streak, reward)` |
| **Logic/Schedule** (B) | `rushHourState(now)`, `nextRushHourAt(now)`, `nextMenuDropAt(now)` |
| **Logic/Cooking** (B) | `schedule(dishId, ownerUpgrades): CookSchedule`, `advance(state, now, sched)`, `applyAction(state, action, now, sched, actorUserId): (ok, state, quality?)` |

### Remote ownership (who registers the server handler)

| Remote | Handler |
|---|---|
| `BuyUpgrade`, `ClaimStreak`, `CollectRestock`, `CompleteTutorial`, `SetSetting` | DataService |
| `RequestRewardedAd` | PurchaseService |
| `JoinCrew`, `LeaveCrew`, `SetCrewName` | PlotService |
| `CookAction` | StationService |
| `ServeCustomer` | CustomerService |
| `GetSnapshot` | `init.server.luau` |

| Server→client | Sender |
|---|---|
| `DataSync`, `CoinsAwarded` | DataService |
| `PurchaseGranted` | PurchaseService |
| `LeaderboardUpdate` | LeaderboardService |
| `PlotsChanged` | PlotService |
| `StationUpdate`, `HeldItemChanged` | StationService |
| `CustomerUpdate`, `CustomerRemoved`, `OrderServed`, `LegendaryAnnounce` | CustomerService |
| `RushHourState` | RushHourService |
| `Toast` | any service (one player) |

## 5. Key data flows

### Cook (server-authoritative timers)

1. Client walks to a station; its ProximityPrompt (created by StationService on the slot's `Interact` part) opens the StationController minigame UI.
2. Client fires `CookAction { plotId, slot, action = "Start" }` while the player holds the button.
3. StationService: Guard rate limit → `plotId`/`slot` are ints in range → `PlotService.IsMember(player, plotId)` → `Guard.isNear(player, Interact.Position, Timings.Station.InteractRange)` → `Cooking.applyAction(state, "Start", now, Cooking.schedule(dish, ownerUpgrades), userId)`.
4. The server advances phases on its own clock (`Cooking.advance`) and broadcasts `StationUpdate` to the plot's members. The client animates from `phaseStartedAt`/`phaseEndsAt`; it never decides an outcome.
5. `Flip` during `NeedsFlip` gives Perfect (within `perfectSeconds`) or Good. Missing the window, or leaving it `Ready` past `burnSeconds`, gives `Burnt` (`Clear` resets).
6. `Collect` on `Ready` with empty hands gives the player `HeldItem { Dish, dishId, quality }` (`HeldItemChanged`, plus a dish prop welded to the hand) and fires `Events.DishCooked`.

### Serve → pay

1. Client: the player holding a dish triggers the customer's prompt and fires `ServeCustomer { customerId }`.
2. CustomerService validates: `customerId` is an int, the customer exists and is `Waiting` with an order, `PlotService.IsMember(player, customer.plotId)`, `Guard.isNear(player, customerRoot, Timings.Serve.InteractRange)`, and `StationService.GetHeldItem(player)` matches `order.dishId` and isn't Burnt.
3. `StationService.TakeHeldItem(player)` consumes the dish.
4. It builds the `PayoutContext`:
   - `waitSeconds` = now − `order.placedAt`
   - `ownerUpgrades` = `DataService.GetData(owner).upgrades`
   - `crewSize` = `#PlotService.GetMembers(plotId)`
   - `rushHour` = `RushHourService.IsActive()`
   - `hasTipsPass` = `PurchaseService.OwnsPass(player, "TipsX2")`
   - `tipBoostPct` = `PurchaseService.GetTipBoostPct(player)`
   - `combo` comes from the per-player combo in CustomerService
5. `Economy.computePayout(ctx)`, then `DataService.AddCoins(player, payout.total, "Serve")`. **Coins go to the player who served.** For bot serves they go to the plot owner.
6. The customer goes to `Eating`, then `Leaving`. CustomerService fires `Events.OrderServed(ServeResult)` and broadcasts `OrderServed`. A legendary also gets `LegendaryAnnounce` with `servedByName` and `tip`.
7. Reactions:
   - DataService sends `DataSync`, updates stats and logs the economy event.
   - LeaderboardService adds to the rush-hour tally.
   - AudioDirector plays Cash.
   - Client FXController plays the coin burst plus a tip explosion scaled by `tipFraction`.

### Purchase (idempotent)

`MarketplaceService.ProcessReceipt`:
1. Wait for the player's profile.
2. If `DataService.HasReceipt(PurchaseId)`, return `PurchaseGranted`.
3. Otherwise grant the effect, then `RecordReceipt`, then `SaveAndConfirm`.
4. Return `PurchaseGranted` **only** if the save confirmed, else `NotProcessedYet`.

Product effects:
- Coin packs: `AddCoins`.
- TipPotion and AdTipBoost: `AddBoost`.
- InstantRestock: `CollectRestock(player, true)`.
- RushHourNow: `RushHourService.TriggerNow(player)`. It's server-wide and the buyer is named in `RushHourState.triggeredByName`. If a rush is already active, it extends that rush instead of being refused.

Products with placeholder id 0 are never prompted or granted.

### Rush Hour

- `Logic/Schedule.rushHourState(now)` gives the scheduled window (every hour at :00 UTC, 4 minutes).
- RushHourService polls each second, layers in purchased triggers, and fires `Events.RushHourStarted`/`Ended`. It broadcasts `RushHourState`.
- Listeners:
  - LightingDirector tweens the Rush preset.
  - AudioDirector swaps the music and plays the horn.
  - CustomerService multiplies the spawn rate by `GetSpawnMultiplier()`.
  - `Economy` applies the 2× pay through `ctx.rushHour`.
  - LeaderboardService tracks per-player rush earnings.
- The HUD always shows a countdown to `nextAt` (or to `endsAt` while active).

### Offline earnings (ingredient restock)

`PlayerData.lastRestock` accrues `Offline.coinsPerMinute(upgrades)`, capped at 8h, and is only paid when the player presses Collect (`CollectRestock`). `PlayerDataView.restockPending` drives the HUD timer. Auto-Chef pass: while in game, StationService pays `Offline.autoChefIncome(upgrades, Timings.AutoChef.TickSeconds)` each tick.

## 6. World contract

Instance names and attributes are in `src/shared/Contracts/WorldSchema.luau`.

- MapBuilder builds `Workspace.Plots.Plot_<n>` in `Init`.
- StationService adds ProximityPrompts on `Stations/Slot_<k>/Interact`.
- CustomerService parents customer models to `Workspace.Customers` with the `CustomerId` attribute.
- The client finds models by these names. Nothing else is shared between world and gameplay code.

## 7. File ownership (Wave 1)

| Agent | Owns (may write) |
|---|---|
| Orchestrator | `src/shared/Contracts/**`, `src/shared/Net.luau`, `src/server/Util/**`, `src/server/init.server.luau`, `src/server/Services/AnalyticsService.luau`, `Config/Stations`, `Config/Products`, `Config/Timings`, root config, CI, `docs/ARCHITECTURE.md`, `docs/GDD.md`, `docs/CHANGELOG.md` |
| A. Data & Purchases | `src/server/Services/{DataService,PurchaseService,LeaderboardService}.luau` |
| B. Economy Logic | `src/shared/Logic/**`, `tests/**`, `tools/econ_sim.luau`, `Config/{Upgrades,Dishes,Customers,Economy}` |
| C. Gameplay | `src/server/Services/{PlotService,CustomerService,StationService,RushHourService}.luau` |
| D. Client & UI | `src/client/**` |
| E. World, Look & Sound | `src/server/World/**`, `src/shared/VFX/**`, `assets/**`, `Config/{Palette,Lighting,Audio}`, `tools/upload_assets.luau`, `tools/gen_sfx.luau` |

An owned module file may be turned into a folder (`X/init.luau` plus private helper children). Its require path stays the same. Agents never edit files they don't own; they put contract-change requests in their report.
