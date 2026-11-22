import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:waste_lens/waste_lens.dart';
import 'package:waste_lens_dio/waste_lens_dio.dart';

/// GET /quote/{symbol} traffic, as waste_lens_dio's RedundantCallInterceptor
/// sees it. One instance for the whole app (get_it).
///
/// It also owns the interceptor, so the Episode 3 "coalesce" switch can swap in
/// a new one: RedundantCallInterceptor's options are final.
class QuoteCallStats extends ChangeNotifier {
  QuoteCallStats({this.bus}) : _current = _make(bus, coalesce: false) {
    // Coalesced duplicates only show up as bus events (CallReport has no
    // per-endpoint coalesced count), so count those here.
    _busSub = bus?.stream.listen((event) {
      if (event is RedundantCall &&
          event.coalesced &&
          _isQuote(event.endpoint)) {
        _coalescedTotal++;
        _notifyAfterFrame();
      }
    });
  }

  final DiagnosticsBus? bus;
  RedundantCallInterceptor _current;
  bool _coalesce = false;

  StreamSubscription<DiagnosticEvent>? _busSub;
  int _coalescedTotal = 0;

  /// Totals from interceptors we've already swapped out.
  CallTotals _retired = CallTotals.zero;

  String _label = '';
  final Map<String, NetRun> _runs = {};
  bool _notifyScheduled = false;

  static RedundantCallInterceptor _make(DiagnosticsBus? bus,
          {required bool coalesce}) =>
      RedundantCallInterceptor(bus: bus, coalesce: coalesce);

  static bool _isQuote(String endpoint) => endpoint.startsWith('GET /quote/');

  /// Add this to Dio once. It forwards to whichever interceptor is current.
  Interceptor get interceptor => _Forwarder(this);

  /// Is in-flight coalescing on? (Episode 3's "shortcut".)
  bool get coalesce => _coalesce;

  /// The run key for the visible Episode 3 tab, e.g. 'ep3 bug + coalesce'.
  String get runKey => '$_label${_coalesce ? ' + coalesce' : ''}';

  /// The visible tab's run.
  NetRun? get current => _runs[runKey];

  NetRun? runFor(String key) => _runs[key];

  /// All /quote/ traffic seen so far, across interceptor swaps.
  CallTotals get totals {
    var requests = 0, redundant = 0, wasted = 0;
    for (final e in _current.report.endpoints) {
      if (_isQuote(e.endpoint)) {
        requests += e.total;
        redundant += e.redundant;
        wasted += e.wastedBytes;
      }
    }
    return CallTotals(
      requests: _retired.requests + requests,
      redundant: _retired.redundant + redundant,
      // Counted from bus events, app-wide: no per-interceptor bookkeeping.
      coalesced: _coalescedTotal,
      wastedBytes: _retired.wastedBytes + wasted,
    );
  }

  /// Start a fresh run for an Episode 3 tab. Coalescing always starts OFF.
  void track(String label) {
    _endRun(); // close the run we're leaving BEFORE its key changes
    _setCoalesce(false);
    _label = label;
    _beginRun();
  }

  /// The "coalesce" switch. Starts a separate run, so the numbers never mix.
  void setCoalesce(bool on) {
    if (on == _coalesce) return;
    _endRun(); // close the run we're leaving BEFORE its key changes
    _setCoalesce(on);
    _beginRun();
  }

  /// A detail screen was opened in the current run.
  void recordOpen() {
    current?.opens++;
    _notifyAfterFrame();
  }

  void _setCoalesce(bool on) {
    if (on == _coalesce) return;
    _retired = totals;
    _coalesce = on;
    _current = _make(bus, coalesce: on);
  }

  /// Freezes the current run's numbers.
  void _endRun() => current?.end ??= totals;

  void _beginRun() {
    _runs[runKey] = NetRun(start: totals, coalesce: _coalesce, stats: this);
    _notifyAfterFrame();
  }

  /// Many responses in one frame -> one update, after that frame.
  void _notifyAfterFrame() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _notifyScheduled = false;
        notifyListeners();
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _busSub?.cancel();
    super.dispose();
  }
}

/// /quote/ traffic counters.
class CallTotals {
  const CallTotals({
    required this.requests,
    required this.redundant,
    required this.coalesced,
    required this.wastedBytes,
  });

  static const zero =
      CallTotals(requests: 0, redundant: 0, coalesced: 0, wastedBytes: 0);

  /// Requests the app made (including ones the interceptor then coalesced).
  final int requests;

  /// Duplicates the interceptor flagged.
  final int redundant;

  /// Duplicates merged into an in-flight request (never reached the server).
  final int coalesced;

  /// Response bytes the duplicates fetched (or would have fetched) again.
  final int wastedBytes;

  /// Requests that actually reached the server.
  int get reachedServer => requests - coalesced;

  CallTotals operator +(CallTotals o) => CallTotals(
        requests: requests + o.requests,
        redundant: redundant + o.redundant,
        coalesced: coalesced + o.coalesced,
        wastedBytes: wastedBytes + o.wastedBytes,
      );

  CallTotals operator -(CallTotals o) => CallTotals(
        requests: requests - o.requests,
        redundant: redundant - o.redundant,
        coalesced: coalesced - o.coalesced,
        wastedBytes: wastedBytes - o.wastedBytes,
      );
}

/// One measurement: from the moment a tab opened (or coalesce was toggled)
/// until you left it.
class NetRun {
  NetRun({required this.start, required this.coalesce, required this.stats});

  final CallTotals start;
  final bool coalesce;
  final QuoteCallStats stats;
  CallTotals? end;
  int opens = 0;

  CallTotals get value => (end ?? stats.totals) - start;
}

/// Forwards to the current RedundantCallInterceptor and nudges the counters
/// after every response.
class _Forwarder extends Interceptor {
  _Forwarder(this._stats);

  final QuoteCallStats _stats;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _stats._current.onRequest(options, handler);
    _stats._notifyAfterFrame();
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    _stats._current.onResponse(response, handler);
    _stats._notifyAfterFrame();
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _stats._current.onError(err, handler);
    _stats._notifyAfterFrame();
  }
}

/// "requests: N · redundant: M" for the visible Episode 3 run.
class RequestCounter extends StatelessWidget {
  const RequestCounter({super.key, required this.stats});

  final QuoteCallStats stats;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: stats,
      builder: (context, _) {
        final run = stats.current?.value ?? CallTotals.zero;
        return Text(
          'requests: ${run.requests} · redundant: ${run.redundant}',
          style: const TextStyle(
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}
