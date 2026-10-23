# Collect Brainrot Cards

A Roblox card collecting game inspired by *Collect Cat Cards!*: open packs of brainrot cards, chase rare variants, and put your best cards on stands that earn Cash every second, even while you're away.

## The game

- **The plaza**: in the middle of the map, around a giant brainrot statue, with 4 stands you use with the **E** key:
  - **Pack Shop**: buy packs (x1 or x5) and bigger backpacks. Bought packs go to your backpack.
  - **Sell**: sell cards (for 60 seconds of their Cash) and unopened packs (half their price).
  - **Grading**: grade a card (see below).
  - **Towers**: choose your team and fight (see below).
- **Packs** (PACKS button): the packs in your backpack, opened whenever you want, anywhere. 5 packs, from the Starter Pack ($50) to the Galaxy Pack ($10M). Each pack gives 3 cards and has its own odds: the cheap rarities fade out and rarer ones (up to Divine) show up as packs get more expensive.
- **Backpack**: 50 slots to start; every card and every unopened pack takes one (cards on the stands don't). When it's full you can't buy or open packs: sell cards or buy a bigger backpack at the Pack Shop (up to 300 slots).
- **Grading**: a card gets 4 scores from 1 to 10 (Centering, Corners, Edges, Surface). The average gives its grade, which multiplies its Cash and sell price: 10 (average 9.5+) x5 at 0.5%, 9 x3 at 2%, 8 x2 at 8%, 7 x1.6 at 14.5%, 6 x1.3 at 25%, 5 x1.15 at 25%, below x1 at 25%. It costs the card's pack price x its variant multiplier. A card is graded once, and graded cards can't be fused. Grades 9 and 10 are announced to the server.
- **The reveal**: cards flip one by one, rarest last. Under each card, its chance is shown as **1/X**: the base chance of that exact card in that pack, with its variant applied (a Holo at 0.5% multiplies X by 200). Luck buffs never change the number shown.
- **Variants**: every card rolls its own variant, whatever the pack: Holo 0.5%, Rainbow 5%, Gold 20%. A card has a single variant, the rarest one rolled wins. Variants multiply the card's Cash (x50, x10, x3).
- **Fusion** (CARDS button): 5 identical ungraded cards fuse into the next variant (normal → Gold → Rainbow → Holo).
- **Stands**: each player gets a plot with 8 stands. Cards on stands earn Cash every second (rarity × pack × variant), shown above each stand and on the plot's sign. PLACE BEST fills the stands with the best cards.
- **Offline income**: the stands keep earning while you're away, up to 8 hours.
- **Weather**: every 10 minutes, a random weather buffs the whole server for 3 minutes: Lucky Breeze (x2 luck), Shiny Storm (x2 variant chances), Golden Hour (x2 Cash), or the rare Brainrot Eclipse (all three).
- **Pity**: in packs that have rarities below Epic, an Epic or better is guaranteed after 20 packs without one.
- **Index** (INDEX button): every card of every pack, found or not, with its 1/X chance. Each pack fully found gives +10% Cash forever.
- **Server announcements**: pulls rarer than 1/1,000 are announced to everyone.
- **Towers**: a team of 3 cards fights automatically, floor after floor, in an arena. Each card has HP and DMG: the more Cash it makes (rarity × pack × variant, without grade nor Coin Boost), the stronger it is. On each floor the front card and the enemy headbutt each other until one falls; HP carry over between floors (10% heal per floor, full heal after a mini-boss), so it's an endurance test. 4 towers: Easy (100 floors), Medium (200), Hard (300) and Infinite (its best floor shows on the leaderboard). A mini-boss every 10 floors, a boss every 100. Rewards are kept when you lose or leave:
  - first clear of a floor: Cash, 1 pack per mini-boss (2 on floors 50, 150...), 2 packs and a card per boss;
  - cleared again: a quarter of the Cash and a chance of a pack on mini-bosses and bosses;
  - always: a **Trait Reroll** every 5 floors.
- **Traits**: a Trait Reroll gives a card of your backpack a random trait (never the one it had): DMG Boost (+30% DMG), HP Boost (+30% HP) or Coin Boost (+30% Cash, not its stats). Cards with a trait can't be fused.
- **Rewards** (REWARDS button): a daily reward that grows with your streak (7 days max) and codes (`BRAINROT`, `RELEASE`).

Every setting (cards, odds, prices, Cash, weather...) lives in [`src/shared/Config.luau`](src/shared/Config.luau).

## Project layout

The whole game is written in **Luau** as plain text files, and the map is built by code when the server starts.

| Folder | Where it goes in Roblox | What it does |
|---|---|---|
| `src/server/` | ServerScriptService | Packs, stands, income, weather, towers, saving, map |
| `src/client/` | StarterPlayerScripts | The UI (packs and reveal, cards, Index, rewards, towers) and the fight arena |
| `src/shared/` | ReplicatedStorage | Settings and shared helpers |
| `tools/` | (not in the game) | Script to import the 3D models into the place |

**Rojo** turns these files into a Roblox game: it builds a `.rbxl` place file, or syncs the files live into Studio.

## Testing the game

### Option 1: download the place

Every push makes GitHub build the place file:

1. On the repository page, open the **Actions** tab, then the latest successful "Build" (green check).
2. Under **Artifacts**, download `collect-brainrot-cards` and unzip it.
3. Open `collect-brainrot-cards.rbxl` in Studio (**File > Open**), then press **Play**.

### Option 2: live sync with Rojo

1. Clone the project with GitHub Desktop (**File > Clone repository**).
2. Put `rojo.exe` 7.7.1 in the project folder (the same one as for Speed Escape works), run `.\rojo.exe serve` in a terminal there and keep it open.
3. In Studio, open the game's `.rbxl` with **File > Open** (not the Baseplate template), then click **Rojo** > **Connect** and press **Play**.

To save progress between tests, turn on **Game Settings > Security > Enable Studio Access to API Services**.

## The brainrot models

The 3D models come from the Creator Store (30 of the 36 cards have one, listed in `Config.ASSETS`). Cards without a model only show the card on their stand. The look follows the big Roblox simulators (Steal a Brainrot, Grow a Garden): bright plastic colors, a studded green baseplate, a colored base per player (`Config.PLOT_COLORS`), a cyan cartoon sky (`Config.SKY`) and big floating labels.

The plaza decoration (stalls, lamps, trees, benches, flowers) also comes from the Creator Store (`Config.DECOR`); a missing model is replaced by a simple shape. Like in Speed Escape, the models have to be saved into the place once (run it again after an update that adds models: it only adds the missing ones):

1. Open the place in Studio (edit mode, not Play), with Rojo connected.
2. Open **View > Command Bar**, paste the whole content of [`tools/import-assets.lua`](tools/import-assets.lua) and press Enter.
3. Wait for the `[Import] ... models added` line in the Output, then save the place (**Ctrl+S**).
