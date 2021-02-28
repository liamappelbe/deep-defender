// Copyright 2021 The Deep Defender Authors
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
import 'package:crypto_keys/crypto_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/src/utils.dart' show encodeBigInt, decodeBigInt;
import 'package:shared_preferences/shared_preferences.dart';

Future<KeyPair> _generateKeyPair(Null) async {
  return KeyPair.generateRsa();
}

class KeyStore {
  final Future<KeyPair> _keyPair;
  KeyStore() : _keyPair = _getKeyPair();

  Future<PrivateKey> privateKey() { return _keyPair.then((k) => k.privateKey); }
  Future<PublicKey> publicKey() { return _keyPair.then((k) => k.publicKey); }
  Future<String> publicKeyAsJwk() { return publicKey().then(_toJwk); }

  static Future<KeyPair> _getKeyPair() async {
    const kName = "key_pair";
    final sp = await SharedPreferences.getInstance();
    if (sp.containsKey(kName)) return _fromJwk(sp.getString(kName));
    final kp = await compute(_generateKeyPair, null);
    sp.setString(kName, _toJwk(kp.publicKey, kp.privateKey));
    return kp;
  }

  static String _base64UrlUint(BigInt x) => base64UrlEncode(encodeBigInt(x));

  static String _toJwk(PublicKey pub, [PrivateKey priv = null]) {
    // See https://tools.ietf.org/html/rfc7517 and rfc7518.
    final rsaPub = pub as RsaPublicKey;
    final n = _base64UrlUint(rsaPub.modulus);
    final e = _base64UrlUint(rsaPub.exponent);
    var pk = "";
    if (priv != null) {
      final rsaPriv = priv as RsaPrivateKey;
      assert(rsaPriv.modulus == rsaPub.modulus);
      final d = _base64UrlUint(rsaPriv.privateExponent);
      final p = _base64UrlUint(rsaPriv.firstPrimeFactor);
      final q = _base64UrlUint(rsaPriv.secondPrimeFactor);
      pk = ',"d":"$d","p":"$p","q":"$q"';
    }
    return '{"kty":"RSA","alg":"RS256","use":"sig","n":"$n","e":"$e"$pk}';
  }

  static KeyPair _fromJwk(String jwk) {
    return KeyPair.fromJwk(jsonDecode(jwk) as Map<String, dynamic>);
  }
}
