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

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crypto.dart';

/// Provides an RSA public/private key pair.
///
/// If there's a key pair available in SharedPreferences it uses that. Otherwise
/// it generates a new key pair and stores it.
class KeyStore {
  final Future<KeyPair> _keyPair;
  KeyStore() : _keyPair = _getKeyPair();

  Future<PrivateKey> privateKey() async => (await _keyPair).privateKey;
  Future<PublicKey> publicKey() async => (await _keyPair).publicKey;
  Future<String> publicKeyAsJwk() async => (await _keyPair).toJwk();

  static Future<KeyPair> _getKeyPair() async {
    const kName = "key_pair";
    final sp = await SharedPreferences.getInstance();
    final storedKey = sp.getString(kName);
    if (storedKey != null) return KeyPair.fromJwk(storedKey);
    final kp = await compute((_) => KeyPair.generate(), null);
    sp.setString(kName, kp.toJwk(includePrivateKey: true));
    return kp;
  }
}
