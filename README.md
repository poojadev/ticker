# Ticker

A production-style stock watchlist built to show
[waste_lens](https://pub.dev/packages/waste_lens) catching real wasted work:
dead rebuilds, redundant API calls, leaks and memory pressure.
Every company in it is fictional.

```
server/    Deterministic mock market (Dart + shelf): REST + WebSocket
app/       Flutter app (iOS + Android): Bloc, get_it, Dio, Equatable, waste_lens
episodes/  One guide per video: the bug, the fix, the script
```

## Run it

### 1. Server

```bash
cd server
dart pub get
dart run bin/server.dart
```

Options (defaults shown):

```bash
dart run bin/server.dart --port 8080 --symbols 50 --hz 2 --per-tick 3 --latency-ms 150 --seed 42
```

It binds `0.0.0.0`, so a phone on the same Wi-Fi can reach it.

### 2. App

First time only:

```bash
cd app
./tool/setup.sh
```

The script creates `ios/` and `android/`, allows local HTTP on iOS (ATS +
Local Network prompt), and allows cleartext HTTP in Android debug builds.
Running it again changes nothing.

**iOS Simulator / Android emulator** (with the server running):

```bash
flutter run
```

The app uses `localhost` on iOS and `10.0.2.2` on Android.

**Physical iPhone** (same Wi-Fi as your Mac):

```bash
flutter run --dart-define=API_HOST=$(ipconfig getifaddr en0)
```

On first launch iOS asks for Local Network access: tap **Allow**. If you
tapped Don't Allow, go to Settings → Privacy & Security → Local Network → Ticker.

Run in **debug** mode (the default). In release builds waste_lens turns itself off.

### Checks

```bash
cd server && dart analyze
cd app && flutter analyze && flutter test
```

## Server API

| Method | Endpoint | Returns |
|---|---|---|
| GET | `/symbols` | `[{symbol, name, sector}]` for every instrument |
| GET | `/quotes` | All quotes in one batch |
| GET | `/quotes?symbols=NOVA,KITE` | Only those quotes |
| GET | `/quote/{symbol}` | One quote (404 for an unknown symbol) |
| GET | `/history/{symbol}` | `{symbol, range: "1D", points: [{t, p}]}` with 78 intraday points |
| GET | `/news?page=1&pageSize=10` | `{page, pageSize, hasMore, items}` from 60 items, each with `imageUrl: /images/nX.bmp` |
| GET | `/images/{id}.bmp` | A 1600×1000 24-bit BMP (~4.8 MB), deliberately large |
| GET | `/health` | `{ok, ticks}` |
| WS | `/stream` | `{"type":"ticks","data":[{"s":"NOVA","p":123.45,"c":0.52}]}` at `--hz` per second |

A quote looks like
`{symbol, name, sector, price, open, high, low, change, changePct, volume}`.

The same `--seed` gives the same prices and ticks on every run, so recording
retakes match.

### Server log

```
[#1] GET /quotes
[#2] GET /quotes   <-- x2 in 2s        a repeat of the same request within 2 seconds
[ws] client connected  (open sockets: 1)
[ws] client disconnected (open sockets: 0)
```

The `<-- x2 in 2s` flag shows redundant calls from the server's side. The
open-socket count shows stream leaks.

## Branches
- `shipped`: the app as a typical team would ship it, waste included
- `optimized`: one commit per fix, one fix per episode

## Episodes
1. [One price tick rebuilds your whole list](episodes/EP01_one_tick_rebuilds_everything.md)
2. [Why const didn't save us](episodes/EP02_why_const_didnt_save_us.md)
3. [Two widgets, one API call, double the requests](episodes/EP03_two_widgets_one_api_call.md)
4. Pull-to-refresh + `initState` = duplicate fetch
5. The stream you forgot to cancel
6. The AnimationController leak that shows up on the 10th navigation
7. Full-resolution images in a list
8. Catching it before it runs (waste_lens_lints)
