import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/quote.dart';

/// Live price ticks over WebSocket.
///
/// Each call to [connect] opens a NEW socket. Whoever listens is responsible
/// for cancelling the subscription — which closes the socket. (Episode 5 is
/// about what happens when someone forgets.)
class PriceStream {
  PriceStream(this._uri);

  final Uri _uri;

  Stream<List<Tick>> connect() {
    final channel = WebSocketChannel.connect(_uri);
    return channel.stream.map((raw) {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final data = msg['data'] as List<dynamic>;
      return [for (final t in data) Tick.fromJson(t as Map<String, dynamic>)];
    }).handleError((Object _) {
      // Keep the demo resilient; a real app would surface a reconnect banner.
    }).asBroadcastStream(
      // Close the socket when the last listener cancels.
      onCancel: (sub) {
        sub.cancel();
        channel.sink.close();
      },
    );
  }
}
