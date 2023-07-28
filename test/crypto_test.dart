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
import 'package:deep_defender/crypto.dart';
import 'package:deep_defender/key_store.dart';
import 'package:test/test.dart';

const kTestKey =
    '{"kty":"EC","alg":"ES256","use":"sig","crv":"P-256","x":"AJXCXc4kQBQm'
    'bMLi2MpwrklFJtQC01LYCwwF-cdodv_z","y":"cyV700E19jQVyGf9S0vdsfpjj-hkhx'
    'OhVMlzkB-9AJc=","d":"AK86ItzaEXq05gA5LhLSnAmP6aPLrSotlSqq67TvgvIx"}';

main() {
  test('Byte signer produces correct signature', () {
    final keyPair = KeyPair.fromJwk(kTestKey);
    final signer = keyPair.privateKey.signer();
    final input = utf8.encode("Hello World!");

    final bytes = Uint8List(input.length + Signer.length);
    for (int i = 0; i < input.length; ++i) {
      bytes[i] = input[i];
    }

    signer.signInline(bytes, input.length);

    expect(keyPair.publicKey.verifier().verifyInline(bytes), isTrue);
  });

  test('JWK', () {
    final keyPair = KeyPair.fromJwk(kTestKey);
    expect(keyPair.toJwk(includePrivateKey: true), kTestKey);
    expect(
        keyPair.toJwk(),
        '{"kty":"EC","alg":"ES256","use":"sig","crv":"P-256","x":"AJXCXc4kQBQm'
        'bMLi2MpwrklFJtQC01LYCwwF-cdodv_z","y":"cyV700E19jQVyGf9S0vdsfpjj-hkhx'
        'OhVMlzkB-9AJc="}');
  });
}
