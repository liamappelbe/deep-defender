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

import 'package:crypto_keys/crypto_keys.dart';
import 'package:flutter/foundation.dart';

KeyPair generateKeyPair(Null) {
  return KeyPair.generateRsa();
}

class KeyStore {
  Future<KeyPair> _keyPair;
  KeyStore() {
    // TODO: Store the key pair. Build a UI to share the public key.
    _keyPair = compute(generateKeyPair, null);
  }

  Future<PrivateKey> privateKey() { return _keyPair.then((k) => k.privateKey); }
  Future<PublicKey> publicKey() { return _keyPair.then((k) => k.publicKey); }
}
