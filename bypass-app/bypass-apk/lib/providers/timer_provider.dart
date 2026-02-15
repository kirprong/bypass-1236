import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/foreground_service.dart';
import '../utils/constants.dart';
import 'stats_provider.dart';

/// Провайдер таймера с автоматическими переходами и Dead Man's Switch
class TimerProvider with ChangeNotifier {
  Timer? _timer;
  Timer? _deadManSwitchTimer;
  int _currentPhaseIndex = 0;
  int _remainingSeconds = AppConstants.phase1Duration;
  bool _isRunning = false;
  bool _isInertiaMode = false;
  int _inertiaSeconds = 0;
  bool _isWaitingForChoice = false; // Ожидание выбора после фазы 3
  bool _hasPlayedWarning = false; // Флаг для предупреждения

  // Временные метки для точности
  int? _targetEndTimeMillis;
  int? _inertiaStartTimeMillis;

  final AudioService _audioService = AudioService();
  final NotificationService _notificationService = NotificationService();
  StatsProvider? _statsProvider;

  // Getters
  int get currentPhaseIndex => _currentPhaseIndex;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get isInertiaMode => _isInertiaMode;
  int get inertiaSeconds => _inertiaSeconds;
  bool get isWaitingForChoice => _isWaitingForChoice;

  Color get currentPhaseColor => _isInertiaMode
      ? AppConstants.inertiaColor
      : AppConstants.getPhaseColor(_currentPhaseIndex);

  String get currentPhaseName => _isInertiaMode
      ? 'INERTIA'
      : AppConstants.getPhaseName(_currentPhaseIndex);

  String get currentPhaseText => _isInertiaMode
      ? 'OVERDRIVE MODE'
      : _isWaitingForChoice
      ? 'ВЫБЕРИ: ИНЕРЦИЯ ИЛИ ОТДЫХ?'
      : AppConstants.getPhaseText(_currentPhaseIndex);

  // Проверка на премиум для показа кнопки инерции
  bool get isPremium => _statsProvider?.isPremium ?? false;

  void setStatsProvider(StatsProvider statsProvider) {
    _statsProvider = statsProvider;
  }

  /// Инициализация: восстановление состояния
  Future<void> initialize() async {
    // AudioService уже инициализирован в main()
    debugPrint('🔧 TimerProvider: Restoring state...');
    await _restoreState();
    debugPrint('✅ TimerProvider: State restored');
  }

  /// Сохранение состояния в SharedPreferences
  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'currentPhaseIndex': _currentPhaseIndex,
      'targetEndTimeMillis': _targetEndTimeMillis,
      'isRunning': _isRunning,
      'isInertiaMode': _isInertiaMode,
      'inertiaStartTimeMillis': _inertiaStartTimeMillis,
      'remainingSeconds': _remainingSeconds,
      'inertiaSeconds': _inertiaSeconds,
      'isWaitingForChoice': _isWaitingForChoice,
    };
    await prefs.setString('bypass_timer_state', jsonEncode(state));
  }

  /// Восстановление состояния
  Future<void> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('bypass_timer_state');
      if (savedStr != null) {
        final state = jsonDecode(savedStr);
        _currentPhaseIndex = state['currentPhaseIndex'] ?? 0;
        _targetEndTimeMillis = state['targetEndTimeMillis'];
        _isRunning = state['isRunning'] ?? false;
        _isInertiaMode = state['isInertiaMode'] ?? false;
        _inertiaStartTimeMillis = state['inertiaStartTimeMillis'];
        _remainingSeconds =
            state['remainingSeconds'] ??
            AppConstants.getPhaseDuration(_currentPhaseIndex);
        _inertiaSeconds = state['inertiaSeconds'] ?? 0;
        _isWaitingForChoice = state['isWaitingForChoice'] ?? false;

        if (_isRunning) {
          final now = DateTime.now().millisecondsSinceEpoch;

          if (_isInertiaMode && _inertiaStartTimeMillis != null) {
            _inertiaSeconds = ((now - _inertiaStartTimeMillis!) / 1000).floor();
            _startTimerLoop();
          } else if (_targetEndTimeMillis != null) {
            final remaining = ((_targetEndTimeMillis! - now) / 1000).floor();
            if (remaining > 0) {
              _remainingSeconds = remaining;
              _startTimerLoop();
            } else {
              _remainingSeconds = 0;
              _isRunning = false;
              _onPhaseComplete();
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error restoring timer state: $e');
    }
  }

  /// Запуск цикла таймера
  void _startTimerLoop() {
    _timer?.cancel();
    WakelockPlus.enable();
    _hasPlayedWarning = false; // Сброс флага предупреждения
    
    // Показываем уведомление при старте таймера
    _updateNotification();

    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;

      if (_isInertiaMode) {
        if (_inertiaStartTimeMillis != null) {
          _inertiaSeconds = ((now - _inertiaStartTimeMillis!) / 1000).floor();
        }
      } else {
        if (_targetEndTimeMillis != null) {
          final remaining = ((_targetEndTimeMillis! - now) / 1000).floor();

          // Предупреждение за 6 секунд до конца (кроме фазы 2 STRIKE)
          if (remaining == AppConstants.warningBeforeEndSeconds &&
              !_hasPlayedWarning &&
              _currentPhaseIndex != 2) {
            _audioService.playWarningSound(); // finish.mp3
            _hasPlayedWarning = true;
            debugPrint(
              'TIMER: Предупреждение за 6 секунд до конца фазы $_currentPhaseIndex',
            );
          }

          if (remaining <= 0) {
            _remainingSeconds = 0;
            _onPhaseComplete();
          } else {
            _remainingSeconds = remaining;
          }
        }
      }
      notifyListeners();
      _saveState(); // Периодически сохраняем
      
      // Обновляем уведомление каждую секунду
      if ((DateTime.now().millisecondsSinceEpoch ~/ 1000) % 1 == 0) {
        _updateNotification();
      }
    });
  }
  
  /// Обновление уведомления с текущим статусом
  void _updateNotification() {
    if (!_isRunning) return;
    
    String title;
    String body;
    String progress;
    
    if (_isInertiaMode) {
      title = '⚡ OVERDRIVE MODE';
      body = 'Режим инерции активен';
      progress = 'Прошло: ${formatTime(_inertiaSeconds)}';
    } else {
      title = '${AppConstants.getPhaseName(_currentPhaseIndex)} - ${formatTime(_remainingSeconds)}';
      body = currentPhaseText;
      int totalSeconds = AppConstants.getPhaseDuration(_currentPhaseIndex);
      int elapsed = totalSeconds - _remainingSeconds;
      progress = 'Прогресс: $elapsed/$totalSeconds сек';
    }
    
    _notificationService.updateNotification(
      title: title,
      body: body,
      progress: progress,
    );
  }

  /// Старт/Стоп (Toggle)
  void toggle() {
    // Звук играет ВСЕГДА при нажатии (и на старт, и на паузу)
    _audioService.playStartSound();

    if (_isRunning) {
      _pause();
    } else {
      _start();
    }
  }

  void _start() {
    _isRunning = true;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (_isInertiaMode) {
      _inertiaStartTimeMillis = now - (_inertiaSeconds * 1000);
    } else {
      _targetEndTimeMillis = now + (_remainingSeconds * 1000);
    }
    
    // Запускаем foreground service для фоновой работы
    ForegroundService.start(
      title: 'BYPASS-1236 Таймер',
      body: 'Фаза: ${AppConstants.getPhaseName(_currentPhaseIndex)}',
    );

    _startTimerLoop();
    notifyListeners();
    _saveState();
  }

  void _pause() {
    _isRunning = false;
    _timer?.cancel();
    _targetEndTimeMillis = null;
    _inertiaStartTimeMillis = null;
    WakelockPlus.disable();
    
    // Останавливаем foreground service
    ForegroundService.stop();
    
    // Скрываем уведомление при паузе
    _notificationService.hideNotification();
    
    notifyListeners();
    _saveState();
  }

  /// Сброс
  void reset() {
    _timer?.cancel();
    _deadManSwitchTimer?.cancel();
    _isRunning = false;
    _currentPhaseIndex = 0;
    _remainingSeconds = AppConstants.phase1Duration;
    _isInertiaMode = false;
    _inertiaSeconds = 0;
    _targetEndTimeMillis = null;
    _inertiaStartTimeMillis = null;
    _isWaitingForChoice = false;
    _hasPlayedWarning = false;
    WakelockPlus.disable();
    
    // Останавливаем foreground service
    ForegroundService.stop();
    
    // Скрываем уведомление при сбросе
    _notificationService.hideNotification();
    
    notifyListeners();
    _saveState();
  }

  /// Активация инерции (только для премиум пользователей)
  void activateInertia() {
    if (_currentPhaseIndex == 2 && !_isInertiaMode && isPremium) {
      _stopDeadManSwitch(); // Останавливаем Dead Man's Switch
      _isWaitingForChoice = false;
      _isInertiaMode = true;
      _inertiaSeconds = 0;
      _inertiaStartTimeMillis = DateTime.now().millisecondsSinceEpoch;

      if (!_isRunning) {
        _isRunning = true;
        _startTimerLoop();
      }

      _audioService.playInertiaSound();
      
      // Уведомление об активации инерции
      _notificationService.showSimpleNotification(
        title: '⚡ OVERDRIVE активирован!',
        body: 'Режим инерции запущен',
      );
      
      notifyListeners();
      _saveState();
    }
  }

  /// Остановка инерции и переход к отдыху
  void stopInertia() {
    if (!_isInertiaMode) return;

    if (_statsProvider != null) {
      _statsProvider!.addInertiaTime(_inertiaSeconds);
      _statsProvider!.addStrike(); // Считаем за завершенный страйк
    }

    _isInertiaMode = false;
    _currentPhaseIndex = 3; // RECOVERY

    // Формула из оригинала: 1 минута за каждые 10 минут переработки
    int extraRestSeconds = (_inertiaSeconds / 600).floor() * 60;
    _remainingSeconds = AppConstants.phase4Duration + extraRestSeconds;

    final now = DateTime.now().millisecondsSinceEpoch;
    _targetEndTimeMillis = now + (_remainingSeconds * 1000);
    _inertiaStartTimeMillis = null;
    _inertiaSeconds = 0;
    _hasPlayedWarning = false;

    _audioService.playPhaseSound(_currentPhaseIndex);
    
    // Уведомление о дополнительном отдыхе
    if (extraRestSeconds > 0) {
      _notificationService.showSimpleNotification(
        title: '🎁 Бонусный отдых!',
        body: 'Получено +${extraRestSeconds ~/ 60} мин отдыха за инерцию',
      );
    }
    
    notifyListeners();
    _saveState();
  }

  /// Переход к отдыху (вручную после фазы 3)
  void startRecovery() {
    if (_currentPhaseIndex != 2 || _isInertiaMode) return;

    _stopDeadManSwitch(); // Останавливаем Dead Man's Switch
    _isWaitingForChoice = false;

    if (_statsProvider != null) {
      _statsProvider!.addStrike();
    }

    _currentPhaseIndex = 3; // RECOVERY
    _remainingSeconds = AppConstants.phase4Duration;

    final now = DateTime.now().millisecondsSinceEpoch;
    _targetEndTimeMillis = now + (_remainingSeconds * 1000);
    _hasPlayedWarning = false;

    if (!_isRunning) {
      _isRunning = true;
    }

    _audioService.playPhaseSound(_currentPhaseIndex);
    _startTimerLoop();
    notifyListeners();
    _saveState();
  }

  /// Завершение фазы (АВТОМАТИЧЕСКИЕ ПЕРЕХОДЫ 1→2→3)
  void _onPhaseComplete() {
    // АВТОМАТИЧЕСКИЕ ПЕРЕХОДЫ: 1 → 2 → 3
    if (_currentPhaseIndex < 2) {
      // Фазы 0, 1 → автоматически переходят к следующей
      _currentPhaseIndex++;
      _remainingSeconds = AppConstants.getPhaseDuration(_currentPhaseIndex);
      _hasPlayedWarning = false;

      final now = DateTime.now().millisecondsSinceEpoch;
      _targetEndTimeMillis = now + (_remainingSeconds * 1000);

      // Звуки при переходах
      _audioService.playPhaseSound(_currentPhaseIndex);
      
      // Показываем уведомление о смене фазы
      _notificationService.showSimpleNotification(
        title: '🎯 Новая фаза: ${AppConstants.getPhaseName(_currentPhaseIndex)}',
        body: currentPhaseText,
      );

      debugPrint(
        'TIMER: Автопереход на фазу $_currentPhaseIndex (${AppConstants.getPhaseName(_currentPhaseIndex)})',
      );

      notifyListeners();
      _saveState();
      return;
    }

    // Фаза 2 (THE STRIKE) завершена → ОСТАНАВЛИВАЕМ и ждём выбора
    if (_currentPhaseIndex == 2) {
      _isRunning = false;
      _timer?.cancel();
      _targetEndTimeMillis = null;
      _isWaitingForChoice = true;

      // НЕТ звука окончания фазы 2 (по описанию)
      
      // Уведомление о выборе
      _notificationService.showSimpleNotification(
        title: '⚡ Выбор режима',
        body: 'Инерция или отдых? У вас 30 секунд',
      );

      // Запускаем Dead Man's Switch (30 секунд)
      _startDeadManSwitch();

      debugPrint('TIMER: Фаза 2 завершена. Ожидание выбора (ИНЕРЦИЯ/ОТДЫХ)');

      notifyListeners();
      _saveState();
      return;
    }

    // Фаза 3 (RECOVERY) завершена → сброс
    if (_currentPhaseIndex == 3) {
      _audioService.playCycleEndSound(); // scan.mp3 - конец отдыха
      
      // Уведомление о завершении цикла
      _notificationService.showSimpleNotification(
        title: '✅ Цикл завершён!',
        body: 'BYPASS-1236 цикл успешно пройден',
      );
      
      reset();
      debugPrint('TIMER: Цикл завершён. Сброс.');
      return;
    }
  }

  /// Dead Man's Switch - если нет выбора 30 секунд
  void _startDeadManSwitch() {
    _stopDeadManSwitch(); // Останавливаем предыдущий если был

    int secondsLeft = AppConstants.deadManSwitchTimeout;

    _deadManSwitchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsLeft--;

      // Повторяющийся beep каждую секунду
      if (secondsLeft <= AppConstants.deadManSwitchTimeout) {
        _audioService.playDeadManSwitchSound(); // beep.mp3
      }

      debugPrint('Dead Man\'s Switch: $secondsLeft секунд до авто-отдыха');

      if (secondsLeft <= 0) {
        // Автоматически переходим к отдыху
        debugPrint('Dead Man\'s Switch сработал! Автоматический переход к ОТДЫХУ');
        _stopDeadManSwitch();
        startRecovery();
      }
    });
  }

  void _stopDeadManSwitch() {
    _deadManSwitchTimer?.cancel();
    _deadManSwitchTimer = null;
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get progress {
    if (_isInertiaMode) return 1.0;
    int total = AppConstants.getPhaseDuration(_currentPhaseIndex);
    if (total == 0) return 0.0;
    return 1.0 - (_remainingSeconds / total).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _deadManSwitchTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }
}
