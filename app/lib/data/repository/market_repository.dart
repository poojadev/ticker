import '../api/market_api.dart';
import '../api/price_stream.dart';
import '../models/quote.dart';
import '../models/quote_detail.dart';

class MarketRepository {
  MarketRepository(this._api, this._stream);

  final MarketApi _api;
  final PriceStream _stream;

  Future<List<Quote>> loadWatchlist() => _api.fetchQuotes();

  /// No cache, no de-duplication: every call is a network request.
  /// (Episode 3 is about who calls this, not about hiding it here.)
  Future<QuoteDetail> quote(String symbol) => _api.fetchQuote(symbol);

  Stream<List<Tick>> liveTicks() => _stream.connect();
}
