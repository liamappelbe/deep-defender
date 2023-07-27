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
    '{"kty":"RSA","alg":"RS256","use":"sig","n":"AIWJIVrOZGEwFAGU1z'
    'AmEJkFXVntpASFH1cjSxT9-X3WpeKZ8txr6D_l4NIA3Nih5f7OAADG8neEXsah'
    'bO5lmEL7sSCNHUUtkbIqUoe5IQwPsjW0gd02IUybHKy-2u503QH5puB0NVLsmf'
    'UuDRqJO7sca6QZ4msR2ZbTj7RERnGh7kH5TNf5eaMSK7O1PqMqQm556lahZMaX'
    'g4MnsTQMWosLzL3YuPKKH7wiubHek6aZoCbCHWQ1OZCETAOJUnYNcDu38hQQ2G'
    'zexjBMVKu-YEyaQUibh6ZSKoffxdrr8YQ3wUT4l_Ap0FcVl1VJfSKtBkWHt47B'
    'q9VeJ6TmzETuhKk=","e":"AQAB","d":"Ij_WvzyagFbder5bJu1MaoL2u375'
    'B3PBYw8ZTcwKNp1cNK95m9FNYz4pmJNCEYoMvHrHg2uDeuYHjPiQQODr2ZpGhu'
    'vKqxiR-tliC4-PC1HnSmD-wecFSWmrRB87ddeha8VFaOJFXvxyTHFASSMTn90d'
    'Opys9vtADLA8dmbgjnoz7FahhzWnY5Yuyjc2F_oSdKW568mwwM3x7ze9JST6Da'
    'enzifbMXne-jXYYf5ybrjj1oosW7UY1T3fQar5LKAJym1M-rFoFcCJPLMYoTAw'
    'lN4_P180PfCWZByJUldqpAg2HVkU1f9Ksk5dQ3EPovccoQOwMiPItHeznZ7omb'
    'AHAQ==","p":"AMOWIyTpYmZENkszapxVN_xkMTssqlz0-CuEbp64JwvDMh-QM'
    'vDlzC8xh4viD5w53Ysl22fMPnc4kHnkVQ5BE2jt7-JgQOaDpvDfYx4ELJ5Kxm3'
    'jWkln96XNtL-ryFM_Ij9AmiAiMl7LfekGcnIkFKDdxy8BctpXMx2eRu-OqqDh"'
    ',"q":"AK7IXndISqxWG7MruD04dFSmY1P1kI4nkc7sUJ6pfgfQlNxRXe-_yLsR'
    'YOpYeCJXEqP12_0w_MRJr7xCOsG8-g166Am7e3fHnIS_AMy19uNcHPVJtlY2mq'
    'lzgJRPz7OZpJNe5IyvAI5ChLIaaeOIiWK1KTiFcxVK7a0t5PzK2LTJ"}';

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
        '{"kty":"RSA","alg":"RS256","use":"sig","n":"AIWJIVrOZGEwFAGU1z'
        'AmEJkFXVntpASFH1cjSxT9-X3WpeKZ8txr6D_l4NIA3Nih5f7OAADG8neEXsah'
        'bO5lmEL7sSCNHUUtkbIqUoe5IQwPsjW0gd02IUybHKy-2u503QH5puB0NVLsmf'
        'UuDRqJO7sca6QZ4msR2ZbTj7RERnGh7kH5TNf5eaMSK7O1PqMqQm556lahZMaX'
        'g4MnsTQMWosLzL3YuPKKH7wiubHek6aZoCbCHWQ1OZCETAOJUnYNcDu38hQQ2G'
        'zexjBMVKu-YEyaQUibh6ZSKoffxdrr8YQ3wUT4l_Ap0FcVl1VJfSKtBkWHt47B'
        'q9VeJ6TmzETuhKk=","e":"AQAB"}');
  });
}
