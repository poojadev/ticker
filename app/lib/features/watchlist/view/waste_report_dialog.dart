import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:waste_lens/waste_lens.dart';

import '../../../app/theme.dart';
import 'ep2_after_const.dart';
import 'ep2_before_const.dart';
import 'optimized_watchlist.dart';
import 'rebuild_stats.dart';
import 'shipped_watchlist.dart';

const _bugColor = Color(0xFFE0A52E); // same amber as the dead-rebuild flash
const _fixColor = TickerTheme.up;
const _constColor = Color(0xFF58A6FF); // Ep 2 "after": changed, not fixed

/// How one side of the comparison is labelled and coloured.
class _Side {
  const _Side(this.title, this.icon, this.color, this.probeLabel, this.jsonKey);

  final String title;
  final IconData icon;
  final Color color;
  final String probeLabel;
  final String jsonKey;
}

const _sides = {
  1: (
    _Side('With bug', Icons.bug_report, _bugColor, ShippedWatchlist.probeLabel,
        'withBug'),
    _Side('With fix', Icons.check_circle, _fixColor,
        OptimizedWatchlist.probeLabel, 'withFix'),
  ),
  2: (
    _Side('Before const', Icons.remove_circle, _bugColor,
        Ep2BeforeConst.probeLabel, 'beforeConst'),
    _Side('After const', Icons.push_pin, _constColor, Ep2AfterConst.probeLabel,
        'afterConst'),
  ),
};

/// Opens the waste report for [episode]: its two tabs side by side, plus the
/// app-wide waste_lens totals. Also prints the raw JSON to the console.
Future<void> showWasteReportDialog(BuildContext context, {int episode = 1}) {
  final stats = RebuildStats.instance;
  final (leftSide, rightSide) = _sides[episode]!;
  // Freeze the numbers now: the visible tab keeps ticking under the dialog.
  final left = _RunSnapshot.of(stats.runFor(leftSide.probeLabel));
  final right = _RunSnapshot.of(stats.runFor(rightSide.probeLabel));
  final waste = WasteLens.exportReport();

  final json = <String, Object?>{
    'episode': episode,
    leftSide.jsonKey: left?.toJson(),
    rightSide.jsonKey: right?.toJson(),
    'wasteLens': waste,
  };
  debugPrint(const JsonEncoder.withIndent('  ').convert(json));

  return showDialog<void>(
    context: context,
    builder: (_) => _WasteReportDialog(
      episode: episode,
      leftSide: leftSide,
      rightSide: rightSide,
      left: left,
      right: right,
      wasteLens: waste,
      json: json,
    ),
  );
}

/// Banner builds per 10 s. A banner built only once (when the tab opened)
/// says "once": scaling one build to "0.8 / 10 s" would just confuse.
String _bannerRate(_RunSnapshot run) {
  if (run.banner <= 1) return run.banner == 0 ? '0' : 'once';
  return _rate(run.per10s(run.banner));
}

/// The banner's count in words, for the summary line.
String _bannerPhrase(_RunSnapshot run) {
  if (run.banner == 1) return 'a single build, when the tab opened';
  return '${_bannerRate(run)} builds / 10 s';
}

/// Per-10 s numbers: whole numbers from 10 up; below that, the nearest whole
/// number if it's close (0.99 -> "1"), else one decimal (0.3 -> "0.3").
String _rate(double v) {
  if (v >= 10 || (v - v.round()).abs() < 0.15) return v.round().toString();
  return v.toStringAsFixed(1);
}

/// One tab's numbers, frozen at the moment the report opened.
class _RunSnapshot {
  const _RunSnapshot(this.rebuilds, this.dead, this.banner, this.duration);

  static _RunSnapshot? of(TabRun? run) => run == null
      ? null
      : _RunSnapshot(run.rebuilds, run.dead, run.bannerBuilds, run.duration);

  final int rebuilds;
  final int dead;
  final int banner;
  final Duration duration;

  double get seconds => duration.inMilliseconds / 1000;

  /// Tabs are measured for different lengths of time. Scaling to "per 10 s"
  /// makes them comparable.
  double per10s(int count) => seconds == 0 ? 0 : count / seconds * 10;

  int get wastedPercent => rebuilds == 0 ? 0 : (dead / rebuilds * 100).round();

  Map<String, Object?> toJson() => {
        'rebuilds': rebuilds,
        'dead': dead,
        'bannerBuilds': banner,
        'seconds': double.parse(seconds.toStringAsFixed(1)),
        'wastedPercent': wastedPercent,
      };
}

class _WasteReportDialog extends StatelessWidget {
  const _WasteReportDialog({
    required this.episode,
    required this.leftSide,
    required this.rightSide,
    required this.left,
    required this.right,
    required this.wasteLens,
    required this.json,
  });

  final int episode;
  final _Side leftSide;
  final _Side rightSide;
  final _RunSnapshot? left;
  final _RunSnapshot? right;
  final Map<String, Object?> wasteLens;
  final Map<String, Object?> json;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TickerTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Header(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  // 1. The comparison: the whole point of the episode.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _TabCard(
                            side: leftSide,
                            run: left,
                            showBanner: episode == 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TabCard(
                            side: rightSide,
                            run: right,
                            showBanner: episode == 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (episode == 2)
                    _ConstVerdict(before: left, after: right)
                  else
                    _Verdict(withBug: left, withFix: right),
                  const SizedBox(height: 20),
                  // 2. What the numbers mean, in one line each.
                  _Glossary(showBanner: episode == 2),
                  const SizedBox(height: 8),
                  // 3. Everything else waste_lens knows, folded away.
                  _AppTotals(report: wasteLens),
                ],
              ),
            ),
            _Actions(json: json),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waste report',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Same ticks on both tabs. Each tab is measured from the '
                  'moment you opened it.',
                  style: TextStyle(color: TickerTheme.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// One tab's card: the dead-rebuild count big, the details underneath.
class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.side,
    required this.run,
    this.showBanner = false,
  });

  final _Side side;
  final _RunSnapshot? run;

  /// Episode 2 also shows how often MarketStatusBanner was built.
  final bool showBanner;

  @override
  Widget build(BuildContext context) {
    final run = this.run;
    final color = side.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TickerTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(side.icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                side.title,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (run == null)
            const Text(
              'Not measured yet.\nOpen this tab for a few seconds.',
              style: TextStyle(color: TickerTheme.muted, fontSize: 13),
            )
          else ...[
            // Headline: dead rebuilds per 10 seconds.
            Text(
              run.per10s(run.dead).round().toString(),
              style: TickerTheme.numbers.copyWith(fontSize: 34, color: color),
            ),
            const Text(
              'dead rebuilds / 10 s',
              style: TextStyle(color: TickerTheme.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _StatLine('Rebuilds / 10 s', _rate(run.per10s(run.rebuilds))),
            _StatLine('Wasted', '${run.wastedPercent}%'),
            if (showBanner) _StatLine('Banner / 10 s', _bannerRate(run)),
            const Divider(height: 16),
            // The raw counts behind the "/ 10 s" numbers above.
            Text(
              'Measured ${run.seconds.toStringAsFixed(1)} s\n'
              '${run.rebuilds} rebuilds\n'
              '${run.dead} dead'
              '${showBanner ? '\n${run.banner} banner build${run.banner == 1 ? '' : 's'}' : ''}',
              style: TickerTheme.numbers.copyWith(
                color: TickerTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Text(value, style: TickerTheme.numbers.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

/// One sentence that sums up the comparison.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.withBug, required this.withFix});

  final _RunSnapshot? withBug;
  final _RunSnapshot? withFix;

  @override
  Widget build(BuildContext context) {
    final bug = withBug;
    final fix = withFix;
    final String message;
    if (bug == null || fix == null) {
      message = 'Open both tabs for ~10 seconds each to compare them.';
    } else {
      final bugRate = bug.per10s(bug.rebuilds);
      final fixRate = fix.per10s(fix.rebuilds);
      final fewer = bugRate == 0 ? 0 : ((1 - fixRate / bugRate) * 100).round();
      message = 'The fix does $fewer% fewer rebuilds, and '
          '${fix.dead == 0 ? 'none of them are' : '${fix.wastedPercent}% are'} '
          'wasted (vs ${bug.wastedPercent}% with the bug).';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fixColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, color: _fixColor, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Episode 2's summary: const didn't change the tiles, but it did change the
/// banner. Stated in plain words with this run's numbers.
class _ConstVerdict extends StatelessWidget {
  const _ConstVerdict({required this.before, required this.after});

  final _RunSnapshot? before;
  final _RunSnapshot? after;

  @override
  Widget build(BuildContext context) {
    final b = before;
    final a = after;
    final String message;
    if (b == null || a == null) {
      message = 'Open both tabs for ~10 seconds each to compare them.';
    } else {
      final deadB = _rate(b.per10s(b.dead));
      final deadA = _rate(a.per10s(a.dead));
      message = "const didn't change the tiles ($deadB → $deadA dead / 10 s), "
          'but the banner went from ${_bannerPhrase(b)} to ${_bannerPhrase(a)}.';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _constColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, color: _constColor, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _Glossary extends StatelessWidget {
  const _Glossary({this.showBanner = false});

  final bool showBanner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('What the numbers mean'),
        _Explain(
          'Rebuilds',
          'How many times a QuoteTile was built. Each one costs build, '
              'layout and paint time.',
        ),
        _Explain(
          'Dead rebuilds',
          'Rebuilds where the tile\'s quote was the same as last time, so it '
              'drew identical pixels. Pure waste, proven by DeadRebuildProbe.',
        ),
        _Explain(
          'Wasted',
          'Dead rebuilds as a share of all rebuilds.',
        ),
        _Explain(
          '/ 10 s',
          'Tabs are open for different lengths of time, so counts are scaled '
              'to 10 seconds to compare them fairly.',
        ),
        if (showBanner)
          const _Explain(
            'Banner builds',
            'How many times MarketStatusBanner.build ran. A const banner is '
                'the same instance every time, so Flutter skips it.',
          ),
      ],
    );
  }
}

/// App-wide waste_lens totals since launch (both tabs, plus network, leaks
/// and memory). Collapsed by default: Episode 1 is about rebuilds.
class _AppTotals extends StatelessWidget {
  const _AppTotals({required this.report});

  final Map<String, Object?> report;

  Object? _value(String section, String key) =>
      (report[section] as Map<String, Object?>?)?[key];

  @override
  Widget build(BuildContext context) {
    if (report.isEmpty) {
      return const _Explain(
        'waste_lens is off',
        'It only runs in debug and profile builds.',
      );
    }
    return Theme(
      // No divider lines above/below the expansion tile.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const _SectionTitle('Whole app since launch'),
        children: [
          _TotalRow(
            'Dead rebuilds',
            '${_value('rebuilds', 'dead') ?? 0}',
            'Both tabs together, never reset.',
          ),
          _TotalRow(
            'Churn warnings',
            '${_value('rebuilds', 'churnEvents') ?? 0}',
            'A widget type rebuilt 30+ times in 2 s (frequent, not '
                'necessarily wasted).',
          ),
          _TotalRow(
            'Redundant API calls',
            '${_value('redundantCalls', 'count') ?? 0}',
            'Same request repeated within 2 s (Dio interceptor).',
          ),
          _TotalRow(
            'Leaked objects',
            '${_value('leaks', 'count') ?? 0}',
            'Controllers or notifiers never disposed.',
          ),
          _TotalRow(
            'App memory',
            _megabytes(_value('memory', 'rssBytes')),
            'Whole process (RSS). Debug builds use far more than release.',
          ),
        ],
      ),
    );
  }

  static String _megabytes(Object? bytes) =>
      bytes is int ? '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB' : '-';
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, this.explanation);

  final String label;
  final String value;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                Text(
                  explanation,
                  style:
                      const TextStyle(color: TickerTheme.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: TickerTheme.numbers.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: TickerTheme.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _Explain extends StatelessWidget {
  const _Explain(this.term, this.meaning);

  final String term;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$term  ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: meaning,
              style: const TextStyle(color: TickerTheme.muted),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.json});

  final Map<String, Object?> json;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy JSON'),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: const JsonEncoder.withIndent('  ').convert(json),
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report JSON copied')),
              );
            },
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
