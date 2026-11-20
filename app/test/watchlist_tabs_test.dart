import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ticker/app/di.dart';
import 'package:ticker/data/models/quote.dart';
import 'package:ticker/data/repository/market_repository.dart';
import 'package:ticker/features/watchlist/bloc/watchlist_bloc.dart';
import 'package:ticker/features/watchlist/view/rebuild_stats.dart';
import 'package:ticker/features/watchlist/view/watchlist_page.dart';
import 'package:waste_lens/waste_lens.dart';

class _MockRepo extends Mock implements MarketRepository {}

void main() {
  // 10 symbols. With the default 800x600 test screen ~7 tiles are visible.
  final quotes = [
    for (var i = 0; i < 10; i++)
      Quote(symbol: 'S$i', name: 'Company $i', price: 100.0 + i, changePct: 0),
  ];

  late StreamController<List<Tick>> ticks;

  setUp(() {
    ticks = StreamController<List<Tick>>();
    final repo = _MockRepo();
    when(repo.loadWatchlist).thenAnswer((_) async => quotes);
    when(repo.liveTicks).thenAnswer((_) => ticks.stream);
    getIt.registerFactory<WatchlistBloc>(() => WatchlistBloc(repo));
  });

  tearDown(() async {
    await ticks.close();
    await getIt.reset();
  });

  /// Sends 10 ticks, each moving ONE symbol, and lets every frame, bus event
  /// and post-frame counter update finish.
  Future<void> pumpTenTicks(WidgetTester tester, {required int round}) async {
    for (var i = 0; i < 10; i++) {
      final symbol = 'S${i % 3}'; // always a visible tile
      ticks.add([Tick(symbol: symbol, price: 200.0 + round * 10 + i, changePct: 1)]);
      await tester.pump();
      await tester.pump();
    }
    // Let the probes' 400ms amber flash finish.
    await tester.pump(const Duration(milliseconds: 500));
    // The counter notifies AFTER a frame, so its text lands one frame later.
    await tester.pump();
  }

  testWidgets('optimized tab has 0 dead rebuilds, shipped tab has some',
      (tester) async {
    await tester.pumpWidget(
      const WasteLens(
        // Probes report to the bus; no modules or overlay needed for this.
        config: WasteLensConfig.none(),
        child: MaterialApp(home: WatchlistPage()),
      ),
    );
    await tester.pump(); // load -> loaded
    await tester.pump();

    // ── Shipped (default tab) ──
    await pumpTenTicks(tester, round: 0);
    final shippedDead = RebuildStats.instance.dead;
    final shippedRebuilds = RebuildStats.instance.rebuilds;
    expect(shippedDead, greaterThan(0));
    expect(
      find.text('rebuilds: $shippedRebuilds · dead: $shippedDead'),
      findsOneWidget,
    );

    // ── Optimized ──
    await tester.tap(find.text('Optimized'));
    await tester.pump();
    await tester.pump();
    await pumpTenTicks(tester, round: 1);
    expect(RebuildStats.instance.dead, 0);
    // Tiles DID rebuild (the ones whose price moved), just none for nothing.
    expect(RebuildStats.instance.rebuilds, greaterThan(0));
    expect(find.textContaining('· dead: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
