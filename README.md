# Collect Brainrot Cards

A Roblox card collecting game inspired by *Collect Cat Cards!*: open packs of brainrot cards, chase rare variants, and put your best cards on stands that earn Cash every second, even while you're away.

## The game

- **Packs** (PACKS button): 5 packs, from the Starter Pack ($50) to the Galaxy Pack ($10M). Each pack gives 3 cards and has its own odds: the cheap rarities fade out and rarer ones (up to Divine) show up as packs get more expensive.
- **The reveal**: cards flip one by one, rarest last. Under each card, its chance is shown as **1/X**: the base chance of that exact card in that pack, with its variant applied (a Holo at 0.5% multiplies X by 200). Luck buffs never change the number shown.
- **Variants**: every card rolls its own variant, whatever the pack: Holo 0.5%, Rainbow 5%, Gold 20%. A card has a single variant, the rarest one rolled wins. Variants multiply the card's Cash (x50, x10, x3).
- **Fusion** (CARDS button): 5 identical cards fuse into the next variant (normal → Gold → Rainbow → Holo).
- **Stands**: each player gets a plot with 8 stands. Cards on stands earn Cash every second (rarity × pack × variant), shown above each stand and on the plot's sign. PLACE BEST fills the stands with the best cards.
- **Offline income**: the stands keep earning while you're away, up to 8 hours.
- **Weather**: every 10 minutes, a random weather buffs the whole server for 3 minutes: Lucky Breeze (x2 luck), Shiny Storm (x2 variant chances), Golden Hour (x2 Cash), or the rare Brainrot Eclipse (all three).
- **Pity**: in packs that have rarities below Epic, an Epic or better is guaranteed after 20 packs without one.
- **Index** (INDEX button): every card of every pack, found or not, with its 1/X chance. Each pack fully found gives +10% Cash forever.
- **Server announcements**: pulls rarer than 1/1,000 are announced to everyone.
- **Rewards** (REWARDS button): a daily reward that grows with your streak (7 days max) and codes (`BRAINROT`, `RELEASE`).

Every setting (cards, odds, prices, Cash, weather...) lives in [`src/shared/Config.luau`](src/shared/Config.luau).

## Project layout

The whole game is written in **Luau** as plain text files, and the map is built by code when the server starts.

| Folder | Where it goes in Roblox | What it does |
|---|---|---|
| `src/server/` | ServerScriptService | Packs, stands, income, weather, saving, map |
| `src/client/` | StarterPlayerScripts | The UI (packs and reveal, cards, Index, rewards) |
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

The 3D models come from the Creator Store (30 of the 36 cards have one, listed in `Config.ASSETS`). Cards without a model only show the card on their stand. Like in Speed Escape, the models have to be saved into the place once:

1. Open the place in Studio (edit mode, not Play), with Rojo connected.
2. Open **View > Command Bar**, paste the whole content of [`tools/import-assets.lua`](tools/import-assets.lua) and press Enter.
3. Wait for the `[Import] ... models added` line in the Output, then save the place (**Ctrl+S**).
