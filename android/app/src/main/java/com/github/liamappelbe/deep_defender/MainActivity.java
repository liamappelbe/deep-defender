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

package com.github.liamappelbe.deep_defender;

import android.os.Bundle;
import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;
import com.github.liamappelbe.deep_defender.TfEmbedder;
import java.io.IOException;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL =
      "com.github.liamappelbe.deep_defender/embedder";

  private static TfEmbedder embedder = null;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
  }

  @Override
  public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    new MethodChannel(
        flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
        .setMethodCallHandler(
          (call, result) -> {
            if (call.method.equals("runEmbedder")) {
              runEmbedder(call.arguments(), result);
            } else {
              result.notImplemented();
            }
          }
        );
  }

  private void runEmbedder(byte[] inputs, Result result) {
    if (embedder == null) {
      try {
        embedder = new TfEmbedder(this);
      } catch (Exception e) {
        throw new RuntimeException("Failed to create TfEmbedder", e);
      }
    }
    embedder.run(inputs, result);
  }
}
