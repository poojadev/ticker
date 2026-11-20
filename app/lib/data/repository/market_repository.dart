import '../api/market_api.dart';
import '../api/price_stream.dart';
import '../models/quote.dart';

class MarketRepository {
  MarketRepository(this._api, this._stream);

  final MarketApi _api;
  final PriceStream _stream;

  Future<List<Quote>> loadWatchlist() => _api.fetchQuotes();

  Future<Quote> quote(String symbol) => _api.fetchQuote(symbol);

  Stream<List<Tick>> liveTicks() => _stream.connect();
}
