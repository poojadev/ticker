import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ticker/app/di.dart';
import 'package:ticker/data/models/quote.dart';
import 'package:ticker/data/repository/market_repository.dart';
import 'package:ticker/features/watchlist/bloc/watchlist_bloc.dart';
import 'package:ticker/features/watchlist/view/ep2_after_const.dart';
import 'package:ticker/features/watchlist/view/ep2_before_const.dart';
import 'package:ticker/features/watchlist/view/rebuild_stats.dart';
import 'package:ticker/features/watchlist/view/watchlist_page.dart';
import 'package:waste_lens/waste_lens.dart';

class _MockRepo extends Mock implements MarketRepository {}

/// Episode 2: const fixes the static banner, but not the live tiles.
void main() {
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

  /// 10 ticks, each moving ONE visible symbol; then let flashes and the
  /// post-frame counter updates finish.
  Future<void> pumpTenTicks(WidgetTester tester, {required int round}) async {
    for (var i = 0; i < 10; i++) {
      ticks.add([
        Tick(symbol: 'S${i % 3}', price: 200.0 + round * 10 + i, changePct: 1),
      ]);
      await tester.pump();
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  testWidgets('const stops the banner rebuilding, but not the tiles',
      (tester) async {
    await tester.pumpWidget(
      const WasteLens(
        config: WasteLensConfig.none(),
        child: MaterialApp(home: WatchlistPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    // ── Episode 2, "Before const" (first tab) ──
    await tester.tap(find.text('Ep 2 · const'));
    await tester.pumpAndSettle();
    expect(find.text('Market open · Live prices'), findsOneWidget);
    await pumpTenTicks(tester, round: 0);
    final before = RebuildStats.instance.runFor(Ep2BeforeConst.probeLabel)!;
    expect(before.bannerBuilds, greaterThan(1)); // rebuilt with every tick
    expect(before.dead, greaterThan(0));

    // ── "After const" ──
    await tester.tap(find.text('After const'));
    await tester.pump();
    await tester.pump();
    await pumpTenTicks(tester, round: 1);
    final after = RebuildStats.instance.runFor(Ep2AfterConst.probeLabel)!;
    expect(after.bannerBuilds, 1); // built once, then skipped every tick
    expect(after.dead, greaterThan(0)); // const didn't save the tiles
    expect(find.text('built 1×'), findsOneWidget);
    expect(find.textContaining('banner: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
