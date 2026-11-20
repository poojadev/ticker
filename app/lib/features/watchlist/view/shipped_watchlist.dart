import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:waste_lens/waste_lens.dart';

import '../bloc/watchlist_bloc.dart';
import 'quote_tile.dart';
import 'watchlist_status_views.dart';

/// EPISODE 1, THE BUG: one tick rebuilds every visible tile.
class ShippedWatchlist extends StatelessWidget {
  const ShippedWatchlist({super.key});

  static const probeLabel = 'QuoteTile · shipped';

  @override
  Widget build(BuildContext context) {
    // 1. The list listens to the WHOLE state. Every tick is a new state,
    //    so the whole list rebuilds.
    return BlocBuilder<WatchlistBloc, WatchlistState>(
      builder: (context, state) {
        if (state.status != WatchlistStatus.loaded) {
          return WatchlistStatusView(state: state);
        }
        return ListView.builder(
          itemCount: state.symbols.length,
          itemBuilder: (context, index) {
            final quote = state.quotes[state.symbols[index]]!;
            // 2. Every tile is rebuilt with whatever the list hands it,
            //    changed or not. Same quote + rebuilt anyway = dead rebuild.
            return DeadRebuildProbe(
              label: probeLabel,
              fingerprint: () => [quote],
              child: QuoteTile(quote: quote),
            );
          },
        );
      },
    );
  }
}
