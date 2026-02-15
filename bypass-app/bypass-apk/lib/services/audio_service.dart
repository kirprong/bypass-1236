import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import '../utils/constants.dart';

/// Сервис для управления звуковым сопровождением
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final Map<String, AudioPlayer> _players = {};
  bool _isInitialized = false;

  /// Инициализация аудио-сервиса
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Создаем плееры для каждого звука
      _players['START_THINKING'] = AudioPlayer();
      _players['PREP_PHASE'] = AudioPlayer();
      _players['STRIKE_PHASE'] = AudioPlayer();
      _players['RECOVERY'] = AudioPlayer();
      _players['INERTIA_ACTIVE'] = AudioPlayer();
      _players['START'] = AudioPlayer();
      _players['WARNING'] = AudioPlayer();
      _players['FINISH'] = AudioPlayer();
      _players['DEAD_MAN_SWITCH'] = AudioPlayer();

      // Предзагрузка звуков с метаданными для фона
      await _loadSound(
          'START_THINKING', AppConstants.soundStartThinking, 'Scanning...');
      await _loadSound(
          'PREP_PHASE', AppConstants.soundPrepPhase, 'Preparation');
      await _loadSound(
          'STRIKE_PHASE', AppConstants.soundStrikePhase, 'The Strike');
      await _loadSound('RECOVERY', AppConstants.soundRecovery, 'Recovery');
      await _loadSound(
          'INERTIA_ACTIVE', AppConstants.soundInertiaActive, 'Overdrive');
      await _loadSound('START', AppConstants.soundStart, 'Timer Started');
      await _loadSound('WARNING', AppConstants.soundWarning, 'Warning');
      await _loadSound('FINISH', AppConstants.soundFinish, 'Phase Complete');
      await _loadSound('DEAD_MAN_SWITCH', AppConstants.soundDeadManSwitch,
          'Dead Man\'s Switch');

      _isInitialized = true;
    } catch (e) {
      debugPrint('Ошибка инициализации AudioService: $e');
    }
  }

  /// Вспомогательный метод для загрузки звука с MediaItem
  Future<void> _loadSound(String key, String assetPath, String title) async {
    try {
      final source = AudioSource.asset(
        assetPath,
        tag: MediaItem(
          id: key,
          album: "Bypass 1236",
          title: title,
          artUri: Uri.parse(
              'https://media.istockphoto.com/id/1145618475/vector/stopwatch-timer-speed-alarm-clock-line-icon-vector-illustration.jpg?s=612x612&w=0&k=20&c=Xp_FywgC4e0zJz5t-5Lh7Qy-9Z8_j_0-7x_0-7x_0-7x_0'),
        ),
      );
      await _players[key]!.setAudioSource(source);
    } catch (e) {
      debugPrint('Ошибка загрузки звука $key: $e');
    }
  }

  /// Воспроизведение звука по ключу
  Future<void> playSound(String key) async {
    if (!_isInitialized) await initialize();

    try {
      final player = _players[key];
      if (player != null) {
        // Для Android: принудительный стоп и перемотка для надежности повторного запуска
        if (player.playing) {
          await player.stop();
        }
        await player.seek(Duration.zero);

        // Запускаем без await, чтобы не ждать окончания звука
        player.play().catchError((e) {
          debugPrint('Ошибка при вызове play() для $key: $e');
          return null;
        });

        debugPrint('AUDIO: Воспроизведение звука $key');
      } else {
        debugPrint('AUDIO: Плеер для $key не найден');
      }
    } catch (e) {
      debugPrint('Ошибка воспроизведения звука $key: $e');
    }
  }

  /// Воспроизведение звука для фазы (при переходе между фазами)
  Future<void> playPhaseSound(int phaseIndex) async {
    String soundKey;
    switch (phaseIndex) {
      case 0:
        soundKey = 'START_THINKING'; // scan.mp3
        break;
      case 1:
        soundKey = 'PREP_PHASE'; // bolt.mp3
        break;
      case 2:
        soundKey = 'STRIKE_PHASE'; // siren.mp3
        break;
      case 3:
        soundKey = 'RECOVERY'; // rest.mp3
        break;
      default:
        return;
    }
    await playSound(soundKey);
  }

  /// Воспроизведение звука инерции
  Future<void> playInertiaSound() async {
    await playSound('INERTIA_ACTIVE');
  }

  /// Воспроизведение звука старта/паузы
  Future<void> playStartSound() async {
    await playSound('START');
  }

  /// Воспроизведение звука предупреждения (за 6 секунд до конца)
  Future<void> playWarningSound() async {
    await playSound('WARNING');
  }

  /// Воспроизведение звука окончания фазы
  Future<void> playFinishSound() async {
    await playSound('FINISH');
  }

  /// Воспроизведение звука Dead Man's Switch (повторяющийся beep)
  Future<void> playDeadManSwitchSound() async {
    await playSound('DEAD_MAN_SWITCH');
  }

  /// Остановка всех звуков
  Future<void> stopAll() async {
    try {
      for (final player in _players.values) {
        await player.stop();
      }
    } catch (e) {
      debugPrint('Ошибка остановки звуков: $e');
    }
  }

  /// Освобождение ресурсов
  Future<void> dispose() async {
    try {
      for (final player in _players.values) {
        await player.dispose();
      }
      _players.clear();
      _isInitialized = false;
    } catch (e) {
      debugPrint('Ошибка освобождения ресурсов AudioService: $e');
    }
  }
}
