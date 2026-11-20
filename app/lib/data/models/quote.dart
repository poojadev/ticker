import 'package:equatable/equatable.dart';

/// A snapshot of one instrument's price. Equatable: two quotes with the same
/// values are `==`, which is what lets BlocSelector (and DeadRebuildProbe)
/// tell "nothing changed" apart from "something changed".
class Quote extends Equatable {
  const Quote({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        changePct: (json['changePct'] as num).toDouble(),
      );

  final String symbol;
  final String name;
  final double price;
  final double changePct;

  bool get isUp => changePct >= 0;

  Quote copyWith({double? price, double? changePct}) => Quote(
        symbol: symbol,
        name: name,
        price: price ?? this.price,
        changePct: changePct ?? this.changePct,
      );

  @override
  List<Object?> get props => [symbol, name, price, changePct];
}

/// One live price update from the stream.
class Tick extends Equatable {
  const Tick({
    required this.symbol,
    required this.price,
    required this.changePct,
  });

  factory Tick.fromJson(Map<String, dynamic> json) => Tick(
        symbol: json['s'] as String,
        price: (json['p'] as num).toDouble(),
        changePct: (json['c'] as num).toDouble(),
      );

  final String symbol;
  final double price;
  final double changePct;

  @override
  List<Object?> get props => [symbol, price, changePct];
}
