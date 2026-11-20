# Episode 1 — "One price tick rebuilds your whole list"

**Length:** ~1:45 · **Format:** 16:9, editor font 20pt+, app on the right, code on the left
**Branch to record from:** `shipped` (bug) → then make the fix live on camera

---

## 1. Understand it first (read this before recording)

**What the app does:** the server changes ~3 of 50 prices, twice a second.
The Bloc emits a new `WatchlistState` each time. That part is correct.

**The bug:** `WatchlistPage` uses one `BlocBuilder` around the whole `ListView`.
A `BlocBuilder` with no `buildWhen` rebuilds whenever the state changes. The state
changes on every tick, so:

```
tick → new state → BlocBuilder rebuilds → new ListView → every visible QuoteTile rebuilds
```

About 12 tiles are visible. 3 prices changed, and only some of those are on screen.
So on most ticks **9–12 of 12 rebuilds produce exactly the same pixels.** That is wasted work.

**How waste_lens proves it (not just counts it):**
`DeadRebuildProbe` wraps each tile with `fingerprint: () => [quote]`. When the parent
rebuilds the probe, it compares the new fingerprint to the previous one. `Quote` is
`Equatable`, so if the price didn't change, the fingerprints are equal. Same inputs
and rebuilt anyway means a **dead rebuild**. The tile flashes amber and the overlay counter goes up.

Separately, the zero-config churn tracker (debug mode) reports
"QuoteTile rebuilt N times in 2000ms". That shows *frequency*. The probe shows *waste*.
Say this distinction on camera, because it's the whole point of your package.

**The fix in one sentence:** the list should rebuild when the **list** changes,
and each tile should rebuild when **its own quote** changes.

```dart
body: BlocBuilder<WatchlistBloc, WatchlistState>(
  // 1. The list only cares about status and which symbols exist.
  buildWhen: (prev, curr) =>
      prev.status != curr.status || prev.symbols != curr.symbols,
  builder: (context, state) {
    switch (state.status) {
      // ...loading / failure unchanged...
      case WatchlistStatus.loaded:
        return ListView.builder(
          itemCount: state.symbols.length,
          itemBuilder: (context, index) {
            final symbol = state.symbols[index];
            // 2. Each tile subscribes to ONE quote.
            return BlocSelector<WatchlistBloc, WatchlistState, Quote?>(
              selector: (s) => s.quotes[symbol],
              builder: (context, quote) {
                if (quote == null) return const SizedBox.shrink();
                return DeadRebuildProbe(
                  label: 'QuoteTile',
                  fingerprint: () => [quote],
                  child: QuoteTile(quote: quote),
                );
              },
            );
          },
        );
    }
  },
),
```
(Add `import '../../../data/models/quote.dart';` to the page.)

**Why it works, in plain words:**
- `buildWhen` stops the ticks from reaching the list at all. `symbols` is only replaced on load,
  so `!=` (identity) is enough here. Mention that a list that changes in place would need
  `listEquals`.
- `BlocSelector` runs `selector` on every state, but **rebuilds only if the selected value
  changed** (`==`). `Quote` is `Equatable`, so an unchanged quote is `==` and the tile is skipped.
- Expect someone in the comments to ask "Why not just `const QuoteTile`?" The answer: `const` needs
  compile-time-constant arguments, and `quote` is runtime data. That's the teaser for Episode 2.

**Likely interview follow-up:** "Isn't one `BlocSelector` per row expensive?" No.
The selector is a map lookup plus `==`, which is far cheaper than building and laying out a row.
The cost that matters is build, layout and paint, not the comparison.

---

## 2. Recording checklist

1. `cd server && dart run bin/server.dart --hz 4` (a faster tick makes the flashing obvious)
2. `cd app && flutter run` (**debug mode**, since the churn tracker hooks a debug-only callback)
3. Wait 10s on the watchlist, then tap the report icon → note `rebuilds.dead` in the console JSON
4. Make the fix (type it live, or cut to the diff)
5. Hot restart, wait the same 10s, export again → note the new number

Write the two numbers down. They become the hook and the thumbnail.

---

## 3. Script (~1:45)

| Time | Screen | Voiceover |
|---|---|---|
| 0:00 | App running, tiles flashing amber | "Only three prices changed. Every amber flash is a widget Flutter rebuilt for nothing." |
| 0:06 | Overlay counter climbing | "This is waste_lens, a package I built. It doesn't just count rebuilds. It proves a rebuild produced the same output." |
| 0:18 | `watchlist_page.dart`, highlight `BlocBuilder` | "The cause is one BlocBuilder around the whole list. New state on every tick means the entire list rebuilds, twice a second." |
| 0:35 | Highlight `DeadRebuildProbe` | "The probe compares each tile's inputs with last time. Same quote, rebuilt anyway: that's a dead rebuild." |
| 0:50 | Type `buildWhen` | "Fix one: the list only rebuilds when the list changes, meaning status or symbols, not prices." |
| 1:05 | Type `BlocSelector` | "Fix two: each tile selects just its own quote. Quote is Equatable, so if it didn't change, the tile is skipped." |
| 1:20 | Hot restart, no amber | "Same app, same ticks. Flutter now only rebuilds the tiles whose prices actually changed." |
| 1:30 | Before/after numbers on screen | "Dead rebuilds: [BEFORE] down to [AFTER] in ten seconds." |
| 1:38 | Outro card | "Next: why `const` wouldn't have saved you. Link to waste_lens below." |

**Title options:** "One price tick rebuilds your whole Flutter list" ·
"Your BlocBuilder is rebuilding 50 widgets for 3 prices"

**Description links:** pub.dev/packages/waste_lens · github.com/poojadev/waste_lens · Ticker repo

---

## 4. Commit plan
- `shipped` branch: as delivered (bug present)
- `optimized` branch: commit `ep01: scope watchlist rebuilds with buildWhen + BlocSelector`
