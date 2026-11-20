# Episode 1: "One price tick rebuilds your whole list"

**Length:** ~1:45 · **Format:** 16:9, editor font 20pt+, app on the right, code on the left
**Branch:** `shipped`. The app has two tabs: **With bug** (`shipped_watchlist.dart`) and **With fix** (`optimized_watchlist.dart`).

---

## 1. Understand it first (read this before recording)

**What the app does:** the server changes 3 of 50 prices per tick (4 ticks a second
with `--hz 4`). The Bloc emits a new `WatchlistState` each time. That part is correct.

**The two tabs:**
- One `WatchlistBloc` is provided **above** both tabs, so both see the same data and the
  same ticks. The comparison is fair.
- Only the **visible** tab is built. The body is swapped on tab change, with no
  `IndexedStack`, so a hidden tab can't keep rebuilding and inflate the numbers.
- The AppBar shows **`rebuilds: N · dead: M`** for the visible tab and resets to zero
  when you switch tabs:
  - `rebuilds` counts every `QuoteTile.build`.
  - `dead` counts waste_lens `RebuildEvent(dead: true)` events from that tab's probe
    (`'QuoteTile · shipped'` or `'QuoteTile · optimized'`).
  - The counter repaints *after* each frame, never during a build.

**The bug (`shipped_watchlist.dart`):** one `BlocBuilder` around the whole `ListView`,
with no `buildWhen`. A `BlocBuilder` with no `buildWhen` rebuilds whenever the state
changes, and the state changes on every tick:

```
tick → new state → BlocBuilder rebuilds → new ListView → every built QuoteTile rebuilds
```

About 12 tiles are built (8 on screen plus the scroll cache). 3 prices changed, and
most of those are off screen. So on most ticks **nearly all 12 rebuilds produce exactly
the same pixels.** That is wasted work.

**How waste_lens proves it (not just counts it):**
- `DeadRebuildProbe` wraps each tile with `fingerprint: () => [quote]`.
- When the parent rebuilds the probe, it compares the new fingerprint to the previous one.
  `Quote` is `Equatable`, so if the price didn't change, the fingerprints are equal.
- Same inputs and rebuilt anyway means a **dead rebuild**. The tile flashes amber and the
  `dead` count goes up.

**The fix (`optimized_watchlist.dart`):** the list should rebuild when the **list**
changes, and each tile should rebuild when **its own quote** changes. Side by side, the
two files differ only in this:

```dart
// 1. The list only listens to status and symbols.
return BlocBuilder<WatchlistBloc, WatchlistState>(
  buildWhen: (prev, curr) =>
      prev.status != curr.status || prev.symbols != curr.symbols,
  builder: (context, state) {
    // ...
    return ListView.builder(
      itemCount: state.symbols.length,
      itemBuilder: (context, index) {
        final symbol = state.symbols[index];
        // 2. Each tile selects only its own quote.
        return BlocSelector<WatchlistBloc, WatchlistState, Quote?>(
          selector: (state) => state.quotes[symbol],
          builder: (context, quote) => DeadRebuildProbe(
            label: probeLabel,
            fingerprint: () => [quote],
            child: QuoteTile(quote: quote!),
          ),
        );
      },
    );
  },
);
```

**Why it works, in plain words:**
- `buildWhen` stops the ticks from reaching the list at all. `symbols` is only replaced on
  load, so `!=` (identity) is enough here. Mention that a list that changes in place would
  need `listEquals`.
- `BlocSelector` runs `selector` on every state, but **rebuilds only if the selected value
  changed** (`==`). `Quote` is `Equatable`, so an unchanged quote is `==` and the tile is
  skipped.
- Expect someone in the comments to ask "Why not just `const QuoteTile`?" The answer:
  `const` needs compile-time-constant arguments, and `quote` is runtime data. That's the
  teaser for Episode 2.

**Likely interview follow-up:** "Isn't one `BlocSelector` per row expensive?" No.
The selector is a map lookup plus `==`, which is far cheaper than building and laying out a
row. The cost that matters is build, layout and paint, not the comparison.

---

## 2. Measured numbers (iPhone 17 Pro Simulator, debug, `--hz 4`, ~10 s per tab)

| Tab | rebuilds | dead |
|---|---|---|
| With bug | **479** | **417** |
| With fix | **40** | **0** |

How to read them:
- **With bug:** 40 ticks × ~12 built tiles ≈ 480 rebuilds, and 417 of them (87%) changed
  nothing.
- **With fix:** ~12 first builds when the tab opens, plus ~28 tiles whose price really
  moved. None of them were dead.

Your own take will land close to these, not exactly on them (tap timing, scroll position).
Read the AppBar on camera and say the numbers you see.

---

## 3. Recording checklist

1. `cd server && dart run bin/server.dart --hz 4` (a faster tick makes the flashing obvious)
2. `cd app && flutter run` (**debug mode**: waste_lens is off in release)
3. On **With bug**, tap the tab again to reset the counter, wait 10 s, and note the AppBar numbers
4. Tap **With fix** (it resets on its own), wait 10 s, then tap the report icon: the dialog compares both tabs side by side, scaled to "per 10 s"
5. Optional: expand "Whole app since launch" in the dialog for the waste_lens totals (network, leaks, memory)

Write the two pairs of numbers down. They become the hook and the thumbnail.

---

## 4. Script (~1:45)

| Time | Screen | Voiceover |
|---|---|---|
| 0:00 | With bug tab, tiles flashing amber | "Only three prices changed. Every amber flash is a tile Flutter rebuilt for nothing." |
| 0:06 | Zoom on AppBar: `rebuilds: 479 · dead: 417` | "Ten seconds: 479 tile rebuilds, and 417 of them produced exactly the same pixels. That's 87% waste." |
| 0:16 | waste_lens logo / pub.dev page | "This is waste_lens, a package I built. It doesn't just count rebuilds. It proves a rebuild changed nothing." |
| 0:24 | `shipped_watchlist.dart`, highlight `BlocBuilder` | "The cause is one BlocBuilder around the whole list. New state on every tick means every tile rebuilds, four times a second." |
| 0:38 | Highlight `DeadRebuildProbe` | "The probe compares each tile's inputs with last time. Same quote, rebuilt anyway: that's a dead rebuild." |
| 0:50 | Both files side by side, highlight `buildWhen` | "Fix one: the list only rebuilds when the list changes, meaning status or symbols, not prices." |
| 1:04 | Highlight `BlocSelector` | "Fix two: each tile selects just its own quote. Quote is Equatable, so if it didn't change, the tile is skipped." |
| 1:18 | Tap With fix, no amber | "Same bloc, same ticks. Only the tiles whose price actually moved rebuild." |
| 1:26 | Report dialog: With bug vs With fix cards | "Ten seconds: 40 rebuilds instead of 479, and zero dead." |
| 1:36 | Outro card | "Next: why `const` wouldn't have saved you. Link to waste_lens below." |

**Title options:** "One price tick rebuilds your whole Flutter list" ·
"479 rebuilds vs 40: fixing a Flutter list in two lines"

**Description links:** pub.dev/packages/waste_lens · github.com/poojadev/waste_lens · Ticker repo

---

## 5. Notes
- The waste_lens overlay is off (`overlay: false` in `main.dart`) until waste_lens 0.1.2
  ships, because 0.1.1 throws in the console on every dead rebuild. The AppBar counter and
  the amber flashes don't depend on the overlay.
- Both tabs live on the `shipped` branch, so the before/after is one tap apart on camera.
