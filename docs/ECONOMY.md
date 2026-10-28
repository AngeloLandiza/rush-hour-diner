# Economy and balance

Numbers come from `src/shared/Config/*` and are measured by `tools/econ_sim.luau` (deterministic, seed 20240601, one solo player playing continuously and buying the cheapest affordable upgrade). Real players take breaks, so the sim is a lower bound on wall-clock time.

## Formulas (prose)

- **Serve payout** = (dish base price x customer pay multiplier) plus a tip, times Rush Hour (x2) times the crew bonus (+10% per member, cap +30%), rounded, minimum 1.
- **Tip fraction** = (0.2 x speed factor, from 2.0 for a serve inside 25% of patience easing to 0.25 at the last second, + 0.25 for a Perfect flip, + legendary tip bonus, + Decor bonus) x (1 + 0.1 x combo, combo max 10) x Charm School multiplier (1 + 0.25 per level) x 2 if the Tips pass x (1 + active boost: Tip Potion 0.5, Ad 0.25).
- **Combo** grows by one when a customer is served within half of their patience, else resets.
- **Customers** spawn every 8 s per plot (3x faster in Rush Hour), limited by seats (3 base, +3 per Seating level: 3, 6, 9, 12). Mix is 80 Regular, 15 Hungry (1.5x pay, 0.6x patience), 5 VIP (3x pay). Each spawn is legendary with chance 0.5% (x3 in Rush Hour); legendaries pay 10x/12x/15x base plus a +200%/250%/300% tip.
- **Offline restock** = minutes offline (capped at 8 h) x (4 + 0.6 per upgrade level owned) coins per minute. Auto-Chef AFK income uses the same rate.
- **Streak** pays a fixed coin amount for days 1-7, then cycles. A missed day resets to day 1.
- **Upgrades**: total of 13 levels, costs below. Station speed upgrades multiply cook time by 1.5x speed.

## Tuned values (changed in the balance pass marked with *)

| Setting | Value |
|---|---|
| Dishes base price | Burger 10, Fries 8, Pizza 16, Soda 5 (unchanged) |
| Upgrade costs: Turbo Grill / Hot Oil / Brick Oven / Fizz Pump | 60 / 350 / 900 / 200 |
| Comfy Music (Patience) | 900 |
| Upgrade costs: Brick Oven / Comfy Music | 1000* (was 900) / 1100* (was 900) |
| More Seats levels 1-3 | 700 / 3000 / 9000* (was 500 / 2000 / 8000), now +3 seats per level (was +1): 3 -> 6 -> 9 -> 12 |
| Charm School (Tips) levels 1-2 | 1800 / 12000* (was 1500 / 10000) |
| Robo-Waiter | 12500* (was 14000) |
| Diner Makeover (Decor) levels 1-2 | 4000 / 26000* (was 3500 / 20000) |
| Total upgrade cost | 71,710 |
| Offline base / per level per minute | 4.5* (was 4) / 0.6 |
| Streak days 1-7 | 230 / 280 / 340 / 450 / 560 / 680 / 900* (was 200/250/300/400/500/600/800) |
| Coin packs | 500 / 2,500 / 11,000* (was 12,000) |
| Legendary chance, customer weights, patience, Timings | unchanged |

Spec-fixed (not touched): Hungry 1.5x, VIP 3x, Rush Hour 3x spawn and 2x pay for 4 min each hour, crew +10% (cap +30%), 8 h offline cap, Tip Potion +50%/15 min, Ad +25%/10 min, 2x Tips pass.

## Sim geometry (110x90 plots, up to 12 seats)

Constants live at the top of `tools/econ_sim.luau`: CustomerSpawn to Door 40 studs, Door to stool 18 studs, Door to farthest seat 33 studs, WalkSpeed 12. Seats 1-5 are counter stools served across the counter (7 studs, about 1.7 s round trip with the prompt). Seats 6-12 are booths and a high-top: the player walks about 16.5 studs each way (about 3.3 s per serve). A customer takes the lowest free seat, starts its patience clock when it sits (walk time 6.7 s to 8.3 s after spawning) and cannot be served before then. Pickup between stations costs 3 s. The spawn interval (8 s), patience (45 s) and dish prices are unchanged: demand is about 7.5 customers/min against one cook-at-a-time player who manages about 6 to 7 per min, so the diner is busy at every size. Share of arrivals turned away (diner full): 19% at 3 seats, 21% at 6, 11% at 9, 9% at 12 (the 12-seat figure includes the Robo-Waiter, which is what makes 12 seats workable for a solo player; crew help too).

## Time to each upgrade

| # | Upgrade | Free | 2x Tips pass |
|---|---|---|---|
| 1 | Turbo Grill | 0:00:34 | 0:00:34 |
| 2 | Fizz Pump | 0:02:30 | 0:01:54 |
| 3 | Hot Oil | 0:05:23 | 0:04:03 |
| 4 | Seats 1 (6 seats) | 0:10:59 | 0:07:54 |
| 5 | Brick Oven | 0:20:46 | 0:14:50 |
| 6 | Comfy Music | 0:30:49 | 0:24:06 |
| 7 | Charm 1 | 0:41:04 | 0:32:56 |
| 8 | Seats 2 (9 seats) | 1:00:17 | 0:43:50 |
| 9 | Makeover 1 | 1:32:57 | 1:06:40 |
| 10 | Seats 3 (12 seats) | 2:32:01 | 1:58:01 |
| 11 | Charm 2 | 3:50:25 | 2:44:36 |
| 12 | Robo-Waiter | 5:19:07 | 3:35:34 |
| 13 | Makeover 2 | 6:47:55 | 4:30:54 |

First cook-to-serve cycle finishes at 18 s (limit 3 min); first upgrade at 34 s (limit 2 min). A new player can cook at 7.8 s: 3 s first-customer delay plus about 4.8 s for the first customer to walk about 58 studs to stool 1 (limit 60 s). The pass finishes all 13 in 66% of the free time (target 60-75%). Longest single wait is 1h29m before the last upgrade, 22% of the total (limit 25%).

## Income per minute by stage (free, 3-stage smoothed)

| Stage (before buying #) | Coins/min |
|---|---|
| 1-4 | 107-122 |
| 5-8 | 111-149 |
| 9-11 | 144-147 |
| 12 (bot bought next) | 197 |
| 13 | 217 |

Income is demand- and player-bound, not seat-bound. Seats mainly cut turned-away customers and are cheap early. The Robo-Waiter is the late jump (+34%), because it removes the serve walk, which matters most at table seats.

## Levers

- **Rush Hour**: 3x spawns and 2x pay for 240 s each hour, up to 6x income if seats and cooking keep up. Legendary chance is 3x as well (the odds bonus applies to free scheduled rushes only).
- **Streak** (minutes of income at the stage reached): day 1 = 2.1 min, day 2 = 1.9, day 3 = 2.3, day 4 = 3.1, day 5 = 2.8, day 6 = 3.4, day 7 = 4.2.
- **Offline restock at 8 h cap**: 20 to 34 minutes of active income at every stage (2160 coins at the start, 5616 at the end). Instant Restock pays the same amount.
- **Legendary tip**: 2.9 to 4.0 minutes of income at every stage (434 coins early, 671 late), 2.4 served per hour in the sim (target 1-3).
- **Coin packs**: Small 500 (0.7% of total cost, 2-5 min of income), Medium 2,500 (3.5%, 12-23 min), Large 11,000 (15.3%, 51-103 min); target is under 18%.
- **2x Tips pass**: all 13 in 66% of free time.

## Tuning rationale (geometry pass)

- Plots went from 60x50 to 110x90 and seats from 6 to 12. The Seating upgrade stays at 3 levels (13 upgrade levels total) but now gives +3 seats per level so the curve reaches 12 (3 -> 6 -> 9 -> 12). Four extra levels would have broken the 13-level spec.
- Customers walk about 40 studs to the door and up to 33 more to a seat, so the arrival-to-sit delay is 6.7 s to 8.3 s. Stool service is quicker than table service, so income would have risen sharply (about 40% at the start). Upgrade costs were raised to compensate (about +15% total) and the 6-8 h window restored (6h48m).
- Robo-Waiter was cut to 12,500 and Makeover 2 raised to 26,000 so the longest wait stays under 25% of the total.
- Offline base rose 4 -> 4.5 and the streak rewards rose about 15% to keep them at 2-4 minutes of income at the higher early income.
- Spawn interval, patience and dish prices were left alone: the sim shows the diner is already saturated for a solo player at 6 seats (21% turned away) and still turns away 9% at 12 seats.

## Re-running the sim

`lune run tools/econ_sim` prints the tables above and exits non-zero if a target is missed (first upgrade, first cycle, new-player cook start under 60 s, 6-8 h, 25% gap, pass 60-75%, packs under 18%, streak, restock, legendary value and frequency, maxed Seating reaching Seats.Max). Legendary value uses a 2.5-5.5 minute tolerance around the "about 3-5" target because the smoothed income is noisy. `lune run tools/test` runs the unit tests.
