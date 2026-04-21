import 'package:flutter/material.dart';

/// Константы приложения 1234
class AppConstants {
  // Цвета фаз (неоновые акценты на черном фоне)
  static const Color phase1Color = Color(
    0xFF00D4FF,
  ); // Холодный неон - THINKING
  static const Color phase2Color = Color(
    0xFFFF8A00,
  ); // Пульсирующий оранжевый - PREP
  static const Color phase3Color = Color(
    0xFFFF0000,
  ); // Агрессивный красный - STRIKE
  static const Color phase4Color = Color(
    0xFF0A1E5C,
  ); // Глубокий синий - RECOVERY (для отдыха глаз)
  static const Color inertiaColor = Color(0xFFFFD700); // Золотой - INERTIA MODE

  // Основные цвета
  static const Color backgroundColor = Color(0xFF000000); // OLED Black
  static const Color textPrimaryColor = Color(0xFFFFFFFF); // Белый
  static const Color textSecondaryColor = Color(0xFF999999); // Серый

  // Длительности фаз (в секундах)
  static const int phase1Duration = 60; // 1 минута - Анализ
  static const int phase2Duration = 120; // 2 минуты - Подготовка
  static const int phase3Duration = 180; // 3 минуты - Работа

  // Фаза 4 (RECOVERY) - случайная длительность от 1 до 4 минут
  static const int phase4MinDuration = 60; // Минимум 1 минута
  static const int phase4MaxDuration = 240; // Максимум 4 минуты
  static const int phase4Duration = 0; // Устарело, используется рандом

  // Названия фаз
  static const String phase1Name = 'THINKING';
  static const String phase2Name = 'PREP';
  static const String phase3Name = 'STRIKE';
  static const String phase4Name = 'ПЕРЕЗАГРУЗКА';

  // Тексты для фаз
  static const String phase1Text = 'ЦЕЛЬ?';
  static const String phase2Text = 'ОРУЖИЕ К БОЮ!';
  static const String phase3Text = 'УНИЧТОЖАЙ';
  static const String phase4Text = 'БУДЬ ГОТОВ ВСЕГДА';

  // Звуковые файлы
  static const String soundStartThinking =
      'assets/sounds/scan.mp3'; // Переход 0→1 (начало первой фазы)
  static const String soundPrepPhase = 'assets/sounds/bolt.mp3'; // Переход 1→2
  static const String soundStrikePhase =
      'assets/sounds/siren.mp3'; // Переход 2→3
  static const String soundRecovery =
      'assets/sounds/rest.mp3'; // Переход 3→4 (начало отдыха)
  static const String soundInertiaActive =
      'assets/sounds/ignite.mp3'; // Активация инерции
  static const String soundStart =
      'assets/sounds/start.mp3'; // Нажатие Start/Pause
  static const String soundWarning =
      'assets/sounds/beep.mp3'; // Предупреждение за 6 секунд
  static const String soundFinish =
      'assets/sounds/finish.mp3'; // Окончание фазы
  static const String soundDeadManSwitch =
      'assets/sounds/beep.mp3'; // Dead Man's Switch (30 сек)

  // Настройки инерции
  static const int inertiaRestMultiplier =
      1; // 1 минута отдыха за каждые 10 минут инерции
  static const int inertiaRestBase = 360; // Базовые 6 минут отдыха

  // Настройки таймингов
  static const int warningBeforeEndSeconds =
      6; // Предупреждение за 6 секунд до конца фазы
  static const int deadManSwitchSeconds =
      30; // Dead Man's Switch таймаут после фазы 3

  // Алиас для совместимости
  static int get deadManSwitchTimeout => deadManSwitchSeconds;

  // Лимиты для free версии
  static const int freeCyclesPerDay = 3;

  // Ранги (геометрическая прогрессия, минимальный шаг 100)
  static const List<Map<String, dynamic>> ranks = [
    {'name': 'ROOKIE', 'strikes': 100, 'color': Color(0xFF4A4A4A)},
    {'name': 'RECRUIT', 'strikes': 200, 'color': Color(0xFF5C6B5C)},
    {'name': 'SOLDIER', 'strikes': 350, 'color': Color(0xFF6B8E23)},
    {'name': 'EXECUTOR', 'strikes': 550, 'color': Color(0xFF2ECC71)},
    {'name': 'STRIKER', 'strikes': 850, 'color': Color(0xFF1ABC9C)},
    {'name': 'DESTROYER', 'strikes': 1300, 'color': Color(0xFFFF0000)},
    {'name': 'PHANTOM', 'strikes': 2000, 'color': Color(0xFFFF4500)},
    {'name': 'TITAN', 'strikes': 3000, 'color': Color(0xFFFF8A00)},
    {'name': 'ARCHON', 'strikes': 4500, 'color': Color(0xFF8B00FF)},
    {'name': 'LEGEND', 'strikes': 6700, 'color': Color(0xFF4169E1)},
    {'name': 'SLAYER', 'strikes': 10000, 'color': Color(0xFF6A0DAD)},
    {'name': 'WARLORD', 'strikes': 15000, 'color': Color(0xFFFF1493)},
    {'name': 'OVERLORD', 'strikes': 22500, 'color': Color(0xFFDC143C)},
    {'name': 'APEX PREDATOR', 'strikes': 33750, 'color': Color(0xFFC0C0C0)},
    {'name': 'ULTIMATUM', 'strikes': 50000, 'color': Color(0xFFFFD700)},
  ];

  // Получить текущий ранг по количеству strikes
  static Map<String, dynamic> getRankByStrikes(int strikes) {
    for (int i = ranks.length - 1; i >= 0; i--) {
      if (strikes >= ranks[i]['strikes']) {
        return ranks[i];
      }
    }
    return ranks[0];
  }

  // Получить следующий ранг
  static Map<String, dynamic>? getNextRank(int strikes) {
    for (int i = 0; i < ranks.length; i++) {
      if (strikes < ranks[i]['strikes']) {
        return ranks[i];
      }
    }
    return null; // Максимальный ранг достигнут
  }

  // Получить цвет фазы
  static Color getPhaseColor(int phaseIndex) {
    switch (phaseIndex) {
      case 0:
        return phase1Color;
      case 1:
        return phase2Color;
      case 2:
        return phase3Color;
      case 3:
        return phase4Color;
      default:
        return textPrimaryColor;
    }
  }

  // Получить название фазы
  static String getPhaseName(int phaseIndex) {
    switch (phaseIndex) {
      case 0:
        return phase1Name;
      case 1:
        return phase2Name;
      case 2:
        return phase3Name;
      case 3:
        return phase4Name;
      default:
        return '';
    }
  }

  // Получить текст фазы
  static String getPhaseText(int phaseIndex) {
    switch (phaseIndex) {
      case 0:
        return phase1Text;
      case 1:
        return phase2Text;
      case 2:
        return phase3Text;
      case 3:
        return phase4Text;
      default:
        return '';
    }
  }

  // Получить длительность фазы
  static int getPhaseDuration(int phaseIndex) {
    switch (phaseIndex) {
      case 0:
        return phase1Duration;
      case 1:
        return phase2Duration;
      case 2:
        return phase3Duration;
      case 3:
        return phase4Duration;
      default:
        return 0;
    }
  }
}
