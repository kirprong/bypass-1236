# 🛠️ Вариант 2: Правильная установка Android SDK

## Что делаем
Устанавливаем Android Studio и Android SDK для правильной сборки и отладки.

## Шаги установки

### 1. Скачать Android Studio
Перейдите на: https://developer.android.com/studio
Скачайте последнюю версию (Ladybug | 2024.2.2 или новее)

### 2. Установить Android Studio
1. Запустите установщик
2. Выберите "Standard" installation
3. Дождитесь установки (займёт 10-20 минут)
4. При первом запуске выберите "Install SDK"

### 3. Установить Android SDK компоненты
В Android Studio:
1. Откройте `Tools → SDK Manager`
2. Во вкладке "SDK Platforms" отметьте:
   - ✅ Android 14.0 (API 34) - Recommended
   - ✅ Android 13.0 (API 33)
   - ✅ Show Package Details → Android SDK Platform 34

3. Во вкладке "SDK Tools" отметьте:
   - ✅ Android SDK Build-Tools 34
   - ✅ Android SDK Command-line Tools
   - ✅ Android SDK Platform-Tools
   - ✅ Android Emulator
   - ✅ Google Play services

4. Нажмите "Apply" и дождитесь установки

### 4. Настроить переменные окружения
#### Windows PowerShell (как администратор):
```powershell
# Путь к Android SDK (обычно)
$androidSdk = "$env:LOCALAPPDATA\Android\Sdk"

# Добавить в PATH
[Environment]::SetEnvironmentVariable(
    "ANDROID_HOME",
    $androidSdk,
    [EnvironmentVariableTarget]::User
)

[Environment]::SetEnvironmentVariable(
    "Path",
    $env:Path + ";$androidSdk\platform-tools;$androidSdk\tools;$androidSdk\tools\bin",
    [EnvironmentVariableTarget]::User
)

Write-Host "Android SDK установлен в: $androidSdk" -ForegroundColor Green
```

### 5. Настроить Flutter
```bash
# Указать Flutter где находится Android SDK
flutter config --android-sdk $env:LOCALAPPDATA\Android\Sdk

# Принять лицензии
flutter doctor --android-licenses

# Проверить установку
flutter doctor -v
```

Вы должны увидеть:
```
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
```

### 6. Настроить проект
Создайте или обновите `android/local.properties`:
```properties
sdk.dir=C:\\Users\\<YOUR_USERNAME>\\AppData\\Local\\Android\\Sdk
flutter.sdk=C:\\src\\flutter
flutter.buildMode=release
flutter.versionName=1.0.0
flutter.versionCode=1
```

### 7. Пересобрать проект
```bash
cd first/BYPASS-1236/bypass-app/bypass-apk

# Очистка
flutter clean
rm -rf android/app/build
rm -rf build

# Получение зависимостей
flutter pub get

# Сборка
flutter build apk --release --verbose
```

### 8. Отладка на реальном устройстве
```bash
# Подключите телефон по USB
# Включите "Режим разработчика" и "Отладка по USB"

# Проверьте подключение
adb devices

# Запустите приложение с логами
flutter run --release

# Или установите APK и смотрите логи
flutter install
adb logcat | grep -E "flutter|bypass"
```

## Преимущества этого подхода
- ✅ Правильная сборка APK
- ✅ Полная отладка
- ✅ Можно видеть все ошибки в реальном времени
- ✅ Профессиональный подход
- ✅ Все функции работают корректно

## Проверка после установки
```bash
flutter doctor -v
```

Должно быть:
```
[✓] Flutter (Channel stable, 3.41.1)
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
[✓] Android Studio (version 2024.2)
[✓] Connected device (1 available)
```

## Troubleshooting
Если `flutter doctor` показывает ошибки:

### Проблема: "Unable to locate Android SDK"
```bash
flutter config --android-sdk C:\Users\<USERNAME>\AppData\Local\Android\Sdk
```

### Проблема: "Android license status unknown"
```bash
flutter doctor --android-licenses
# Нажимайте 'y' на все вопросы
```

### Проблема: "cmdline-tools component is missing"
1. Откройте Android Studio
2. Tools → SDK Manager → SDK Tools
3. Отметьте "Android SDK Command-line Tools"
4. Apply

## Сборка после установки SDK
```bash
cd first/BYPASS-1236/bypass-app/bypass-apk
flutter build apk --release
```

APK будет в:
```
build/app/outputs/flutter-apk/app-release.apk
```
