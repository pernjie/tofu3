# Game Balance Framework

## Core Principle: Low Numbers, Clear Math

The economy is built on one rule: **1 need = 1 money**. A guest with 2 needs should baseline-carry 2 money. Every deviation from this tells the player something about the guest's skill and the strategy required.

This means players can do mental math at a glance. "This guest has 3 needs and 2 money — something about their skill must compensate, or I need a strategy."

---

## The Value Unit (VU)

**1 VU = 1 point of need fulfillment.**

This is the atomic unit of the economy. Everything is priced relative to it:

| Concept | Baseline |
|---|---|
| 1 guest need point | costs 1 money to fulfill |
| 1 stall service | provides VU equal to its cost_to_guest |
| Guest money budget | equals their total need points |

When a stall provides 2 VU for 2 money, that's baseline — no profit, no loss, just conversion. Profit and loss come from deviations.

### Two Currencies

The game has two separate economies:

- **Money** — Guest-level currency. Guests carry money, spend it at stalls. Money exists only within a level and measures whether a guest can afford a stall's service. A guest with 2 money can spend 1 at each of two stalls, or 2 at one premium stall. When a guest runs out of money, they can't pay for more services.
- **Tokens** — Player-level currency. Used between levels to buy cards, upgrade stalls, and build the deck. Token income is not derived from guest money — these are intentionally decoupled so the guest economy and player economy can be balanced independently.

The VU framework governs the money economy (guest needs vs. stall costs). Token pricing is a separate balance lever (see [Stall Pricing](#stall-pricing-token-cost)).

---

## Guest Balance

### Money Budget Formula

```
money = total_needs + skill_adjustment
```

Where `skill_adjustment` is:

| Skill Type | Adjustment | Reasoning |
|---|---|---|
| No skill (vanilla) | +0 to +1 | Slight generosity for simple guests |
| Beneficial to player | -1 to -2 | Skill IS the value — money is tight |
| Harmful to player | +1 to +2 | Compensation for disruption |
| Demands strategy | -1 to -3 | Punishes lazy play, rewards mastery |

### Guest Archetypes

**Vanilla Guests** — No skills, straightforward. Slight money surplus so new players can profit. These are the "bread and butter" that fund the player's economy.

- *Example: Hungry Ghost* — 2 food needs, 2-3 money. Easy to serve, small reliable profit.
- *Example: Wandering Shade* — 2 needs (1 food + 1 joy), 2-3 money. Needs two stall types but still fair.

**Benefit Guests** — Their skill helps the player. Tight budget because the skill IS the payoff.

- *Example: Apothecary* — 3 food needs, 2 money. Bad deal on paper, but restocks your stall when it empties. The restock saves you a turn, which is the real value.
- *Example: Cat Lady* — 2 joy needs, 2 money. Tight budget, but summons a Cat that provides free AOE joy on ascend. The value is in the cat, not the money.

**Disruption Guests** — Their skill hurts the player. Generous budget as compensation.

- *Example: Drunkard* — 2 joy needs, 3-4 money. Pays well but resets service durations when entering a stall, costing you tempo.
- *Example: Old Man* — 2 needs, 3 money. Pays above rate but takes 2x longer to serve, blocking stall capacity.

**Strategy Guests** — Their skill creates a puzzle. Tight budget that only works if you solve it.

- *Example: Seamstress* — 4 needs (2 food + 2 joy), 2 money. Terrible deal normally. But perfectionist triggers ascension on exactly 2 VU served — so the right stall tier skips all remaining needs. The player must build toward that exact number.
- *Example: Dancer* — 3 joy needs, 3 money. Fair budget — the Charmed AOE on ascend is already a net negative for the player by default (blocks service on other guests). Good players can leverage it with Yoga Mat synergy, but forcing that synergy would be too punishing. Fair value lets the dancer exist as a "build-around if you want" rather than "must combo or lose".

### Multi-Need Guests

Guests with multiple need types are inherently harder to serve (require multiple stall types nearby). This is a hidden cost, so multi-need guests should have slightly more money relative to single-need guests of the same total.

```
multi_need_bonus = (number_of_distinct_need_types - 1)
```

A guest with 2 food + 1 joy (2 types) gets +1 implicit value over a guest with 3 food (1 type), because the player needs more infrastructure to serve them.

---

## Stall Balance

### Efficiency Rating

```
efficiency = service_value / cost_to_guest
```

| Efficiency | Meaning |
|---|---|
| 1.0 | Baseline — guest breaks even |
| < 1.0 | Guest overpays — player profits, stall is "good value for player" |
| > 1.0 | Guest underpays — player subsidizes, stall needs a skill to justify |

### Stall Archetypes

**Workhorse Stalls** — No skills, reliable efficiency near 1.0. The backbone of the economy.

- *Example: Game Booth* — Efficiency ~1.0 at all tiers. Predictable, no surprises.
- *Example: Noodle Stand* — Slight player profit (efficiency ~0.8). Reliable food source.

**Strategy Stalls** — Below-baseline efficiency WITHOUT their skill. The skill creates a conditional bonus that rewards specific board states.

- *Example: Yoga Mats* — 1 VU for 1 money (efficiency 1.0, no profit). Baseline is break-even. But with a debuffed guest, bonus fulfillment kicks in, making it very efficient. Without debuff synergy, it's the worst stall in the shop.

**Event Stalls** — Have periodic or conditional power spikes.

- *Example: Mooncake Stand* — Below-baseline efficiency normally. But at midnight, value doubles and cost zeroes. The player must time guest arrivals around midnight for the spike.

### Product Stall Baseline

Product stalls sell discrete items from a stock pool. The guest walks up, pays, receives VU, stock decreases. When stock hits 0, the stall restocks over time.

**Vanilla T1 Product Stall:**

| Stat | Baseline | Rule |
|---|---|---|
| Stock | 2 | How many guests can be served before restock |
| Restock duration | 2 turns | 1 stock = 1 turn of restock time |
| Value per purchase | 1 VU | Each stock unit fulfills 1 need point |
| Cost to guest | 1 money | 1:1 with value (baseline efficiency) |

The **stock:restock ratio** is the key identity lever. A stall with better throughput (3 stock, 2 restock) is more convenient but should pay for it with lower value or higher cost. A stall with worse throughput (2 stock, 3 restock) is slower but should compensate with higher value or a skill.

**Product stall identity axes:**

| Identity | Tradeoff | Example |
|---|---|---|
| High stock, slow restock | Burst serving, then long downtime | Festival stall: 4 stock, 4 restock |
| Low stock, fast restock | Steady trickle, never empty long | Street vendor: 1 stock, 1 restock |
| High value, high cost | Premium — great for rich guests, bad for poor | Fine dining: 2 VU, 2 cost |
| Skill-dependent | Bad baseline, great with synergy | Mooncake (midnight feast) |

### Service Stall Baseline

Service stalls occupy guests for a duration. The guest enters, pays, sits for N turns, then receives VU on completion. Multiple guests can occupy a stall up to its capacity.

**Guests have no time limit.** There is no cost *to the guest* for spending turns in a service stall — they don't expire or lose value by waiting. The cost is entirely to the *stall's* throughput: an occupied slot can't serve anyone else. Guests who walk past a full stall keep moving and may never return. This makes capacity the critical service stall stat.

**Vanilla T1 Service Stall:**

| Stat | Baseline | Rule |
|---|---|---|
| Value | 2 VU | Total need points fulfilled on completion |
| Duration | 3 turns | How long the guest is occupied |
| Capacity | 1 | How many guests can be served simultaneously |
| Cost to guest | 2 money | 1:1 with value (baseline efficiency) |

Both stall types start at the same per-stall throughput (**0.67 VU/turn**), but their failure modes differ — product stalls have restock downtime, service stalls deny guests while at capacity. See [Throughput Comparison](#throughput-comparison) for the full analysis. T1 is intentionally weak for both types — upgrades come quickly.

Service stalls trade **throughput** against **exclusion**. The bottleneck is how many guests can sit simultaneously. While a guest occupies a slot, no other guest can use it — but the guest pays no cost for waiting (no time limit). A capacity-2 stall pipelines guests (once full, one finishes per tick), dramatically increasing throughput. Duration determines how long each slot is occupied — shorter duration means faster cycling.

**Service stall identity axes:**

| Identity | Tradeoff | Example |
|---|---|---|
| High capacity, long duration | Serves many simultaneously, slow per-guest cycling | Bathhouse: cap 3, 3 turns |
| Low capacity, short duration | Fast cycling, but few guests at once | Massage: cap 1, 1 turn |
| High value, long duration | Big payoff per guest, slot occupied longer | Meditation: 3 VU, 3 turns |
| Skill-dependent | Bad baseline, great with synergy | Yoga Mats (debuff bonus) |

### Tier Progression

**~50% improvement per tier, always along the same axis.** A stall's identity determines which stat it scales — and every tier deepens that same strength. A stock-focused product stall gets more stock at T2 *and* T3, not stock at T2 then restock at T3. You're sharpening an identity, not rounding out weaknesses.

The tradeoff against going wide: a T2 stall is ~50% better than T1, but placing a second T1 copy gives 100% more output at double the board space. Early game, go wide. Late game when space is scarce, upgrade.

| Tier | Role | Improvement |
|---|---|---|
| T1 | Functional but tight. Thin margins. | — |
| T2 | Comfortable. Worth upgrading if this stall is core to strategy. | ~50% on the identity axis |
| T3 | Powerful. A commitment — space efficiency is unmatched. | ~50% again on the same axis |

**Product tier examples (stock-focused identity):**

| Tier | Stock | Restock | Value | Cost | What improved |
|---|---|---|---|---|---|
| T1 | 2 | 2 | 1 | 1 | — |
| T2 | 3 | 2 | 1 | 1 | +50% stock |
| T3 | 4 | 2 | 1 | 1 | +33% stock (2× baseline) |

**Product tier examples (value-focused identity):**

| Tier | Stock | Restock | Value | Cost | What improved |
|---|---|---|---|---|---|
| T1 | 2 | 2 | 1 | 1 | — |
| T2 | 2 | 2 | 2 | 2 | +100% value (cost scales) |
| T3 | 2 | 2 | 3 | 3 | +50% value (cost scales) |

**Service tier examples (capacity-focused identity):**

| Tier | Value | Duration | Capacity | Cost | What improved |
|---|---|---|---|---|---|
| T1 | 2 | 3 | 1 | 2 | — (0.67 VU/turn) |
| T2 | 2 | 3 | 2 | 2 | +100% capacity (pipelines to ~1.3 VU/turn) |
| T3 | 2 | 3 | 3 | 2 | +50% capacity (pipelines to 2.0 VU/turn) |

**Service tier examples (value-focused identity):**

| Tier | Value | Duration | Capacity | Cost | What improved |
|---|---|---|---|---|---|
| T1 | 2 | 3 | 1 | 2 | — (0.67 VU/turn) |
| T2 | 3 | 3 | 1 | 3 | +50% value (1.0 VU/turn, cost scales) |
| T3 | 4 | 3 | 1 | 4 | +33% value (1.33 VU/turn, cost scales) |

Note: when value increases, cost to guest should scale proportionally to maintain efficiency. The improvement is throughput (more VU per visit), not free value. The player benefits because fewer stall visits = fewer turns spent = more guests servable.

### Throughput Comparison

Both stall types have the same per-stall throughput at T1: **0.67 VU/turn**. The difference is in their **denial pattern** — how often they turn guests away — and how many board slots it takes to eliminate denials.

#### Per-Stall Cycles

**Product** (2 stock, 2 restock, 1 VU) — Serve, serve, dead. The restock's final tick completes at TURN_START, and the stall can serve again at STALL_ENTRY on the same turn, so 2 turns of restock = 1 dead turn. Throughput = `stock / (stock + restock - 1)` VU/turn. Baseline: `2 / (2 + 2 - 1)` = **0.67 VU/turn**. Denial rate: **1 in 3 turns (33%).**

**Service** (2 VU, 3 duration, cap 1) — Enter, occupied, occupied. Guest completes at SERVICE_RESOLUTION and a new guest enters at STALL_ENTRY on the same turn, so the cycle is exactly `duration` turns. Throughput = `value / duration` VU/turn. Baseline: `2 / 3` = **0.67 VU/turn**. Denial rate: **2 in 3 turns (67%).**

Same VU/turn, but service stalls deny twice as many guests per stall. This is where the board-level comparison matters.

#### Multi-Stall Analysis (1 guest/turn, stalls on the same path)

When a guest can't be served at one stall, they continue to the next. This is the realistic scenario — multiple stalls of the same type covering a path.

**2 Product Stalls — 0% denial:**

```
Turn 1: Guest → S1 (stock 2→1)                         ✓
Turn 2: Guest → S1 (stock 1→0), restock begins          ✓
Turn 3: Guest → S1 (empty) → S2 (stock 2→1)             ✓
Turn 4: Guest → S1 (restocked, 2→1)                     ✓
Turn 5: Guest → S1 (stock 1→0), restock begins           ✓
Turn 6: Guest → S1 (empty) → S2 (stock 1→0)              ✓
Turn 7: Guest → S1 (restocked, 2→1)                     ✓
```

S2 absorbs S1's downtime naturally. The stalls self-stagger because S2 only depletes when S1 is restocking. **Every guest served. 1.0 VU/turn total.**

**2 Service Stalls — 33% denial:**

```
Turn 1: Guest → S1 (enters)                              ✓
Turn 2: Guest → S1 (full) → S2 (enters)                  ✓
Turn 3: Guest → S1 (full) → S2 (full)                    ✗
Turn 4: S1 completes. Guest → S1 (enters)                ✓
Turn 5: S2 completes. Guest → S1 (full) → S2 (enters)   ✓
Turn 6: Both full                                         ✗
```

Repeating cycle: serve, serve, deny. **1.33 VU/turn total, but 1 in 3 guests walks past unserved.**

**3 Service Stalls — 0% denial:**

```
Turn 1: Guest → S1    Turn 4: S1 completes → Guest enters
Turn 2: Guest → S2    Turn 5: S2 completes → Guest enters
Turn 3: Guest → S3    Turn 6: S3 completes → Guest enters
```

Perfect pipeline. **2.0 VU/turn, every guest served.**

#### Summary: Board Slots Required for Zero Denial

| | Product | Service |
|---|---|---|
| Slots for 0% denial | **2** | **3** |
| VU/turn at 0% denial | 1.0 | 2.0 |
| VU/turn per slot | 0.50 | 0.67 |
| Guest money spent per service | 1 | 2 |

Service stalls are more VU-efficient per board slot (0.67 vs 0.50), but need **50% more slots** to stop turning guests away. With board space shared between stalls and permanent relics, that extra slot is a real cost.

**The tradeoff:** product stalls are slot-cheap and denial-free with just 2 copies. Service stalls are more powerful per slot but demand a bigger board commitment. A player with tight board space (many relics, mixed need types) leans product. A player with open board space and focused needs leans service.

Both carry the same risk: if a guest walks past a stall that can't serve (out of stock / at capacity), that guest may never come back. This makes placement and path awareness critical for both.

### Board Space as the Fundamental Constraint

Board placement slots are scarce and permanent. Relics occupy the same slots as stalls and cannot be removed, so every relic placed is one fewer stall the player can ever have on that board. This is the resource that makes every other decision interesting:

- **Wide vs. tall** — Two T1 product stalls eliminate denials entirely. One T2 product stall has 50% more stock but still has downtime. The player only upgrades when they can't afford another board slot.
- **Product vs. service** — Service stalls need 3 copies for zero denial vs. product's 2, but deliver more VU per slot. With tight board space, product is safer. With open board space, service pays off.
- **Relics** — Permanent investments that shrink available stall space for every future level. A powerful relic is worth less if it costs the player a denial-preventing stall slot.

Board space scarcity is what makes the tier progression tradeoff real. Without it, the player would always prefer two T1 stalls over one T2.

### Stall Pricing (Token Cost)

Stall token cost (what the player pays to buy the card) should reflect:
- Base power level at T1
- Skill ceiling (how good it gets with synergy)
- Flexibility (how many guest types it can serve)

Stalls with narrow synergy windows (yoga mats) should cost less than flexible workhorses (noodle stand).

---

## Level Scaling & Difficulty Tiers

### Philosophy

Early levels teach mechanics. Mid levels reward synergy. Late levels **demand** it.

As level tier increases, guests become more "unfair" in their money/needs ratios — but this is intentional because players accumulate relics and upgraded stalls that create equally unfair advantages.

