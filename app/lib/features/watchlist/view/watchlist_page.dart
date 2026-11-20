import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:waste_lens/waste_lens.dart';

import '../../../app/di.dart';
import '../../../app/theme.dart';
import '../bloc/watchlist_bloc.dart';
import 'quote_tile.dart';

class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<WatchlistBloc>()..add(const WatchlistStarted()),
      child: const _WatchlistView(),
    );
  }
}

class _WatchlistView extends StatelessWidget {
  const _WatchlistView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: const [_ExportReportButton()],
      ),
      // ─────────────────────────────────────────────────────────────────────
      // EPISODE 1 — THE BUG
      //
      // This BlocBuilder listens to the WHOLE state. The state changes on every
      // tick (2x per second), so the entire ListView — and every visible
      // QuoteTile — rebuilds, even though only ~3 of 50 prices changed.
      //
      // Looks harmless. Works fine. waste_lens proves most of it is wasted.
      // ─────────────────────────────────────────────────────────────────────
      body: BlocBuilder<WatchlistBloc, WatchlistState>(
        builder: (context, state) {
          switch (state.status) {
            case WatchlistStatus.initial:
            case WatchlistStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case WatchlistStatus.failure:
              return _ErrorView(message: state.error ?? 'Something went wrong');
            case WatchlistStatus.loaded:
              return ListView.builder(
                itemCount: state.symbols.length,
                itemBuilder: (context, index) {
                  final quote = state.quotes[state.symbols[index]]!;
                  // The probe compares this tile's inputs with last time.
                  // Same inputs + rebuilt anyway = a dead rebuild.
                  return DeadRebuildProbe(
                    label: 'QuoteTile',
                    fingerprint: () => [quote],
                    child: QuoteTile(quote: quote),
                  );
                },
              );
          }
        },
      ),
    );
  }
}

/// Dumps the waste_lens report to the console — the before/after numbers for
/// the end of each episode.
class _ExportReportButton extends StatelessWidget {
  const _ExportReportButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Export waste report',
      icon: const Icon(Icons.receipt_long_outlined),
      onPressed: () {
        final report = WasteLens.exportReport();
        debugPrint(const JsonEncoder.withIndent('  ').convert(report));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Waste report printed to console')),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: TickerTheme.muted),
            const SizedBox(height: 12),
            const Text(
              'Can\'t reach the market server.\nIs `dart run bin/server.dart` running?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: TickerTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.read<WatchlistBloc>().add(const WatchlistStarted()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
