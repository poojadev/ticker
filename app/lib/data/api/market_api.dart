import 'package:dio/dio.dart';

import '../models/quote.dart';

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

  /// A single quote. (Later episodes: watch how often this gets called.)
  Future<Quote> fetchQuote(String symbol) async {
    final res = await _dio.get<Map<String, dynamic>>('/quote/$symbol');
    return Quote.fromJson(res.data!);
  }
}
