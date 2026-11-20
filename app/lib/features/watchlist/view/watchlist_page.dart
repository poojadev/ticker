import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:waste_lens/waste_lens.dart';

import '../../../app/di.dart';
import '../bloc/watchlist_bloc.dart';
import 'optimized_watchlist.dart';
import 'rebuild_stats.dart';
import 'shipped_watchlist.dart';

/// Two tabs over ONE WatchlistBloc: "Shipped" (Episode 1 bug) and
/// "Optimized" (the fix). Same data, same ticks, so the comparison is fair.
class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Provided ABOVE both tabs: switching tabs never reloads or resubscribes.
    return BlocProvider(
      create: (_) => getIt<WatchlistBloc>()..add(const WatchlistStarted()),
      child: const _WatchlistTabs(),
    );
  }
}

class _WatchlistTabs extends StatefulWidget {
  const _WatchlistTabs();

  @override
  State<_WatchlistTabs> createState() => _WatchlistTabsState();
}

class _WatchlistTabsState extends State<_WatchlistTabs> {
  int _tab = 0;

  static const _probeLabels = [
    ShippedWatchlist.probeLabel,
    OptimizedWatchlist.probeLabel,
  ];

  @override
  void initState() {
    super.initState();
    RebuildStats.instance.track(_probeLabels[_tab]);
  }

  @override
  void dispose() {
    RebuildStats.instance.stop();
    super.dispose();
  }

  void _selectTab(int tab) {
    setState(() => _tab = tab);
    // Fresh counters for the tab we just opened.
    RebuildStats.instance.track(_probeLabels[tab]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: const [
          Center(child: RebuildCounter()),
          _ExportReportButton(),
        ],
      ),
      // Only the visible tab exists. No IndexedStack: a hidden tab would keep
      // rebuilding on every tick and pollute the counts.
      body: _tab == 0 ? const ShippedWatchlist() : const OptimizedWatchlist(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bug_report_outlined),
            label: 'Shipped',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            label: 'Optimized',
          ),
        ],
      ),
    );
  }
}

/// Dumps the waste_lens report to the console: the before/after numbers for
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
