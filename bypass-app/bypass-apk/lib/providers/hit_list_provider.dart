import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'timer_provider.dart';

/// Слот расписания HIT-LIST.
class HitListSlot {
  final String slotId;
  final bool enabled;
  final int slotOrdinal; // Стабильный вес для детерминизма выбора winner
  final int hour; // 0..23
  final int minute; // 0..59

  HitListSlot({
    required this.slotId,
    required this.enabled,
    required this.slotOrdinal,
    required this.hour,
    required this.minute,
  });

  factory HitListSlot.fromJson(Map<String, dynamic> json) => HitListSlot(
        slotId: json['slotId'] as String,
        enabled: json['enabled'] as bool? ?? false,
        slotOrdinal: json['slotOrdinal'] as int? ?? 0,
        hour: json['hour'] as int? ?? 0,
        minute: json['minute'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'enabled': enabled,
        'slotOrdinal': slotOrdinal,
        'hour': hour,
        'minute': minute,
      };

  HitListSlot copyWith({
    String? slotId,
    bool? enabled,
    int? slotOrdinal,
    int? hour,
    int? minute,
  }) =>
      HitListSlot(
        slotId: slotId ?? this.slotId,
        enabled: enabled ?? this.enabled,
        slotOrdinal: slotOrdinal ?? this.slotOrdinal,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

/// HitListScheduler (V1.3 / "THE HIT-LIST").
///
/// Ответственность:
/// - хранит до [AppConstants.hitListMaxSlots] слотов расписания;
/// - при включённом хотя бы одном слоте — ежедневно в выбранное HH:mm инициирует
///   авто-старт цикла через [TimerProvider.autoStartFromScheduler];
/// - анти-дубликаты и идемпотентность "один раз на окно" (windowKey);
/// - guard: если [TimerProvider.isRunning] — авто-старт не выполняется (no-op);
/// - выбор winner при конфликте одинакового HH:mm — по минимальному [slotOrdinal].
class HitListProvider with ChangeNotifier {
  TimerProvider? _timerProvider;
  List<HitListSlot> _slots = [];
  String? _lastExecutedWindow;
  Timer? _pollTimer;

  List<HitListSlot> get slots => List.unmodifiable(_slots);
  bool get isActive => _slots.any((s) => s.enabled);
  String? get lastExecutedWindow => _lastExecutedWindow;
  int get nextOrdinal =>
      _slots.isEmpty ? 0 : _slots.map((s) => s.slotOrdinal).reduce((a, b) => a > b ? a : b) + 1;

  void setTimerProvider(TimerProvider provider) {
    _timerProvider = provider;
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final slotsJson = prefs.getString(AppConstants.hitListSlotsKey);
      if (slotsJson != null) {
        final decoded = jsonDecode(slotsJson) as List<dynamic>;
        _slots = decoded
            .map((e) => HitListSlot.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      _lastExecutedWindow =
          prefs.getString(AppConstants.hitListLastExecutedWindowKey);
    } catch (e) {
      debugPrint('HitListProvider: init error: $e');
    }
    notifyListeners();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: AppConstants.hitListPollIntervalSeconds),
      (_) => processScheduledTriggers(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Обработка ежедневных триггеров на текущий момент.
  /// Вызывается из периодического poll-таймера, а также может быть
  /// вызвана вручную (для E2E/тестирования).
  void processScheduledTriggers() {
    if (_timerProvider == null) return;

    final now = DateTime.now();
    final windowKey = AppConstants.hitListWindowKey(
      now.millisecondsSinceEpoch,
    );

    // Идемпотентность: окно уже выполнялось — no-op.
    if (_lastExecutedWindow == windowKey) return;

    // Включённые слоты, совпадающие с текущим HH:mm.
    final matching = _slots
        .where((s) => s.enabled && s.hour == now.hour && s.minute == now.minute)
        .toList();
    if (matching.isEmpty) return;

    // Winner = минимальный slotOrdinal среди включённых слотов на это время.
    matching.sort((a, b) => a.slotOrdinal.compareTo(b.slotOrdinal));
    final winner = matching.first;

    // Guard: не стартовать при активной работе цикла.
    if (_timerProvider!.isRunning) return;

    final scheduledAt = DateTime(
      now.year,
      now.month,
      now.day,
      winner.hour,
      winner.minute,
    ).millisecondsSinceEpoch;

    _timerProvider!.autoStartFromScheduler(
      windowKey,
      winner.slotId,
      scheduledAt,
    );
  }

  /// Добавить новый слот (до [AppConstants.hitListMaxSlots]).
  /// Время по умолчанию — ближайший "круглый" получас, чтобы не конфликтовать
  /// с текущим окном.
  Future<void> addSlot() async {
    if (_slots.length >= AppConstants.hitListMaxSlots) return;
    final slot = HitListSlot(
      slotId: 'hit_${DateTime.now().millisecondsSinceEpoch}_${_slots.length}',
      enabled: true,
      slotOrdinal: nextOrdinal,
      hour: 9,
      minute: 0,
    );
    _slots.add(slot);
    await _persist();
    notifyListeners();
  }

  Future<void> removeSlot(String slotId) async {
    _slots.removeWhere((s) => s.slotId == slotId);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleSlot(String slotId, bool enabled) async {
    final idx = _slots.indexWhere((s) => s.slotId == slotId);
    if (idx == -1) return;
    _slots[idx] = _slots[idx].copyWith(enabled: enabled);
    await _persist();
    notifyListeners();
  }

  Future<void> setSlotTime(String slotId, int hour, int minute) async {
    final idx = _slots.indexWhere((s) => s.slotId == slotId);
    if (idx == -1) return;
    _slots[idx] = _slots[idx].copyWith(hour: hour, minute: minute);
    await _persist();
    notifyListeners();
  }

  /// Сбросить идемпотентный ключ окна (для тестов/ручного перезапуска расписания).
  Future<void> clearLastExecutedWindow() async {
    _lastExecutedWindow = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.hitListLastExecutedWindowKey);
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_slots.map((s) => s.toJson()).toList());
      await prefs.setString(AppConstants.hitListSlotsKey, json);
    } catch (e) {
      debugPrint('HitListProvider: persist error: $e');
    }
  }

  /// Синхронизация локального кэша выполненного окна из TimerProvider
  /// (используется после прямых вызовов autoStartFromScheduler).
  void syncExecutedWindow(String? window) {
    if (_lastExecutedWindow != window) {
      _lastExecutedWindow = window;
      notifyListeners();
    }
  }
}
