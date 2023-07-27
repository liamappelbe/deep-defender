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

final _signingAlgorithm = ck.algorithms.signing.rsa.sha256;
const _signatureLength = 256;
typedef _PublicKeyImpl = ck.RsaPublicKey;
typedef _PrivateKeyImpl = ck.RsaPrivateKey;

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
  final ck.Signer _signer;
  Signer(this._signer);

  // Output signature length in bytes.
  static const int length = _signatureLength;

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
  final ck.Verifier _verifier;
  Verifier(this._verifier);

  bool verify(Uint8List input, Uint8List signature) {
    assert(signature.length == Signer.length);
    return _verifier.verify(input, ck.Signature(signature));
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
  KeyPair._kp(ck.KeyPair kp)
      : this._(PublicKey._(kp.publicKey as _PublicKeyImpl),
            PrivateKey._(kp.privateKey as _PrivateKeyImpl));

  static KeyPair generate() => KeyPair._kp(ck.KeyPair.generateRsa());
  static KeyPair fromJwk(String jwk) =>
      KeyPair._kp(ck.KeyPair.fromJwk(jsonDecode(jwk) as Map<String, dynamic>));

  String toJwk({bool includePrivateKey = false}) {
    // See https://tools.ietf.org/html/rfc7517 and rfc7518.
    final pub = publicKey._key;
    final n = _base64UrlUint(pub.modulus);
    final e = _base64UrlUint(pub.exponent);
    String pk = "";
    if (includePrivateKey) {
      final priv = privateKey._key;
      assert(priv.modulus == pub.modulus);
      final d = _base64UrlUint(priv.privateExponent);
      final p = _base64UrlUint(priv.firstPrimeFactor);
      final q = _base64UrlUint(priv.secondPrimeFactor);
      pk = ',"d":"$d","p":"$p","q":"$q"';
    }
    return '{"kty":"RSA","alg":"RS256","use":"sig","n":"$n","e":"$e"$pk}';
  }
}

String _base64UrlUint(BigInt x) => base64UrlEncode(encodeBigInt(x));
