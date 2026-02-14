import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/audio_service.dart';
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

  /// Инициализация: аудио + восстановление состояния
  Future<void> initialize() async {
    await _audioService.initialize();
    await _restoreState();
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

    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;

      if (_isInertiaMode) {
        if (_inertiaStartTimeMillis != null) {
          _inertiaSeconds = ((now - _inertiaStartTimeMillis!) / 1000).floor();
        }
      } else {
        if (_targetEndTimeMillis != null) {
          final remaining = ((_targetEndTimeMillis! - now) / 1000).floor();

          // Предупреждение за 6 секунд до конца (кроме фазы 3)
          if (remaining == AppConstants.warningBeforeEndSeconds &&
              !_hasPlayedWarning &&
              _currentPhaseIndex != 2) {
            _audioService.playWarningSound();
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
    });
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
      _vibrateShort();
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
    _vibratePhase();
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
    _vibratePhase();
    _startTimerLoop();
    notifyListeners();
    _saveState();
  }

  /// Завершение фазы (АВТОМАТИЧЕСКИЕ ПЕРЕХОДЫ 1→2→3)
  void _onPhaseComplete() {
    _vibratePhase(); // Вибрация при окончании фазы

    // АВТОМАТИЧЕСКИЕ ПЕРЕХОДЫ: 1 → 2 → 3
    if (_currentPhaseIndex < 2) {
      _currentPhaseIndex++;
      _remainingSeconds = AppConstants.getPhaseDuration(_currentPhaseIndex);

      final now = DateTime.now().millisecondsSinceEpoch;
      _targetEndTimeMillis = now + (_remainingSeconds * 1000);
      _hasPlayedWarning = false;

      _audioService.playPhaseSound(_currentPhaseIndex);

      debugPrint('TIMER: Автоматический переход на фазу $_currentPhaseIndex');
      notifyListeners();
      _saveState();
      return;
    }

    // После фазы 3 (STRIKE) - РУЧНОЙ ВЫБОР
    if (_currentPhaseIndex == 2) {
      _isRunning = false;
      _isWaitingForChoice = true;
      _timer?.cancel();
      WakelockPlus.disable();

      // По истечении 3-х минутного таймера играет REST.mp3 (soundRecovery)
      _audioService.playPhaseSound(3);

      // Запускаем Dead Man's Switch (30с ожидания -> повтор beep)
      _startDeadManSwitch();

      debugPrint('TIMER: Фаза 3 завершена. Звук REST. Ожидание выбора.');
      notifyListeners();
      _saveState();
      return;
    }

    // После фазы 4 (RECOVERY) - цикл завершен
    if (_currentPhaseIndex == 3) {
      _audioService.playSound(
        'START_THINKING',
      ); // scan.mp3 в конце 6-минутного интервала
      reset();
      return;
    }
  }

  /// Запуск Dead Man's Switch (30 секунд ПОСЛЕ фазы 3 БЕЗ выбора)
  void _startDeadManSwitch() {
    _deadManSwitchTimer?.cancel();

    // Сначала ждем 30 секунд тишины
    _deadManSwitchTimer = Timer(
      const Duration(seconds: AppConstants.deadManSwitchSeconds),
      () {
        // Через 30 секунд запускаем ПОВТОРЯЮЩИЙСЯ писк каждую секунду
        _deadManSwitchTimer = Timer.periodic(const Duration(seconds: 1), (
          timer,
        ) {
          _audioService.playDeadManSwitchSound();
          debugPrint('TIMER: Dead Man\'s Switch - ПОВТОРЯЮЩИЙСЯ ПИСК!');
        });
      },
    );

    debugPrint('TIMER: Dead Man\'s Switch запущен (таймаут 30 сек)');
  }

  /// Остановка Dead Man's Switch
  void _stopDeadManSwitch() {
    _deadManSwitchTimer?.cancel();
    _deadManSwitchTimer = null;
  }

  Future<void> _vibrateShort() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
  }

  Future<void> _vibratePhase() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }
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
