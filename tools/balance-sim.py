# Simulates an active player to check the pace of the economy (python3 tools/balance-sim.py).
# Reads the rarities, variants and packs from src/shared/Config.luau, then plays N runs:
# the player spends half of their income on the best pack they have unlocked, keeps the best
# cards on the stands and sells the rest, and saves the other half to buy the next pack as soon
# as they can. Prints, for each pack, when it is first bought (median, fast 10%, slow 10%).
# Not counted: offline income, towers, weather, Index bonus, walking to the Shop or the Sell stand.
import math
import random
import re
import statistics
from pathlib import Path

CONFIG = (Path(__file__).parent.parent / "src/shared/Config.luau").read_text()
RUNS = 40
OPEN_TIME = 6  # seconds to buy and open one pack (the opening animation included)
HORIZON = 60 * 3600
SPEND = 0.5  # share of the income spent on packs of the current tier


def number(name, text=CONFIG):
    return float(re.search(r"%s = ([\d.]+(?:e\d+)?)" % name, text).group(1))


RARITY = {m[0]: float(m[1]) for m in re.findall(r'\{ id = "(\w+)", name = "[^"]+", order = \d+, color = [^}]*\), cash = ([\d.]+) \}', CONFIG)}
VARIANTS = [(float(c), float(m)) for c, m in re.findall(r'\{ id = "\w+", name = "\w+", chance = ([\d.]+), cash = ([\d.]+), color', CONFIG)]
PACKS = []
for block in re.findall(r"\{\n\t\tid = \"\w+\",\n\t\torder.*?\n\t\},", CONFIG, re.S):
    odds = {r: float(o) for r, o in re.findall(r"(\w+) = ([\d.]+)", re.search(r"odds = \{(.*?)\}", block).group(1))}
    PACKS.append({"name": re.search(r'name = "([^"]+)"', block).group(1), "price": number("price", block), "cash": number("cash", block), "odds": odds})

STANDS = int(number("Config.STAND_COUNT"))
CARDS = int(number("Config.CARDS_PER_PACK"))
SELL_RATIO = number("Config.SELL_RATIO")
START = number("Config.STARTING_CASH")
VARIANT_AVERAGE = sum(c / 100 * m for c, m in VARIANTS) + 1 - sum(c for c, _ in VARIANTS) / 100
for pack in PACKS:
    pack["average"] = sum(o / 100 * RARITY[r] for r, o in pack["odds"].items()) * pack["cash"] * VARIANT_AVERAGE


def pull(pack):
    roll = random.random() * 100
    for rarity, odds in pack["odds"].items():
        roll -= odds
        if roll <= 0:
            break
    variant = 1
    for chance, cash in VARIANTS:
        if random.random() * 100 < chance:
            variant = cash
            break
    return RARITY[rarity] * pack["cash"] * variant


def play():
    cash, budget, time, stands, first = START, START, 0.0, [], {0: 0.0}
    tier = 0

    def open_pack(index):
        nonlocal cash, budget, time
        pack = PACKS[index]
        for _ in range(CARDS):
            stands.append(pull(pack))
            stands.sort(reverse=True)
            if len(stands) > STANDS:
                money = pack["price"] / CARDS * SELL_RATIO * stands.pop() / pack["average"]
                cash += money
                budget += money
        income = sum(stands)
        time += OPEN_TIME
        cash += income * OPEN_TIME
        budget += income * SPEND * OPEN_TIME

    cash -= PACKS[0]["price"]
    budget -= PACKS[0]["price"]
    open_pack(0)
    while time < HORIZON and tier < len(PACKS) - 1:
        income = sum(stands)
        if cash >= PACKS[tier + 1]["price"]:
            tier += 1
            first[tier] = time
            cash -= PACKS[tier]["price"]
            budget = min(budget, cash)
            open_pack(tier)
        elif budget >= PACKS[tier]["price"] and cash >= PACKS[tier]["price"]:
            cash -= PACKS[tier]["price"]
            budget -= PACKS[tier]["price"]
            open_pack(tier)
        else:
            # Nothing to buy yet: skip ahead to the next purchase
            wait = min((PACKS[tier]["price"] - budget) / (income * SPEND), (PACKS[tier + 1]["price"] - cash) / income)
            wait = max(1.0, math.ceil(wait))
            time += wait
            cash += income * wait
            budget += income * SPEND * wait
    return first


def minutes(seconds):
    return "never" if seconds is None else "%d h %02d" % divmod(round(seconds / 60), 60)


results = [play() for _ in range(RUNS)]
for index, pack in enumerate(PACKS):
    times = sorted(r.get(index, HORIZON * 10) for r in results)
    pick = lambda t: None if t >= HORIZON else t
    print("%-13s median %8s   fast %8s   slow %8s" % (pack["name"], minutes(pick(statistics.median(times))), minutes(pick(times[RUNS // 10])), minutes(pick(times[RUNS * 9 // 10]))))
