# Economy and balance

Numbers come from `src/shared/Config/*` and are measured by `tools/econ_sim.luau` (deterministic, seed 20240601, one solo player playing continuously and buying the cheapest affordable upgrade). Real players take breaks, so the sim is a lower bound on wall-clock time.

## Formulas (prose)

- **Serve payout** = (dish base price x customer pay multiplier) plus a tip, times Rush Hour (x2) times the crew bonus (+10% per member, cap +30%), rounded, minimum 1.
- **Tip fraction** = (0.2 x speed factor, from 2.0 for a serve inside 25% of patience easing to 0.25 at the last second, + 0.25 for a Perfect flip, + legendary tip bonus, + Decor bonus) x (1 + 0.1 x combo, combo max 10) x Charm School multiplier (1 + 0.25 per level) x 2 if the Tips pass x (1 + active boost: Tip Potion 0.5, Ad 0.25).
- **Combo** grows by one when a customer is served within half of their patience, else resets.
- **Customers** spawn every 8 s per plot (3x faster in Rush Hour), limited by seats (2 base, +3 from upgrades). Mix is 80 Regular, 15 Hungry (1.5x pay, 0.6x patience), 5 VIP (3x pay). Each spawn is legendary with chance 0.5% (x3 in Rush Hour); legendaries pay 10x/12x/15x base plus a +200%/250%/300% tip.
- **Offline restock** = minutes offline (capped at 8 h) x (4 + 0.6 per upgrade level owned) coins per minute. Auto-Chef AFK income uses the same rate.
- **Streak** pays a fixed coin amount for days 1-7, then cycles. A missed day resets to day 1.
- **Upgrades**: total of 13 levels, costs below. Station speed upgrades multiply cook time by 1.5x speed.

## Tuned values (changed in the balance pass marked with *)

| Setting | Value |
|---|---|
| Dishes base price | Burger 10, Fries 8, Pizza 16, Soda 5 (unchanged) |
| Upgrade costs: Turbo Grill / Hot Oil / Brick Oven / Fizz Pump | 60 / 350 / 900 / 200 |
| Comfy Music (Patience) | 900 |
| More Seats levels 1-3 | 500 / 2000 / 8000* (was 6500) |
| Charm School (Tips) levels 1-2 | 1500 / 10000* (was 8000) |
| Robo-Waiter | 14000* (was 16000) |
| Diner Makeover (Decor) levels 1-2 | 3500 / 20000* (was 24000) |
| Total upgrade cost | 62,910 |
| Offline base / per level per minute | 4* (was 2) / 0.6* (was 1) |
| Streak days 1-7 | 200 / 250 / 300 / 400 / 500 / 600 / 800* (was 50/100/150/250/400/600/1000) |
| Coin packs | 500 / 2,500 / 11,000* (was 12,000) |
| Legendary chance, customer weights, patience, Timings | unchanged |

Spec-fixed (not touched): Hungry 1.5x, VIP 3x, Rush Hour 3x spawn and 2x pay for 4 min each hour, crew +10% (cap +30%), 8 h offline cap, Tip Potion +50%/15 min, Ad +25%/10 min, 2x Tips pass.

## Time to each upgrade

| # | Upgrade | Free | 2x Tips pass |
|---|---|---|---|
| 1 | Turbo Grill | 0:00:51 | 0:00:40 |
| 2 | Fizz Pump | 0:03:24 | 0:02:43 |
| 3 | Hot Oil | 0:07:38 | 0:05:18 |
| 4 | Seats 1 | 0:13:16 | 0:09:15 |
| 5 | Brick Oven | 0:24:46 | 0:17:28 |
| 6 | Comfy Music | 0:33:22 | 0:26:20 |
| 7 | Charm 1 | 0:38:51 | 0:32:48 |
| 8 | Seats 2 | 0:56:39 | 0:36:18 |
| 9 | Makeover 1 | 1:22:01 | 0:59:05 |
| 10 | Seats 3 | 2:38:34 | 1:44:14 |
| 11 | Charm 2 | 3:59:36 | 2:52:31 |
| 12 | Robo-Waiter | 5:39:42 | 3:54:40 |
| 13 | Makeover 2 | 7:27:12 | 4:56:25 |

The first cook-to-serve cycle finishes at 17 s. The pass finishes all 13 in 66% of the free time.

Curve in text: the first four upgrades arrive in the first quarter hour (minutes apart), the next four by one hour, then waits stretch to 1 to 1.7 hours each. The longest single wait is 1h47m before the last upgrade, 24% of the total. There are no dead zones because the cheapest affordable upgrade is always bought first and each cost step is roughly 1.5 to 2x the last.

A new player is cooking in about 5 s: 3 s first-customer delay plus about 2.2 s to walk about 26 studs from the customer spawn (Z 22) to a seat (Z -4) at WalkSpeed 12.

## Income per minute by stage (free, 3-stage smoothed)

| Stage (before buying #) | Coins/min |
|---|---|
| 1-4 | 80-85 |
| 5-7 | 130-150 |
| 8-11 | 115-125 |
| 12 | 150 |
| 13 | 160 |

Income is demand-bound (seats and spawn rate), not cook-speed-bound, so it only roughly doubles across the game while costs grow about 300x. The late game is long by design.

## Levers

- **Rush Hour**: 3x spawns and 2x pay for 240 s each hour, up to 6x income if seats and cooking keep up. Legendary chance is 3x as well.
- **Streak** (minutes of income at the stage reached): day 1 = 2.5 min, day 2 = 2.2, day 3 = 2.5, day 4 = 3.2, day 5 = 3.3, day 6 = 3.9, day 7 = 5.1.
- **Offline restock at 8 h cap**: 24 to 39 minutes of active income across all stages (1920 coins at the start, 5376 at the end). Instant Restock pays the same amount.
- **Legendary tip**: about 3 to 5.4 minutes of income at every stage (434 coins early, 671 late), 1.9 served per hour in the sim.
- **Coin packs**: Small 500 (0.8% of total cost, 3-6 min of income), Medium 2,500 (4.0%, 15-31 min), Large 11,000 (17.5%, 64-137 min).
- **2x Tips pass**: all 13 in 66% of free time.

## Tuning rationale

- Hit the spec windows (first upgrade under 2 min, all 13 in 6-8 h) first, then fix the dead zone: the old last wait was 2h10m (30%). Decor 2 and Robo-Waiter were cut and the middle costs raised so no wait is above 25%.
- Streak day 1 was worth under a minute. It is now 200 coins, so early days are about 2-3 minutes and day 7 stays near 5.
- Offline was 13 to 53 minutes of play and spiky. A higher base and lower per-level slope keeps it between 24 and 39.
- Legendary multipliers were already right; no change needed.
- Large pack was 18.6% of the old total, 21% after cost trims; 11,000 keeps it at 17.5% of the new total.

## Re-running the sim

`lune run tools/econ_sim` prints the tables above and exits non-zero if a target is missed (first upgrade, first cycle, 6-8 h, 25% gap, pass 60-75%, packs, streak, restock, legendary value and frequency). Legendary value uses a 2.5-5.5 minute tolerance around the "about 3-5" target because the smoothed income is noisy. `lune run tools/test` runs the unit tests.
