# Rush Hour Diner: Game Design Document

## Pitch

1–4 friends run a tiny meme-food stand that grows into a chaotic diner. Hourly **Rush Hours** flood the street with customers. Rare **Legendary Customers** tip huge and trigger a server-wide announcement. That announcement is the clip moment.

## Pillars

1. **Cooking in 60 seconds.** A new player is at a station within a minute of joining.
2. **Readable chaos.** It's loud, bright and bouncy, and every coin gained is visible.
3. **Come back on the hour.** Rush Hour, restock, streak and the weekly menu drop each give a reason to return.
4. **Fair and server-authoritative.** There is no way to cheat coins, and no paid randomness.

## Core loop (first cycle under 3 minutes)

1. A customer walks in, sits down and shows an order bubble (dish icon plus a patience ring).
2. A player goes to the matching station and plays the cook minigame:
   - **hold** to start
   - **flip** in the window (early is Perfect, late is Good, missed is Burnt)
   - **collect** when it's ready
3. The player carries the plated dish to the customer and **serves** it.
4. The customer pays the dish price × customer multiplier, plus a **tip**. The tip scales with serve speed, combo, flip quality, decor and boosts.
5. Coins buy **upgrades**, so the diner gets faster, bigger and pays more.

## Content (MVP)

### Plots and crew

- One plot per player, up to 6 per server. Players get one automatically on join.
- Friends can join a plot as crew, up to 3 crew for 4 players in total.
- Crew bonus: +10% coins per crew member on the plot, up to +30%.
- Coins from a serve go to the player who served it. The plot owner's upgrades shape that plot.
- Crew/diner names pass through `TextService:FilterStringAsync`.

### Stations and dishes

| Station | Dish |
|---|---|
| Grill | Burger |
| Fryer | Fries |
| Oven | Pizza |
| Soda Fountain | Drink |

The Extra Station Slot pass adds a second Grill.

### Upgrades (13 levels in total)

The spec's itemized list adds up to 13 purchasable levels. That list was kept as written, even though the summary says "12".

| Upgrade | Levels | Effect |
|---|---|---|
| Station speed (Grill, Fryer, Oven, Soda) | 1 each (4) | Faster cook at that station |
| Customer patience | 1 | Customers wait longer |
| Seating capacity | 3 | +1 seat per level (base 2) |
| Tip multiplier | 2 | Bigger tips |
| Auto-server bot | 1 | A bot delivers ready dishes |
| Decor tiers | 2 | Bigger diner shell, higher tip % |

Targets: the first upgrade comes in under 2 minutes, and all 13 levels take about 6–8 hours of free play.

### Customers

| Type | Behavior |
|---|---|
| Regular | R15 default bundles with randomized free outfits |
| Hungry | Impatient, pays 1.5× |
| VIP | Pays 3× |
| Legendary | Rare (more likely during Rush Hour), pays a huge tip, and triggers a server-wide banner, VFX and sound |

There are three legendaries at launch:
- Giant Chef
- Space Alien
- the **Weekly Meme slot**, driven entirely by `Config/Customers.Legendary.WeeklyMeme` and always an original character

### Rush Hour

- Every hour at :00 server time (UTC), for 4 minutes, with 3× spawn rate and 2× pay.
- The HUD always shows a countdown.
- Lighting tweens to a saturated neon preset, and the music switches.
- Developer product "Rush Hour Now" starts one server-wide and credits the buyer by name.

### Retention

- **Daily streak:** days 1–7 rewards, then the cycle repeats. Missing a day resets it to day 1.
- **Ingredient restock:** offline earnings, capped at 8h. Players must come back and press Collect.
- **Rush Hour countdown.**
- **Next menu drop:** a weekly countdown (Saturday 16:00 UTC).

### Leaderboards

- Lifetime coins: global, OrderedDataStore.
- Best Rush Hour: per server.

## Monetization

IDs live in `Config/Products.luau` and stay placeholders (0) until they're created.

| Type | Item |
|---|---|
| Game pass | 2× Tips |
| Game pass | Auto-Chef (AFK income while in game) |
| Game pass | Extra Station Slot |
| Game pass | VIP Booth (cosmetic and a chat tag) |
| Dev product | Instant Restock (full 8h restock now) |
| Dev product | Rush Hour Now (server-wide, buyer credited) |
| Dev product | Tip Potion (+50% tips for 15 min, shown numerically on the HUD) |
| Dev product | Coin packs ×3 |
| Rewarded video ad | +25% tips for 10 min. Opt-in only, never auto-played |

There are **no paid random items.** If any are ever added, they need odds disclosure and `PolicyService` checks.

## Hard constraints

- R15 avatars only.
- Server-authoritative coins, cooking completion, serving and purchases.
- `ProcessReceipt` is idempotent: the receipt is recorded in the profile, and `PurchaseGranted` is returned only after the save is confirmed.
- No video feeds, autoplay or scroll-for-reward mechanics.
- No copyrighted names, characters, music or logos. Audio is either generated or from Roblox's licensed library.
- All player text is filtered.

## Art direction ("code-first stylized")

- **Materials:** SmoothPlastic and Neon only.
- **Palette** (`Config/Palette`, the only source of colors): cream `#FFF4E0`, ketchup `#E63946`, mustard `#FFB703`, mint `#2EC4B6`, ink `#1D3557`, neon pink `#FF5DA2`.
- **Shapes:** chunky, rounded and oversized props built from parts, CornerWedges, cylinders and spheres.
- **Lighting:** Future, with Atmosphere, ColorCorrection and Bloom. There's a warm Day preset and a neon Rush preset that tweens in and out.
- **UI:** built 100% in code (Frame, UICorner, UIStroke, UIGradient), with bouncy tweens, FredokaOne and touch targets of at least 44px. It's mobile-first and works at 360×640.
- **VFX:** steam, sizzle, fire, a coin burst, and a tip explosion that scales with tip size.
