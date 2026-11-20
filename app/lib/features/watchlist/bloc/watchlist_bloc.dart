import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/models/quote.dart';
import '../../../data/repository/market_repository.dart';

part 'watchlist_event.dart';
part 'watchlist_state.dart';

class WatchlistBloc extends Bloc<WatchlistEvent, WatchlistState> {
  WatchlistBloc(this._repo) : super(const WatchlistState()) {
    on<WatchlistStarted>(_onStarted);
    on<_TicksReceived>(_onTicks);
  }

  final MarketRepository _repo;
  StreamSubscription<List<Tick>>? _ticksSub;

  Future<void> _onStarted(
    WatchlistStarted event,
    Emitter<WatchlistState> emit,
  ) async {
    emit(state.copyWith(status: WatchlistStatus.loading));
    try {
      final quotes = await _repo.loadWatchlist();
      emit(
        state.copyWith(
          status: WatchlistStatus.loaded,
          symbols: [for (final q in quotes) q.symbol],
          quotes: {for (final q in quotes) q.symbol: q},
        ),
      );
      await _ticksSub?.cancel();
      _ticksSub = _repo.liveTicks().listen((t) => add(_TicksReceived(t)));
    } catch (e) {
      emit(state.copyWith(status: WatchlistStatus.failure, error: '$e'));
    }
  }

  void _onTicks(_TicksReceived event, Emitter<WatchlistState> emit) {
    // Only a handful of symbols change per tick, but we emit a brand-new state
    // (new map) every time. That is normal and correct for Bloc — what the UI
    // does with it is where the waste happens.
    final next = Map<String, Quote>.of(state.quotes);
    for (final t in event.ticks) {
      final q = next[t.symbol];
      if (q != null) {
        next[t.symbol] = q.copyWith(price: t.price, changePct: t.changePct);
      }
    }
    emit(state.copyWith(quotes: next));
  }

  @override
  Future<void> close() async {
    await _ticksSub?.cancel();
    return super.close();
  }
}
