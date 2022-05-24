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

import 'package:test/test.dart';
import 'package:crypto_keys/crypto_keys.dart';
import 'package:deep_defender/key_store.dart';

void testJwk(RsaPublicKey pub, RsaPrivateKey? priv, String expectedJwk) {
  final jwk = KeyStore.toJwk(pub, priv);
  expect(jwk, equals(expectedJwk));
  final kp = KeyStore.fromJwk(jwk);
  expect(kp.publicKey, equals(pub));
  expect(kp.privateKey, equals(priv));
}

main() {
  test('JWK', () {
    testJwk(
        RsaPublicKey(
          modulus:
              BigInt.parse("9283450293849383948573984759872394873945874958"),
          exponent:
              BigInt.parse("198347593284574598678235692836579185693487523"),
        ),
        RsaPrivateKey(
          privateExponent:
              BigInt.parse("63498570293485908425760982730598034986"),
          firstPrimeFactor:
              BigInt.parse("7237589720986702937598457698479823745"),
          secondPrimeFactor:
              BigInt.parse("398735098203983587687298375018104938"),
          modulus:
              BigInt.parse("9283450293849383948573984759872394873945874958"),
        ),
        '{"kty":"RSA","alg":"RS256","use":"sig",' +
            '"n":"AaBIyHD_gFELTDnQDH0zFULmYg4=",' +
            '"e":"COTrMEJj6Zow01Uxp0wb8u7xow==",' +
            '"d":"L8VhOkV3KPfceTWziwSuKg==",' +
            '"p":"BXHouUM9RxB02V51JMDbgQ==",' +
            '"q":"TMsofPrDRiZXK87vVEhq"}');

    testJwk(
        RsaPublicKey(
          modulus:
              BigInt.parse("4938759348709837456098928374987540968309283400"),
          exponent:
              BigInt.parse("294857049568309873458098174059801364571329429"),
        ),
        null,
        '{"kty":"RSA","alg":"RS256","use":"sig",' +
            '"n":"AN12LUlERJFAMt5sRJrDTvtQWkg=",' +
            '"e":"DTjK_Xu6Wsyi6xaU3iA1pZOTlQ=="}');
  });
}
