import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:ticker_server/market.dart';
import 'package:ticker_server/news.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Ticker mock market server.
///
///   dart run bin/server.dart                      # defaults
///   dart run bin/server.dart --symbols 100 --hz 5 # stress mode for recording
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: '8080')
    ..addOption('symbols', defaultsTo: '50', help: 'Instruments in the market')
    ..addOption('hz', defaultsTo: '2', help: 'Ticks per second')
    ..addOption('per-tick',
        defaultsTo: '3', help: 'How many symbols change on each tick')
    ..addOption('latency-ms',
        defaultsTo: '150', help: 'Artificial REST latency (realistic overlap)')
    ..addOption('seed', defaultsTo: '42')
    ..addFlag('help', abbr: 'h', negatable: false);
  final opts = parser.parse(args);
  if (opts['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  final port = int.parse(opts['port'] as String);
  final hz = double.parse(opts['hz'] as String);
  final latency = Duration(milliseconds: int.parse(opts['latency-ms'] as String));

  final market = Market(
    symbolCount: int.parse(opts['symbols'] as String),
    symbolsPerTick: int.parse(opts['per-tick'] as String),
    seed: int.parse(opts['seed'] as String),
  )..start(Duration(microseconds: (1000000 / hz).round()));
  final news = NewsFeed(market);

  final router = Router()
    ..get('/health', (Request _) => _json({'ok': true, 'ticks': market.tickCount}))
    // Watchlist bootstrap: the list of symbols.
    ..get('/symbols', (Request _) {
      return _json([
        for (final i in market.instruments.values)
          {'symbol': i.symbol, 'name': i.name, 'sector': i.sector},
      ]);
    })
    // Batch quotes: GET /quotes?symbols=NOVA,KITE  (the efficient way)
    ..get('/quotes', (Request req) {
      final wanted = req.url.queryParameters['symbols']?.split(',');
      final list = [
        for (final i in market.instruments.values)
          if (wanted == null || wanted.contains(i.symbol)) i.toQuoteJson(),
      ];
      return _json(list);
    })
    // Single quote: GET /quote/NOVA  (the one apps tend to call too often)
    ..get('/quote/<symbol>', (Request req, String symbol) {
      final inst = market.instruments[symbol.toUpperCase()];
      if (inst == null) return _json({'error': 'unknown symbol'}, status: 404);
      return _json(inst.toQuoteJson());
    })
    ..get('/history/<symbol>', (Request req, String symbol) {
      final points = market.history(symbol.toUpperCase());
      if (points.isEmpty) return _json({'error': 'unknown symbol'}, status: 404);
      return _json({'symbol': symbol.toUpperCase(), 'range': '1D', 'points': points});
    })
    ..get('/news', (Request req) {
      final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
      final size = int.tryParse(req.url.queryParameters['pageSize'] ?? '10') ?? 10;
      return _json(news.page(page, size));
    })
    ..get('/images/<file>', (Request req, String file) {
      final id = file.replaceAll('.bmp', '');
      return Response.ok(bmpImage(id), headers: {
        'content-type': 'image/bmp',
        'cache-control': 'no-store',
      });
    })
    // Live prices. Each message: {"type":"ticks","data":[{"s":"NOVA","p":123.4,"c":0.52}, ...]}
    ..get('/stream', webSocketHandler((WebSocketChannel ws, String? _) {
      _activeSockets++;
      stdout.writeln('[ws] client connected  (open sockets: $_activeSockets)');
      final sub = market.ticks.listen((batch) {
        ws.sink.add(jsonEncode({'type': 'ticks', 'data': batch}));
      });
      ws.stream.listen(
        (_) {},
        onDone: () {
          sub.cancel();
          _activeSockets--;
          stdout.writeln(
              '[ws] client disconnected (open sockets: $_activeSockets)');
        },
      );
    }));

  final handler = const Pipeline()
      .addMiddleware(_requestLog())
      .addMiddleware(_latency(latency))
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('''
Ticker mock market on http://${server.address.host}:${server.port}
  symbols=${market.instruments.length}  hz=$hz  per-tick=${opts['per-tick']}  latency=${latency.inMilliseconds}ms
  iOS simulator:     http://localhost:$port
  Android emulator:  http://10.0.2.2:$port
''');
}

int _activeSockets = 0;

Response _json(Object body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );

Middleware _latency(Duration d) => (inner) => (req) async {
      if (d > Duration.zero && !req.url.path.startsWith('stream')) {
        await Future<void>.delayed(d);
      }
      return inner(req);
    };

/// Logs every request and flags repeats of the same path within 2 seconds —
/// the server-side view of the redundant-call episodes.
Middleware _requestLog() {
  final recent = <String, List<DateTime>>{};
  var n = 0;
  return (inner) => (req) async {
        final key = '${req.method} /${req.url}';
        final now = DateTime.now();
        final hits = recent.putIfAbsent(key, () => [])
          ..removeWhere((t) => now.difference(t) > const Duration(seconds: 2))
          ..add(now);
        n++;
        final dup = hits.length > 1 ? '   <-- x${hits.length} in 2s' : '';
        if (!req.url.path.startsWith('stream')) {
          stdout.writeln('[#$n] $key$dup');
        }
        return inner(req);
      };
}
