import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:waste_lens/waste_lens.dart';

/// One measurement on one tab: from the moment the tab opened until you left
/// it (or until now, for the visible tab).
class TabRun {
  TabRun() : startedAt = DateTime.now();

  final DateTime startedAt;
  DateTime? endedAt;

  /// Times QuoteTile.build ran.
  int rebuilds = 0;

  /// Rebuilds waste_lens proved were dead (same quote, same pixels).
  int dead = 0;

  /// Times MarketStatusBanner.build ran (Episode 2 tabs only).
  int bannerBuilds = 0;

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  /// Share of rebuilds that were wasted, 0..1.
  double get wastedShare => rebuilds == 0 ? 0 : dead / rebuilds;
}

/// Live numbers for the visible tab, plus the last run of every tab so the
/// waste report can compare "with bug" against "with fix".
///
/// Counters change WHILE Flutter is building (QuoteTile.build) or right after
/// (the bus event). So we never notify listeners immediately: we wait for the
/// frame to finish (addPostFrameCallback), then update the AppBar once.
/// That's the same "setState during build" trap waste_lens 0.1.1 fell into.
class RebuildStats extends ChangeNotifier {
  RebuildStats._();

  /// One shared instance, so QuoteTile can count without extra parameters.
  static final RebuildStats instance = RebuildStats._();

  /// Latest run per probe label ('QuoteTile · shipped', ...).
  final Map<String, TabRun> _runs = {};

  String _label = '';
  StreamSubscription<DiagnosticEvent>? _deadEvents;
  bool _notifyScheduled = false;

  TabRun? get _current => _runs[_label];

  /// Visible tab's numbers, for the AppBar.
  int get rebuilds => _current?.rebuilds ?? 0;
  int get dead => _current?.dead ?? 0;
  int get bannerBuilds => _current?.bannerBuilds ?? 0;

  /// The latest run for the tab whose probe uses [label], or null if that tab
  /// hasn't been opened yet.
  TabRun? runFor(String label) => _runs[label];

  /// Start a fresh measurement for the tab whose DeadRebuildProbe uses
  /// [label]. The tab we're leaving keeps its numbers, frozen.
  void track(String label) {
    _current?.endedAt = DateTime.now();
    _label = label;
    _runs[label] = TabRun();
    _deadEvents?.cancel();
    _deadEvents = WasteLens.current?.bus.stream.listen((event) {
      if (event is RebuildEvent && event.dead && event.widget == _label) {
        _current?.dead++;
        _notifyAfterFrame();
      }
    });
    _notifyAfterFrame();
  }

  /// Called from QuoteTile.build. Just an int increment: cheap.
  void recordRebuild() {
    _current?.rebuilds++;
    _notifyAfterFrame();
  }

  /// Called from MarketStatusBanner.build. Same idea: an int++.
  void recordBannerBuild() {
    _current?.bannerBuilds++;
    _notifyAfterFrame();
  }

  /// Stop listening to waste_lens and forget all runs (the page is gone).
  void stop() {
    _deadEvents?.cancel();
    _deadEvents = null;
    _runs.clear();
    _label = '';
  }

  /// Many changes in one frame -> one AppBar update, after that frame.
  void _notifyAfterFrame() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _notifyScheduled = false;
        notifyListeners();
      })
      // If no frame is coming (e.g. a bus event between frames), ask for one.
      ..ensureVisualUpdate();
  }
}

/// "rebuilds: N · dead: M" for the visible tab. Episode 2 adds a second
/// line, "banner: B", so the AppBar stays the same width as in Episode 1.
class RebuildCounter extends StatelessWidget {
  const RebuildCounter({super.key, this.showBanner = false});

  final bool showBanner;

  @override
  Widget build(BuildContext context) {
    final stats = RebuildStats.instance;
    return ListenableBuilder(
      listenable: stats,
      builder: (context, _) => Text(
        'rebuilds: ${stats.rebuilds} · dead: ${stats.dead}'
        '${showBanner ? '\nbanner: ${stats.bannerBuilds}' : ''}',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: showBanner ? 12 : 13,
          height: showBanner ? 1.25 : null,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
