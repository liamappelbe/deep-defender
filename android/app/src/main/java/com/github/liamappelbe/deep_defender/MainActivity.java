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
