import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ticker/data/models/quote.dart';
import 'package:ticker/data/repository/market_repository.dart';
import 'package:ticker/features/watchlist/bloc/watchlist_bloc.dart';

class _MockRepo extends Mock implements MarketRepository {}

void main() {
  const nova = Quote(symbol: 'NOVA', name: 'Nova Robotics', price: 100, changePct: 0);
  const kite = Quote(symbol: 'KITE', name: 'Kite Aerospace', price: 50, changePct: 0);

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.loadWatchlist()).thenAnswer((_) async => [nova, kite]);
    when(() => repo.liveTicks()).thenAnswer(
      (_) => Stream.value(
        const [Tick(symbol: 'NOVA', price: 101, changePct: 1)],
      ),
    );
  });

  blocTest<WatchlistBloc, WatchlistState>(
    'loads the watchlist, then applies a live tick to only that symbol',
    build: () => WatchlistBloc(repo),
    act: (bloc) => bloc.add(const WatchlistStarted()),
    expect: () => [
      const WatchlistState(status: WatchlistStatus.loading),
      const WatchlistState(
        status: WatchlistStatus.loaded,
        symbols: ['NOVA', 'KITE'],
        quotes: {'NOVA': nova, 'KITE': kite},
      ),
      WatchlistState(
        status: WatchlistStatus.loaded,
        symbols: const ['NOVA', 'KITE'],
        quotes: {'NOVA': nova.copyWith(price: 101, changePct: 1), 'KITE': kite},
      ),
    ],
  );
}
