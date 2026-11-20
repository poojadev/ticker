import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ticker/data/models/quote.dart';
import 'package:ticker/data/repository/market_repository.dart';
import 'package:ticker/features/watchlist/bloc/watchlist_bloc.dart';

/// A fake repository: no network, we decide exactly what it returns.
class _MockRepo extends Mock implements MarketRepository {}

void main() {
  const nova = Quote(
    symbol: 'NOVA',
    name: 'Nova Robotics',
    price: 100,
    changePct: 0,
  );
  const kite = Quote(
    symbol: 'KITE',
    name: 'Kite Aerospace',
    price: 50,
    changePct: 0,
  );

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    // REST: the batch load returns two quotes.
    when(() => repo.loadWatchlist()).thenAnswer((_) async => [nova, kite]);
    // WebSocket: exactly one tick, and it only touches NOVA.
    when(() => repo.liveTicks()).thenAnswer(
      (_) => Stream.value(
        const [Tick(symbol: 'NOVA', price: 101, changePct: 1)],
      ),
    );
  });

  blocTest<WatchlistBloc, WatchlistState>(
    'loads the watchlist, then a tick updates only that symbol',
    build: () => WatchlistBloc(repo),
    act: (bloc) => bloc.add(const WatchlistStarted()),
    expect: () => [
      // 1. loading
      const WatchlistState(status: WatchlistStatus.loading),
      // 2. loaded with the batch quotes, in server order
      const WatchlistState(
        status: WatchlistStatus.loaded,
        symbols: ['NOVA', 'KITE'],
        quotes: {'NOVA': nova, 'KITE': kite},
      ),
      // 3. one tick: NOVA moves, KITE is untouched
      WatchlistState(
        status: WatchlistStatus.loaded,
        symbols: const ['NOVA', 'KITE'],
        quotes: {'NOVA': nova.copyWith(price: 101, changePct: 1), 'KITE': kite},
      ),
    ],
    verify: (bloc) {
      // Untouched quotes keep the SAME instance. Episode 1's fix relies on
      // this: a per-tile BlocSelector sees `==` and skips the rebuild.
      expect(identical(bloc.state.quotes['KITE'], kite), isTrue);
      verify(() => repo.liveTicks()).called(1);
    },
  );

  blocTest<WatchlistBloc, WatchlistState>(
    'emits failure when the server is unreachable',
    setUp: () => when(() => repo.loadWatchlist())
        .thenThrow(Exception('connection refused')),
    build: () => WatchlistBloc(repo),
    act: (bloc) => bloc.add(const WatchlistStarted()),
    expect: () => [
      const WatchlistState(status: WatchlistStatus.loading),
      isA<WatchlistState>()
          .having((s) => s.status, 'status', WatchlistStatus.failure)
          .having((s) => s.error, 'error', contains('connection refused')),
    ],
  );
}
