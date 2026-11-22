import 'package:dio/dio.dart';

import '../models/quote.dart';
import '../models/quote_detail.dart';

/// Thin REST client for the mock market server.
class MarketApi {
  MarketApi(this._dio);

  final Dio _dio;

  /// All quotes in one batch request.
  Future<List<Quote>> fetchQuotes({List<String>? symbols}) async {
    final res = await _dio.get<List<dynamic>>(
      '/quotes',
      queryParameters: {
        if (symbols != null) 'symbols': symbols.join(','),
      },
    );
    return [
      for (final j in res.data!) Quote.fromJson(j as Map<String, dynamic>),
    ];
  }

  /// One quote with its day stats: GET /quote/{symbol}.
  /// (Episode 3: watch how often this gets called.)
  Future<QuoteDetail> fetchQuote(String symbol) async {
    final res = await _dio.get<Map<String, dynamic>>('/quote/$symbol');
    return QuoteDetail.fromJson(res.data!);
  }
}
