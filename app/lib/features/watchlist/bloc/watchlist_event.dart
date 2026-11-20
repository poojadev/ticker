part of 'watchlist_bloc.dart';

sealed class WatchlistEvent extends Equatable {
  const WatchlistEvent();

  @override
  List<Object?> get props => [];
}

final class WatchlistStarted extends WatchlistEvent {
  const WatchlistStarted();
}

final class _TicksReceived extends WatchlistEvent {
  const _TicksReceived(this.ticks);

  final List<Tick> ticks;

  @override
  List<Object?> get props => [ticks];
}
