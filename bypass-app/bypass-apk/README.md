# 1234 - Flutter App

**Техника 1-2-3: Взлом продуктивности**

Приложение для продуктивной работы по методу 1-2-3:
- 1 минута - Анализ задачи
- 2 минуты - Подготовка
- 3 минуты - Работа
- Рандомный отдых (1-4 минуты) с автоматическим перезапуском цикла

## Особенности

✨ **GOD MODE (Инерция)** - продолжай работать когда поймал поток  
🎯 **Система рангов** - от Планктона до Apex Predator  
🔊 **Звуковое сопровождение** - психологические якоря для каждой фазы  
📊 **Статистика** - отслеживание прогресса и времени доминирования  
💎 **Premium версия** - безлимитные циклы и расширенные функции

## Структура проекта

```
bypass-apk/
├── lib/
│   ├── main.dart                 # Точка входа
│   ├── providers/                # State management
│   │   ├── timer_provider.dart   # Логика таймера и фаз
│   │   └── stats_provider.dart   # Статистика пользователя
│   ├── screens/                  # UI экраны
│   │   ├── main_screen.dart      # Главный экран с таймером
│   │   ├── stats_screen.dart     # Статистика и ранги
│   │   └── paywall_screen.dart   # Премиум подписка
│   ├── services/                 # Сервисы
│   │   └── audio_service.dart    # Управление звуками
│   └── utils/                    # Утилиты
│       └── constants.dart        # Константы и цвета
├── assets/
│   └── sounds/                   # Звуковые файлы
└── pubspec.yaml                  # Зависимости
```

## Установка зависимостей

```bash
flutter pub get
```

## Запуск в режиме разработки

```bash
# На эмуляторе
flutter run

# На подключенном устройстве
flutter run -d <device-id>
```

## Сборка APK

### Вариант 1: Локальная сборка (требует Android SDK)

```bash
# Debug версия
flutter build apk --debug

# Release версия
flutter build apk --release

# Split APK по архитектурам (меньший размер)
flutter build apk --split-per-abi
```

APK файлы будут в папке: `build/app/outputs/flutter-apk/`

### Вариант 2: Онлайн сборка через Codemagic

1. Зарегистрируйтесь на [codemagic.io](https://codemagic.io)
2. Подключите репозиторий
3. Выберите Flutter project
4. Настройте сборку для Android
5. Запустите build

### Вариант 3: GitHub Actions (если проект в GitHub)

Создайте файл `.github/workflows/build.yml`:

```yaml
name: Build APK

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v3
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

## Настройка Android SDK (для локальной сборки)

1. **Установите Android Studio**: https://developer.android.com/studio
2. **Откройте SDK Manager** в Android Studio
3. **Установите необходимые компоненты**:
   - Android SDK Platform (минимум API 21)
   - Android SDK Build-Tools
   - Android SDK Command-line Tools
4. **Настройте переменные окружения**:
   ```bash
   # Windows
   ANDROID_HOME=C:\Users\<username>\AppData\Local\Android\Sdk
   
   # Add to PATH
   %ANDROID_HOME%\platform-tools
   %ANDROID_HOME%\tools
   ```
5. **Проверьте установку**:
   ```bash
   flutter doctor
   ```

## Технологии

- **Flutter** 3.x - UI фреймворк
- **Provider** - State management
- **just_audio** - Воспроизведение звуков
- **shared_preferences** - Локальное хранилище
- **vibration** - Вибрация при переходах
- **wakelock_plus** - Предотвращение затухания экрана

## Цветовая схема

- 🔵 **Phase 1 (THINKING)**: Холодный неон `#00D4FF`
- 🟠 **Phase 2 (PREP)**: Пульсирующий оранжевый `#FF8A00`
- 🔴 **Phase 3 (STRIKE)**: Агрессивный красный `#FF0000`
- 🔵 **Phase 4 (ПЕРЕЗАГРУЗКА)**: Глубокий синий `#0A1E5C` (для отдыха глаз)
- 🟡 **INERTIA MODE**: Золотой `#FFD700`

## Монетизация

**Free версия:**
- 3 цикла в день
- Базовая статистика

**Premium ($5/месяц):**
- Безлимитные циклы
- Режим инерции
- Полная статистика
- Премиум звуки

## Лицензия

Приложение создано для личного использования.

## Новые фичи в версии 1.0.0

🎲 **Непредсказуемый отдых**: Длительность перезагрузки рандомна (1-4 минуты), таймер скрыт
🔄 **Автоматический перезапуск**: После отдыха система сама запускает новый цикл
🎨 **Успокаивающий дизайн**: Глубокий синий цвет и пульсирующая анимация во время отдыха
⚡ **Всегда готов**: Отсутствие предсказуемости держит тебя в тонусе

---

**1234** - Перестань планировать. Начни доминировать. 🔥
