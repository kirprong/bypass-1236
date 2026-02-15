import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Сервис для управления уведомлениями
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  static const String _channelId = 'bypass_1236_audio_channel';
  static const String _channelName = 'BYPASS-1236 Timer';
  static const int _notificationId = 1236;

  /// Инициализация сервиса уведомлений
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔔 Initializing NotificationService...');

      // Запрос разрешений для Android 13+
      if (await _requestNotificationPermission()) {
        // Настройки для Android
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        
        // Настройки для iOS (на будущее)
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

        const initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

        await _notifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTap,
        );

        // Создаем канал уведомлений для Android
        await _createNotificationChannel();

        _isInitialized = true;
        debugPrint('✅ NotificationService initialized successfully');
      } else {
        debugPrint('⚠️ Notification permission denied');
        _isInitialized = false;
      }
    } catch (e) {
      debugPrint('⚠️ NotificationService initialization failed: $e');
      _isInitialized = false;
    }
  }

  /// Запрос разрешения на уведомления (Android 13+)
  Future<bool> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();
      debugPrint('📱 Notification permission status: $status');
      return status.isGranted;
    } catch (e) {
      debugPrint('⚠️ Error requesting notification permission: $e');
      return false;
    }
  }

  /// Создание канала уведомлений (Android 8.0+)
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Уведомления о фазах таймера BYPASS-1236',
      importance: Importance.high,
      playSound: false, // Звуки управляются через just_audio
      enableVibration: false,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    
    debugPrint('📢 Notification channel created: $_channelId');
  }

  /// Обработка нажатия на уведомление
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // Здесь можно добавить навигацию или действия
  }

  /// Показать постоянное уведомление (для фонового режима)
  Future<void> showOngoingNotification({
    required String title,
    required String body,
    String? progress,
  }) async {
    if (!_isInitialized) {
      debugPrint('⚠️ NotificationService not initialized');
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Таймер активен',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true, // Постоянное уведомление
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        showWhen: true,
        usesChronometer: false,
        category: AndroidNotificationCategory.progress,
        visibility: NotificationVisibility.public,
        styleInformation: progress != null
            ? BigTextStyleInformation(
                '$body\n$progress',
                contentTitle: title,
                summaryText: 'BYPASS-1236',
              )
            : BigTextStyleInformation(
                body,
                contentTitle: title,
                summaryText: 'BYPASS-1236',
              ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _notificationId,
        title,
        body,
        details,
      );

      debugPrint('🔔 Ongoing notification shown: $title - $body');
    } catch (e) {
      debugPrint('⚠️ Error showing notification: $e');
    }
  }

  /// Обновить уведомление (для смены фазы/прогресса)
  Future<void> updateNotification({
    required String title,
    required String body,
    String? progress,
  }) async {
    await showOngoingNotification(
      title: title,
      body: body,
      progress: progress,
    );
  }

  /// Скрыть уведомление
  Future<void> hideNotification() async {
    try {
      await _notifications.cancel(_notificationId);
      debugPrint('🔔 Notification hidden');
    } catch (e) {
      debugPrint('⚠️ Error hiding notification: $e');
    }
  }

  /// Показать обычное уведомление (не постоянное)
  Future<void> showSimpleNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('⚠️ Error showing simple notification: $e');
    }
  }

  /// Очистить все уведомления
  Future<void> cancelAll() async {
    try {
      await _notifications.cancelAll();
      debugPrint('🔔 All notifications cancelled');
    } catch (e) {
      debugPrint('⚠️ Error cancelling notifications: $e');
    }
  }
}
