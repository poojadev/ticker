import 'dart:math';
import 'dart:typed_data';

import 'market.dart';

/// Deterministic fake news feed.
class NewsFeed {
  NewsFeed(Market market, {int count = 60}) {
    final rng = Random(7);
    final symbols = market.instruments.keys.toList();
    for (var i = 0; i < count; i++) {
      final symbol = symbols[rng.nextInt(symbols.length)];
      final name = market.instruments[symbol]!.name;
      final template = _headlines[rng.nextInt(_headlines.length)];
      items.add({
        'id': 'n$i',
        'symbol': symbol,
        'headline': template.replaceAll('{co}', name),
        'source': _sources[rng.nextInt(_sources.length)],
        'publishedAt': DateTime.utc(2026, 1, 5, 16)
            .subtract(Duration(minutes: 17 * i))
            .toIso8601String(),
        // Served by this server. Deliberately LARGE (see [bmpImage]) so the
        // memory-pressure episode has something real to show.
        'imageUrl': '/images/n$i.bmp',
      });
    }
  }

  final List<Map<String, Object>> items = [];

  Map<String, Object> page(int page, int pageSize) {
    final start = (page - 1) * pageSize;
    final slice = start >= items.length
        ? <Map<String, Object>>[]
        : items.sublist(start, min(start + pageSize, items.length));
    return {
      'page': page,
      'pageSize': pageSize,
      'hasMore': start + pageSize < items.length,
      'items': slice,
    };
  }
}

const _headlines = [
  '{co} beats quarterly earnings expectations',
  '{co} announces new product line',
  'Analysts upgrade {co} to buy',
  '{co} shares slide after guidance cut',
  '{co} expands into European markets',
  '{co} CEO outlines five-year plan',
  'Regulators approve {co} merger',
  '{co} hit by supply chain delays',
];

const _sources = ['Market Wire', 'Daily Ledger', 'Trade Desk', 'Ticker Times'];

final Map<String, Uint8List> _imageCache = {};

/// A deterministic 24-bit BMP gradient. BMP is uncompressed, so a 1600x1000
/// image is ~4.8 MB on the wire and decodes to ~6.4 MB of RGBA in Flutter's
/// image cache — unless the app asks for a smaller decode size.
Uint8List bmpImage(String id, {int width = 1600, int height = 1000}) {
  return _imageCache.putIfAbsent(id, () {
    final rng = Random(stableHash(id));
    final c1 = [rng.nextInt(256), rng.nextInt(256), rng.nextInt(256)];
    final c2 = [rng.nextInt(256), rng.nextInt(256), rng.nextInt(256)];
    final rowSize = (width * 3 + 3) & ~3; // rows padded to 4 bytes
    final pixelBytes = rowSize * height;
    final fileSize = 54 + pixelBytes;
    final bytes = ByteData(fileSize);
    // BITMAPFILEHEADER
    bytes
      ..setUint8(0, 0x42)
      ..setUint8(1, 0x4D)
      ..setUint32(2, fileSize, Endian.little)
      ..setUint32(10, 54, Endian.little)
      // BITMAPINFOHEADER
      ..setUint32(14, 40, Endian.little)
      ..setInt32(18, width, Endian.little)
      ..setInt32(22, height, Endian.little)
      ..setUint16(26, 1, Endian.little)
      ..setUint16(28, 24, Endian.little)
      ..setUint32(34, pixelBytes, Endian.little);
    for (var y = 0; y < height; y++) {
      final row = 54 + y * rowSize;
      for (var x = 0; x < width; x++) {
        final t = (x / width + y / height) / 2;
        final o = row + x * 3;
        // BMP stores BGR.
        bytes
          ..setUint8(o, (c1[2] + (c2[2] - c1[2]) * t).round())
          ..setUint8(o + 1, (c1[1] + (c2[1] - c1[1]) * t).round())
          ..setUint8(o + 2, (c1[0] + (c2[0] - c1[0]) * t).round());
      }
    }
    return bytes.buffer.asUint8List();
  });
}
