import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:waste_lens/waste_lens.dart';

/// Live numbers for the AppBar: how many times QuoteTile.build ran, and how
/// many of those rebuilds waste_lens proved were dead, for the visible tab.
///
/// Both counters change WHILE Flutter is building (QuoteTile.build) or right
/// after (the bus event). So we never notify listeners immediately: we wait
/// for the frame to finish (addPostFrameCallback), then update the AppBar once.
/// That's the same "setState during build" trap waste_lens 0.1.1 fell into.
class RebuildStats extends ChangeNotifier {
  RebuildStats._();

  /// One shared instance, so QuoteTile can count without extra parameters.
  static final RebuildStats instance = RebuildStats._();

  int rebuilds = 0;
  int dead = 0;

  String _label = '';
  StreamSubscription<DiagnosticEvent>? _deadEvents;
  bool _notifyScheduled = false;

  /// Start counting for the tab whose DeadRebuildProbe uses [label].
  /// Resets both counters.
  void track(String label) {
    _label = label;
    rebuilds = 0;
    dead = 0;
    _deadEvents?.cancel();
    _deadEvents = WasteLens.current?.bus.stream.listen((event) {
      if (event is RebuildEvent && event.dead && event.widget == _label) {
        dead++;
        _notifyAfterFrame();
      }
    });
    _notifyAfterFrame();
  }

  /// Called from QuoteTile.build. Just an int increment: cheap.
  void recordRebuild() {
    rebuilds++;
    _notifyAfterFrame();
  }

  /// Stop listening to waste_lens (the page is gone).
  void stop() {
    _deadEvents?.cancel();
    _deadEvents = null;
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

/// "rebuilds: N · dead: M" for the visible tab.
class RebuildCounter extends StatelessWidget {
  const RebuildCounter({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = RebuildStats.instance;
    return ListenableBuilder(
      listenable: stats,
      builder: (context, _) => Text(
        'rebuilds: ${stats.rebuilds} · dead: ${stats.dead}',
        style: const TextStyle(
          fontSize: 13,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
