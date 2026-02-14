@echo off
:: Переходим в папку проекта, если скрипт запущен из другого места
cd /d "%~dp0"

echo [1/2] Проверка зависимостей...
call flutter pub get

echo [2/2] Запуск приложения в браузере (Chrome)...
echo Для тестирования в других браузерах используйте: flutter run -d web-server
echo.

:: Запуск в Chrome для интерактивной отладки
call flutter run -d chrome

pause
