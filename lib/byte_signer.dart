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

import 'dart:typed_data';
import 'package:crypto_keys/crypto_keys.dart';

// Thin wrapper around crpyto_keys Signer implementing RSA/SHA-256 signing.
class ByteSigner {
  static const int kSize = 256;

  final Signer _signer;
  ByteSigner(PrivateKey key)
      : _signer = key.createSigner(algorithms.signing.rsa.sha256) {}

  int size() { return kSize; }

  void fill(ByteData data, int signatureStart) {
    assert(signatureStart + kSize == data.lengthInBytes);
    final s = _signer.sign(Uint8List.view(data.buffer, 0, signatureStart)).data;
    assert(s.length == kSize);
    for (var i = 0; i < s.length; ++i) {
      data.setUint8(i + signatureStart, s[i]);
    }
  }
}
