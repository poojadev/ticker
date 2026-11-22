import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticker/app/quote_call_stats.dart';
import 'package:waste_lens/waste_lens.dart';

/// Answers GET /quote/{symbol} after a short delay, like the mock server.
class _FakeServer implements HttpClientAdapter {
  int hits = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? body,
      Future<void>? cancelFuture) async {
    hits++;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return ResponseBody.fromString(
      jsonEncode({'symbol': options.path.split('/').last}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DiagnosticsBus bus;
  late QuoteCallStats stats;
  late _FakeServer server;
  late Dio dio;

  setUp(() {
    bus = DiagnosticsBus();
    stats = QuoteCallStats(bus: bus);
    server = _FakeServer();
    dio = Dio(BaseOptions(baseUrl: 'http://ticker.test'))
      ..httpClientAdapter = server
      ..interceptors.add(stats.interceptor);
  });

  tearDown(() async {
    stats.dispose();
    await bus.dispose();
  });

  /// One detail-screen open on the bug page: two identical requests at once.
  Future<void> openBugPage(String symbol) async {
    await Future.wait([
      dio.get<dynamic>('/quote/$symbol'),
      dio.get<dynamic>('/quote/$symbol')
    ]);
    await pumpEventQueue(); // let bus events arrive
  }

  test('each run keeps its own numbers (bug, bug + coalesce, fix)', () async {
    stats.track('ep3 bug');
    await openBugPage('NOVA');

    stats.setCoalesce(true);
    await openBugPage('KITE');

    stats.track('ep3 fix');
    await dio.get<dynamic>('/quote/MERI');
    await pumpEventQueue();

    final bug = stats.runFor('ep3 bug')!.value;
    expect(bug.requests, 2);
    // Both copies were in flight together: the always-on check can't see it.
    expect(bug.redundant, 0);
    expect(bug.reachedServer, 2);

    final coalesce = stats.runFor('ep3 bug + coalesce')!.value;
    expect(coalesce.requests, 2); // the code still asked twice...
    expect(coalesce.redundant, 1);
    expect(coalesce.coalesced, 1);
    expect(coalesce.reachedServer, 1); // ...but only one reached the server

    final fix = stats.runFor('ep3 fix')!.value;
    expect(fix.requests, 1);
    expect(fix.redundant, 0);

    expect(server.hits, 2 + 1 + 1);
    expect(stats.coalesce, isFalse); // switching tabs turns coalesce off
  });

  test('a duplicate that starts AFTER the first finished is flagged', () async {
    stats.track('ep3 bug');
    await dio.get<dynamic>('/quote/NOVA');
    await dio.get<dynamic>('/quote/NOVA'); // sequential, within 2 s
    final run = stats.runFor('ep3 bug')!.value;
    expect(run.requests, 2);
    expect(run.redundant, 1);
    expect(run.coalesced, 0);
  });
}
