import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Провайдер статистики пользователя
class StatsProvider with ChangeNotifier {
  int _totalStrikes = 0;
  int _totalInertiaTime = 0; // в секундах
  int _todayCycles = 0;
  String _lastCycleDate = '';
  
  bool _isPremium = false; // Для демо всегда false

  // Getters
  int get totalStrikes => _totalStrikes;
  int get totalInertiaTime => _totalInertiaTime;
  int get todayCycles => _todayCycles;
  bool get isPremium => _isPremium;

  /// Получить текущий ранг
  Map<String, dynamic> get currentRank {
    return AppConstants.getRankByStrikes(_totalStrikes);
  }

  /// Получить следующий ранг
  Map<String, dynamic>? get nextRank {
    return AppConstants.getNextRank(_totalStrikes);
  }

  /// Сколько strikes нужно до следующего ранга
  int get strikesToNextRank {
    final next = nextRank;
    if (next == null) return 0;
    return next['strikes'] - _totalStrikes;
  }

  /// Общее время доминирования в часах
  double get totalDominationHours {
    // Каждый strike = 3 минуты работы + время инерции
    int totalSeconds = (_totalStrikes * 180) + _totalInertiaTime;
    return totalSeconds / 3600;
  }

  /// Можно ли начать новый цикл (для free версии)
  bool get canStartCycle {
    if (_isPremium) return true;
    _checkAndResetDailyCycles();
    return _todayCycles < AppConstants.freeCyclesPerDay;
  }

  /// Инициализация - загрузка данных из SharedPreferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    _totalStrikes = prefs.getInt('totalStrikes') ?? 0;
    _totalInertiaTime = prefs.getInt('totalInertiaTime') ?? 0;
    _todayCycles = prefs.getInt('todayCycles') ?? 0;
    _lastCycleDate = prefs.getString('lastCycleDate') ?? '';
    _isPremium = prefs.getBool('isPremium') ?? false;
    
    _checkAndResetDailyCycles();
    notifyListeners();
  }

  /// Проверка и сброс дневных циклов
  void _checkAndResetDailyCycles() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (_lastCycleDate != today) {
      _todayCycles = 0;
      _lastCycleDate = today;
      _saveDailyCycles();
    }
  }

  /// Добавить strike (завершенная фаза работы)
  Future<void> addStrike() async {
    _totalStrikes++;
    _todayCycles++;
    _lastCycleDate = DateTime.now().toIso8601String().split('T')[0];
    
    await _saveStats();
    await _saveDailyCycles();
    notifyListeners();
  }

  /// Добавить время инерции
  Future<void> addInertiaTime(int seconds) async {
    _totalInertiaTime += seconds;
    await _saveStats();
    notifyListeners();
  }

  /// Сохранить статистику
  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('totalStrikes', _totalStrikes);
    await prefs.setInt('totalInertiaTime', _totalInertiaTime);
  }

  /// Сохранить дневные циклы
  Future<void> _saveDailyCycles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('todayCycles', _todayCycles);
    await prefs.setString('lastCycleDate', _lastCycleDate);
  }

  /// Активировать премиум (для демо)
  Future<void> activatePremium() async {
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', true);
    notifyListeners();
  }

  /// Сбросить все данные (для тестирования)
  Future<void> resetAll() async {
    _totalStrikes = 0;
    _totalInertiaTime = 0;
    _todayCycles = 0;
    _lastCycleDate = '';
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
