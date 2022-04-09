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

// Wrapper utils around pointycastle.
// TODO: Consider switching back to package:crypto_keys when versioning issues
// are fixed.

class RsaPublicKey {
  final BigInt modulus;
  final BigInt exponent;

  RsaPublicKey({this.modulus, this.exponent});
}

class RsaPrivateKey {
  final BigInt modulus;
  final BigInt privateExponent;
  final BigInt firstPrimeFactor;
  final BigInt secondPrimeFactor;

  RsaPrivateKey(
      {this.privateExponent,
      this.firstPrimeFactor,
      this.secondPrimeFactor,
      this.modulus});
}

class KeyPair {
  final RsaPublicKey publicKey;
  final RsaPrivateKey privateKey;

  KeyPair({this.publicKey, this.privateKey});

  factory RSAKeyPair.fromJwk(Map<String, dynamic> jwk) {
    if (jwk['kty'] == 'RSA') {
        return RSAKeyPair(
            publicKey: jwk.containsKey('n') && jwk.containsKey('e')
                ? RsaPublicKey(
                    modulus: _base64ToInt(jwk['n']),
                    exponent: _base64ToInt(jwk['e']),
                  )
                : null,
            privateKey: jwk.containsKey('n') &&
                    jwk.containsKey('d') &&
                    jwk.containsKey('p') &&
                    jwk.containsKey('q')
                ? RsaPrivateKey(
                    modulus: _base64ToInt(jwk['n']),
                    privateExponent: _base64ToInt(jwk['d']),
                    firstPrimeFactor: _base64ToInt(jwk['p']),
                    secondPrimeFactor: _base64ToInt(jwk['q']),
                  )
                : null);
    }
    throw ArgumentError('Unknown key type ${jwk['kty']}');
  }
}
