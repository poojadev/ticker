import 'package:material_ui/material_ui.dart';

import '../../app/di.dart';
import '../../app/quote_call_stats.dart';
import '../../app/theme.dart';

/// The detail screen's frame: AppBar with the symbol, the request counter
/// underneath, and (bug page only) the "coalesce" switch.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.symbol,
    required this.children,
    this.showCoalesceSwitch = false,
  });

  final String symbol;
  final List<Widget> children;
  final bool showCoalesceSwitch;

  @override
  Widget build(BuildContext context) {
    final stats =
        getIt.isRegistered<QuoteCallStats>() ? getIt<QuoteCallStats>() : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(symbol),
        actions: [
          if (showCoalesceSwitch && stats != null)
            _CoalesceSwitch(stats: stats),
          const SizedBox(width: 8),
        ],
        bottom: stats == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RequestCounter(stats: stats),
                ),
              ),
      ),
      body: ListView(children: children),
    );
  }
}

/// Debug switch: run the RedundantCallInterceptor with coalesce on.
/// The shortcut, not the fix: the code still asks twice.
class _CoalesceSwitch extends StatelessWidget {
  const _CoalesceSwitch({required this.stats});

  final QuoteCallStats stats;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: stats,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'coalesce',
            style: TextStyle(fontSize: 13, color: TickerTheme.muted),
          ),
          Switch(
            value: stats.coalesce,
            onChanged: stats.setCoalesce,
          ),
        ],
      ),
    );
  }
}
