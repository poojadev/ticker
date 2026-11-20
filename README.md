# Ticker

A production-style market watchlist built to show
[waste_lens](https://pub.dev/packages/waste_lens) catching real wasted work:
dead rebuilds, redundant API calls, leaks and memory pressure.

```
server/    Deterministic mock market (Dart + shelf): REST + WebSocket
app/       Flutter app: Bloc, get_it, Dio, Equatable, waste_lens
episodes/  One guide per video: the bug, the fix, the script
```

## Run it

```bash
# 1. Server
cd server
dart pub get
dart run bin/server.dart            # --symbols 100 --hz 5 for stress mode

# 2. App (first time only)
cd ../app
./tool/setup.sh                     # creates ios/ + android/, enables local HTTP on Android
flutter run                         # debug mode: all waste_lens modules active
```

On a physical device, use your Mac's Wi-Fi IP:
`flutter run --dart-define=API_HOST=192.168.x.x`

## Server API

| Endpoint | Purpose |
|---|---|
| `GET /symbols` | Watchlist symbols |
| `GET /quotes?symbols=A,B` | Batch quotes |
| `GET /quote/{symbol}` | Single quote |
| `GET /history/{symbol}` | 1-day price history (78 points) |
| `GET /news?page=1&pageSize=10` | News feed |
| `GET /images/{id}.bmp` | Deliberately large (1600×1000) news images |
| `WS /stream` | Live ticks: `{"type":"ticks","data":[{"s","p","c"}]}` |

Same seed means the same prices and ticks on every run, so recording takes match.
The server log marks repeated requests (`<-- x2 in 2s`), which gives the server-side view of redundant calls.

## Branches
- `shipped`: the app as a typical team would ship it, waste included
- `optimized`: one commit per fix, one fix per episode

## Episodes
1. [One price tick rebuilds your whole list](episodes/EP01_one_tick_rebuilds_everything.md)
2. `const` isn't enough: why the tile still rebuilds
3. Two widgets, same API call
4. Pull-to-refresh + `initState` = duplicate fetch
5. The stream you forgot to cancel
6. The AnimationController leak that shows up on the 10th navigation
7. Full-resolution images in a list
8. Catching it before it runs (waste_lens_lints)
