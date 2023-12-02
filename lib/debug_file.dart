// Copyright 2023 The Deep Defender Authors
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
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:wav/wav.dart';
import 'const.dart';

// Saves an audio chunks as wav file, with its SAF code as the filename. This is
// just for debugging.
class DebugFile {
  static const _enabled = false;

  static int _debugIndex = 0;
  static Future<void> save(Float64List audio, Uint8List safCode) async {
    if (!DebugFile._enabled) return;
    ++_debugIndex;
    final audioCopy = audio.sublist(0); // Make sure to copy before any awaits.
    final dir = await directory();
    final filename = '${_debugIndex}_${base64Url.encode(safCode)}.wav';
    final path = '$dir/$filename';
    print(
        "C:/Users/tiusic/AppData/Local/Android/Sdk/platform-tools/adb.exe pull $path $filename");
    await Wav([audioCopy], kSampleRate).writeFile(path);
  }

  static String? _dir;
  static Future<String> directory() async => _dir ??= await _directory();
  static Future<String> _directory() async {
    final dir = (await getExternalStorageDirectories(
      type: StorageDirectory.downloads,
    ))!
        .first;
    return (await dir.create(recursive: true)).path;
  }
}
