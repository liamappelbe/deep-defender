import 'dart:typed_data';
import 'package:crypto_keys/crypto_keys.dart';

class ByteSigner {
  static const int kSize = 256 ~/ 8;

  final Signer _signer;
  ByteSigner(PrivateKey key)
      : _signer = key.createSigner(algorithms.signing.hmac.sha256) {}

  int size() { return kSize; }

  void fill(Uint8List data, Uint8List signature) {
    assert(signature.length == kSize);
    final s = _signer.sign(data).data;
    assert(s.length == kSize);
    signature.setAll(0, s);
  }
}
