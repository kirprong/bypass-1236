@echo off
echo Building optimized APK for arm64-v8a only...
echo.

REM Clean previous build
flutter clean

REM Build APK only for arm64-v8a (reduces size significantly)
flutter build apk --target-platform android-arm64

echo.
echo Build complete!
echo.
echo APK location: build\app\outputs\apk\release\app-release.apk
echo.

REM Show APK size
for %%A in (build\app\outputs\apk\release\app-release.apk) do (
    set size=%%~zA
    set /a sizeMB=!size! / 1048576
    echo APK Size: !sizeMB! MB
)

pause
