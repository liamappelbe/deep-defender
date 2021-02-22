import 'dart:typed_data';
import 'audio_hasher.dart';

class TfEmbedder implements AudioHasher {
  static const int kEmbeddingSize = 32;
  static const int kSize = 3 * kEmbeddingSize;
  static const int kAlgorithmId = 0;

  @override
  int size() { return kSize; }

  @override
  int algorithmId() { return kAlgorithmId; }

  @override
  void fill(Float64List audio, Uint8List hash) {
    // TODO: Implement using tensorflow.
    hash.buffer.asFloat64List().setRange(0, kSize ~/ 8, audio);
  }
}
