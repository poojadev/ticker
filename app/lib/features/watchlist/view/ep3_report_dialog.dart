import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/di.dart';
import '../../../app/quote_call_stats.dart';
import '../../../app/theme.dart';

const _bugColor = Color(0xFFE0A52E);
const _coalesceColor = Color(0xFF58A6FF);
const _fixColor = TickerTheme.up;

class _RunSpec {
  const _RunSpec(this.key, this.title, this.icon, this.color);

  final String key;
  final String title;
  final IconData icon;
  final Color color;
}

const _runs = [
  _RunSpec('ep3 bug', 'With bug', Icons.bug_report, _bugColor),
  _RunSpec('ep3 bug + coalesce', 'With bug + coalesce', Icons.call_merge,
      _coalesceColor),
  _RunSpec('ep3 fix', 'With fix', Icons.check_circle, _fixColor),
];

/// Episode 3's waste report: GET /quote/{symbol} traffic per run.
Future<void> showEp3ReportDialog(BuildContext context) {
  final stats = getIt<QuoteCallStats>();
  // Freeze the numbers now.
  final snaps = {
    for (final spec in _runs)
      if (stats.runFor(spec.key) case final run?)
        spec.key: (run.value, run.opens),
  };
  final json = {
    'episode': 3,
    for (final e in snaps.entries)
      e.key: {
        'opens': e.value.$2,
        'requests': e.value.$1.requests,
        'reachedServer': e.value.$1.reachedServer,
        'redundant': e.value.$1.redundant,
        'coalesced': e.value.$1.coalesced,
        'wastedBytes': e.value.$1.wastedBytes,
      },
  };
  debugPrint(const JsonEncoder.withIndent('  ').convert(json));
  return showDialog<void>(
    context: context,
    builder: (_) => _Ep3Report(snaps: snaps, json: json),
  );
}

class _Ep3Report extends StatelessWidget {
  const _Ep3Report({required this.snaps, required this.json});

  final Map<String, (CallTotals, int)> snaps;
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
            Padding(
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
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'GET /quote/{symbol} calls. Each run counts from the '
                          'moment you opened the tab (or flipped coalesce).',
                          style:
                              TextStyle(color: TickerTheme.muted, fontSize: 13),
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
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  for (final spec in _runs) ...[
                    _RunCard(spec: spec, snap: snaps[spec.key]),
                    const SizedBox(height: 10),
                  ],
                  _Verdict(snaps: snaps),
                  const SizedBox(height: 16),
                  const _Glossary(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy JSON'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: const JsonEncoder.withIndent('  ')
                              .convert(json)));
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
            ),
          ],
        ),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.spec, required this.snap});

  final _RunSpec spec;
  final (CallTotals, int)? snap;

  @override
  Widget build(BuildContext context) {
    final snap = this.snap;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TickerTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: spec.color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(spec.icon, color: spec.color, size: 18),
              const SizedBox(width: 6),
              Text(spec.title,
                  style: TextStyle(
                      color: spec.color, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (snap != null)
                Text('${snap.$2} opens',
                    style: const TextStyle(
                        color: TickerTheme.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          if (snap == null)
            const Text('Not measured yet.',
                style: TextStyle(color: TickerTheme.muted, fontSize: 13))
          else ...[
            _Line('Requests the app made', '${snap.$1.requests}', bold: true),
            _Line('Reached the server', '${snap.$1.reachedServer}'),
            _Line('Flagged redundant', '${snap.$1.redundant}'),
            _Line('Coalesced (merged)', '${snap.$1.coalesced}'),
            _Line('Wasted', _bytes(snap.$1.wastedBytes)),
          ],
        ],
      ),
    );
  }

  static String _bytes(int b) =>
      b < 1024 ? '$b B' : '${(b / 1024).toStringAsFixed(1)} KB';
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: TickerTheme.numbers.copyWith(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The result in plain words, from this run's numbers.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.snaps});

  final Map<String, (CallTotals, int)> snaps;

  @override
  Widget build(BuildContext context) {
    final bug = snaps['ep3 bug'];
    final coalesce = snaps['ep3 bug + coalesce'];
    final fix = snaps['ep3 fix'];
    final parts = <String>[];
    if (bug != null && bug.$2 > 0) {
      parts.add(
          'With the bug, ${bug.$2} opens made ${bug.$1.requests} requests.');
      if (bug.$1.redundant == 0 && bug.$1.requests > bug.$2) {
        parts.add(
            "waste_lens didn't flag them: both start at the same time, and it "
            'only flags a copy of a request that has already finished. '
            'Only coalesce mode catches these.');
      }
    }
    if (coalesce != null && coalesce.$2 > 0) {
      parts.add(
          'Coalesce kept ${coalesce.$1.coalesced} duplicates off the server, '
          'but the code still asked ${coalesce.$1.requests} times for '
          '${coalesce.$2} opens.');
    }
    if (fix != null && fix.$2 > 0) {
      parts.add(
          'With the fix, ${fix.$2} opens made ${fix.$1.requests} requests.');
    }
    if (parts.isEmpty) {
      parts.add(
          'Open the detail screen for a few symbols on each tab to compare.');
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fixColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights, color: _fixColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(parts.join(' '), style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _Glossary extends StatelessWidget {
  const _Glossary();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        'Requests the app made',
        'Every call to GET /quote/{symbol}, counted by the interceptor.'
      ),
      (
        'Reached the server',
        'Requests minus coalesced ones. Matches the server log.'
      ),
      (
        'Flagged redundant',
        'Duplicates waste_lens_dio caught (repeat within 2 s, or coalesced).'
      ),
      (
        'Coalesced',
        'Duplicates merged into the identical request already on the wire.'
      ),
      (
        'Wasted',
        'Response bytes the duplicates fetched (or would have fetched) again.'
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (term, meaning) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '$term  ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(
                    text: meaning,
                    style: const TextStyle(color: TickerTheme.muted)),
              ]),
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
