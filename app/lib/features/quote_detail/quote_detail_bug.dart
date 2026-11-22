import 'package:material_ui/material_ui.dart';

import '../../app/di.dart';
import '../../data/models/quote_detail.dart';
import '../../data/repository/market_repository.dart';
import 'detail_scaffold.dart';
import 'quote_detail_views.dart';

/// EPISODE 3, THE BUG: two widgets, each fetching the same quote itself.
class QuoteDetailPageBug extends StatelessWidget {
  const QuoteDetailPageBug({super.key, required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    // 1. Two widgets, written by two developers. Each is fine on its own.
    return DetailScaffold(
      symbol: symbol,
      showCoalesceSwitch: true,
      children: [
        PriceHeader(symbol: symbol),
        KeyStatsCard(symbol: symbol),
      ],
    );
  }
}

/// 2. Fetches GET /quote/{symbol} in its own initState...
class PriceHeader extends StatefulWidget {
  const PriceHeader({super.key, required this.symbol});

  final String symbol;

  @override
  State<PriceHeader> createState() => _PriceHeaderState();
}

class _PriceHeaderState extends State<PriceHeader> {
  QuoteDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    getIt<MarketRepository>().quote(widget.symbol).then(
          (d) => mounted ? setState(() => _detail = d) : null,
          onError: (Object e) => mounted ? setState(() => _error = '$e') : null,
        );
  }

  @override
  Widget build(BuildContext context) => _error != null
      ? DetailError(message: _error!)
      : PriceHeaderView(detail: _detail);
}

/// 3. ...and so does this one. Same symbol, same request: every open of this
///    screen sends GET /quote/{symbol} TWICE.
class KeyStatsCard extends StatefulWidget {
  const KeyStatsCard({super.key, required this.symbol});

  final String symbol;

  @override
  State<KeyStatsCard> createState() => _KeyStatsCardState();
}

class _KeyStatsCardState extends State<KeyStatsCard> {
  QuoteDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    getIt<MarketRepository>().quote(widget.symbol).then(
          (d) => mounted ? setState(() => _detail = d) : null,
          onError: (Object e) => mounted ? setState(() => _error = '$e') : null,
        );
  }

  @override
  Widget build(BuildContext context) => _error != null
      ? DetailError(message: _error!)
      : KeyStatsView(detail: _detail);
}
