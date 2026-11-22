# Episode 3: "Why my Flutter screen calls the same API twice"

**Length:** ~2:00 · **Format:** 16:9, editor font 20pt+, app on the right, code on the left
**Branch:** `ep03-dup-calls`. Pick **Ep 3 · calls** at the top of the app. Tap any stock to open
its detail screen. **With bug** opens `quote_detail_bug.dart`, **With fix** opens
`quote_detail_fix.dart`.

---

## 1. Understand it first (read this before recording)

**The new screen:** tapping a stock opens a detail page with two cards:
- **PriceHeader**: the big price and today's change
- **KeyStatsCard**: open, high, low and volume

Both cards need the same data: `GET /quote/{symbol}`.

**The bug (`quote_detail_bug.dart`):** each card was written as if by a different developer,
and each one fetches its own data in its own `initState`:

```dart
class _PriceHeaderState extends State<PriceHeader> {
  @override
  void initState() {
    super.initState();
    getIt<MarketRepository>().quote(widget.symbol).then(...);   // request #1
  }
}

class _KeyStatsCardState extends State<KeyStatsCard> {
  @override
  void initState() {
    super.initState();
    getIt<MarketRepository>().quote(widget.symbol).then(...);   // request #2, same URL
  }
}
```

Each widget is perfectly reasonable on its own. Put them on the same screen and **every
open sends the same request twice**. Nobody wrote "fetch twice". It happens because
**each widget owns its own fetch**.

The repository doesn't cache and nothing de-duplicates, on purpose: the problem is who
calls `quote()`, not how `quote()` works.

**The fix (`quote_detail_fix.dart`):** one owner for the data. A `QuoteDetailCubit` is
provided at the page and fetches once. Both cards become `StatelessWidget`s and read from it
with a `BlocSelector`, the same scoping idea as Episode 1:

```dart
BlocProvider(
  create: (_) => QuoteDetailCubit(getIt<MarketRepository>())..load(symbol),  // 1 request
  child: DetailScaffold(children: const [PriceHeader(), KeyStatsCard()]),
);

class PriceHeader extends StatelessWidget {          // no fetch: reads the page's quote
  Widget build(BuildContext context) =>
      BlocSelector<QuoteDetailCubit, QuoteDetailState, (QuoteDetail?, String?)>(
        selector: (state) => (state.detail, state.error),
        builder: (context, quote) => PriceHeaderView(detail: quote.$1),
      );
}
```

**How we measure it:**
- On Ep 3, the AppBar shows **`requests: N · redundant: M`** for `GET /quote/` calls. The
  detail page shows the same counter under its title. Both update after each frame, never
  during a build.
- `requests` comes from `RedundantCallInterceptor.report` (waste_lens_dio). `redundant` is
  what the interceptor flagged. Coalesced calls are counted from its `RedundantCall` events
  on the waste_lens bus.
- The **server log** is the independent check: it prints `<-- x2 in 2s` whenever the same
  path arrives twice within 2 seconds.

**One honest surprise: the overlay doesn't flag this bug by itself.**
waste_lens_dio's always-on check only flags a request if an identical one has already
*finished* within the last 2 seconds. Our two requests start in the **same frame**, so
neither has finished when the other starts. With `coalesce` off, the interceptor reports
**0 redundant** even though the server clearly got everything twice. Only `coalesce` mode
looks at requests still in flight, so that's where waste_lens catches these. (The server log
and the `requests: 20` vs `requests: 10` count catch them either way.)

---

## 2. Measured numbers (iPhone 17 Pro Simulator, debug, `--hz 4`, 10 detail opens per run)

| Run | App made | Reached server | Server log `x2` | Flagged redundant | Coalesced | Wasted |
|---|---|---|---|---|---|---|
| **With bug** | **20** | **20** | **10** | 0 | 0 | 0 B |
| **With bug + coalesce** | **20** | **10** | 0 | 10 | 10 | 1.6 KB |
| **With fix** | **10** | **10** | 0 | 0 | 0 | 0 B |

How to read them:
- **With bug:** 10 opens, 20 requests. The server saw both copies every time (`<-- x2 in 2s` ten
  times). The interceptor flagged none of them, for the reason above.
- **With bug + coalesce:** the app *still asked 20 times*. The interceptor merged every second
  copy into the first one in flight, so the server only saw 10 and the log stayed clean. The
  overlay counted 10 redundant calls, about 1.6 KB of response it would otherwise have
  fetched twice.
- **With fix:** 10 opens, 10 requests. Nothing to merge, nothing to flag.

Server log, one open of each:

```
[#4] GET /quote/NOVA                       ← With bug
[#5] GET /quote/NOVA   <-- x2 in 2s
[#24] GET /quote/PIXL                      ← With bug + coalesce (one reached the server)
[#34] GET /quote/DUNE                      ← With fix
```

---

## 3. The shortcut vs the real fix

The **coalesce** switch on the With bug detail page runs `RedundantCallInterceptor` with
`coalesce: true`. (The option is called `coalesce`. There's also `serveCache`, which isn't used
here.)

| | Coalesce (the shortcut) | One owner (the fix) |
|---|---|---|
| Requests the code makes per open | **2** | **1** |
| Requests that reach the server | 1 | 1 |
| Works when both copies overlap in time | Yes | Yes |
| Works when the 2nd copy starts after the 1st finished | **No**: flagged, but sent | Yes |
| Works with `serveCache: false` (default) | Only in-flight copies | Yes |
| Hides the bug from the server log | **Yes** | Nothing to hide |
| Same data in both widgets, guaranteed | Only if responses match | Yes (one object) |
| Where the knowledge lives | A network setting, far from the screen | The screen itself |

**When coalescing would NOT catch it:** coalescing only merges a request with an identical
one *that is still on the wire*. If KeyStatsCard were built later, say below the fold in a
`ListView`, behind a tab, or after an animation, its request would start after the first one
had finished. Then the interceptor flags it as redundant (within the 2 s window) but still
**sends it to the server**, unless you also turn on `serveCache`. And after 2 seconds it isn't
even flagged. The fix doesn't care about timing: there's only one request.

**So:** coalescing is a **safety net** for code you don't control yet. It's not a fix. The
code still asks twice; the interceptor just quietly answers once.

---

## 4. Questions viewers (and interviewers) will ask

**"Why not just cache in the repository?"**
You can, but now the repository needs a cache policy: how long is a price fresh, who
invalidates it, what happens when two calls race before the first one finishes? (That's the
exact case here.) You've moved the bug into infrastructure and added staleness. Make one
widget own the data for the screen first; add caching later if you need it across screens.

**"Isn't the interceptor enough?"**
It's a great safety net, and it's how we *found* the problem in coalesce mode. But it only
merges requests that overlap in time, it doesn't change what your code asks for, and it hides
the bug from your server logs. Use it to catch duplicates, then fix the ownership.

**"What about FutureBuilder?"**
`FutureBuilder(future: repo.quote(symbol))` in each card is the same bug in fewer lines. Worse,
if you create the future inside `build()`, every rebuild sends a new request. One owner (a
cubit, or one `Future` created once in the page's state and passed down) fixes both.

---

## 5. Recording checklist

1. Override the simulator status bar (so it doesn't show the default time):
   `xcrun simctl status_bar booted override --time "10:30" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`
2. `cd server && dart run bin/server.dart --hz 4`. Keep this terminal visible: its log is the hook.
3. `cd app && flutter run` (**debug mode**: waste_lens is off in release)
4. Tap **Ep 3 · calls**, stay on **With bug**. Open a few stocks and point at the server log:
   `<-- x2 in 2s` after every open. The counter reads `requests: 2` per open, `redundant: 0`.
5. On a detail page, flip **coalesce** on. Open more stocks: the server log goes quiet,
   `redundant` climbs, and the overlay bubble counts them. Point out `requests` still goes up by 2.
6. Tap **With fix** (coalesce resets to off). Open stocks: `requests` goes up by 1, the log stays clean.
7. Tap the report icon: three cards, With bug / With bug + coalesce / With fix.
8. When you're done: `xcrun simctl status_bar booted clear`

---

## 6. Script (~2:00)

| Time | Beat | Screen | Voiceover |
|---|---|---|---|
| 0:00 | **Hook** | Server terminal: `GET /quote/NOVA` then `<-- x2 in 2s` | "I opened one screen. My server got the same request twice. Every single time." |
| 0:10 | **Two widgets** | `quote_detail_bug.dart`: both `initState`s highlighted | "Here's the detail page. A price header, and a stats card. Each one fetches the quote in its own initState. Each is fine on its own. Together, every open asks twice." |
| 0:30 | **What waste_lens sees** | Detail page counter: `requests: 2 · redundant: 0` | "The interceptor counts two requests, but flags zero. Both start in the same frame, and it only flags a copy of a request that's already finished. The server log is what catches it." |
| 0:45 | **The coalesce shortcut** | Flip **coalesce** on; server log goes quiet; overlay counts up | "Flip on coalescing, and the second request gets merged into the first. The server sees one. The overlay counts the duplicates. Problem solved? Look at the counter: the app still asks twice." |
| 1:05 | **Why it's not a fix** | Shortcut vs fix table | "Coalescing only merges requests that overlap. If the second widget loads a moment later, it goes straight to the server. It's a safety net, not a fix." |
| 1:20 | **The real fix** | `quote_detail_fix.dart`: `BlocProvider` + `QuoteDetailCubit`, stateless cards | "The real fix: one owner. One cubit for the page fetches once. Both cards just read from it." |
| 1:35 | **The numbers** | Report: 20 / 20 · 20 / 10 · 10 / 10 | "Ten opens. With the bug: twenty requests, twenty hit the server. With coalescing: still twenty asked, ten got through. With the fix: ten. Done." |
| 1:50 | **The rule + teaser** | Outro card | "If two widgets need the same data, give it one owner. And next time: pull-to-refresh plus initState, and the duplicate fetch hiding in almost every app." |

**Title options:** "Why my Flutter screen calls the same API twice" ·
"My Flutter screen called the API twice and I never wrote that"

**Description links:** pub.dev/packages/waste_lens · pub.dev/packages/waste_lens_dio ·
github.com/poojadev/ticker (branch `ep03-dup-calls`)

---

## 7. Notes
- **Dependencies:** waste_lens **0.2.0** (includes the 0.1.2 overlay fix, plus Jank Radar) and
  waste_lens_dio **0.1.1**. The overlay is back on (`overlay: true`), and the console shows no
  "setState() called during build" errors.
- `QuoteCallStats` (`lib/app/quote_call_stats.dart`) owns the interceptor. The interceptor's
  options are `final`, so the coalesce switch swaps in a new one, and each run (bug, bug +
  coalesce, fix) keeps its own numbers.
- Every tile in every episode opens a detail page. Outside Ep 3's With bug tab it's the fixed page.
- Clear the status bar override afterwards: `xcrun simctl status_bar booted clear`
