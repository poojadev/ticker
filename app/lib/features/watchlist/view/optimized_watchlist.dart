import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:waste_lens/waste_lens.dart';

import '../../../data/models/quote.dart';
import '../bloc/watchlist_bloc.dart';
import 'quote_tile.dart';
import 'watchlist_status_views.dart';

/// EPISODE 1, THE FIX: one tick rebuilds only the tiles that changed.
class OptimizedWatchlist extends StatelessWidget {
  const OptimizedWatchlist({super.key});

  static const probeLabel = 'QuoteTile · optimized';

  @override
  Widget build(BuildContext context) {
    // 1. The list only listens to status and symbols. Ticks change neither,
    //    so the list does NOT rebuild on a tick.
    return BlocBuilder<WatchlistBloc, WatchlistState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status || prev.symbols != curr.symbols,
      builder: (context, state) {
        if (state.status != WatchlistStatus.loaded) {
          return WatchlistStatusView(state: state);
        }
        return ListView.builder(
          itemCount: state.symbols.length,
          itemBuilder: (context, index) {
            final symbol = state.symbols[index];
            // 2. Each tile selects only its own quote, and rebuilds only when
            //    that quote changes (Quote is Equatable, so `==` compares values).
            return BlocSelector<WatchlistBloc, WatchlistState, Quote?>(
              selector: (state) => state.quotes[symbol],
              builder: (context, quote) => DeadRebuildProbe(
                label: probeLabel,
                fingerprint: () => [quote],
                child: QuoteTile(quote: quote!),
              ),
            );
          },
        );
      },
    );
  }
}
