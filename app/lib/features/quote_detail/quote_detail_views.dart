import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../data/models/quote_detail.dart';

/// What the detail screen draws. Shared by the bug and the fix pages, so those
/// two files only differ in WHO fetches the data.

/// Symbol, name, big price, change pill.
class PriceHeaderView extends StatelessWidget {
  const PriceHeaderView({super.key, required this.detail});

  final QuoteDetail? detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    if (d == null) return const _CardPlaceholder(height: 150);
    final color = d.isUp ? TickerTheme.up : TickerTheme.down;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.name, style: const TextStyle(color: TickerTheme.muted)),
          const SizedBox(height: 8),
          Text(
            d.price.toStringAsFixed(2),
            style: TickerTheme.numbers.copyWith(fontSize: 40),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${d.isUp ? '+' : ''}${d.changePct.toStringAsFixed(2)}% today',
              style: TickerTheme.numbers.copyWith(color: color, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Open / high / low / volume.
class KeyStatsView extends StatelessWidget {
  const KeyStatsView({super.key, required this.detail});

  final QuoteDetail? detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    if (d == null) return const _CardPlaceholder(height: 190);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KEY STATS',
            style: TextStyle(
              color: TickerTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _Stat('Open', d.open.toStringAsFixed(2)),
          _Stat('High', d.high.toStringAsFixed(2)),
          _Stat('Low', d.low.toStringAsFixed(2)),
          _Stat('Volume', _volume(d.volume)),
        ],
      ),
    );
  }

  static String _volume(int v) => v >= 1000000
      ? '${(v / 1000000).toStringAsFixed(2)}M'
      : v >= 1000
          ? '${(v / 1000).toStringAsFixed(1)}K'
          : '$v';
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: TickerTheme.numbers.copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TickerTheme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// Shown while a widget's quote is loading.
class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: SizedBox(
        height: height - 40,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

/// Shown when a fetch fails.
class DetailError extends StatelessWidget {
  const DetailError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Text(
        "Couldn't load this quote.\n$message",
        style: const TextStyle(color: TickerTheme.down),
      ),
    );
  }
}
