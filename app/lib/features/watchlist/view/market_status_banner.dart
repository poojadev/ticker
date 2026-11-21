import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import 'rebuild_stats.dart';

/// EPISODE 2: a widget with NO live data. It takes no arguments, so it CAN be
/// `const`. Whether it is, is decided where it's used, not here.
class MarketStatusBanner extends StatelessWidget {
  const MarketStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Count every build. Just an int++; the badge shows it after the frame.
    RebuildStats.instance.recordBannerBuild();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TickerTheme.up.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TickerTheme.up.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          _LiveDot(),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Market open · Live prices',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          _BuildBadge(),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: TickerTheme.up,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Debug badge: "built N×". It listens to RebuildStats by itself, so updating
/// the number rebuilds only this badge, never the banner around it.
class _BuildBadge extends StatelessWidget {
  const _BuildBadge();

  @override
  Widget build(BuildContext context) {
    final stats = RebuildStats.instance;
    return ListenableBuilder(
      listenable: stats,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'built ${stats.bannerBuilds}×',
          style: TickerTheme.numbers.copyWith(
            fontSize: 11,
            color: TickerTheme.muted,
          ),
        ),
      ),
    );
  }
}
