import 'dart:typed_data';

class Metadata {
  static const String kMagicString = "deepdef:";
  static const int kVersion = 0;
  static const int kSize = 8 + 2 + 2 + 8;

  int size() { return kSize; }

  void fill(int timeMs, int algorithmId, Uint8List metadata) {
    // [magic string (8)] [version (2)] [algorithm (2)] [time (8)]
    for (var i = 0; i < kMagicString.length; ++i) {
      metadata[i] = kMagicString.codeUnitAt(i);
    }

    final verData = Uint8List.sublistView(metadata, 8).buffer.asUint16List();
    verData[0] = kVersion;
    verData[1] = algorithmId;

    final timeData = Uint8List.sublistView(metadata, 12).buffer.asUint64List();
    timeData[0] = timeMs;
  }
}
