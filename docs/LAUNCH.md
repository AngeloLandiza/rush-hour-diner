# Rush Hour Diner: Launch Kit

Source of truth: `src/shared/Config/Products.luau`, `src/shared/Config/Customers.luau` and `docs/GDD.md`. If a value changes there, update this file.

---

## 1. Creator Hub setup

Create each item in the Creator Hub (open the experience, then Monetization: Passes for game passes and Developer Products for products; menu names may change). Paste each returned ID into `Products.luau` in place of `id = 0`. Until an ID is set, `PurchaseService` treats the item as not configured and never prompts for it.

### Game passes

| Key (Config) | Display name | Description | Price (Robux) |
|---|---|---|---|
| `Passes.TipsX2` | 2× Tips | Double every tip, forever. | 199 |
| `Passes.AutoChef` | Auto-Chef | Your diner earns coins while you are AFK in game. | 299 |
| `Passes.ExtraStation` | Extra Station Slot | A second grill in your kitchen. | 249 |
| `Passes.VIPBooth` | VIP Booth | A glowing VIP booth and a VIP chat tag. | 149 |

### Developer products

| Key (Config) | Display name | Description | Price (Robux) |
|---|---|---|---|
| `Products.InstantRestock` | Instant Restock | Collect a full 8 hours of restock earnings now. | 49 |
| `Products.RushHourNow` | Rush Hour Now! | Start a Rush Hour for the whole server. Everyone sees your name. | 99 |
| `Products.TipPotion` | Tip Potion | +50% tips for 15 minutes. | 39 |
| `Products.CoinsSmall` | Pile of Coins | 500 coins to spend on your diner. | 25 |
| `Products.CoinsMedium` | Bag of Coins | 2,500 coins to spend on your diner. | 99 |
| `Products.CoinsLarge` | Vault of Coins | 11,000 coins to spend on your diner. | 399 |
| `Products.AdTipBoost` | Ad Tip Boost | +25% tips for 10 minutes. | 0 |

**Notes**

- **Coin packs** have empty descriptions in the config. Creator Hub may require one, so use the suggested text above and add it to `Products.luau`.
- **`Products.AdTipBoost` is not a store item.** It is a free product used only as the reward for an opt-in rewarded video ad. Do not list it for sale and do not promote it in the store. If Creator Hub does not accept a 0 Robux price, do not work around it with a fake price. Check Roblox's rewarded video ad documentation for the supported setup.
- **Name and description limits** are set by Creator Hub. If a field rejects the text, shorten it and keep the meaning.
- After creating the items, confirm that each `id` in `Products.luau` is a real non-zero ID and that the prices match the table.

---

## 2. Game titles

Each title is 50 characters or fewer.

| # | Title | Chars | Why it works |
|---|---|---|---|
| 1 | Rush Hour Diner: Co-op Cooking Chaos | 36 | Names the game and the co-op hook in one line. |
| 2 | Rush Hour Diner: Friends Cook Fast | 30 | Speaks to the friends audience and the 60-second cooking pillar. |
| 3 | Rush Hour Diner Tycoon: Serve the Chaos | 40 | Adds the tycoon keyword that players search for. |
| 4 | Rush Hour Diner: Legendary Customers! | 37 | Leads with the clip moment (the server-wide legendary announcement). |
| 5 | Rush Hour Diner: Burgers, Fries & Fire | 35 | Lists the food and the kitchen-chaos fantasy for quick recognition. |

---

## 3. Game descriptions

Each description is under 1000 characters. The features are short lines and make no claims about rewards for watching ads. Ads are described as optional.

### Description A: the hook (lead with cooking)

```
Flip burgers. Fry fries. Pull pizza out before it burns. Your tiny street stand is about to become the loudest diner on the block.

Rush Hour Diner is a co-op cooking game for 1 to 4 friends. Cook in under a minute, grow your diner and keep up when the street floods with hungry customers.

Features
- Cook fast: hold, flip at the right moment, collect, serve
- Four stations: Grill, Fryer, Oven and Soda Fountain
- Upgrades: faster stations, more seats, bigger tips and a helper bot
- Daily streak rewards and an ingredient restock you collect when you return

Optional: game passes and coin packs. Coins can also be earned by playing.
Optional: an opt-in video ad for a temporary tip boost. Ads are never required.
```

### Description B: co-op with friends

```
Cooking is better with friends. Invite up to 3 friends to your plot as crew and run the kitchen together.

- Crew bonus: +10% coins per crew member on your plot, up to +30%
- Coins go to the player who served the order
- Crew and diner names are filtered for safe chat

Every hour, Rush Hour hits. For 4 minutes, customers flood the street, the lights turn neon and the countdown sits on your HUD. Get your crew to the stations and keep the orders moving.

Pick your team, pick a station and cook like it is the only shift that matters.

Optional: game passes and coin packs. Coins can also be earned by playing.
```

### Description C: legendary customers

```
Most customers just want a burger. Some want the whole diner to stop.

Rare Legendary Customers tip huge and announce their arrival to every player on the server. Meet:
- The Giant Chef
- A Space Alien with a taste for soda
- Sir Sandwich, the weekly guest, who changes with each weekly update

Legendaries are more likely during Rush Hour, the hourly 4-minute rush with a neon countdown on your HUD.

Build your diner with upgrades: faster stations, more seats, bigger tips and a helper bot that delivers ready dishes. Play with friends or on your own.

Optional: game passes and coin packs. Coins can also be earned by playing.
Optional: an opt-in video ad for a temporary tip boost. Ads are never required.
```

---

## 4. Icon concept

**Primary concept: "The Flip"**

- **Composition:** A square badge with a ketchup-red circle behind a bust of a round, grinning chef, centered and cropped at the chest. A mustard spatula flips a cream burger in the upper-right, and a small mint clock face sits behind the chef's hat, showing 12. Keep the background simple.
- **Palette:** Cream `#FFF4E0` background and highlights, ketchup `#E63946` badge, mustard `#FFB703` spatula and burger top, mint `#2EC4B6` clock, ink `#1D3557` outlines, neon pink `#FF5DA2` sparkle.
- **Focal character:** Chef Pip, an original round chef with a tall paper hat, wide eyes and a huge open grin. Expression: delighted and a little frantic, mid-flip.
- **Shape language:** Thick ink outline (at least 6 px at 1024 px), rounded forms, no fine detail.
- **Readability at 150 px:** The chef's face and the red circle carry the icon. The burger and spatula read as one bright shape. No text in the icon. Test it at 150 px and at 48 px in both light and dark Roblox themes.

**Alternates**

- **Alt A, "Sir Sandwich":** Mustard sandwich character with a tiny crown, on a mint background. Strong for the weekly-meme angle, but less clear about the diner.
- **Alt B, "The Clock":** Big ketchup-red clock face with an ink hour hand at 12 and a neon pink ring, with a spatula crossing it. Strong for the Rush Hour hook, but no character.

---

## 5. Thumbnail compositions (1920 x 1080)

### T1: Giant Chef arrives

- **Shot:** The Giant Chef fills the right third of the frame, looming over a small player-owned grill. Confetti and a neon banner across the top.
- **Camera:** Low angle, slightly from below, to sell the scale.
- **In-game moment:** The legendary announcement banner ("THE GIANT CHEF has arrived at ...").
- **Text overlay:** `GIANT CHEF!` (2 words)
- **Capture in Studio:** In a test place, use a temporary LocalScript to set `workspace.CurrentCamera` to a low-angle CFrame near the Giant Chef and trigger the legendary spawn. Hide the Roblox UI, except the banner. Set the window to 1920 x 1080 and take the screenshot with the OS screenshot tool. Remove the test script before publishing.

### T2: Kitchen on fire

- **Shot:** A burger and grill in flames, sparks, steam and a panicked chef in the foreground. The order bubble above the grill shows a red "burnt" icon.
- **Camera:** Three-quarter top-down, looking into the grill from the counter.
- **In-game moment:** A missed flip that turns the dish to Burnt, with fire VFX.
- **Text overlay:** `KITCHEN ON FIRE` (3 words)
- **Capture in Studio:** Play the Grill station in a test place and let a flip go unflipped until the fire VFX plays. Capture the frame on the burn, with the Roblox UI hidden except for the order bubble. Retake the shot until the fire and steam are both visible.

### T3: Rush Hour, neon

- **Shot:** A wide view of the street with the neon Rush preset: saturated pink and mint light, a crowd of customers, and the countdown in the top-center HUD.
- **Camera:** Wide, eye level, centered on the diner front.
- **In-game moment:** The Rush Hour start, after the lighting tween and while the countdown is showing.
- **Text overlay:** `RUSH HOUR NOW` (3 words)
- **Capture in Studio:** In Play mode, switch to the Server view and run `require(game.ServerScriptService.Server.Services.RushHourService).TriggerNow()` in the Command Bar. No code changes are needed. Wait for the lighting tween to finish, then capture at 1920 x 1080 with the HUD visible.

### T4: Cook with friends

- **Shot:** Four Roblox avatars at four stations (Grill, Fryer, Oven, Soda), shot from behind, with a bright crew badge over each. The plot is full of color.
- **Camera:** Over-the-shoulder, from behind the Grill player, with the others visible in the distance.
- **In-game moment:** A full crew of four during a busy minute, with the crew bonus shown.
- **Text overlay:** `COOK WITH FRIENDS` (3 words)
- **Capture in Studio:** Run a 4-player test session (two Studio windows or a local server with test clients). Position each character at a station with a temporary script, capture from one client's camera, and hide the Roblox UI.

---

## 6. TikTok and Shorts scripts

**Format for every script:** vertical 9:16, 15 to 30 seconds, captions on by default. A hook appears in the first 1 to 2 seconds.

**Audio rules:** original voiceover (recorded by you, or generated), in-game generated sound effects, and Roblox's licensed audio library only. No copyrighted songs, no trending sounds, no memes or characters from other franchises, and no brand names.

**Character rules:** The Giant Chef, Space Alien, Sir Sandwich and Chef Pip are original to this game. Use only these and the generic "Customer" characters.

---

### Script 1: The Giant Chef arrives (announcement)

- **Hook (0 to 2 s):** The screen shakes, a red banner slams in, and the text reads "THE GIANT CHEF HAS ARRIVED."
- **Shot list**

| Time | Shot | On-screen text |
|---|---|---|
| 0:00 to 0:02 | Close-up of the banner slamming in, screen shake | THE GIANT CHEF HAS ARRIVED |
| 0:02 to 0:06 | Low-angle shot of the Giant Chef stepping into the diner | Rare legendary |
| 0:06 to 0:12 | Player fumbles a burger, then hits PERFECT on the flip | PERFECT FLIP |
| 0:12 to 0:20 | Coin burst and the tip explosion, numbers climb | Tip: huge |
| 0:20 to 0:25 | Player stares at the screen, then grins | |

- **Voiceover or caption:** "Nobody tells you the Giant Chef is coming. You find out when the whole server does."
- **CTA:** "Come see who shows up. Tap to play Rush Hour Diner."

### Script 2: Space Alien orders a drink

- **Hook (0 to 2 s):** A mint alien appears in the frame and says, in text, "I WANT A DRINK."
- **Shot list**

| Time | Shot | On-screen text |
|---|---|---|
| 0:00 to 0:02 | Alien pops up at the counter | I WANT A DRINK |
| 0:02 to 0:07 | Player races to the Soda Fountain, pours the drink | 4 seconds |
| 0:07 to 0:14 | Serve, coins fly, tip bounces | Alien is happy |
| 0:14 to 0:20 | Alien waves and beams away | Legendary Space Alien |

- **Voiceover or caption:** "A space alien walked in and ordered a drink. I had four seconds. I made it."
- **CTA:** "Your turn. Tap to play."

### Script 3: Sir Sandwich demands a table (weekly guest)

- **Hook (0 to 2 s):** The text "SIR SANDWICH DEMANDS A TABLE" appears over a close-up of the mustard sandwich.
- **Shot list**

| Time | Shot | On-screen text |
|---|---|---|
| 0:00 to 0:02 | Sir Sandwich at the door, banner drops in | SIR SANDWICH DEMANDS A TABLE |
| 0:02 to 0:08 | Player scrambles to clear a seat | Seat him! |
| 0:08 to 0:15 | Player hands over the order, Sir Sandwich nods | Royal approval |
| 0:15 to 0:22 | Big tip, coins rain | Weekly guest |

- **Voiceover or caption:** "This week's guest is Sir Sandwich. He does not take no for an answer."
- **CTA:** "New guests every week. Come see who's next."

### Script 4: Kitchen on fire (burnt dish chaos)

- **Hook (0 to 2 s):** Flames jump up from the grill as the text reads "I FORGOT THE BURGER."
- **Shot list**

| Time | Shot | On-screen text |
|---|---|---|
| 0:00 to 0:02 | Flames on the grill, close-up | I FORGOT THE BURGER |
| 0:02 to 0:06 | Player yanks the burger off the heat, fire and smoke | BURNT |
| 0:06 to 0:12 | Player frantically starts a new one | Try again |
| 0:12 to 0:20 | Customer waves a menu, unimpressed | Customer is NOT happy |
| 0:20 to 0:25 | Player takes a deep breath, next order starts | Back on track |

- **Voiceover or caption:** "Rule one of the diner: never forget the burger."
- **CTA:** "Can you save the kitchen? Tap to play."

### Script 5: Burnt burger rescue (fail, then win)

- **Hook (0 to 2 s):** A smoke alarm sound effect and the text "3 ORDERS, 1 GRILL."
- **Shot list**

| Time | Shot | On-screen text |
|---|---|---|
| 0:00 to 0:03 | Smoke, three order bubbles, one grill | 3 ORDERS, 1 GRILL |
| 0:03 to 0:09 | Player misses the flip, dish turns BURNT | Oops |
| 0:09 to 0:17 | Player starts the next burger and hits GOOD, then PERFECT | Redeemed |
| 0:17 to 0:24 | Player serves all three, tips pop up | 3 for 3 |

- **Voiceover or caption:** "I burned one. Then I got a perfect flip. Watch me win the rush."
- **CTA:** "Think you can do better? Tap to play."

### Script 6: Rush Hour countdown (required)

- **Hook (0 to 2 s):** A big neon countdown reads "3, 2, 1, RUSH HOUR."
- **Shot list**

| Time | Shot | On-screen text |
|---|---|---|
| 0:00 to 0:02 | Countdown HUD fills the screen, screen flashes pink | 3, 2, 1 |
| 0:02 to 0:06 | Lighting tweens to neon, music sting (licensed or generated) | RUSH HOUR |
| 0:06 to 0:14 | Customers flood in, order bubbles pop up, player cooks | 3x customers |
| 0:14 to 0:21 | Player serves a stack of orders, coins fly | Keep up! |
| 0:21 to 0:27 | HUD shows the countdown at 0:45, player wipes their brow | 4 min, every hour |

- **Voiceover or caption:** "Every hour, the street floods for four minutes. Can you keep up?"
- **CTA:** "Set a reminder for the hour. Tap to play."

### Script 7: Friends co-op chaos (required)

- **Hook (0 to 2 s):** Four avatars run in from four directions as the text reads "ALL 4 OF US. ONE KITCHEN."
- **Shot list**

| Time | Shot | On-screen text |
|---|---|---|
| 0:00 to 0:02 | Four players collide in the doorway | ALL 4 OF US. ONE KITCHEN. |
| 0:02 to 0:08 | Each player runs to a different station | Grill, Fryer, Oven, Soda |
| 0:08 to 0:15 | Dish collisions, a dropped plate, a laugh | Oops |
| 0:15 to 0:22 | Orders get served, crew bonus shows up | Crew bonus +30% |
| 0:22 to 0:27 | The four players high-five | Invite your friends |

- **Voiceover or caption:** "Me and my friends running a diner. Nobody agreed on who does what."
- **CTA:** "Invite up to 3 friends. Tap to play."

### Script 8: The perfect flip (satisfying cut)

- **Hook (0 to 2 s):** Extreme close-up of the spatula as the burger flips, text "PERFECT."
- **Shot list**

| Time | Shot | On-screen text |
|---|---|---|
| 0:00 to 0:02 | Close-up of the flip, slow motion | PERFECT |
| 0:02 to 0:06 | Burger lands, sizzle, steam | Timing matters |
| 0:06 to 0:12 | Quick cut through three more flips (perfect, good, good) | 3 flips |
| 0:12 to 0:20 | Serve, coins burst out | Tip: bigger |
| 0:20 to 0:24 | Player smiles at the camera | |

- **Voiceover or caption:** "Hold, flip, collect, serve. Early is perfect. Late is good. Miss and it burns."
- **CTA:** "It takes one second to learn. Tap to play."

### Script 9: The tip explosion (coins, numbers)

- **Hook (0 to 2 s):** A serve lands and the tip number explodes on screen.
- **Shot list**

| Time | Shot | On-screen text |
|---|---|---|
| 0:00 to 0:02 | Tip number pops up, coin burst | +1,250 |
| 0:02 to 0:07 | Replay of the serve in slow motion | Speed + combo |
| 0:07 to 0:14 | Customer throws coins at the counter | Tip bonus |
| 0:14 to 0:20 | Coins in the bank counter climbs | Upgrade time |
| 0:20 to 0:24 | Player buys an upgrade (faster grill) | Faster grill |

- **Voiceover or caption:** "A serve fast enough and the tip explodes. Then I spent it on a faster grill."
- **CTA:** "Your first upgrade comes fast. Tap to play." *(Numbers are illustrative. Do not claim real earnings.)*

### Script 10: Your first 60 seconds (onboarding)

- **Hook (0 to 2 s):** Text "60 SECONDS TO COOK" and the player's hand reaches for the grill.
- **Shot list**

| Time | Shot | On-screen text |
|---|---|---|
| 0:00 to 0:02 | Player walks up to the grill | 60 SECONDS |
| 0:02 to 0:08 | Customer sits, order bubble shows a burger | Order up |
| 0:08 to 0:15 | Hold, flip, collect (with on-screen prompts) | Hold. Flip. Collect. |
| 0:15 to 0:21 | Serve, first coins | First coins! |
| 0:21 to 0:25 | Player looks at the next order | Keep going |

- **Voiceover or caption:** "A new player is cooking in under a minute. Here is how."
- **CTA:** "Free to play. Tap to join."

---

## 7. Maturity and compliance questionnaire (guidance)

**Important:** These are likely answers based on `docs/GDD.md` and the config. The developer must check the current questions and labels in the Creator Hub and Roblox's Experience Guidelines before submitting. This is not legal advice.

**Likely answer: Minimal**

| Topic | Likely answer for this game | Basis |
|---|---|---|
| Cartoon or fantasy violence | None | Cooking and customer chaos only, no combat. |
| Realistic violence or gore | None | No weapons, no injury. |
| Blood | None | Not in the game. |
| Romance or sexual content | None | Not in the game. |
| Gambling or simulated gambling | None | No randomized rewards or spin mechanics. |
| Paid random items | None | GDD: "There are no paid random items." |
| Substance use | None | "Drink" is soda. |
| Profanity or crude humor | None to mild | Silly meme-food characters only. Confirm in review. |
| User-generated content | Limited | Crew and diner names are filtered with `TextService`. |
| Social features | Text chat (filtered) | Crew names and text chat only. No voice or video chat. |

**Checks to verify before submitting**

- Text chat is filtered and enabled only as Roblox's standard filtered chat. Confirm this in the Creator Hub.
- Crew and diner names pass through `TextService:FilterStringAsync`. Confirm that the filter is applied on every save.
- Developer product descriptions and game passes contain no crude content.
- Rewarded video ads, if enabled, are opt-in and never auto-played. Confirm the Roblox rewarded ad policy.
- If any paid random item is ever added, it needs odds disclosure and `PolicyService` checks first.
- If the questionnaire asks about voice or video chat, answer "No" unless that changes.
