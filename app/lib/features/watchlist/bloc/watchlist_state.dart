part of 'watchlist_bloc.dart';

enum WatchlistStatus { initial, loading, loaded, failure }

final class WatchlistState extends Equatable {
  const WatchlistState({
    this.status = WatchlistStatus.initial,
    this.symbols = const [],
    this.quotes = const {},
    this.error,
  });

  final WatchlistStatus status;

  /// Display order. Changes rarely (load, add/remove symbol).
  final List<String> symbols;

  /// Latest quote per symbol. Changes several times a second.
  final Map<String, Quote> quotes;

  final String? error;

  WatchlistState copyWith({
    WatchlistStatus? status,
    List<String>? symbols,
    Map<String, Quote>? quotes,
    String? error,
  }) {
    return WatchlistState(
      status: status ?? this.status,
      symbols: symbols ?? this.symbols,
      quotes: quotes ?? this.quotes,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, symbols, quotes, error];
}
