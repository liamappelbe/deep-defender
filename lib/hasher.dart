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

// Receives a stream of timestamped audio data, in fixed sized chunks, and
// yields a list of robust audio hashes for that chunk.
//
// As soon as the chunk callback is finished, the hash buffer that was sent will
// be overwritten, so the callback should copy any data it needs.
class Hasher {
  void onData(int timeMs, Uint16List chunk){
    // (chunk[i].toDouble() * 2.0 / 0xFFFF) - 1.0
  }
}
