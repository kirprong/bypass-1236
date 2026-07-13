# Technical Design Document (TDD): 1234 Timer

## 1. System Architecture

### Overview
1234 Timer — это мобильное приложение (Flutter) с 4 фазами и множеством психологических микромеханик:
- **THINKING (60s)** → **PREP (120s)** → **STRIKE (180s)** → **ПЕРЕЗАГРУЗКА (60-240s случайно)**

Состояния: **Ready/Idle**, **Running**, **Paused**, **WaitingForChoice**, **TargetConfirmation**

```mermaid
graph TD
    User[User] --> UI[Timer UI]
    UI --> Timer[TimerProvider]
    Timer --> Audio[AudioService]
    Timer --> Notif[NotificationService]
    Timer --> Storage[SharedPreferences]
    Timer --> Stats[StatsProvider]
    Timer --> FG[ForegroundService]
```

### Timing Model (без накопления ошибок)
- Используем `DateTime.now().millisecondsSinceEpoch` как источник времени
- Храним:
  - `phaseIndex`: 0-3 (THINKING, PREP, STRIKE, RECOVERY)
  - `status`: через поле `isRunning` (true/false) + `isWaitingForChoice` + `isInertiaMode` + `needsTargetConfirmation`
  - `remainingMs` → `remainingSeconds`: integer секунды
  - `phaseEndsAt` → `targetEndTimeMillis`: absolute timestamp
  - `lastTickId` → `_timer`: Timer.periodic(200ms)
  - `inertiaStartTimeMillis`: для режима инерции
  - `inertiaSeconds`: счетчик в реальном времени

---

## 2. Database / Storage Schema

Stage 0 не требует сервера. Данные хранятся локально в SharedPreferences.

```mermaid
erDiagram
    TIMER_STATE {
        int currentPhaseIndex
        int targetEndTimeMillis
        bool isRunning
        bool isInertiaMode
        int inertiaStartTimeMillis
        int remainingSeconds
        int inertiaSeconds
        bool isWaitingForChoice
        bool needsTargetConfirmation
        bool hasPlayedWarning
    }
    
    STATS {
        int totalStrikes
        int totalInertiaTime
        int todayCycles
        string lastCycleDate
        bool isPremium
    }
```

**Timer State (bypass_timer_state):**
```json
{
  "currentPhaseIndex": 0,
  "targetEndTimeMillis": null,
  "isRunning": false,
  "isInertiaMode": false,
  "inertiaStartTimeMillis": null,
  "remainingSeconds": 60,
  "inertiaSeconds": 0,
  "isWaitingForChoice": false,
  "needsTargetConfirmation": false
}
```

**Stats (SharedPreferences keys):**
- `totalStrikes`: int
- `totalInertiaTime`: int (секунды)
- `todayCycles`: int
- `lastCycleDate`: string (YYYY-MM-DD)
- `isPremium`: bool

---

## 3. Frontend / Client Architecture

### Phase Configuration (фактические значения)

| Index | Название | Длительность | Цвет | Текст |
|-------|----------|--------------|------|-------|
| 0 | THINKING | 60s (1 мин) | #00D4FF (неоновый синий) | "ЦЕЛЬ?" |
| 1 | PREP | 120s (2 мин) | #FF8A00 (оранжевый) | "ОРУЖИЕ К БОЮ!" |
| 2 | STRIKE | 180s (3 мин) | #FF0000 (красный) | "УНИЧТОЖАЙ" |
| 3 | ПЕРЕЗАГРУЗКА | 60-240s (случайно) | #0A1E5C (глубокий синий) | "БУДЬ ГОТОВ ВСЕГДА" |

### State Management (TimerProvider)

```dart
int _currentPhaseIndex = 0;         // Текущая фаза
int _remainingSeconds = 60;         // Оставшееся время
bool _isRunning = false;           // Таймер работает
bool _isInertiaMode = false;       // Режим инерции активен
int _inertiaSeconds = 0;          // Время в инерции
bool _isWaitingForChoice = false;  // Ожидание выбора (ИНЕРЦИЯ/ОТДЫХ)
bool _hasPlayedWarning = false;    // Флаг предупреждения
bool _needsTargetConfirmation = false; // Требуется подтверждение цели
int? _targetEndTimeMillis;        // Абсолютное время окончания
int? _inertiaStartTimeMillis;     // Время старта инерции
Timer? _timer;                     // Основной таймер
Timer? _deadManSwitchTimer;       // Dead Man's Switch таймер
```

### Transitions Logic

**ENGAGE (toggle):**
- `isRunning == false` → `isRunning = true`, старт таймера
- `isRunning == true` → `isRunning = false`, пауза (сохранение remainingSeconds)
- Звук start.mp3 при любом нажатии

**HALT (reset):**
- `isRunning = false`
- `currentPhaseIndex = 0`
- `remainingSeconds = 60`
- Отмена всех таймеров
- Остановка foreground service
- Скрытие уведомлений

**Auto-transition при окончании фазы:**
- Фаза 0 (THINKING): остановка, `needsTargetConfirmation = true`, зацикленный beep
- Фазы 0-1 (THINKING→PREP): автоматический переход
- Фазы 1-2 (PREP→STRIKE): автоматический переход
- Фаза 2 (STRIKE): остановка, `isWaitingForChoice = true`, Dead Man's Switch (30s)
- Фаза 3 (ПЕРЕЗАГРУЗКА): автоматический переход к фазе 0 и запуск нового цикла

### UI Components (MainScreen)

**Display:**
- "ФАЗА X. НАЗВАНИЕ" (верх)
- Текст фазы (центр)
- Таймер mm:ss (96pt monospace)
- **Прогресс-бар (4 сегмента)** - отличное от PRD отклонение
- Кнопка СТАРТ/ПАУЗА (цвет фазы)
- Кнопка СБРОС (при паузе)

**Overlays:**
- Target Confirmation Overlay: "ЦЕЛЬ НАЙДЕНА?" (после THINKING)
- Инерция Mode: замена таймера на секунды инерции

---

## 4. Audio System (Stage 8)

### AudioService (just_audio)
```dart
// Sounds
'start.mp3'     // Нажатие СТАРТ/ПАУЗА
'bolt.mp3'      // Переход к фазе PREP (1→2)
'siren.mp3'       // Переход к фазе STRIKE (2→3)
'rest.mp3'       // Начало ПЕРЕЗАГРУЗКИ
'ignite.mp3'     // Активация инерции
'beep.mp3'       // Предупреждение + Dead Man's Switch
'scan.mp3'       // Конец цикла (переход к THINKING)
```

### Sound Triggers
- `toggle()`: start.mp3 всегда
- `playPhaseSound(phaseIndex)`: звук перехода между фазами
- `playWarningSound()`: 6 секунд до конца (кроме STRIKE)
- `startLoopingBeep()`: при Target Confirmation и Waiting For Choice (20 минут)
- `playInertiaSound()`: при активации инерции
- `playCycleEndSound()`: при окончании цикла

---

## 5. Notification System

### NotificationService (flutter_local_notifications)
- Канал: `bypass_1236_audio_channel`
- ID: 1236
- Показ текущей фазы и оставшегося времени
- Обновление каждую секунду
- Скрытие при паузе/reset

---

## 6. Stats & Ranks (Stage 9-10)

### Rank System (геометрическая прогрессия)
```
ROOKIE (100) → RECRUIT (200) → SOLDIER (350) → EXECUTOR (550) → STRIKER (850) → 
DESTROYER (1300) → PHANTOM (2000) → TITAN (3000) → ARCHON (4500) → LEGEND (6700) → 
SLAYER (10000) → WARLORD (15000) → OVERLORD (22500) → APEX PREDATOR (33750) → ULTIMATUM (50000)
```

### Stats Metrics
- `totalStrikes`: завершенные циклы
- `totalInertiaTime`: суммарное время инерции (сек)
- `totalDominationHours`: (strikes * 180 + inertiaTime) / 3600

---

## 7. Paywall & Limits (Stage 11)

### Free Tier Limitations
- `freeCyclesPerDay = 3`
- Инерция недоступна
- Ограничение проверяется в `canStartCycle`

### Premium Features
- Бесконечные циклы
- Режим ИНЕРЦИЯ
- Полная статистика
- Статус: `isPremium = true`

---

## 8. Acceptance Criteria (Фактическое поведение)

### AC1: Загрузка
- ✅ UI отображает "ФАЗА 1. THINKING" и "01:00"
- ✅ Состояние восстанавливается из SharedPreferences

### AC2: Пауза/Resume
- ✅ ENGAGE во время RUNNING → PAUSE
- ✅ ENGAGE при PAUSE → RESUME с тем же remaining

### AC3: HALT
- ✅ HALT → сброс к ФАЗА 1 и 01:00
- ✅ Автопереходы отменяются

### AC4: Автопереходы
- ✅ 0 (THINKING) завершается → Target Confirmation
- ✅ 1 (PREP) → 2 (STRIKE) автоматически
- ✅ 2 (STRIKE) → Waiting For Choice (ИНЕРЦИЯ/ОТДЫХ)
- ✅ 3 (ПЕРЕЗАГРУЗКА) → 0 (THINKING) автоматически

### AC5: Поведение после фазы 3
- ✅ Автоматический переход к THINKING + запуск
- ❌ Отличие от PRD: не останавливается на 00:00

### AC6: UI
- ✅ Отображается "ФАЗА X. НАЗВАНИЕ"
- ✅ Формат времени mm:ss
- ✅ **Отклонение:** прогресс-бар добавлен (4 сегмента)

### AC7: Тайминг
- ✅ DateTime.now() + targetEndTimeMillis
- ✅ Без накопления ошибок

---

## 🛑 As-Built Deviations (Отклонения реальности от плана)

### Stage 0: Core Mechanic
1. **Фазы:** Было "1-2-3-6", стало "1-2-3" с 4 фазами (THINKING, PREP, STRIKE, ПЕРЕЗАГРУЗКА)
2. **UI:** Добавлен прогресс-бар (4 сегмента), запрещенный в Stage 0
3. **Хранилище:** SharedPreferences вместо in-memory state
4. **Platform:** Flutter/Dart вместо browser JS (performance.now)
5. **Time source:** DateTime.now().millisecondsSinceEpoch вместо performance.now()

### Stage 5-7: Психологические механики (ранний внедр)
1. **Инерция:** Реализована в Stage 0 (должна быть Stage 5)
2. **Target Confirmation:** Реализован в Stage 0 (должен быть Stage 6)
3. **Chaos Protocol:** Случайная длительность и скрытый таймер (должен быть Stage 7)

### Stage 8: Audio
1. **AudioService:** Использует just_audio вместо Web Audio API
2. **Звуки:** Все 8 звуковых файлов реализованы

### Stage 9-10: Stats & Ranks
1. **StatsProvider:** Полная статистика реализована
2. **StatsScreen:** Экран "БОЕВЫЕ ЗАСЛУГИ" с рангами

### Stage 11: Paywall
1. **PaywallScreen:** UI реализован
2. **Лимиты:** 3 цикла/день для free
3. **Оплата:** Mock-реализация (activatePremium())

### Технические компромиссы
1. **Background execution:** Foreground service (Android only) для работы в фоне
2. **Audio initialization:** Graceful degradation при ошибках
3. **Notification:** flutter_local_notifications с кастомным каналом
4. **Wakelock:** wakelock_plus для предотвращения сна экрана

---

## 9. Security & Authentication

Stage 0-4: **без Auth**, **без пользователей**. Все локально.

---

## 10. Error Handling

- Все сервисы работают в `try-catch`
- Graceful degradation при ошибках audio/notification
- Safe state на READY/Фаза 1 при ошибках

---
*Добавлено: 2026-06-14*
## Architecture Upgrade: Version 1.1 - Meta Time Scaling (Global Time Warp)

### 0. Scope / Non-goals
- Не меняем порядок фаз и точки переходов (THINKING → PREP → STRIKE → ПЕРЕЗАГРУЗКА).
- Не добавляем сервер/БД: только локальная настройка в state/UI.

### 1. Architectural Changes (Изменения в архитектуре)
Добавляется глобальный параметр **timeWarpScale** (ползунок Meta Time Scaling), который применяется в логике расчёта тайминга фаз внутри `TimerProvider`.

Новый принцип:
- **Порядок фаз и точки переходов не меняются**: THINKING → PREP → STRIKE → ПЕРЕЗАГРУЗКА.
- **Масштаб меняет только темп**: длительность фаз (и оставшееся время) вычисляется с учётом `timeWarpScale`.
- **Требование “без зависания”**: при любом изменении `timeWarpScale` автопереходы продолжают срабатывать по корректно масштабированному таймингу; таймер не должен “переставать” завершать фазу.

### 2. Database Migrations (Миграции БД)
Server-side БД нет, только offline state в SharedPreferences.

**Storage (SharedPreferences / timer state) — (ALTER, CREATE keys):**
- Добавить ключ **`timeWarpScale`** (double, Nullable) в локально-персистентное состояние настроек/таймера.
- Backward compatibility:
  - если ключ отсутствует — default `timeWarpScale = 1.0`.

### 3. API Delta Contracts (Изменения в контрактах API)
Backend/API отсутствует.
- **Внутренний контракт:** `TimerProvider` получает текущее значение `timeWarpScale` из UI Settings/State и применяет его при вычислениях:
  - вычисление `targetEndTimeMillis`/`remainingSeconds`
  - проверка условий завершения фазы для автопереходов

### 4. Infrastructure & Third-Party (Инфраструктура)
Не требуется новых интеграций/сервисов.

### 5. Fallback & Migration Strategy (План Б)
- Если `timeWarpScale` недоступен/невалиден — fallback `timeWarpScale = 1.0`.
- Если пользователь меняет ползунок во время RUNNING:
  - поведение должно обеспечивать продолжение автопереходов (переходы не должны “останавливаться” из-за рассинхрона тайминга).

---
*Добавлено: 2026-07-13*
## Architecture Upgrade: Version 1.2 - Deep Flow Inertia Controller (Auto after Phase 3)

### 1. Architectural Changes (Изменения в архитектуре)
Цель апгрейда — убрать ветвление после завершения фазы 3 (“Уничтожай”) и переводить пользователя в режим **INERTIA** автоматически, без UI выбора “⚡ ИНЕРЦИЯ / 🧠 ОТДЫХ”.

Изменения в state machine (delta):
- **Было:** после завершения **STRIKE (фаза 3)** система переводит в ветку ожидания выбора режимов (ИНЕРЦИЯ/ОТДЫХ).
- **Стало:** после завершения **STRIKE (фаза 3)** сразу и автоматически:
  - включается `isInertiaMode = true`
  - вход в INERTIA выполняется **один раз** на одно завершение STRIKE (guard от повторного триггера).
- В INERTIA применяется отдельная внутренняя логика:
  - планировщик мягких pulse-сигналов каждые **3–6 минут** (рандом внутри диапазона) только пока активен `isInertiaMode`.
  - лимитер бездействия “MAX FLOW” на **6 циклов** (нарастание счётчика при отсутствии ответа/действий пользователя).
  - 30-секундное окно confirm на 6-м цикле:
    - если пользователь не подтверждает **YES в течение 30 секунд**, система автоматически переводит в стандартный **ОТДЫХ** (recovery/rest flow).

### 2. Database Migrations (Миграции БД)
Серверной БД нет; сохраняется только локальное состояние в **SharedPreferences** (offline persistence). Для сохранения устойчивости после перезапуска приложения добавляем *дополнительные поля* в `bypass_timer_state`.

**Storage (SharedPreferences / timer state) — (ALTER, new optional keys):**
- **Добавить (nullable / safe defaults):**
  - `inertiaCycleCount` (int, default `0`)
    - Количество завершенных “инерционных циклов” внутри INERTIA.
    - **Определение цикла (важно для консистентности):** 1 цикл = интервал INERTIA между двумя “проверками активности”:
      1) либо между входом в INERTIA/последним pulse,
      2) и моментом, когда система считает, что пользователь не сделал валидного действия (в текущей спецификации валидным действием считается нажатие `EXIT`, либо (если есть) подтверждение YES на overlay MAX FLOW).
    - Практически: `inertiaCycleCount` инкрементится ровно один раз на каждое срабатывание/истечение pulse-таймера INERTIA (если до этого не было `EXIT` и не был закрыт overlay через `YES`).
  - `inertiaNextPulseAtMillis` (int?, default `null`)
    - абсолютное время следующего pulse (вычисляется при входе в INERTIA и после каждого срабатывания pulse).
    - Для идемпотентности интерпретируется как **deadline**: `pulse` должен сработать **не чаще 1 раза** на одно и то же окно.
  - `inertiaPendingMaxFlowConfirmUntilMillis` (int?, default `null`)
    - абсолютное время истечения 30-секундного окна на 6-м цикле
  - `isInertiaConfirmShown` (bool, default `false`)
    - флаг отображения overlay “MAX FLOW REACHED. CONTINUE?”
  - `lastInertiaPhaseTransitionId` (int?, default `null`)
    - guard для гарантии “вход в INERTIA срабатывает ровно один раз” на завершение STRIKE.
    - **Правило:** вход в INERTIA выполняется только если `lastInertiaPhaseTransitionId != currentPhaseTransitionId` (см. ниже определение `currentPhaseTransitionId`).

**Определение `currentPhaseTransitionId` (для guard/идемпотентности):**
- `currentPhaseTransitionId` = монотонно растущий id “события завершения фазы”.
- Инкремент происходит **строго при фиксации** перехода STRIKE(фаза 3) → INERTIA (то есть один раз на одно завершение STRIKE).
- Это значение должно быть доступно на момент вычисления guard; если его нет в хранилище, то временно используем производную величину: `targetEndTimeMillis` фазы STRIKE + `currentPhaseIndex` (как строковой/числовой composite id), но лучше хранить явный id в state.

**Backward compatibility:**
- Если ключи отсутствуют (старые версии приложения):
  - `inertiaCycleCount = 0`
  - `inertiaNextPulseAtMillis = null` (планировщик создаётся при старте INERTIA)
  - `isInertiaConfirmShown = false`
  - `inertiaPendingMaxFlowConfirmUntilMillis = null`
  - `lastInertiaPhaseTransitionId = null` (guard устанавливается при первом завершении STRIKE в сессию)

**Схема новых связей (Delta ERD):**
```mermaid
erDiagram
    TIMER_STATE {
        int inertiaCycleCount
        int? inertiaNextPulseAtMillis
        bool isInertiaConfirmShown
        int? inertiaPendingMaxFlowConfirmUntilMillis
    }
```

### 3. API Delta Contracts (Изменения в контрактах API)
Backend/API отсутствует. Изменение — в *контракте поведения* UI и `TimerProvider`.

**NEW/Modified UI behavior (delta contracts):**
- **INERTIA entry trigger (MODIFIED):**
  - Триггер: завершение **STRIKE**.
  - Действие: `TimerProvider` выставляет `isInertiaMode = true` без пользовательского перехода/выбора.
  - Звук: проигрывается `bypass-app\bypass-apk\assets\sounds\ignite.mp3` при входе в INERTIA.
- **INERTIA UI lock (MODIFIED):**
  - В INERTIA показывается только одна кнопка: `EXIT`
  - Отсутствуют действия/кнопки кроме `EXIT` (и временного overlay confirm на 6-м цикле).
- **MAX FLOW confirm (NEW):**
  - При достижении лимита бездействия `inertiaCycleCount == 6`:
    - overlay: “MAX FLOW REACHED. CONTINUE?”
    - ожидание ответа **YES** в течение **30 секунд**
  - При отсутствии YES в срок:
    - автоматический переход в **ОТДЫХ** (standard rest/recovery transition дальше по текущим правилам).

**Breaking change?**
- Нет. Это изменение *ветвления в UI/flow после фазы 3*.
- Порядок фаз не нарушается: после INERTIA система продолжает стандартный recovery/rest сценарий так, как было предусмотрено ранее.

### 4. Infrastructure & Third-Party (Инфраструктура)
- Новые интеграции не требуются.
- Используется существующий аудио-ресурс:
  - `ignite.mp3` для входа и мягких pulse-сигналов в INERTIA.
- Тайминг pulse реализуется через существующую модель абсолютных timestamp’ов (`...AtMillis`) для устойчивости к пересчётам/паузам/перезапускам.

### 5. Fallback & Migration Strategy (План Б)
- Если после рестарта не удалось восстановить `inertiaNextPulseAtMillis` (ключ `null`):
  - при первом входе в INERTIA планировщик пересчитывает `inertiaNextPulseAtMillis` заново.
- Если confirm overlay не был восстановлен корректно (`isInertiaConfirmShown=false` при наличии pending timestamp):
  - при обнаружении `inertiaPendingMaxFlowConfirmUntilMillis != null` overlay должен быть показан до истечения 30 секунд (или сразу отработан авто-выход при истечении).
- Guard от повторного входа в INERTIA:
  - `lastInertiaPhaseTransitionId` используется как “одиночное срабатывание” на завершение STRIKE.
- Если воспроизведение `ignite.mp3` недоступно/провалилось:
  - аудио — best-effort, но переходы в INERTIA/ОТДЫХ должны происходить независимо от успешности audio.


