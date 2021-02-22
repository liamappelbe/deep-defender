import 'dart:typed_data';

// Hashes the given audio buffer. Expects Microphone.kChunkSize samples.
abstract class AudioHasher {
  int size();
  int algorithmId();
  void fill(Float64List audio, Uint8List hash);
}
