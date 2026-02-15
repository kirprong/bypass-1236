import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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
      debugPrint('🔊 Initializing AudioService...');
      
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

      // Предзагрузка звуков с метаданными для фона с таймаутом
      await _loadSound(
          'START_THINKING', AppConstants.soundStartThinking, 'Scanning...')
          .timeout(const Duration(seconds: 3));
      await _loadSound(
          'PREP_PHASE', AppConstants.soundPrepPhase, 'Preparation')
          .timeout(const Duration(seconds: 3));
      await _loadSound(
          'STRIKE_PHASE', AppConstants.soundStrikePhase, 'The Strike')
          .timeout(const Duration(seconds: 3));
      await _loadSound('RECOVERY', AppConstants.soundRecovery, 'Recovery')
          .timeout(const Duration(seconds: 3));
      await _loadSound(
          'INERTIA_ACTIVE', AppConstants.soundInertiaActive, 'Overdrive')
          .timeout(const Duration(seconds: 3));
      await _loadSound('START', AppConstants.soundStart, 'Timer Started')
          .timeout(const Duration(seconds: 3));
      await _loadSound('WARNING', AppConstants.soundWarning, 'Warning')
          .timeout(const Duration(seconds: 3));
      await _loadSound('FINISH', AppConstants.soundFinish, 'Phase Complete')
          .timeout(const Duration(seconds: 3));
      await _loadSound('DEAD_MAN_SWITCH', AppConstants.soundDeadManSwitch,
          'Dead Man\'s Switch')
          .timeout(const Duration(seconds: 3));

      _isInitialized = true;
      debugPrint('✅ AudioService initialized successfully');
    } catch (e) {
      debugPrint('⚠️ AudioService initialization failed: $e');
      debugPrint('   App will continue without audio');
      _isInitialized = false; // Работаем без звука
    }
  }

  /// Вспомогательный метод для загрузки звука
  Future<void> _loadSound(String key, String assetPath, String title) async {
    try {
      debugPrint('   Loading: $key from $assetPath');
      final source = AudioSource.asset(assetPath);
      await _players[key]!.setAudioSource(source);
      
      // Предзагружаем (preload) для быстрого воспроизведения
      await _players[key]!.load();
      
      debugPrint('✅ Loaded and preloaded: $key ($title)');
    } catch (e) {
      debugPrint('⚠️ Error loading sound $key: $e');
      rethrow;
    }
  }

  /// Воспроизведение звука по ключу
  Future<void> playSound(String key) async {
    if (!_isInitialized) {
      debugPrint('⚠️ AudioService not initialized - skipping sound $key');
      return; // Продолжаем работу без звука
    }

    try {
      final player = _players[key];
      if (player != null) {
        debugPrint('🔊 Attempting to play sound: $key');
        
        // Для Android: принудительный стоп и перемотка для надежности повторного запуска
        if (player.playing) {
          await player.stop();
          debugPrint('   Stopped previous playback');
        }
        
        await player.seek(Duration.zero);
        debugPrint('   Seeked to start');
        
        // Устанавливаем громкость на максимум
        await player.setVolume(1.0);

        // Запускаем воспроизведение и ждем, чтобы убедиться что началось
        await player.play();
        debugPrint('✅ Sound playing: $key');
      } else {
        debugPrint('⚠️ Player for $key not found');
      }
    } catch (e) {
      debugPrint('⚠️ Error playing sound $key: $e');
    }
  }

  /// Воспроизведение звука для фазы (при переходе между фазами)
  Future<void> playPhaseSound(int phaseIndex) async {
    String soundKey;
    switch (phaseIndex) {
      case 0:
        // Фаза 0 (THINKING) - звук играет при нажатии START (start.mp3), а не здесь
        return; // Не играем звук для фазы 0
      case 1:
        soundKey = 'PREP_PHASE'; // bolt.mp3 - переход 0→1
        break;
      case 2:
        soundKey = 'STRIKE_PHASE'; // siren.mp3 - переход 1→2
        break;
      case 3:
        soundKey = 'RECOVERY'; // rest.mp3 - начало отдыха
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
    await playSound('FINISH'); // finish.mp3 - предупреждение за 6 секунд
  }

  /// Воспроизведение звука окончания фазы
  Future<void> playFinishSound() async {
    await playSound('FINISH');
  }

  /// Воспроизведение звука Dead Man's Switch (повторяющийся beep)
  Future<void> playDeadManSwitchSound() async {
    await playSound('WARNING'); // beep.mp3 - противно пищать
  }
  
  /// Воспроизведение звука окончания цикла (конец отдыха)
  Future<void> playCycleEndSound() async {
    await playSound('START_THINKING'); // scan.mp3 - конец отдыха
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
