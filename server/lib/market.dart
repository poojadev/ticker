import 'dart:async';
import 'dart:math';

/// A single tradable instrument with a live, randomly-walking price.
class Instrument {
  Instrument({
    required this.symbol,
    required this.name,
    required this.sector,
    required this.price,
  })  : open = price,
        high = price,
        low = price;

  final String symbol;
  final String name;
  final String sector;
  final double open;
  double price;
  double high;
  double low;
  int volume = 0;

  double get change => price - open;
  double get changePct => (price - open) / open * 100;

  Map<String, Object> toQuoteJson() => {
        'symbol': symbol,
        'name': name,
        'sector': sector,
        'price': _round(price),
        'open': _round(open),
        'high': _round(high),
        'low': _round(low),
        'change': _round(change),
        'changePct': _round(changePct),
        'volume': volume,
      };

  Map<String, Object> toTickJson() => {
        's': symbol,
        'p': _round(price),
        'c': _round(changePct),
      };
}

double _round(double v) => (v * 100).roundToDouble() / 100;

/// Stable string hash (Dart's String.hashCode is not guaranteed stable across
/// runs, and we want identical data on every recording take).
int stableHash(String s) {
  var h = 17;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// Deterministic fake market. Same [seed] => same symbols, prices and tick
/// sequence on every run, so demos are reproducible on camera.
class Market {
  Market({
    required int symbolCount,
    required this.symbolsPerTick,
    int seed = 42,
  }) : _rng = Random(seed) {
    final pool = List<_Seed>.of(_seeds);
    for (var i = 0; i < symbolCount; i++) {
      final s = pool[i % pool.length];
      // Past the hand-written list, generate suffixed symbols (NOVA2, ...).
      final suffix = i < pool.length ? '' : '${i ~/ pool.length + 1}';
      final instrument = Instrument(
        symbol: '${s.symbol}$suffix',
        name: s.name,
        sector: s.sector,
        price: 20 + _rng.nextDouble() * 480,
      );
      instruments[instrument.symbol] = instrument;
    }
  }

  final Random _rng;

  /// How many symbols change on each tick. Kept small on purpose: in a real
  /// market most prices do NOT change every tick — which is exactly what makes
  /// whole-list rebuilds wasteful.
  final int symbolsPerTick;

  final Map<String, Instrument> instruments = {};
  final StreamController<List<Map<String, Object>>> _ticks =
      StreamController.broadcast();
  Timer? _timer;
  int tickCount = 0;

  Stream<List<Map<String, Object>>> get ticks => _ticks.stream;

  void start(Duration interval) {
    _timer ??= Timer.periodic(interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    tickCount++;
    final symbols = instruments.keys.toList();
    final changed = <Instrument>{};
    while (changed.length < min(symbolsPerTick, symbols.length)) {
      changed.add(instruments[symbols[_rng.nextInt(symbols.length)]]!);
    }
    for (final i in changed) {
      // Random walk: +/- up to 0.6% per tick.
      final delta = i.price * (_rng.nextDouble() - 0.5) * 0.012;
      i.price = max(1.0, i.price + delta);
      i.high = max(i.high, i.price);
      i.low = min(i.low, i.price);
      i.volume += 100 + _rng.nextInt(5000);
    }
    _ticks.add([for (final i in changed) i.toTickJson()]);
  }

  /// Intraday history: 78 five-minute candles' closing prices, ending at the
  /// instrument's open price. Deterministic per symbol.
  List<Map<String, Object>> history(String symbol) {
    final inst = instruments[symbol];
    if (inst == null) return const [];
    final rng = Random(stableHash(symbol));
    final start = DateTime.utc(2026, 1, 5, 9, 30);
    var p = inst.open * (0.95 + rng.nextDouble() * 0.1);
    final points = <Map<String, Object>>[];
    for (var k = 0; k < 78; k++) {
      // Drift gently toward the open price so the chart joins the live price.
      p += (inst.open - p) * 0.05 + p * (rng.nextDouble() - 0.5) * 0.01;
      points.add({
        't': start.add(Duration(minutes: 5 * k)).toIso8601String(),
        'p': _round(p),
      });
    }
    return points;
  }
}

class _Seed {
  const _Seed(this.symbol, this.name, this.sector);
  final String symbol;
  final String name;
  final String sector;
}

// 50 fictional companies — no real tickers, so nobody mistakes demo data for
// market data. Asking for more than 50 (--symbols 100) reuses them with a
// numeric suffix (NOVA2, KITE2, ...).
const _seeds = <_Seed>[
  _Seed('NOVA', 'Nova Robotics', 'Tech'),
  _Seed('KITE', 'Kite Aerospace', 'Industrials'),
  _Seed('MERI', 'Meridian Bank', 'Finance'),
  _Seed('LUMA', 'Luma Health', 'Healthcare'),
  _Seed('ORCA', 'Orca Shipping', 'Industrials'),
  _Seed('PIXL', 'Pixel Forge', 'Tech'),
  _Seed('TERA', 'Terra Foods', 'Consumer'),
  _Seed('VOLT', 'Volt Energy', 'Energy'),
  _Seed('ZENO', 'Zeno Pharma', 'Healthcare'),
  _Seed('HALO', 'Halo Networks', 'Tech'),
  _Seed('BRIO', 'Brio Retail', 'Consumer'),
  _Seed('CRUX', 'Crux Materials', 'Materials'),
  _Seed('DUNE', 'Dune Solar', 'Energy'),
  _Seed('ECHO', 'Echo Media', 'Communication'),
  _Seed('FERN', 'Fern Biotech', 'Healthcare'),
  _Seed('GLOW', 'Glow Cosmetics', 'Consumer'),
  _Seed('HIVE', 'Hive Logistics', 'Industrials'),
  _Seed('IRIS', 'Iris Optics', 'Tech'),
  _Seed('JADE', 'Jade Insurance', 'Finance'),
  _Seed('KOVA', 'Kova Mining', 'Materials'),
  _Seed('LYNX', 'Lynx Security', 'Tech'),
  _Seed('MOSS', 'Moss Agritech', 'Consumer'),
  _Seed('NEON', 'Neon Gaming', 'Communication'),
  _Seed('OPAL', 'Opal Telecom', 'Communication'),
  _Seed('PEAK', 'Peak Outdoors', 'Consumer'),
  _Seed('QUIL', 'Quill Software', 'Tech'),
  _Seed('RIFT', 'Rift Semiconductors', 'Tech'),
  _Seed('SAGE', 'Sage Capital', 'Finance'),
  _Seed('TIDE', 'Tide Water Utilities', 'Utilities'),
  _Seed('UNIX', 'Unix Cloud', 'Tech'),
  _Seed('VEGA', 'Vega Motors', 'Consumer'),
  _Seed('WREN', 'Wren Airlines', 'Industrials'),
  _Seed('XENO', 'Xeno Labs', 'Healthcare'),
  _Seed('YARD', 'Yard Homes', 'Real Estate'),
  _Seed('ZEST', 'Zest Beverages', 'Consumer'),
  _Seed('ATLS', 'Atlas Rail', 'Industrials'),
  _Seed('BOLT', 'Bolt Payments', 'Finance'),
  _Seed('CYAN', 'Cyan Water', 'Utilities'),
  _Seed('DRFT', 'Drift Mobility', 'Consumer'),
  _Seed('EMBR', 'Ember Steel', 'Materials'),
  _Seed('FLUX', 'Flux Batteries', 'Energy'),
  _Seed('GRID', 'Gridline Utilities', 'Utilities'),
  _Seed('HELM', 'Helm Marine', 'Industrials'),
  _Seed('INKY', 'Inkwell Publishing', 'Communication'),
  _Seed('JUNO', 'Juno Space Systems', 'Industrials'),
  _Seed('KELP', 'Kelp Ocean Farms', 'Consumer'),
  _Seed('LOOM', 'Loom Textiles', 'Consumer'),
  _Seed('MINT', 'Mint Lending', 'Finance'),
  _Seed('NEST', 'Nest Property Trust', 'Real Estate'),
  _Seed('ONYX', 'Onyx Chemicals', 'Materials'),
];
