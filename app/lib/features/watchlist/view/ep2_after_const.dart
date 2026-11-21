import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:waste_lens/waste_lens.dart';

import '../bloc/watchlist_bloc.dart';
import 'market_status_banner.dart';
import 'quote_tile.dart';
import 'watchlist_status_views.dart';

/// EPISODE 2, AFTER CONST: the same buggy list, `const` wherever it's allowed.
class Ep2AfterConst extends StatelessWidget {
  const Ep2AfterConst({super.key});

  static const probeLabel = 'QuoteTile · ep2 after';

  @override
  Widget build(BuildContext context) {
    // 1. Same as Episode 1: the whole list rebuilds on every tick.
    return BlocBuilder<WatchlistBloc, WatchlistState>(
      builder: (context, state) {
        if (state.status != WatchlistStatus.loaded) {
          return WatchlistStatusView(state: state);
        }
        return Column(
          children: [
            // 2. The SAME banner instance every tick, so Flutter skips it.
            //    const works here because the banner takes no arguments.
            const MarketStatusBanner(),
            Expanded(
              child: ListView.builder(
                itemCount: state.symbols.length,
                itemBuilder: (context, index) {
                  final quote = state.quotes[state.symbols[index]]!;
                  // 3. Live data: this tile can't be const (QuoteTile uses
                  //    const inside, but its own build still runs every tick).
                  return DeadRebuildProbe(
                    label: probeLabel,
                    fingerprint: () => [quote],
                    child: QuoteTile(quote: quote),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
