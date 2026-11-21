# Episode 2: "Why const didn't save us"

**Length:** ~1:45 · **Format:** 16:9, editor font 20pt+, app on the right, code on the left
**Branch:** `ep02-const`. Pick **Ep 2 · const** at the top of the app. It has two tabs:
**Before const** (`ep2_before_const.dart`) and **After const** (`ep2_after_const.dart`).

---

## 1. Understand it first (read this before recording)

**The question from Episode 1's comments:** "Why not just make QuoteTile `const`?"

**The rule Flutter actually follows:** when a parent rebuilds, Flutter walks its new
children and calls `Element.updateChild(child, newWidget, slot)` for each one. The first
thing it checks is:

```dart
if (child.widget == newWidget) {   // framework.dart, Element.updateChild
  // same widget as last time: keep the element, skip build() entirely
}
```

`Widget`'s `==` is `@nonVirtual` and falls straight through to `Object`'s, so this check
means **"is it the identical instance as last time?"**, not "does it look the same?".

- `const MarketStatusBanner()` is created once, when the code is compiled. Every rebuild
  hands Flutter **the same instance**, so the check passes and the banner's `build()` never
  runs again.
- `QuoteTile(quote: quote)` **can't** be `const`: `quote` is live data from the server, and
  `const` only works when every argument is a compile-time constant. So every rebuild
  creates a **new** QuoteTile instance, the check fails, and its `build()` runs.
- Adding `const` *inside* QuoteTile (`const SizedBox`, `const TextStyle`...) makes each build
  a little cheaper. It does **not** stop QuoteTile's own `build()` from running.

**The two tabs:** both use Episode 1's **buggy** list on purpose: one `BlocBuilder`, no
`buildWhen`, so the whole list rebuilds on every tick. Nothing else is optimized. Side by
side, the files differ only in `const`, plus one necessary name:

```dart
// ep2_before_const.dart                    // ep2_after_const.dart
// ignore: prefer_const_constructors
MarketStatusBanner(),                       const MarketStatusBanner(),
...
child: QuoteTileNoConst(quote: quote),      child: QuoteTile(quote: quote),
```

`QuoteTileNoConst` is QuoteTile with every `const` stripped out inside `build()`. Neither
call site can be `const`, because both take a live `quote`.

**How we measure it:**
- The AppBar shows **`rebuilds: N · dead: M`** and, on Ep 2, **`banner: B`**. All three reset
  when you switch tabs.
- `rebuilds` counts every QuoteTile `build()`. `dead` counts waste_lens dead rebuilds from
  that tab's probe (`'QuoteTile · ep2 before'` / `'QuoteTile · ep2 after'`).
- `banner` counts `MarketStatusBanner.build()`. The banner shows it too, as a
  **"built N×"** badge. There's deliberately **no** `DeadRebuildProbe` around the banner:
  the probe isn't `const` itself, so wrapping the banner would create a new parent instance
  every tick and hide the effect.
- Counters update *after* each frame, never with `setState` during a build.

---

## 2. Measured numbers (iPhone 17 Pro Simulator, debug, `--hz 4`, ~10 s per tab)

From the waste report, scaled to 10 seconds:

| Tab | QuoteTile rebuilds / 10 s | dead / 10 s | wasted | banner builds / 10 s |
|---|---|---|---|---|
| Before const | **430** | **368** | 86% | **41** |
| After const | **428** | **371** | 87% | **once** |

Raw counts, 10.1 s on each tab: Before 435 rebuilds, 372 dead, 41 banner builds · After 433
rebuilds, 375 dead, 1 banner build.

The report's own summary line: *"const didn't change the tiles (368 → 371 dead / 10 s), but
the banner went from 41 builds / 10 s to a single build, when the tab opened."*

How to read them:
- **Tiles:** about 40 ticks × ~11 built tiles on both tabs. The small difference between
  the tabs is tick-to-tick noise, not `const`. If anything, After const wasted slightly
  *more*.
- **Banner:** Before rebuilds it on every tick (~4 a second). After builds it **once**, when
  the tab opens, then never again.
- About 5 s into each tab, the AppBar showed `rebuilds: 238` on **both** tabs (dead 211 vs 209),
  with `banner: 23` vs `banner: 1`. If you can catch that on camera, it's the cleanest
  before/after shot.

Your own take will land close to these, not exactly on them (tap timing, scroll position).
Read the AppBar on camera and say the numbers you see.

---

## 3. Questions viewers (and interviewers) will ask

**"So should I still use const?"**
Yes, always where the linter allows it. It costs nothing and it's the only thing that lets
Flutter skip a subtree with zero work. Just don't expect it to fix widgets that take live
data. For those you need to scope the rebuild (Episode 1's `buildWhen` + `BlocSelector`).

**"What about helper methods vs widgets?"**
A helper method like `Widget _buildBanner()` returns a brand new widget every call, and it
can never be `const`. Inline code and helper methods both rebuild with the parent. A
separate `StatelessWidget` class with a `const` constructor is what makes `const` possible.
That's the real reason "prefer widgets over helper methods" exists.

**"Does const help memory too?"**
A little. A `const` widget is created once, when the code is compiled, and shared
everywhere it's used. So there's one instance instead of a new allocation every frame, and
less garbage collection. The main win is still skipping `build()`, though, not the memory.

---

## 4. Recording checklist

1. `cd server && dart run bin/server.dart --hz 4`
2. `cd app && flutter run` (**debug mode**: waste_lens is off in release)
3. Tap **Ep 2 · const** at the top. It opens **Before const** with fresh counters.
4. Wait 10 s. Watch the banner badge climb ("built 40×...") while the tiles flash amber.
5. Tap **After const**. The counters reset. Wait 10 s: the badge stays at **"built 1×"** while
   the tiles keep flashing.
6. Tap the report icon: Before vs After side by side, plus the summary line.
7. Optional: show `ep2_before_const.dart` and `ep2_after_const.dart` side by side. The
   difference is one `const` keyword (and the tile class name).

Write down the banner numbers and the dead numbers. "Same dead, banner 41 → 1" is the
thumbnail.

---

## 5. Script (~1:45, 5 beats)

| Time | Beat | Screen | Voiceover |
|---|---|---|---|
| 0:00 | **Hook** | Episode 1 comment: "Why not just make it const?" | "Last episode, half the comments said: just make it const. So let's do exactly that, and measure it." |
| 0:12 | **Add const, nothing changes** | Before const tab, amber flashing → After const tab, still flashing. AppBar: `rebuilds: 238` on both | "Before const: 238 tile rebuilds in five seconds. I add const everywhere the linter lets me. After const: 238. The tiles didn't notice." |
| 0:35 | **Why** | `Element.updateChild` snippet, highlight `child.widget == newWidget` | "When a parent rebuilds, Flutter asks one question per child: is this the exact same widget instance as last time? If yes, it skips it. A tile with a live price is a new instance every tick, and it can't be const, because the price isn't known at compile time." |
| 1:00 | **The banner** | Banner badge: `built 23×` vs `built 1×`. Report: 41 → once | "Now look at this banner. It takes no arguments, so it can be const. Without const it's rebuilt every tick: 41 times in ten seconds. With const it's the same instance every time, so Flutter builds it once. Then never again." |
| 1:25 | **The rule** | Split: `const MarketStatusBanner()` / Episode 1's `BlocSelector` | "So here's the rule. const is for things that don't change: use it everywhere you can. For live data, const can't help. You have to scope the rebuild, like we did in Episode 1. Next: two widgets, one API call." |

**Title options:** "Why const didn't save my Flutter list" ·
"I added const everywhere. Nothing changed. Here's why."

**Description links:** pub.dev/packages/waste_lens · github.com/poojadev/waste_lens · Ticker repo

---

## 6. Notes
- The Ep 2 tabs keep Episode 1's bug on purpose. Don't add `buildWhen` or `BlocSelector`
  there, or the tiles stop proving the point.
- The missing `const`s in the Before tab are deliberate. They're protected by
  `// ignore: prefer_const_constructors` (one call site) and
  `// ignore_for_file: prefer_const_constructors` (`quote_tile_no_const.dart`), so
  `dart fix` and the IDE won't add them back.
- Episode 1 is unchanged: pick **Ep 1 · One tick** for With bug / With fix.
- The waste_lens overlay is still off (`overlay: false`) until waste_lens 0.1.2 ships.
