import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/quote.dart';

/// Live price ticks over WebSocket.
///
/// Each call to [connect] returns a stream that opens a NEW socket when
/// someone listens, and closes that socket when they cancel. Whoever listens
/// is responsible for cancelling. (Episode 5 is about what happens when
/// someone forgets.)
class PriceStream {
  PriceStream(this._uri);

  final Uri _uri;

  Stream<List<Tick>> connect() {
    WebSocketChannel? channel;
    StreamSubscription<dynamic>? socketSub;
    late final StreamController<List<Tick>> controller;

    controller = StreamController<List<Tick>>(
      // 1. Someone listened: open the socket and forward each message.
      onListen: () {
        channel = WebSocketChannel.connect(_uri);
        socketSub = channel!.stream.listen(
          (raw) => controller.add(_parse(raw as String)),
          // Keep the demo resilient: a dropped socket just stops the ticks.
          // A real app would show a "reconnecting" banner here.
          onError: (Object _) {},
          onDone: controller.close,
        );
      },
      // 2. The listener cancelled: stop listening and close the socket.
      //    The server logs this as "client disconnected".
      onCancel: () async {
        await socketSub?.cancel();
        await channel?.sink.close();
      },
    );
    return controller.stream;
  }

  /// `{"type":"ticks","data":[{"s":"NOVA","p":123.45,"c":0.52}]}` -> ticks.
  List<Tick> _parse(String raw) {
    final msg = jsonDecode(raw) as Map<String, dynamic>;
    final data = msg['data'] as List<dynamic>;
    return [for (final t in data) Tick.fromJson(t as Map<String, dynamic>)];
  }
}
