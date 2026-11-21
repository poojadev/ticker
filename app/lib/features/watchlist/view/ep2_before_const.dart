import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:waste_lens/waste_lens.dart';

import '../bloc/watchlist_bloc.dart';
import 'market_status_banner.dart';
import 'quote_tile_no_const.dart';
import 'watchlist_status_views.dart';

/// EPISODE 2, BEFORE CONST: Episode 1's buggy list, with no `const` anywhere.
class Ep2BeforeConst extends StatelessWidget {
  const Ep2BeforeConst({super.key});

  static const probeLabel = 'QuoteTile · ep2 before';

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
            // 2. A new banner instance every tick, so Flutter must rebuild it.
            //    No const on purpose: this is the "before" in the comparison.
            // ignore: prefer_const_constructors
            MarketStatusBanner(),
            Expanded(
              child: ListView.builder(
                itemCount: state.symbols.length,
                itemBuilder: (context, index) {
                  final quote = state.quotes[state.symbols[index]]!;
                  // 3. Live data: this tile can't be const.
                  return DeadRebuildProbe(
                    label: probeLabel,
                    fingerprint: () => [quote],
                    child: QuoteTileNoConst(quote: quote),
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
