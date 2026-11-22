import 'package:equatable/equatable.dart';

/// Everything GET /quote/{symbol} returns: the detail screen's data.
class QuoteDetail extends Equatable {
  const QuoteDetail({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePct,
    required this.open,
    required this.high,
    required this.low,
    required this.volume,
  });

  factory QuoteDetail.fromJson(Map<String, dynamic> json) => QuoteDetail(
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        changePct: (json['changePct'] as num).toDouble(),
        open: (json['open'] as num).toDouble(),
        high: (json['high'] as num).toDouble(),
        low: (json['low'] as num).toDouble(),
        volume: (json['volume'] as num).toInt(),
      );

  final String symbol;
  final String name;
  final double price;
  final double changePct;
  final double open;
  final double high;
  final double low;
  final int volume;

  bool get isUp => changePct >= 0;

  @override
  List<Object?> get props =>
      [symbol, name, price, changePct, open, high, low, volume];
}
