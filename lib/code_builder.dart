import 'dart:typed_data';
import 'audio_hasher.dart';
import 'byte_signer.dart';
import 'metadata.dart';

class CodeBuilder {
  final AudioHasher _hasher;
  final ByteSigner _signer;
  final Metadata _metadata;
  final Uint8List _buf;
  CodeBuilder(this._metadata, this._hasher, this._signer) :
      _buf = Uint8List(_metadata.size() + _hasher.size() + _signer.size()) {}

  Uint8List generate(int timeMs, Float64List audio) {
    // [metadata] [audio hash] [signature]
    // [    signable data    ] [signature]
    _metadata.fill(timeMs, _hasher.algorithmId(), _buf);
    _hasher.fill(audio, Uint8List.sublistView(_buf, _metadata.size()));
    final dataSize = _metadata.size() + _hasher.size();
    _signer.fill(
        Uint8List.sublistView(_buf, 0, dataSize),
        Uint8List.sublistView(_buf, dataSize));
    return _buf;
  }
}
