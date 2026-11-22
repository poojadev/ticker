import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/quote_call_stats.dart';
import '../../quote_detail/open_quote_detail.dart';
import '../bloc/watchlist_bloc.dart';
import 'ep2_after_const.dart';
import 'ep2_before_const.dart';
import 'optimized_watchlist.dart';
import 'rebuild_stats.dart';
import 'shipped_watchlist.dart';
import 'waste_report_dialog.dart';

/// One episode = two bottom tabs to compare.
class _Episode {
  const _Episode(this.tabs);

  final List<_Tab> tabs;
}

class _Tab {
  const _Tab(
      this.label, this.icon, this.selectedIcon, this.probeLabel, this.view);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String probeLabel;
  final Widget view;
}

const _episodes = [
  // Episode 1: "With bug" (ShippedWatchlist) vs "With fix" (OptimizedWatchlist).
  _Episode([
    _Tab('With bug', Icons.bug_report_outlined, Icons.bug_report,
        ShippedWatchlist.probeLabel, ShippedWatchlist()),
    _Tab('With fix', Icons.check_circle_outline, Icons.check_circle,
        OptimizedWatchlist.probeLabel, OptimizedWatchlist()),
  ]),
  // Episode 2: the same buggy list, without and with const.
  _Episode([
    _Tab('Before const', Icons.remove_circle_outline, Icons.remove_circle,
        Ep2BeforeConst.probeLabel, Ep2BeforeConst()),
    _Tab('After const', Icons.push_pin_outlined, Icons.push_pin,
        Ep2AfterConst.probeLabel, Ep2AfterConst()),
  ]),
  // Episode 3: Episode 1's fixed list. The tabs differ in which DETAIL page a
  // tapped tile opens: two widgets fetching the quote, or one shared cubit.
  _Episode([
    _Tab(
        'With bug',
        Icons.bug_report_outlined,
        Icons.bug_report,
        'ep3 bug',
        DetailVariantScope(
            variant: DetailVariant.bug, child: OptimizedWatchlist())),
    _Tab(
        'With fix',
        Icons.check_circle_outline,
        Icons.check_circle,
        'ep3 fix',
        DetailVariantScope(
            variant: DetailVariant.fix, child: OptimizedWatchlist())),
  ]),
];

/// Episode 3 counts network requests instead of rebuilds.
const _ep3 = 2;

/// The watchlist with an episode picker. Every tab of every episode shares ONE
/// WatchlistBloc: same data, same ticks, so the comparisons are fair.
class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Provided ABOVE all tabs: switching never reloads or resubscribes.
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
  int _episode = 0;
  int _tab = 0;

  _Tab get _current => _episodes[_episode].tabs[_tab];

  @override
  void initState() {
    super.initState();
    _track();
  }

  /// Fresh counters for the tab that's now visible.
  void _track() {
    RebuildStats.instance.track(_current.probeLabel);
    if (_episode == _ep3) getIt<QuoteCallStats>().track(_current.probeLabel);
  }

  @override
  void dispose() {
    RebuildStats.instance.stop();
    super.dispose();
  }

  void _select({int? episode, required int tab}) {
    setState(() {
      _episode = episode ?? _episode;
      _tab = tab;
    });
    _track();
  }

  @override
  Widget build(BuildContext context) {
    final isEp2 = _episode == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlist'),
        actions: [
          Center(
            child: _episode == _ep3
                ? RequestCounter(stats: getIt<QuoteCallStats>())
                : RebuildCounter(showBanner: isEp2),
          ),
          _ExportReportButton(episode: _episode + 1),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _EpisodePicker(
              episode: _episode,
              onChanged: (episode) => _select(episode: episode, tab: 0),
            ),
          ),
        ),
      ),
      // Only the visible tab of the visible episode exists. No IndexedStack: a
      // hidden tab would keep rebuilding on every tick and pollute the counts.
      body: _current.view,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => _select(tab: tab),
        destinations: [
          for (final tab in _episodes[_episode].tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

/// "Ep 1" / "Ep 2" / "Ep 3" segmented control under the AppBar title.
class _EpisodePicker extends StatelessWidget {
  const _EpisodePicker({required this.episode, required this.onChanged});

  final int episode;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      width: double.infinity,
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(value: 0, label: Text('Ep 1 · tick')),
          ButtonSegment(value: 1, label: Text('Ep 2 · const')),
          ButtonSegment(value: 2, label: Text('Ep 3 · calls')),
        ],
        selected: {episode},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

/// Opens the waste report for the visible episode (and prints the raw JSON to
/// the console): the before/after numbers for the end of each episode.
class _ExportReportButton extends StatelessWidget {
  const _ExportReportButton({required this.episode});

  final int episode;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Waste report',
      icon: const Icon(Icons.receipt_long_outlined),
      onPressed: () => showWasteReportDialog(context, episode: episode),
    );
  }
}
