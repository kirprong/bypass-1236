import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/foreground_service.dart';
import '../utils/constants.dart';
import 'stats_provider.dart';
import 'hit_list_provider.dart';

/// Провайдер таймера с автоматическими переходами и Dead Man's Switch
class TimerProvider with ChangeNotifier {
  Timer? _timer;
  Timer? _deadManSwitchTimer;
  int _currentPhaseIndex = 0;
  int _remainingSeconds = AppConstants.phase1Duration;
  bool _isRunning = false;
  bool _isInertiaMode = false;
  int _inertiaSeconds = 0;
  bool _isWaitingForChoice = false;
  bool _hasPlayedWarning = false;
  bool _needsTargetConfirmation = false;
  double _timeWarpScale = AppConstants.timeWarpDefault; // Глобальный масштаб времени
  int _currentPhaseBaseSeconds =
      AppConstants.phase1Duration; // Немасштабированная база текущей фазы (для пересчёта)
  bool _phaseCompleted = false; // Guard от повторного триггера перехода фазы

  // Временные метки для точности
  int? _targetEndTimeMillis;
  int? _inertiaStartTimeMillis;

  // Поля устойчивости INERTIA после перезапуска (V1.2 / TASK-V1.1-005)
  int _inertiaCycleCount = 0; // Кол-во завершённых инерционных циклов
  int? _inertiaNextPulseAtMillis; // Абсолютное время следующего pulse (deadline)
  int? _inertiaPendingMaxFlowConfirmUntilMillis; // Окно подтверждения MAX FLOW (30с)
  bool _isInertiaConfirmShown = false; // Показан ли overlay MAX FLOW
  int? _lastInertiaPhaseTransitionId; // Guard одиночного входа в INERTIA (на STRIKE)
  int? _currentStrikeTransitionId; // Id завершения текущего STRIKE (для idempotent guard)

  // HIT-LIST (V1.3) — идемпотентность "один раз на окно" (yyyy-MM-dd|HH:mm)
  String? _hitListLastExecutedMinuteWindow;

  final AudioService _audioService = AudioService();
  final NotificationService _notificationService = NotificationService();
  StatsProvider? _statsProvider;
  HitListProvider? _hitListProvider;

  // Getters
  int get currentPhaseIndex => _currentPhaseIndex;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get isInertiaMode => _isInertiaMode;
  int get inertiaSeconds => _inertiaSeconds;
  bool get isWaitingForChoice => _isWaitingForChoice;
  bool get needsTargetConfirmation => _needsTargetConfirmation;
  double get timeWarpScale => _timeWarpScale;
  int get inertiaCycleCount => _inertiaCycleCount;
  int? get inertiaNextPulseAtMillis => _inertiaNextPulseAtMillis;
  int? get inertiaPendingMaxFlowConfirmUntilMillis =>
      _inertiaPendingMaxFlowConfirmUntilMillis;
  bool get isInertiaConfirmShown => _isInertiaConfirmShown;
  int? get lastInertiaPhaseTransitionId => _lastInertiaPhaseTransitionId;
  bool get showMaxFlowConfirm => _isInertiaConfirmShown;
  String? get hitListLastExecutedMinuteWindow =>
      _hitListLastExecutedMinuteWindow;
  int get maxFlowConfirmRemainingSeconds {
    if (_inertiaPendingMaxFlowConfirmUntilMillis == null) return 0;
    final remaining =
        ((_inertiaPendingMaxFlowConfirmUntilMillis! -
                    DateTime.now().millisecondsSinceEpoch) /
                1000)
            .ceil();
    return remaining < 0 ? 0 : remaining;
  }

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

  /// Связывает HitListScheduler с этим провайдером (двунаправленная связь).
  void setHitListProvider(HitListProvider hitListProvider) {
    _hitListProvider = hitListProvider;
    hitListProvider.setTimerProvider(this);
  }

  /// Установка глобального масштаба времени (Meta Time Scaling / Time Warp).
  /// - Валидирует/клэмпит значение (NaN/Infinity/вне диапазона → fallback 1.0).
  /// - При изменении ВО ВРЕМЯ RUNNING пересчитывает окончание текущей фазы,
  ///   сохраняя долю пройденного времени (без рестарта и без зависаний).
  ///   Guard _phaseCompleted гарантирует единичный авто-переход на завершение фазы.
  void setTimeWarpScale(double scale) {
    // Валидация: NaN/Infinity → fallback; иначе clamp в допустимый диапазон.
    if (scale.isNaN || scale.isInfinite) {
      scale = AppConstants.timeWarpDefault;
    } else {
      scale = scale.clamp(AppConstants.timeWarpMin, AppConstants.timeWarpMax);
    }

    final oldScale = _timeWarpScale;
    _timeWarpScale = scale;

    if (_isRunning && !_isInertiaMode && _targetEndTimeMillis != null) {
      // Пересчёт окончания текущей фазы без рестарта.
      // phaseStart восстанавливается из текущего targetEndTimeMillis и старого масштаба,
      // затем targetEndTimeMillis пересобирается под новый масштаб.
      final oldScaledMs = (_currentPhaseBaseSeconds * oldScale * 1000).round();
      final phaseStart = _targetEndTimeMillis! - oldScaledMs;
      final newScaledMs = (_currentPhaseBaseSeconds * scale * 1000).round();
      final now = DateTime.now().millisecondsSinceEpoch;
      _targetEndTimeMillis = phaseStart + newScaledMs;
      final newRemaining = ((_targetEndTimeMillis! - now) / 1000).ceil();
      _remainingSeconds = newRemaining < 0 ? 0 : newRemaining;
    } else if (_isInertiaMode && _inertiaNextPulseAtMillis != null) {
      // INERTIA: пересчитываем отложенный pulse пропорционально смене масштаба,
      // чтобы циклы ускорялись/замедлялись без скачков и без зависаний.
      final now = DateTime.now().millisecondsSinceEpoch;
      final remaining = _inertiaNextPulseAtMillis! - now;
      if (remaining > 0 && oldScale > 0) {
        final newRemaining = (remaining * scale / oldScale).round();
        _inertiaNextPulseAtMillis = now + newRemaining;
      }
    } else if (!_isRunning && !_isInertiaMode && !_needsTargetConfirmation) {
      // На паузе/ожидании: подстраиваем отображаемое оставшееся время под новый масштаб.
      _remainingSeconds = _getScaledPhaseDuration(_currentPhaseIndex, _currentPhaseBaseSeconds);
    }

    _saveState();
    notifyListeners();
  }

  int _getScaledPhaseDuration(int phaseIndex, [int? baseSeconds]) {
    final base = baseSeconds ?? AppConstants.getPhaseDuration(phaseIndex);
    final scaled = (base * _timeWarpScale).round();
    return scaled < 1 ? 1 : scaled;
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
      'needsTargetConfirmation': _needsTargetConfirmation,
      'timeWarpScale': _timeWarpScale,
      'currentPhaseBaseSeconds': _currentPhaseBaseSeconds,
      'inertiaCycleCount': _inertiaCycleCount,
      'inertiaNextPulseAtMillis': _inertiaNextPulseAtMillis,
      'inertiaPendingMaxFlowConfirmUntilMillis': _inertiaPendingMaxFlowConfirmUntilMillis,
      'isInertiaConfirmShown': _isInertiaConfirmShown,
      'lastInertiaPhaseTransitionId': _lastInertiaPhaseTransitionId,
      'hitListLastExecutedMinuteWindow': _hitListLastExecutedMinuteWindow,
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
        _needsTargetConfirmation = state['needsTargetConfirmation'] ?? false;
        _timeWarpScale = (state['timeWarpScale'] as num?)?.toDouble() ?? AppConstants.timeWarpDefault;
        if (_timeWarpScale.isNaN || _timeWarpScale.isInfinite) {
          _timeWarpScale = AppConstants.timeWarpDefault;
        }
        _currentPhaseBaseSeconds =
            state['currentPhaseBaseSeconds'] ?? AppConstants.getPhaseDuration(_currentPhaseIndex);
        if (_currentPhaseBaseSeconds < 1) {
          _currentPhaseBaseSeconds = AppConstants.getPhaseDuration(_currentPhaseIndex);
        }

        // Поля устойчивости INERTIA (backward compatibility: безопасные default)
        _inertiaCycleCount = state['inertiaCycleCount'] ?? 0;
        _inertiaNextPulseAtMillis = state['inertiaNextPulseAtMillis'];
        _inertiaPendingMaxFlowConfirmUntilMillis =
            state['inertiaPendingMaxFlowConfirmUntilMillis'];
        _isInertiaConfirmShown = state['isInertiaConfirmShown'] ?? false;
        _lastInertiaPhaseTransitionId = state['lastInertiaPhaseTransitionId'];
        _hitListLastExecutedMinuteWindow =
            state['hitListLastExecutedMinuteWindow'];

        if (_isRunning) {
          final now = DateTime.now().millisecondsSinceEpoch;

          if (_isInertiaMode && _inertiaStartTimeMillis != null) {
            _inertiaSeconds = ((now - _inertiaStartTimeMillis!) / 1000).floor();
            // Восстановление планировщика pulse (без дублей):
            // null → планируем заново; просроченный → перепланируем без всплеска.
            if (_inertiaNextPulseAtMillis == null) {
              _scheduleNextPulse();
            } else if (_inertiaNextPulseAtMillis! <= now) {
              _scheduleNextPulse();
            }
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
    _hasPlayedWarning = false;
    _phaseCompleted = false; // Сброс guard при старте цикла
    
    // Показываем уведомление при старте таймера
    _updateNotification();

    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;

      if (_isInertiaMode) {
        if (_inertiaStartTimeMillis != null) {
          _inertiaSeconds = ((now - _inertiaStartTimeMillis!) / 1000).floor();
        }
        // INERTIA pulse scheduler (V1.2): мягкий сигнал каждые 3–6 минут,
        // ровно один раз на окно (guard через перепланировку deadline).
        if (_inertiaNextPulseAtMillis != null && now >= _inertiaNextPulseAtMillis!) {
          _firePulse();
        }
        // Таймаут MAX FLOW confirm (30с без YES) → авто-выход в ОТДЫХ
        if (_isInertiaConfirmShown &&
            _inertiaPendingMaxFlowConfirmUntilMillis != null &&
            now >= _inertiaPendingMaxFlowConfirmUntilMillis!) {
          _autoExitMaxFlow();
        }
      } else {
        if (_targetEndTimeMillis != null) {
          final remaining = ((_targetEndTimeMillis! - now) / 1000).floor();

          // Предупреждение за 6 секунд до конца (кроме фазы 2 STRIKE)
          if (remaining == AppConstants.warningBeforeEndSeconds &&
              !_hasPlayedWarning &&
              _currentPhaseIndex != 2) {
            _audioService.playWarningSound();
            _hasPlayedWarning = true;
            debugPrint(
              'TIMER: Предупреждение за 6 секунд до конца фазы $_currentPhaseIndex',
            );
          }

          // Guard от повторного триггера перехода фазы
          if (remaining <= 0 && !_phaseCompleted) {
            _phaseCompleted = true;
            _remainingSeconds = 0;
            _onPhaseComplete();
          } else if (remaining > 0) {
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
      final cycle = _inertiaCycleCount > AppConstants.inertiaMaxFlowCycle
          ? AppConstants.inertiaMaxFlowCycle
          : _inertiaCycleCount;
      body = 'Режим инерции активен · Цикл $cycle/${AppConstants.inertiaMaxFlowCycle}';
      progress = 'Прошло: ${formatTime(_inertiaSeconds)}';
    } else {
      title = '${AppConstants.getPhaseName(_currentPhaseIndex)} - ${formatTime(_remainingSeconds)}';
      body = currentPhaseText;
      int totalSeconds = _getScaledPhaseDuration(_currentPhaseIndex);
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
      if (_currentPhaseIndex < 3) {
        _currentPhaseBaseSeconds = AppConstants.getPhaseDuration(_currentPhaseIndex);
      }
      _targetEndTimeMillis = now + (_remainingSeconds * 1000);
    }
    
    // Запускаем foreground service для фоновой работы
    ForegroundService.start(
      title: '1234 Таймер',
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
    _audioService.stopLoopingBeep(); // Останавливаем зацикленный beep при паузе
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
    _audioService.stopLoopingBeep();
    _isRunning = false;
    _currentPhaseIndex = 0;
    _remainingSeconds = _getScaledPhaseDuration(0, AppConstants.phase1Duration);
    _currentPhaseBaseSeconds = AppConstants.phase1Duration;
    _isInertiaMode = false;
    _inertiaSeconds = 0;
    _targetEndTimeMillis = null;
    _inertiaStartTimeMillis = null;
    _inertiaCycleCount = 0;
    _inertiaNextPulseAtMillis = null;
    _inertiaPendingMaxFlowConfirmUntilMillis = null;
    _isInertiaConfirmShown = false;
    _lastInertiaPhaseTransitionId = null;
    _currentStrikeTransitionId = null;
    _isWaitingForChoice = false;
    _needsTargetConfirmation = false;
    _hasPlayedWarning = false;
    _phaseCompleted = false;
    WakelockPlus.disable();
    
    ForegroundService.stop();
    _notificationService.hideNotification();
    
    notifyListeners();
    _saveState();
  }

  /// Авто-старт из HitListScheduler (V1.3 / TASK-V1.3-002).
  ///
  /// Контракт:
  /// - Guard: если таймер уже запущен (_isRunning) — НЕ инициировать авто-старт (no-op).
  /// - Идемпотентность "один раз на окно": windowKey = yyyy-MM-dd|HH:mm, вычисляемый
  ///   из [scheduledAtLocalMillis]; если окно уже выполнялось — no-op.
  /// - Переводит систему в состояние "фаза 0 → ожидание подтверждения цели":
  ///   currentPhaseIndex = 0, needsTargetConfirmation = true.
  /// - Побочные эффекты (звук/уведомления) best-effort: state machine не ломается
  ///   при ошибках audio/notification.
  ///
  /// Возвращает `true`, если авто-старт реально выполнен, иначе `false`.
  bool autoStartFromScheduler(
    String triggerKey,
    String slotId,
    int scheduledAtLocalMillis,
  ) {
    // Guard 1: активный цикл — не трогаем состояние (защита от конфликта).
    if (_isRunning) return false;

    // Идемпотентность "один раз на окно".
    final windowKey = AppConstants.hitListWindowKey(scheduledAtLocalMillis);
    if (_hitListLastExecutedMinuteWindow == windowKey) return false;

    // Полный сброс активности к безопасному idle-состоянию перед авто-стартом.
    _timer?.cancel();
    _deadManSwitchTimer?.cancel();
    _audioService.stopLoopingBeep();
    _safePlatform(() => WakelockPlus.disable());
    _isRunning = false;
    _isInertiaMode = false;
    _inertiaSeconds = 0;
    _isWaitingForChoice = false;
    _hasPlayedWarning = false;
    _phaseCompleted = false;
    _targetEndTimeMillis = null;
    _inertiaStartTimeMillis = null;
    _inertiaCycleCount = 0;
    _inertiaNextPulseAtMillis = null;
    _inertiaPendingMaxFlowConfirmUntilMillis = null;
    _isInertiaConfirmShown = false;
    _lastInertiaPhaseTransitionId = null;
    _currentStrikeTransitionId = null;

    // Переход в фазу 0 с ожиданием подтверждения цели ("ЦЕЛЬ НАЙДЕНА?").
    _currentPhaseIndex = 0;
    _currentPhaseBaseSeconds = AppConstants.phase1Duration;
    _remainingSeconds = _getScaledPhaseDuration(0, AppConstants.phase1Duration);
    _needsTargetConfirmation = true;

    // Фиксируем выполненное окно (idempotency).
    _hitListLastExecutedMinuteWindow = windowKey;
    _hitListProvider?.syncExecutedWindow(windowKey);

    // Best-effort побочные эффекты: независимо от ошибок audio/notification.
    // Обёртка глушит как синхронные, так и асинхронные исключения плагинов.
    _safePlatform(() => _audioService.playStartSound());
    _safePlatform(() => ForegroundService.stop());
    _safePlatform(() => _notificationService.hideNotification());

    notifyListeners();
    _saveState();
    return true;
  }

  /// Безопасный вызов платформенного метода: глушит синхронные и
  /// асинхронные исключения (например, MissingPluginException в тестах
  /// или при отсутствии сервиса на устройстве).
  void _safePlatform(Future<void> Function() fn) {
    try {
      fn().catchError((_) {});
    } catch (_) {}
  }

  /// Активация инерции (только для премиум пользователей)
  void activateInertia() {
    if (_currentPhaseIndex == 2 && !_isInertiaMode && isPremium) {
      _stopDeadManSwitch(); // Останавливаем Dead Man's Switch
      _audioService.stopLoopingBeep(); // Останавливаем зацикленный beep
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

  /// Автоматический вход в режим INERTIA (V1.2) сразу после завершения STRIKE.
  /// Не требует выбора пользователя. Аудио (ignite.mp3) — best-effort,
  /// переход происходит независимо от успеха воспроизведения.
  void _enterInertiaMode() {
    _stopDeadManSwitch();
    _audioService.stopLoopingBeep();
    _isWaitingForChoice = false;
    _needsTargetConfirmation = false;

    _isInertiaMode = true;
    _inertiaSeconds = 0;
    _inertiaStartTimeMillis = DateTime.now().millisecondsSinceEpoch;
    _inertiaCycleCount = 0;
    _isInertiaConfirmShown = false;
    _inertiaPendingMaxFlowConfirmUntilMillis = null;
    _inertiaNextPulseAtMillis = null;
    _hasPlayedWarning = false;
    _phaseCompleted = false;

    if (!_isRunning) {
      _isRunning = true;
    }

    // best-effort аудио: переход не зависит от ошибок audio
    _audioService.playInertiaSound();

    // Планируем первый pulse (3–6 минут)
    _scheduleNextPulse();

    _notificationService.showSimpleNotification(
      title: '⚡ OVERDRIVE активирован!',
      body: 'Режим инерции запущен автоматически',
    );

    _startTimerLoop();
    notifyListeners();
    _saveState();
  }

  /// Перепланировка следующего pulse INERTIA (рандом 3–6 минут),
  /// масштабированного глобальным timeWarpScale (ускоряет/замедляет циклы).
  void _scheduleNextPulse() {
    final random = Random();
    final delayMs = AppConstants.inertiaPulseMinMs +
        random.nextInt(
          AppConstants.inertiaPulseMaxMs - AppConstants.inertiaPulseMinMs + 1,
        );
    final scaledMs = (delayMs * _timeWarpScale).round();
    _inertiaNextPulseAtMillis = DateTime.now().millisecondsSinceEpoch + scaledMs;
  }

  /// Срабатывание pulse INERTIA: мягкий ignite.mp3 (best-effort) + инкремент цикла.
  /// Перепланирует следующий pulse, гарантируя ровно одно срабатывание на окно.
  void _firePulse() {
    // Звук проигрывается только пока активен режим INERTIA
    _audioService.playInertiaSound();

    // 1 инерционный цикл на каждое срабатывание pulse
    _inertiaCycleCount++;

    // Лимит бездействия MAX FLOW: на 6-м цикле показываем overlay ровно один раз
    if (_inertiaCycleCount >= AppConstants.inertiaMaxFlowCycle &&
        !_isInertiaConfirmShown) {
      _isInertiaConfirmShown = true;
      _inertiaPendingMaxFlowConfirmUntilMillis =
          DateTime.now().millisecondsSinceEpoch +
              AppConstants.inertiaMaxFlowConfirmSeconds * 1000;
      // Сигнал beep.mp3 (бип-бип) ровно один раз при достижении лимита
      _audioService.playDeadManSwitchSound();
    }

    // Перепланировка следующего окна (без дублей)
    _scheduleNextPulse();

    debugPrint(
      'TIMER: INERTIA pulse #$_inertiaCycleCount, следующий в $_inertiaNextPulseAtMillis',
    );
    notifyListeners();
    _saveState();
  }

  /// Подтверждение MAX FLOW (YES): закрывает overlay, продолжает INERTIA,
  /// сбрасывает счётчик бездействия (лимит отсчитывается заново).
  void confirmMaxFlow() {
    if (!_isInertiaConfirmShown) return;

    _isInertiaConfirmShown = false;
    _inertiaPendingMaxFlowConfirmUntilMillis = null;
    _inertiaCycleCount = 0;

    debugPrint('TIMER: MAX FLOW подтверждён (YES), INERTIA продолжается');
    notifyListeners();
    _saveState();
  }

  /// Отклонение MAX FLOW (NO): закрывает overlay и выходит в стандартный ОТДЫХ.
  void declineMaxFlow() {
    if (!_isInertiaConfirmShown) return;

    _isInertiaConfirmShown = false;
    _inertiaPendingMaxFlowConfirmUntilMillis = null;

    debugPrint('TIMER: MAX FLOW отклонён (NO) — выход в ОТДЫХ');
    stopInertia();
  }

  /// Авто-выход из INERTIA по таймауту MAX FLOW (нет YES за 30с) → стандартный ОТДЫХ.
  void _autoExitMaxFlow() {
    debugPrint('TIMER: MAX FLOW таймаут — авто-выход в ОТДЫХ');
    _isInertiaConfirmShown = false;
    _inertiaPendingMaxFlowConfirmUntilMillis = null;
    stopInertia();
  }

  /// Остановка инерции и переход к отдыху
  void stopInertia() {
    if (!_isInertiaMode) return;

    if (_statsProvider != null) {
      _statsProvider!.addInertiaTime(_inertiaSeconds);
      _statsProvider!.addStrike();
    }

    _isInertiaMode = false;
    _currentPhaseIndex = 3;

    // Остановка планировщика pulse и очистка окна MAX FLOW при выходе из INERTIA
    _inertiaNextPulseAtMillis = null;
    _inertiaPendingMaxFlowConfirmUntilMillis = null;
    _isInertiaConfirmShown = false;

    int extraRestSeconds = (_inertiaSeconds / 600).floor() * 60;

    final random = Random();
    int baseRecoverySeconds = AppConstants.phase4MinDuration +
        random.nextInt(AppConstants.phase4MaxDuration - AppConstants.phase4MinDuration + 1);

    _currentPhaseBaseSeconds = baseRecoverySeconds + extraRestSeconds;
    _remainingSeconds = _getScaledPhaseDuration(3, baseRecoverySeconds + extraRestSeconds);

    debugPrint('🎲 RECOVERY после инерции: Базовая = $baseRecoverySeconds сек, бонус = $extraRestSeconds сек, scaled = $_remainingSeconds сек');

    final now = DateTime.now().millisecondsSinceEpoch;
    _targetEndTimeMillis = now + (_remainingSeconds * 1000);
    _inertiaStartTimeMillis = null;
    _inertiaSeconds = 0;
    _hasPlayedWarning = false;
    _needsTargetConfirmation = false;
    _phaseCompleted = false;

    _audioService.playPhaseSound(_currentPhaseIndex);

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

    _stopDeadManSwitch();
    _audioService.stopLoopingBeep();
    _isWaitingForChoice = false;

    if (_statsProvider != null) {
      _statsProvider!.addStrike();
    }

    _currentPhaseIndex = 3;

    final random = Random();
    int baseRecoverySeconds = AppConstants.phase4MinDuration +
        random.nextInt(AppConstants.phase4MaxDuration - AppConstants.phase4MinDuration + 1);

    _currentPhaseBaseSeconds = baseRecoverySeconds;
    _remainingSeconds = _getScaledPhaseDuration(3, baseRecoverySeconds);

    debugPrint('🎲 RECOVERY: Случайная длительность = $baseRecoverySeconds сек, scaled = $_remainingSeconds сек (${_remainingSeconds ~/ 60} мин)');

    final now = DateTime.now().millisecondsSinceEpoch;
    _targetEndTimeMillis = now + (_remainingSeconds * 1000);
    _hasPlayedWarning = false;
    _needsTargetConfirmation = false;
    _phaseCompleted = false;

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
    // Фаза 0 (THINKING) завершена → ОСТАНАВЛИВАЕМ и показываем подтверждение цели
    if (_currentPhaseIndex == 0) {
      _isRunning = false;
      _timer?.cancel();
      _targetEndTimeMillis = null;
      _needsTargetConfirmation = true;

      // Запускаем зацикленный beep.mp3 на 20 минут
      _audioService.startLoopingBeep();
      
      // Уведомление о подтверждении цели
      _notificationService.showSimpleNotification(
        title: '🎯 ЦЕЛЬ НАЙДЕНА?',
        body: 'Подтвердите обнаружение цели',
      );

      debugPrint('TIMER: Фаза 0 завершена. Ожидание подтверждения цели');

      notifyListeners();
      _saveState();
      return;
    }
    
    // АВТОМАТИЧЕСКИЕ ПЕРЕХОДЫ: 1 → 2
    if (_currentPhaseIndex < 2) {
      _currentPhaseIndex++;
      _currentPhaseBaseSeconds = AppConstants.getPhaseDuration(_currentPhaseIndex);
      // Сброс guard входа в INERTIA при старте новой фазы STRIKE
      if (_currentPhaseIndex == 2) {
        _currentStrikeTransitionId = null;
      }
      _remainingSeconds = _getScaledPhaseDuration(_currentPhaseIndex);
      _hasPlayedWarning = false;
      _phaseCompleted = false;

      final now = DateTime.now().millisecondsSinceEpoch;
      _targetEndTimeMillis = now + (_remainingSeconds * 1000);

      _audioService.playPhaseSound(_currentPhaseIndex);

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

    // Фаза 2 (THE STRIKE) завершена → автоматический вход в INERTIA (V1.2).
    // Ветка выбора ИНЕРЦИЯ/ОТДЫХ удалена. Idempotent guard от повторного входа
    // на одно завершение STRIKE (lastInertiaPhaseTransitionId).
    if (_currentPhaseIndex == 2) {
      // Guard: если уже в INERTIA — не дублируем вход
      if (_isInertiaMode) {
        debugPrint('TIMER: Фаза 2 уже в INERTIA, пропуск повторного входа');
        return;
      }
      _currentStrikeTransitionId ??= (_lastInertiaPhaseTransitionId ?? 0) + 1;
      if (_lastInertiaPhaseTransitionId == _currentStrikeTransitionId) {
        debugPrint('TIMER: INERTIA уже активирована для transition $_lastInertiaPhaseTransitionId, пропуск');
        return;
      }
      _lastInertiaPhaseTransitionId = _currentStrikeTransitionId;

      _targetEndTimeMillis = null;
      _timer?.cancel();

      debugPrint('TIMER: Фаза 2 завершена. Авто-вход в INERTIA (transition $_lastInertiaPhaseTransitionId)');
      _enterInertiaMode();
      return;
    }

    // Фаза 3 (RECOVERY) завершена → автоматический переход к фазе 1
    if (_currentPhaseIndex == 3) {
      _audioService.playCycleEndSound();

      _notificationService.showSimpleNotification(
        title: '✅ Цикл завершён! Начинается новый',
        body: 'Автоматический переход к THINKING',
      );

      debugPrint('TIMER: Цикл завершён. Автоматический переход к фазе 1.');

      _currentPhaseIndex = 0;
      _remainingSeconds = _getScaledPhaseDuration(0, AppConstants.phase1Duration);
      _currentPhaseBaseSeconds = AppConstants.phase1Duration;
      _hasPlayedWarning = false;
      _isWaitingForChoice = false;
      _needsTargetConfirmation = false;
      _phaseCompleted = false;

      final now = DateTime.now().millisecondsSinceEpoch;
      _targetEndTimeMillis = now + (_remainingSeconds * 1000);

      _isRunning = true;

      notifyListeners();
      _saveState();
      return;
    }
  }

  void _stopDeadManSwitch() {
    _deadManSwitchTimer?.cancel();
    _deadManSwitchTimer = null;
  }

  /// Подтверждение цели - ДА (переход к фазе 1)
  void confirmTargetFound() {
    if (!_needsTargetConfirmation) return;

    _audioService.stopLoopingBeep();
    _needsTargetConfirmation = false;
    _currentPhaseIndex = 1;
    _currentPhaseBaseSeconds = AppConstants.getPhaseDuration(1);
    _remainingSeconds = _getScaledPhaseDuration(1, AppConstants.phase2Duration);
    _hasPlayedWarning = false;
    _phaseCompleted = false;

    final now = DateTime.now().millisecondsSinceEpoch;
    _targetEndTimeMillis = now + (_remainingSeconds * 1000);

    _isRunning = true;
    _audioService.playPhaseSound(_currentPhaseIndex);

    _notificationService.showSimpleNotification(
      title: '✅ Цель подтверждена!',
      body: 'ОРУЖИЕ К БОЮ - 2 минуты подготовки',
    );

    _startTimerLoop();
    notifyListeners();
    _saveState();
  }

  /// Подтверждение цели - НЕТ (возврат к началу)
  void confirmTargetNotFound() {
    if (!_needsTargetConfirmation) return;

    _audioService.stopLoopingBeep();
    _needsTargetConfirmation = false;

    _notificationService.showSimpleNotification(
      title: '🔄 Возврат к поиску',
      body: 'Начинаем новый цикл поиска цели',
    );

    _currentPhaseIndex = 0;
    _currentPhaseBaseSeconds = AppConstants.phase1Duration;
    _remainingSeconds = _getScaledPhaseDuration(0, AppConstants.phase1Duration);
    _hasPlayedWarning = false;
    _isWaitingForChoice = false;
    _phaseCompleted = false;

    final now = DateTime.now().millisecondsSinceEpoch;
    _targetEndTimeMillis = now + (_remainingSeconds * 1000);

    _isRunning = true;
    _startTimerLoop();
    notifyListeners();
    _saveState();
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double get progress {
    if (_isInertiaMode) return 1.0;
    int total = _getScaledPhaseDuration(_currentPhaseIndex);
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
