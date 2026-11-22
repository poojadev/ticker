// EPISODE 2: this is QuoteTile with every `const` removed on purpose, so the
// "Before const" tab really has none. Don't let `dart fix` or the IDE add them back.
// ignore_for_file: prefer_const_constructors

import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../data/models/quote.dart';
import '../../quote_detail/open_quote_detail.dart';
import 'rebuild_stats.dart';

/// Same pixels as QuoteTile, but no `const` anywhere inside build().
class QuoteTileNoConst extends StatelessWidget {
  const QuoteTileNoConst({super.key, required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context) {
    // Count every build for the AppBar's "rebuilds: N".
    RebuildStats.instance.recordRebuild();
    final color = quote.isUp ? TickerTheme.up : TickerTheme.down;
    final sign = quote.isUp ? '+' : '';
    final tile = Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  quote.name,
                  style: TextStyle(color: TickerTheme.muted, fontSize: 12),
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
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
