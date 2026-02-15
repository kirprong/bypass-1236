import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Сервис для управления foreground service на Android
class ForegroundService {
  static const platform = MethodChannel('com.bypass1236.bypass_1236/foreground_service');
  
  /// Запуск foreground service
  static Future<void> start({
    required String title,
    required String body,
  }) async {
    try {
      await platform.invokeMethod('startForegroundService', {
        'title': title,
        'body': body,
      });
      debugPrint('✅ Foreground service started: $title');
    } on PlatformException catch (e) {
      debugPrint('⚠️ Failed to start foreground service: ${e.message}');
    }
  }
  
  /// Остановка foreground service
  static Future<void> stop() async {
    try {
      await platform.invokeMethod('stopForegroundService');
      debugPrint('✅ Foreground service stopped');
    } on PlatformException catch (e) {
      debugPrint('⚠️ Failed to stop foreground service: ${e.message}');
    }
  }
}
