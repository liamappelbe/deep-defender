// Copyright 2022 The Deep Defender Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto_keys/crypto_keys.dart' as ck;
import 'package:pointycastle/src/utils.dart' show encodeBigInt, decodeBigInt;

/// Wrapper around crypto_keys to abstract away the details. For example, we
/// should be able to switch the crypto algorithm without changing the rest of
/// the app.

typedef _KeyPairImpl = ck.KeyPair;
typedef _SignerImpl = ck.Signer;
typedef _VerifierImpl = ck.Verifier;
typedef _SignatureImpl = ck.Signature;

final _signingAlgorithm = ck.algorithms.signing.ecdsa.sha256;
const _signatureLengthBytes = 64;
final _ecCurve = ck.curves.p256;
typedef _PublicKeyImpl = ck.EcPublicKey;
typedef _PrivateKeyImpl = ck.EcPrivateKey;

_KeyPairImpl _generateKeyPair() => _KeyPairImpl.generateEc(_ecCurve);

class PublicKey {
  final _PublicKeyImpl _key;
  PublicKey._(this._key);
  Verifier verifier() => Verifier(_key.createVerifier(_signingAlgorithm));
}

class PrivateKey {
  final _PrivateKeyImpl _key;
  PrivateKey._(this._key);
  Signer signer() => Signer(_key.createSigner(_signingAlgorithm));
}

class Signer {
  final _SignerImpl _signer;
  Signer(this._signer);

  // Output signature length in bytes.
  static const int length = _signatureLengthBytes;

  Uint8List sign(Uint8List input) {
    final s = _signer.sign(input).data;
    assert(s.length == length);
    return s;
  }

  void signInline(Uint8List data, int signatureStart) {
    assert(signatureStart + length == data.length);
    final s = sign(Uint8List.sublistView(data, 0, signatureStart));
    for (int i = 0; i < s.length; ++i) {
      data[i + signatureStart] = s[i];
    }
  }
}

class Verifier {
  final _VerifierImpl _verifier;
  Verifier(this._verifier);

  bool verify(Uint8List input, Uint8List signature) {
    assert(signature.length == Signer.length);
    return _verifier.verify(input, _SignatureImpl(signature));
  }

  bool verifyInline(Uint8List input) {
    assert(input.length >= Signer.length);
    final split = input.length - Signer.length;
    return verify(Uint8List.sublistView(input, 0, split),
        Uint8List.sublistView(input, split));
  }
}

class KeyPair {
  final PublicKey publicKey;
  final PrivateKey privateKey;

  KeyPair._(this.publicKey, this.privateKey);
  KeyPair._kp(_KeyPairImpl kp)
      : this._(PublicKey._(kp.publicKey as _PublicKeyImpl),
            PrivateKey._(kp.privateKey as _PrivateKeyImpl));

  static KeyPair generate() => KeyPair._kp(_generateKeyPair());
  static KeyPair fromJwk(String jwk) => KeyPair._kp(
      _KeyPairImpl.fromJwk(jsonDecode(jwk) as Map<String, dynamic>));

  String toJwk({bool includePrivateKey = false}) {
    // See https://tools.ietf.org/html/rfc7517 and rfc7518.
    final x = _bigIntToBase64(publicKey._key.xCoordinate);
    final y = _bigIntToBase64(publicKey._key.yCoordinate);
    final pub = '"x":"$x","y":"$y"';
    String priv = '';
    if (includePrivateKey) {
      final d = _bigIntToBase64(privateKey._key.eccPrivateKey);
      priv = ',"d":"$d"';
    }
    return '{"kty":"EC","alg":"ES256","use":"sig","crv":"P-256",$pub$priv}';
  }
}

String _bigIntToBase64(BigInt x) => base64UrlEncode(encodeBigInt(x));
