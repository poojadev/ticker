import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/di.dart';
import '../../data/models/quote_detail.dart';
import '../../data/repository/market_repository.dart';
import 'detail_scaffold.dart';
import 'quote_detail_cubit.dart';
import 'quote_detail_views.dart';

/// EPISODE 3, THE FIX: one owner fetches the quote once; both widgets read it.
class QuoteDetailPageFix extends StatelessWidget {
  const QuoteDetailPageFix({super.key, required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    // 1. ONE cubit for the page fetches GET /quote/{symbol} exactly once.
    return BlocProvider(
      create: (_) => QuoteDetailCubit(getIt<MarketRepository>())..load(symbol),
      child: DetailScaffold(
        symbol: symbol,
        children: const [
          PriceHeader(),
          KeyStatsCard(),
        ],
      ),
    );
  }
}

/// 2. No fetch here: reads the page's quote...
class PriceHeader extends StatelessWidget {
  const PriceHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<QuoteDetailCubit, QuoteDetailState,
        (QuoteDetail?, String?)>(
      selector: (state) => (state.detail, state.error),
      builder: (context, quote) => quote.$2 != null
          ? DetailError(message: quote.$2!)
          : PriceHeaderView(detail: quote.$1),
    );
  }
}

/// 3. ...and so does this one. Same data, one request.
class KeyStatsCard extends StatelessWidget {
  const KeyStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<QuoteDetailCubit, QuoteDetailState,
        (QuoteDetail?, String?)>(
      selector: (state) => (state.detail, state.error),
      builder: (context, quote) => quote.$2 != null
          ? DetailError(message: quote.$2!)
          : KeyStatsView(detail: quote.$1),
    );
  }
}
