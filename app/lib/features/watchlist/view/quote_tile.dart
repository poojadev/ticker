import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../data/models/quote.dart';
import '../../quote_detail/open_quote_detail.dart';
import 'rebuild_stats.dart';

/// One row of the watchlist. Pure and cheap on its own — the problem in
/// Episode 1 is not what it builds, it's how often it's asked to.
class QuoteTile extends StatelessWidget {
  const QuoteTile({super.key, required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    // Count every build for the AppBar's "rebuilds: N". Just an int++; the
    // AppBar itself only updates after the frame.
    RebuildStats.instance.recordRebuild();
    final color = quote.isUp ? TickerTheme.up : TickerTheme.down;
    final sign = quote.isUp ? '+' : '';
    final tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: TickerTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.symbol,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quote.name,
                  style:
                      const TextStyle(color: TickerTheme.muted, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quote.price.toStringAsFixed(2),
                style: TickerTheme.numbers.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$sign${quote.changePct.toStringAsFixed(2)}%',
                  style: TickerTheme.numbers.copyWith(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    // Tap a tile to open its detail screen (Episode 3).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openQuoteDetail(context, quote.symbol),
      child: tile,
    );
  }
}
