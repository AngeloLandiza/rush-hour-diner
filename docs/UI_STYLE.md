# Rush Hour Diner: UI Style Guide

The visual and interaction spec for every piece of client UI. Tokens live in `src/shared/Config/UI.luau`
(pure data). `src/client/UI/Theme.luau` resolves them into Color3s, fonts and TweenInfos at runtime.
Components live in `src/client/UI/Components/*` and screens in `src/client/UI/Screens/*`. If this doc
and the code disagree, fix one of them in the same change.

Direction: **"Neon Diner Pop."** A 1950s diner rebuilt as candy-colored stickers. It uses chunky
rounded shapes, dark outlines on objects, glossy 3D buttons that physically press, and one loud
neon moment (Rush Hour).

## 0. What we learned (research, patterns only)

We studied patterns, never assets. No logos, art, names or exact layouts were copied.

1. **One color = one meaning, everywhere.** Top mobile games keep color semantics stable. Yellow is
   the primary action, green is buy/positive, red is notifications and danger, and blue/dark is
   background and low priority. A Clash Royale UX teardown notes that putting a paid item in the
   reward color confused players, and that unaffordable prices are shown in red text. Without that,
   players tapped things they couldn't buy. ([The Rookies: Clash Royale UX breakdown](https://www.therookies.co/blog/game-design-ux-best-practices-detailed-breakdown-of-clash-royale/))
2. **Persistent badges beat pop-ups.** Use at most one start-of-session pop-up. Everything else is a
   badge or a glow on the HUD button that leads to it. A full resource glows and pulses when it's
   ready. (Same source.)
3. **Thumb zone.** Primary controls go in the bottom half or bottom center on phones, and the HUD
   shows only real-time essentials (currency, timers, core actions). Everything else lives behind
   icon buttons. Respect safe areas (`ScreenInsets`). ([creation.dev: Roblox UI best practices](https://www.creation.dev/blog/roblox-ui-design-best-practices), [Roblox: HUD meters](https://create.roblox.com/docs/tutorials/use-case-tutorials/ui/create-hud-meters))
4. **Depth reads as "premium".** Roblox has no native UI shadow, so polished games layer a soft
   offset shadow frame, a white-topped gradient bevel and a stroke. Glows go on key buttons such as
   purchase and VIP. UIGradient Transparency and Offset, UIStroke `BorderStrokePosition` and UICorner
   at Scale 0.5 for pills are the building blocks. ([DevForum: Ultimate UI design guide](https://devforum.roblox.com/t/the-ultimate-ui-design-guide/1236916), [DevForum: UI shadows](https://devforum.roblox.com/t/how-to-create-ui-shadows/1537218), [Roblox: appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers))
5. **Juice timing.** Press is fast (50–100 ms, ease-out, scale about 0.95). Release is slower with an
   overshoot. Reward pops use a roughly 500 ms spring. Squash on UI should be subtle (2–5%).
   ([Animation principles for games](https://playbooks.com/skills/dylantarre/animation-principles/gaming-entertainment), [Buttons and CTAs](https://playbooks.com/skills/dylantarre/animation-principles/buttons-ctas))
6. **Custom prompts.** `ProximityPrompt.Style = Custom` plus `ProximityPromptService.PromptShown` and
   `PromptHidden` (LocalScript only) let us draw our own prompt. `InputHoldBegin` and `InputHoldEnd`
   trigger it from our own button. ([Roblox: proximity prompts](https://create.roblox.com/docs/ui/proximity-prompts))
7. **Simulator HUD conventions** (observed across top Roblox simulators, tycoons and casual cooking
   games): currency is a capsule with an oversized icon breaking its left edge. Menu entries are
   square icon tiles with a short stroked caption, stacked in side rails. Timers are compact pills
   that escalate (color, pulse) as they approach zero. Big wins get a slam-in stamp, rays and
   confetti, and coins visibly fly into the counter.

## 1. Design tokens

### Color roles (all derived from `Config/Palette`)

| Role | Palette source | Use |
|---|---|---|
| Surface | Cream | modal paper |
| Raised | White | cards, secondary buttons, bubbles |
| Sunken / SunkenDeep | CreamShade (→ Ink 18%) | wells, tracks, tab track |
| Glass | NightInk @ 18% transparency, white 80% rim | HUD counters and chips over the 3D world |
| Text / TextMuted / TextInverse | Ink / Ink→Cream 38% / White | copy |
| Outline / Shadow / Scrim | NightInk | sticker outlines, drop shadows, modal dim |
| Primary (+Deep, Edge, Light) | Mustard / MustardDeep | the main action: cook, collect, claim, coin buy |
| Success / Premium | Mint / MintDeep | positive, owned, **Robux purchases** |
| Danger | Ketchup / KetchupDeep | close, clear, warnings, badges |
| Accent | NeonPink (→ KetchupDeep for Deep) | free rewards (ads, daily), Rush Hour, legendary |
| Info | InkSoft / Ink | neutral headers (leaderboard, settings) |
| Gold (+Deep, Light) | Mustard family | currency, numbers |
| Patience High/Mid/Low | Mint → Mustard → Ketchup | patience ring, continuous blend |
| RushHot / RushWarm / RushDeep | NeonPink / Mustard / NeonPink→NightInk | Rush bar and edge glow |

Rules:
- Coin prices are mustard, Robux prices are mint and free rewards are pink. Paid and earned never
  share a color.
- An unaffordable coin price turns into a white button with **ketchup text**. It stays tappable and
  explains "Need N more coins".
- Light text on a saturated face always gets an Outline text stroke.

### Typography (Roblox `FontFace`, both built in)

| Token | Font | Size | Use |
|---|---|---|---|
| Hero | Fredoka One | 48 | stamps, coin popups, float text |
| Display | Fredoka One | 32 | station action button |
| Heading | Fredoka One | 24 | modal titles, coin counter |
| Title | Fredoka One | 20 | card names, prompt action, rush timer |
| Body | Builder Sans Bold | 16 | toasts, coach text |
| Small | Builder Sans Bold / Fredoka | 14 | chips, tabs |
| Caption | Builder Sans Bold | 12 | descriptions, sub-labels |
| Micro | Fredoka One | 11 | keycaps, over-labels ("RUSH HOUR IN") |

Fredoka One (`Enum.Font.FredokaOne`) handles headings and every number. Builder Sans Bold
(`Enum.Font.BuilderSansBold`) handles readable copy. Labels that can overflow use `Util.fit`, which
scales text down to 10 px minimum. Buttons measure text with `TextService` and shrink it to fit.

### Spacing, radii, strokes

- Spacing: XS 4, SM 8, MD 12, LG 16, XL 24. Screen margin is 8 and the HUD gap is 6.
- Radii: SM 8, MD 12, LG 16, XL 20, plus pill (scale 0.5). Modals are 18.
- Strokes: Hair 1, Thin 2 (control edges), Base 2.5 (panels, icons, cards that need weight), Bold 3.5
  (bubbles, stamps).
- Objects (icons, modals, bubbles) get a dark Outline. Controls get a same-hue "Edge" stroke (a
  deeper shade of their face), which reads cleaner than ink outlines everywhere.

### Depth recipe

```
  ┌──────────────┐  face: base color, UIGradient white→10% darker (bevel), 2px Edge stroke
  │▔▔▔▔▔▔▔▔▔▔▔▔▔▔│  highlight: white band, 72% transparent, top 42% of the face
  │    LABEL     │
  └──────────────┘
  └──────────────┘  lip: Deep shade, offset +4px (3px small)
   ░░░░░░░░░░░░░░   shadow: NightInk 78% transparent, offset lip+2px
```

Cards use the same idea without the lip: a shadow at +4 px, a face and a bevel.

### Motion (Config/UI.Motion)

| Motion | Spec | Notes |
|---|---|---|
| Press | 0.07 s Quad Out, scale 0.94, face sinks 75% of the lip | instant feedback |
| Release | 0.28 s Back Out → 1.0 | springy overshoot |
| Hover (mouse only) | 0.12 s Quad Out, scale 1.04 | not on touch |
| PopIn | 0.32 s Back Out from 0.55 | toasts, chips, bubbles, panels (from 0.86) |
| PopOut | 0.14 s Quad In → 0 | always shorter than PopIn |
| Bounce | 0.42 s Back Out from 1.18 | value changed, level up |
| Pulse | 0.6 s Sine InOut ±5%, looped | ready or claimable items |
| Count-up | 0.6 s Quad Out | coin counter never jumps |
| Coin fly | burst 0.2 s Back Out (radius ≤ 46), travel 0.5 s Quad In, stagger 0.04 s | 3–12 coins (log₂ of amount) |
| Banner | in 0.45 s Back Out, hold 4.5 s, out 0.3 s Back In | |
| Stamp | slam from 2.2× in 0.3 s Back Out, hold 1.4 s, swell to 1.35 and fade | |

## 2. Components

| Component | File | Variants and states |
|---|---|---|
| Button | `Components/Button` | primary, secondary, success, premium, danger, accent, info, ghost. States: idle, hover, pressed, disabled. Has an optional icon (left of the text), auto-fit text and a 44 px minimum size. `SetVariant`, `SetIcon`, `SetText`, `SetEnabled`, `SetColor`, `Bounce`. |
| Card | `Components/Card` | paper (cream, ink outline), raised (white), sunken (well), glass (HUD), accent (custom color). The root holds the layout and `.face` holds the content. |
| Panel (modal) | `Components/Panel` | scrim, cream paper, colored header band, icon medallion that breaks the top edge, round danger close, pinned toolbar and scrolling body. One open at a time. Tapping the scrim or pressing ButtonB closes it. |
| Tabs | `Components/Tabs` | segmented pill with a sliding raised thumb. The selected tab has ink text and the rest are muted. There is an optional red dot per tab. |
| Badge | `Components/Badge` | a count ("3", "9+") or "!". Pops on change and pulses while visible. |
| Toast | `Components/Toast` | white pill with a kind icon disc and a kind-colored edge. Kinds are Info, Success, Warning, Error and Reward. Max 3, newest on top. |
| ProgressBar | `Components/ProgressBar` | sunken pill track, beveled fill, gloss, optional moving stripes and a centered caption. Driven by `SetRange` and `Step`. |
| Stripes | `Components/Stripes` | diagonal candy stripes using 45° stepped-gradient tiles (no rotated frames, so clipping works). |
| Countdown | `Components/Countdown` | label bound to a server timestamp. |
| CurrencyCounter | `Components/CurrencyCounter` | glass capsule, oversized icon, count-up, a punch per arriving coin, an optional "+" button. |
| Tooltip | `Components/Tooltip` | mouse-only glass bubble beside a target. |
| Toggle | `Components/Toggle` | pill switch with a sliding knob. Mint when on. |
| Stamp | `Components/Stamp` | tilted slam-in word plus a sub line. |
| Confetti | `Components/Confetti` | palette chips that burst, tumble and fade. |
| Icons | `UI/Icons` | code-built sticker icons in three passes: shadow, outline silhouette, fills. Includes Coin, Shop, Trophy, Crew, Gear, Clock, Flame, Calendar, Crate, Burger, Fries, Pizza, Drink, Bolt, Star, Crown, ChefHat, Potion, Robot, Stool, Music, Speaker, Check, Close, Plus, Lock, Info, Warning, Error, Success, Chevron, Ad and Cart, plus the composites Coins2 and Coins3. `"A+B"` puts a small B badge on A. `Config/UI.Images[name] ≠ 0` swaps in an uploaded image. |
| CoinFly | `UI/CoinFly` | coins from a world, screen or local point into the HUD counter. |

## 3. HUD layout

The design space is 360×640 scaled by UIScale (1.0–1.5). The ScreenGui uses `CoreUISafeInsets`, so
nothing sits under the Roblox top bar or a notch.

### Desktop and landscape (width ≥ 560)

```
┌────────────────────────────────────────────────────────────────────────┐
│ (●)  12,345  [+]        ╭ ◷ RUSH HOUR IN  41:07 ╮                  (*) │
│                         ╰───────────────────────╯                      │
│                      [p +50% 12:31] [f COMBO ×3]                     │
│                          ┌ toast ───────────────┐                      │
│ ┌────┐                   └──────────────────────┘               ┌────┐ │
│ │ Sh │ !                                                        │ Dy │!│
│ └SHOP┘                                                          └DAY2┘ │
│ ┌────┐                                                          ┌────┐ │
│ │ Cr │                                                          │ Rs │ │
│ └CREW┘                                                          └1.2K┘ │
│ ┌────┐                                                         NEW MENU│
│ │ Tp │                                                          2d 4h  │
│ └TOP─┘                      ╭─ HOLDING Burger [PERFECT] ─╮             │
│                    ┌──────────── station panel ────────────┐          │
│                    └───────────────────────────────────────┘          │
└────────────────────────────────────────────────────────────────────────┘
```
(Two-letter codes stand in for the code-built icons: Sh shop bag, Cr crew, Tp trophy, Dy calendar, Rs restock crate; p potion, f flame, b burger.)

### Phone portrait, 360×640 (width < 560)

```
┌────────────────────────────────────┐
│ (●) 12,345 [+]                 (*) │  row 1: currency and gear
│      ╭ ◷ RUSH HOUR IN 41:07 ╮      │  row 2: rush widget (bar is 320 wide when active)
│   [p +50% 12:31] [f COMBO ×3]    │  row 3: chips (only when present)
│   ┌ toast ───────────────────┐     │
│ ┌──┐                         ┌──┐  │
│ │Sh│                         │Dy│  │  rails are centered above the
│ ┌──┐                         ┌──┐  │  station panel reserve (they would
│ │Cr│                         │Rs│  │  collide horizontally)
│ ┌──┐                       NEW MENU│
│ │Tp│                               │
│      ╭ HOLDING Burger [PERFECT] ╮  │
│ ┌──────── station panel ────────┐  │
│ │ (b) GRILL · Burger         ⓧ │  │
│ │ [████████ COOKING ░░░░░░░]    │  │
│ │ [      HOLD TO COOK  SPACE ]  │  │
│ └───────────────────────────────┘  │
└────────────────────────────────────┘
```

On short screens (landscape phones, height < 360), the held-dish chip and coach mark hide while the
station panel is open.

## 4. Screens

### Shop (Upgrades / Passes / Products)
- The header is Ketchup with a bag medallion. The tabs have icons (Bolt, Crown, Coin). The Upgrades
  tab dot lights when something is affordable, and the HUD shop tile shows the count as a badge.
- Each card has, left to right: a 54 px tinted icon tile, then the name (Title), a 2-line muted
  effect line and level pips (multi-level only), then a price button at right.
- Upgrade prices are a mustard button with a coin and a short number ("1.5K"). When unaffordable,
  the button is white with ketchup text and a tap shakes the card and toasts the shortfall. A maxed
  upgrade shows a mint "MAX" with a check.
- A level-up bounces the card, bursts confetti and shows a "<name> upgraded!" toast.
- Passes and products use mint "R$ N" buttons. Owned passes show a mint "Owned" with a check.
  Unconfigured ids (0) show a disabled "Soon" and are never prompted.
- Products open with a pink **Free Tip Boost** card (the rewarded ad). It is opt-in, sits behind a
  "Watch" button and has a cooldown.
- The coin capsule's "+" opens the shop straight on Products.

### Leaderboard
- The header is Info (ink). Tabs are Lifetime (coin) and Rush Hour (flame).
- Each row has a medal disc (gold, silver, bronze, then plain sunken), the name and a short score
  with a coin. The local player's row is tinted mustard.
- The empty state is a sunken card with a trophy.

### Crew
- The header is Mint. "Your diner" card shows the name, a role line and seat pips (players / 4).
- Owners get a rename well with Save (enter also submits). Crew members get a full-width danger
  "Leave crew".
- "Join a friend's diner" lists other diners: an initial avatar disc, the name, seat pips and
  "Join" / "Joined ✓" / "Full".

### Settings
- Each icon row (Music, Speaker) has a title, a sub line and a Toggle.

### Station minigame panel (bottom center, 344×186)
- A dish medallion breaks the top edge. The title is "GRILL · Burger" with a muted phase hint under
  it, and a round close sits top-right.
- The track is a striped bar while cooking or finishing (mustard, then pink). While ready it drains
  mint and turns ketchup in the last 3 s, captioned "BURNS IN 5s". While flipping it becomes the flip
  track: a mint PERFECT zone, a mustard GOOD remainder and a white needle.
- The action button changes per phase: HOLD TO COOK (primary + flame), COOKING... (disabled), FLIP!
  (accent + bounce), ALMOST... , COLLECT (success), CLEAR (danger). A keycap chip ("SPACE" / "A")
  shows for keyboard and gamepad.
- Feedback: a PERFECT! or GOOD! stamp above the panel after the flip, and a BURNT! stamp plus a
  panel shake.
- It opens from the station ProximityPrompt (StationController) and closes past the interact range.

### Order bubbles (BillboardGui on the customer Head)
- A white speech bubble (84 px face, radius 28, bold outline, shadow) with a tail.
- The dish icon sits inside a **patience ring**. The ring is two clipped halves masked by
  hard-stepped gradients, so it drains clockwise from 12 o'clock. Its color blends continuously
  Mint → Mustard → Ketchup.
- Kind tag: VIP (mustard, crown), HUNGRY! (ketchup) or the legendary name (pink, star). A legendary
  also gets a pink frame and spinning gold rays.
- Below 25% patience the bubble wiggles and its outline turns ketchup.
- When served, the icon swaps to a mint check, bounces and pops out. Serving the wrong dish shakes
  the bubble.

### Custom proximity prompts
- Every prompt uses `Style = Custom` locally. The pill holds a keycap (E / F, gamepad X / Y, or an
  icon on touch), the action (Title) and the object (Caption).
- A tap calls `InputHoldBegin` / `InputHoldEnd`, so all triggering stays in ProximityPromptService.
- The Serve prompt turns mint when you hold the right dish. A station's prompt hides while its panel
  is open.
- If building the UI fails, the prompt falls back to Default.

### Toasts
- Pills sit top-center under the status rows, 330 px max width, 3 s. Kinds map to color and icon:
  Info ink "i", Success mint check, Warning mustard "!", Error ketchup ×, Reward coin.

### Legendary banner
- Gold rays spin behind a pink→gold→pink ribbon (ink outline, folded tails). A tilted "LEGENDARY"
  crown kicker sits on top, a white shine sweeps across, and confetti bursts on entrance.
- The headline is the announcement, or "X served Y!". The sub line is "+N tip!" in gold.

### Rush Hour treatment
- **Idle:** a glass pill with a clock, "RUSH HOUR IN" and m:ss. In the last 60 s it turns pink,
  pulses and reads "RUSH HOUR SOON!".
- **Active:** the widget morphs (Back) into a 320×50 neon bar:
  - a dark pink base
  - a pink→gold fill that drains with time left, with moving stripes and gloss
  - a bobbing flame breaking the left edge
  - "RUSH HOUR!" with "Started by X" or "Every coin pays double!"
  - the big timer
  - a tilted "2× PAY" tag
  - a pulsing pink glow behind it
- Pink edge glow frames the screen. A "RUSH HOUR!" stamp ("2× PAY · 3× CUSTOMERS") fires when a
  rush starts.

### Tutorial (coach mark, not a banner)
- A compact glass chip with a pink rim sits bottom-center, above the held chip and the station
  panel. It shows a step disc (1–3), one short line, step dots and a Skip.
- In the world, a pink "COOK HERE" / "COLLECT" / "SERVE" tag with a bobbing chevron, plus a thin
  fading beam from the player.
- It completes on the first serve (after a "Nice!" beat), on Skip or on timeout.

## 5. Accessibility and touch
- Every interactive element is at least 44×44 design px (Button enforces it with UISizeConstraint).
  Tabs are 44 tall.
- Information is never color-only. Quality has text tags, patience has ring length plus a wiggle,
  and prices have icons.
- Keyboard and gamepad: B shop, L leaderboard, C crew, O settings, R daily, Space/A cook action,
  ButtonB closes modals. Keycaps appear in the station button and prompts.

## 6. Phase 2 hooks
- `Config/UI.Images` maps hero icons to uploaded image ids. 0 keeps the code icon.
- Screenshot loop checklist: HUD idle, shop open, station panel, customer bubble, Rush active,
  legendary banner, plus a small viewport.

## 7. Implementation rules learned in Studio (phase 2)
- **Every BillboardGui sets `ZIndexBehavior = Sibling`.** The default (Global) let ring discs bury the
  dish-icon shapes inside the order bubbles.
- Name important buttons uniquely: `ShopButton`, `CrewButton`, `TrophyButton`, `CalendarButton`,
  `CrateButton`, `SettingsButton`, `<Title>CloseButton`, `CookActionButton`, `StationCloseButton`.
  Automation and tests can then click them by path.
- The keycap hint is a tilted sticker on the action button's top-right corner, so it never covers
  the label.
- Small-screen preview (Studio only): set
  `PlayerGui.RushHourDiner:SetAttribute("DebugViewport", Vector2.new(360, 640))` (or 640×360). Set it
  to nil to restore the real viewport.
- `screen_capture` does not render BillboardGuis. To review bubbles and prompts, clone
  `OrderBubble.Bubble` or `RHD_Prompt.Hit` into a temporary Sibling ScreenGui.
