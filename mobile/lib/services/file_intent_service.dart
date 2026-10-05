import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FileIntentService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.mobile/file_intent',
  );

  static final ValueNotifier<String?> incomingFile = ValueNotifier<String?>(
    null,
  );

  static Future<String?> getInitialFile() async {
    try {
      return await _channel.invokeMethod<String>('getInitialFile');
    } catch (_) {
      return null;
    }
  }

  static void listen() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fileReceived') {
        final path = call.arguments as String?;

        if (path != null && path.trim().isNotEmpty) {
          incomingFile.value = path;
        }
      }
    });
  }

  static void clearIncomingFile() {
    incomingFile.value = null;
  }
}
